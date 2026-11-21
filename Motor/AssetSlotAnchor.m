#import "AssetSlotAnchor.h"

#include <string.h>
#include <zlib.h>

// A float slot is three big-endian-looking little-endian float32 values
// followed by a u32 length and a `bone_<Name>` string. The length prefix sits
// 12 bytes after the first float (3 * 4 bytes).
static const NSUInteger kSlotFloatBytes = 12;
static const NSUInteger kMarkerPrefixBytes = 4;

static BOOL IsGzip(NSData *data) {
    const uint8_t *b = data.bytes;
    return data.length >= 2 && b[0] == 0x1f && b[1] == 0x8b;
}

static NSData *_Nullable InflateGzip(NSData *data) {
    if (!IsGzip(data)) return nil;

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit2(&stream, 15 + 16) != Z_OK) return nil;

    NSUInteger chunk = 64 * 1024;
    NSMutableData *out = [NSMutableData dataWithLength:chunk];
    stream.next_in = (Bytef *)data.bytes;
    stream.avail_in = (uInt)data.length;
    int status = Z_OK;
    while (status == Z_OK) {
        if (stream.avail_out == 0) {
            [out increaseLengthBy:chunk];
            stream.next_out = (Bytef *)(out.mutableBytes + out.length - chunk);
            stream.avail_out = (uInt)chunk;
        }
        status = inflate(&stream, Z_NO_FLUSH);
        if (status == Z_STREAM_END) break;
        if (status != Z_OK && status != Z_BUF_ERROR) {
            inflateEnd(&stream);
            return nil;
        }
        if (status == Z_BUF_ERROR && stream.avail_in == 0) {
            inflateEnd(&stream);
            return nil;
        }
    }
    inflateEnd(&stream);
    if (status != Z_STREAM_END) return nil;

    out.length = stream.total_out;
    return out;
}

static NSData *_Nullable DeflateGzip(NSData *data) {
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8,
                     Z_DEFAULT_STRATEGY) != Z_OK) return nil;

    NSUInteger bound = compressBound((uLong)data.length) + 64;
    NSMutableData *out = [NSMutableData dataWithLength:bound];
    stream.next_in = (Bytef *)data.bytes;
    stream.avail_in = (uInt)data.length;
    stream.next_out = (Bytef *)out.mutableBytes;
    stream.avail_out = (uInt)out.length;
    if (deflate(&stream, Z_FINISH) != Z_STREAM_END) {
        deflateEnd(&stream);
        return nil;
    }
    deflateEnd(&stream);
    out.length = stream.total_out;
    return out;
}

/// Every `bone_*` marker in the asset, keyed by its exact on-disk bytes
/// (4-byte little-endian length + name). Value is the 12 float bytes that
/// immediately precede it.
static NSDictionary<NSData *, NSData *> *SlotMap(NSData *asset) {
    const uint8_t *b = asset.bytes;
    NSUInteger n = asset.length;
    NSMutableDictionary<NSData *, NSData *> *map = [NSMutableDictionary dictionary];

    for (NSUInteger i = kSlotFloatBytes; i + 5 + kMarkerPrefixBytes <= n; i++) {
        if (memcmp(b + i, "bone_", 5) != 0) continue;
        NSUInteger j = i + 5;
        while (j < n) {
            uint8_t c = b[j];
            BOOL letter = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
            if (!letter) break;
            j++;
        }
        if (j == i + 5) continue;
        uint32_t declared = 0;
        memcpy(&declared, b + i - kMarkerPrefixBytes, 4);
        if ((NSUInteger)declared != j - i) continue;

        NSData *marker = [NSData dataWithBytes:b + i - kMarkerPrefixBytes
                                        length:(j - i) + kMarkerPrefixBytes];
        NSData *floats = [NSData dataWithBytes:b + i - kMarkerPrefixBytes - kSlotFloatBytes
                                        length:kSlotFloatBytes];
        map[marker] = floats;
    }
    return map;
}

@implementation AssetSlotAnchor

+ (nullable NSData *)patchedAssetFromPackage:(NSData *)packageAsset
                                      device:(NSData *)deviceAsset {
    if (!packageAsset.length || !deviceAsset.length) return nil;

    BOOL deviceWasGzip = IsGzip(deviceAsset);
    NSData *packagePlain = InflateGzip(packageAsset) ?: packageAsset;
    NSData *devicePlain = InflateGzip(deviceAsset) ?: deviceAsset;
    if ([packagePlain length] < kSlotFloatBytes + kMarkerPrefixBytes + 5 ||
        [devicePlain length] < kSlotFloatBytes + kMarkerPrefixBytes + 5) {
        return nil;
    }

    NSDictionary<NSData *, NSData *> *slots = SlotMap(packagePlain);
    if (!slots.count) return nil;

    NSMutableData *patched = [devicePlain mutableCopy];
    NSUInteger dn = devicePlain.length;
    NSUInteger replaced = 0;

    // Search the device build by marker bytes. Bone names are unique in the
    // hitbox table, so a direct substring match is unambiguous and does not
    // depend on where the build inserted or removed unrelated bytes.
    for (NSData *marker in slots) {
        NSRange hit = [devicePlain rangeOfData:marker
                                       options:0
                                         range:NSMakeRange(0, dn)];
        while (hit.location != NSNotFound) {
            if (hit.location < kSlotFloatBytes) break;
            NSUInteger floatsAt = hit.location - kSlotFloatBytes;
            if (floatsAt <= dn - kSlotFloatBytes) {
                [patched replaceBytesInRange:NSMakeRange(floatsAt, kSlotFloatBytes)
                                    withBytes:slots[marker].bytes
                                       length:kSlotFloatBytes];
                replaced++;
            }
            NSUInteger next = NSMaxRange(hit);
            if (next + marker.length > dn) break;
            hit = [devicePlain rangeOfData:marker
                                   options:0
                                     range:NSMakeRange(next, dn - next)];
        }
    }
    if (!replaced) return nil;

    if (deviceWasGzip) {
        NSData *gz = DeflateGzip(patched);
        return gz.length ? gz : nil;
    }
    return patched;
}

@end
