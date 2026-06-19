# Relay traffic over the mixnet

> **Summary.** Goblin gives the Nostr relay pool a custom websocket transport that dials every relay through the local Nym SOCKS5 proxy. The proxy resolves the relay host *inside* the mixnet (`socks5h`-style, no clearnet DNS), then the TLS + websocket handshake runs over that tunnel.

## Motivation

The `nostr-sdk` relay pool normally opens websockets directly. To put relay traffic on the mixnet without forking the SDK, Goblin implements the SDK's `WebSocketTransport` trait with its own connector. This is the clean seam: the entire rest of the Nostr layer is unchanged; only *how a socket is opened* differs.

## How it works

For each relay URL the pool wants to connect to, `NymWebSocketTransport::connect`:

1. Parses the host and port (defaulting 80 for `ws://`, 443 for `wss://`).
2. Opens a SOCKS5 connection to `127.0.0.1:1080` and asks the proxy to reach `(host, port)`. Because the proxy does the DNS resolution inside the mixnet, the destination host is never resolved on the clear.
3. Runs the TLS (for `wss`) and websocket handshake **over** that mixnet stream.
4. Splits the socket into a sink (writes) and a stream (reads), adapting tungstenite messages to the pool's message type.

All of this is wrapped in the pool's connect timeout. The result is an ordinary websocket from the SDK's point of view: it just happens to traverse five mixnet hops.

## Reference

In `goblin/src/nym/transport.rs`:

- `NymWebSocketTransport` implements `nostr_relay_pool::transport::websocket::WebSocketTransport`; `support_ping()` is `true`.
- `connect()`: host/port parse, `tokio_socks::tcp::Socks5Stream::connect(socks5_addr, (host, port))`, then `tokio_tungstenite::client_async_tls(url, stream)`, split into `WebSocketSink` / `WebSocketStream`.
- `tg_to_message()`: maps tungstenite `Text/Binary/Ping/Pong/Close` to the pool's `Message`.
- `NymSink`: sink adapter converting pool messages back to tungstenite messages.
- The SOCKS5 address comes from `crate::nym::socks5_addr()` (`127.0.0.1:1080`).

## References

- The proxy that serves `:1080`: [The in-process mixnet client](nym-client.md).
- The pool that uses this transport: [The NostrService](nostr-service.md).
- `socks5h` (DNS-in-proxy) rationale: [HTTP over the mixnet](nym-http.md).
