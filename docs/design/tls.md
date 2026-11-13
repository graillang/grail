# TLS over the system TLS stack

Status: **agreed; implementation follows this note** (Linux/OpenSSL first, then the Windows and
macOS branches; the verification section records what was actually run at the end). This note fixes the API, the error taxonomy, the trust
store rules and the lifetime of a session before any of it was written, and records where the
platform code had to live and why.

## What the standard library promises

`lib/tls.grl` (module `tls`) is a small client TLS layer over the operating system's own TLS
implementation - OpenSSL/LibreSSL on Linux and the BSDs, SChannel on Windows, SecureTransport on
macOS. Nothing above the module sees a foreign pointer, a length that has to be tracked by hand, or
an unverified connection: the whole FFI surface, every `unsafe` block and every C-shaped record is
inside `lib/tls.grl`, and what a user calls is ordinary safe Grail.

```grl
pub struct TlsConfig { ... }                     // trust store, SNI, ALPN, minimum version, client cert
pub fn TlsConfig::new() -> TlsConfig
pub fn with_ca_file(self, path: string) -> TlsConfig
pub fn with_ca_dir(self, path: string) -> TlsConfig
pub fn with_alpn(self, protocols: u8[][] ) -> TlsConfig
pub fn with_sni(self, name: string) -> TlsConfig
pub fn with_min_version(self, version: u64) -> TlsConfig
pub fn with_client_cert(self, cert: string, key: string) -> TlsConfig

pub struct TlsClient { ctx: u64 }                // one client context: session cache lives here
pub fn TlsClient::new(config: &TlsConfig) -> TlsClient |? Error
pub fn TlsClient::connect(self: (&TlsClient), host: string, port: u64) -> TlsStream |? Error
pub fn TlsClient::connect_over(self: (&TlsClient), stream: &mut net::TcpStream, server_name: string) -> TlsStream |? Error

pub struct TlsStream { ... }                     // owns the socket it was handed
pub fn read(self: (&mut TlsStream), buffer: (&mut u8[])) -> u64 |? Error
pub fn read_all(self: (&mut TlsStream)) -> u8[] |? Error
pub fn write(self: (&mut TlsStream), data: (&[u8])) -> u64 |? Error
pub fn write_all(self: (&mut TlsStream), data: (&[u8])) -> u64 |? Error
pub fn shutdown(self: (&mut TlsStream)) -> unit |? Error    // close_notify, socket stays open
pub fn close(self: TlsStream)                                // close_notify + close the socket
pub fn version(self: (&TlsStream)) -> string
pub fn alpn(self: (&TlsStream)) -> string
pub fn peer_subject(self: (&TlsStream)) -> string
pub fn fd(self: (&TlsStream)) -> u64

pub enum Error { Verify(u64), Protocol(u64), Io(u64), NoTrustStore, Closed }
```

### The four error classes, and why they are distinct

Verification failure is not an IO error and must never be retried as one: `Error::Verify(code)`
carries the library's own verification result, and it is produced **only** after the library has
rejected the peer's chain or name. A caller is allowed to do exactly one thing with it - report it.
There is no configuration in which verification is off (§"Trust store"), so a `Verify` value cannot
be produced by a program that forgot to configure something.

- `Verify(code)` - the chain or the name did not verify (`code` is `SSL_get_verify_result` /
  `SecTrustResultType` / `CERT_E_*`).
- `Protocol(code)` - the peer verified but the conversation is not TLS we can continue: bad record,
  no shared version, ALPN mismatch, handshake failure.
- `Io(code)` - the transport failed: refused, reset, EOF in the middle of a record.
- `NoTrustStore` - the process has no trust anchors and no explicit CA file was given. This is a
  *refusal to connect*, not an unverified connection (see below).
- `Closed` - the stream was already closed, or the peer's TCP connection ended without a
  `close_notify`. The second is the truncation case: `read` returns `Ok(0)` **only** for a clean
  `close_notify`, so a peer cannot turn a truncation attack into an ordinary end of stream.

### Trust store, per platform

