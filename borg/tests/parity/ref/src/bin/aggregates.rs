//! Reference for `borg/tests/aggregates_test.grl`.
//!
//! An independent implementation of the goal, plan and work aggregates, in the same spirit as
//! `replay.rs` and `frames.rs`: the event layouts, the fold rules and the fingerprint are written
//! here from the model rather than sharing code with the port, so a rule the port gets wrong shows up
//! as a diff line instead of agreeing with itself.
//!
//! What it reproduces, line for line:
//!
//!   * the fold of each fixture, rendered as the goal, the plan items, the work items and the
//!     session facts the same journal reconstructs
//!   * the refusal table: a goal created twice, an update with no goal, an update naming another
//!     goal, an update of a completed goal, a plan item naming work that does not exist, a duplicate
//!     plan item, a duplicate work item, and the readers' own refusals (`unknown-goal-status`,
//!     `unknown-item-status`, a cut stream, a sequence gap)
//!   * the three properties: the same journal through the byte stream, replayed twice, and replayed as
//!     a prefix plus a direct apply of the last event
//!   * a command line session over a real loopback socket: each command is folded by a daemon that
//!     keeps the session between connections, answered with the reply frame and the state frame, and
//!     printed from the bytes that came back
//!
//! The stamping the daemon does (sequence, event id, timestamp) is reproduced because the fold's
//! cursor rule depends on it: a command carries no sequence of its own.

use serde_json::Value;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};

// ---------------------------------------------------------------- fixtures

struct Event {
    session_id: String,
    sequence: u64,
    kind: Kind,
}

enum Kind {
    Started,
    Titled {
        title: String,
        generated: bool,
        #[allow(dead_code)]
        tokens: Option<u64>,
        model: Option<String>,
    },
    Status {
        status: String,
        detail: Option<String>,
    },
    Message {
        actor: String,
        text: String,
        status: String,
    },
    Delta,
    GoalCreated {
        goal_id: String,
        objective: String,
        budget: Option<u64>,
    },
    GoalUpdated {
        goal_id: String,
        status: String,
    },
    Plan {
        participant: String,
        revision: u64,
        items: Vec<PlanItem>,
    },
    Work {
        revision: u64,
        items: Vec<WorkItem>,
    },
}

#[derive(Clone)]
struct PlanItem {
    id: String,
    content: String,
    status: String,
    work: Option<String>,
}

#[derive(Clone)]
struct WorkItem {
    id: String,
    title: String,
    assignee: Option<String>,
    status: String,
}

// A decode failure, classified the way the port classifies it.
struct Malformed {
    class: &'static str,
    index: usize,
}

fn text(node: &Value, key: &str) -> Result<String, &'static str> {
    match node.get(key) {
        None => Err("missing"),
        Some(value) => match value.as_str() {
            Some(text) => Ok(text.to_string()),
            None => Err("type"),
        },
    }
}

fn number(node: &Value, key: &str) -> Result<u64, &'static str> {
    match node.get(key) {
        None => Err("missing"),
        Some(value) => match value.as_u64() {
            Some(number) => Ok(number),
            None => Err("type"),
        },
    }
}

fn optional_text(node: &Value, key: &str) -> Option<String> {
    match node.get(key) {
        None => None,
        Some(Value::Null) => None,
        Some(value) => value.as_str().map(|text| text.to_string()),
    }
}

fn optional_number(node: &Value, key: &str) -> Option<u64> {
    match node.get(key) {
        None => None,
        Some(Value::Null) => None,
        Some(value) => value.as_u64(),
    }
}

const GOAL_STATUSES: [&str; 3] = ["active", "complete", "blocked"];
const ITEM_STATUSES: [&str; 5] = [
    "pending",
    "in_progress",
    "blocked",
    "awaiting_review",
    "completed",
];

fn goal_status(name: &str) -> Result<String, &'static str> {
    if GOAL_STATUSES.contains(&name) {
        return Ok(name.to_string());
    }
    Err("unknown-goal-status")
}

fn item_status(name: &str) -> Result<String, &'static str> {
    if ITEM_STATUSES.contains(&name) {
        return Ok(name.to_string());
    }
    Err("unknown-item-status")
}

fn plan_item(node: &Value) -> Result<PlanItem, &'static str> {
    if !node.is_object() {
        return Err("type");
    }
    Ok(PlanItem {
        id: text(node, "id")?,
        content: text(node, "content")?,
        status: item_status(&text(node, "status")?)?,
        work: optional_text(node, "work_id"),
    })
}

fn work_item(node: &Value) -> Result<WorkItem, &'static str> {
    if !node.is_object() {
        return Err("type");
    }
    Ok(WorkItem {
        id: text(node, "id")?,
        title: text(node, "title")?,
        assignee: optional_text(node, "assignee"),
        status: item_status(&text(node, "status")?)?,
    })
}

fn list<T>(
    node: &Value,
    key: &str,
    one: fn(&Value) -> Result<T, &'static str>,
) -> Result<Vec<T>, &'static str> {
    let value = match node.get(key) {
        None => return Err("missing"),
        Some(value) => value,
    };
    let array = match value.as_array() {
        None => return Err("type"),
        Some(array) => array,
    };
    let mut out = Vec::new();
    for element in array {
        out.push(one(element)?);
    }
    Ok(out)
}

fn decode_event(node: &Value) -> Result<Event, &'static str> {
    if !node.is_object() {
        return Err("not-object");
    }
    let _id = text(node, "id")?;
    let session_id = text(node, "session_id")?;
    let sequence = number(node, "sequence")?;
    let _created_at = text(node, "created_at")?;
    let kind_node = match node.get("kind") {
        None => return Err("missing"),
        Some(value) => value,
    };
    let name = text(kind_node, "type")?;
    let kind = match name.as_str() {
        "session_started" => Kind::Started,
        "session_titled" => Kind::Titled {
            title: text(kind_node, "title")?,
            generated: kind_node
                .get("generated")
                .and_then(Value::as_bool)
                .unwrap_or(false),
            tokens: optional_number(kind_node, "usage_tokens"),
            model: optional_text(kind_node, "model"),
        },
        "status_changed" => {
            let status = text(kind_node, "status")?;
            match status.as_str() {
                "starting" | "ready" | "running" | "waiting_for_approval" | "completed"
                | "failed" | "stopped" => {}
                _ => return Err("unknown-kind"),
            }
            Kind::Status {
                status,
                detail: optional_text(kind_node, "detail"),
            }
        }
        "message" => Kind::Message {
            actor: text(kind_node, "actor")?,
            text: text(kind_node, "text")?,
            status: text(kind_node, "status")?,
        },
        "message_delta" => Kind::Delta,
        "goal_created" => Kind::GoalCreated {
            goal_id: text(kind_node, "goal_id")?,
            objective: text(kind_node, "objective")?,
            budget: optional_number(kind_node, "token_budget"),
        },
        "goal_updated" => Kind::GoalUpdated {
            goal_id: text(kind_node, "goal_id")?,
            status: goal_status(&text(kind_node, "status")?)?,
        },
        "plan_projected" => Kind::Plan {
            participant: text(kind_node, "participant_id")?,
            revision: number(kind_node, "workspace_revision")?,
            items: list(kind_node, "items", plan_item)?,
        },
        "work_projected" => Kind::Work {
            revision: number(kind_node, "revision")?,
            items: list(kind_node, "items", work_item)?,
        },
        _ => return Err("unknown-kind"),
    };
    Ok(Event {
        session_id,
        sequence,
        kind,
    })
}

