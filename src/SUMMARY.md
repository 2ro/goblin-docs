# Summary

[Introduction](README.md)
[Quick start](quickstart.md)

# Overview

- [What is Goblin?](overview/what-is-goblin.md)
- [Architecture: the three pillars](overview/architecture.md)

# Pillar 1: The GRIM wallet base

- [GRIM: the wallet engine Goblin forks](pillars/grim-base.md)

# Pillar 2: Nostr messaging

- [Nostr in Goblin](pillars/nostr.md)
  - [Identity (NIP-06 / NIP-49)](pillars/nostr-identity.md)
  - [The payment protocol (NIP-17 / 44 / 59)](pillars/nostr-protocol.md)
  - [The NostrService relay thread](pillars/nostr-service.md)
  - [Ingest policy (the security core)](pillars/nostr-ingest.md)
  - [Storage, config & types](pillars/nostr-storage.md)
  - [Relays](pillars/nostr-relays.md)

# Pillar 3: The Tor transport

- [Tor in Goblin](pillars/tor.md)
  - [The embedded Tor client](pillars/tor-client.md)
  - [The relay's Tor exit path](pillars/tor-exit.md)
  - [Name resolution under Tor](pillars/tor-dns.md)
  - [Relay traffic over Tor](pillars/tor-relay-transport.md)
  - [HTTP over Tor](pillars/tor-http.md)

# Features

- [The end-to-end payment flow](features/payment-flow.md)
- [Send & request, recipient search](features/send-request.md)
- [News on Home](features/news.md)
- [The NIP-05 name authority](features/name-authority.md)
- [Multiple identities](features/identities.md)
- [Onboarding](features/onboarding.md)
- [Cancel & decline](features/cancel-decline.md)

# Subsystems

- [Balance, node health & fiat rate](subsystems/balance.md)
- [Theme: light / dark / yellow](subsystems/theme.md)
- [Avatars & identicons](subsystems/avatars.md)
- [QR & camera](subsystems/qr-camera.md)
- [Localization](subsystems/localization.md)
- [Security hardening](subsystems/security.md)

# Operating Goblin

- [Self-hosting overview](self-hosting/README.md)
- [Run a name authority](self-hosting/name-authority.md)
- [Run a relay](self-hosting/relay.md)
- [Tor and your relay](self-hosting/tor-relay.md)
- [Building Goblin](self-hosting/building.md)
