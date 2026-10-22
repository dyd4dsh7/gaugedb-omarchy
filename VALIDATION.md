# Validation record

## Local state read fix — 22 October 2026

Version 0.4.4 replaces the startup FileView read with scripts/state-read.py. The
helper opens the directory and state file with no-follow descriptors, rejects
nonregular files, and reads at most 4194305 bytes even if the file grows after
its metadata check. Oversize, invalid UTF-8 or more than 1048576 UTF-16 units
fail without emitting content to QML. The 4 MiB raw transport budget preserves
valid existing Unicode files whose UTF-8 encoding exceeds 1 MiB; Store.read
retains the existing 1048576-unit schema limit.

FileView is writer-only with preload and watching disabled. It has no text/data/
reload calls or load handlers, and gets a path only after bounded reading and
model validation succeed. Existing atomic writes, 0700/0600 repair, and corrupt
file preservation remain. A rejected read completes initialization with writes
disabled; existing disk data and current session state are kept.

Local checks pass: 53 Bun tests / 255 assertions, 18 public-fetch Python tests
and six state-read Python tests. Regressions cover sparse oversized files with
empty helper output, bounded reads from growing streams, descriptor replacement,
UTF-8/UTF-16 budgets, short reads, symlinks and FIFOs. Native CI adds four modes
for oversized-file preservation, large Unicode restore/save, file-symlink canaries
and FIFO rejection, alongside the nine existing modes. Exact-commit CI results
are recorded on the release and its linked update request. Version 0.4.3 at
63985ccbed36329b17d2d53a720fbd449e5ac79d was verified and published through
completed issue #11915; that approval does not cover 0.4.4. The UTM VM remains
stopped; no new
desktop visual pass is claimed.

## Capsule and redirect transport fix — 22 October 2026

Version 0.4.3 closes two follow-up response paths found during the owner-requested
review. The existing presentation helper now fetches an exact-app Steam capsule,
reads at most 131073 bytes and rejects images above 131072 bytes before image
header parsing or shell delivery. Only JPEG headers with dimensions at most
1024 by 1024 are accepted. The helper reconstructs the matched item and emits a
JPEG data URL; upstream imageData is discarded. Model.decodePresentation accepts
only bounded JPEG data URLs, so Qt receives no remote image URL. The existing
262144-byte serialized-output cap also bounds base64 expansion. This validates
headers and dimensions, not every JPEG bitstream; Qt retains decode-error fallback.
Optional image failures preserve matched game detail. An absolute image deadline
uses the remaining seven-second helper budget, reserving time for delivery before
the panel deadline, including trickling image responses; 429, cancellation, the
eight-second deadline and the artwork queue remain. No disk image cache is added.

All redirects, including same-origin redirects, are rejected and closed before
urllib can drain a body. This intentionally replaces the earlier same-origin
redirect support. Live public search/details/deals/comparison and bounded capsule
loading still pass without redirects. Local checks: 51 Bun tests / 247 assertions
and 18 Python tests. Regressions cover oversized chunked image streams, invalid
formats/dimensions, wrong app/host, injected image data, JPEG control, image 429,
and 301/302/303/307/308 handlers that must close without any body read. Native CI
adds actual JPEG data-URL rendering to the existing artwork smoke mode. Exact
commit and CI outcomes are recorded on the release and update issue #11915.
The UTM VM remains stopped; no new desktop visual pass is claimed.

## Core MCP transport fix — 22 October 2026

Version 0.4.2 addresses issue #11915 comment 6332404107. Search, details,
regional deals and comparison now use the existing Python helper instead of Qt
XMLHttpRequest. All remote bodies are read with a 262145-byte ceiling and rejected
above 262144 bytes before response JSON decoding or shell delivery. Serialized
stdout is separately bounded. The fixed MCP endpoint, protocol headers, request
IDs, exact-game/country validation and cache keys remain. Requests use bounded
stdin; cancelled children must finish before queued replacement requests start.
The 12-second panel deadline, 429 recovery and offline summaries remain.

Local validation passes: 51 Bun tests / 244 assertions and 13 Python tests.
Real local HTTP chunked and declared-length oversized MCP responses fail with
empty stdout/stderr; Unicode output expansion also fails closed. Live public
search, details, deals and comparison pass through the shipped helper and model.
Native CI adds a ninth mode for the four tools, 429, cancellation and delayed
child replacement. Exact-commit CI results are recorded on the release and issue.
Local Docker is unavailable; Linux CI owns strict QML lint, manifest validation
and native Wayland checks. The UTM VM remains stopped; no new desktop visual
validation is claimed.

