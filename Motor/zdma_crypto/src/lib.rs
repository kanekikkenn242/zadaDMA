#![allow(clippy::missing_safety_doc)]
use aes_gcm::{aead::{Aead, KeyInit}, Aes256Gcm, Key, Nonce};
use pbkdf2::pbkdf2_hmac;
use sha2::{Digest, Sha256};
use std::slice;
use std::os::raw::{c_char, c_void};

extern "C" {
    // idevice_ffi FFI functions - these are provided by libidevice_ffi
    pub fn idevice_new(device: *mut *mut c_void) -> i32;
    pub fn idevice_free(device: *mut c_void);
    pub fn idevice_get_usbmuxd_socket() -> *mut c_void;
    pub fn idevice_start_pairing_host(pairing_file: *const c_char, pin: *const c_char) -> i32;
    pub fn idevice_afc_connect_with_pairing_file(pairing_file: *const c_char, host: *const c_char, port: u16) -> i32;
    pub fn idevice_afc_write(client: *mut c_void, remote_path: *const c_char, local_data: *const c_char) -> i32;
    pub fn idevice_afc_close(client: *mut c_void) -> i32;
}

// Core crypto functions

#[no_mangle]
pub unsafe extern "C" fn zdma_sha256(inp: *const u8, inp_len: usize, out: *mut u8) -> i32 {
    if out.is_null() || (inp.is_null() && inp_len > 0) { return -1; }
    let d = Sha256::digest(slice::from_raw_parts(inp, inp_len));
    slice::from_raw_parts_mut(out, 32).copy_from_slice(&d); 0
}

#[no_mangle]
pub unsafe extern "C" fn zdma_pbkdf2_sha256(pass: *const u8, pass_len: usize, salt: *const u8, salt_len: usize, iter: u32, out: *mut u8, out_len: usize) -> i32 {
    if out.is_null() || out_len == 0 { return -1; }
    if (pass.is_null() && pass_len > 0) || (salt.is_null() && salt_len > 0) { return -1; }
    pbkdf2_hmac::<Sha256>(slice::from_raw_parts(pass, pass_len), slice::from_raw_parts(salt, salt_len), iter, slice::from_raw_parts_mut(out, out_len)); 0
}

#[no_mangle]
pub unsafe extern "C" fn zdma_aes256gcm_encrypt(key: *const u8, key_len: usize, nonce: *const u8, nonce_len: usize, pt: *const u8, pt_len: usize, ct: *mut u8, tag: *mut u8) -> i32 {
    if key_len != 32 || nonce_len != 12 || ct.is_null() || tag.is_null() { return -1; }
    if pt.is_null() && pt_len > 0 { return -1; }
    let c = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(slice::from_raw_parts(key, 32)));
    let n = Nonce::from_slice(slice::from_raw_parts(nonce, 12));
    match c.encrypt(n, slice::from_raw_parts(pt, pt_len)) {
        Ok(mut v) => { if v.len() != pt_len + 16 { return -2; }
            let t = v.split_off(pt_len);
            slice::from_raw_parts_mut(ct, pt_len).copy_from_slice(&v);
            slice::from_raw_parts_mut(tag, 16).copy_from_slice(&t); 0 }
        Err(_) => -3,
    }
}

#[no_mangle]
pub unsafe extern "C" fn zdma_aes256gcm_decrypt(key: *const u8, key_len: usize, nonce: *const u8, nonce_len: usize, ct: *const u8, ct_len: usize, tag: *const u8, tag_len: usize, pt: *mut u8) -> i32 {
    if key_len != 32 || nonce_len != 12 || tag_len != 16 || pt.is_null() || tag.is_null() { return -1; }
    if ct.is_null() && ct_len > 0 { return -1; }
    let c = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(slice::from_raw_parts(key, 32)));
    let n = Nonce::from_slice(slice::from_raw_parts(nonce, 12));
    let mut v = Vec::with_capacity(ct_len + 16);
    v.extend_from_slice(slice::from_raw_parts(ct, ct_len));
    v.extend_from_slice(slice::from_raw_parts(tag, 16));
    match c.decrypt(n, v.as_slice()) {
        Ok(p) => { if p.len() != ct_len { return -2; }
            slice::from_raw_parts_mut(pt, ct_len).copy_from_slice(&p); 0 }
        Err(_) => -3,
    }
}

#[no_mangle]
pub unsafe extern "C" fn zdma_random(out: *mut u8, len: usize) -> i32 {
    if out.is_null() { return -1; }
    extern "C" { fn getentropy(buf: *mut u8, len: usize) -> i32; }
    getentropy(out, len)
}

// NEW: Generate 6-digit PIN for iOS Developer Mode pairing
#[no_mangle]
pub unsafe extern "C" fn zdma_generate_pin(out: *mut u8, out_len: usize) -> i32 {
    if out.is_null() { return -1; }
    // Generate random PIN 000000-999999 (exactly 6 digits)
    // out_len should be at least 6; we write exactly 6 bytes
    extern "C" { fn getentropy(buf: *mut u8, len: usize) -> i32; }
    let mut rng_buf = [0u8; 4];
    if getentropy(rng_buf.as_mut_ptr(), 4) != 0 { return -1; }
    let pin_value = u32::from_le_bytes(rng_buf) % 1000000;
    let pin_str = format!("{:06}", pin_value);
    // Write exactly 6 bytes to the output buffer
    let pin_bytes = pin_str.as_bytes();
    if out_len >= 6 {
        for i in 0..6 { out[i] = pin_bytes[i]; }
    } else {
        // Buffer too small, write what we can
        let write_len = std::cmp::min(out_len, pin_bytes.len());
        for i in 0..write_len { out[i] = pin_bytes[i]; }
    }
    0
}

// NEW: Start pairing host session (idevice_ffi integration)
#[no_mangle]
pub unsafe extern "C" fn zdma_start_pairing_host(pairing_file: *const c_char, pin: *const c_char) -> i32 {
    // Call the idevice_ffi function to start host pairing
    // This will prompt the iOS device for PIN verification
    idevice_start_pairing_host(pairing_file, pin)
}

// NEW: Connect AFC with pairing file (creates LocalDevVPN tunnel)
#[no_mangle]
pub unsafe extern "C" fn zdma_afc_connect_with_pairing_file(pairing_file: *const c_char, host: *const c_char, port: u16) -> i32 {
    idevice_afc_connect_with_pairing_file(pairing_file, host, port)
}

// NEW: Write file via AFC (for .3105 aim configs, etc.)
#[no_mangle]
pub unsafe extern "C" fn zdma_afc_write(client: *mut c_void, remote_path: *const c_char, local_data: *const c_char) -> i32 {
    idevice_afc_write(client, remote_path, local_data)
}

// NEW: Close AFC client
#[no_mangle]
pub unsafe extern "C" fn zdma_afc_close(client: *mut c_void) -> i32 {
    idevice_afc_close(client)
}