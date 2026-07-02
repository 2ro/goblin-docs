# The end-to-end payment flow

> **Summary.** This page follows one payment from the moment you hold *Send* to the moment it settles on the Grin chain, through GRIM, Nostr, and Nym. It's the single best way to see how the three pillars cooperate.

## The cast

- **GRIM** builds and finalizes the Grin slatepacks.
- **The [Nostr protocol](../pillars/nostr-protocol.md)** wraps each slatepack as an encrypted message.
- **The [NostrService](../pillars/nostr-service.md)** publishes and receives them.
- **[Nym](../pillars/nym.md)** carries every byte.
- **The [ingest policy](../pillars/nostr-ingest.md)** decides what each side does with what it receives.

## Standard payment, step by step

Alice pays Bob `5 ツ` by username.

```
ALICE                                                   BOB
  │ 1. resolve bob → npub (NIP-05, over Nym)
  │ 2. GRIM builds Standard-1 slatepack
  │ 3. gift-wrap (kind 1059) + publish ───┐
  │    to Bob's kind 10050 relays         │  Nym mixnet
  │    over Nym                           └──────────────▶ 4. ingest: AutoReceive
  │                                                         5. GRIM builds Standard-2
  │ 7. ingest: FinalizePost  ◀──────────── gift-wrap ──────┘ 6. publish reply (over Nym)
  │ 8. GRIM finalizes the tx
  │ 9. broadcast to Grin node (direct)
  ▼ 10. both wallets see it confirm (10 blocks)
```

1. **Resolve.** If you typed `bob`, the wallet resolves it to an `npub` via [NIP-05](name-authority.md), an HTTPS lookup that goes over the mixnet. (Paste an `npub`/`nprofile` and this is skipped; relay hints may come along for free.)
2. **Build leg 1.** GRIM creates the Standard-1 slatepack for `5 ツ` to Bob and records `tx_meta` (`direction = Sent`, `status = Created`).
3. **Wrap & send.** The [send pipeline](../pillars/nostr-service.md) builds a `kind 14` rumor (preamble + slatepack + note), seals and gift-wraps it ([NIP-59](../pillars/nostr-protocol.md)), and publishes the `kind 1059` to *your* relays and Bob's DM relays, all over [Nym](../pillars/nym-relay-transport.md). Status → `AwaitingS2`. The UI shows a spinner.
4. **Bob ingests.** Bob's wallet (even if just reconnected) pulls the gift wrap, unwraps it, parses the slate, and runs [`decide()`](../pillars/nostr-ingest.md). A new payment under the default policy → `AutoReceive`.
5. **Build leg 2.** Bob's GRIM builds the Standard-2 reply.
6. **Reply.** Bob's wallet gift-wraps and publishes it back to Alice's relays, over Nym.
7. **Alice ingests the reply.** Her wallet matches the Standard-2 to her pending tx *and* confirms it came from Bob's `npub` → `FinalizePost`.
8. **Finalize.** Alice's GRIM finalizes the transaction.
9. **Broadcast.** The finalized tx is posted to the **Grin node directly** (public chain data; not over the mixnet).
10. **Confirm.** Both wallets watch the chain; after the confirmation window the payment shows as settled.

Neither party pasted a slatepack, and neither needed the other online at the same instant: relays buffered the messages.

## How the bytes travel

Every message above rides the [Nym mixnet](../pillars/nym.md), and the wraps themselves are [NIP-44 encrypted](../pillars/nostr-protocol.md#encryption-nip-44-v3-with-v2-fallback) (v3 when both wallets support it). The primary relay is dialed through its operator's [scoped exit](../pillars/nym-exit.md) when the relay pool advertises one, so the payment path needs no public DNS and no shared public exit; every other connection, and any exit failure, rides the shared [tunnel](../pillars/nym-client.md). One honest caveat: the first relay connect after a cold app start can take up to about a minute while the exit's mixnet client acquires bandwidth. It's one-time per session, and the tunnel keeps the wallet connected in the meantime.

## Requests (invoice flow)

A *request* runs the same machinery with the roles inverted: you issue an Invoice-1 ("please pay me `5 ツ`"), the payer's wallet **surfaces it for explicit approval** (never auto-paid; see [ingest policy](../pillars/nostr-ingest.md)), and on approval the Invoice-2/finalize legs complete. Declining or cancelling sends a [void control message](cancel-decline.md).

## Where it's wired

- UI dispatch: `goblin/src/gui/views/goblin/send.rs` → `WalletTask::NostrSend` / `NostrRequest` / `NostrPayRequest`.
- Task handling + finalize/broadcast: `goblin/src/wallet/wallet.rs` (the `WalletTask::Nostr*` arm, guarded wrappers `nostr_receive` / `nostr_finalize_post` / `nostr_pay`).
- Wrap/unwrap + publish/subscribe: `goblin/src/nostr/{protocol,client}.rs`.
- Accept/finalize decisions: `goblin/src/nostr/ingest.rs`.

## References

- The whole flow is exercised live by `goblin/tests/nostr_e2e.rs` (`nip17_slatepack_roundtrip`).
- Slate stages (Standard-1/2, Invoice-1/2): Grin docs, <https://docs.grin.mw>.