## Artwork transport fix — 20 October 2026

Version 0.4.1 addresses maintainer feedback on issue #11915, comment 6279508621.
Artwork metadata now uses the existing bounded Python public-fetch helper rather
than Qt XMLHttpRequest. The helper reads at most 262145 bytes and rejects bodies
over 262144 bytes before JSON decoding or returning anything to the shell; its
serialized output is separately bounded. Inputs use stdin and the endpoint stays
fixed to GaugeDB. Exact-game and trusted Steam capsule validation remain in QML.
The eight-second artwork deadline, cancellation, optional-failure behavior and
HTTP 429 queue stopping remain; 429 is conveyed through a dedicated exit code.

Local checks pass: 50 Bun tests / 236 assertions and ten Python tests. The new
regressions exercise an oversized chunked HTTP response, bounded pre-decode reads,
valid metadata, output expansion, invalid IDs, 429 status, timeout and late replies.
CI additionally runs strict QML lint, the official validator and eight native
Wayland smoke modes, including artwork subprocess completion, 429 and cancellation.
The exact pushed commit and CI outcome are recorded on the release/update issue.
Local Docker was unavailable. The Linux-only clipboard helper cannot run locally
because macOS rejects its virtual-memory ulimit; CI runs it on Linux. The UTM VM
remains stopped at the owner's request; no new VM visual pass is claimed.

## Current status — 17 October 2026

Version 0.3.1 at `00eadbc20bc474ae473ff19730047f585cbb1bf1` is approved and
published in the marketplace via issue #11307. The full seven-mode ARM native
smoke rerun after guest login passed, in addition to the focused privacy/input
checks below. Older sections retain their original dates and reflect what was
known at that stage, rather than the current publication state.

Version 0.4.0 is under validation. Its source/model suite passes 47 tests / 219
assertions and six Python helper tests; official manifest validation passes.
The original temporary VM is no longer present. Its saved checkpoint is in
iCloud; restoration ran out of host disk space and was stopped at the owner's
request. No 0.4.0 VM visual pass is claimed. Linux release CI now runs the native
checks in an isolated Wayland session; its result will be recorded separately.
No previous desktop or native run verifies the new candidate.

Linux x86_64 CI at candidate `11b7ef5c532f44ef767e5cc773397e5543a6e00b`
passed official manifest validation, zero-warning strict QML lint, six Python
checks, clipboard helper limits, native Qt input/Tab/Backtab, captured generic
notification argv, and all seven native smoke modes including actual Qt HTTP
catalogue reads, wishlist name resolution and retained watch previous/check dates.
Run: https://github.com/dyd4dsh7/gaugedb-omarchy/actions/runs/39015187722
The final release commit is gated by the same CI workflow again. This is native
Linux/headless Wayland evidence, not a new ARM UTM desktop/390px visual pass.
The disposable pinned host checkout uses QtQuick 6.11 imports to avoid its known
Color type collision with Qt 6.12; this does not modify installed user shells.

---

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
Quickshell configuration and uses isolated temporary state. Five fresh processes
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

### Local-state confidentiality fix — version 0.2.2

Addresses the maintainer feedback on marketplace issue #11087. A fixed shell
program creates/repairs the state directory to mode 0700 and state file to 0600
before FileView receives its path. Directory paths and initial JSON are passed
as separate arguments. Creation uses umask 077 and noclobber; existing contents
are retained. Symlink targets and setup failures disable storage instead of
falling back to publicly readable files.

The native suite runs under umask 022 and checks actual directory/file modes
following writes, a fresh process and corrupt-file recovery. It deliberately
makes the prior directory/file modes 0755/0644 and verifies startup repairs them
to 0700/0600 without losing the favourite/country. A symlinked state directory is
rejected and the canary contents remain unchanged after an attempted save.
Atomic updates retain the existing owner-only file mode in the tested Qt runtime.

### Clipboard boundary fix — version 0.2.4

Addresses issue #11099 comment 6114331400. Qt 6.12 TextInput's clipboard-change
callback eagerly calls `mimeData->text()`. A native retrieval-counter probe
observed one payload read without any paste gesture in the old TextField,
and zero in the new production ClipboardField. Plain-text TextArea retains
native editing/IME/accessibility but its availability check inspects MIME formats
without retrieving the payload.

