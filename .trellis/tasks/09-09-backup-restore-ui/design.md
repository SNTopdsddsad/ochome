# Design

Approved source: design/backup-restore/plan.md. Keep coordinator/storage protocol unchanged. Home owns reload and action dispatch, detail observes coordinator job for its snapshot, shared compact panel displays actionable states. Completion feedback only for observed transitions. Keep prepare/review/activate separate and guard navigation while activating. Use existing Zaidang confirmation and snackbar widgets.
