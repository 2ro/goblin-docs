# Send & request, recipient search

> **Summary.** The send flow is a small state machine (pick a recipient, enter an amount, review, hold to send) with a type-ahead recipient search that resolves usernames, verifies pasted keys against Nostr profiles, and gates unverified keys behind a confirmation. The same surface issues *requests* (invoices).

## Motivation

Paying should feel like a chat app: start typing a name, see suggestions, tap, confirm. But pasted keys are dangerous (typos send money into the void), so the picker has to *verify* what you give it and warn when it can't. And because Grin payments are interactive, the UI must clearly show progress while the two legs complete.

## How it works

The flow (`SendFlow`) moves through stages: **Recipient → Amount → Review → Sending → Success / Failed**.

- **Recipient search.** As you type, the wallet matches local contacts instantly and runs a debounced (~0.4 s) network lookup in parallel. Results render as tappable cards:
  - A **name** resolves via [NIP-05](name-authority.md) → a verified card (shown as the bare `name`, or `name · domain` for a foreign authority).
  - A **pasted `npub`/hex/`nprofile`** triggers a `kind 0` profile fetch. A key with a published profile shows "✓ on nostr"; a key with **no** profile is shown as unverified.
  - **Unverified keys** are gated: tapping one asks *"Pay an unverified key?"* with **Keep looking** / **Pay anyway**. (Goblin's own domain skips the gate; foreign domains don't.)
- **Amount.** A centered numpad (mobile) or typed field (desktop). Over-balance entry flashes red and shakes rather than silently failing.
- **Note.** An optional memo, editable in a modal, travels in the message's `subject` tag.
- **Review → hold to send.** The review hero shows recipient, amount, fee and note; a **hold-to-send** gesture (a deliberate ~1.5 s press) confirms, and is hard to do by accident. This dispatches the [payment](payment-flow.md).
- **Sending → Sent.** The sending spinner completes as soon as the relay acknowledges the write (the gift wrap is on a relay), so "Sent" appears quickly instead of blocking on a full delivery re-check. The read-back delivery confirmation still runs, now in the background, and a genuine delivery failure still surfaces.
- **Sent once.** The moment a payment is dispatched, the pay affordances that produced it, the send button and any pay QR, clear immediately. There is no window in which the same payment can be fired twice by an impatient second tap: once it's sent, the control that sent it is gone.
- **QR / scan-to-pay.** The recipient row and the home header offer a camera scanner; the home **My Code** QR shows your own `nprofile` so someone can scan to pay you, rendered white and centred with your avatar so it reads as clearly yours. Scanning a checkout code that carries an amount (for example from GoblinPay) fills the amount and note too, not just the recipient. See [QR & camera](../subsystems/qr-camera.md).
- **Payment deep links.** A `goblin:` or `nostr:` pay link (the two are byte-identical) opens the wallet straight to the review screen with the recipient, amount and note already filled in, ready to hold-to-send, on desktop (macOS included), Android, and via a scanned QR, which all take the same path. A link that carries only a recipient drops you into the prefilled recipient search instead. Whatever a link claims, the wallet re-parses the recipient and amount authoritatively before building the payment, so a malformed link degrades to "recipient only, enter the amount yourself" rather than doing anything surprising.

**Requests** reuse the **Pay/Request** screen: choose *Request* instead of *Pay* to issue an Invoice-1 to a contact (or broadcast a "requesting X ツ" code). Incoming requests appear as approve/decline cards; see [Cancel & decline](cancel-decline.md).

The **Activity** feed and home "recent contacts" strip are built by joining the GRIM transaction log with nostr `tx_meta` (`goblin/src/gui/views/goblin/data.rs`). Each recent-activity row reads left-to-right the way a message list does: the note or counterparty on the left, ellipsised when it's long, with the amount and a relative time stacked on the right. Opening a payment's detail view shows the fuller picture, down to the seconds on its timestamp.

<div class="shot-todo"><strong>Screenshots:</strong> (1) recipient search with candidate cards, (2) numpad amount, (3) review hero with hold-to-send, (4) Activity feed, dark, 390×844.</div>

## Reference

In `goblin/src/gui/views/goblin/send.rs`:

- `SendFlow` + `Stage` enum; `Recipient`, `Candidate`, `LookupResult` types.
- Debounced lookup → NIP-05 resolve / `kind 0` fetch; the unverified-key confirm gate.
- `request: bool` switches Pay ↔ Request; scan via `CameraContent` + `ScanTab`.
- Dispatch: `WalletTask::NostrSend` / `NostrRequest` (amount, recipient hex, note, relay hints).
- Profile verification: `NostrService::fetch_profile_blocking()` (`client.rs`).
- Feed/contacts model: `goblin/src/gui/views/goblin/data.rs`.

## References

- What happens after you hold-to-send: [The payment flow](payment-flow.md).
- Avatars on the cards: [Avatars & identicons](../subsystems/avatars.md).
