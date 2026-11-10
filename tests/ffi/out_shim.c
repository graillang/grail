/* out_shim.c - C functions that write a handle or a bare pointer through an out-parameter.
 *
 * This is the Vulkan/D3D12/Metal shape: `vkCreateInstance(..., VkInstance *pInstance)` cannot
 * return the object it creates, so it stores it through a slot the caller passes. Every function
 * here returns a checksum that reads the slot *before* writing it, so the Grail side proves both
 * that the slot arrived with a defined value (null, or whatever the program seeded) and that the
 * written word is what it reads back afterwards. A slot passed by value, or a write the Grail side
 * does not observe, changes the sum.
 */
typedef unsigned long long out_handle;

/* 1000 * (the value found in the slot) + the low 16 bits of the handle written. */
long long c_out_create(out_handle *pOut, long long seed)
{
    long long before = (long long)*pOut;
    out_handle h = 0x5100ULL | (out_handle)(seed & 0xFF);
    *pOut = h;
    return 1000 * before + (long long)(h & 0xFFFF);
}
/* The same slot again: the call must see what the previous one wrote. */
long long c_out_reread(out_handle *pOut)
{
    long long before = (long long)*pOut;
    *pOut = *pOut + 1;
    return 1000 * before + (long long)(*pOut & 0xFFFF);
}
/* The handle's low 16 bits as Grail read it back, so the read is checked independently of C. */
long long c_out_id(out_handle h) { return (long long)(h & 0xFFFF); }
/* A handle out-slot in the seventh argument position: x86-64 SysV passes it on the stack, AAPCS64
 * and RISC-V 64 in their seventh integer register. */
long long c_out_seventh(long long a, long long b, long long c, long long d, long long e, long long f,
                        out_handle *pOut)
{
    long long before = (long long)*pOut;
    *pOut = a + b * 2 + c * 3 + d * 4 + e * 5 + f * 6;
    return 1000 * before + (long long)(*pOut & 0xFFFF);
}
/* Two out-slots in one call, the second after a scalar. */
long long c_out_two(long long tag, out_handle *pFirst, out_handle *pSecond)
{
    long long first_before = (long long)*pFirst;
    long long second_before = (long long)*pSecond;
    *pFirst = 0x2000 | tag;
    *pSecond = 0x3000 | tag;
    return first_before * 1000000 + second_before * 10000
         + (long long)(*pFirst & 0xFFFF) * 100 + (long long)(*pSecond & 0xFF);
}
/* A bare pointer written through a slot (`const void **`): the address of a static byte buffer. */
static unsigned char out_bytes[4] = { 10, 20, 30, 40 };
long long c_out_ptr(const void **pOut)
{
    long long before = (long long)*pOut;
    *pOut = out_bytes;
    return 1000 * before + (long long)((const unsigned char *)*pOut)[3];
}
/* The same shape with `void **` and a CMutPtr slot: C owns the buffer, Grail may write through
 * the pointer it got back. */
static unsigned char out_mut_bytes[3] = { 1, 2, 3 };
long long c_out_ptr_mut(void **pOut)
{
    long long before = (long long)*pOut;
    *pOut = out_mut_bytes;
    return 1000 * before + (long long)out_mut_bytes[0];
}
long long c_out_ptr_list(const unsigned char *p, long long n)
{
    long long total = 0;
    for (long long i = 0; i < n; i++) total = total * 100 + p[i];
    return total;
}
/* Reads through the pointer the callee wrote: Grail must see the same bytes C does. */
long long c_out_ptr_sum(const unsigned char *p, long long n)
{
    long long total = 0;
    for (long long i = 0; i < n; i++) total += p[i];
    return total;
}
/* A create-info record plus an out slot, shaped like vkCreateInstance: a record pointer, a
 * two-word byte view, then the out slot, so the slot is neither first nor alone. */
struct out_info { long long magic; long long flags; };
long long c_out_info(struct out_info *info, const unsigned char *bytes, unsigned long len,
                     out_handle *pOut)
{
    long long before = (long long)*pOut;
    long long sum = info->magic + info->flags + (long long)len;
    for (unsigned long i = 0; i < len; i++) sum += bytes[i];
    *pOut = 0x7000 | (unsigned long long)(sum & 0xFFF);
    return 1000 * before + (long long)(*pOut & 0xFFFF) + sum;
}
