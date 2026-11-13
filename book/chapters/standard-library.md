# The standard library

The library is a set of ordinary source files under `lib/`. A program names one with `use` and the
file goes on the build command line like any other module, so nothing is loaded implicitly:

```sh
grail build program.s main.grl lib/strings.grl lib/core.grl compiler/runtime.grl compiler/os-linux.grl
```

What a module exports is exactly what it marks `pub`; everything else belongs to that file. The
three modules below are the ones a first program usually reaches for.

## Strings

`strings` works on byte text: its functions take readonly `&[u8]` views, so a `string` is passed as
`view(text)`, and the ones that build text return an owned `u8[]` that `.text()` turns back into a
`string`. Searching answers with an index or with `None`, and parsing answers with `Some(value)` or
`None` rather than stopping the program.

```grl
use strings;

fn main() {
    text := "Grail by example".text();
    assert(strings::starts_with(view(text), view("Grail")));
    assert(strings::ends_with(view(text), view("example")));
    start := strings::find(view(text), view(" by "))!;    // Some(index); ! aborts on None
    replaced := strings::replace(view(text), view("example"), view("code"));
    println(replaced);
    println(strings::from_u64(start));
    println(strings::from_i64(-42));
    match strings::parse_u64(view("18446744073709551615")) {
        Some(value) => { println(value); },
        None => { println("not a number"); }
    }
}
```

`find` returns the byte index of the first occurrence, `contains` is its boolean form, and
`replace`, `split`, `trim`, `join_with`, `to_upper`, `to_lower`, `repeat` and `chars` cover the
everyday cases. `parse_u64` accepts decimal digits only and rejects empty input, a stray character
and overflow; `parse_i64` also accepts a leading `-` and checks the signed range. `from_u64` and
`from_i64` are their inverse. Building a line from parts needs no library call: `format("{} of {}",
done, total)` is a builtin and returns a `string`, which is what `println` uses.

## Time

`time::now()` reads the monotonic clock. Only differences of an `Instant` mean anything; the wall
clock is a separate call, for a stamp or a date. Both clocks read in milliseconds, so elapsed time
is exact to one millisecond, and `sleep_ms` suspends the calling task rather than a worker thread,
so other tasks keep running.

```grl
use time;

fn main() {
    started := time::now();
    time::sleep_ms(20);
    println(started.elapsed_ms() >= 15);
    println(time::unix_seconds() > 1600000000);
}
```

`elapsed_ns` reports the same difference in nanoseconds, `nanos_from_ms` and `millis_from_nanos`
convert a duration, and `unix_seconds` is seconds since the Unix epoch from the wall clock.

## Networking

`net` is TCP over the runtime's socket layer. `connect` opens a stream and `read`, `read_all`,
`write_all` and `close` use it; a listener is made with `bind` and hands out one stream per
`accept`. A refused or failed connection is an `io::Error`, so `?` propagates it and `show()` names
the usual cases. Addresses are IPv4 dotted quads: there is no name lookup.

Reads and writes wait by suspending the task, so a program can be a client and a server at once.
Port `0` asks the operating system for an unused port, which `port()` reports:

```grl
use net;
use io;

fn client(port: u64, unused: u64) -> u64 {
    mut stream = net::connect("127.0.0.1", port)!;
    stream.write_all(view("hello"));
    stream.close();
    return 1;
}

fn serve<s>(scope: (&s Scope<u64>), unused: u64) -> u64 {
    listener := net::bind("127.0.0.1", 0)!;
    peer := spawn(scope, listener.port(), client);
    mut stream = listener.accept()!;
    data := stream.read_all();
    stream.close();
    listener.close();
    assert(join(peer) == 1);
    println(data.text());
    return 0;
}

fn main() {
    assert(task_scope(2, serve) == 0);
}
```

Reading a connection the peer closed is not an error: `read` returns 0 bytes and `read_all` returns
what arrived. `read` fills a caller's buffer (`read(&mut stream, &mut buffer)`) and reports how many
bytes it read; `write_all` writes the whole view and returns false only if the connection failed
partway. A stream and a listener each own one descriptor, there is no destructor, so `close` is what
releases it - use it exactly once. The runtime's listener covers every local interface for its port
and a bind the operating system refuses stops the program; `bind` validates the address text and the
port instead.

## Files

`fs` answers a value or an `fs::Error`, and the error names the path it happened on: a program says
`cannot read tree/one.txt: not found` because the failure carries both halves. Nothing in the module
stops the program; `!` is still there when a caller decides a failure cannot be handled.

```grl
use fs;

fn main() {
    fs::create_dir_all(view("out/reports"))!;
    fs::write_atomic(view("out/reports/today.txt"), view("42 sales"))!;
    text := fs::read_text(view("out/reports/today.txt"))!;   // UTF-8 is checked
    md := fs::metadata(view("out/reports/today.txt"))!;
    println(text);
    println(md.size());
    println(md.modified.unix_seconds() > 0);
    for entry in fs::walk(view("out"), fs::walk_options())! {
        println(entry.path());
    }
    fs::remove_dir_all(view("out"))!;
}
```

