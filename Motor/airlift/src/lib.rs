// airlift_ffi — pairing-record → RemotePairing → RSD → AFC.
//
// The on-device path: a pairing record imported into the app is used to run the
// RPPairing handshake against the loopback endpoint published by LocalDevVPN,
// request a TCP listener from the device, wrap that listener in the TLS-PSK
// CDtunnel, run a userspace TCP stack over it, handshake RSD, and connect the
// `com.apple.afc.shim.remote` service. AFC then addresses the device filesystem
// directly, so a file inside another app's data container can be replaced
// without touching the local sandbox.
//
// Every exported function is self-contained: connect, work, disconnect. A patch
// is one file, so a per-call tunnel costs less than keeping a socket alive
// across app suspension.

use std::ffi::CStr;
use std::io::Cursor;
use std::net::IpAddr;
use std::os::raw::{c_char, c_int};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::OnceLock;
use std::time::Duration;

use idevice::afc::opcode::AfcFopenMode;
use idevice::afc::AfcClient;
use idevice::remote_pairing::{
    connect_tls_psk_tunnel_native, RemotePairingClient, RpPairingFile, RpPairingSocket,
};
use idevice::rsd::RsdHandshake;
use idevice::{tcp, ReadWrite, RsdService};
use sha2::{Digest, Sha256};
use tokio::net::TcpStream;
use tokio::time::timeout;

const AFC_SERVICE: &str = "com.apple.afc.shim.remote";
const SENDING_HOST: &str = "zadaDMA";
const CONNECT_TIMEOUT: Duration = Duration::from_secs(20);
const DATA_CONTAINER_ROOTS: [&str; 2] = [
    "/private/var/mobile/Containers/Data/Application",
    "/var/mobile/Containers/Data/Application",
];

static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

fn runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .thread_name("airlift")
            .build()
            .expect("airlift tokio runtime")
    })
}

struct PairingConfig {
    pairing_path: String,
    host: String,
    port: u16,
    pin: String,
}

/// A live AFC client plus the userspace TCP stack its stream rides on.
/// Field order matters: the AFC stream is dropped before the stack that feeds it.
struct AfcSession {
    afc: AfcClient,
    _stack: tcp::handle::AdapterHandle,
}

async fn open_afc(cfg: &PairingConfig) -> Result<AfcSession, String> {
    let mut pairing_file = RpPairingFile::read_from_file(&cfg.pairing_path)
        .await
        .map_err(|e| format!("cannot read pairing record: {e}"))?;

    let endpoint = format!("{}:{}", cfg.host, cfg.port);
    let stream = timeout(CONNECT_TIMEOUT, TcpStream::connect(&endpoint))
        .await
        .map_err(|_| format!("timeout connecting to {endpoint}"))?
        .map_err(|e| format!("cannot connect to {endpoint}: {e}"))?;

    let socket = RpPairingSocket::new(stream);
    let mut rpc = RemotePairingClient::new(socket, SENDING_HOST);

    let pin = cfg.pin.clone();
    let pin_cb = move || {
        let pin = pin.clone();
        async move { pin }
    };
    rpc.connect(&mut pairing_file, pin_cb)
        .await
        .map_err(|e| format!("pair-verify rejected: {e}"))?;

    let listener_port = rpc
        .create_tcp_listener()
        .await
        .map_err(|e| format!("device refused a tunnel listener: {e}"))?;

    let tunnel_stream = timeout(
        CONNECT_TIMEOUT,
        TcpStream::connect((cfg.host.as_str(), listener_port)),
    )
    .await
    .map_err(|_| "timeout connecting to the tunnel listener".to_string())?
    .map_err(|e| format!("cannot connect to tunnel listener {listener_port}: {e}"))?;

    let tunnel = connect_tls_psk_tunnel_native(tunnel_stream, rpc.encryption_key())
        .await
        .map_err(|e| format!("TLS-PSK tunnel handshake failed: {e}"))?;

    let client_ip: IpAddr = tunnel
        .info
        .client_address
        .parse()
        .map_err(|_| format!("bad tunnel client address: {}", tunnel.info.client_address))?;
    let server_ip: IpAddr = tunnel
        .info
        .server_address
        .parse()
        .map_err(|_| format!("bad tunnel server address: {}", tunnel.info.server_address))?;
    let rsd_port = tunnel.info.server_rsd_port;

    let raw = tunnel.into_inner();
    let adapter = tcp::adapter::Adapter::new(Box::new(raw), client_ip, server_ip);
    let mut handle = adapter.to_async_handle();

    let rsd_stream = timeout(CONNECT_TIMEOUT, handle.connect(rsd_port))
        .await
        .map_err(|_| "timeout opening RSD through the tunnel".to_string())?
        .map_err(|e| format!("RSD connect failed on port {rsd_port}: {e}"))?;

    let handshake = RsdHandshake::new(rsd_stream)
        .await
        .map_err(|e| format!("RSD handshake failed: {e}"))?;

    let afc_port = handshake
        .services
        .get(AFC_SERVICE)
        .map(|service| service.port)
        .ok_or_else(|| format!("{AFC_SERVICE} is not advertised by this build"))?;

    let afc_stream = timeout(CONNECT_TIMEOUT, handle.connect(afc_port))
        .await
        .map_err(|_| "timeout opening AFC".to_string())?
        .map_err(|e| format!("AFC connect failed on port {afc_port}: {e}"))?;

    let afc = <AfcClient as RsdService>::from_stream(
        Box::new(afc_stream) as Box<dyn ReadWrite>
    )
    .await
    .map_err(|e| format!("AFC handshake failed: {e}"))?;

    Ok(AfcSession {
        afc,
        _stack: handle,
    })
}

