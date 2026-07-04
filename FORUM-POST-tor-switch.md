# We're moving Goblin from the Nym mixnet to Tor

**We're switching the privacy plumbing under Goblin from the Nym mixnet back to Tor. Here's the honest why — and the one simple idea that makes it the right call.**

Start with that idea, because it's the whole thing:

**Tor has exactly one job in Goblin: to hide your IP address — where you are on the network — from our relay.** That's it, and it's the one job Tor is the best tool in the world for.

Why only one job? Because the relay is the one server your wallet actually connects to, so it's the one piece that can't hide your network location by itself. *Everything else* about a payment is already handled, by the relay and by Nostr:

- **What you send is encrypted end to end.** The relay only ever holds a sealed envelope it can't open — nobody but the person you paid can read it.
- **Who sent it is a throwaway key.** Every payment goes out under a one-time key, so the relay never sees that it was you.
- **When you sent it is shuffled by our own relay** — it holds each payment for a brief, random moment before passing it on, so nobody can line up "you sent" with "they received."

So here's the whole division of labor:

> **Tor hides your IP from the relay. The relay hides everything else.**

Once you see it that way, the rest follows: we never needed a whole mixnet's machinery — just Tor for one narrow job, and our own relay for the rest.

Now the honest part — why we're leaving. When I built Goblin's privacy on the Nym mixnet, I meant it; a mixnet is a genuinely strong tool and I wasn't hedging. But a money wallet has to stand on ground that doesn't move, and the ground moved. The free bandwidth Goblin relied on turns out to be temporary testnet scaffolding that Nym is actively removing — it's written right into their code to expire at midnight, and their public gateways are switching to a paid model that means holding a specific crypto token just to buy bandwidth. That is not a foundation I'll build your money on. It went dark on us more than once, on a schedule, and "your payments work unless it's the wrong time of day" is not something I'll ship. I'm disappointed — but the call isn't a hard one.

So we're going back to **Tor**: the most battle-tested privacy network there is, with no token, no rented bandwidth, and nothing to expire. And we're embedding it **right inside the app**, the way our sibling wallet GRIM already does — no separate program to install.

And honestly, it's better day to day. Tor is **faster** for the moments you actually wait on — sending a payment, opening the app — because it skips the mixnet's built-in delays. It's **easier on your battery**, and more reliable, with no metered bandwidth to run out. You won't even feel that timing shuffle — it lands in the gap where your payment is already on its way, and your screen says "Sent" the instant our relay has it safely in hand.

I'll be straight about the one thing we give up: a full mixnet can resist an adversary powerful enough to watch the *entire* internet at once. Tor doesn't claim to stop that, and neither do we — it's simply not the threat a Grin payments wallet faces. For every attacker that actually exists, you're covered.

Faster, more reliable, runs on your phone, no tokens, nothing to expire. That's the trade, and I'm glad to make it.