`write_atomic` writes beside the destination and renames over it, so a reader sees the old file or
the new one and never a half-written one. `walk` is depth first with each directory's entries in byte
order; a symbolic link is an entry of its own and is not followed unless
`fs::follow_links(fs::walk_options(), true)` says so, and a directory that repeats one already on the
path is not entered, so a link back to its own directory cannot run away. `metadata` reports the type,
the size, the permission bits, the owner and the times as `time::Timestamp` values; `symlink_metadata`
reports the link itself instead of what it points at.

`Path` keeps a path as bytes and its operations are lexical - `normalize`, `parent`, `file_name`,
`extension`, `join` - so they answer without the file system, and `canonicalize` makes a path absolute
and normal without requiring anything to exist. Two writers' rules are stated where they matter:
`rename` replaces a destination file atomically and refuses a non-empty destination directory (the
operating system's rule), and `copy` creates or truncates its destination and copies a regular file
only. A `File` handle is closed exactly once - `close` consumes the descriptor's liveness, a second
close is `EBADF`, a short write is `ShortWrite` - because the language runs no destructor for it.

## Processes

A child is started from an argument vector, never from a shell, and how it ended is a value:

```grl
use process;

fn main() {
    mut argv = u8[][];
    argv.push("/bin/sh".copy());
    argv.push("-c".copy());
    argv.push("echo out; echo err 1>&2; exit 3".copy());
    captured := process::run(&argv)!;          // stdout and stderr, separately, capped
    println(captured.code());                  // 3
    println(captured.out());                   // out
    println(captured.err());                   // err
    mut victim = u8[][];
    victim.push("/bin/sh".copy());
    victim.push("-c".copy());
    victim.push("kill -9 $$".copy());
    killed := process::run(&victim)!;
    println(killed.show_status());             // killed by signal 9 (SIGKILL)
}
```

`Status` is `Exited(code)` or `Signaled(signal)`, so a signal is not reported as 128 plus its number
and cannot be confused with an exit code; `signal_name` spells the usual ones. `run` reads both pipes
a step at a time, so a child that fills one while writing nothing to the other still finishes, and it
keeps at most one mebibyte of each - `is_truncated` says when a stream was cut off, and a truncated
child sees its reader go away. `spawn`/`spawn_with` start a child without capturing and
`Child::wait` reaps it; the value is consumed, so a child cannot be waited for twice.

The environment a child starts with is a value too: `process::environment()` captures what this
process inherits, `set`/`remove`/`get` change the copy (case-insensitively on Windows, as that
platform's own environment is), and `run_in`/`spawn_with` hand it to the child. Changing the copy does
not change the running image's environment. A program that cannot be executed at all is the child's
own failure - it exits 127 - while `spawn` answers an error only when no child could be created.

## Time zones

`tz` reads the system's tzdata. A `TimeZone` is a value loaded from a TZif file, and every question
about it is answered from that file: `offset_at`, `abbreviation_at`, `is_dst_at` and `to_local` take
an instant, and `from_local` goes the other way.

```grl
use tz;
use time;

fn main() {
    zone := tz::available(view("Europe/Berlin"))!;      // ! aborts when the machine has no tzdata
    println(zone.offset_at(1767222000));                // 3600, CET
    println(zone.abbreviation_at(1780000000));          // CEST
    println(zone.to_local(1780000000).show());          // the wall clock there
    twice := tz::local(2026, 10, 25, 2, 30, 0);         // the hour that happens twice
    match zone.from_local(&twice) {
        Ambiguous(pair) => { println(pair.earlier()); println(pair.later()); },
        Unique(instant) => { println(instant); },
        Skipped(gap) => { println(gap.seconds()); }
    }
}
```

A wall-clock reading is not always one instant, and the module reports which case it is instead of
picking: `Unique`, `Ambiguous` (both instants, an hour or half an hour apart) or `Skipped` (the gap a
spring-forward leaves, with the transition's instant and the jump's size). `load` reads `$TZDIR` or
`/usr/share/zoneinfo` and refuses a name that is not a relative path of ordinary components, so a zone
name cannot name a file outside the zone directory. Leap seconds are ignored deliberately: a
`time::Timestamp` is the POSIX second count Unix time uses, and a leap-second table would make the two
disagree.

## Validated text

`utf8::Utf8String` is text whose bytes are known to be valid UTF-8, and the byte-slice `string` is
still what the language, the runtime and every allocation-free interface speak. The two are not
rivals: a `Utf8String` is a *promise about* bytes, made once at construction, and `as_bytes` hands
those bytes back as a view with no copy in between.

```grl
use utf8;

fn main() {
    text := utf8::from_bytes(view("caf\\u{e9} \\u{4e16}\\u{754c}"))!;   // or the offset that refused
    println(text.char_count());
    left := text.slice_chars(0, 4)!;                  // character boundaries, checked
    println(left.concat(&text).show());
    println(text.as_bytes().len());                   // the bytes, without a copy
    for c in text.chars() {
        println(c);                                   // every sequence decodes: no U+FFFD
    }
}
```
