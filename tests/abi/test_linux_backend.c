/* End-to-end behaviour of the Linux reference backend. */
#include <errno.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../../include/grail/grail.h"
#include "../../runtime/abi/linux/grail_os_linux.h"

static int failures;
static int checks;
static uint64_t live_bytes;

#define CHECK(condition)                                                       \
    do {                                                                       \
        checks++;                                                              \
        if (!(condition)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__,   \
                    #condition);                                               \
            failures++;                                                        \
        }                                                                      \
    } while (0)

static void *test_allocate(void *context, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)alignment;
    uint8_t *base = (uint8_t *)malloc((size_t)size + 16);
    if (base == NULL) {
        return NULL;
    }
    *(uint64_t *)base = size + 16;
    live_bytes += size + 16;
    return base + 16;
}

static void test_release(void *context, void *pointer, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)size;
    (void)alignment;
    if (pointer == NULL) {
        return;
    }
    uint8_t *base = (uint8_t *)pointer - 16;
    live_bytes -= *(uint64_t *)base;
    free(base);
}

static grail_allocator test_allocator = // NOLINT
    {sizeof(grail_allocator), NULL, test_allocate, NULL, test_release};

static void expect_string(grail_result result, const uint8_t *data, uint64_t length,
                          const char *expected) {
    CHECK(result == (grail_result)strlen(expected));
    CHECK(length == strlen(expected));
    CHECK(memcmp(data, expected, strlen(expected)) == 0);
}

static grail_result get_env(const char *name, uint8_t *out, uint64_t capacity) {
    return grail_os_env_get((const uint8_t *)name, strlen(name), out, capacity);
}

static atomic_int detached_finished;

static uint64_t detached_entry(void *user) {
    (void)user;
    atomic_store(&detached_finished, 1);
    return 0;
}

static uint64_t thread_entry(void *user) {
    (void)user;
    return 42;
}

static void test_environment(void) {
    uint8_t buffer[64];
    grail_result length = get_env("ABI_TEST_ONE", buffer, sizeof(buffer));
    expect_string(length, buffer, (uint64_t)length, "1");
    CHECK(get_env("ABI_TEST_TWO", buffer, sizeof(buffer)) == 0);
    CHECK(get_env("ABI_TEST_THREE", buffer, sizeof(buffer)) == 5);
    CHECK(memcmp(buffer, "three", 5) == 0);
    CHECK(get_env("ABI_TEST_MISSING", buffer, sizeof(buffer)) == GRAIL_E_NOT_FOUND);
    CHECK(get_env("ABI_TEST_ONE", NULL, 0) == 1);
    CHECK(grail_os_env_get((const uint8_t *)"BAD=NAME", 8, buffer, sizeof(buffer)) ==
          GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_os_env_set((const uint8_t *)"ABI_TEST_NEW", 12,
                           (const uint8_t *)"value", 5) == GRAIL_OK);
    CHECK(get_env("ABI_TEST_NEW", buffer, sizeof(buffer)) == 5);
    CHECK(memcmp(buffer, "value", 5) == 0);
    CHECK(grail_os_env_unset((const uint8_t *)"ABI_TEST_NEW", 12) == GRAIL_OK);
    CHECK(get_env("ABI_TEST_NEW", buffer, sizeof(buffer)) == GRAIL_E_NOT_FOUND);
    CHECK(grail_os_env_unset((const uint8_t *)"ABI_TEST_NEW", 12) == GRAIL_OK);

    grail_env_iter iterator = GRAIL_HANDLE_NONE;
    CHECK(grail_os_env_iter_open(&iterator) == GRAIL_OK);
    int found_one = 0;
    int found_three = 0;
    for (;;) {
        uint64_t last = 0;
        CHECK(grail_os_env_iter_next(iterator, &last) == GRAIL_OK);
        if (last) {
            break;
        }
        uint8_t name[128];
        const grail_result name_length = grail_os_env_iter_name(iterator, name, sizeof(name));
        CHECK(name_length > 0);
        if (name_length == 12 && memcmp(name, "ABI_TEST_ONE", 12) == 0) {
            found_one = 1;
            uint8_t value[16];
            CHECK(grail_os_env_iter_value(iterator, value, sizeof(value)) == 1);
            CHECK(value[0] == '1');
        }
        if (name_length == 14 && memcmp(name, "ABI_TEST_THREE", 14) == 0) {
            found_three = 1;
        }
    }
    CHECK(found_one == 1);
    CHECK(found_three == 1);
    CHECK(grail_os_env_iter_close(iterator) == GRAIL_OK);
    CHECK(grail_os_env_iter_close(iterator) == GRAIL_E_INVALID_HANDLE);
}

