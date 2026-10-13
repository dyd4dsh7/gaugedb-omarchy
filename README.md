# GaugeDB for Omarchy

<img src="preview.png" width="96" height="96" alt="GaugeDB six-square logo" />

Search Steam games, browse regional deals, save favourites and compare two games
from an Omarchy bar panel. Built for **Omarchy Quattro / Omarchy 4** and Quickshell.

**Version 0.3.0 adds public wishlist import, local price watches and native history.**
Marketplace verification for 0.3.0 is pending; 0.2.4 remains the verified snapshot until approval.
ARM UTM desktop, native input, strict QML lint and regression results are
documented in [VALIDATION.md](VALIDATION.md), including remaining limitations.

## Features

- Games search and regional deals with a searchable country dropdown (default NZ).
- Saved favourites, the last 12 recently opened games and two-game comparison.
- Prices, currencies, source countries and independently dated activity/review observations.
- Exact-request offline summaries with visible stale dates and a 30-day expiry.
- Browser actions for GaugeDB, Steam, ProtonDB, price history, price alerts and Steam wishlist.

Missing values remain unknown. Coverage is partial and prices are saved observations;
check Steam before buying. Browser alerts and wishlist actions may require sign-in.
Opening those pages does not create an alert or import private wishlist data.

## Requirements

Omarchy Quattro / Omarchy 4 with its Quickshell shell, Qt Quick Controls,
`Quickshell.Io`, Git and `xdg-open`. These are host dependencies; no separate
GaugeDB server, API key or account is required. Paste additionally requires `wl-paste` from `wl-clipboard`,
Bash, GNU coreutils (`timeout`, `head`, `base64`) and `iconv`. Public wishlist,
history and watch requests require Python 3. Desktop notifications require
`notify-send` from libnotify. Typed input continues
to work if the paste helper is unavailable. Internet access is needed for new
public results and optional artwork. Bun is needed only to run development tests.

## Install

Review the code before enabling it. Omarchy plugins run without a sandbox.

```sh
omarchy plugin add https://github.com/dyd4dsh7/gaugedb-omarchy.git --enable
```

Omarchy clones the public repository, validates its root manifest, and enables
`com.gaugedb.search` after validation. It asks before cloning and lets you choose
the bar placement. An existing plugin ID is refused rather than overwritten.
This command installs the current `main` commit; the store's verified snapshot
is listed separately. This plugin does not edit your personal Hyprland bindings.

Open the GaugeDB bar button, or summon it with:

```sh
omarchy-shell shell summon com.gaugedb.search '{}'
omarchy-shell shell hide com.gaugedb.search
```

Optional personal binding:

```ini
bind = SUPER CTRL, G, exec, omarchy-shell shell summon com.gaugedb.search '{}'
```

## Use

**First use:** open the GaugeDB bar button, choose **Store** and search for your
country, then search a game or select Deals. The country picker validates bundled
supported countries and saves your choice on this device. **Options** lets you
choose Games, Saved or Deals as the starting view for a new panel session.

| Control | Action |
| --- | --- |
| Enter | Search or activate the focused result |
| Down / Up | Navigate results; return to search from the first result |
| `/` outside a text field | Focus game search |
| F1, or `?` outside a text field | Toggle keyboard help |
| Tab / Shift+Tab | Move between controls |
| Escape | Dismiss help/options, country picker or panel |
| Ctrl+V / Shift+Insert / middle-click | Paste through the bounded helper |


Enter a title and press Enter or Search. Select a result for details. Deals uses
the selected country; changing country clears previous regional results.
**Store** opens the country dropdown with search inside it. Filter by country name
or code; Down enters the list, Up from its first row returns to search, Enter
selects, and Escape or an outside click dismisses it. Filtering alone does not
change country.

Use Save to pin a game (up to 40 favourites). Saved → Recent shows the last 12
opened games. Select + on two results and press Compare; Clear removes the
selection. Back restores the current results or saved list without another request.
Ctrl+V, Shift+Insert and middle-click paste use an isolated helper with a 4 KiB
byte cap, 64 MiB address-space cap and a one-second total deadline (forced kill
after another 200 ms). Only valid UTF-8 within the field limit is inserted.
Clipboard payloads are never loaded merely because the clipboard changes.
Right-click native paste is disabled; use these explicit paste gestures.

Tab moves through controls and Escape closes the panel. Requests time out after
12 seconds; Retry starts a new request. Replaced or cancelled replies are ignored.

## Data and privacy

The plugin calls the public GaugeDB catalogue at
`https://gaugedb.com/integrations/public-games/mcp`, and
`https://gaugedb.com/api/search?q=<appId>` for artwork and developer/type labels.
Search titles, game IDs and requested country are sent to GaugeDB. Optional
capsules load from validated HTTPS Steam CDN URLs for that exact app.
There is no background polling or Steam refresh. No game artwork is bundled.

Browser actions open fixed GaugeDB, Steam and ProtonDB URLs for validated Steam
IDs via `xdg-open`. The browser manages its own login and store preference.
The plugin does not read browser cookies or store credentials/account data.

