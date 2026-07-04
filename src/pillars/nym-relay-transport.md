# Relay traffic over Tor

> **Summary.** Goblin gives the Nostr relay pool a custom websocket transport backed by its [embedded Tor client](nym-client.md). A relay whose pool entry advertises an [`.onion`](nym-exit.md) is dialed straight to that onion; any other relay is reached over a Tor circuit to its clearnet host. Either way, the same hostname-validated TLS + websocket handshake runs over the Tor-carried byte stream, so nothing above the byte transport can tell the difference.

## Motivation

The `nostr-sdk` relay pool normally opens websockets directly. To put relay traffic on Tor without forking the SDK, Goblin implements the SDK's `WebSocketTransport` trait with its own connector. This is the clean seam: the entire rest of the Nostr layer is unchanged; only *how a socket is opened* differs. It is the same seam the old mixnet transport plugged into — the byte source underneath simply changed from a mixnet stream to a Tor `DataStream`.

## How it works

For each relay URL the pool wants to connect to, the transport:

1. **Prefers the onion.** If the [relay pool](nostr-relays.md#the-candidate-pool) advertises this relay's `.onion`, the wallet asks arti for a circuit to `<onion>:443` and runs the TLS + websocket handshake over it — no DNS, no clearnet leg. This is the money path.
2. **Otherwise dials over Tor to the clearnet host.** A relay with no advertised onion (discovery and secondary relays) is reached by handing its hostname to arti, which builds a circuit out through an exit relay; the TLS (for `wss`) + websocket handshake then runs over that. The device still never resolves the name or reveals its IP.
3. **Splits the socket** into a sink (writes) and a stream (reads) for the pool, identical whichever circuit carried the connection.

Each stage is bounded by the pool's connect timeout and timed in the logs, so connect cost can be attributed per relay. The result is an ordinary websocket from the SDK's point of view; it just happens to traverse Tor.

## Reference

In `goblin/src/tor/` (the arti-backed transport, copied from GRIM):

- The transport type implements `nostr_relay_pool::transport::websocket::WebSocketTransport`.
- `connect()`: the onion-first fork (`pool::onion_for(url)`) via `TorClient::connect(<onion>:443)`, else a Tor circuit to the resolved-by-Tor clearnet host; both feed `tokio_tungstenite::client_async_tls(url, stream)` — the TLS + websocket wrap is **unchanged** from the old transport.
- The socket-split and frame-adapter helpers, shared by both circuit kinds.

## References

- The client that serves every circuit: [The embedded Tor client](nym-client.md).
- The onion the money path prefers: [The relay's onion service](nym-exit.md).
- The pool that uses this transport: [The NostrService](nostr-service.md).
