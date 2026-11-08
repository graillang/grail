//! Reference for `borg/tests/jsonrpc_test.grl`.
//!
//! The envelope is built with `agent-client-protocol-schema` 1.5.0 — the crate Borg's ACP support
//! uses — and printed in canonical (sorted-key) form, so `"params": null`, `"result": null` and a
//! string id are the crate's decisions, not this file's. The framing and dispatch rules are copied
//! verbatim from Borg with citations, and `--anchors` re-checks those snippets upstream:
//!
//!   lsp.rs::write_message          `Content-Length: {}\r\n\r\n` header (lsp.rs:1487)
//!   lsp.rs::read_message           bounded header scan, `\r\n\r\n` or `\n\n` (lsp.rs:1513-1551)
//!   lsp.rs::request_with_timeout   ids from 1, one in flight, server requests answered with null,
//!                                  unrelated ids ignored (lsp.rs:1355-1395)
//!   lsp.rs::cancel_pending_request `$/cancelRequest` for the superseded id (lsp.rs:1398-1408)

use serde_json::{json, Value};

use agent_client_protocol_schema::rpc::{
    JsonRpcMessage, Notification, Request, RequestId, Response,
};

const MAX_MESSAGE_BYTES: u64 = 8 * 1024 * 1024;
const MAX_HEADER_BYTES: usize = 8192;

/// The crate's own serialisation, compared byte for byte: field order included. The port emits
/// `jsonrpc`, then the message fields, in the same order `JsonRpcMessage` does.
fn canonical(value: &Value) -> String {
    serde_json::to_string(value).expect("value serialises")
}

fn request_id(spec: &Value) -> RequestId {
    let Some(id) = spec.get("id") else { return RequestId::Null };
    match id.get("t").and_then(Value::as_str) {
        Some("null") => RequestId::Null,
        Some("str") => RequestId::Str(id.get("v").and_then(Value::as_str).unwrap_or("").to_string()),
        _ => RequestId::Number(id.get("v").and_then(Value::as_i64).unwrap_or(0)),
    }
}

/// Builds the envelope with the ACP types and returns it canonicalised.
fn build(spec: &Value) -> Option<String> {
    let kind = spec.get("kind").and_then(Value::as_str).unwrap_or("request");
    let id = request_id(spec);
    let params = spec.get("params").cloned().unwrap_or(Value::Null);
    let message = match kind {
        "notification" => {
            let method = spec.get("method").and_then(Value::as_str).unwrap_or("").to_string();
            let note = JsonRpcMessage::wrap(Notification { method: method.into(), params: Some(params) });
            serde_json::to_value(&note).ok()?
        }
        "result" => {
            let result = spec.get("result").cloned().unwrap_or(Value::Null);
            let response = JsonRpcMessage::wrap(Response::<Value, Value>::Result { id, result });
            serde_json::to_value(&response).ok()?
        }
        "error" => {
            let code = spec.get("code").and_then(Value::as_i64).unwrap_or(0);
            let message = spec.get("message").and_then(Value::as_str).unwrap_or("");
            let error = json!({ "code": code, "message": message });
            let response = JsonRpcMessage::wrap(Response::<Value, Value>::Error { id, error });
            serde_json::to_value(&response).ok()?
        }
        _ => {
            let method = spec.get("method").and_then(Value::as_str).unwrap_or("").to_string();
            let request = JsonRpcMessage::wrap(Request { id, method: method.into(), params: Some(params) });
            serde_json::to_value(&request).ok()?
        }
    };
    Some(canonical(&message))
}

fn kind_of(wire: &Value) -> &'static str {
    if wire.get("method").is_some() && wire.get("id").is_some() {
        "request"
    } else if wire.get("method").is_some() {
        "notification"
    } else if wire.get("result").is_some() {
        "result"
    } else {
        "error"
    }
}

fn id_text(wire: &Value) -> String {
    match wire.get("id") {
        None => "-".to_string(),
        Some(Value::Null) => "null".to_string(),
        Some(Value::Number(number)) => number.to_string(),
        Some(Value::String(text)) => text.clone(),
        Some(_) => "?".to_string(),
    }
}

