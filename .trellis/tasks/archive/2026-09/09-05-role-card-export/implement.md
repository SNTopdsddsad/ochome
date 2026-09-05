# Role-card export implementation plan

The user approved the character-sheet composition on 2026-09-05. Proceed with implementation; do not change the selected style back to the rejected framed-photo design.

1. Review the main card/continuation concept with representative user-approved artwork. Confirm output dimensions, fit policy, font and visibility defaults. Update PRD/design with the answer.
2. Verify the selected font's upstream license, payload and glyph coverage, then choose a single feature directory layout. Curate context manifests and activate the task after review.
3. Implement immutable snapshot/selection projection and deterministic document models. Test duplicate-name attributes and hidden values, including repeated headers/semantics/filenames.
4. Implement fixed-geometry text layout, complete-line pagination and shared painting. Build a main card and continuation fixtures with short/long CJK text, emoji, very long field names, empty fields and many attributes. Verify complete selected-content coverage.
5. Add bounded cover decoding and deliberate missing/corrupt/no-image behavior. Render real PNGs at the reviewed dimensions and visually inspect main cards plus continuation pages with actual artwork and no-artwork states.
6. Add preview/field selection and a guarded current-draft entry from the role editor. Verify back navigation, preserved drafts, zero repository writes and selection/render races. Keep controls accessible while export typography stays fixed.
7. Add sequential PNG-job generation and predictable temporary-file ownership. Do not deliver a job until all pages are ready; test an injected mid-job failure and stale-generation cancellation.
8. Add iOS PhotoKit batch save, macOS folder save and system sharing through injectable adapters. Pin verified dependencies, update native registration/build files/permissions, and preserve unrelated iCloud/cover-picker code.
9. Run focused model/layout/renderer/page/channel tests and whole-project analysis. Build iOS without signing and macOS where the environment permits; inspect platform behavior on an available device/simulator/desktop app. Report OS behavior that cannot be verified instead of inferring it from mocked channels.
10. Run full-scope review and the relevant existing suite once the feature is stable. Update the actual component/native export contracts in specs, prepare the scoped commit plan, and use the project's commit/archival workflow.

Validation targets:

- PNG dimensions and document geometry independent of viewport/DPR/app theme/text scale.
- All selected content represented without hidden-field leakage, silent truncation or non-advancing pagination.
- Original role/artwork data preserved; return from preview retains the editing session.
- iOS save permission requested on action, complete multi-page save results, explicit denied/error handling, quiet user cancellation.
- macOS folder cancellation/copy failure/collision handling and sandbox access; iPad share anchoring.
- Memory/resource disposal and temporary-file lifetime under page generation/replacement/share consumption.

Rollback: remove the export entry and feature module, undo its native/dependency/font additions. Existing role data, database format, backups and draft-save behavior require no migration or rollback operation.

## Execution outcome

- User-approved character sheet implemented as a standalone feature module with immutable content projection, shared measured page document/painter and fixed-size PNG encoding.
- Current-draft editor entry, per-field/per-attribute selection, page preview/zoom, progress, error/cancellation behavior and native delivery are integrated.
- Official unmodified Serif CN Bold and Sans SC Regular assets/licenses are bundled and the notices are accessible from the export page.
- Whole Flutter suite: 166 passing tests. After the final license-entry adjustment, all 11 page tests and whole-project analysis passed again. Native file helpers had 13 passing host XCTest cases.
- Real HEIC-derived PNG and multi-page fixtures, plus light/dark export-page screenshots, were visually inspected. A separate runtime-only system-font probe verified emoji glyph rendering and text clipping boundaries without redistributing Apple fonts.
- Final iOS no-signing build, final macOS no-signing build and Android debug APK build succeeded. Normal macOS signing is blocked by the existing iCloud entitlement/development-certificate requirement; this task did not remove it.
- Independent review findings (premature share-success copy, repeated long-name shaping and vertical ZWJ-name overflow) are fixed and verified. New specs and provenance are recorded.
- The user authorized local commits on 2026-09-05. The core export implementation commit is `5bfbdb6`; the complete work-commit sequence is recorded in `commit-plan.md` and task metadata. Signed Apple runtime permission/save/share acceptance is still required before release; it is not claimed by these build/test results.

### Feedback-style follow-up

The user requested replacing the unattractive default `_snack` feedback.
Shared floating-paper notices now cover four pages, preserve native closing
and semantics, and retain long/accessible messages until manual dismissal.
Seven focused regressions, a full 173-test Flutter run, analysis and actual
light/dark SnackBar screenshots passed. Native/dependency code is unchanged by
this polish; the commit plan includes it separately.