Keyboard Paste (including Ctrl+V and Shift+Insert), reflected zero-argument paste
and middle-button primary selection all route to an external helper. Native
context-menu paste is disabled. The whole process group has a one-second timeout
plus a 200 ms forced-kill grace period. The helper has a 64 MiB address-space
limit, reads at most 4097 bytes to detect overflow, rejects payloads over 4096
bytes, invalid UTF-8 and NULs, and emits no text until validation completes.
Clipboard bytes stay in bounded memory; no temporary clipboard files are written.
Insertion additionally rejects text exceeding the field's 80/100 UTF-16-unit
limit. Closing the picker, moving focus or cancelling a panel request discards
pending paste. Failed helper startup recovers rather than leaving paste disabled.

Verified after the independent boundary/compatibility review:

- Strict QML lint and 37 JavaScript regression tests pass.
- Actual Qt production-field checks: zero passive payload reads, Ctrl+V,
  Shift+Insert, reflected paste, middle-click placement, normal/oversized paste,
  selection replacement, Return, native Unicode IME, editable accessibility,
  typing/IME length limits, retained typed undo and horizontal caret visibility.
- Native Linux helper cases pass for normal text, Unicode, primary selection,
  oversized data, an endless trickle stream and invalid UTF-8. Unsafe transfers
  produce no accepted output.
- Headless Quickshell smoke checks pass for failed helper startup/retry and
  picker-close cancellation, alongside the prior state/network regressions.

The memory-capped helper was tested on native Linux ARM; Rosetta's own mappings
cannot fit the intentional address-space limit. The Qt input probes used the
emulated Linux Qt 6.12 environment. Native Linux CI repeats the helper and input
checks. Selection replacement retains native undo history but its remove/insert
operation uses two native undo steps. A fully hostile foreign Wayland producer
was not run; the native retrieval counter and isolated streaming-provider tests
are the focused substitute. Other host-owned editable TextFields are outside
this plugin fix; it does not patch Qt globally.

## Historical limitations at the 0.2.4 submission

Actual Hyprland install/enable/summon/hide/disable/remove lifecycle, shell restart,
keyboard and accessibility, country dropdown interaction, desktop and 390px
output in both themes, Steam CDN image loading, browser handoffs and real permission-denied filesystem
failures. Native state creation, persistence across processes and corrupt-file
preservation are now verified; shell restart is still distinct.

The JavaScript tests cover many corresponding failure modes using mocks; they do
not replace these native checks. No mock screenshot is offered as a native preview.
The plugin is submitted for maintainer review as a testing release with these
limitations disclosed. Marketplace approval is a separate outcome.

## Unreleased feature work — 13 October 2026

The working tree adds preferred starting view, keyboard help, bounded public
wishlist import, opt-in local price watches and native history. These changes
are not part of the approved 0.2.4 snapshot and have not been published.

- 43 plugin JavaScript tests / 198 assertions pass.
- Three Python public-read boundary tests pass (import cap, unavailable/oversized
  response preservation, invalid IDs and cross-origin redirect rejection).
- Full QML lint: zero warnings against official shell source
  `4c1b4cb3a94447aff39af98e2fcc0490a9fb32e7`, Quickshell 0.3.2 and Qt 6.12.
- Existing native clipboard/IME/accessibility input probe passes.
- Seven headless Quickshell smoke cases pass, including native wishlist isolation,
  history data, local watch updates, notification startup failure, options/help,
  prior filesystem privacy/recovery and real public catalogue HTTP cases.
- One repeated emulated run timed out during the unsafe-state case; the complete
  retry passed unchanged. This does not establish full desktop stability.
- Private-app public-history projection test and full Next/TypeScript check pass.
  The existing local dev server returned HTTP 200 with 30 scoped Portal 2/NZ
  observations; invalid country and out-of-range game IDs returned HTTP 400.

The history endpoint is local and not deployed. These initial headless results
use controlled new-feature fixtures, not private accounts or real alerts.
Subsequent ARM desktop checks and remaining coverage are recorded below.

### ARM UTM desktop checks — 13 October 2026

