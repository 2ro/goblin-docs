# HTTP over Tor

> **Summary.** Every HTTP request Goblin makes (NIP-05 name resolution and registration, the price feed, avatar fetches, the relay pool and its NIP-11 probes) goes through [Tor](nym-client.md). Requests to the `goblin.st` name authority ride a circuit to its pinned [`.onion`](nym-exit.md); the small clearnet lookups (pool refresh, price, avatars) ride Tor out through an exit relay, which resolves the hostname for you. TLS is validated against the hostname, and HTTP/1.1 runs on top. There is no clearnet HTTP path from the device.

## Motivation

It would be easy to leave "just a name lookup" or "just the price" on the clear net. Goblin deliberately doesn't: a name lookup reveals *who you're about to pay*, and any clearnet request reveals your IP and ties you to the app. The rule is simple and absolute: **everything over Tor**, so there's no accidental leak to audit for.

## How it works

The shared HTTP helper waits for the [Tor client](nym-client.md) to be ready (starting it lazily if needed), then for each redirect hop:

1. **Circuit pick.** A request to the name authority is dialed at its **pinned `.onion`** — the most sensitive HTTP the wallet makes, since it names who you're about to pay, so it never leaves an onion circuit. HTTPS to the money-path relay's own host (in practice its NIP-11 probe) rides that relay's onion. Every other request — the pool refresh, price, avatars — is handed to Tor **by hostname** and carried out through an exit relay, which does the DNS. Neither the lookup nor the body ever touches the clear net from your device.
2. **TLS.** For `https` the Tor byte stream is wrapped in TLS and validated against the **hostname**, so a lying resolver or a hostile hop cannot man-in-the-middle the request.
3. **HTTP/1.1** via hyper: a fixed `goblin-wallet` user agent, the caller's method, headers, and body, with a generous per-hop budget.
4. **Redirects** are followed like a browser, up to a small hop cap: 301/302/303 turn into a bodiless GET, 307/308 replay the method and body.

Logs never contain full URLs, only hosts. A string-bodied convenience wrapper sits on top of the byte-level helper.

**Connections are reused.** HTTP over Tor keeps circuits warm and reuses connections (keep-alive) instead of a fresh handshake per request, which is what makes repeated price and username lookups cheap. The **price feed** in particular paints instantly: the last fetched rate (if recent) shows on the very first frame, and a live fetch fires the moment Tor is ready rather than waiting for the balance screen.

## Reference

- `http_request_bytes(method, url, body, headers) -> Option<(u16, Vec<u8>)>` and the `String`-bodied `http_request(...)`: the HTTP chokepoint, re-routed through arti.
- Per request: the onion fork (`pool::onion_for_host(host)` and the pinned name-authority onion) via `TorClient::connect`, else a Tor circuit to the clearnet host; then a hostname-validated TLS wrap and one hyper HTTP/1.1 exchange.

## References

- Where these calls originate: [NIP-05 name authority](../features/name-authority.md) (`goblin/src/nostr/nip05.rs`), the [relay pool](nostr-relays.md#the-candidate-pool) (`goblin/src/nostr/pool.rs`), and the price/avatar fetchers.
- The client underneath: [The embedded Tor client](nym-client.md).
- Why the name authority needs no DNS: [Name resolution under Tor](nym-dns.md).
