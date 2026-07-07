# The NIP-05 name authority

> **Summary.** Usernames like `alice@goblin.st` come from a small, self-hostable service (`goblin-nip05d`) that implements [NIP-05](https://nips.nostr.com/5) resolution and [NIP-98](https://nips.nostr.com/98)-authenticated registration. Goblin ships with `goblin.st` as the default authority, but it's **configurable**: anyone can run their own and Goblin can point at it (federation). The standalone `goblin-nip05d` is the original minimal edition; the same name service is now bundled into the Floonet relay packages, which run it alongside a relay or on its own (see [Run a name authority](../self-hosting/name-authority.md)).

## Motivation

`npub1…` keys are unreadable. NIP-05 maps a friendly `name@domain` to a key over plain HTTPS, but the *registration* side (who gets a name, how squatting is prevented, how you prove you own a key) is not specified by NIP-05. `goblin-nip05d` is Goblin's answer: a tiny authority that hands out names, proves ownership with signed Nostr events (no passwords), and resists abuse, and which you can host yourself so Goblin isn't dependent on one operator.

## How it works

- **Resolution.** A wallet resolving `alice@goblin.st` fetches `https://goblin.st/.well-known/nostr.json?name=alice` (over [Tor](../pillars/tor-http.md), via a Tor-exit circuit to `goblin.st`'s clearnet host) and reads the pubkey (and any relay hints). A **reverse** lookup (name-by-pubkey) lets a wallet show the `name` for a key it only knows by `npub`.
- **Registration is keypair-authenticated.** Claiming or releasing a name is a [NIP-98](https://nips.nostr.com/98)-signed HTTP request: you prove control of the key, no account or password. The server enforces **one active name per pubkey**, a set of **reserved names** (and domain-label reservations), look-alike/homograph folding, a name length cap, and a change **cooldown** to stop churn/abuse. NIP-98 events are single-use within a freshness window (replay protection).
- **Transfer.** Rotating your key can carry your name with it: the old key authorizes a transfer to the new pubkey, so you keep `alice` after rotation. Selling a name to *someone else* is a separate, payment-verified flow: see [Name marketplace](name-marketplace.md).
- **Federation.** The authority is just a host. **Settings → Username** is the single home for everything name-related, and it leads with the name authority: the page opens with the authority you are pointed at, and claim or release sits below it. Leave it as the default `goblin.st`, pick another instance from the known list, or free-type a custom server's URL. Point it at another instance and bare names then resolve against that domain, and foreign `name@otherdomain` identifiers resolve against *their* domain. Goblin only auto-trusts its own domain's names; others pass through the [unverified-key gate](send-request.md). The Username page carries a one-line authority note with a **Learn more** link that opens this chapter.

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Username, name authority on top (value <code>goblin.st</code>, custom field) with the claim / release panel below, dark.</div>

## Reference

- **Client side** (`goblin/src/nostr/nip05.rs`): `split_identifier()` (parses `user@domain` or a bare `name`; a leading `@` the user happens to type is stripped), `is_valid_hostname()`, `resolve()`, `name_by_pubkey()` (reverse), `verify()`, `Nip05Check` (`Verified` / `Mismatch` / `Unreachable`); `set_home_domain()` / `home_domain()`; defaults `HOME_NIP05_DOMAIN = "goblin.st"`, `DEFAULT_NIP05_SERVER`.
- **Server side** (`goblin-nip05d/`, a sibling Axum + SQLite crate): the `.well-known/nostr.json` endpoint, `/api/v1` name availability / register / release / transfer / by-pubkey, NIP-98 auth, reserved names, cooldown. It bundles a stock `strfry` relay write-policy and is deployed at `goblin.st` but designed to be self-hosted.
- **UI**: the **Username** settings page (`SettingsPage::Username`, `username_ui()`) is the single home for claim, release, and choosing the authority (known list plus a free-typed custom server); the old inline name-authority editor and the main-settings claim card were removed. Claim/transfer flows in `goblin/src/gui/views/goblin/mod.rs` (`ClaimState`); availability mapped to friendly copy via `availability_feedback()`. The one-line authority note links out via `goblin.username.learn_more` to this chapter.

## References

- NIP-05 (DNS-based names): <https://nips.nostr.com/5>.
- NIP-98 (HTTP auth): <https://nips.nostr.com/98>.
- Selling and buying names: [Name marketplace](name-marketplace.md).
- Self-hosting: [Run a name authority](../self-hosting/name-authority.md).
