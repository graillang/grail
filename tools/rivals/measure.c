// measure OUT CMD ARGS...: runs CMD and writes one JSON line to OUT with its CPU time (getrusage of
// the child and everything it waited for), wall time, peak RSS and the user-space instructions it
// and all its threads and children retired (perf_event_open, inherited; -1 when the kernel refuses).
// Used by tools/bench-rivals.mjs, compile-rivals.mjs and sched-rivals.mjs: on a loaded host CPU
// time and instruction counts compare programs; wall time does not.
#define _GNU_SOURCE
#include <linux/perf_event.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: measure OUT CMD [ARGS...]\n"); return 2; }
    int go[2];
    if (pipe(go)) return 2;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    pid_t pid = fork();
    if (pid == 0) {
        char c;
        close(go[1]);
        if (read(go[0], &c, 1) != 1) _exit(127);
        execvp(argv[2], argv + 2);
        perror(argv[2]);
        _exit(127);
    }
    close(go[0]);
    struct perf_event_attr attr;
    memset(&attr, 0, sizeof attr);
    attr.size = sizeof attr;
    attr.type = PERF_TYPE_HARDWARE;
    attr.config = PERF_COUNT_HW_INSTRUCTIONS;
    attr.disabled = 1;
    attr.enable_on_exec = 1;
    attr.inherit = 1;
    attr.exclude_kernel = 1;
    attr.exclude_hv = 1;
    int fd = (int)syscall(SYS_perf_event_open, &attr, pid, -1, -1, 0);
    if (write(go[1], "x", 1) != 1) return 2;
    close(go[1]);
    int status;
    struct rusage ru;
    if (wait4(pid, &status, 0, &ru) < 0) return 2;
    clock_gettime(CLOCK_MONOTONIC, &t1);
    long long instructions = -1;
    uint64_t count;
    if (fd >= 0 && read(fd, &count, sizeof count) == sizeof count) instructions = (long long)count;
    double user = ru.ru_utime.tv_sec + ru.ru_utime.tv_usec / 1e6, sys = ru.ru_stime.tv_sec + ru.ru_stime.tv_usec / 1e6;
    double wall = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    FILE *out = fopen(argv[1], "w");
    if (!out) return 2;
    fprintf(out, "{\"user\":%.6f,\"sys\":%.6f,\"wall\":%.6f,\"maxrss_kb\":%ld,\"instructions\":%lld,\"status\":%d}\n",
            user, sys, wall, ru.ru_maxrss, instructions, WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status));
    fclose(out);
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
