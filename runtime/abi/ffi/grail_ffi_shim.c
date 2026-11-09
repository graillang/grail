/*
 * Hosted FFI adapter for the Linux OS ABI reference backend.
 *
 * This is test/build scaffolding, not part of the ABI or the shipping Grail
 * runtime.  It supplies the allocator that grail_os_init requires, returns an
 * opened file/socket/process/thread handle directly (the ABI uses an
 * out-pointer), and keeps that handle in a thread-local slot so the
 * scalar/handle FFI can carry it without a raw pointer.  Process arguments are
 * packed into the ABI's offset-addressed block here.  Environment initialization is empty; the Grail entry shim owns
 * the real startup environment.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "../../../include/grail/grail_abi.h"
#include "../../../include/grail/grail_error.h"
#include "../../../include/grail/grail_fs.h"
#include "../../../include/grail/grail_proc.h"
#include "../../../include/grail/grail_socket.h"
#include "../../../include/grail/grail_thread.h"

static void *grail_ffi_allocate(void *context, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)alignment;
    return malloc((size_t)size);
}

static void *grail_ffi_reallocate(void *context, void *pointer, uint64_t old_size,
                                  uint64_t new_size, uint64_t alignment) {
    (void)context;
    (void)old_size;
    (void)alignment;
    return realloc(pointer, (size_t)new_size);
}

static void grail_ffi_release(void *context, void *pointer, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)size;
    (void)alignment;
    free(pointer);
}

static _Thread_local grail_file grail_ffi_last_file;
static _Thread_local grail_socket grail_ffi_last_socket;
static _Thread_local grail_process grail_ffi_last_process;
static _Thread_local grail_thread grail_ffi_last_thread;

int64_t grail_ffi_init(void) {
    grail_allocator allocator = {
        sizeof(grail_allocator),
        NULL,
        grail_ffi_allocate,
        grail_ffi_reallocate,
        grail_ffi_release,
    };
    return grail_os_init(&allocator, NULL);
}

int64_t grail_ffi_shutdown(void) {
    return grail_os_shutdown();
}

int64_t grail_ffi_file_open(const uint8_t *path, uint64_t path_length, uint64_t flags,
                            uint64_t mode) {
    grail_file handle = GRAIL_HANDLE_NONE;
    const int64_t status = grail_os_file_open(path, path_length, flags, mode, &handle);
    grail_ffi_last_file = status == 0 ? handle : GRAIL_HANDLE_NONE;
    return status;
}

grail_file grail_ffi_file_handle(void) {
    return grail_ffi_last_file;
}


int64_t grail_ffi_socket_create(uint64_t family, uint64_t type) {
    grail_socket handle = GRAIL_HANDLE_NONE;
    const int64_t status = grail_os_socket_create(family, type, &handle);
    grail_ffi_last_socket = status == 0 ? handle : GRAIL_HANDLE_NONE;
    return status;
}

grail_socket grail_ffi_socket_handle(void) {
    return grail_ffi_last_socket;
}

int64_t grail_ffi_socket_accept(grail_socket listener) {
    grail_socket handle = GRAIL_HANDLE_NONE;
    const int64_t status = grail_os_socket_accept(listener, &handle, NULL);
    grail_ffi_last_socket = status == 0 ? handle : GRAIL_HANDLE_NONE;
    return status;
}


static int grail_ffi_text_has_zero(const uint8_t *text, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (text[i] == 0) {
            return 1;
        }
    }
    return 0;
}

int64_t grail_ffi_process_spawn(const uint8_t *program, uint64_t program_length,
                                const uint8_t *arguments, uint64_t arguments_length) {
    if (program == NULL || program_length == 0 ||
        (arguments == NULL && arguments_length != 0) ||
        grail_ffi_text_has_zero(program, program_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_process_options options;
    memset(&options, 0, sizeof(options));
    options.struct_size = sizeof(options);
    options.abi_version = GRAIL_ABI_VERSION;
    options.flags = GRAIL_PROC_INHERIT_STDIO;
    options.program = program;
    options.program_length = program_length;
    options.standard_input = GRAIL_HANDLE_NONE;
    options.standard_output = GRAIL_HANDLE_NONE;
    options.standard_error = GRAIL_HANDLE_NONE;

    uint8_t *block = NULL;
    uint64_t *offsets = NULL;
    if (arguments_length != 0) {
        uint64_t argument_count = 0;
        uint64_t start = 0;
        for (uint64_t i = 0; i <= arguments_length; i++) {
            if (i == arguments_length || arguments[i] == 0) {
                if (i == arguments_length && start == arguments_length) {
                    break;
                }
                argument_count++;
                start = i + 1;
            }
        }
        if (program_length > SIZE_MAX - arguments_length - 2) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        const uint64_t block_length = program_length + 1 + arguments_length + 1;
        if (argument_count > SIZE_MAX / sizeof(uint64_t) - 1) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        block = (uint8_t *)malloc((size_t)block_length);
        offsets = (uint64_t *)malloc((size_t)(argument_count + 1) * sizeof(uint64_t));
        if (block == NULL || offsets == NULL) {
            free(block);
            free(offsets);
            return GRAIL_E_OUT_OF_MEMORY;
        }
        memcpy(block, program, (size_t)program_length);
        block[program_length] = 0;
        if (arguments_length != 0) {
            memcpy(block + program_length + 1, arguments, (size_t)arguments_length);
        }
        block[block_length - 1] = 0;
        offsets[0] = 0;
        uint64_t argument_index = 1;
        start = 0;
        for (uint64_t i = 0; i <= arguments_length; i++) {
            if (i == arguments_length || arguments[i] == 0) {
                if (i == arguments_length && start == arguments_length) {
                    break;
                }
                offsets[argument_index++] = program_length + 1 + start;
                start = i + 1;
            }
        }
        options.arguments = block;
        options.arguments_length = block_length;
        options.argument_offsets = offsets;
        options.argument_count = argument_index;
    }

    grail_process handle = GRAIL_HANDLE_NONE;
    const int64_t status = grail_os_process_spawn(&options, &handle);
    free(block);
    free(offsets);
    grail_ffi_last_process = status == 0 ? handle : GRAIL_HANDLE_NONE;
    return status;
}

grail_process grail_ffi_process_handle(void) {
    return grail_ffi_last_process;
}

int64_t grail_ffi_thread_spawn(grail_thread_entry entry, uint64_t user) {
    if (entry == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_thread handle = GRAIL_HANDLE_NONE;
    const int64_t status =
        grail_os_thread_spawn(entry, (void *)(uintptr_t)user, NULL, &handle);
    grail_ffi_last_thread = status == 0 ? handle : GRAIL_HANDLE_NONE;
    return status;
}

grail_thread grail_ffi_thread_handle(void) {
    return grail_ffi_last_thread;
}
