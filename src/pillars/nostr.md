# Nostr in Goblin

> **Summary.** Goblin uses [Nostr](https://github.com/nostr-protocol/nostr) as its messaging and identity layer. A Grin slatepack is wrapped as an encrypted Nostr direct message and delivered through public relays; your identity is a Nostr keypair with an optional human-readable [NIP-05](../features/name-authority.md) username. Relays buffer messages, so payments are asynchronous; relays see only ciphertext.

## Why Nostr

The hard part of a Grin payment is getting the two slatepack legs between sender and receiver. That is a **messaging** problem: a small encrypted blob needs to reach a specific recipient, who might be offline, identified by something friendlier than a 90-character address.

Nostr is a good fit because it already solves the boring parts:

- **Addressing by key.** Every user is a public key; you message a key.
- **Store-and-forward.** Relays hold events for offline clients and deliver them on reconnect: exactly the asynchronous mailbox an interactive payment needs.
- **A real encryption story.** [NIP-17 / NIP-44 / NIP-59](nostr-protocol.md) give sealed, gift-wrapped DMs where relays can't read the content *or* see the real sender.
- **Human names without a blockchain.** [NIP-05](../features/name-authority.md) maps `alice@goblin.st` to a key over plain HTTPS.
- **An existing, decentralized network.** No bespoke server to run; any relay works, and you can run your own.

Goblin could have built a custom relay (the way [grinbox](https://github.com/vault713/grinbox) did for Grin years ago). Using Nostr instead means inheriting a maintained ecosystem and standard, audited encryption, and adding a mixnet *underneath* for the metadata privacy Nostr alone doesn't provide.

## The parts

The Nostr layer (`goblin/src/nostr/`) breaks into six components, each with its own page:

| Page | What it covers | Key file |
| --- | --- | --- |
| [Identity](nostr-identity.md) | The nostr keypair, encryption at rest, rotation | `identity.rs` |
| [Payment protocol](nostr-protocol.md) | How a slatepack becomes a gift-wrapped event | `protocol.rs` |
| [The NostrService](nostr-service.md) | The per-wallet relay thread + send pipeline | `client.rs` |
| [Ingest policy](nostr-ingest.md) | What the wallet accepts, and what it never does | `ingest.rs` |
| [Storage, config & types](nostr-storage.md) | The metadata archive and per-wallet settings | `store.rs`, `config.rs`, `types.rs` |
| [Relays](nostr-relays.md) | Defaults, DM relay lists, the editor | `relays.rs` |

## The NIPs Goblin implements

NIP-05 (names), NIP-06 (key derivation), NIP-17 (private DMs), NIP-19 (`npub`/`nprofile` encoding), NIP-44 (encryption), NIP-49 (encrypted key at rest), NIP-59 (gift wrap), NIP-65 (relay lists), NIP-98 (HTTP auth). Each is cited on the page where it's used.

## References

- `goblin/src/nostr/`: the whole layer (`mod.rs` re-exports the public surface).
- Nostr protocol & NIPs: <https://github.com/nostr-protocol/nips>, <https://nostrbook.dev>.
