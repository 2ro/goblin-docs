# Localization

> **Summary.** Every user-facing string in the Goblin surface goes through translation keys. Ten locales ship today (English, German, French, Russian, Turkish, Simplified Chinese, Traditional Chinese, Spanish, Korean, Japanese), and a test fails the build if any key is missing from any locale.

## Motivation

Goblin is aimed at a global audience, so hard-coded English is a non-starter. The constraint that matters operationally is *drift*: as features are added, it's easy for a new string to exist in `en.yml` but nowhere else. A parity test turns that from a silent gap into a failing test.

## How it works

Strings are referenced with the `t!("goblin.…")` macro and defined in per-locale YAML under `goblin/locales/`. The ten files (`en`, `de`, `fr`, `ru`, `tr`, `zh-CN`, `zh-TW`, `es`, `ko`, `ja`) share an identical key tree. An integration test loads all of them and asserts every `goblin.*` key present in one locale is present in all, so adding a key means adding it everywhere. The display language is auto-detected from the system locale on first run and can be overridden in Settings.

For example, the recent UI change that renamed the relay row added a `goblin.settings.nostr_relays` key to all ten files at once; the parity test is what guarantees that. Beyond parity, the non-English locales get periodic full translation passes as screens change, so the wording stays natural rather than merely present.

## Reference

- `goblin/locales/{en,de,fr,ru,tr,zh-CN,zh-TW,es,ko,ja}.yml`: the string tree.
- `goblin/tests/i18n_keys.rs`: `every_locale_has_all_goblin_keys` (the drift test).
- Usage: `t!("…")` call sites throughout `goblin/src/gui/views/goblin/`.

## References

- Contributing a locale: [Building Goblin](../self-hosting/building.md).
