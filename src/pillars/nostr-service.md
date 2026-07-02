# The NostrService relay thread

> **Summary.** `NostrService` is the long-running, per-wallet engine that connects to relays (over [Nym](nym.md)), publishes payment messages, watches for incoming ones, and exposes send progress to the UI. Each open wallet has its own service and its own relay pool; there is no global connection.

## Motivation

A wallet that pays by message needs a persistent worker: something that keeps relay sockets alive, subscribes for gift wraps addressed to you, runs the send pipeline off the UI thread, and survives for the life of the open wallet. Bundling that into one owned object (started on `Wallet::open`, stopped on `Wallet::close`) keeps the relay lifecycle tied to the wallet lifecycle and keeps per-wallet state (keys, rate limits, send status) isolated.

## How it works

When a wallet opens with Nostr enabled, it spawns a `NostrService` on a dedicated tokio runtime. The service:

- **Holds the decrypted keys** in memory only (never re-serialized to disk) and builds a `nostr-sdk` client whose relay transport is the [Nym websocket transport](nym-relay-transport.md), so every relay socket runs over the mixnet.
- **Subscribes** for `kind 1059` gift wraps addressed to your key, with a **3-day lookback** (NIP-59 randomizes timestamps up to ~2 days into the past, so the window must be generous). Incoming events flow into the [ingest policy](nostr-ingest.md).
- **Runs the send pipeline**: build rumor → seal → gift wrap → publish to *your* relays and the recipient's DM relays. Progress is published to the UI through an atomic `send_phase` (`IDLE → WORKING → SENT / FAILED`, plus `REQUEST_BLOCKED`), with a human-readable reason on failure.
- **Rate-limits incoming senders** to blunt spam: a known **contact** may send ~30 events/hour, an **unknown** key ~10/hour.
- **Re-verifies names** on a rolling basis (a few contacts per tick, on a periodic heartbeat) so a contact whose `name` was reassigned or released is caught.
- **Reports relay liveness to the transport layer**: the service tells the [Nym tunnel](nym-client.md) which exit generation its relays are connected on, which both drives the honest "Connected over Nym" indicator and lets the tunnel's watchdog condemn an exit that can't carry relay traffic.
- **Serializes cancel vs. finalize** with a lock, so a user-initiated cancel can't race a concurrent auto-finalize of the same slate.

It also answers one-shot queries the UI needs: `fetch_profile_blocking()` (pull a `kind 0` profile to verify a pasted key), `nprofile()` (your shareable [NIP-19](https://nips.nostr.com/19) profile with relay hints), and `nsec()` (plaintext key for an explicit user backup only).

## Reference

In `goblin/src/nostr/client.rs`:

- `NostrService` struct: `keys`, `client` (relay pool), `rt_handle`, `connected`, per-sender `rate` map, `send_phase` (atomic) + `last_send_error`, `cancel_finalize_lock`.
- `send_phase` constants: `IDLE=0`, `WORKING=1`, `SENT=2`, `FAILED=3`, `REQUEST_BLOCKED=4`.
- One-shots: `public_key()`, `nprofile()`, `nsec()`, `keys()`, `fetch_profile_blocking()`.
- Lifecycle hooks: `Wallet::open` / `close` / `start_sync` in `goblin/src/wallet/wallet.rs`; jobs arrive as `WalletTask::Nostr*`.
- Relay transport: [`NymWebSocketTransport`](nym-relay-transport.md) (`goblin/src/nym/transport.rs`).

## References

- The send pipeline end to end: [The payment flow](../features/payment-flow.md).
- What the service *accepts*: [Ingest policy](nostr-ingest.md).
- NIP-65 relay lists (`kind 10002`) and NIP-17 DM relays (`kind 10050`): [Relays](nostr-relays.md).
