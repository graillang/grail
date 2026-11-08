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

typedef struct grail_macos_dir grail_macos_dir;

typedef struct grail_macos_dirent {
    uint64_t d_ino;
    uint64_t d_seekoff;
    uint16_t d_reclen;
    uint16_t d_namlen;
    uint8_t d_type;
    char d_name[256];
} grail_macos_dirent;

typedef void *grail_macos_pthread_t;
typedef struct grail_macos_pthread_mutex {
    uint64_t opaque[8];
} grail_macos_pthread_mutex_t;
typedef struct grail_macos_pthread_cond {
    uint64_t opaque[8];
} grail_macos_pthread_cond_t;
typedef struct grail_macos_pthread_attr {
    uint64_t opaque[8];
} grail_macos_pthread_attr_t;

typedef struct grail_macos_tm {
    int32_t tm_sec;
    int32_t tm_min;
    int32_t tm_hour;
    int32_t tm_mday;
    int32_t tm_mon;
    int32_t tm_year;
    int32_t tm_wday;
    int32_t tm_yday;
    int32_t tm_isdst;
    int32_t padding;
    int64_t tm_gmtoff;
    const char *tm_zone;
} grail_macos_tm;

typedef uint32_t grail_macos_socklen_t;

typedef struct grail_macos_sockaddr {
    uint8_t sa_len;
    uint8_t sa_family;
    char sa_data[14];
} grail_macos_sockaddr;

typedef struct grail_macos_sockaddr_in {
    uint8_t sin_len;
    uint8_t sin_family;
    uint16_t sin_port;
    uint32_t sin_addr;
    uint8_t sin_zero[8];
} grail_macos_sockaddr_in;

typedef struct grail_macos_sockaddr_in6 {
    uint8_t sin6_len;
    uint8_t sin6_family;
    uint16_t sin6_port;
    uint32_t sin6_flowinfo;
    uint8_t sin6_addr[16];
    uint32_t sin6_scope_id;
} grail_macos_sockaddr_in6;

typedef struct grail_macos_linger {
    int32_t l_onoff;
    int32_t l_linger;
} grail_macos_linger;

typedef void *grail_macos_spawn_file_actions_t;
typedef void *grail_macos_spawnattr_t;

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
#define GRAIL_MACOS_ENOBUFS 55
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
#define GRAIL_MACOS_DT_UNKNOWN 0
#define GRAIL_MACOS_DT_FIFO 1
#define GRAIL_MACOS_DT_CHR 2
#define GRAIL_MACOS_DT_DIR 4
#define GRAIL_MACOS_DT_BLK 6
#define GRAIL_MACOS_DT_REG 8
#define GRAIL_MACOS_DT_LNK 10
#define GRAIL_MACOS_DT_SOCK 12
#define GRAIL_MACOS_RTLD_LAZY 0x1
#define GRAIL_MACOS_RTLD_NOW 0x2
#define GRAIL_MACOS_RTLD_LOCAL 0x4
#define GRAIL_MACOS_RTLD_GLOBAL 0x8
#define GRAIL_MACOS_POSIX_SPAWN_SETPGROUP 0x0002
#define GRAIL_MACOS_WNOHANG 0x0001
#define GRAIL_MACOS_SIGTERM 15
#define GRAIL_MACOS_SIGKILL 9
#define GRAIL_MACOS_F_OK 0
#define GRAIL_MACOS_X_OK 1
#define GRAIL_MACOS_AF_INET 2
#define GRAIL_MACOS_AF_INET6 30
#define GRAIL_MACOS_SOCK_STREAM 1
#define GRAIL_MACOS_SOCK_DGRAM 2
#define GRAIL_MACOS_IPPROTO_TCP 6
#define GRAIL_MACOS_SOL_SOCKET 0xFFFF
#define GRAIL_MACOS_SO_REUSEADDR 0x0004
#define GRAIL_MACOS_SO_KEEPALIVE 0x0008
#define GRAIL_MACOS_SO_BROADCAST 0x0020
#define GRAIL_MACOS_SO_LINGER 0x0080
#define GRAIL_MACOS_SO_REUSEPORT 0x0200
#define GRAIL_MACOS_SO_SNDTIMEO 0x1005
#define GRAIL_MACOS_SO_RCVTIMEO 0x1006
#define GRAIL_MACOS_SO_NOSIGPIPE 0x1022
#define GRAIL_MACOS_TCP_NODELAY 0x01
#define GRAIL_MACOS_SHUT_RD 0
#define GRAIL_MACOS_SHUT_WR 1
#define GRAIL_MACOS_SHUT_RDWR 2
#define GRAIL_MACOS_INVALID_SOCKET (-1)

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
grail_macos_dir *opendir(const char *path);
grail_macos_dirent *readdir(grail_macos_dir *directory);
int closedir(grail_macos_dir *directory);
int pthread_create(grail_macos_pthread_t *thread, const grail_macos_pthread_attr_t *attributes,
                   void *(*start)(void *), void *argument);
