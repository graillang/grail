/* Trusted Linux I/O/process boundary. No borrowed pointer escapes a call. */
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>
typedef struct { uint8_t *p; uint64_t n,c; } gb;
typedef struct { uint8_t *p; uint64_t n; } gv;
typedef struct { void *p; uint64_t n,c; } ga;

static uint64_t host_error(void) { return errno > 0 ? (uint64_t)errno : (uint64_t)EIO; }
static char *host_string(gv v) {
    if (v.n >= SIZE_MAX || (v.n && memchr(v.p, 0, (size_t)v.n))) {
        errno = EINVAL; return NULL;
    }
    char *p = malloc((size_t)v.n + 1);
    if (!p) { errno = ENOMEM; return NULL; }
    if (v.n) memcpy(p, v.p, (size_t)v.n);
    p[v.n] = 0; return p;
}
static gb host_read(gv path) {
    char *p = host_string(path);
    if (!p) abort();
    int fd = open(p, O_RDONLY | O_CLOEXEC);
    free(p);
    if (fd < 0) abort();
    gb b = {NULL,0,0};
    for (;;) {
        if (b.n == b.c) {
            if (b.c > SIZE_MAX / 2) abort();
            uint64_t cap = b.c ? b.c * 2 : 4096;
            void *next = realloc(b.p, (size_t)cap);
            if (!next) abort();
            b.p = next; b.c = cap;
        }
        size_t count = (size_t)(b.c - b.n);
        if (count > (size_t)SSIZE_MAX) count = (size_t)SSIZE_MAX;
        ssize_t n = read(fd, b.p + b.n, count);
        if (n < 0) { if (errno == EINTR) continue; abort(); }
        if (!n) break;
        b.n += (uint64_t)n;
    }
    if (close(fd)) abort();
    return b;
}
gb q_4_host_9_read_file(gv path) { return host_read(path); }
static gb host_cmdline(void) {
    static uint8_t path[] = "/proc/self/cmdline";
    gb b = host_read((gv){path,sizeof(path)-1});
    if (!b.n || b.p[b.n-1]) abort();
    return b;
}
uint64_t q_4_host_4_argc(void) {
    gb b = host_cmdline(); uint64_t n = 0;
    for (uint64_t i=0; i<b.n; ++i) if (!b.p[i]) ++n;
    free(b.p); return n;
}
gb q_4_host_3_arg(uint64_t index) {
    gb b = host_cmdline(); uint64_t start = 0;
    for (uint64_t i=0; i<b.n; ++i) if (!b.p[i]) {
        if (!index) {
            uint64_t n = i-start;
            uint8_t *p = malloc(n ? (size_t)n : 1);
            if (!p) abort();
            if (n) memcpy(p,b.p+start,(size_t)n);
            free(b.p); return (gb){p,n,n ? n : 1};
        }
        --index; start = i+1;
    }
    free(b.p); abort();
}
static uint64_t host_write(int fd, gv data) {
    uint64_t done = 0;
    while (done < data.n) {
        uint64_t remaining = data.n - done;
        size_t count = remaining > (uint64_t)SSIZE_MAX ? (size_t)SSIZE_MAX : (size_t)remaining;
        ssize_t n = write(fd, data.p + done, count);
        if (n < 0) { if (errno == EINTR) continue; return host_error(); }
        if (!n) return EIO;
        done += (uint64_t)n;
    }
    return 0;
}
uint64_t q_4_host_10_write_file(gv path, gv data) {
    char *p = host_string(path);
    if (!p) return host_error();
    int fd = open(p, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0666);
    free(p);
    if (fd < 0) return host_error();
    uint64_t error = host_write(fd,data);
    /* Linux closes the fd even on EINTR: never retry close on a reused fd. */
    if (close(fd) && !error) error = host_error();
    return error;
}
uint8_t q_4_host_5_print(gv data) {
    if (host_write(STDOUT_FILENO,data)) abort();
    return 0;
}
static void host_drop_args(ga args) {
    gb *items = args.p;
    for (uint64_t i=0; i<args.n; ++i) free(items[i].p);
    free(args.p);
}
uint64_t q_4_host_7_command(ga args) {
    uint64_t error = 0;
    char **argv = NULL;
    if (!args.n || args.n >= SIZE_MAX / sizeof(char *)) error = 256 + EINVAL;
    else {
        argv = malloc(((size_t)args.n+1)*sizeof(char *));
        if (!argv) error = 256 + ENOMEM;
    }
    uint64_t made = 0;
    if (!error) {
        for (; made<args.n; ++made) {
            gb b = ((gb*)args.p)[made];
            argv[made] = host_string((gv){b.p,b.n});
            if (!argv[made]) { error = 256 + host_error(); break; }
        }
    }
    host_drop_args(args);
    if (!error) {
        argv[made] = NULL;
        pid_t child = fork();
        if (child < 0) error = 256 + host_error();
        else if (!child) { execvp(argv[0],argv); _exit(127); }
        else {
            int status; pid_t result;
            do { result = waitpid(child,&status,0); } while (result < 0 && errno == EINTR);
            if (result < 0) error = 256 + host_error();
            else if (WIFEXITED(status)) error = (uint64_t)WEXITSTATUS(status);
            else if (WIFSIGNALED(status)) error = 128 + (uint64_t)WTERMSIG(status);
            else error = 256 + ECHILD;
        }
    }
    for (uint64_t i=0; i<made; ++i) free(argv[i]);
    free(argv); return error;
}
