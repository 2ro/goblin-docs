# DNS over the mixnet

> **Summary.** Before the tunnel can dial `relay.example` it has to resolve the name itself, and a clearnet DNS lookup would announce exactly which relays and hosts the wallet talks to. So Goblin resolves **through the tunnel**, over DNS-over-TLS (DoT), with DNS-over-HTTPS (DoH) as an in-tunnel fallback. Answers are cached and prewarmed. There is never a clearnet lookup, and the [scoped relay exit](nym-exit.md) needs no DNS at all.

## Motivation

The tunnel connects to IP addresses, so hostname resolution is the wallet's job. Doing it on the clear would leak precisely the metadata the mixnet exists to hide.

The transport also matters. The first implementation sent plain UDP DNS over the mixnet, and mixnet UDP loses packets: a lost datagram stalled behind multi-second timeouts (resolves measured at ~10 seconds), which tipped relay connects past the exit watchdog's grace and drove a minutes-long reselect loop. Moving to DoT fixed both axes at once: TCP retransmits (no packet-loss stalls) and TLS encrypts the query end to end, so not even the exit can see, or forge, which host was asked for.

## How it works

- **DoT first.** An A query is fired at two resolvers **concurrently** (Cloudflare `1.1.1.1` and Quad9 `9.9.9.9`, on port 853) and the first valid answer wins, so one slow handshake never stalls a lookup. The resolvers are addressed by IP (no bootstrap circularity) and each TLS session is validated against the resolver's certificate name, so a hostile exit cannot redirect a lookup.
- **DoH fallback.** If an exit's policy blocks port 853 entirely, lookups switch (stickily, for that exit) to DoH on port 443, which is always reachable since relays and HTTPS already ride it. Both transports run **inside the tunnel**; there is no clearnet fallback by design.
- **Cache + prewarm.** Answers land in a TTL-respecting in-memory cache (clamped between 1 minute and 1 hour), and known hosts are resolved in a batch at startup, so the common case is a warm cache hit rather than a fresh mixnet round trip.
- **The liveness probe.** The tunnel watchdog's exit-health probe also lives here: a TCP connect through the tunnel to a stable public address. Because TCP retransmits, a single lost packet can't falsely condemn a healthy exit the way the old UDP probe could.

A legacy UDP path is retained behind `GOBLIN_DNS_UDP=1` purely for measuring the regression it caused; it is never used in shipped builds.

## Reference

In `goblin/src/nym/dns.rs`:

- `resolve(tunnel, host, port)`: IP literals skip DNS; cache, then DoT rounds, then the sticky DoH fallback (`PREFER_DOH`).
- `DOT_RESOLVERS` / `DOH_RESOLVERS`: the raced resolver pairs with their SNI names; `query_dot()` (RFC 7858 length-framed messages), `query_doh()` (RFC 8484 POST).
- Wire codec: `hickory-proto` (`encode_query()` / `parse_response()`, transaction-id and rcode checked, only A records accepted).
- `prewarm(tunnel, hosts)`: startup batch resolution; `probe(tunnel)`: the exit-liveness TCP connect used by [the watchdog](nym-client.md).
- Budgets: 8 s per DoT query, 10 s per DoH query, 2 rounds each; TTL clamp 60 s to 3600 s.

## References

- Who calls `resolve()`: [Relay transport](nym-relay-transport.md) and [HTTP](nym-http.md).
- DoT: RFC 7858. DoH: RFC 8484.
