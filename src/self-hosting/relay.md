# Run a relay

> **Summary.** Goblin's payment messages ride ordinary Nostr relays, so any relay works. The default relay (`relay.floonet.dev`) is a [Floonet](https://docs.floonet.dev) relay: stock [strfry](https://github.com/hoytech/strfry) with a small write policy that restricts stored event kinds to the handful Goblin needs, plus a Tor onion service in front. Running your own keeps your community's traffic on infrastructure you control.

## Motivation

A relay only needs to do one thing for Goblin: accept and serve the gift-wrapped payment events (and the profile / relay-list events that make delivery work). Restricting *which* kinds it stores keeps a payment relay lean and uninteresting to abuse; it isn't a general-purpose social relay.

## How it works

- **strfry, unmodified**, plus a **write-policy plugin** that only admits the kinds Goblin uses: profiles (`kind 0`), contact/relay lists, gift wraps (`kind 1059`), and the relay-list kinds (`10002` / `10050`). Everything else is rejected, so the relay won't fill with unrelated content.
- Clients reach it over `wss://`, **over [Tor](../pillars/nym-relay-transport.md)**: with the onion service on, connections arrive from the co-located Tor process (localhost), which is why abuse controls are per-connection rather than naive per-IP.
- It's typically fronted by the same TLS reverse proxy as the [name authority](name-authority.md), with the websocket location proxied to strfry's loopback port.
- **Optionally, a Tor onion service.** The default relay runs a system-Tor [onion service](../pillars/nym-exit.md) in front of strfry, so wallets reach it at a pinned `.onion` with no public DNS, and fast. Both Floonet packages bundle the onion service behind a config toggle; a relay without one is simply reached [over Tor](../pillars/nym-client.md) at its clearnet host, which works fine.

## Deploying

The recommended path is a [Floonet relay package](https://docs.floonet.dev): **floonet-strfry** (Docker Compose: relay + name authority + auto-HTTPS + the optional Tor onion service) or **floonet-rs** (a single hardened binary with the same features built in). A minimal strfry write-policy setup also lives under `goblin-nip05d/deploy/strfry/` if you'd rather assemble it by hand. Then advertise the relay in your wallet: **Settings → Nostr Relays → add `wss://relay.yourdomain` → Save & reconnect**.

## Reference

- The Floonet relay packages (floonet-strfry, floonet-rs): <https://docs.floonet.dev>.
- Hand-rolled write policy + deployment: `goblin-nip05d/deploy/strfry/`.
- Allowed kinds rationale: [Relays](../pillars/nostr-relays.md), [Protocol](../pillars/nostr-protocol.md).
- strfry upstream: <https://github.com/hoytech/strfry>.

## References

- How clients connect: [Relay traffic over Tor](../pillars/nym-relay-transport.md).
