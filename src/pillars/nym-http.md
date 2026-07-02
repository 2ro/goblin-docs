# HTTP over the mixnet

> **Summary.** Every HTTP request Goblin makes (NIP-05 name resolution and registration, the price feed, avatar fetches, the relay pool and its NIP-11 probes) goes through the mixnet: the hostname is resolved over [encrypted DNS](nym-dns.md), TCP runs through the [tunnel](nym-client.md), TLS is validated against the hostname, and HTTP/1.1 runs on top. HTTPS to a host whose relay advertises a [scoped exit](nym-exit.md) rides that exit instead. There is no clearnet HTTP path.

## Motivation

It would be easy to leave "just a name lookup" or "just the price" on the clear net. Goblin deliberately doesn't: a name lookup reveals *who you're about to pay*, and any clearnet request reveals your IP and ties you to the app. The rule is simple and absolute: **everything over the mixnet**, so there's no accidental leak to audit for.

## How it works

`http_request_bytes()` waits for the shared tunnel (up to 30 seconds, starting it lazily if needed), then for each redirect hop:

1. **Egress pick.** HTTPS to a host whose relay entry advertises a co-located exit (in practice, the money-path relay's NIP-11 probe) dials through that exit; any failure, and every other request, resolves the host over [DoT](nym-dns.md) and opens TCP through the tunnel. Neither the lookup nor the body ever touches the clear.
2. **TLS.** For `https` the stream is wrapped in rustls with webpki roots and validated against the **hostname**, even though the dial went to a resolved IP, so a lying resolver or a hostile exit cannot man-in-the-middle the request.
3. **HTTP/1.1** via hyper: a fixed `goblin-wallet` user agent, the caller's method, headers, and body, and a generous 60-second per-hop budget, because the mixnet adds deliberate per-hop delay.
4. **Redirects** are followed like a browser, up to 5 hops: 301/302/303 turn into a bodiless GET, 307/308 replay the method and body.

Logs never contain full URLs, only hosts. A string-bodied convenience wrapper, `http_request()`, sits on top.

## Reference

In `goblin/src/nym/mod.rs`:

- `http_request_bytes(method, url, body, headers) -> Option<(u16, Vec<u8>)>` and the `String`-bodied `http_request(...)`.
- `request_once()`: the exit fork (`pool::exit_for_host(host)`), `dns::resolve()`, `tunnel.tcp_connect()`, `tls_connect()` (rustls + webpki roots, hostname-validated), one hyper HTTP/1.1 exchange.
- `exit_connect()`: a mixnet stream to the operator's exit + the same `tls_connect()`, bounded by the shared bootstrap cap.
- Budgets: `HTTP_TIMEOUT` (60 s per hop), `TUNNEL_WAIT` (30 s), `MAX_REDIRECTS` (5).

## References

- Where these calls originate: [NIP-05 name authority](../features/name-authority.md) (`goblin/src/nostr/nip05.rs`), the [relay pool](nostr-relays.md#the-candidate-pool) (`goblin/src/nostr/pool.rs`), and the price/avatar fetchers.
- The tunnel underneath: [The in-process mixnet tunnel](nym-client.md).
