# Run the relay's onion service

> **Summary.** Goblin reaches a relay over [Tor](../pillars/nym.md), at a pinned **`.onion` address**. The relay operator provides that onion by running a plain **system-Tor onion service** in front of the relay's TLS/websocket port, and publishing the `.onion` in the relay pool. Both [Floonet](https://docs.floonet.dev) relay packages ship this onion service. There is nothing for a *wallet* to configure — Tor handles egress on the client side automatically; the operator side is the whole story.

## Motivation

The relay is the one machine a wallet must open a socket to, so it's the piece that can't hide the wallet's network location on its own. Fronting the relay with a **Tor onion service** closes that gap: wallets dial the onion, so the relay (and every hop, and anyone watching the wire) sees a Tor address instead of a user's IP, and there's no hostname to look up on the clear net. Running your own means your community's payments reach infrastructure you control, and it keeps the onion next to the relay and name authority you already run.

The hosting is done by **mature system Tor** (C-Tor), the most-audited part of the Tor codebase and the strongest "hosting half" of the network. Because the service forwards to exactly one destination — your relay — it is **not an open proxy**: there's no exit policy to manage and no abuse surface.

## Setting it up

At heart it's a handful of `torrc` lines pointing an onion at the relay's existing TLS front:

```
# /etc/tor/torrc  (system Tor on the relay box)
HiddenServiceDir /var/lib/tor/floonet-relay/
HiddenServicePort 443 127.0.0.1:443
```

- **`HiddenServiceDir`** holds the onion service's keys — this *is* the `.onion` identity. Its `.onion` address is written to `hostname` inside that directory. **Back this directory up:** losing it rotates your `.onion`, and wallets that pinned the old address would have to pick up the new one from the pool.
- **`HiddenServicePort 443 → 127.0.0.1:443`** forwards the onion to wherever the relay's TLS/websocket is served (a loopback port, the stack's TLS proxy such as `caddy:443`, etc.). TLS stays end to end: the onion just carries the wallet's ordinary hostname-validated handshake against your relay's certificate, so system Tor only ever pipes ciphertext.
- **Enable [Vanguards](https://gitlab.torproject.org/tpo/core/torspec/-/blob/main/proposals/292-mesh-vanguards.txt)** on the service side to harden the onion against guard-discovery attacks.

Then **publish the `.onion`** (from the `hostname` file) in the wallet-side [relay candidate pool](../pillars/nostr-relays.md#the-candidate-pool), in that relay's `onion` field, so wallets learn it and dial your relay over Tor. The wallet-side behavior is documented in [The relay's onion service](../pillars/nym-exit.md).

## With the Floonet packages

Both [Floonet relay packages](https://docs.floonet.dev) bundle the onion service so you don't wire up `torrc` by hand: turn it on, and the package runs system Tor fronting the relay for you, printing the `.onion` on startup and persisting its keys in a volume/directory you back up. The first production deployment is the one serving `relay.floonet.dev`, Goblin's default money-path relay. See the [Floonet docs](https://docs.floonet.dev) for the exact per-package toggle.

## References

- Tor onion services: <https://community.torproject.org/onion-services/>.
- Vanguards (guard-discovery defense): <https://gitlab.torproject.org/tpo/core/torspec>.
- The wallet side of the onion: [The relay's onion service](../pillars/nym-exit.md).
- The client that dials it: [The embedded Tor client](../pillars/nym-client.md).
