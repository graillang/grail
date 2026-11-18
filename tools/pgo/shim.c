// Profile-guided optimisation of the release compiler (tools/native.mjs pgo-train): linked into the
// instrumented compiler, it writes the run's counters when the program ends - the profile runtime's
// buffer writer, with the file written by raw syscalls (a Grail binary has no libc), from a wrapper
// around rt_shutdown (ld --wrap). Each process writes PGO_DIR/p<pid>.raw.
typedef unsigned long u64;
int __llvm_profile_runtime;
u64 __llvm_profile_get_size_for_buffer(void);
int __llvm_profile_write_buffer(char *);
extern u64 __real_rt_shutdown(void);
static long sys(long n, long a, long b, long c) {
  long r; __asm__ volatile("syscall" : "=a"(r) : "a"(n), "D"(a), "S"(b), "d"(c) : "rcx", "r11", "memory"); return r;
}
static char buf[1 << 27];
#ifndef PGO_DIR
#define PGO_DIR "/tmp"
#endif
u64 __wrap_rt_shutdown(void) {
  u64 n = __llvm_profile_get_size_for_buffer();
  if (n <= sizeof buf && __llvm_profile_write_buffer(buf) == 0) {
    char path[512];
    int i = 0;
    for (const char *d0 = PGO_DIR "/p"; *d0; d0++) path[i++] = *d0;
    long pid = sys(39, 0, 0, 0); char d[20]; int k = 0;
    do { d[k++] = '0' + pid % 10; pid /= 10; } while (pid);
    while (k) path[i++] = d[--k];
    path[i++] = '.'; path[i++] = 'r'; path[i++] = 'a'; path[i++] = 'w'; path[i] = 0;
    long fd = sys(2, (long)path, 01 | 0100 | 01000, 0644);
    if (fd >= 0) { u64 off = 0; while (off < n) { long w = sys(1, fd, (long)(buf + off), n - off); if (w <= 0) break; off += w; } sys(3, fd, 0, 0); }
  }
  return __real_rt_shutdown();
}
// Stubs for what the buffer writer's objects mention but this use never reaches (value profiling,
// warnings): never called during a buffer write of plain counters.
void __stack_chk_fail(void) { sys(231, 99, 0, 0); for (;;) {} }
char *getenv(const char *n) { (void)n; return 0; }
long strtol(const char *s, char **e, int b) { (void)s; (void)e; (void)b; return 0; }
void *calloc(u64 n, u64 m) { (void)n; (void)m; return 0; }
void free(void *p) { (void)p; }
void *stderr;
int __vfprintf_chk(void *f, int fl, const char *fmt, __builtin_va_list ap) { (void)f; (void)fl; (void)fmt; (void)ap; return 0; }