Local favourites, recent identities, country and cached public summaries live in
`${XDG_STATE_HOME:-~/.local/state}/gaugedb-omarchy/state.json`, separate from the
installation. Only absolute XDG paths are accepted. At most 20 requests are cached;
serialized data is capped at 1,048,576 characters. Offline recovery matches the
exact query/action/country, preserves original dates and marks observations stale.
It does not fetch artwork. Cache entries older than 30 days are not reused.

The state directory is secured to mode 0700 and the state file to 0600 before
reads or writes, including existing installations. Unsafe symlink targets or
permission setup failures disable storage. Writes are asynchronous and atomic. Corrupt or unsupported state is preserved;
writes are disabled and changes stay in the session. Back up the file before repair.
Your favourites, recent games and state file should never be committed to this repo.

## Disable and remove

```sh
omarchy plugin disable com.gaugedb.search
omarchy plugin remove com.gaugedb.search
```

Removal asks for confirmation. Local saved data remains outside the plugin folder.
To delete it too, first back it up, then remove only
`${XDG_STATE_HOME:-~/.local/state}/gaugedb-omarchy/state.json`.

## Development and release checks

```sh
bun --no-env-file test
omarchy plugin validate .
OMARCHY_PATH=/path/to/omarchy bash scripts/lint-qml.sh
```

The standalone suite uses synthetic public response data and the shipped
JavaScript. It covers malformed responses, missing prices, stale cache, safe links,
country filtering, storage bounds, request cancellation, late callbacks and recovery.
Panel tests execute extracted QML JavaScript methods with a fake transport and timers;
they do not execute a QML engine or real filesystem integration.

For release validation, use [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
and [VALIDATION.md](VALIDATION.md). ARM UTM checks cover image loading, persistence,
native input and 390px history in both themes; manual mouse results are identified
as owner-reported. Fully hostile external Wayland producers and all browser
destination rendering remain separate checks.

The square preview is the GaugeDB brand mark, not a native application screenshot.

[SUBMISSION.md](SUBMISSION.md) records the marketplace issue and submission body.
See the [marketplace submission status](https://plugins.omarchy.org/plugin.html?id=com.gaugedb.search).
Repository publication and issue submission do not mean store approval.
Current checks and their limits are recorded in [VALIDATION.md](VALIDATION.md).

For Linux native smoke checks with an existing Wayland session:

```sh
GAUGEDB_WAYLAND_RUNTIME="$XDG_RUNTIME_DIR" bash scripts/native-smoke.sh
```

Set `OMARCHY_PATH` to the official checkout first. The runner needs Bash, coreutils,
Git/Qt/Quickshell host dependencies and jq. It copies runtime files to an isolated
temporary config/state path and removes those test files afterward; no user state
is changed. Its live network case reads public catalogue data. It does not open
browser pages, create alerts or authenticate accounts.

Clipboard regression checks (Linux):

```sh
bash tests/clipboard-helper.test.sh
bash scripts/test-clipboard-input.sh
```

The native input test needs a C++ compiler, pkg-config and Qt 6 development/test
libraries. It uses the offscreen platform and a controlled clipboard provider,
so it does not read or replace the desktop clipboard. The helper tests use a
private fake provider, not real clipboard content.

## Wishlist, watches and history

Version 0.3.0 adds **Options**, a saved starting view, F1 / ? help,
public Steam wishlist import, local price watches and a native price-history view.

Public wishlist import reads Valve's public wishlist endpoint for the SteamID64
entered explicitly. It keeps up to 40 IDs separate from favourites. The ID itself
is not persisted; private/unavailable responses preserve existing saved games.

Local watches are limited to ten exact game/country/currency combinations. Start a
watch from a fresh regional detail price. Background checks are off by default;
when enabled, they run every 30 minutes with sequential bounded requests. Newer
lower observations trigger a desktop notification. Stale, foreign-country and
changed-currency prices do not trigger it. Disable background watches to stop
polling. Removing the plugin ends its running services.

The native chart reads the deployed public price-history endpoint.
It shows saved points, excludes other currencies from the chosen series, and
labels source country and legacy timestamps. It does not manufacture gaps or
claim live Steam availability. If the endpoint is unavailable, the web history action remains the fallback.

Helper dependencies: Python 3 and GNU coreutils; desktop notifications need
`notify-send` (libnotify). Public reads are limited to 256 KiB and a 20-second
process deadline. No GaugeDB account or Steam cookie is used.

## Later work

Authenticated price-alert management and GaugeDB account sync require a dedicated
scoped authorization API and remain future work. Browser account actions retain
their existing sign-in flow.

## License and assets

Plugin code and bundled GaugeDB SVG branding are provided under the [MIT license](LICENSE).
Steam game images are fetched at runtime and belong to their respective owners;
they are not covered by this repository's license. This repository contains only
the plugin, with independent Git history; the GaugeDB application remains private.

References: [Omarchy development](https://plugins.omarchy.org/develop.html),
[publishing](https://plugins.omarchy.org/publish.html) and
[the official shell contract](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md).
