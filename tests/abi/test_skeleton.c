/* Skeleton backends must fail closed and advertise nothing. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../../include/grail/grail.h"

static int failures;
static int checks;

#define CHECK(condition)                                                       \
    do {                                                                       \
        checks++;                                                              \
        if (!(condition)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__,   \
                    #condition);                                               \
            failures++;                                                        \
        }                                                                      \
    } while (0)

static void *allocate(void *context, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)alignment;
    static uint8_t storage[4096];
    static uint64_t used;
    if (used + size > sizeof(storage)) {
        return NULL;
    }
    void *result = storage + used;
    used += size;
    return result;
}

static void release(void *context, void *pointer, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)pointer;
    (void)size;
    (void)alignment;
}

int main(void) {
    grail_allocator allocator = {sizeof(grail_allocator), NULL, allocate, NULL, release};
    CHECK(grail_os_init(&allocator, NULL) == GRAIL_E_UNSUPPORTED);
    CHECK(grail_os_capabilities() == 0);
    grail_os_error detail;
    detail.domain = 99;
    detail.code = 99;
    CHECK(grail_os_error_last(&detail) == GRAIL_OK);
    CHECK(detail.domain == GRAIL_OS_DOMAIN_NONE);
    CHECK(detail.code == 0);

    grail_file file = GRAIL_HANDLE_NONE;
    CHECK(grail_os_file_open((const uint8_t *)"x", 1, GRAIL_OPEN_READ, 0, &file) ==
          GRAIL_E_UNSUPPORTED);
    uint8_t buffer[8];
    CHECK(grail_os_env_get((const uint8_t *)"PATH", 4, buffer, sizeof(buffer)) ==
          GRAIL_E_UNSUPPORTED);
    int64_t now = 0;
    CHECK(grail_os_time_now(GRAIL_CLOCK_MONOTONIC, &now) == GRAIL_E_UNSUPPORTED);
    grail_thread thread = GRAIL_HANDLE_NONE;
    CHECK(grail_os_thread_spawn(NULL, NULL, NULL, &thread) == GRAIL_E_UNSUPPORTED);
    grail_library library = GRAIL_HANDLE_NONE;
    CHECK(grail_os_dl_open(NULL, 0, 0, &library) == GRAIL_E_UNSUPPORTED);
    grail_process process = GRAIL_HANDLE_NONE;
    CHECK(grail_os_process_spawn(NULL, &process) == GRAIL_E_UNSUPPORTED);
    grail_socket socket = GRAIL_HANDLE_NONE;
    CHECK(grail_os_socket_create(GRAIL_ADDRESS_INET, GRAIL_SOCKET_STREAM, &socket) ==
          GRAIL_E_UNSUPPORTED);
    CHECK(grail_os_net_resolve(NULL, 0, 0, NULL, 0) == GRAIL_E_UNSUPPORTED);
    CHECK(grail_os_shutdown() == GRAIL_E_NOT_INITIALIZED);
    if (failures != 0) {
        fprintf(stderr, "skeleton: %d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("skeleton: %d checks passed\n", checks);
    return 0;
}
