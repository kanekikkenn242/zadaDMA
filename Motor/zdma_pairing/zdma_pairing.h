#ifndef ZDMA_PAIRING_H
#define ZDMA_PAIRING_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Ready callback for the pairable host.
 *
 * Called once the TCP listener is bound, before a device connects. The
 * identifier/authTag/flags/ver/minVer values are the exact mDNS TXT
 * records that must be advertised for _remotepairing-pairable-host._tcp.
 */
typedef void (*zdma_ready_cb)(
    const char *identifier,
    const char *name,
    const char *model,
    const char *auth_tag,
    const char *flags,
    const char *ver,
    const char *min_ver,
    uint16_t port,
    void *ctx);

/* Called with the 6-digit PIN the user has to type on the iPhone. */
typedef void (*zdma_pin_cb)(const char *pin, void *ctx);

/*
 * Blocks while advertising/accepting a device-initiated pairing.
 *
 * Returns 0 on success, 1 on error, 2 when cancelled. On success the
 * RPPairing file is written to pairing_file_path.
 */
int zdma_pairing_host_accept(
    const char *name,
    const char *model,
    uint16_t port,
    zdma_ready_cb ready,
    zdma_pin_cb pin_cb,
    void *ctx,
    const char *pairing_file_path,
    char *errbuf,
    size_t errbuf_len);

/* Aborts a running zdma_pairing_host_accept. */
void zdma_pairing_host_cancel(void);

/*
 * Creates the RPPairing tunnel, connects to House Arrest and writes one
 * local file into the target app container.
 *
 * Returns 0 on success. On failure a readable message is placed in errbuf.
 * On success a short description is placed in outbuf.
 */
int zdma_tunnel_write_file(
    const char *host,
    uint16_t port,
    const char *hostname,
    const char *pairing_file_path,
    const char *bundle_id,
    const char *remote_path,
    const char *local_path,
    char *errbuf,
    size_t errbuf_len,
    char *outbuf,
    size_t outbuf_len);

/*
 * Returns 1 when auth_tag matches the pairing file's device altIRK,
 * 0 when it does not, -1 when the pairing file cannot be read.
 */
int zdma_pairing_file_validate(
    const char *pairing_file_path,
    const char *service_identifier,
    const char *auth_tag);

#ifdef __cplusplus
}
#endif

#endif
