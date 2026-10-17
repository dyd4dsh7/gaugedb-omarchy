# Marketplace release checks

## Current release: 0.4.0

- [x] Public plugin-only source; MIT licensing and fixed-origin credential-free reads retained.
- [x] JavaScript regressions and six Python helper boundary tests pass locally.
- [x] Official pinned Omarchy manifest validator passes locally.
- [x] Strict zero-warning QML lint and full Linux release checks pass at candidate `11b7ef5`; the final release commit repeats these CI gates.
- [ ] VM desktop/390px light/dark visual inspection: blocked by unavailable VM checkpoint and host disk space; restoration stopped at the owner's request. Linux native CI is separate evidence.
- [ ] Confirm final commit CI and marketplace submission from the GitHub release/update issue; these external outcomes are recorded there with their exact SHA.

## Previously verified evidence

Version 0.3.1 at `00eadbc20bc474ae473ff19730047f585cbb1bf1` was approved and
published via [#11307](https://github.com/omacom/omarchy-plugin-marketplace/issues/11307).
Its focused notification privacy test, full seven-mode ARM native smoke rerun,
QML lint, clipboard boundaries and Qt input checks passed. Earlier 0.3.0 desktop
checks covered install/enable/summon/hide/disable/re-enable, restart, removal and
reinstall with saved-state preservation, light/dark layouts, 390px history and
keyboard input. The owner reported the three manual mouse checks passed.
These are historical results, not a pass for changed 0.4.0 code.

## Remaining coverage limits

- Full screen-reader behaviour and inherited motion preferences.
- Real permission-denied writes and every browser destination's rendered page.
- A fully hostile external Wayland clipboard producer (controlled retrieval,
  streaming and native input probes are the existing focused coverage).
- Real public-profile wishlist testing is intentionally replaced by owner-approved
  controlled fixtures; no account credentials are used.

The marketplace header logo/tag change is tracked separately in PR #11100.
Approval, merge, plugin snapshot verification and live publication are distinct.
