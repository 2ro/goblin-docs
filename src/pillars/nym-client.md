# The in-process mixnet client

> **Summary.** Goblin links the Nym SDK directly and runs its SOCKS5 mixnet client on a private tokio runtime, exposing the mixnet at `127.0.0.1:1080`. It's warmed up at app launch so the network is ready by the time you open a wallet. There is no subprocess and no bundled binary.

## Motivation

An earlier design ran Nym as a separate `nym-socks5-client` **sidecar** binary, bundled per platform and launched as a subprocess. That worked but meant shipping and managing native binaries (especially awkward on Android). Once a dependency conflict that had blocked linking the SDK was resolved, Goblin moved the client **in-process**: simpler to ship (one binary), simpler to reason about, and a cleaner lifecycle. The SOCKS5 model was kept (rather than a bespoke peer-to-peer bridge) so Goblin interoperates with *any* relay and *any* NIP-05 host through a standard mixnet exit.

## How it works

At startup `warm_up()` spawns a background thread:

1. If something is already listening on `127.0.0.1:1080` (e.g. an externally-run client), it's **reused** as-is.
2. Otherwise the in-process client is built on a dedicated multi-threaded tokio runtime and started. It connects to the mixnet via SOCKS5, pointed at a **network requester** (the mixnet exit). Typical readiness is ~2 seconds.

A cheap, cached `is_ready()` flag (an atomic, safe to poll every UI frame) tells the rest of the app when the proxy is up, distinct from a relay actually being connected. The client (and its runtime) is held open for the whole process lifetime.

**Persistence.** The client's identity and chosen gateway are stored under `~/.goblin/nym`, so the gateway is picked once and reused across launches, which cuts cold-start time. If there's no home directory, it falls back to ephemeral in-memory keys.

**The network requester** is a baked-in default address, overridable at runtime with the `GOBLIN_NYM_PROVIDER` environment variable. Self-hosters can run their own requester (see [Run a Nym network requester](../self-hosting/nym-requester.md)) for reliability.

> **Implementation footnote (TLS provider).** Linking Nym pulls in `aws-lc-rs` alongside Goblin's `ring`. With rustls 0.23 unable to auto-pick a default crypto provider, the first TLS handshake would panic. Goblin installs the ring provider explicitly at startup (`rustls::crypto::ring::default_provider().install_default()`), with `rustls` built with the `ring` feature. Worth knowing if you hack on the transport.

## Reference

In `goblin/src/nym/sidecar.rs`:

- `warm_up()`: background start / reuse; `is_ready()` + `MIXNET_READY` atomic; `port_open()` TCP probe of `:1080`.
- `run_client()`: builds the tokio runtime, starts the SOCKS5 client, holds it open with `std::future::pending()`.
- `build_client()`: persistent storage (`StoragePaths` under `~/.goblin/nym`) vs. ephemeral; `Socks5MixnetClient` via `MixnetClientBuilder`.
- `NETWORK_REQUESTER` constant + `GOBLIN_NYM_PROVIDER` override (`provider()`).
- Warm-up is kicked off from app start (desktop `main.rs` and Android entry) so the mixnet is ready before wallet open.

## References

- The constants (`SOCKS5_HOST`, `SOCKS5_PORT = 1080`) and proxy helpers: `goblin/src/nym/mod.rs`.
- Consumers: [Relay transport](nym-relay-transport.md), [HTTP](nym-http.md).
- Nym SDK (Rust): <https://nym.com/docs/developers/rust>.