| | where the anchors come from | when it is empty |
| --- | --- | --- |
| Linux/BSD (OpenSSL) | `SSL_CTX_set_default_verify_paths` (which honours `SSL_CERT_FILE` and `SSL_CERT_DIR`), or `SSL_CTX_load_verify_locations` for an explicit `ca_file`/`ca_dir` | `TlsClient::new` returns `Error::NoTrustStore` |
| macOS | SecureTransport's default policy: the system keychain and the system anchor set (`SecTrustEvaluate` with no explicit anchors) | the handshake fails with `Error::Verify` |
| Windows | SChannel's default chain policy against the machine `ROOT` store (`CertGetCertificateChain` with `CERT_CHAIN_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT`) | the handshake fails with `Error::Verify` |

Peer verification is **on** in every path (`SSL_CTX_set_verify(SSL_VERIFY_PEER)` on OpenSSL,
`SSL_set_session_option(kSSLSessionOptionBreakOnServerAuth, false)` - the default - on macOS,
`SCH_CRED_MANUAL_CRED_VALIDATION` *not* set on SChannel), and the host name is always checked:
`SSL_set1_host` for a DNS name and `X509_VERIFY_PARAM_set1_ip_asc` through `SSL_get0_param` for an
address on OpenSSL, `SSLSetPeerDomainName` on macOS, `SECBUFFER_SNI` + `ISC_REQ_MANUAL_CRED_VALIDATION`
absent on Windows. There is no API to skip it.

The empty-store rule is the one that needs saying out loud: a TLS context with no anchors verifies
nothing, and the naive reading of that - "every connection fails" - is wrong for OpenSSL, where a
store with zero certificates plus `SSL_VERIFY_PEER` still lets *some* chains through paths the
platform store would have rejected. So `TlsClient::new` asks the store it built how many objects it
holds (`SSL_CTX_get_cert_store` + `X509_STORE_get0_objects` + `OPENSSL_sk_num`) and refuses with
`Error::NoTrustStore` when the answer is zero and no explicit CA was configured. A container with
no `ca-certificates` package therefore fails at `TlsClient::new`, by name, instead of shipping a
program that cannot verify anything.

### The session cache is scoped to `TlsClient`

A TLS session cache is what makes resumption (and therefore a second connection to the same host
that costs one round trip instead of two) possible. The cache is a property of the TLS *context*,
not of a stream, so the API makes it one: `TlsClient` owns the context and `connect` borrows it.
That gives a rule a reader can hold on to:

- one `TlsClient` per process (per configuration) - resumption works, memory is bounded by the
  library's own cache limits;
- one `TlsClient` per connection - correct, and no resumption, which is what the type makes
  obvious rather than surprising.

On OpenSSL 1.1 and later the session cache inside one `SSL_CTX` is internally locked, so a context
shared by several worker threads is safe; on macOS `SSLSessionCache` is per-process and on Windows
the credential handle's cache is per-`SCHANNEL_CRED`. Grail's own rule is narrower than the C
library's: `TlsClient` holds a `handle`, and a handle is thread-affine unless its declaration says
otherwise, so passing one to a worker is refused until the audit is written. Concurrent connections
from one `TlsClient` are fine - the second `connect` takes only `&TlsClient`.

### Blocking on the reactor, non-blocking underneath

The socket is never handed to the C library. The stream keeps *its* file descriptor and pumps the
TLS state machine with memory BIOs (OpenSSL `BIO_s_mem`), so:

- the C library never blocks, never calls `recv`, and never installs a signal handler;
- `SSL_connect`/`SSL_read`/`SSL_write` return `WANT_READ`/`WANT_WRITE`, and the module answers by
  flushing the output BIO to the socket (`host::write_fd`) and waiting for input (`host::read_fd`);
- those two are the runtime's own blocking operations, which on Linux/BSD suspend the *task* on the
  readiness reactor (epoll/kqueue) and on Windows hand the wait to an offload thread. A TLS stream
  therefore behaves like `net::TcpStream`: other tasks keep running while it waits, and the
  scheduler thread is never held by a foreign call.

This is also why the module does not use `SSL_set_fd`: that path makes the C library do the
blocking read itself, which would occupy a scheduler thread for the whole handshake.

### close_notify