async fn read_remote(afc: &mut AfcClient, path: &str) -> Result<Vec<u8>, String> {
    let mut file = afc
        .open(path, AfcFopenMode::RdOnly)
        .await
        .map_err(|e| format!("open {path}: {e}"))?;
    let bytes = file
        .read_entire()
        .await
        .map_err(|e| format!("read {path}: {e}"));
    let _ = file.close().await;
    bytes
}

async fn write_remote(afc: &mut AfcClient, path: &str, data: &[u8]) -> Result<(), String> {
    let mut file = afc
        .open(path, AfcFopenMode::WrOnly)
        .await
        .map_err(|e| format!("open {path} for write: {e}"))?;
    let written = file.write_entire(data).await;
    let closed = file.close().await;
    written.map_err(|e| format!("write {path}: {e}"))?;
    closed.map_err(|e| format!("close {path}: {e}"))?;

    let info = afc
        .get_file_info(path)
        .await
        .map_err(|e| format!("stat {path}: {e}"))?;
    if info.size != data.len() {
        return Err(format!(
            "{path} landed at {} bytes, expected {}",
            info.size,
            data.len()
        ));
    }
    Ok(())
}

async fn find_container(afc: &mut AfcClient, bundle_id: &str) -> Result<String, String> {
    for root in DATA_CONTAINER_ROOTS {
        let entries = match afc.list_dir(root).await {
            Ok(entries) => entries,
            Err(_) => continue,
        };

        for entry in entries {
            let name = entry.trim_matches('/');
            if name.is_empty() {
                continue;
            }
            let meta_path =
                format!("{root}/{name}/.com.apple.mobile_container_manager.metadata.plist");
            let Ok(bytes) = read_remote(afc, &meta_path).await else {
                continue;
            };
            let Ok(value) = plist::Value::from_reader(Cursor::new(bytes)) else {
                continue;
            };
            let Some(dict) = value.as_dictionary() else {
                continue;
            };
            if dict.get("MCMMetadataIdentifier").and_then(|v| v.as_string()) == Some(bundle_id) {
                return Ok(format!("{root}/{name}"));
            }
        }
    }
    Err(format!(
        "no data container carries identifier {bundle_id} (is the game installed?)"
    ))
}

fn sha256_hex(data: &[u8]) -> String {
    let digest = Sha256::digest(data);
    let mut out = String::with_capacity(64);
    for byte in digest {
        out.push_str(&format!("{byte:02x}"));
    }
    out
}

fn normalize_sha(value: &str) -> Option<String> {
    let trimmed = value.trim().to_ascii_lowercase();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed)
    }
}

async fn apply_file(
    cfg: &PairingConfig,
    bundle_id: &str,
    dest_rel: &str,
    payload: &[u8],
    expect_sha: Option<&str>,
    backup_path: Option<&str>,
) -> Result<String, String> {
    if let Some(expected) = expect_sha {
        let actual = sha256_hex(payload);
        if actual != expected {
            return Err(format!(
                "payload digest {actual} does not match manifest {expected}"
            ));
        }
    }

    let mut session = open_afc(cfg).await?;
    let container = find_container(&mut session.afc, bundle_id).await?;
    let remote_path = format!("{container}/{}", dest_rel.trim_start_matches('/'));

    let previous = read_remote(&mut session.afc, &remote_path).await.ok();
    if let (Some(path), Some(previous)) = (backup_path, previous.as_ref()) {
        std::fs::write(path, previous).map_err(|e| format!("local backup {path}: {e}"))?;
    }

    write_remote(&mut session.afc, &remote_path, payload).await?;

    let readback = read_remote(&mut session.afc, &remote_path).await?;
    if readback != payload {
        if let Some(previous) = previous {
            let _ = write_remote(&mut session.afc, &remote_path, &previous).await;
            return Err(format!(
                "readback of {remote_path} did not match; original restored"
            ));
        }
        return Err(format!("readback of {remote_path} did not match"));
    }

    Ok(remote_path)
}

