# Storage, config & types

> **Summary.** Goblin keeps a small per-wallet archive of Nostr metadata (transaction context, contacts, requests, processed-event markers) in an embedded key-value store, and a per-wallet config file for relay list, accept policy, and timeouts. These join to the GRIM wallet's own transaction log to produce the Activity feed.

## Motivation

Grin's wallet log knows about *transactions*; it knows nothing about *who* you paid by username, the note you attached, or which request is still pending. Goblin needs a side-archive for that nostr-shaped context, plus a record of which events it has already processed (so it doesn't replay them), all scoped to the wallet so nothing leaks between wallets.

## How it works

### The metadata store

A per-wallet [rkv](https://docs.rs/rkv) (SafeMode/LMDB) archive at `wallet_data/nostr.rkv`, holding:

- **`tx_meta`**: nostr context for a slate (counterparty `npub`, direction, note, status, the gift-wrap/rumor event ids, timestamps), keyed by slate id and joined to the GRIM tx log.
- **`contacts`**: people you've paid or saved (petname, `nip05` + when last verified, DM relays, avatar hue, a `blocked` flag, and an `unknown` flag for keys auto-added from an incoming payment).
- **`requests`**: incoming/outgoing payment requests by rumor id.
- **`processed`**: event/rumor ids already handled, with slate state, pruned after **30 days** (replay + dedup guard).

### Per-wallet config

A `nostr.toml` (`NostrConfig`) holding: `enabled`, `relays` override, `accept_from` (`Everyone` *default* / `Contacts` / `Ask`), `nip05_server` (your [name authority](../features/name-authority.md), which also yields `home_domain()` for federation), `expiry_secs` (auto-cancel an unanswered payment, default 24 h), `cancel_grace_secs` (how long before the [cancel button](../features/cancel-decline.md) appears, default 10 min), and `allow_incoming_requests` (opt-out of Invoice-1, advertised in your `kind 0`).

### The types

`types.rs` defines the vocabulary the rest of the layer speaks:

- `NostrTxDirection`: `Sent`, `Received`, `RequestedByUs`, `RequestedOfUs`.
- `NostrSendStatus`: the slate state machine: `Created`, `AwaitingS2`, `RepliedS2`, `AwaitingI2`, `PaidAwaitingFinalize`, `Finalized`, `SendFailed`, `Cancelled`, …
- `TxNostrMeta`, `Contact`, `PaymentRequest`, `RequestStatus`, `CancelOutcome`.

## Reference

- Store: `goblin/src/nostr/store.rs`: rkv SafeMode, the named databases above, 30-day TTL on `processed`. (Note: the env is opened with extra capacity so reopening a full set of DBs doesn't panic, a fix recorded in the wallet history.)
- Config: `goblin/src/nostr/config.rs`: `AcceptPolicy`, `NostrConfig`, `load()/save()`, `home_domain()`.
- Types: `goblin/src/nostr/types.rs`: directions, statuses, `TxNostrMeta`, `Contact`, `PaymentRequest`.

## References

- How statuses drive acceptance: [Ingest policy](nostr-ingest.md).
- How `tx_meta` + the GRIM log become the feed: [Send & request](../features/send-request.md) and `goblin/src/gui/views/goblin/data.rs`.
