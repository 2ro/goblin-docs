# Tor in Goblin

> **Summary.** Goblin routes every Nostr relay socket and every HTTP request (names, price feed, avatars) through **Tor**, embedded **in-process** with [arti](https://tpo.pages.torproject.net/core/arti/) (Tor written in Rust), the same engine our sister wallet [GRIM](grim-base.md) already ships. The wallet dials the relay's pinned **`.onion` address** directly, so the relay and every network observer see a Tor address, never your phone's IP. The division of labor is the whole idea: **Tor hides your network location from the relay; the relay and the Nostr protocol hide everything else.** The one deliberate exception is the Grin **node** connection, which stays direct: public chain data, where liveness matters more than anonymity.

## Motivation

Encryption hides *what* you say; it doesn't hide *that you're saying it, to whom, and when*. For an interactive Grin payment that distinction matters a lot, and it breaks down into pieces that are best solved by different tools:

- **Your network location (IP).** A relay you connect to is, by definition, the one machine you open a socket to, so it structurally *can't* hide your network identity by itself: it sees where your connection comes from. That is the one gap Tor exists to close, and Tor is the best tool in the world for exactly it. An onion connection has no exit node in the usual sense; the relay is reached at a `.onion`, so it (and every hop, and anyone watching the wire) sees a Tor address, never your phone.
- **Everything else** is already handled *above* the transport, by the relay and the Nostr protocol Goblin runs on:
  - **Content** is end-to-end encrypted. A payment is a [NIP-59 gift-wrap](nostr-protocol.md): the relay stores an opaque blob and nobody but the recipient can read it.
  - **The sender** is a throwaway, one-time key. The relay never sees who really sent a payment, only a per-message ephemeral key.
  - **The timing** — the one thing an interactive payment would otherwise leak, since the two-message ping-pong is a recognizable pattern — is shuffled by **our own relay**, which holds each message and releases it to the recipient on a short randomized delay (see [below](#timing-privacy-the-relay-does-it)).

So we need Tor for one narrow, well-suited job — hide the IP from the relay — and our own relay for the rest. That is why Goblin does **not** need a full mixnet's heavy machinery.

## Why Tor (and not a mixnet)

Goblin's privacy transport used to be the Nym mixnet. We returned to Tor because a payments wallet has to stand on ground that doesn't move, and the mixnet's ground moved: the free bandwidth tier Goblin relied on turned out to be **testnet scaffolding that Nym is actively removing** — it is written to expire at UTC midnight, and Nym's public gateways are switching to a **paid model gated on holding the NYM token**. A money wallet can't stand on bandwidth that expires on a schedule or must be rented with a speculative token, and it went dark on us more than once.

Tor has none of those properties. It is free, unmetered, has no token, no bonding, and nothing to expire; it runs **in-process** on a phone (no separate program, no sidecar); it has the largest anonymity set of any deployed privacy network; it is lighter on the battery; and — measured where the user actually waits (sending, cold start) — it is **faster**, because it skips a mixnet's built-in per-hop delays. GRIM has already proven the whole embedded path in production. The honest trade is covered under [the threat model](#what-tor-covers-and-what-covers-the-rest) below.

## How it works

The Tor client is a **direct dependency**, linked into the binary via `arti-client` — no sidecar process and no bundled binary to ship or sideload. Traffic leaves the wallet on one of two kinds of Tor circuit:

1. **Onion circuits (the money path and identity).** At startup Goblin bootstraps one process-lifetime [embedded Tor client](nym-client.md). The money-path relay is reached at a **pinned `.onion`**: the wallet opens a Tor circuit straight to it, so the payment path needs **no public DNS** and no clearnet leg at all. The `goblin.st` [name authority](../features/name-authority.md) is reached at its own pinned `.onion` the same way. Because the destination is an onion address, name resolution happens inside Tor — [there is no clearnet lookup](nym-dns.md).
2. **Tor-to-clearnet circuits (small background lookups).** The handful of requests that target ordinary web hosts — the relay-pool refresh, the price feed, avatars — ride Tor out through a normal exit relay. Tor resolves those hostnames at the exit, so even these never leak a DNS query or your IP from the device.

Whichever circuit carries a connection, TLS is negotiated end to end against the destination hostname, so every hop — including the relay's own hosting Tor — only ever sees ciphertext.

The component pages:

| Page | Covers | File |
| --- | --- | --- |
| [The embedded Tor client](nym-client.md) | Bootstrapping arti in-process, readiness, the health/rebuild loop, mobile | `src/tor/` |
| [The relay's onion service](nym-exit.md) | Dialing the relay's pinned `.onion`; the fast money path | `src/tor/`, `pool.rs` |
| [Name resolution under Tor](nym-dns.md) | Why `.onion` needs no DNS, and how clearnet names resolve without a leak | (arti) |
| [Relay traffic over Tor](nym-relay-transport.md) | The websocket transport for the relay pool, over a Tor `DataStream` | `transport` |
| [HTTP over Tor](nym-http.md) | HTTP requests over onion or Tor-to-clearnet | `mod.rs` |

## Timing privacy: the relay does it

Tor is low-latency by design and does **not** shuffle message timing — a payment flows through as fast as the circuit allows. A mixnet's one genuine advantage was **timing unlinkability**: even an observer near both ends can't match "this sender uploaded at 10:01:03" to "that recipient downloaded at 10:01:04." Goblin rebuilds exactly that property in the one place it fully controls — **the relay** — which holds each incoming gift-wrap and releases it to the recipient after a short randomized (Poisson) delay. It is the same fuzzing a mixnet performs, collapsed onto the single server we operate, unmetered and always on.

The elegant part is that this costs the user nothing they can see. The sender's on-screen "Sent" clears the moment the relay **confirms it holds the message**, not when the recipient receives it — and delivery to the recipient is already asynchronous and invisible (they may be offline for hours). The randomized delay lands entirely inside that already-invisible gap. It also stacks on a fuzz the wallet already applies: [NIP-59](nostr-protocol.md) backdates every gift-wrap's timestamp by a random offset of up to two days, so even the timestamps on the wire are decorrelated from real send time.

## What Tor covers, and what covers the rest

The realistic adversary is the relay operator, ISPs, near-endpoint observers, and chain analysts. Each kind of leak has an owner:

| Leak | Who covers it |
| --- | --- |
| **Network location** (your IP, as seen by the relay and on-path observers) | **Tor** — the onion connection shows a Tor address, never your phone. |
| **Timing** (matching send-time to receive-time) | **The relay** — the randomized release delay above, plus NIP-59 timestamp backdating already in the wallet. |
| **Content** (the message plaintext) | **The protocol** — [NIP-44](nostr-protocol.md) encryption inside a NIP-59 gift-wrap; the relay stores an opaque blob. |
| **Sender identity** | **The protocol** — a throwaway one-time key per message; the relay never sees the real sender. |
| **Message size** | **The protocol** — NIP-44 padding, and gift-wraps are already near-uniform at payments volume. |

**The one honest limitation.** A full distributed mixnet spreads its mixing across many independent nodes, which is what lets it resist a *global passive adversary* who can watch the entire internet at once. A single relay plus Tor does not, and Tor itself states plainly that it does not defend against an attacker who can watch **both ends** of a circuit. That adversary is out of scope for a low-value Grin payments wallet, and it is not the threat this wallet realistically faces. For the adversary that actually exists, every level above is covered.

## What goes over Tor, and what doesn't

| Traffic | Path |
| --- | --- |
| Nostr relay sockets (payments + identity events) | **Tor**: a circuit straight to the relay's pinned `.onion`. |
| NIP-05 name lookups + registration | **Tor**: a circuit to the `goblin.st` name authority's pinned `.onion`. |
| Price feed, avatars, relay-pool + NIP-11 probes | **Tor**: out through a normal exit relay to the clearnet host (Tor resolves the name at the exit). |
| DNS | **None on the device** — onion addresses need no DNS, and clearnet names are resolved by Tor at the exit. There is never a clearnet lookup. |
| Grin **node** connection (sync, broadcast) | **Direct, by design**: public chain data, not tied to your identity. The privacy budget is spent on the money path; chain sync favors liveness over anonymity, and Tor-wrapping it would buy nothing but latency. |

## References

- Tor engine (copied from GRIM's proven `grim/src/tor/`): `goblin/src/tor/{mod,tor,config,types}.rs` (arti 0.43, native-tls runtime).
- The seams the transport plugs into: `goblin/src/nostr/{client,pool}.rs`.
- arti (Tor in Rust): <https://tpo.pages.torproject.net/core/arti/>.
- The Tor Project: <https://www.torproject.org>.
