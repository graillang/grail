/*
 * Minimal, pinned Darwin/libSystem declarations for the Grail OS ABI backend.
 *
 * This host has no macOS SDK, so the backend declares exactly the libSystem
 * surface it uses instead of including <fcntl.h>, <unistd.h> or <sys/stat.h>.
 * Types and constants match 64-bit Darwin.  No struct stat is declared because
 * the macOS first layer does not implement metadata; adding it later requires a
 * struct layout verified against the SDK.
 */
#ifndef GRAIL_MACOS_H
#define GRAIL_MACOS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t grail_macos_off_t;
typedef int64_t grail_macos_ssize_t;
typedef uint16_t grail_macos_mode_t;

typedef struct grail_macos_timeval {
    int64_t tv_sec;
    int32_t tv_usec;
} grail_macos_timeval;

typedef struct grail_macos_timespec {
    int64_t tv_sec;
    int64_t tv_nsec;
} grail_macos_timespec;

typedef struct grail_macos_unfair_lock {
    uint32_t opaque;
} grail_macos_unfair_lock;

/* Darwin open/fcntl values. */
#define GRAIL_MACOS_O_RDONLY 0x0000
#define GRAIL_MACOS_O_WRONLY 0x0001
#define GRAIL_MACOS_O_RDWR 0x0002
#define GRAIL_MACOS_O_NONBLOCK 0x0004
#define GRAIL_MACOS_O_APPEND 0x0008
#define GRAIL_MACOS_O_SYNC 0x0080
#define GRAIL_MACOS_O_NOFOLLOW 0x0100
#define GRAIL_MACOS_O_CREAT 0x0200
#define GRAIL_MACOS_O_TRUNC 0x0400
#define GRAIL_MACOS_O_EXCL 0x0800
#define GRAIL_MACOS_O_DIRECTORY 0x100000
#define GRAIL_MACOS_O_CLOEXEC 0x1000000
#define GRAIL_MACOS_F_GETFL 3
#define GRAIL_MACOS_F_SETFL 4
#define GRAIL_MACOS_F_SETFD 2
#define GRAIL_MACOS_FD_CLOEXEC 1
#define GRAIL_MACOS_SEEK_SET 0
#define GRAIL_MACOS_SEEK_CURRENT 1
#define GRAIL_MACOS_SEEK_END 2

/* Darwin clock identifiers. */
#define GRAIL_MACOS_CLOCK_REALTIME 0
#define GRAIL_MACOS_CLOCK_MONOTONIC 6
#define GRAIL_MACOS_CLOCK_PROCESS_CPUTIME_ID 12
#define GRAIL_MACOS_CLOCK_THREAD_CPUTIME_ID 16

/* Darwin errno values used by the first-layer mapping. */
#define GRAIL_MACOS_EPERM 1
#define GRAIL_MACOS_ENOENT 2
#define GRAIL_MACOS_ESRCH 3
#define GRAIL_MACOS_EINTR 4
#define GRAIL_MACOS_EIO 5
#define GRAIL_MACOS_ENOMEM 12
#define GRAIL_MACOS_EACCES 13
#define GRAIL_MACOS_EBUSY 16
#define GRAIL_MACOS_EEXIST 17
#define GRAIL_MACOS_EXDEV 18
#define GRAIL_MACOS_ENOTDIR 20
#define GRAIL_MACOS_EISDIR 21
#define GRAIL_MACOS_EINVAL 22
#define GRAIL_MACOS_EMFILE 24
#define GRAIL_MACOS_ENOSPC 28
#define GRAIL_MACOS_ESPIPE 29
#define GRAIL_MACOS_EROFS 30
#define GRAIL_MACOS_EPIPE 32
#define GRAIL_MACOS_ERANGE 34
#define GRAIL_MACOS_EAGAIN 35
#define GRAIL_MACOS_EINPROGRESS 36
#define GRAIL_MACOS_EALREADY 37
#define GRAIL_MACOS_ENOTSOCK 38
#define GRAIL_MACOS_EMSGSIZE 40
#define GRAIL_MACOS_ENOPROTOOPT 42
#define GRAIL_MACOS_EPROTONOSUPPORT 43
#define GRAIL_MACOS_ENOTSUP 45
#define GRAIL_MACOS_EAFNOSUPPORT 47
#define GRAIL_MACOS_EADDRINUSE 48
#define GRAIL_MACOS_EADDRNOTAVAIL 49
#define GRAIL_MACOS_ENETUNREACH 51
#define GRAIL_MACOS_ECONNABORTED 53
#define GRAIL_MACOS_ECONNRESET 54
#define GRAIL_MACOS_ENOTCONN 57
#define GRAIL_MACOS_ESHUTDOWN 58
#define GRAIL_MACOS_ETIMEDOUT 60
#define GRAIL_MACOS_ECONNREFUSED 61
#define GRAIL_MACOS_ELOOP 62
#define GRAIL_MACOS_ENAMETOOLONG 63
#define GRAIL_MACOS_ENOTEMPTY 66
#define GRAIL_MACOS_ENOSYS 78
#define GRAIL_MACOS_EOVERFLOW 84
#define GRAIL_MACOS_ECANCELED 89

int open(const char *path, int flags, ...);
int close(int descriptor);
grail_macos_ssize_t read(int descriptor, void *buffer, uint64_t length);
grail_macos_ssize_t write(int descriptor, const void *buffer, uint64_t length);
grail_macos_off_t lseek(int descriptor, grail_macos_off_t offset, int whence);
int ftruncate(int descriptor, grail_macos_off_t length);
int fsync(int descriptor);
int fcntl(int descriptor, int command, ...);
int pipe(int descriptors[2]);
int mkdir(const char *path, grail_macos_mode_t mode);
int rmdir(const char *path);
int unlink(const char *path);
int rename(const char *from, const char *to);
grail_macos_ssize_t readlink(const char *path, char *buffer, uint64_t length);
char *realpath(const char *path, char *resolved);
char *getcwd(char *buffer, uint64_t length);
int chdir(const char *path);
int _NSGetExecutablePath(char *buffer, uint32_t *length);
int clock_gettime(int clock, grail_macos_timespec *value);
int clock_getres(int clock, grail_macos_timespec *value);
int nanosleep(const grail_macos_timespec *request, grail_macos_timespec *remainder);
int access(const char *path, int mode);
int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
int *__error(void);
void os_unfair_lock_lock(grail_macos_unfair_lock *lock);
void os_unfair_lock_unlock(grail_macos_unfair_lock *lock);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_MACOS_H */
