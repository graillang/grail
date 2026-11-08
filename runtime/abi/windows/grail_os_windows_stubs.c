/*
 * Windows backend: explicit fail-closed stubs for the remaining domains.
 *
 * DNS, non-blocking files and symlink read/realpath are not implemented.  Every function returns
 * GRAIL_E_UNSUPPORTED and the corresponding capability bit is clear.
 */
#include "../../../include/grail/grail_fs.h"
#include "../../../include/grail/grail_socket.h"

grail_status grail_os_file_set_nonblocking(grail_file file, uint64_t enabled) {
    (void)file;
    (void)enabled;
    return GRAIL_E_UNSUPPORTED;
}

grail_result grail_os_fs_readlink(const uint8_t *path, uint64_t path_length, uint8_t *out,
                                  uint64_t capacity) {
    (void)path;
    (void)path_length;
    (void)out;
    (void)capacity;
    return GRAIL_E_UNSUPPORTED;
}

grail_result grail_os_fs_realpath(const uint8_t *path, uint64_t path_length, uint8_t *out,
                                  uint64_t capacity) {
    (void)path;
    (void)path_length;
    (void)out;
    (void)capacity;
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
