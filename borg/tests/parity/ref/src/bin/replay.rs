//! Reference for `borg/tests/replay_test.grl`.
//!
//! An independent implementation of the rules `borg_replay` ports from `SessionState::reduce` and
//! `SessionState::apply` (session_store.rs:906-959, 1036-1041, 1320-1336): the sequence check, which
//! kinds move the activity clock (session_store.rs:582-602), the title that a generated title makes
//! final, the prompt/response rules, and the two enums a message row must fit (`EventActor`
//! contract.rs:2455, `MessageStatus` contract.rs:2470).
//!
//! The byte stream the replay test encodes for its `via: "stream"` scenarios is written and read
//! here as well, because the point of those cases is that replay folds what the *reader* returned: a
//! truncated tail must refuse, so the reference has to be able to produce one. The reader's other
//! refusals (unknown tag, over-long body, bad presence byte) are covered by the events and store
//! suites and are not re-derived twice; the reference reads tags 1-5 and reports a cut stream as 21.

use serde::Deserialize;

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
    via: String,
    #[serde(default)]
    truncate: u64,
    events: Vec<Event>,
}

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

    // Every status but a terminal mark means work is happening.
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
    Stream(u64),
    Sequence,
    Session,
    UnknownActor,
    UnknownMessageStatus,
}

