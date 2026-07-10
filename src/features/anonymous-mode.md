# Advanced Privacy & Anonymous mode

> **Summary.** **Settings → Advanced Privacy** is the single home for how much the wallet reveals on this device. It has two parts: **notification privacy**, with three levels of how much a lock-screen alert prints, and **Anonymous mode**, which blurs your balance and history on the wallet's own screens until you tap to reveal. Both are presentation only: they change nothing about how money moves or what is stored, so turning them on or off is always safe.

## Motivation

Goblin already keeps the *network* from linking a payment to you: payment contents are end-to-end encrypted, and with [Tor routing](../pillars/tor.md#tor-routing-is-a-per-wallet-setting) on the relay never sees your IP either. Advanced Privacy covers the other threat, the person standing next to you. A notification on your lock screen or a glance at your open wallet can leak who paid you and how much, even though the network learned nothing. This page gathers those shoulder-surfing defences in one place, separate from that network privacy.

It pairs naturally with keeping [separate, unlinkable identities](identities.md): different faces for different contexts on the network, and a censored surface so a shoulder glance cannot read any of them either.

## Notification privacy

The **Notifications** section decides how much an incoming-payment or payment-request alert prints on your lock screen. Three toggles, from least to most private:

- **Hide amounts.** The alert still names who paid, but the figure is left off, so a glance over your shoulder reveals nothing about the size of the payment.
- **Hide names.** The alert leaves out who paid, showing a generic sender instead of a name or npub.
- **Hide all details.** The alert collapses to a single generic private line, *"You got paid. Open Goblin to see."* (and the request equivalent), with no name and no amount at all. On Android an empty amount collapses the notification template down to just that private line.

**Hide all details takes precedence, and turning it on visually locks Hide amounts and Hide names on** — the alert is already stripped to the single private line, so those two can add nothing while it is set. Your own Hide-amounts and Hide-names choices are preserved underneath the lock: turn Hide all details back off and each returns to whatever you last set it to. With Hide all details off, hide names and hide amounts apply independently, so you can hide just the figure, just the sender, or both. Hide amounts is the same setting that older builds exposed as the lone "Hide amounts" toggle, so upgrading keeps its exact meaning; the two new levels default off.

## Anonymous mode

**Anonymous mode** is a single toggle, *"Blur balance and activity"*, that censors what the wallet shows on **this device**. It is scoped to three surfaces, the wallet **Home** balance, the **activity** list, and the **Recent** strip, and it changes only what is drawn, never the money path or storage.

While it is on:

- **The balance is a row of five dots.** The Home balance hero renders a fixed count of dots instead of the number. The count is fixed and never derived from the real balance, so its width can never hint at the magnitude. Tap it to reveal the true figure. Leaving the Home tab re-censors it, so a later glance is blurred again.
- **The fiat rate is not fetched while censored.** Because the fiat line is what triggers the exchange-rate lookup, no rate request goes out until you tap to reveal. A censored balance makes no network noise for its fiat value.
- **Activity rows are dotted.** Each row's name and amount become dots and the memo is dropped, so nothing about a counterparty or a figure leaks. Tapping a row reveals it and opens the full detail, which is the "reveal" for the activity list.
- **Every avatar becomes one uniform tile.** In place of each counterparty's picture, gradient, or initial, the wallet draws a single identical tile: a solid Goblin-yellow (`#FED60E`) circle with the Goblin mark inked dark on top. It is byte-identical for every identity, so no per-user colour, image, or letter can leak who a row belongs to.
- **The Recent strip is anonymized like the rest.** Every avatar in the Recent strip becomes the same censored tile and every name is dotted. Tapping a tile still opens the full detail.

The amount dots are always the same fixed count and are never digit-matched to the real value, so a censored row cannot leak an amount's size. The uniform yellow tile and the amount dots exist **only** while anonymous mode is on: turn it off and every avatar, including your own, returns to its normal [colour gradient](../subsystems/avatars.md) and every figure to its real value (Build 158 made this scoping explicit). Anonymous mode is purely a display choice: it does not touch the balance the wallet actually holds, the history it stores, or anything it sends.

<div class="shot-todo"><strong>Screenshots:</strong> Settings → Advanced Privacy (Notifications toggles + Anonymous mode); Home with the balance censored to dots; the activity list with dotted rows and the uniform yellow tiles, dark, 390×844.</div>

## Reference

In `goblin/src/gui/views/goblin/`:

- `mod.rs`: `SettingsPage::AdvancedPrivacy` and `advanced_privacy_ui()` (the two sections). `CENSOR_DOT_COUNT = 5`, `censored_amount_dots()` (fixed dot string, ignores the real amount), `CENSOR_NAME_DOTS` (the fixed dotted name), and `censored_balance_hero()` (the tappable dotted balance that skips the fiat fetch until revealed). `balance_revealed` resets when Home is left.
- `widgets.rs`: `avatar_censored()` draws the uniform `#FED60E` tile with the Goblin mark (reusing the `img/goblin-logo2` asset).
- Notification levels: `AppConfig::hide_amounts()` / `notif_hide_names()` / `notif_hide_details()` in config, read where the received / requested notifications are built in `goblin/src/nostr/client.rs`; the generic strings are `goblin.settings.notif_private_received` / `notif_private_requested` / `notif_someone`. The Android template collapses an empty amount in `BackgroundService.java`.
- Config migration: the existing `hide_amounts` field keeps its meaning; the three new fields default off, covered by a config test. All new copy is in `goblin/locales/*.yml` under `goblin.advprivacy` and `goblin.settings`.

## References

- The network privacy this complements (a per-wallet Tor switch): [Network privacy](../pillars/tor.md).
- Separate faces for separate contexts: [Multiple identities](identities.md).
- What the notification looks like normally: [Balance, node health & fiat rate](../subsystems/balance.md).
