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
- [ ] Install, enable, summon/hide, disable/re-enable, restart shell and remove.
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
- [x] Initial automated marketplace validation and security baseline passed; refresh required for 0.2.2.
- [ ] Wait for marketplace validation and maintainer approval; repository publication alone is not store listing.

Submission is permitted as a testing release with incomplete native checks disclosed;
these unchecked items remain release validation work and are not claimed complete.

Native tests also verify country filter/accepted bindings, result delegates/focus,
and Qt HTTP catalogue actions. Full user event/visual/lifecycle checks above remain open.
