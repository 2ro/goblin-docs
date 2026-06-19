# The NIP-05 name authority

> **Summary.** Usernames like `alice@goblin.st` come from a small, self-hostable service (`goblin-nip05d`) that implements [NIP-05](https://nips.nostr.com/5) resolution and [NIP-98](https://nips.nostr.com/98)-authenticated registration. Goblin ships with `goblin.st` as the default authority, but it's **configurable**: anyone can run their own and Goblin can point at it (federation).

## Motivation

`npub1…` keys are unreadable. NIP-05 maps a friendly `name@domain` to a key over plain HTTPS, but the *registration* side (who gets a name, how squatting is prevented, how you prove you own a key) is not specified by NIP-05. `goblin-nip05d` is Goblin's answer: a tiny authority that hands out names, proves ownership with signed Nostr events (no passwords), and resists abuse, and which you can host yourself so Goblin isn't dependent on one operator.

## How it works

- **Resolution.** A wallet resolving `alice@goblin.st` fetches `https://goblin.st/.well-known/nostr.json?name=alice` (over the [mixnet](../pillars/nym-http.md)) and reads the pubkey (and any relay hints). A **reverse** lookup (name-by-pubkey) lets a wallet show the `name` for a key it only knows by `npub`.
- **Registration is keypair-authenticated.** Claiming or releasing a name is a [NIP-98](https://nips.nostr.com/98)-signed HTTP request: you prove control of the key, no account or password. The server enforces **one active name per pubkey**, a set of **reserved names** (and domain-label reservations), look-alike/homograph folding, a name length cap, and a change **cooldown** to stop churn/abuse. NIP-98 events are single-use within a freshness window (replay protection).
- **Transfer.** Rotating your key can carry your name with it: the old key authorizes a transfer to the new pubkey, so you keep `alice` after rotation.
- **Federation.** The authority is just a host. **Settings → Identity → Name authority** lets you change it; bare names then resolve against your chosen domain, and foreign `name@otherdomain` identifiers resolve against *their* domain. Goblin only auto-trusts its own domain's names; others pass through the [unverified-key gate](send-request.md).

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Identity → Name authority row (value <code>goblin.st</code>) and the claim-username panel, dark.</div>

## Reference

- **Client side** (`goblin/src/nostr/nip05.rs`): `split_identifier()` (parses `user@domain` or a bare `name`; a leading `@` the user happens to type is stripped), `is_valid_hostname()`, `resolve()`, `name_by_pubkey()` (reverse), `verify()`, `Nip05Check` (`Verified` / `Mismatch` / `Unreachable`); `set_home_domain()` / `home_domain()`; defaults `HOME_NIP05_DOMAIN = "goblin.st"`, `DEFAULT_NIP05_SERVER`.
- **Server side** (`goblin-nip05d/`, a sibling Axum + SQLite crate): the `.well-known/nostr.json` endpoint, `/api/v1` name availability / register / release / transfer / by-pubkey, NIP-98 auth, reserved names, cooldown. It bundles a stock `strfry` relay write-policy and is deployed at `goblin.st` but designed to be self-hosted.
- **UI**: claim/rotate/transfer flows in `goblin/src/gui/views/goblin/mod.rs` (`ClaimState`, `RotateState`, `NameAuthorityState`); availability mapped to friendly copy via `availability_feedback()`.

## References

- NIP-05 (DNS-based names): <https://nips.nostr.com/5>.
- NIP-98 (HTTP auth): <https://nips.nostr.com/98>.
- Self-hosting: [Run a name authority](../self-hosting/name-authority.md).
