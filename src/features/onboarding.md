# Onboarding

> **Summary.** First run walks you from nothing to a funded, named wallet: pick how you connect to Grin, create or restore a wallet, confirm your recovery phrase, and optionally claim a username, with a prominent skip so you can stay anonymous.

## Motivation

Goblin's audience isn't only Grin veterans. The first-run flow has to teach just enough (a recovery phrase is your money; a username is optional and public) without burying a newcomer in node configuration or nostr jargon. It reuses GRIM's proven mnemonic machinery so the security-critical parts are the upstream-tested ones.

## How it works

The flow (`OnboardingContent`) steps through:

1. **Intro**: what Goblin is (private, pay-by-username).
2. **Node**: connect to a node, either *Instant* (a default external node, ready immediately) or *Private* (run the integrated node and sync yourself). This choice now also lives in Settings/Advanced.
3. **Wallet setup**: name + password, or choose **restore**.
4. **Recovery phrase**: generate (12–24 words) or import. Import supports paste and a **SeedQR** scan. This step uses GRIM's `MnemonicSetup` word grid and validation.
5. **Confirm words**: verify the phrase by re-entering it.
6. **Identity**: optionally claim a `@username` (reusing the [name-authority](name-authority.md) claim flow) or import an existing identity (`nsec` / backup). A prominent **Skip** keeps you anonymous.

On completion the new wallet is opened and its [NostrService](../pillars/nostr-service.md) starts. Restoring from seed gives you a *fresh* random nostr identity by default; you bring your old one back via **Import**.

<div class="shot-todo"><strong>Screenshots:</strong> Intro, Node choice (Instant/Private), Recovery-phrase grid, Claim-username step, dark, 390×844.</div>

## Reference

In `goblin/src/gui/views/goblin/onboarding.rs`:

- `OnboardingContent` + `Step` enum (Intro → Node → WalletSetup → Words → ConfirmWords → Identity).
- `OnbImport`: optional identity import (nsec / backup, with password when sealed), async worker result.
- Reuses GRIM `MnemonicSetup.word_list_ui` (made `pub(crate)`), with SeedQR scan.
- Hosted in `goblin/src/gui/views/wallets/content.rs` (replaces only the empty-state branch; the stock GRIM wallet-creation path stays for later wallets).

## References

- The identity it sets up: [Identity](../pillars/nostr-identity.md).
- The username it can claim: [Name authority](name-authority.md).
