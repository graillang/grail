/*
 * macOS first-layer backend: explicit fail-closed stubs.
 *
 * Every function in a domain that is not implemented returns
 * GRAIL_E_UNSUPPORTED.  The corresponding capability bit is clear in
 * grail_os_macos.c, so callers can discover this before calling.
 */
#include "../../../include/grail/grail_dl.h"
#include "../../../include/grail/grail_fs.h"
#include "../../../include/grail/grail_proc.h"
#include "../../../include/grail/grail_socket.h"
#include "../../../include/grail/grail_thread.h"
#include "../../../include/grail/grail_time.h"

grail_status grail_os_time_local_offset(int64_t utc_nanoseconds, int64_t *offset_nanoseconds) {
    (void)utc_nanoseconds;
    (void)offset_nanoseconds;
    return GRAIL_E_UNSUPPORTED;
}

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

grail_status grail_os_dir_open(const uint8_t *path, uint64_t path_length, grail_dir *out) {
    (void)path;
    (void)path_length;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_result grail_os_dir_next(grail_dir dir, uint8_t *name, uint64_t capacity,
                               grail_dir_entry *out) {
    (void)dir;
    (void)name;
    (void)capacity;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_dir_close(grail_dir dir) {
    (void)dir;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_process_spawn(const grail_process_options *options, grail_process *out) {
    (void)options;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_process_wait(grail_process process, grail_process_status *out) {
    (void)process;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_process_wait_timeout(grail_process process, int64_t timeout_ns,
                                           grail_process_status *out) {
    (void)process;
    (void)timeout_ns;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_process_terminate(grail_process process) {
    (void)process;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_process_kill(grail_process process) {
    (void)process;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_process_id(grail_process process, uint64_t *out) {
    (void)process;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_process_close(grail_process process) {
    (void)process;
    return GRAIL_E_UNSUPPORTED;
}

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

grail_status grail_os_thread_spawn(grail_thread_entry entry, void *user,
                                   const grail_thread_options *options, grail_thread *out) {
    (void)entry;
    (void)user;
    (void)options;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_thread_join(grail_thread thread, uint64_t *exit_code) {
    (void)thread;
    (void)exit_code;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_thread_detach(grail_thread thread) {
    (void)thread;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_thread_id(uint64_t *out) {
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_thread_yield(void) {
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_mutex_create(grail_mutex *out) {
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_mutex_lock(grail_mutex mutex) {
    (void)mutex;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_mutex_try_lock(grail_mutex mutex, uint64_t *acquired) {
    (void)mutex;
    (void)acquired;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_mutex_unlock(grail_mutex mutex) {
    (void)mutex;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_mutex_destroy(grail_mutex mutex) {
    (void)mutex;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_condvar_create(grail_condvar *out) {
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_condvar_wait(grail_condvar condvar, grail_mutex mutex, int64_t timeout_ns,
                                   uint64_t *signaled) {
    (void)condvar;
    (void)mutex;
    (void)timeout_ns;
    (void)signaled;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_condvar_signal(grail_condvar condvar) {
    (void)condvar;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_condvar_broadcast(grail_condvar condvar) {
    (void)condvar;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_condvar_destroy(grail_condvar condvar) {
    (void)condvar;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_dl_open(const uint8_t *name, uint64_t name_length, uint64_t flags,
                              grail_library *out) {
    (void)name;
    (void)name_length;
    (void)flags;
    (void)out;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_dl_symbol(grail_library library, const uint8_t *name, uint64_t name_length,
                                void **symbol) {
    (void)library;
    (void)name;
    (void)name_length;
    (void)symbol;
    return GRAIL_E_UNSUPPORTED;
}
grail_status grail_os_dl_close(grail_library library) {
    (void)library;
    return GRAIL_E_UNSUPPORTED;
}
grail_result grail_os_dl_error(uint8_t *out, uint64_t capacity) {
    (void)out;
    (void)capacity;
    return GRAIL_E_UNSUPPORTED;
}