async fn restore_file(
    cfg: &PairingConfig,
    bundle_id: &str,
    dest_rel: &str,
    payload: &[u8],
) -> Result<String, String> {
    let mut session = open_afc(cfg).await?;
    let container = find_container(&mut session.afc, bundle_id).await?;
    let remote_path = format!("{container}/{}", dest_rel.trim_start_matches('/'));
    write_remote(&mut session.afc, &remote_path, payload).await?;

    let readback = read_remote(&mut session.afc, &remote_path).await?;
    if readback != payload {
        return Err(format!("readback of {remote_path} did not match after restore"));
    }
    Ok(remote_path)
}

async fn probe(cfg: &PairingConfig, bundle_id: &str) -> Result<String, String> {
    let mut session = open_afc(cfg).await?;
    let container = find_container(&mut session.afc, bundle_id).await?;
    let info = session
        .afc
        .get_device_info()
        .await
        .map_err(|e| format!("AFC is up but device info failed: {e}"))?;
    Ok(format!(
        "container={container};afc=ok;free={};total={}",
        info.free_bytes, info.total_bytes
    ))
}

// ---------------------------------------------------------------- C ABI

unsafe fn cstr<'a>(value: *const c_char, field: &str) -> Result<&'a str, String> {
    if value.is_null() {
        return Err(format!("{field} is null"));
    }
    CStr::from_ptr(value)
        .to_str()
        .map_err(|_| format!("{field} is not valid UTF-8"))
}

unsafe fn write_out(dst: *mut c_char, cap: usize, text: &str) {
    if dst.is_null() || cap == 0 {
        return;
    }
    let bytes = text.as_bytes();
    let n = bytes.len().min(cap - 1);
    ptr::copy_nonoverlapping(bytes.as_ptr(), dst as *mut u8, n);
    *(dst as *mut u8).add(n) = 0;
}

/// Shared body: parse the common arguments, run `job`, report.
unsafe fn run_job<F>(pairing_path: *const c_char,
                     host: *const c_char,
                     port: u16,
                     pin: *const c_char,
                     out: *mut c_char,
                     out_cap: usize,
                     err: *mut c_char,
                     err_cap: usize,
                     job: F) -> c_int
where
    F: FnOnce(&PairingConfig) -> Result<String, String>,
{
    if !err.is_null() && err_cap > 0 {
        write_out(err, err_cap, "");
    }
    let parsed = (|| {
        let pairing_path = cstr(pairing_path, "pairing_path")?.to_string();
        let host = cstr(host, "host")?.to_string();
        let pin = cstr(pin, "pin").unwrap_or("000000").to_string();
        if port == 0 {
            return Err("port must not be zero".to_string());
        }
        if !std::path::Path::new(&pairing_path).exists() {
            return Err(format!("pairing record not found at {pairing_path}"));
        }
        Ok(PairingConfig {
            pairing_path,
            host,
            port,
            pin,
        })
    })();

    let cfg = match parsed {
        Ok(cfg) => cfg,
        Err(message) => {
            write_out(err, err_cap, &message);
            return -1;
        }
    };

    match job(&cfg) {
        Ok(result) => {
            write_out(out, out_cap, &result);
            0
        }
        Err(message) => {
            write_out(err, err_cap, &message);
            -1
        }
    }
}

fn blocking<F: std::future::Future<Output = Result<String, String>>>(fut: F) -> Result<String, String> {
    runtime().block_on(fut)
}

#[no_mangle]
pub unsafe extern "C" fn al_probe(
    pairing_path: *const c_char,
    host: *const c_char,
    port: u16,
    pin: *const c_char,
    out: *mut c_char,
    out_cap: usize,
    err: *mut c_char,
    err_cap: usize,
) -> c_int {
    catch_unwind(AssertUnwindSafe(|| {
        run_job(pairing_path, host, port, pin, out, out_cap, err, err_cap, |cfg| {
            blocking(probe(cfg, "com.dts.freefireth"))
        })
    }))
    .unwrap_or_else(|_| {
        write_out(err, err_cap, "airlift: panic inside probe");
        -2
    })
}