impl Reason {
    fn name(&self) -> &'static str {
        match self {
            Reason::Stream(_) => "stream",
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

fn put_counters(out: &mut String, key: &str, applied: u64, frozen: u64) {
    put_key(out, key);
    out.push_str(&format!("{applied}/{frozen}"));
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
    put_counters(&mut out, "titles", state.titles_applied, state.titles_frozen);
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

fn show_state(name: &str, state: &State) {
    println!("case {name} ok {}", checksum(state));
    let line = |field: &str, value: String| println!("state {name} {field} {value}");
    line("seq", state.latest_sequence.to_string());
    line("events", state.events_seen.to_string());
    line("session", if state.session_id.is_empty() { "-".to_string() } else { state.session_id.clone() });
    line("started", state.started_at.clone().unwrap_or_else(|| "-".into()));
    line("activity", state.activity_at.clone().unwrap_or_else(|| "-".into()));
    line("status", state.status.map(|status| status.name().to_string()).unwrap_or_else(|| "-".into()));
    line("detail", state.status_detail.clone().unwrap_or_else(|| "-".into()));
    line("title", state.title.clone().unwrap_or_else(|| "-".into()));
    line("generated", state.title_generated.to_string());
    line("tokens", state.title_usage_tokens.map(|v| v.to_string()).unwrap_or_else(|| "-".into()));
    line("model", state.title_model.clone().unwrap_or_else(|| "-".into()));
    line("first", state.first_prompt.clone().unwrap_or_else(|| "-".into()));
    line("prompt", state.latest_prompt.clone().unwrap_or_else(|| "-".into()));
    line("response", state.latest_response.clone().unwrap_or_else(|| "-".into()));
    line("titles", format!("{}/{}", state.titles_applied, state.titles_frozen));
}

fn show_refusal(name: &str, refusal: &Refusal) {
    let at = refusal.at.map(|value| value.to_string()).unwrap_or_else(|| "-".into());
    let code = match refusal.reason {
        Reason::Stream(code) => code.to_string(),
        _ => "-".to_string(),
    };
    let detail = if refusal.detail.is_empty() { "-".to_string() } else { refusal.detail.clone() };
    println!("case {name} refused {} at {at} code {code} detail {detail}", refusal.reason.name());
}

// ---- the byte stream the `via: "stream"` scenarios travel over ----

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

fn encode_event(out: &mut Vec<u8>, event: &Event) {
    let mut body = Vec::new();
    push_text(&mut body, &event.id);
    push_text(&mut body, &event.session_id);
    push_uint(&mut body, event.sequence, 8);
    push_text(&mut body, &event.created_at);
    let code = match &event.kind {
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
        Kind::Message { message_id, actor, text, status, delivery } => {
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
    push_uint(out, code, 1);
    push_uint(out, body.len() as u64, 4);
    out.extend_from_slice(&body);
}

struct Cursor<'a> {
    bytes: &'a [u8],
    at: usize,
    end: usize,
}

impl<'a> Cursor<'a> {
    fn read_uint(&mut self, width: usize) -> Option<u64> {
        if self.end - self.at < width {
            return None;
        }
        let mut value = 0u64;
        for index in (0..width).rev() {
            value = value * 256 + u64::from(self.bytes[self.at + index]);
        }
        self.at += width;
        Some(value)
    }

    fn read_text(&mut self) -> Option<String> {
        let length = self.read_uint(4)? as usize;
        if length > self.end - self.at {
            return None;
        }
        let text = String::from_utf8(self.bytes[self.at..self.at + length].to_vec()).ok()?;
        self.at += length;
        Some(text)
    }

    fn read_optional_text(&mut self) -> Option<Option<String>> {
        match self.read_uint(1)? {
            0 => Some(None),
            1 => Some(Some(self.read_text()?)),
            _ => None,
        }
    }
}

fn decode_event(bytes: &[u8], tag: u64, at: usize, end: usize) -> Option<Event> {
    let mut cursor = Cursor { bytes, at, end };
    let id = cursor.read_text()?;
    let session_id = cursor.read_text()?;
    let sequence = cursor.read_uint(8)?;
    let created_at = cursor.read_text()?;
    let kind = match tag {
        1 => Kind::SessionStarted,
        2 => {
            let title = cursor.read_text()?;
            let generated = match cursor.read_uint(1)? {
                0 => false,
                1 => true,
                _ => return None,
            };
            let usage_tokens = match cursor.read_uint(1)? {
                0 => None,
                1 => Some(cursor.read_uint(8)?),
                _ => return None,
            };
            let model = cursor.read_optional_text()?;
            Kind::SessionTitled { title, generated, usage_tokens, model }
        }
        3 => {
            let status = cursor.read_text()?;
            let detail = cursor.read_optional_text()?;
            Kind::StatusChanged { status, detail }
        }
        4 => {
            let message_id = cursor.read_text()?;
            let actor = cursor.read_text()?;
            let text = cursor.read_text()?;
            let count = cursor.read_uint(4)? as usize;
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
        _ => return None,
    };
    if cursor.at != end {
        return None;
    }
    Some(Event { id, session_id, sequence, created_at, kind })
}

// 21 is TRUNCATED_EVENT in `borg_events`; the other reader refusals are not re-derived here.
const TRUNCATED_EVENT: u64 = 21;

fn decode_stream(bytes: &[u8]) -> Result<Vec<Event>, u64> {
    let mut events = Vec::new();
    let mut at = 0usize;
    while at < bytes.len() {
        if bytes.len() - at < 5 {
            return Err(TRUNCATED_EVENT);
        }
        let tag = u64::from(bytes[at]);
        let length = u64::from(bytes[at + 1])
            | (u64::from(bytes[at + 2]) << 8)
            | (u64::from(bytes[at + 3]) << 16)
            | (u64::from(bytes[at + 4]) << 24);
        at += 5;
        if !(1..=5).contains(&tag) {
            return Err(20);
        }
        if length > bytes.len() as u64 - at as u64 {
            return Err(TRUNCATED_EVENT);
        }
        let end = at + length as usize;
        match decode_event(bytes, tag, at, end) {
            Some(event) => events.push(event),
            None => return Err(23),
        }
        at = end;
    }
    Ok(events)
}

// ---- generated sequences ----

fn step(state: &mut u64) -> u64 {
    let mut x = *state;
    if x == 0 {
        x = 88172645463325252;
    }
    x ^= x / 8192;
    x ^= x.wrapping_mul(1099511628211);
    x ^= x / 131072;
    *state = x;
    x
}

fn status_word(roll: u64) -> String {
    match roll % 7 {
        0 => "starting",
        1 => "ready",
        2 => "running",
        3 => "waiting_for_approval",
        4 => "completed",
        5 => "failed",
        _ => "stopped",
    }
    .to_string()
}

fn generate(seed: u64, count: u64) -> Vec<Event> {
    let mut out = Vec::new();
    let mut random = seed;
    for index in 1..=count {
        let roll = step(&mut random);
        let sequence = if roll % 100 >= 96 { index + 3 } else { index };
        let kind = match roll % 8 {
            0 => Kind::SessionStarted,
            1 => Kind::SessionTitled {
                title: format!("t{}", roll % 3),
                generated: roll % 2 == 0,
                usage_tokens: Some(roll % 500),
                model: Some("m1".to_string()),
            },
            2 => Kind::StatusChanged {
                status: status_word(roll),
                detail: if roll % 3 == 0 { None } else { Some(format!("d{}", roll % 4)) },
            },
            3 => Kind::Message {
                message_id: format!("m{}", roll % 4),
                actor: "user".to_string(),
                text: format!("  p{}  ", roll % 3),
                status: "complete".to_string(),
                delivery: None,
            },
            4 => Kind::Message {
                message_id: format!("a{}", roll % 3),
                actor: "assistant".to_string(),
                text: format!("r{}", roll % 3),
                status: if roll % 2 == 0 { "complete" } else { "in_progress" }.to_string(),
                delivery: None,
            },
            5 => Kind::Message {
                message_id: format!("x{}", roll % 3),
                actor: "tool".to_string(),
                text: "tool".to_string(),
                status: "in_progress".to_string(),
                delivery: None,
            },
            6 => {
                if (roll / 8) % 8 == 0 {
                    Kind::Message {
                        message_id: "g1".to_string(),
                        actor: "ghost".to_string(),
                        text: "boo".to_string(),
                        status: "complete".to_string(),
                        delivery: None,
                    }
                } else {
                    Kind::Message {
                        message_id: format!("x{}", roll % 3),
                        actor: "tool".to_string(),
                        text: "tool".to_string(),
                        status: "in_progress".to_string(),
                        delivery: None,
                    }
                }
            }
            _ => Kind::MessageDelta {
                message_id: "m1".to_string(),
                delta: "d".to_string(),
            },
        };
        out.push(Event {
            id: format!("e{sequence}"),
            session_id: "s1".to_string(),
            sequence,
            created_at: format!("t{sequence}"),
            kind,
        });
    }
    out
}

fn outcome(events: &[Event]) -> String {
    match replay(events) {
        Ok(state) => checksum(&state),
        Err(refusal) => refusal_text(&refusal),
    }
}

fn refusal_text(refusal: &Refusal) -> String {
    let at = refusal.at.map(|value| value.to_string()).unwrap_or_else(|| "-".into());
    format!("refused:{}@{at}", refusal.reason.name())
}

fn append_matches(events: &[Event]) -> bool {
    if events.is_empty() {
        return true;
    }
    let last = events.len() - 1;
    let whole = outcome(events);
    match replay(&events[..last]) {
        Ok(state) => match apply(&state, &events[last], last as u64) {
            Ok(next) => checksum(&next) == whole,
            Err(refusal) => refusal_text(&refusal) == whole,
        },
        Err(refusal) => refusal_text(&refusal) == whole,
    }
}

fn property(seed: u64) {
    let events = generate(seed, 6);
    let first = outcome(&events);
    let stable = first == outcome(&events);
    let ok = stable && append_matches(&events);
    let verdict = if ok { "ok" } else { "fail" };
    println!("property {seed} {verdict} {first}");
}

fn label(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}

fn main() {
    for path in std::env::args().skip(1) {
        let name = label(&path);
        let Ok(bytes) = std::fs::read_to_string(&path) else { continue };
        let Ok(scenario) = serde_json::from_str::<Scenario>(&bytes) else {
            println!("case {name} malformed scenario");
            continue;
        };
        let shown = if scenario.name.is_empty() { name.clone() } else { scenario.name.clone() };
        if scenario.via == "stream" {
            let mut stream = Vec::new();
            for event in &scenario.events {
                encode_event(&mut stream, event);
            }
            let keep = if scenario.truncate as usize > stream.len() {
                0
            } else {
                stream.len() - scenario.truncate as usize
            };
            match decode_stream(&stream[..keep]) {
                Ok(events) => match replay(&events) {
                    Ok(state) => show_state(&shown, &state),
                    Err(refusal) => show_refusal(&shown, &refusal),
                },
                Err(code) => show_refusal(
                    &shown,
                    &Refusal { at: None, reason: Reason::Stream(code), detail: String::new() },
                ),
            }
            continue;
        }
        match replay(&scenario.events) {
            Ok(state) => show_state(&shown, &state),
            Err(refusal) => show_refusal(&shown, &refusal),
        }
    }
    for seed in 1..=24 {
        property(seed);
    }
}
