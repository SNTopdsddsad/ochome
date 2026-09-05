# 角色自定义属性

## Goal

Let each OC owner record character-specific information as named text attributes without changing the existing fixed basic fields.

## Confirmed Scope

The user confirmed the following behavior during the 2026-09-05 discussion: fixed fields remain fixed; each OC owns its attributes; attributes have a user-defined name and content; editing happens inline; attributes support addition, editing, deletion and ordering; everything saves with the role.

The current role editor contains “基本信息” and “设定”. The new section sits between them. Existing characters start with no custom attributes.

## Requirements

- **R1 — Ownership:** Custom attributes belong only to their OC. Editing one character does not add or change attributes on another. Existing basic fields and their required/optional rules stay as they are.
- **R2 — Data entry:** Each attribute has a required name and optional free-text content. Whitespace-only names fail validation. Content supports multiple lines, Unicode and an empty value. There are no numeric/date/choice field types in this version.
- **R3 — Placement and empty state:** Between “基本信息” and “设定”, show only an “添加自定义属性” action when the list is empty. Once the user adds an entry, display a “自定义属性” card containing the entries and an add action.
- **R4 — Inline management:** Adding inserts an editable entry in the page. Users can change the name and content, remove an entry, and reorder entries. Deleting the last entry returns to the empty state. Reordering keeps each name paired with its content.
- **R5 — Save boundary:** Attribute changes remain in the current form until the existing role save succeeds. Save attributes together with the fixed fields and description. Validation errors or a save failure preserve the draft for correction/retry. Reopening a saved role restores the names, content and order.
- **R6 — Data preservation:** Existing roles retain their fixed fields, description, description history and cover when upgraded. Restoring description history preserves saved custom attributes and any attribute draft currently open in the role editor. Custom attributes participate in existing database backup/restore; an older supported backup opens with an empty attribute list.
- **R7 — Presentation:** Use the existing paper card, spacing and light/dark theme conventions. Controls have clear accessible labels. Adding, editing and reordering work in the existing scrolling form on a phone.

## Acceptance Criteria

- [x] **AC1 (R1, R3):** A new or pre-feature role shows fixed fields, the lightweight add action, then “设定”; no empty custom-attribute card is present.
- [x] **AC2 (R2–R4):** Add two attributes inline, including “魔法属性 / 冰” and a multiline value. The custom card appears at the agreed position. Adding does not open a separate editor.
- [x] **AC3 (R2, R5):** A missing/whitespace-only attribute name blocks role save with a field error. A named attribute with empty content saves successfully.
- [x] **AC4 (R4, R5):** Rename, edit, reorder and delete entries; save and reopen. The remaining entries retain exactly the intended name/content pairing and order. Removing all entries restores the add-only state.
- [x] **AC5 (R1, R5):** Editing role A's attributes leaves role B untouched. Leaving the form without saving does not persist attribute changes. Failed saves retain the attribute draft.
- [x] **AC6 (R6):** Upgrade an existing schema-6 database; fixed data and description history remain, and attributes are empty. Existing supported older migration paths still work.
- [x] **AC7 (R6):** Restore a description revision on a role with attributes; only the description/history changes. Returning to the editor preserves unsaved attribute edits.
- [x] **AC8 (R6):** Backup and restore a role with multiple attributes, including multiline/empty content and a custom order. Reopened data matches. A supported older backup still restores and migrates.
- [x] **AC9 (R7):** Phone-sized light/dark layouts have no overflow; keyboard entry and sorting remain usable; add/delete/reorder controls are distinguishable through accessible labels.

## Out of Scope

- Editing, hiding, deleting or reordering the fixed basic fields.
- Shared attribute definitions, cross-character copying, templates, groups, typed values, filtering and calculations.
- A separate custom-attribute revision history or changes to role-list presentation.

## Delivery Status

The user approved implementation with “开始” on 2026-09-05 and approved the work-commit plan after all 110 tests passed. All acceptance criteria are verified. The task remains open for the project's finish-work archival step; implementation and verification details are recorded alongside this PRD.
