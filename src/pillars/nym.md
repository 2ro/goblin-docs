# Nym in Goblin

> **Summary.** Goblin routes **all** of its network traffic (every Nostr relay socket and every HTTP request) through the [Nym mixnet](https://nym.com), a 5-hop anonymizing network. The mixnet client is linked **in-process**: one shared [tunnel](nym-client.md) carries traffic to an auto-selected public exit, and the money-path relay is dialed straight through its operator's own [scoped exit](nym-exit.md) when one is advertised. Even DNS happens [inside the mixnet](nym-dns.md). Nothing Goblin sends touches the clear net.

## Motivation

Encryption hides *what* you say; it doesn't hide *that you're saying it, to whom, and when*. For an interactive Grin payment that distinction matters a lot:

- A relay you connect to learns your **IP**.
- Even with gift-wrapped messages, an observer who can see both legs of the exchange can **correlate them by timing**: the two-message ping-pong of a payment is a recognizable pattern.

A mixnet is the right tool against both. Nym batches and delays packets across five hops, so per-message timing is decoupled and the network can't tell who is talking to whom. Goblin's owner specifically wanted metadata privacy for the slatepack exchange, and found the previous transport (Tor) painfully slow to bootstrap.

## How it works

The mixnet client is a **direct dependency**, linked into the binary. There is no sidecar process and no bundled binary to ship or sideload. Traffic leaves the wallet by one of two mixnet egresses:

1. **The in-process tunnel** (the default). At startup Goblin warms up one process-lifetime [mixnet tunnel](nym-client.md): raw TCP over the mixnet to an auto-selected public **exit gateway**. Relay sockets and HTTP requests both ride it, and hostnames are resolved [through the same tunnel](nym-dns.md) over encrypted DNS, so not even a lookup touches the clear net. The tunnel is health-checked continuously and rebuilt on a fresh exit whenever the current one goes bad, so there is no single-exit point of failure.
2. **A scoped relay exit** (the money-path anchor). A relay operator can run a small Nym exit co-located with their relay that forwards **only** to that relay. When Goblin's [relay pool](nostr-relays.md#the-candidate-pool) advertises one, the wallet dials it directly over the mixnet: no public DNS and no shared public exit on the payment path. Any failure falls back to the tunnel transparently; see [The scoped relay exit](nym-exit.md).

Whichever egress carries a connection, TLS is negotiated end to end against the destination hostname, so an exit (public or scoped) only ever sees ciphertext.

The component pages:

| Page | Covers | File |
| --- | --- | --- |
| [The in-process mixnet tunnel](nym-client.md) | Bootstrapping the tunnel, exit selection, the health watchdog | `nymproc.rs` |
| [The scoped relay exit](nym-exit.md) | The direct mixnet stream to a relay operator's own exit | `streamexit.rs` |
| [DNS over the mixnet](nym-dns.md) | DoT/DoH resolution through the tunnel | `dns.rs` |
| [Relay traffic over the mixnet](nym-relay-transport.md) | The websocket transport for the relay pool | `transport.rs` |
| [HTTP over the mixnet](nym-http.md) | HTTP requests through the tunnel or a scoped exit | `mod.rs` |

## What goes over the mixnet, and what doesn't

| Traffic | Path |
| --- | --- |
| Nostr relay sockets (payments + identity events) | **Nym**: the operator's scoped exit for the primary relay when advertised, the tunnel otherwise. |
| NIP-05 lookups, price feed, avatars, relay pool + NIP-11 probes | **Nym** (the tunnel; HTTPS to a relay with a scoped exit rides that exit). |
| DNS | **Nym** (DNS-over-TLS through the tunnel, DNS-over-HTTPS fallback; never a clearnet lookup). |
| Grin **node** connection (sync, broadcast) | **Direct**: public chain data, not tied to your identity; anonymizing it adds latency for no metadata gain. |

## References

- Layer entry points: `goblin/src/nym/{nymproc,streamexit,dns,transport,mod}.rs`.
- Why Tor was replaced by Nym: project history; see [The in-process tunnel](nym-client.md).
- Nym developer docs: <https://nym.com/docs/developers/rust>.
