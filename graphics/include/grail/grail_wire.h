/* grail_wire.h - driving the RHI from a process that cannot link it.
 *
 * Why this exists. A Grail program is a static Linux ELF: the compiler links exactly one
 * object (`ld.lld -m elf_x86_64 <obj> -o <exe>`, tools/native.mjs) with no libc and no
 * libraries, and the language has no `extern`, no dlopen and no FFI. So a Grail program
 * cannot call gr_device_create() in-process today, and cannot link SDL3 or Vulkan.
 * What it *can* do is what the standard library already does: socket(), mmap(), read(),
 * write(). This header defines the contract over that surface, so the graphics work can be
 * developed, tested and benchmarked before the front-end gains an FFI.
 *
 * The rule that makes this possible, and that the rest of the ABI was written to keep:
 * every value crossing this boundary is a fixed-size POD with no pointers. Handles are
 * u64, text is (offset, length) into the packet, and bulk data lives in a shared region
 * addressed by (offset, length). Nothing is serialised by hand and no structure is ever
 * reinterpreted across a compiler boundary: the same C headers define both sides.
 *
 * Topology.
 *   host process (C/C++, owns SDL3 + VkDevice/D3D12/Metal, implements the ABI)
 *        ^  AF_UNIX SOCK_SEQPACKET (Linux, one packet per message, atomic delivery)
 *   Grail process (static ELF, connects with socket/read/write, sends gr_wire_request)
 *
 * The host is the server: it creates the listening socket, creates the device, and runs the
 * frame loop. The client sends requests and, once per frame, a batch of commands. A future
 * in-process FFI removes the transport and keeps every structure and every semantic below.
 *
 * See graphics/docs/wire-protocol.md. Status: the framing and the op table are implemented
 * by graphics/src/grail_wire.c and exercised by graphics/tests/wire_test.c. A full client
 * is not implemented; graphics/docs/first-renderer-port.md lists what is missing.
 */
#ifndef GRAIL_WIRE_H
#define GRAIL_WIRE_H

#include "grail_abi.h"
#include "grail_rhi.h"
#include "grail_shader.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------------------------
 * Framing. One packet is one request or one response; SOCK_SEQPACKET preserves the message
 * boundary and makes a truncated message a failed read rather than a misparse.
 *
 *   gr_wire_packet { op, request_id, length, status, payload_length, payload_offset }
 *   payload bytes
 *
 * A payload is the ABI structure the op names, followed by its variable-length tail (string
 * bytes, arrays). `length` covers the payload; a packet larger than GR_WIRE_MAX_PACKET is
 * refused before it is read. The maximum matters: a host must not let a peer make it
 * allocate without a bound.
 * --------------------------------------------------------------------------------------- */
#define GR_WIRE_MAGIC 0x4C4941524757ull /* 'G','W','R','A','I','L' little-endian, 6 bytes */
#define GR_WIRE_VERSION 1u
#define GR_WIRE_MAX_PACKET (1024u * 1024u)
#define GR_WIRE_MAX_REPLY (4u * 1024u * 1024u)
#define GR_WIRE_HEADER_SIZE 40u

typedef enum gr_wire_op {
    GR_WIRE_OP_NONE = 0,
    GR_WIRE_OP_HELLO = 1,            /* client -> host: version, app name; reply: caps */
    GR_WIRE_OP_DEVICE_CAPS = 2,
    GR_WIRE_OP_DEVICE_INFO = 3,
    GR_WIRE_OP_RESOURCE_CREATE = 10, /* buffer or texture; reply: handle */
    GR_WIRE_OP_RESOURCE_DESTROY = 11,
    GR_WIRE_OP_RESOURCE_WRITE = 12,  /* payload names a shared-memory range */
    GR_WIRE_OP_RESOURCE_READ = 13,
    GR_WIRE_OP_SHADER_LOAD = 20,     /* payload is a reflection blob + bytecode */
    GR_WIRE_OP_PIPELINE_DECLARE = 21,
    GR_WIRE_OP_PIPELINE_COMMIT = 22,
    GR_WIRE_OP_FRAME_BEGIN = 30,     /* writes gr_frame_constants into the frame slot */
    GR_WIRE_OP_CMD_BATCH = 31,       /* an array of gr_wire_cmd for one command buffer */
    GR_WIRE_OP_FRAME_SUBMIT = 32,    /* submit the batch, signal the timeline */
    GR_WIRE_OP_FRAME_WAIT = 33,      /* wait for the timeline value */
    GR_WIRE_OP_SWAPCHAIN_ACQUIRE = 40,
    GR_WIRE_OP_SWAPCHAIN_PRESENT = 41,
    GR_WIRE_OP_INPUT_STATE = 50,
    GR_WIRE_OP_EVENTS = 51,
    GR_WIRE_OP_QUERY_RESULTS = 60,
    GR_WIRE_OP_RETIRE = 61,
    GR_WIRE_OP_COLLECT = 62,
    GR_WIRE_OP_SHUTDOWN = 99,
    GR_WIRE_OP_COUNT
} gr_wire_op;

