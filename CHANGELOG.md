# Changelog

## 0.4.5 — Unreleased

- Pause watch and wishlist-name batches together for 60 seconds after HTTP 429, then resume unfinished items without counting rate-limited requests as failures.
- Report updated, unchanged, unavailable and failed watch checks separately. Record the last check time while retaining saved prices when a request fails or returns no usable quote.
- Keep wishlist names loading while browsing within the panel; cancel pending lookups when closing the panel or changing store country.
- Retain queued work while a cancelled helper process shuts down, so replacement batches do not lose items.
- Keep notification delivery errors visible when later watch checks finish; clear them after a successful delivery.

The implementation is committed at `11464fe6f31876bd3cfe6eba8f98c228d4883aa3`.
Version 0.4.5 is prepared locally for review; no tag, release or marketplace update
has been published. Validation and remaining release gates are recorded in
[VALIDATION.md](VALIDATION.md) and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## 0.4.0

- Manage exact-country watches in Saved, with previous/latest/starting prices, observation and check dates, manual-check status, opening and removal.
- Resolve missing public wishlist names sequentially, retain them across restart/reimport, and cancel pending lookups when closing the panel.
- Label history price/date ranges and lowest/latest values; expose exact observations in an expandable accessible list.
- Correct the recorded 0.3.1 marketplace approval/publication and separate historical checks from current release gates.
- Add official manifest validation, strict QML lint and seven native smoke modes to Linux CI alongside clipboard/input and notification privacy regressions.

## 0.3.1

- Keep watched game names, prices and countries out of notification arguments by using a generic notification.
- Send public request inputs over bounded stdin so watched app IDs and entered SteamID64 values are not exposed through helper command lines.

## 0.3.0

- Import a public Steam wishlist into a separate Saved tab; retain up to 40 game IDs without saving the SteamID64.
- Add up to ten local price watches, optional 30-minute background checks and deduplicated desktop notifications for newer lower saved prices.
- Show regional price-history observations in the panel, with explicit country, currency and legacy timing labels; retain the web fallback.
- Choose Games, Saved or Deals as the starting view and open keyboard help with F1.
- Fix Tab / Shift+Tab navigation, watch request content negotiation, history chart repaint and narrow metric column sizing.

Public requests use fixed origins, bounded responses and process deadlines. Background checks are off by default. Prices are saved observations; check Steam before buying.

Validation includes ARM Omarchy UTM, 390px history in both themes, owner-reported mouse checks, native clipboard/input and model/helper regression tests. Wishlist testing uses controlled fixtures; full hostile external Wayland producers and all browser destination rendering remain outside the verified coverage. See VALIDATION.md.
