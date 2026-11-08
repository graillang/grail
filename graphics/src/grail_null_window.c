/* grail_null_window.c - the window and input half of the null backend.
 *
 * There is no platform window and there is no input device. The point of implementing this
 * half at all is that a caller's window and input code is compiled and exercised on a
 * machine with no display, and that the shapes (a pixel size distinct from a logical size,
 * a per-frame event drain, a relative-mouse flag) are the ones the SDL3 implementation of
 * the same interface will provide. A test may inject events through
 * gr_null_window_inject() to drive the drain path.
 */
#include "grail_internal.h"
#include "../include/grail/grail_window.h"

typedef struct gr_null_window {
    gr_window_desc desc;
    gr_window_size size;
    uint32_t relative_mouse;
    uint32_t minimised;
    uint32_t focused;
    uint64_t frame;
    /* Injected events, drained by gr_window_pump(). A ring would be wrong here: the point is
     * to hand back exactly what was injected, in order, once. */
    gr_event pending[64];
    uint32_t pending_count;
} gr_null_window;

static gr_null_window *null_window(gr_handle handle, gr_result *out_status)
{
    gr_result status = GR_OK;
    gr_null_window *w = (gr_null_window *)gr_object_lookup(gr_objects(), handle,
                                                           GR_HANDLE_WINDOW, &status);
    if (out_status)
        *out_status = w ? GR_OK : status;
    return w;
}

gr_result gr_window_create(const gr_window_desc *desc, gr_handle *out_window)
{
    gr_null_window *w;
    gr_handle handle;

    if (!desc || !out_window)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_window = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_window_desc))
        return GR_ERROR_VERSION_MISMATCH;

    gr_objects_init_once();
    w = (gr_null_window *)calloc(1, sizeof(*w));
    if (!w)
        return GR_ERROR_OUT_OF_MEMORY;
    w->desc = *desc;
    w->size.logical_width = desc->width ? desc->width : 1280u;
    w->size.logical_height = desc->height ? desc->height : 720u;
    /* No HiDPI display exists, so pixels equal points and the scale is 1. A caller that
     * conflates the two will still work here and fail on a real display; that is why the
     * contract asks for both and why the test asserts they can differ. */
    w->size.pixel_width = w->size.logical_width;
    w->size.pixel_height = w->size.logical_height;
    w->size.scale = 1.0f;
    w->focused = (desc->flags & GR_WINDOW_HIDDEN) ? 0u : 1u;

    handle = gr_object_insert(gr_objects(), GR_HANDLE_WINDOW, w);
    if (handle == GR_NULL_HANDLE) {
        free(w);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_window = handle;
    return GR_OK;
}

void gr_window_destroy(gr_handle window)
{
    gr_null_window *w = gr_object_remove(gr_objects(), window, GR_HANDLE_WINDOW);
    free(w);
}