/* The packet header, exactly as it appears in the first 40 bytes. */
typedef struct gr_wire_packet {
    uint32_t magic_low;    /* GR_WIRE_MAGIC & 0xFFFFFFFF */
    uint16_t version;      /* GR_WIRE_VERSION */
    uint16_t op;           /* gr_wire_op */
    uint32_t request_id;   /* echoed by the reply so a client can pipeline requests */
    int32_t status;        /* gr_result; a reply carries the host's status */
    uint32_t payload_length;
    uint32_t _reserved;
    uint64_t sequence;     /* monotonic per direction; a gap fails the channel */
    uint64_t aux;          /* op-specific: a handle, a timeline value, a range id */
} gr_wire_packet;

#if defined(__cplusplus) && (__cplusplus >= 201703L)
static_assert(sizeof(gr_wire_packet) == GR_WIRE_HEADER_SIZE, "wire header must be 40 bytes");
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L)
_Static_assert(sizeof(gr_wire_packet) == GR_WIRE_HEADER_SIZE, "wire header must be 40 bytes");
#endif

/* ---------------------------------------------------------------------------------------
 * Shared memory. Bulk data does not go through the socket: a 64 MiB vertex buffer per frame
 * would be a copy inside the host and a syscall per 1 MiB otherwise. One region is mapped
 * by both processes; a range is (offset, length) with the generation that was current when
 * it was written, so the host can refuse to read a range the client has since reused.
 * --------------------------------------------------------------------------------------- */
#define GR_WIRE_SHM_NAME_MAX 108u

typedef struct gr_wire_shm {
    char name[GR_WIRE_SHM_NAME_MAX];  /* a POSIX shm name, '\0' terminated */
    uint64_t size;
    uint32_t flags;                   /* 0 */
    uint32_t _reserved;
} gr_wire_shm;

/* A range in the shared region. `generation` is the value of the region's counter when the
 * data was produced; the host rejects a stale range instead of reading overwritten bytes. */
typedef struct gr_wire_range {
    uint64_t offset;
    uint64_t length;
    uint64_t generation;
} gr_wire_range;

/* ---------------------------------------------------------------------------------------
 * Commands. A frame's work arrives as an array of these in one packet: one opcode per
 * command, followed by its arguments. The set mirrors gr_rhi's command surface exactly;
 * there is no second semantics to keep in step.
 * --------------------------------------------------------------------------------------- */
typedef enum gr_wire_cmd_op {
    GR_WCMD_BEGIN_RENDER = 0,
    GR_WCMD_END_RENDER = 1,
    GR_WCMD_BARRIER = 2,
    GR_WCMD_VIEWPORT = 3,
    GR_WCMD_SCISSOR = 4,
    GR_WCMD_BIND_PIPELINE = 5,
    GR_WCMD_PUSH_CONSTANTS = 6,
    GR_WCMD_PUSH_FRAME_OFFSET = 7,
    GR_WCMD_BIND_VERTEX_BUFFER = 8,
    GR_WCMD_BIND_INDEX_BUFFER = 9,
    GR_WCMD_DRAW = 10,
    GR_WCMD_DRAW_INDEXED = 11,
    GR_WCMD_DRAW_INDIRECT = 12,
    GR_WCMD_DISPATCH = 13,
    GR_WCMD_DISPATCH_INDIRECT = 14,
    GR_WCMD_COPY_BUFFER = 15,
    GR_WCMD_COPY_BUFFER_TO_TEXTURE = 16,
    GR_WCMD_COPY_TEXTURE_TO_BUFFER = 17,
    GR_WCMD_BEGIN_SCOPE = 18,
    GR_WCMD_END_SCOPE = 19,
    GR_WCMD_WRITE_TIMESTAMP = 20,
    GR_WCMD_OP_COUNT
} gr_wire_cmd_op;

/* One command. `a`,`b`,`c` are arguments and their meaning is the opcode's; `range` is the
 * shared-memory payload (push-constant bytes, a name) when the command has variable data. */
typedef struct gr_wire_cmd {
    uint16_t op;             /* gr_wire_cmd_op */
    uint16_t flags;
    uint32_t a, b, c;
    uint64_t handle_a, handle_b;
    uint64_t offset_a, offset_b;
    gr_wire_range range;
    uint32_t _reserved[2];
} gr_wire_cmd;

typedef struct gr_wire_cmd_batch {
    uint32_t cmd_buffer;     /* which recording command buffer on the host */
    uint32_t count;
    uint64_t sequence;
    /* gr_wire_cmd[count] follows immediately */
} gr_wire_cmd_batch;

/* ---------------------------------------------------------------------------------------
 * Framing helpers. Both sides use these; they are the only code that touches the header,
 * so a version skew is caught in one place. They do not do I/O.
 * --------------------------------------------------------------------------------------- */
/* Writes the header for `op` into `out` (32 bytes) and the payload into out+32. Returns the
 * total packet size, or 0 when it would not fit. */
size_t gr_wire_pack(uint8_t *out, size_t out_capacity, gr_wire_op op, uint32_t request_id,
                    uint64_t sequence, uint64_t aux, const void *payload, uint32_t payload_length);
/* Validates a received packet. Returns GR_OK, or GR_ERROR_VERSION_MISMATCH / GR_ERROR_INVALID_ARGUMENT
 * when the magic, version, length or op is wrong. Never reads past `received`. */
gr_result gr_wire_unpack(const uint8_t *data, size_t received, gr_wire_packet *out_header,
                         const void **out_payload);
const char *gr_wire_op_name(gr_wire_op op);

/* The maximum payload a given op may carry, so a receiver can bound its read. */
uint32_t gr_wire_op_max_reply(gr_wire_op op);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_WIRE_H */