static void test_time(void) {
    int64_t first = 0;
    int64_t second = 0;
    CHECK(grail_os_time_now(GRAIL_CLOCK_MONOTONIC, &first) == GRAIL_OK);
    CHECK(first > 0);
    int64_t resolution = 0;
    CHECK(grail_os_time_resolution(GRAIL_CLOCK_MONOTONIC, &resolution) == GRAIL_OK);
    CHECK(resolution > 0);
    CHECK(grail_os_time_sleep(2000000, NULL) == GRAIL_OK);
    CHECK(grail_os_time_now(GRAIL_CLOCK_MONOTONIC, &second) == GRAIL_OK);
    CHECK(second >= first + 1000000);
    int64_t wall = 0;
    CHECK(grail_os_time_now(GRAIL_CLOCK_REALTIME, &wall) == GRAIL_OK);
    CHECK(wall > 1600000000000000000ll);
    int64_t offset = 0;
    CHECK(grail_os_time_local_offset(wall, &offset) == GRAIL_OK);
    CHECK(grail_os_time_now(99, &wall) == GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_os_time_sleep(-1, NULL) == GRAIL_E_INVALID_ARGUMENT);
}

static void test_files(const char *scratch) {
    char original[512];
    grail_result original_length =
        grail_os_path_current_directory((uint8_t *)original, sizeof(original));
    CHECK(original_length > 0 && original_length < (grail_result)sizeof(original));
    CHECK(original[0] == '/');
    CHECK(grail_os_path_set_current_directory((const uint8_t *)scratch, strlen(scratch)) ==
          GRAIL_OK);
    char current[512];
    CHECK(grail_os_path_current_directory((uint8_t *)current, sizeof(current)) ==
          (grail_result)strlen(scratch));
    CHECK(memcmp(current, scratch, strlen(scratch)) == 0);
    char executable[512];
    CHECK(grail_os_path_executable((uint8_t *)executable, sizeof(executable)) > 0);

    grail_file file = GRAIL_HANDLE_NONE;
    CHECK(grail_os_file_open((const uint8_t *)"note.txt", 8,
                             GRAIL_OPEN_WRITE | GRAIL_OPEN_CREATE | GRAIL_OPEN_TRUNCATE, 0600,
                             &file) == GRAIL_OK);
    uint64_t written = 0;
    CHECK(grail_os_file_write(file, (const uint8_t *)"hello world", 11, &written) == GRAIL_OK);
    CHECK(written == 11);
    CHECK(grail_os_file_close(file) == GRAIL_OK);
    CHECK(grail_os_file_close(file) == GRAIL_E_INVALID_HANDLE);

    grail_file_stat metadata;
    CHECK(grail_os_fs_stat((const uint8_t *)"note.txt", 8, GRAIL_STAT_FOLLOW_SYMLINKS,
                           &metadata) == GRAIL_OK);
    CHECK(metadata.kind == GRAIL_FILE_KIND_FILE);
    CHECK(metadata.size == 11);
    CHECK(metadata.struct_size == sizeof(metadata));

    CHECK(grail_os_file_open((const uint8_t *)"note.txt", 8, GRAIL_OPEN_READ, 0, &file) ==
          GRAIL_OK);
    uint8_t buffer[64];
    uint64_t count = 0;
    CHECK(grail_os_file_read(file, buffer, sizeof(buffer), &count) == GRAIL_OK);
    CHECK(count == 11);
    CHECK(memcmp(buffer, "hello world", 11) == 0);
    uint64_t position = 0;
    CHECK(grail_os_file_seek(file, 6, GRAIL_SEEK_SET, &position) == GRAIL_OK);
    CHECK(position == 6);
    CHECK(grail_os_file_read(file, buffer, sizeof(buffer), &count) == GRAIL_OK);
    CHECK(count == 5);
    CHECK(memcmp(buffer, "world", 5) == 0);
    CHECK(grail_os_file_read(file, buffer, sizeof(buffer), &count) == GRAIL_OK);
    CHECK(count == 0);
    CHECK(grail_os_file_stat(file, &metadata) == GRAIL_OK);
    CHECK(metadata.kind == GRAIL_FILE_KIND_FILE);
    CHECK(grail_os_file_close(file) == GRAIL_OK);

    grail_file duplicate = GRAIL_HANDLE_NONE;
    CHECK(grail_os_file_open((const uint8_t *)"note.txt", 8,
                             GRAIL_OPEN_WRITE | GRAIL_OPEN_CREATE | GRAIL_OPEN_EXCLUSIVE, 0600,
                             &duplicate) == GRAIL_E_ALREADY_EXISTS);
    CHECK(grail_os_file_open((const uint8_t *)"missing.txt", 11, GRAIL_OPEN_READ, 0,
                             &duplicate) == GRAIL_E_NOT_FOUND);
    grail_os_error detail;
    CHECK(grail_os_error_last(&detail) == GRAIL_OK);
    CHECK(detail.domain == GRAIL_OS_DOMAIN_ERRNO);
    CHECK(detail.code == ENOENT);
    CHECK(grail_os_file_open((const uint8_t *)"note.txt", 8, 0, 0, &duplicate) ==
          GRAIL_E_INVALID_ARGUMENT);

    char long_target[320];
    memset(long_target, 't', sizeof(long_target) - 1);
    long_target[sizeof(long_target) - 1] = '\0';
    CHECK(symlink(long_target, "long-link") == 0);
    uint8_t link_buffer[512];
    const grail_result link_length =
        grail_os_fs_readlink((const uint8_t *)"long-link", 9, link_buffer, sizeof(link_buffer));
    CHECK(link_length == (grail_result)(sizeof(long_target) - 1));
    CHECK(memcmp(link_buffer, long_target, sizeof(long_target) - 1) == 0);
    CHECK(grail_os_fs_stat((const uint8_t *)"long-link", 9, GRAIL_STAT_NO_FOLLOW, &metadata) ==
          GRAIL_OK);
    CHECK(metadata.kind == GRAIL_FILE_KIND_SYMLINK);
    CHECK((metadata.flags & GRAIL_STAT_SYMLINK) != 0);
    CHECK(grail_os_fs_remove_file((const uint8_t *)"long-link", 9) == GRAIL_OK);

    CHECK(grail_os_fs_mkdir((const uint8_t *)"sub", 3, 0700, 0) == GRAIL_OK);
    CHECK(grail_os_fs_mkdir((const uint8_t *)"sub", 3, 0700, 0) == GRAIL_E_ALREADY_EXISTS);
    CHECK(grail_os_fs_stat((const uint8_t *)"sub", 3, GRAIL_STAT_FOLLOW_SYMLINKS, &metadata) ==
          GRAIL_OK);
    CHECK(metadata.kind == GRAIL_FILE_KIND_DIRECTORY);
    CHECK(grail_os_fs_mkdir((const uint8_t *)"a/b/c", 5, 0700, GRAIL_MKDIR_PARENTS) == GRAIL_OK);
    CHECK(grail_os_fs_stat((const uint8_t *)"a/b/c", 5, GRAIL_STAT_FOLLOW_SYMLINKS, &metadata) ==
          GRAIL_OK);

    grail_dir directory = GRAIL_HANDLE_NONE;
    CHECK(grail_os_dir_open((const uint8_t *)".", 1, &directory) == GRAIL_OK);
    int saw_note = 0;
    int saw_sub = 0;
    int saw_last = 0;
    for (int i = 0; i < 64 && !saw_last; i++) {
        grail_dir_entry entry;
        uint8_t name[256];
        const grail_result length = grail_os_dir_next(directory, name, sizeof(name), &entry);
        CHECK(length >= 0);
        if (length == 0) {
            CHECK(entry.is_last == 1);
            saw_last = 1;
            break;
        }
        CHECK(entry.name_length == (uint64_t)length);
        if (length == 8 && memcmp(name, "note.txt", 8) == 0) {
            saw_note = 1;
            CHECK(entry.kind == GRAIL_FILE_KIND_FILE);
        }
        if (length == 3 && memcmp(name, "sub", 3) == 0) {
            saw_sub = 1;
            CHECK(entry.kind == GRAIL_FILE_KIND_DIRECTORY);
        }
        if (entry.is_last) {
            saw_last = 1;
        }
    }
    CHECK(saw_note == 1);
    CHECK(saw_sub == 1);
    CHECK(saw_last == 1);
    CHECK(grail_os_dir_close(directory) == GRAIL_OK);

    grail_pipe pipe_pair;
    CHECK(grail_os_pipe(&pipe_pair) == GRAIL_OK);
    CHECK(grail_os_file_write(pipe_pair.write_end, (const uint8_t *)"x", 1, &written) ==
          GRAIL_OK);
    CHECK(written == 1);
    CHECK(grail_os_file_read(pipe_pair.read_end, buffer, sizeof(buffer), &count) == GRAIL_OK);
    CHECK(count == 1);
    CHECK(buffer[0] == 'x');
    CHECK(grail_os_file_close(pipe_pair.read_end) == GRAIL_OK);
    CHECK(grail_os_file_close(pipe_pair.write_end) == GRAIL_OK);

    CHECK(grail_os_fs_rename((const uint8_t *)"note.txt", 8, (const uint8_t *)"renamed.txt", 11,
                             0) == GRAIL_OK);
    CHECK(grail_os_fs_rename((const uint8_t *)"renamed.txt", 11, (const uint8_t *)"sub", 3, 0) ==
          GRAIL_E_ALREADY_EXISTS);
    CHECK(grail_os_fs_remove_file((const uint8_t *)"renamed.txt", 11) == GRAIL_OK);
    CHECK(grail_os_fs_remove_file((const uint8_t *)"renamed.txt", 11) == GRAIL_E_NOT_FOUND);
    CHECK(grail_os_fs_remove_dir((const uint8_t *)"sub", 3) == GRAIL_OK);
    CHECK(grail_os_fs_remove_dir((const uint8_t *)"a/b/c", 5) == GRAIL_OK);
    CHECK(grail_os_fs_remove_dir((const uint8_t *)"a/b", 3) == GRAIL_OK);
    CHECK(grail_os_fs_remove_dir((const uint8_t *)"a", 1) == GRAIL_OK);
    CHECK(grail_os_path_set_current_directory((const uint8_t *)original,
                                              (uint64_t)original_length) == GRAIL_OK);
}

