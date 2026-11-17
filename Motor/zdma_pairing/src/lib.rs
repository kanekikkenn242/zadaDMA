// zadaDMA on-device remote pairing + House Arrest/AFC bridge.
//
// This is the iOS 27 device-initiated pairing path:
//   1. advertise as a pairable host (NSNetService does the mDNS in ObjC),
//   2. accept the device, show the 6-digit PIN, persist the RPPairing file,
//   3. open the RPPairing tunnel to the device's _remotepairing._tcp service,
//   4. connect to House Arrest over RSD and write the .3105 file with AFC.

use base64::Engine as _;
use idevice::afc::opcode::AfcFopenMode;
use idevice::afc::AfcClient;
use idevice::house_arrest::HouseArrestClient;
use idevice::remote_pairing::{
    compute_auth_tag, connect_tls_psk_tunnel_native, PairableHost, PairableHostInfo,
    RemotePairingClient, RpPairingFile, RpPairingSocket,
};
use idevice::rsd::RsdHandshake;
use idevice::tcp::adapter::Adapter;
use idevice::RsdService;
use std::ffi::{c_char, c_void, CStr, CString};
use std::net::{IpAddr, SocketAddr};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Duration;

type ReadyCb = extern "C" fn(
    *const c_char,
    *const c_char,
    *const c_char,
    *const c_char,
    *const c_char,
    *const c_char,
    *const c_char,
    u16,
    *mut c_void,
);
type PinCb = extern "C" fn(*const c_char, *mut c_void);

const CANCELLED: &str = "__CANCELLED__";

static CANCEL: OnceLock<Arc<AtomicBool>> = OnceLock::new();

fn cancel_flag() -> Arc<AtomicBool> {
    CANCEL
        .get_or_init(|| Arc::new(AtomicBool::new(false)))
        .clone()
}

fn runtime() -> Result<tokio::runtime::Runtime, String> {
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .map_err(|e| format!("Tokio runtime: {e}"))
}

unsafe fn set_buf(buf: *mut c_char, len: usize, text: &str) {
    if buf.is_null() || len == 0 {
        return;
    }
    let bytes = text.as_bytes();
    let n = bytes.len().min(len - 1);
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), buf as *mut u8, n);
        *(buf as *mut u8).add(n) = 0;
    }
}

unsafe fn cstr<'a>(p: *const c_char) -> Option<&'a str> {
    if p.is_null() {
        None
    } else {
        unsafe { CStr::from_ptr(p) }.to_str().ok()
    }
}

async fn wait_cancel(flag: Arc<AtomicBool>) {
    while !flag.load(Ordering::Relaxed) {
        tokio::time::sleep(Duration::from_millis(150)).await;
    }
}

#[no_mangle]
pub unsafe extern "C" fn zdma_pairing_host_cancel() {
    cancel_flag().store(true, Ordering::Relaxed);
}

