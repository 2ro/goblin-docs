# Ingest policy (the security core)

> **Summary.** Every incoming message runs through one pure decision function, `decide()`, before the wallet does anything with it. This is where Goblin enforces its safety invariants: **a request for you to pay is never paid automatically**, and a reply is only finalized when it matches a payment *you* started and comes from the counterparty you expected. Everything else is dropped.

## Motivation

A wallet that auto-processes messages from strangers is a wallet waiting to be drained or confused. The ingest policy exists so that "what does the wallet do with this slate?" has exactly one answer, derived purely from the slate's contents and your stored state, not from anything the sender can spoof (tags, notes, claimed identity). Keeping it a **pure function** makes it unit-testable and auditable in isolation.

## How it works

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
- **Zero-amount and already-seen slates are dropped** (anti-noise, anti-replay).
- **Crash tolerance**: replies are also accepted when the local tx is still in `Created`/`SendFailed` (not yet flipped to `AwaitingS2`), because a send can crash between building and recording, but still only from the expected counterparty.

## Reference

In `goblin/src/nostr/ingest.rs`:

- `IngestDecision` enum: `AutoReceive`, `SurfaceIncoming`, `FinalizePost`, `SurfaceRequest`, `Drop(&'static str)`.
- `IngestContext` struct: parsed slate, amount, sender npub, stored meta, `is_contact`, accept policy, `allow_requests`.
- `decide(ctx) -> IngestDecision`: the whole policy; covers Standard-1/2 and Invoice-1/2.
- Accept policies (`Everyone` / `Contacts` / `Ask`) come from [config](nostr-storage.md).

## References

- Slate states and direction: [Storage, config & types](nostr-storage.md) (`NostrSendStatus`, `NostrTxDirection`).
- How decisions become actions: [The payment flow](../features/payment-flow.md).
- The policy is exercised by the live `nostr_e2e` round-trip tests in `goblin/tests/nostr_e2e.rs`.
