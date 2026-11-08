/* grail_graph.c - the render graph: declaration, validation, culling, ordering, barriers.
 *
 * No GPU, no device, no backend: this is the layer that decides what a frame *is*, which is why it
 * can be tested exhaustively on a machine with no driver. The only concepts it shares with a
 * backend are gr_barrier and gr_resource_state, both already in the ABI.
 *
 * The interesting decisions:
 *
 *   Order comes from dependencies, not from declaration order. Passes may be declared in any
 *   order; edges are derived by versioning each resource (every access depends on the previous
 *   access to the same resource), and a topological sort produces the execution order. Declaration
 *   order only breaks ties, which is why a caller can reorganise a frame without changing it.
 *
 *   A cycle can only come from an explicit gr_graph_pass_depends edge, because resource versioning
 *   always points forward. Refusing it rather than picking an order is the point: a cyclic frame
 *   has no correct execution order to pick.
 *
 *   Barriers are derived, not declared. Each resource carries the state it is in; when a pass
 *   needs a different state, the transition is emitted before that pass and the resource's state
 *   advances. A pass that reads what the previous pass wrote in the same state gets no barrier,
 *   which is the whole reason to derive them instead of hand-writing them.
 *
 *   Culling runs backwards from the passes that must happen (side effects), keeping a pass only if
 *   something live consumes what it writes. A write to a resource nothing reads and no effect
 *   depends on is dead, and so, transitively, is the chain that fed it.
 */
#include "grail_internal.h"
#include "../include/grail/grail_graph.h"

typedef struct graph_resource {
    char name[GR_GRAPH_MAX_NAME];
    uint32_t name_len;
    gr_graph_resource_kind kind;
    gr_handle handle;
    uint32_t initial_state;
    uint32_t housekeeping; /* imported flag */
    uint32_t final_state;
} graph_resource;

typedef struct graph_pass {
    char name[GR_GRAPH_MAX_NAME];
    uint32_t name_len;
    uint32_t side_effect;
    uint32_t first_access;   /* into accesses, contiguous per pass */
    uint32_t access_count;
    uint32_t live;
    uint32_t order;          /* position in the execution order, or ~0u */
    uint32_t first_barrier;
    uint32_t barrier_count;
} graph_pass;

typedef struct graph_access {
    uint32_t pass;
    uint32_t resource;
    uint32_t state;
    uint32_t is_write;
} graph_access;

typedef struct graph_edge {
    uint32_t from;
    uint32_t to;
} graph_edge;

typedef struct graph_barrier {
    gr_barrier barrier;
} graph_barrier;

typedef struct graph {
    graph_resource resources[GR_GRAPH_MAX_RESOURCES];
    uint32_t resource_count;
    graph_pass passes[GR_GRAPH_MAX_PASSES];
    uint32_t pass_count;
    graph_access accesses[GR_GRAPH_MAX_ACCESSES];
    uint32_t access_count;
    graph_edge edges[GR_GRAPH_MAX_EDGES];
    uint32_t explicit_edges; /* added by gr_graph_pass_depends: caller state, survives a reset of
                              * the derived state */
    uint32_t edge_count;
    graph_barrier barriers[GR_GRAPH_MAX_BARRIERS];
    uint32_t barrier_count;
    uint32_t order[GR_GRAPH_MAX_PASSES];   /* live passes, in execution order */
    uint32_t order_count;
    uint32_t compiled;
    gr_graph_error error;
    uint32_t error_pass;
    uint32_t error_resource;
} graph;

static void graph_clear_derived(graph *g)
{
    /* Derived edges start after the caller's; dropping them is a count reset, not a clear. Wiping
     * edge_count to zero here would discard the explicit edges and make gr_graph_pass_depends a
     * no-op, which is exactly the bug this comment exists because of. */
    g->edge_count = g->explicit_edges;
    g->barrier_count = 0;
    g->order_count = 0;
    g->compiled = 0;
    g->error = GR_GRAPH_OK;
    g->error_pass = GR_GRAPH_PASS_NONE;
    g->error_resource = GR_GRAPH_RESOURCE_NONE;
}

