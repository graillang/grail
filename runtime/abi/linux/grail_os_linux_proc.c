/*
 * Linux reference backend: child-process skeleton.
 *
 * Deliberately unimplemented: GRAIL_CAP_PROCESSES stays clear and every entry
 * point reports GRAIL_E_UNSUPPORTED.  The shipping implementation belongs in
 * runtime.grl (fork/clone + execve + wait4); the hosted reference must not
 * become a second process runtime.
 */
#include "grail_os_linux.h"

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
