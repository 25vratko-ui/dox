# Dox – vizuálny jazyk

Dox is a second dock that should feel like a precision instrument: calm glass, crisp edges,
color used only where it carries meaning (categories, accent, state). Code: `Sources/Dox/Design/`.

## Principles

1. **Content first.** The dock body is a quiet stage; icons and category colors are the only loud things.
2. **Light has a direction.** Every surface is lit from above: a faint top sheen + a brighter top rim,
   a soft ambient shadow below. Never bevels, never inner glows on the sides.
3. **Hairlines, not boxes.** Borders are 0.5–1 pt at low alpha; separation comes from spacing first.
4. **Continuous corners everywhere** (`RoundedRectangle(style: .continuous)`), radii from tokens.
5. **Everything is a parameter.** Visuals derive from `DockAppearance`; no hard-coded dock colors.
6. **Native, not imitated.** System materials, SF Symbols, system fonts, standard controls styled lightly.

## Dock anatomy (`DockBackground`)

Bottom → top:

| Layer | Source parameter |
|---|---|
| Ambient shadow (y = 0.3 × radius) + contact shadow (≤ 2 pt), masked out of the body | `shadowRadius`, `shadowOpacity` |
| Base: `NSVisualEffectView` (behind-window, active) / opaque tint / nothing | `material`, `mode` |
| Tint wash; gradient `tint → gradientEnd` along the dock axis (vertical docks top→bottom, horizontal leading→trailing) | `tint`, `tintOpacity`, `gradientEnd` |
| Base + tint together | `backgroundOpacity` |
| Top sheen (0 → 45 % height) + 1 pt top rim | auto: stronger on dark looks |
| Border (`strokeBorder`) | `borderWidth`, `borderColor` |

Corner radius is clamped to half the short side, so a thin dock becomes a perfect capsule.
Material map (glass steps go from most to least see-through):
`ultraThin→fullScreenUI, thin→headerView, regular→titlebar, thick→sheet, ultraThick→windowBackground,
hud→hudWindow, sidebar, menu, popover` 1:1; `solid` = opaque `tint`; `clear` = tint only.
Previews inside the settings window use `DockBackground(…, blendingMode: .withinWindow)`.

## Category headers (`CategoryBadge`)

| Style | Rendering |
|---|---|
| hidden | nothing – `categorySpacing` alone separates groups |
| divider | 1 pt hairline across the dock, `primary` at 22 %, fading out at both ends |
| pill | symbol in category color on a capsule (color 18 % fill, 40 % hairline, soft color glow); 26×18 on side docks, 18×26 on top/bottom docks |
| label | symbol (category color) + name in small caps, 10 pt semibold, tracking 0.6, secondary text |

`vertical: true` = left/right dock (header above the group); `false` = top/bottom (header before the group).

## Settings window tokens (`DS`)

- **Spacing** `xs 4 · s 8 · m 12 · l 16 · xl 24`. Card padding `m`, row gap `s`, section gap `xl`.
- **Radius** `s 6` (readouts, symbol cells) · `m 10` (theme previews) · `l 14` (cards).
- **Typography** (SF Pro, system):
  `sectionTitle` 13 semibold · `rowTitle` 13 regular · `caption` 11 · `mono` 11 medium monospaced (values, hex).
- **Color** (adaptive light/dark):
  `cardBackground` white 72 % / white 4.5 % · `cardBorder` black 8 % / white 9 % ·
  `secondaryText` system secondary · `accent` Dox indigo `#5461DB` light / `#7C8CFF` dark ·
  extras `readoutBackground`, `rowSeparator`.
- **Layout** label column 150 pt, value readout 58 pt, min row height 26 pt.

## Components

- `SettingsSection(title, symbol:)` – accent-gradient symbol chip + title above a card.
- `SliderRow` – label | small slider | mono readout. Units: `pt` integer (1 decimal when step < 1),
  `%` value 0…1 shown as `35 %`, `×` one decimal, `s` two decimals.
- `ColorRow` / `OptionalColorRow` – hex readout (copy via context menu) + `ColorPicker` with opacity;
  the optional row adds a switch and remembers the last color while off.
- `ToggleRow` (switch, optional caption subtitle), `PickerRow` (`.menu` / `.segmented`).
- `SymbolPicker` – symbol chip button → popover: search, ~90 curated symbols in 9 groups,
  any valid SF Symbol name accepted (Enter or "Použiť …").
- `ThemeCard` – 148×84 abstract wallpaper tinted by the theme accent, mini dock with 4 accent-shade
  tiles, name below; selection = 2 pt `DS.Color.accent` ring + check badge; hover lifts 2.5 %.

## Motion

- Dock motion: `DS.Motion.spring(speed: appearance.animationSpeed)` =
  `.spring(response: 0.35 × speed, dampingFraction: 0.8)`; speed 0 → `nil` (no animation).
- UI feedback (hover, selection): `DS.Motion.snappy` (response 0.25, damping 0.85), not scaled.
- Animate transforms and opacity only; never animate blur radius or material changes.
- Respect Reduce Motion: callers should pass speed 0 when
  `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is on.

## Themes → parameters

| Theme | Mode | Material | Tint / gradient | Accent | Character |
|---|---|---|---|---|---|
| Obsidián | dark | hud | `#14141A` 55 % | `#7C8CFF` | default; deep glass, pills |
| Mráz | light | ultraThin | white 25 % | `#0A84FF` | airy, 1 pt white rim, dividers |
| Polárna žiara | dark | thin | `#3A1C71 → #0F6B6B` | `#5EF2C2` | gradient + glowing indicators |
| Grafit | system | sidebar | `#2B2B2E` 15 % | `#A0A0A8` | understated, lift hover, bars |
| Žeravé uhlíky | dark | ultraThick | `#2A0E0A → #5C1F0C` | `#FF9F45` | warm, glow hover |
| Papier | light | solid | `#F6F3EE` | `#C2410C` | print-like, squircle tiles, labels |
| Polnočný neón | dark | clear | `#05060A` 85 % | `#FF4FD8` | neon border, circle tiles |

A new theme should change at most: mode, material, tint (+ gradient), accent, border, radius,
shadow and one or two behaviour flavours (hover effect, indicator, header style).

## Accessibility

Text ≥ 11 pt in settings; category color is never the only cue (symbol + name exist via
`.help` / accessibility labels); all rows expose a combined label + value; contrast of
`secondaryText` follows the system.
