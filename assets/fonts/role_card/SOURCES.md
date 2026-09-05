# Role-card fonts

These two static OpenType/CFF fonts are bundled for the role-card template. They are official Adobe release binaries, copied without any glyph, metadata, name, format or subset modification. No AI-generated assets are used.

Retrieved and verified: 2026-09-05.

| Asset | Use / Flutter alias | Upstream version | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `SourceHanSerifCN-Bold.otf` | Title, `RoleCardSerif`, weight 700 | Source Han Serif 2.003 (`2.003R`) | 12,094,680 | `4ee555ae58b3d22f6a95c2c494f2c36b7cccfc1d2224635f6461a03756f0e3c1` |
| `SourceHanSansSC-Regular.otf` | Body, `RoleCardSans`, weight 400 | Source Han Sans 2.005 (`2.005R`) | 16,529,832 | `f1d8611151880c6c336aabeac4640ef434fa13cbfbf1ffe82d0a71b2a5637256` |

The Flutter aliases are application configuration only; the font binaries and their internal family names are unchanged. Only the stated weight is bundled in each family.

## Exact sources

- Serif upstream: [Adobe Source Han Serif](https://github.com/adobe-fonts/source-han-serif).
  - Release commit: `7889f11bf31170b5d092a083b357c8c8130f89e0`.
  - [Pinned original font](https://raw.githubusercontent.com/adobe-fonts/source-han-serif/7889f11bf31170b5d092a083b357c8c8130f89e0/SubsetOTF/CN/SourceHanSerifCN-Bold.otf).
  - [Pinned original license](https://raw.githubusercontent.com/adobe-fonts/source-han-serif/7889f11bf31170b5d092a083b357c8c8130f89e0/LICENSE.txt), preserved as `source-han-serif-LICENSE.txt` (4,463 bytes; SHA-256 `9ff5bb567e1b92c801fc1069e5fbf992ff8efccacb9db94e5959a5b3ba9bb903`).
- Sans upstream: [Adobe Source Han Sans](https://github.com/adobe-fonts/source-han-sans).
  - Release commit: `a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2`.
  - [Pinned original font](https://raw.githubusercontent.com/adobe-fonts/source-han-sans/a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2/OTF/SimplifiedChinese/SourceHanSansSC-Regular.otf).
  - [Pinned original license](https://raw.githubusercontent.com/adobe-fonts/source-han-sans/a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2/LICENSE.txt), preserved as `source-han-sans-LICENSE.txt` (4,463 bytes; SHA-256 `fcac737e761ec63dbfbdce11030a1780161920d80315edba9c8beff1c2bac5a2`).

Both upstream repositories link their `release` branch from the main README as the font download location. The immutable commit URLs above pin the actual downloaded resources.

## License

Both fonts use SIL Open Font License 1.1. The complete upstream copyright notice and license are retained beside each asset. OFL permits embedding and bundling with software, including commercial software, subject to its conditions. Fonts cannot be sold by themselves; this license does not apply to documents/images created with them. `Source` is the reserved font name. Read the complete license files for the actual terms.

Distribute both license files with the app and make them available in the app's license notices. Keeping them in the repository alone is not the application distribution step.

## Coverage and size choice

The template uses a mixed configuration: the smaller official **CN region-specific Serif subset** for titles, and the official **SC language-specific Sans** for body text and explicit title fallback. The SC font retains the Sans family's full character coverage and defaults to Simplified Chinese forms. Adobe describes the configurations in the [Serif release README](https://github.com/adobe-fonts/source-han-serif/tree/7889f11bf31170b5d092a083b357c8c8130f89e0#language-specific-otfs) and [Sans release README](https://github.com/adobe-fonts/source-han-sans/tree/a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2#language-specific-otfs).

Direct `cmap` inspection confirms that both selected fonts cover the complete basic CJK unified-ideograph block (20,992 code points), Extension A (6,592), common Japanese kana and the sample name `度漪`. Sans SC additionally contains all 11,172 Hangul syllables and `𠮷` (U+20BB7), which Serif CN lacks. Set `RoleCardSans` as explicit title fallback so those characters still use bundled fonts. Their title appearance switches from Serif to Sans; consistent serif styling cannot be promised for those characters. Script-specific glyph forms require appropriate locale/language tagging and shaping; an SC default is not a guarantee of Japanese/Korean regional forms without that configuration.

The selected pair totals **28,624,512 bytes / 27.30 MiB**. This saves 13,427,052 bytes / 12.81 MiB versus two SC fonts (40.10 MiB), and adds 7.73 MiB versus two CN fonts (19.57 MiB) while covering ordinary Korean/name cases with the bundled Sans fallback. These are uncompressed asset sizes, not measured final app-download sizes. No additional weights, families or custom subsets are included.

“Full character coverage” means the upstream family's coverage, not every Unicode character. Rare extensions such as `𠀀` (U+20000), emoji and some other scripts/symbols remain outside these fonts. Without an explicitly bundled fallback those characters may use device fonts or a missing-glyph box, and their appearance/metrics are not guaranteed across platforms. Load these assets before measuring or painting, use the same font setup for preview/export, and do not promise universal Unicode fallback consistency.
