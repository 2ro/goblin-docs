# Run a relay

> **Summary.** Goblin's payment messages ride ordinary Nostr relays, so any relay works, as long as it accepts connections from Tor exit nodes (Goblin dials relays over Tor whenever a wallet's [Tor routing](../pillars/tor.md#tor-routing-is-a-per-wallet-setting) is on, and many wallets keep it on). The default relay (`relay.floonet.dev`) is a [Floonet](https://docs.floonet.dev) relay: stock [strfry](https://github.com/hoytech/strfry) with a small write policy that restricts stored event kinds to the handful Goblin needs. Running your own keeps your community's traffic on infrastructure you control.

## Motivation

A relay only needs to do one thing for Goblin: accept and serve the gift-wrapped payment events (and the profile / relay-list events that make delivery work). Restricting *which* kinds it stores keeps a payment relay lean and uninteresting to abuse; it isn't a general-purpose social relay.

## How it works

- **strfry, unmodified**, plus a **write-policy plugin** that only admits the kinds Goblin uses: profiles (`kind 0`), contact/relay lists, gift wraps (`kind 1059`), and the relay-list kinds (`10002` / `10050`). Everything else is rejected, so the relay won't fill with unrelated content.
- Clients reach it over `wss://`, **over [Tor](../pillars/tor-relay-transport.md)**: every wallet connection arrives from a shared Tor exit IP, which is why abuse controls are per-connection rather than naive per-IP.
- It's typically fronted by the same TLS reverse proxy as the [name authority](name-authority.md), with the websocket location proxied to strfry's loopback port.
- **Payment retention.** The point of a payment relay is to hold a gift-wrap until its recipient comes online, so don't set an aggressive expiry or eviction policy that could drop an unfetched payment. The project's `relay.floonet.dev` **guarantees** payment-message retention (it cannot prematurely delete a payment), which is why it ships as the default relay in every wallet; run yours the same way.
- **Optional NIP-42 auth.** Goblin wallets do [opportunistic NIP-42 auth](../pillars/nostr-relays.md#relay-authentication-nip-42) automatically, so a relay *may* enable it and wallets will answer. Do not make it *mandatory* or paid, though: the wallet's pool gate refuses any relay that requires payment or AUTH.
- **Make sure Tor exit traffic isn't blocked.** Any wallet with [Tor routing](../pillars/tor.md#tor-routing-is-a-per-wallet-setting) on reaches your relay [over a Tor exit](../pillars/tor-exit.md), so a CDN or WAF rule that blocks Tor exit nodes (Cloudflare's "Block Tor" toggle, for example) will silently cut those wallets off. An earlier build ran a dedicated Tor onion service in front of the relay; that requirement is retired (see [Tor and your relay](tor-relay.md)), and a plain clearnet-reachable relay works fine today.

## Deploying

The recommended path is a [Floonet relay package](https://docs.floonet.dev): **floonet-strfry** (Docker Compose: relay + name authority + auto-HTTPS) or **floonet-rs** (a single hardened binary with the same features built in). A minimal strfry write-policy setup also lives under `goblin-nip05d/deploy/strfry/` if you'd rather assemble it by hand. Then advertise the relay in your wallet: **Settings → Nostr Relays → add `wss://relay.yourdomain` → Save & reconnect**.

## Reference

- The Floonet relay packages (floonet-strfry, floonet-rs): <https://docs.floonet.dev>.
- Hand-rolled write policy + deployment: `goblin-nip05d/deploy/strfry/`.
- Allowed kinds rationale: [Relays](../pillars/nostr-relays.md), [Protocol](../pillars/nostr-protocol.md).
- strfry upstream: <https://github.com/hoytech/strfry>.

## References

- How clients connect: [Relay traffic over Tor](../pillars/tor-relay-transport.md).
- Why an onion service is no longer required: [Tor and your relay](tor-relay.md).
