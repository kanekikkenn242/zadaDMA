#!/usr/bin/env python3
"""Pack one file into a .3105 patch package.

Layout (little endian), mirrored by PatchPackageCodec.swift:

    "3105"  u16 schema=2  u16 aadVersion=1  u16 flags  u32 iterations
    u32 idLen         + id (utf8)
    u32 saltLen       + salt
    u32 manifestLen   + manifest (utf8 JSON)
    u32 payloadLen    + payload
    32 bytes          sha256 of the payload

flags bit0 marks a password-protected payload: the payload is then
nonce(12) || AES-256-GCM(ciphertext||tag) under PBKDF2-SHA256(password, salt,
iterations). This packer writes the plaintext variant, which is what bundled
patches use; the app still accepts protected packages.

Usage:
    python scripts/pack3105.py --src assetindexer.tdn --id aim_neck_70 \
        --name "AIM NECK 70%" --dst "Documents/assetindexer.tdn" \
        --bundle com.dts.freefireth --out Payload/zadaDMA.app/aimneck_70.3105
"""

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

MAGIC = b"3105"
SCHEMA = 2
AAD_VERSION = 1
FLAGS_PLAIN = 0


def pack(package_id: str, name: str, bundle: str, dst: str, payload: bytes) -> bytes:
    digest = hashlib.sha256(payload).digest()
    manifest = json.dumps(
        {
            "id": package_id,
            "name": name,
            "bundle": bundle,
            "files": [{"dst": dst, "sha256": digest.hex()}],
        },
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")

    ident = package_id.encode("utf-8")
    salt = b""

    out = bytearray()
    out += MAGIC
    out += struct.pack("<HHHI", SCHEMA, AAD_VERSION, FLAGS_PLAIN, 0)
    out += struct.pack("<I", len(ident)) + ident
    out += struct.pack("<I", len(salt)) + salt
    out += struct.pack("<I", len(manifest)) + manifest
    out += struct.pack("<I", len(payload)) + payload
    out += digest
    return bytes(out)


def verify(blob: bytes, expect_payload: bytes) -> None:
    assert blob[:4] == MAGIC, "bad magic"
    schema, aad, flags, _ = struct.unpack_from("<HHHI", blob, 4)
    assert (schema, aad, flags) == (SCHEMA, AAD_VERSION, FLAGS_PLAIN), "header mismatch"

    offset = 14  # magic(4) + schema/aad/flags/iterations(10)
    (id_len,) = struct.unpack_from("<I", blob, offset)
    offset += 4 + id_len
    (salt_len,) = struct.unpack_from("<I", blob, offset)
    offset += 4 + salt_len
    (man_len,) = struct.unpack_from("<I", blob, offset)
    offset += 4 + man_len
    (pay_len,) = struct.unpack_from("<I", blob, offset)
    offset += 4
    payload = blob[offset:offset + pay_len]
    digest = blob[offset + pay_len:offset + pay_len + 32]

    assert payload == expect_payload, "payload round-trip mismatch"
    assert digest == hashlib.sha256(payload).digest(), "payload digest mismatch"
    assert len(blob) == offset + pay_len + 32, "trailing bytes in package"


def main() -> int:
    parser = argparse.ArgumentParser(description="Pack a file into a .3105 package")
    parser.add_argument("--src", required=True, help="file to embed")
    parser.add_argument("--id", required=True, help="package identifier")
    parser.add_argument("--name", required=True, help="display name")
    parser.add_argument("--dst", required=True, help="destination path inside the app container")
    parser.add_argument("--bundle", default="com.dts.freefireth", help="target bundle identifier")
    parser.add_argument("--out", required=True, help="output .3105 path")
    args = parser.parse_args()

    payload = Path(args.src).read_bytes()
    if not payload:
        print("payload is empty", file=sys.stderr)
        return 1
    if args.dst.startswith("/") or ".." in args.dst:
        print("destination must be a relative path inside the container", file=sys.stderr)
        return 1

    blob = pack(args.id, args.name, args.bundle, args.dst, payload)
    verify(blob, payload)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(blob)

    print(f"wrote {out} ({len(blob)} bytes, payload {len(payload)} bytes, sha256 {hashlib.sha256(payload).hexdigest()})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
