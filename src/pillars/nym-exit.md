# The relay's Tor exit path

> **Summary.** Every relay Goblin talks to, including the default `relay.floonet.dev`, is reached over a **Tor exit** to its ordinary clearnet host: the wallet's embedded Tor client builds a circuit out through a normal Tor exit relay and runs the usual hostname-validated TLS + websocket handshake against the relay's public address. There is no onion hop. An earlier build briefly pinned the relay behind a dedicated `.onion` address; build134 dropped it after the shared onion flapped under load (see [the historical note](#historical-note-the-retired-onion-service) below). Reaching the relay this way still hides the wallet's IP, and it is fast: a cold app start connects in a few seconds, and a funded payment finalizes in about eight.

## Motivation

The relay is the one machine the wallet must open a socket to, so it is exactly the piece that can't hide your network location on its own, that is [Tor's narrow job](nym.md#motivation). Routing that connection through a Tor exit closes the gap without needing anything special from the relay operator: the relay sees a Tor exit address on the wire, never the wallet's IP, and the relay itself needs no onion service, no pinned address, and no extra infrastructure. The one requirement on the relay side is mundane: it has to accept connections from Tor exit nodes, which is why `relay.damus.io` and `nos.lol` (both of which block Tor exits) aren't usable defaults, and why the pinned pool sticks to relays known to accept them (`relay.floonet.dev`, `relay.0xchat.com`, `offchain.pub`).

## How it works

- **No discovery step.** Because there is no onion to look up, connecting to a relay needs nothing beyond its ordinary `wss://` URL. Every relay in the [relay pool](nostr-relays.md#the-candidate-pool) is dialed the same way.
- **Dialing.** The [relay transport](nym-relay-transport.md) hands the relay's hostname to arti, which builds a Tor circuit out through an exit relay to that host; the usual TLS + websocket handshake then runs over the resulting stream.
- **TLS is end to end.** The stream carries the same hostname-validated TLS + websocket handshake as any other connection (SNI is the relay host, certificate checked). The exit relay and every hop in the circuit see only ciphertext.
- **No clearnet fallback.** The wallet never dials a relay directly outside Tor. If the Tor circuit can't connect, the wallet surfaces the failure rather than silently dropping to the clear net. That is safe because sending is guarded, a payment is only ever reported "Sent" once the relay confirms it holds the gift-wrap (see [the payment flow](../features/payment-flow.md)), so a slow or failed connect makes the caller retry, never lose money.

### The fast money path

Even without an onion hop, this is a fast connection: against the default relay, a cold app start connects in a few seconds, and a funded payment finalizes in about eight seconds end to end (measured on build134 with two funded wallets on independent mainnet nodes). The wait the user actually watches, publish the payment, wait for the relay to confirm it holds it, stays short.

## Historical note: the retired onion service

An earlier build (133) pinned the money-path relay behind a dedicated `.onion` address and dialed it directly over a real onion circuit, with the relay operator running a system-Tor onion service in front of the relay's websocket port. That path is **retired**. Under real load the shared onion hop flapped (WebSocket 1006 errors), and a drop mid-handshake could strand a payment after the first gift-wrap: the recipient got the incoming alert, but the sender's side never confirmed. Build 134 removed the pinned `.onion`, the has-onion gate that had rejected an onion-less relay list, and the `onion` field from the relay-pool schema, in favor of the Tor-exit path described above. Relay operators no longer need to run an onion service for Goblin to reach them; see [Run a relay](../self-hosting/relay.md) for what running a relay actually requires today.

## Reference

- Dialing: `goblin/src/tor/transport.rs` implements the Nostr SDK's `WebSocketTransport` trait; `connect()` hands the relay's hostname to arti and runs `tokio_tungstenite::client_async_tls` over the resulting Tor stream.
- `goblin/src/nostr/pool.rs`: `PINNED_POOL` (no `onion` or `exit` fields as of build134); `goblin/src/nostr/relays.rs`: `DEFAULT_RELAYS`.

## References

- The client that dials the relay: [The embedded Tor client](nym-client.md).
- Where the relay pool comes from: [Relays](nostr-relays.md).
- What the retired onion path required of an operator: [Run a relay](../self-hosting/relay.md).
