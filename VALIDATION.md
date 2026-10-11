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

### QML warning fixes — version 0.2.1

All production QML and the native smoke harness pass full `qmllint` with zero
warnings and exit status 0, using the real Qt, Quickshell and Omarchy imports.
The repeatable runner uses `--max-warnings 0` and machine-readable diagnostics.
No warning category is disabled. The previous 131 warnings were resolved with
bound component contexts, typed Loader/result-delegate interfaces, an explicitly
qualified host UI types, block-scoped JavaScript declarations and dynamic adapters for the host's QtObject role groups.
The role adapters retain the live Omarchy objects; the native test confirms their values.

The 37 JavaScript tests / 169 assertions still pass. The extracted-method VM
strips only QML's `as GameResult` type assertion syntax; the assertion and delegate
interface are additionally exercised by the real QML engine below.

### Actual QML-engine checks

`scripts/native-smoke.sh` copies only public runtime files into a temporary
Quickshell configuration and uses isolated temporary state. Four fresh processes
under headless Weston pass:

- Native delegate creation, required modelData/index, focus restoration, valid/invalid country selection, country filter/empty bindings and the accepted handler.
- Atomic state writes for a favourite and country, verified by reading the actual file.
- A fresh process restores that favourite and country from disk.
- A corrupt file disables writes and stays byte-for-byte unchanged after an attempted favourite change.
- Actual Qt HTTP requests for public details, search, NZ deals and comparison return decoded game data without offline recovery.

The runner fails on assertion errors, missing pass markers, runtime JavaScript
errors, missing required properties and plugin binding errors. Expected official
shell warnings from missing Hyprland, import scanning, inherited deprecations and
headless teardown remain; these are not a clean full-shell runtime claim.

## Still unverified

Actual Hyprland install/enable/summon/hide/disable/remove lifecycle, shell restart,
keyboard and accessibility, country dropdown interaction, desktop and 390px
output in both themes, Steam CDN image loading, browser handoffs and real permission-denied filesystem
failures. Native state creation, persistence across processes and corrupt-file
preservation are now verified; shell restart is still distinct.

The JavaScript tests cover many corresponding failure modes using mocks; they do
not replace these native checks. No mock screenshot is offered as a native preview.
The plugin is submitted for maintainer review as a testing release with these
limitations disclosed. Marketplace approval is a separate outcome.
