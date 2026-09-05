# Composition review after the first sample rejection

Date: 2026-09-05. Visual research only. The user has now selected the direction “同人设定纸：信息分区清楚，像精心排过的设卡”. No template/code/spec edits were made.

## Evidence and scope

I inspected the supplied, correctly decoded portrait image at `oc-sample-decoded.png`. It is a photographed **finished character poster**, with a white outer edge, slight perspective distortion, visible display/print striping, a large brand lockup at upper left, lettering behind the character, an existing occupation/name panel near the bottom, and an existing platform watermark at lower right. It is not a clean cutout illustration.

The user confirmed only the name **度漪**. Text baked into the image must remain image content; it must not be copied into editable/exported role facts. No age, affiliation, occupation, personality, or description has been provided.

The earlier rejected proposal was described as a cool-white frame plus a name at the bottom. I did not inspect a separate screenshot of that proposal, so the following critique is of that described composition against the actual source image.

## Why the earlier direction fails

- The original already contains a border, a complete typographic hierarchy, and a lower name panel. A second white frame plus another lower name plaque duplicates the same structure without adding useful information.
- The source’s deep-blue picture carries nearly all visual detail. A wide cool-white border disconnects it from the new card rather than organizing that detail.
- With only a name, a large metadata area is not an information design: it is an empty template. Decorative labels, serial numbers, unsupported biography, or repeated “未填写” would make the absence more conspicuous.
- A photo of a finished poster cannot convincingly become a fresh character illustration just by adding dividers, shadows, and a stamp. The template must treat it as a complete illustration panel and build a second, restrained information layer outside it.

## Shared rules for the selected setting-sheet direction

- Preserve the complete source, including its existing text and watermark. Scale proportionally; do not crop away the lower label or place a new opaque name panel over it. Do not recolor/repaint the character.
- Add no second rounded frame around this rectangular source. Its existing pale edge already delineates it. Keep any sheet-level background, rules, and decoration outside the illustration.
- Use one title treatment, one compact fact treatment, and one body treatment. Hierarchy should come from size, alignment, and space rather than a boxed label for every field.
- Only nonempty selected content generates a section. An absent description removes the description band and its heading/rules. This is content adaptation within one template, not additional selectable templates.
- Use the app stamp as a small maker’s mark in the sheet’s own margin, visually distinct from the original image’s watermark. Do not pile both marks into the same lower-right location.

## Composition A — aligned reference sheet (recommended for populated roles)

Illustrative dimensions below use a 1200 × 1600 page; the ratio still belongs to the design decision.

| Region | Geometry | Hierarchy |
| --- | --- | --- |
| Header | x 64–1136, y 64–214 (about 10% of height) | 度漪 at 108 px, one quiet contextual label at 22 px only if needed; no invented issue number or Latin alias. |
| Complete illustration | x 64, y 260, width 760, height about 1013 (63% width / 63% height) | Uncropped original, square corners, no extra picture frame. |
| Facts | x 872–1136, y 260–1230 (22% width) | Label 22–24 px, value 34–38 px, 30–40 px between independent facts. Thin rules group sections, not individual input cells. |
| Description | x 64–1136, y about 1330–1510 | Heading 26 px, body 30–32 px; complete overflow moves to continuation pages. Do not reserve this band when empty. |

This has a clear reading path: name → face/illustration → concise facts → narrative. The right-hand column uses actual data and the bottom is prose, so it reads as a designed character reference rather than a form. A very long value moves into a wider narrative block instead of making a 22%-wide column unreadable.

**Current name-only sample:** this populated layout must collapse. Keep the same header, enlarge the picture to about 78–80% of page width/height below it, and leave only a narrow outer margin for the stamp. Remove the entire empty facts/description scaffolding. The sparse result cannot demonstrate the eventual rich-data layout; it can only establish typography and artwork treatment. If the main agent wants to discuss absent sections, annotate them in the surrounding preview UI, not as fabricated exported content.

## Composition B — side-title illustration sheet (stronger for the current sparse role)

This differs structurally from A: the character name forms a vertical side axis, and the image occupies the upper/left body. It does not have a top title bar, a lower name plaque, or a right-side grid.

- On a 1200 × 1600 page, place the complete source at x 48, y 64, width 960, height 1280: **80% width and height**, ending at y 1344.
- Reserve x 1044–1152 as a narrow title spine. Stack the two confirmed name characters **度 / 漪** at approximately 90–96 px, with their block centered near the image’s upper-middle (roughly y 360–640), rather than repeating the source’s bottom-name location. Place a very small maker’s mark away from the original watermark, e.g. in the outer lower-left margin.
- The remaining 10–12% lower area is a flexible annotation strip. With real short facts, use 2–3 horizontally flowing fact groups, labels 22 px and values 32 px. With description, add a short labeled block and continue the complete text on subsequent pages. With the current name-only data, omit the band contents and tighten the lower spacing; do not draw an empty ruled box.
- For long names, use the same side zone as a horizontal two/three-line block in a wider title region and reduce the image proportionally. Do not rotate individual Latin letters or force every possible name into two vertical characters.

The side axis gives this particular dense poster room to remain itself while creating a clearly different outer composition. It suits sparse data better than A, but provides less immediately visible fact capacity. It should be chosen for its reading order, not merely recolored to look “less formal”.

## Source constraints relevant to a single reusable template

1. Source aspect ratio and orientation can be handled deterministically; semantic quiet areas cannot. The face, raised hand, poster logo, and lower text already occupy most of this source. Do not assume an arbitrary user image has a safe place for overlay text.
2. Original photo borders, perspective, and striping remain visible when all pixels are preserved. Enlarging them can make those capture artifacts more prominent. CSS/Canvas composition cannot promise to remove them.
3. A complete poster and a transparent full-body PNG need different fitting behavior within the same illustration region. Keep the template’s information structure stable, with contain-fit as the safe baseline, and do not depend on removing the image background.
4. The current sample contains only a two-character name. It cannot validate information density, long field wrapping, or continuation-page aesthetics. A proper template review needs a separate explicitly labeled layout fixture with real approved data or clearly marked sample data; none should be invented as facts about 度漪.

Recommendation to the main agent: keep A as the full-content template structure, borrow B’s strong side-name axis if the immediate name-only sample needs more composition, and most importantly remove empty sections instead of styling them harder. The chief improvement must be how the actual image and available information are organized, not another frame color.
