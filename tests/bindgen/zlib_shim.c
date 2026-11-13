/* zlib_shim.c - a minimal stand-in for libz, so the binding generated from the real <zlib.h> can be
 * called: `crc32` is the real CRC-32 (bitwise), and `zlib_shim_sizeof_stream` reports C's own
 * sizeof(z_stream) so the generated layout can be compared with it.
 */
#include <stddef.h>
#include <zlib.h>

unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len)
{
    unsigned long c = crc ^ 0xffffffffUL;
    for (unsigned int i = 0; i < len; i++) {
        c ^= buf[i];
        for (int bit = 0; bit < 8; bit++) c = (c & 1) ? ((c >> 1) ^ 0xedb88320UL) : (c >> 1);
    }
    return c ^ 0xffffffffUL;
}

unsigned long zlib_shim_sizeof_stream(void) { return (unsigned long)sizeof(z_stream); }
unsigned long zlib_shim_offset_next_in(void) { return (unsigned long)offsetof(z_stream, next_in); }
unsigned long zlib_shim_offset_msg(void) { return (unsigned long)offsetof(z_stream, msg); }
