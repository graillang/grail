/* grail_sdl.c - SDL3 window and Vulkan surface, loaded at run time.
 *
 * SDL3 owns the platform window; the RHI owns the GPU. They meet at one value, the native window
 * handle, which is exactly what grail_window.h says. This file supplies the platform half through
 * dlopen, so a machine without SDL3 still builds and runs every other test and a test that needs a
 * window skips instead of refusing to link.
 *
 * Only the entry points a Vulkan host needs are resolved. The symbols are exported versioned
 * (SDL_CreateWindow@@SDL3_0.0.0), so dlsym by plain name is what resolves them.
 */
#include "grail_sdl.h"

#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#if defined(_WIN32)
/* Windows: SDL3.dll through LoadLibrary, beside the executable or on the DLL search path. */
#  include <windows.h>
#  undef CreateWindow /* a windows.h macro; the field below is SDL_CreateWindow */
#  define GRAIL_HAVE_DLOPEN 1
#  define sdl_open(name) ((void *)LoadLibraryA(name))
#  define sdl_sym(lib, name) ((void *)GetProcAddress((HMODULE)(lib), name))
#  define sdl_close(lib) FreeLibrary((HMODULE)(lib))
#elif defined(__has_include)
#  if __has_include(<dlfcn.h>)
#    include <dlfcn.h>
#    define GRAIL_HAVE_DLOPEN 1
#    define sdl_open(name) dlopen(name, RTLD_NOW | RTLD_LOCAL)
#    define sdl_sym(lib, name) dlsym(lib, name)
#    define sdl_close(lib) dlclose(lib)
#  endif
#endif
#if !defined(GRAIL_HAVE_DLOPEN)
#  define GRAIL_HAVE_DLOPEN 0
#endif

#if GRAIL_HAVE_DLOPEN

typedef struct sdl_api {
    void *library;
    /* SDL3 returns C `bool` (one byte): declaring these `int` would read undefined upper bits. */
    bool (*InitSubSystem)(uint32_t flags);
    void *(*CreateWindow)(const char *title, int w, int h, uint64_t flags);
    void (*DestroyWindow)(void *window);
    bool (*GetWindowSizeInPixels)(void *window, int *w, int *h);
    /* SDL 3.4 returns the names directly; only 3.6+ splits this into ...ExtensionNames. */
    const char *const *(*Vulkan_GetInstanceExtensions)(uint32_t *count);
    bool (*Vulkan_CreateSurface)(void *window, void *instance, void *allocator, uint64_t *surface);
    void (*Vulkan_DestroySurface)(void *instance, uint64_t surface, void *allocator);
    /* The window's platform handles (HWND/HINSTANCE on Windows), for backends that are not
     * Vulkan. Optional: resolved when present, required only where a D3D12 swapchain asks. */
    uint32_t (*GetWindowProperties)(void *window);
    void *(*GetPointerProperty)(uint32_t props, const char *name, void *default_value);
} sdl_api;

static sdl_api g_sdl;
static int g_sdl_state; /* 0 unknown, 1 available, -1 unavailable */
static gr_window_backend g_backend = GR_WINDOW_BACKEND_NULL;

#define SDL_INIT_VIDEO 0x00000020u
#define SDL_WINDOW_HIDDEN 0x00000008u
#define SDL_WINDOW_VULKAN 0x10000000u

int gr_sdl_available(void)
{
#if defined(_WIN32)
    static const char *kCandidates[] = { "SDL3.dll", NULL };
#else
    static const char *kCandidates[] = { "libSDL3.so.0", "libSDL3.so", NULL };
#endif
    const char *missing = NULL;
    int i;

    if (g_sdl_state != 0)
        return g_sdl_state > 0;
    for (i = 0; kCandidates[i]; ++i) {
        g_sdl.library = sdl_open(kCandidates[i]);
        if (g_sdl.library)
            break;
    }
    if (!g_sdl.library) {
        g_sdl_state = -1;
        return 0;
    }
#define SDL_RESOLVE(field, name)                                                     \
    do {                                                                             \
        *(void **)(&g_sdl.field) = sdl_sym(g_sdl.library, name);                      \
        if (!g_sdl.field && !missing)                                                 \
            missing = name;                                                          \
    } while (0)
    SDL_RESOLVE(InitSubSystem, "SDL_InitSubSystem");
    SDL_RESOLVE(CreateWindow, "SDL_CreateWindow");
    SDL_RESOLVE(DestroyWindow, "SDL_DestroyWindow");
    SDL_RESOLVE(GetWindowSizeInPixels, "SDL_GetWindowSizeInPixels");
    SDL_RESOLVE(Vulkan_GetInstanceExtensions, "SDL_Vulkan_GetInstanceExtensions");
    SDL_RESOLVE(Vulkan_CreateSurface, "SDL_Vulkan_CreateSurface");
    SDL_RESOLVE(Vulkan_DestroySurface, "SDL_Vulkan_DestroySurface");
#undef SDL_RESOLVE
    *(void **)(&g_sdl.GetWindowProperties) = sdl_sym(g_sdl.library, "SDL_GetWindowProperties");
    *(void **)(&g_sdl.GetPointerProperty) = sdl_sym(g_sdl.library, "SDL_GetPointerProperty");
    if (missing) {
        /* A partial resolution is a loader version this file was not written for: refuse rather
         * than call a NULL entry point. */
        sdl_close(g_sdl.library);
        memset(&g_sdl, 0, sizeof(g_sdl));
        g_sdl_state = -1;
        return 0;
    }
    g_sdl_state = 1;
    return 1;
}

