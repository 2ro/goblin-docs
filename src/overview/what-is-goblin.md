# What is Goblin?

> **Summary.** Goblin is a mobile-first wallet for [Grin](https://grin.mw) that lets you pay a **username** instead of swapping transaction files. It is a fork of the **GRIM** Grin wallet, with a Nostr-based messaging layer and a Nym mixnet transport bolted on so payments are end-to-end encrypted and metadata-private from the network up.

## The problem Goblin solves

Grin is built on [Mimblewimble](https://github.com/mimblewimble/grin): there are no addresses and no amounts on the chain, which makes it one of the most private cryptocurrencies in existence. But that privacy comes with a famously awkward UX. Grin transactions are **interactive**: to build one, the sender and receiver each have to contribute to a "slate," passing a *slatepack* file back and forth at least once before the payment is final.

In practice that means emailing files, pasting blobs into chat, or both parties being online at the same time. It works, but nobody would call it Cash App.

Goblin's thesis is simple: **keep Grin's on-chain privacy, and make the off-chain handshake feel like sending a text.**

## How it feels

You open Goblin to a single balance and a *Pay* button. You type `@alice` (or paste an `npub`), enter an amount, add an optional note, and **hold to send**. Alice's wallet (even if it was closed when you paid) picks the payment up the next time it connects, finishes its half of the transaction automatically, and the money settles on the Grin chain. Neither of you ever saw a slatepack.

<div class="shot-todo"><strong>Screenshot:</strong> Home tab with balance and the Pay puck (mobile 390×844, dark theme).</div>

## What makes that possible

Three things, each documented in depth in these pages:

- **A real Grin wallet underneath.** Goblin doesn't reimplement Grin; it [forks GRIM](../pillars/grim-base.md) and keeps its full node + wallet engine: seed and key management, chain sync, and the slatepack transaction state machine. Everything Goblin adds sits *on top* of an unmodified, audited wallet core.

- **Nostr as the courier.** The slatepack is wrapped as an [encrypted Nostr message](../pillars/nostr.md) and delivered through public relays. Relays buffer messages for wallets that are offline, so the exchange is asynchronous. Relays only ever see ciphertext, never the amount, the sender, or the recipient. Usernames are [NIP-05](../features/name-authority.md) identifiers like `alice@goblin.st`.

- **Nym for anonymity.** Every connection Goblin makes (relay sockets *and* every HTTP request for name lookups, price, avatars) is tunneled through the [Nym mixnet](../pillars/nym.md), a 5-hop anonymizing network. This hides your IP from relays and breaks the timing correlation that an interactive payment would otherwise leak at the network layer. **Nothing Goblin sends touches the clear net**, except the Grin node connection, which carries only public chain data and is deliberately kept direct.

## What stays the same as Grin

Goblin is still a self-custodial Grin wallet. Your funds are controlled by your seed phrase; your transactions are confidential Mimblewimble transactions; you can run your own node or use an external one. If you ever need to pay someone who isn't on Goblin, the classic by-hand slatepack flow is still there under **Settings → Wallet → Slatepacks**.

## Where to go next

- [Architecture: the three pillars](architecture.md): how the pieces connect.
- [The end-to-end payment flow](../features/payment-flow.md): follow one payment from tap to chain.
- [Nostr in Goblin](../pillars/nostr.md) and [Nym in Goblin](../pillars/nym.md): the layers that make it private.

## References

- Project README and banner: `goblin/README.md`.
- Crate metadata (package `grim`, binary `goblin`, fork base): `goblin/Cargo.toml`, `goblin/build.rs`.
- Grin / Mimblewimble: <https://grin.mw>, <https://github.com/mimblewimble/grin>.
