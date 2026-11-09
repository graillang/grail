// Reference values for tests/lib/png_write_test.grl: each tests/lib/png/*.png that stb accepts is
// decoded with req_comp 1..4 and re-encoded with stbi_write_png_to_mem (defaults); prints
// "name n length fnv64" of the encoded file.
//   cc -O1 -I<stb dir> png_write_reference.c -lm -o png_write_reference && ./png_write_reference png/*.png > png/written.txt
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    for (int a = 1; a < argc; a++) {
        const char *name = strrchr(argv[a], '/'); name = name ? name + 1 : argv[a];
        for (int n = 1; n <= 4; n++) {
            int w, h, c;
            unsigned char *px = stbi_load(argv[a], &w, &h, &c, n);
            if (!px) continue;
            int len = 0;
            unsigned char *png = stbi_write_png_to_mem(px, 0, w, h, n, &len);
            unsigned long long hash = 14695981039346656037ULL;
            for (int i = 0; i < len; i++) { hash ^= png[i]; hash *= 1099511628211ULL; }
            printf("%s %d %d %llu\n", name, n, len, hash);
            STBIW_FREE(png); stbi_image_free(px);
        }
    }
    return 0;
}
