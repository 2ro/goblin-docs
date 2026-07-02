# Relay traffic over the mixnet

> **Summary.** Goblin gives the Nostr relay pool a custom websocket transport with **two mixnet egresses**, picked per relay: a relay whose pool entry advertises its operator's [scoped exit](nym-exit.md) is dialed straight through that exit; every other relay, and every fallback, rides the shared [tunnel](nym-client.md). Either way, the same hostname-validated TLS + websocket handshake runs over the mixnet-carried stream, so nothing above the byte transport can tell the difference.

## Motivation

The `nostr-sdk` relay pool normally opens websockets directly. To put relay traffic on the mixnet without forking the SDK, Goblin implements the SDK's `WebSocketTransport` trait with its own connector. This is the clean seam: the entire rest of the Nostr layer is unchanged; only *how a socket is opened* differs.

## How it works

For each relay URL the pool wants to connect to, `NymWebSocketTransport::connect`:

1. **Tries the scoped exit first.** If the [relay pool](nostr-relays.md#the-candidate-pool) advertises this relay operator's co-located exit, the wallet opens a mixnet stream straight to it (no DNS, no public exit) and runs the TLS + websocket handshake over that. Any failure (bootstrap, open, handshake, timeout) logs and falls through to step 2, so an exit outage never locks the wallet out.
2. **Falls back to the tunnel.** The relay host is resolved [over encrypted DNS through the tunnel](nym-dns.md), a TCP stream to the resolved address is opened through the same tunnel, and the TLS (for `wss`) + websocket handshake runs over it.
3. **Splits the socket** into a sink (writes) and a stream (reads) for the pool, identical whichever egress carried the connection.

Every stage is bounded by the pool's connect timeout, and each is timed in the logs so connect cost can be attributed per relay. The result is an ordinary websocket from the SDK's point of view: it just happens to traverse five mixnet hops.

## Reference

In `goblin/src/nym/transport.rs`:

- `NymWebSocketTransport` implements `nostr_relay_pool::transport::websocket::WebSocketTransport`; `support_ping()` is `true`.
- `connect()`: the exit-first fork (`pool::exit_for(url)`), then the tunnel path: `dns::resolve()`, `tunnel.tcp_connect(addr)`, `tokio_tungstenite::client_async_tls(url, stream)`.
- `exit_connect()`: `streamexit::open_stream()` + the same `client_async_tls`; the TLS handshake doubles as the exit liveness probe.
- `split_ws()`, `tg_to_message()`, `NymSink`: adapting tungstenite frames to the pool's message type, shared by both egresses.

## References

- The tunnel that serves the fallback: [The in-process mixnet tunnel](nym-client.md).
- The direct egress: [The scoped relay exit](nym-exit.md).
- The pool that uses this transport: [The NostrService](nostr-service.md).
