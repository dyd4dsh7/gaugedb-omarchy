# Marketplace release checks

## Completed locally

- Plugin-only export with independent Git history; no GaugeDB backend or account data.
- Root manifest, MIT license, install/removal/dependency/privacy documentation.
- Standalone JavaScript model, storage and panel-method tests.

## Remaining on a real Omarchy Quattro host

- [x] Official manifest validator passes locally.
- [x] Headless Wayland/Quickshell component loading attempted; see VALIDATION.md.
- [ ] Resolve/review qmllint warnings and validate on the actual Omarchy host.
- [ ] Install, enable, summon/hide, disable/re-enable, restart shell and remove.
- [ ] Search, deals, details and comparison; missing/partial data and long titles.
- [ ] Country dropdown search, no matches, arrows, Enter, Escape, outside click and focus return.
- [ ] Favourites/recent, Back after removal, persisted country and restart persistence.
- [ ] Offline cache, expiry, timeout/Retry, cancelled/rapid requests, HTTP 429 and optional artwork failure.
- [ ] Storage creation, failed writes and corrupt-file preservation using a temporary test state directory.
- [ ] Desktop and 390px output in both themes, scrolling, keyboard focus, accessibility and inherited motion.
- [ ] Confirm all browser destinations open correctly; review public Qt network access and image loading.
- [ ] Capture an optional real native `preview.png` (no personal state or private account data).

## Submission

- [x] Rechecked current catalogue, existing submission search and public repository files.
- [ ] Complete native checks above and record host/version/results.
- [x] Owner authorized public MIT plugin publication and marketplace submission.
- [ ] Marketplace issue submission/validation; track the linked issue in SUBMISSION.md.
- [ ] Wait for marketplace validation and maintainer approval; repository publication alone is not store listing.

Submission is permitted as a testing release with incomplete native checks disclosed;
these unchecked items remain release validation work and are not claimed complete.
