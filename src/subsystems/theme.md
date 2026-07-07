# Theme: light / dark / yellow

> **Summary.** Goblin has three themes (Light, Dark, and a high-contrast **Yellow**) driven by a single set of design tokens. The tokens distinguish "text on the background" from "text on a surface," which is what makes the bright-yellow theme readable.

## Motivation

A payments app is used in sunlight and in bed; some people want the brand's yellow front-and-center. Centralizing every color into one token struct (rather than scattering hex values) means a new theme is just a new token set, and accessibility fixes happen in one place. The Yellow theme in particular forced a clean separation: on a bright background, on-surface text needs different colors than on-background text, so the token set carries both.

## How it works

`ThemeKind` selects one of three `ThemeTokens` palettes. Tokens cover backgrounds (`bg`, `surface`, `surface2`), text **on the background** (`text`, `text_dim`, `text_mute`), text **on surfaces** (`surface_text`, `surface_text_dim`, `surface_text_mute`), plus `line`, `accent` (the Goblin yellow `#FFD60A`), positive/negative status colors, hover, and eight `(background, ink)` **avatar pairs**. The selected theme persists in app config and is chosen from the Settings appearance picker.

The rule for contributors: any new on-card text must use the `surface_text*` tokens, never the on-background `text*` tokens, otherwise it goes black-on-bright in the Yellow theme.

> The docs site you're reading reuses this palette (Geist type, `#FFD60A` accent on `#0E0E0C` ink) so it feels like the app.

## The Appearance settings section

The theme picker lives in an **Appearance** section of Settings that gathers the look-and-feel choices in one place:

- **Theme.** Light, Dark, or Yellow, as above.
- **Language.** A selector for the wallet's display language; Goblin auto-detects your system language on first run and this lets you override it. See [Localization](localization.md).

The lone "Hide amounts" notification toggle that once sat here now lives on its own page alongside two further notification-privacy levels and the Anonymous-mode balance blur: see [Advanced Privacy & Anonymous mode](../features/anonymous-mode.md).

When an app update is available, an **update button** appears near the profile panel. Tapping it opens the update dialog, which carries Goblin's own branding and the changelog for the new version, along with links to the source on [github.com/2ro/goblin](https://github.com/2ro/goblin), the community on [t.me/goblinfamily](https://t.me/goblinfamily), and these docs at [docs.goblin.st](https://docs.goblin.st).

## Reference

- `goblin/src/gui/theme.rs`: `ThemeKind` (`Light` / `Dark` / `Yellow`), `ThemeTokens`, the `LIGHT` / `DARK` / `YELLOW` palettes, the avatar pairs, and `theme::tokens()` / `ink_for()` helpers.
- Picker: appearance section in `goblin/src/gui/views/goblin/mod.rs` settings.

## References

- Avatar colors come from these pairs: [Avatars & identicons](avatars.md).
