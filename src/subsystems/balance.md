# Balance, node health & fiat rate

> **Summary.** Home shows one balance, and Goblin is careful to tell you the truth about it. When you switch Grin nodes the change applies live, and while a balance is not yet trustworthy the wallet says so in plain words rather than flashing a misleading zero. An optional fiat (or Bitcoin/sats) figure sits under the balance, fetched fresh when you look at it.

## Motivation

A balance is the one number a payments app must never lie about. Two moments make that hard: the seconds after you switch nodes (the new node has not answered yet), and any time the connected node is unreachable or still catching up. The naive behaviour, showing `0 ツ` until data arrives, reads as "your money is gone." Goblin instead treats "I don't know yet" as its own state and labels it. The fiat pairing has the opposite problem: a rate that silently goes stale is worse than no rate, so Goblin fetches it when you actually look and is honest when it can't.

## How it works

### Switching nodes applies live

The Grin node is chosen in **Settings → Advanced**. Picking a different node applies immediately, with no restart: the wallet re-points at the new node and the balance re-derives from it. There is no stale figure left over from the old node.

### Honest balance states

Rather than show a bare `0 ツ` whenever the number isn't ready, Home carries a short subline that names the actual situation:

- **Unreachable** when the connected node can't be reached, so no balance can be trusted right now.
- **Stale** when the last known balance predates the current chain tip, i.e. the wallet has data but it may be out of date.
- **Updating** while a fresh balance is being derived (typically right after a node switch or on reconnect).

A genuine zero balance is only ever shown when the wallet is confident the balance really is zero. The distinction is the whole point: "I can't reach the node" and "you have nothing" are different facts and are shown as different facts.

### The fiat rate is view-triggered, not polled

Under the balance you can show its value in a world currency, in Bitcoin, or in sats (or turn the preview off entirely). The rate is fetched **when the view needs it**, cached for a short freshness window, and reused within that window so a quick glance doesn't refetch. It is **not** polled in the background: Goblin does not sit and fetch prices on a timer. If a fetch fails, the wallet shows **rate unavailable** rather than a guessed or indefinitely stale number. Like every other HTTP request, the rate fetch rides [Tor](../pillars/tor.md).

## References

- Balance and rate rendering, and the appearance pairing picker: `goblin/src/gui/views/goblin/mod.rs`.
- Node selection: **Settings → Advanced** (`goblin/src/gui/views/goblin/mod.rs`), applied to the running wallet without a restart.
- Amount pairing options (currency / BTC / sats / off): [Theme & appearance](theme.md).
