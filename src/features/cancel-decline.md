# Cancel & decline

> **Summary.** Two related "call it off" actions. **Cancel payment** appears on a payment *you sent* that hasn't completed, and reclaims your funds. **Decline** appears on a request *someone sent you*, and tells them no. Both are deliberately gated so they're hard to trigger by accident, which is exactly why they're hard to catch in a screenshot.

## Motivation

Interactive payments can get stuck: the recipient never comes online, or you change your mind before the second leg arrives. You need an escape hatch, but a *careless* one is dangerous, because cancelling a payment that has actually completed could look like free money or double-spends. So both actions are guarded:

- **Cancel payment** only appears after a **grace period** (so you don't cancel a payment that's about to complete), only where a cancel is safe (see [the cancel-safety rule](#when-cancel-is-offered-the-cancel-safety-rule)), and it refuses once the payment has truly gone through.
- **Decline** is a normal, immediate choice on a request, but a request only exists transiently, when someone has sent you one.

## How it works

### Cancel payment (outgoing)

On the **receipt** screen for a payment you sent, a **Cancel payment** button appears when the payment is still pending (`Created` / `AwaitingS2`), not yet confirmed, the grace window (`cancel_grace_secs`, default 10 minutes) has elapsed, **and** the [cancel-safety rule](#when-cancel-is-offered-the-cancel-safety-rule) allows it. It's a two-tap confirm (the label changes to a confirm state on first tap). Confirming dispatches `WalletTask::NostrCancelSend(slate_id)`, which reclaims the locked outputs so your balance returns. The result is shown for a few seconds:

- success → *"Payment cancelled, your funds are available again"* (positive green);
- lost the race → *"This payment already went through and can't be cancelled"* (dim).

A send whose dispatch failed needs no button: the wallet cancels it itself before it shows *"Couldn't send"* (see [Send & request](send-request.md)). A request you issued that nobody has paid yet offers **Cancel request** on its receipt, under the same rule; it cancels the invoice locally and sends the payer a [void](#one-wire-message-void).

### When Cancel is offered: the cancel-safety rule

Every cancel in the wallet follows one rule, on the receipt and in the transaction list alike. **Before the wallet has synced with its Grin node**, Cancel is offered only for a payment that this wallet alone can still complete: your own send that the recipient hasn't answered yet, or your own request that nobody has paid yet. Every other pending row (a payment you replied to, a request you paid, anything this wallet already finalized) may already be on chain without the wallet knowing, so its Cancel appears only **after a node sync**, and never once the transaction is confirmed. A cancel the wallet would refuse is simply not offered, so no Cancel button ever does nothing.

### Expiry and stuck payments

A payment that stays unanswered is expired after **24 hours** (`expiry_secs`). For a row that locks your coins (a send, or a request you paid), expiry really cancels the Grin transaction under the same safety rule, rather than only labelling the row *canceled*. While the wallet's data, or a node sync the rule needs, is not available yet, the row is left untouched for a later cycle; if the Grin cancel itself fails, the heal pass below retries it. If the payment turns out to be confirmed on chain, it is recorded as completed, not canceled.

**What "canceled" means.** In Activity and on the receipt, *canceled* means the payment will not complete: the wallet cancelled the Grin transaction, or closed the payment while it was still unconfirmed (a late confirmation on chain still wins). On a payment you sent, its coins are free again, or, when a cancel could not reach the Grin node, are freed by the heal pass below. A Grin cancel that fails shows as *Error: Cancelling* in the transaction list until it succeeds.

**Healing.** After every good node sync the wallet looks for payments you sent (or requests you paid) that are marked *canceled* but whose Grin transaction still locks your coins, for example rows an older build expired too early, or a cancel that failed while the node was unreachable, and cancels them for real. Payments you *received* are never touched by this pass. Old stuck rows therefore heal by themselves after the first sync on a new build.

<div class="shot-todo"><strong>Screenshot (rendered in isolation):</strong> receipt screen with the <em>Cancel payment</em> button: secondary outline button, 56 px tall, <code>t.line</code> border. Hard to reach live because it's grace-gated.</div>

### Decline (incoming request)

When someone sends you a payment request (Invoice-1), it shows as a card with the requester, amount and optional note, and two half-width buttons: **Decline** and **Approve** (approve is hold-to-accept). Decline marks the request `Declined` and dispatches `WalletTask::NostrDeclineRequest`, which sends a **void control message** back to the requester.

<div class="shot-todo"><strong>Screenshot (rendered in isolation):</strong> incoming-request card with <em>Decline</em> / <em>Approve</em>, needs a live incoming request to appear, so it's reproduced from the real widgets for the docs.</div>

### One wire message: "void"

Cancel-a-request and decline-a-request are the **same** message (*"this request is off"*), differing only by who sends it (the requester cancels; the payer declines). It's a `kind 14` rumor tagged `["goblin-action","void", <slate_id>]`, gift-wrapped like any payment. Cancelling an *outgoing payment* additionally reclaims your outputs locally. See [the protocol](../pillars/nostr-protocol.md#control-messages-void).

## Reference

- Cancel-payment button + two-tap confirm + outcome copy: `goblin/src/gui/views/goblin/receipt.rs` (`cancel_confirm` state; `WalletTask::NostrCancelSend`). Gating uses `cancel_grace_secs` from [config](../pillars/nostr-storage.md) (`config.rs:190`) and the safety rule (`cancel_allowed`, `receipt.rs:248-260`; request cancel `receipt.rs:264-279`; payment cancel `receipt.rs:306-321`).
- The cancel-safety rule: `cancel_safe()` in `goblin/src/wallet/types.rs:417`. The transaction list applies it in `goblin/src/gui/views/wallets/wallet/txs/content.rs:287` and `txs/tx.rs:354`; the task arms re-check it with an authoritative lookup (`WalletTask::Cancel`, `wallet.rs:3207`; `NostrCancelOutgoing`, `wallet.rs:3588`; `NostrCancelSend`, `wallet.rs:3651`).
- Automatic cancels (failed dispatch, expiry, heal) go through `nostr_cancel_slate()` (`goblin/src/wallet/wallet.rs:4026`), which marks the payment first and then cancels under the finalize lock. Expiry and heal: `expire_stale()`, `expire_step()`, `expire_status_after()`, `heal_candidate()`, `heal_due()` in `goblin/src/nostr/client/service.rs:43`, `:838`, `:858`, `:882`, `:893`; the heal waits for `nostr_cancel_node_ready()` (`wallet.rs:4121`). Expiry window: `expiry_secs()`, `config.rs:185` (default 24 h).
- What the feed calls canceled: `is_canceled()` in `goblin/src/gui/views/goblin/data.rs:186`.
- Decline button on the request card: `decline_button()` in `goblin/src/gui/views/goblin/helpers.rs:291`; `WalletTask::NostrDeclineRequest`. Outgoing-request cancel is `WalletTask::NostrCancelOutgoing`.
- The void control message: `goblin/src/nostr/protocol.rs` (`GOBLIN_ACTION_TAG`, `ACTION_VOID`, `build_control_tags()`, `extract_control()`).
- Button styling: `w::big_action(..., secondary = true)` in `widgets.rs` (transparent fill, `t.line` border, `t.text` ink).

## References

- Why a request is never auto-paid in the first place: [Ingest policy](../pillars/nostr-ingest.md).
- The states a payment moves through: [Storage, config & types](../pillars/nostr-storage.md).
