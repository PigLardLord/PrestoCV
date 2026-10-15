# App icon

The app icon is `PrestoCV/PrestoCV.icon`, an Icon Composer file. `ASSETCATALOG_COMPILER_APPICON_NAME` in `PrestoCV.xcodeproj/project.xcproj` names it. Xcode builds every size and appearance from this one file, and the older images for earlier iOS releases too.

## The design

The icon shows a speech bubble and a CV page: the person describes themselves, and the words become a CV. A gold spark on the folded corner stands for the draft appearing.

| Layer (back to front) | File | Fill | In `icon.json` |
|---|---|---|---|
| Background | none | Mint `#00C8B3` | `fill`: Icon Composer's automatic gradient from Mint |
| 1 Bubble | `Assets/1_Bubble.svg` | Mint, dark variant `#00DAC3` | glass, opacity 0.55, translucent group |
| 2 Document | `Assets/2_Document.svg` | white | glass, opacity 0.4, translucent group with the fold |
| 3 Fold | `Assets/3_Fold.svg` | `#E6FFFB` | glass, opacity 0.85 |
| 4 CV headings | `Assets/4_CV_Headings.svg` | white | photo, name and section titles; no glass |
| 5 CV lines | `Assets/5_CV_Lines.svg` | white | opacity 0.75; no glass |
| 6 Spark | `Assets/6_Spark.svg` | Yellow `#FFCC00` | glass, own group |

The colours are Apple's system colours (Human Interface Guidelines, Color): Mint and Yellow. The app's accent colour (`AccentColor`) uses the Mint values that pass contrast for text: `#008575` in light mode (4.5:1 on white) and `#00DAC3` in dark mode.

## Rules the layers follow

These come from Apple's Human Interface Guidelines, App icons, and from "Creating your app icon using Icon Composer".

- **Canvas.** 1024 × 1024, square and unmasked: the system applies the rounded corners. The content stays centred.
- **Layers.** Flat, opaque vector shapes with crisp edges, named with a number from back to front, in at most four groups. There are no own highlights, shadows, glows, blurs or bevels: the system adds them.
- **Where the effects live.** The background, the opacity of each layer and the Liquid Glass settings live in `icon.json`, not in the SVGs.
- **Shapes.** Few, filled, overlapping shapes. No text, no hairlines, and no sharp corners: the spark's tips are rounded by a stroke of its own colour.
- **Appearances.** The dark, clear and tinted appearances keep the same shapes. They are left to Icon Composer's automatic variants; customise them there if a check shows a problem.

## Changing the icon

1. Edit or replace an SVG in `Assets/`, keeping the 1024 × 1024 canvas and the number in the name.
2. Open `PrestoCV/PrestoCV.icon` in Icon Composer (Xcode > Open Developer Tool > Icon Composer). Check Default, Dark and Mono (clear and tinted, light and dark) on iOS, with the grid on, and at small preview sizes.
3. Save. Icon Composer rewrites `icon.json`, so commit both the SVGs and `icon.json`.
