// Reference values for tests/lib/png_test.grl: stb_image (as vendored by Abundance) decodes every
// tests/lib/png/*.png for req_comp 0..4 and prints "name req width height comp fnv64" lines, where
// fnv64 is FNV-1a 64 over the returned pixels, or "name req reject".
//   cc -O1 -I<stb dir> png_reference.c -lm -o png_reference && ./png_reference png/*.png > png/expected.txt
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#include "stb_image.h"
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    for (int a = 1; a < argc; a++) {
        const char *name = strrchr(argv[a], '/'); name = name ? name + 1 : argv[a];
        for (int req = 0; req <= 4; req++) {
            int w, h, n;
            unsigned char *px = stbi_load(argv[a], &w, &h, &n, req);
            if (!px) { printf("%s %d reject\n", name, req); continue; }
            int out = req ? req : n;
            unsigned long long hash = 14695981039346656037ULL;
            for (long i = 0; i < (long)w * h * out; i++) { hash ^= px[i]; hash *= 1099511628211ULL; }
            printf("%s %d %d %d %d %llu\n", name, req, w, h, n, hash);
            stbi_image_free(px);
        }
    }
    return 0;
}
