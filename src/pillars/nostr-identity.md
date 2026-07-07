# Identity (NIP-06 / NIP-49)

> **Summary.** Each wallet has a Nostr keypair that is its payment identity. The secret key is stored encrypted at rest ([NIP-49](https://nips.nostr.com/49) `ncryptsec`, owner-only file permissions). Crucially, this key is **separate from your Grin seed**, so you can rotate your identity to stay unlinkable without ever touching your funds. A wallet can also hold several identities at once, all listening together; see [Multiple identities](../features/identities.md).

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

**Starting a fresh, unlinkable key** does not need a dedicated rotate action, and the old one was removed: it was only a random add-and-switch that also released your name, adding nothing over the identity switcher. To present as a new independent key you add an identity (a random `Keys::generate` key, unlinkable to your seed and your other identities) and switch to it, all without re-seeding, so your Grin balance is untouched. Adding a new key does not carry your username or profile to it; to keep a name on a new key, transfer the name through the [authority](../features/name-authority.md). See [Multiple identities](../features/identities.md). The `prev_npubs` field still records keys a wallet has moved away from.

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Identity card (Copy npub, Back up to a file, and the identity switcher), dark theme.</div>

**Backup & restore.** As of Build 158 the **backup** (Settings → Advanced, under *Advanced nostr settings*, captioned *"Contains your wallet and all identities."*) writes one sealed, encrypted `.backup` file that holds **both** your Grin money seed **and** every identity the wallet holds, with the active one marked. One file now moves a whole wallet, funds and names together, so there is no longer a separate seed-phrase-plus-identity-file dance. Restoring it is a single step in [onboarding](../features/onboarding.md): the restore flow's *"Choose a .backup file"* picker takes the file, you unlock it with the wallet password, and it fills the 24-word recovery grid for you; once the wallet opens, the identities restore automatically (a *"Restoring your identities…"* card shows the progress). Older single-identity backups still restore: importing one adopts that one identity (name and history included), decrypting with its export-time password and re-encrypting under the new wallet's password.

**Logging in to other nostr apps.** **Settings → Advanced → Nostr key** reveals your `nsec` behind your wallet password: enter the password, then copy the key or show it as a QR. Scanning that QR (or pasting the copied `nsec`) into another nostr app's private-key login, for example [magick.market](https://magick.market), signs you in with the same identity your wallet uses. The key is derived on demand behind the password and never persisted in the clear; a wrong password reveals nothing.

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
