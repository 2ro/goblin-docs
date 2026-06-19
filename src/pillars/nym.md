# Nym in Goblin

> **Summary.** Goblin routes **all** of its network traffic (every Nostr relay socket and every HTTP request) through the [Nym mixnet](https://nym.com), a 5-hop anonymizing network. The Nym SDK is linked **in-process** and exposes a local SOCKS5 proxy at `127.0.0.1:1080`; relays and HTTP both dial that. Nothing Goblin sends touches the clear net.

## Motivation

Encryption hides *what* you say; it doesn't hide *that you're saying it, to whom, and when*. For an interactive Grin payment that distinction matters a lot:

- A relay you connect to learns your **IP**.
- Even with gift-wrapped messages, an observer who can see both legs of the exchange can **correlate them by timing**: the two-message ping-pong of a payment is a recognizable pattern.

A mixnet is the right tool against both. Nym batches and delays packets across five hops, so per-message timing is decoupled and the network can't tell who is talking to whom. Goblin's owner specifically wanted metadata privacy for the slatepack exchange, and found the previous transport (Tor) painfully slow to bootstrap. Nym connects in ~2 seconds and round-trips a slatepack-sized message in well under a second per leg.

## How it works

The Nym SDK is a **direct dependency**, linked into the binary. There is no sidecar process and no bundled binary to ship or sideload. At startup Goblin warms up an in-process **SOCKS5 mixnet client** that listens on `127.0.0.1:1080`. From then on:

- The [Nostr relay transport](nym-relay-transport.md) dials relays *through* that SOCKS5 endpoint.
- Every [HTTP request](nym-http.md) (name lookups, price, avatars) uses it as a `socks5h` proxy (so DNS happens inside the proxy: no clearnet DNS leak either).

Both reach the mixnet exit (a **network requester**) and from there the public internet.

The three component pages:

| Page | Covers | File |
| --- | --- | --- |
| [The in-process mixnet client](nym-client.md) | Starting the SDK, the SOCKS5 endpoint, warm-up | `sidecar.rs` |
| [Relay traffic over the mixnet](nym-relay-transport.md) | The websocket transport for the relay pool | `transport.rs` |
| [HTTP over the mixnet](nym-http.md) | Routing reqwest through the proxy | `mod.rs` |

## What goes over the mixnet, and what doesn't

| Traffic | Path |
| --- | --- |
| Nostr relay sockets (payments + identity events) | **Nym** |
| NIP-05 lookups, price feed, avatar fetches | **Nym** |
| Grin **node** connection (sync, broadcast) | **Direct**: public chain data, not tied to your identity; anonymizing it adds latency for no metadata gain. |

## References

- Layer entry points: `goblin/src/nym/{sidecar,transport,mod}.rs`.
- Why Tor was replaced by Nym, and the measured connect/round-trip numbers: project history; see [The in-process client](nym-client.md).
- Nym developer docs: <https://nym.com/docs/developers/rust>.
