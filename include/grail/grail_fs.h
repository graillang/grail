/*
 * Files, directories and pipes.
 *
 * Paths are UTF-8 with '/' as the canonical separator (see grail_path.h).
 * Handles are linear: each one is closed exactly once by its closer, and a
 * stale or foreign handle returns GRAIL_E_INVALID_HANDLE rather than
 * undefined behaviour.  File operations are blocking unless the handle was
 * opened with GRAIL_OPEN_NONBLOCKING or switched with file_set_nonblocking.
 *
 * Byte reads and writes may be partial.  A read returning 0 bytes is clean
 * end-of-file.  The ABI does not loop on the caller's behalf.
 */
#ifndef GRAIL_FS_H
#define GRAIL_FS_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef grail_handle grail_file;
typedef grail_handle grail_dir;

/* Open flags. */
#define GRAIL_OPEN_READ (1ull << 0)
#define GRAIL_OPEN_WRITE (1ull << 1)
#define GRAIL_OPEN_CREATE (1ull << 2)
#define GRAIL_OPEN_TRUNCATE (1ull << 3)
#define GRAIL_OPEN_APPEND (1ull << 4)
#define GRAIL_OPEN_EXCLUSIVE (1ull << 5)
#define GRAIL_OPEN_DIRECTORY (1ull << 6)
#define GRAIL_OPEN_NO_FOLLOW (1ull << 7)
#define GRAIL_OPEN_SYNC (1ull << 8)
#define GRAIL_OPEN_NONBLOCKING (1ull << 9)

/* Seek origins. */
#define GRAIL_SEEK_SET 0u
#define GRAIL_SEEK_CURRENT 1u
#define GRAIL_SEEK_END 2u

/* File kinds reported by stat and directory iteration. */
#define GRAIL_FILE_KIND_UNKNOWN 0u
#define GRAIL_FILE_KIND_FILE 1u
#define GRAIL_FILE_KIND_DIRECTORY 2u
#define GRAIL_FILE_KIND_SYMLINK 3u
#define GRAIL_FILE_KIND_BLOCK 4u
#define GRAIL_FILE_KIND_CHARACTER 5u
#define GRAIL_FILE_KIND_FIFO 6u
#define GRAIL_FILE_KIND_SOCKET 7u

/* Portable stat flags. */
#define GRAIL_STAT_READ_ONLY (1ull << 0)
#define GRAIL_STAT_HIDDEN (1ull << 1)
#define GRAIL_STAT_EXECUTABLE (1ull << 2)
#define GRAIL_STAT_SYMLINK (1ull << 3)

/* stat/lstat selection for fs_stat. */
#define GRAIL_STAT_FOLLOW_SYMLINKS 0u
#define GRAIL_STAT_NO_FOLLOW 1u

/* mkdir flags. */
#define GRAIL_MKDIR_PARENTS (1ull << 0)

/* rename flags. */
#define GRAIL_RENAME_REPLACE (1ull << 0)

typedef struct grail_file_stat {
    uint64_t struct_size; /* sizeof(grail_file_stat) */
    uint64_t abi_version;
    uint64_t kind;        /* GRAIL_FILE_KIND_* */
    uint64_t flags;       /* GRAIL_STAT_* */
    uint64_t size;        /* bytes */
    uint64_t mode;        /* permission bits in the low 12 bits */
    uint64_t link_count;
    uint64_t device;
    uint64_t inode;
    int64_t modified_ns;  /* UTC since 1970, 0 when unavailable */
    int64_t accessed_ns;
    int64_t created_ns;   /* birth time; 0 when unavailable */
} grail_file_stat;

typedef struct grail_pipe {
    grail_file read_end;
    grail_file write_end;
} grail_pipe;

typedef struct grail_dir_entry {
    uint64_t struct_size; /* sizeof(grail_dir_entry) */
    uint64_t abi_version;
    uint64_t name_length;
    uint64_t kind;        /* GRAIL_FILE_KIND_*; valid even on buffer-too-small */
    uint64_t is_last;     /* 1 after the final entry */
} grail_dir_entry;

