# Cancel & decline

> **Summary.** Two related "call it off" actions. **Cancel payment** appears on a payment *you sent* that hasn't completed, and reclaims your funds. **Decline** appears on a request *someone sent you*, and tells them no. Both are deliberately gated so they're hard to trigger by accident, which is exactly why they're hard to catch in a screenshot.

## Motivation

Interactive payments can get stuck: the recipient never comes online, or you change your mind before the second leg arrives. You need an escape hatch, but a *careless* one is dangerous, because cancelling a payment that has actually completed could look like free money or double-spends. So both actions are guarded:

- **Cancel payment** only appears after a **grace period** (so you don't cancel a payment that's about to complete), and it refuses once the payment has truly gone through.
- **Decline** is a normal, immediate choice on a request, but a request only exists transiently, when someone has sent you one.

## How it works

### Cancel payment (outgoing)

On the **receipt** screen for a payment you sent, a **Cancel payment** button appears when the payment is still pending (`Created` / `AwaitingS2` / `SendFailed`), not yet confirmed, **and** either the send failed or the grace window (`cancel_grace_secs`, default 10 minutes) has elapsed. It's a two-tap confirm (the label changes to a confirm state on first tap). Confirming dispatches `WalletTask::NostrCancelSend(slate_id)`, which reclaims the locked outputs so your balance returns. The result is shown for a few seconds:

- success → *"Payment cancelled, your funds are available again"* (positive green);
- lost the race → *"This payment already went through and can't be cancelled"* (dim).

<div class="shot-todo"><strong>Screenshot (rendered in isolation):</strong> receipt screen with the <em>Cancel payment</em> button: secondary outline button, 56 px tall, <code>t.line</code> border. Hard to reach live because it's grace-gated.</div>

### Decline (incoming request)

When someone sends you a payment request (Invoice-1), it shows as a card with the requester, amount and optional note, and two half-width buttons: **Decline** and **Approve** (approve is hold-to-accept). Decline marks the request `Declined` and dispatches `WalletTask::NostrDeclineRequest`, which sends a **void control message** back to the requester.

<div class="shot-todo"><strong>Screenshot (rendered in isolation):</strong> incoming-request card with <em>Decline</em> / <em>Approve</em>, needs a live incoming request to appear, so it's reproduced from the real widgets for the docs.</div>

### One wire message: "void"

Cancel-a-request and decline-a-request are the **same** message (*"this request is off"*), differing only by who sends it (the requester cancels; the payer declines). It's a `kind 14` rumor tagged `["goblin-action","void", <slate_id>]`, gift-wrapped like any payment. Cancelling an *outgoing payment* additionally reclaims your outputs locally. See [the protocol](../pillars/nostr-protocol.md#control-messages-void).

## Reference

- Cancel-payment button + two-tap confirm + outcome copy: `goblin/src/gui/views/goblin/mod.rs` (receipt screen, `cancel_confirm` state; `WalletTask::NostrCancelSend`). Gating uses `cancel_grace_secs` from [config](../pillars/nostr-storage.md).
- Decline button on the request card: `goblin/src/gui/views/goblin/mod.rs` (request row; `decline_button()`); `WalletTask::NostrDeclineRequest`. Outgoing-request cancel is `WalletTask::NostrCancelOutgoing`.
- The void control message: `goblin/src/nostr/protocol.rs` (`GOBLIN_ACTION_TAG`, `ACTION_VOID`, `build_control_tags()`, `extract_control()`).
- Button styling: `w::big_action(..., secondary = true)` in `widgets.rs` (transparent fill, `t.line` border, `t.text` ink).

## References

- Why a request is never auto-paid in the first place: [Ingest policy](../pillars/nostr-ingest.md).
- The states a payment moves through: [Storage, config & types](../pillars/nostr-storage.md).
