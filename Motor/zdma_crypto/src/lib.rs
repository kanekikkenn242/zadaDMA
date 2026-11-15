#![allow(clippy::missing_safety_doc)]
use aes_gcm::{aead::{Aead, KeyInit}, Aes256Gcm, Key, Nonce};
use pbkdf2::pbkdf2_hmac;
use sha2::{Digest, Sha256};
use std::slice;

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

extern "C" { fn getentropy(buf: *mut u8, len: usize) -> i32; }
#[no_mangle]
pub unsafe extern "C" fn zdma_random(out: *mut u8, len: usize) -> i32 {
    if out.is_null() { return -1; } getentropy(out, len)
}
