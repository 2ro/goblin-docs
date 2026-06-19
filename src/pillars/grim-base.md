# GRIM: the wallet engine Goblin forks

> **Summary.** Goblin is a fork of **GRIM**, a cross-platform Grin wallet and integrated node written in Rust on [egui](https://github.com/emilk/egui). Goblin keeps GRIM's entire money engine (seed/key management, node and chain sync, and the Mimblewimble slatepack transaction state machine) unmodified, and adds its payments experience in new modules alongside it.

## Motivation

Writing a correct cryptocurrency wallet is hard and security-critical; writing a Grin wallet *and* a full Grin node is harder still. GRIM had already done that work: a mature, audited egui app with the complete Grin stack vendored in. Rather than reimplement any of it, Goblin forks GRIM and treats it as a stable foundation, so all of Goblin's new code is about *messaging and transport*, not about money primitives. This keeps the risky surface (key handling, transaction building, consensus) on well-trodden upstream code.

## How it works

GRIM bundles the Grin node and wallet libraries as path dependencies and drives them from an egui UI. Goblin inherits all of that:

- **Seed & keys.** BIP-39 mnemonic (12–24 words), the wallet master seed, and Grin's output/rangeproof key derivation: all GRIM/Grin code. Your Grin *funds* are controlled by this seed. (Goblin's *nostr* identity is deliberately separate; see [Identity](nostr-identity.md).)
- **Integrated node + sync.** GRIM can run a full Grin node or talk to an external one, track the chain tip, and scan for your outputs. Goblin exposes this under **Settings → Node** but does not change it.
- **The slatepack transaction machine.** Grin's interactive flow (Standard (send) and Invoice (request), each a two-step slate exchange) and the slatepack armor encoding live in the Grin wallet library. Goblin's entire job is to *carry* these slatepacks; it never alters how they're built or validated.
- **The egui shell & platform layer.** Window, fonts, Android/desktop entry points, camera, and storage abstractions come from GRIM.

What Goblin **adds** lives in three new trees that GRIM doesn't have (`src/nostr/`, `src/nym/`, and `src/gui/views/goblin/`), plus a handful of hooks into the wallet lifecycle (`src/wallet/wallet.rs`) to start/stop the Nostr service and dispatch `WalletTask::Nostr*` jobs.

What Goblin **changes** in upstream is intentionally minimal: it swaps the default presented surface to the Goblin UI, removes the old clearnet/Tor transport in favor of Nym, and rebrands. The original GRIM tree is kept side-by-side (at `../grim`) precisely so the fork can be diffed and stay close to upstream.

## Reference

- **Crate identity.** The package is still named `grim` (`version = "0.3.6"`), the binary is `goblin`; see `goblin/Cargo.toml` (`[package]`, `[[bin]]`). The node/wallet libraries are path deps: `grin_api = { path = "node/api" }`, `grin_chain`, `grin_wallet_*`, etc.
- **Versioning is build-number based, off the fork point.** `goblin/build.rs` defines `GOBLIN_FORK_BASE = "b51a46b"` (the GRIM commit Goblin forked from) and computes **Build N = number of commits since the fork** via `git rev-list`. An explicit `GOBLIN_BUILD` env var overrides it (used by CI single-commit public builds). So Goblin ships "Build 97," not a semver.
- **Release profiles.** `[profile.release]` strips symbols (the nym+nostr+grin tree is ~16 MB of symbols); `[profile.release-apk]` adds `opt-level="z"`, `lto`, `panic="abort"` for Android size.
- **Upstream.** GRIM lives at <https://code.gri.mw/GUI/grim> (author *Ardocrat*). Goblin's `repository` field still points there.

To see exactly what the fork changed, diff the two trees:

```sh
diff -ru ../grim/src ./src        # new: nostr/, nym/, gui/views/goblin/
diff -ru ../grim/Cargo.toml ./Cargo.toml
```

## References

- `goblin/Cargo.toml`: package name, binary, path deps, release profiles.
- `goblin/build.rs:5-6`: `GOBLIN_FORK_BASE = "b51a46b"`; build-count logic at `:11-34`.
- `goblin/README.md`: "Goblin is a fork of the **Grim** egui GRIN wallet…".
- Reference copy of upstream GRIM: `../grim` (sibling of the `goblin` tree).
- egui: <https://github.com/emilk/egui>.