#[no_mangle]
pub unsafe extern "C" fn al_apply_file(
    pairing_path: *const c_char,
    host: *const c_char,
    port: u16,
    pin: *const c_char,
    bundle_id: *const c_char,
    dest_rel: *const c_char,
    src_path: *const c_char,
    expect_sha256_hex: *const c_char,
    backup_path: *const c_char,
    out: *mut c_char,
    out_cap: usize,
    err: *mut c_char,
    err_cap: usize,
) -> c_int {
    catch_unwind(AssertUnwindSafe(|| {
        run_job(pairing_path, host, port, pin, out, out_cap, err, err_cap, |cfg| {
            let bundle = cstr(bundle_id, "bundle_id")?;
            let dest = cstr(dest_rel, "dest_rel")?;
            let src = cstr(src_path, "src_path")?;
            let sha = if expect_sha256_hex.is_null() {
                None
            } else {
                normalize_sha(cstr(expect_sha256_hex, "expect_sha256_hex")?)
            };
            let backup = if backup_path.is_null() {
                None
            } else {
                Some(cstr(backup_path, "backup_path")?)
            };
            if dest.contains("..") || dest.starts_with('/') {
                return Err("destination must be a relative path inside the container".to_string());
            }
            let payload = std::fs::read(src).map_err(|e| format!("cannot read {src}: {e}"))?;
            if payload.is_empty() {
                return Err("patch payload is empty".to_string());
            }
            blocking(apply_file(cfg, bundle, dest, &payload, sha.as_deref(), backup))
        })
    }))
    .unwrap_or_else(|_| {
        write_out(err, err_cap, "airlift: panic inside apply");
        -2
    })
}

#[no_mangle]
pub unsafe extern "C" fn al_restore_file(
    pairing_path: *const c_char,
    host: *const c_char,
    port: u16,
    pin: *const c_char,
    bundle_id: *const c_char,
    dest_rel: *const c_char,
    backup_path: *const c_char,
    out: *mut c_char,
    out_cap: usize,
    err: *mut c_char,
    err_cap: usize,
) -> c_int {
    catch_unwind(AssertUnwindSafe(|| {
        run_job(pairing_path, host, port, pin, out, out_cap, err, err_cap, |cfg| {
            let bundle = cstr(bundle_id, "bundle_id")?;
            let dest = cstr(dest_rel, "dest_rel")?;
            let backup = cstr(backup_path, "backup_path")?;
            if dest.contains("..") || dest.starts_with('/') {
                return Err("destination must be a relative path inside the container".to_string());
            }
            let payload =
                std::fs::read(backup).map_err(|e| format!("cannot read backup {backup}: {e}"))?;
            blocking(restore_file(cfg, bundle, dest, &payload))
        })
    }))
    .unwrap_or_else(|_| {
        write_out(err, err_cap, "airlift: panic inside restore");
        -2
    })
}

#[no_mangle]
pub unsafe extern "C" fn al_pull_file(
    pairing_path: *const c_char,
    host: *const c_char,
    port: u16,
    pin: *const c_char,
    bundle_id: *const c_char,
    dest_rel: *const c_char,
    dst_path: *const c_char,
    out: *mut c_char,
    out_cap: usize,
    err: *mut c_char,
    err_cap: usize,
) -> c_int {
    catch_unwind(AssertUnwindSafe(|| {
        run_job(pairing_path, host, port, pin, out, out_cap, err, err_cap, |cfg| {
            let bundle = cstr(bundle_id, "bundle_id")?;
            let dest = cstr(dest_rel, "dest_rel")?;
            let dst = cstr(dst_path, "dst_path")?;
            blocking(async {
                let mut session = open_afc(cfg).await?;
                let container = find_container(&mut session.afc, bundle).await?;
                let remote = format!("{container}/{}", dest.trim_start_matches('/'));
                let bytes = read_remote(&mut session.afc, &remote).await?;
                std::fs::write(dst, &bytes).map_err(|e| format!("cannot write {dst}: {e}"))?;
                Ok::<String, String>(format!("{remote} -> {dst} ({} bytes, sha256 {})", bytes.len(), sha256_hex(&bytes)))
            })
        })
    }))
    .unwrap_or_else(|_| {
        write_out(err, err_cap, "airlift: panic inside pull");
        -2
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn digest_is_stable() {
        assert_eq!(
            sha256_hex(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn sha_ignore_blank() {
        assert!(normalize_sha("   ").is_none());
        assert_eq!(normalize_sha(" ABCdef ").as_deref(), Some("abcdef"));
    }
}
