//! Reference for `borg/tests/frames_test.grl`.
//!
//! An independent implementation of the transport layer, in the same spirit as `replay.rs`: the
//! frame encoder is written here from the journal's layout rather than sharing code with the port,
//! so a byte the port gets wrong shows up as a diff line instead of agreeing with itself.
//!
//! What it reproduces, line for line:
//!
//!   * one frame per event — the journal's `tag | u32 LE length | body` — and its bytes in hex
//!   * the same capture decoded one byte at a time, which must produce the same frames
//!   * the capture handed to the byte stream reader and the fold, yielding a checksum or a refusal
//!   * the refusal table: a stream cut short, a declared length past the ceiling, an unknown tag, a
//!     frame short inside, trailing bytes, a bad presence byte, a control frame with no opcode, a
//!     reply with an impossible marker, an event before the handshake, a foreign session, a version
//!     mismatch, and a frame that decodes and cannot be applied — each with the code the *file*
//!     reader reports for the same bytes
//!   * a real loopback round trip on 127.0.0.1, where the daemon's answer is read back by a client
//!     that has to decode it, and a peer that stops inside a reply frame
//!
//! The fold and its checksum are the rules `replay.rs` already implements against
//! `SessionState::apply` (session_store.rs:906-959, 1036-1041, 1320-1336); they are repeated here
//! because a reference binary is standalone, not because the transport has its own fold.

use serde::Deserialize;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};

#[derive(Deserialize, Clone)]
struct Event {
    id: String,
    session_id: String,
    sequence: u64,
    created_at: String,
    kind: Kind,
}

#[derive(Deserialize, Clone)]
#[serde(tag = "type", rename_all = "snake_case")]
enum Kind {
    SessionStarted,
    SessionTitled {
        title: String,
        #[serde(default)]
        generated: bool,
        #[serde(default)]
        usage_tokens: Option<u64>,
        #[serde(default)]
        model: Option<String>,
    },
    StatusChanged {
        status: String,
        detail: Option<String>,
    },
    Message {
        message_id: String,
        actor: String,
        text: String,
        #[serde(default)]
        status: String,
        #[serde(default)]
        delivery: Option<String>,
    },
    MessageDelta {
        message_id: String,
        delta: String,
    },
}

#[derive(Deserialize)]
struct Scenario {
    #[serde(default)]
    name: String,
    #[serde(default)]
    session: String,
    #[serde(default = "current_version")]
    client_version: u64,
    events: Vec<Event>,
}

fn current_version() -> u64 {
    1
}

// ---- the fold (`replay.rs`, repeated so this binary stands alone) ----

#[derive(Clone, Copy, PartialEq, Eq)]
enum Status {
    Starting,
    Ready,
    Running,
    WaitingForApproval,
    Completed,
    Failed,
    Stopped,
}

impl Status {
    fn named(name: &str) -> Option<Status> {
        Some(match name {
            "starting" => Status::Starting,
            "ready" => Status::Ready,
            "running" => Status::Running,
            "waiting_for_approval" => Status::WaitingForApproval,
            "completed" => Status::Completed,
            "failed" => Status::Failed,
            "stopped" => Status::Stopped,
            _ => return None,
        })
    }

    fn name(self) -> &'static str {
        match self {
            Status::Starting => "starting",
            Status::Ready => "ready",
            Status::Running => "running",
            Status::WaitingForApproval => "waiting_for_approval",
            Status::Completed => "completed",
            Status::Failed => "failed",
            Status::Stopped => "stopped",
        }
    }

    fn advancing(self) -> bool {
        matches!(
            self,
            Status::Starting | Status::Running | Status::WaitingForApproval
        )
    }
}

#[derive(Default)]
struct State {
    session_id: String,
    latest_sequence: u64,
    started_at: Option<String>,
    activity_at: Option<String>,
    status: Option<Status>,
    status_detail: Option<String>,
    title: Option<String>,
    title_generated: bool,
    title_usage_tokens: Option<u64>,
    title_model: Option<String>,
    first_prompt: Option<String>,
    latest_prompt: Option<String>,
    latest_response: Option<String>,
    events_seen: u64,
    titles_applied: u64,
    titles_frozen: u64,
}

enum Reason {
    Sequence,
    Session,
    UnknownActor,
    UnknownMessageStatus,
}

impl Reason {
    fn name(&self) -> &'static str {
        match self {
            Reason::Sequence => "sequence",
            Reason::Session => "session",
            Reason::UnknownActor => "unknown-actor",
            Reason::UnknownMessageStatus => "unknown-message-status",
        }
    }
}

struct Refusal {
    at: Option<u64>,
    reason: Reason,
    detail: String,
}

fn advances_clock(event: &Event) -> bool {
    match &event.kind {
        Kind::SessionTitled { .. } => false,
        Kind::StatusChanged { status, .. } => Status::named(status).is_some_and(Status::advancing),
        _ => true,
    }
}

fn known_actor(name: &str) -> bool {
    matches!(name, "user" | "assistant" | "tool" | "system")
}

fn known_message_status(name: &str) -> bool {
    matches!(name, "queued" | "in_progress" | "complete" | "failed")
}

