/* Compile-only macOS ABI call-site check for metadata, reparse and DNS.
 *
 * This is never executed here: cross-compiling it for Apple ARM64 with the
 * pinned libSystem declarations proves the public signatures and types line up.
 */
#include <stdint.h>

#include "../../include/grail/grail.h"

int grail_macos_abi_call_sites(void);
int grail_macos_abi_call_sites(void) {
    grail_file_stat metadata;
    uint8_t buffer[256];
    grail_socket_address addresses[4];
    const uint8_t path[] = "file";
    const uint8_t link[] = "link";
    const uint8_t host[] = "localhost";
    grail_file file = GRAIL_HANDLE_NONE;

    if (grail_os_file_stat(file, &metadata) != GRAIL_OK) return 1;
    if (grail_os_fs_stat(path, 4, GRAIL_STAT_NO_FOLLOW, &metadata) != GRAIL_OK) return 2;
    if (grail_os_fs_readlink(link, 4, buffer, sizeof(buffer)) < 0) return 3;
    if (grail_os_fs_realpath(link, 4, buffer, sizeof(buffer)) < 0) return 4;
    if (grail_os_net_resolve(host, 9, GRAIL_ADDRESS_INET, addresses, 4) < 0) return 5;
    if (grail_os_net_resolve(host, 9, 0, NULL, 0) < 0) return 6;
    return (int)metadata.size;
}
