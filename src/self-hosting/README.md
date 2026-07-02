# Self-hosting overview

> **Summary.** Goblin's public infrastructure (the `goblin.st` name authority, the Goblin relay, and its Nym exits) is all run-your-own. None of it is a hard dependency: you can point a Goblin wallet at your own name authority, your own relay, and your own mixnet exit, and build the app from source.

## Why self-host

Defaults are conveniences, not gatekeepers. Running your own pieces gives you:

- **Independence**: your community isn't reliant on one operator for names or relaying.
- **A smaller metadata footprint**: your users' name lookups and messages stay on infrastructure you control.
- **Federation**: your name authority issues `name@yourdomain`, and Goblin can be told to treat it as home.

## The pieces

| Service | What it does | Guide |
| --- | --- | --- |
| **Name authority** (`goblin-nip05d`) | Issues **names**, resolves NIP-05, NIP-98 auth | [Run a name authority](name-authority.md) |
| **Relay** (`strfry` + write policy) | Carries the encrypted payment messages | [Run a relay](relay.md) |
| **Nym exit** | The mixnet exit(s) Goblin egresses through | [Run a Nym exit](nym-requester.md) |
| **The app itself** | Build for desktop / Android | [Building Goblin](building.md) |

## Pointing a wallet at your infra

- **Name authority**: Settings → Identity → Name authority → set your domain. Bare names then resolve against it.
- **Relays**: Settings → Nostr Relays → add your `wss://…` and save & reconnect.
- **Mixnet exit**: prefer your own public exit with the `GOBLIN_NYM_IPR` environment variable (see [Run a Nym exit](nym-requester.md)). A relay's co-located [scoped exit](../pillars/nym-exit.md) is advertised through the relay pool rather than configured per wallet.

> These docs keep deployment generic. Adapt paths, domains, and certificates to your own host; don't copy another operator's production specifics.
