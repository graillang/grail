/* grail_window.h - window and input contract.
 *
 * Who owns what. SDL3 owns the platform window, the event queue and input. The RHI owns
 * the GPU instance, device and swapchain. The two meet at exactly one value: a
 * gr_window_native, which the backend turns into a VkSurfaceKHR, an HWND-backed swapchain
 * or a CAMetalLayer. This split matches Abundance's own engine, which creates its VkDevice
 * itself and asks SDL for the surface (abundance/engine/core/device.hpp: DeviceCreate
 * carries an SDL_Window* that only the surface path reads).
 *
 * SDL3 is a hard requirement of the window layer and of no other layer: a headless process
 * creates a device with window = GR_NULL_HANDLE and never includes this header.
 *
 * Input is polled, not callbacks. The loop pumps events into a caller-owned array and reads
 * one gr_input_state snapshot per frame. Nothing here allocates.
 */
#ifndef GRAIL_WINDOW_H
#define GRAIL_WINDOW_H

#include "grail_abi.h"
#include "grail_rhi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------------------------
 * Creation.
 * --------------------------------------------------------------------------------------- */
typedef enum gr_window_flags {
    GR_WINDOW_NONE = 0,
    GR_WINDOW_RESIZABLE = 1u << 0,
    GR_WINDOW_HIGH_DPI = 1u << 1,   /* report pixel size separately from logical size */
    GR_WINDOW_VULKAN = 1u << 2,     /* the surface will be a VkSurfaceKHR */
    GR_WINDOW_HEADLESS = 1u << 3,   /* no platform window; rendering is offscreen */
    GR_WINDOW_HIDDEN = 1u << 4,
    GR_WINDOW_BORDERLESS = 1u << 5,
    GR_WINDOW_METAL = 1u << 6,      /* create a CAMetalLayer-backed view */
    GR_WINDOW_CAPTURE = 1u << 7     /* permit offscreen capture of the presented image */
} gr_window_flags;

typedef struct gr_window_desc {
    gr_desc_head head;
    gr_str title;
    uint32_t width;          /* logical points; 0 asks for a backend default */
    uint32_t height;
    uint32_t flags;          /* gr_window_flags */
    uint32_t display_index;  /* GR_DISPLAY_AUTO, or an index from gr_window_display_count */
} gr_window_desc;

#define GR_DISPLAY_AUTO 0xFFFFFFFFu

/* Creates a window. On success writes a GR_HANDLE_WINDOW and returns GR_OK. */
gr_result gr_window_create(const gr_window_desc *desc, gr_handle *out_window);
void gr_window_destroy(gr_handle window);

/* ---------------------------------------------------------------------------------------
 * Geometry. Logical size is in points; pixel size is what a swapchain or a render target
 * must use. They differ on a HiDPI display and are equal otherwise. A zero pixel
 * dimension means minimised, and presenting must be skipped for that frame.
 * --------------------------------------------------------------------------------------- */
typedef struct gr_window_size {
    uint32_t logical_width, logical_height;
    uint32_t pixel_width, pixel_height;
    float scale;   /* pixel / logical; 1.0 when unreported */
} gr_window_size;

gr_result gr_window_get_size(gr_handle window, gr_window_size *out);

/* The native handle a backend needs. handle_a/handle_b are typed by `backend`:
 *   GR_BACKEND_VULKAN -> handle_a = SDL_Window*
 *   GR_BACKEND_METAL  -> handle_a = SDL_Window*, handle_b = CAMetalLayer* (window-owned)
 *   GR_BACKEND_D3D12  -> handle_a = HWND,        handle_b = HINSTANCE
 * The pointers are borrowed for the window's lifetime. They are deliberately NOT part of
 * the wire contract (grail_wire.h): a surface is created in the process that owns the
 * window, and a remote caller receives a swapchain handle instead. */
typedef struct gr_window_native {
    gr_backend backend;
    void *handle_a;
    void *handle_b;
    uint64_t display_id;   /* backend display identifier, 0 when unknown */
} gr_window_native;

