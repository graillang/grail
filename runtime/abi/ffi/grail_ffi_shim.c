/*
 * Hosted FFI adapter for the Linux OS ABI reference backend.
 *
 * This is test/build scaffolding, not part of the ABI or the shipping Grail
 * runtime.  It supplies the allocator that grail_os_init requires, returns an
 * opened file handle directly (the ABI uses an out-pointer), and keeps that
 * handle in a thread-local slot so the scalar/handle FFI can carry it without a
 * raw pointer.  Environment initialization is empty; the Grail entry shim owns
 * the real startup environment.
 */
#include <stdlib.h>

#include "../../../include/grail/grail_abi.h"
#include "../../../include/grail/grail_error.h"
#include "../../../include/grail/grail_fs.h"

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
