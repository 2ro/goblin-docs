# Run a relay

> **Summary.** Goblin's payment messages ride ordinary Nostr relays, so any relay works. The Goblin default relay is a stock [strfry](https://github.com/hoytech/strfry) with a small write policy that restricts stored event kinds to the handful Goblin needs. Running your own keeps your community's traffic on infrastructure you control.

## Motivation

A relay only needs to do one thing for Goblin: accept and serve the gift-wrapped payment events (and the profile / relay-list events that make delivery work). Restricting *which* kinds it stores keeps a payment relay lean and uninteresting to abuse; it isn't a general-purpose social relay.

## How it works

- **strfry, unmodified**, plus a **write-policy plugin** that only admits the kinds Goblin uses: profiles (`kind 0`), contact/relay lists, gift wraps (`kind 1059`), and the relay-list kinds (`10002` / `10050`). Everything else is rejected, so the relay won't fill with unrelated content.
- Clients reach it over `wss://`, **through the [Nym mixnet](../pillars/nym-relay-transport.md)**: from the relay's perspective connections arrive from mixnet exit IPs, which is why abuse controls are per-connection rather than naive per-IP.
- It's typically fronted by the same TLS reverse proxy as the [name authority](name-authority.md), with the websocket location proxied to strfry's loopback port.
- **Optionally, a co-located scoped Nym exit.** The default Goblin relay also runs a small [scoped exit](../pillars/nym-exit.md) beside strfry, so wallets can reach it over the mixnet with no public DNS. The packaging that would let any operator flip this on next to their own relay isn't published yet; a relay without one is simply reached through the wallets' regular [tunnel](../pillars/nym-client.md), which works fine.

## Deploying

The write-policy and a Compose/relay setup live under `goblin-nip05d/deploy/strfry/`. The fastest path is the bundled Docker Compose (relay + name authority + auto-HTTPS); to run strfry standalone, install it per its upstream docs and add the Goblin write-policy. Then advertise the relay in your wallet: **Settings → Nostr Relays → add `wss://relay.yourdomain` → Save & reconnect**.

## Reference

- Write policy + deployment: `goblin-nip05d/deploy/strfry/`.
- Allowed kinds rationale: [Relays](../pillars/nostr-relays.md), [Protocol](../pillars/nostr-protocol.md).
- strfry upstream: <https://github.com/hoytech/strfry>.

## References

- How clients connect: [Relay traffic over the mixnet](../pillars/nym-relay-transport.md).
