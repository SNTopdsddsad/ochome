# User-directed character-sheet revision

The user rejected the mat-and-caption photo proof with “可真丑呀”, then selected
“同人设定纸：信息分区清楚，像精心排过的设卡”. This is the current design direction.

The revised composition uses a strong name heading, a dominant artwork column,
a narrow basic-information column and bottom setting/custom-attribute regions.
Warm paper and ink-blue typography surround a shared deep-blue artwork/data
area. The photograph is intact; no cropping, watermark removal or generated
character facts were used.

The review offers two states of the same template:

- `设定纸分区`: empty rules/dashes show future information placement. They are
  explicitly labeled placeholders, not claims about 度漪.
- `仅现有资料`: only the supplied name and photo appear; empty regions collapse
  and the artwork expands beside a narrow vertical name rail.

The proof was inspected at roughly 736 and 320 CSS-pixel host widths and the
view switch was exercised. Image remains contain-fit; sections, labels and
footer fit. The actual-data state removes the placeholder fields rather than
showing them in the export. Host viewport override was reset after inspection.
The optional paper-tone Tweak control remains a design comparison.

The actual preview is `role-character-sheet.html` in the task's conversation
visualization directory. `setting-sheet-template.html` in this directory uses
an explicit image marker; no user photo bytes/base64 enter the repository.
The generated preview is below 1 MB and has no network/image upload calls.

This remains a proposed visual layout. No final user acceptance, Flutter export
implementation, native save or sharing operation is implied by this proof.
