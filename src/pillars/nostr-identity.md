# Identity (NIP-06 / NIP-49)

> **Summary.** Each wallet has a Nostr keypair that is its payment identity. The secret key is stored encrypted at rest ([NIP-49](https://nips.nostr.com/49) `ncryptsec`, owner-only file permissions). Crucially, this key is **separate from your Grin seed**, so you can rotate your identity to stay unlinkable without ever touching your funds. A wallet can also hold several identities at once, all listening together; see [Multiple identities](../features/identities.md).

## Motivation

Two design tensions shape Goblin's identity:

1. **Linkability.** If your payment identity were derived from your wallet seed, it would be permanent: every payment forever tied to one key. Goblin wants you to be able to start fresh. So the nostr key is independent and **rotatable**.
2. **Safety at rest.** The secret key sits on a phone. It must never be on disk in the clear, and the file must not be world-readable.

## How it works

Your identity lives in `wallet_data/nostr/identity.json`, written with Unix mode `0600` inside a `0700` directory. Inside, the secret key is a **NIP-49 `ncryptsec`**: a bech32 blob encrypted with your wallet password via scrypt (work factor `log_N = 16`, ~64 MiB, interactive grade). The file also stores your `npub` in the clear (so the UI can show "you" before you've unlocked), your `nip05` name if you've claimed one, an `anonymous` flag, and `prev_npubs`, a history of keys you've rotated away from.

**Changing the wallet password.** The Grin seed and every identity the wallet holds are encrypted with the same wallet password, and a password change moves them together or not at all. Before the seed moves, the wallet checks that every identity unlocks with the old password; if one doesn't, nothing changes. If the identities still fail to move after the seed did, the seed is moved back. A wallet that an earlier failed change (Build 168 or older) left split, seed on one password and identities on the other, repairs itself: change the password from the seed's password to the one the identities are on, and only the seed moves.

There are three ways an identity comes to exist (`IdentitySource`):

- **Random** *(default)*: a brand-new independent key (`Keys::generate`). Unlinkable to your seed and to any other wallet.
- **Imported**: you paste an `nsec` or restore an encrypted backup file, adopting an existing identity (name and history included).
- **Derived**: a [NIP-06](https://nips.nostr.com/06) seed-derived key. Kept for legacy wallets; new wallets use Random.

**Starting a fresh, unlinkable key** does not need a dedicated rotate action, and the old one was removed: it was only a random add-and-switch that also released your name, adding nothing over the identity switcher. To present as a new independent key you add an identity (a random `Keys::generate` key, unlinkable to your seed and your other identities) and switch to it, all without re-seeding, so your Grin balance is untouched. Adding a new key does not carry your username or profile to it; to keep a name on a new key, transfer the name through the [authority](../features/name-authority.md). See [Multiple identities](../features/identities.md). The `prev_npubs` field still records keys a wallet has moved away from.

<div class="shot-todo"><strong>Screenshot:</strong> Settings → Identity card (Copy npub, Back up to a file, and the identity switcher), dark theme.</div>

**Backup & restore.** As of Build 158 the **backup** (Settings → Advanced, under *Advanced nostr settings*, captioned *"Contains your wallet and all identities."*) writes one sealed, encrypted `.backup` file that holds **both** your Grin money seed **and** every identity the wallet holds, with the active one marked. One file now moves a whole wallet, funds and names together, so there is no longer a separate seed-phrase-plus-identity-file dance. Restoring it is a single step in [onboarding](../features/onboarding.md): the restore flow's *"Choose a .backup file"* picker takes the file, you unlock it with the wallet password, and it fills the 24-word recovery grid for you; once the wallet opens, the identities restore automatically (a *"Restoring your identities…"* card shows the progress). Older single-identity backups still restore: importing one adopts that one identity (name and history included), decrypting with its export-time password and re-encrypting under the new wallet's password. *"Backup saved"* appears only once the file has really been written to the place you picked; closing the save dialog returns you to the backup form, and a write that fails shows *"Couldn't save the file."*, so you are never told a backup exists when it doesn't.

**Logging in to other nostr apps.** **Settings → Advanced → Nostr key** reveals your `nsec` behind your wallet password: enter the password, then copy the key or show it as a QR. Scanning that QR (or pasting the copied `nsec`) into another nostr app's private-key login, for example [magick.market](https://magick.market), signs you in with the same identity your wallet uses. The key is derived on demand behind the password and never persisted in the clear; a wrong password reveals nothing. The same page can reveal your recovery phrase behind the password. A revealed key or phrase is hidden again as soon as you leave the page. A copied `nsec` (or a recovery phrase copied while setting up a wallet) is cleared from the clipboard after 45 seconds if the clipboard still holds it. On Android the copy is also marked sensitive, and if Goblin isn't in front when the 45 seconds pass, it is cleared when you come back to the app; while the page shows the phrase, the `nsec` or its QR, the screen is hidden from screenshots, screen recording and the Recents view.

## Reference

- `IdentitySource` enum and the `NostrIdentity` struct: `goblin/src/nostr/identity.rs`. Fields: `ncryptsec`, `npub`, `nip05`, `anonymous`, `prev_npubs`.
- Encryption at rest: NIP-49 `ncryptsec`, scrypt `NCRYPTSEC_LOG_N = 16`.
- File safety: `write_private()` (Unix `0600`), `restrict_dir()` (`0700`); stored at `wallet_data/nostr/identity.json`.
- Key derivation for the legacy `Derived` source: `derive_keys()` (NIP-06 BIP-44 path).
- Import/backup UI: identity import lives in the add sheet of the identity switcher (`IdentitySwitchState`, `goblin/src/gui/views/goblin/mod.rs:582`); the backup card is `BackupState` (`mod.rs:639`) drawn by `backup_ui()` (`goblin/src/gui/views/goblin/settings.rs:236`); onboarding import in `onboarding.rs` (`OnbImport`). The backup card reacts to the real save outcome (`SaveResult`: saved, cancelled, failed) in `apply_save_result()`, `goblin/src/gui/views/goblin/settings.rs:364`; `SaveResult` is in `goblin/src/gui/platform/mod.rs:112`.
- Password change: `Wallet::change_password()` (`goblin/src/wallet/wallet.rs:2440`), with the dry-run check `HeldIdentities::verify_all_unlock()` and the all-or-nothing `reencrypt_all()` (`goblin/src/nostr/identities.rs:407`, `:430`); the seed file is made owner-only (`0600`) again after every change, repair or rollback (`change_seed_password()`, `wallet.rs:2499`).
- Secrets on screen: the Advanced page state is dropped whenever the page is not drawn (`advanced_state_kept()`, `goblin/src/gui/views/goblin/mod.rs:309`); the secure-screen flag follows `secret_shown()` (`mod.rs:299`, set at `mod.rs:850`), the onboarding words and confirm steps (`onboarding.rs:217`) and the wallet-creation word grids (`goblin/src/gui/views/wallets/content.rs:410`); Android applies it as `FLAG_SECURE` (`MainActivity.setSecureScreen`, `MainActivity.java:826`).
- Copying a secret: `copy_secret_to_buffer()` (callers: the `nsec` copy, `goblin/src/gui/views/goblin/settings_advanced.rs:267`; the onboarding phrase copy, `onboarding.rs:676`; the wallet-creation phrase copy, `goblin/src/gui/views/wallets/creation/content.rs:237`); Android `MainActivity.copySecretText()` and `clearSecretClipIfDue()` (`MainActivity.java:552`, `:580`; 45 s TTL at `:87`); desktop clears after `CLIPBOARD_SECRET_TTL_SECS = 45` (`goblin/src/gui/platform/desktop/mod.rs:30`).

## References

- NIP-06 (key derivation from mnemonic): <https://nips.nostr.com/6>.
- NIP-19 (`npub`/`nsec`/`nprofile` bech32): <https://nips.nostr.com/19>.
- NIP-49 (encrypted secret key): <https://nips.nostr.com/49>.
- Identity is deliberately *not* the Grin seed; see [GRIM base](grim-base.md) and [project rationale in the wallet README](../overview/what-is-goblin.md).
