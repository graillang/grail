/*
 * TCP and UDP sockets over IPv4 and IPv6.
 *
 * Addresses are pointer-free POD records.  `family` is GRAIL_ADDRESS_INET or
 * GRAIL_ADDRESS_INET6; `address` holds the 4- or 16-byte network-order address
 * and `port` is host order.  IPv6 scope IDs are accepted; IPv4-mapped addresses
 * remain ordinary IPv6 addresses.  Unix-domain sockets are not part of this
 * version (a separate address type is required).
 *
 * Calls are blocking unless the socket is non-blocking.  Readiness
 * multiplexing (epoll/kqueue/IOCP) is deliberately *not* in this ABI: the
 * runtime's reactor owns registration and uses non-blocking sockets.  Name
 * resolution blocks and must be offloaded by a green-task runtime.
 */
#ifndef GRAIL_SOCKET_H
#define GRAIL_SOCKET_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef grail_handle grail_socket;

#define GRAIL_ADDRESS_INET 1u
#define GRAIL_ADDRESS_INET6 2u
#define GRAIL_SOCKET_STREAM 1u
#define GRAIL_SOCKET_DATAGRAM 2u

#define GRAIL_SHUTDOWN_READ 1u
#define GRAIL_SHUTDOWN_WRITE 2u
#define GRAIL_SHUTDOWN_BOTH 3u

#define GRAIL_SOCKOPT_REUSE_ADDRESS 1u
#define GRAIL_SOCKOPT_REUSE_PORT 2u
#define GRAIL_SOCKOPT_NO_DELAY 3u
#define GRAIL_SOCKOPT_KEEPALIVE 4u
#define GRAIL_SOCKOPT_RECEIVE_TIMEOUT_MS 5u
#define GRAIL_SOCKOPT_SEND_TIMEOUT_MS 6u
#define GRAIL_SOCKOPT_BROADCAST 7u
#define GRAIL_SOCKOPT_LINGER_MS 8u

typedef struct grail_socket_address {
    uint64_t struct_size; /* sizeof(grail_socket_address) */
    uint64_t abi_version;
    uint64_t family;      /* GRAIL_ADDRESS_* */
    uint64_t port;        /* host order */
    uint64_t scope_id;    /* IPv6 only */
    uint8_t address[16];  /* network order; first 4 bytes for IPv4 */
} grail_socket_address;

GRAIL_API grail_status GRAIL_CALL grail_os_socket_create(uint64_t family, uint64_t type,
                                                          grail_socket *out);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_bind(grail_socket socket,
                                                       const grail_socket_address *address);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_listen(grail_socket socket, uint64_t backlog);
/* `peer` may be NULL.  The accepted socket is a new owned handle. */
GRAIL_API grail_status GRAIL_CALL grail_os_socket_accept(grail_socket socket, grail_socket *out,
                                                         grail_socket_address *peer);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_connect(grail_socket socket,
                                                          const grail_socket_address *address);
/* May send fewer bytes than requested; 0 is a valid result. */
GRAIL_API grail_status GRAIL_CALL grail_os_socket_send(grail_socket socket, const uint8_t *buffer,
                                                       uint64_t length, uint64_t *sent);
/* 0 bytes means the peer closed the stream, not an error. */
GRAIL_API grail_status GRAIL_CALL grail_os_socket_recv(grail_socket socket, uint8_t *buffer,
                                                       uint64_t capacity, uint64_t *received);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_send_to(grail_socket socket,
                                                          const uint8_t *buffer, uint64_t length,
                                                          const grail_socket_address *address,
                                                          uint64_t *sent);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_recv_from(grail_socket socket, uint8_t *buffer,
                                                            uint64_t capacity,
                                                            grail_socket_address *address,
                                                            uint64_t *received);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_shutdown(grail_socket socket, uint64_t how);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_close(grail_socket socket);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_local_address(
    grail_socket socket, grail_socket_address *out);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_peer_address(
    grail_socket socket, grail_socket_address *out);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_set_nonblocking(grail_socket socket,
                                                                  uint64_t enabled);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_set_option(grail_socket socket, uint64_t option,
                                                             uint64_t value);
GRAIL_API grail_status GRAIL_CALL grail_os_socket_get_option(grail_socket socket, uint64_t option,
                                                             uint64_t *value);

/*
 * Resolves `host` for `family` (0 accepts both) and writes up to `capacity`
 * addresses with port 0.  Returns the number written; a result greater than
 * `capacity` is the required capacity and nothing was written.  Blocking.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_net_resolve(const uint8_t *host, uint64_t host_length,
                                                       uint64_t family,
                                                       grail_socket_address *addresses,
                                                       uint64_t capacity);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_SOCKET_H */
