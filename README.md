# Giant Thumbs

An alternative keyboard for Android (iOS soon) with large, transparent keys and a branching glyph system for fast one-handed typing.

## What it does

- **Large keys** — a configurable grid (default 4×3) fills the screen so every target is easy to hit
- **Transparent overlay** — keys are semi-transparent (configurable 5–95%) so you can see the app behind the keyboard
- **Hold & branch** — hold any key to reveal a radial ring of related glyphs (symbols, accented characters, punctuation). Swipe to a child and hold again to go deeper
- **Grammar key (`*`)** — quick access to punctuation and special characters
- **Settings key (`#`)** — opens layout and transparency settings in-app
- **System keyboard** — installs as a proper Android IME so it works in every app

## Default layout

```
1  2  3
4  5  6
7  8  9
*  0  #
```

Hold examples:
- `*` → `.` `,` `?` `!` `;` `:`
- `4` → `$` `€` `£`
- `9` → `+` `=` `~`

## Project structure

```
lib/
  main.dart            # App entry point + demo shell
  keyboard_view.dart   # 4×3 key grid + branch stack manager
  key_segment.dart     # Individual key widget (tap / long-press)
  branch_overlay.dart  # Radial branch popup with swipe selection
  key_data.dart        # Glyph definitions and branch trees
  ime_channel.dart     # Platform channel to Android IME service
  settings_screen.dart # Column count + opacity settings UI

android/app/src/main/
  kotlin/.../GiantThumbsIME.kt   # Android InputMethodService
  res/xml/ime_method.xml         # IME declaration
  AndroidManifest.xml            # Service registration
```

## Building & running

**Prerequisites:** Flutter 3.x, Android Studio, Android SDK

```bash
# Run the demo app (shows keyboard over a test screen)
flutter run

# Build a release APK to sideload
flutter build apk --release
```

After installing the APK:
1. Go to **Settings → Language & Input → Keyboards**
2. Enable **Giant Thumbs**
3. In any text field, switch input method to Giant Thumbs

## Configuring

Inside the app (or tap `#` while using the keyboard):
- **Columns** — choose 2, 3, or 4 columns
- **Transparency** — slide to adjust key opacity

## Roadmap

- [ ] Letter / alphabet mode with full branching tree
- [ ] Swipe-path word prediction
- [ ] Smartwatch support
- [ ] iOS `UIInputViewController` implementation
