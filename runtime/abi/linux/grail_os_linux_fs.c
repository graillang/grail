/*
 * Linux reference backend: files, directories, pipes and path metadata.
 * Hosted C oracle for the ABI contract; see runtime/abi/README.md.
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "grail_os_linux.h"

typedef struct grail_linux_file {
    int descriptor;
    uint64_t kind;
} grail_linux_file;

typedef struct grail_linux_dir {
    DIR *stream;
    char *path;
    char *current;
    uint64_t current_kind;
    int current_valid;
    char *next;
    uint64_t next_kind;
    int next_valid;
    int eof;
} grail_linux_dir;

static int grail_path_has_zero(const uint8_t *path, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (path[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static char *grail_fs_path(const uint8_t *path, uint64_t length) {
    if (path == NULL || grail_path_has_zero(path, length)) {
        return NULL;
    }
    return grail_linux_copy_text(path, length);
}

static grail_status grail_file_lookup(grail_file handle, grail_linux_file **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.files, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

static uint64_t grail_kind_from_mode(mode_t mode) {
    if (S_ISREG(mode)) {
        return GRAIL_FILE_KIND_FILE;
    }
    if (S_ISDIR(mode)) {
        return GRAIL_FILE_KIND_DIRECTORY;
    }
    if (S_ISLNK(mode)) {
        return GRAIL_FILE_KIND_SYMLINK;
    }
    if (S_ISBLK(mode)) {
        return GRAIL_FILE_KIND_BLOCK;
    }
    if (S_ISCHR(mode)) {
        return GRAIL_FILE_KIND_CHARACTER;
    }
    if (S_ISFIFO(mode)) {
        return GRAIL_FILE_KIND_FIFO;
    }
    if (S_ISSOCK(mode)) {
        return GRAIL_FILE_KIND_SOCKET;
    }
    return GRAIL_FILE_KIND_UNKNOWN;
}

static int64_t grail_seconds_to_ns(time_t seconds, long nanoseconds) {
    if (seconds > (time_t)(INT64_MAX / 1000000000) ||
        seconds < (time_t)(INT64_MIN / 1000000000)) {
        return 0;
    }
    return (int64_t)seconds * 1000000000 + nanoseconds;
}

static void grail_fill_stat(const struct stat *source, grail_file_stat *out) {
    memset(out, 0, sizeof(*out));
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    out->kind = grail_kind_from_mode(source->st_mode);
    out->size = (uint64_t)source->st_size;
    out->mode = (uint64_t)(source->st_mode & 07777);
    out->link_count = (uint64_t)source->st_nlink;
    out->device = (uint64_t)source->st_dev;
    out->inode = (uint64_t)source->st_ino;
    out->modified_ns = grail_seconds_to_ns(source->st_mtime, source->st_mtim.tv_nsec);
    out->accessed_ns = grail_seconds_to_ns(source->st_atime, source->st_atim.tv_nsec);
    out->created_ns = 0;
    if ((source->st_mode & S_IWUSR) == 0) {
        out->flags |= GRAIL_STAT_READ_ONLY;
    }
    if ((source->st_mode & S_IXUSR) != 0) {
        out->flags |= GRAIL_STAT_EXECUTABLE;
    }
    if (S_ISLNK(source->st_mode)) {
        out->flags |= GRAIL_STAT_SYMLINK;
    }
}

static int grail_name_is_hidden(const char *path) {
    const char *base = path;
    for (const char *cursor = path; *cursor != '\0'; cursor++) {
        if (*cursor == '/') {
            base = cursor + 1;
        }
    }
    return base[0] == '.' && base[1] != '\0' &&
           !(base[1] == '.' && base[2] == '\0');
}

grail_status grail_os_file_open(const uint8_t *path, uint64_t path_length, uint64_t flags,
                                uint64_t mode, grail_file *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const int read = (flags & GRAIL_OPEN_READ) != 0;
    const int write = (flags & GRAIL_OPEN_WRITE) != 0;
    if (!read && !write) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    int access = O_RDONLY;
    if (read && write) {
        access = O_RDWR;
    } else if (write) {
        access = O_WRONLY;
    }
    int status = access | O_CLOEXEC;
    if ((flags & GRAIL_OPEN_CREATE) != 0) {
        status |= O_CREAT;
    }
    if ((flags & GRAIL_OPEN_TRUNCATE) != 0) {
        status |= O_TRUNC;
    }
    if ((flags & GRAIL_OPEN_APPEND) != 0) {
        status |= O_APPEND;
    }
    if ((flags & GRAIL_OPEN_EXCLUSIVE) != 0) {
        status |= O_EXCL;
    }
    if ((flags & GRAIL_OPEN_DIRECTORY) != 0) {
        status |= O_DIRECTORY;
    }
    if ((flags & GRAIL_OPEN_NO_FOLLOW) != 0) {
        status |= O_NOFOLLOW;
    }
    if ((flags & GRAIL_OPEN_SYNC) != 0) {
        status |= O_SYNC;
    }
    if ((flags & GRAIL_OPEN_NONBLOCKING) != 0) {
        status |= O_NONBLOCK;
    }
    const mode_t creation = mode == 0 ? (mode_t)0666 : (mode_t)(mode & 07777);
    const int descriptor = open(text, status, creation);
    const int error_number = errno;
    grail_linux_free_text(text);
    if (descriptor < 0) {
        return grail_linux_errno(error_number);
    }
    struct stat metadata;
    uint64_t kind = GRAIL_FILE_KIND_UNKNOWN;
    if (fstat(descriptor, &metadata) == 0) {
        kind = grail_kind_from_mode(metadata.st_mode);
    }
    grail_linux_file *file = (grail_linux_file *)grail_linux_allocate(sizeof(*file));
    if (file == NULL) {
        close(descriptor);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    file->descriptor = descriptor;
    file->kind = kind;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status allocated =
        grail_handle_table_allocate(&grail_linux.files, file, &handle);
    grail_linux_unlock();
    if (allocated != GRAIL_OK) {
        close(descriptor);
        grail_linux_release(file, sizeof(*file));
        return allocated;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_file_read(grail_file handle, uint8_t *buffer, uint64_t capacity,
                                uint64_t *read_length) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (read_length == NULL || (buffer == NULL && capacity != 0) ||
        capacity > (uint64_t)SSIZE_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (capacity == 0) {
        *read_length = 0;
        return GRAIL_OK;
    }
    const ssize_t count = read(file->descriptor, buffer, (size_t)capacity);
    if (count < 0) {
        return grail_linux_errno(errno);
    }
    *read_length = (uint64_t)count;
    return GRAIL_OK;
}

grail_status grail_os_file_write(grail_file handle, const uint8_t *buffer, uint64_t length,
                                 uint64_t *written_length) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (written_length == NULL || (buffer == NULL && length != 0) || length > (uint64_t)SSIZE_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (length == 0) {
        *written_length = 0;
        return GRAIL_OK;
    }
    const ssize_t count = write(file->descriptor, buffer, (size_t)length);
    if (count < 0) {
        return grail_linux_errno(errno);
    }
    *written_length = (uint64_t)count;
    return GRAIL_OK;
}

grail_status grail_os_file_seek(grail_file handle, int64_t offset, uint64_t whence,
                                uint64_t *position) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (position == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    int origin;
    switch (whence) {
    case GRAIL_SEEK_SET:
        origin = SEEK_SET;
        break;
    case GRAIL_SEEK_CURRENT:
        origin = SEEK_CUR;
        break;
    case GRAIL_SEEK_END:
        origin = SEEK_END;
        break;
    default:
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const off_t result = lseek(file->descriptor, (off_t)offset, origin);
    if (result < 0) {
        return grail_linux_errno(errno);
    }
    *position = (uint64_t)result;
    return GRAIL_OK;
}

grail_status grail_os_file_truncate(grail_file handle, uint64_t length) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (ftruncate(file->descriptor, (off_t)length) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_file_sync(grail_file handle, uint64_t data_only) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    const int result =
        data_only != 0 ? fdatasync(file->descriptor) : fsync(file->descriptor);
    if (result != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_file_set_nonblocking(grail_file handle, uint64_t enabled) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    int flags = fcntl(file->descriptor, F_GETFL);
    if (flags < 0) {
        return grail_linux_errno(errno);
    }
    if (enabled != 0) {
        flags |= O_NONBLOCK;
    } else {
        flags &= ~O_NONBLOCK;
    }
    if (fcntl(file->descriptor, F_SETFL, flags) != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

grail_status grail_os_file_stat(grail_file handle, grail_file_stat *out) {
    grail_linux_file *file = NULL;
    grail_status status = grail_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct stat metadata;
    if (fstat(file->descriptor, &metadata) != 0) {
        return grail_linux_errno(errno);
    }
    grail_fill_stat(&metadata, out);
    return GRAIL_OK;
}

grail_status grail_os_file_close(grail_file handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_file *file = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_release(&grail_linux.files, handle, (void **)&file);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int result = close(file->descriptor);
    const int error_number = errno;
    grail_linux_release(file, sizeof(*file));
    return result == 0 ? GRAIL_OK : grail_linux_errno(error_number);
}

static grail_status grail_pipe_end(int descriptor, grail_file *out) {
    grail_linux_file *file = (grail_linux_file *)grail_linux_allocate(sizeof(*file));
    if (file == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    file->descriptor = descriptor;
    file->kind = GRAIL_FILE_KIND_FIFO;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status = grail_handle_table_allocate(&grail_linux.files, file, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        grail_linux_release(file, sizeof(*file));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_pipe(grail_pipe *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    int ends[2];
    if (pipe2(ends, O_CLOEXEC) != 0) {
        return grail_linux_errno(errno);
    }
    grail_file read_end = GRAIL_HANDLE_NONE;
    grail_status status = grail_pipe_end(ends[0], &read_end);
    if (status != GRAIL_OK) {
        close(ends[0]);
        close(ends[1]);
        return status;
    }
    grail_file write_end = GRAIL_HANDLE_NONE;
    status = grail_pipe_end(ends[1], &write_end);
    if (status != GRAIL_OK) {
        grail_linux_file *file = NULL;
        grail_linux_lock();
        grail_handle_table_release(&grail_linux.files, read_end, (void **)&file);
        grail_linux_unlock();
        if (file != NULL) {
            close(file->descriptor);
            grail_linux_release(file, sizeof(*file));
        }
        close(ends[1]);
        return status;
    }
    out->read_end = read_end;
    out->write_end = write_end;
    return GRAIL_OK;
}

grail_status grail_os_fs_stat(const uint8_t *path, uint64_t path_length, uint64_t flags,
                              grail_file_stat *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct stat metadata;
    const int result = flags == GRAIL_STAT_NO_FOLLOW ? lstat(text, &metadata)
                                                     : stat(text, &metadata);
    const int error_number = errno;
    if (result != 0) {
        grail_linux_free_text(text);
        return grail_linux_errno(error_number);
    }
    grail_fill_stat(&metadata, out);
    if (grail_name_is_hidden(text)) {
        out->flags |= GRAIL_STAT_HIDDEN;
    }
    grail_linux_free_text(text);
    return GRAIL_OK;
}

grail_status grail_os_fs_mkdir(const uint8_t *path, uint64_t path_length, uint64_t mode,
                               uint64_t flags) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const mode_t creation = mode == 0 ? (mode_t)0777 : (mode_t)(mode & 07777);
    grail_status status = GRAIL_OK;
    if ((flags & GRAIL_MKDIR_PARENTS) == 0) {
        if (mkdir(text, creation) != 0) {
            status = grail_linux_errno(errno);
        }
    } else {
        char *cursor = text;
        if (*cursor == '/') {
            cursor++;
        }
        for (;;) {
            if (*cursor == '/' || *cursor == '\0') {
                const char saved = *cursor;
                *cursor = '\0';
                if (text[0] != '\0' && mkdir(text, creation) != 0 && errno != EEXIST) {
                    status = grail_linux_errno(errno);
                }
                *cursor = saved;
                if (saved == '\0' || status != GRAIL_OK) {
                    break;
                }
            }
            cursor++;
        }
    }
    grail_linux_free_text(text);
    return status;
}

grail_status grail_os_fs_remove_file(const uint8_t *path, uint64_t path_length) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const int result = unlink(text);
    const int error_number = errno;
    grail_linux_free_text(text);
    return result == 0 ? GRAIL_OK : grail_linux_errno(error_number);
}

grail_status grail_os_fs_remove_dir(const uint8_t *path, uint64_t path_length) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const int result = rmdir(text);
    const int error_number = errno;
    grail_linux_free_text(text);
    return result == 0 ? GRAIL_OK : grail_linux_errno(error_number);
}

grail_status grail_os_fs_rename(const uint8_t *from, uint64_t from_length, const uint8_t *to,
                                uint64_t to_length, uint64_t flags) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    char *from_text = grail_fs_path(from, from_length);
    char *to_text = grail_fs_path(to, to_length);
    if (from_text == NULL || to_text == NULL) {
        grail_linux_free_text(from_text);
        grail_linux_free_text(to_text);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((flags & GRAIL_RENAME_REPLACE) == 0) {
        struct stat metadata;
        if (lstat(to_text, &metadata) == 0) {
            grail_linux_free_text(from_text);
            grail_linux_free_text(to_text);
            return grail_linux_errno(EEXIST);
        }
    }
    const int result = rename(from_text, to_text);
    const int error_number = errno;
    grail_linux_free_text(from_text);
    grail_linux_free_text(to_text);
    return result == 0 ? GRAIL_OK : grail_linux_errno(error_number);
}

grail_result grail_os_fs_readlink(const uint8_t *path, uint64_t path_length, uint8_t *out,
                                  uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t size = 256;
    while (size <= 1048576) {
        char *buffer = (char *)grail_linux_allocate(size);
        if (buffer == NULL) {
            grail_linux_free_text(text);
            return GRAIL_E_OUT_OF_MEMORY;
        }
        const ssize_t length = readlink(text, buffer, (size_t)size - 1);
        if (length >= 0) {
            if ((uint64_t)length < size - 1) {
                buffer[length] = '\0';
                const grail_result result =
                    grail_abi_copy_out((const uint8_t *)buffer, (uint64_t)length, out, capacity);
                grail_linux_release(buffer, size);
                grail_linux_free_text(text);
                return result;
            }
            grail_linux_release(buffer, size);
            size *= 2;
            continue;
        }
        const int error_number = errno;
        grail_linux_release(buffer, size);
        if (error_number != ENAMETOOLONG) {
            grail_linux_free_text(text);
            return grail_linux_errno(error_number);
        }
        size *= 2;
    }
    grail_linux_free_text(text);
    return GRAIL_E_NAME_TOO_LONG;
}

grail_result grail_os_fs_realpath(const uint8_t *path, uint64_t path_length, uint8_t *out,
                                  uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *resolved = realpath(text, NULL);
    const int error_number = errno;
    grail_linux_free_text(text);
    if (resolved == NULL) {
        return grail_linux_errno(error_number);
    }
    const grail_result result =
        grail_abi_copy_out((const uint8_t *)resolved, strlen(resolved), out, capacity);
    free(resolved);
    return result;
}

static uint64_t grail_kind_from_dirent(const struct dirent *entry, DIR *stream) {
    switch (entry->d_type) {
    case DT_REG:
        return GRAIL_FILE_KIND_FILE;
    case DT_DIR:
        return GRAIL_FILE_KIND_DIRECTORY;
    case DT_LNK:
        return GRAIL_FILE_KIND_SYMLINK;
    case DT_BLK:
        return GRAIL_FILE_KIND_BLOCK;
    case DT_CHR:
        return GRAIL_FILE_KIND_CHARACTER;
    case DT_FIFO:
        return GRAIL_FILE_KIND_FIFO;
    case DT_SOCK:
        return GRAIL_FILE_KIND_SOCKET;
    default: {
        struct stat metadata;
        if (fstatat(dirfd(stream), entry->d_name, &metadata, AT_SYMLINK_NOFOLLOW) == 0) {
            return grail_kind_from_mode(metadata.st_mode);
        }
        return GRAIL_FILE_KIND_UNKNOWN;
    }
    }
}

/* Returns 1 with a newly allocated name, 0 at end, -1 on error. */
static int grail_dir_read(grail_linux_dir *directory, char **name, uint64_t *kind) {
    for (;;) {
        errno = 0;
        const struct dirent *entry = readdir(directory->stream);
        if (entry == NULL) {
            if (errno != 0) {
                grail_linux_errno(errno);
                return -1;
            }
            return 0;
        }
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        char *copy = grail_linux_copy_text((const uint8_t *)entry->d_name,
                                           strlen(entry->d_name));
        if (copy == NULL) {
            return -1;
        }
        *name = copy;
        *kind = grail_kind_from_dirent(entry, directory->stream);
        return 1;
    }
}