`close_notify` is a TLS record that says "I am done sending, and nothing was truncated". It is part
of the API, not an implementation detail:

- `shutdown(&mut TlsStream)` sends `close_notify` and half-closes the write side of the socket; the
  caller may still read. This is the polite order - say you are done, then drain the peer.
- `close(TlsStream)` sends `close_notify` (if the stream is healthy), waits for nothing, closes the
  socket and releases the session. It is the one call every stream must reach exactly once; a
  stream that is merely dropped leaks its descriptor and its session until the process exits,
  because Grail has no destructor.
- `read` returns `Ok(0)` when the peer sent `close_notify`, and `Error::Closed` when the connection
  ended without one. A caller that treats both as "end of stream" loses the distinction, which is
  exactly the distinction TLS puts there.

## Where the platform code lives, and why it is not `compiler/os-*.grl`

The task was to put the Windows and macOS halves into `compiler/os-windows.grl` and
`compiler/darwin.grl` as platform services. **They are in `lib/tls.grl` instead**, one `@if target.os`
static branch each, and this is the measured reason:

1. `compiler/os-linux.grl` is compiled into **every** Linux program - the driver passes it beside
   `runtime.grl` unconditionally.
2. `extern "C" lib "ssl"` requests its link input at *declaration* time (`ffi_link`), not when a
   declaration is called. There is no lazily-emitted link input.
3. Unreferenced functions are still emitted: a function that calls a declared-but-absent symbol
   makes the *link* fail even when nothing calls it.

Together those mean a binding in `compiler/os-linux.grl` would put `-lssl -lcrypto` on every Grail
program on Linux - every build would need `libssl-dev`, every static program would become
dynamically linked against OpenSSL, and the cross targets (AArch64/RISC-V without a sysroot) would
stop linking. `lib/tls.grl` is a top-level standard-library module, so it is compiled only when a
program says `use tls;`: a program that does not use TLS is byte-for-byte what it was, and a program
that does gets OpenSSL on its link line and nothing else.

The same file also has to be the one place where the three libraries are described, because Grail
has no conditional *import*: a module is compiled for every target its program is built for, so
per-target code has to sit behind `@if target.os`, whose untaken branch is parsed but neither
type-checked nor emitted (and, for a declaration, emits no link input). The Windows branch is
therefore a real compile-checked SChannel binding rather than a comment, and it costs a Linux build
nothing.

What the platform layers still own is unchanged: `compiler/os-linux.grl` provides the reactor and
the readiness wait that `host::read_fd`/`host::write_fd` use, which is the mechanism the pump
builds on.

## Implementations

### Linux/BSD: OpenSSL (3.x, 1.1-compatible symbols)

Symbols are the ones every 1.1-and-later build exports, so one binding works against LibreSSL's
ABI-compatible subset and against OpenSSL 3.6: `TLS_client_method`, `SSL_CTX_new`,
`SSL_CTX_set_verify`, `SSL_CTX_set_default_verify_paths`, `SSL_CTX_load_verify_locations`,
`SSL_CTX_get_cert_store`, `SSL_new`, `SSL_set_bio`, `SSL_connect`, `SSL_read`, `SSL_write`,
`SSL_get_error`, `SSL_shutdown`, `SSL_free`, `SSL_CTX_free`, `SSL_set1_host`, `SSL_get0_param`,
`X509_VERIFY_PARAM_set1_ip_asc`, `SSL_get1_peer_certificate`, `SSL_get_version`,
`SSL_CTX_set_alpn_protos`, `SSL_get0_alpn_selected`, `X509_get_subject_name`, `X509_NAME_oneline`,
`X509_free`, `ERR_get_error`, `ERR_error_string_n`, plus `BIO_s_mem`/`BIO_new`/`BIO_read`/
`BIO_write`/`BIO_ctrl` from libcrypto. `SSL_set_tlsext_host_name` is a macro in the C header and so
not a symbol: SNI is `SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, TLSEXT_NAMETYPE_host_name, name)`,
which is the ctrl the macro expands to.

ALPN is `SSL_CTX_set_alpn_protos` with the length-prefixed wire list; the negotiated protocol is
read back with `SSL_get0_alpn_selected`.

