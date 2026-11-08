/*
 * Child processes.
 *
 * The ABI spawns directly from an argument vector; there is no shell and no
 * command string.  Arguments and environment use the same NUL-terminated,
 * offset-addressed UTF-8 blocks as grail_startup.  Standard streams are
 * explicit grail_file handles; the backend duplicates them for the child, so
 * the caller may close them after spawn returns.
 *
 * The runtime must convert the environment copy to the child's form.  On
 * Windows the backend quotes the argument vector with the MSVCRT rules and
 * applies PATHEXT when GRAIL_PROC_SEARCH_PATH is set; on POSIX it execs the
 * vector unchanged and uses execvp semantics for path search.  A backend that
 * cannot provide one of those behaviours must clear GRAIL_CAP_PROCESSES.
 */
#ifndef GRAIL_PROC_H
#define GRAIL_PROC_H

#include "grail_abi.h"
#include "grail_error.h"
#include "grail_fs.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef grail_handle grail_process;

#define GRAIL_PROC_SEARCH_PATH (1ull << 0)
#define GRAIL_PROC_NEW_GROUP (1ull << 1)
#define GRAIL_PROC_NO_WINDOW (1ull << 2)
#define GRAIL_PROC_INHERIT_STDIO (1ull << 3)
#define GRAIL_PROC_REPLACE_ENVIRONMENT (1ull << 4)

typedef struct grail_process_options {
    uint64_t struct_size; /* sizeof(grail_process_options) */
    uint64_t abi_version;
    uint64_t flags;       /* GRAIL_PROC_* */
    const uint8_t *program;
    uint64_t program_length;
    const uint8_t *arguments;
    uint64_t arguments_length;
    const uint64_t *argument_offsets;
    uint64_t argument_count;
    const uint8_t *environment;
    uint64_t environment_length;
    const uint64_t *environment_offsets;
    uint64_t environment_count;
    const uint8_t *working_directory;
    uint64_t working_directory_length;
    grail_file standard_input;
    grail_file standard_output;
    grail_file standard_error;
} grail_process_options;

#define GRAIL_PROCESS_EXITED 0u
#define GRAIL_PROCESS_SIGNALED 1u
#define GRAIL_PROCESS_STILL_ACTIVE 2u

typedef struct grail_process_status {
    uint64_t struct_size; /* sizeof(grail_process_status) */
    uint64_t abi_version;
    uint64_t kind;        /* GRAIL_PROCESS_* */
    int64_t exit_code;    /* valid for EXITED */
    int64_t term_signal;  /* valid for SIGNALED; 0 on Windows */
} grail_process_status;

/*
 * Starts a child.  `options` must be complete; argument_count == 0 inserts
 * `program` as argv[0].  A standard-stream handle of GRAIL_HANDLE_NONE means
 * inherit when GRAIL_PROC_INHERIT_STDIO is set, otherwise the platform null
 * device.  Without GRAIL_PROC_REPLACE_ENVIRONMENT the supplied entries overlay
 * the runtime copy; with it they are the entire environment.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_process_spawn(const grail_process_options *options,
                                                          grail_process *out);

/* Blocks until the child exits.  Repeats return the cached status. */
GRAIL_API grail_status GRAIL_CALL grail_os_process_wait(grail_process process,
                                                        grail_process_status *out);
/* Returns GRAIL_E_TIMED_OUT with kind = STILL_ACTIVE when the timeout expires. */
GRAIL_API grail_status GRAIL_CALL grail_os_process_wait_timeout(grail_process process,
                                                                int64_t timeout_ns,
                                                                grail_process_status *out);
/* Requests orderly termination (SIGTERM / Ctrl-Break where supported). */
GRAIL_API grail_status GRAIL_CALL grail_os_process_terminate(grail_process process);
/* Forces termination (SIGKILL / TerminateProcess). */
GRAIL_API grail_status GRAIL_CALL grail_os_process_kill(grail_process process);
GRAIL_API grail_status GRAIL_CALL grail_os_process_id(grail_process process, uint64_t *out);
/*
 * Consumes the handle.  It does not wait for or kill the child; a still-running
 * child becomes unreachable and continues on both POSIX and Windows.  The
 * runtime must arrange ownership explicitly.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_process_close(grail_process process);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_PROC_H */
