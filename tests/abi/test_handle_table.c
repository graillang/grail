/* Internal generation-checked handle table. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "../../runtime/abi/grail_handle_table.h"

static int failures;
static int checks;
static uint64_t allocations;
static uint64_t releases;

#define CHECK(condition)                                                       \
    do {                                                                       \
        checks++;                                                              \
        if (!(condition)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__,   \
                    #condition);                                               \
            failures++;                                                        \
        }                                                                      \
    } while (0)

static void *tracked_allocate(void *context, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)alignment;
    allocations++;
    return malloc((size_t)size);
}

static void *tracked_reallocate(void *context, void *pointer, uint64_t old_size, uint64_t new_size,
                                uint64_t alignment) {
    (void)context;
    (void)old_size;
    (void)alignment;
    allocations++;
    return realloc(pointer, (size_t)new_size);
}

static void tracked_release(void *context, void *pointer, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)size;
    (void)alignment;
    releases++;
    free(pointer);
}

static grail_allocator allocator = {
    sizeof(grail_allocator), NULL, tracked_allocate, tracked_reallocate, tracked_release};

int main(void) {
    grail_handle_table files;
    grail_handle_table other;
    CHECK(grail_handle_table_init(&files, &allocator, GRAIL_HANDLE_KIND_FILE) == GRAIL_OK);
    CHECK(grail_handle_table_init(&other, &allocator, GRAIL_HANDLE_KIND_DIR) == GRAIL_OK);
    CHECK(grail_handle_table_init(NULL, &allocator, 1) == GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_handle_table_init(&files, NULL, 1) == GRAIL_E_INVALID_ARGUMENT);

    enum { COUNT = 1000 };
    static int objects[COUNT];
    grail_handle handles[COUNT];
    for (int i = 0; i < COUNT; i++) {
        objects[i] = i;
        CHECK(grail_handle_table_allocate(&files, &objects[i], &handles[i]) == GRAIL_OK);
        CHECK(handles[i] != GRAIL_HANDLE_NONE);
        void *found = NULL;
        CHECK(grail_handle_table_lookup(&files, handles[i], &found) == GRAIL_OK);
        CHECK(found == &objects[i]);
        CHECK(grail_handle_table_lookup(&other, handles[i], &found) == GRAIL_E_INVALID_HANDLE);
    }
    CHECK(allocations > 0);

    for (int i = 0; i < COUNT; i++) {
        if (i % 2 == 0) {
            void *released = NULL;
            CHECK(grail_handle_table_release(&files, handles[i], &released) == GRAIL_OK);
            CHECK(released == &objects[i]);
            CHECK(grail_handle_table_release(&files, handles[i], NULL) ==
                  GRAIL_E_INVALID_HANDLE);
        }
    }
    for (int i = 0; i < COUNT; i++) {
        void *found = NULL;
        const grail_status status = grail_handle_table_lookup(&files, handles[i], &found);
        CHECK(status == (i % 2 == 0 ? GRAIL_E_INVALID_HANDLE : GRAIL_OK));
    }

    grail_handle reused = GRAIL_HANDLE_NONE;
    CHECK(grail_handle_table_allocate(&files, &objects[0], &reused) == GRAIL_OK);
    CHECK(reused != handles[0]);
    CHECK(grail_handle_table_lookup(&files, handles[0], NULL) == GRAIL_E_INVALID_HANDLE);
    void *found = NULL;
    CHECK(grail_handle_table_lookup(&files, reused, &found) == GRAIL_OK);
    CHECK(found == &objects[0]);

    CHECK(grail_handle_table_lookup(&files, GRAIL_HANDLE_NONE, &found) ==
          GRAIL_E_INVALID_HANDLE);
    CHECK(grail_handle_table_lookup(&files, 0xFFFFFFFFFFFFFFFFull, &found) ==
          GRAIL_E_INVALID_HANDLE);
    CHECK(grail_handle_table_allocate(&files, NULL, &reused) == GRAIL_E_INVALID_ARGUMENT);

    grail_handle_table_destroy(&files);
    grail_handle_table_destroy(&other);
    CHECK(allocations >= releases);
    if (failures != 0) {
        fprintf(stderr, "handles: %d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("handles: %d checks passed\n", checks);
    return 0;
}
