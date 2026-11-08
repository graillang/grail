/* test_graph.c - the render graph, with no GPU anywhere in sight.
 *
 * The graph decides what a frame is: which passes run, in what order, and which transitions they
 * need. That makes it exhaustively testable on a machine with no driver, which is the point of it
 * being a separate layer.
 */
#include "../include/grail/grail_graph.h"

#include <stdio.h>
#include <string.h>

static int failures = 0;
static int checks = 0;

#define CHECK(cond)                                                                   \
    do {                                                                              \
        checks++;                                                                     \
        if (!(cond)) {                                                                \
            failures++;                                                               \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);           \
        }                                                                             \
    } while (0)

#define CHECK_EQ(a, b)                                                                \
    do {                                                                              \
        checks++;                                                                     \
        if ((a) != (b)) {                                                             \
            failures++;                                                               \
            fprintf(stderr, "FAIL %s:%d: %s == %s (%lld != %lld)\n", __FILE__,        \
                    __LINE__, #a, #b, (long long)(a), (long long)(b));                \
        }                                                                             \
    } while (0)

static gr_handle new_graph(void)
{
    gr_graph_desc desc;
    gr_handle graph = GR_NULL_HANDLE;
    memset(&desc, 0, sizeof(desc));
    desc.head.size = (uint32_t)sizeof(desc);
    gr_graph_create(&desc, &graph);
    return graph;
}

static gr_str s(const char *text)
{
    gr_str out;
    out.data = text;
    out.len = (uint32_t)strlen(text);
    out._pad = 0;
    return out;
}

static gr_graph_compile_report compile(gr_handle graph, gr_result *out_status)
{
    gr_graph_compile_report report;
    gr_result status;
    memset(&report, 0, sizeof(report));
    report.head.size = (uint32_t)sizeof(report);
    status = gr_graph_compile(graph, &report);
    if (out_status)
        *out_status = status;
    return report;
}

/* Order comes from the dependencies, not from the order the passes were declared in. */
static void test_derived_order(void)
{
    gr_handle graph = new_graph();
    gr_graph_resource target, out_pass_resource;
    gr_graph_pass read_pass, write_pass;
    gr_graph_compile_report report;
    gr_result status;
    gr_barrier barriers[8];
    uint32_t count = 0;
    gr_graph_pass order = GR_GRAPH_PASS_NONE;

    /* Declared in the wrong order on purpose: the reader first, the writer second. */
    CHECK_EQ(gr_graph_add_resource(graph, s("target"), GR_GRAPH_RESOURCE_TEXTURE,
                                   (gr_handle)0x1001, &target), GR_OK);
    CHECK_EQ(gr_graph_add_resource(graph, s("final"), GR_GRAPH_RESOURCE_TEXTURE,
                                   (gr_handle)0x1002, &out_pass_resource), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("shade"), &read_pass), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("clear"), &write_pass), GR_OK);

    CHECK_EQ(gr_graph_pass_write(graph, write_pass, target, GR_STATE_COLOR_ATTACHMENT), GR_OK);
    CHECK_EQ(gr_graph_pass_read(graph, read_pass, target, GR_STATE_SHADER_READ), GR_OK);
    CHECK_EQ(gr_graph_pass_write(graph, read_pass, out_pass_resource, GR_STATE_COLOR_ATTACHMENT),
             GR_OK);
    CHECK_EQ(gr_graph_pass_set_side_effect(graph, read_pass, 1), GR_OK);

    report = compile(graph, &status);
    CHECK_EQ(status, GR_OK);
    CHECK_EQ(report.error, GR_GRAPH_OK);
    CHECK_EQ(report.live_count, 2u);
    CHECK_EQ(report.culled_count, 0u);

    /* The writer must come first even though it was declared second. */
    CHECK_EQ(gr_graph_execution_order(graph, 0, &order), GR_OK);
    CHECK_EQ(order, write_pass);
    CHECK_EQ(gr_graph_execution_order(graph, 1, &order), GR_OK);
    CHECK_EQ(order, read_pass);

    /* The writer's first use of the target transitions from undefined; the reader transitions it
     * to a sampled layout. Two barriers, derived rather than declared. */
    CHECK_EQ(gr_graph_pass_barriers(graph, 0, barriers, 8, &count), GR_OK);
    CHECK_EQ(count, 1u);
    CHECK_EQ(barriers[0].resource, (gr_handle)0x1001);
    CHECK_EQ(barriers[0].src_state, GR_STATE_UNDEFINED);
    CHECK_EQ(barriers[0].dst_state, GR_STATE_COLOR_ATTACHMENT);
    CHECK_EQ(gr_graph_pass_barriers(graph, 1, barriers, 8, &count), GR_OK);
    CHECK_EQ(count, 2u); /* target -> sampled, final -> colour attachment */
    CHECK_EQ(barriers[0].resource, (gr_handle)0x1001);
    CHECK_EQ(barriers[0].src_state, GR_STATE_COLOR_ATTACHMENT);
    CHECK_EQ(barriers[0].dst_state, GR_STATE_SHADER_READ);
    CHECK_EQ(report.barrier_count, 3u);

    /* A sizing call reports without writing. */
    CHECK_EQ(gr_graph_pass_barriers(graph, 1, NULL, 0, &count), GR_OK);
    CHECK_EQ(count, 2u);

    /* The final state is what the next frame imports. */
    {
        uint32_t state = GR_STATE_UNDEFINED;
        CHECK_EQ(gr_graph_final_state(graph, target, &state), GR_OK);
        CHECK_EQ(state, GR_STATE_SHADER_READ);
        CHECK_EQ(gr_graph_final_state(graph, out_pass_resource, &state), GR_OK);
        CHECK_EQ(state, GR_STATE_COLOR_ATTACHMENT);
    }
    gr_graph_destroy(graph);
}

