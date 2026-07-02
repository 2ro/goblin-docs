# The scoped relay exit

> **Summary.** Goblin's money-path relay (`relay.goblin.st` by default) is reached through a **scoped Nym exit**: a small forwarder the relay's operator runs next to the relay, which pipes mixnet traffic to that one relay and nowhere else. The wallet dials it directly over the mixnet by Nym address, so the payment path needs **no public DNS** and doesn't depend on a shared public exit. It is an anchor with a fallback: if the exit is unavailable for any reason, the wallet transparently uses the [regular tunnel](nym-client.md), so availability is never reduced.

## Motivation

The tunnel path leaves the payment path with two dependencies the wallet doesn't control: a public DNS answer for the relay's hostname, and whichever shared public exit the tunnel happened to select. Both are usually fine, and both are the flakiest links in the chain (a public exit can go bad at any moment; a DNS lookup is one more mixnet round trip that can stall).

A relay operator can remove both. By running a tiny mixnet exit co-located with the relay, the wallet can reach the relay by **Nym address alone**: one mixnet stream, straight from the wallet to the operator's own machine, piped into the relay. And because the exit forwards to exactly one destination, it is not an open proxy: there is no exit policy to manage and no abuse surface for the operator.

## How it works

- **Discovery.** Each entry in the [relay candidate pool](nostr-relays.md#the-candidate-pool) may carry an `exit` field: the Nym address (`<client>.<enc>@<gateway>`) of that operator's co-located exit. The pinned pool compiled into the app carries the exit for `relay.goblin.st`, so the money path bootstraps offline, before any network fetch, with no chicken-and-egg on learning the address.
- **Dialing.** When the [relay transport](nym-relay-transport.md) (or an [HTTPS request](nym-http.md) to the same host, such as the relay's NIP-11 probe) targets a relay with an advertised exit, the wallet opens a mixnet stream straight to the exit. The exit pipes the raw bytes to its one configured relay.
- **TLS is end to end.** The stream then carries exactly the same hostname-validated TLS + websocket handshake as the tunnel path (SNI is the relay host, certificates checked against webpki roots). The exit sees only ciphertext; a hostile or compromised exit cannot read or tamper with the connection.
- **Anchor + fallback, never pin-only.** Every failure (a bad address, a stuck mixnet bootstrap, a failed stream open, a TLS timeout) simply falls through to the tunnel path. The whole dial is capped by the same 20-second bootstrap budget as the tunnel, so a dead exit costs seconds, and the TLS handshake itself doubles as the exit liveness probe.

### The one-time cold-start cost

The exit egress rides a second mixnet client, separate from the tunnel and created lazily on first use. On a cold app start both clients have to acquire Nym bandwidth, and the grants serialize, so the **first relay connect after a cold start can take up to about a minute**. This is one-time per session: payments themselves are fast once connected, and the tunnel plus the automatic fallback keep the wallet usable in the meantime (discovery and secondary relays never wait on the exit). Sharing one mixnet client between the tunnel and the exit would remove this cost entirely and is tracked as future work.

## Running one

The exit holds an ordinary, unbonded Nym client identity: no bonding, no NYM tokens, no exit policy. The instance serving `relay.goblin.st` is the first deployment. Packaging that lets any relay operator flip on a co-located exit next to their own relay is planned but **not yet published**, so today the only scoped exit wallets use is the one advertised for the default relay. See [Run a Nym exit](../self-hosting/nym-requester.md) for the operator-side picture.

## Reference

- `goblin/src/nym/streamexit.rs`: `open_stream(exit, timeout)` (parse, capped dial, 3 s post-open settle so the exit is listening before the first byte); the shared lazily-connected mixnet client (ephemeral identity, dropped and reconnected if it dies).
- `goblin/src/nostr/pool.rs`: `PoolRelay::exit`, `exit_for()` (websocket dials, keyed by relay URL), `exit_for_host()` (HTTPS dials, keyed by hostname).
- Dial sites: `goblin/src/nym/transport.rs` (`exit_connect`) and the HTTP path in `goblin/src/nym/mod.rs`.
- Live proof: the ignored `live_exit_roundtrip` test in `streamexit.rs` dials the deployed exit over the mixnet, runs the real TLS + websocket handshake, and round-trips a Nostr REQ.

## References

- The fallback path: [The in-process mixnet tunnel](nym-client.md).
- Where the exit address comes from: [Relays](nostr-relays.md).
- Nym stream API: <https://nym.com/docs/developers/rust>.
