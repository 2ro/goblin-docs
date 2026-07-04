# Relay traffic over Tor

> **Summary.** Goblin gives the Nostr relay pool a custom websocket transport backed by its [embedded Tor client](nym-client.md). Every relay is dialed the same way: a Tor-exit circuit to its clearnet host, running the usual hostname-validated TLS + websocket handshake over the Tor-carried byte stream. Nothing above the byte transport can tell one relay's connection from another's.

## Motivation

The `nostr-sdk` relay pool normally opens websockets directly. To put relay traffic on Tor without forking the SDK, Goblin implements the SDK's `WebSocketTransport` trait with its own connector. This is the clean seam: the entire rest of the Nostr layer is unchanged; only *how a socket is opened* differs. It is the same seam the old mixnet transport plugged into, the byte source underneath simply changed from a mixnet stream to a Tor `DataStream`.

## How it works

For each relay URL the pool wants to connect to, the transport:

1. **Dials over Tor to the relay's clearnet host.** The relay's hostname is handed to arti, which builds a circuit out through an exit relay; the TLS (for `wss`) + websocket handshake then runs over that stream. The device never resolves the name or reveals its IP. (An earlier build preferred a pinned `.onion` when the pool advertised one; build134 dropped the `onion` field and that fork entirely, see [The relay's Tor exit path](nym-exit.md).)
2. **Splits the socket** into a sink (writes) and a stream (reads) for the pool.

Each stage is bounded by the pool's connect timeout and timed in the logs, so connect cost can be attributed per relay. The result is an ordinary websocket from the SDK's point of view; it just happens to traverse Tor.

## Reference

In `goblin/src/tor/transport.rs` (the arti-backed transport, copied from GRIM):

- The transport type implements `nostr_relay_pool::transport::websocket::WebSocketTransport`.
- `connect()`: hands the relay's hostname to arti for a Tor-exit circuit, then feeds `tokio_tungstenite::client_async_tls(url, stream)`, the TLS + websocket wrap is unchanged from the earlier onion-preferring version.
- The socket-split and frame-adapter helpers.

## References

- The client that serves every circuit: [The embedded Tor client](nym-client.md).
- Why there's no onion path any more: [The relay's Tor exit path](nym-exit.md).
- The pool that uses this transport: [The NostrService](nostr-service.md).
