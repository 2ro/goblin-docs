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
- **Review → hold to send.** The review hero shows recipient, amount, fee and note; a **hold-to-send** gesture (a deliberate ~1.5 s press) confirms, and is hard to do by accident. This dispatches the [payment](payment-flow.md). On Android, a touch that passes through another app's overlay window is ignored on this screen (and on the hold-to-accept review of a request and a site's money prompt), so a window drawn on top of the wallet can't steer your hold.
- **Sending → Sent.** A payment counts as sent only once **at least one relay has accepted** its message; then "Sent" appears. A read-back check still runs in the background afterwards, but it only logs: it never fails a payment and never sends one again.
- **Waiting for a relay.** If no relay accepts the message at first, the wallet sends the *same* message again (same id, so a relay that already holds it simply confirms it) while a whole attempt still fits in a 40-second budget. It then asks the relays once more whether one of them holds the message, and only then gives the failure verdict. So a send made while the relays are still connecting (a cold start, a slow Tor circuit) goes through as before, and a send made with no connection at all ends in *"Couldn't send"* instead of "Sent". The verdict normally comes within about 45 seconds of the wallet starting to publish, longer if a relay asks the wallet to log in during the last attempt. The wallet dials the relays once, when the send starts: if the network is fully down at that moment and comes back during the window, the relay connections return only on their own retry timer, so the send can still fail; **Try again** then works.
- **Couldn't send → Try again.** If the dispatch fails, the wallet cancels that payment *before* the screen changes, so its coins are unlocked and it can never complete later. (If the Grin node can't be reached at that moment, the unlock is retried after the wallet's next good node sync.) The screen shows *"Couldn't send"* with **Try again** and **Close**; **Try again** builds one new, clean payment. The wallet never re-sends a failed payment on its own, so one intended payment can't be paid twice. If the recipient's reply had already completed the payment despite the error, the screen shows "Sent" instead, because trying again would pay twice. A request that fails to dispatch is cancelled the same way and shows *"Couldn't request"*. One rare case remains: a relay connection may still deliver a queued copy of the message after the verdict; the recipient then sees a pending payment that never completes, and no funds move.
- **Approving a request.** The reply that pays a request you approved is pushed the same way, but it gives no failure verdict: if no relay accepts it, the request still counts as approved, the reply stays "not replied" and is re-sent at the wallet's next start, and its coins stay reserved until the payment completes or expires. An approval that fails before its reply is built (the identity the request was addressed to is no longer held, the request is no longer payable, or your funds are still confirming) returns *its own* request card to its buttons and shows the reason there.
- **One result per screen.** Every send, request or approval you start takes its own turn, and its result reaches only the screen of that send. If you leave a slow send and start another, the first one still does all its money work (including cancelling itself if it fails), but it can no longer show "Sent" or "Couldn't send" on the second.
- **Signed by the identity you send as.** A payment or request is sealed and signed by the identity that is active when you hold to send, including right after you switch identities.
- **Sent once.** The moment a payment is dispatched, the pay affordances that produced it, the send button and any pay QR, clear immediately. There is no window in which the same payment can be fired twice by an impatient second tap: once it's sent, the control that sent it is gone.
- **QR / scan-to-pay.** The recipient row and the home header offer a camera scanner; the home **My Code** QR encodes your own `nprofile` (npub + relay hints) so someone can scan to pay you and reach you with no lookup, with the black Goblin logo centred in it so it reads as clearly yours. The receive screen's **Share** and **Copy** both hand over that same `nprofile`. Scanning a checkout code that carries an amount (for example from GoblinPay) fills the amount and note too, not just the recipient. See [QR & camera](../subsystems/qr-camera.md).
- **Payment deep links.** A `goblin:` or `nostr:` pay link (the two are byte-identical) opens the wallet straight to the review screen with the recipient, amount and note already filled in, ready to hold-to-send, on desktop (macOS included), Android, and via a scanned QR, which all take the same path. A link that carries only a recipient drops you into the prefilled recipient search instead. Whatever a link claims, the wallet re-parses the recipient and amount authoritatively before building the payment, so a malformed link degrades to "recipient only, enter the amount yourself" rather than doing anything surprising.

**Requests** reuse the **Pay/Request** screen: choose *Request* instead of *Pay* to issue an Invoice-1 to a contact (or broadcast a "requesting X ツ" code). Incoming requests appear as approve/decline cards; see [Cancel & decline](cancel-decline.md).

