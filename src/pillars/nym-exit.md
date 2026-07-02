# The scoped relay exit

> **Summary.** Goblin's money-path relay (`relay.floonet.dev` by default) is reached through a **scoped mixnet exit**: a small forwarder the relay's operator runs next to the relay, which pipes mixnet traffic to that one relay and nowhere else. The wallet dials it directly over the mixnet by Nym address, so the payment path needs **no public DNS** and doesn't depend on a shared public exit, and it is fast: the relay connects in a couple of seconds from a cold start, and a funded payment finalizes in about six. It is an anchor with a fallback: if the exit is unavailable for any reason, the wallet transparently uses the [regular tunnel](nym-client.md), so availability is never reduced.

## Motivation

The tunnel path leaves the payment path with two dependencies the wallet doesn't control: a public DNS answer for the relay's hostname, and whichever shared public exit the tunnel happened to select. Both are usually fine, and both are the flakiest links in the chain (a public exit can go bad at any moment; a DNS lookup is one more mixnet round trip that can stall).

A relay operator can remove both. By running a tiny mixnet exit co-located with the relay, the wallet can reach the relay by **Nym address alone**: one mixnet stream, straight from the wallet to the operator's own machine, piped into the relay. And because the exit forwards to exactly one destination, it is not an open proxy: there is no exit policy to manage and no abuse surface for the operator.

## How it works

- **Discovery.** Each entry in the [relay candidate pool](nostr-relays.md#the-candidate-pool) may carry an `exit` field: the Nym address (`<client>.<enc>@<gateway>`) of that operator's co-located exit. The pinned pool compiled into the app carries the exit for `relay.floonet.dev`, so the money path bootstraps offline, before any network fetch, with no chicken-and-egg on learning the address.
- **Dialing.** When the [relay transport](nym-relay-transport.md) (or an [HTTPS request](nym-http.md) to the same host, such as the relay's NIP-11 probe) targets a relay with an advertised exit, the wallet opens a mixnet stream straight to the exit. The exit pipes the raw bytes to its one configured relay.
- **TLS is end to end.** The stream then carries exactly the same hostname-validated TLS + websocket handshake as the tunnel path (SNI is the relay host, certificates checked against webpki roots). The exit sees only ciphertext; a hostile or compromised exit cannot read or tamper with the connection.
- **Anchor + fallback, never pin-only.** Every failure (a bad address, a stuck mixnet bootstrap, a failed stream open, a TLS timeout) simply falls through to the tunnel path. The whole dial is capped by the same 20-second bootstrap budget as the tunnel, so a dead exit costs seconds, and the TLS handshake itself doubles as the exit liveness probe.

### The fast money path

Dialing the exit skips both slow legs of the tunnel path: the in-mixnet DNS lookup and the shared public exit (the public-IPR hop). The result is the fastest connection the wallet makes: against the default relay, a **cold app start connects in about 0–2 seconds**, and a funded payment finalizes in about **6 seconds** end to end. Over the public-IPR route the same first connect used to take anywhere from 15 seconds to 3 minutes. A wallet that has to fall back to the tunnel pays that older cost, never a dead end, and discovery and secondary relays never wait on the exit either way.

## Running one

The exit holds an ordinary, unbonded Nym client identity: no bonding, no NYM tokens, no exit policy. It ships **bundled in both [Floonet](https://docs.floonet.dev) relay packages** behind a single config toggle: `COMPOSE_PROFILES=exit` for floonet-strfry, `[exit] enabled = true` for floonet-rs. The instance serving `relay.floonet.dev` (floonet-strfry with the exit enabled) is the first production deployment. See [Run a mixnet exit](../self-hosting/nym-requester.md) for the operator-side picture and the [Floonet docs](https://docs.floonet.dev) for the packages themselves.

## Reference

- `goblin/src/nym/streamexit.rs`: `open_stream(exit, timeout)` (parse, capped dial, 3 s post-open settle so the exit is listening before the first byte); the shared lazily-connected mixnet client (ephemeral identity, dropped and reconnected if it dies).
- `goblin/src/nostr/pool.rs`: `PoolRelay::exit`, `exit_for()` (websocket dials, keyed by relay URL), `exit_for_host()` (HTTPS dials, keyed by hostname).
- Dial sites: `goblin/src/nym/transport.rs` (`exit_connect`) and the HTTP path in `goblin/src/nym/mod.rs`.
- Live proof: the ignored `live_exit_roundtrip` test in `streamexit.rs` dials the deployed exit over the mixnet, runs the real TLS + websocket handshake, and round-trips a Nostr REQ.

## References

- The fallback path: [The in-process mixnet tunnel](nym-client.md).
- Where the exit address comes from: [Relays](nostr-relays.md).
- Nym stream API: <https://nym.com/docs/developers/rust>.
