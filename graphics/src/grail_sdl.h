/* grail_sdl.h - the SDL3-backed window, shared between its implementation and the dispatcher. */
#ifndef GRAIL_SDL_H
#define GRAIL_SDL_H

#include "grail_internal.h"
#include "../include/grail/grail_window.h"

#define GR_SDL_WINDOW_NAME_MAX 128

typedef struct gr_sdl_window {
    void *window;          /* SDL_Window* */
    uint32_t flags;
    int32_t logical_width, logical_height;
    int32_t pixel_width, pixel_height;
} gr_sdl_window;

/* 1 when libSDL3 loaded and every entry point this file needs resolved. */
int gr_sdl_available(void);
int gr_sdl_backend_is_sdl3(void);
gr_result gr_sdl_window_create(const gr_window_desc *desc, gr_handle *out_window);
void gr_sdl_window_destroy(gr_handle window);
gr_result gr_sdl_window_get_size(gr_handle window, gr_window_size *out);
gr_result gr_sdl_window_get_native(gr_handle window, gr_window_native *out);
/* The instance extensions the platform requires for a Vulkan surface. */
gr_result gr_sdl_vulkan_extensions(uint32_t *out_count, const char *const **out_names);
/* The VkSurfaceKHR, as a handle-sized integer so no Vulkan type crosses this header. */
gr_result gr_sdl_vulkan_create_surface(uint64_t instance, uint64_t sdl_window, uint64_t *out_surface);
void gr_sdl_vulkan_destroy_surface(uint64_t instance, uint64_t surface);

#endif /* GRAIL_SDL_H */
