# Marketplace release checks

## Completed locally

- Plugin-only export with independent Git history; no GaugeDB backend or account data.
- Root manifest, MIT license, install/removal/dependency/privacy documentation.
- Standalone JavaScript model, storage and panel-method tests.

## Required on an Omarchy Quattro host

- [ ] Run `omarchy plugin validate .` and `qmllint` with the shell import path.
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

- [ ] Recheck plugin ID availability and public repository files at the exact release commit.
- [ ] Complete native checks above and record host/version/results.
- [ ] Confirm submission ownership checklist and submit the prepared issue.
- [ ] Wait for marketplace validation and maintainer approval; repository publication alone is not store listing.
