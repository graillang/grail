/*
 * Lexical path manipulation over UTF-8 bytes.
 *
 * ABI paths use '/' as the canonical separator on every platform.  The Windows
 * backend accepts both '/' and '\' and converts to the native separator only at
 * the syscall boundary; these helpers accept both and emit '/'.  No function
 * here touches the file system or resolves symbolic links.
 *
 * Paths are byte strings, not necessarily valid UTF-8: these helpers only
 * inspect separators.  Validate text with grail_os_utf8_validate before passing
 * it to a backend that requires valid Unicode (Windows).
 */
#ifndef GRAIL_PATH_H
#define GRAIL_PATH_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GRAIL_PATH_SEPARATOR '/'

/*
 * 1 when the path is absolute (POSIX: leading '/'; Windows: drive-absolute,
 * UNC, or rooted).  On Windows "C:name" is drive-relative and not absolute.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_path_is_absolute(const uint8_t *path, uint64_t length,
                                                           uint64_t *is_absolute);

/*
 * Concatenates base and child without normalization.  An absolute child
 * replaces base.  A drive-relative base such as "C:" does not gain a separator
 * before the child.  Returns the required length.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_path_join(const uint8_t *base, uint64_t base_length,
                                                    const uint8_t *child, uint64_t child_length,
                                                    uint8_t *out, uint64_t capacity);

/*
 * Lexical parent.  "a" -> ".", "/a" -> "/", "C:/a" -> "C:/", "C:a" -> "C:".
 * Returns the required length.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_path_parent(const uint8_t *path, uint64_t length,
                                                      uint8_t *out, uint64_t capacity);

/* Final component; empty for a root or a bare drive prefix. */
GRAIL_API grail_result GRAIL_CALL grail_os_path_file_name(const uint8_t *path, uint64_t length,
                                                         uint8_t *out, uint64_t capacity);

/* Final extension without the dot; empty for dotfiles and names without a dot. */
GRAIL_API grail_result GRAIL_CALL grail_os_path_extension(const uint8_t *path, uint64_t length,
                                                         uint8_t *out, uint64_t capacity);

/*
 * Lexical normalization: removes empty components and ".", resolves ".."
 * against preceding components without crossing the root prefix, and emits
 * '/'.  It does not resolve symlinks and does not change case.  An empty
 * result becomes ".".  At most 256 retained components are supported;
 * exceeding that returns GRAIL_E_OVERFLOW.  Returns the required length.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_path_normalize(const uint8_t *path, uint64_t length,
                                                         uint8_t *out, uint64_t capacity);

/* Working directory of the process.  Requires an initialized backend. */
GRAIL_API grail_result GRAIL_CALL grail_os_path_current_directory(uint8_t *out, uint64_t capacity);

/* Changes the process working directory.  Requires an initialized backend. */
GRAIL_API grail_status GRAIL_CALL grail_os_path_set_current_directory(const uint8_t *path,
                                                                     uint64_t length);

/* Absolute path of the running executable.  Requires an initialized backend. */
GRAIL_API grail_result GRAIL_CALL grail_os_path_executable(uint8_t *out, uint64_t capacity);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_PATH_H */
