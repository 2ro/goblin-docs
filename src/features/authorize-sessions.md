# Authorize Sessions (trust a site)

> **Summary.** A site that speaks Goblin can ask you to **trust** it for a signing session. Once you do, it can sign **low-risk** actions for you (posts, reactions, direct messages, marketplace listings that carry no price, profile edits) without asking again, for this session only. Anything that spends or receives money always asks for your wallet password, every time. Your key never leaves the wallet, the wallet (never the site) decides which requests are money, and you can end any session from **Settings → Trusted Sites** at any moment.

## Motivation

[Signing in with Goblin](sign-in.md) proves who you are for one login and stops there: on its own it grants the site no power to publish as you. That is the right default, but it is tiring when a site legitimately needs to sign a stream of low-risk events on your behalf, for example a marketplace posting your chat messages, reactions, and listing edits as you browse. Approving every one of those with your password would be unusable; handing the site your key would be dangerous.

Authorize Sessions is the middle path. You grant one site, for one identity, the ability to sign a **specific, low-risk** set of actions silently for the length of a session. The wallet keeps a hard line around anything that moves value: those requests are never covered by the grant and always raise a per-action password prompt. The key stays in the wallet the whole time; only signatures leave.

## How it works

**The site asks you to trust it.** As with login, the request arrives over a Goblin URI: on the same device a button opens the app, from another device you scan a QR. A trust request is a superset of a login request. On approval the wallet signs the one-time login event **and** opens an encrypted channel to the site so it can make signing requests during the session.

**The Trust screen.** The wallet shows a single modal, **Trust `<domain>`?**, with:

- **Signing in as**: the identity that will sign (your private tag or claimed name, with the npub beneath it). If you hold several identities you choose one.
- **What the site may sign silently**: the low-risk categories it is asking for, shown in plain language, never as raw kind numbers:
  - Posts and reactions
  - Direct messages
  - Listings
  - Profile and lists
  - Deletes
  - Uploads and HTTP auth
  An event type the wallet does not recognize is shown on its own caution line rather than folded into a category.
- **The fixed money line**: *"Anything that spends or receives money will still ask for your password, every time. Buying, selling, and payment confirmations are never signed silently."* This is not something the site can turn off.
- **Login is never granted to a site.** If the site asked for the login event type as part of the set, the wallet strips it and says so.
- **Duration**: the grant lasts for this session only and can be ended any time from Settings → Trusted Sites.

You **hold to trust for this session** and enter your wallet password once. From then on, requests in the granted set are signed silently; everything else follows the rules below.

**Two tiers, and the wallet decides.** Every request the site makes is classified by the wallet from the event's kind **and its content**, never from anything the site claims:

- **Low tier**: signed silently, but only if the kind is in the set you granted. A low-tier kind you did not grant is refused, not signed.
- **Money tier**: never silent. It always raises a **Confirm** prompt (*"This moves or commits value, so it always asks"*) and is signed only after you enter your password. Finalizing a purchase and posting a priced product listing are money tier by kind. In addition, a direct-message or order request whose readable content commits you to a payment is **escalated** to the money tier, so a pay-commitment hidden inside a message still asks. The classifier is fail-safe: when it is unsure whether something commits value, it treats it as money and prompts.

**What is never signed at all.** A login event and any delegation-bearing event are refused by the session outright, in every build, even through the money prompt. A session for one identity can never sign as another identity, and the wallet signs exactly the event the site composed (it never re-stamps the time or adopts a site-supplied id or signature).

**Order messages (encrypt and decrypt).** To build a sealed order message a marketplace needs the wallet to encrypt and decrypt with your identity key, not just sign. A trusted site can request those over the same channel. They are low risk like a silent sign, with two guards: an encrypted order message whose content commits to a payment escalates to the money prompt, and heavy message-reading surfaces an honest notice (below), because decrypting reads that identity's messages.

**Safety notices.** If a trusted site signs unusually fast, the wallet shows a quiet, non-blocking notice, *"A trusted site is signing a lot."* If it reads a lot of your messages, *"A trusted site is reading your messages."* If the request rate crosses a hard ceiling, the session **pauses**: it stops signing silently and stays listed as paused until you resume or end it.

## Trusted Sites

**Settings → Trusted Sites** lists every site you have trusted this session. Each entry shows the site, the categories it can sign silently, and how long the session has left. From here you:

- **End session** to revoke a site immediately. The wallet tears the session down on its side at once and tells the site the session ended.
- **Resume** a session that paused itself after a burst.

Sessions are held in memory only, so they are **inherently temporary**: closing or restarting the wallet ends every one of them. Even if you never touch it, a session ends after it goes idle for a while and cannot outlive a hard time cap. It is always safe to end a session you no longer recognize.

<div class="shot-todo"><strong>Screenshots:</strong> Trust modal showing domain, identity, granted categories, the fixed money line, and Hold to trust; the Confirm (money) prompt; Settings → Trusted Sites with one active session, time remaining, and End session, dark, 390×844.</div>

## Reference

- The trust request URI (`goblin:trust?c=<64-hex nonce>&d=<domain>&cb=<https callback>&sk=<site channel pubkey>&r=<wss relay hint>&k=<csv kind set>`; the `nostr:trust` QR form is byte-identical) is parsed fail-closed in `goblin/src/nostr/trusturi.rs`. Any single validation failure rejects the whole URI before any modal can open.
- The two-tier core lives in `goblin/src/nostr/session.rs`: `classify()` decides Low vs Money from kind and content; the money-tier kinds are purchase-finalize (`17`) and product listing (`30402`); the flagged conversation kinds (`13`, `14`, `16`, `1059`) escalate to money when their readable content commits a payment; `sanitize_kind_set()` strips the login kind and every money kind from any requested set before it is stored; `sign_session_event()` pins the client's `created_at`, binds to the session identity, and refuses the login kind and any `delegation` tag.
- Requests and responses ride an encrypted, addressed channel (event kind `24140`, NIP-44 v2 envelopes with a NIP-40 short expiration) bound to the site's ephemeral channel key. A session is bound to a single identity, deduplicates replays, and enforces size caps, a rate limit, an idle timeout, and a hard time cap (memory-only, so a restart ends it).
- The Trust grant modal, the money-tier Confirm prompt, and the Trusted Sites screen live in `goblin/src/gui/views/goblin/mod.rs`, with copy in `goblin/locales/*.yml` under `goblin.trust`, `goblin.money`, and `goblin.trusted_sites`.

## References

- The one-time login this builds on: [Sign in with Goblin](sign-in.md).
- The identity a session signs as: [Multiple identities](identities.md).
- The site that uses sessions: [Name marketplace](name-marketplace.md).
- The wallet's broader guardrails: [Security hardening](../subsystems/security.md).