/// Classifies a document by the envelope rule; the ACP crate requires `"jsonrpc": "2.0"`.
fn classify(text: &str) -> Result<(String, String, String, String), &'static str> {
    let Ok(value) = serde_json::from_str::<Value>(text) else { return Err("not-object") };
    if !value.is_object() {
        return Err("not-object");
    }
    match value.get("jsonrpc").and_then(Value::as_str) {
        Some("2.0") => {}
        _ => return Err("bad-version"),
    }
    let id = id_text(&value);
    if value.get("method").is_some() {
        let Some(method) = value.get("method").and_then(Value::as_str) else { return Err("bad-method") };
        let kind = if value.get("id").is_some() { "request" } else { "notification" };
        return Ok((kind.to_string(), id, method.to_string(), "-".to_string()));
    }
    if value.get("result").is_some() {
        return Ok(("result".to_string(), id, "-".to_string(), "-".to_string()));
    }
    if let Some(error) = value.get("error") {
        let Some(code) = error.get("code").and_then(Value::as_i64) else { return Err("bad-error") };
        if error.get("message").and_then(Value::as_str).is_none() {
            return Err("bad-error");
        }
        return Ok(("error".to_string(), id, "-".to_string(), code.to_string()));
    }
    Err("no-kind")
}

/// Copied from `lsp.rs::read_message` (1513-1551): the terminator is the first `\r\n\r\n` or `\n\n`
/// inside the bounded prefix, `Content-Length` is a line prefix, and the body is capped.
fn take_frame(buffer: &[u8]) -> (&'static str, u64, Option<Value>) {
    let limit = buffer.len().min(MAX_HEADER_BYTES);
    let prefix = &buffer[..limit];
    let end = prefix
        .windows(4)
        .position(|bytes| bytes == b"\r\n\r\n")
        .map(|at| at + 4)
        .into_iter()
        .chain(prefix.windows(2).position(|bytes| bytes == b"\n\n").map(|at| at + 2))
        .min();
    let Some(header_end) = end else {
        if buffer.len() >= MAX_HEADER_BYTES {
            return ("bad-header", 0, None);
        }
        return ("need-more", 0, None);
    };
    let header = String::from_utf8_lossy(&buffer[..header_end]).to_string();
    let Some(length) = header
        .lines()
        .find_map(|line| line.strip_prefix("Content-Length:").and_then(|value| value.trim().parse::<u64>().ok()))
    else {
        return ("bad-header", 0, None);
    };
    if length > MAX_MESSAGE_BYTES {
        return ("too-large", 0, None);
    }
    if (buffer.len() as u64) < header_end as u64 + length {
        return ("need-more", 0, None);
    }
    let body = &buffer[header_end..header_end + length as usize];
    match serde_json::from_slice::<Value>(body) {
        Ok(value) => ("complete", header_end as u64 + length, Some(value)),
        Err(_) => ("bad-json", 0, None),
    }
}

/// Copied from `lsp.rs::request_with_timeout` (1355-1395) and `cancel_pending_request` (1398-1408).
struct Dispatcher {
    next_id: u64,
    pending: Option<u64>,
}

impl Dispatcher {
    fn new() -> Self {
        Self { next_id: 1, pending: None }
    }

    fn begin(&mut self) -> (u64, Option<u64>) {
        let cancelled = self.pending.take();
        let id = self.next_id;
        self.next_id += 1;
        self.pending = Some(id);
        (id, cancelled)
    }

    fn incoming(&mut self, message: &Value) -> &'static str {
        let has_method = message.get("method").is_some();
        if has_method && message.get("id").is_some() {
            return "server-request";
        }
        let Some(id) = message.get("id").and_then(Value::as_u64) else { return "ignored" };
        if Some(id) != self.pending {
            return "ignored";
        }
        self.pending = None;
        if message.get("error").is_some() { "failed" } else { "resolved" }
    }
}