#[no_mangle]
pub unsafe extern "C" fn zdma_pairing_host_accept(
    name: *const c_char,
    model: *const c_char,
    port: u16,
    ready: Option<ReadyCb>,
    pin_cb: Option<PinCb>,
    ctx: *mut c_void,
    pairing_file_path: *const c_char,
    errbuf: *mut c_char,
    errbuf_len: usize,
) -> i32 {
    let name = match unsafe { cstr(name) } {
        Some(v) => v.to_string(),
        None => {
            unsafe { set_buf(errbuf, errbuf_len, "Invalid host name") };
            return 1;
        }
    };
    let model = unsafe { cstr(model) }.unwrap_or("Mac17,7").to_string();
    let pairing_path = match unsafe { cstr(pairing_file_path) } {
        Some(v) => v.to_string(),
        None => {
            unsafe { set_buf(errbuf, errbuf_len, "Invalid pairing file path") };
            return 1;
        }
    };

    let cancel = cancel_flag();
    cancel.store(false, Ordering::Relaxed);
    let ctx_addr = ctx as usize;

    let rt = match runtime() {
        Ok(rt) => rt,
        Err(e) => {
            unsafe { set_buf(errbuf, errbuf_len, &e) };
            return 1;
        }
    };

    let result: Result<(), String> = rt.block_on(async move {
        let listener = tokio::net::TcpListener::bind(("0.0.0.0", port))
            .await
            .map_err(|e| format!("Bind port {port}: {e}"))?;
        let actual_port = listener
            .local_addr()
            .map_err(|e| format!("Local port: {e}"))?
            .port();

        let mut pairing_file = RpPairingFile::generate(&name);
        // Fresh random uppercase UUID per pairing. The device keys the host by this
        // exact string: it is sent in the handshake `peerDeviceInfo.identifier`, in
        // the M6 identity TLV, advertised in the pairable-host TXT record, and later
        // presented during pair-verify on `_remotepairing._tcp`. iOS normalizes UUIDs
        // to uppercase, so every one of them must use the canonical uppercase form.
        pairing_file.identifier = uuid::Uuid::new_v4().to_string().to_uppercase();
        let identifier = pairing_file.identifier.clone();
        let mut host_info = PairableHostInfo::generate(&name, &model);
        host_info.identifier = identifier.clone();
        host_info.allows_pinless_pairing = false;
        let txt = host_info.mdns_txt_records(&identifier);

        if let Some(cb) = ready {
            let value = |key: &str| -> &str {
                txt.iter()
                    .find(|(k, _)| k == key)
                    .map(|(_, v)| v.as_str())
                    .unwrap_or("")
            };
            let c_id = CString::new(identifier.clone()).unwrap_or_default();
            let c_name = CString::new(name.clone()).unwrap_or_default();
            let c_model = CString::new(model.clone()).unwrap_or_default();
            let c_auth = CString::new(value("authTag")).unwrap_or_default();
            let c_flags = CString::new(value("flags")).unwrap_or_default();
            let c_ver = CString::new(value("ver")).unwrap_or_default();
            let c_min = CString::new(value("minVer")).unwrap_or_default();
            cb(
                c_id.as_ptr(),
                c_name.as_ptr(),
                c_model.as_ptr(),
                c_auth.as_ptr(),
                c_flags.as_ptr(),
                c_ver.as_ptr(),
                c_min.as_ptr(),
                actual_port,
                ctx_addr as *mut c_void,
            );
        }

        let accepted = tokio::select! {
            r = listener.accept() => Some(r),
            _ = wait_cancel(cancel.clone()) => None,
        };

        let (stream, _peer) = match accepted {
            None => return Err(CANCELLED.to_string()),
            Some(Ok(v)) => v,
            Some(Err(e)) => return Err(format!("Accept: {e}")),
        };

        let socket = RpPairingSocket::new_device(stream);
        let mut host = PairableHost::new(socket, host_info);

        let pairing = host.accept(&mut pairing_file, move |pin: String| {
            let ctx = ctx_addr as *mut c_void;
            async move {
                if let Some(cb) = pin_cb {
                    if let Ok(cpin) = CString::new(pin) {
                        cb(cpin.as_ptr(), ctx);
                    }
                }
            }
        });

        let mut pairing = Box::pin(pairing);
        let peer = tokio::select! {
            r = &mut pairing => Some(r),
            _ = wait_cancel(cancel.clone()) => None,
        };
        drop(pairing);

        match peer {
            None => Err(CANCELLED.to_string()),
            Some(Ok(peer)) => {
                pairing_file
                    .write_to_file(&pairing_path)
                    .await
                    .map_err(|e| format!("Write pairing file: {e}"))?;
                let _ = peer;
                Ok(())
            }
            Some(Err(e)) => Err(format!("Pairing: {e}")),
        }
    });

    match result {
        Ok(()) => 0,
        Err(e) if e == CANCELLED => {
            unsafe { set_buf(errbuf, errbuf_len, "Pairing cancelled") };
            2
        }
        Err(e) => {
            unsafe { set_buf(errbuf, errbuf_len, &e) };
            1
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn zdma_pairing_file_validate(
    pairing_file_path: *const c_char,
    service_identifier: *const c_char,
    auth_tag: *const c_char,
) -> i32 {
    let path = match unsafe { cstr(pairing_file_path) } {
        Some(v) => v,
        None => return -1,
    };
    let identifier = match unsafe { cstr(service_identifier) } {
        Some(v) => v,
        None => return 0,
    };
    let tag = match unsafe { cstr(auth_tag) } {
        Some(v) => v,
        None => return 0,
    };

    let bytes = match std::fs::read(path) {
        Ok(v) => v,
        Err(_) => return -1,
    };
    let pairing = match RpPairingFile::from_bytes(&bytes) {
        Ok(v) => v,
        Err(_) => return -1,
    };
    let alt_irk = match pairing.alt_irk.as_deref() {
        Some(v) if v.len() == 16 => v,
        _ => return 0,
    };
    let decoded = match base64::engine::general_purpose::STANDARD.decode(tag) {
        Ok(v) if v.len() == 6 => v,
        _ => return 0,
    };
    let key: [u8; 16] = alt_irk.try_into().unwrap();
    let expected = compute_auth_tag(&key, identifier);
    if expected.as_slice() == decoded.as_slice() {
        1
    } else {
        0
    }
}

fn candidates(remote_path: &str) -> Vec<String> {
    let mut relative = remote_path.trim_start_matches('/').to_string();
    if let Some(pos) = relative.find("Data/Raw/") {
        relative = relative[pos..].to_string();
    }
    let mut out = Vec::new();
    out.push(relative.clone());
    if !relative.starts_with("Documents/") {
        out.push(format!("Documents/{relative}"));
    }
    if !relative.starts_with("Library/") {
        out.push(format!("Library/{relative}"));
        out.push(format!("Library/Caches/{relative}"));
    }
    out.dedup();
    out
}

async fn write_candidate(afc: &mut AfcClient, path: &str, data: &[u8]) -> Result<(), String> {
    let mut file = afc
        .open(path, AfcFopenMode::WrOnly)
        .await
        .map_err(|e| format!("{e}"))?;
    file.write_entire(data)
        .await
        .map_err(|e| format!("write: {e}"))?;
    file.close().await.map_err(|e| format!("close: {e}"))?;
    Ok(())
}

fn stage_error(stage: &str, error: idevice::IdeviceError) -> String {
    // `IdeviceError::Socket` only renders as "device socket io failed", which hid
    // the real reason (RST, EOF, timeout) during pair-verify. Surface the io kind.
    let detail = match error {
        idevice::IdeviceError::Socket(io) => format!("{} ({io})", io.kind()),
        other => other.to_string(),
    };
    format!("{stage}: {detail}")
}

/// Parses the comma-separated candidate list produced by `IdeviceBridge`.
///
/// The order is significant: the bridge puts the loopback/utun paths first,
/// because a direct connection to the iPhone's own Wi-Fi address is reset by
/// `remoted`, while the LocalDevVPN loopback path is accepted.
fn endpoint_list(host: &str, port: u16) -> Result<Vec<SocketAddr>, String> {
    let mut out: Vec<SocketAddr> = Vec::new();
    for raw in host.split(',') {
        let raw = raw.trim();
        if raw.is_empty() {
            continue;
        }
        let raw = raw.trim_start_matches('[').trim_end_matches(']');
        let ip: IpAddr = match raw.parse() {
            Ok(ip) => ip,
            Err(_) => continue,
        };
        let addr = SocketAddr::new(ip, port);
        if !out.contains(&addr) {
            out.push(addr);
        }
    }
    if out.is_empty() {
        return Err(format!("Invalid device address: {host}"));
    }
    Ok(out)
}

type RppStream = RpPairingSocket<tokio::net::TcpStream>;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(3);
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(8);
const VERIFY_TIMEOUT: Duration = Duration::from_secs(12);

/// Runs the handshake + pair-verify against one candidate address.
///
/// Returns `(message, fatal)`: `fatal` means the device answered and rejected
/// the pairing file, so trying another address cannot help.
async fn verify_endpoint(
    addr: SocketAddr,
    hostname: &str,
    pairing: &mut RpPairingFile,
) -> Result<RemotePairingClient<RppStream>, (String, bool)> {
    let stream = match tokio::time::timeout(CONNECT_TIMEOUT, tokio::net::TcpStream::connect(addr))
        .await
    {
        Err(_) => return Err(("TCP: timeout 3s".to_string(), false)),
        Ok(Err(e)) => return Err((format!("TCP: {e}"), false)),
        Ok(Ok(stream)) => stream,
    };
    let _ = stream.set_nodelay(true);
    let mut rpc = RemotePairingClient::new(RpPairingSocket::new(stream), hostname);

    match tokio::time::timeout(HANDSHAKE_TIMEOUT, rpc.attempt_pair_verify()).await {
        Ok(Ok(_)) => {}
        Ok(Err(e)) => return Err((stage_error("handshake", e), false)),
        Err(_) => return Err(("handshake: timeout 8s".to_string(), false)),
    }

    match tokio::time::timeout(VERIFY_TIMEOUT, rpc.validate_pairing(pairing)).await {
        Ok(Ok(())) => Ok(rpc),
        Ok(Err(e)) => {
            let fatal = matches!(
                e,
                idevice::IdeviceError::RemotePairing(
                    idevice::remote_pairing::errors::RemotePairingError::PairVerifyFailed
                )
            );
            Err((stage_error("verify", e), fatal))
        }
        Err(_) => Err(("verify: timeout 12s".to_string(), false)),
    }
}

#[no_mangle]
pub unsafe extern "C" fn zdma_tunnel_write_file(
    host: *const c_char,
    port: u16,
    hostname: *const c_char,
    pairing_file_path: *const c_char,
    bundle_id: *const c_char,
    remote_path: *const c_char,
    local_path: *const c_char,
    errbuf: *mut c_char,
    errbuf_len: usize,
    outbuf: *mut c_char,
    outbuf_len: usize,
) -> i32 {
    let host = unsafe { cstr(host) }.unwrap_or("").to_string();
    let hostname = unsafe { cstr(hostname) }.unwrap_or("zadaDMA").to_string();
    let pairing_path = unsafe { cstr(pairing_file_path) }.unwrap_or("").to_string();
    let bundle_id = unsafe { cstr(bundle_id) }.unwrap_or("").to_string();
    let remote_path = unsafe { cstr(remote_path) }.unwrap_or("").to_string();
    let local_path = unsafe { cstr(local_path) }.unwrap_or("").to_string();

    if host.is_empty() || pairing_path.is_empty() || bundle_id.is_empty() {
        unsafe { set_buf(errbuf, errbuf_len, "Missing device, pairing file or bundle id") };
        return 1;
    }

    let rt = match runtime() {
        Ok(rt) => rt,
        Err(e) => {
            unsafe { set_buf(errbuf, errbuf_len, &e) };
            return 1;
        }
    };

    let result: Result<String, String> = rt.block_on(async move {
        let endpoints = endpoint_list(&host, port)?;
        let mut pairing = RpPairingFile::read_from_file(&pairing_path)
            .await
            .map_err(|e| format!("Pairing file: {e}"))?;

        // Pairing files written before the uppercase identifier fix can never pass
        // pair-verify: fail with an explicit re-pair instruction instead of a vague
        // socket error after the device rejects the signature.
        if pairing.identifier.chars().any(|c| c.is_ascii_lowercase()) {
            return Err(
                "Pairing file i vjetër (identifier jo uppercase). Bëj Start Pairing përsëri."
                    .into(),
            );
        }

        // Only pair-verify belongs on `_remotepairing._tcp`. `RemotePairingClient::connect`
        // falls back to a full pair-setup when verify fails; the device closes that
        // connection, which surfaced as the misleading "device socket io failed".
        // Run the stages explicitly so the error says which one broke.
        //
        // Try every candidate path: on-device, the iPhone's own Wi-Fi address is
        // reset by `remoted`; the loopback/utun paths (LocalDevVPN) are the ones
        // that work. Keep the winner so the tunnel reuses the same address.
        let mut failures: Vec<String> = Vec::new();
        let mut winner: Option<(SocketAddr, RemotePairingClient<RppStream>)> = None;

        for addr in endpoints.iter().copied() {
            match verify_endpoint(addr, &hostname, &mut pairing).await {
                Ok(rpc) => {
                    winner = Some((addr, rpc));
                    break;
                }
                Err((detail, fatal)) => {
                    failures.push(format!("{addr}: {detail}"));
                    if fatal {
                        return Err(format!(
                            "{detail} — pairing file nuk pranohet; bëj Start Pairing përsëri."
                        ));
                    }
                }
            }
        }

        let (winning_addr, mut rpc) = match winner {
            Some(v) => v,
            None => {
                // Check if any utun/loopback VPN path was available
                let has_vpn_path = endpoints.iter().any(|a| {
                    let ip = a.ip().to_string();
                    ip.starts_with("10.7.") || ip == "127.0.0.1"
                });
                let vpn_hint = if has_vpn_path {
                    "LocalDevVPN është instaluar por nuk funksionon. Restart LocalDevVPN dhe provo përsëri."
                } else {
                    "Instalo \"LocalDevVPN\" nga App Store, aktivizo VPN-in dhe provo Inject përsëri — pa Start Pairing."
                };
                return Err(format!(
                    "RPPairing nuk u lidh ({} rrugë). {}. Wi-Fi ON, Developer Mode ON, \
                     Local Network ON. {}",
                    endpoints.len(),
                    failures.join(" | "),
                    vpn_hint
                ));
            }
        };

        let _ = pairing.write_to_file(&pairing_path).await;

        let tunnel_port = rpc
            .create_tcp_listener()
            .await
            .map_err(|e| format!("Create tunnel listener: {e}"))?;
        let tunnel_addr = SocketAddr::new(winning_addr.ip(), tunnel_port);
        let tunnel_stream = tokio::net::TcpStream::connect(tunnel_addr)
            .await
            .map_err(|e| format!("Tunnel TCP {tunnel_addr}: {e}"))?;
        let tunnel = connect_tls_psk_tunnel_native(tunnel_stream, rpc.encryption_key())
            .await
            .map_err(|e| format!("TLS-PSK tunnel: {e}"))?;

        let client_ip: IpAddr = tunnel
            .info
            .client_address
            .parse()
            .map_err(|e| format!("Tunnel client address: {e}"))?;
        let server_ip: IpAddr = tunnel
            .info
            .server_address
            .parse()
            .map_err(|e| format!("Tunnel server address: {e}"))?;
        let mtu = tunnel.info.mtu as usize;
        let rsd_port = tunnel.info.server_rsd_port;

        let raw = tunnel.into_inner();
        let mut adapter = Adapter::new(Box::new(raw), client_ip, server_ip);
        adapter.set_mss(mtu.min(8192).saturating_sub(60));
        let mut adapter = adapter.to_async_handle();
        let rsd_stream = adapter
            .connect(rsd_port)
            .await
            .map_err(|e| format!("RSD connect: {e}"))?;
        let mut handshake = RsdHandshake::new(rsd_stream)
            .await
            .map_err(|e| format!("RSD handshake: {e}"))?;

        let data = tokio::fs::read(&local_path)
            .await
            .map_err(|e| format!("Read {local_path}: {e}"))?;
        let targets = candidates(&remote_path);
        let mut failures = Vec::new();

        for vend in ["container", "documents"] {
            let client = HouseArrestClient::connect_rsd(&mut adapter, &mut handshake)
                .await
                .map_err(|e| format!("House Arrest connect ({vend}): {e}"))?;
            let afc = if vend == "container" {
                client.vend_container(&bundle_id).await
            } else {
                client.vend_documents(&bundle_id).await
            };

            match afc {
                Ok(mut afc) => {
                    for target in &targets {
                        match write_candidate(&mut afc, target, &data).await {
                            Ok(()) => {
                                return Ok(format!(
                                    "{} bytes -> {} ({})",
                                    data.len(),
                                    target,
                                    vend
                                ));
                            }
                            Err(e) => {
                                // Translate AFC write errors into Albanian UX
                                let txt = e.split("installationlookupfailed")
                                    .next()
                                    .unwrap_or(&e);
                                failures.push(format!("{vend}:{target}: {txt}"));
                            }
                        }
                    }
                }
                Err(e) => {
                    let txt = e.to_string();
                    if txt.contains("installationlookupfailed") {
                        failures.push(format!(
                            "Kontainer i/g requesting bundle ID '{}' nuk gjet. \
                             Njavezja: kontrollo versionin e Free Fire, Start Pairing përsëri.",
                            bundle_id
                        ));
                    } else {
                        failures.push(format!("{vend}: {txt}"));
                    }
                }
            }
        }

        Err(format!(
            "House Arrest/AFC dështoi: {}",
            failures.join(" | ")
        ))
    });

    match result {
        Ok(msg) => {
            unsafe { set_buf(outbuf, outbuf_len, &msg) };
            0
        }
        Err(e) => {
            unsafe { set_buf(errbuf, errbuf_len, &e) };
            1
        }
    }
}
