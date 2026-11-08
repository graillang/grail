/*
 * Linux reference backend: child processes.
 *
 * fork + execve + wait4 with an explicit argv/environment, explicit standard
 * streams and an exec-error pipe.  Only async-signal-safe calls run between
 * fork and exec, so the runtime's locks are not re-entered in the child.
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "grail_os_linux.h"

typedef struct grail_linux_process {
    pid_t pid;
    int reaped;
    int status;
} grail_linux_process;

typedef struct grail_env_build {
    char **names;
    char **values;
    uint64_t count;
    uint64_t capacity;
} grail_env_build;

static int grail_text_has_zero(const uint8_t *bytes, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static int grail_block_valid(const uint8_t *block, uint64_t length, const uint64_t *offsets,
                             uint64_t count) {
    if (count == 0) {
        return 1;
    }
    if (block == NULL || offsets == NULL || length == 0) {
        return 0;
    }
    for (uint64_t i = 0; i < count; i++) {
        const uint64_t begin = offsets[i];
        const uint64_t end = i + 1 < count ? offsets[i + 1] : length;
        if (begin >= end || end > length) {
            return 0;
        }
        if (block[end - 1] != 0 || grail_text_has_zero(block + begin, end - begin - 1)) {
            return 0;
        }
    }
    return 1;
}

static void grail_env_build_free(grail_env_build *environment) {
    for (uint64_t i = 0; i < environment->count; i++) {
        grail_linux_free_text(environment->names[i]);
        grail_linux_free_text(environment->values[i]);
    }
    if (environment->names != NULL) {
        grail_linux_release(environment->names, environment->capacity * sizeof(char *));
        grail_linux_release(environment->values, environment->capacity * sizeof(char *));
    }
    environment->names = NULL;
    environment->values = NULL;
    environment->count = 0;
    environment->capacity = 0;
}

static grail_status grail_env_build_reserve(grail_env_build *environment, uint64_t capacity) {
    if (capacity <= environment->capacity) {
        return GRAIL_OK;
    }
    uint64_t next = environment->capacity == 0 ? 8 : environment->capacity * 2;
    while (next < capacity) {
        next *= 2;
    }
    char **names = (char **)grail_linux_allocate(next * sizeof(char *));
    char **values = (char **)grail_linux_allocate(next * sizeof(char *));
    if (names == NULL || values == NULL) {
        grail_linux_release(names, next * sizeof(char *));
        grail_linux_release(values, next * sizeof(char *));
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < environment->count; i++) {
        names[i] = environment->names[i];
        values[i] = environment->values[i];
    }
    if (environment->names != NULL) {
        grail_linux_release(environment->names, environment->capacity * sizeof(char *));
        grail_linux_release(environment->values, environment->capacity * sizeof(char *));
    }
    environment->names = names;
    environment->values = values;
    environment->capacity = next;
    return GRAIL_OK;
}

static uint64_t grail_env_build_find(const grail_env_build *environment, const char *name) {
    for (uint64_t i = 0; i < environment->count; i++) {
        if (strcmp(environment->names[i], name) == 0) {
            return i;
        }
    }
    return environment->count;
}

static grail_status grail_env_build_put(grail_env_build *environment, const uint8_t *name,
                                        uint64_t name_length, const uint8_t *value,
                                        uint64_t value_length) {
    char *name_text = grail_linux_copy_text(name, name_length);
    char *value_text = grail_linux_copy_text(value, value_length);
    if (name_text == NULL || value_text == NULL) {
        grail_linux_free_text(name_text);
        grail_linux_free_text(value_text);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    uint64_t index = grail_env_build_find(environment, name_text);
    if (index == environment->count) {
        const grail_status reserved = grail_env_build_reserve(environment, environment->count + 1);
        if (reserved != GRAIL_OK) {
            grail_linux_free_text(name_text);
            grail_linux_free_text(value_text);
            return reserved;
        }
        environment->names[environment->count] = name_text;
        environment->values[environment->count] = value_text;
        environment->count++;
        return GRAIL_OK;
    }
    grail_linux_free_text(name_text);
    grail_linux_free_text(environment->values[index]);
    environment->values[index] = value_text;
    return GRAIL_OK;
}

static grail_status grail_overlay(const uint8_t *block, uint64_t length, const uint64_t *offsets,
                                  uint64_t count, grail_env_build *environment) {
    if (!grail_block_valid(block, length, offsets, count)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    for (uint64_t i = 0; i < count; i++) {
        const uint64_t begin = offsets[i];
        const uint64_t end = i + 1 < count ? offsets[i + 1] : length;
        const uint8_t *entry = block + begin;
        const uint64_t size = end - begin - 1;
        uint64_t separator = 0;
        while (separator < size && entry[separator] != '=') {
            separator++;
        }
        if (separator == 0 || separator == size) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        const grail_status status = grail_env_build_put(environment, entry, separator,
                                                        entry + separator + 1,
                                                        size - separator - 1);
        if (status != GRAIL_OK) {
            return status;
        }
    }
    return GRAIL_OK;
}

static grail_status grail_build_environment(const grail_process_options *options,
                                            grail_env_build *environment) {
    if ((options->flags & GRAIL_PROC_REPLACE_ENVIRONMENT) == 0) {
        grail_linux_lock();
        for (uint64_t i = 0; i < grail_linux.env_count; i++) {
            const grail_status status = grail_env_build_put(
                environment, (const uint8_t *)grail_linux.env_names[i],
                strlen(grail_linux.env_names[i]), (const uint8_t *)grail_linux.env_values[i],
                strlen(grail_linux.env_values[i]));
            if (status != GRAIL_OK) {
                grail_linux_unlock();
                return status;
            }
        }
        grail_linux_unlock();
    }
    return grail_overlay(options->environment, options->environment_length,
                         options->environment_offsets, options->environment_count, environment);
}

static const char *grail_env_value(const grail_env_build *environment, const char *name) {
    const uint64_t index = grail_env_build_find(environment, name);
    return index == environment->count ? NULL : environment->values[index];
}

static grail_status grail_resolve_program(const grail_process_options *options,
                                          const grail_env_build *environment, char **out) {
    char *program = grail_linux_copy_text(options->program, options->program_length);
    if (program == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    if ((options->flags & GRAIL_PROC_SEARCH_PATH) == 0 || strchr(program, '/') != NULL) {
        *out = program;
        return GRAIL_OK;
    }
    const char *path = grail_env_value(environment, "PATH");
    if (path == NULL) {
        path = "/usr/local/bin:/usr/bin:/bin";
    }
    int saw_file = 0;
    const char *cursor = path;
    for (;;) {
        const char *end = strchr(cursor, ':');
        const uint64_t directory_length = end == NULL ? strlen(cursor) : (uint64_t)(end - cursor);
        const uint64_t program_length = strlen(program);
        char *candidate = (char *)grail_linux_allocate(directory_length + program_length + 2);
        if (candidate == NULL) {
            grail_linux_free_text(program);
            return GRAIL_E_OUT_OF_MEMORY;
        }
        uint64_t at = 0;
        if (directory_length == 0) {
            candidate[at++] = '.';
        } else {
            memcpy(candidate, cursor, (size_t)directory_length);
            at = directory_length;
        }
        candidate[at++] = '/';
        memcpy(candidate + at, program, (size_t)program_length);
        candidate[at + program_length] = '\0';
        if (access(candidate, X_OK) == 0) {
            grail_linux_free_text(program);
            *out = candidate;
            return GRAIL_OK;
        }
        if (access(candidate, F_OK) == 0) {
            saw_file = 1;
        }
        grail_linux_free_text(candidate);
        if (end == NULL) {
            break;
        }
        cursor = end + 1;
    }
    grail_linux_free_text(program);
    return saw_file ? GRAIL_E_ACCESS_DENIED : GRAIL_E_NOT_FOUND;
}

static void grail_free_envp(char **environment, uint64_t count) {
    if (environment == NULL) {
        return;
    }
    for (uint64_t i = 0; i < count; i++) {
        grail_linux_free_text(environment[i]);
    }
    grail_linux_release(environment, (count + 1) * sizeof(char *));
}

static grail_status grail_build_envp(const grail_env_build *environment, char ***out,
                                     uint64_t *count_out) {
    char **values = (char **)grail_linux_allocate((environment->count + 1) * sizeof(char *));
    if (values == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < environment->count; i++) {
        const uint64_t name_length = strlen(environment->names[i]);
        const uint64_t value_length = strlen(environment->values[i]);
        char *entry = (char *)grail_linux_allocate(name_length + value_length + 2);
        if (entry == NULL) {
            for (uint64_t j = 0; j < i; j++) {
                grail_linux_free_text(values[j]);
            }
            grail_linux_release(values, (environment->count + 1) * sizeof(char *));
            return GRAIL_E_OUT_OF_MEMORY;
        }
        memcpy(entry, environment->names[i], (size_t)name_length);
        entry[name_length] = '=';
        memcpy(entry + name_length + 1, environment->values[i], (size_t)value_length);
        entry[name_length + value_length + 1] = '\0';
        values[i] = entry;
    }
    values[environment->count] = NULL;
    *out = values;
    *count_out = environment->count;
    return GRAIL_OK;
}

static grail_status grail_stdio_descriptor(grail_file handle, int inherited, int open_flags,
                                           int *descriptor, int *owned) {
    if (handle == GRAIL_HANDLE_NONE) {
        *descriptor = inherited;
        *owned = 0;
        return GRAIL_OK;
    }
    const grail_status status = grail_linux_file_descriptor(handle, descriptor);
    if (status != GRAIL_OK) {
        return status;
    }
    *owned = 0;
    (void)open_flags;
    return GRAIL_OK;
}

static grail_status grail_process_lookup(grail_process handle, grail_linux_process **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.processes, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

static void grail_fill_process_status(const grail_linux_process *process,
                                      grail_process_status *out) {
    memset(out, 0, sizeof(*out));
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    if (!process->reaped) {
        out->kind = GRAIL_PROCESS_STILL_ACTIVE;
        return;
    }
    if (WIFEXITED(process->status)) {
        out->kind = GRAIL_PROCESS_EXITED;
        out->exit_code = WEXITSTATUS(process->status);
    } else if (WIFSIGNALED(process->status)) {
        out->kind = GRAIL_PROCESS_SIGNALED;
        out->term_signal = WTERMSIG(process->status);
    } else {
        out->kind = GRAIL_PROCESS_STILL_ACTIVE;
    }
}

static grail_status grail_process_reap(grail_linux_process *process, int flags, int *reaped) {
    if (process->reaped) {
        *reaped = 1;
        return GRAIL_OK;
    }
    for (;;) {
        int status = 0;
        const pid_t result = wait4(process->pid, &status, flags, NULL);
        if (result == process->pid) {
            process->status = status;
            process->reaped = 1;
            *reaped = 1;
            return GRAIL_OK;
        }
        if (result == 0) {
            *reaped = 0;
            return GRAIL_OK;
        }
        if (errno == EINTR) {
            continue;
        }
        return grail_linux_errno(errno);
    }
}

static int grail_supported_flags(uint64_t flags) {
    const uint64_t supported = GRAIL_PROC_SEARCH_PATH | GRAIL_PROC_NEW_GROUP |
                               GRAIL_PROC_NO_WINDOW | GRAIL_PROC_INHERIT_STDIO |
                               GRAIL_PROC_REPLACE_ENVIRONMENT;
    return (flags & ~supported) == 0;
}

grail_status grail_os_process_spawn(const grail_process_options *options, grail_process *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (options == NULL || out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (options->struct_size < sizeof(*options) || options->abi_version != GRAIL_ABI_VERSION ||
        !grail_supported_flags(options->flags)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (options->program == NULL || options->program_length == 0 ||
        grail_text_has_zero(options->program, options->program_length) ||
        !grail_block_valid(options->arguments, options->arguments_length,
                           options->argument_offsets, options->argument_count) ||
        !grail_block_valid(options->environment, options->environment_length,
                           options->environment_offsets, options->environment_count)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((options->working_directory == NULL && options->working_directory_length != 0) ||
        (options->working_directory != NULL &&
         (options->working_directory_length == 0 ||
          grail_text_has_zero(options->working_directory, options->working_directory_length)))) {
        return GRAIL_E_INVALID_ARGUMENT;
    }

    grail_env_build environment;
    memset(&environment, 0, sizeof(environment));
    char *program = NULL;
    char *directory = NULL;
    char **argv = NULL;
    char **envp = NULL;
    uint64_t envp_count = 0;
    int stdin_fd = -1;
    int stdout_fd = -1;
    int stderr_fd = -1;
    int owned_stdin = 0;
    int owned_stdout = 0;
    int owned_stderr = 0;
    int error_pipe[2] = {-1, -1};
    grail_status status = grail_build_environment(options, &environment);
    if (status != GRAIL_OK) {
        goto cleanup;
    }
    status = grail_resolve_program(options, &environment, &program);
    if (status != GRAIL_OK) {
        goto cleanup;
    }
    if (options->working_directory != NULL) {
        directory = grail_linux_copy_text(options->working_directory,
                                          options->working_directory_length);
        if (directory == NULL) {
            status = GRAIL_E_OUT_OF_MEMORY;
            goto cleanup;
        }
    }
    if (options->argument_count == 0) {
        argv = (char **)grail_linux_allocate(2 * sizeof(char *));
        if (argv == NULL) {
            status = GRAIL_E_OUT_OF_MEMORY;
            goto cleanup;
        }
        argv[0] = grail_linux_copy_text(options->program, options->program_length);
        if (argv[0] == NULL) {
            status = GRAIL_E_OUT_OF_MEMORY;
            goto cleanup;
        }
        argv[1] = NULL;
    } else {
        argv = (char **)grail_linux_allocate((options->argument_count + 1) * sizeof(char *));
        if (argv == NULL) {
            status = GRAIL_E_OUT_OF_MEMORY;
            goto cleanup;
        }
        for (uint64_t i = 0; i < options->argument_count; i++) {
            argv[i] = (char *)(options->arguments + options->argument_offsets[i]);
        }
        argv[options->argument_count] = NULL;
    }
    status = grail_build_envp(&environment, &envp, &envp_count);
    if (status != GRAIL_OK) {
        goto cleanup;
    }
    status = grail_stdio_descriptor(options->standard_input, STDIN_FILENO, O_RDONLY, &stdin_fd,
                                    &owned_stdin);
    if (status != GRAIL_OK) {
        goto cleanup;
    }
    status = grail_stdio_descriptor(options->standard_output, STDOUT_FILENO, O_WRONLY, &stdout_fd,
                                    &owned_stdout);
    if (status != GRAIL_OK) {
        goto cleanup;
    }
    status = grail_stdio_descriptor(options->standard_error, STDERR_FILENO, O_WRONLY, &stderr_fd,
                                    &owned_stderr);
    if (status != GRAIL_OK) {
        goto cleanup;
    }
    if ((options->flags & GRAIL_PROC_INHERIT_STDIO) != 0) {
        if (options->standard_input == GRAIL_HANDLE_NONE) {
            stdin_fd = STDIN_FILENO;
        }
        if (options->standard_output == GRAIL_HANDLE_NONE) {
            stdout_fd = STDOUT_FILENO;
        }
        if (options->standard_error == GRAIL_HANDLE_NONE) {
            stderr_fd = STDERR_FILENO;
        }
    } else {
        if (options->standard_input == GRAIL_HANDLE_NONE) {
            stdin_fd = open("/dev/null", O_RDONLY | O_CLOEXEC);
            if (stdin_fd < 0) {
                status = grail_linux_errno(errno);
                goto cleanup;
            }
            owned_stdin = 1;
        }
        if (options->standard_output == GRAIL_HANDLE_NONE) {
            stdout_fd = open("/dev/null", O_WRONLY | O_CLOEXEC);
            if (stdout_fd < 0) {
                status = grail_linux_errno(errno);
                goto cleanup;
            }
            owned_stdout = 1;
        }
        if (options->standard_error == GRAIL_HANDLE_NONE) {
            stderr_fd = open("/dev/null", O_WRONLY | O_CLOEXEC);
            if (stderr_fd < 0) {
                status = grail_linux_errno(errno);
                goto cleanup;
            }
            owned_stderr = 1;
        }
    }
    if (pipe2(error_pipe, O_CLOEXEC) != 0) {
        status = grail_linux_errno(errno);
        goto cleanup;
    }
    const pid_t child = fork();
    if (child < 0) {
        status = grail_linux_errno(errno);
        goto cleanup;
    }
    if (child == 0) {
        close(error_pipe[0]);
        int child_error = 0;
        if ((options->flags & GRAIL_PROC_NEW_GROUP) != 0 && setpgid(0, 0) != 0) {
            child_error = errno;
        }
        if (child_error == 0 && directory != NULL && chdir(directory) != 0) {
            child_error = errno;
        }
        if (child_error == 0 && dup2(stdin_fd, STDIN_FILENO) < 0) {
            child_error = errno;
        }
        if (child_error == 0 && dup2(stdout_fd, STDOUT_FILENO) < 0) {
            child_error = errno;
        }
        if (child_error == 0 && dup2(stderr_fd, STDERR_FILENO) < 0) {
            child_error = errno;
        }
        if (stdin_fd > STDERR_FILENO) {
            close(stdin_fd);
        }
        if (stdout_fd > STDERR_FILENO) {
            close(stdout_fd);
        }
        if (stderr_fd > STDERR_FILENO) {
            close(stderr_fd);
        }
        if (child_error == 0) {
            execve(program, argv, envp);
            child_error = errno;
        }
        if (child_error != 0) {
            const ssize_t ignored = write(error_pipe[1], &child_error, sizeof(child_error));
            (void)ignored;
        }
        _exit(127);
    }

    close(error_pipe[1]);
    error_pipe[1] = -1;
    int child_error = 0;
    ssize_t read_length;
    do {
        read_length = read(error_pipe[0], &child_error, sizeof(child_error));
    } while (read_length < 0 && errno == EINTR);
    if (read_length == (ssize_t)sizeof(child_error)) {
        int child_status = 0;
        while (wait4(child, &child_status, 0, NULL) < 0 && errno == EINTR) {
        }
        status = grail_linux_errno(child_error);
        goto cleanup;
    }
    if (read_length < 0) {
        status = grail_linux_errno(errno);
        (void)kill(child, SIGKILL);
        int child_status = 0;
        while (wait4(child, &child_status, 0, NULL) < 0 && errno == EINTR) {
        }
        goto cleanup;
    }
    grail_linux_process *process =
        (grail_linux_process *)grail_linux_allocate(sizeof(*process));
    if (process == NULL) {
        (void)kill(child, SIGKILL);
        int child_status = 0;
        while (wait4(child, &child_status, 0, NULL) < 0 && errno == EINTR) {
        }
        status = GRAIL_E_OUT_OF_MEMORY;
        goto cleanup;
    }
    process->pid = child;
    process->reaped = 0;
    process->status = 0;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    status = grail_handle_table_allocate(&grail_linux.processes, process, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        (void)kill(child, SIGKILL);
        int child_status = 0;
        while (wait4(child, &child_status, 0, NULL) < 0 && errno == EINTR) {
        }
        grail_linux_release(process, sizeof(*process));
        goto cleanup;
    }
    *out = handle;
    status = GRAIL_OK;

cleanup:
    if (error_pipe[0] >= 0) {
        close(error_pipe[0]);
    }
    if (error_pipe[1] >= 0) {
        close(error_pipe[1]);
    }
    if (owned_stdin && stdin_fd >= 0) {
        close(stdin_fd);
    }
    if (owned_stdout && stdout_fd >= 0) {
        close(stdout_fd);
    }
    if (owned_stderr && stderr_fd >= 0) {
        close(stderr_fd);
    }
    if (argv != NULL) {
        if (options->argument_count == 0) {
            grail_linux_free_text(argv[0]);
            grail_linux_release(argv, 2 * sizeof(char *));
        } else {
            grail_linux_release(argv, (options->argument_count + 1) * sizeof(char *));
        }
    }
    grail_free_envp(envp, envp_count);
    grail_linux_free_text(program);
    grail_linux_free_text(directory);
    grail_env_build_free(&environment);
    return status;
}

grail_status grail_os_process_wait(grail_process handle, grail_process_status *out) {
    grail_linux_process *process = NULL;
    grail_status status = grail_process_lookup(handle, &process);
    if (status != GRAIL_OK) {
        return status;
    }
    int reaped = 0;
    status = grail_process_reap(process, 0, &reaped);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out != NULL) {
        grail_fill_process_status(process, out);
    }
    return GRAIL_OK;
}

grail_status grail_os_process_wait_timeout(grail_process handle, int64_t timeout_ns,
                                           grail_process_status *out) {
    grail_linux_process *process = NULL;
    grail_status status = grail_process_lookup(handle, &process);
    if (status != GRAIL_OK) {
        return status;
    }
    if (timeout_ns < 0) {
        return grail_os_process_wait(handle, out);
    }
    uint64_t remaining = (uint64_t)timeout_ns;
    for (;;) {
        int reaped = 0;
        status = grail_process_reap(process, WNOHANG, &reaped);
        if (status != GRAIL_OK) {
            return status;
        }
        if (reaped) {
            if (out != NULL) {
                grail_fill_process_status(process, out);
            }
            return GRAIL_OK;
        }
        if (remaining == 0) {
            if (out != NULL) {
                grail_fill_process_status(process, out);
                out->kind = GRAIL_PROCESS_STILL_ACTIVE;
            }
            return GRAIL_E_TIMED_OUT;
        }
        const uint64_t slice = remaining < 1000000 ? remaining : 1000000;
        struct timespec delay;
        delay.tv_sec = (time_t)(slice / 1000000000);
        delay.tv_nsec = (long)(slice % 1000000000);
        while (nanosleep(&delay, &delay) != 0 && errno == EINTR) {
        }
        remaining -= slice;
    }
}

static grail_status grail_process_signal(grail_process handle, int signal_number) {
    grail_linux_process *process = NULL;
    const grail_status status = grail_process_lookup(handle, &process);
    if (status != GRAIL_OK) {
        return status;
    }
    if (process->reaped) {
        return GRAIL_OK;
    }
    if (kill(process->pid, signal_number) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_process_terminate(grail_process process) {
    return grail_process_signal(process, SIGTERM);
}

grail_status grail_os_process_kill(grail_process process) {
    return grail_process_signal(process, SIGKILL);
}

grail_status grail_os_process_id(grail_process handle, uint64_t *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_linux_process *process = NULL;
    const grail_status status = grail_process_lookup(handle, &process);
    if (status != GRAIL_OK) {
        return status;
    }
    *out = (uint64_t)process->pid;
    return GRAIL_OK;
}

grail_status grail_os_process_close(grail_process handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_process *process = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_release(&grail_linux.processes, handle, (void **)&process);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_linux_release(process, sizeof(*process));
    return GRAIL_OK;
}
