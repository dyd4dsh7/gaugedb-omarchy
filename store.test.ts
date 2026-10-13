import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
const load = (file: string, exports: string) =>
  runInNewContext(readFileSync(new URL(file, import.meta.url), "utf8") + `\n({${exports}})`);
const Model = load("Model.js", "request,decode");
const Store = load(
  "Store.js",
  "empty,read,encode,toggle,remember,put,get,savedGames,mergeLoaded",
);
const Countries = load("Countries.js", "countries,supported,filter,label");
const game = {
  id: "steam:620",
  name: "Portal 2",
  metadata: { at: "2026-10-08T00:00:00Z", freshness: "fresh" },
  price: {
    status: "priced",
    requestedCountry: "NZ",
    actualStoreCountry: "NZ",
    finalMinor: 1475,
    currency: "NZD",
    observation: { at: "2026-10-08T00:00:00Z", freshness: "fresh" },
  },
};
describe("Omarchy local saved data", () => {
  test("favourites and recent identities survive serialization without duplicate entries", () => {
    let data = Store.toggle(Store.empty(), game);
    data = Store.remember(Store.remember(data, game), game);
    const restored = Store.read(Store.encode(data), Model, Countries);
    expect(restored.favourites).toEqual([{ id: "steam:620", name: "Portal 2" }]);
    expect(restored.recent).toHaveLength(1);
    expect(Store.toggle(restored, game).favourites).toHaveLength(0);
    expect(Store.savedGames(restored, "favourites")[0].price).toBeNull();
  });
  test("offline summaries match the exact country and mark saved observations stale", () => {
    const now = Date.now();
    const body = Model.request("get_game", { id: game.id, country: "NZ" }, 1);
    const data = Store.put(
      Store.empty(),
      body,
      { games: [game], coverage: "Saved observations" },
      now,
    );
    const restored = Store.read(Store.encode(data), Model, Countries);
    const cached = Store.get(
      restored,
      Model.request("get_game", { id: game.id, country: "NZ" }, 99),
      now,
    );
    expect(cached.result.games[0].price.observation.freshness).toBe("stale");
    expect(data.cache[0].result.games[0].price.observation.freshness).toBe("fresh");
    expect(
      Store.get(restored, Model.request("get_game", { id: game.id, country: "US" }, 1), now),
    ).toBeNull();
    expect(Store.get(restored, body, now + 31 * 86400000)).toBeNull();
  });
  test("corrupt, oversized, unknown-version and mismatched-region files are rejected", () => {
    expect(() => Store.read("{", Model, Countries)).toThrow();
    expect(() => Store.read("x".repeat(1048577), Model, Countries)).toThrow();
    expect(() =>
      Store.read(JSON.stringify({ ...Store.empty(), version: 2 }), Model, Countries),
    ).toThrow();
    const body = Model.request("get_game", { id: game.id, country: "US" }, 1);
    const data = Store.put(
      Store.empty(),
      body,
      { games: [game], coverage: "Saved" },
      Date.now(),
    );
    expect(() => Store.read(Store.encode(data), Model, Countries)).toThrow();
  });
  test("late disk loading preserves favourites while merging new public results", () => {
    const loaded = Store.toggle(Store.empty(), game);
    const current = Store.remember(Store.empty(), { id: "steam:730", name: "Other" });
    expect(Store.mergeLoaded(loaded, current).favourites).toHaveLength(1);
    expect(Store.mergeLoaded(loaded, current).recent[0].id).toBe("steam:730");
  });
  test("saved data strips account and transport fields and enforces bounds", () => {
    let data = Store.empty();
    for (let i = 1; i <= 45; i++)
      data = Store.remember(data, { id: `steam:${i}`, name: "Game" });
    expect(data.recent).toHaveLength(12);
    for (let i = 1; i <= 40; i++)
      data = Store.toggle(data, { id: `steam:${i}`, name: "Game" });
    expect(() => Store.toggle(data, { id: "steam:41", name: "Game" })).toThrow();
    const body = Model.request("get_game", { id: game.id, country: "NZ" }, 1);
    const cached = Store.put(
      data,
      body,
      {
        games: [{ ...game, cookie: "private", token: "private" }],
        coverage: "Saved",
        account: "private",
      },
      Date.now(),
    );
    expect(Store.encode(cached)).not.toContain("private");
  });
  test("country picker validates its bundled registry and matches names or codes", () => {
    const codes = Countries.countries.map((country: { code: string }) => country.code);
    expect(new Set(codes).size).toBe(codes.length);
    expect(
      Countries.countries.every(
        (country: { code: string; name: string }) =>
          /^[A-Z]{2}$/.test(country.code) && country.name.trim().length > 0,
      ),
    ).toBe(true);
    expect(Countries.filter("New Zealand")[0].code).toBe("NZ");
    expect(Countries.filter(" nz ")[0].code).toBe("NZ");
    expect(Countries.supported("ZZ")).toBe(false);
  });
});

test("starting view migrates old state and rejects unsupported preferences", () => {
  const old = Store.empty();
  delete old.startView;
  expect(Store.read(JSON.stringify(old), Model, Countries).startView).toBe("");
  const saved = { ...Store.empty(), startView: "saved" };
  expect(Store.read(Store.encode(saved), Model, Countries).startView).toBe("saved");
  expect(() => Store.read(JSON.stringify({ ...saved, startView: "invalid" }), Model, Countries)).toThrow();
  expect(Store.mergeLoaded(saved, { ...Store.empty(), startView: "deals" }).startView).toBe("deals");
});

test("invalid watch and wishlist state is rejected rather than clearing saved games",()=>{
 for (const extra of [{watches:null},{wishlist:0},{backgroundWatches:"on"},{watches:Array(11).fill({})}]) {
  expect(()=>Store.read(JSON.stringify({...Store.empty(),...extra}),Model,Countries)).toThrow();
 }
});