fn apply(state: &State, event: &Event, at: u64) -> Result<State, Refusal> {
    if !state.session_id.is_empty() && state.session_id != event.session_id {
        return Err(Refusal {
            at: Some(at),
            reason: Reason::Session,
            detail: event.session_id.clone(),
        });
    }
    let expected = state.latest_sequence.saturating_add(1);
    if event.sequence != expected {
        return Err(Refusal {
            at: Some(at),
            reason: Reason::Sequence,
            detail: format!("{expected}/{}", event.sequence),
        });
    }
    if let Kind::Message { actor, status, .. } = &event.kind {
        if !known_actor(actor) {
            return Err(Refusal {
                at: Some(at),
                reason: Reason::UnknownActor,
                detail: actor.clone(),
            });
        }
        if !known_message_status(status) {
            return Err(Refusal {
                at: Some(at),
                reason: Reason::UnknownMessageStatus,
                detail: status.clone(),
            });
        }
    }
    let mut next = State {
        session_id: event.session_id.clone(),
        latest_sequence: event.sequence,
        started_at: state.started_at.clone(),
        activity_at: state.activity_at.clone(),
        status: state.status,
        status_detail: state.status_detail.clone(),
        title: state.title.clone(),
        title_generated: state.title_generated,
        title_usage_tokens: state.title_usage_tokens,
        title_model: state.title_model.clone(),
        first_prompt: state.first_prompt.clone(),
        latest_prompt: state.latest_prompt.clone(),
        latest_response: state.latest_response.clone(),
        events_seen: state.events_seen + 1,
        titles_applied: state.titles_applied,
        titles_frozen: state.titles_frozen,
    };
    if advances_clock(event) {
        next.activity_at = Some(event.created_at.clone());
    }
    match &event.kind {
        Kind::SessionStarted => next.started_at = Some(event.created_at.clone()),
        Kind::SessionTitled { title, generated, usage_tokens, model } => {
            if next.title_generated {
                next.titles_frozen += 1;
            } else {
                next.title = Some(title.clone());
                next.title_generated = *generated;
                next.title_usage_tokens = *usage_tokens;
                next.title_model = model.clone();
                next.titles_applied += 1;
            }
        }
        Kind::StatusChanged { status, detail } => {
            next.status = Status::named(status);
            next.status_detail = detail.clone();
        }
        Kind::Message { actor, text, status, .. } => {
            let prompt = text.trim();
            if !prompt.is_empty() {
                if actor == "user" {
                    if next.first_prompt.is_none() {
                        next.first_prompt = Some(prompt.to_string());
                    }
                    next.latest_prompt = Some(prompt.to_string());
                } else if actor == "assistant" && status == "complete" {
                    next.latest_response = Some(prompt.to_string());
                }
            }
        }
        Kind::MessageDelta { .. } => {}
    }
    Ok(next)
}

fn replay(events: &[Event]) -> Result<State, Refusal> {
    let mut state = State::default();
    for (index, event) in events.iter().enumerate() {
        state = apply(&state, event, index as u64)?;
    }
    Ok(state)
}

fn put_key(out: &mut String, key: &str) {
    if !out.is_empty() {
        out.push(';');
    }
    out.push_str(key);
    out.push('=');
}

fn put_number(out: &mut String, key: &str, value: u64) {
    put_key(out, key);
    out.push_str(&value.to_string());
}

fn put_text(out: &mut String, key: &str, value: Option<&str>) {
    put_key(out, key);
    match value {
        Some(text) => {
            out.push_str(&text.len().to_string());
            out.push(':');
            out.push_str(text);
        }
        None => out.push('-'),
    }
}

fn fingerprint(state: &State) -> String {
    let mut out = String::new();
    put_number(&mut out, "seq", state.latest_sequence);
    put_text(&mut out, "session", Some(&state.session_id));
    put_text(&mut out, "started", state.started_at.as_deref());
    put_text(&mut out, "activity", state.activity_at.as_deref());
    put_text(&mut out, "status", state.status.map(Status::name));
    put_text(&mut out, "detail", state.status_detail.as_deref());
    put_text(&mut out, "title", state.title.as_deref());
    put_key(&mut out, "generated");
    out.push_str(if state.title_generated { "true" } else { "false" });
    put_key(&mut out, "tokens");
    match state.title_usage_tokens {
        Some(tokens) => out.push_str(&tokens.to_string()),
        None => out.push('-'),
    }
    put_text(&mut out, "model", state.title_model.as_deref());
    put_text(&mut out, "first", state.first_prompt.as_deref());
    put_text(&mut out, "prompt", state.latest_prompt.as_deref());
    put_text(&mut out, "response", state.latest_response.as_deref());
    put_number(&mut out, "events", state.events_seen);
    put_key(&mut out, "titles");
    out.push_str(&format!("{}/{}", state.titles_applied, state.titles_frozen));
    out
}

fn checksum(state: &State) -> String {
    let mut hash: u64 = 14695981039346656037;
    for byte in fingerprint(state).bytes() {
        hash ^= u64::from(byte);
        hash = hash.wrapping_mul(1099511628211);
    }
    format!("{hash:016x}")
}

// ---- the journal's byte stream ----

const MAX_EVENT_BODY: u64 = 262144;
const STREAM_OK: u64 = 0;
const UNKNOWN_TAG: u64 = 20;
const TRUNCATED_EVENT: u64 = 21;
const LENGTH_OVERFLOW: u64 = 22;
const BAD_FIELD: u64 = 23;
const TRAILING_BYTES: u64 = 24;

fn push_uint(out: &mut Vec<u8>, value: u64, width: usize) {
    let mut rest = value;
    for _ in 0..width {
        out.push((rest % 256) as u8);
        rest /= 256;
    }
}

fn push_text(out: &mut Vec<u8>, text: &str) {
    push_uint(out, text.len() as u64, 4);
    out.extend_from_slice(text.as_bytes());
}

fn push_optional_text(out: &mut Vec<u8>, value: Option<&String>) {
    match value {
        Some(text) => {
            push_uint(out, 1, 1);
            push_text(out, text);
        }
        None => push_uint(out, 0, 1),
    }
}

