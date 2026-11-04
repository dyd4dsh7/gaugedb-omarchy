# Marketplace release checks

## Prepared patch: 0.4.5 — unpublished

- [x] Manifest, development package and HTTP user agent identify version 0.4.5.
- [x] Release notes describe cooldown, queue recovery, watch outcomes and wishlist navigation changes.
- [x] After the local version bump, 63 Bun tests / 323 assertions and 24 Python tests pass; JSON/version consistency and git diff --check pass.
- [x] Implementation commit `11464fe6f31876bd3cfe6eba8f98c228d4883aa3` passed [Linux CI](https://github.com/dyd4dsh7/gaugedb-omarchy/actions/runs/41918178906): 63 Bun tests / 323 assertions, 24 Python tests, strict zero-warning QML lint, clipboard/input and notification privacy checks, and all 13 native smoke modes.
- [x] Twelve local native QML captures cover watch results, watch cooldown and wishlist cooldown at desktop and 390px in light/dark palettes. Headless Sway ran in emulated x86 Linux; UTM was not used.
- [ ] Commit the reviewed 0.4.5 preparation and pass CI at that exact candidate SHA. The implementation run above predates this version bump.
- [ ] Obtain separate authorization before tagging, publishing a release or submitting a marketplace update. No 0.4.5 publication is claimed.

## Published patch: 0.4.4

- [x] Local state reads are bounded before QML; FileView is writer-only.
- [x] Unicode compatibility and corrupt/oversized-file preservation remain covered.
- [x] Local 53 Bun tests / 255 assertions and 24 Python tests passed for that patch.
- [x] [Exact-commit Linux CI](https://github.com/dyd4dsh7/gaugedb-omarchy/actions/runs/39730215106), including 13 native modes, passed at `176ba87dd1867451331a77ef21fe3e899d030a08`.
- [x] That exact snapshot was approved, verified and published through [completed issue #12568](https://github.com/omacom/omarchy-plugin-marketplace/issues/12568).

The UTM VM remains stopped. No new ARM/Hyprland desktop validation is claimed.

## Previous patch: 0.4.3

- [x] Capsule bytes and JPEG dimensions are bounded before QML; Qt receives data URLs only.
- [x] All five redirect statuses close without reading response bodies.
- [x] Local 51 Bun tests / 247 assertions and 18 Python tests pass.
- [x] Live four-tool MCP reads and bounded capsule loading pass.
- [ ] Exact-commit Linux CI and marketplace review/publication: see issue #11915.
- [ ] New UTM visual checks: not run; VM remains stopped at the owner's request.

## Previous patch: 0.4.2

- [x] All four core MCP tools use bounded transport before response JSON decoding or shell delivery.
- [x] Local 51 Bun tests / 244 assertions and 13 Python tests pass, including oversized HTTP streams and delayed replacement.
- [x] Live public search/details/deals/comparison pass through the shipped helper and model.
- [ ] Exact-commit Linux CI and maintainer review/publication: see issue #11915.
- [ ] New UTM visual checks: not run; VM remains stopped at the owner's request.

## Previous patch: 0.4.1

- [x] Artwork metadata crosses the bounded public helper before reaching QML.
- [x] Local 50 Bun tests / 236 assertions and ten Python tests pass.
- [ ] Exact-commit Linux CI and maintainer review/publication: see issue #11915.
- [ ] New UTM visual checks: not run; VM remains stopped at the owner's request.

## Previous candidate: 0.4.0

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

The supported single preview image is the GaugeDB logo. The earlier custom
header-logo/tag [PR #11100](https://github.com/omacom/omarchy-plugin-marketplace/pull/11100)
was closed unmerged and is not a release gate. Approval, merge, plugin snapshot
verification and live publication are distinct.
