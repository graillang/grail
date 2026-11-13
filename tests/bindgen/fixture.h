/* fixture.h - the constructs a C header importer has to get right.
 *
 * Compiled by cc in tools/bindgen-test.mjs, which compares this header's own sizeof/offsetof with
 * the SIZE/OFFSET constants `grail bindgen` emits, and runs the generated declarations against
 * `fixture_shim.c` so the values cross the real C ABI.
 */
#ifndef FIXTURE_H
#define FIXTURE_H

#include "fixture_extra.h"

/* Object-like macros: a shift expression, an alias, and one with no body at all. */
#define FIX_FLAG_A (1u << 3)
#define FIX_FLAG_B FIX_FLAG_A
#define FIX_FLAG_MASK (FIX_FLAG_A | 16u)
#define FIX_NEG (-20)
#define FIX_EMPTY
#define FIX_VERSION_MAJOR 2

/* A function-like macro used in declarations, and one the importer must not emit as a value. */
#define FIX_API(ret) ret
#define FIX_SQUARE(x) ((x) * (x))

/* Basic typedefs, including one that names a struct and one of a bare pointer. */
typedef unsigned int fix_u32;
typedef signed short fix_i16;
typedef char fix_name[16];
typedef void *fix_handle;

#if !defined(FIX_DISABLE_EXTRA) && (FIX_VERSION_MAJOR >= 2)
#define FIX_EXTRA_ON 1
#else
#define FIX_EXTRA_ON 0
#endif

/* Alignment-critical shapes: mixed widths, an inline array, a nested record, a function pointer
 * member and a double, which only come out right with C's padding rules. */
typedef struct fix_record {
    unsigned char tag;
    int value;
    short small;
    char name[16];
    double weight;
    fix_id id;
} fix_record;

typedef struct fix_nested {
    fix_record inner;
    int tail;
    float ratio;
} fix_nested;

typedef struct fix_ops {
    int (*on_event)(int code, void *user);
    const char *label;
    unsigned long count;
} fix_ops;

struct fix_opaque;                 /* incomplete: only ever a pointer */
typedef struct fix_opaque *fix_opaque_p;

/* A union: overlapping members have no Grail spelling, so only its size and alignment exported. */
union fix_bits {
    unsigned int whole;
    unsigned char bytes[4];
};

/* An enum with implicit, explicit and negative values. */
enum fix_mode {
    FIX_MODE_ZERO,
    FIX_MODE_ONE = 5,
    FIX_MODE_NEXT,
    FIX_MODE_NEGATIVE = -3,
    FIX_MODE_BIG = 0x7fffffff
};

/* Function declarations of the shapes a binding must type: scalars, const/non-const pointers,
 * arrays that decay, a function pointer parameter, a variadic tail, a record by pointer, and a
 * record returned by value. */
FIX_API(int) fix_add(int a, int b);
fix_u32 fix_mask(fix_u32 value, fix_u32 flags);
const char *fix_text(void);
fix_handle fix_open(const char *path, int flags);
int fix_sum_bytes(const unsigned char *data, fix_u32 length);
int fix_names(char **names, int count);
int fix_call(fix_ops *ops, int code, void *user);
int fix_vsum(int count, ...);
fix_u32 fix_record_tag(const fix_record *record);
fix_record fix_make_record(unsigned char tag, int value);

/* A file-scope variable: no Grail spelling, reported as a note and not emitted. */
extern const char *fix_build_id;
extern int fix_global_counter;

/* The header's own claim about its layout; the importer evaluates it with its own offsets. */
#if defined(FIX_STATIC_ASSERT_CHECK)
_Static_assert(sizeof(fix_record) == 48, "fix_record layout");
#endif

#endif