### Windows: SChannel

`AcquireCredentialsHandleA` with `SCHANNEL_CRED` (`SCH_CREDENTIALS_VERSION`, protocol flags for TLS
1.2/1.3, `SCH_USE_STRONG_CRYPTO`), `InitializeSecurityContextA` driven to completion for the
handshake and per message, `QueryContextAttributesA` for the stream sizes
(`SECPKG_ATTR_STREAM_SIZES`) and the negotiated protocol (`SECPKG_ATTR_CONNECTION_INFO`),
`EncryptMessage`/`DecryptMessage` for the records, `SECBUFFER_SNI` for the server name, and chain
verification through `CertGetCertificateChain` against the machine `ROOT` store. The credential and
context handles are the C-owned opaque handles the module releases with
`FreeCredentialsHandle`/`DeleteSecurityContext`. `secur32` and `crypt32` are named as the link
inputs, which the compiler turns into `// grail-link: import secur32 AcquireCredentialsHandleA`
notes that the Windows driver turns into import objects.

### macOS: SecureTransport

SecureTransport rather than Network.framework: Network.framework is an asynchronous,
dispatch-queue API, and this layer is a synchronous pump over a file descriptor - adopting it would
mean running a dispatch queue and bridging callbacks back into a blocking call, for no gain. The
deprecation of SecureTransport is a compile-time warning in C and not a removal; the symbols are
present in every macOS SDK Grail targets.

`SSLCreateContext` (`kSSLClientSide`), `SSLSetIOFuncs` with the two callbacks reading and writing
the descriptor, `SSLSetPeerDomainName` for the name, `SSLSetProtocolVersionMin`, `SSLSetALPNProtocols`,
`SSLSetCertificate` for a client cert, `SSLHandshake`, `SSLRead`/`SSLWrite`, `SSLClose`,
`SSLGetNegotiatedProtocolVersion`, `SSLGetNegotiatedProtocol`. The trust evaluation is the default
one: the handshake fails with `errSSLXCertChainInvalid` (or
`errSSLPeerCertVerificationFailed`) and the module maps that result to `Error::Verify`.

## Verification

Executed on x86-64 Linux against OpenSSL 3.6.5, in `tests/native-cases.json`:

- `tls-local-server-refused-untrusted` / `tls-local-server-accepted-trusted`: the case starts
  `openssl s_server` on a loopback port with a certificate generated on the fly for `127.0.0.1`
  (self-signed, so its own trust anchor), then connects **twice** with the same call. The first
  context has only the system store, which does not contain that certificate: the handshake must
  fail with `tls::Error::Verify`, and the case prints the class, not the code. The second context
  names the generated certificate as its CA file: the handshake must succeed. The pair is the
  acceptance test, because it proves the layer *checks* - a layer that spoke TLS without verifying
  would pass both.
- `tls-local-server-data-integrity`: 8 KiB in both directions through the local server, compared
  byte for byte, then `shutdown` (close_notify) and a clean end of stream.
- `tls-trust-store-empty-refused`: `SSL_CERT_FILE` and `SSL_CERT_DIR` point at a directory with no
  certificates; `TlsClient::new` must answer `NoTrustStore` and no connection is attempted.
- `tls-real-host-handshake`: `example.com:443`, asserting the negotiated version, the certificate
  subject and that verification succeeded. It skips (and says so, exiting 0) when the network is
  unavailable.

The Windows and macOS branches are cross-compiled (`--target windows-x86_64`, `--target
macos-x86_64`) on every corpus run: the branch has to type-check, lower and emit its `import`
notes. Nothing of SChannel or SecureTransport was executed; no Windows or macOS host was available.

## Not in this increment

- server side (`SSL_accept`, SChannel `AcceptSecurityContext`, `kSSLServerSide`);
- `read_all`-style zero-copy or vectored IO, and any buffering layer above the record layer;
- client certificates beyond loading a PEM pair, and no OCSP/CRL policy of our own (the library's
  default policy applies);
- session resumption across processes (no session ticket cache on disk);
- runtime reactor integration for the macOS/Windows branches beyond what `host::read_fd`/
  `host::write_fd` already give (both branches are written against those two operations).
