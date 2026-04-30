# MySimsLife — Design system

Living document. Update when patterns change. The goal: stop regressing on the
same UI bugs (clipping, padding, alignment) every time we touch a view.

## Palette

All colours live in `MySimsLife/Theme/SimsTheme.swift`. **Never hardcode RGB
literals in views.** If you need a colour that isn't there, add it to the theme.

| Constant                  | Hex     | Use                                          |
| ------------------------- | ------- | -------------------------------------------- |
| `panelPeriwinkle`         | #929FCA | Panels, cards, list rows, field backgrounds  |
| `frame`                   | #0E135B | Borders/strokes, primary text, primary icons |
| `textPrimary`             | #0E135B | Headings, body text on light bgs             |
| `textSecondary`           | #0E135B@65% | Secondary labels                         |
| `tabActive`               | cream   | Selected chips/options                       |
| `accentGreen`             | sims green | Positive deltas, achievements             |
| `negativeTint`            | sims red | Destructive actions, negative deltas        |
| `backgroundGradient`      | navy gradient | Outer screen background (top-left → bot-right) |

Do **not** introduce a "dark variant" of `panelPeriwinkle` for inactive states.
Use opacity (`.opacity(0.55)`) or `tabActive` for selection.

## Layout primitives

Three styled-rect helpers — use these instead of hand-rolling `RoundedRectangle
+ fill + overlay(stroke)`:

- `View.simsFieldStyle(cornerRadius:selected:)` — periwinkle fill + 1.2pt navy
  stroke. The default for input fields, option rows, kind chips.
- `View.simsChipStyle(selected:)` — capsule version. For inline chips.
- `SimsTintedTile(tint:cornerRadius:lineWidth:)` — gradient tint + navy
  stroke. The Sims-2 "icon tile" backdrop. Pair with `SimsOutlinedIcon`.
- `SimsOutlinedIcon(systemName:size:)` — navy outline (heavy) layered behind a
  white fill (bold). Faked-stroke SF Symbol. Always use this for outlined
  icons; never re-roll the two-Image trick inline.

## Container / overflow rules — **READ BEFORE TOUCHING ANY SCROLLVIEW**

This is the recurring bug. Borders are 1.5pt centred on the path → they extend
0.75pt outside the shape's nominal bounds. `.scaleEffect()` and `.shadow()`
also render outside the layout frame. Any clip cuts these.

### Default behaviour to assume

- `ScrollView` clips its viewport by default.
- `VStack` / `HStack` / `ZStack` do **not** clip.
- `.background(...)` fills the padded frame; it does **not** clip.
- `.frame(width:height:)` constrains size but does not clip rendering of
  scaled / shadowed content.

### Rules

1. **Any view with a 1.5pt navy border placed at x=0 of its parent will lose
   0.75pt of stroke if the parent clips.** Always either:
   - leave ≥4pt of horizontal padding around bordered content, or
   - put the bordered content inside a non-clipping parent.

2. **Any view with `.scaleEffect(>1)` needs ≥`(scale - 1) × max(width, height)`
   of breathing room on every side**, because parents clip the over-scaled
   portion. Aspiration cards scale to 1.03 → need ≥4pt vertical padding around
   their HStack.

3. **Horizontal scroll inside vertical scroll** loses bleed-to-edge. The outer
   `ScrollView` clips at its viewport, so any negative padding on the inner
   `ScrollView` only extends within the outer's bounds, not past them.
   - For tabs that ONLY contain a horizontal scroll (aspirations, agenda):
     don't wrap them in a vertical `ScrollView` at all.
   - For tabs that mix vertical and horizontal scrolling (none currently),
     this needs a custom solution — don't blanket-add `.scrollClipDisabled()`.

4. **`.scrollClipDisabled()` is a hammer.** It disables the clip on **both**
   axes. Using it on a vertical scroll lets content overflow past the bottom
   too. Avoid unless the scroll holds only horizontal content and overflow
   is genuinely intended.

5. **Don't double-pad.** If the parent has `.padding(.horizontal, 22)` and you
   add `.padding(.horizontal, 4)` inside, total inset is 26pt — likely too
   much. Pad in ONE place.

## Sims-2 tabs (`tabbedPanel` in DashboardView)

Anatomy:

- Three layers in a `ZStack`:
  - Inactive tabs (zIndex 0, behind panel)
  - Panel (zIndex 1)
  - Active tab (zIndex 2, in front of panel)
- Each tab is `tabHeight` tall (`38` compact / `44` regular).
- The active tab's body extends the full `tabHeight`, but its 3-sided stroke
  (`TabTopBorderShape`) only spans `strokeHeight = tabHeight - panelOverlap`.
  The lower 8pt of body merges visually into the panel's top.
- Panel's `topLeading` corner is 0 radius (square) — first tab sits flush.
- When the active tab is the leftmost, its body covers the panel's left
  stroke for the overlap pixels. This leaves a visible gap. Patched in
  `sims2Tab` with a `Rectangle().fill(SimsTheme.frame).frame(width: 1.5,
  height: panelOverlap+1).offset(x: -0.75)` — must be CENTRED on x=0 to
  align with the panel's stroke (also centred on its left edge).

Don't change `panelOverlap` without checking the patch alignment.

## Editor sheets (AspirationEditor, TaskEditor, CustomActionSheet, CategoriesEditor)

- Outer bg: `SimsTheme.backgroundGradient.ignoresSafeArea()`.
- Section title helper: `caption2 / .heavy / tracking 1.2 / uppercase /
  textSecondary`.
- All field bgs use `simsFieldStyle()` (or `simsChipStyle()` for chips). Don't
  re-style.
- Selected state: pass `selected: true` to the helper. Renders cream
  (`SimsTheme.tabActive`) fill with thicker navy stroke.

## Recurring regressions to watch for

When making any layout change, audit these specific spots — they break
repeatedly:

- **Need bar avatars (`NeedBarView.tile`)**: the navy stroke is at x=0 of the
  bar's HStack. The bar lives inside the LazyVGrid, inside the panel's inner
  scroll. If the inner scroll has 0pt horizontal padding + clips → stroke is
  cut. Fix: 4pt horizontal padding INSIDE the needs scroll, applied
  specifically to the grid container (not the outer scroll content — that
  would also clip the aspirations bleed).
- **Aspiration card pulse**: `.scaleEffect(1.03)` on completion. Parent
  HStack must have ≥4pt vertical padding so the scaled corners aren't
  clipped by the horizontal scroll.
- **Aspirations / agenda right-edge bleed**: the `padding(.horizontal,
  -inset)` trick only works if there's no clipping `ScrollView` between the
  row and its target edge. Don't wrap these tabs in a vertical scroll.
- **Active Sims-2 tab patch**: must be centred on x=0 (offset -0.75pt). Double
  check the math anytime `lineWidth` or `panelOverlap` changes.

## How to know you're regressing

Before merging a layout change, mentally walk through each of:

1. Does a 1.5pt border on a child sit at the parent's x=0? → likely clipped.
2. Does any descendant `.scaleEffect`? → parent needs scale buffer.
3. Did you add `.padding` to a `ScrollView`'s content? → does it conflict
   with negative padding tricks of children rows?
4. Did you add `.scrollClipDisabled()`? → does it let content overflow on the
   wrong axis?
5. Did you hardcode a colour literal? → use `SimsTheme.*`.