fn read_uint(bytes: &[u8], at: usize, width: usize) -> u64 {
    let mut value = 0u64;
    for index in (0..width).rev() {
        value = value * 256 + u64::from(bytes[at + index]);
    }
    value
}

// One event's frame: the tag, the little-endian body length, then the body. This is the journal's
// encoding, written out again rather than imported from the port.
fn encode_event(event: &Event) -> Vec<u8> {
    let mut body = Vec::new();
    push_text(&mut body, &event.id);
    push_text(&mut body, &event.session_id);
    push_uint(&mut body, event.sequence, 8);
    push_text(&mut body, &event.created_at);
    let tag = match &event.kind {
        Kind::SessionStarted => 1,
        Kind::SessionTitled { title, generated, usage_tokens, model } => {
            push_text(&mut body, title);
            push_uint(&mut body, u64::from(*generated), 1);
            match usage_tokens {
                Some(tokens) => {
                    push_uint(&mut body, 1, 1);
                    push_uint(&mut body, *tokens, 8);
                }
                None => push_uint(&mut body, 0, 1),
            }
            push_optional_text(&mut body, model.as_ref());
            2
        }
        Kind::StatusChanged { status, detail } => {
            push_text(&mut body, status);
            push_optional_text(&mut body, detail.as_ref());
            3
        }
        Kind::Message { message_id, actor, text, status, delivery, .. } => {
            push_text(&mut body, message_id);
            push_text(&mut body, actor);
            push_text(&mut body, text);
            push_uint(&mut body, 0, 4);
            push_text(&mut body, status);
            push_optional_text(&mut body, delivery.as_ref());
            4
        }
        Kind::MessageDelta { message_id, delta } => {
            push_text(&mut body, message_id);
            push_text(&mut body, delta);
            5
        }
    };
    let mut frame = Vec::new();
    push_uint(&mut frame, tag, 1);
    push_uint(&mut frame, body.len() as u64, 4);
    frame.extend_from_slice(&body);
    frame
}

struct Cursor<'a> {
    bytes: &'a [u8],
    at: usize,
    end: usize,
}

impl<'a> Cursor<'a> {
    fn read_uint(&mut self, width: usize) -> Result<u64, u64> {
        if self.end - self.at < width {
            return Err(TRUNCATED_EVENT);
        }
        let value = read_uint(self.bytes, self.at, width);
        self.at += width;
        Ok(value)
    }

    fn read_presence(&mut self) -> Result<bool, u64> {
        match self.read_uint(1)? {
            0 => Ok(false),
            1 => Ok(true),
            _ => Err(BAD_FIELD),
        }
    }

    fn read_text(&mut self) -> Result<String, u64> {
        let length = self.read_uint(4)? as usize;
        if self.end - self.at < length {
            return Err(TRUNCATED_EVENT);
        }
        let text = String::from_utf8_lossy(&self.bytes[self.at..self.at + length]).into_owned();
        self.at += length;
        Ok(text)
    }

    fn read_optional_text(&mut self) -> Result<Option<String>, u64> {
        match self.read_presence()? {
            true => Ok(Some(self.read_text()?)),
            false => Ok(None),
        }
    }
}

fn decode_event(bytes: &[u8], tag: u64, at: usize, end: usize) -> Result<Event, u64> {
    let mut cursor = Cursor { bytes, at, end };
    let id = cursor.read_text()?;
    let session_id = cursor.read_text()?;
    let sequence = cursor.read_uint(8)?;
    let created_at = cursor.read_text()?;
    let kind = match tag {
        1 => Kind::SessionStarted,
        2 => {
            let title = cursor.read_text()?;
            let generated = cursor.read_presence()?;
            let usage_tokens = match cursor.read_presence()? {
                true => Some(cursor.read_uint(8)?),
                false => None,
            };
            let model = cursor.read_optional_text()?;
            Kind::SessionTitled { title, generated, usage_tokens, model }
        }
        3 => {
            let status = cursor.read_text()?;
            if Status::named(&status).is_none() {
                return Err(BAD_FIELD);
            }
            let detail = cursor.read_optional_text()?;
            Kind::StatusChanged { status, detail }
        }
        4 => {
            let message_id = cursor.read_text()?;
            let actor = cursor.read_text()?;
            let text = cursor.read_text()?;
            let count = cursor.read_uint(4)?;
            if count > (cursor.end - cursor.at) as u64 / 4 {
                return Err(TRUNCATED_EVENT);
            }
            for _ in 0..count {
                cursor.read_text()?;
            }
            let status = cursor.read_text()?;
            let delivery = cursor.read_optional_text()?;
            Kind::Message { message_id, actor, text, status, delivery }
        }
        5 => {
            let message_id = cursor.read_text()?;
            let delta = cursor.read_text()?;
            Kind::MessageDelta { message_id, delta }
        }
        _ => return Err(UNKNOWN_TAG),
    };
    if cursor.at != end {
        return Err(TRAILING_BYTES);
    }
    Ok(Event { id, session_id, sequence, created_at, kind })
}

// The `borg_events` reader, with the same reasons in the same order: a tag outside 1..5, a length
// past the ceiling, a body that stops early, a field marker that is neither 0 nor 1, and bytes past
// the last field.
fn decode_stream(bytes: &[u8]) -> Result<Vec<Event>, u64> {
    let mut events = Vec::new();
    let mut at = 0usize;
    while at < bytes.len() {
        if bytes.len() - at < 5 {
            return Err(TRUNCATED_EVENT);
        }
        let tag = u64::from(bytes[at]);
        let length = read_uint(bytes, at + 1, 4);
        at += 5;
        if !(1..=5).contains(&tag) {
            return Err(UNKNOWN_TAG);
        }
        if length > MAX_EVENT_BODY {
            return Err(LENGTH_OVERFLOW);
        }
        if ((bytes.len() - at) as u64) < length {
            return Err(TRUNCATED_EVENT);
        }
        let end = at + length as usize;
        events.push(decode_event(bytes, tag, at, end)?);
        at = end;
    }
    Ok(events)
}

