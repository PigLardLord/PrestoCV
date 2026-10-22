# App icon

The app icon is `PrestoCV/PrestoCV.icon`, an Icon Composer file. `ASSETCATALOG_COMPILER_APPICON_NAME` in `PrestoCV.xcodeproj/project.xcproj` names it. Xcode builds every size and appearance from this one file, and the older images for earlier iOS releases too.

## The design

The icon shows a speech bubble and a CV page: the person describes themselves, and the words become a CV. A gold spark on the folded corner stands for the draft appearing.

| Layer (back to front) | File | Fill | In `icon.json` |
|---|---|---|---|
| Background | none | Mint `#00C8B3`; dark appearance `#0A403B` | `fill-specializations`: Icon Composer's automatic gradient from Mint, and from a deep teal in the dark appearance |
| 1 Bubble | `Assets/1_Bubble.svg` | Mint, dark variant `#00DAC3` | glass, opacity 0.55, translucent group |
| 2 Document | `Assets/2_Document.svg` | white | glass, opacity 0.4, translucent group with the fold |
| 3 Fold | `Assets/3_Fold.svg` | `#E6FFFB` | glass, opacity 0.85 |
| 4 CV headings | `Assets/4_CV_Headings.svg` | white | photo, name and section titles; no glass |
| 5 CV lines | `Assets/5_CV_Lines.svg` | white | opacity 0.75; no glass |
| 6 Spark | `Assets/6_Spark.svg` | Yellow `#FFCC00` | glass, own group |

The colours are Apple's system colours (Human Interface Guidelines, Color): Mint and Yellow.

## The accent colour in the app

The app's accent colour (`AccentColor` in `PrestoCV/Assets.xcassets`) uses the Mint values that pass contrast for text: `#008575` in light mode and `#00DAC3` in dark mode. With Increase Contrast it takes the system's own Mint for that setting: `#54DFCB` in dark mode, while light mode keeps `#008575`. The design system draws with the same asset (`DesignTokens.Colors.accent`), so the app's own buttons, rows and cards and the system's controls show one Mint.

| Colour | Light | Dark | Light, Increase Contrast | Dark, Increase Contrast |
|---|---|---|---|---|
| `AccentColor` (`DesignTokens.Colors.accent`) | `#008575` | `#00DAC3` | `#008575` | `#54DFCB` |
| `OnAccentColor` (`DesignTokens.Colors.onAccent`) | `#FFFFFF` | `#00201C` | `#FFFFFF` | `#00201C` |
| `SwipeActionColor` (`DesignTokens.Colors.swipeActionTint`) | `#008575` | `#008575` | `#008575` | `#008575` |
| `AccentPressedColor` (`DesignTokens.Colors.accentPressed`) | `#006A5E` | `#59E7D8` | `#006A5E` | `#90EADD` |

- **Labels on the accent.** White on the bright Mint of dark mode reaches only 1.8:1. A label on a fill of the accent, such as the title of a primary button, uses `OnAccentColor`: white in light mode and the near-black `#00201C`, from Mint's hue, in dark mode. A disabled primary button has a grey fill, and its title takes the disabled colour instead.
- **Pressed buttons.** A press never fades a button: fading lets the screen through, and the light Mint at 80% on white reaches only 3.3:1. The design system has a style for each kind of button, and none of them fades:
  - `PrimaryButtonStyle`, a fill of the accent: pressed, the fill becomes `AccentPressedColor`, a darker Mint in light mode and a lighter one in dark mode, under the same label.
  - `AccentTextButtonStyle`, text in the accent, as in a secondary button or a form's add button: pressed, the text becomes `AccentPressedColor` and shrinks a little. The label sets no colour of its own, which would hide the pressed one.
  - `CardButtonStyle`, a card: pressed, the card shrinks a little and keeps its colours.

  Every button, navigation link, menu or link drawn in the accent, or in the system's tint, uses one of these styles, unless the system draws it: the controls of a navigation or keyboard bar, of an alert or a confirmation dialog, of a swipe action, and the items of a menu or a context menu.
- **Swipe actions.** The system draws a swipe action's symbol in white whatever its fill, so swipe actions are filled with `SwipeActionColor`, the deep Mint, in both modes.
- **No other blue.** No colour of the app is hard-coded to the system blue, purple or indigo.

