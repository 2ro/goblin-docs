# Tor and your relay (the onion service is retired)

> **Summary.** Goblin wallets reach relays over [Tor](../pillars/nym.md) automatically: the client dials a Tor-exit circuit to your relay's ordinary clearnet host. There is nothing for a relay operator to run for Tor support today. **This used to not be true**: builds through 133 needed operators to front their relay with a system-Tor onion service, which this page originally documented. Build 134 dropped the pinned onion (it flapped under load) in favor of the plain Tor-exit path, so that setup is retired.

## What this means for operators today

Nothing to install. Wallets reach your relay the same way they'd reach it over any other Tor-exit connection: your relay's normal `wss://` endpoint. The one thing to check is that your relay (and anything in front of it, a CDN or WAF) doesn't **block Tor exit-node traffic**; `relay.damus.io` and `nos.lol` do, which is why Goblin's default pool no longer includes them. See [Run a relay](relay.md) for the rest of what running a relay involves.

## Historical: the retired onion service

For reference, in case you're maintaining an older Floonet package or comparing against an old deployment, this is what an earlier build (133) asked operators to run:

```
# /etc/tor/torrc  (system Tor on the relay box)
HiddenServiceDir /var/lib/tor/floonet-relay/
HiddenServicePort 443 127.0.0.1:443
```

A `HiddenServiceDir` held the onion service's keys, and wallets pinned the resulting `.onion` from the relay pool's `onion` field. Build 134 removed that field from the pool schema, and the wallet no longer looks for it. An onion service left running alongside a relay today is simply unused, not harmful.

## References

- Why the onion path was dropped: [The relay's Tor exit path](../pillars/nym-exit.md).
- Running the relay itself: [Run a relay](relay.md).
- The client that dials it: [The embedded Tor client](../pillars/nym-client.md).
