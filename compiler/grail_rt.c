/* Runtime for C emitted by compiler/grailc.grl. Every Grail value is one 64-bit word:
   numbers directly; bytes/string/views/vec as Seq pointers; records as field arrays;
   enums as {tag,payload}; typed references as slot addresses. Memory is never freed. */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
typedef uint64_t G;
typedef struct { G *p; G n; G cap; } Seq;
static int rt_argc;
static char **rt_argv;
static void *rt_alloc(size_t n) { void *p = calloc(1, n ? n : 1); if (!p) abort(); return p; }
static G rt_new(void) { return (G)rt_alloc(sizeof(Seq)); }
static void rt_push(G s, G v) {
    Seq *q = (Seq *)s;
    if (q->n == q->cap) {
        q->cap = q->cap ? q->cap * 2 : 8;
        q->p = realloc(q->p, q->cap * sizeof(G));
        if (!q->p) abort();
    }
    q->p[q->n++] = v;
}
static void rt_pushb(G s, G v) { rt_push(s, v & 255); }
static G rt_pop(G s) { Seq *q = (Seq *)s; if (!q->n) abort(); return q->p[--q->n]; }
static G rt_len(G s) { return ((Seq *)s)->n; }
static G rt_at(G s, G i) { Seq *q = (Seq *)s; if (i >= q->n) abort(); return q->p[i]; }
static G rt_slot(G s, G i) { Seq *q = (Seq *)s; if (i >= q->n) abort(); return (G)&q->p[i]; }
static void rt_write(G s, G i, G v) { Seq *q = (Seq *)s; if (i >= q->n) abort(); q->p[i] = v & 255; }
static G rt_view(G s) { Seq *q = (Seq *)s, *v = rt_alloc(sizeof(Seq)); v->p = q->p; v->n = q->n; return (G)v; }
static G rt_slice(G s, G a, G b) {
    Seq *q = (Seq *)s, *v;
    if (a > b || b > q->n) abort();
    v = rt_alloc(sizeof(Seq)); v->p = q->p + a; v->n = b - a; return (G)v;
}
static G rt_copy(G s) { Seq *q = (Seq *)s; G r = rt_new(); for (G i = 0; i < q->n; i++) rt_push(r, q->p[i]); return r; }
static void rt_append(G d, G s) { Seq *q = (Seq *)s; G n = q->n; for (G i = 0; i < n; i++) rt_push(d, q->p[i]); }
static G rt_lit(const char *s, G n) { G r = rt_new(); for (G i = 0; i < n; i++) rt_push(r, (unsigned char)s[i]); return r; }
static G rt_rec(G n) { return (G)rt_alloc(n * sizeof(G)); }
static G rt_enum(G tag, G payload) { G *e = rt_alloc(2 * sizeof(G)); e[0] = tag; e[1] = payload; return (G)e; }
static G rt_xchg(G r, G v) { G *p = (G *)r, o = *p; *p = v; return o; }
static G rt_rem(G a, G b) { if (!b) abort(); return a % b; }
static char *rt_cstr(G s) {
    Seq *q = (Seq *)s; char *c = rt_alloc(q->n + 1);
    for (G i = 0; i < q->n; i++) { if (!q->p[i]) return 0; c[i] = (char)q->p[i]; }
    return c;
}
static G f_host_argc(void) { return (G)rt_argc; }
static G f_host_arg(G i) {
    if (i >= (G)rt_argc) abort();
    return rt_lit(rt_argv[i], strlen(rt_argv[i]));
}
static G f_host_read_file(G path) {
    char *p = rt_cstr(path); FILE *f; G r = rt_new(); int c;
    if (!p || !(f = fopen(p, "rb"))) abort();
    while ((c = getc(f)) != EOF) rt_push(r, (G)c);
    if (ferror(f)) abort();
    fclose(f); return r;
}
static G f_host_write_file(G path, G data) {
    Seq *q = (Seq *)data; char *p = rt_cstr(path); FILE *f;
    if (!p) return EINVAL;
    if (!(f = fopen(p, "wb"))) return errno ? errno : EIO;
    for (G i = 0; i < q->n; i++) if (putc((int)q->p[i], f) == EOF) { fclose(f); return EIO; }
    if (fclose(f)) return errno ? errno : EIO;
    return 0;
}
static G f_host_print(G data) {
    Seq *q = (Seq *)data;
    for (G i = 0; i < q->n; i++) if (putchar((int)q->p[i]) == EOF) abort();
    fflush(stdout); return 0;
}
static G f_host_command(G args) {
    Seq *q = (Seq *)args; char **argv; pid_t child; int status;
    if (!q->n) return 256 + EINVAL;
    argv = rt_alloc((q->n + 1) * sizeof(char *));
    for (G i = 0; i < q->n; i++) if (!(argv[i] = rt_cstr(q->p[i]))) return 256 + EINVAL;
    fflush(stdout);
    child = fork();
    if (child < 0) return 256 + errno;
    if (!child) { execvp(argv[0], argv); _exit(127); }
    if (waitpid(child, &status, 0) < 0) return 256 + errno;
    if (WIFEXITED(status)) return (G)WEXITSTATUS(status);
    return 128 + (G)WTERMSIG(status);
}
