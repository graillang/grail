/* A libc-linked shim for the per-thread host TLS test (tests/ffi/threads.grl). Everything here
 * reads or writes per-thread libc state, so it only behaves when each calling thread runs on its
 * own glibc TCB: errno lives in the TCB's static TLS and pthread_self() is the TCB itself. */
#include <errno.h>
#include <pthread.h>
#include <stdatomic.h>
#include <time.h>

static atomic_int arrived;

static void nap(void) {
  struct timespec t = {0, 1000000};
  nanosleep(&t, 0);
}

/* Set errno, wait (at most about two seconds) until a second thread has set its own, then return
 * what errno reads now. Two threads sharing one TCB would see the later writer's value. */
long ts_errno_hold(long value) {
  errno = (int)value;
  atomic_fetch_add(&arrived, 1);
  for (int i = 0; i < 2000 && atomic_load(&arrived) < 2; i++) nap();
  return errno;
}

long ts_arrived(void) { return atomic_load(&arrived); }

long ts_errno(void) { return errno; }

/* Foreign-thread callbacks (tests/ffi/foreign_thread.grl): run `cb(value)` on a pthread this shim
 * creates, so the callback lands on a thread the Grail runtime never saw, and return its result.
 * `ts_call_here` lets that callback re-enter C and call back again (a nested callback on the same
 * foreign thread). */
typedef long (*ts_cb)(long);
struct ts_job { ts_cb cb; long value; long result; };

static void *ts_run(void *arg) {
  struct ts_job *job = arg;
  job->result = job->cb(job->value);
  return 0;
}

long ts_call_on_new_thread(ts_cb cb, long value) {
  struct ts_job job = {cb, value, -1};
  pthread_t thread;
  if (pthread_create(&thread, 0, ts_run, &job) != 0) return -2;
  pthread_join(thread, 0);
  return job.result;
}

long ts_call_here(ts_cb cb, long value) { return cb(value); }
