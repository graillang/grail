// C twin of bench/chan.grl: a bounded ring guarded by a pthread mutex and two condition variables,
// the textbook bounded queue. Same cases, same output. tools/bench-rivals.mjs checks every twin
// against this program's output.
// bench-cflags: -pthread
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    uint64_t *items;
    uint64_t cap, head, len;
    int closed;
    pthread_mutex_t m;
    pthread_cond_t not_empty, not_full;
} chan;

static chan *bounded(uint64_t cap) {
    chan *c = calloc(1, sizeof *c);
    c->items = calloc(cap, sizeof(uint64_t));
    c->cap = cap;
    pthread_mutex_init(&c->m, 0);
    pthread_cond_init(&c->not_empty, 0);
    pthread_cond_init(&c->not_full, 0);
    return c;
}
static int send(chan *c, uint64_t v) {
    pthread_mutex_lock(&c->m);
    while (!c->closed && c->len == c->cap) pthread_cond_wait(&c->not_full, &c->m);
    if (c->closed) { pthread_mutex_unlock(&c->m); return 0; }
    c->items[(c->head + c->len) % c->cap] = v;
    c->len++;
    pthread_mutex_unlock(&c->m);
    pthread_cond_signal(&c->not_empty);
    return 1;
}
static int recv(chan *c, uint64_t *out) {
    pthread_mutex_lock(&c->m);
    while (!c->closed && c->len == 0) pthread_cond_wait(&c->not_empty, &c->m);
    if (c->len == 0) { pthread_mutex_unlock(&c->m); return 0; }
    *out = c->items[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    pthread_mutex_unlock(&c->m);
    pthread_cond_signal(&c->not_full);
    return 1;
}
static void close_chan(chan *c) {
    pthread_mutex_lock(&c->m);
    c->closed = 1;
    pthread_mutex_unlock(&c->m);
    pthread_cond_broadcast(&c->not_empty);
    pthread_cond_broadcast(&c->not_full);
}

typedef struct { chan *c; uint64_t p, each, sum; } job;
static void *producer(void *a) {
    job *j = a;
    for (uint64_t i = 0; i < j->each; i++) send(j->c, j->p * 1000000 + i + 1);
    return 0;
}
static void *consumer(void *a) {
    job *j = a;
    uint64_t v;
    while (recv(j->c, &v)) j->sum += v;
    return 0;
}
static uint64_t spread(int producers, int consumers, uint64_t each) {
    chan *c = bounded(64);
    pthread_t pt[8], ct[8];
    job pj[8], cj[8];
    for (int p = 0; p < producers; p++) { pj[p] = (job){c, p, each, 0}; pthread_create(&pt[p], 0, producer, &pj[p]); }
    for (int q = 0; q < consumers; q++) { cj[q] = (job){c, 0, 0, 0}; pthread_create(&ct[q], 0, consumer, &cj[q]); }
    for (int p = 0; p < producers; p++) pthread_join(pt[p], 0);
    close_chan(c);
    uint64_t total = 0;
    for (int q = 0; q < consumers; q++) { pthread_join(ct[q], 0); total += cj[q].sum; }
    return total;
}

static chan *there, *back;
static void *echo(void *a) {
    uint64_t v;
    while (recv(there, &v)) send(back, v + 1);
    return 0;
}
static uint64_t ping(uint64_t rounds) {
    there = bounded(1);
    back = bounded(1);
    pthread_t t;
    pthread_create(&t, 0, echo, 0);
    uint64_t v = 0;
    for (uint64_t i = 0; i < rounds; i++) { send(there, v); recv(back, &v); }
    close_chan(there);
    pthread_join(t, 0);
    return v;
}

int main(void) {
    const char *e = getenv("CHAN_CASE");
    int only = e && *e ? *e - '0' : 0;
    if (!only || only == 1) printf("1:1 %llu\n", (unsigned long long)spread(1, 1, 400000));
    if (!only || only == 2) printf("N:1 %llu\n", (unsigned long long)spread(4, 1, 100000));
    if (!only || only == 3) printf("N:M %llu\n", (unsigned long long)spread(4, 4, 100000));
    if (!only || only == 4) printf("ping %llu\n", (unsigned long long)ping(100000));
    return 0;
}
