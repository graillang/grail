/* fixture_shim.c - C twins for tests/bindgen/fixture.h.
 *
 * Two jobs: report this compiler's own sizeof/offsetof so the Grail side can compare them with the
 * constants `grail bindgen` emitted, and compute a position-weighted checksum over every field a
 * record carries, so a binding with the wrong offset or width fails instead of agreeing by luck.
 */
#include <stdarg.h>
#include <stddef.h>
#include "fixture.h"

/* Freestanding: the Grail program links a bare image, so the shim must not need libc. */
static int fix_strlen(const char *text)
{
    int n = 0;
    while (text != NULL && text[n] != 0) n++;
    return n;
}

long long fix_shim_sizeof_record(void) { return (long long)sizeof(fix_record); }
long long fix_shim_sizeof_nested(void) { return (long long)sizeof(fix_nested); }
long long fix_shim_sizeof_ops(void) { return (long long)sizeof(fix_ops); }
long long fix_shim_sizeof_bits(void) { return (long long)sizeof(union fix_bits); }
long long fix_shim_align_record(void) { return (long long)offsetof(struct { char c; fix_record r; }, r); }
long long fix_shim_offset_tag(void) { return (long long)offsetof(fix_record, tag); }
long long fix_shim_offset_value(void) { return (long long)offsetof(fix_record, value); }
long long fix_shim_offset_small(void) { return (long long)offsetof(fix_record, small); }
long long fix_shim_offset_name(void) { return (long long)offsetof(fix_record, name); }
long long fix_shim_offset_weight(void) { return (long long)offsetof(fix_record, weight); }
long long fix_shim_offset_id(void) { return (long long)offsetof(fix_record, id); }
long long fix_shim_offset_inner(void) { return (long long)offsetof(fix_nested, inner); }
long long fix_shim_offset_tail(void) { return (long long)offsetof(fix_nested, tail); }
long long fix_shim_offset_ratio(void) { return (long long)offsetof(fix_nested, ratio); }

/* The declared functions the binding names. */
int fix_add(int a, int b) { return a + b; }
fix_u32 fix_mask(fix_u32 value, fix_u32 flags) { return (value & flags) | 1u; }
const char *fix_text(void) { return "fixture"; }
fix_handle fix_open(const char *path, int flags) { return (fix_handle)(long)(path[0] + flags); }
int fix_sum_bytes(const unsigned char *data, fix_u32 length)
{
    int sum = 0;
    for (fix_u32 i = 0; i < length; i++) sum += data[i] * (int)(i + 1);
    return sum;
}
int fix_names(char **names, int count)
{
    int total = 0;
    for (int i = 0; i < count; i++) total += fix_strlen(names[i]) * (i + 1);
    return total;
}
int fix_call(fix_ops *ops, int code, void *user)
{
    int from_callback = ops->on_event ? ops->on_event(code, user) : 0;
    return from_callback + (int)ops->count + fix_strlen(ops->label);
}
int fix_vsum(int count, ...)
{
    va_list ap;
    int total = 0;
    va_start(ap, count);
    for (int i = 0; i < count; i++) total += va_arg(ap, int) * (i + 1);
    va_end(ap);
    return total;
}
fix_u32 fix_record_tag(const fix_record *record) { return record->tag + (fix_u32)record->value; }

fix_record fix_make_record(unsigned char tag, int value)
{
    fix_record r;
    r.tag = tag;
    r.value = value;
    r.small = (short)(value * 2);
    for (int i = 0; i < 16; i++) r.name[i] = 0;
    r.name[0] = (char)('a' + (tag & 3));
    r.weight = 1.5;
    r.id = 9000000000ULL;
    return r;
}

/* The checksum the Grail side compares with its own reading of the same record. */
long long fix_shim_checksum(const fix_record *r)
{
    long long sum = (long long)r->tag;
    sum += (long long)r->value * 10;
    sum += (long long)r->small * 100;
    sum += (long long)(r->weight * 1000);
    sum += (long long)(r->id % 100000) * 10000;
    for (int i = 0; i < 16; i++) sum += (long long)(unsigned char)r->name[i] * (i + 1);
    return sum;
}
