import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

// Execute the shipped QML JavaScript methods, not a second implementation.
// This checks request behavior, not QML parsing, bindings or native rendering.
const qml = readFileSync(new URL("Panel.qml", import.meta.url), "utf8");
const methods =
  qml.match(/^  function \w+\([^)]*\) \{(?:[^\n]*\}\n|[\s\S]*?^  \}\n)/gm)?.join("\n") ?? "";
if (!methods) throw new Error("Panel methods unavailable");
const modelSource = readFileSync(new URL("Model.js", import.meta.url), "utf8");
const Model = runInNewContext(
  `${modelSource}\n({request, decode, gameId, presentationUrl, decodePresentation, compactObservation, endpoint})`,
);
const Store = runInNewContext(
  readFileSync(new URL("Store.js", import.meta.url), "utf8") +
    "\n({empty, read, encode, toggle, remember, put, get, savedGames, mergeLoaded})",
);
const Countries = runInNewContext(
  readFileSync(new URL("Countries.js", import.meta.url), "utf8") + "\n({supported, filter, label})",
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
  class Xhr {
    static DONE = 4;
    readyState = 0;
    status = 0;
    responseText = "";
    aborted = false;
    method = "";
    body = "";
    onreadystatechange = () => {};
    constructor() {
      requests.push(this);
    }
    open(method: string) {
      this.method = method;
      if (method === failMethod) throw new Error("Transport unavailable");
    }
    setRequestHeader() {}
    send(body = "") {
      this.body = body;
    }
    abort() {
      this.aborted = true;
      this.readyState = 4;
      this.onreadystatechange();
    }
    finish(status: number, text: string) {
      this.status = status;
      this.responseText = text;
      this.readyState = 4;
      this.onreadystatechange();
    }
  }
  const requests: Xhr[] = [];
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
    storageReady: true,
    storageWritable: true,
    storageWriting: false,
    storageDirty: false,
    storageMessage: "",
    countryCode: "NZ",
    countryPopup: { close() {} },
    requestBody: "",
    comparisonIds: [] as string[],
    savedSection: "favourites",
    offline: false,
    listOffline: false,
    XMLHttpRequest: Xhr,
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
    writeDelay: timer(),
    stateFile: {
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
        | "search"
        | "cancel"
        | "details"
        | "back"
        | "queryChanged"
        | "countryChanged"
        | "compare"
        | "setCountry"
        | "saved"
        | "loadState"
        | "writeState",
        (...args: string[]) => void
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
    expect(requests[2].aborted).toBe(true);
    expect(state.busy).toBe(false);
    expect(state.deadline.running).toBe(false);
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
    later.forEach((fn) => fn());
    expect(state.artworkDeadline.running).toBe(false);
  });
  test("rate limiting and duplicate completion callbacks do not restart artwork", () => {
    const { state, requests } = harness();
    state.search();
    requests[0].finish(200, response(state.serial));
    requests[1].finish(429, "");
    requests[0].finish(200, response(state.serial));
    expect(requests).toHaveLength(2);
    expect(state.artworkQueue).toHaveLength(0);
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
    const callback = qml.match(/id: deadline\s+interval: 12000\s+onTriggered: \{([^\n]+)\}/)?.[1];
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
