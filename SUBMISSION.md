# Marketplace submissions

The original submission below is historical. Version 0.3.1 was approved and
published at `00eadbc20bc474ae473ff19730047f585cbb1bf1` via
https://github.com/omacom/omarchy-plugin-marketplace/issues/11307.
Version 0.4.0 uses a new exact-commit update request after its release checks; the release notes and update issue record the final SHA, CI and submission outcome.
The original maintainer notes describe the older implementation, before opt-in
background watches and bundled branding were added; see README.md for current
behaviour and dependencies.

---

# Marketplace submission

Issue: https://github.com/omacom/omarchy-plugin-marketplace/issues/11087

Title: `[Plugin]: GaugeDB`

The owner authorized submission on 12 October 2026. This testing release is
submitted with incomplete native validation disclosed; see VALIDATION.md.
Use the body below with the [official submission form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).

---

### Repository URL

https://github.com/dyd4dsh7/gaugedb-omarchy

### Category

Widgets

### Tags

bar, games, quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

GaugeDB is an Omarchy Quattro bar widget for public saved Steam game observations,
regional deals, local favourites/recent games, comparison and offline summaries.
It uses the host's Quickshell/Qt controls and xdg-open. No API credentials,
background polling or private account sync. Local state is outside the plugin
installation and existing user bindings are not edited. Code and bundled GaugeDB
branding are MIT licensed; game artwork is loaded at runtime from Steam CDN.
Version 0.2.2 is a testing release. All QML passes full qmllint with zero warnings
using real Qt/Quickshell/Omarchy imports; no warning category is suppressed.
37 JavaScript tests / 169 assertions pass. Native headless tests verify bound
result delegates, focus restoration, country filtering/acceptance, actual state
writes, fresh-process country/favourite restoration and corrupt-file preservation.
Public details/search/deals/comparison also pass through Qt's actual HTTP client.
The maintainer-reported local-state permissions issue is fixed: setup secures
the directory/file to 0700/0600 before FileView access. Native tests under umask
022 verify actual modes, repair old 0755/0644 modes without data loss and reject
symlinked state without modifying its target.
Full Hyprland lifecycle, desktop themes/layout, actual keyboard/mouse events,
screen-reader behavior, game artwork/browser handoffs and permission-denied writes
still need native desktop review. VALIDATION.md records the environment and limits.
No preview assets are bundled. This is a request for listing review, not approval.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