fn code_name(code: u64) -> &'static str {
    match code {
        0 => "ok",
        10 => "version-mismatch",
        11 => "session-mismatch",
        12 => "not-handshaken",
        13 => "frame-too-large",
        14 => "short-read",
        15 => "bad-control",
        16 => "bad-reply",
        17 => "replay-refused",
        20 => "unknown-tag",
        21 => "truncated-event",
        22 => "length-overflow",
        23 => "bad-field",
        24 => "trailing-bytes",
        _ => "unknown",
    }
}

// ---- the transport ----

const PROTOCOL_VERSION: u64 = 1;
const VERSION_MISMATCH: u64 = 10;
const SESSION_MISMATCH: u64 = 11;
const NOT_HANDSHAKEN: u64 = 12;
const FRAME_TOO_LARGE: u64 = 13;
const SHORT_READ: u64 = 14;
const BAD_CONTROL: u64 = 15;
const BAD_REPLY: u64 = 16;
const REPLAY_REFUSED: u64 = 17;

// `at`, `reason` and `detail` are rendered the way `borg_replay` renders its reports, so `-` means
// absent.
#[derive(Clone)]
struct FrameRefusal {
    code: u64,
    at: String,
    reason: String,
    detail: String,
}

impl FrameRefusal {
    fn new(code: u64, detail: &str) -> FrameRefusal {
        FrameRefusal {
            code,
            at: "-".to_string(),
            reason: String::new(),
            detail: detail.to_string(),
        }
    }

    // The name the refusal reports: the fold's own reason when it has one, otherwise its code.
    fn name(&self) -> &str {
        if !self.reason.is_empty() {
            return &self.reason;
        }
        code_name(self.code)
    }

    fn journal_code(&self) -> u64 {
        match self.code {
            SHORT_READ => TRUNCATED_EVENT,
            FRAME_TOO_LARGE => LENGTH_OVERFLOW,
            code if (UNKNOWN_TAG..=TRAILING_BYTES).contains(&code) => code,
            _ => 0,
        }
    }
}

const OP_HELLO: u64 = 1;
const OP_HELLO_OK: u64 = 2;
const OP_HELLO_REFUSED: u64 = 3;
const OP_REPLY: u64 = 4;
const OP_END: u64 = 5;

fn header(tag: u64, length: u64) -> Vec<u8> {
    let mut out = Vec::new();
    push_uint(&mut out, tag, 1);
    push_uint(&mut out, length, 4);
    out
}

fn control(op: u64, body: &[u8]) -> Vec<u8> {
    let mut framed = Vec::new();
    push_uint(&mut framed, op, 1);
    framed.extend_from_slice(body);
    let mut out = header(0, framed.len() as u64);
    out.extend_from_slice(&framed);
    out
}

fn hello(version: u64, session: &str) -> Vec<u8> {
    let mut body = Vec::new();
    push_uint(&mut body, version, 4);
    push_text(&mut body, session);
    control(OP_HELLO, &body)
}

fn hello_ok(version: u64, session: &str) -> Vec<u8> {
    let mut body = Vec::new();
    push_uint(&mut body, version, 4);
    push_text(&mut body, session);
    control(OP_HELLO_OK, &body)
}

fn hello_refused(daemon: u64, client: u64, detail: &str) -> Vec<u8> {
    let mut body = Vec::new();
    push_uint(&mut body, daemon, 4);
    push_uint(&mut body, client, 4);
    push_text(&mut body, detail);
    control(OP_HELLO_REFUSED, &body)
}

fn end_marker() -> Vec<u8> {
    control(OP_END, &[])
}

struct Reply {
    sequence: u64,
    status: String,
    events: u64,
    refused: bool,
    code: u64,
    at: String,
    reason: String,
    detail: String,
}

impl Reply {
    fn empty() -> Reply {
        Reply {
            sequence: 0,
            status: "-".to_string(),
            events: 0,
            refused: false,
            code: 0,
            at: "-".to_string(),
            reason: String::new(),
            detail: String::new(),
        }
    }

    fn of_state(state: &State) -> Reply {
        Reply {
            sequence: state.latest_sequence,
            status: state
                .status
                .map(|status| status.name().to_string())
                .unwrap_or_else(|| "-".to_string()),
            events: state.events_seen,
            ..Reply::empty()
        }
    }

    fn of_refusal(value: &FrameRefusal) -> Reply {
        Reply {
            refused: true,
            code: value.code,
            at: value.at.clone(),
            reason: value.reason.clone(),
            detail: value.detail.clone(),
            ..Reply::empty()
        }
    }

    fn name(&self) -> &str {
        if !self.reason.is_empty() {
            return &self.reason;
        }
        code_name(self.code)
    }

    fn frame(&self) -> Vec<u8> {
        let mut body = Vec::new();
        push_uint(&mut body, self.sequence, 8);
        push_text(&mut body, &self.status);
        push_uint(&mut body, self.events, 8);
        if self.refused {
            push_uint(&mut body, 1, 1);
            push_uint(&mut body, self.code, 8);
            push_text(&mut body, &self.at);
            push_text(&mut body, &self.reason);
            push_text(&mut body, &self.detail);
        } else {
            push_uint(&mut body, 0, 1);
        }
        control(OP_REPLY, &body)
    }

    fn line(&self) -> String {
        if self.refused {
            format!("refused {} at {} detail {}", self.name(), self.at, self.detail)
        } else {
            format!(
                "ok sequence {} status {} events {}",
                self.sequence, self.status, self.events
            )
        }
    }
}

