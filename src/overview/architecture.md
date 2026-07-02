# Architecture: the three pillars

> **Summary.** Goblin is layered. A [GRIM](../pillars/grim-base.md) wallet/node core handles money; a [Nostr](../pillars/nostr.md) layer handles messaging and identity; a [Nym](../pillars/nym.md) layer handles transport. The UI ties them into a Cash-App-style experience. Each layer is replaceable in principle and isolated in the code.

## The stack, top to bottom

```
┌─────────────────────────────────────────────────────────┐
│  Goblin UI   (src/gui/views/goblin/)                     │
│  Home · Pay/Request · Activity · Receive · Me · Send flow│
├─────────────────────────────────────────────────────────┤
│  Nostr messaging   (src/nostr/)                          │
│  identity · gift-wrapped slatepacks · ingest policy ·    │
│  relays · NIP-05 names · per-wallet service thread       │
├─────────────────────────────────────────────────────────┤
│  Nym mixnet transport   (src/nym/)                       │
│  mixnet tunnel + scoped relay exits → 5-hop mixnet       │
│  ALL relay sockets + HTTP + DNS go through here          │
├─────────────────────────────────────────────────────────┤
│  GRIM wallet + node engine   (wallet/, node/)            │
│  seed · keys · sync · Mimblewimble slatepack tx machine  │
└─────────────────────────────────────────────────────────┘
        │                                   │
   Nym mixnet                        Grin node (direct,
 (identity + payments               public chain data,
  + price + avatars)                 not tied to identity)
```

## Why these three

Each pillar exists because the layer below it leaves a gap:

- **GRIM** gives a correct, complete Grin wallet, but its native payment UX is file-swapping. *Gap: usability.*
- **Nostr** closes that gap: it turns the slatepack handshake into encrypted, store-and-forward messaging addressed by key, with human usernames on top. *Gap it leaves: the relay still sees your IP, and an observer can correlate the two legs of the exchange by timing.*
- **Nym** closes *that* gap: routing everything through a mixnet hides your network identity and breaks timing correlation. *Result: who-pays-whom is private from the chain up and the network down.*

## What rides which transport

A deliberate split (see [the project decisions](../pillars/nym.md#what-goes-over-the-mixnet-and-what-doesnt)):

| Traffic | Path | Why |
| --- | --- | --- |
| Nostr relay sockets (payments, identity events) | **Nym mixnet** (the primary relay through its operator's [scoped exit](../pillars/nym-exit.md) when available) | Reveals who you talk to; must be hidden. |
| NIP-05 name lookups, price feed, avatars (HTTP) | **Nym mixnet** | Reveal who you are / who you're paying. |
| DNS | **Nym mixnet** ([DoT/DoH through the tunnel](../pillars/nym-dns.md)) | A clearnet lookup would announce which relays and hosts you contact. |
| Grin node connection (block sync, broadcast) | **Direct** | Public chain data, identical for everyone, not tied to your identity. Anonymizing it buys little and costs reliability. |

## Code map

| Layer | Directory | Start here |
| --- | --- | --- |
| UI | `goblin/src/gui/views/goblin/` | `mod.rs` (`GoblinWalletView`) |
| Nostr | `goblin/src/nostr/` | `mod.rs`, `client.rs` |
| Nym | `goblin/src/nym/` | `nymproc.rs`, `streamexit.rs`, `transport.rs` |
| Wallet↔Nostr glue | `goblin/src/wallet/wallet.rs` | `WalletTask::Nostr*` |
| GRIM core | `goblin/wallet/`, `goblin/node/` | inherited from GRIM |
| Identity server | `goblin-nip05d/` (sibling crate) | the NIP-05 authority |

## A payment in one breath

You tap Pay → GRIM builds a slatepack → the Nostr layer gift-wraps it and publishes it to relays → the bytes leave your machine through the Nym mixnet → the recipient's wallet ingests it, auto-builds its half, and replies the same way → your wallet finalizes and GRIM broadcasts to the Grin node. The [payment-flow page](../features/payment-flow.md) walks every step.

## References

- Layer directories: `goblin/src/{gui/views/goblin,nostr,nym}/`, `goblin/wallet/`, `goblin/node/`.
- Transport split rationale: `goblin/README.md`; see also [Nym in Goblin](../pillars/nym.md).
- Architecture overview diagram: `Goblin-Transport-Overview.pdf` (project root).
