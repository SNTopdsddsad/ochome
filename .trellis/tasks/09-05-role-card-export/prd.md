# 角色卡导出

## Goal

Let OC creators export an attractive, locally generated set of character-card images that they want to share. This is the user's highest-priority current feature. Build one polished template and a complete preview-to-export flow.

## Requirements

- User-selected direction (2026-09-05): “晒崽分享：立绘为主，固定比例主卡，长内容接续页”. The main card emphasizes artwork; long selected content continues onto matching pages.
- First release has one template, consistent with the SiYuan product brief. Template visuals are independent of the application theme palette.
- The user rejected the actual-photo cold-mat/bottom-caption proof (“可真丑呀”) and explicitly selected **同人设定纸：信息分区清楚，像精心排过的设卡**. Build a character-sheet composition with artwork, basic information and setting sections, not a framed poster plus repeated caption.
- Use existing role data: name, sex, age, birthday, race, occupation, description, cover and ordered custom attributes. No invented role fields or additional database requirements for template decoration.
- Let the user explicitly control visible fields, including custom attributes and description. Omitted structured fields must stay absent from all app-generated page text, semantics and filenames/metadata. Artwork pixels are preserved; explain that hiding fields does not remove text already present in the original image.
- Show a preview of every output page and the final page count before exporting. Selected text must not silently disappear, be replaced by ellipses, or shrink indefinitely to fit.
- Keep output resolution and card appearance deterministic across device pixel ratios, screen sizes, app dark mode and accessibility text scale. The surrounding UI must remain accessible.
- Render entirely on device. Provide PNG output, a save destination and the system share flow appropriate to the platform. iOS is the first target; retain a practical macOS development/verification path.
- Include a small “崽档” brand watermark in the corner, keeping the role artwork prominent.
- Preserve original role data and source artwork. Export UI choices must not overwrite role fields. Resolve the saved-versus-unsaved entry boundary explicitly before implementation.
- Handle absent/corrupt images, long names, many attributes, cancelled sharing/saving, denied save access and rendering failures without reporting false success or producing a silently incomplete set.
- Product has no AI content features; do not generate character illustrations or marketing artwork for this task. Layout mockups may use clearly marked image placeholders until a suitable reference is provided.
- Follow-up UX requirement: the user found the default `_snack` feedback unattractive. Use a reusable floating paper-style SnackBar for export, save and backup feedback, consistent with the approved app tokens and OC tone.

## Acceptance Criteria

- [x] Read the relevant SiYuan brief, research notes and roadmap.
- [x] Record the user's priority and chosen main-card/continuation-page approach.
- [x] Review the first template composition and export flow with the user.
- [x] Define fields, output dimensions, pagination, image treatment, defaults and destination behavior.
- [x] Implement a reusable render/layout pipeline and preview UI with identical visible content.
- [x] Verify hidden structured data is excluded from every page and filename, and selected text paginates completely.
- [x] Verify real PNG output, delivery contracts/native file helpers and affected platform builds.
- [x] Run appropriate analysis, focused tests and visual validation.
- [ ] Release acceptance: verify live Photos permission/album import and real share targets on signed Apple builds. This is not established by host tests or no-signing builds.

## Notes

- The user's request to start this next project task authorizes its creation. This is a Trellis project task, not a separate Codex task.
- The user approved the character-sheet design on 2026-09-05 (“这个我喜欢！ 要怎么实现这个模版导出”). Continue into implementation of this approved template and the previously described export flow.
- Source notes and technical research are recorded in `research/`.
- Current constraints: only one stored cover per role, no export renderer or image sharing dependency yet.
- The user provided `IMG_0031.HEIC` for visual sampling and confirmed the name “度漪”. No identity/description was provided; do not invent it. The sample is a portrait poster photo with existing text and watermarks; retain the whole image for the layout review.
- Distinguish the section-location mock (empty placeholder rules for discussion) from actual output, which omits empty fields and adapts the composition to the provided content. The current sparse-data preview only uses the confirmed name and supplied artwork.
- Implementation is complete and locally validated; see `verification.md`. The user authorized local commits on 2026-09-05. The task remains unarchived, with signed-device acceptance explicitly recorded before release.