static graph *graph_of(gr_handle handle)
{
    return (graph *)gr_object_lookup(gr_objects(), handle, GR_HANDLE_GRAPH, NULL);
}

static void set_error(graph *g, gr_graph_error error, uint32_t pass, uint32_t resource)
{
    g->error = error;
    g->error_pass = pass;
    g->error_resource = resource;
}

static int names_equal(const char *a, uint32_t a_len, const char *b, uint32_t b_len)
{
    return a_len == b_len && memcmp(a, b, a_len) == 0;
}

const char *gr_graph_error_name(gr_graph_error error)
{
    switch (error) {
    case GR_GRAPH_OK: return "ok";
    case GR_GRAPH_ERROR_DUPLICATE_PASS: return "duplicate_pass";
    case GR_GRAPH_ERROR_DUPLICATE_WRITE: return "duplicate_write";
    case GR_GRAPH_ERROR_UNKNOWN_RESOURCE: return "unknown_resource";
    case GR_GRAPH_ERROR_USE_BEFORE_WRITE: return "use_before_write";
    case GR_GRAPH_ERROR_CYCLE: return "cycle";
    case GR_GRAPH_ERROR_TOO_MANY: return "too_many";
    case GR_GRAPH_ERROR_INVALID_STATE: return "invalid_state";
    case GR_GRAPH_ERROR_EMPTY: return "empty";
    default: return "unknown";
    }
}

gr_handle gr_graph_create(const gr_graph_desc *desc, gr_handle *out_graph)
{
    graph *g;
    gr_handle handle;
    if (!desc || !out_graph)
        return GR_NULL_HANDLE;
    *out_graph = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_graph_desc))
        return GR_NULL_HANDLE;
    g = (graph *)calloc(1, sizeof(*g));
    if (!g)
        return GR_NULL_HANDLE;
    graph_clear_derived(g);
    gr_objects_init_once();
    handle = gr_object_insert(gr_objects(), GR_HANDLE_GRAPH, g);
    if (handle == GR_NULL_HANDLE) {
        free(g);
        return GR_NULL_HANDLE;
    }
    *out_graph = handle;
    return handle;
}

void gr_graph_destroy(gr_handle graph_handle)
{
    graph *g = (graph *)gr_object_remove(gr_objects(), graph_handle, GR_HANDLE_GRAPH);
    free(g);
}

gr_result gr_graph_reset(gr_handle graph_handle)
{
    graph *g = graph_of(graph_handle);
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    /* Every array is reset, not just the counters: a stale access from the previous frame would
     * otherwise be read by the next compile under a matching index. */
    memset(g, 0, sizeof(*g));
    graph_clear_derived(g);
    return GR_OK;
}

static gr_result graph_add(graph *g, graph_resource **out_resource, gr_str name,
                           gr_graph_resource_kind kind, gr_handle handle, int imported,
                           uint32_t state)
{
    graph_resource *resource;
    if (!g || !name.data || name.len == 0 || name.len >= GR_GRAPH_MAX_NAME)
        return GR_ERROR_INVALID_ARGUMENT;
    if (g->resource_count >= GR_GRAPH_MAX_RESOURCES)
        return GR_ERROR_EXHAUSTED;
    resource = &g->resources[g->resource_count];
    memcpy(resource->name, name.data, name.len);
    resource->name[name.len] = '\0';
    resource->name_len = name.len;
    resource->kind = kind;
    resource->handle = handle;
    resource->housekeeping = imported ? 1u : 0u;
    resource->initial_state = imported ? state : GR_STATE_UNDEFINED;
    resource->final_state = resource->initial_state;
    if (out_resource)
        *out_resource = resource;
    return GR_OK;
}

