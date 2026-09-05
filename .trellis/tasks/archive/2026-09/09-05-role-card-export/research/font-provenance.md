# Role-card font provenance and coverage

Date: 2026-09-05. Scope: two font files, their original licenses and source documentation. No application Dart, pubspec or native registration was modified by this font-preparation step.

## Selected assets

| Application asset | Intended family / weight | Upstream release | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `assets/fonts/role_card/SourceHanSerifCN-Bold.otf` | `RoleCardSerif`, 700 | Serif `2.003R`, internal version 2.003 | 12,094,680 | `4ee555ae58b3d22f6a95c2c494f2c36b7cccfc1d2224635f6461a03756f0e3c1` |
| `assets/fonts/role_card/SourceHanSansSC-Regular.otf` | `RoleCardSans`, 400 | Sans `2.005R`, internal version 2.005 | 16,529,832 | `f1d8611151880c6c336aabeac4640ef434fa13cbfbf1ffe82d0a71b2a5637256` |

Serif source: [official binary](https://raw.githubusercontent.com/adobe-fonts/source-han-serif/7889f11bf31170b5d092a083b357c8c8130f89e0/SubsetOTF/CN/SourceHanSerifCN-Bold.otf), release commit `7889f11bf31170b5d092a083b357c8c8130f89e0`.

Sans source: [official binary](https://raw.githubusercontent.com/adobe-fonts/source-han-sans/a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2/OTF/SimplifiedChinese/SourceHanSansSC-Regular.otf), release commit `a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2`.

The main official repository READMEs were opened first and their “Latest release” links followed to the official release branches. GitHub API metadata resolved the branch commits and latest release tags, and confirmed individual-file sizes. Font names and embedded versions were checked directly from each downloaded OTF's `name` table, rather than relying on filenames alone. OTF signature and `file` identification were also checked.

No glyph data, metadata, internal naming, format or subset was modified. The final assets use the official Serif CN subset and Sans SC font; unselected Serif SC and Sans CN binaries are not repository assets. No user artwork or AI imagery was added.

## License verification

Read both original Adobe `LICENSE.txt` files in full. Both declare SIL OFL 1.1; Serif carries Adobe's 2017–2022 notice, Sans 2014–2025. Both reserve `Source`. The license permits use/bundling/embedding and distribution with commercial software subject to its conditions, retains copyright/license notices with the font, disallows selling the font by itself, and does not place generated documents under OFL. The application-family aliases do not modify font binaries.

Original copies retained byte-for-byte:

- `assets/fonts/role_card/source-han-serif-LICENSE.txt` — [pinned upstream license](https://raw.githubusercontent.com/adobe-fonts/source-han-serif/7889f11bf31170b5d092a083b357c8c8130f89e0/LICENSE.txt); 4,463 bytes; SHA-256 `9ff5bb567e1b92c801fc1069e5fbf992ff8efccacb9db94e5959a5b3ba9bb903`.
- `assets/fonts/role_card/source-han-sans-LICENSE.txt` — [pinned upstream license](https://raw.githubusercontent.com/adobe-fonts/source-han-sans/a4f7cf94edfb9d7ffbdfc4841de276358bd7e0f2/LICENSE.txt); 4,463 bytes; SHA-256 `fcac737e761ec63dbfbdce11030a1780161920d80315edba9c8beff1c2bac5a2`.

Integration must include both license texts in shipped assets and expose them through the app's license notices/Flutter license registry. `assets/fonts/role_card/SOURCES.md` is the long-lived provenance record; this task note records the decision process.

## Why mix Serif CN with Sans SC

Adobe's release documentation distinguishes [language-specific OTFs with full family coverage](https://github.com/adobe-fonts/source-han-serif/tree/7889f11bf31170b5d092a083b357c8c8130f89e0#language-specific-otfs) from regional subsets. The actual CN fonts contain no Hangul syllables and lack `𠮷`, so relying only on CN would introduce ordinary character-name fallback cases. The final decision retains the smaller Serif CN for titles while bundling Sans SC for body text and explicit title fallback. That avoids carrying two complete SC files while keeping common CJK text in bundled assets.

A read-only Python `struct` inspection of OpenType tables unioned Unicode format 4/12 `cmap` entries with nonzero glyph IDs, and read `maxp`/`name` metadata. These are observed mapped-codepoint counts, not a statement that every code point represents a distinct drawing:

| Measurement | Serif CN Bold | Serif SC Bold | Sans CN Regular | Sans SC Regular |
| --- | ---: | ---: | ---: | ---: |
| Bytes | 12,094,680 | 25,521,732 | 8,429,224 | 16,529,832 |
| Glyphs | 31,058 | 65,535 | 31,072 | 65,535 |
| Unicode code points | 30,930 | 44,779 | 30,926 | 44,853 |
| Basic CJK U+4E00–U+9FFF | 20,992 | 20,992 | 20,992 | 20,992 |
| Extension A U+3400–U+4DBF | 6,592 | 6,592 | 6,592 | 6,592 |
| Extension B U+20000–U+2A6DF | 52 | 2,057 | 53 | 2,109 |
| Hiragana U+3040–U+309F | 93 | 93 | 93 | 93 |
| Katakana U+30A0–U+30FF | 96 | 96 | 96 | 96 |
| Hangul syllables U+AC00–U+D7A3 | 0 | 11,172 | 0 | 11,172 |

Sans SC covers the inspected sample `度漪角色设定紙繁體龍龜鬱齉𠮷さくらカタカナ한글中文éöπЖ`. Serif CN covers the same sample except `𠮷한글`; these switch to bundled Sans when `RoleCardSans` is configured as explicit title fallback. This makes their title styling different from surrounding Serif text. SC remains a Simplified Chinese language configuration: proper regional glyph forms depend on locale/language tagging and OpenType shaping support. Complete character coverage is not equivalent to every region using the same preferred glyph form.

Chosen raw font total: **28,624,512 bytes / 27.30 MiB**. This saves **13,427,052 bytes / 12.81 MiB** compared with two SC fonts and adds **8,100,608 bytes / 7.73 MiB** compared with two CN fonts. The hybrid retains common CJK coverage via explicit bundled Sans fallback, at the cost of a font-style change for characters missing from the Serif subset. It is not a measured IPA/APK download-size estimate. Only the two required static weights are bundled; no full family archives or custom glyph subsetting were used.

## Remaining limits and integration obligations

- Full coverage refers to the Source Han family's repertoire, not all of Unicode. Both chosen files lack inspected examples `𠀀` U+20000, `❤` U+2764, `⭐` U+2B50 and `😀` U+1F600. Some other rare characters/scripts also lie outside the repertoire.
- Without another explicitly bundled font, these unsupported characters depend on device fallback or show a missing-glyph box. This preparation therefore guarantees offline bundled fonts for the verified repertoire, not universal cross-platform Unicode consistency. Do not advertise otherwise.
- Register `RoleCardSerif` weight 700 and `RoleCardSans` weight 400 using the paths above, with explicit `RoleCardSans` fallback for Serif titles. Await font loading before first paragraph measurement, use the identical font/locale configuration for preview and PNG export, and avoid treating device fallback metrics as a stable pagination contract.
- Font metadata/coverage checks do not replace the main task's Flutter render, pagination and real-image visual verification.
