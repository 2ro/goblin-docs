# Name resolution under Tor

> **Summary.** The wallet runs no DNS resolver of its own. Every hostname Goblin needs, relay or otherwise, is handed to Tor **by name**, and Tor's exit relay performs the DNS lookup and opens the connection. The device never emits a DNS query and never sees the resolved IP.

## How it works

- **Every request is resolved at the Tor exit.** Nostr relay sockets, NIP-05 lookups, the relay-pool refresh, price, and avatars are all handed to Tor by hostname. Tor carries the name to an exit relay, which performs the DNS lookup, then opens the connection. There is nothing to leak on the device.
- **No wallet-side resolver.** Goblin ships no DNS-over-TLS/DNS-over-HTTPS resolver of its own: Tor's exit-side resolution makes one unnecessary.

## Historical note

An earlier build (133) pinned the money-path relay and the `goblin.st` name authority behind dedicated `.onion` addresses, which resolve inside Tor's own distributed hash and need no DNS lookup at all. Build 134 dropped that pinned onion (see [The relay's Tor exit path](nym-exit.md)), so every hostname, including those two, now takes the exit-resolution path above.

## References

- Who needs a clearnet host resolved: [HTTP over Tor](nym-http.md) (pool refresh, price, avatars, name lookups).
- The client that carries all of this: [The embedded Tor client](nym-client.md).
- Tor exit relays (how a clearnet hostname resolves): <https://community.torproject.org/relay/types-of-relays/#exit-relay>.
