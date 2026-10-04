# The end-to-end payment flow

> **Summary.** This page follows one payment from the moment you hold *Send* to the moment it settles on the Grin chain, through GRIM, Nostr, and Tor. It's the single best way to see how the three pillars cooperate.

## The cast

- **GRIM** builds and finalizes the Grin slatepacks.
- **The [Nostr protocol](../pillars/nostr-protocol.md)** wraps each slatepack as an encrypted message.
- **The [NostrService](../pillars/nostr-service.md)** publishes and receives them.
- **[Tor](../pillars/tor.md)** carries every byte, when [Tor routing](../pillars/tor.md#tor-routing-is-a-per-wallet-setting) is on (the diagram below assumes it is; in clearnet mode the same legs go direct).
- **The [ingest policy](../pillars/nostr-ingest.md)** decides what each side does with what it receives.

## Standard payment, step by step

Alice pays Bob `5 ツ` by username.

```
ALICE                                                   BOB
  │ 1. resolve bob → npub (NIP-05, over Tor)
  │ 2. GRIM builds Standard-1 slatepack
  │ 3. gift-wrap (kind 1059) + publish ───┐
  │    to Bob's kind 10050 relays         │  over Tor
  │    over Tor                           └──────────────▶ 4. ingest: AutoReceive
  │                                                         5. GRIM builds Standard-2
  │ 7. ingest: FinalizePost  ◀──────────── gift-wrap ──────┘ 6. publish reply (over Tor)
  │ 8. GRIM finalizes the tx
  │ 9. broadcast to Grin node (direct)
  ▼ 10. both wallets see it confirm (10 blocks)
```

1. **Resolve.** If you typed `bob`, the wallet resolves it to an `npub` via [NIP-05](name-authority.md), an HTTPS lookup that goes over Tor. (Paste an `npub`/`nprofile` and this is skipped; relay hints may come along for free.)
2. **Build leg 1.** GRIM creates the Standard-1 slatepack for `5 ツ` to Bob and records `tx_meta` (`direction = Sent`, `status = Created`).
3. **Wrap & send.** The [send pipeline](../pillars/nostr-service.md) builds a `kind 14` rumor (preamble + slatepack + note), seals and gift-wraps it ([NIP-59](../pillars/nostr-protocol.md)), and publishes the `kind 1059` to *your* relays and Bob's DM relays, all over [Tor](../pillars/tor-relay-transport.md). Status → `AwaitingS2`. The send spinner completes as soon as at least one relay accepts the message, so the UI shows "Sent" promptly. If none does, the wallet offers the same message again while a whole attempt fits in 40 seconds and reads it back from the relays before it gives up ([details](send-request.md)). A background read-back re-checks delivery without holding up the screen (it only logs, and never re-sends). If the dispatch fails, the payment is cancelled on the spot, its coins unlock, and you see *"Couldn't send"* with **Try again**, which builds one new payment; the failed one is never re-sent and can't complete later (see [Send & request](send-request.md)).
4. **Bob ingests.** Bob's wallet (even if just reconnected) pulls the gift wrap, unwraps it, parses the slate, and runs [`decide()`](../pillars/nostr-ingest.md). A new payment under the default policy → `AutoReceive`.
5. **Build leg 2.** Bob's GRIM builds the Standard-2 reply.
6. **Reply.** Bob's wallet gift-wraps and publishes it back to Alice's relays, over Tor, sealed and signed by the identity Alice paid. Bob may hold [several identities](identities.md) and have another one active; the reply still comes from the one Alice addressed, so her wallet accepts it. This automatic reply makes a single attempt, so it never holds up Bob's other incoming payments; if no relay accepts it, the payment stays "not replied" and the reply is re-sent at Bob's next start. Re-sends at start, voids, receipts and proofs also make a single attempt each and rely on their own retry.
7. **Alice ingests the reply.** Her wallet matches the Standard-2 to her pending tx *and* confirms it came from Bob's `npub` → `FinalizePost`.
8. **Finalize.** Alice's GRIM finalizes the transaction.
9. **Broadcast.** The finalized tx is posted to the **Grin node directly** (public chain data; not over Tor).
10. **Confirm.** Both wallets watch the chain; after the confirmation window the payment shows as settled.

Neither party pasted a slatepack, and neither needed the other online at the same instant: relays buffered the messages.

## How the bytes travel

With [Tor routing](../pillars/tor.md#tor-routing-is-a-per-wallet-setting) on, every message above rides [Tor](../pillars/tor.md); the wraps themselves are [NIP-44 encrypted](../pillars/nostr-protocol.md#encryption-nip-44-v3-with-v2-fallback) (v3 when both wallets support it) either way. The primary relay, like every other relay, is then dialed over a [Tor exit](../pillars/tor-exit.md) to its clearnet host, so the payment path never touches the clear net from the device, and it's fast: the money-path relay connects in a few seconds even from a cold app start, and a funded payment finalizes in about eight seconds end to end.

## Requests (invoice flow)

A *request* runs the same machinery with the roles inverted: you issue an Invoice-1 ("please pay me `5 ツ`"), the payer's wallet **surfaces it for explicit approval** (never auto-paid; see [ingest policy](../pillars/nostr-ingest.md)), and on approval the Invoice-2/finalize legs complete. Declining or cancelling sends a [void control message](cancel-decline.md). If your wallet finalizes a paid request but the broadcast to the Grin node fails, the next retry re-posts the already finalized transaction (the same recovery a send has), so a paid request can't get stuck unbroadcast.

## Payment proofs (on request)

Payments can include a native Grin payment proof when the payment request asks for one, off by default, shown on the review screen.

That is the whole rule. An ordinary person-to-person send carries no proof and is byte-identical to a send with the feature never involved. Proof mode is turned on for a single transaction only when the payment link that opened the review screen asks for it, by carrying the relevant parameters (a proof address, and optional order and notify hints). When it is on, the review screen shows a plain **Payment proof: Included** row so you can see it before you hold to send. The parsing is fail-closed: if any of those parameters is missing or malformed, the wallet drops proof mode and falls back to a normal proof-free payment rather than guessing. Requests you issue are unaffected; only a send whose link explicitly asks for a proof ever produces one.

In proof mode the plain *"payment sent"* receipt goes out right after the payment is recorded as sent, and only while it is still waiting for its reply or already finalized, so a send cancelled in the meantime gets none. The encrypted proof follows at finalize. Each is marked delivered only when a relay accepted it; otherwise it is retried at the wallet's next start. Both are signed by the identity that paid, or by the active identity if that one has since been removed (the merchant matches the order, not the sender).

## Where it's wired

- UI dispatch: `goblin/src/gui/views/goblin/send.rs` → `WalletTask::NostrSend` / `NostrRequest` / `NostrPayRequest`.
- Task handling + finalize/broadcast: `goblin/src/wallet/wallet.rs` (the `WalletTask::Nostr*` arm, guarded wrappers `nostr_receive` / `nostr_finalize_post` / `nostr_pay`). A failed post is retried from the saved finalized slatepack of the slate's own flow (`Standard3` for a send, `Invoice3` for a request): `nostr_finalize_post()` and `finalized_state_for()`, `wallet.rs:1997` and `:2048`.
- Failed dispatch: `nostr_cancel_slate()` (`wallet.rs:4026`), called from the `NostrSend` / `NostrRequest` arms (`wallet.rs:3383-3423`, `:3519-3542`).
- Delivery evidence: every wallet message goes through `publish()` (`goblin/src/nostr/client/send.rs:656`). An empty accepted set is an error (`relay_accepted()`, `:787`). Messages started on screen get the long push (`Push::Long`, `send_payment_dm_on_screen()`, `:217`); everything else gets one attempt (`Push::Short`: `send_payment_dm()` `:194`, `send_control_dm()` `:270`, `publish_receipt_sent()` `:305`, `deliver_proof_wrap()` `:330`). The automatic reply and the start-up re-send are in `goblin/src/nostr/client/service.rs:2061-2074` and `reconcile()` `:1075-1172`; `reconcile()` runs at service start (`:396`).
- Row status after a dispatch moves on only from the status the task left it in (`advance_after_dispatch()`, `send.rs:126`). The receipt waits for that row (`receipt_owed_now()`, `:154`; `wallet.rs:3368-3381`), and the delivered flags are written alone under the finalize lock (`mark_delivered()`, `send.rs:175`; retries `service.rs:945-1000`).
- Which identity signs: every outgoing wallet message names its identity (`sender_keys()`, `send.rs:67`). A new payment or request uses the identity active when the task starts (`wallet.rs:3263`, `:3449`). A reply, void or re-send uses the identity recorded for that transaction: `TxNostrMeta.recipient_pubkey`, or for an incoming request the new `PaymentRequest.recipient_pubkey` (`goblin/src/nostr/types.rs:203`, filled at ingest `service.rs:2098`, read by `request_identity()`, `send.rs:112`). If that identity is no longer held, the message fails rather than go out as another identity (`held_keys_for()`, `send.rs:556`). Receipts and proofs use `payment_proof_keys()` (`send.rs:82`), which falls back to the active identity. The v2 gift wrap is built with that identity's keys by the library's own NIP-17 builder (`build_dm_wrap()`, `send.rs:573-587`); the relay client's signer is left for NIP-42 auth. The wire format is unchanged.
- A row that never went out (`Created`) and whose identity is gone is closed at start like a failed dispatch, so its coins unlock (`reconcile_action()`, `service.rs:1039-1072`).
- Wrap/unwrap + publish/subscribe: `goblin/src/nostr/protocol.rs` and `goblin/src/nostr/client/` (`send.rs` for the send pipeline, `service.rs` for the relay loop and reconcile).
- Accept/finalize decisions: `goblin/src/nostr/ingest.rs`.

## References

- The whole flow is exercised live by `goblin/tests/nostr_e2e.rs` (`nip17_slatepack_roundtrip`).
- Slate stages (Standard-1/2, Invoice-1/2): Grin docs, <https://docs.grin.mw>.
