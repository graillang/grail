/* grail_graph.h - the render graph: passes and resources declared, order and barriers derived.
 *
 * A frame is described, not ordered. A pass names the resources it reads and the resources it
 * writes; the graph works out what may run when, which passes are dead, and which layout
 * transitions each pass needs. Nothing here touches a GPU, a device or a backend: the output is
 * an execution order and a list of gr_barrier values that gr_cmd_barrier already accepts, which is
 * what keeps this layer testable on a machine with no driver.
 *
 * The graph does not own resources. It tracks the *state* of resources the caller owns, which is
 * what a barrier is derived from: given where a resource is and where a pass needs it, the
 * transition is not a matter of opinion.
 *
 * Lifecycle:
 *
 *     gr_graph_create / gr_graph_reset
 *     gr_graph_import        (a resource that exists before the frame, with its current state)
 *     gr_graph_add_resource  (a resource the frame creates; its state starts at UNDEFINED)
 *     gr_graph_add_pass
 *     gr_graph_pass_read / gr_graph_pass_write      (repeatable, per resource and state)
 *     gr_graph_pass_depends                          (optional: an edge no access implies)
 *     gr_graph_compile                               (validate, cull, order, derive barriers)
 *     gr_graph_execution_order / gr_graph_pass_barriers
 *
 * Compile is where every check happens, so a caller cannot submit a frame that was never
 * validated. A compile that fails leaves the report's error, and the offending pass and resource,
 * set.
 */
#ifndef GRAIL_GRAPH_H
#define GRAIL_GRAPH_H

#include "grail_abi.h"
#include "grail_rhi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Capacities. A frame beyond these is GR_ERROR_EXHAUSTED from the call that would exceed them,
 * which is a build-time conversation rather than a run-time surprise. */
enum {
    GR_GRAPH_MAX_RESOURCES = 128,
    GR_GRAPH_MAX_PASSES = 64,
    GR_GRAPH_MAX_ACCESSES = 512,
    GR_GRAPH_MAX_EDGES = 512,
    GR_GRAPH_MAX_BARRIERS = 512,
    GR_GRAPH_MAX_NAME = 48
};

typedef uint32_t gr_graph_resource;   /* index into the graph's resources */
typedef uint32_t gr_graph_pass;       /* index into the graph's passes */

#define GR_GRAPH_RESOURCE_NONE 0xFFFFFFFFu
#define GR_GRAPH_PASS_NONE 0xFFFFFFFFu

typedef enum gr_graph_resource_kind {
    GR_GRAPH_RESOURCE_TEXTURE = 0,
    GR_GRAPH_RESOURCE_BUFFER = 1
} gr_graph_resource_kind;

typedef enum gr_graph_error {
    GR_GRAPH_OK = 0,
    GR_GRAPH_ERROR_DUPLICATE_PASS,     /* two passes with the same name */
    GR_GRAPH_ERROR_DUPLICATE_WRITE,    /* one pass writes the same resource twice */
    GR_GRAPH_ERROR_UNKNOWN_RESOURCE,   /* an access names a resource the graph does not know */
    GR_GRAPH_ERROR_USE_BEFORE_WRITE,   /* a read with no writer and no imported initial state */
    GR_GRAPH_ERROR_CYCLE,              /* the dependency edges contain a cycle */
    GR_GRAPH_ERROR_TOO_MANY,           /* a capacity above was exceeded */
    GR_GRAPH_ERROR_INVALID_STATE,      /* an access state that cannot be a destination */
    GR_GRAPH_ERROR_EMPTY               /* nothing to compile */
} gr_graph_error;

const char *gr_graph_error_name(gr_graph_error error);

typedef struct gr_graph_compile_report {
    gr_desc_head head;
    gr_graph_error error;
    gr_graph_pass error_pass;         /* GR_GRAPH_PASS_NONE when the error is not pass-specific */
    gr_graph_resource error_resource; /* GR_GRAPH_RESOURCE_NONE when not resource-specific */
    uint32_t pass_count;              /* passes declared */
    uint32_t live_count;              /* passes that will execute */
    uint32_t culled_count;            /* passes proven dead */
    uint32_t barrier_count;           /* transitions derived */
    uint32_t edge_count;
} gr_graph_compile_report;

typedef struct gr_graph_desc {
    gr_desc_head head;
    uint32_t flags;                   /* reserved; 0 */
} gr_graph_desc;

gr_handle gr_graph_create(const gr_graph_desc *desc, gr_handle *out_graph);
void gr_graph_destroy(gr_handle graph);
/* Clears every declaration, keeping the graph's identity. A frame loop calls this once a frame
 * rather than destroying and recreating. */
gr_result gr_graph_reset(gr_handle graph);

/* Declares a resource the caller owns. `handle` is what the barriers will name, so the graph's
 * output feeds gr_cmd_barrier without translation. A created resource starts at
 * GR_STATE_UNDEFINED: its contents are not to be read before something writes them. */
gr_result gr_graph_add_resource(gr_handle graph, gr_str name, gr_graph_resource_kind kind,
                                gr_handle handle, gr_graph_resource *out_resource);
/* Declares a resource that exists before this frame, in `state`. This is what makes a read
 * before any write legal — an imported swapchain image or a previous frame's history buffer. */
gr_result gr_graph_import(gr_handle graph, gr_str name, gr_graph_resource_kind kind,
                          gr_handle handle, uint32_t state, gr_graph_resource *out_resource);

gr_result gr_graph_add_pass(gr_handle graph, gr_str name, gr_graph_pass *out_pass);
/* A pass with side effects is never culled: it does something the graph cannot see, such as
 * presenting or writing an imported resource. */
gr_result gr_graph_pass_set_side_effect(gr_handle graph, gr_graph_pass pass, int side_effect);
/* Declares that `pass` reads or writes `resource`, arriving in `state`. A pass may read the same
 * resource more than once in different states; it may write it once. */
gr_result gr_graph_pass_read(gr_handle graph, gr_graph_pass pass, gr_graph_resource resource,
                             uint32_t state);
gr_result gr_graph_pass_write(gr_handle graph, gr_graph_pass pass, gr_graph_resource resource,
                              uint32_t state);
/* An ordering edge that no access implies. This is the only way to build a cycle, and a cycle is
 * refused rather than ordered arbitrarily. */
gr_result gr_graph_pass_depends(gr_handle graph, gr_graph_pass pass, gr_graph_pass depends_on);

/* Validates, culls, orders and derives barriers. Idempotent: calling it twice is not an error and
 * recompiles from the same declarations. */
gr_result gr_graph_compile(gr_handle graph, gr_graph_compile_report *out_report);

/* The pass at `index` in execution order. Indices are dense over the live passes only. */
gr_result gr_graph_execution_order(gr_handle graph, uint32_t index, gr_graph_pass *out_pass);
/* The barriers the pass at `index` in execution order needs, in submission order. Fills up to
 * `capacity` and writes the total needed to `out_count`, so a caller can size its array from a
 * first call with capacity 0. */
gr_result gr_graph_pass_barriers(gr_handle graph, uint32_t index, gr_barrier *out,
                                 uint32_t capacity, uint32_t *out_count);
/* The state a resource is in after the frame, for the next frame to import. */
gr_result gr_graph_final_state(gr_handle graph, gr_graph_resource resource, uint32_t *out_state);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_GRAPH_H */
