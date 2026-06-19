# Avatars & identicons

> **Summary.** Every account gets a distinctive avatar with no upload and no server storage: a two-tone gradient deterministically derived from the public key, with the Grin mark or the person's initial on top. The derivation is byte-identical across platforms.

## Motivation

Faces make a contact list scannable. But hosting user images means storage, moderation, and a privacy leak (who fetched whose picture, from where). Goblin sidesteps all of it: an avatar is a pure function of the pubkey, computed on the device. Same key → same avatar, on every platform, forever, so you recognize a contact by their colors even before a name resolves.

## How it works

The pubkey (normalized to lowercase hex) is hashed with SHA-256; bytes of that hash choose two hues, a blend offset, and a gradient angle (HSL→RGB, all in `f64` so independent ports produce identical bytes). The result is rendered as an SVG gradient. On top:

- a **letter** (the contact's initial) for named users, or
- the **Grin mark** for anonymous keys.

When a contact *does* publish a picture in their Nostr profile, Goblin can render that instead; otherwise the deterministic gradient is the fallback, so there is always an avatar. The eight theme [avatar pairs](theme.md) supply complementary ink colors so initials stay legible.

## Reference

- `goblin/src/gui/views/goblin/identicon.rs`: `to_hex_seed()`, `gradient_params()` (SHA-256 → hues/angle), `gradient_bg_svg()`, `gradient_avatar_svg()` (gradient + Grin mark), `GRIN_PATH`, `LOGO_FRAC`, `LOGO_OPACITY`.
- `goblin/src/gui/views/goblin/widgets.rs`: `avatar()`, `gradient_avatar()`, `gradient_letter_avatar()`, `avatar_any()` (dispatch to the best available avatar).
- Picture handling/processing: `goblin/src/nostr/avatar.rs` (format sniff, square-crop, resize, metadata strip).

## References

- The color pairs: [Theme](theme.md).
- Where avatars appear: [Send & request](../features/send-request.md).