int pthread_join(grail_macos_pthread_t thread, void **result);
int pthread_detach(grail_macos_pthread_t thread);
grail_macos_pthread_t pthread_self(void);
int pthread_attr_init(grail_macos_pthread_attr_t *attributes);
int pthread_attr_destroy(grail_macos_pthread_attr_t *attributes);
int pthread_attr_setstacksize(grail_macos_pthread_attr_t *attributes, uint64_t size);
int pthread_setname_np(const char *name);
int pthread_mutex_init(grail_macos_pthread_mutex_t *mutex, const void *attributes);
int pthread_mutex_destroy(grail_macos_pthread_mutex_t *mutex);
int pthread_mutex_lock(grail_macos_pthread_mutex_t *mutex);
int pthread_mutex_trylock(grail_macos_pthread_mutex_t *mutex);
int pthread_mutex_unlock(grail_macos_pthread_mutex_t *mutex);
int pthread_cond_init(grail_macos_pthread_cond_t *condition, const void *attributes);
int pthread_cond_destroy(grail_macos_pthread_cond_t *condition);
int pthread_cond_wait(grail_macos_pthread_cond_t *condition,
                      grail_macos_pthread_mutex_t *mutex);
int pthread_cond_timedwait_relative_np(grail_macos_pthread_cond_t *condition,
                                       grail_macos_pthread_mutex_t *mutex,
                                       const grail_macos_timespec *timeout);
int pthread_cond_signal(grail_macos_pthread_cond_t *condition);
int pthread_cond_broadcast(grail_macos_pthread_cond_t *condition);
int sched_yield(void);
void *dlopen(const char *path, int mode);
void *dlsym(void *library, const char *name);
int dlclose(void *library);
char *dlerror(void);
int posix_spawn_file_actions_init(grail_macos_spawn_file_actions_t *actions);
int posix_spawn_file_actions_destroy(grail_macos_spawn_file_actions_t *actions);
int posix_spawn_file_actions_adddup2(grail_macos_spawn_file_actions_t *actions, int descriptor,
                                     int target);
int posix_spawn_file_actions_addopen(grail_macos_spawn_file_actions_t *actions, int target,
                                     const char *path, int flags,
                                     grail_macos_mode_t mode);
int posix_spawn_file_actions_addchdir_np(grail_macos_spawn_file_actions_t *actions,
                                         const char *path);
int posix_spawnattr_init(grail_macos_spawnattr_t *attributes);
int posix_spawnattr_destroy(grail_macos_spawnattr_t *attributes);
int posix_spawnattr_setflags(grail_macos_spawnattr_t *attributes, int16_t flags);
int posix_spawnattr_setpgroup(grail_macos_spawnattr_t *attributes, int group);
int posix_spawn(int *pid, const char *path,
                const grail_macos_spawn_file_actions_t *actions,
                const grail_macos_spawnattr_t *attributes, char *const argv[],
                char *const envp[]);
int waitpid(int pid, int *status, int options);
int kill(int pid, int signal);
grail_macos_tm *localtime_r(const int64_t *time, grail_macos_tm *result);
int socket(int family, int type, int protocol);
int bind(int descriptor, const grail_macos_sockaddr *address, grail_macos_socklen_t length);
int listen(int descriptor, int backlog);
int accept(int descriptor, grail_macos_sockaddr *address, grail_macos_socklen_t *length);
int connect(int descriptor, const grail_macos_sockaddr *address, grail_macos_socklen_t length);
grail_macos_ssize_t send(int descriptor, const void *buffer, uint64_t length, int flags);
grail_macos_ssize_t recv(int descriptor, void *buffer, uint64_t length, int flags);
grail_macos_ssize_t sendto(int descriptor, const void *buffer, uint64_t length, int flags,
                           const grail_macos_sockaddr *address, grail_macos_socklen_t address_length);
grail_macos_ssize_t recvfrom(int descriptor, void *buffer, uint64_t length, int flags,
                             grail_macos_sockaddr *address, grail_macos_socklen_t *address_length);
int shutdown(int descriptor, int how);
int getsockname(int descriptor, grail_macos_sockaddr *address, grail_macos_socklen_t *length);
int getpeername(int descriptor, grail_macos_sockaddr *address, grail_macos_socklen_t *length);
int setsockopt(int descriptor, int level, int option, const void *value,
               grail_macos_socklen_t length);
int getsockopt(int descriptor, int level, int option, void *value, grail_macos_socklen_t *length);

#ifdef __cplusplus
}
#endif

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
_Static_assert(sizeof(grail_macos_tm) == 56, "Darwin struct tm layout");
_Static_assert(sizeof(grail_macos_dirent) == 280, "Darwin struct dirent layout");
_Static_assert(sizeof(grail_macos_sockaddr) == 16, "Darwin sockaddr layout");
_Static_assert(sizeof(grail_macos_sockaddr_in) == 16, "Darwin sockaddr_in layout");
_Static_assert(sizeof(grail_macos_sockaddr_in6) == 28, "Darwin sockaddr_in6 layout");
_Static_assert(sizeof(grail_macos_pthread_mutex_t) == 64, "Darwin pthread_mutex_t size");
_Static_assert(sizeof(grail_macos_pthread_attr_t) == 64, "Darwin pthread_attr_t size");
_Static_assert(sizeof(grail_macos_timeval) == 16, "Darwin timeval layout");
_Static_assert(sizeof(grail_macos_linger) == 8, "Darwin linger layout");
#endif

#endif /* GRAIL_MACOS_H */
