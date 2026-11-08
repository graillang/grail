/* grail_wire.c - framing for grail_wire.h. No I/O: the transport belongs to the host, and a
 * function that both framed and transmitted would need a socket to test. */
#include "grail_internal.h"
#include "../include/grail/grail_wire.h"

#include <string.h>

/* The maximum payload per op. A receiver uses this to bound its allocation before reading,
 * so a peer cannot make it reserve a gigabyte by lying in a header. */
uint32_t gr_wire_op_max_reply(gr_wire_op op)
{
    switch (op) {
    case GR_WIRE_OP_HELLO:
    case GR_WIRE_OP_DEVICE_CAPS:
        return 4096u;
    case GR_WIRE_OP_DEVICE_INFO:
        return 65536u;
    case GR_WIRE_OP_RESOURCE_CREATE:
    case GR_WIRE_OP_RESOURCE_DESTROY:
    case GR_WIRE_OP_RESOURCE_WRITE:
    case GR_WIRE_OP_RESOURCE_READ:
        return 65536u;
    case GR_WIRE_OP_SHADER_LOAD:
        return GR_WIRE_MAX_PACKET - GR_WIRE_HEADER_SIZE;  /* a reflection blob */
    case GR_WIRE_OP_PIPELINE_DECLARE:
    case GR_WIRE_OP_PIPELINE_COMMIT:
        return 65536u;
    case GR_WIRE_OP_CMD_BATCH:
        return GR_WIRE_MAX_PACKET - GR_WIRE_HEADER_SIZE;  /* a frame's commands */
    case GR_WIRE_OP_FRAME_BEGIN:
    case GR_WIRE_OP_FRAME_SUBMIT:
    case GR_WIRE_OP_FRAME_WAIT:
    case GR_WIRE_OP_SWAPCHAIN_ACQUIRE:
    case GR_WIRE_OP_SWAPCHAIN_PRESENT:
    case GR_WIRE_OP_INPUT_STATE:
    case GR_WIRE_OP_EVENTS:
    case GR_WIRE_OP_QUERY_RESULTS:
    case GR_WIRE_OP_RETIRE:
    case GR_WIRE_OP_COLLECT:
    case GR_WIRE_OP_SHUTDOWN:
    case GR_WIRE_OP_NONE:
    case GR_WIRE_OP_COUNT:
    default:
        return 4096u;
    }
}

const char *gr_wire_op_name(gr_wire_op op)
{
    switch (op) {
    case GR_WIRE_OP_NONE: return "none";
    case GR_WIRE_OP_HELLO: return "hello";
    case GR_WIRE_OP_DEVICE_CAPS: return "device_caps";
    case GR_WIRE_OP_DEVICE_INFO: return "device_info";
    case GR_WIRE_OP_RESOURCE_CREATE: return "resource_create";
    case GR_WIRE_OP_RESOURCE_DESTROY: return "resource_destroy";
    case GR_WIRE_OP_RESOURCE_WRITE: return "resource_write";
    case GR_WIRE_OP_RESOURCE_READ: return "resource_read";
    case GR_WIRE_OP_SHADER_LOAD: return "shader_load";
    case GR_WIRE_OP_PIPELINE_DECLARE: return "pipeline_declare";
    case GR_WIRE_OP_PIPELINE_COMMIT: return "pipeline_commit";
    case GR_WIRE_OP_FRAME_BEGIN: return "frame_begin";
    case GR_WIRE_OP_CMD_BATCH: return "cmd_batch";
    case GR_WIRE_OP_FRAME_SUBMIT: return "frame_submit";
    case GR_WIRE_OP_FRAME_WAIT: return "frame_wait";
    case GR_WIRE_OP_SWAPCHAIN_ACQUIRE: return "swapchain_acquire";
    case GR_WIRE_OP_SWAPCHAIN_PRESENT: return "swapchain_present";
    case GR_WIRE_OP_INPUT_STATE: return "input_state";
    case GR_WIRE_OP_EVENTS: return "events";
    case GR_WIRE_OP_QUERY_RESULTS: return "query_results";
    case GR_WIRE_OP_RETIRE: return "retire";
    case GR_WIRE_OP_COLLECT: return "collect";
    case GR_WIRE_OP_SHUTDOWN: return "shutdown";
    default: return "unknown";
    }
}

size_t gr_wire_pack(uint8_t *out, size_t out_capacity, gr_wire_op op, uint32_t request_id,
                    uint64_t sequence, uint64_t aux, const void *payload, uint32_t payload_length)
{
    gr_wire_packet header;
    size_t total;

    if (!out)
        return 0;
    if ((uint64_t)payload_length + GR_WIRE_HEADER_SIZE > GR_WIRE_MAX_PACKET)
        return 0;
    /* Refuse at the sender what gr_wire_unpack() would refuse at the receiver, so a
     * mismatch between the two cannot exist: the payload limit is one number, asked of one
     * function. */
    if (payload_length > gr_wire_op_max_reply(op))
        return 0;
    if (payload_length != 0 && !payload)
        return 0;
    total = GR_WIRE_HEADER_SIZE + (size_t)payload_length;
    if (total > out_capacity)
        return 0;

    memset(&header, 0, sizeof(header));
    header.magic_low = (uint32_t)(GR_WIRE_MAGIC & 0xFFFFFFFFull);
    header.version = (uint16_t)GR_WIRE_VERSION;
    header.op = (uint16_t)op;
    header.request_id = request_id;
    header.status = GR_OK;
    header.payload_length = payload_length;
    header.sequence = sequence;
    header.aux = aux;

    /* The header is copied as bytes because its layout is the contract; the static_assert in
     * grail_wire.h pins the size, and this copy pins the field order. */
    memcpy(out, &header, sizeof(header));
    if (payload_length)
        memcpy(out + GR_WIRE_HEADER_SIZE, payload, payload_length);
    return total;
}

gr_result gr_wire_unpack(const uint8_t *data, size_t received, gr_wire_packet *out_header,
                         const void **out_payload)
{
    gr_wire_packet header;

    if (out_header)
        memset(out_header, 0, sizeof(*out_header));
    if (out_payload)
        *out_payload = NULL;
    if (!data || !out_header)
        return GR_ERROR_INVALID_ARGUMENT;
    if (received < GR_WIRE_HEADER_SIZE)
        return GR_ERROR_INVALID_ARGUMENT;

    memcpy(&header, data, sizeof(header));

    if (header.magic_low != (uint32_t)(GR_WIRE_MAGIC & 0xFFFFFFFFull))
        return GR_ERROR_INVALID_ARGUMENT;
    if (header.version != (uint16_t)GR_WIRE_VERSION)
        return GR_ERROR_VERSION_MISMATCH;
    if (header.op >= (uint16_t)GR_WIRE_OP_COUNT)
        return GR_ERROR_INVALID_ARGUMENT;
    /* A message is one packet on SOCK_SEQPACKET, so the length must match exactly. Refusing
     * a mismatch is what turns a desynchronised stream into a failed call, not a misparse. */
    if ((size_t)header.payload_length + GR_WIRE_HEADER_SIZE != received)
        return GR_ERROR_INVALID_ARGUMENT;
    if (header.payload_length > gr_wire_op_max_reply((gr_wire_op)header.op))
        return GR_ERROR_INVALID_ARGUMENT;

    *out_header = header;
    if (out_payload && header.payload_length)
        *out_payload = data + GR_WIRE_HEADER_SIZE;
    return GR_OK;
}
