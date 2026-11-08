/* Executed Windows ABI harness for metadata, reparse/readlink, realpath and DNS.
 *
 * Built with Zig's MinGW-w64 target and run under Wine.  The harness uses the
 * public C ABI only for file operations; windows.h supplies temp-directory and
 * symlink setup.  It is a test artifact, not part of the shipped runtime.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#include "../../include/grail/grail.h"

static int failures;
static int checks;

#define CHECK(condition)                                                       \
    do {                                                                       \
        checks++;                                                              \
        if (!(condition)) {                                                    \
            fprintf(stderr, "wine-abi: check failed at line %d: %s\n",         \
                    __LINE__, #condition);                                     \
            failures++;                                                        \
        }                                                                      \
    } while (0)

static void *test_allocate(void *context, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)alignment;
    return malloc((size_t)size);
}

static void *test_reallocate(void *context, void *pointer, uint64_t old_size,
                             uint64_t new_size, uint64_t alignment) {
    (void)context;
    (void)old_size;
    (void)alignment;
    return realloc(pointer, (size_t)new_size);
}

static void test_release(void *context, void *pointer, uint64_t size, uint64_t alignment) {
    (void)context;
    (void)size;
    (void)alignment;
    free(pointer);
}

static grail_allocator allocator = {
    sizeof(grail_allocator), NULL, test_allocate, test_reallocate, test_release};

static int write_all(grail_file file, const char *text) {
    uint64_t written = 0;
    const uint64_t length = (uint64_t)strlen(text);
    if (grail_os_file_write(file, (const uint8_t *)text, length, &written) != GRAIL_OK) {
        return 0;
    }
    return written == length;
}

int main(void) {
    char directory[MAX_PATH];
    char file_path[MAX_PATH];
    char link_path[MAX_PATH];
    char temp[MAX_PATH];
    DWORD temp_length = GetTempPathA(MAX_PATH, temp);
    CHECK(temp_length > 0 && temp_length < MAX_PATH);
    snprintf(directory, sizeof(directory), "%sgrail-abi-wine-%lu", temp,
             (unsigned long)GetCurrentProcessId());
    CreateDirectoryA(directory, NULL);
    snprintf(file_path, sizeof(file_path), "%s\\file.txt", directory);
    snprintf(link_path, sizeof(link_path), "%s\\link.txt", directory);

    CHECK(grail_os_init(&allocator, NULL) == GRAIL_OK);
    const uint64_t capabilities = grail_os_capabilities();
    CHECK((capabilities & GRAIL_CAP_FILE_METADATA) != 0);
    CHECK((capabilities & GRAIL_CAP_SYMLINKS) != 0);
    CHECK((capabilities & GRAIL_CAP_RESOLVE) != 0);
    CHECK((capabilities & GRAIL_CAP_FILE_NONBLOCKING) != 0);

    grail_file file = GRAIL_HANDLE_NONE;
    const uint64_t file_length = (uint64_t)strlen(file_path);
    CHECK(grail_os_file_open((const uint8_t *)file_path, file_length,
                             GRAIL_OPEN_WRITE | GRAIL_OPEN_CREATE | GRAIL_OPEN_TRUNCATE,
                             0666, &file) == GRAIL_OK);
    CHECK(write_all(file, "hello"));
    CHECK(grail_os_file_close(file) == GRAIL_OK);

    grail_file_stat metadata;
    memset(&metadata, 0, sizeof(metadata));
    CHECK(grail_os_fs_stat((const uint8_t *)file_path, file_length,
                           GRAIL_STAT_FOLLOW_SYMLINKS, &metadata) == GRAIL_OK);
    CHECK(metadata.struct_size == sizeof(metadata));
    CHECK(metadata.abi_version == GRAIL_ABI_VERSION);
    CHECK(metadata.kind == GRAIL_FILE_KIND_FILE);
    CHECK(metadata.size == 5);
    CHECK(metadata.modified_ns > 0);
    CHECK(metadata.created_ns > 0);
    printf("wine-abi: metadata size=%llu kind=%llu\n",
           (unsigned long long)metadata.size, (unsigned long long)metadata.kind);

    CHECK(grail_os_file_open((const uint8_t *)file_path, file_length, GRAIL_OPEN_READ, 0,
                             &file) == GRAIL_OK);
    memset(&metadata, 0, sizeof(metadata));
    CHECK(grail_os_file_stat(file, &metadata) == GRAIL_OK);
    CHECK(metadata.kind == GRAIL_FILE_KIND_FILE);
    CHECK(metadata.size == 5);
    CHECK(grail_os_file_set_nonblocking(file, 1) == GRAIL_E_UNSUPPORTED);
    CHECK(grail_os_file_close(file) == GRAIL_OK);

    SetFileAttributesA(file_path, FILE_ATTRIBUTE_HIDDEN);
    memset(&metadata, 0, sizeof(metadata));
    CHECK(grail_os_fs_stat((const uint8_t *)file_path, file_length,
                           GRAIL_STAT_FOLLOW_SYMLINKS, &metadata) == GRAIL_OK);
    CHECK((metadata.flags & GRAIL_STAT_HIDDEN) != 0);
    SetFileAttributesA(file_path, FILE_ATTRIBUTE_NORMAL);

    uint8_t readlink_buffer[512];
    CHECK(grail_os_fs_readlink((const uint8_t *)file_path, file_length, readlink_buffer,
                               sizeof(readlink_buffer)) == GRAIL_E_INVALID_ARGUMENT);
    printf("wine-abi: readlink non-reparse rejected\n");

    uint8_t resolved[512];
    const grail_result resolved_length =
        grail_os_fs_realpath((const uint8_t *)file_path, file_length, resolved,
                             sizeof(resolved));
    CHECK(resolved_length > 0);
    if (resolved_length > 0) {
        CHECK((uint64_t)resolved_length < sizeof(resolved));
        resolved[resolved_length] = 0;
        CHECK(strstr((const char *)resolved, "file.txt") != NULL);
        CHECK(strchr((const char *)resolved, '\\') == NULL);
        printf("wine-abi: realpath=%s\n", (const char *)resolved);
    }

    BOOL linked = CreateSymbolicLinkA(link_path, "file.txt", 2);
    if (!linked) linked = CreateSymbolicLinkA(link_path, "file.txt", 0);
    if (linked) {
        memset(&metadata, 0, sizeof(metadata));
        CHECK(grail_os_fs_stat((const uint8_t *)link_path, (uint64_t)strlen(link_path),
                               GRAIL_STAT_NO_FOLLOW, &metadata) == GRAIL_OK);
        CHECK(metadata.kind == GRAIL_FILE_KIND_SYMLINK);
        const grail_result link_length =
            grail_os_fs_readlink((const uint8_t *)link_path, (uint64_t)strlen(link_path),
                                 readlink_buffer, sizeof(readlink_buffer));
        CHECK(link_length > 0);
        if (link_length > 0) {
            CHECK((uint64_t)link_length < sizeof(readlink_buffer));
            readlink_buffer[link_length] = 0;
            CHECK(strstr((const char *)readlink_buffer, "file.txt") != NULL);
            printf("wine-abi: readlink=%s\n", (const char *)readlink_buffer);
        }
        CHECK(grail_os_fs_stat((const uint8_t *)link_path, (uint64_t)strlen(link_path),
                               GRAIL_STAT_FOLLOW_SYMLINKS, &metadata) == GRAIL_OK);
        CHECK(metadata.kind == GRAIL_FILE_KIND_FILE);
        const grail_result link_real =
            grail_os_fs_realpath((const uint8_t *)link_path, (uint64_t)strlen(link_path),
                                 resolved, sizeof(resolved));
        CHECK(link_real > 0);
        if (link_real > 0) {
            CHECK((uint64_t)link_real < sizeof(resolved));
            resolved[link_real] = 0;
            CHECK(strstr((const char *)resolved, "file.txt") != NULL);
        }
        printf("wine-abi: symlink ok\n");
        DeleteFileA(link_path);
    } else {
        printf("wine-abi: symlink SKIP (error %lu)\n", (unsigned long)GetLastError());
    }

    grail_socket_address addresses[8];
    const grail_result count =
        grail_os_net_resolve((const uint8_t *)"localhost", 9, GRAIL_ADDRESS_INET, addresses, 8);
    CHECK(count >= 1);
    if (count >= 1) {
        CHECK(addresses[0].struct_size == sizeof(addresses[0]));
        CHECK(addresses[0].abi_version == GRAIL_ABI_VERSION);
        CHECK(addresses[0].family == GRAIL_ADDRESS_INET);
        CHECK(addresses[0].port == 0);
        printf("wine-abi: dns count=%lld first=%u.%u.%u.%u\n", (long long)count,
               addresses[0].address[0], addresses[0].address[1], addresses[0].address[2],
               addresses[0].address[3]);
    }
    const grail_result required =
        grail_os_net_resolve((const uint8_t *)"localhost", 9, GRAIL_ADDRESS_INET, NULL, 0);
    CHECK(required >= 1);
    CHECK(required >= count);

    CHECK(grail_os_shutdown() == GRAIL_OK);
    DeleteFileA(file_path);
    RemoveDirectoryA(directory);
    if (failures != 0) {
        printf("wine-abi: FAIL (%d/%d)\n", failures, checks);
        return 1;
    }
    printf("wine-abi: PASS (%d checks)\n", checks);
    return 0;
}