fn refusal_line(value: &FrameRefusal) -> String {
    let detail = if value.detail.is_empty() { "-" } else { &value.detail };
    format!(
        "refused {} at {} detail {detail}",
        value.name(),
        value.at
    )
}

// A body cursor that reports `BAD_CONTROL` for a control frame cut short, mirroring the framing
// module's own readers.
struct Body<'a> {
    bytes: &'a [u8],
    at: usize,
    end: usize,
    ok: bool,
}

impl<'a> Body<'a> {
    fn new(bytes: &'a [u8]) -> Body<'a> {
        Body { bytes, at: 1, end: bytes.len(), ok: true }
    }

    fn uint(&mut self, width: usize) -> u64 {
        if !self.ok {
            return 0;
        }
        if self.end < self.at || self.end - self.at < width {
            self.ok = false;
            return 0;
        }
        let value = read_uint(self.bytes, self.at, width);
        self.at += width;
        value
    }

    fn text(&mut self) -> String {
        if !self.ok {
            return String::new();
        }
        if self.end < self.at || self.end - self.at < 4 {
            self.ok = false;
            return String::new();
        }
        let length = read_uint(self.bytes, self.at, 4) as usize;
        self.at += 4;
        if self.end < self.at || self.end - self.at < length {
            self.ok = false;
            return String::new();
        }
        let text = String::from_utf8_lossy(&self.bytes[self.at..self.at + length]).into_owned();
        self.at += length;
        text
    }
}

fn reply_of(bytes: &[u8]) -> Result<Reply, FrameRefusal> {
    let mut body = Body::new(bytes);
    if bytes.is_empty() || bytes[0] != OP_REPLY as u8 {
        return Err(FrameRefusal::new(BAD_REPLY, "reply expected"));
    }
    let sequence = body.uint(8);
    let status = body.text();
    let events = body.uint(8);
    let marker = body.uint(1);
    if !body.ok {
        return Err(FrameRefusal::new(BAD_REPLY, "reply truncated"));
    }
    if marker > 1 {
        return Err(FrameRefusal::new(BAD_REPLY, "reply refusal marker"));
    }
    if marker == 0 {
        if body.at != body.end {
            return Err(FrameRefusal::new(BAD_REPLY, "trailing bytes"));
        }
        return Ok(Reply {
            sequence,
            status,
            events,
            ..Reply::empty()
        });
    }
    let code = body.uint(8);
    let at = body.text();
    let reason = body.text();
    let detail = body.text();
    if !body.ok || body.at != body.end {
        return Err(FrameRefusal::new(BAD_REPLY, "reply refusal truncated"));
    }
    Ok(Reply {
        sequence,
        status,
        events,
        refused: true,
        code,
        at,
        reason,
        detail,
    })
}

fn hello_refusal_of(bytes: &[u8]) -> Result<FrameRefusal, FrameRefusal> {
    let mut body = Body::new(bytes);
    if bytes.is_empty() || bytes[0] != OP_HELLO_REFUSED as u8 {
        return Err(FrameRefusal::new(BAD_CONTROL, "handshake answer expected"));
    }
    let daemon = body.uint(4);
    let client = body.uint(4);
    let _detail = body.text();
    if !body.ok || body.at != body.end {
        return Err(FrameRefusal::new(BAD_CONTROL, "handshake answer truncated"));
    }
    Ok(FrameRefusal {
        code: VERSION_MISMATCH,
        at: "-".to_string(),
        reason: String::new(),
        detail: format!("daemon {daemon} client {client}"),
    })
}

fn hello_ok_of(bytes: &[u8]) -> Result<(u64, String), FrameRefusal> {
    let mut body = Body::new(bytes);
    if bytes.is_empty() || bytes[0] != OP_HELLO_OK as u8 {
        return Err(FrameRefusal::new(BAD_CONTROL, "handshake answer expected"));
    }
    let version = body.uint(4);
    let session = body.text();
    if !body.ok || body.at != body.end {
        return Err(FrameRefusal::new(BAD_CONTROL, "handshake answer truncated"));
    }
    Ok((version, session))
}

// One decoded frame: its bytes are kept because the event reader is handed exactly what a journal
// file would hold.
struct Frame {
    tag: u64,
    body: Vec<u8>,
}

impl Frame {
    fn bytes(&self) -> Vec<u8> {
        let mut out = header(self.tag, self.body.len() as u64);
        out.extend_from_slice(&self.body);
        out
    }
}

enum Next {
    Frame(Frame),
    Pending,
    Refused(FrameRefusal),
}

struct Transport {
    buffer: Vec<u8>,
}

impl Transport {
    fn new() -> Transport {
        Transport { buffer: Vec::new() }
    }

    fn feed(&mut self, bytes: &[u8]) {
        self.buffer.extend_from_slice(bytes);
    }

    fn next(&mut self) -> Next {
        if self.buffer.len() < 5 {
            return Next::Pending;
        }
        let tag = u64::from(self.buffer[0]);
        let length = read_uint(&self.buffer, 1, 4);
        if length > MAX_EVENT_BODY {
            return Next::Refused(FrameRefusal::new(
                FRAME_TOO_LARGE,
                &format!("{length}/{MAX_EVENT_BODY}"),
            ));
        }
        if tag == 0 && length < 1 {
            return Next::Refused(FrameRefusal::new(
                BAD_CONTROL,
                "control frame without an opcode",
            ));
        }
        if ((self.buffer.len() - 5) as u64) < length {
            return Next::Pending;
        }
        let total = 5 + length as usize;
        let body = self.buffer[5..total].to_vec();
        self.buffer.drain(..total);
        Next::Frame(Frame { tag, body })
    }

