/*
 * Linux reference backend: socket skeleton.
 *
 * Deliberately unimplemented: GRAIL_CAP_SOCKETS stays clear and every entry
 * point reports GRAIL_E_UNSUPPORTED.  The shipping implementation belongs in
 * runtime.grl behind the readiness reactor; this file only keeps the reference
 * backend link-complete.
 */
#include "grail_os_linux.h"

grail_status grail_os_socket_create(uint64_t family, uint64_t type, grail_socket *out) {
    (void)family;
    (void)type;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_bind(grail_socket socket, const grail_socket_address *address) {
    (void)socket;
    (void)address;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_listen(grail_socket socket, uint64_t backlog) {
    (void)socket;
    (void)backlog;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_accept(grail_socket socket, grail_socket *out,
                                    grail_socket_address *peer) {
    (void)socket;
    (void)out;
    (void)peer;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_connect(grail_socket socket, const grail_socket_address *address) {
    (void)socket;
    (void)address;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_send(grail_socket socket, const uint8_t *buffer, uint64_t length,
                                  uint64_t *sent) {
    (void)socket;
    (void)buffer;
    (void)length;
    (void)sent;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_recv(grail_socket socket, uint8_t *buffer, uint64_t capacity,
                                  uint64_t *received) {
    (void)socket;
    (void)buffer;
    (void)capacity;
    (void)received;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_send_to(grail_socket socket, const uint8_t *buffer, uint64_t length,
                                     const grail_socket_address *address, uint64_t *sent) {
    (void)socket;
    (void)buffer;
    (void)length;
    (void)address;
    (void)sent;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_recv_from(grail_socket socket, uint8_t *buffer, uint64_t capacity,
                                       grail_socket_address *address, uint64_t *received) {
    (void)socket;
    (void)buffer;
    (void)capacity;
    (void)address;
    (void)received;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_shutdown(grail_socket socket, uint64_t how) {
    (void)socket;
    (void)how;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_close(grail_socket socket) {
    (void)socket;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_local_address(grail_socket socket, grail_socket_address *out) {
    (void)socket;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_peer_address(grail_socket socket, grail_socket_address *out) {
    (void)socket;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_set_nonblocking(grail_socket socket, uint64_t enabled) {
    (void)socket;
    (void)enabled;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_set_option(grail_socket socket, uint64_t option, uint64_t value) {
    (void)socket;
    (void)option;
    (void)value;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_socket_get_option(grail_socket socket, uint64_t option, uint64_t *value) {
    (void)socket;
    (void)option;
    (void)value;
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
