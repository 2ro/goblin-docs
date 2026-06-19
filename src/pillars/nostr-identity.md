# Identity (NIP-06 / NIP-49)

> **Summary.** Each wallet has a Nostr keypair that is its payment identity. The secret key is stored encrypted at rest ([NIP-49](https://nips.nostr.com/49) `ncryptsec`, owner-only file permissions). Crucially, this key is **separate from your Grin seed**, so you can rotate your identity to stay unlinkable without ever touching your funds.

## Motivation

Two design tensions shape Goblin's identity:

1. **Linkability.** If your payment identity were derived from your wallet seed, it would be permanent: every payment forever tied to one key. Goblin wants you to be able to start fresh. So the nostr key is independent and **rotatable**.
2. **Safety at rest.** The secret key sits on a phone. It must never be on disk in the clear, and the file must not be world-readable.

## How it works

Your identity lives in `wallet_data/nostr/identity.json`, written with Unix mode `0600` inside a `0700` directory. Inside, the secret key is a **NIP-49 `ncryptsec`**: a bech32 blob encrypted with your wallet password via scrypt (work factor `log_N = 16`, ~64 MiB, interactive grade). The file also stores your `npub` in the clear (so the UI can show "you" before you've unlocked), your `nip05` name if you've claimed one, an `anonymous` flag, and `prev_npubs`, a history of keys you've rotated away from.

There are three ways an identity comes to exist (`IdentitySource`):

- **Random** *(default)*: a brand-new independent key (`Keys::generate`). Unlinkable to your seed and to any other wallet.
- **Imported**: you paste an `nsec` or restore an encrypted backup file, adopting an existing identity (name and history included).
- **Derived**: a [NIP-06](https://nips.nostr.com/06) seed-derived key. Kept for legacy wallets; new wallets use Random.

**Rotation** generates (or imports) a new key, releases your old name from the [authority](../features/name-authority.md), records the old `npub` in `prev_npubs`, and restarts the relay service under the new key, all without re-seeding, so your Grin balance is untouched.

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Identity card (Copy npub, Back up to a file, Rotate nostr key, Import identity), dark theme.</div>

**Backup & restore.** "Back up to a file" exports the whole identity (encrypted key + name + history) as one sealed JSON file. Importing it on a new device decrypts with the export-time password and re-encrypts under the new wallet's password, so moving devices preserves your username and history. (Moving a wallet needs *both* backups: the seed phrase for funds, and the identity file for your name + key.)

## Reference

- `IdentitySource` enum and the `NostrIdentity` struct: `goblin/src/nostr/identity.rs`. Fields: `ncryptsec`, `npub`, `nip05`, `anonymous`, `prev_npubs`.
- Encryption at rest: NIP-49 `ncryptsec`, scrypt `NCRYPTSEC_LOG_N = 16`.
- File safety: `write_private()` (Unix `0600`), `restrict_dir()` (`0700`); stored at `wallet_data/nostr/identity.json`.
- Key derivation for the legacy `Derived` source: `derive_keys()` (NIP-06 BIP-44 path).
- Rotation/import/backup UI: `RotateState` / `ImportState` / `BackupState` flows in `goblin/src/gui/views/goblin/mod.rs`; onboarding import in `onboarding.rs` (`OnbImport`).

## References

- NIP-06 (key derivation from mnemonic): <https://nips.nostr.com/6>.
- NIP-19 (`npub`/`nsec`/`nprofile` bech32): <https://nips.nostr.com/19>.
- NIP-49 (encrypted secret key): <https://nips.nostr.com/49>.
- Identity is deliberately *not* the Grin seed; see [GRIM base](grim-base.md) and [project rationale in the wallet README](../overview/what-is-goblin.md).
