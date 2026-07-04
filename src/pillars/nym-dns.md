# Name resolution under Tor

> **Summary.** Moving to Tor removes a whole moving part: the wallet no longer runs its own DNS resolver. The money path is reached at an **`.onion` address, which needs no DNS at all** — onions resolve inside Tor. For the handful of ordinary web hosts the wallet still talks to (the relay-pool refresh, the price feed, avatars), **Tor resolves the hostname at its exit relay**, not on the device. Either way, a clearnet DNS query never leaves your phone.

## Motivation

A clearnet DNS lookup would announce exactly which relays and hosts the wallet talks to — precisely the metadata the transport exists to hide. The old mixnet path solved this the hard way, by shipping a full in-wallet resolver (DNS-over-TLS with a DNS-over-HTTPS fallback) so a lookup could ride the tunnel instead of the clear net. Tor makes almost all of that unnecessary.

## How it works

- **Onion addresses need no DNS.** The money-path [relay](nym-exit.md) and the [name authority](../features/name-authority.md) are pinned as `.onion` addresses. An onion address is resolved by the Tor network itself (via its distributed hash of onion descriptors); there is no hostname to look up and nothing to leak. The pinned addresses ship compiled into the app, so the money path works offline on first run.
- **Clearnet names are resolved by Tor, at the exit.** The few requests that target ordinary hosts — the [pool refresh, price, and avatars](nym-http.md) — are handed to Tor *by hostname*. Tor carries the name to an exit relay and the **exit** performs the DNS lookup, then opens the connection. The device never emits a DNS query and never sees the resolved IP, so there is still no clearnet leak.
- **No wallet-side resolver.** Because Tor handles both cases, Goblin drops its own DoT/DoH resolver entirely. That is a net simplification: less code, fewer timeouts to tune, and one fewer thing that can stall a connect.

## References

- Who needs a clearnet host resolved: [HTTP over Tor](nym-http.md) (pool refresh, price, avatars).
- Why the money path skips resolution entirely: [The relay's onion service](nym-exit.md).
- The client that carries all of this: [The embedded Tor client](nym-client.md).
- Tor onion services (how `.onion` addresses resolve): <https://community.torproject.org/onion-services/>.
