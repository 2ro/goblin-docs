# Security hardening

> **Summary.** A grab-bag of the defensive choices that don't fit on one feature page: never auto-paying a request, binding replies to the expected counterparty, hard size ceilings, encrypted keys at rest, replay protection, rate limiting, and (when [Tor routing](../pillars/tor.md#tor-routing-is-a-per-wallet-setting) is on) routing everything over Tor. This page is a map to where each lives.

## Motivation

A wallet that accepts messages from strangers and moves money is an attractive target. Goblin's posture is defense-in-depth: assume any incoming message is hostile, validate before acting, cap everything, and never let the network see more than ciphertext.

## The measures

| Measure | What it prevents | Where |
| --- | --- | --- |
| **Requests are never auto-paid** | A stranger draining you with an Invoice-1 | [Ingest policy](../pillars/nostr-ingest.md) (`decide()` → `SurfaceRequest`) |
| **Replies bound to counterparty + pending tx** | A forged Standard-2/Invoice-2 finalizing something | [Ingest policy](../pillars/nostr-ingest.md) |
| **Slatepacks checked before the pinned parser; a message that crashed it retried once, then skipped** | A crafted message closing the app, on Android at every launch | [Ingest policy](../pillars/nostr-ingest.md#before-the-parser) (`precheck()`, parse-attempt markers) |
| **Size ceilings (64 K / 32 K / 30 K / 256)** | Memory-blow-up / DoS via huge messages | [Protocol](../pillars/nostr-protocol.md) constants |
| **Encrypted key at rest** | Offline key theft; password grinding | [Identity](../pillars/nostr-identity.md): NIP-49 `ncryptsec`, scrypt `log_N=16`, `0600` |
| **Processed-id archive + 30-day TTL** | Replaying an old payment message | [Storage](../pillars/nostr-storage.md) (`processed` db) |
| **NIP-98 single-use auth** | Replaying a name registration request | [Name authority](../features/name-authority.md) |
| **Per-sender rate limits** | Spam flooding from one key | [NostrService](../pillars/nostr-service.md) (contact 30/h, unknown 10/h) |
| **Everything over Tor, no clearnet lookups** *(when Tor routing is on)* | Your IP / network location exposed to the relay and on-path observers | [Tor](../pillars/tor.md), [Name resolution](../pillars/tor-dns.md) |
| **Relay-side randomized release + NIP-59 backdating** | Matching a send to a receive by timing | [Tor pillar](../pillars/tor.md#timing-privacy-the-relay-does-it) |
| **Hostname-validated TLS over every circuit** | A hostile hop or lying resolver reading or MITMing a connection | [Tor](../pillars/tor.md), [Tor exit path](../pillars/tor-exit.md) |
| **NIP-44 v3 context binding (when negotiated)** | Ciphertext from one wrap layer replayed as the other | [Protocol](../pillars/nostr-protocol.md#encryption-nip-44-v3-with-v2-fallback) |
| **Relays gated by a local NIP-11 probe** | A broken or hostile relay pool entry silently dropping payments | [Relays](../pillars/nostr-relays.md#the-candidate-pool) |
| **Reserved names, homograph folding, cooldown** | Impersonation / squatting on names | [Name authority](../features/name-authority.md) |
| **Tag-independent classification** | A sender lying about message type via tags | [Protocol](../pillars/nostr-protocol.md) (classify by parsed slate only) |
| **A failed dispatch is final** | One intended payment being paid twice after *Try again* | [Send & request](../features/send-request.md), [Ingest policy](../pillars/nostr-ingest.md) (`nostr_cancel_slate()`; `SendFailed` never finalized or re-sent) |
| **One cancel-safety rule** | Cancelling a payment that may already be on chain | [Cancel & decline](../features/cancel-decline.md#when-cancel-is-offered-the-cancel-safety-rule) (`cancel_safe()`) |
| **Sessions never touch payment messages; crypto needs the Direct messages grant** | A trusted site reading or writing your wallet's payment messages | [Authorize Sessions](../features/authorize-sessions.md) (`is_wallet_protocol_payload()`, `decide_crypto()`) |
| **Site HTTP auth for its own domain only; strict site domains and callback binding** | A site's signature or token being used at another service | [Authorize Sessions](../features/authorize-sessions.md#reference), [Sign in](../features/sign-in.md) (`http_auth_target()`, `domain_bound()`) |
| **Password change moves seed and identities together** | A wallet left with the seed and identities on different passwords | [Identity](../pillars/nostr-identity.md#how-it-works) (`change_password()`) |
| **Secret screens hidden from capture; secret copies cleared after 45 s** *(capture: Android)* | A seed or `nsec` leaking through screenshots, screen recording, the Recents view or the clipboard | [Identity](../pillars/nostr-identity.md#how-it-works) (`FLAG_SECURE`, `copySecretText`) |
| **Overlay touches ignored on money-commit screens** *(Android)* | Another app's window steering a hold-to-send or hold-to-accept | [Send & request](../features/send-request.md) (`touch_filter_wanted()`) |

On the server side, the [name authority](../self-hosting/name-authority.md) runs under a hardened systemd sandbox and trusts an `X-Real-IP` set by its reverse proxy for rate limiting. Because many Goblin clients reach the relay over Tor (those connections arrive from shared Tor exit IPs), server-side abuse controls are tuned to be per-connection / per-account rather than naive per-IP.

## References

- Ingest invariants: `goblin/src/nostr/ingest.rs`.
- Protocol ceilings + tag-independence: `goblin/src/nostr/protocol.rs`.
- Slatepack precheck and parse-attempt markers: `goblin/src/wallet/slatepack_precheck.rs:102` (`precheck()`), `goblin/src/nostr/client/service.rs:1971-2001`.
- Key at rest: `goblin/src/nostr/identity.rs`.
- Failed dispatch and the cancel-safety rule: `nostr_cancel_slate()` (`goblin/src/wallet/wallet.rs:4081`), `cancel_safe()` (`goblin/src/wallet/types.rs:417`).
- Session guards: `goblin/src/nostr/session/classify.rs:158` (`is_wallet_protocol_payload()`), `:251` (`http_auth_target()`); `goblin/src/nostr/session/mod.rs:339` (`decide_crypto()`); `goblin/src/nostr/authuri.rs:223`, `:323` (site domain, callback binding).
- Android capture, clipboard and overlay guards: `goblin/android/app/src/main/java/mw/gri/android/MainActivity.java:387-413` (touch filter), `:552-610` (secret copy and clear), `:826` (`FLAG_SECURE`).
- Replay protection: `goblin/src/nostr/store.rs` and the server's NIP-98 handling.
- Live guards are covered by `goblin/tests/{nostr_e2e,replay_check}.rs`.
