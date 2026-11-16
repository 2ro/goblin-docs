# Ingest policy (the security core)

> **Summary.** Every incoming message runs through one pure decision function, `decide()`, before the wallet does anything with it. This is where Goblin enforces its safety invariants: **a request for you to pay is never paid automatically**, and a reply is only finalized when it matches a payment *you* started and comes from the counterparty you expected. Everything else is dropped.

## Motivation

A wallet that auto-processes messages from strangers is a wallet waiting to be drained or confused. The ingest policy exists so that "what does the wallet do with this slate?" has exactly one answer, derived purely from the slate's contents and your stored state, not from anything the sender can spoof (tags, notes, claimed identity). Keeping it a **pure function** makes it unit-testable and auditable in isolation.

## How it works

### Before the parser

The pinned Grin slatepack parser panics on some crafted input instead of returning an error, and the Android build stops the whole app on a panic (`panic = "abort"`). Before Build 171 one such message from a stranger closed the app, and because the [catch-up](nostr-service.md) fetches the last 3 days of messages at every start, it closed it again at every launch. So Goblin checks the slatepack itself before the parser sees it. `precheck()` walks the parser's own steps (size, armor framing, base58 text, the 4-byte check code, the binary header, the payment-proof keys, and for an encrypted payload the age header: X25519 recipients only, no passphrase) and refuses where the parser would panic. It never refuses a slatepack the parser accepts. Over Nostr an encrypted slatepack is refused outright: Goblin only sends plain ones there, and the parser's remaining panics come after decryption. A refused message is marked processed and dropped with a log line, before `decide()` runs.

Since Build 172 the pinned parser is GRIM v0.3.6's. It now returns an error at most of those points (armor framing, a payload too short for its check code, a payment-proof key that is not a curve point), but a passphrase-encrypted payload still panics it, so the precheck stays in front of it. It still refuses the cases the parser now reports as errors, only earlier. One rule went: the new parser reads any 64-byte payment-proof signature, so a signature with its top bits set now passes the precheck too, and proof verification refuses it later with an error. The fixtures hold both sides: 8 hostile slatepacks are refused (5 the parser now reports as errors, 3 that still panic it), and 108 real ones of every shape still pass.

As a last guard, one store write records a parse attempt on the wrap and its rumor right before the parser runs, and one clears it as soon as the parser returns. An attempt left over from a run that died inside the parser gets one more try at the next start; a second leftover means the message is skipped for good, also when the same rumor comes again in a new wrap. Since Build 172 a parse error in a run whose wallet is closing or closed marks nothing: the error comes from the closed wallet, not from the slatepack, so the message waits for the next open (see [The NostrService](nostr-service.md)).

### The decision

After a gift wrap is unwrapped and the slate parsed, `decide()` is called with an `IngestContext` (the parsed slate, amount, sender `npub`, any stored metadata for that slate, whether the sender is a contact, your accept policy, and whether requests are allowed). It returns one of:

| Decision | When | Effect |
| --- | --- | --- |
| `AutoReceive` | A new payment (Standard-1) your policy lets in | Build the reply leg automatically |
| `SurfaceIncoming` | A new payment under Contacts/Ask policy | Show it for you to accept |
| `FinalizePost` | A reply (Standard-2 / Invoice-2) that matches a pending tx **and** the right counterparty | Finalize and broadcast |
| `SurfaceRequest` | A request for you to pay (Invoice-1) | Show it for **explicit** approval; never auto-paid |
| `Drop(reason)` | Anything else | Discard, log the reason |

The invariants that must never be weakened:

- **Invoice-1 (someone asking you to pay) is never auto-paid.** It can only become `SurfaceRequest`, which requires you to hold-to-approve.
- **A reply only finalizes if it matches your pending transaction** *and* the sender equals the stored counterparty `npub`. A Standard-2 from the wrong key, or with no matching send, is dropped.
- **Zero-amount and already-seen slates are dropped** (anti-noise, anti-replay). Since Build 171 a 0-grin payment or request that is pasted, scanned or opened from a file is refused too, before any transaction is made.
- **The parser only sees checked slatepacks.** Every path that parses a slatepack (Nostr, paste, QR scan, file) runs the precheck first. Until Build 172 one limit remained, as in GRIM: an encrypted slatepack pasted or opened by hand was decrypted by the pinned parser, and a crafted one could close the app once. The v0.3.6 parser checks the reads after decryption and returns an error instead, so that limit is closed at the source. Over Nostr an encrypted slatepack is still refused outright.
- **Crash tolerance**: replies are also accepted when the local tx is still `Created` (not yet flipped to `AwaitingS2`), because a send can crash between building and recording, but still only from the expected counterparty.
- **A failed dispatch is final.** A reply to a payment or request whose dispatch failed is never finalized: you saw the failure and may already have paid again with *Try again*, so finishing the old one could pay twice. Since Build 169 the wallet cancels a failed dispatch at once and never writes `SendFailed`; a row an older build left in `SendFailed` is closed at the next start and its reply is dropped. See [Send & request](../features/send-request.md).

## Reference

In `goblin/src/nostr/ingest.rs`:

- `IngestDecision` enum: `AutoReceive`, `SurfaceIncoming`, `FinalizePost`, `SurfaceRequest`, `Drop(&'static str)`.
- `IngestContext` struct: parsed slate, amount, sender npub, stored meta, `is_contact`, accept policy, `allow_requests`.
- Before the parser: `precheck()` in `goblin/src/wallet/slatepack_precheck.rs:102`, its refusal reasons `Reject` at `:67`; `Wallet::parse_slatepack()` runs it first (`goblin/src/wallet/wallet.rs:1860`). In `handle_wrap()` (`goblin/src/nostr/client/service.rs`): the skip of a wrap that crashed two runs at `:1846`, of its rumor at `:1935`, the precheck and the encrypted refusal at `:1971`, the parse-attempt markers around the parser at `:1988-2001`; helpers `parse_aborted()` and `next_parse_attempt()` at `:1811` and `:1823`. The pinned parser at `9cc6a5eb`: the passphrase panic it keeps (`wallet/libwallet/src/slatepack/types.rs:202-205`), the checked reads after decryption (`:211-227`), the payment-proof reader that now returns an error (`wallet/libwallet/src/slate_versions/v4_bin.rs:346-367`). Zero-amount refusal for paste, scan and file: `refuse_zero_amount()` (`wallet.rs:3046`).
- `decide(ctx) -> IngestDecision`: the whole policy; covers Standard-1/2 and Invoice-1/2 (`ingest.rs:64`). The reply allow-sets (`Created` or `AwaitingS2` / `AwaitingI2`, never `SendFailed`) are at `ingest.rs:100-115` (Standard-2) and `ingest.rs:133-143` (Invoice-2).
- Closing a legacy `SendFailed` row at service start: `reconcile_action()` / `reconcile()` in `goblin/src/nostr/client/service.rs:1040` and `:1076`.
- Accept policies (`Everyone` / `Contacts` / `Ask`) come from [config](nostr-storage.md).

## References

- Slate states and direction: [Storage, config & types](nostr-storage.md) (`NostrSendStatus`, `NostrTxDirection`).
- How decisions become actions: [The payment flow](../features/payment-flow.md).
- The policy is exercised by the live `nostr_e2e` round-trip tests in `goblin/tests/nostr_e2e.rs`.
