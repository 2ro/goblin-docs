# Multiple identities

> **Summary.** One wallet can hold several identities at once (up to 8). They all share the same Grin seed and the same balance: an identity is a front door, not a separate pot of money. While the wallet is open every identity listens at the same time, so you can receive on all of them simultaneously, and switching which one you present as is instant, with no password and no re-sync.

## Motivation

One person is often several "yous". A seller on [magick.market](https://magick.market) taking payments is not the same face as the personal identity that pays friends, and neither should be linkable to the other. Before this feature the choices were rotation (which retires the old identity) or a second wallet (which splits your funds). Holding many identities in one wallet keeps a single balance while each context gets its own name, its own payment history, and no public connection to the rest.

## How it works

**One wallet, many identities, one balance.** The wallet still has exactly one recovery phrase and one balance. Identities are how people reach you and how you sign, not where the money lives, so adding or removing an identity never moves or risks funds.

**All listening at once.** Unlocking the wallet unlocks every held identity together, and one relay subscription listens for payments to all of them simultaneously. A payment to your seller identity lands even while you are sending as your personal one, and the transaction details show which identity was paid.

**Instant switching.** Switching just changes which identity you present and send as. No password, no syncing, no waiting: the keys were already unlocked when the wallet opened, so the switch is a pointer move.

**Adding an identity.** Three ways in, matching the import options elsewhere in the app:

- **Generate**: a brand-new anonymous key, unlinkable to your seed and to your other identities.
- **Import a backup**: restore an identity `.backup` file (name and history included).
- **Paste an `nsec`**: adopt an existing key directly.

**Private tags.** You can rename any identity with a local tag ("shop", "friends"). The tag lives only on your device and is never published anywhere, so it can be as honest as you like.

**Deleting.** Delete is double-gated: a confirmation step, then your wallet password, with a warning to back up first. Deleting an identity you have not backed up is unrecoverable; the key is gone for good. Your funds are not at risk either way, because they live on the seed, not the identity.

**Security model, in plain words.** Each identity's key is encrypted on your device with your wallet password, exactly like the single identity always was. Keys are only unlocked in memory while the wallet is open; close the wallet and every identity locks again.

<div class="shot-todo"><strong>Screenshots:</strong> Identity switcher list with tags, Add identity (generate / import), Delete confirmation with backup warning, dark, 390×844.</div>

## Reference

- The held-identity index (which identities the wallet holds, display order, which is active; carries no secrets): `HeldIdentities` / `HeldEntry` in `goblin/src/nostr/identities.rs`, persisted as `nostr/identities.json` with a cap of `MAX_IDENTITIES = 8`. Pre-feature wallets migrate automatically: the existing `identity.json` is adopted as identity #1 and never rewritten, so an older build still opens the wallet cleanly.
- Each held identity is a full `NostrIdentity` with its own NIP-49 `ncryptsec` (`identities/<hex>/identity.json`); the local tag is the `private_tag` field in `goblin/src/nostr/identity.rs`.
- All-at-once listening: the service keeps every held identity of the open wallet live for the session and names all their pubkeys in a single gift-wrap subscription; an incoming wrap is opened by whichever held key it was addressed to. See `goblin/src/nostr/client.rs`.
- Switcher, add, tag, and delete UI: `IdentitySwitchState` in `goblin/src/gui/views/goblin/mod.rs` (step-1 `confirm_delete`, then a password-gated pending action).

## References

- How a single identity is stored and encrypted: [Identity (NIP-06 / NIP-49)](../pillars/nostr-identity.md).
- Claiming a username for an identity: [Name authority](name-authority.md).
- Importing an identity at first run: [Onboarding](onboarding.md).
