# HTTP over Tor

> **Summary.** Every HTTP request Goblin makes (NIP-05 name resolution and registration, the price feed, avatar fetches, the relay pool and its NIP-11 probes) goes through [Tor](tor-client.md) via a Tor-exit circuit to the destination's ordinary clearnet host. TLS is validated against the hostname, and HTTP/1.1 runs on top. There is no clearnet HTTP path from the device, and no onion hop for any of it.

## Motivation

It would be easy to leave "just a name lookup" or "just the price" on the clear net. Goblin deliberately doesn't: a name lookup reveals *who you're about to pay*, and any clearnet request reveals your IP and ties you to the app. The rule is simple and absolute: **everything over Tor**, so there's no accidental leak to audit for.

## How it works

The shared HTTP helper waits for the [Tor client](tor-client.md) to be ready (starting it lazily if needed), then for each redirect hop:

1. **Every request rides a Tor-exit circuit.** The hostname, whether it's `goblin.st`, the money-path relay's own host (in practice its NIP-11 probe), or the pool refresh/price/avatar hosts, is handed to Tor by hostname and carried out through a normal exit relay, which performs the DNS lookup. Neither the lookup nor the body ever touches the clear net from the device. (An earlier build dialed the name authority at a pinned `.onion`; build134 dropped that in favor of this single path, see [The relay's Tor exit path](tor-exit.md).)
2. **TLS.** For `https` the Tor byte stream is wrapped in TLS and validated against the **hostname**, so a lying resolver or a hostile hop cannot man-in-the-middle the request.
3. **HTTP/1.1** via hyper: a fixed `goblin-wallet` user agent, the caller's method, headers, and body, with a generous per-hop budget.
4. **Redirects** are followed like a browser, up to a small hop cap: 301/302/303 turn into a bodiless GET, 307/308 replay the method and body.

Logs never contain full URLs, only hosts. A string-bodied convenience wrapper sits on top of the byte-level helper.

**Connections are reused.** HTTP over Tor keeps circuits warm and reuses connections (keep-alive) instead of a fresh handshake per request, which is what makes repeated price and username lookups cheap. The **price feed** in particular paints instantly: the last fetched rate (if recent) shows on the very first frame, and a live fetch fires the moment Tor is ready rather than waiting for the balance screen.

## Reference

- `http_request_bytes(method, url, body, headers) -> Option<(u16, Vec<u8>)>` and the `String`-bodied `http_request(...)`: the HTTP chokepoint, routed through arti.
- Per request: a Tor-exit circuit to the clearnet host, then a hostname-validated TLS wrap and one hyper HTTP/1.1 exchange.

## References

- Where these calls originate: [NIP-05 name authority](../features/name-authority.md) (`goblin/src/nostr/nip05.rs`), the [relay pool](nostr-relays.md#the-candidate-pool) (`goblin/src/nostr/pool.rs`), and the price/avatar fetchers.
- The client underneath: [The embedded Tor client](tor-client.md).
- Why the wallet needs no DNS resolver: [Name resolution under Tor](tor-dns.md).
