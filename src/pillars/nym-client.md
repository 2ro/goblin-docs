# The embedded Tor client

> **Summary.** Goblin links Tor directly with [arti](https://tpo.pages.torproject.net/core/arti/) (Tor written in Rust) and runs one process-lifetime client, copied almost verbatim from our sister wallet [GRIM](grim-base.md)'s proven engine. It bootstraps at app launch, it's gated on a real end-to-end readiness signal before the UI ever shows "Connected," it's health-checked for its whole life, and a dead circuit is rebuilt automatically. Goblin only ever *dials* over Tor — it never hosts a service — which makes it simpler than GRIM, which also hosts an onion to receive.

## Motivation

Goblin's transport used to be the Nym mixnet, linked in-process. That path broke for reasons outside our control — Nym is removing the free bandwidth tier the wallet floated on (it's testnet scaffolding written to expire at UTC midnight, with public gateways moving to a paid, NYM-token model) — so a money wallet could not keep standing on it. See [Tor in Goblin](nym.md#why-tor-and-not-a-mixnet).

Rather than write our own Tor engine, Goblin **copies GRIM's**. GRIM's `src/tor/` is a small, four-file engine already running in production on desktop and Android, so Goblin inherits a known-good implementation instead of paying for one twice. Two technical choices come along verbatim because GRIM already settled them:

- **arti 0.43** across the whole arti family (`arti-client`, `tor-rtcompat`, and the onion/crypto crates).
- **The native-tls Tor runtime** (`TokioNativeTlsRuntime`), *not* rustls. This deliberately sidesteps the rustls crypto-provider (ring / aws-lc-rs) conflict we fought all through the Nym era. We take GRIM's TLS path and never re-open that wound.

## How it works

At startup `warm_up()` spawns a background task that bootstraps the Tor client on a dedicated runtime and keeps it alive for the life of the process:

1. **One bootstrap.** Tor is a *single* bootstrap — dramatically simpler than the mixnet path it replaces, which needed two mixnet clients racing each other for bandwidth grants plus a sequencer just to get connected. The bootstrap overlaps with app launch, so it's mostly invisible; warming the circuit at launch hides even the first-send edge.
2. **Onion dialing.** Once bootstrapped, the client opens circuits to the pinned `.onion` addresses for the [relay](nym-exit.md) and the [name authority](../features/name-authority.md), and Tor-to-clearnet circuits for the [small background lookups](nym-http.md). Goblin only connects *out*; it never publishes a service of its own.
3. **Readiness gate.** The UI refuses to show "Connected" until the transport is genuinely live: arti has bootstrapped, the onion circuit is up, **and** a required relay is actually subscribed on it. A pipe that opened but can't yet deliver never latches the UI green.
4. **Health and rebuild.** A live circuit is watched, and a circuit that dies is torn down and rebuilt automatically. The wallet's existing "the connection died, bring it back" logic and its background/foreground handling map cleanly onto Tor circuits.

**Readiness, in detail (preserved from the old transport).** The honest "carrying traffic on the *current* connection" signal is load-bearing and survives the swap intact. `warm_up()` starts the client idempotently; a cheap `is_ready()` (safe to poll every UI frame) says the client is up; and the authoritative `transport_ready()` is true only when a relay is connected **and** subscribed on the current circuit generation. A stale or half-open circuit can never falsely report "Connected over Tor." Only the mechanism's *target* changed — from a mixnet tunnel to a Tor circuit — not its semantics.

**Identity.** Circuits use fresh, ephemeral state; nothing about your Tor usage is persisted as a stable identity.

**Battery.** A persistent Tor circuit is lighter than a live mixnet client: there is no continuous cover-traffic machinery to run and no per-hop delay work to perform, so always-listening costs less.

## Mobile

**Android is solved** — GRIM already ships embedded Tor there and the recipe copies over. It comes down to two things: **arti compiles into the app's native library** (the same `.so` the rest of the Rust already lives in — no separate process), and a few environment variables are set **before the Rust runtime starts**. The critical one is `ARTI_FS_DISABLE_PERMISSION_CHECKS=true` (GRIM sets it in `MainActivity.java` before loading native code): arti's `fs-mistrust` layer normally refuses to start if its state directory has "too-open" Unix permissions, and Android's app sandbox always trips that check — so without this flag Tor simply never boots on a phone. It's a known one-line fix, not a research problem.

**iOS** should work — nothing about arti is Android-specific — but it is treated as unproven until we ship it, so it gets its own spike. Two things going in: iOS runs **plain Tor without pluggable-transport bridges** (the platform won't let an app spawn the helper processes those need, which is fine for reaching the relay), and the same `fs-mistrust` / state-directory questions get answered against iOS's sandbox.

## Reference

In `goblin/src/tor/` (copied from GRIM's `grim/src/tor/`, four files: `config.rs`, `mod.rs`, `tor.rs`, `types.rs`):

- `warm_up()`: idempotent background start; the bootstrap/dial/readiness/watch loop on a dedicated runtime.
- `is_ready()` / `transport_ready()`: the readiness surface the Nostr client and the UI use; `transport_ready()` is relay-gated on the current circuit generation.
- arti wiring: `TorClient` on the `TokioNativeTlsRuntime`, arti 0.43.
- Android bring-up: native-lib link + `ARTI_FS_DISABLE_PERMISSION_CHECKS=true` set in `MainActivity.java` before native code loads.

## References

- Onion name resolution and the (absence of a) DNS layer: [Name resolution under Tor](nym-dns.md).
- Consumers: [Relay transport](nym-relay-transport.md), [HTTP](nym-http.md).
- The money-path destination this client dials: [The relay's onion service](nym-exit.md).
- arti (Tor in Rust): <https://tpo.pages.torproject.net/core/arti/>.
