# News on Home

> **Summary.** The Home screen can show a single news card: the latest article published by the official Goblin news key. It sits between the Send/Receive actions and Recent Activity, is hidden when there is nothing to show, and always renders only the newest post. This page also covers how the news is published (a plain kind 30023 long-form article), so an operator can post their own.

## What the user sees

When the wallet has cached a news post, Home renders a card with the article's **title** and a short **summary**, spanning the full content width so it reads as a band rather than a chip. Any `http(s)` link in the summary is tappable and opens in the browser. No markdown is rendered in the panel, and there is no empty state: with no post cached, the card simply does not appear.

The panel is **latest-only** and **language-aware**. It shows exactly one article: the most recent one from the news key **in the wallet's own language**, falling back to the newest English article when nothing is published in that language. An edit republished under the same identifier replaces it in place rather than stacking a second card.

The card is fetched from the wallet's own relay set (which includes the money-path relay `relay.floonet.dev`) on the same subscription machinery as everything else, so it arrives over [Tor](../pillars/tor.md) like the rest of the wallet's traffic. The wallet guards both the **kind** (30023) and the **author** (the news key), so a stray event on the news subscription cannot spoof the panel.

## How it works

- The news publisher is a fixed key compiled into the wallet (`NEWS_NPUB` in `goblin/src/nostr/client.rs`), currently `npub15gsytqvs5c78u83yv2agl4twjkk6qgem7gtwe2agu7s90tkelxys0xxely`.
- The wallet subscribes to that key's `kind 30023` (NIP-23 long-form) events on its relay set under a stable subscription id (`goblin-news`), so a reconnect replaces the subscription rather than piling up duplicates.
- Each post is cached with its `d` identifier, `created_at`, `title`, a summary, and a detected **language**. The store dedupes **newest-per-`d`**, and the panel (`news_latest`) selects the newest article whose language matches the wallet's locale (folded to its ISO-639-1 primary, so `zh-CN` matches `zh`), then falls back to the newest English article if there is none. A post's language comes from its `["l", …]` tag if present, otherwise a trailing `[xx]` marker in the title, otherwise it is treated as English. The summary is the `summary` tag when present, otherwise the first couple of lines of the article body flattened to plain text and capped to about two lines.

On desktop, Home now lays out to the full window width, so the news band and the rest of the Home content use the available space instead of a fixed narrow column.

## Publishing the news (MOTD how-to)

The news card is just a standard Nostr long-form article, so publishing is ordinary Nostr with two rules: sign with the news key, and send it to the relay the wallets read.

1. **Sign with the news key.** Only articles from the compiled-in news key render in the panel; anything else is ignored.
2. **Publish a `kind 30023` long-form article** (NIP-23) to **`wss://relay.floonet.dev`**. That is the money-path relay in the wallet's default set, so a post there reaches wallets. (30023 is [author-locked on Floonet relays](https://docs.floonet.dev/reference/allowed-kinds.html#public-notes-are-author-locked): the news key must be an authorized author on the relay, which the flagship is configured for.)
3. **Add a `title` tag and a `summary` tag.** The panel shows the title and the summary; without a `summary` tag it falls back to the first lines of the body. Keep the summary to roughly two lines.
4. **Put any link in the summary.** `http(s)` URLs in the summary are tappable in the wallet; links in the article body are not surfaced in the card.
5. **To update or correct a post, republish under the same `d` identifier.** Because the panel is latest-only and dedupes per `d`, an edit-in-place replaces the card instead of adding another. A brand-new `d` (with a newer timestamp) simply becomes the new latest.

### Caveat: verify it landed

Some Nostr clients (Jumble is one) can silently fail to deliver an event to a relay you just added to their relay list, reporting success while the write never reaches the relay. After publishing, **verify the article is actually on `relay.floonet.dev`** (query the relay for the news key's `kind 30023`), and republish if it did not land.

## Reference

In `goblin/src/nostr/`:

- `client.rs`: `NEWS_NPUB`, `NEWS_SUB`, the news subscription, and `handle_news` (kind + author guard, newest-per-`d` cache).
- `types.rs`: the cached `NewsItem`.
- `store.rs`: `save_news` (dedupe newest-per-`d`) and `news_latest`.
- `gui/views/goblin/mod.rs`: `news_panel_ui` (the Home card, tappable summary links).

## References

- The relay the news is published to: [Relays](../pillars/nostr-relays.md).
- The author-lock on the publishing relay: the Floonet [allowed kinds reference](https://docs.floonet.dev/reference/allowed-kinds.html#public-notes-are-author-locked).
