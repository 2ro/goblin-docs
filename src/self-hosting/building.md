# Building Goblin

> **Summary.** Goblin is pure Rust on [egui](https://github.com/emilk/egui), building for Linux, macOS, Windows, and Android from one workspace. Desktop is a normal `cargo build`; Android uses the NDK via a helper script. Versioning is a build number derived from commits since the GRIM fork point.

## Prerequisites

- A recent Rust toolchain (edition 2024). `goblin/scripts/toolchain.sh` sets up what's needed.
- For Android: the Android SDK + NDK and `cargo-ndk` (driven by `goblin/scripts/android.sh`).
- For the [name authority](name-authority.md) / [relay](relay.md): build those from the `goblin-nip05d` crate separately.

## Desktop

```sh
cd goblin
cargo build              # debug
cargo build --release    # stripped release binary (see [profile.release])
./scripts/desktop.sh     # convenience wrapper
cargo test               # unit + drift tests (live e2e tests are #[ignore])
```

The release binary is `goblin`. Linux packaging into an AppImage uses the `linux/Goblin.AppDir/` layout; Windows embeds an icon via `winresource`; macOS builds a universal binary.

## Android

```sh
cd goblin
./scripts/android.sh release '' <flavor>   # flavor is required; empty version auto-derives
```

This produces signed-or-debug APKs (arm v7/v8, plus x86_64 for emulators). The manifest is configured to survive configuration changes (orientation, dark-mode, locale) without restarting.

## Versioning

There is no semver. `build.rs` computes **Build N = commits since `GOBLIN_FORK_BASE` (`b51a46b`)**, or honors an explicit `GOBLIN_BUILD` env var (used for single-commit public builds). The build number shows in the title bar and About screen.

## Releases and download links

The public download page at [goblin.st](https://goblin.st) links to stable, unversioned paths (`/dl/android`, `/dl/linux`, `/dl/appimage`, `/dl/windows`, `/dl/macos`) rather than to a specific build. Each `/dl/*` path resolves to the matching asset on the **latest** GitHub release, so the site never has to be edited when a new build ships. The in-app updater is stricter: it matches assets by exact name (for example `-android-arm.apk`), so a release whose asset names drift will 404 the update.

Two rules keep the aliases working:

1. **Every release uploads the stable-named assets** for all platforms alongside the per-build files, so the `/dl/*` aliases have something current to point at.
2. **Run the post-publish link check** after the release is published: `/opt/goblin/bin/check-dl-links.sh` on the us-east host follows each `/dl/*` alias and verifies it resolves to a real asset on the latest release. Treat a failure as a broken download page.

## Localization

To add or fix a locale, edit the YAML under `goblin/locales/`. The `i18n_keys` test enforces that every locale has every key; run `cargo test --test i18n_keys`. See [Localization](../subsystems/localization.md).

## Reference

- Build scripts: `goblin/scripts/{desktop,android,toolchain,version}.sh`, `gen_icons.sh`, `make-icns.py`.
- Versioning: `goblin/build.rs`; profiles: `goblin/Cargo.toml` (`[profile.release]`, `[profile.release-apk]`).
- Tests: `goblin/tests/{nostr_e2e,replay_check,i18n_keys}.rs`.

## References

- The engine you're building: [GRIM base](../pillars/grim-base.md).
