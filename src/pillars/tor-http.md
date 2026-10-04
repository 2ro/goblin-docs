# HTTP over Tor

> **Summary.** With [Tor routing](tor.md#tor-routing-is-a-per-wallet-setting) on, every HTTP request Goblin makes (NIP-05 name resolution and registration, sign-in and trust callbacks, the price feed, avatar fetches, the relay pool and its NIP-11 probes, the update check) goes through [Tor](tor-client.md) via a Tor-exit circuit to the destination's ordinary clearnet host. TLS is validated against the hostname, and HTTP/1.1 runs on top. A Tor request never falls back to the clear net, and there is no onion hop for any of it. Each request names its route: a wallet's requests follow that wallet's own setting, and the price feed and update check follow an app-level rule.

## Motivation

It would be easy to leave "just a name lookup" or "just the price" on the clear net even when the wallet is otherwise private. Goblin deliberately doesn't: a name lookup reveals *who you're about to pay*, and any clearnet request reveals your IP and ties you to the app. So whenever [Tor routing](tor.md#tor-routing-is-a-per-wallet-setting) is on the rule is simple and absolute, **everything over Tor**, with no side channel left on the clear net to audit for. (When a wallet is in clearnet mode these same requests go direct, the deliberate trade the user chose.)

## How it works

**Which route a request takes.** The caller always passes a route; no process-wide flag decides it. A request made for a wallet (name lookups and registration, sign-in and trust callbacks, avatars, the pool refresh and NIP-11 probes) passes that wallet's own Tor setting, read when the request leaves, so with two wallets open each one's requests go its own way. The price feed and the update check belong to no wallet and use the app-level route: Tor, unless at least one wallet is open and every open wallet has Tor off. A direct route never waits on the Tor bootstrap.

On a Tor route, the shared HTTP helper waits for the [Tor client](tor-client.md) to be ready (starting it lazily if needed; if it is not ready in time the request is dropped, never sent direct), then for each redirect hop:

1. **Every request rides a Tor-exit circuit.** The hostname, whether it's `goblin.st`, the money-path relay's own host (in practice its NIP-11 probe), or the pool refresh/price/avatar hosts, is handed to Tor by hostname and carried out through a normal exit relay, which performs the DNS lookup. Neither the lookup nor the body ever touches the clear net from the device. (An earlier build dialed the name authority at a pinned `.onion`; build134 dropped that in favor of this single path, see [The relay's Tor exit path](tor-exit.md).)
2. **TLS.** For `https` the Tor byte stream is wrapped in TLS and validated against the **hostname**, so a lying resolver or a hostile hop cannot man-in-the-middle the request.
3. **HTTP/1.1** via hyper: a generic desktop-browser user agent (so the traffic doesn't announce itself as Goblin), the caller's method, headers, and body, with a generous per-hop budget.
4. **Redirects** are followed like a browser, up to a small hop cap: 301/302/303 turn into a bodiless GET, 307/308 replay the method and body.

Logs never contain full URLs, only hosts. A string-bodied convenience wrapper sits on top of the byte-level helper.

**Connections are reused.** HTTP over Tor keeps circuits warm and reuses connections (keep-alive) instead of a fresh handshake per request, which is what makes repeated price and username lookups cheap. The **price feed** in particular paints instantly: the last fetched rate (if recent) shows on the very first frame, and a live fetch fires the moment Tor is ready rather than waiting for the balance screen.

## Reference

- `http_request_bytes(route, method, url, body, headers) -> Option<(u16, Vec<u8>)>` and the `String`-bodied `http_request(route, ...)`: the HTTP chokepoint (`goblin/src/tor/mod.rs:172`, `:220`). `Route::Tor` goes through arti; `Route::Clearnet` goes direct (`tor/mod.rs:80-105`).
- `app_route()` (`tor/mod.rs:127-138`): the app-level rule over the open wallets, used by the price feed (`goblin/src/http/price.rs:248`) and the update check (`goblin/src/http/release.rs:148`).
- `DEFAULT_USER_AGENT` (`tor/mod.rs:71`).
- Per request on the Tor route: a Tor-exit circuit to the clearnet host, then a hostname-validated TLS wrap and one hyper HTTP/1.1 exchange.

## References

- Where these calls originate: [NIP-05 name authority](../features/name-authority.md) (`goblin/src/nostr/nip05.rs`), the [relay pool](nostr-relays.md#the-candidate-pool) (`goblin/src/nostr/pool.rs`), and the price/avatar fetchers.
- The client underneath: [The embedded Tor client](tor-client.md).
- Why the wallet needs no DNS resolver: [Name resolution under Tor](tor-dns.md).