gr_result gr_window_set_backend(gr_window_backend backend)
{
    if (backend == GR_WINDOW_BACKEND_NULL) {
        g_backend = backend;
        return GR_OK;
    }
    if (backend != GR_WINDOW_BACKEND_SDL3)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!gr_sdl_available())
        return GR_ERROR_UNSUPPORTED;
    g_backend = backend;
    return GR_OK;
}

int gr_sdl_backend_is_sdl3(void) { return g_backend == GR_WINDOW_BACKEND_SDL3; }

gr_result gr_sdl_window_create(const gr_window_desc *desc, gr_handle *out_window)
{
    char title[GR_SDL_WINDOW_NAME_MAX];
    /* Only a Vulkan surface needs SDL's Vulkan loader; a D3D12 window must not require it. */
    uint64_t flags = (desc->flags & GR_WINDOW_VULKAN) ? SDL_WINDOW_VULKAN : 0;
    gr_sdl_window *object;
    void *window;
    gr_handle handle;

    if (!gr_sdl_available())
        return GR_ERROR_UNSUPPORTED;
    if (desc->head.size != sizeof(gr_window_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (!g_sdl.InitSubSystem(SDL_INIT_VIDEO))
        return GR_ERROR_BACKEND;

    title[0] = '\0';
    if (desc->title.data) {
        size_t n = desc->title.len < sizeof(title) - 1u ? desc->title.len : sizeof(title) - 1u;
        memcpy(title, desc->title.data, n);
        title[n] = '\0';
    }
    /* A test has no display to show a window on; a caller that wants one simply does not ask for
     * a hidden window. */
    if (desc->flags & GR_WINDOW_HIDDEN)
        flags |= SDL_WINDOW_HIDDEN;

    window = g_sdl.CreateWindow(title[0] ? title : "grail",
                                (int)(desc->width ? desc->width : 1280u),
                                (int)(desc->height ? desc->height : 720u), flags);
    if (!window)
        return GR_ERROR_BACKEND;

    object = (gr_sdl_window *)calloc(1, sizeof(*object));
    if (!object) {
        g_sdl.DestroyWindow(window);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    object->window = window;
    object->flags = desc->flags;
    if (!g_sdl.GetWindowSizeInPixels(window, &object->pixel_width, &object->pixel_height)) {
        object->pixel_width = (int32_t)(desc->width ? desc->width : 1280u);
        object->pixel_height = (int32_t)(desc->height ? desc->height : 720u);
    }
    object->logical_width = object->pixel_width;
    object->logical_height = object->pixel_height;

    gr_objects_init_once();
    handle = gr_object_insert(gr_objects(), GR_HANDLE_WINDOW, object);
    if (gr_handle_is_null(handle)) {
        g_sdl.DestroyWindow(window);
        free(object);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_window = handle;
    return GR_OK;
}

void gr_sdl_window_destroy(gr_handle window_handle)
{
    gr_sdl_window *object = (gr_sdl_window *)gr_object_remove(gr_objects(), window_handle,
                                                              GR_HANDLE_WINDOW);
    if (!object)
        return;
    if (object->window && g_sdl.DestroyWindow)
        g_sdl.DestroyWindow(object->window);
    free(object);
}

gr_result gr_sdl_window_get_size(gr_handle window_handle, gr_window_size *out)
{
    gr_sdl_window *object = (gr_sdl_window *)gr_object_lookup(gr_objects(), window_handle,
                                                              GR_HANDLE_WINDOW, NULL);
    if (!object || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (g_sdl.GetWindowSizeInPixels(object->window, &object->pixel_width, &object->pixel_height)) {
        /* Logical and pixel sizes differ on a HiDPI display; here they are the same because
         * SDL reports one and the other is not exposed without a scale query. */
        object->logical_width = object->pixel_width;
        object->logical_height = object->pixel_height;
    }
    memset(out, 0, sizeof(*out));
    out->logical_width = (uint32_t)object->logical_width;
    out->logical_height = (uint32_t)object->logical_height;
    out->pixel_width = (uint32_t)object->pixel_width;
    out->pixel_height = (uint32_t)object->pixel_height;
    out->scale = 1.0f;
    return GR_OK;
}

gr_result gr_sdl_window_get_native(gr_handle window_handle, gr_window_native *out)
{
    gr_sdl_window *object = (gr_sdl_window *)gr_object_lookup(gr_objects(), window_handle,
                                                              GR_HANDLE_WINDOW, NULL);
    if (!object || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(out, 0, sizeof(*out));
    /* The handles are typed by the backend that will consume them (grail_window.h). */
    if (gr_active_backend() == GR_BACKEND_D3D12) {
        uint32_t props;
        if (!g_sdl.GetWindowProperties || !g_sdl.GetPointerProperty)
            return GR_ERROR_UNSUPPORTED;
        props = g_sdl.GetWindowProperties(object->window);
        out->backend = GR_BACKEND_D3D12;
        out->handle_a = g_sdl.GetPointerProperty(props, "SDL.window.win32.hwnd", NULL);
        out->handle_b = g_sdl.GetPointerProperty(props, "SDL.window.win32.instance", NULL);
        return out->handle_a ? GR_OK : GR_ERROR_UNSUPPORTED; /* not a Win32 window */
    }
    out->backend = GR_BACKEND_VULKAN;
    out->handle_a = object->window;
    return GR_OK;
}

gr_result gr_sdl_vulkan_extensions(uint32_t *out_count, const char *const **out_names)
{
    uint32_t count = 0;
    const char *const *names;
    if (!out_count || !out_names)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!gr_sdl_available())
        return GR_ERROR_UNSUPPORTED;
    names = g_sdl.Vulkan_GetInstanceExtensions(&count);
    if (!names || count == 0)
        return GR_ERROR_BACKEND;
    *out_count = count;
    *out_names = names;
    return GR_OK;
}

gr_result gr_sdl_vulkan_create_surface(uint64_t instance, uint64_t sdl_window, uint64_t *out_surface)
{
    uint64_t surface = 0;
    if (!out_surface || !instance || !sdl_window)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_surface = 0;
    if (!gr_sdl_available())
        return GR_ERROR_UNSUPPORTED;
    /* SDL3 takes the window first and the instance second; SDL2 had the opposite order, which is
     * the kind of difference that compiles either way. */
    if (!g_sdl.Vulkan_CreateSurface((void *)(uintptr_t)sdl_window, (void *)(uintptr_t)instance,
                                    NULL, &surface))
        return GR_ERROR_BACKEND;
    *out_surface = surface;
    return GR_OK;
}

void gr_sdl_vulkan_destroy_surface(uint64_t instance, uint64_t surface)
{
    if (gr_sdl_available() && g_sdl.Vulkan_DestroySurface && surface)
        g_sdl.Vulkan_DestroySurface((void *)(uintptr_t)instance, surface, NULL);
}

#else /* !GRAIL_HAVE_DLOPEN */

int gr_sdl_available(void) { return 0; }
int gr_sdl_backend_is_sdl3(void) { return 0; }
gr_result gr_window_set_backend(gr_window_backend backend)
{
    return backend == GR_WINDOW_BACKEND_NULL ? GR_OK : GR_ERROR_UNSUPPORTED;
}
gr_result gr_sdl_window_create(const gr_window_desc *d, gr_handle *o) { (void)d; (void)o; return GR_ERROR_UNSUPPORTED; }
void gr_sdl_window_destroy(gr_handle w) { (void)w; }
gr_result gr_sdl_window_get_size(gr_handle w, gr_window_size *o) { (void)w; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_sdl_window_get_native(gr_handle w, gr_window_native *o) { (void)w; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_sdl_vulkan_extensions(uint32_t *c, const char *const **n) { (void)c; (void)n; return GR_ERROR_UNSUPPORTED; }
gr_result gr_sdl_vulkan_create_surface(uint64_t i, uint64_t w, uint64_t *s) { (void)i; (void)w; (void)s; return GR_ERROR_UNSUPPORTED; }
void gr_sdl_vulkan_destroy_surface(uint64_t i, uint64_t s) { (void)i; (void)s; }

#endif
