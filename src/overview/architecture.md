# Architecture: the three pillars

> **Summary.** Goblin is layered. A [GRIM](../pillars/grim-base.md) wallet/node core handles money; a [Nostr](../pillars/nostr.md) layer handles messaging and identity; a [Tor](../pillars/nym.md) layer handles transport. The UI ties them into a Cash-App-style experience. Each layer is replaceable in principle and isolated in the code.

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
│  Tor transport   (src/tor/)                              │
│  embedded arti -> the relay's pinned .onion              │
│  ALL relay sockets + HTTP go through here                │
├─────────────────────────────────────────────────────────┤
│  GRIM wallet + node engine   (wallet/, node/)            │
│  seed · keys · sync · Mimblewimble slatepack tx machine  │
└─────────────────────────────────────────────────────────┘
        │                                   │
        Tor                          Grin node (direct,
 (identity + payments               public chain data,
  + price + avatars)                 not tied to identity)
```

## Why these three

Each pillar exists because the layer below it leaves a gap:

- **GRIM** gives a correct, complete Grin wallet, but its native payment UX is file-swapping. *Gap: usability.*
- **Nostr** closes that gap: it turns the slatepack handshake into encrypted, store-and-forward messaging addressed by key, with human usernames on top. It also hides the *content*, the *sender* (a throwaway one-time key), and — via our own relay's randomized release delay — the *timing*. *Gap it leaves: the relay still sees your IP.*
- **Tor** closes *that* one gap: the relay is the machine you connect to, so it's the only piece that can't hide your network location by itself. An onion connection shows the relay a Tor address, never your phone. *Result: who-pays-whom is private from the chain up and the network down.*

That division of labor is the whole design: **Tor hides your network location from the relay; the relay and the Nostr protocol hide everything else.** It's why Goblin needs Tor for one narrow job and not a full mixnet — see [Tor in Goblin](../pillars/nym.md).

## What rides which transport

A deliberate split (see [the transport page](../pillars/nym.md#what-goes-over-tor-and-what-doesnt)):

| Traffic | Path | Why |
| --- | --- | --- |
| Nostr relay sockets (payments, identity events) | **Tor** (a circuit to the relay's pinned [`.onion`](../pillars/nym-exit.md)) | Reveals your network location to the relay; must be hidden. |
| NIP-05 name lookups (HTTP) | **Tor** (a circuit to the name authority's pinned `.onion`) | Reveals who you're about to pay. |
| Price feed, avatars (HTTP) | **Tor** (out through an exit relay to the clearnet host) | Reveal your IP and tie you to the app. |
| DNS | **None on the device** ([onions need no DNS](../pillars/nym-dns.md); clearnet names resolve at the Tor exit) | A clearnet lookup would announce which relays and hosts you contact. |
| Grin node connection (block sync, broadcast) | **Direct** | Public chain data, identical for everyone, not tied to your identity. Anonymizing it buys little and costs reliability. |

## Code map

| Layer | Directory | Start here |
| --- | --- | --- |
| UI | `goblin/src/gui/views/goblin/` | `mod.rs` (`GoblinWalletView`) |
| Nostr | `goblin/src/nostr/` | `mod.rs`, `client.rs` |
| Tor | `goblin/src/tor/` | the arti engine, copied from GRIM |
| Wallet↔Nostr glue | `goblin/src/wallet/wallet.rs` | `WalletTask::Nostr*` |
| GRIM core | `goblin/wallet/`, `goblin/node/` | inherited from GRIM |
| Identity server | `goblin-nip05d/` (sibling crate) | the NIP-05 authority |

## A payment in one breath

You tap Pay → GRIM builds a slatepack → the Nostr layer gift-wraps it and publishes it to relays → the bytes leave your machine over Tor, to the relay's pinned onion → the recipient's wallet ingests it, auto-builds its half, and replies the same way → your wallet finalizes and GRIM broadcasts to the Grin node. The [payment-flow page](../features/payment-flow.md) walks every step.

## References

- Layer directories: `goblin/src/{gui/views/goblin,nostr,tor}/`, `goblin/wallet/`, `goblin/node/`.
- Transport split rationale: `goblin/README.md`; see also [Tor in Goblin](../pillars/nym.md).
