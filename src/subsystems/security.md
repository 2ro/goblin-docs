# Security hardening

> **Summary.** A grab-bag of the defensive choices that don't fit on one feature page: never auto-paying a request, binding replies to the expected counterparty, hard size ceilings, encrypted keys at rest, replay protection, rate limiting, and routing everything over Tor. This page is a map to where each lives.

## Motivation

A wallet that accepts messages from strangers and moves money is an attractive target. Goblin's posture is defense-in-depth: assume any incoming message is hostile, validate before acting, cap everything, and never let the network see more than ciphertext.

## The measures

| Measure | What it prevents | Where |
| --- | --- | --- |
| **Requests are never auto-paid** | A stranger draining you with an Invoice-1 | [Ingest policy](../pillars/nostr-ingest.md) (`decide()` → `SurfaceRequest`) |
| **Replies bound to counterparty + pending tx** | A forged Standard-2/Invoice-2 finalizing something | [Ingest policy](../pillars/nostr-ingest.md) |
| **Size ceilings (64 K / 32 K / 30 K / 256)** | Memory-blow-up / DoS via huge messages | [Protocol](../pillars/nostr-protocol.md) constants |
| **Encrypted key at rest** | Offline key theft; password grinding | [Identity](../pillars/nostr-identity.md): NIP-49 `ncryptsec`, scrypt `log_N=16`, `0600` |
| **Processed-id archive + 30-day TTL** | Replaying an old payment message | [Storage](../pillars/nostr-storage.md) (`processed` db) |
| **NIP-98 single-use auth** | Replaying a name registration request | [Name authority](../features/name-authority.md) |
| **Per-sender rate limits** | Spam flooding from one key | [NostrService](../pillars/nostr-service.md) (contact 30/h, unknown 10/h) |
| **Everything over Tor, no clearnet lookups** | Your IP / network location exposed to the relay and on-path observers | [Tor](../pillars/tor.md), [Name resolution](../pillars/tor-dns.md) |
| **Relay-side randomized release + NIP-59 backdating** | Matching a send to a receive by timing | [Tor pillar](../pillars/tor.md#timing-privacy-the-relay-does-it) |
| **Hostname-validated TLS over every circuit** | A hostile hop or lying resolver reading or MITMing a connection | [Tor](../pillars/tor.md), [Tor exit path](../pillars/tor-exit.md) |
| **NIP-44 v3 context binding (when negotiated)** | Ciphertext from one wrap layer replayed as the other | [Protocol](../pillars/nostr-protocol.md#encryption-nip-44-v3-with-v2-fallback) |
| **Relays gated by a local NIP-11 probe** | A broken or hostile relay pool entry silently dropping payments | [Relays](../pillars/nostr-relays.md#the-candidate-pool) |
| **Reserved names, homograph folding, cooldown** | Impersonation / squatting on names | [Name authority](../features/name-authority.md) |
| **Tag-independent classification** | A sender lying about message type via tags | [Protocol](../pillars/nostr-protocol.md) (classify by parsed slate only) |

On the server side, the [name authority](../self-hosting/name-authority.md) runs under a hardened systemd sandbox and trusts an `X-Real-IP` set by its reverse proxy for rate limiting. Because Goblin clients reach the relay over Tor (every connection arrives from a shared Tor exit IP), server-side abuse controls are tuned to be per-connection / per-account rather than naive per-IP.

## References

- Ingest invariants: `goblin/src/nostr/ingest.rs`.
- Protocol ceilings + tag-independence: `goblin/src/nostr/protocol.rs`.
- Key at rest: `goblin/src/nostr/identity.rs`.
- Replay protection: `goblin/src/nostr/store.rs` and the server's NIP-98 handling.
- Live guards are covered by `goblin/tests/{nostr_e2e,replay_check}.rs`.
