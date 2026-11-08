/* Header self-containment and layout probe; compiled for every ABI target. */
#include "../../include/grail/grail_abi.h"
#include "../../include/grail/grail_error.h"
#include "../../include/grail/grail_time.h"
#include "../../include/grail/grail_unicode.h"

GRAIL_STATIC_ASSERT(sizeof(grail_startup) == 80, "grail_startup layout");
GRAIL_STATIC_ASSERT(sizeof(grail_allocator) == 40, "grail_allocator layout");
GRAIL_STATIC_ASSERT(sizeof(grail_os_error) == 16, "grail_os_error layout");
GRAIL_STATIC_ASSERT(sizeof(grail_status) == 8, "grail_status layout");

int grail_abi_header_probe(void);
int grail_abi_header_probe(void) {
    return (int)grail_abi_version();
}