gr_result gr_graph_add_resource(gr_handle graph_handle, gr_str name, gr_graph_resource_kind kind,
                                gr_handle handle, gr_graph_resource *out_resource)
{
    graph *g = graph_of(graph_handle);
    graph_resource *resource = NULL;
    gr_result status;
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    status = graph_add(g, &resource, name, kind, handle, 0, 0);
    if (status != GR_OK)
        return status;
    if (out_resource)
        *out_resource = g->resource_count;
    g->resource_count++;
    graph_clear_derived(g);
    return GR_OK;
}

gr_result gr_graph_import(gr_handle graph_handle, gr_str name, gr_graph_resource_kind kind,
                          gr_handle handle, uint32_t state, gr_graph_resource *out_resource)
{
    graph *g = graph_of(graph_handle);
    graph_resource *resource = NULL;
    gr_result status;
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    if (state == GR_STATE_UNDEFINED)
        return GR_ERROR_INVALID_ARGUMENT; /* importing "nothing" is not an import */
    status = graph_add(g, &resource, name, kind, handle, 1, state);
    if (status != GR_OK)
        return status;
    if (out_resource)
        *out_resource = g->resource_count;
    g->resource_count++;
    graph_clear_derived(g);
    return GR_OK;
}

gr_result gr_graph_add_pass(gr_handle graph_handle, gr_str name, gr_graph_pass *out_pass)
{
    graph *g = graph_of(graph_handle);
    graph_pass *pass;
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    if (!name.data || name.len == 0 || name.len >= GR_GRAPH_MAX_NAME)
        return GR_ERROR_INVALID_ARGUMENT;
    if (g->pass_count >= GR_GRAPH_MAX_PASSES)
        return GR_ERROR_EXHAUSTED;
    pass = &g->passes[g->pass_count];
    memset(pass, 0, sizeof(*pass));
    memcpy(pass->name, name.data, name.len);
    pass->name[name.len] = '\0';
    pass->name_len = name.len;
    pass->first_access = g->access_count;
    pass->order = GR_GRAPH_PASS_NONE;
    if (out_pass)
        *out_pass = g->pass_count;
    g->pass_count++;
    graph_clear_derived(g);
    return GR_OK;
}

gr_result gr_graph_pass_set_side_effect(gr_handle graph_handle, gr_graph_pass pass_index,
                                        int side_effect)
{
    graph *g = graph_of(graph_handle);
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    if (pass_index >= g->pass_count)
        return GR_ERROR_INVALID_ARGUMENT;
    g->passes[pass_index].side_effect = side_effect ? 1u : 0u;
    graph_clear_derived(g);
    return GR_OK;
}

static gr_result pass_access(graph *g, gr_graph_pass pass_index, gr_graph_resource resource_index,
                             uint32_t state, int write)
{
    graph_access *access;
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    if (pass_index >= g->pass_count || resource_index >= g->resource_count)
        return GR_ERROR_INVALID_ARGUMENT;
    if (state == GR_STATE_UNDEFINED)
        return GR_ERROR_INVALID_ARGUMENT; /* a pass cannot arrive in "undefined" */
    if (g->access_count >= GR_GRAPH_MAX_ACCESSES)
        return GR_ERROR_EXHAUSTED;
    access = &g->accesses[g->access_count];
    access->pass = pass_index;
    access->resource = resource_index;
    access->state = state;
    access->is_write = write ? 1u : 0u;
    g->access_count++;
    g->passes[pass_index].access_count++;
    graph_clear_derived(g);
    return GR_OK;
}

gr_result gr_graph_pass_read(gr_handle graph_handle, gr_graph_pass pass,
                             gr_graph_resource resource, uint32_t state)
{
    graph *g = graph_of(graph_handle);
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    return pass_access(g, pass, resource, state, 0);
}

gr_result gr_graph_pass_write(gr_handle graph_handle, gr_graph_pass pass,
                              gr_graph_resource resource, uint32_t state)
{
    graph *g = graph_of(graph_handle);
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    return pass_access(g, pass, resource, state, 1);
}

