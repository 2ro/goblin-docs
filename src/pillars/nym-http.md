# HTTP over the mixnet

> **Summary.** Every HTTP request Goblin makes (NIP-05 name resolution and registration, the price feed, avatar fetches) goes through the local Nym SOCKS5 proxy as a `socks5h://127.0.0.1:1080` proxy. Generous timeouts account for mixnet latency. There is no clearnet HTTP path.

## Motivation

It would be easy to leave "just a name lookup" or "just the price" on the clear net. Goblin deliberately doesn't: a name lookup reveals *who you're about to pay*, and any clearnet request reveals your IP and ties you to the app. The rule is simple and absolute: **everything over the mixnet**, so there's no accidental leak to audit for.

## How it works

`http_request_bytes()` builds a `reqwest` client configured with the Nym proxy and a fixed `goblin-wallet` user agent, sends the request, and returns `(status, body)`. Because the proxy URL uses the `socks5h` scheme, DNS resolution happens inside the proxy (mixnet), not locally. The timeout is generous (60 s) because the mixnet adds deliberate per-hop delay: a name lookup that would be instant on the clear net might take a couple of seconds here, which is fine for the interactions involved. A string-bodied convenience wrapper, `http_request()`, sits on top.

Callers include:

- **NIP-05** resolution (`/.well-known/nostr.json?name=…`), registration/release (NIP-98-authenticated `POST`/`DELETE`), and reverse `name-by-pubkey` lookup.
- **Avatars**: fetching a contact's image from the authority.
- **Price**: the fiat/BTC rate for the amount preview.

## Reference

In `goblin/src/nym/mod.rs`:

- `SOCKS5_HOST` / `SOCKS5_PORT = 1080`; `proxy_url()` → `socks5h://127.0.0.1:1080`; `socks5_addr()` → `127.0.0.1:1080` (raw TCP for the [relay transport](nym-relay-transport.md)).
- `http_request_bytes(method, url, body, headers) -> Option<(u16, Vec<u8>)>`: reqwest client with `Proxy::all(proxy_url())`, `user_agent("goblin-wallet")`, 60 s timeout.
- `http_request(...)`: `String`-bodied wrapper.

## References

- Where these calls originate: [NIP-05 name authority](../features/name-authority.md) (`goblin/src/nostr/nip05.rs`), and the price/avatar fetchers.
- The proxy itself: [The in-process mixnet client](nym-client.md).