// ---------------------------------------------------------------- the fold

#[derive(Default)]
struct Goal {
    id: String,
    objective: String,
    budget: Option<u64>,
    status: String,
}

#[derive(Default)]
struct Aggregates {
    goal: Option<Goal>,
    participant: Option<String>,
    revision: u64,
    plan: Vec<PlanItem>,
    work_revision: u64,
    work: Vec<WorkItem>,
    applied: u64,
    stale: u64,
}

#[derive(Default)]
struct Session {
    session: String,
    sequence: u64,
    events: u64,
    status: Option<String>,
    detail: Option<String>,
    title: Option<String>,
    generated: bool,
    model: Option<String>,
}

#[derive(Default)]
struct State {
    session: Session,
    aggregates: Aggregates,
}

enum Refusal {
    Stream(u64),
    Sequence {
        expected: u64,
        got: u64,
    },
    Session(String),
    UnknownActor(String),
    UnknownMessageStatus(String),
    Aggregate {
        reason: &'static str,
        detail: String,
    },
}

impl Refusal {
    fn reason(&self) -> String {
        match self {
            Refusal::Stream(_) => "stream".to_string(),
            Refusal::Sequence { .. } => "sequence".to_string(),
            Refusal::Session(_) => "session".to_string(),
            Refusal::UnknownActor(_) => "unknown-actor".to_string(),
            Refusal::UnknownMessageStatus(_) => "unknown-message-status".to_string(),
            Refusal::Aggregate { reason, .. } => (*reason).to_string(),
        }
    }

    fn detail(&self) -> String {
        match self {
            Refusal::Stream(_) => "-".to_string(),
            Refusal::Sequence { expected, got } => format!("{}/{}", expected, got),
            Refusal::Session(said) => said.clone(),
            Refusal::UnknownActor(name) | Refusal::UnknownMessageStatus(name) => name.clone(),
            Refusal::Aggregate { detail, .. } => detail.clone(),
        }
    }

    fn code(&self) -> String {
        match self {
            Refusal::Stream(code) => code.to_string(),
            _ => "-".to_string(),
        }
    }
}

fn aggregate_refusal(state: &State, event: &Event) -> Result<Option<Aggregates>, Refusal> {
    match &event.kind {
        Kind::GoalCreated {
            goal_id,
            objective,
            budget,
        } => {
            if let Some(goal) = &state.aggregates.goal {
                return Err(Refusal::Aggregate {
                    reason: "goal-exists",
                    detail: goal.id.clone(),
                });
            }
            Ok(Some(Aggregates {
                goal: Some(Goal {
                    id: goal_id.clone(),
                    objective: objective.clone(),
                    budget: *budget,
                    status: "active".to_string(),
                }),
                ..clone_aggregates(&state.aggregates)
            }))
        }
        Kind::GoalUpdated { goal_id, status } => {
            let goal = match &state.aggregates.goal {
                None => {
                    return Err(Refusal::Aggregate {
                        reason: "no-goal",
                        detail: goal_id.clone(),
                    })
                }
                Some(goal) => goal,
            };
            if goal.id != *goal_id {
                return Err(Refusal::Aggregate {
                    reason: "goal-mismatch",
                    detail: goal_id.clone(),
                });
            }
            if goal.status == "complete" {
                return Err(Refusal::Aggregate {
                    reason: "goal-finished",
                    detail: goal_id.clone(),
                });
            }
            let mut next = clone_aggregates(&state.aggregates);
            if let Some(goal) = next.goal.as_mut() {
                goal.status = status.clone();
            }
            Ok(Some(next))
        }
        Kind::Plan {
            participant,
            revision,
            items,
        } => {
            // The model's own rule first: a projection it would ignore cannot refuse.
            let same_participant = state
                .aggregates
                .participant
                .as_deref()
                .map(|known| known == participant)
                .unwrap_or(false);
            if same_participant && *revision < state.aggregates.revision {
                let mut kept = clone_aggregates(&state.aggregates);
                kept.stale += 1;
                return Ok(Some(kept));
            }
            for (index, item) in items.iter().enumerate() {
                if items[..index].iter().any(|earlier| earlier.id == item.id) {
                    return Err(Refusal::Aggregate {
                        reason: "duplicate-item",
                        detail: format!("plan item {}", item.id),
                    });
                }
                if let Some(work) = &item.work {
                    let known = state.aggregates.work.iter().any(|held| held.id == *work);
                    if !known {
                        return Err(Refusal::Aggregate {
                            reason: "unknown-work",
                            detail: format!("plan item {} wants work {}", item.id, work),
                        });
                    }
                }
            }
            Ok(Some(Aggregates {
                goal: clone_goal(&state.aggregates.goal),
                participant: Some(participant.clone()),
                revision: *revision,
                plan: items.clone(),
                work_revision: state.aggregates.work_revision,
                work: state.aggregates.work.clone(),
                applied: state.aggregates.applied + 1,
                stale: state.aggregates.stale,
            }))
        }
        Kind::Work { revision, items } => {
            for (index, item) in items.iter().enumerate() {
                if items[..index].iter().any(|earlier| earlier.id == item.id) {
                    return Err(Refusal::Aggregate {
                        reason: "duplicate-work",
                        detail: format!("work item {}", item.id),
                    });
                }
            }
            Ok(Some(Aggregates {
                goal: clone_goal(&state.aggregates.goal),
                participant: state.aggregates.participant.clone(),
                revision: state.aggregates.revision,
                plan: state.aggregates.plan.clone(),
                work_revision: *revision,
                work: items.clone(),
                applied: state.aggregates.applied,
                stale: state.aggregates.stale,
            }))
        }
        _ => Ok(None),
    }
}

fn clone_goal(goal: &Option<Goal>) -> Option<Goal> {
    goal.as_ref().map(|goal| Goal {
        id: goal.id.clone(),
        objective: goal.objective.clone(),
        budget: goal.budget,
        status: goal.status.clone(),
    })
}

fn clone_aggregates(aggregates: &Aggregates) -> Aggregates {
    Aggregates {
        goal: clone_goal(&aggregates.goal),
        participant: aggregates.participant.clone(),
        revision: aggregates.revision,
        plan: aggregates.plan.clone(),
        work_revision: aggregates.work_revision,
        work: aggregates.work.clone(),
        applied: aggregates.applied,
        stale: aggregates.stale,
    }
}