static void test_threads(void) {
    grail_thread thread = GRAIL_HANDLE_NONE;
    CHECK(grail_os_thread_spawn(thread_entry, NULL, NULL, &thread) == GRAIL_OK);
    uint64_t exit_code = 0;
    CHECK(grail_os_thread_join(thread, &exit_code) == GRAIL_OK);
    CHECK(exit_code == 42);
    CHECK(grail_os_thread_join(thread, &exit_code) == GRAIL_E_INVALID_HANDLE);

    atomic_store(&detached_finished, 0);
    grail_thread detached = GRAIL_HANDLE_NONE;
    CHECK(grail_os_thread_spawn(detached_entry, NULL, NULL, &detached) == GRAIL_OK);
    CHECK(grail_os_thread_detach(detached) == GRAIL_OK);
    for (int i = 0; i < 1000 && atomic_load(&detached_finished) == 0; i++) {
        (void)grail_os_time_sleep(1000000, NULL);
    }
    CHECK(atomic_load(&detached_finished) == 1);

    uint64_t identifier = 0;
    CHECK(grail_os_thread_id(&identifier) == GRAIL_OK);
    CHECK(identifier != 0);
    CHECK(grail_os_thread_yield() == GRAIL_OK);

    grail_mutex mutex = GRAIL_HANDLE_NONE;
    CHECK(grail_os_mutex_create(&mutex) == GRAIL_OK);
    CHECK(grail_os_mutex_lock(mutex) == GRAIL_OK);
    uint64_t acquired = 99;
    CHECK(grail_os_mutex_try_lock(mutex, &acquired) == GRAIL_OK);
    CHECK(acquired == 0);
    CHECK(grail_os_mutex_unlock(mutex) == GRAIL_OK);
    CHECK(grail_os_mutex_try_lock(mutex, &acquired) == GRAIL_OK);
    CHECK(acquired == 1);
    CHECK(grail_os_mutex_unlock(mutex) == GRAIL_OK);

    grail_condvar condvar = GRAIL_HANDLE_NONE;
    CHECK(grail_os_condvar_create(&condvar) == GRAIL_OK);
    CHECK(grail_os_mutex_lock(mutex) == GRAIL_OK);
    uint64_t signaled = 99;
    CHECK(grail_os_condvar_wait(condvar, mutex, 1000000, &signaled) == GRAIL_OK);
    CHECK(signaled == 0);
    CHECK(grail_os_mutex_unlock(mutex) == GRAIL_OK);
    CHECK(grail_os_condvar_signal(condvar) == GRAIL_OK);
    CHECK(grail_os_condvar_broadcast(condvar) == GRAIL_OK);
    CHECK(grail_os_condvar_destroy(condvar) == GRAIL_OK);
    CHECK(grail_os_mutex_destroy(mutex) == GRAIL_OK);
    CHECK(grail_os_mutex_lock(mutex) == GRAIL_E_INVALID_HANDLE);
}

