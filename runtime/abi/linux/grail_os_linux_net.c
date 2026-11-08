/*
 * Linux reference backend: TCP/UDP sockets, address conversion and DNS.
 *
 * The public ABI is blocking/non-blocking sockets without a reactor interface;
 * readiness registration belongs to the shipping runtime.  Every address is
 * converted at the boundary, so no sockaddr or descriptor escapes.
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdint.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include "grail_os_linux.h"

typedef struct grail_linux_socket {
    int descriptor;
    uint64_t family;
    uint64_t type;
} grail_linux_socket;

static int grail_socket_text_has_zero(const uint8_t *bytes, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static int grail_socket_family(uint64_t family, int *out) {
    if (family == GRAIL_ADDRESS_INET) {
        *out = AF_INET;
        return 1;
    }
    if (family == GRAIL_ADDRESS_INET6) {
        *out = AF_INET6;
        return 1;
    }
    return 0;
}

static int grail_socket_type(uint64_t type, int *out) {
    if (type == GRAIL_SOCKET_STREAM) {
        *out = SOCK_STREAM;
        return 1;
    }
    if (type == GRAIL_SOCKET_DATAGRAM) {
        *out = SOCK_DGRAM;
        return 1;
    }
    return 0;
}

static int grail_address_valid(const grail_socket_address *address) {
    if (address == NULL || address->struct_size < sizeof(*address) ||
        address->abi_version != GRAIL_ABI_VERSION) {
        return 0;
    }
    if (address->family != GRAIL_ADDRESS_INET && address->family != GRAIL_ADDRESS_INET6) {
        return 0;
    }
    return address->port <= 65535 && address->scope_id <= 0xFFFFFFFFull;
}

static int grail_fill_sockaddr(const grail_socket_address *address,
                               struct sockaddr_storage *storage, socklen_t *length) {
    memset(storage, 0, sizeof(*storage));
    if (address->family == GRAIL_ADDRESS_INET) {
        struct sockaddr_in *value = (struct sockaddr_in *)storage;
        value->sin_family = AF_INET;
        value->sin_port = htons((uint16_t)address->port);
        memcpy(&value->sin_addr, address->address, 4);
        *length = sizeof(*value);
        return 1;
    }
    if (address->family == GRAIL_ADDRESS_INET6) {
        struct sockaddr_in6 *value = (struct sockaddr_in6 *)storage;
        value->sin6_family = AF_INET6;
        value->sin6_port = htons((uint16_t)address->port);
        memcpy(&value->sin6_addr, address->address, 16);
        value->sin6_scope_id = (uint32_t)address->scope_id;
        *length = sizeof(*value);
        return 1;
    }
    return 0;
}

static grail_status grail_from_sockaddr(const struct sockaddr *source, socklen_t length,
                                        grail_socket_address *out) {
    if (source == NULL || out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    memset(out, 0, sizeof(*out));
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    if (source->sa_family == AF_INET && length >= (socklen_t)sizeof(struct sockaddr_in)) {
        const struct sockaddr_in *value = (const struct sockaddr_in *)source;
        out->family = GRAIL_ADDRESS_INET;
        out->port = ntohs(value->sin_port);
        memcpy(out->address, &value->sin_addr, 4);
        return GRAIL_OK;
    }
    if (source->sa_family == AF_INET6 && length >= (socklen_t)sizeof(struct sockaddr_in6)) {
        const struct sockaddr_in6 *value = (const struct sockaddr_in6 *)source;
        out->family = GRAIL_ADDRESS_INET6;
        out->port = ntohs(value->sin6_port);
        memcpy(out->address, &value->sin6_addr, 16);
        out->scope_id = value->sin6_scope_id;
        return GRAIL_OK;
    }
    return GRAIL_E_ADDRESS_INVALID;
}

static grail_status grail_socket_lookup(grail_socket handle, grail_linux_socket **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.sockets, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

static grail_status grail_socket_wrap(int descriptor, uint64_t family, uint64_t type,
                                      grail_socket *out) {
    grail_linux_socket *socket_object =
        (grail_linux_socket *)grail_linux_allocate(sizeof(*socket_object));
    if (socket_object == NULL) {
        close(descriptor);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    socket_object->descriptor = descriptor;
    socket_object->family = family;
    socket_object->type = type;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.sockets, socket_object, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        close(descriptor);
        grail_linux_release(socket_object, sizeof(*socket_object));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_socket_create(uint64_t family, uint64_t type, grail_socket *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    int address_family;
    int socket_type;
    if (!grail_socket_family(family, &address_family) || !grail_socket_type(type, &socket_type)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const int descriptor = socket(address_family, socket_type | SOCK_CLOEXEC, 0);
    if (descriptor < 0) {
        return grail_linux_errno(errno);
    }
    return grail_socket_wrap(descriptor, family, type, out);
}

grail_status grail_os_socket_bind(grail_socket handle, const grail_socket_address *address) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (!grail_address_valid(address)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct sockaddr_storage storage;
    socklen_t length = 0;
    if (!grail_fill_sockaddr(address, &storage, &length)) {
        return GRAIL_E_ADDRESS_INVALID;
    }
    if (bind(socket_object->descriptor, (const struct sockaddr *)&storage, length) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_socket_listen(grail_socket handle, uint64_t backlog) {
    grail_linux_socket *socket_object = NULL;
    const grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    int depth = backlog == 0 ? SOMAXCONN : (int)(backlog > (uint64_t)INT_MAX ? INT_MAX : backlog);
    if (listen(socket_object->descriptor, depth) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_socket_accept(grail_socket handle, grail_socket *out,
                                    grail_socket_address *peer) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct sockaddr_storage storage;
    socklen_t length = sizeof(storage);
    const int descriptor =
        accept4(socket_object->descriptor, (struct sockaddr *)&storage, &length, SOCK_CLOEXEC);
    if (descriptor < 0) {
        return grail_linux_errno(errno);
    }
    if (peer != NULL) {
        status = grail_from_sockaddr((const struct sockaddr *)&storage, length, peer);
        if (status != GRAIL_OK) {
            close(descriptor);
            return status;
        }
    }
    return grail_socket_wrap(descriptor, socket_object->family, socket_object->type, out);
}

grail_status grail_os_socket_connect(grail_socket handle, const grail_socket_address *address) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (!grail_address_valid(address)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct sockaddr_storage storage;
    socklen_t length = 0;
    if (!grail_fill_sockaddr(address, &storage, &length)) {
        return GRAIL_E_ADDRESS_INVALID;
    }
    if (connect(socket_object->descriptor, (const struct sockaddr *)&storage, length) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_socket_send(grail_socket handle, const uint8_t *buffer, uint64_t length,
                                  uint64_t *sent) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (sent == NULL || (buffer == NULL && length != 0) || length > (uint64_t)SSIZE_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (length == 0) {
        *sent = 0;
        return GRAIL_OK;
    }
    const ssize_t result =
        send(socket_object->descriptor, buffer, (size_t)length, MSG_NOSIGNAL);
    if (result < 0) {
        return grail_linux_errno(errno);
    }
    *sent = (uint64_t)result;
    return GRAIL_OK;
}

grail_status grail_os_socket_recv(grail_socket handle, uint8_t *buffer, uint64_t capacity,
                                  uint64_t *received) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (received == NULL || (buffer == NULL && capacity != 0) ||
        capacity > (uint64_t)SSIZE_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (capacity == 0) {
        *received = 0;
        return GRAIL_OK;
    }
    const ssize_t result = recv(socket_object->descriptor, buffer, (size_t)capacity, 0);
    if (result < 0) {
        return grail_linux_errno(errno);
    }
    *received = (uint64_t)result;
    return GRAIL_OK;
}

grail_status grail_os_socket_send_to(grail_socket handle, const uint8_t *buffer, uint64_t length,
                                     const grail_socket_address *address, uint64_t *sent) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (sent == NULL || (buffer == NULL && length != 0) || length > (uint64_t)SSIZE_MAX ||
        !grail_address_valid(address)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct sockaddr_storage storage;
    socklen_t address_length = 0;
    if (!grail_fill_sockaddr(address, &storage, &address_length)) {
        return GRAIL_E_ADDRESS_INVALID;
    }
    const ssize_t result = sendto(socket_object->descriptor, buffer, (size_t)length,
                                  MSG_NOSIGNAL, (const struct sockaddr *)&storage,
                                  address_length);
    if (result < 0) {
        return grail_linux_errno(errno);
    }
    *sent = (uint64_t)result;
    return GRAIL_OK;
}

grail_status grail_os_socket_recv_from(grail_socket handle, uint8_t *buffer, uint64_t capacity,
                                       grail_socket_address *address, uint64_t *received) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (received == NULL || address == NULL || (buffer == NULL && capacity != 0) ||
        capacity > (uint64_t)SSIZE_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct sockaddr_storage storage;
    socklen_t address_length = sizeof(storage);
    const ssize_t result = recvfrom(socket_object->descriptor, buffer, (size_t)capacity, 0,
                                    (struct sockaddr *)&storage, &address_length);
    if (result < 0) {
        return grail_linux_errno(errno);
    }
    status = grail_from_sockaddr((const struct sockaddr *)&storage, address_length, address);
    if (status != GRAIL_OK) {
        return status;
    }
    *received = (uint64_t)result;
    return GRAIL_OK;
}

grail_status grail_os_socket_shutdown(grail_socket handle, uint64_t how) {
    grail_linux_socket *socket_object = NULL;
    const grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    int direction;
    switch (how) {
    case GRAIL_SHUTDOWN_READ:
        direction = SHUT_RD;
        break;
    case GRAIL_SHUTDOWN_WRITE:
        direction = SHUT_WR;
        break;
    case GRAIL_SHUTDOWN_BOTH:
        direction = SHUT_RDWR;
        break;
    default:
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (shutdown(socket_object->descriptor, direction) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_socket_close(grail_socket handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_socket *socket_object = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_release(&grail_linux.sockets, handle, (void **)&socket_object);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int result = close(socket_object->descriptor);
    const int error_number = errno;
    grail_linux_release(socket_object, sizeof(*socket_object));
    return result == 0 ? GRAIL_OK : grail_linux_errno(error_number);
}

static grail_status grail_socket_name(grail_socket handle, int peer, grail_socket_address *out) {
    grail_linux_socket *socket_object = NULL;
    const grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct sockaddr_storage storage;
    socklen_t length = sizeof(storage);
    const int result = peer ? getpeername(socket_object->descriptor,
                                          (struct sockaddr *)&storage, &length)
                            : getsockname(socket_object->descriptor,
                                          (struct sockaddr *)&storage, &length);
    if (result != 0) {
        return grail_linux_errno(errno);
    }
    return grail_from_sockaddr((const struct sockaddr *)&storage, length, out);
}

grail_status grail_os_socket_local_address(grail_socket handle, grail_socket_address *out) {
    return grail_socket_name(handle, 0, out);
}

grail_status grail_os_socket_peer_address(grail_socket handle, grail_socket_address *out) {
    return grail_socket_name(handle, 1, out);
}

grail_status grail_os_socket_set_nonblocking(grail_socket handle, uint64_t enabled) {
    grail_linux_socket *socket_object = NULL;
    const grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    int flags = fcntl(socket_object->descriptor, F_GETFL, 0);
    if (flags < 0) {
        return grail_linux_errno(errno);
    }
    if (enabled != 0) {
        flags |= O_NONBLOCK;
    } else {
        flags &= ~O_NONBLOCK;
    }
    if (fcntl(socket_object->descriptor, F_SETFL, flags) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

static int grail_option_int(uint64_t value, int *out) {
    if (value > (uint64_t)INT_MAX) {
        return 0;
    }
    *out = (int)value;
    return 1;
}

static void grail_timeout_value(uint64_t milliseconds, struct timeval *out) {
    out->tv_sec = (time_t)(milliseconds / 1000);
    out->tv_usec = (suseconds_t)((milliseconds % 1000) * 1000);
}

grail_status grail_os_socket_set_option(grail_socket handle, uint64_t option, uint64_t value) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    int level = SOL_SOCKET;
    int name = 0;
    int number = 0;
    struct timeval timeout;
    struct linger linger;
    const void *data = &number;
    socklen_t length = sizeof(number);
    switch (option) {
    case GRAIL_SOCKOPT_REUSE_ADDRESS:
        name = SO_REUSEADDR;
        if (!grail_option_int(value, &number)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        break;
    case GRAIL_SOCKOPT_REUSE_PORT:
#ifdef SO_REUSEPORT
        name = SO_REUSEPORT;
#else
        return GRAIL_E_UNSUPPORTED;
#endif
        if (!grail_option_int(value, &number)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        break;
    case GRAIL_SOCKOPT_NO_DELAY:
        level = IPPROTO_TCP;
        name = TCP_NODELAY;
        if (!grail_option_int(value, &number)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        break;
    case GRAIL_SOCKOPT_KEEPALIVE:
        name = SO_KEEPALIVE;
        if (!grail_option_int(value, &number)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        break;
    case GRAIL_SOCKOPT_BROADCAST:
        name = SO_BROADCAST;
        if (!grail_option_int(value, &number)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        break;
    case GRAIL_SOCKOPT_RECEIVE_TIMEOUT_MS:
        name = SO_RCVTIMEO;
        grail_timeout_value(value, &timeout);
        data = &timeout;
        length = sizeof(timeout);
        break;
    case GRAIL_SOCKOPT_SEND_TIMEOUT_MS:
        name = SO_SNDTIMEO;
        grail_timeout_value(value, &timeout);
        data = &timeout;
        length = sizeof(timeout);
        break;
    case GRAIL_SOCKOPT_LINGER_MS:
        name = SO_LINGER;
        linger.l_onoff = value == 0 ? 0 : 1;
        linger.l_linger = value == 0 ? 0 : (int)((value + 999) / 1000);
        data = &linger;
        length = sizeof(linger);
        break;
    default:
        return GRAIL_E_UNSUPPORTED;
    }
    if (setsockopt(socket_object->descriptor, level, name, data, length) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_socket_get_option(grail_socket handle, uint64_t option, uint64_t *value) {
    grail_linux_socket *socket_object = NULL;
    grail_status status = grail_socket_lookup(handle, &socket_object);
    if (status != GRAIL_OK) {
        return status;
    }
    if (value == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    int level = SOL_SOCKET;
    int name = 0;
    int number = 0;
    struct timeval timeout;
    struct linger linger;
    void *data = &number;
    socklen_t length = sizeof(number);
    switch (option) {
    case GRAIL_SOCKOPT_REUSE_ADDRESS:
        name = SO_REUSEADDR;
        break;
    case GRAIL_SOCKOPT_REUSE_PORT:
#ifdef SO_REUSEPORT
        name = SO_REUSEPORT;
#else
        return GRAIL_E_UNSUPPORTED;
#endif
        break;
    case GRAIL_SOCKOPT_NO_DELAY:
        level = IPPROTO_TCP;
        name = TCP_NODELAY;
        break;
    case GRAIL_SOCKOPT_KEEPALIVE:
        name = SO_KEEPALIVE;
        break;
    case GRAIL_SOCKOPT_BROADCAST:
        name = SO_BROADCAST;
        break;
    case GRAIL_SOCKOPT_RECEIVE_TIMEOUT_MS:
        name = SO_RCVTIMEO;
        data = &timeout;
        length = sizeof(timeout);
        break;
    case GRAIL_SOCKOPT_SEND_TIMEOUT_MS:
        name = SO_SNDTIMEO;
        data = &timeout;
        length = sizeof(timeout);
        break;
    case GRAIL_SOCKOPT_LINGER_MS:
        name = SO_LINGER;
        data = &linger;
        length = sizeof(linger);
        break;
    default:
        return GRAIL_E_UNSUPPORTED;
    }
    if (getsockopt(socket_object->descriptor, level, name, data, &length) != 0) {
        return grail_linux_errno(errno);
    }
    if (option == GRAIL_SOCKOPT_RECEIVE_TIMEOUT_MS || option == GRAIL_SOCKOPT_SEND_TIMEOUT_MS) {
        *value = (uint64_t)timeout.tv_sec * 1000 + (uint64_t)timeout.tv_usec / 1000;
    } else if (option == GRAIL_SOCKOPT_LINGER_MS) {
        *value = linger.l_onoff == 0 ? 0 : (uint64_t)linger.l_linger * 1000;
    } else {
        *value = (uint64_t)number;
    }
    return GRAIL_OK;
}

grail_result grail_os_net_resolve(const uint8_t *host, uint64_t host_length, uint64_t family,
                                  grail_socket_address *addresses, uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (host == NULL || host_length == 0 || grail_socket_text_has_zero(host, host_length) ||
        (addresses == NULL && capacity != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_linux_copy_text(host, host_length);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    if (family == 0) {
        hints.ai_family = AF_UNSPEC;
    } else if (family == GRAIL_ADDRESS_INET) {
        hints.ai_family = AF_INET;
    } else if (family == GRAIL_ADDRESS_INET6) {
        hints.ai_family = AF_INET6;
    } else {
        grail_linux_free_text(text);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct addrinfo *results = NULL;
    const int result = getaddrinfo(text, NULL, &hints, &results);
    grail_linux_free_text(text);
    if (result != 0) {
        switch (result) {
        case EAI_NONAME:
#ifdef EAI_NODATA
        case EAI_NODATA:
#endif
            return GRAIL_E_NOT_FOUND;
        case EAI_MEMORY:
            return GRAIL_E_OUT_OF_MEMORY;
        case EAI_FAMILY:
            return GRAIL_E_ADDRESS_INVALID;
        case EAI_SYSTEM:
            return grail_linux_errno(errno);
        default:
            grail_linux_set_error(GRAIL_OS_DOMAIN_NONE, (uint64_t)(uint32_t)result);
            return GRAIL_E_SYSTEM;
        }
    }
    uint64_t count = 0;
    for (const struct addrinfo *item = results; item != NULL; item = item->ai_next) {
        if (item->ai_family == AF_INET || item->ai_family == AF_INET6) {
            count++;
        }
    }
    if (count > capacity) {
        freeaddrinfo(results);
        return (grail_result)count;
    }
    uint64_t at = 0;
    for (const struct addrinfo *item = results; item != NULL && at < count;
         item = item->ai_next) {
        if (item->ai_family == AF_INET) {
            const struct sockaddr_in *value = (const struct sockaddr_in *)item->ai_addr;
            memset(&addresses[at], 0, sizeof(addresses[at]));
            addresses[at].struct_size = sizeof(addresses[at]);
            addresses[at].abi_version = GRAIL_ABI_VERSION;
            addresses[at].family = GRAIL_ADDRESS_INET;
            addresses[at].port = 0;
            memcpy(addresses[at].address, &value->sin_addr, 4);
            at++;
        } else if (item->ai_family == AF_INET6) {
            const struct sockaddr_in6 *value = (const struct sockaddr_in6 *)item->ai_addr;
            memset(&addresses[at], 0, sizeof(addresses[at]));
            addresses[at].struct_size = sizeof(addresses[at]);
            addresses[at].abi_version = GRAIL_ABI_VERSION;
            addresses[at].family = GRAIL_ADDRESS_INET6;
            addresses[at].port = 0;
            addresses[at].scope_id = value->sin6_scope_id;
            memcpy(addresses[at].address, &value->sin6_addr, 16);
            at++;
        }
    }
    freeaddrinfo(results);
    return (grail_result)at;
}
