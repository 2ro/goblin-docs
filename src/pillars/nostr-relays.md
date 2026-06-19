# Relays

> **Summary.** Relays are the public servers that carry Goblin's encrypted messages. Goblin ships sensible defaults, advertises a short DM-relay list ([NIP-17](https://nips.nostr.com/17) `kind 10050`) so others know where to reach you, and lets you edit the list. All relay traffic runs over the [Nym mixnet](nym.md).

## Motivation

Nostr has no central server: reachability depends on sender and receiver sharing at least one relay. So a wallet must (a) start with good defaults, (b) publish where it listens, and (c) let advanced users or self-hosters point at their own relays. Keeping the DM-relay list small is deliberate: NIP-17 guidance is to advertise only a couple, both to limit metadata and to make delivery predictable.

## How it works

- **Defaults.** Out of the box Goblin uses a small set: a relay it operates (`relay.goblin.st`) plus large public relays (`relay.damus.io`, `nos.lol`). The Goblin relay is a stock [strfry](https://github.com/hoytech/strfry) with a write policy restricting stored kinds to the handful Goblin needs (profiles, relay lists, gift wraps).
- **Advertising reachability.** Your wallet publishes a `kind 10050` DM-relay list (capped at 3) so a sender's wallet knows which relays to deliver your payment to. `nprofile` shares carry relay hints too, so a fresh recipient is reachable without any lookup.
- **Editing.** **Settings → Nostr Relays** shows your list and lets you add `wss://…` relays (URLs are normalized: a bare host gets `wss://`). "Save & reconnect" rewrites your `kind 10050` and restarts the [service](nostr-service.md) on the new set.

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Nostr Relays editor (list + add field + Save & reconnect), dark theme.</div>

> **Note on the UI:** the relay editor now lives in the **Identity** section of Settings, labelled **"Nostr Relays"** (it sits just above *Name authority*), so it's clear these are Nostr relays, distinct from the Grin *Node* connection under Wallet.

## Reference

- `goblin/src/nostr/relays.rs`: `DEFAULT_RELAYS`, `MAX_DM_RELAYS = 3`, `normalize_relay_url()`; default name authority constants (`HOME_NIP05_DOMAIN`, `DEFAULT_NIP05_SERVER`).
- Editor + "Save & reconnect": the relays page in `goblin/src/gui/views/goblin/mod.rs` (`SettingsPage::Relays`, `relay_summary()`); the row that opens it is the **Nostr Relays** entry in the Identity card.
- Relay transport: every socket runs over [`NymWebSocketTransport`](nym-relay-transport.md).

## References

- NIP-17 DM relays (`kind 10050`): <https://nips.nostr.com/17>.
- NIP-65 relay lists (`kind 10002`): <https://nips.nostr.com/65>.
- Running your own: [Run a relay](../self-hosting/relay.md).
