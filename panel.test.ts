import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

// Execute the shipped QML JavaScript methods, not a second implementation.
// This checks request behavior, not QML parsing, bindings or native rendering.
// The VM cannot parse QML type assertions; the native smoke suite checks that interface.
const qml = readFileSync(new URL("Panel.qml", import.meta.url), "utf8");
const methods =
  qml
    .match(/^  function \w+\([^)]*\) \{(?:[^\n]*\}\n|[\s\S]*?^  \}\n)/gm)
    ?.join("\n")
    .replace(/ as GameResult\b/g, "") ?? "";
if (!methods) throw new Error("Panel methods unavailable");
const modelSource = readFileSync(new URL("Model.js", import.meta.url), "utf8");
const Model = runInNewContext(
  `${modelSource}\n({request, decode, gameId, presentationUrl, decodePresentation, compactObservation, endpoint})`,
);
const Store = runInNewContext(
  readFileSync(new URL("Store.js", import.meta.url), "utf8") +
    "\n({empty, read, encode, toggle, remember, put, get, savedGames, mergeLoaded, wishlistName})",
);
const Countries = runInNewContext(
  readFileSync(new URL("Countries.js", import.meta.url), "utf8") +
    "\n({supported, filter, label})",
);
const response = (id: number, game = "steam:620") =>
  JSON.stringify({
    jsonrpc: "2.0",
    id,
    result: {
      structuredContent: {
        games: [{ id: game, name: "Portal 2" }],
        coverage: "Saved observations",
      },
    },
  });

function harness(failMethod = "") {
  const later: (() => void)[] = [];
  const writes: string[] = [];
  const requests: { body: string; aborted: boolean; finish(status: number, value: string): void }[] = [];
  let active: (typeof requests)[number] | null = null;
  const timer = () => ({
    running: false,
    stop() {
      this.running = false;
    },
    restart() {
      this.running = true;
    },
  });
  const state = {
    root: null as unknown,
    Model,
    Store,
    Countries,
    localData: Store.empty(),
    clipboardPaste: { cancel() {} },
    wishlistRequest: { cancel() {} },
    wishlistNames: { cancel() {} },
    historyRequest: { cancel() {} },
    artworkRequest: {
      busy: false,
      process: { running: false },
      cancelled: false,
      calls: [] as string[][],
      request(args: string[]) {
        if (failMethod === "GET" || this.busy) return false;
        this.calls.push(args); this.busy = true; return true;
      },
      cancel() { this.busy = false; this.cancelled = true; },
    },
    storageReady: true,
    startApplied: false,
    showHelp: false,
    showSettings: false,
    storageWritable: true,
    storageWriting: false,
    storageDirty: false,
    storageMessage: "",
    stateDirectory: "/tmp/gaugedb-test",
    countryCode: "NZ",
    countryPopup: { close() {} },
    requestBody: "",
    comparisonIds: [] as string[],
    savedSection: "favourites",
    offline: false,
    listOffline: false,
    mcpRequest: {
      busy: false,
      process: { running: false },
      request(args: string[]) {
        const request = { body: args[1], aborted: false, finish(status: number, value: string) {
          if (active !== request) return;
          active = null;
          state.mcpRequest.busy = false;
          state.finishMcp(value, status === 200, status === 429);
        }};
        if (failMethod === "POST") return false;
        requests.push(request); active = request; this.busy = true; return true;
      },
      cancel() { if (active) active.aborted = true; active = null; this.busy = false; },
    },
    Qt: {
      callLater(fn: () => void) {
        later.push(fn);
      },
    },
    busy: false,
    opened: true,
    serial: 0,
    pending: null,
    artworkPending: null,
    artworkQueue: [],
    presentation: {} as Record<string, { image: string; detail: string }>,
    games: [] as { id: string; name?: string }[],
    coverage: "",
    message: "",
    canRetry: false,
    mode: "search",
    selectedId: "",
    listGames: [] as { id: string; name?: string }[],
    listMode: "search",
    listMessage: "",
    listCoverage: "",
    deadline: timer(),
    artworkDeadline: timer(),
    artworkRetry: timer(),
    mcpRetry: timer(),
    writeDelay: timer(),
    stateFile: {
      path: "",
      setText(text: string) {
        writes.push(text);
      },
    },
    country: { text: "NZ" },
    query: { text: "Portal", forceActiveFocus() {} },
    scroll: { contentY: 0 },
    results: { count: 0 },
    dealsTab: { forceActiveFocus() {} },
    savedTab: { forceActiveFocus() {} },
    controller: { hide() {} },
  };
  state.root = state;
  runInNewContext(methods, state);
  return {
    state: state as typeof state &
      Record<
        | "startMcp"
        | "finishMcp"
        | "setStartView"
        | "applyStartView"
        | "dismiss"
        | "search"
        | "cancel"
        | "details"
        | "back"
        | "queryChanged"
        | "countryChanged"
        | "compare"
        | "removeWatch"
        | "openWatch"
        | "setCountry"
        | "saved"
        | "finishPresentation"
        | "artworkTimedOut"
        | "fetchPresentation"
        | "finishStateRead"
        | "loadState"
        | "writeState",
        (...args: any[]) => void
      > & {
        favourite(game: { id: string; name: string }): void;
        selectComparison(id: string): void;
      },
    requests,
    later,
    writes,
  };
}

