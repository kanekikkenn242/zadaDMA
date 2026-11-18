// airlift.h — pairing-record → RSD → AFC file replacement for iOS.
//
// Every entry point is self-contained: it opens the pairing tunnel, resolves the
// target app container, performs its work and tears the tunnel down. Call them
// off the main thread; each one blocks for the duration of a device round trip.
//
// Return value: 0 on success, negative on failure. On failure `err` receives a
// human-readable diagnostic (never empty), on success `out` receives the result.

#ifndef AIRLIFT_H
#define AIRLIFT_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Default loopback endpoint published by LocalDevVPN / the pairing daemon.
#define AIRLIFT_DEFAULT_HOST "127.0.0.1"
#define AIRLIFT_DEFAULT_PORT 49152

// Free Fire target bundles.
#define AIRLIFT_FF_BUNDLE       "com.dts.freefireth"
#define AIRLIFT_FFMAX_BUNDLE    "com.dts.freefiremax"

/// Opens the tunnel and reports what it can see.
/// `out`: "container=<path>;afc=ok" on success.
int32_t al_probe(const char *pairing_path,
                 const char *host,
                 uint16_t port,
                 const char *pin,
                 char *out, size_t out_cap,
                 char *err, size_t err_cap);

/// Replaces `dest_rel` inside the app container identified by `bundle_id`.
/// The current remote file is copied to `backup_path` first; if the write does
/// not verify against `expect_sha256_hex` the backup is written back before the
/// call returns.
/// `out`: resolved absolute remote path on success.
int32_t al_apply_file(const char *pairing_path,
                      const char *host,
                      uint16_t port,
                      const char *pin,
                      const char *bundle_id,
                      const char *dest_rel,
                      const char *src_path,
                      const char *expect_sha256_hex,
                      const char *backup_path,
                      char *out, size_t out_cap,
                      char *err, size_t err_cap);

/// Restores `dest_rel` from a local backup made by al_apply_file().
int32_t al_restore_file(const char *pairing_path,
                        const char *host,
                        uint16_t port,
                        const char *pin,
                        const char *bundle_id,
                        const char *dest_rel,
                        const char *backup_path,
                        char *out, size_t out_cap,
                        char *err, size_t err_cap);

/// Pulls `dest_rel` out of the app container into `dst_path`.
int32_t al_pull_file(const char *pairing_path,
                     const char *host,
                     uint16_t port,
                     const char *pin,
                     const char *bundle_id,
                     const char *dest_rel,
                     const char *dst_path,
                     char *out, size_t out_cap,
                     char *err, size_t err_cap);

#ifdef __cplusplus
}
#endif

#endif /* AIRLIFT_H */
