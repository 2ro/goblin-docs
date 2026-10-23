# Ingest policy (the security core)

> **Summary.** Every incoming message runs through one pure decision function, `decide()`, before the wallet does anything with it. This is where Goblin enforces its safety invariants: **a request for you to pay is never paid automatically**, and a reply is only finalized when it matches a payment *you* started and comes from the counterparty you expected. Everything else is dropped.

## Motivation

A wallet that auto-processes messages from strangers is a wallet waiting to be drained or confused. The ingest policy exists so that "what does the wallet do with this slate?" has exactly one answer, derived purely from the slate's contents and your stored state, not from anything the sender can spoof (tags, notes, claimed identity). Keeping it a **pure function** makes it unit-testable and auditable in isolation.

## How it works

### Before the parser

The pinned Grin slatepack parser panics on some crafted input instead of returning an error, and the Android build stops the whole app on a panic (`panic = "abort"`). Before Build 171 one such message from a stranger closed the app, and because the [catch-up](nostr-service.md) fetches the last 3 days of messages at every start, it closed it again at every launch. So Goblin checks the slatepack itself before the parser sees it. `precheck()` walks the parser's own steps (size, armor framing, base58 text, the 4-byte check code, the binary header, the payment-proof keys and signature, and for an encrypted payload the age header: X25519 recipients only, no passphrase) and refuses where the parser would panic. It never refuses a slatepack the parser accepts. Over Nostr an encrypted slatepack is refused outright: Goblin only sends plain ones there, and the parser's remaining panics come after decryption. A refused message is marked processed and dropped with a log line, before `decide()` runs.

As a last guard, one store write records a parse attempt on the wrap and its rumor right before the parser runs, and one clears it as soon as the parser returns. An attempt left over from a run that died inside the parser gets one more try at the next start; a second leftover means the message is skipped for good, also when the same rumor comes again in a new wrap.

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
- **The parser only sees checked slatepacks.** Every path that parses a slatepack (Nostr, paste, QR scan, file) runs the precheck first. One limit remains, as in GRIM: an encrypted slatepack pasted or opened by hand is decrypted by the pinned parser, and a crafted one can still close the app once. The next pin move closes that at the source.
- **Crash tolerance**: replies are also accepted when the local tx is still `Created` (not yet flipped to `AwaitingS2`), because a send can crash between building and recording, but still only from the expected counterparty.
- **A failed dispatch is final.** A reply to a payment or request whose dispatch failed is never finalized: you saw the failure and may already have paid again with *Try again*, so finishing the old one could pay twice. Since Build 169 the wallet cancels a failed dispatch at once and never writes `SendFailed`; a row an older build left in `SendFailed` is closed at the next start and its reply is dropped. See [Send & request](../features/send-request.md).

## Reference

In `goblin/src/nostr/ingest.rs`:

- `IngestDecision` enum: `AutoReceive`, `SurfaceIncoming`, `FinalizePost`, `SurfaceRequest`, `Drop(&'static str)`.
- `IngestContext` struct: parsed slate, amount, sender npub, stored meta, `is_contact`, accept policy, `allow_requests`.
- Before the parser: `precheck()` in `goblin/src/wallet/slatepack_precheck.rs:102`, its refusal reasons `Reject` at `:67`; `Wallet::parse_slatepack()` runs it first (`goblin/src/wallet/wallet.rs:1860`). In `handle_wrap()` (`goblin/src/nostr/client/service.rs`): the skip of a wrap that crashed two runs at `:1846`, of its rumor at `:1935`, the precheck and the encrypted refusal at `:1971`, the parse-attempt markers around the parser at `:1988-2001`; helpers `parse_aborted()` and `next_parse_attempt()` at `:1811` and `:1823`. Zero-amount refusal for paste, scan and file: `refuse_zero_amount()` (`wallet.rs:3046`).
- `decide(ctx) -> IngestDecision`: the whole policy; covers Standard-1/2 and Invoice-1/2 (`ingest.rs:64`). The reply allow-sets (`Created` or `AwaitingS2` / `AwaitingI2`, never `SendFailed`) are at `ingest.rs:100-115` (Standard-2) and `ingest.rs:133-143` (Invoice-2).
- Closing a legacy `SendFailed` row at service start: `reconcile_action()` / `reconcile()` in `goblin/src/nostr/client/service.rs:1040` and `:1076`.
- Accept policies (`Everyone` / `Contacts` / `Ask`) come from [config](nostr-storage.md).

## References

- Slate states and direction: [Storage, config & types](nostr-storage.md) (`NostrSendStatus`, `NostrTxDirection`).
- How decisions become actions: [The payment flow](../features/payment-flow.md).
- The policy is exercised by the live `nostr_e2e` round-trip tests in `goblin/tests/nostr_e2e.rs`.
