# Implementation plan (after design review)

The user approved the v2 preview on 2026-09-05 (“这个可以”). The design gate is satisfied; implement and validate the approved direction.

1. Confirm the final visual direction/copy from `design.md`; update the PRD and design together if scope changes.
2. Read frontend theming, component and quality specs. Curate the existing context manifests, then start the task after review.
3. Add a small shared confirmation dialog/helper using existing semantic tokens and stock Flutter primitives. Follow the v2 creator-notebook direction: softer shape, compact icon, target embedded in conversational body text, explicit consequence, ink destructive actions and dismiss-to-false behavior.
4. Replace the three confirmation call sites. Preserve mounted/busy/stale-callback guards, draft deletion timing, history restoration behavior, and iCloud inspection/cleanup/commit flow.
5. Apply only compatible surface/shape defaults to the history content viewer. Preserve its selectable and scrollable description.
6. Validate the UI at 320/390 logical pixel mobile widths and desktop, in both themes, with long attribute names and increased text scale. Check layout overflow, essential text contrast, touch targets, focus and non-confirm dismissals.
7. Run targeted existing tests plus meaningful shared-dialog coverage for cancel, explicit confirmation, Escape/back/barrier dismissal, dark action contrast, text scale and long names. Extend behavior assertions only where the migration changes a contract; do not test every decorative gap.
8. Run `dart format` on changed Dart files, `flutter analyze`, and appropriate dialog/history/custom-attribute/backup tests available in the repository. If no suitable history/backup UI tests exist, add focused tests using established dependency injection; no real cloud writes for visual verification.
9. Review the diff, update the theming/component specs with the approved contract and correct the stale purple-seed statement. Follow Trellis finish/commit workflow for the implementation task.

Rollback: restore the three old dialog call sites and remove the helper/theme addition. No schema, persistence, cloud format or asset migration is involved.

## Execution result

- Design reviewed and approved; task activated.
- Reusable Widget/helper implemented and all three confirmation sites migrated.
- Compatible shared dialog theme added; history reading behavior preserved.
- Full-scope independent check completed without business-code findings. Added regression coverage for repeated callbacks, focus traversal and exceptionally short windows.
- Full suite passed (124 tests); the subsequent 3 additional shared-dialog regressions also passed as part of the 16-test component suite.
- Whole-project `flutter analyze`, formatting check for all eight changed Dart files, `git diff --check` and task context validation passed.
- Real Flutter screenshots inspected in light/dark, cloud overwrite and 2× text. Standard layouts retain visible actions; large text scrolls within the content region. A temporary local Chinese font was used for readable screenshot QA only, with no font added to the app.
- Frontend specs updated for the reusable contract, OC visual direction, dismissal/focus semantics and actual theme state.
- The user approved the Phase 3.4 commit plan and task archival on 2026-09-05 (“commit 然后归档”). Local application/test commits are `6550af6` / `0dbf03a`; specification, task archival and journal records follow them. No remote push is included.