| Pair | Light | Dark | Light, Increase Contrast | Dark, Increase Contrast |
|---|---|---|---|---|
| Label of a primary button (`OnAccentColor` on `AccentColor`) | 4.55:1 | 9.66:1 | 4.55:1 | 10.46:1 |
| Label of a pressed primary button (`OnAccentColor` on `AccentPressedColor`) | 6.52:1 | 11.32:1 | 6.52:1 | 12.26:1 |
| Symbol of a swipe action (white on `SwipeActionColor`) | 4.55:1 | 4.55:1 | 4.55:1 | 4.55:1 |
| Accent text on a screen (`systemBackground`) | 4.55:1 | 11.82:1 | 4.55:1 | 12.79:1 |
| Accent text on a card (`tertiarySystemBackground`) | 4.55:1 | 7.84:1 | 4.55:1 | 7.35:1 |
| Accent text on a row of a list or form (`secondarySystemGroupedBackground`) | 4.55:1 | 9.57:1 | 4.55:1 | 9.44:1 |
| Title of a pressed secondary button on a screen (`AccentPressedColor` on `systemBackground`) | 6.52:1 | 13.85:1 | 6.52:1 | 15.00:1 |
| Title of a pressed add button on a form row (`AccentPressedColor` on `secondarySystemGroupedBackground`) | 6.52:1 | 11.22:1 | 6.52:1 | 11.07:1 |

`PrestoCVTests/DesignSystem/AccentColorTests.swift` checks each of these pairs from the resolved colours, against the 4.5:1 that WCAG asks of body text, and checks that both tables show the colours and contrasts the app has. A translucent colour counts as the screen shows it, drawn over what lies beneath it. The test also checks text in the accent, at rest and pressed, on every background above; that a press changes the colour and leaves it opaque; that the primary and secondary buttons draw their titles in their own colours, not in the colour of body text; and that no colour of the app is hard-coded to blue or purple. A new pair of a label and a fill of the accent, or a new background for text in the accent, joins that test and the table. `PrestoCVTests/DesignSystem/ButtonPressTests.swift` reads every `Button`, `NavigationLink`, `Menu` and `Link` of the app's sources. It fails on one drawn in the accent or the tint without a style of the design system, outside the system's containers; a navigation link that is a row of a list or a form takes the colour of text, not the tint. Its short list of the controls the system owns elsewhere says why for each, and small sources fed to the same rule show what it rejects and what it passes.

Text in the accent stays off the grey grouped background (`systemGroupedBackground`), where the light Mint falls below 4.5:1: on a list or a form it goes in the rows. The exception is the system's own glass, such as the buttons of a navigation bar, which the system draws over that background; there the contrast in light mode, a little under 4.5:1, is the system's.

## Rules the layers follow

These come from Apple's Human Interface Guidelines, App icons, and from "Creating your app icon using Icon Composer".

- **Canvas.** 1024 × 1024, square and unmasked: the system applies the rounded corners. The content stays centred.
- **Layers.** Flat, opaque vector shapes with crisp edges, named with a number from back to front, in at most four groups. There are no own highlights, shadows, glows, blurs or bevels: the system adds them.
- **Where the effects live.** The background, the opacity of each layer and the Liquid Glass settings live in `icon.json`, not in the SVGs.
- **Shapes.** Few, filled, overlapping shapes. No text, no hairlines, and no sharp corners: the spark's tips are rounded by a stroke of its own colour.
- **Appearances.** The dark, clear and tinted appearances keep the same shapes. The dark appearance has its own background, a deep teal (`#0A403B`) from Mint's hue, so the white page and the gold spark stand out on a dark Home Screen. The clear and tinted appearances are left to Icon Composer's automatic variants; customise them there if a check shows a problem.

## Changing the icon

1. Edit or replace an SVG in `Assets/`, keeping the 1024 × 1024 canvas and the number in the name.
2. Open `PrestoCV/PrestoCV.icon` in Icon Composer (Xcode > Open Developer Tool > Icon Composer). Check Default, Dark and Mono (clear and tinted, light and dark) on iOS, with the grid on, and at small preview sizes.
3. Save. Icon Composer rewrites `icon.json`, so commit both the SVGs and `icon.json`.