/*
 * Opens a file.  `mode` is used only with GRAIL_OPEN_CREATE and is subject to
 * the process umask; the backend ignores unsupported permission bits.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_file_open(const uint8_t *path, uint64_t path_length,
                                                     uint64_t flags, uint64_t mode,
                                                     grail_file *out);
GRAIL_API grail_status GRAIL_CALL grail_os_file_read(grail_file file, uint8_t *buffer,
                                                     uint64_t capacity, uint64_t *read_length);
GRAIL_API grail_status GRAIL_CALL grail_os_file_write(grail_file file, const uint8_t *buffer,
                                                      uint64_t length, uint64_t *written_length);
GRAIL_API grail_status GRAIL_CALL grail_os_file_seek(grail_file file, int64_t offset,
                                                     uint64_t whence, uint64_t *position);
GRAIL_API grail_status GRAIL_CALL grail_os_file_truncate(grail_file file, uint64_t length);
GRAIL_API grail_status GRAIL_CALL grail_os_file_sync(grail_file file, uint64_t data_only);
GRAIL_API grail_status GRAIL_CALL grail_os_file_set_nonblocking(grail_file file, uint64_t enabled);
GRAIL_API grail_status GRAIL_CALL grail_os_file_stat(grail_file file, grail_file_stat *out);

/* Consumes the handle.  A second close returns GRAIL_E_INVALID_HANDLE. */
GRAIL_API grail_status GRAIL_CALL grail_os_file_close(grail_file file);

/* Creates a unidirectional pipe; both ends are owned handles. */
GRAIL_API grail_status GRAIL_CALL grail_os_pipe(grail_pipe *out);

/* Path metadata.  `flags` is GRAIL_STAT_FOLLOW_SYMLINKS or GRAIL_STAT_NO_FOLLOW. */
GRAIL_API grail_status GRAIL_CALL grail_os_fs_stat(const uint8_t *path, uint64_t path_length,
                                                   uint64_t flags, grail_file_stat *out);
GRAIL_API grail_status GRAIL_CALL grail_os_fs_mkdir(const uint8_t *path, uint64_t path_length,
                                                    uint64_t mode, uint64_t flags);
GRAIL_API grail_status GRAIL_CALL grail_os_fs_remove_file(const uint8_t *path,
                                                          uint64_t path_length);
/* Removes an empty directory; recursive removal is deliberately absent. */
GRAIL_API grail_status GRAIL_CALL grail_os_fs_remove_dir(const uint8_t *path,
                                                         uint64_t path_length);
GRAIL_API grail_status GRAIL_CALL grail_os_fs_rename(const uint8_t *from, uint64_t from_length,
                                                     const uint8_t *to, uint64_t to_length,
                                                     uint64_t flags);
GRAIL_API grail_result GRAIL_CALL grail_os_fs_readlink(const uint8_t *path, uint64_t path_length,
                                                       uint8_t *out, uint64_t capacity);
GRAIL_API grail_result GRAIL_CALL grail_os_fs_realpath(const uint8_t *path, uint64_t path_length,
                                                       uint8_t *out, uint64_t capacity);

GRAIL_API grail_status GRAIL_CALL grail_os_dir_open(const uint8_t *path, uint64_t path_length,
                                                    grail_dir *out);
/*
 * Returns the next entry name (without a trailing separator) and fills `entry`.
 * "." and ".." are never returned.  On buffer-too-small the required length is
 * returned, nothing is written and iteration does not advance; `entry.kind` and
 * `entry.is_last` remain valid.  End of directory returns 0 with is_last=1.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_dir_next(grail_dir dir, uint8_t *name,
                                                    uint64_t capacity, grail_dir_entry *out);
/* Consumes the handle. */
GRAIL_API grail_status GRAIL_CALL grail_os_dir_close(grail_dir dir);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_FS_H */