fn apply(state: &State, event: &Event, index: u64) -> Result<State, Refusal> {
    if !state.session.session.is_empty() && state.session.session != event.session_id {
        return Err(Refusal::Session(event.session_id.clone()));
    }
    let expected = state.session.sequence.saturating_add(1);
    if event.sequence != expected {
        return Err(Refusal::Sequence {
            expected,
            got: event.sequence,
        });
    }
    if let Kind::Message { actor, status, .. } = &event.kind {
        if !["user", "assistant", "tool", "system"].contains(&actor.as_str()) {
            return Err(Refusal::UnknownActor(actor.clone()));
        }
        if !["queued", "in_progress", "complete", "failed"].contains(&status.as_str()) {
            return Err(Refusal::UnknownMessageStatus(status.clone()));
        }
    }
    let mut next = State {
        session: Session {
            session: event.session_id.clone(),
            sequence: event.sequence,
            events: state.session.events + 1,
            status: state.session.status.clone(),
            detail: state.session.detail.clone(),
            title: state.session.title.clone(),
            generated: state.session.generated,
            model: state.session.model.clone(),
        },
        aggregates: clone_aggregates(&state.aggregates),
    };
    let _ = index;
    if let Some(aggregates) = aggregate_refusal(state, event)? {
        next.aggregates = aggregates;
    }
    match &event.kind {
        Kind::Started => {}
        Kind::Titled {
            title,
            generated,
            tokens: _,
            model,
        } => {
            if !next.session.generated {
                next.session.title = Some(title.clone());
                next.session.generated = *generated;
                next.session.model = model.clone();
            }
        }
        Kind::Status { status, detail } => {
            next.session.status = Some(status.clone());
            next.session.detail = detail.clone();
        }
        _ => {}
    }
    Ok(next)
}

fn replay(events: &[Event]) -> Result<State, (Refusal, Option<u64>)> {
    let mut state = State::default();
    for (index, event) in events.iter().enumerate() {
        match apply(&state, event, index as u64) {
            Ok(next) => state = next,
            Err(refusal) => return Err((refusal, Some(index as u64))),
        }
    }
    Ok(state)
}

// ---------------------------------------------------------------- the fingerprint
//
// Byte for byte the layout in `borg/src/aggregates.grl`: keys separated by `;`, a key followed by
// `=`, text length-prefixed as `len:text`, an absent value as `-`.

fn put_bytes(out: &mut Vec<u8>, text: &str) {
    out.extend_from_slice(text.as_bytes());
}

fn put_key(out: &mut Vec<u8>, key: &str) {
    if !out.is_empty() {
        out.push(b';');
    }
    put_bytes(out, key);
    out.push(b'=');
}

fn put_text(out: &mut Vec<u8>, key: &str, value: Option<&str>) {
    put_key(out, key);
    match value {
        Some(text) => {
            put_bytes(out, &text.len().to_string());
            out.push(b':');
            put_bytes(out, text);
        }
        None => out.push(b'-'),
    }
}

fn put_number(out: &mut Vec<u8>, key: &str, value: u64) {
    put_key(out, key);
    put_bytes(out, &value.to_string());
}

fn put_optional_number(out: &mut Vec<u8>, key: &str, value: Option<u64>) {
    put_key(out, key);
    match value {
        Some(number) => put_bytes(out, &number.to_string()),
        None => out.push(b'-'),
    }
}

fn fingerprint(aggregates: &Aggregates) -> String {
    let mut out = Vec::new();
    put_text(
        &mut out,
        "goal",
        aggregates.goal.as_ref().map(|goal| goal.id.as_str()),
    );
    put_text(
        &mut out,
        "objective",
        aggregates.goal.as_ref().map(|goal| goal.objective.as_str()),
    );
    put_optional_number(
        &mut out,
        "budget",
        aggregates.goal.as_ref().and_then(|goal| goal.budget),
    );
    put_text(
        &mut out,
        "goal-status",
        aggregates.goal.as_ref().map(|goal| goal.status.as_str()),
    );
    put_text(&mut out, "participant", aggregates.participant.as_deref());
    put_number(&mut out, "revision", aggregates.revision);
    for item in &aggregates.plan {
        put_text(&mut out, "item", Some(&item.id));
        put_text(&mut out, "content", Some(&item.content));
        put_text(&mut out, "status", Some(&item.status));
        put_text(&mut out, "work", item.work.as_deref());
    }
    put_number(&mut out, "work-revision", aggregates.work_revision);
    for item in &aggregates.work {
        put_text(&mut out, "work-id", Some(&item.id));
        put_text(&mut out, "work-title", Some(&item.title));
        put_text(&mut out, "assignee", item.assignee.as_deref());
        put_text(&mut out, "work-status", Some(&item.status));
    }
    put_key(&mut out, "plans");
    put_bytes(&mut out, &format!("{}/{}", aggregates.applied, aggregates.stale));
    String::from_utf8(out).expect("utf8")
}

fn checksum(aggregates: &Aggregates) -> String {
    let shown = fingerprint(aggregates);
    let mut hash: u64 = 14695981039346656037;
    for byte in shown.as_bytes() {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(1099511628211);
    }
    format!("{:016x}", hash)
}

// ---------------------------------------------------------------- rendering

fn readable(text: &str) -> String {
    if text.is_empty() {
        "-".to_string()
    } else {
        text.to_string()
    }
}

fn outcome(events: &[Event]) -> String {
    match replay(events) {
        Ok(state) => checksum(&state.aggregates),
        Err((refusal, at)) => format!(
            "refused:{}@{}",
            refusal.reason(),
            at.map(|index| index.to_string())
                .unwrap_or_else(|| "-".to_string())
        ),
    }
}

fn refusal_text(refusal: &Refusal, at: Option<u64>) -> String {
    format!(
        "refused:{}@{}",
        refusal.reason(),
        at.map(|index| index.to_string())
            .unwrap_or_else(|| "-".to_string())
    )
}

fn show_state(name: &str, state: &State) {
    println!(
        "case {} ok {}",
        name,
        checksum(&state.aggregates)
    );
    println!(
        "state {} seq {} events {}",
        name, state.session.sequence, state.session.events
    );
    match &state.aggregates.goal {
        Some(goal) => println!(
            "state {} goal {} {} budget {}",
            name,
            goal.id,
            goal.status,
            goal.budget
                .map(|budget| budget.to_string())
                .unwrap_or_else(|| "-".to_string())
        ),
        None => println!("state {} goal - - budget -", name),
    }
    println!(
        "state {} objective {}",
        name,
        state
            .aggregates
            .goal
            .as_ref()
            .map(|goal| readable(&goal.objective))
            .unwrap_or_else(|| "-".to_string())
    );
    println!(
        "state {} plan {} revision {} items {}",
        name,
        state
            .aggregates
            .participant
            .clone()
            .unwrap_or_else(|| "-".to_string()),
        state.aggregates.revision,
        state.aggregates.plan.len()
    );
    for (index, item) in state.aggregates.plan.iter().enumerate() {
        println!(
            "item {} {} {} {} work {} {}",
            name,
            index,
            item.id,
            item.status,
            item.work.clone().unwrap_or_else(|| "-".to_string()),
            item.content
        );
    }
    println!(
        "state {} work revision {} items {}",
        name,
        state.aggregates.work_revision,
        state.aggregates.work.len()
    );
    for (index, item) in state.aggregates.work.iter().enumerate() {
        println!(
            "work {} {} {} {} {} {}",
            name,
            index,
            item.id,
            item.assignee.clone().unwrap_or_else(|| "-".to_string()),
            item.status,
            item.title
        );
    }
    println!(
        "state {} session {} status {} title {}",
        name,
        readable(&state.session.session),
        state
            .session
            .status
            .clone()
            .unwrap_or_else(|| "-".to_string()),
        readable(&state.session.title.clone().unwrap_or_default())
    );
    println!(
        "state {} plans {}/{}",
        name, state.aggregates.applied, state.aggregates.stale
    );
}