static void test_dynamic_library(void) {
    grail_library library = GRAIL_HANDLE_NONE;
    CHECK(grail_os_dl_open(NULL, 0, GRAIL_DL_LAZY, &library) == GRAIL_OK);
    void *symbol = NULL;
    CHECK(grail_os_dl_symbol(library, (const uint8_t *)"malloc", 6, &symbol) == GRAIL_OK);
    CHECK(symbol != NULL);
    CHECK(grail_os_dl_symbol(library, (const uint8_t *)"grail_missing_symbol", 20, &symbol) ==
          GRAIL_E_NOT_FOUND);
    uint8_t message[256];
    CHECK(grail_os_dl_error(message, sizeof(message)) > 0);
    CHECK(grail_os_dl_close(library) == GRAIL_OK);
    CHECK(grail_os_dl_close(library) == GRAIL_E_INVALID_HANDLE);
    grail_library missing = GRAIL_HANDLE_NONE;
    CHECK(grail_os_dl_open((const uint8_t *)"/nonexistent/grail-abi.so", 25, GRAIL_DL_LAZY,
                           &missing) == GRAIL_E_NOT_FOUND);
}


static void process_options(grail_process_options *options) {
    memset(options, 0, sizeof(*options));
    options->struct_size = sizeof(*options);
    options->abi_version = GRAIL_ABI_VERSION;
}

static uint64_t read_pipe(grail_file file, char *buffer, uint64_t capacity) {
    uint64_t total = 0;
    while (total < capacity) {
        uint64_t count = 0;
        CHECK(grail_os_file_read(file, (uint8_t *)buffer + total, capacity - total, &count) ==
              GRAIL_OK);
        if (count == 0) {
            break;
        }
        total += count;
    }
    return total;
}