describe("Omarchy panel request methods", () => {
  test("Back from an unpinned game rebuilds Saved instead of restoring the removed favourite", () => {
    const { state } = harness();
    const game = { id: "steam:620", name: "Portal 2" };
    state.localData = Store.toggle(state.localData, game);
    state.presentation[game.id] = { image: "", detail: "Valve" };
    state.saved();
    state.details(game.id);
    state.favourite(game);
    state.back();
    expect(state.mode).toBe("saved");
    expect(state.localData.favourites).toHaveLength(0);
    expect(state.games).toHaveLength(0);
  });
  test("comparison selections toggle, cap at two and reject invalid IDs", () => {
    const { state } = harness();
    state.selectComparison("steam:620");
    state.selectComparison("steam:730");
    state.selectComparison("steam:570");
    expect(state.comparisonIds).toEqual(["steam:620", "steam:730"]);
    state.selectComparison("steam:620");
    state.selectComparison("steam:570");
    expect(state.comparisonIds).toEqual(["steam:730", "steam:570"]);
    state.comparisonIds = [];
    state.selectComparison("file:///bad");
    expect(state.comparisonIds).toHaveLength(0);
  });
  test("invalid country selection preserves current results; valid selection is serialized", () => {
    const { state, requests, writes } = harness();
    state.search();
    state.setCountry("ZZ");
    expect(state.countryCode).toBe("NZ");
    expect(requests[0].aborted).toBe(false);
    state.setCountry("US");
    expect(requests[0].aborted).toBe(true);
    state.writeState();
    expect(JSON.parse(writes[0]).country).toBe("US");
  });
  test("selecting the current country closes the picker without cancelling the game request", () => {
    const { state, requests } = harness();
    state.details("steam:620");
    state.setCountry("NZ");
    expect(state.mode).toBe("details");
    expect(state.selectedId).toBe("steam:620");
    expect(requests[0].aborted).toBe(false);
  });
  test("disk write errors preserve local favourites and surface a recovery message", () => {
    const { state } = harness();
    const game = { id: "steam:620", name: "Portal 2" };
    state.favourite(game);
    state.stateFile.setText = () => {
      throw new Error("Disk unavailable");
    };
    expect(() => state.writeState()).not.toThrow();
    expect(state.localData.favourites).toHaveLength(1);
    expect(state.storageWriting).toBe(false);
    expect(state.storageMessage).toContain("could not be saved");
  });
  test("Back to Recent includes the game just opened, rather than a stale snapshot", () => {
    const { state, requests } = harness();
    state.localData = Store.remember(state.localData, { id: "steam:730", name: "Other" });
    state.savedSection = "recent";
    state.listMode = "saved";
    state.mode = "details";
    state.details("steam:620");
    requests[0].finish(200, response(state.serial));
    state.back();
    expect(state.games.map((game) => game.id)).toEqual(["steam:620", "steam:730"]);
  });
  test("replaced and cancelled requests cannot overwrite current state", () => {
    const { state, requests } = harness();
    state.search();
    const firstId = state.serial;
    state.query.text = "Half-Life";
    state.search();
    expect(requests[0].aborted).toBe(true);
    requests[0].finish(200, response(firstId));
    expect(state.games).toHaveLength(0);
    requests[1].finish(200, response(state.serial));
    expect(state.games[0].id).toBe("steam:620");
    state.cancel();
    expect(state.artworkRequest.cancelled).toBe(true);
    expect(state.busy).toBe(false);
    expect(state.deadline.running).toBe(false);
  });
  test("replacement waits for child shutdown and cancellation clears queued MCP work", () => {
    const { state, requests } = harness();
    state.search();
    const oldId = state.serial;
    state.mcpRequest.process.running = true;
    state.query.text = "Half-Life";
    state.search();
    expect(requests).toHaveLength(1);
    expect(state.mcpRetry.running).toBe(true);
    requests[0].finish(200, response(oldId));
    expect(state.games).toHaveLength(0);
    state.mcpRequest.process.running = false;
    state.startMcp();
    expect(JSON.parse(requests[1].body).params.arguments.query).toBe("Half-Life");
    requests[1].finish(200, response(state.serial));
    expect(state.games[0].id).toBe("steam:620");
    state.mcpRequest.process.running = true;
    state.search();
    state.cancel();
    state.mcpRequest.process.running = false;
    state.startMcp();
    expect(requests).toHaveLength(2);
    expect(state.mcpRetry.running).toBe(false);
    expect(state.pending).toBeNull();
  });
  test("transport setup failures recover without a stuck loading state", () => {
    const { state } = harness("POST");
    expect(() => state.search()).not.toThrow();
    expect(state.busy).toBe(false);
    expect(state.pending).toBeNull();
    expect(state.canRetry).toBe(true);
    expect(state.deadline.running).toBe(false);
  });
  test("optional artwork transport failures preserve data and release the queue", () => {
    const { state, requests, later } = harness("GET");
    state.search();
    requests[0].finish(200, response(state.serial));
    expect(state.games).toHaveLength(1);
    expect(state.canRetry).toBe(false);
    expect(state.artworkPending).toBeNull();
    expect(state.artworkDeadline.running).toBe(false);
  });
  test("rate limiting and duplicate completion callbacks do not restart artwork", () => {
    const { state, requests } = harness();
    state.search();
    requests[0].finish(200, response(state.serial));
    state.artworkRequest.busy = false;
    state.finishPresentation("", false, true);
    requests[0].finish(200, response(state.serial));
    expect(requests).toHaveLength(1);
    expect(state.artworkRequest.calls).toEqual([["presentation", "620"]]);
    expect(state.artworkQueue).toHaveLength(0);
  });
  test("bounded artwork completion retains exact-game validation and ignores cancellation", () => {
    const { state, requests } = harness();
    state.search();
    requests[0].finish(200, response(state.serial));
    expect(state.artworkRequest.calls).toEqual([["presentation", "620"]]);
    state.artworkRequest.busy = false;
    state.finishPresentation(JSON.stringify({results:[{appId:620,imageData:"data:image/jpeg;base64,/9j/wAALCAABAAEBAREA/9k=",detail:"Valve"}]}), true, false);
    expect(state.presentation["steam:620"].detail).toBe("Valve");
    expect(state.presentation["steam:620"].image).toStartWith("data:image/jpeg;base64,");
    expect(state.games[0].id).toBe("steam:620");
    delete state.presentation["steam:620"];
    state.artworkQueue = ["steam:620"];
    state.fetchPresentation();
    state.cancel();
    state.finishPresentation('{"results":[{"appId":620,"detail":"stale"}]}', true, false);
    expect(state.presentation["steam:620"]).toBeUndefined();
  });
  test("artwork timeout and rejected metadata preserve game data and release transport", () => {
    const { state, requests } = harness();
    state.search();
    requests[0].finish(200, response(state.serial));
    state.artworkTimedOut();
    expect(state.artworkPending).toBeNull();
    expect(state.artworkRequest.cancelled).toBe(true);
    state.finishPresentation('{"results":[{"appId":620,"detail":"late"}]}', true, false);
    expect(state.presentation).toEqual({});
    state.artworkQueue = ["steam:620"];
    state.fetchPresentation();
    state.artworkRequest.busy = false;
    state.finishPresentation("x".repeat(262145), true, false);
    expect(state.presentation).toEqual({});
    expect(state.games).toHaveLength(1);
    expect(state.canRetry).toBe(false);
  });
  test("a terminating artwork child retains the queue until transport is idle", () => {
    const { state } = harness();
    state.artworkQueue = ["steam:620"];
    state.artworkRequest.process.running = true;
    state.fetchPresentation();
    expect(state.artworkQueue).toEqual(["steam:620"]);
    expect(state.artworkRequest.calls).toHaveLength(0);
    expect(state.artworkRetry.running).toBe(true);
    state.artworkRequest.process.running = false;
    state.fetchPresentation();
    expect(state.artworkRequest.calls).toEqual([["presentation","620"]]);
    state.cancel();
    expect(state.artworkRetry.running).toBe(false);
  });
  test("query edits cancel stale work; country edits clear cached navigation", () => {
    const { state, requests } = harness();
    state.search();
    state.queryChanged();
    expect(requests[0].aborted).toBe(true);
    expect(state.games).toHaveLength(0);
    expect(state.canRetry).toBe(false);
    state.listGames = [{ id: "steam:620" }];
    state.countryChanged();
    expect(state.listGames).toHaveLength(0);
    expect(state.mode).toBe("search");
  });
  test("details enforce selection; Back restores the saved list without transport", () => {
    const { state, requests, later } = harness();
    state.games = [{ id: "steam:620", name: "Portal 2" }];
    state.details("steam:620");
    requests[0].finish(200, response(state.serial, "steam:730"));
    expect(state.games).toHaveLength(0);
    expect(state.canRetry).toBe(true);
    state.presentation["steam:620"] = { image: "", detail: "Valve" };
    state.back();
    later.forEach((fn) => fn());
    expect(state.games[0].id).toBe("steam:620");
    expect(state.mode).toBe("search");
    expect(requests).toHaveLength(1);
  });
  test("timeout callback cancels transport and ignores a late successful reply", () => {
    const { state, requests } = harness();
    state.search();
    const id = state.serial;
    const callback = qml.match(
      /id: deadline\s+interval: 12000\s+onTriggered: \{([^\n]+)\}/,
    )?.[1];
    if (!callback) throw new Error("Request timeout callback unavailable");
    runInNewContext(callback, state);
    requests[0].finish(200, response(id));
    expect(requests[0].aborted).toBe(true);
    expect(state.games).toHaveLength(0);
    expect(state.busy).toBe(false);
    expect(state.canRetry).toBe(true);
    expect(state.message).toContain("timed out");
  });
  test("offline, rate-limited and malformed responses offer Retry without displaying results", () => {
    for (const [status, body] of [
      [0, ""],
      [429, ""],
      [200, "not JSON"],
    ] as const) {
      const { state, requests } = harness();
      state.search();
      requests[0].finish(status, body);
      expect(state.busy).toBe(false);
      expect(state.canRetry).toBe(true);
      expect(state.games).toHaveLength(0);
      expect(state.deadline.running).toBe(false);
    }
  });
  test("a failed request restores only its exact cached summary and makes no artwork requests", () => {
    const { state, requests } = harness();
    state.details("steam:620");
    requests[0].finish(200, response(state.serial));
    state.details("steam:620");
    const before = requests.length;
    requests[before - 1].finish(0, "");
    expect(state.offline).toBe(true);
    expect(state.games[0].id).toBe("steam:620");
    expect(state.message).toContain("Offline summary");
    expect(requests).toHaveLength(before);
    state.setCountry("US");
    state.details("steam:620");
    requests[requests.length - 1].finish(0, "");
    expect(state.games).toHaveLength(0);
    expect(state.offline).toBe(false);
  });
  test("comparison uses the selected IDs and requested country", () => {
    const { state, requests } = harness();
    state.comparisonIds = ["steam:620", "steam:730"];
    state.compare();
    const sent = JSON.parse(requests[0].body);
    expect(sent.params.name).toBe("compare_games");
    expect(sent.params.arguments).toEqual({ ids: ["steam:620", "steam:730"], country: "NZ" });
    requests[0].finish(200, response(state.serial));
    expect(state.games).toHaveLength(1);
    expect(state.mode).toBe("compare");
  });
  test("failed bounded state reads preserve session changes and never enable writes", () => {
    const { state, writes } = harness();
    state.storageReady = false;
    state.localData = Store.toggle(state.localData, {id:"steam:620",name:"Portal 2"});
    state.finishStateRead("", false);
    state.writeState();
    expect(state.storageReady).toBe(true);
    expect(state.storageWritable).toBe(false);
    expect(state.localData.favourites[0].id).toBe("steam:620");
    expect(state.stateFile.path).toBe("");
    expect(writes).toHaveLength(0);
  });
  test("bounded state success enables the writer only after model validation", () => {
    const { state } = harness();
    state.storageReady = false;
    state.finishStateRead(Store.encode(Store.empty()), true);
    expect(state.stateFile.path).toBe("/tmp/gaugedb-test/state.json");
    const corrupt = harness().state;
    corrupt.storageReady = false;
    corrupt.finishStateRead("broken JSON", true);
    expect(corrupt.stateFile.path).toBe("");
    expect(corrupt.storageWritable).toBe(false);
  });
  test("invalid local data is preserved by disabling writes", () => {
    const { state } = harness();
    state.loadState("broken JSON");
    expect(state.storageReady).toBe(true);
    expect(state.storageWritable).toBe(false);
    expect(() => state.writeState()).not.toThrow();
    expect(state.storageMessage).toContain("preserved");
  });
  test("a late persisted country cancels requests for the previous region", () => {
    const { state, requests } = harness();
    state.details("steam:620");
    state.loadState(Store.encode({ ...Store.empty(), country: "US" }));
    expect(state.countryCode).toBe("US");
    expect(requests[0].aborted).toBe(true);
    expect(state.games).toHaveLength(0);
    expect(state.storageWritable).toBe(true);
  });
});

