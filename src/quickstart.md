# Quick start

New to Goblin? This is everything you need to send and receive money. It takes about two minutes.

> Goblin is like Cash App, but for [Grin](https://grin.mw). You pay a **username** (an easy alias for your friend's real address, their npub), your money stays private, and there's nothing to set up beyond a wallet.

## 1. Set up your wallet

The first time you open Goblin:

1. Tap **Get started**. Goblin connects you to the Grin network automatically, so there's nothing to set up.
2. Pick a **wallet name** and a **password**.
3. Goblin shows your **recovery phrase**: a list of words. Write them down on paper and keep them somewhere safe. **These words are your money.** If you lose them, nobody can get your funds back for you.
4. Re-enter the words to confirm you saved them.
5. Your wallet already has an address, a long key called an **npub**. Optionally pick a **username** like `yourname`, a friendly alias that points to your npub, so friends can pay you without copying the key. Or tap **Skip** to stay anonymous.

That's it. You're ready.

## 2. Get paid (receive)

You receive money by sharing your username or your code.

**Share your handle**

1. Tap **Receive**.
2. Show your **QR code**, or tap **Share** or **Copy** to hand over your payment code (an `nprofile`, your address plus a hint of where to reach you). Your **username** works too, if you claimed one.
3. Send that to whoever is paying you.

When they pay, it lands in your wallet on its own, even if your app was closed.

**Ask for a specific amount**

1. Open **Pay/Request** (the **ツ** button) and enter the **amount** you want.
2. Tap **Request**.
3. Pick a contact or share the request. They get a tap-to-pay request.

## 3. Pay someone (send)

1. Tap the big **ツ** button in the middle to open **Pay/Request**.
2. Type their **username** or **npub**, or tap the **scan** icon to scan their QR code.
3. Enter the **amount**.
4. Optional: add a short **note**.
5. Check the details, then **press and hold** the send button until it fills.

Done. Your payment goes out encrypted and private. The other person's wallet finishes it automatically, even if they were offline when you paid.

## 4. Check a payment

Tap **Activity** to see everything you've sent and received, and whether each one has confirmed yet.

## Good to know

- **Your recovery phrase is your money.** Back it up on paper. Goblin can't reset it for you, and support can't either.
- **Payments are private by default.** They travel encrypted, and the network hides who paid whom. [Here's how](overview/architecture.md).
- **Private by choice.** Goblin can route its payment network over **Tor**, running right inside the app, so the relay never sees your IP. It's a per-wallet switch under **Settings → Privacy → Tor routing**: a wallet you updated from an older version keeps Tor on, and a brand-new wallet asks you during setup (off means faster to connect but the relay can see your IP, so pair it with a VPN if that matters to you). With Tor on the money path still connects in a couple of seconds; the very first connection can take a moment while Tor warms up, which is normal.
- **Paying someone who isn't on Goblin?** Use **Settings → Wallet → Slatepacks** for the by-hand method.
- **On Android, the back button won't dump you out of the app by accident.** On the wallet home screen, press back twice to return to the wallet switcher; the first press shows a "Press back again to switch wallets" hint. The confirmation to exit the app lives at the wallet switcher.

Want the full picture of how it all works? Start with [What is Goblin?](overview/what-is-goblin.md)