static void test_processes(const char *scratch) {
    grail_process process = GRAIL_HANDLE_NONE;
    grail_process_options options;
    grail_pipe pipe_pair;
    char output[256];

    /* argv and stdout wiring. */
    process_options(&options);
    static const char echo_arguments[] = "echo\0hello";
    static const uint64_t echo_offsets[] = {0, 5};
    options.program = (const uint8_t *)"/bin/echo";
    options.program_length = 9;
    options.arguments = (const uint8_t *)echo_arguments;
    options.arguments_length = sizeof(echo_arguments);
    options.argument_offsets = echo_offsets;
    options.argument_count = 2;
    CHECK(grail_os_pipe(&pipe_pair) == GRAIL_OK);
    options.standard_output = pipe_pair.write_end;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_file_close(pipe_pair.write_end) == GRAIL_OK);
    const uint64_t echo_length = read_pipe(pipe_pair.read_end, output, sizeof(output));
    CHECK(echo_length == 6);
    CHECK(memcmp(output, "hello\n", 6) == 0);
    CHECK(grail_os_file_close(pipe_pair.read_end) == GRAIL_OK);
    grail_process_status status;
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.kind == GRAIL_PROCESS_EXITED);
    CHECK(status.exit_code == 0);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.exit_code == 0);
    uint64_t identifier = 0;
    CHECK(grail_os_process_id(process, &identifier) == GRAIL_OK);
    CHECK(identifier > 0);
    CHECK(grail_os_process_terminate(process) == GRAIL_OK);
    CHECK(grail_os_process_close(process) == GRAIL_OK);
    CHECK(grail_os_process_close(process) == GRAIL_E_INVALID_HANDLE);

    /* Replacement environment and argument vector. */
    process_options(&options);
    static const char sh_arguments[] = "sh\0-c\0printf %s \"$ABI_CHILD\"";
    static const uint64_t sh_offsets[] = {0, 3, 6};
    static const char child_environment[] = "ABI_CHILD=ok";
    static const uint64_t child_offsets[] = {0};
    options.program = (const uint8_t *)"/bin/sh";
    options.program_length = 7;
    options.arguments = (const uint8_t *)sh_arguments;
    options.arguments_length = sizeof(sh_arguments);
    options.argument_offsets = sh_offsets;
    options.argument_count = 3;
    options.environment = (const uint8_t *)child_environment;
    options.environment_length = sizeof(child_environment);
    options.environment_offsets = child_offsets;
    options.environment_count = 1;
    options.flags = GRAIL_PROC_REPLACE_ENVIRONMENT;
    CHECK(grail_os_pipe(&pipe_pair) == GRAIL_OK);
    options.standard_output = pipe_pair.write_end;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_file_close(pipe_pair.write_end) == GRAIL_OK);
    const uint64_t env_length = read_pipe(pipe_pair.read_end, output, sizeof(output));
    CHECK(env_length == 2);
    CHECK(memcmp(output, "ok", 2) == 0);
    CHECK(grail_os_file_close(pipe_pair.read_end) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.kind == GRAIL_PROCESS_EXITED);
    CHECK(status.exit_code == 0);
    CHECK(grail_os_process_close(process) == GRAIL_OK);

    /* Exit status. */
    process_options(&options);
    static const char exit_arguments[] = "sh\0-c\0exit 7";
    static const uint64_t exit_offsets[] = {0, 3, 6};
    options.program = (const uint8_t *)"/bin/sh";
    options.program_length = 7;
    options.arguments = (const uint8_t *)exit_arguments;
    options.arguments_length = sizeof(exit_arguments);
    options.argument_offsets = exit_offsets;
    options.argument_count = 3;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.kind == GRAIL_PROCESS_EXITED);
    CHECK(status.exit_code == 7);
    CHECK(status.term_signal == 0);
    CHECK(grail_os_process_close(process) == GRAIL_OK);

    /* Working directory. */
    process_options(&options);
    static const char pwd_arguments[] = "pwd\0-P";
    static const uint64_t pwd_offsets[] = {0, 4};
    options.program = (const uint8_t *)"/bin/pwd";
    options.program_length = 8;
    options.arguments = (const uint8_t *)pwd_arguments;
    options.arguments_length = sizeof(pwd_arguments);
    options.argument_offsets = pwd_offsets;
    options.argument_count = 2;
    options.working_directory = (const uint8_t *)scratch;
    options.working_directory_length = strlen(scratch);
    CHECK(grail_os_pipe(&pipe_pair) == GRAIL_OK);
    options.standard_output = pipe_pair.write_end;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_file_close(pipe_pair.write_end) == GRAIL_OK);
    const uint64_t pwd_length = read_pipe(pipe_pair.read_end, output, sizeof(output));
    CHECK(pwd_length == strlen(scratch) + 1);
    CHECK(memcmp(output, scratch, strlen(scratch)) == 0);
    CHECK(output[pwd_length - 1] == '\n');
    CHECK(grail_os_file_close(pipe_pair.read_end) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.exit_code == 0);
    CHECK(grail_os_process_close(process) == GRAIL_OK);

    /* stdin wiring. */
    process_options(&options);
    grail_pipe input_pipe;
    grail_pipe output_pipe;
    CHECK(grail_os_pipe(&input_pipe) == GRAIL_OK);
    CHECK(grail_os_pipe(&output_pipe) == GRAIL_OK);
    options.program = (const uint8_t *)"/bin/cat";
    options.program_length = 8;
    options.standard_input = input_pipe.read_end;
    options.standard_output = output_pipe.write_end;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_file_close(input_pipe.read_end) == GRAIL_OK);
    CHECK(grail_os_file_close(output_pipe.write_end) == GRAIL_OK);
    uint64_t written = 0;
    CHECK(grail_os_file_write(input_pipe.write_end, (const uint8_t *)"data", 4, &written) ==
          GRAIL_OK);
    CHECK(written == 4);
    CHECK(grail_os_file_close(input_pipe.write_end) == GRAIL_OK);
    const uint64_t cat_length = read_pipe(output_pipe.read_end, output, sizeof(output));
    CHECK(cat_length == 4);
    CHECK(memcmp(output, "data", 4) == 0);
    CHECK(grail_os_file_close(output_pipe.read_end) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.exit_code == 0);
    CHECK(grail_os_process_close(process) == GRAIL_OK);

    /* Path search. */
    process_options(&options);
    options.program = (const uint8_t *)"true";
    options.program_length = 4;
    options.flags = GRAIL_PROC_SEARCH_PATH;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.exit_code == 0);
    CHECK(grail_os_process_close(process) == GRAIL_OK);
    process_options(&options);
    options.program = (const uint8_t *)"grail-no-such-program-xyz";
    options.program_length = 25;
    options.flags = GRAIL_PROC_SEARCH_PATH;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_E_NOT_FOUND);

    /* Timeout, terminate and kill. */
    process_options(&options);
    static const char sleep_arguments[] = "sleep\0" "5";
    static const uint64_t sleep_offsets[] = {0, 6};
    options.program = (const uint8_t *)"/bin/sleep";
    options.program_length = 10;
    options.arguments = (const uint8_t *)sleep_arguments;
    options.arguments_length = sizeof(sleep_arguments);
    options.argument_offsets = sleep_offsets;
    options.argument_count = 2;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_process_wait_timeout(process, 10000000, &status) == GRAIL_E_TIMED_OUT);
    CHECK(status.kind == GRAIL_PROCESS_STILL_ACTIVE);
    CHECK(grail_os_process_terminate(process) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.kind == GRAIL_PROCESS_SIGNALED);
    CHECK(status.term_signal == 15);
    CHECK(grail_os_process_close(process) == GRAIL_OK);

    process_options(&options);
    options.program = (const uint8_t *)"/bin/sleep";
    options.program_length = 10;
    options.arguments = (const uint8_t *)sleep_arguments;
    options.arguments_length = sizeof(sleep_arguments);
    options.argument_offsets = sleep_offsets;
    options.argument_count = 2;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_OK);
    CHECK(grail_os_process_kill(process) == GRAIL_OK);
    CHECK(grail_os_process_wait(process, &status) == GRAIL_OK);
    CHECK(status.kind == GRAIL_PROCESS_SIGNALED);
    CHECK(status.term_signal == 9);
    CHECK(grail_os_process_close(process) == GRAIL_OK);

    /* Invalid option records fail before spawning. */
    process_options(&options);
    options.struct_size = 0;
    CHECK(grail_os_process_spawn(&options, &process) == GRAIL_E_INVALID_ARGUMENT);
}