gr_result gr_window_get_native(gr_handle window, gr_window_native *out);

/* Clamps `wanted` (gr_present_mode, grail_rhi.h) to what this window's display supports and
 * writes the choice. */
gr_result gr_window_resolve_present_mode(gr_handle window, gr_present_mode wanted,
                                         gr_present_mode *out);

/* A presentation that is not a frame yet: the caller may render an offscreen target (the
 * --headless capture path) and hand the image over. out_handled is 1 when the window
 * accepted the frame, 0 when the frame was dropped (minimised, occluded). */
typedef struct gr_present_frame {
    gr_desc_head head;
    gr_handle swapchain;      /* swapchain presented from, or GR_NULL_HANDLE for capture */
    uint32_t image_index;     /* image the swapchain handed out */
    uint32_t flags;           /* reserved; 0 */
} gr_present_frame;

/* ---------------------------------------------------------------------------------------
 * Input. Modifier bits, keys and mouse buttons are a fixed, backend-independent set so a
 * Grail program never sees SDL scancodes. Values are stable and may be extended only by
 * appending before GR_KEY_COUNT. Codes follow the USB HID usage numbering for printable
 * keys (SDL3 also uses HID usage on scancode), so a mapping table exists on both sides.
 * --------------------------------------------------------------------------------------- */
typedef enum gr_key_mod {
    GR_MOD_NONE = 0,
    GR_MOD_SHIFT = 1u << 0,
    GR_MOD_CTRL = 1u << 1,
    GR_MOD_ALT = 1u << 2,
    GR_MOD_GUI = 1u << 3,      /* Super / Windows / Command */
    GR_MOD_CAPS = 1u << 4,
    GR_MOD_NUM = 1u << 5
} gr_key_mod;

typedef enum gr_key {
    GR_KEY_UNKNOWN = 0,
    GR_KEY_ESCAPE = 0x1B,      /* printable range uses HID/ASCII-compatible values */
    GR_KEY_RETURN = 0x0D,
    GR_KEY_TAB = 0x09,
    GR_KEY_BACKSPACE = 0x08,
    GR_KEY_SPACE = 0x20,
    GR_KEY_LEFT = 0x1000,      /* non-printables are >= 0x1000 so the ranges cannot collide */
    GR_KEY_RIGHT,
    GR_KEY_UP,
    GR_KEY_DOWN,
    GR_KEY_DELETE,
    GR_KEY_HOME,
    GR_KEY_END,
    GR_KEY_PAGE_UP,
    GR_KEY_PAGE_DOWN,
    GR_KEY_INSERT,
    GR_KEY_F1, GR_KEY_F2, GR_KEY_F3, GR_KEY_F4, GR_KEY_F5, GR_KEY_F6,
    GR_KEY_F7, GR_KEY_F8, GR_KEY_F9, GR_KEY_F10, GR_KEY_F11, GR_KEY_F12,
    GR_KEY_SHIFT, GR_KEY_CTRL, GR_KEY_ALT, GR_KEY_GUI,
    GR_KEY_COUNT
} gr_key;

typedef enum gr_mouse_button {
    GR_MOUSE_LEFT = 0,
    GR_MOUSE_MIDDLE = 1,
    GR_MOUSE_RIGHT = 2,
    GR_MOUSE_X1 = 3,
    GR_MOUSE_X2 = 4,
    GR_MOUSE_BUTTON_COUNT
} gr_mouse_button;

/* One event. size is fixed so an event ring can be a flat array; `a`,`b` are the payload
 * and their meaning is a function of `type`. Everything is explicit 32/64-bit so the
 * structure is identical in memory and on the wire. */
