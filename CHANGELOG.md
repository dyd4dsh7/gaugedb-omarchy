# Changelog

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
