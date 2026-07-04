# Self-hosting overview

> **Summary.** Goblin's public infrastructure (the `goblin.st` name authority, the default `relay.floonet.dev` relay, and its Tor onion service) is all run-your-own. None of it is a hard dependency: you can point a Goblin wallet at your own name authority, your own relay, and your own onion service, and build the app from source.

## Why self-host

Defaults are conveniences, not gatekeepers. Running your own pieces gives you:

- **Independence**: your community isn't reliant on one operator for names or relaying.
- **A smaller metadata footprint**: your users' name lookups and messages stay on infrastructure you control.
- **Federation**: your name authority issues `name@yourdomain`, and Goblin can be told to treat it as home.

## The pieces

| Service | What it does | Guide |
| --- | --- | --- |
| **Name authority** (`goblin-nip05d`) | Issues **names**, resolves NIP-05, NIP-98 auth | [Run a name authority](name-authority.md) |
| **Relay** (a [Floonet](https://docs.floonet.dev) package) | Carries the encrypted payment messages | [Run a relay](relay.md) |
| **Onion service** | The Tor onion service fronting your relay | [Run the relay's onion service](nym-requester.md) |
| **The app itself** | Build for desktop / Android | [Building Goblin](building.md) |

## Pointing a wallet at your infra

- **Name authority**: Settings → Identity → Name authority → set your domain. Bare names then resolve against it.
- **Relays**: Settings → Nostr Relays → add your `wss://…` and save & reconnect.
- **Onion service**: run a Tor onion service in front of your relay and publish its `.onion` in the relay pool (see [Run the relay's onion service](nym-requester.md)); wallets dial it automatically. There's no per-wallet exit to configure — Tor handles egress on the client side, so the relay's [onion](../pillars/nym-exit.md) is advertised through the relay pool rather than set per wallet.

> These docs keep deployment generic. Adapt paths, domains, and certificates to your own host; don't copy another operator's production specifics.