gr_result gr_graph_pass_depends(gr_handle graph_handle, gr_graph_pass pass,
                                gr_graph_pass depends_on)
{
    graph *g = graph_of(graph_handle);
    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    if (pass >= g->pass_count || depends_on >= g->pass_count)
        return GR_ERROR_INVALID_ARGUMENT;
    if (g->explicit_edges >= GR_GRAPH_MAX_EDGES)
        return GR_ERROR_EXHAUSTED;
    g->edges[g->explicit_edges].from = depends_on;
    g->edges[g->explicit_edges].to = pass;
    g->explicit_edges++;
    graph_clear_derived(g);
    return GR_OK;
}

/* ---------------------------------------------------------------------------------------
 * Compile
 * --------------------------------------------------------------------------------------- */
static void add_edge(graph *g, uint32_t from, uint32_t to)
{
    if (from == to || from >= g->pass_count || to >= g->pass_count)
        return;
    if (g->edge_count >= GR_GRAPH_MAX_EDGES)
        return;
    g->edges[g->edge_count].from = from;
    g->edges[g->edge_count].to = to;
    g->edge_count++;
}

gr_result gr_graph_compile(gr_handle graph_handle, gr_graph_compile_report *out_report)
{
    graph *g = graph_of(graph_handle);
    uint32_t i, j;
    uint32_t explicit_edges;
    uint32_t indegree[GR_GRAPH_MAX_PASSES];
    uint32_t queue[GR_GRAPH_MAX_PASSES];
    uint32_t head = 0, tail = 0;
    int changed;
    gr_result result = GR_OK;

    if (!g)
        return GR_ERROR_INVALID_HANDLE;
    if (out_report && out_report->head.size != 0 &&
        out_report->head.size < sizeof(gr_graph_compile_report))
        return GR_ERROR_VERSION_MISMATCH;

    explicit_edges = g->explicit_edges; /* the caller's edges survive; derived ones are rebuilt */
    graph_clear_derived(g);
    g->edge_count = explicit_edges;

    /* Duplicate pass names: two passes called "shadow" make every report ambiguous. */
    for (i = 0; i < g->pass_count; ++i)
        for (j = 0; j < i; ++j)
            if (names_equal(g->passes[i].name, g->passes[i].name_len, g->passes[j].name,
                            g->passes[j].name_len)) {
                set_error(g, GR_GRAPH_ERROR_DUPLICATE_PASS, i, GR_GRAPH_RESOURCE_NONE);
                goto finish;
            }

    if (g->pass_count == 0) {
        set_error(g, GR_GRAPH_ERROR_EMPTY, GR_GRAPH_PASS_NONE, GR_GRAPH_RESOURCE_NONE);
        goto finish;
    }

    /* One write per resource per pass: two writes in one pass have no order between them, so
     * neither the barrier derivation nor the culling could be correct. */
    for (i = 0; i < g->access_count; ++i) {
        if (!g->accesses[i].is_write)
            continue;
        for (j = i + 1; j < g->access_count; ++j)
            if (g->accesses[j].is_write &&
                g->accesses[j].pass == g->accesses[i].pass &&
                g->accesses[j].resource == g->accesses[i].resource) {
                set_error(g, GR_GRAPH_ERROR_DUPLICATE_WRITE, g->accesses[i].pass,
                          g->accesses[i].resource);
                goto finish;
            }
    }

    /* Use before write: a read is legal when the resource was imported (it exists already) or some
     * earlier access wrote it. Declaration order is the versioning order. */
    {
        uint8_t written[GR_GRAPH_MAX_RESOURCES];
        for (i = 0; i < g->resource_count; ++i)
            written[i] = (uint8_t)g->resources[i].housekeeping;
        for (i = 0; i < g->access_count; ++i) {
            const graph_access *access = &g->accesses[i];
            if (!access->is_write && !written[access->resource]) {
                set_error(g, GR_GRAPH_ERROR_USE_BEFORE_WRITE, access->pass, access->resource);
                goto finish;
            }
            if (access->is_write)
                written[access->resource] = 1;
        }
    }

    /* Version edges: every access depends on the previous access to the same resource. */
    for (i = 0; i < g->access_count; ++i) {
        uint32_t previous = GR_GRAPH_PASS_NONE;
        for (j = 0; j < i; ++j)
            if (g->accesses[j].resource == g->accesses[i].resource)
                previous = g->accesses[j].pass;
        if (previous != GR_GRAPH_PASS_NONE)
            add_edge(g, previous, g->accesses[i].pass);
    }

    /* Topological sort (Kahn). Declaration order breaks ties, so a frame that is already in order
     * keeps its order. */
    memset(indegree, 0, sizeof(indegree));
    for (i = 0; i < g->edge_count; ++i)
        indegree[g->edges[i].to]++;
    for (i = 0; i < g->pass_count; ++i)
        if (indegree[i] == 0)
            queue[tail++] = i;
    g->order_count = 0;
    while (head < tail) {
        uint32_t current = queue[head++];
        g->order[g->order_count] = current;
        g->passes[current].order = g->order_count;
        g->order_count++;
        for (i = 0; i < g->edge_count; ++i)
            if (g->edges[i].from == current && --indegree[g->edges[i].to] == 0)
                queue[tail++] = g->edges[i].to;
    }
    if (g->order_count != g->pass_count) {
        /* Whatever did not come out of the sort is in, or downstream of, a cycle. */
        for (i = 0; i < g->pass_count; ++i)
            if (g->passes[i].order == GR_GRAPH_PASS_NONE) {
                set_error(g, GR_GRAPH_ERROR_CYCLE, i, GR_GRAPH_RESOURCE_NONE);
                break;
            }
        goto finish;
    }

    /* Liveness, backwards: a pass matters if it has a side effect or writes something a live pass
     * reads. Iterate to a fixpoint over the reverse execution order, so a chain of dead passes
     * collapses in one compile. */
    for (i = 0; i < g->pass_count; ++i)
        g->passes[i].live = g->passes[i].side_effect ? 1u : 0u;
    changed = 1;
    while (changed) {
        changed = 0;
        for (i = g->order_count; i-- > 0;) {
            uint32_t pass_index = g->order[i];
            const graph_pass *pass = &g->passes[pass_index];
            if (pass->live)
                continue;
            for (j = 0; j < g->access_count; ++j) {
                uint32_t k;
                if (!g->accesses[j].is_write || g->accesses[j].pass != pass_index)
                    continue;
                /* Does a live pass read this resource afterwards? */
                for (k = 0; k < g->access_count; ++k) {
                    if (g->accesses[k].is_write || !g->passes[g->accesses[k].pass].live)
                        continue;
                    if (g->accesses[k].resource != g->accesses[j].resource)
                        continue;
                    if (g->passes[g->accesses[k].pass].order < pass->order)
                        continue; /* the reader runs before this write: not a consumer */
                    g->passes[pass_index].live = 1;
                    changed = 1;
                    break;
                }
                if (g->passes[pass_index].live)
                    break;
            }
        }
    }

    /* Execution order of the live passes, and their barriers. */
    {
        uint32_t state[GR_GRAPH_MAX_RESOURCES];
        uint32_t live_order = 0;
        for (i = 0; i < g->resource_count; ++i)
            state[i] = g->resources[i].initial_state;
        for (i = 0; i < g->order_count; ++i) {
            uint32_t pass_index = g->order[i];
            graph_pass *pass = &g->passes[pass_index];
            if (!pass->live)
                continue;
            pass->first_barrier = g->barrier_count;
            pass->barrier_count = 0;
            /* Accesses are appended in declaration order across all passes, so a pass's accesses
             * are not contiguous. Filter by pass rather than slicing a range: the range form was
             * wrong the moment two passes interleaved their declarations. */
            for (j = 0; j < g->access_count; ++j) {
                const graph_access *access = &g->accesses[j];
                if (access->pass != pass_index)
                    continue;
                if (access->state == state[access->resource])
                    continue; /* already in the state this pass needs */
                if (access->state == GR_STATE_UNDEFINED) {
                    set_error(g, GR_GRAPH_ERROR_INVALID_STATE, pass_index, access->resource);
                    goto finish;
                }
                if (g->barrier_count >= GR_GRAPH_MAX_BARRIERS) {
                    set_error(g, GR_GRAPH_ERROR_TOO_MANY, pass_index, access->resource);
                    goto finish;
                }
                memset(&g->barriers[g->barrier_count].barrier, 0, sizeof(gr_barrier));
                g->barriers[g->barrier_count].barrier.resource =
                    g->resources[access->resource].handle;
                g->barriers[g->barrier_count].barrier.src_state = state[access->resource];
                g->barriers[g->barrier_count].barrier.dst_state = access->state;
                g->barrier_count++;
                pass->barrier_count++;
                state[access->resource] = access->state;
            }
            g->order[live_order] = pass_index;
            g->passes[pass_index].order = live_order;
            live_order++;
        }
        g->order_count = live_order;
        for (i = 0; i < g->resource_count; ++i)
            g->resources[i].final_state = state[i];
    }

    g->compiled = 1;

finish:
    result = (g->error == GR_GRAPH_OK) ? GR_OK : GR_ERROR_VALIDATION_FAILED;
    if (g->error == GR_GRAPH_ERROR_TOO_MANY)
        result = GR_ERROR_EXHAUSTED;
    if (out_report) {
        memset(out_report, 0, sizeof(*out_report));
        out_report->head.size = (uint32_t)sizeof(*out_report);
        out_report->error = g->error;
        out_report->error_pass = g->error_pass;
        out_report->error_resource = g->error_resource;
        out_report->pass_count = g->pass_count;
        out_report->live_count = g->order_count;
        out_report->culled_count = g->pass_count - g->order_count;
        out_report->barrier_count = g->barrier_count;
        out_report->edge_count = g->edge_count;
    }
    return result;
}