fn show_refusal(name: &str, refusal: &Refusal, at: Option<u64>) {
    println!(
        "case {} refused {} at {} code {} detail {}",
        name,
        refusal.reason(),
        at.map(|index| index.to_string())
            .unwrap_or_else(|| "-".to_string()),
        refusal.code(),
        readable(&refusal.detail())
    );
}

// ---------------------------------------------------------------- the byte stream
//
// The journal layout `borg/src/events.grl` writes: `u8 tag | u32 LE length | body`, with the two
// aggregate tags placed after the five transcript ones.

const TAG_STARTED: u8 = 1;
const TAG_TITLED: u8 = 2;
const TAG_STATUS: u8 = 3;
const TAG_MESSAGE: u8 = 4;
const TAG_DELTA: u8 = 5;
const TAG_GOAL_CREATED: u8 = 6;
const TAG_GOAL_UPDATED: u8 = 7;
const TAG_PLAN: u8 = 8;
const TAG_WORK: u8 = 9;

fn push_text(out: &mut Vec<u8>, text: &str) {
    out.extend_from_slice(&(text.len() as u32).to_le_bytes());
    out.extend_from_slice(text.as_bytes());
}

fn push_optional_text(out: &mut Vec<u8>, text: &Option<String>) {
    match text {
        Some(text) => {
            out.push(1);
            push_text(out, text);
        }
        None => out.push(0),
    }
}

fn push_u64(out: &mut Vec<u8>, value: u64) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn tag_of(kind: &Kind) -> u8 {
    match kind {
        Kind::Started => TAG_STARTED,
        Kind::Titled { .. } => TAG_TITLED,
        Kind::Status { .. } => TAG_STATUS,
        Kind::Message { .. } => TAG_MESSAGE,
        Kind::Delta => TAG_DELTA,
        Kind::GoalCreated { .. } => TAG_GOAL_CREATED,
        Kind::GoalUpdated { .. } => TAG_GOAL_UPDATED,
        Kind::Plan { .. } => TAG_PLAN,
        Kind::Work { .. } => TAG_WORK,
    }
}

fn encode_event(event: &Event) -> Vec<u8> {
    let mut body = Vec::new();
    push_text(&mut body, "e");
    push_text(&mut body, &event.session_id);
    push_u64(&mut body, event.sequence);
    push_text(&mut body, "t");
    match &event.kind {
        Kind::Started => {}
        Kind::Titled {
            title,
            generated,
            tokens,
            model,
        } => {
            push_text(&mut body, title);
            body.push(if *generated { 1 } else { 0 });
            match tokens {
                Some(count) => {
                    body.push(1);
                    push_u64(&mut body, *count);
                }
                None => body.push(0),
            }
            push_optional_text(&mut body, model);
        }
        Kind::Status { status, detail } => {
            push_text(&mut body, status);
            push_optional_text(&mut body, detail);
        }
        Kind::Message {
            actor,
            text,
            status,
        } => {
            push_text(&mut body, "m1");
            push_text(&mut body, actor);
            push_text(&mut body, text);
            body.extend_from_slice(&0u32.to_le_bytes());
            push_text(&mut body, status);
            body.push(0);
        }
        Kind::Delta => {
            push_text(&mut body, "m1");
            push_text(&mut body, "d");
        }
        Kind::GoalCreated {
            goal_id,
            objective,
            budget,
        } => {
            push_text(&mut body, goal_id);
            push_text(&mut body, objective);
            match budget {
                Some(count) => {
                    body.push(1);
                    push_u64(&mut body, *count);
                }
                None => body.push(0),
            }
        }
        Kind::GoalUpdated { goal_id, status } => {
            push_text(&mut body, goal_id);
            push_text(&mut body, status);
        }
        Kind::Plan {
            participant,
            revision,
            items,
        } => {
            push_text(&mut body, participant);
            push_u64(&mut body, *revision);
            body.extend_from_slice(&(items.len() as u32).to_le_bytes());
            for item in items {
                push_text(&mut body, &item.id);
                push_text(&mut body, &item.content);
                push_text(&mut body, &item.status);
                push_optional_text(&mut body, &item.work);
            }
        }
        Kind::Work { revision, items } => {
            push_u64(&mut body, *revision);
            body.extend_from_slice(&(items.len() as u32).to_le_bytes());
            for item in items {
                push_text(&mut body, &item.id);
                push_text(&mut body, &item.title);
                push_optional_text(&mut body, &item.assignee);
                push_text(&mut body, &item.status);
            }
        }
    }
    let mut out = Vec::new();
    out.push(tag_of(&event.kind));
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

fn encode_stream(events: &[Event]) -> Vec<u8> {
    let mut out = Vec::new();
    for event in events {
        out.extend_from_slice(&encode_event(event));
    }
    out
}

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
    status: u64,
}

impl<'a> Reader<'a> {
    fn take_u8(&mut self) -> u8 {
        if self.status != 0 || self.at + 1 > self.bytes.len() {
            self.status = 21;
            return 0;
        }
        let value = self.bytes[self.at];
        self.at += 1;
        value
    }

    fn take_u64(&mut self) -> u64 {
        if self.status != 0 || self.at + 8 > self.bytes.len() {
            self.status = 21;
            return 0;
        }
        let mut value = 0u64;
        for index in (0..8).rev() {
            value = value.wrapping_mul(256).wrapping_add(self.bytes[self.at + index] as u64);
        }
        self.at += 8;
        value
    }

    // A thirty-two bit length, bounded by the bytes that are left.
    fn take_length(&mut self) -> u64 {
        if self.status != 0 || self.at + 4 > self.bytes.len() {
            self.status = 21;
            return 0;
        }
        let mut value = 0u64;
        for index in (0..4).rev() {
            value = value.wrapping_mul(256).wrapping_add(self.bytes[self.at + index] as u64);
        }
        self.at += 4;
        value
    }

    // A list count: each element carries at least its own four byte length, so a count larger than
    // the remaining bytes divided by four cannot be honest.
    fn take_count(&mut self) -> u64 {
        let value = self.take_length();
        if self.status != 0 {
            return 0;
        }
        if value > ((self.bytes.len() - self.at) / 4) as u64 {
            self.status = 21;
            return 0;
        }
        value
    }

    fn take_text(&mut self) -> String {
        let length = self.take_length() as usize;
        if self.status != 0 || self.at + length > self.bytes.len() {
            self.status = 21;
            return String::new();
        }
        let text = String::from_utf8_lossy(&self.bytes[self.at..self.at + length]).to_string();
        self.at += length;
        text
    }

