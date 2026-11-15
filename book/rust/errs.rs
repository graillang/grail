use std::fs;
use std::io;

// Rust's standard library has no context chain: an error is a value implementing std::error::Error,
// whose `source` hands back another boxed error. Grail's errs::Report is one owned chain of frames
// over a root message, so this control spells the same thing with its own type and both programs
// print the same text. The note under the example says what std does and does not provide.
struct Report {
    message: String,
    frames: Vec<String>,
    origin: Option<io::Error>,
}

impl Report {
    fn new(message: &str) -> Report {
        Report {
            message: message.to_string(),
            frames: Vec::new(),
            origin: None,
        }
    }
    fn context(mut self, text: &str) -> Report {
        self.frames.push(text.to_string());
        self
    }
    fn depth(&self) -> usize {
        self.frames.len()
    }
    fn show(&self) -> String {
        let mut out = String::new();
        for frame in self.frames.iter().rev() {
            out.push_str(frame);
            out.push_str(": ");
        }
        out.push_str(&self.message);
        out
    }
    fn report(&self) {
        eprintln!("{}", self.show());
    }
}

fn read_config(path: &str) -> Result<Vec<u8>, Report> {
    match fs::read(path) {
        Ok(data) => Ok(data),
        Err(error) => {
            // Grail's io::Error::show names the case (`not found`); Rust's io::Error prints the
            // operating system's own words, so the control maps the kind to the same text.
            let text = match error.kind() {
                io::ErrorKind::NotFound => "not found".to_string(),
                other => format!("{other:?}"),
            };
            let mut report = Report::new(&text);
            report.frames.push("while opening config".to_string());
            report.origin = Some(error);
            Err(report)
        }
    }
}

fn main() {
    Report::new("cannot open /etc/app.conf").report();

    let mut chain = Report::new("not found");
    chain = chain.context("while opening /x");
    chain = chain.context("while parsing config");
    chain = chain.context("while loading app");
    println!("{}", chain.depth());
    println!("{}", chain.show());

    match read_config("missing.conf") {
        Ok(data) => println!("{}", data.len()),
        Err(report) => {
            println!("{}", report.show());
            match report.origin.as_ref() {
                Some(error) => println!("{}", error.kind() == io::ErrorKind::NotFound),
                None => println!("false"),
            }
        }
    }
}
