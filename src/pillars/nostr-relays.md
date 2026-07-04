# Relays

> **Summary.** Relays are the public servers that carry Goblin's encrypted messages. Goblin ships a **candidate pool** of vetted relays, verifies each one locally before use, advertises a short DM-relay list ([NIP-17](https://nips.nostr.com/17) `kind 10050`) so others know where to reach you, and lets you edit the list. All relay traffic runs over [Tor](nym.md), and the primary relay is reached at its pinned [`.onion`](nym-exit.md).

## Motivation

Nostr has no central server: reachability depends on sender and receiver sharing at least one relay. So a wallet must (a) start with good defaults, (b) publish where it listens, and (c) let advanced users or self-hosters point at their own relays. Keeping the DM-relay list small is deliberate: NIP-17 guidance is to advertise only a couple, both to limit metadata and to make delivery predictable. And because a bad relay can silently drop a payment message, every candidate is verified by the wallet itself before it's trusted with one.

## How it works

- **Defaults.** Out of the box Goblin advertises the relay the project operates (`relay.floonet.dev`) plus up to two relays drawn from the candidate pool below. It is a [Floonet](https://docs.floonet.dev) relay (the floonet-strfry package: stock [strfry](https://github.com/hoytech/strfry) with a write policy restricting stored kinds to the handful Goblin needs), and its pool entry advertises the operator's [Tor onion service](nym-exit.md), so the money path needs no public DNS. The previous default, `relay.goblin.st`, is retired on **2026-07-04**: wallets that still pin it keep working until then, and new wallets never see it.
- **Advertising reachability.** Your wallet publishes a `kind 10050` DM-relay list (capped at 3) so a sender's wallet knows which relays to deliver your payment to. The same event carries an `encryption` tag advertising the wallet's [NIP-44 v3 capability](nostr-protocol.md#encryption-nip-44-v3-with-v2-fallback). The list is also fanned out, publish-only, to the pool's *discovery* indexers so a payer who shares no relay with you can still find your inbox list. `nprofile` shares carry relay hints too, so a fresh recipient is reachable without any lookup.
- **Selection is sticky.** The advertised set is picked once and persisted; there is no timer rotation, because churning a `kind 10050` list breaks payers' cached routing.
- **Editing.** **Settings → Nostr Relays** shows your list and lets you add `wss://…` relays (URLs are normalized: a bare host gets `wss://`). "Save & reconnect" rewrites your `kind 10050` and restarts the [service](nostr-service.md) on the new set. A user-edited list disables automatic selection entirely.

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Nostr Relays editor (list + add field + Save & reconnect), dark theme.</div>

> **Note on the UI:** the relay editor lives in the **Identity** section of Settings, labelled **"Nostr Relays"** (it sits just above *Name authority*), so it's clear these are Nostr relays, distinct from the Grin *Node* connection under Wallet.

### The candidate pool

The pool is a maintained list of vetted public relays, fetched from the project's published pool file **over Tor**, cached on disk, and refreshed when the cache is older than 7 days. A pinned copy is compiled into the app, byte-for-byte the published contents, so first-run and offline behave exactly like a fresh fetch.

Each entry carries:

- **Roles**: `dm` (eligible to carry gift-wrapped payments) and/or `discovery` (an indexer that only ever receives the public identity events, never a wrap).
- **A vetted date**: vetted entries are weighted 3:1 when the advertised set is drawn.
- **Optionally, an `onion`**: the `.onion` address of that operator's [Tor onion service](nym-exit.md). The pinned pool carries one for `relay.floonet.dev`.

A pool relay is only ever used after passing a **NIP-11 gate**, checked lazily right before use (results cached for 24 hours): it must accept messages of at least 128 KiB (a worst-case payment wrap is ~66 KB on the wire), must not require payment, AUTH, or restricted writes, and must tolerate [NIP-59](https://nips.nostr.com/59)'s up-to-2-day backdated timestamps. The NIP-11 fetch itself runs over Tor.

The fetched pool file is validated locally (schema version, entry caps) and can only *raise* the message-size floor, never lower it; and since every relay is still individually gated by your own wallet's probe, a broken or hostile pool file degrades to the pinned defaults rather than being trusted.

## Reference

- `goblin/src/nostr/pool.rs`: `RelayPool` / `PoolRelay` (the `onion` field), `PINNED_POOL`, `load()` / `refresh_if_stale()`, the NIP-11 gate (`nip11_pass()`, `probe()`), `weighted_order()`, `usable_discovery_relays()`, `MIN_MESSAGE_LENGTH = 131072`.
- `goblin/src/nostr/relays.rs`: `DEFAULT_RELAYS`, `MAX_DM_RELAYS = 3`, `normalize_relay_url()`; default name authority constants (`HOME_NIP05_DOMAIN`, `DEFAULT_NIP05_SERVER`).
- Advertised-set selection and the discovery fan-out: `ensure_advertised_set()` and `publish_identity()` in `goblin/src/nostr/client.rs`.
- Editor + "Save & reconnect": the relays page in `goblin/src/gui/views/goblin/mod.rs` (`SettingsPage::Relays`, `relay_summary()`); the row that opens it is the **Nostr Relays** entry in the Identity card.
- Relay transport: every socket runs over [Tor](nym-relay-transport.md).

## References

- NIP-17 DM relays (`kind 10050`): <https://nips.nostr.com/17>.
- NIP-65 relay lists (`kind 10002`): <https://nips.nostr.com/65>.
- NIP-11 relay information documents: <https://nips.nostr.com/11>.
- Running your own: [Run a relay](../self-hosting/relay.md).