    fn take_optional(&mut self) -> Option<String> {
        let marker = self.take_u8();
        if self.status != 0 {
            return None;
        }
        match marker {
            0 => None,
            1 => Some(self.take_text()),
            _ => {
                self.status = 23;
                None
            }
        }
    }

    fn take_optional_number(&mut self) -> Option<u64> {
        let marker = self.take_u8();
        if self.status != 0 {
            return None;
        }
        match marker {
            0 => None,
            1 => Some(self.take_u64()),
            _ => {
                self.status = 23;
                None
            }
        }
    }
}

// One event from a complete frame body, `None` when the body does not decode.
fn decode_body(tag: u8, body: &[u8]) -> Option<Event> {
    let mut reader = Reader {
        bytes: body,
        at: 0,
        status: 0,
    };
    let _id = reader.take_text();
    let session_id = reader.take_text();
    let sequence = reader.take_u64();
    let _created_at = reader.take_text();
    let kind = match tag {
        TAG_STARTED => Kind::Started,
        TAG_TITLED => Kind::Titled {
            title: reader.take_text(),
            generated: reader.take_u8() == 1,
            tokens: reader.take_optional_number(),
            model: reader.take_optional(),
        },
        TAG_STATUS => Kind::Status {
            status: reader.take_text(),
            detail: reader.take_optional(),
        },
        TAG_MESSAGE => Kind::Message {
            actor: reader.take_text(),
            text: reader.take_text(),
            status: reader.take_text(),
        },
        TAG_DELTA => Kind::Delta,
        TAG_GOAL_CREATED => Kind::GoalCreated {
            goal_id: reader.take_text(),
            objective: reader.take_text(),
            budget: reader.take_optional_number(),
        },
        TAG_GOAL_UPDATED => Kind::GoalUpdated {
            goal_id: reader.take_text(),
            status: reader.take_text(),
        },
        TAG_PLAN => {
            let participant = reader.take_text();
            let revision = reader.take_u64();
            let count = reader.take_count();
            let mut items = Vec::new();
            for _ in 0..count {
                let id = reader.take_text();
                let content = reader.take_text();
                let status = reader.take_text();
                let work = reader.take_optional();
                items.push(PlanItem {
                    id,
                    content,
                    status,
                    work,
                });
            }
            Kind::Plan {
                participant,
                revision,
                items,
            }
        }
        TAG_WORK => {
            let revision = reader.take_u64();
            let count = reader.take_count();
            let mut items = Vec::new();
            for _ in 0..count {
                let id = reader.take_text();
                let title = reader.take_text();
                let assignee = reader.take_optional();
                let status = reader.take_text();
                items.push(WorkItem {
                    id,
                    title,
                    assignee,
                    status,
                });
            }
            Kind::Work { revision, items }
        }
        _ => return None,
    };
    if reader.status != 0 || reader.at != body.len() {
        return None;
    }
    Some(Event {
        session_id,
        sequence,
        kind,
    })
}

// The reader's answer for a whole stream: the events, or the status it refused with.
fn decode_stream(bytes: &[u8]) -> Result<Vec<Event>, u64> {
    let mut events = Vec::new();
    let mut at = 0usize;
    while at < bytes.len() {
        if bytes.len() - at < 5 {
            return Err(21);
        }
        let tag = bytes[at];
        let length = u32::from_le_bytes([bytes[at + 1], bytes[at + 2], bytes[at + 3], bytes[at + 4]])
            as usize;
        at += 5;
        if tag == 0 || tag > TAG_WORK {
            return Err(20);
        }
        if length > 262144 {
            return Err(22);
        }
        if length > bytes.len() - at {
            return Err(21);
        }
        match decode_body(tag, &bytes[at..at + length]) {
            None => return Err(21),
            Some(event) => events.push(event),
        }
        at += length;
    }
    Ok(events)
}

fn properties(name: &str, events: &[Event]) {
    // Replayed twice: the same journal must reconstruct the same aggregates.
    let first = outcome(events);
    let second = outcome(events);
    println!(
        "twice {} {}",
        name,
        if first == second { "ok" } else { "fail" }
    );
    // Prefix + last event, against a direct apply of the last event.
    let mut verdict = "ok";
    if let Some((last, prefix)) = events.split_last() {
        let whole = outcome(events);
        let reached = match replay(prefix) {
            Ok(state) => match apply(&state, last, prefix.len() as u64) {
                Ok(next) => checksum(&next.aggregates),
                Err(refusal) => refusal_text(&refusal, Some(prefix.len() as u64)),
            },
            Err((refusal, at)) => refusal_text(&refusal, at),
        };
        if whole != reached {
            verdict = "fail";
        }
    }
    println!("append {} {}", name, verdict);
}

// ---------------------------------------------------------------- the command line
//
// The aggregate fields of the state frame, in the order `borg/src/frames.grl` writes them.

struct Snapshot {
    goal: bool,
    goal_id: String,
    objective: String,
    budget: Option<u64>,
    goal_status: String,
    participant: String,
    plan_revision: u64,
    plan: Vec<PlanItem>,
    work_revision: u64,
    work: Vec<WorkItem>,
}

fn snapshot_of(state: &State) -> Snapshot {
    Snapshot {
        goal: state.aggregates.goal.is_some(),
        goal_id: state
            .aggregates
            .goal
            .as_ref()
            .map(|goal| goal.id.clone())
            .unwrap_or_default(),
        objective: state
            .aggregates
            .goal
            .as_ref()
            .map(|goal| goal.objective.clone())
            .unwrap_or_default(),
        budget: state.aggregates.goal.as_ref().and_then(|goal| goal.budget),
        goal_status: state
            .aggregates
            .goal
            .as_ref()
            .map(|goal| goal.status.clone())
            .unwrap_or_else(|| "-".to_string()),
        // The frame carries `-` for an absent participant, the same rendering every other absent
        // aggregate field uses.
        participant: state
            .aggregates
            .participant
            .clone()
            .unwrap_or_else(|| "-".to_string()),
        plan_revision: state.aggregates.revision,
        plan: state.aggregates.plan.clone(),
        work_revision: state.aggregates.work_revision,
        work: state.aggregates.work.clone(),
    }
}