**Batch invoices.** A payment link or QR can ask the wallet to issue several invoices at once, up to 20 in one link. Instead of a prompt per invoice, the wallet shows a single approval that says how many invoices are being requested and for how much in total; one confirmation issues the whole batch. Anything a batch link gets wrong (or a count the wallet cannot honour directly) quietly degrades to the ordinary single-invoice flow.

The **Activity** feed and home "recent contacts" strip are built by joining the GRIM transaction log with nostr `tx_meta` (`goblin/src/gui/views/goblin/data.rs`). Each recent-activity row reads left-to-right the way a message list does: the note or counterparty on the left, ellipsised when it's long, with the amount and a relative time stacked on the right. Opening a payment's detail view shows the fuller picture, down to the seconds on its timestamp.

<div class="shot-todo"><strong>Screenshots:</strong> (1) recipient search with candidate cards, (2) numpad amount, (3) review hero with hold-to-send, (4) Activity feed, dark, 390×844.</div>

## Reference

In `goblin/src/gui/views/goblin/send.rs`:

- `SendFlow` + `Stage` enum; `Recipient`, `Candidate`, `LookupResult` types.
- Debounced lookup → NIP-05 resolve / `kind 0` fetch; the unverified-key confirm gate.
- `request: bool` switches Pay ↔ Request; scan via `CameraContent` + `ScanTab`.
- Dispatch: `WalletTask::NostrSend` / `NostrRequest` (amount, recipient hex, note, relay hints, and the send turn). `dispatch()` takes a new turn before queueing the task (`send.rs:1443`, `begin_send()` at `:1457`). The sending screen advances only on its own turn's result (`sending_ui()`, `send.rs:1482`, reading `send_phase_for()` / `send_error_for()`, `goblin/src/nostr/client/mod.rs:404`, `:411`); the failed screen and its **Try again** (a fresh `dispatch()`) are `failed_ui()`, `send.rs:1536-1579`.
- Send turns: `begin_send()`, `set_send_phase_for()` and `fail_send_for()` in `goblin/src/nostr/client/mod.rs:337`, `:356`, `:370`. A task left behind still runs its money work but cannot change the phase.
- Delivery evidence: `publish()` and `publish_until_accepted()` in `goblin/src/nostr/client/send.rs:656` and `:717-768`. A publish counts only if a relay accepted it, a duplicate acknowledgement included (`relay_accepted()`, `:787`). The budget is `SEND_TIMEOUT = 40 s` (`client/mod.rs:81`); the pacing, attempt window, hang guard and read-back wait are `RETRY_GAP`, `ATTEMPT_WINDOW`, `ATTEMPT_CAP` and `READBACK_WAIT` (`send.rs:627-641`). A read-back hit must be the sent event's own id (`holds_event()`, `:774`). On-screen messages use `send_payment_dm_on_screen()` (`:217`); a refusal of the first attempt by the relay pool (no relays) still fails at once (`:739`). The relays are dialed once per send by `connect_relays()` (`goblin/src/nostr/client/service.rs:594`); after that, reconnecting is the relay library's own retry timer (nostr-relay-pool 0.44.3, `relay/constants.rs:20`, `:23`).
- Failure is final: the `NostrSend` and `NostrRequest` arms in `goblin/src/wallet/wallet.rs:3308` and `:3495` call `nostr_cancel_slate(..., failure_is_final = true)` (`wallet.rs:4081`) on any dispatch error before the UI shows it (`wallet.rs:3438-3478`, `:3574-3597`).
- Approval: `WalletTask::NostrPayRequest` (`wallet.rs:3846`). An unaccepted reply is only logged, and the request is still marked approved (`:3904-3921`). Earlier failures go through `approve_failed()` (`wallet.rs:3871`, `:3925`, `:3981`, `:3987`; `goblin/src/nostr/client/mod.rs:383`), and the activity view takes each request's own failure (`take_approve_failure()`, `goblin/src/gui/views/goblin/activity.rs:88-101`).
- The background read-back, advisory only: `dispatch_dm()` and `confirm_delivery()` in `goblin/src/nostr/client/send.rs:371` and `:413`.
- Overlay-touch filter (Android): `touch_filter_wanted()` in `goblin/src/gui/views/goblin/mod.rs:320`; `MainActivity.dispatchTouchEvent` / `setTouchFilter` in `goblin/android/app/src/main/java/mw/gri/android/MainActivity.java:387-415`.
- Profile verification: `NostrService::fetch_profile_blocking()` (`goblin/src/nostr/client/identity.rs:122`).
- Feed/contacts model: `goblin/src/gui/views/goblin/data.rs`.

## References

- What happens after you hold-to-send: [The payment flow](payment-flow.md).
- Avatars on the cards: [Avatars & identicons](../subsystems/avatars.md).
