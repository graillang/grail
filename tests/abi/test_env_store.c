/* Shared environment store used by the Windows and macOS backends. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../runtime/abi/grail_env_store.h"

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

static grail_allocator allocator = // NOLINT
    {sizeof(grail_allocator), NULL, test_allocate, NULL, test_release};

static void expect_get(const grail_env_store *store, const char *name, const char *expected) {
    const char *value = NULL;
    uint64_t length = 0;
    CHECK(grail_env_store_get(store, (const uint8_t *)name, strlen(name), &value, &length) ==
          GRAIL_OK);
    CHECK(length == strlen(expected));
    CHECK(memcmp(value, expected, length) == 0);
}

int main(void) {
    grail_env_store store;
    CHECK(grail_env_store_init(&store, &allocator) == GRAIL_OK);
    CHECK(grail_env_store_count(&store) == 0);

    const char *missing = NULL;
    uint64_t missing_length = 0;
    CHECK(grail_env_store_get(&store, (const uint8_t *)"NOPE", 4, &missing, &missing_length) ==
          GRAIL_E_NOT_FOUND);
    CHECK(grail_env_store_set(&store, (const uint8_t *)"A", 1, (const uint8_t *)"1", 1) ==
          GRAIL_OK);
    CHECK(grail_env_store_set(&store, (const uint8_t *)"B", 1, (const uint8_t *)"", 0) ==
          GRAIL_OK);
    expect_get(&store, "A", "1");
    expect_get(&store, "B", "");
    CHECK(grail_env_store_set(&store, (const uint8_t *)"A", 1, (const uint8_t *)"two", 3) ==
          GRAIL_OK);
    expect_get(&store, "A", "two");
    CHECK(grail_env_store_count(&store) == 2);
    CHECK(grail_env_store_set(&store, (const uint8_t *)"BAD=NAME", 8, (const uint8_t *)"x", 1) ==
          GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_env_store_set(&store, (const uint8_t *)"X", 1, (const uint8_t *)"a\0b", 3) ==
          GRAIL_E_INVALID_ARGUMENT);

    grail_env_snapshot snapshot;
    CHECK(grail_env_snapshot_take(&store, &snapshot) == GRAIL_OK);
    CHECK(snapshot.count == 2);
    CHECK(grail_env_store_unset(&store, (const uint8_t *)"B", 1) == GRAIL_OK);
    CHECK(grail_env_store_count(&store) == 1);
    CHECK(snapshot.count == 2); /* snapshot is independent */
    grail_env_snapshot_free(&snapshot);

    static const char environment[] = "ONE=1\0TWO=\0THREE=three";
    static const uint64_t offsets[] = {0, 6, 11};
    grail_startup startup;
    memset(&startup, 0, sizeof(startup));
    startup.struct_size = sizeof(startup);
    startup.abi_version = GRAIL_ABI_VERSION;
    startup.environment = (const uint8_t *)environment;
    startup.environment_length = sizeof(environment);
    startup.environment_offsets = offsets;
    startup.environment_count = 3;
    grail_env_store seeded;
    CHECK(grail_env_store_init(&seeded, &allocator) == GRAIL_OK);
    CHECK(grail_env_store_seed(&seeded, &startup) == GRAIL_OK);
    expect_get(&seeded, "ONE", "1");
    expect_get(&seeded, "TWO", "");
    expect_get(&seeded, "THREE", "three");
    CHECK(grail_env_store_count(&seeded) == 3);
    grail_env_store_free(&seeded);

    grail_startup malformed = startup;
    malformed.environment = (const uint8_t *)"BROKEN";
    malformed.environment_length = 6;
    malformed.environment_count = 1;
    grail_env_store bad;
    CHECK(grail_env_store_init(&bad, &allocator) == GRAIL_OK);
    CHECK(grail_env_store_seed(&bad, &malformed) == GRAIL_E_INVALID_ARGUMENT);
    grail_env_store_free(&bad);

    grail_env_store_free(&store);
    CHECK(live_bytes == 0);
    if (failures != 0) {
        fprintf(stderr, "env-store: %d of %d checks failed (live %llu)\n", failures, checks,
                (unsigned long long)live_bytes);
        return 1;
    }
    printf("env-store: %d checks passed\n", checks);
    return 0;
}
