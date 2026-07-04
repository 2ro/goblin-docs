# Goblin Docs

Source for **<https://docs.goblin.st>**, the Goblin documentation site, built with
[mdBook](https://rust-lang.github.io/mdBook/) and skinned to match goblin.st.

## Build locally

```sh
cargo install mdbook       # once
mdbook serve               # live preview at http://localhost:3000
mdbook build               # writes static site to ./book
```

## Layout

```
book.toml          mdBook config (default theme: navy, restyled by goblin.css)
goblin.css         the Goblin skin (Geist fonts, #FFD60A accent, mobile-first)
goblin.js          progressive enhancement (frames ![shot: …] images)
src/
  SUMMARY.md       the chapter tree
  README.md        Introduction
  overview/        what Goblin is + architecture
  pillars/         GRIM · Nostr · Tor (the three foundations)
  features/        payment flow, send/request, name authority, onboarding, cancel/decline
  subsystems/      theme, avatars, QR, localization, security
  self-hosting/    run your own authority / relay / requester; building
  fonts/           Geist TTFs (copied into the build)
  assets/          marks + screenshots
```

## Deployment

The site auto-deploys on push, mirroring the goblin.st pipeline:

```
push to git.us-ea.st/GRIN/goblin-docs
   │  Forgejo webhook (HMAC)
   ▼
server: git pull --ff-only  →  mdbook build -d /opt/goblin/www-docs
   ▼
nginx serves docs.goblin.st from /opt/goblin/www-docs
```

The nginx vhost template is in [`deploy/docs.goblin.st.conf`](deploy/docs.goblin.st.conf).
Only the Markdown source is committed; `book/` is git-ignored and built on the server.
