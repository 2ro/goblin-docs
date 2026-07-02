# The payment protocol (NIP-17 / 44 / 59)

> **Summary.** A Grin slatepack is delivered as a [NIP-17](https://nips.nostr.com/17) private direct message: a `kind 14` rumor carrying the slatepack armor, sealed and **gift-wrapped** ([NIP-59](https://nips.nostr.com/59)) inside a `kind 1059` event encrypted with [NIP-44](https://nips.nostr.com/44) (v3 when both wallets support it, v2 otherwise). Relays see only the wrap: not the content, not the real sender, not the timestamp.

## Motivation

The courier needs three properties Grin's bare slatepack doesn't have on its own:

1. **Confidentiality**: a relay must not read the slatepack (it would reveal a pending payment and its amount).
2. **Sender privacy**: a relay must not even learn *who* sent the message.
3. **A stable, versioned wire format**: so two Goblin wallets (and other NIP-17 clients) agree on how to read it.

NIP-17/44/59 give the first two for free; Goblin adds a thin, explicit protocol on top for the third.

## How it works

A payment message is built in layers:

```
kind 14 rumor   ── content: PREAMBLE + "\n\n" + <slatepack armor>
   (unsigned)      tags: ["goblin","1"]  + optional ["subject", note]
      │
   NIP-59 seal (kind 13)  ── signed by the REAL sender, NIP-44 encrypted
      │
   NIP-59 gift wrap (kind 1059) ── signed by a throwaway EPHEMERAL key,
                                    NIP-44 encrypted to the recipient,
                                    timestamp randomized into the past
      │
   published to relays
```

- The **content** starts with a human-readable preamble (`"[Goblin] GRIN payment message: open in Goblin (https://goblin.st) to process."`), then a blank line, then the raw `BEGINSLATEPACK…ENDSLATEPACK` armor. Other NIP-17 clients render something legible; Goblin extracts the slate.
- A `["goblin","1"]` tag marks the protocol and its version. **Classification never trusts tags**: the wallet decides what a message *is* only by parsing the slate itself.
- An optional `["subject", …]` tag carries the payment note (sanitized, capped at 256 chars).
- Because the gift wrap is signed by an **ephemeral** key and the timestamp is randomized, a relay can't link the message to the sender or place it in time. The real sender is recoverable only *after* the recipient decrypts the inner seal.

### Encryption: NIP-44 v3 with v2 fallback

Both encrypted layers (the seal and the gift wrap) use [NIP-44](https://nips.nostr.com/44). Goblin speaks **v3** and negotiates it per recipient, with v2 as the always-safe fallback:

- **Advertising.** Your `kind 10050` DM-relay list carries an `encryption` tag with the wallet's capabilities, space-separated best-first: `nip44_v3 nip44_v2`.
- **Sending.** If the recipient's `10050` advertises `nip44_v3`, the wrap is built with v3: the seal's ciphertext is cryptographically bound to `kind 13` and the wrap's to `kind 1059`, so ciphertext produced for one layer cannot be replayed as the other. Everything else (tags, ephemeral wrap key, timestamp fuzzing) mirrors the v2 builders exactly. No tag, or a v2-only tag, means v2.
- **Receiving.** Unwrapping dispatches on the payload's version byte (`0x02` is v2, `0x03` is v3); unknown versions and malformed payloads are rejected cleanly. A wallet that only speaks v2 is completely unaffected: it receives v2 wraps and its own wraps still decrypt.

### Control messages (void)

Cancelling or declining a request is the same wire message (*"this request is off"*), differing only by who sends it. It's a `kind 14` rumor tagged `["goblin-action","void", <slate_id>]`, gift-wrapped the same way. The receiver reads the `goblin-action` tag and voids the matching request. See [Cancel & decline](../features/cancel-decline.md).

### Size ceilings

Hard limits are enforced before doing any work, as a denial-of-service guard:

| Limit | Value |
| --- | --- |
| Gift wrap content (before unwrap) | 64 KiB |
| Rumor content (after unwrap) | 32 KiB |
| Slatepack armor | 30 KiB |
| Note (after sanitize) | 256 chars |

## Reference

All in `goblin/src/nostr/protocol.rs`:

- Constants: `MAX_WRAP_CONTENT`, `MAX_RUMOR_CONTENT`, `MAX_SLATEPACK`, `MAX_NOTE_CHARS`; `GOBLIN_TAG = "goblin"`, `PROTOCOL_VERSION = "1"`, `GOBLIN_ACTION_TAG = "goblin-action"`, `ACTION_VOID = "void"`, `PREAMBLE`.
- Builders: `build_payment_content()`, `build_rumor_tags()`, `build_control_content()`, `build_control_tags()`.
- Parsers: `extract_slatepack()` (matches exactly one armor block), `extract_subject()`, `extract_control()`, `sanitize_note()`.
- v2 sealing/wrapping is handled by the `nostr-sdk` gift-wrap APIs; v3 by `goblin/src/nostr/wrapv3.rs` (`ENCRYPTION_CAPABILITY`, `peer_supports_v3()`, `wrap()`, and the version-dispatched `unwrap()`). Both are driven from the [send pipeline](nostr-service.md), which reads the recipient's capability from their `kind 10050`.

## References

- NIP-17 (private DMs): <https://nips.nostr.com/17>.
- NIP-44 (versioned encryption): <https://nips.nostr.com/44>.
- NIP-59 (gift wrap / seal): <https://nips.nostr.com/59>.
- `kind 1059` gift wrap: <https://nostrbook.dev/kinds/1059>.
- Grin slatepacks: <https://docs.grin.mw>.
