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

## TLS over the system stack

`tls` puts a client TLS connection over the operating system's own implementation - OpenSSL or
LibreSSL on Linux and the BSDs, SChannel on Windows, SecureTransport on macOS - behind the same
ownership rules as `net`. The whole foreign surface is inside the module, so a program never names a
C type and never writes `unsafe` to use TLS.

```grl
use tls;

fn main() -> u64 {
    mut cfg = tls::config();
    cfg.add_alpn("h2,http/1.1");
    cfg.set_min_version(tls::VERSION_TLS12);
    match tls::client(&cfg) {
        ready: tls::TlsClient => {
            mut client = ready;
            // The address is a dotted quad: the runtime has no name lookup. The third argument is
            // the name the certificate must carry, and it is what SNI sends.
            mut s = client.connect("93.184.216.34", 443, "example.com")!;
            println(s.version());       // TLSv1.3
            println(s.alpn());          // h2
            mut request: string = "GET / HTTP/1.0\r\nHost: example.com\r\n\r\n";
            s.write_all(view(request))!;
            body := s.read_all()!;
            println(body.len() > 0);
            s.close();
        },
        error: tls::Error => {
            println(error.show());
        }
    }
    return 0;
}
```

Peer verification is not optional and has no switch: `tls::client` loads a trust store and **refuses
to build a context whose store is empty** (`Error::NoTrustStore`) rather than one that verifies
nothing, and the name or address passed to `connect` is always checked against the certificate. A
private CA is trusted by naming it: `cfg.set_ca_file("ca.pem")`.

`Error` keeps four classes apart because callers act on them differently. `Verify` is a security
result - the chain or the name was rejected - and is never retried. `Protocol` is a conversation
that cannot continue. `Io` is the transport. `Closed` means the stream was already closed, or the
peer's connection ended without a `close_notify`: `read` returns `0` **only** for a clean
`close_notify`, so a truncated response cannot pass for an ordinary end of stream.

One `TlsClient` holds one TLS context, and that is where the library's session cache lives: create
one per process (per policy) and connections through it can resume, while a client per connection
resumes nothing. A `TlsStream` owns the socket it was given - `connect_over` consumes a
`net::TcpStream`, so the same descriptor cannot be closed twice - and `close` sends `close_notify`
and releases both. `shutdown` sends `close_notify` and leaves the socket open for reading.

A TLS stream suspends its task exactly like `net::TcpStream`: the socket is never handed to the C
library, which drives a memory BIO on Linux while the module waits with the runtime's own
`host::read_fd`/`host::write_fd`. The negotiated version, the ALPN protocol and the peer's
certificate subject are available as `version()`, `alpn()` and `peer_subject()`.
