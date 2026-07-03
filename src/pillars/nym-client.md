# The in-process mixnet tunnel

> **Summary.** Goblin links the mixnet client directly and runs one process-lifetime **tunnel** (the `smolmix` crate) on a private tokio runtime: raw TCP over the mixnet to a public exit gateway. It's warmed up at app launch, gated on a real end-to-end liveness probe, health-checked for its whole life, and rebuilt on a fresh exit the moment the current one goes bad. Losing any one exit never takes the wallet down.

## Motivation

An earlier design ran Nym as a separate sidecar binary, then as an in-process SOCKS5 client. Both worked, but the SOCKS5 seam hid the thing that matters most on a money path: **whether the exit is actually carrying your traffic**. Some public exits accept the handshake and then silently deliver nothing; a wallet that shows "Connected" while blackholed is worse than one that shows "Connecting". The current tunnel design makes exit health observable and enforceable: bounded bootstraps, a liveness gate before a tunnel is ever used, and a watchdog that condemns and replaces a dead exit automatically.

## How it works

At startup `warm_up()` spawns a background thread that builds the tunnel on a dedicated tokio runtime and keeps both alive for the life of the process:

1. **Exit selection.** By default the tunnel auto-selects a public exit gateway from the network. A **preferred exit** (the anchor) can be configured with the `GOBLIN_NYM_IPR` environment variable, at runtime or baked in at build time (the only option on Android). Each selection cycle tries the anchor exactly once, then falls back to auto-select for every further attempt, and the next cycle tries the anchor again. Pin-only operation is deliberately impossible: a dead anchor costs seconds, never a lockout.
2. **Bounded bootstrap.** A single build attempt is capped at 20 seconds. A healthy bootstrap completes in a few seconds; a dead gateway pick would otherwise block for over a minute inside the SDK before the wallet could re-select.
3. **Liveness gate.** A freshly built tunnel must pass an end-to-end probe (a TCP connect through the tunnel to a stable public address) before it is published to the rest of the app. An exit that handshakes but never delivers data is re-selected immediately instead of blackholing every consumer.
4. **Health watchdog.** A published tunnel is watched with two signals: **relay reachability** (authoritative while a wallet's relay service is running: an exit whose relays stay unreachable past a grace period is condemned) and a cheap periodic **keepalive probe** (the backstop, and it keeps the exit session from idling out). Condemned exits are torn down and replaced with a fresh one, rate-limited by a minimum exit lifetime so a transient hiccup can never thrash into a reselect loop.

**Generations and readiness.** Every published tunnel gets a monotonically increasing generation number, and the Nostr client tags its relay-liveness reports with the generation it dialed on. `is_ready()` (cheap, safe to poll every UI frame) says the tunnel is up; `transport_ready()` is the authoritative "Connected over Nym" signal, true only when a relay is connected **and** subscribed on the *current* generation. A stale exit can never latch the UI green.

**Identity.** The tunnel uses ephemeral in-memory keys: a fresh mixnet identity per run, nothing persisted.

**Warm connect from cached choices.** The last entry gateway and preferred exit that worked are persisted across launches (only which ones were picked, never any key), and are tried first on the next cold start instead of re-running the auto-select lottery against a possibly-dead pick. Measured effect: cold connect to a ready tunnel drops from about 5.6 s to about 4.4 s. A cached choice that fails just clears itself and falls back to normal auto-select, so a stale hint can never cost more than one attempt.

**Throughput.** The tunnel's TCP buffers were raised from 8 KB to 256 KB and the mixnet packet burst from 1 to 64, lifting the bulk-transfer ceiling roughly 32x, so relay backfill and profile/JSON reads no longer crawl at a few KB/s. HTTP requests over the tunnel also reuse connections (keep-alive) instead of a fresh handshake per request, which is what made repeated price and username lookups slow before.

The tunnel is the **fallback and everything-else path**: discovery relays, secondary relays, HTTP, and DNS all ride it, and the money-path relay falls back to it whenever its [scoped exit](nym-exit.md) is unavailable.

> **Implementation footnote (TLS provider).** Linking Nym pulls in `aws-lc-rs` alongside Goblin's `ring`. With rustls 0.23 unable to auto-pick a default crypto provider, the first TLS handshake would panic. Goblin installs the ring provider explicitly at startup (`rustls::crypto::ring::default_provider().install_default()`). Worth knowing if you hack on the transport.

## Reference

In `goblin/src/nym/nymproc.rs`:

- `warm_up()`: idempotent background start; `run_tunnel()`: build/probe/publish/watch loop on a dedicated runtime.
- `is_ready()`, `transport_ready()`, `tunnel_generation()`, `report_relay_live()` / `report_relay_down()`, `set_relay_consumer()`: the readiness and liveness surface the Nostr client and the UI use.
- `ExitSelector` + `anchor_recipient()`: the prefer-with-fallback anchor policy (`GOBLIN_NYM_IPR`, runtime or baked via `option_env!`).
- Budgets: `BOOTSTRAP_TIMEOUT` (20 s, shared with the scoped-exit dial), `RELAY_GRACE` (25 s), `RELAY_HARD_GRACE` (90 s), `MIN_EXIT_LIFETIME` (20 s), keepalive every 60 s with 3 strikes.
- `wait_for_tunnel()`: lazy init for consumers; `tunnel()`: the shared handle (cheap clone).
- Cached gateway/exit hints: persisted in [config](../pillars/nostr-storage.md)-adjacent settings (`goblin/src/settings/config.rs`), self-clearing on failure.

## References

- The liveness probe and in-tunnel DNS: [DNS over the mixnet](nym-dns.md).
- Consumers: [Relay transport](nym-relay-transport.md), [HTTP](nym-http.md).
- The money-path egress that bypasses this tunnel: [The scoped relay exit](nym-exit.md).
- Nym SDK (Rust): <https://nym.com/docs/developers/rust>.
