/* fixture_extra.h - included by fixture.h to exercise `#include "..."` resolution through -I. */
#ifndef FIXTURE_EXTRA_H
#define FIXTURE_EXTRA_H

typedef unsigned long long fix_id;
typedef struct fix_extra fix_extra;

enum fix_extra_kind {
    FIX_EXTRA_NONE = 0,
    FIX_EXTRA_SOME = 7
};

#endif
