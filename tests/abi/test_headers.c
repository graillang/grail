/* Header self-containment and layout probe; compiled for every ABI target. */
#include "../../include/grail/grail.h"

GRAIL_STATIC_ASSERT(sizeof(grail_startup) == 80, "grail_startup layout");
GRAIL_STATIC_ASSERT(sizeof(grail_allocator) == 40, "grail_allocator layout");
GRAIL_STATIC_ASSERT(sizeof(grail_os_error) == 16, "grail_os_error layout");
GRAIL_STATIC_ASSERT(sizeof(grail_status) == 8, "grail_status layout");
GRAIL_STATIC_ASSERT(sizeof(grail_file_stat) == 96, "grail_file_stat layout");
GRAIL_STATIC_ASSERT(sizeof(grail_dir_entry) == 40, "grail_dir_entry layout");
GRAIL_STATIC_ASSERT(sizeof(grail_pipe) == 16, "grail_pipe layout");
GRAIL_STATIC_ASSERT(sizeof(grail_thread_options) == 48, "grail_thread_options layout");
GRAIL_STATIC_ASSERT(sizeof(grail_process_options) == 144, "grail_process_options layout");
GRAIL_STATIC_ASSERT(sizeof(grail_process_status) == 40, "grail_process_status layout");
GRAIL_STATIC_ASSERT(sizeof(grail_socket_address) == 56, "grail_socket_address layout");

int grail_abi_header_probe(void);
int grail_abi_header_probe(void) {
    return (int)grail_abi_version();
}
