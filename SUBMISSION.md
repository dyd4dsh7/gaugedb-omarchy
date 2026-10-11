# Marketplace submission

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
Version 0.2.0 is a testing release. 37 regression tests and the official manifest
validator pass. Live public search/details/deals/comparison decode with the client.
Headless Wayland/Quickshell component loading succeeds with host-environment
warnings; qmllint reports scope/dynamic-property warnings, so no clean lint pass
is claimed. Full Hyprland desktop interaction, themes, restart persistence, Qt
networking and browser handoffs remain unverified. Please review with these
limitations in mind; VALIDATION.md records the environment and results. No preview
assets are bundled. This is a request for listing review, not a claim of approval.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
