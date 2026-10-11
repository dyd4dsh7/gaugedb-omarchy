# Release validation — 12 October 2026

## Verified

- 37 standalone tests / 169 assertions pass (client, storage and extracted panel methods).
- Official Omarchy Quattro manifest validator passes.
- Live public search, details, regional deals and comparison return HTTP 200 and decode with the shipped Model.js.
- Fresh public plugin-only repository; GaugeDB application repository remains private.
- MIT license, root manifest, install/removal instructions and external dependencies checked.
- No existing GaugeDB submission or `com.gaugedb.search` entry in the current marketplace catalogue at review time.
- Scoped credential/path/symlink disclosure checks found no matches. This is not a comprehensive security audit.

## Native loading attempt

Disposable Linux x86_64 container under emulation, with Arch packages
`quickshell 0.3.2-1`, `qt6-declarative 6.12.0-1`, Qt Wayland and Weston headless.
Official Omarchy Quattro shell source:
`e71a816e9032f040225e086c7256f73e8080ae45`.
The public plugin was mounted read-only and state paths were disposable.

Qt qmllint resolved Qt/Quickshell/Omarchy imports and reported no syntax/import
errors. It exited nonzero with 131 warnings: 83 unqualified accesses, 47 missing
properties (including dynamic Loader items and theme objects), and one renamed-type
warning. This is not a clean lint pass; warnings remain for native-host review.

Quickshell under headless Weston reported `Configuration Loaded` without the
PanelWindow backend failure seen in the offscreen-only attempt. It stayed running
until the 15-second test timeout. Warnings included Quickshell's import scanner,
missing Hyprland signature/`hyprctl`, inherited window deprecations and software
rendering infrastructure. No full Omarchy desktop or actual panel interaction
was exercised. This is a limited component-loading smoke check, not visual QA.

## Still unverified

Actual Hyprland install/enable/summon/hide/disable/remove lifecycle, shell restart,
keyboard and accessibility, country dropdown interaction, desktop and 390px
output in both themes, real Qt HTTP/image loading, browser handoffs, storage
restart persistence and real filesystem failure/recovery paths.

The JavaScript tests cover many corresponding failure modes using mocks; they do
not replace these native checks. No mock screenshot is offered as a native preview.
The plugin is submitted for maintainer review as a testing release with these
limitations disclosed. Marketplace approval is a separate outcome.
