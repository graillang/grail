/*
 * Windows backend skeleton.
 *
 * This file is intentionally not a working backend: every entry point reports
 * GRAIL_E_UNSUPPORTED and grail_os_capabilities() stays 0, so no caller can
 * mistake it for an implementation.  It compiles on any host because it does
 * not include Windows headers; the intended Win32/Winsock calls are recorded in
 * runtime/abi/README.md.  A capability bit may be set only after every function
 * in that domain is implemented and tested on Windows.
 *
 * Known prerequisite outside this directory: Grail codegen must implement the
 * Win64 calling convention (rcx, rdx, r8, r9, 32-byte shadow space, callee-saved
 * rdi/rsi/r12-r15 are *not* Windows callee-saved) before these symbols can be
 * called from generated Grail code.
 */
#include "../../../include/grail/grail.h"

grail_status grail_os_init(const grail_allocator *allocator, const grail_startup *startup) {
    (void)allocator;
    (void)startup;
    return GRAIL_E_UNSUPPORTED;
}

grail_status grail_os_shutdown(void) {
    return GRAIL_E_NOT_INITIALIZED;
}

uint64_t grail_os_capabilities(void) {
    return 0;
}

grail_status grail_os_error_last(grail_os_error *out) {
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    out->domain = GRAIL_OS_DOMAIN_NONE;
    out->code = 0;
    return GRAIL_OK;
}

/* Representative stubs: one per domain. */
grail_status grail_os_file_open(const uint8_t *path, uint64_t path_length, uint64_t flags,
                                uint64_t mode, grail_file *out) {
    (void)path;
    (void)path_length;
    (void)flags;
    (void)mode;
    (void)out;
    return GRAIL_E_UNSUPPORTED; /* TODO: CreateFileW with UTF-16 and \\?\ handling. */
}

grail_result grail_os_env_get(const uint8_t *name, uint64_t name_length, uint8_t *out,
                              uint64_t capacity) {
    (void)name;
    (void)name_length;
    (void)out;
    (void)capacity;
    return GRAIL_E_UNSUPPORTED; /* TODO: GetEnvironmentVariableW over the runtime copy. */
}

grail_status grail_os_time_now(uint64_t clock, int64_t *nanoseconds) {
    (void)clock;
    (void)nanoseconds;
    return GRAIL_E_UNSUPPORTED; /* TODO: QueryPerformanceCounter / GetSystemTimePreciseAsFileTime. */
}

grail_status grail_os_thread_spawn(grail_thread_entry entry, void *user,
                                   const grail_thread_options *options, grail_thread *out) {
    (void)entry;
    (void)user;
    (void)options;
    (void)out;
    return GRAIL_E_UNSUPPORTED; /* TODO: CreateThread and an owning thread record. */
}

grail_status grail_os_dl_open(const uint8_t *name, uint64_t name_length, uint64_t flags,
                              grail_library *out) {
    (void)name;
    (void)name_length;
    (void)flags;
    (void)out;
    return GRAIL_E_UNSUPPORTED; /* TODO: LoadLibraryExW + GetProcAddress. */
}

grail_status grail_os_process_spawn(const grail_process_options *options, grail_process *out) {
    (void)options;
    (void)out;
    return GRAIL_E_UNSUPPORTED; /* TODO: CreateProcessW, MSVCRT quoting, PATHEXT. */
}

grail_status grail_os_socket_create(uint64_t family, uint64_t type, grail_socket *out) {
    (void)family;
    (void)type;
    (void)out;
    return GRAIL_E_UNSUPPORTED; /* TODO: WSAStartup + WSASocketW. */
}

grail_result grail_os_net_resolve(const uint8_t *host, uint64_t host_length, uint64_t family,
                                  grail_socket_address *addresses, uint64_t capacity) {
    (void)host;
    (void)host_length;
    (void)family;
    (void)addresses;
    (void)capacity;
    return GRAIL_E_UNSUPPORTED; /* TODO: getaddrinfoW. */
}