static void set_ipv4(grail_socket_address *address, uint16_t port) {
    memset(address, 0, sizeof(*address));
    address->struct_size = sizeof(*address);
    address->abi_version = GRAIL_ABI_VERSION;
    address->family = GRAIL_ADDRESS_INET;
    address->port = port;
    address->address[0] = 127;
    address->address[3] = 1;
}

static void test_sockets(void) {
    grail_socket listener = GRAIL_HANDLE_NONE;
    grail_socket client = GRAIL_HANDLE_NONE;
    grail_socket server = GRAIL_HANDLE_NONE;
    grail_socket_address bind_address;
    set_ipv4(&bind_address, 0);
    CHECK(grail_os_socket_create(GRAIL_ADDRESS_INET, GRAIL_SOCKET_STREAM, &listener) == GRAIL_OK);
    CHECK(grail_os_socket_bind(listener, &bind_address) == GRAIL_OK);
    CHECK(grail_os_socket_listen(listener, 8) == GRAIL_OK);
    grail_socket_address local;
    CHECK(grail_os_socket_local_address(listener, &local) == GRAIL_OK);
    CHECK(local.family == GRAIL_ADDRESS_INET);
    CHECK(local.port != 0);
    CHECK(local.address[0] == 127 && local.address[3] == 1);

    uint64_t option = 0;
    CHECK(grail_os_socket_set_option(listener, GRAIL_SOCKOPT_REUSE_ADDRESS, 1) == GRAIL_OK);
    CHECK(grail_os_socket_get_option(listener, GRAIL_SOCKOPT_REUSE_ADDRESS, &option) == GRAIL_OK);
    CHECK(option != 0);

    CHECK(grail_os_socket_create(GRAIL_ADDRESS_INET, GRAIL_SOCKET_STREAM, &client) == GRAIL_OK);
    CHECK(grail_os_socket_connect(client, &local) == GRAIL_OK);
    grail_socket_address peer;
    CHECK(grail_os_socket_accept(listener, &server, &peer) == GRAIL_OK);
    CHECK(peer.family == GRAIL_ADDRESS_INET);
    CHECK(peer.port != 0);

    CHECK(grail_os_socket_set_option(client, GRAIL_SOCKOPT_NO_DELAY, 1) == GRAIL_OK);
    CHECK(grail_os_socket_get_option(client, GRAIL_SOCKOPT_NO_DELAY, &option) == GRAIL_OK);
    CHECK(option == 1);

    uint64_t sent = 0;
    uint64_t received = 0;
    uint8_t buffer[32];
    CHECK(grail_os_socket_send(client, (const uint8_t *)"ping", 4, &sent) == GRAIL_OK);
    CHECK(sent == 4);
    CHECK(grail_os_socket_recv(server, buffer, sizeof(buffer), &received) == GRAIL_OK);
    CHECK(received == 4);
    CHECK(memcmp(buffer, "ping", 4) == 0);
    CHECK(grail_os_socket_send(server, (const uint8_t *)"pong", 4, &sent) == GRAIL_OK);
    CHECK(sent == 4);
    CHECK(grail_os_socket_recv(client, buffer, sizeof(buffer), &received) == GRAIL_OK);
    CHECK(received == 4);
    CHECK(memcmp(buffer, "pong", 4) == 0);

    CHECK(grail_os_socket_set_nonblocking(listener, 1) == GRAIL_OK);
    grail_socket extra = GRAIL_HANDLE_NONE;
    CHECK(grail_os_socket_accept(listener, &extra, NULL) == GRAIL_E_WOULD_BLOCK);
    CHECK(grail_os_socket_set_nonblocking(listener, 0) == GRAIL_OK);
    CHECK(grail_os_socket_shutdown(client, GRAIL_SHUTDOWN_BOTH) == GRAIL_OK);
    CHECK(grail_os_socket_close(client) == GRAIL_OK);
    CHECK(grail_os_socket_close(client) == GRAIL_E_INVALID_HANDLE);
    CHECK(grail_os_socket_close(server) == GRAIL_OK);
    CHECK(grail_os_socket_close(listener) == GRAIL_OK);

    /* UDP send_to/recv_from over loopback. */
    grail_socket sender = GRAIL_HANDLE_NONE;
    grail_socket receiver = GRAIL_HANDLE_NONE;
    grail_socket_address sender_address;
    grail_socket_address receiver_address;
    set_ipv4(&sender_address, 0);
    set_ipv4(&receiver_address, 0);
    CHECK(grail_os_socket_create(GRAIL_ADDRESS_INET, GRAIL_SOCKET_DATAGRAM, &sender) == GRAIL_OK);
    CHECK(grail_os_socket_create(GRAIL_ADDRESS_INET, GRAIL_SOCKET_DATAGRAM, &receiver) ==
          GRAIL_OK);
    CHECK(grail_os_socket_bind(sender, &sender_address) == GRAIL_OK);
    CHECK(grail_os_socket_bind(receiver, &receiver_address) == GRAIL_OK);
    CHECK(grail_os_socket_local_address(sender, &sender_address) == GRAIL_OK);
    CHECK(grail_os_socket_local_address(receiver, &receiver_address) == GRAIL_OK);
    CHECK(sender_address.port != 0);
    CHECK(receiver_address.port != 0);
    CHECK(grail_os_socket_send_to(sender, (const uint8_t *)"udp", 3, &receiver_address, &sent) ==
          GRAIL_OK);
    CHECK(sent == 3);
    grail_socket_address from;
    CHECK(grail_os_socket_recv_from(receiver, buffer, sizeof(buffer), &from, &received) ==
          GRAIL_OK);
    CHECK(received == 3);
    CHECK(memcmp(buffer, "udp", 3) == 0);
    CHECK(from.port == sender_address.port);
    CHECK(grail_os_socket_close(sender) == GRAIL_OK);
    CHECK(grail_os_socket_close(receiver) == GRAIL_OK);

    /* Name resolution. */
    grail_socket_address resolved[8];
    const grail_result count =
        grail_os_net_resolve((const uint8_t *)"localhost", 9, GRAIL_ADDRESS_INET, resolved, 8);
    CHECK(count >= 1);
    CHECK(resolved[0].family == GRAIL_ADDRESS_INET);
    CHECK(resolved[0].struct_size == sizeof(grail_socket_address));
    CHECK(resolved[0].port == 0);
    CHECK(grail_os_net_resolve((const uint8_t *)"localhost", 9, GRAIL_ADDRESS_INET, NULL, 0) ==
          count);

    CHECK(grail_os_socket_create(99, GRAIL_SOCKET_STREAM, &listener) == GRAIL_E_INVALID_ARGUMENT);
    grail_socket_address malformed;
    memset(&malformed, 0, sizeof(malformed));
    CHECK(grail_os_socket_create(GRAIL_ADDRESS_INET, GRAIL_SOCKET_STREAM, &listener) == GRAIL_OK);
    CHECK(grail_os_socket_bind(listener, &malformed) == GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_os_socket_close(listener) == GRAIL_OK);
}