gr_result gr_window_get_size(gr_handle window, gr_window_size *out)
{
    gr_result status;
    gr_null_window *w = null_window(window, &status);
    if (!w || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    *out = w->size;
    return GR_OK;
}

gr_result gr_window_get_native(gr_handle window, gr_window_native *out)
{
    gr_result status;
    gr_null_window *w = null_window(window, &status);
    if (!w || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(out, 0, sizeof(*out));
    out->backend = GR_BACKEND_NULL;
    /* No native handle exists. A backend asked for one by a device created with this window
     * must refuse rather than receive a fabricated pointer. */
    out->handle_a = NULL;
    out->handle_b = NULL;
    out->display_id = 0;
    return GR_OK;
}

gr_result gr_window_resolve_present_mode(gr_handle window, gr_present_mode wanted,
                                         gr_present_mode *out)
{
    gr_result status;
    gr_null_window *w = null_window(window, &status);
    if (!w || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (wanted > GR_PRESENT_FIFO_RELAXED)
        return GR_ERROR_INVALID_ARGUMENT;
    /* Every mode is available: with no display there is nothing to clamp to. */
    *out = wanted;
    return GR_OK;
}

gr_result gr_window_pump(gr_handle window, gr_event *events, uint32_t capacity,
                         uint32_t *out_count, gr_mut_span_u8 text_out, size_t *out_text_used)
{
    gr_result status;
    gr_null_window *w = null_window(window, &status);
    uint32_t written = 0;
    if (!w)
        return status;
    if (out_text_used)
        *out_text_used = 0;
    (void)text_out;
    if (capacity && !events)
        return GR_ERROR_INVALID_ARGUMENT;
    while (written < capacity && written < w->pending_count) {
        events[written] = w->pending[written];
        written++;
    }
    /* Whatever was not returned stays queued, so a caller with a small array loses nothing. */
    if (written) {
        uint32_t left = w->pending_count - written;
        uint32_t i;
        for (i = 0; i < left; ++i)
            w->pending[i] = w->pending[written + i];
        w->pending_count = left;
    }
    if (out_count)
        *out_count = written;
    return GR_OK;
}

gr_result gr_window_input_state(gr_handle window, gr_input_state *out)
{
    gr_result status;
    gr_null_window *w = null_window(window, &status);
    if (!w || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_input_state))
        return GR_ERROR_VERSION_MISMATCH;
    memset(out, 0, sizeof(*out));
    out->head.size = (uint32_t)sizeof(*out);
    out->relative_mouse = w->relative_mouse;
    out->focused = w->focused;
    out->frame = w->frame;
    w->frame++;
    return GR_OK;
}

int gr_window_key_down(gr_handle window, gr_key key)
{
    gr_null_window *w = null_window(window, NULL);
    if (!w)
        return 0;
    if ((uint32_t)key >= (uint32_t)GR_KEY_COUNT && (uint32_t)key < 0x1000u)
        return 0;
    return 0; /* no input device */
}

gr_result gr_window_set_relative_mouse(gr_handle window, int enabled)
{
    gr_result status;
    gr_null_window *w = null_window(window, &status);
    if (!w)
        return status;
    w->relative_mouse = enabled ? 1u : 0u;
    return GR_OK;
}

uint32_t gr_window_display_count(void) { return 1u; }

gr_result gr_window_display_query(uint32_t index, gr_display_info *out)
{
    if (!out || index != 0)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(out, 0, sizeof(*out));
    out->index = 0;
    out->name = (gr_str)GR_STR("grail null display");
    out->refresh_hz = 60.0f;
    out->hdr = 0;
    out->width = 1920;
    out->height = 1080;
    return GR_OK;
}

gr_result gr_window_clipboard_text(gr_handle window, gr_mut_span_u8 buffer, size_t *out_used)
{
    gr_null_window *w = null_window(window, NULL);
    if (!w)
        return GR_ERROR_INVALID_HANDLE;
    if (out_used)
        *out_used = 0;
    (void)buffer;
    return GR_OK;
}

/* Test hook, not part of the ABI: injects one event into the window's queue so that the
 * drain path in gr_window_pump() is exercised. Declared by the test, not by a public header. */
gr_result gr_null_window_inject(gr_handle window, const gr_event *event);

gr_result gr_null_window_inject(gr_handle window, const gr_event *event)
{
    gr_null_window *w = null_window(window, NULL);
    if (!w || !event)
        return GR_ERROR_INVALID_ARGUMENT;
    if (w->pending_count >= (uint32_t)(sizeof(w->pending) / sizeof(w->pending[0])))
        return GR_ERROR_EXHAUSTED;
    w->pending[w->pending_count++] = *event;
    /* A resize injected by a test moves the pixel size, so the "minimised is zero pixels"
     * rule can be checked. */
    if (event->type == GR_EVENT_RESIZED) {
        w->size.pixel_width = (uint32_t)event->a;
        w->size.pixel_height = (uint32_t)event->b;
    } else if (event->type == GR_EVENT_MINIMISED) {
        w->minimised = event->a ? 1u : 0u;
        if (w->minimised) {
            w->size.pixel_width = 0;
            w->size.pixel_height = 0;
        } else {
            w->size.pixel_width = w->size.logical_width;
            w->size.pixel_height = w->size.logical_height;
        }
    } else if (event->type == GR_EVENT_FOCUS_LOST) {
        w->focused = event->a ? 0u : 1u;
    }
    return GR_OK;
}
