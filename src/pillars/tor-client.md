# The embedded Tor client

> **Summary.** Goblin links Tor directly with [arti](https://tpo.pages.torproject.net/core/arti/) (Tor written in Rust) and runs one process-lifetime client, copied almost verbatim from our sister wallet [GRIM](grim-base.md)'s proven engine. It bootstraps at app launch, it's gated on a real end-to-end readiness signal before the UI ever shows "Connected," it's health-checked for its whole life, and a dead circuit is rebuilt automatically. Goblin only ever *dials* over Tor — it never hosts a service — which makes it simpler than GRIM, which also hosts an onion to receive.

## Motivation

Goblin has to hide a phone's IP from the relays it talks to, and it has to do that on desktop and on a phone without shipping a separate helper process. Tor, embedded in-process, is built for exactly that. See [Tor in Goblin](tor.md#why-tor) for why it's the right fit.

Rather than write our own Tor engine, Goblin **copies GRIM's**. GRIM's `src/tor/` is a small, four-file engine already running in production on desktop and Android, so Goblin inherits a known-good implementation instead of paying for one twice. Two technical choices come along verbatim because GRIM already settled them:

- **arti 0.43** across the whole arti family (`arti-client`, `tor-rtcompat`, and the onion/crypto crates).
- **The native-tls Tor runtime** (`TokioNativeTlsRuntime`), *not* rustls. This deliberately sidesteps the rustls crypto-provider (ring / aws-lc-rs) conflict. We take GRIM's TLS path, which already settled it, and never re-open that wound.

## How it works

The client is only started when the active wallet has [Tor routing](tor.md#tor-routing-is-a-per-wallet-setting) on; a wallet running in clearnet mode never bootstraps Tor at all. When it is on, `warm_up()` spawns a background task that bootstraps the Tor client on a dedicated runtime and keeps it alive for the life of the process:

1. **One bootstrap.** Tor is a *single* bootstrap — one client, one connect. The bootstrap overlaps with app launch, so it's mostly invisible; warming the circuit at launch hides even the first-send edge.
2. **Exit dialing.** Once bootstrapped, the client opens Tor-exit circuits to the [relay](tor-exit.md) pool's clearnet hosts, the [name authority](../features/name-authority.md), and the [small background lookups](tor-http.md). Goblin only connects *out*; it never publishes a service of its own. (An earlier build also dialed a pinned relay `.onion` directly; that path was dropped in build134, see [The relay's Tor exit path](tor-exit.md).)
3. **Readiness gate.** The UI refuses to show "Connected" until the transport is genuinely live: arti has bootstrapped, the Tor circuit is up, **and** a required relay is actually subscribed on it. A pipe that opened but can't yet deliver never latches the UI green.
4. **Health and rebuild.** A live circuit is watched, and a circuit that dies is torn down and rebuilt automatically. The wallet's existing "the connection died, bring it back" logic and its background/foreground handling map cleanly onto Tor circuits.

**Readiness, in detail.** The honest "carrying traffic on the *current* connection" signal is load-bearing. `warm_up()` starts the client idempotently; a cheap `is_ready()` (safe to poll every UI frame) says the client is up; and the authoritative `transport_ready()` is true only when a relay is connected **and** subscribed on the current circuit generation. A stale or half-open circuit can never falsely report "Connected over Tor."

**Identity.** Circuits use fresh, ephemeral state; nothing about your Tor usage is persisted as a stable identity.

**Battery.** A persistent Tor circuit is cheap to keep alive: there is no continuous cover-traffic machinery to run and no per-hop delay work to perform, so always-listening costs little.

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

- Exit-side name resolution and the (absence of a) DNS layer: [Name resolution under Tor](tor-dns.md).
- Consumers: [Relay transport](tor-relay-transport.md), [HTTP](tor-http.md).
- The money-path destination this client dials: [The relay's Tor exit path](tor-exit.md).
- arti (Tor in Rust): <https://tpo.pages.torproject.net/core/arti/>.