/* A transition is derived only when the state actually differs. */
static void test_state_continuity(void)
{
    gr_handle graph = new_graph();
    gr_graph_resource tex;
    gr_graph_pass a, b, c;
    gr_graph_compile_report report;
    gr_result status;
    gr_barrier barriers[8];
    uint32_t count = 0;

    CHECK_EQ(gr_graph_add_resource(graph, s("t"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)0x2001,
                                   &tex), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("b"), &b), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("c"), &c), GR_OK);
    CHECK_EQ(gr_graph_pass_write(graph, a, tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
    CHECK_EQ(gr_graph_pass_read(graph, b, tex, GR_STATE_COLOR_ATTACHMENT), GR_OK); /* same state */
    CHECK_EQ(gr_graph_pass_write(graph, c, tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
    CHECK_EQ(gr_graph_pass_set_side_effect(graph, b, 1), GR_OK);
    CHECK_EQ(gr_graph_pass_set_side_effect(graph, c, 1), GR_OK);

    report = compile(graph, &status);
    CHECK_EQ(status, GR_OK);
    CHECK_EQ(report.live_count, 3u);
    /* Exactly one transition: into COLOR_ATTACHMENT once. Reading and writing in the state the
     * resource is already in needs no barrier, which is the point of deriving them. */
    CHECK_EQ(report.barrier_count, 1u);
    CHECK_EQ(gr_graph_pass_barriers(graph, 0, barriers, 8, &count), GR_OK);
    CHECK_EQ(count, 1u);
    CHECK_EQ(gr_graph_pass_barriers(graph, 1, NULL, 0, &count), GR_OK);
    CHECK_EQ(count, 0u);
    CHECK_EQ(gr_graph_pass_barriers(graph, 2, NULL, 0, &count), GR_OK);
    CHECK_EQ(count, 0u);
    gr_graph_destroy(graph);
}

/* A pass whose write nothing reads, and which has no side effect, is dead. */
static void test_culling(void)
{
    gr_handle graph = new_graph();
    gr_graph_resource dead_tex, live_tex, final_tex;
    gr_graph_pass dead, feeder, live;
    gr_graph_compile_report report;
    gr_result status;

    CHECK_EQ(gr_graph_add_resource(graph, s("dead"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)0x3001,
                                   &dead_tex), GR_OK);
    CHECK_EQ(gr_graph_add_resource(graph, s("live"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)0x3002,
                                   &live_tex), GR_OK);
    CHECK_EQ(gr_graph_add_resource(graph, s("final"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)0x3003,
                                   &final_tex), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("feeder"), &feeder), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("dead"), &dead), GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("live"), &live), GR_OK);

    /* feeder writes dead_tex; dead reads it and writes live_tex; nothing reads live_tex. Nothing
     * in this chain feeds a side effect, so all three are dead... except `live`, which we give a
     * side effect. */
    CHECK_EQ(gr_graph_pass_write(graph, feeder, dead_tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
    CHECK_EQ(gr_graph_pass_read(graph, dead, dead_tex, GR_STATE_SHADER_READ), GR_OK);
    CHECK_EQ(gr_graph_pass_write(graph, dead, live_tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
    CHECK_EQ(gr_graph_pass_write(graph, live, final_tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
    CHECK_EQ(gr_graph_pass_set_side_effect(graph, live, 1), GR_OK);

    report = compile(graph, &status);
    CHECK_EQ(status, GR_OK);
    CHECK_EQ(report.pass_count, 3u);
    CHECK_EQ(report.live_count, 1u);
    CHECK_EQ(report.culled_count, 2u);

    /* Now make the live pass read the middle pass's output. That makes the middle pass live, and
     * because it reads the feeder's output, the feeder becomes live too: liveness propagates all
     * the way back in one compile. */
    CHECK_EQ(gr_graph_pass_read(graph, live, live_tex, GR_STATE_SHADER_READ), GR_OK);
    report = compile(graph, &status);
    CHECK_EQ(status, GR_OK);
    CHECK_EQ(report.live_count, 3u);
    CHECK_EQ(report.culled_count, 0u);
    gr_graph_destroy(graph);
}

/* Every validation the graph performs, one graph each. */
static void test_validation(void)
{
    gr_result status;
    gr_graph_compile_report report;

    /* Two passes with one name. */
    {
        gr_handle graph = new_graph();
        gr_graph_pass a, b;
        CHECK_EQ(gr_graph_add_pass(graph, s("same"), &a), GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("same"), &b), GR_OK);
        report = compile(graph, &status);
        CHECK_EQ(status, GR_ERROR_VALIDATION_FAILED);
        CHECK_EQ(report.error, GR_GRAPH_ERROR_DUPLICATE_PASS);
        CHECK_EQ(report.error_pass, b);
        gr_graph_destroy(graph);
    }
    /* One pass writing one resource twice. */
    {
        gr_handle graph = new_graph();
        gr_graph_resource tex;
        gr_graph_pass a;
        CHECK_EQ(gr_graph_add_resource(graph, s("t"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)1, &tex),
                 GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
        CHECK_EQ(gr_graph_pass_write(graph, a, tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
        CHECK_EQ(gr_graph_pass_write(graph, a, tex, GR_STATE_GENERAL), GR_OK);
        report = compile(graph, &status);
        CHECK_EQ(status, GR_ERROR_VALIDATION_FAILED);
        CHECK_EQ(report.error, GR_GRAPH_ERROR_DUPLICATE_WRITE);
        gr_graph_destroy(graph);
    }
    /* Reading something nothing wrote and nothing imported. */
    {
        gr_handle graph = new_graph();
        gr_graph_resource tex;
        gr_graph_pass a;
        CHECK_EQ(gr_graph_add_resource(graph, s("t"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)1, &tex),
                 GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
        CHECK_EQ(gr_graph_pass_read(graph, a, tex, GR_STATE_SHADER_READ), GR_OK);
        CHECK_EQ(gr_graph_pass_set_side_effect(graph, a, 1), GR_OK);
        report = compile(graph, &status);
        CHECK_EQ(status, GR_ERROR_VALIDATION_FAILED);
        CHECK_EQ(report.error, GR_GRAPH_ERROR_USE_BEFORE_WRITE);
        CHECK_EQ(report.error_resource, tex);
        gr_graph_destroy(graph);
    }
    /* The same read is legal when the resource is imported in that state. */
    {
        gr_handle graph = new_graph();
        gr_graph_resource tex;
        gr_graph_pass a;
        CHECK_EQ(gr_graph_import(graph, s("history"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)1,
                                 GR_STATE_SHADER_READ, &tex), GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
        CHECK_EQ(gr_graph_pass_read(graph, a, tex, GR_STATE_SHADER_READ), GR_OK);
        CHECK_EQ(gr_graph_pass_set_side_effect(graph, a, 1), GR_OK);
        report = compile(graph, &status);
        CHECK_EQ(status, GR_OK);
        CHECK_EQ(report.error, GR_GRAPH_OK);
        CHECK_EQ(report.barrier_count, 0u); /* already in the right state */
        gr_graph_destroy(graph);
    }
    /* An explicit edge back the other way is a cycle, and a cycle is refused. */
    {
        gr_handle graph = new_graph();
        gr_graph_pass a, b;
        gr_graph_resource tex;
        CHECK_EQ(gr_graph_add_resource(graph, s("t"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)1, &tex),
                 GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("b"), &b), GR_OK);
        CHECK_EQ(gr_graph_pass_write(graph, a, tex, GR_STATE_COLOR_ATTACHMENT), GR_OK);
        CHECK_EQ(gr_graph_pass_read(graph, b, tex, GR_STATE_SHADER_READ), GR_OK);
        CHECK_EQ(gr_graph_pass_set_side_effect(graph, b, 1), GR_OK);
        /* b already depends on a through the resource; this adds a -> b's reverse. */
        CHECK_EQ(gr_graph_pass_depends(graph, a, b), GR_OK);
        report = compile(graph, &status);
        CHECK_EQ(status, GR_ERROR_VALIDATION_FAILED);
        CHECK_EQ(report.error, GR_GRAPH_ERROR_CYCLE);
        gr_graph_destroy(graph);
    }
    /* A pass cannot arrive in the undefined state. */
    {
        gr_handle graph = new_graph();
        gr_graph_resource tex;
        gr_graph_pass a;
        CHECK_EQ(gr_graph_add_resource(graph, s("t"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)1, &tex),
                 GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
        CHECK_EQ(gr_graph_pass_write(graph, a, tex, GR_STATE_UNDEFINED),
                 GR_ERROR_INVALID_ARGUMENT);
        gr_graph_destroy(graph);
    }
    /* Nothing declared. */
    {
        gr_handle graph = new_graph();
        report = compile(graph, &status);
        CHECK_EQ(report.error, GR_GRAPH_ERROR_EMPTY);
        gr_graph_destroy(graph);
    }
}

/* Compile is repeatable, and a reset clears the frame. */
static void test_repeatable(void)
{
    gr_handle graph = new_graph();
    gr_graph_resource tex;
    gr_graph_pass a;
    gr_graph_compile_report first, second;
    gr_result status;

    CHECK_EQ(gr_graph_add_resource(graph, s("t"), GR_GRAPH_RESOURCE_TEXTURE, (gr_handle)1, &tex),
             GR_OK);
    CHECK_EQ(gr_graph_add_pass(graph, s("a"), &a), GR_OK);
    CHECK_EQ(gr_graph_pass_write(graph, a, tex, GR_STATE_GENERAL), GR_OK);
    CHECK_EQ(gr_graph_pass_set_side_effect(graph, a, 1), GR_OK);
    first = compile(graph, &status);
    CHECK_EQ(status, GR_OK);
    second = compile(graph, &status);
    CHECK_EQ(status, GR_OK);
    /* Same declarations, same answer: derived edges and barriers are rebuilt, not accumulated. */
    CHECK_EQ(first.edge_count, second.edge_count);
    CHECK_EQ(first.barrier_count, second.barrier_count);
    CHECK_EQ(first.live_count, second.live_count);

    CHECK_EQ(gr_graph_reset(graph), GR_OK);
    second = compile(graph, &status);
    CHECK_EQ(second.error, GR_GRAPH_ERROR_EMPTY);
    gr_graph_destroy(graph);
}

int main(void)
{
    test_derived_order();
    test_state_continuity();
    test_culling();
    test_validation();
    test_repeatable();
    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("graph: %d checks passed\n", checks);
    return 0;
}