int main(void) {
    char scratch[] = "/tmp/grail-abi-XXXXXX";
    CHECK(mkdtemp(scratch) != NULL);
    static const char arguments_block[] = "prog\0arg1\0";
    static const uint64_t argument_offsets[] = {0, 5};
    static const char environment_block[] =
        "ABI_TEST_ONE=1\0"
        "ABI_TEST_TWO=\0"
        "ABI_TEST_THREE=three\0"
        "PATH=/usr/bin:/bin";
    static const uint64_t environment_offsets[] = {0, 15, 29, 50};
    grail_startup startup;
    memset(&startup, 0, sizeof(startup));
    startup.struct_size = sizeof(startup);
    startup.abi_version = GRAIL_ABI_VERSION;
    startup.arguments = (const uint8_t *)arguments_block;
    startup.arguments_length = sizeof(arguments_block) - 1;
    startup.argument_offsets = argument_offsets;
    startup.argument_count = 2;
    startup.environment = (const uint8_t *)environment_block;
    startup.environment_length = sizeof(environment_block);
    startup.environment_offsets = environment_offsets;
    startup.environment_count = 4;

    static const char malformed_block[] = "A=1\0BROKEN";
    static const uint64_t malformed_offsets[] = {0, 4};
    grail_startup malformed = startup;
    malformed.environment = (const uint8_t *)malformed_block;
    malformed.environment_length = sizeof(malformed_block) - 1;
    malformed.environment_offsets = malformed_offsets;
    malformed.environment_count = 2;
    CHECK(grail_os_init(&test_allocator, &malformed) == GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_os_capabilities() == 0);
    CHECK(grail_os_init(NULL, NULL) == GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_os_init(&test_allocator, &startup) == GRAIL_OK);
    CHECK(grail_os_init(&test_allocator, &startup) == GRAIL_E_UNSUPPORTED);
    const uint64_t capabilities = grail_os_capabilities();
    CHECK((capabilities & GRAIL_CAP_FILES) != 0);
    CHECK((capabilities & GRAIL_CAP_DIRECTORIES) != 0);
    CHECK((capabilities & GRAIL_CAP_ENVIRONMENT) != 0);
    CHECK((capabilities & GRAIL_CAP_TIME) != 0);
    CHECK((capabilities & GRAIL_CAP_CPU_TIME) != 0);
    CHECK((capabilities & GRAIL_CAP_THREADS) != 0);
    CHECK((capabilities & GRAIL_CAP_DYNAMIC_LIBRARIES) != 0);
    CHECK((capabilities & GRAIL_CAP_PROCESSES) != 0);
    CHECK((capabilities & GRAIL_CAP_SOCKETS) != 0);
    CHECK((capabilities & GRAIL_CAP_SOCKET_UDP) != 0);
    CHECK((capabilities & GRAIL_CAP_RESOLVE) != 0);

    test_environment();
    test_time();
    test_files(scratch);
    test_threads();
    test_dynamic_library();
    test_processes(scratch);
    test_sockets();

    CHECK(grail_os_shutdown() == GRAIL_OK);
    CHECK(grail_os_capabilities() == 0);
    CHECK(grail_os_shutdown() == GRAIL_E_NOT_INITIALIZED);
    CHECK(grail_os_init(&test_allocator, NULL) == GRAIL_OK);
    CHECK(grail_os_capabilities() != 0);
    CHECK(grail_os_shutdown() == GRAIL_OK);
    CHECK(live_bytes == 0);
    CHECK(rmdir(scratch) == 0);
    if (failures != 0) {
        fprintf(stderr, "linux-backend: %d of %d checks failed (live bytes %llu)\n", failures,
                checks, (unsigned long long)live_bytes);
        return 1;
    }
    printf("linux-backend: %d checks passed\n", checks);
    return 0;
}
