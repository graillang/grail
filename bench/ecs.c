// The C twin of bench/ecs.grl: structure-of-arrays float columns on the heap.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
int main(void) {
    const uint64_t n = 1000000;
    float *px = malloc(n * 4), *py = malloc(n * 4), *pz = malloc(n * 4), *vx = malloc(n * 4), *vy = malloc(n * 4), *vz = malloc(n * 4);
    uint64_t x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) {
        x = xs(x);
        px[i] = (float)(int64_t)(x % 1000) * 0.5f;
        py[i] = (float)(int64_t)((x >> 10) % 1000) * 0.5f;
        pz[i] = (float)(int64_t)((x >> 20) % 1000) * 0.5f;
        vx[i] = (float)(int64_t)((x >> 30) % 100) * 0.01f;
        vy[i] = (float)(int64_t)((x >> 40) % 100) * 0.01f;
        vz[i] = (float)(int64_t)((x >> 50) % 100) * 0.01f;
    }
    const float dt = 0.016f, damping = 0.999f, gravity = 0.0981f;
    for (int frame = 0; frame < 600; frame++)
        for (uint64_t i = 0; i < n; i++) {
            vx[i] = vx[i] * damping;
            vy[i] = vy[i] * damping - gravity * dt;
            vz[i] = vz[i] * damping;
            px[i] = px[i] + vx[i] * dt;
            py[i] = py[i] + vy[i] * dt;
            pz[i] = pz[i] + vz[i] * dt;
        }
    double sum = 0;
    for (uint64_t i = 0; i < n; i++) sum = sum + (double)px[i] + (double)py[i] + (double)pz[i];
    printf("%.17g\n", sum);
    return 0;
}