test("starting view waits for storage and never overrides an active user search", () => {
  const { state, requests } = harness();
  state.storageReady = false;
  state.localData.startView = "deals";
  state.applyStartView();
  expect(requests).toHaveLength(0);
  state.storageReady = true;
  state.applyStartView();
  expect(state.mode).toBe("deals");
  expect(requests).toHaveLength(1);
  state.search();
  state.applyStartView();
  expect(state.mode).toBe("search");
  expect(requests).toHaveLength(2);
});

test("invalid starting preferences are ignored and help dismisses before the panel", () => {
  const { state } = harness();
  state.setStartView("javascript:");
  expect(state.localData.startView).toBe("");
  state.setStartView("saved");
  expect(state.localData.startView).toBe("saved");
  state.showHelp = true;
  state.showSettings = true;
  state.dismiss();
  expect(state.showHelp).toBe(false);
  expect(state.showSettings).toBe(true);
  state.dismiss();
  expect(state.showSettings).toBe(false);
});

test("watch removal affects only the exact country and opening uses that region", () => {
  const {state,requests}=harness();
  const item={id:"steam:620",name:"Portal 2",currency:"NZD",baseline:999,last:499,observedAt:Date.now()};
  state.localData.watches=[{...item,country:"NZ"},{...item,country:"US",currency:"USD"}];
  state.removeWatch("steam:620","NZ");
  expect(state.localData.watches).toHaveLength(1);
  expect(state.localData.watches[0].country).toBe("US");
  state.openWatch("steam:620","US");
  expect(JSON.parse(requests[0].body).params.arguments).toEqual({id:"steam:620",country:"US"});
});
