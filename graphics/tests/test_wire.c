/* test_wire.c - the out-of-process framing: pack/unpack round trip and every rejection a
 * receiver must make instead of trusting a peer. */
#include "../include/grail/grail_wire.h"

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

int main(void)
{
    uint8_t packet[256];
    gr_wire_packet header;
    const void *payload = NULL;
    const char body[] = "frame 0";
    size_t total;

    /* Round trip with a payload. */
    total = gr_wire_pack(packet, sizeof(packet), GR_WIRE_OP_FRAME_BEGIN, 42u, 7u, 0xDEADBEEFull,
                         body, sizeof(body));
    CHECK_EQ(total, GR_WIRE_HEADER_SIZE + sizeof(body));
    CHECK_EQ(gr_wire_unpack(packet, total, &header, &payload), GR_OK);
    CHECK_EQ(header.request_id, 42u);
    CHECK_EQ(header.sequence, 7u);
    CHECK_EQ(header.aux, 0xDEADBEEFull);
    CHECK_EQ(header.op, (uint16_t)GR_WIRE_OP_FRAME_BEGIN);
    CHECK_EQ(header.payload_length, sizeof(body));
    CHECK(payload != NULL);
    CHECK(memcmp(payload, body, sizeof(body)) == 0);

    /* An empty payload is legal and reports no payload pointer. */
    total = gr_wire_pack(packet, sizeof(packet), GR_WIRE_OP_COLLECT, 1u, 0u, 0u, NULL, 0);
    CHECK_EQ(total, GR_WIRE_HEADER_SIZE);
    CHECK_EQ(gr_wire_unpack(packet, total, &header, &payload), GR_OK);
    CHECK(payload == NULL);

    /* A truncated message is refused rather than misparsed: this is the property that makes
     * SOCK_SEQPACKET the right transport. */
    CHECK_EQ(gr_wire_unpack(packet, GR_WIRE_HEADER_SIZE - 1u, &header, NULL),
             GR_ERROR_INVALID_ARGUMENT);
    /* A message shorter than its own header claims is refused. */
    total = gr_wire_pack(packet, sizeof(packet), GR_WIRE_OP_FRAME_BEGIN, 1u, 0u, 0u, body,
                         sizeof(body));
    CHECK_EQ(gr_wire_unpack(packet, total - 1u, &header, NULL), GR_ERROR_INVALID_ARGUMENT);
    /* A message longer than its header claims is refused (two messages glued together). */
    CHECK_EQ(gr_wire_unpack(packet, total + 1u, &header, NULL), GR_ERROR_INVALID_ARGUMENT);

    /* Magic and version are checked. */
    total = gr_wire_pack(packet, sizeof(packet), GR_WIRE_OP_COLLECT, 1u, 0u, 0u, NULL, 0);
    packet[0] ^= 0xFFu;
    CHECK_EQ(gr_wire_unpack(packet, total, &header, NULL), GR_ERROR_INVALID_ARGUMENT);
    packet[0] ^= 0xFFu;
    packet[4] = 99u; /* version byte */
    CHECK_EQ(gr_wire_unpack(packet, total, &header, NULL), GR_ERROR_VERSION_MISMATCH);
    packet[4] = (uint8_t)GR_WIRE_VERSION;

    /* An unknown op is refused. */
    packet[6] = 200u;
    CHECK_EQ(gr_wire_unpack(packet, total, &header, NULL), GR_ERROR_INVALID_ARGUMENT);
    packet[6] = (uint8_t)GR_WIRE_OP_COLLECT;

    /* A payload larger than the op allows is refused before it is used. */
    {
        uint8_t big[8192];
        size_t packed = gr_wire_pack(big, sizeof(big), GR_WIRE_OP_COLLECT, 1u, 0u, 0u, big, 5000u);
        CHECK_EQ(packed, 0u); /* COLLECT's maximum is far below 5000 */
    }
    /* A packet that does not fit the caller's buffer is refused, not truncated. */
    CHECK_EQ(gr_wire_pack(packet, 8, GR_WIRE_OP_FRAME_BEGIN, 1u, 0u, 0u, body, sizeof(body)), 0u);

    /* Names are stable for logging. */
    CHECK(strcmp(gr_wire_op_name(GR_WIRE_OP_CMD_BATCH), "cmd_batch") == 0);
    CHECK(gr_wire_op_max_reply(GR_WIRE_OP_SHADER_LOAD) > gr_wire_op_max_reply(GR_WIRE_OP_HELLO));

    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("wire: %d checks passed\n", checks);
    return 0;
}
