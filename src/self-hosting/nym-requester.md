# Run a Nym network requester

> **Summary.** Goblin egresses the mixnet through a **network requester**: the exit that forwards your traffic to relays and HTTPS hosts. Goblin ships with a default, but you can run your own for reliability and point wallets at it with one environment variable.

## Motivation

The network requester is the last mixnet hop before the open internet. Using a requester you operate means you're not depending on a third party's exit for your community's payments, and you can keep it close to the relays and name authority you also run. Goblin uses the standard requester (with a normal exit policy) rather than an open proxy.

## How it works

A `nym-network-requester` is initialized once (it registers with a gateway and gets a mixnet address), then run as a long-lived service. Its **address** is what wallets target. A wallet picks the requester from either:

- the baked-in default (`NETWORK_REQUESTER` in `goblin/src/nym/sidecar.rs`), or
- the `GOBLIN_NYM_PROVIDER` environment variable at runtime (overrides the default).

## Deploying

```sh
# 1. build or obtain a portable nym-network-requester binary
# 2. initialize (registers with a gateway; standard exit policy, NOT an open proxy)
nym-network-requester init --id my-requester
# 3. run it as a service (systemd unit, restart on failure)
nym-network-requester run --id my-requester
# 4. note the printed mixnet address; that's the "provider"
```

Then either set `GOBLIN_NYM_PROVIDER=<address>` in the wallet's environment, or bake it into `NETWORK_REQUESTER` and rebuild. The project includes a reference deploy script (`deploy-nym-requester.sh`) that builds a portable (glibc-2.17) binary, installs a systemd unit, initializes the requester, and prints its address; adapt the host specifics to your own server.

## Reference

- Where the address is consumed: `goblin/src/nym/sidecar.rs` (`NETWORK_REQUESTER`, `provider()`, `GOBLIN_NYM_PROVIDER`).
- Reference deploy automation: `deploy-nym-requester.sh` (project root).
- The in-process client that dials it: [The in-process mixnet client](../pillars/nym-client.md).

## References

- Nym network requester docs: <https://nym.com/docs>.