Omarchy was installed in the official UTM Arch ARM guest and booted with kernel
7.2.10. The source is pinned to
`09f16de292febfc76225dee11ffa64497fc6f30d`; its initial build failed against
today's packaging source, so the official packaging checkout was pinned to the
contemporary `aa0eb88d8c516e6270d1b087774fa3ed8b32b666`. The original boot
partition is preserved; root is 61 GiB and the new EFI partition is 2 GiB.
Package-database checks passed and wired NetworkManager/DNS worked after boot.

The first desktop was blank because Qt 6.12's built-in Color singleton shadowed
the pinned Omarchy shell's palette. The documented upstream workaround pins
bare QtQuick imports to 6.11 in 56 affected host QML files in this VM only.
The original files and stopped installed VM were backed up. GaugeDB already
uses a qualified Commons.Color import. After the workaround, the native
wallpaper, bar and notifications rendered. The user approved the vendor ARM
repository's optional package-signature setting for this VM; standard Arch
package signature checks remain required.

The normal `omarchy plugin add … --enable --yes` command installed and enabled
published 0.2.4 at exact commit
`0c6ce326582dc26b408cc1356bbb7424f1eaa0a1`. Native keyboard tests confirmed
live Portal 2 search, Steam artwork, details with NZ/NZD and US/USD quotes,
dropdown search and selection, and saving Portal 2. The country and favourite
persisted through a normal shell restart. Published files were preserved in a
separate guest copy before loading local development files for further QA.

- All seven isolated native Quickshell smoke modes passed on ARM Hyprland,
  including the controlled new-feature fixtures.
- Strict QML lint passed with zero warnings after the latest layout change,
  using Quickshell 0.3.2-1 and Qt 6.12.
- All three Python public-read boundary tests passed on ARM.
- Linux clipboard helper tests passed for normal/Unicode/primary input,
  oversized and endless streams, invalid UTF-8 and NUL rejection.
- Actual ARM Qt input probes passed: production passive retrieval count zero,
  IME, editable accessibility, keyboard/reflected/middle paste, input limits,
  typed undo and horizontal caret visibility. Selection replacement retains
  the previously documented two-step undo limitation.
- After the native layout finding, 20 affected panel tests / 90 assertions passed.

A native details screenshot exposed unequal grid sizing that crowded the reviews
column. Both metric columns now request equal width with a zero minimum width.
After manual Mac unlock, native screenshots confirmed equal-width columns,
readable review values and wrapping provenance. Focus-driven scrolling reached
the lower controls. The unavailable-history state now offers a direct
"Open web price history" button; keyboard activation launched Chromium with
Portal 2's price-history URL and matching page title. Full browser rendering
remains unverified because the guest screensaver covered the browser.

The controlled lower-price fixture completed through production notify-send,
and the Omarchy notification history recorded the GaugeDB alert with the exact
fixture price and country. After guest login, a native screenshot confirmed
a visible GaugeDB toast with the controlled 4.99 NZD fixture quote. Official disable
and re-enable commands passed, both enabled states were checked through shell
IPC, and the saved-state SHA-256 remained unchanged. The user chose controlled
fixtures for wishlist testing; no real Steam profile was imported.

Final checks after the history fallback change: 43 JavaScript tests / 198
assertions, three Python boundary tests and strict ARM QML lint with zero
warnings passed. Later visible checks confirmed live deals with Steam artwork
in Tokyo Night and Flexoki Light, F1 help, Escape dismissal and the Saved
starting preference surviving a normal shell restart. The original Tokyo Night
theme was restored.

Native Options QA found that Tab inserted whitespace in the shared TextArea.
ClipboardField now explicitly traverses Qt's focus chain for Tab/Shift+Tab.
A focused ARM Qt regression confirms both directions change focus without
mutating text; the existing passive-clipboard, paste, IME, accessibility and undo
checks remain passing. Native screenshots confirm Tab now reaches the Saved
preference through the wishlist field. Strict QML lint remained warning-free,
and all seven native smoke modes passed after this fix.

Official plugin removal preserved the saved-state hash. A normal reinstall
confirmed exact published 0.2.4 at 0c6ce32; restoring development working files
(excluding Git internals) passed validation and kept the saved-state hash. A VM
restart also preserved US country, Portal 2 favourite, one local watch and 0600
state permissions.

At this stage, narrow-display, mouse/hover, all browser destination rendering
and a fully hostile external Wayland producer remained unverified; subsequent
follow-up results are recorded below. UTM did not reliably forward automated mouse
clicks, so opening used supported Omarchy IPC and interactions used guest
keyboard input. Mouse/hover coverage is not claimed. No new feature release,
backend deployment or marketplace snapshot update is claimed.

