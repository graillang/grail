/* Lexical path rules.  Compiled twice: POSIX rules and Windows rules. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../../include/grail/grail_path.h"

#ifndef GRAIL_ABI_PATH_WINDOWS
#define GRAIL_ABI_PATH_WINDOWS 0
#endif

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

static void expect(const char *path, const char *expected) {
    uint8_t buffer[256];
    const uint64_t expected_length = (uint64_t)strlen(expected);
    const grail_result required =
        grail_os_path_normalize((const uint8_t *)path, strlen(path), NULL, 0);
    CHECK(required == (grail_result)expected_length);
    memset(buffer, 0xAA, sizeof(buffer));
    const grail_result written = grail_os_path_normalize(
        (const uint8_t *)path, strlen(path), buffer, sizeof(buffer));
    CHECK(written == (grail_result)expected_length);
    CHECK(memcmp(buffer, expected, (size_t)expected_length) == 0);
    if (expected_length > 0) {
        memset(buffer, 0xAA, sizeof(buffer));
        CHECK(grail_os_path_normalize((const uint8_t *)path, strlen(path), buffer,
                                      expected_length - 1) == (grail_result)expected_length);
        CHECK(buffer[0] == 0xAA);
    }
}

static void expect_parent(const char *path, const char *expected) {
    uint8_t buffer[256];
    const uint64_t expected_length = (uint64_t)strlen(expected);
    const grail_result required =
        grail_os_path_parent((const uint8_t *)path, strlen(path), NULL, 0);
    CHECK(required == (grail_result)expected_length);
    const grail_result written = grail_os_path_parent(
        (const uint8_t *)path, strlen(path), buffer, sizeof(buffer));
    CHECK(written == (grail_result)expected_length);
    CHECK(memcmp(buffer, expected, (size_t)expected_length) == 0);
}

static void expect_name(const char *path, const char *expected) {
    uint8_t buffer[256];
    const uint64_t expected_length = (uint64_t)strlen(expected);
    const grail_result written = grail_os_path_file_name(
        (const uint8_t *)path, strlen(path), buffer, sizeof(buffer));
    CHECK(written == (grail_result)expected_length);
    CHECK(memcmp(buffer, expected, (size_t)expected_length) == 0);
}

static void expect_extension(const char *path, const char *expected) {
    uint8_t buffer[256];
    const uint64_t expected_length = (uint64_t)strlen(expected);
    const grail_result written = grail_os_path_extension(
        (const uint8_t *)path, strlen(path), buffer, sizeof(buffer));
    CHECK(written == (grail_result)expected_length);
    CHECK(memcmp(buffer, expected, (size_t)expected_length) == 0);
}

static void expect_join(const char *base, const char *child, const char *expected) {
    uint8_t buffer[256];
    const uint64_t expected_length = (uint64_t)strlen(expected);
    const grail_result written =
        grail_os_path_join((const uint8_t *)base, strlen(base), (const uint8_t *)child,
                           strlen(child), buffer, sizeof(buffer));
    CHECK(written == (grail_result)expected_length);
    CHECK(memcmp(buffer, expected, (size_t)expected_length) == 0);
}

static void expect_absolute(const char *path, uint64_t expected) {
    uint64_t value = 99;
    CHECK(grail_os_path_is_absolute((const uint8_t *)path, strlen(path), &value) == GRAIL_OK);
    CHECK(value == expected);
}

static void test_absolute(void) {
#if GRAIL_ABI_PATH_WINDOWS
    expect_absolute("C:/a", 1);
    expect_absolute("C:\\a", 1);
    expect_absolute("C:/", 1);
    expect_absolute("C:", 0);
    expect_absolute("C:a", 0);
    expect_absolute("\\a", 1);
    expect_absolute("/a", 1);
    expect_absolute("//server/share", 1);
    expect_absolute("\\\\server\\share", 1);
    expect_absolute("a", 0);
    expect_absolute("", 0);
#else
    expect_absolute("/", 1);
    expect_absolute("/a", 1);
    expect_absolute("//a", 1);
    expect_absolute("a", 0);
    expect_absolute("./a", 0);
    expect_absolute("", 0);
#endif
}

static void test_join(void) {
#if GRAIL_ABI_PATH_WINDOWS
    expect_join("C:/a", "b", "C:/a/b");
    expect_join("C:/a/", "b", "C:/a/b");
    expect_join("C:", "a", "C:a");
    expect_join("C:", "/a", "/a");
    expect_join("C:\\a", "b", "C:\\a/b");
    expect_join("//server/share", "a", "//server/share/a");
#else
    expect_join("/a", "b", "/a/b");
    expect_join("/a/", "b", "/a/b");
    expect_join("a", "/b", "/b");
    expect_join("a/", "b", "a/b");
#endif
    expect_join("", "b", "b");
    expect_join("a", "", "a");
    expect_join("", "", "");
}

static void test_parent(void) {
#if GRAIL_ABI_PATH_WINDOWS
    expect_parent("C:/", "C:/");
    expect_parent("C:/a", "C:/");
    expect_parent("C:/a/b", "C:/a");
    expect_parent("C:/a/b/", "C:/a");
    expect_parent("C:/a//b", "C:/a");
    expect_parent("C:a", "C:");
    expect_parent("C:", "C:");
    expect_parent("C:\\a\\b", "C:/a");
    expect_parent("//server/share", "//server/share");
    expect_parent("//server/share/a", "//server/share");
    expect_parent("//server/share/a/b", "//server/share/a");
    expect_parent("\\a\\b", "/a");
#else
    expect_parent("/", "/");
    expect_parent("/a", "/");
    expect_parent("/a/b", "/a");
    expect_parent("/a/b/", "/a");
    expect_parent("/a//b", "/a");
    expect_parent("a", ".");
    expect_parent("a/b/", "a");
    expect_parent("a//b", "a");
#endif
    expect_parent("", ".");
}

static void test_names(void) {
#if GRAIL_ABI_PATH_WINDOWS
    expect_name("C:/a/b", "b");
    expect_name("C:/", "");
    expect_name("C:", "");
    expect_name("C:a", "a");
    expect_name("\\\\server\\share\\x", "x");
#else
    expect_name("/a/b", "b");
    expect_name("/a/b/", "b");
    expect_name("/", "");
    expect_name("a", "a");
    expect_name(".", ".");
#endif
    expect_extension("a.txt", "txt");
    expect_extension("a.tar.gz", "gz");
    expect_extension(".bashrc", "");
    expect_extension("a.", "");
    expect_extension("a", "");
    expect_extension("/x/y.md", "md");
    expect_extension("dir.d/file", "");
}

static void test_normalize(void) {
#if GRAIL_ABI_PATH_WINDOWS
    expect("", ".");
    expect(".", ".");
    expect("C:\\a\\..\\b", "C:/b");
    expect("C:/a/../../b", "C:/b");
    expect("C:a/../b", "C:b");
    expect("C:../b", "C:../b");
    expect("C:/", "C:/");
    expect("C:", "C:");
    expect("C:/a//b", "C:/a/b");
    expect("C:/a/..", "C:/");
    expect("\\a\\b", "/a/b");
    expect("//server/share/../a", "//server/share/a");
    expect("//server/share/a/..", "//server/share");
    expect("//server\\share\\a", "//server/share/a");
#else
    expect("", ".");
    expect(".", ".");
    expect("a/./b", "a/b");
    expect("a//b", "a/b");
    expect("a/../b", "b");
    expect("a/../../b", "../b");
    expect("/a/../../b", "/b");
    expect("/", "/");
    expect("//a", "/a");
    expect("a/..", ".");
    expect("../a", "../a");
    expect("/..", "/");
    expect("a/./", "a");
    expect("a/b/..", "a");
    expect("a/b/../..", ".");
#endif
}

int main(void) {
    test_absolute();
    test_join();
    test_parent();
    test_names();
    test_normalize();
    if (failures != 0) {
        fprintf(stderr, "paths(%s): %d of %d checks failed\n",
                GRAIL_ABI_PATH_WINDOWS ? "windows" : "posix", failures, checks);
        return 1;
    }
    printf("paths(%s): %d checks passed\n", GRAIL_ABI_PATH_WINDOWS ? "windows" : "posix",
           checks);
    return 0;
}
