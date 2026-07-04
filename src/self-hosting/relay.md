# Run a relay

> **Summary.** Goblin's payment messages ride ordinary Nostr relays, so any relay works, as long as it accepts connections from Tor exit nodes (Goblin dials every relay over Tor). The default relay (`relay.floonet.dev`) is a [Floonet](https://docs.floonet.dev) relay: stock [strfry](https://github.com/hoytech/strfry) with a small write policy that restricts stored event kinds to the handful Goblin needs. Running your own keeps your community's traffic on infrastructure you control.

## Motivation

A relay only needs to do one thing for Goblin: accept and serve the gift-wrapped payment events (and the profile / relay-list events that make delivery work). Restricting *which* kinds it stores keeps a payment relay lean and uninteresting to abuse; it isn't a general-purpose social relay.

## How it works

- **strfry, unmodified**, plus a **write-policy plugin** that only admits the kinds Goblin uses: profiles (`kind 0`), contact/relay lists, gift wraps (`kind 1059`), and the relay-list kinds (`10002` / `10050`). Everything else is rejected, so the relay won't fill with unrelated content.
- Clients reach it over `wss://`, **over [Tor](../pillars/tor-relay-transport.md)**: every wallet connection arrives from a shared Tor exit IP, which is why abuse controls are per-connection rather than naive per-IP.
- It's typically fronted by the same TLS reverse proxy as the [name authority](name-authority.md), with the websocket location proxied to strfry's loopback port.
- **Make sure Tor exit traffic isn't blocked.** Wallets reach your relay exclusively [over Tor](../pillars/tor-exit.md), so a CDN or WAF rule that blocks Tor exit nodes (Cloudflare's "Block Tor" toggle, for example) will silently cut every Goblin wallet off. An earlier build ran a dedicated Tor onion service in front of the relay; that requirement is retired (see [Tor and your relay](tor-relay.md)), and a plain clearnet-reachable relay works fine today.

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
