# Sign in with Goblin

> **Summary.** Sites that speak Goblin, starting with [magick.market](https://magick.market), offer **Log in with Goblin** in their login dialog. On the same device a button opens the Goblin app; from another device you reveal a QR and scan it with the wallet. The wallet shows you who is asking and which identity will sign, you confirm with your wallet password, and it signs a one-time login request. Your key never leaves the wallet, and the site never gains the power to act as you.

## Motivation

Signing in to a website with a Nostr identity usually means handing your key to a browser extension, or pasting an `nsec` into the site itself. Both put the key somewhere it does not belong. The wallet already holds your identities behind your password, so it is the right place to approve a login: the site asks, the wallet shows you exactly what is being asked, and only a signature comes back out.

## How it works

**Starting from the site.** magick.market's login dialog offers **Log in with Goblin**. If the wallet is on the same device, a button opens the Goblin app directly. If it is on another device (your wallet on your phone, the site on your laptop), reveal the QR instead and scan it with the wallet's camera.

**The approval screen.** The wallet opens a single approval modal that shows **who is asking** (the site's domain) and **which identity will sign**: your private tag or claimed name, with the npub beneath it so you can anchor on the key itself. If you hold several identities you pick which one to log in as. Then you enter your wallet password, and the wallet signs the login request.

**What gets signed.** The signature covers a one-time challenge from the site and nothing else. It proves to the site that you control the identity's key, right now, for this login. It is not a session key, not a delegation, and it cannot be replayed: each request is single-use and a pending approval expires after about two minutes if you leave it untouched. Only one login request is considered at a time; while one is on screen, new ones are ignored.

**What the site gets, and does not get.** The key never leaves the wallet. The site receives a signature, not a secret, so it cannot act as you. A plain login grants no signing power: anything that would publish as you (listing a name for sale, signing an offer) still asks for your key separately at that moment. If you want a site to sign low-risk actions for you without asking each time, that is a separate, explicit step, and money always still asks. See [Authorize Sessions](authorize-sessions.md).

**Completing across devices.** When you opened the wallet from a same-device button, a successful sign-in hands you back to the calling app. A QR sign-in is the cross-device case: your phone signed, but the site is on your laptop, so there is nowhere on the phone to return to. The wallet posts the signed login to the site's callback and simply stays put; the browser is watching for that and completes the sign-in on its own. You do not switch apps or copy anything back by hand.

**Declining.** Cancel the modal, or simply let it expire, and nothing is sent. The site's login attempt just fails.

<div class="shot-todo"><strong>Screenshots:</strong> magick.market login dialog with Log in with Goblin (button + QR), wallet approval modal showing domain, identity picker and password field, dark, 390×844.</div>

## Reference

- The login URI (`goblin:login?c=<64-hex challenge>&d=<domain>&cb=<https callback>`; `nostr:login` is the byte-identical QR form) is parsed fail-closed in `goblin/src/nostr/loginuri.rs`, mirroring the pay-URI parser. A login-shaped URI that fails validation is rejected whole: it never reaches the pay path and never opens an approval modal.
- On approval the wallet signs a kind-22242 event (NIP-42 client auth: empty content, `challenge` and `domain` tags) with the chosen identity's key and POSTs it to the callback as `{"event": …}`.
- The approval modal and its lifecycle (`LoginState`, one pending request at a time, `LOGIN_EXPIRY_SECS = 120`, password-gated signing, quiet outcome toast) live in `goblin/src/gui/views/goblin/mod.rs`.
- The `login` keyword cannot collide with a pay recipient: a bech32 `npub`/`nprofile` always starts `npub1`/`nprofile1`.

## References

- The identities you log in as, tags and all: [Multiple identities](identities.md).
- How identities are stored and encrypted: [Identity (NIP-06 / NIP-49)](../pillars/nostr-identity.md).
- The site you log in to: [Name marketplace](name-marketplace.md).
- The same URI scheme carrying payments: [Send & request](send-request.md).