typedef enum gr_event_type {
    GR_EVENT_NONE = 0,
    GR_EVENT_QUIT,             /* the platform asked the process to exit */
    GR_EVENT_CLOSE_REQUESTED,  /* the window's close button; a->0 */
    GR_EVENT_RESIZED,          /* a->pixel width, b->pixel height */
    GR_EVENT_MINIMISED,        /* a->1 minimised, a->0 restored */
    GR_EVENT_FOCUS_LOST,       /* a->1 lost, a->0 gained */
    GR_EVENT_KEY_DOWN,         /* a->gr_key, b->gr_key_mod; repeats set GR_EVENT_FLAG_REPEAT */
    GR_EVENT_KEY_UP,
    GR_EVENT_MOUSE_MOVE,       /* fa/fb absolute in the window, fdx/fdy since the last event */
    GR_EVENT_MOUSE_BUTTON,     /* a->gr_mouse_button, b->1 pressed, b->0 released, fa/fb position */
    GR_EVENT_MOUSE_WHEEL,      /* fdx horizontal, fdy vertical, in notches */
    GR_EVENT_TEXT_INPUT,       /* utf8_offset/utf8_len identify the text in the pump buffer */
    GR_EVENT_DPI_CHANGED,      /* fscale */
    GR_EVENT_GPU_RESET        /* the backend detected a device loss; recreate the device */
} gr_event_type;

typedef enum gr_event_flags {
    GR_EVENT_FLAG_NONE = 0,
    GR_EVENT_FLAG_REPEAT = 1u << 0
} gr_event_flags;

typedef struct gr_event {
    uint32_t type;      /* gr_event_type */
    uint32_t flags;     /* gr_event_flags */
    int32_t a, b;
    float fa, fb;
    float fdx, fdy;
    float fscale;
    uint32_t utf8_offset;   /* byte offset into the text buffer passed to gr_window_pump */
    uint32_t utf8_len;
    uint64_t timestamp_ns;
} gr_event;

/* Per-frame input snapshot. Buttons and keys are indexed by their enumeration value; a key
 * above the table's limit only appears as an event. */
typedef struct gr_input_state {
    gr_desc_head head;
    uint32_t modifiers;              /* gr_key_mod bits */
    uint32_t buttons_down;           /* bit i set => GR_MOUSE_BUTTON i is down */
    float mouse_x, mouse_y;          /* in the window, logical points */
    float mouse_dx, mouse_dy;        /* this frame's motion; meaningful with relative mode */
    float wheel_x, wheel_y;          /* this frame's accumulated wheel notches */
    uint32_t relative_mouse;         /* relative mode is currently on */
    uint32_t focused;
    uint64_t frame;                  /* frames since the window was created */
} gr_input_state;

/* Pumps the platform event queue: writes up to `capacity` events, returns the count
 * written in *out_count (0 is normal), and appends text for GR_EVENT_TEXT_INPUT into
 * `text_out` (may be NULL when capacity is 0). Call once per frame, before input_state. */
gr_result gr_window_pump(gr_handle window, gr_event *events, uint32_t capacity,
                         uint32_t *out_count, gr_mut_span_u8 text_out, size_t *out_text_used);

gr_result gr_window_input_state(gr_handle window, gr_input_state *out);
/* 1 when the key is held now. */
int gr_window_key_down(gr_handle window, gr_key key);
/* Locks the pointer to the window for a camera the way Abundance's overlay does. */
gr_result gr_window_set_relative_mouse(gr_handle window, int enabled);

/* ---------------------------------------------------------------------------------------
 * Displays. A renderer needs the refresh rate and the HDR capability before it picks a
 * format, so they are queried rather than assumed.
 * --------------------------------------------------------------------------------------- */
typedef struct gr_display_info {
    uint32_t index;
    gr_str name;
    float refresh_hz;      /* 0 when unknown */
    uint32_t hdr;          /* 1 when the display can present an HDR format */
    int32_t x, y;
    uint32_t width, height; /* desktop bounds, pixels */
} gr_display_info;

uint32_t gr_window_display_count(void);
gr_result gr_window_display_query(uint32_t index, gr_display_info *out);

/* Clipboard text for a debug overlay; the buffer is caller-owned. */
gr_result gr_window_clipboard_text(gr_handle window, gr_mut_span_u8 buffer, size_t *out_used);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_WINDOW_H */
