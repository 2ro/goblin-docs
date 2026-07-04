# Self-hosting overview

> **Summary.** Goblin's public infrastructure (the `goblin.st` name authority and the default `relay.floonet.dev` relay) is all run-your-own. Wallets already reach any relay over Tor automatically, so there's no separate onion service to run. None of it is a hard dependency: you can point a Goblin wallet at your own name authority and your own relay, and build the app from source.

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
| **Tor reachability** | Nothing to run; just make sure your relay doesn't block Tor exit traffic | [Tor and your relay](tor-relay.md) |
| **The app itself** | Build for desktop / Android | [Building Goblin](building.md) |

## Pointing a wallet at your infra

- **Name authority**: Settings → Identity → Name authority → set your domain. Bare names then resolve against it.
- **Relays**: Settings → Nostr Relays → add your `wss://…` and save & reconnect. There's nothing to configure for Tor: every wallet dials your relay over a Tor exit automatically, so the only requirement on your side is not blocking Tor exit-node traffic (see [Tor and your relay](tor-relay.md)).

> These docs keep deployment generic. Adapt paths, domains, and certificates to your own host; don't copy another operator's production specifics.