fn line(label: &str, what: &str, one: &str, two: &str) {
    if two.is_empty() {
        println!("{label} {what} {one}");
    } else {
        println!("{label} {what} {one} {two}");
    }
}

fn main() {
    for path in std::env::args().skip(1) {
        let Ok(text) = std::fs::read_to_string(&path) else { continue };
        let Ok(scenario) = serde_json::from_str::<Value>(&text) else { continue };
        let name = scenario.get("name").and_then(Value::as_str).unwrap_or("unnamed").to_string();

        if let Some(spec) = scenario.get("frame") {
            let Some(wire_text) = build(spec) else { continue };
            let wire: Value = serde_json::from_str(&wire_text).expect("canonical json");
            line(&name, "wire", &wire_text, "");
            line(&name, "kind", kind_of(&wire), &id_text(&wire));
            let method = wire.get("method").and_then(Value::as_str).unwrap_or("-");
            let code = wire
                .get("error")
                .and_then(|error| error.get("code"))
                .and_then(Value::as_i64)
                .map(|code| code.to_string())
                .unwrap_or_else(|| "-".to_string());
            line(&name, "method", method, &code);
            // Read the crate's own output back into its types.
            let roundtrip = match kind_of(&wire) {
                "request" => serde_json::from_value::<JsonRpcMessage<Request<Value>>>(wire.clone()).is_ok(),
                "notification" => serde_json::from_value::<JsonRpcMessage<Notification<Value>>>(wire.clone()).is_ok(),
                _ => serde_json::from_value::<JsonRpcMessage<Response<Value, Value>>>(wire.clone()).is_ok(),
            };
            line(&name, "roundtrip", if roundtrip { "ok" } else { "fail" }, "");
            line(&name, "line", &(wire_text.len() + 1).to_string(), "");
            // The framed message as it goes on the wire, so the length is the real one.
            let framed = format!("Content-Length: {}\r\n\r\n{wire_text}", wire_text.len());
            line(&name, "header", &framed.len().to_string(), "");
        }

        if let Some(text) = scenario.get("text").and_then(Value::as_str) {
            match classify(text) {
                Ok((kind, id, method, code)) => {
                    line(&name, "frame", &kind, &id);
                    line(&name, "method", &method, &code);
                }
                Err(reason) => line(&name, "error", reason, ""),
            }
        }

        if let Some(buffer) = scenario.get("buffer").and_then(Value::as_str) {
            let (status, consumed, frame) = take_frame(buffer.as_bytes());
            line(&name, "status", status, &consumed.to_string());
            // Framing is about bytes: a body that is valid JSON is a completed frame, and how it
            // would classify is a separate question.
            if let Some(frame) = frame {
                line(&name, "frame", kind_of(&frame), "");
            }
        }

        if let Some(ops) = scenario.get("ops").and_then(Value::as_array) {
            let mut dispatcher = Dispatcher::new();
            for op in ops {
                let kind = op.get("op").and_then(Value::as_str).unwrap_or("");
                match kind {
                    "begin" => {
                        let (id, cancelled) = dispatcher.begin();
                        let cancelled = cancelled
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "-".to_string());
                        line(&name, "begin", &id.to_string(), &cancelled);
                    }
                    "response" => {
                        let id = op.get("id").and_then(Value::as_u64).unwrap_or(0);
                        let answer = json!({ "jsonrpc": "2.0", "id": id, "result": null });
                        line(&name, "response", dispatcher.incoming(&answer), "");
                    }
                    "server-request" => {
                        let id = op.get("id").and_then(Value::as_u64).unwrap_or(0);
                        let ask = json!({ "jsonrpc": "2.0", "id": id, "method": "window/workDoneProgress/create" });
                        line(&name, "incoming", dispatcher.incoming(&ask), "");
                    }
                    _ => {
                        let note = json!({ "jsonrpc": "2.0", "method": "textDocument/publishDiagnostics" });
                        line(&name, "incoming", dispatcher.incoming(&note), "");
                    }
                }
            }
        }
    }
}
