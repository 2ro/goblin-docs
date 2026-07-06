# Name marketplace

> **Summary.** A name like `alice@goblin.st` can be **sold**. The seller lists it on [magick.market](https://magick.market) for a price in Grin, the buyer pays the seller **directly, wallet to wallet**, and the name authority moves the name to the buyer's identity after checking the payment on chain. Nobody in the middle ever holds the money: there is no escrow, no custody, and no platform balance. The marketplace is a shop window and a set of tools, not a bank.

## Motivation

Names are scarce (one active name per identity, first come first served), so a good one is worth something. Before this feature the only way to give a name up was to release it, which throws it open to whoever registers fastest, so there was no safe way to hand it to a specific person for payment. A sale needs two guarantees at once: the buyer must know that paying gets them the name, and the seller must know the name only moves once they have been paid. Grin payment proofs plus a signed sale offer give both, without any third party touching the funds.

## How it works

**Selling.** Sign in to magick.market with the identity that holds the name. Listing it for sale asks for three things: the **price in Grin**, the **buyer's `npub`** (v1 sales are targeted: you name your buyer up front, there are no open "anyone can buy" offers), and a **fresh one-time proof address** from your wallet, used for this sale and nothing else. Magick signs the offer with your identity key and lodges it at the name's authority. Until the buyer completes the sale you can revoke the offer at any time.

**Buying.** Agree the deal with the seller first, off to the side, because the offer is written for your exact key and price. Then pay the seller the **exact amount** straight from your wallet, with **payment proof turned on** for that send. When the payment has settled, submit the proof on magick.market. That is the whole buyer flow: pay, then hand over the receipt.

**Verification, then reassignment.** The authority checks the proof against the signed offer: the exact amount, paid to the offer's one-time address, settled on chain with at least 10 confirmations, and never used for any other sale. If everything matches, it reassigns the name to the buyer's identity in one atomic step. From then on `alice@goblin.st` resolves to the buyer.

**Person to person, no middleman.** The buyer's Grin goes from the buyer's wallet to the seller's wallet and nowhere else. Neither magick.market nor the authority ever holds, forwards, or even sees the funds in flight; the authority only reads the chain to confirm the payment happened. There is no escrow to trust and no platform account to freeze.

**Fair to both sides.** The seller signs and lodges the offer *before* the buyer pays, so once the payment is on chain the transfer needs no further cooperation from the seller: they cannot take the money and keep the name. And the name only ever moves against on-chain proof of the exact agreed payment to the seller's own address: the buyer cannot get the name without paying.

**Operators opt in.** Name sales are **off by default** on every authority. Each operator decides whether to enable them, and doing so needs nothing more than a flag and read-only access to a Grin node (to confirm payments; the authority never runs a wallet). `goblin.st` has them enabled (`GOBLIN_ALLOW_TRANSFERS` with a read-only Grin node URL); the authority bundled with the Floonet relay uses `FLOONET_TRANSFERS`. If an authority has not opted in, names on that domain simply cannot be sold there.

**Before you sell or buy, in plain words.**

- **Agree the sale with your buyer first.** v1 offers name one specific buyer; there is no browsing-and-buying by strangers.
- **Back up before you sell.** Selling a name is like deleting it from your side: once it moves, it is gone from your identity for good, exactly as if you had released it. There is no undo and the authority cannot give it back.
- **Buyers: pay the exact amount, with proof on.** A payment without a proof, or for the wrong amount, cannot complete the transfer. (If you do mispay, the funds are with the seller; the standard fix is for the seller to relist at the amount actually paid so your existing proof matches.)
- **Buyers: one name per identity.** If the identity you are buying with already holds a name, release that name first (or buy with a different identity in your wallet); the offer and your proof stay valid while you do.
- **Keep the offer and your proof.** Together they are your receipt: the seller's signed promise and your on-chain payment.

<div class="shot-todo"><strong>Screenshots:</strong> magick.market sell-name listing form (price, buyer npub, proof address), Goblin send with proof enabled for the exact amount, submit-proof / claim step, dark, 390×844.</div>

## Reference

- **Authority side** (`goblin-nip05d/`): the transfer routes are mounted only when transfers are enabled, otherwise they 404. `POST /api/v1/transfer/offer` lodges the seller-signed offer (a kind-3402 Nostr event binding name, buyer pubkey, price in nanogrin, one-time proof address, and expiry), `GET /api/v1/transfer/offer/{id}` reads an offer and its status, `DELETE` revokes it (seller-signed), and `POST /api/v1/transfer/claim` submits the buyer's payment proof. Claims are authenticated with NIP-98 by the buyer's key, which must match the offer's `p` tag. The authority verifies the proof's two signatures, confirms the kernel on chain via a read-only node foreign API (`get_kernel` + `get_tip`), enforces exact amount and address, keeps every consumed kernel unique forever (no proof reuse), and executes the reassignment as a single SQLite transaction. The full contract is the Goblin Name Transfer Protocol v1 spec; the `goblin-nip05d` README documents every endpoint and error.
- **Configuration**: `GOBLIN_ALLOW_TRANSFERS` (default `false`), `GOBLIN_GRIN_NODE_URL` (required when on), `GOBLIN_TRANSFER_MIN_CONF` (default 10), `GOBLIN_TRANSFER_MAX_OFFER_TTL` (default 30 days), `GOBLIN_TRANSFER_CLAIM_GRACE` (default 1 day). The Floonet-bundled authority takes the identical set under the `FLOONET_` prefix (`FLOONET_TRANSFERS`, `FLOONET_GRIN_NODE_URL`, …).
- **Marketplace side** (`magick.market`): the public listing is an advert (a kind-30402 product event); the binding offer is minted per buyer, and the claim is submitted from the buyer's signed-in session.

## References

- What names are and who issues them: [The NIP-05 name authority](name-authority.md).
- Identities that hold (and can hold only one) name: [Multiple identities](identities.md).
- Enabling sales on your own authority: [Run a name authority](../self-hosting/name-authority.md).
- Payment proofs ride the normal send: [The end-to-end payment flow](payment-flow.md).