static grail_status grail_dir_lookup(grail_dir handle, grail_linux_dir **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.directories, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

grail_status grail_os_dir_open(const uint8_t *path, uint64_t path_length, grail_dir *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_fs_path(path, path_length);
    if (text == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    DIR *stream = opendir(text);
    const int error_number = errno;
    if (stream == NULL) {
        grail_linux_free_text(text);
        return grail_linux_errno(error_number);
    }
    grail_linux_dir *directory = (grail_linux_dir *)grail_linux_allocate(sizeof(*directory));
    if (directory == NULL) {
        closedir(stream);
        grail_linux_free_text(text);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    memset(directory, 0, sizeof(*directory));
    directory->stream = stream;
    directory->path = text;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.directories, directory, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        closedir(stream);
        grail_linux_free_text(text);
        grail_linux_release(directory, sizeof(*directory));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_result grail_os_dir_next(grail_dir handle, uint8_t *name, uint64_t capacity,
                               grail_dir_entry *out) {
    grail_linux_dir *directory = NULL;
    grail_status status = grail_dir_lookup(handle, &directory);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out == NULL || (name == NULL && capacity != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (!directory->current_valid) {
        if (directory->eof) {
            memset(out, 0, sizeof(*out));
            out->struct_size = sizeof(*out);
            out->abi_version = GRAIL_ABI_VERSION;
            out->is_last = 1;
            return 0;
        }
        char *first = NULL;
        uint64_t kind = GRAIL_FILE_KIND_UNKNOWN;
        const int read = grail_dir_read(directory, &first, &kind);
        if (read < 0) {
            return GRAIL_E_SYSTEM;
        }
        if (read == 0) {
            directory->eof = 1;
            memset(out, 0, sizeof(*out));
            out->struct_size = sizeof(*out);
            out->abi_version = GRAIL_ABI_VERSION;
            out->is_last = 1;
            return 0;
        }
        directory->current = first;
        directory->current_kind = kind;
        directory->current_valid = 1;
    }
    if (!directory->next_valid && !directory->eof) {
        char *following = NULL;
        uint64_t kind = GRAIL_FILE_KIND_UNKNOWN;
        const int read = grail_dir_read(directory, &following, &kind);
        if (read < 0) {
            return GRAIL_E_SYSTEM;
        }
        if (read == 0) {
            directory->eof = 1;
        } else {
            directory->next = following;
            directory->next_kind = kind;
            directory->next_valid = 1;
        }
    }
    const uint64_t length = strlen(directory->current);
    memset(out, 0, sizeof(*out));
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    out->name_length = length;
    out->kind = directory->current_kind;
    out->is_last = (directory->eof && !directory->next_valid) ? 1 : 0;
    if (length > capacity || name == NULL) {
        return (grail_result)length;
    }
    memcpy(name, directory->current, (size_t)length);
    grail_linux_free_text(directory->current);
    directory->current = directory->next;
    directory->current_kind = directory->next_kind;
    directory->current_valid = directory->next_valid;
    directory->next = NULL;
    directory->next_valid = 0;
    if (!directory->current_valid) {
        directory->current = NULL;
    }
    return (grail_result)length;
}

grail_status grail_os_dir_close(grail_dir handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_dir *directory = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_release(&grail_linux.directories, handle, (void **)&directory);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    if (directory->stream != NULL) {
        closedir(directory->stream);
    }
    grail_linux_free_text(directory->current);
    grail_linux_free_text(directory->next);
    grail_linux_free_text(directory->path);
    grail_linux_release(directory, sizeof(*directory));
    return GRAIL_OK;
}