After QA, the original Tokyo Night theme and enabled screensaver preference were
restored. The VM shut down gracefully. A durable APFS-cloned checkpoint was
verified against the stopped source bundle for file counts, sizes and exact
configuration; native screenshots were preserved alongside it. The registered
original VM remains unchanged in its temporary location.

### Completed follow-up — narrow display and deployed history

The real ARM Hyprland output was temporarily set through its documented Lua
monitor API to 780×1600 at scale 2 (390×800 logical). A 780×840 output at scale 2
(390×420 logical) fit the UTM console completely and exercised constrained-height
scrolling. Saved/details/history were inspected at the latter dimensions.
Native history observations, metric columns, wrapped provenance and lower actions
remained readable and reachable through focus-driven scrolling in Tokyo Night
and Flexoki Light. The owner explicitly reported that all three manual mouse
checks passed: bar logo open/close, Store popup dismissal by outside click, and
scrolling Portal 2 details. These are owner-reported desktop results; automated
CUA mouse injection into UTM remained unavailable.

The public GaugeDB history endpoint was reviewed and deployed. The frontend deployment
reported Done in 43 seconds. The projection regression, scoped Biome and a clean
webpack/TypeScript production build passed. Live NZ and US reads each returned
30 scoped observations with the expected currency, public field allowlist,
Cache-Control and nosniff. Unsupported country and out-of-range app ID returned
HTTP 400. No migration or Steam refresh was required.

Live follow-up exposed two plugin defects, fixed locally:

- The new watch helper omitted MCP's event-stream media type and received HTTP
  406. Correct content negotiation now succeeds against the live public MCP
  endpoint from ARM UTM; all four Python boundary/contract tests pass on ARM.
- History data arrived before its hidden Canvas could paint. Deferred repaint
  and availability/visibility repaint handlers restore the actual plotted
  observations. Before/after native screenshots verify marks in both themes
  at 390px; strict QML lint remains warning-free.

At this QA stage the feature update was local and unpublished; the API deployment
was separate. The versioned release checks are recorded below.

## Version 0.3.0 release preparation

The feature update is versioned as 0.3.0. Native ARM checks and owner-reported mouse
results above apply to this release candidate. Marketplace verification and publication
require the new exact commit; the verified 0.2.4 snapshot is unchanged until approval.

Final versioned candidate checks passed: 43 Bun tests / 198 assertions, four
Python tests, official Omarchy manifest validation, zero-warning strict QML lint,
all seven native smoke modes, Linux clipboard helper boundary tests and the native
Qt input regression including Tab / Backtab. Native checks ran on the documented
ARM Omarchy UTM host in isolated temporary state, without replacing the active plugin.

## Version 0.3.1 notification privacy fix — 2026-10-14

The 0.3.0 notification body exposed the saved watched game name and regional
price in notify-send arguments. Version 0.3.1 uses a constant generic notification
with no game name, ID, country or price. Its queue stores only trigger tokens.
The related public request helper now receives a bounded newline-delimited JSON
request through stdin; watched app IDs and entered SteamID64 values are absent
from timeout/Python command arguments. No new files or environment variables
carry private request inputs in production. Fixed endpoint validation, deadlines,
price eligibility, deduplication and cancellation remain in place.

The focused native regression captures actual notify-send argv during a controlled
price drop and verifies that watched identifiers and prices are absent. It also
executes native stdin wishlist/watch transport, saved price updates, automatic
notification success, queue draining and opt-out cancellation. The executable is
a disposable fake notification provider, so this test creates no real alerts.

Passed on ARM Qt/Quickshell in the existing test VM: official manifest validation,
strict zero-warning QML lint, six Python tests, native notification privacy test,
Linux clipboard boundary tests and native Qt input/Tab/Backtab regression. The
JavaScript suite passed 43 tests / 198 assertions. Native privacy uses Qt offscreen;
the full panel smoke rerun could not start while the rebooted VM was at login,
and offscreen lacks its PanelWindow backend. Earlier full desktop/390px evidence
remains the 0.3.0 feature validation, not a new 0.3.1 desktop pass.

Generic notifications can still reveal that a price-watch event occurred; they do
not reveal which game or price. This change does not protect against processes
running as the same user or an administrator. Marketplace approval/publication
requires verification of the new exact commit.
