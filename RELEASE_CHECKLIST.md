# Marketplace release checks

## Completed locally

- Plugin-only export with independent Git history; no GaugeDB backend or account data.
- Root manifest, MIT license, install/removal/dependency/privacy documentation.
- Standalone JavaScript model, storage and panel-method tests.

## Remaining on a real Omarchy Quattro host

- [x] Official manifest validator passes locally.
- [x] Headless Wayland/Quickshell component loading attempted; see VALIDATION.md.
- [x] All QML passes full qmllint with zero warnings using real host imports.
- [ ] Validate the complete shell lifecycle on the actual Omarchy desktop.
- [x] Install, enable, summon/hide, disable/re-enable, restart shell, remove and exact-snapshot reinstall in ARM UTM; saved state preserved.
- [ ] Search, deals, details and comparison; missing/partial data and long titles.
- [ ] Country dropdown search, no matches, arrows, Enter, Escape, outside click and focus return.
- [ ] Favourites/recent, Back after removal, persisted country and restart persistence.
- [ ] Offline cache, expiry, timeout/Retry, cancelled/rapid requests, HTTP 429 and optional artwork failure.
- [x] Native temporary state creation, actual writes, fresh-process restoration and corrupt-file preservation.
- [ ] Real permission-denied writes and full shell restart.
- [ ] Desktop and 390px output in both themes, scrolling, keyboard focus, accessibility and inherited motion.
- [ ] Confirm all browser destinations open correctly; review public Qt network access and image loading.
- [ ] Capture an optional real native `preview.png` (no personal state or private account data).

## Submission

- [x] Rechecked current catalogue, existing submission search and public repository files.
- [ ] Complete native checks above and record host/version/results.
- [x] Owner authorized public MIT plugin publication and marketplace submission.
- [x] Marketplace issue submitted: [#11087](https://github.com/omacom/omarchy-plugin-marketplace/issues/11087).
- [x] Version 0.2.4 compatibility and security baseline passed at `0c6ce326582dc26b408cc1356bbb7424f1eaa0a1`.
- [x] Version 0.2.4 approved and published via [update #11099](https://github.com/omacom/omarchy-plugin-marketplace/issues/11099). Subsequent code changes need their own exact-commit verification.

Submission is permitted as a testing release with incomplete native checks disclosed;
these unchecked items remain release validation work and are not claimed complete.

Native tests also verify country filter/accepted bindings, result delegates/focus,
and Qt HTTP catalogue actions. Full user event/visual/lifecycle checks above remain open.
