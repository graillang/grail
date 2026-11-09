/* A shared library the Grail dynamic-loader test loads at run time. It links no
 * libc and exports two functions, so the test proves loading, symbol resolution,
 * calling through the resolved address and unloading. */
long long c_dl_double(long long v) { return v * 2; }
long long c_dl_add(long long a, long long b) { return a + b; }

/* A C function that calls back into Grail, loaded through dlsym. The callback
 * runs on Grail's thread pointer and itself calls libc, so this exercises both
 * directions of the host-TLS bridge. */
typedef long long (*grail_callback)(long long);
long long c_dl_apply(grail_callback callback, long long value) { return callback(value); }
