# Run a mixnet exit

> **Summary.** Goblin leaves the mixnet through an **exit**, and there are two kinds. The shared [tunnel](../pillars/nym-client.md) uses a **public exit gateway**, auto-selected by default; you can run one and tell wallets to prefer it with a single environment variable. The money-path relay is additionally reachable through a **scoped exit** co-located with the relay, advertised in the relay pool; both [Floonet](https://docs.floonet.dev) relay packages bundle one behind a config toggle.

## Motivation

The exit is the last mixnet hop before your traffic reaches a relay or an HTTPS host. Operating your own means your community's payments don't depend on a third party's exit, and you can keep it next to the relay and name authority you also run. Whichever exit carries the traffic, TLS is negotiated end to end against the destination hostname, so an exit only ever sees ciphertext.

## The public exit (the tunnel's anchor)

By default the tunnel **auto-selects** a public exit gateway and re-selects whenever the current one goes bad, so there is no single exit to depend on. To prefer an exit you operate:

1. Run a Nym exit gateway (a `nym-node` in exit-gateway mode, which includes the IP packet router the tunnel targets), per the Nym operator docs.
2. Point wallets at it with `GOBLIN_NYM_IPR=<recipient address>`, either at runtime or baked in at build time (the only way to configure it on Android). Setting it empty disables a baked-in anchor.

The preference is anchor + fallback: each selection cycle tries your exit first and falls back to auto-select on any failure, so a dead anchor costs seconds, never a lockout. An invalid address is ignored with a warning (pure auto-select). Pin-only operation is deliberately impossible.

## The scoped relay exit (the money path)

A relay operator can additionally run a tiny **scoped** exit next to their relay: it holds an ordinary, unbonded Nym client identity (no bonding, no NYM tokens) and pipes mixnet streams to that one relay and nowhere else, so it is not an open proxy and needs no exit policy. Wallets learn its address from the `exit` field of the relay's entry in the [candidate pool](../pillars/nostr-relays.md#the-candidate-pool) and prefer it automatically, falling back to the tunnel whenever it's down. The wallet-side behavior is documented in [The scoped relay exit](../pillars/nym-exit.md).

The packaging is published: both [Floonet relay packages](https://docs.floonet.dev) bundle the exit behind a single toggle (`COMPOSE_PROFILES=exit` for floonet-strfry, `[exit] enabled = true` for floonet-rs). Flip it on, publish the exit's mixnet address from `nym_address.txt`, and wallets that learn it from the relay pool dial your relay straight over the mixnet. The first production deployment is the one serving `relay.floonet.dev`, Goblin's default money-path relay.

## Reference

- Anchor consumption: `goblin/src/nym/nymproc.rs` (`GOBLIN_NYM_IPR`, `anchor_recipient()`, the `ExitSelector` prefer-with-fallback policy).
- Scoped-exit dialing: `goblin/src/nym/streamexit.rs`; advertisement: `goblin/src/nostr/pool.rs` (`PoolRelay::exit`).

## References

- Nym operator docs: <https://nym.com/docs/operators>.
- The tunnel that uses the public exit: [The in-process mixnet tunnel](../pillars/nym-client.md).
- The wallet side of the scoped exit: [The scoped relay exit](../pillars/nym-exit.md).