    fn close(&mut self) -> Option<FrameRefusal> {
        if self.buffer.is_empty() {
            return None;
        }
        Some(FrameRefusal::new(
            SHORT_READ,
            &format!("{} bytes into a frame", self.buffer.len()),
        ))
    }
}

// An event frame through the journal reader: the frame's own bytes, exactly as a file would hold
// them.
fn event_of(frame: &Frame) -> Result<Event, FrameRefusal> {
    let bytes = frame.bytes();
    match decode_stream(&bytes) {
        Ok(events) if events.len() == 1 => Ok(events.into_iter().next().unwrap()),
        Ok(_) => Err(FrameRefusal::new(TRAILING_BYTES, "")),
        Err(code) => Err(FrameRefusal::new(code, "")),
    }
}

// ---- the sections ----

fn hex(bytes: &[u8]) -> String {
    let mut out = String::new();
    for byte in bytes {
        out.push_str(&format!("{byte:02x}"));
    }
    out
}

fn show_frames(name: &str, bytes: &[u8]) {
    let mut whole = Transport::new();
    whole.feed(bytes);
    let mut index = 0;
    loop {
        match whole.next() {
            Next::Frame(frame) => {
                println!(
                    "frame {name} {index} {} {} {}",
                    frame.tag,
                    frame.body.len(),
                    hex(&frame.bytes())
                );
                index += 1;
            }
            Next::Pending | Next::Refused(_) => return,
        }
    }
}

fn show_split(name: &str, bytes: &[u8]) {
    let mut slow = Transport::new();
    let mut index = 0;
    let mut stopped = false;
    for at in 0..bytes.len() {
        slow.feed(&bytes[at..at + 1]);
        while !stopped {
            match slow.next() {
                Next::Frame(frame) => {
                    println!(
                        "split {name} {index} {} {} {}",
                        frame.tag,
                        frame.body.len(),
                        hex(&frame.bytes())
                    );
                    index += 1;
                }
                Next::Pending => break,
                Next::Refused(_) => {
                    stopped = true;
                    break;
                }
            }
        }
    }
}

fn capture(events: &[Event]) -> Vec<u8> {
    let mut out = Vec::new();
    for event in events {
        out.extend_from_slice(&encode_event(event));
    }
    out
}

fn show_capture(name: &str, events: &[Event]) {
    let bytes = capture(events);
    let shown = match decode_stream(&bytes) {
        Ok(decoded) => match replay(&decoded) {
            Ok(state) => checksum(&state),
            Err(refusal) => format!(
                "{}/{}",
                refusal.reason.name(),
                refusal
                    .at
                    .map(|value| value.to_string())
                    .unwrap_or_else(|| "-".to_string())
            ),
        },
        Err(code) => format!("stream/{code}"),
    };
    println!("capture {name} {} {shown}", events.len());
}

fn refused_line(label: &str, value: &FrameRefusal) {
    let detail = if value.detail.is_empty() { "-" } else { value.detail.as_str() };
    println!(
        "refused {label} {} {} {} {} {detail}",
        value.name(),
        value.code,
        value.journal_code(),
        value.at
    );
}

fn code_line(name: &str, code: u64) {
    println!("file {name} {} {code}", code_name(code));
}

fn header_case(label: &str, bytes: &[u8]) {
    let mut state = Transport::new();
    state.feed(bytes);
    match state.next() {
        Next::Frame(frame) => println!(
            "frame {label} 0 {} {} {}",
            frame.tag,
            frame.body.len(),
            hex(&frame.bytes())
        ),
        Next::Pending => println!("decoded {label}"),
        Next::Refused(value) => refused_line("header", &value),
    }
}

fn event_case(label: &str, bytes: &[u8]) {
    let mut state = Transport::new();
    state.feed(bytes);
    match state.next() {
        Next::Frame(frame) => match event_of(&frame) {
            Ok(_) => println!("decoded {label}"),
            Err(value) => refused_line("event", &value),
        },
        Next::Pending => println!("decoded {label}"),
        Next::Refused(value) => refused_line("header", &value),
    }
    code_line(label, decode_stream(bytes).err().unwrap_or(STREAM_OK));
}

fn stream_case(label: &str, bytes: &[u8]) {
    let mut state = Transport::new();
    state.feed(bytes);
    let mut stopped = false;
    loop {
        match state.next() {
            Next::Frame(_) => {}
            Next::Pending => break,
            Next::Refused(value) => {
                refused_line("stream", &value);
                stopped = true;
                break;
            }
        }
    }
    if !stopped {
        match state.close() {
            Some(value) => refused_line("stream", &value),
            None => println!("decoded {label}"),
        }
    }
    code_line(label, decode_stream(bytes).err().unwrap_or(STREAM_OK));
}

fn titled_body(marker: u8) -> Vec<u8> {
    let mut out = Vec::new();
    push_text(&mut out, "e1");
    push_text(&mut out, "s1");
    push_uint(&mut out, 1, 8);
    push_text(&mut out, "t1");
    push_text(&mut out, "wire");
    out.push(marker);
    out
}

fn show_refusals(events: &[Event]) {
    let bytes = capture(events);

    let cut = bytes[..bytes.len() - 3].to_vec();
    stream_case("short-read", &cut);

    let too_large = header(1, MAX_EVENT_BODY + 1);
    header_case("frame-too-large", &too_large);
    code_line(
        "frame-too-large",
        decode_stream(&too_large).err().unwrap_or(STREAM_OK),
    );

    event_case("unknown-tag", &header(6, 0));

    let mut first = Transport::new();
    first.feed(&bytes);
    if let Next::Frame(frame) = first.next() {
        // One body byte short of what its fields need, and one byte past them.
        let mut clipped = header(frame.tag, frame.body.len() as u64 - 1);
        clipped.extend_from_slice(&frame.body[..frame.body.len() - 1]);
        event_case("truncated-event", &clipped);
        let mut padded = header(frame.tag, frame.body.len() as u64 + 1);
        padded.extend_from_slice(&frame.body);
        padded.push(0);
        event_case("trailing-bytes", &padded);
    }

    let bad = titled_body(2);
    let mut bad_field = header(2, bad.len() as u64);
    bad_field.extend_from_slice(&bad);
    event_case("bad-field", &bad_field);

    header_case("bad-control", &header(0, 0));

    let reply = Reply::empty().frame();
    let mut broken = reply[..reply.len() - 1].to_vec();
    broken.push(2);
    let mut answer = Transport::new();
    answer.feed(&broken);
    match answer.next() {
        Next::Frame(frame) => match reply_of(&frame.body) {
            Ok(_) => println!("decoded bad-reply"),
            Err(value) => refused_line("reply", &value),
        },
        Next::Pending | Next::Refused(_) => {}
    }

    let mut fresh = Transport::new();
    fresh.feed(&bytes);
    match fresh.next() {
        Next::Frame(frame) => {
            if event_of(&frame).is_ok() {
                refused_line("handshake", &FrameRefusal::new(NOT_HANDSHAKEN, ""));
            }
        }
        Next::Pending | Next::Refused(_) => {}
    }

    let mut foreign = Transport::new();
    foreign.feed(&hello(PROTOCOL_VERSION, "handshake"));
    if let Next::Frame(frame) = foreign.next() {
        if frame.body.first() == Some(&(OP_HELLO as u8)) {
            foreign.feed(&bytes);
            if let Next::Frame(event_frame) = foreign.next() {
                if let Ok(event) = event_of(&event_frame) {
                    refused_line(
                        "session",
                        &FrameRefusal {
                            code: SESSION_MISMATCH,
                            at: "-".to_string(),
                            reason: String::new(),
                            detail: format!("handshake handshake event {}", event.session_id),
                        },
                    );
                }
            }
        }
    }

    let mut dated = Transport::new();
    dated.feed(&hello(2, "s1"));
    let peer = 2u64;
    if peer != PROTOCOL_VERSION {
        refused_line(
            "version",
            &FrameRefusal {
                code: VERSION_MISMATCH,
                at: "-".to_string(),
                reason: String::new(),
                detail: format!("daemon {PROTOCOL_VERSION} client {peer}"),
            },
        );
    }

    // The fold, one frame at a time, so the first event that cannot apply stops it.
    let mut state = Transport::new();
    state.feed(&bytes);
    let mut folded = State::default();
    let mut step = 0u64;
    loop {
        match state.next() {
            Next::Frame(frame) => {
                if let Ok(event) = event_of(&frame) {
                    match apply(&folded, &event, step) {
                        Ok(next) => {
                            folded = next;
                            step += 1;
                        }
                        Err(refusal) => {
                            refused_line(
                                "fold",
                                &FrameRefusal {
                                    code: REPLAY_REFUSED,
                                    at: refusal
                                        .at
                                        .map(|value| value.to_string())
                                        .unwrap_or_else(|| "-".to_string()),
                                    reason: refusal.reason.name().to_string(),
                                    detail: refusal.detail,
                                },
                            );
                            return;
                        }
                    }
                }
            }
            Next::Pending | Next::Refused(_) => return,
        }
    }
}

// ---- the socket ----

// The daemon half: read frames from the connection, fold them, write exactly one answer.
fn serve(stream: &mut TcpStream) -> Reply {
    let mut state = Transport::new();
    let mut folded = State::default();
    let mut index = 0u64;
    let mut hello_session = String::new();
    loop {
        match state.next() {
            Next::Frame(frame) => {
                if frame.tag == 0 {
                    let op = u64::from(frame.body[0]);
                    if op == OP_HELLO {
                        // `Body::new` starts after the opcode, so the version is the first field.
                        let mut body = Body::new(&frame.body);
                        let version = body.uint(4);
                        let session = body.text();
                        if !body.ok || body.at != body.end || session.is_empty() {
                            let answer = FrameRefusal::new(BAD_CONTROL, "hello");
                            let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                            return Reply::of_refusal(&answer);
                        }
                        if version != PROTOCOL_VERSION {
                            let detail = format!("daemon {PROTOCOL_VERSION} client {version}");
                            let answer = FrameRefusal {
                                code: VERSION_MISMATCH,
                                at: "-".to_string(),
                                reason: String::new(),
                                detail,
                            };
                            let _ = stream.write_all(&hello_refused(
                                PROTOCOL_VERSION,
                                version,
                                &answer.detail,
                            ));
                            return Reply::of_refusal(&answer);
                        }
                        let _ = stream.write_all(&hello_ok(PROTOCOL_VERSION, &session));
                        hello_session = session;
                    } else if op == OP_END {
                        let answer = Reply::of_state(&folded);
                        let _ = stream.write_all(&answer.frame());
                        return answer;
                    } else {
                        let answer = FrameRefusal::new(BAD_CONTROL, "unknown control opcode");
                        let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                        return Reply::of_refusal(&answer);
                    }
                } else {
                    match event_of(&frame) {
                        Ok(event) => {
                            if event.session_id != hello_session {
                                let answer = FrameRefusal {
                                    code: SESSION_MISMATCH,
                                    at: "-".to_string(),
                                    reason: String::new(),
                                    detail: format!(
                                        "handshake {hello_session} event {}",
                                        event.session_id
                                    ),
                                };
                                let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                                return Reply::of_refusal(&answer);
                            }
                            match apply(&folded, &event, index) {
                                Ok(next) => {
                                    folded = next;
                                    index += 1;
                                }
                                Err(refusal) => {
                                    let answer = FrameRefusal {
                                        code: REPLAY_REFUSED,
                                        at: refusal
                                            .at
                                            .map(|value| value.to_string())
                                            .unwrap_or_else(|| "-".to_string()),
                                        reason: refusal.reason.name().to_string(),
                                        detail: refusal.detail,
                                    };
                                    let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                                    return Reply::of_refusal(&answer);
                                }
                            }
                        }
                        Err(answer) => {
                            let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                            return Reply::of_refusal(&answer);
                        }
                    }
                }
            }
            Next::Pending => {
                let mut chunk = [0u8; 65536];
                match stream.read(&mut chunk) {
                    Ok(0) => match state.close() {
                        Some(answer) => {
                            let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                            return Reply::of_refusal(&answer);
                        }
                        None => {
                            let answer = Reply::of_state(&folded);
                            let _ = stream.write_all(&answer.frame());
                            return answer;
                        }
                    },
                    Ok(read) => state.feed(&chunk[..read]),
                    Err(_) => return Reply::of_state(&folded),
                }
            }
            Next::Refused(answer) => {
                let _ = stream.write_all(&Reply::of_refusal(&answer).frame());
                return Reply::of_refusal(&answer);
            }
        }
    }
}

fn main() {
    for path in std::env::args().skip(1) {
        let name = label(&path);
        let Ok(text) = std::fs::read_to_string(&path) else { continue };
        let Ok(scenario) = serde_json::from_str::<Scenario>(&text) else {
            println!("case {name} malformed");
            continue;
        };
        let shown = if scenario.name.is_empty() { name.clone() } else { scenario.name.clone() };
        let bytes = capture(&scenario.events);
        show_frames(&shown, &bytes);
        show_split(&shown, &bytes);
        show_capture(&shown, &scenario.events);
        show_refusals(&scenario.events);
        loopback(&shown, &scenario);
    }
    socket_short_read();
}

fn loopback(name: &str, scenario: &Scenario) {
    let listener = TcpListener::bind(("127.0.0.1", 0)).expect("a loopback listener");
    let port = listener.local_addr().expect("a bound port").port();
    let mut client = TcpStream::connect(("127.0.0.1", port)).expect("a loopback client");
    let mut outbound = Vec::new();
    if scenario.client_version == PROTOCOL_VERSION {
        outbound.extend_from_slice(&hello(PROTOCOL_VERSION, &scenario.session));
        for event in &scenario.events {
            outbound.extend_from_slice(&encode_event(event));
        }
        outbound.extend_from_slice(&end_marker());
    } else {
        outbound.extend_from_slice(&hello(scenario.client_version, &scenario.session));
    }
    client.write_all(&outbound).expect("the request");
    let (mut server, _) = listener.accept().expect("a connection");
    let said = serve(&mut server);
    drop(server);
    let heard = resume(&mut client, &scenario.session);
    println!("loopback {name} {heard}");
    assert_eq!(heard, said.line());
    drop(client);
    drop(listener);
}

// The client half: decode the answer, and never report a session as fine when no answer arrived.
fn resume(stream: &mut TcpStream, session: &str) -> String {
    let mut state = Transport::new();
    loop {
        match state.next() {
            Next::Frame(frame) => {
                if frame.tag != 0 {
                    return refusal_line(&FrameRefusal::new(
                        BAD_CONTROL,
                        "event frame from the daemon",
                    ));
                }
                let op = u64::from(frame.body[0]);
                if op == OP_HELLO_OK {
                    match hello_ok_of(&frame.body) {
                        Ok((_version, acknowledged)) => {
                            if acknowledged != session {
                                return refusal_line(&FrameRefusal::new(
                                    SESSION_MISMATCH,
                                    "the daemon acknowledged another session",
                                ));
                            }
                        }
                        Err(value) => return refusal_line(&value),
                    }
                } else if op == OP_HELLO_REFUSED {
                    return match hello_refusal_of(&frame.body) {
                        Ok(value) => refusal_line(&value),
                        Err(value) => refusal_line(&value),
                    };
                } else if op == OP_REPLY {
                    return match reply_of(&frame.body) {
                        Ok(reply) => reply.line(),
                        Err(value) => refusal_line(&value),
                    };
                } else {
                    return refusal_line(&FrameRefusal::new(
                        BAD_CONTROL,
                        "unexpected control opcode",
                    ));
                }
            }
            Next::Pending => {
                let mut chunk = [0u8; 65536];
                match stream.read(&mut chunk) {
                    Ok(0) => match state.close() {
                        Some(value) => return refusal_line(&value),
                        None => {
                            return refusal_line(&FrameRefusal::new(
                                SHORT_READ,
                                "the daemon closed without an answer",
                            ));
                        }
                    },
                    Ok(read) => state.feed(&chunk[..read]),
                    Err(_) => return refusal_line(&FrameRefusal::new(SHORT_READ, "no answer")),
                }
            }
            Next::Refused(value) => return refusal_line(&value),
        }
    }
}

fn socket_short_read() {
    let listener = TcpListener::bind(("127.0.0.1", 0)).expect("a loopback listener");
    let port = listener.local_addr().expect("a bound port").port();
    let mut client = TcpStream::connect(("127.0.0.1", port)).expect("a loopback client");
    let (mut peer, _) = listener.accept().expect("a connection");
    let reply = Reply::empty().frame();
    peer.write_all(&reply[..reply.len() / 2]).expect("half a frame");
    drop(peer);
    println!("loopback socket {}", resume(&mut client, "s1"));
    drop(client);
    drop(listener);
}

fn label(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}
