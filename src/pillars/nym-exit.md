# The relay's onion service

> **Summary.** Goblin's money-path relay (`relay.floonet.dev` by default) is reached at a **pinned `.onion` address**. The relay's operator runs a plain **system-Tor onion service** in front of the relay's websocket port; the wallet dials that onion directly over its [embedded Tor client](nym-client.md). The payment path therefore needs **no public DNS** and never touches the clear net. It is also fast: the relay connects in a couple of seconds from a cold start, and a funded payment finalizes in about six.

## Motivation

The relay is the one machine the wallet must open a socket to, so it is exactly the piece that can't hide your network location on its own — that is [Tor's narrow job](nym.md#motivation). Reaching the relay at an **onion address** is the cleanest way to do it: an onion connection has no clearnet exit, so the relay (and every hop, and anyone watching the wire) sees a Tor address instead of your phone's IP, and there is no hostname to look up on the clear net.

Hosting the onion is done by **mature system Tor** (C-Tor), the most-audited part of the Tor codebase and the strongest "hosting half" of the network. The wallet only needs the **dialing half** — connect *out* to the relay's onion — which is why Goblin is simpler than a service that also has to host one.

## How it works

- **Discovery.** Each entry in the [relay candidate pool](nostr-relays.md#the-candidate-pool) may carry an `onion` field: the `.onion` address of that relay's Tor onion service. The pinned pool compiled into the app carries the onion for `relay.floonet.dev`, so the money path bootstraps offline, before any network fetch, with nothing to resolve.
- **Dialing.** When the [relay transport](nym-relay-transport.md) (or an [HTTPS request](nym-http.md) to the same host, such as the relay's NIP-11 probe) targets a relay with an advertised onion, the wallet asks arti for a circuit to `<onion>:443`. Tor returns a byte stream (`DataStream`) that behaves like any other socket.
- **TLS is end to end.** The stream carries exactly the same hostname-validated TLS + websocket handshake as any other connection (SNI is the relay host, certificate checked). The hosting Tor and every relay in the circuit see only ciphertext; a hostile hop cannot read or tamper with the connection.
- **No clearnet fallback for the money path.** The relay path is onion-only by design: if it can't connect, the wallet surfaces the failure rather than silently dropping to the clear net. That is safe because sending is guarded — a payment is only ever reported "Sent" once the relay confirms it holds the gift-wrap (see [the payment flow](../features/payment-flow.md)), so a slow or failed connect makes the caller retry, never lose money.

### The fast money path

Dialing the onion is not just cleaner, it's the fastest connection the wallet makes. It skips the per-hop mixing delay and the fixed stream-settle that the old mixnet path paid on every send. Against the default relay, a **cold app start connects in about 0–2 seconds**, and a funded payment finalizes in about **6 seconds** end to end. On the mixnet the same first connect could take anywhere from 15 seconds to 3 minutes. The wait the user actually watches — publish the payment, wait for the relay to confirm it holds it — is shorter on Tor, not longer.

## Running one

The relay operator runs a system-Tor onion service that forwards the onion to the relay's existing TLS/websocket port (`torrc`: a `HiddenServiceDir` plus `HiddenServicePort 443 → the relay's front`), with **Vanguards** enabled on the service side. Because it forwards to exactly one destination, it is not an open proxy: there is no exit policy to manage and no abuse surface. Both [Floonet](https://docs.floonet.dev) relay packages ship this onion service, and the instance serving `relay.floonet.dev` is the first production deployment. See [Run the relay's onion service](../self-hosting/nym-requester.md) for the operator-side picture and the [Floonet docs](https://docs.floonet.dev) for the packages themselves.

## Reference

- Dialing: `goblin/src/tor/` exposes the arti `TorClient`; a relay dial is `TorClient::connect(<onion>:443)` returning a `DataStream` that satisfies the websocket transport's byte-source seam.
- `goblin/src/nostr/pool.rs`: `PoolRelay::onion`, `onion_for()` (websocket dials, keyed by relay URL), `onion_for_host()` (HTTPS dials, keyed by hostname). The pin format is forward-safe: the pool parser tolerates unknown fields (no `deny_unknown_fields`, `version` stays `1`), so older builds simply ignore the `onion` field.
- Dial sites: the relay transport in `goblin/src/tor/` and the HTTP path in `goblin/src/nym/mod.rs`.

## References

- The client that dials this onion: [The embedded Tor client](nym-client.md).
- Where the onion address comes from: [Relays](nostr-relays.md).
- Tor onion services: <https://community.torproject.org/onion-services/>.
