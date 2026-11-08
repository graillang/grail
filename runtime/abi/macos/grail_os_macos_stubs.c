/*
 * macOS backend: explicit fail-closed stubs for the remaining domains.
 *
 * File metadata and DNS are not implemented.
 * Every function returns GRAIL_E_UNSUPPORTED and the corresponding capability
 * bit is clear.
 */
#include "../../../include/grail/grail_fs.h"
#include "../../../include/grail/grail_socket.h"

grail_status grail_os_file_stat(grail_file file, grail_file_stat *out) {
    (void)file;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_fs_stat(const uint8_t *path, uint64_t path_length, uint64_t flags,
                              grail_file_stat *out) {
    (void)path;
    (void)path_length;
    (void)flags;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_result grail_os_net_resolve(const uint8_t *host, uint64_t host_length, uint64_t family,
                                  grail_socket_address *addresses, uint64_t capacity) {
    (void)host;
    (void)host_length;
    (void)family;
    (void)addresses;
    (void)capacity;
    return GRAIL_E_UNSUPPORTED;
}