// `refusal` is the reason, the index the fold stopped at and its detail - what the port puts on the
// wire, because a named refusal without them says the fold refused but not where.
fn reply_frame(
    sequence: u64,
    status: &str,
    events: u64,
    refusal: Option<(&str, String, String)>,
) -> Vec<u8> {
    let mut body = Vec::new();
    body.push(4);
    push_u64(&mut body, sequence);
    push_text(&mut body, status);
    push_u64(&mut body, events);
    match refusal {
        None => body.push(0),
        Some((reason, at, detail)) => {
            body.push(1);
            push_u64(&mut body, 17);
            push_text(&mut body, &at);
            push_text(&mut body, reason);
            push_text(&mut body, &detail);
        }
    }
    let mut out = Vec::new();
    out.push(0);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

fn state_frame(snapshot: &Snapshot) -> Vec<u8> {
    let mut body = Vec::new();
    body.push(6);
    body.push(if snapshot.goal { 1 } else { 0 });
    push_text(&mut body, &snapshot.goal_id);
    push_text(&mut body, &snapshot.objective);
    match snapshot.budget {
        Some(budget) => {
            body.push(1);
            push_u64(&mut body, budget);
        }
        None => body.push(0),
    }
    push_text(&mut body, &snapshot.goal_status);
    push_text(&mut body, &snapshot.participant);
    push_u64(&mut body, snapshot.plan_revision);
    body.extend_from_slice(&(snapshot.plan.len() as u32).to_le_bytes());
    for item in &snapshot.plan {
        push_text(&mut body, &item.id);
        push_text(&mut body, &item.content);
        push_text(&mut body, &item.status);
        push_optional_text(&mut body, &item.work);
    }
    push_u64(&mut body, snapshot.work_revision);
    body.extend_from_slice(&(snapshot.work.len() as u32).to_le_bytes());
    for item in &snapshot.work {
        push_text(&mut body, &item.id);
        push_text(&mut body, &item.title);
        push_optional_text(&mut body, &item.assignee);
        push_text(&mut body, &item.status);
    }
    let mut out = Vec::new();
    out.push(0);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

fn hello_frame(version: u64, session: &str) -> Vec<u8> {
    let mut body = Vec::new();
    body.push(1);
    body.extend_from_slice(&(version as u32).to_le_bytes());
    push_text(&mut body, session);
    let mut out = Vec::new();
    out.push(0);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

fn hello_ok_frame(version: u64, session: &str) -> Vec<u8> {
    let mut body = Vec::new();
    body.push(2);
    body.extend_from_slice(&(version as u32).to_le_bytes());
    push_text(&mut body, session);
    let mut out = Vec::new();
    out.push(0);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

fn end_frame() -> Vec<u8> {
    let mut body = Vec::new();
    body.push(5);
    let mut out = Vec::new();
    out.push(0);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

// One prepared command: the events it means to send, or the line it refuses with.
struct Prepared {
    command: String,
    session: String,
    events: Vec<Event>,
    work_only: bool,
    refusal: Option<(String, bool)>,
}

fn arg(args: &[String], flag: &str) -> String {
    let mut index = 2;
    while index + 1 < args.len() {
        if args[index] == flag {
            return args[index + 1].clone();
        }
        index += 1;
    }
    String::new()
}

fn repeated(args: &[String], flag: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut index = 2;
    while index + 1 < args.len() {
        if args[index] == flag {
            out.push(args[index + 1].clone());
        }
        index += 1;
    }
    out
}

fn placeholder(session: &str, kind: Kind) -> Event {
    Event {
        session_id: session.to_string(),
        sequence: 0,
        kind,
    }
}

fn prepare(args: &[String]) -> Prepared {
    let command = args.get(1).cloned().unwrap_or_default();
    let session = arg(args, "--session");
    let mut prepared = Prepared {
        command: command.clone(),
        session: session.clone(),
        events: Vec::new(),
        work_only: false,
        refusal: None,
    };
    if session.is_empty() {
        prepared.refusal = Some((format!("{} refused bad-argument at - detail --session is required", command), true));
        return prepared;
    }
    match command.as_str() {
        "create-goal" => {
            let goal = arg(args, "--goal");
            let objective = arg(args, "--objective");
            if goal.is_empty() || objective.is_empty() {
                let said = if goal.is_empty() {
                    "--goal is required"
                } else {
                    "--objective is required"
                };
                prepared.refusal = Some((format!("{} refused bad-argument at - detail {}", command, said), true));
                return prepared;
            }
            let budget = arg(args, "--budget").parse::<u64>().ok();
            prepared.events.push(placeholder(
                &session,
                Kind::GoalCreated {
                    goal_id: goal,
                    objective,
                    budget,
                },
            ));
        }
        "update-goal" => {
            let goal = arg(args, "--goal");
            let status = arg(args, "--status");
            if goal.is_empty() || status.is_empty() {
                let said = if goal.is_empty() {
                    "--goal is required"
                } else {
                    "--status is required"
                };
                prepared.refusal = Some((format!("{} refused bad-argument at - detail {}", command, said), true));
                return prepared;
            }
            match goal_status(&status) {
                Err(class) => {
                    prepared.refusal =
                        Some((format!("{} refused {} at - detail {}", command, class, status), false));
                    return prepared;
                }
                Ok(status) => prepared.events.push(placeholder(
                    &session,
                    Kind::GoalUpdated {
                        goal_id: goal,
                        status,
                    },
                )),
            }
        }
        "set-plan" => {
            let participant = arg(args, "--participant");
            let revision = arg(args, "--revision").parse::<u64>();
            if participant.is_empty() || revision.is_err() {
                let said = if participant.is_empty() {
                    "--participant is required"
                } else {
                    "--revision is required"
                };
                prepared.refusal = Some((format!("{} refused bad-argument at - detail {}", command, said), true));
                return prepared;
            }
            let revision = revision.expect("parsed");
            let mut work = Vec::new();
            for spec in repeated(args, "--work") {
                let parts: Vec<&str> = spec.split('|').collect();
                if parts.len() < 4 {
                    prepared.refusal =
                        Some((format!("set-plan refused missing at - detail {}", spec), false));
                    return prepared;
                }
                match item_status(parts[3]) {
                    Err(class) => {
                        prepared.refusal =
                            Some((format!("set-plan refused {} at - detail {}", class, spec), false));
                        return prepared;
                    }
                    Ok(status) => work.push(WorkItem {
                        id: parts[0].to_string(),
                        title: parts[1].to_string(),
                        assignee: if parts[2].is_empty() {
                            None
                        } else {
                            Some(parts[2].to_string())
                        },
                        status,
                    }),
                }
            }
            let mut items = Vec::new();
            for spec in repeated(args, "--item") {
                let parts: Vec<&str> = spec.split('|').collect();
                if parts.len() < 4 {
                    prepared.refusal =
                        Some((format!("set-plan refused missing at - detail {}", spec), false));
                    return prepared;
                }
                match item_status(parts[1]) {
                    Err(class) => {
                        prepared.refusal =
                            Some((format!("set-plan refused {} at - detail {}", class, spec), false));
                        return prepared;
                    }
                    Ok(status) => items.push(PlanItem {
                        id: parts[0].to_string(),
                        content: parts[2].to_string(),
                        status,
                        work: if parts[3].is_empty() {
                            None
                        } else {
                            Some(parts[3].to_string())
                        },
                    }),
                }
            }
            if !work.is_empty() {
                prepared
                    .events
                    .push(placeholder(&session, Kind::Work { revision, items: work }));
            }
            prepared.events.push(placeholder(
                &session,
                Kind::Plan {
                    participant,
                    revision,
                    items,
                },
            ));
        }
        "list-work" => prepared.work_only = true,
        "attach" => {}
        _ => {
            prepared.refusal = Some((
                format!("{} refused bad-argument at - detail no such command", command),
                true,
            ));
        }
    }
    prepared
}

// The daemon half: read one conversation, stamp the events onto the session, answer with the reply
// and the state. The stamping is what a stateful daemon does; the sequence it assigns is the cursor.
fn serve(stream: &mut TcpStream, held: &State) -> State {
    let mut buffer = Vec::new();
    let mut chunk = [0u8; 65536];
    let mut hello_seen = false;
    let mut folded: Option<State> = None;
    let mut reply: Option<Vec<u8>> = None;
    loop {
        let read = stream.read(&mut chunk).expect("a read");
        if read == 0 {
            break;
        }
        buffer.extend_from_slice(&chunk[..read]);
        // Decode every complete frame that has arrived.
        let mut at = 0usize;
        let mut consumed = 0usize;
        while at + 5 <= buffer.len() {
            let tag = buffer[at];
            let length =
                u32::from_le_bytes([buffer[at + 1], buffer[at + 2], buffer[at + 3], buffer[at + 4]])
                    as usize;
            if at + 5 + length > buffer.len() {
                break;
            }
            let body = &buffer[at + 5..at + 5 + length];
            if tag == 0 {
                let opcode = body[0];
                match opcode {
                    1 => {
                        let session = {
                            let mut reader = Reader {
                                bytes: &body[1 + 4..],
                                at: 0,
                                status: 0,
                            };
                            reader.take_text()
                        };
                        let mut answer = hello_ok_frame(1, &session);
                        stream.write_all(&answer).expect("hello");
                        answer.clear();
                        hello_seen = true;
                    }
                    5 => {
                        let state = held_state(&folded, held);
                        stream
                            .write_all(&reply_frame(
                                state.session.sequence,
                                &state
                                    .session
                                    .status
                                    .clone()
                                    .unwrap_or_else(|| "-".to_string()),
                                state.session.events,
                                None,
                            ))
                            .expect("reply");
                        let snapshot = snapshot_of(&state);
                        stream.write_all(&state_frame(&snapshot)).expect("state");
                        reply = Some(Vec::new());
                        consumed = at + 5 + length;
                        break;
                    }
                    _ => {}
                }
            } else if hello_seen {
                match decode_body(tag, body) {
                    None => {}
                    Some(event) => {
                        let current = held_state(&folded, held);
                        let index = current.session.events - held.session.events;
                        let sequence = current.session.sequence + 1;
                        let stamped = Event {
                            session_id: event.session_id.clone(),
                            sequence,
                            kind: event.kind,
                        };
                        match apply(&current, &stamped, index) {
                            Ok(next) => folded = Some(next),
                            Err(refusal) => {
                                stream
                                    .write_all(&reply_frame(
                                        0,
                                        "-",
                                        0,
                                        Some((&refusal.reason(), index.to_string(), refusal.detail())),
                                    ))
                                    .expect("refusal");
                                let state = current;
                                let snapshot = snapshot_of(&state);
                                stream.write_all(&state_frame(&snapshot)).expect("state");
                                consumed = at + 5 + length;
                                break;
                            }
                        }
                    }
                }
            }
            consumed = at + 5 + length;
            at += 5 + length;
        }
        buffer.drain(..consumed);
        if reply.is_some() {
            break;
        }
    }
    held_state(&folded, held)
}

fn held_state(folded: &Option<State>, held: &State) -> State {
    match folded {
        Some(state) => clone_state(state),
        None => clone_state(held),
    }
}

fn clone_state(state: &State) -> State {
    State {
        session: Session {
            session: state.session.session.clone(),
            sequence: state.session.sequence,
            events: state.session.events,
            status: state.session.status.clone(),
            detail: state.session.detail.clone(),
            title: state.session.title.clone(),
            generated: state.session.generated,
            model: state.session.model.clone(),
        },
        aggregates: clone_aggregates(&state.aggregates),
    }
}

// The client half: write hello, the events and the end marker, then decode the reply and the state.
fn exchange(listener: &TcpListener, session: &str, events: &[Event]) -> (String, Snapshot) {
    let port = listener.local_addr().expect("a bound port").port();
    let mut client = TcpStream::connect(("127.0.0.1", port)).expect("a client");
    let mut outbound = hello_frame(1, session);
    for event in events {
        outbound.extend_from_slice(&encode_event(event));
    }
    outbound.extend_from_slice(&end_frame());
    client.write_all(&outbound).expect("a request");
    let mut buffer = Vec::new();
    let mut chunk = [0u8; 65536];
    loop {
        let read = client.read(&mut chunk).expect("a read");
        if read == 0 {
            break;
        }
        buffer.extend_from_slice(&chunk[..read]);
        if settled(&buffer) {
            break;
        }
    }
    decode_answer(&buffer)
}

// Both frames present: the reply (opcode 4) and the state (opcode 6).
fn settled(bytes: &[u8]) -> bool {
    let mut at = 0usize;
    let mut seen_reply = false;
    let mut seen_state = false;
    while at + 5 <= bytes.len() {
        let tag = bytes[at];
        let length = u32::from_le_bytes([bytes[at + 1], bytes[at + 2], bytes[at + 3], bytes[at + 4]])
            as usize;
        if at + 5 + length > bytes.len() {
            break;
        }
        if tag == 0 && length > 0 {
            match bytes[at + 5] {
                4 => seen_reply = true,
                6 => seen_state = true,
                _ => {}
            }
        }
        at += 5 + length;
    }
    seen_reply && seen_state
}

fn decode_answer(bytes: &[u8]) -> (String, Snapshot) {
    let mut at = 0usize;
    let mut line = String::new();
    let mut snapshot = Snapshot {
        goal: false,
        goal_id: String::new(),
        objective: String::new(),
        budget: None,
        goal_status: String::new(),
        participant: String::new(),
        plan_revision: 0,
        plan: Vec::new(),
        work_revision: 0,
        work: Vec::new(),
    };
    while at + 5 <= bytes.len() {
        let tag = bytes[at];
        let length = u32::from_le_bytes([bytes[at + 1], bytes[at + 2], bytes[at + 3], bytes[at + 4]])
            as usize;
        if at + 5 + length > bytes.len() {
            break;
        }
        let body = &bytes[at + 5..at + 5 + length];
        if tag == 0 && !body.is_empty() {
            let opcode = body[0];
            let mut reader = Reader {
                bytes: &body[1..],
                at: 0,
                status: 0,
            };
            if opcode == 4 {
                let sequence = reader.take_u64();
                let status = reader.take_text();
                let events = reader.take_u64();
                let marker = reader.take_u8();
                if marker == 1 {
                    let _code = reader.take_u64();
                    let where_ = reader.take_text();
                    let reason = reader.take_text();
                    let detail = reader.take_text();
                    line = format!(
                        "refused {} at {} detail {}",
                        reason,
                        where_,
                        readable(&detail)
                    );
                } else {
                    line = format!("ok sequence {} status {} events {}", sequence, status, events);
                }
            } else if opcode == 6 {
                let present = reader.take_u8() == 1;
                let goal_id = reader.take_text();
                let objective = reader.take_text();
                let budget = reader.take_optional_number();
                let goal_status = reader.take_text();
                let participant = reader.take_text();
                let plan_revision = reader.take_u64();
                let count = reader.take_count();
                let mut plan = Vec::new();
                for _ in 0..count {
                    let id = reader.take_text();
                    let content = reader.take_text();
                    let status = reader.take_text();
                    let work = reader.take_optional();
                    plan.push(PlanItem {
                        id,
                        content,
                        status,
                        work,
                    });
                }
                let work_revision = reader.take_u64();
                let work_count = reader.take_count();
                let mut work = Vec::new();
                for _ in 0..work_count {
                    let id = reader.take_text();
                    let title = reader.take_text();
                    let assignee = reader.take_optional();
                    let status = reader.take_text();
                    work.push(WorkItem {
                        id,
                        title,
                        assignee,
                        status,
                    });
                }
                snapshot = Snapshot {
                    goal: present,
                    goal_id,
                    objective,
                    budget,
                    goal_status,
                    participant,
                    plan_revision,
                    plan,
                    work_revision,
                    work,
                };
            }
        }
        at += 5 + length;
    }
    (line, snapshot)
}

fn print_answer(command: &str, line: &str, snapshot: &Snapshot, work_only: bool) {
    println!("{} {}", command, line);
    if !work_only {
        if snapshot.goal {
            println!(
                "goal {} {} budget {} {}",
                snapshot.goal_id,
                snapshot.goal_status,
                snapshot
                    .budget
                    .map(|budget| budget.to_string())
                    .unwrap_or_else(|| "-".to_string()),
                snapshot.objective
            );
        } else {
            println!("goal - - budget -");
        }
        println!(
            "plan {} revision {}",
            snapshot.participant, snapshot.plan_revision
        );
        for item in &snapshot.plan {
            println!(
                "  item {} {} work {} {}",
                item.id,
                item.status,
                item.work.clone().unwrap_or_else(|| "-".to_string()),
                item.content
            );
        }
    }
    println!("work revision {}", snapshot.work_revision);
    for item in &snapshot.work {
        println!(
            "  work {} {} {} {}",
            item.id,
            item.assignee.clone().unwrap_or_else(|| "-".to_string()),
            item.status,
            item.title
        );
    }
}

fn cli_session() {
    let listener = TcpListener::bind(("127.0.0.1", 0)).expect("a loopback listener");
    let mut bus = State::default();
    let commands: Vec<Vec<&str>> = vec![
        vec!["borg", "create-goal", "--session", "s1", "--goal", "g1", "--objective", "fix-the-build", "--budget", "1000"],
        vec!["borg", "update-goal", "--session", "s1", "--goal", "g1", "--status", "complete"],
        vec!["borg", "update-goal", "--session", "s1", "--goal", "g1", "--status", "complete"],
        vec!["borg", "update-goal", "--session", "s1", "--goal", "g1", "--status", "done"],
        vec!["borg", "set-plan", "--session", "s1", "--participant", "p1", "--revision", "2", "--work", "w1|write-the-fold|alice|in_progress", "--item", "i1|in_progress|write-the-fold|w1"],
        vec!["borg", "set-plan", "--session", "s1", "--participant", "p1", "--revision", "3", "--item", "i2|pending|review|w9"],
        vec!["borg", "set-plan", "--session", "s1", "--participant", "p1", "--revision", "3", "--item", "i2|done|review|"],
        vec!["borg", "list-work", "--session", "s1"],
        vec!["borg", "attach", "--session", "s1"],
        vec!["borg", "create-goal", "--session", "s2", "--goal", "g2", "--objective", "other"],
        vec!["borg", "attach"],
    ];
    for words in commands {
        let args: Vec<String> = words.iter().map(|word| word.to_string()).collect();
        println!("cli {}", args.join(" "));
        let prepared = prepare(&args);
        if let Some((line, _usage)) = &prepared.refusal {
            println!("{}", line);
            continue;
        }
        // The daemon runs on its own thread for this connection, exactly as a serving daemon would.
        let held = clone_state(&bus);
        let serving = {
            let listener = listener
                .try_clone()
                .expect("a shared listener");
            std::thread::spawn(move || {
                let (mut peer, _) = listener.accept().expect("a connection");
                let next = serve(&mut peer, &held);
                next
            })
        };
        let (line, snapshot) = exchange(&listener, &prepared.session, &prepared.events);
        bus = serving.join().expect("the daemon");
        print_answer(&prepared.command, &line, &snapshot, prepared.work_only);
    }
}

// ---------------------------------------------------------------- main

fn main() {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    for path in &arguments {
        let name = path.rsplit('/').next().unwrap_or(path).to_string();
        let text = std::fs::read_to_string(path).expect("a fixture");
        let scenario: Value = serde_json::from_str(&text).expect("a scenario");
        let shown = scenario
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or(&name)
            .to_string();
        let via = scenario
            .get("via")
            .and_then(Value::as_str)
            .unwrap_or("events")
            .to_string();
        let truncate = scenario
            .get("truncate")
            .and_then(Value::as_u64)
            .unwrap_or(0);
        let elements = match scenario.get("events").and_then(Value::as_array) {
            None => Vec::new(),
            Some(array) => array.clone(),
        };
        let mut events = Vec::new();
        let mut malformed = None;
        for (index, element) in elements.iter().enumerate() {
            match decode_event(element) {
                Ok(event) => events.push(event),
                Err(class) => {
                    malformed = Some(Malformed { class, index });
                    break;
                }
            }
        }
        if let Some(failure) = malformed {
            println!(
                "case {} malformed {} at {}",
                shown, failure.class, failure.index
            );
            continue;
        }
        if via == "stream" {
            let bytes = encode_stream(&events);
            let kept = if (truncate as usize) < bytes.len() {
                bytes.len() - truncate as usize
            } else {
                bytes.len()
            };
            let cut = &bytes[..kept];
            match decode_stream(cut) {
                Ok(handed) => match replay(&handed) {
                    Ok(state) => show_state(&shown, &state),
                    Err((refusal, at)) => show_refusal(&shown, &refusal, at),
                },
                Err(code) => show_refusal(&shown, &Refusal::Stream(code), None),
            }
            let handed = decode_stream(cut).unwrap_or_default();
            properties(&shown, &handed);
            continue;
        }
        match replay(&events) {
            Ok(state) => show_state(&shown, &state),
            Err((refusal, at)) => show_refusal(&shown, &refusal, at),
        }
        // The same journal through the byte stream.
        let bytes = encode_stream(&events);
        let mut verdict = match decode_stream(&bytes) {
            Err(code) => refusal_text(&Refusal::Stream(code), None),
            Ok(handed) => match replay(&handed) {
                Ok(state) if checksum(&state.aggregates) == outcome(&events) => "ok".to_string(),
                Ok(_) => "differs".to_string(),
                Err((refusal, at)) => refusal_text(&refusal, at),
            },
        };
        if verdict.is_empty() {
            verdict = "ok".to_string();
        }
        println!("capture {} {}", shown, verdict);
        properties(&shown, &events);
    }
    cli_session();
}