gr_result gr_graph_execution_order(gr_handle graph_handle, uint32_t index,
                                   gr_graph_pass *out_pass)
{
    graph *g = graph_of(graph_handle);
    if (!g || !out_pass)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!g->compiled)
        return GR_ERROR_NOT_READY;
    if (index >= g->order_count)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pass = g->order[index];
    return GR_OK;
}

gr_result gr_graph_pass_barriers(gr_handle graph_handle, uint32_t index, gr_barrier *out,
                                 uint32_t capacity, uint32_t *out_count)
{
    graph *g = graph_of(graph_handle);
    const graph_pass *pass;
    uint32_t copy;
    if (!g || !out_count)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!g->compiled)
        return GR_ERROR_NOT_READY;
    if (index >= g->order_count)
        return GR_ERROR_INVALID_ARGUMENT;
    pass = &g->passes[g->order[index]];
    *out_count = pass->barrier_count;
    if (capacity == 0)
        return GR_OK; /* a sizing call */
    if (!out)
        return GR_ERROR_INVALID_ARGUMENT;
    copy = capacity < pass->barrier_count ? capacity : pass->barrier_count;
    memcpy(out, &g->barriers[pass->first_barrier].barrier, copy * sizeof(gr_barrier));
    return copy < pass->barrier_count ? GR_NEED_MORE : GR_OK;
}

gr_result gr_graph_final_state(gr_handle graph_handle, gr_graph_resource resource,
                               uint32_t *out_state)
{
    graph *g = graph_of(graph_handle);
    if (!g || !out_state)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!g->compiled)
        return GR_ERROR_NOT_READY;
    if (resource >= g->resource_count)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_state = g->resources[resource].final_state;
    return GR_OK;
}
