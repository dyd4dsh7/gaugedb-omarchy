import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const model = runInNewContext(
  readFileSync(new URL("Model.js", import.meta.url), "utf8") +
    "\n({ request, decode, links, wishlistLink, price, metrics, priceView, metricView, presentationUrl, decodePresentation, activityView, reviewsView, initialPrice })",
);

describe("Omarchy public catalogue client", () => {
  test("comparison validates unique IDs and encodes the public MCP tool", async () => {
    expect(() =>
      model.request("compare_games", { ids: ["steam:620", "steam:620"], country: "NZ" }, 1),
    ).toThrow();
    expect(() =>
      model.request("compare_games", { ids: ["steam:620"], country: "NZ" }, 1),
    ).toThrow();
    const request = JSON.parse(
      model.request("compare_games", { ids: ["steam:620", "steam:730"], country: "NZ" }, 5),
    );
    expect(request.method).toBe("tools/call");
    expect(request.params).toEqual({
      name: "compare_games",
      arguments: { ids: ["steam:620", "steam:730"], country: "NZ" },
    });
    // Synthetic public response: no server code or account data is bundled.
    const data = model.decode(
      JSON.stringify({
        jsonrpc: "2.0",
        id: 5,
        result: {
          structuredContent: {
            games: [
              { id: "steam:620", name: "Portal 2" },
              { id: "steam:730", name: "Counter-Strike 2" },
            ],
            coverage: "Saved observations",
          },
        },
      }),
      5,
      { ids: ["steam:620", "steam:730"], country: "NZ" },
    );
    expect(
      data.games.every((game: { id: string }) => ["steam:620", "steam:730"].includes(game.id)),
    ).toBe(true);
    expect(model.links("steam:620").proton).toBe("https://www.protondb.com/app/620");
    expect(model.links("steam:620").history).toBe("https://gaugedb.com/app/620?tab=prices");
    expect(model.links("steam:620").alerts).toBe("https://gaugedb.com/app/620#price-alert");
    expect(model.wishlistLink()).toBe("https://gaugedb.com/watchlist?tab=steam-wishlist");
  });
  test("details reject unrelated games and prices requested for another country", () => {
    const reply = (games: unknown[]) =>
      JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: { structuredContent: { games, coverage: "saved" } },
      });
    const expected = { gameId: "steam:620", country: "NZ" };
    expect(() =>
      model.decode(reply([{ id: "steam:730", name: "Other" }]), 1, expected),
    ).toThrow();
    expect(() =>
      model.decode(
        reply([{ id: "steam:620", name: "Portal 2", price: { requestedCountry: "US" } }]),
        1,
        expected,
      ),
    ).toThrow();
    expect(model.decode(reply([]), 1, expected).games).toHaveLength(0);
    expect(
      model.decode(
        reply([
          {
            id: "steam:620",
            name: "Portal 2",
            price: { requestedCountry: "NZ", actualStoreCountry: "US" },
          },
        ]),
        1,
        expected,
      ).games,
    ).toHaveLength(1);
  });

  test("invalid prices and impossible metrics remain unavailable", () => {
    const price = { status: "priced", finalMinor: 499, initialMinor: 999, currency: "NZD" };
    for (const invalid of [
      { currency: "" },
      { currency: "usd" },
      { finalMinor: 0.5 },
      { finalMinor: Infinity },
      { finalMinor: null },
    ]) {
      const game = { price: { ...price, ...invalid } };
      expect(model.priceView(game).priced).toBe(false);
      expect(model.initialPrice(game)).toBe("");
    }
    expect(model.activityView({ activity: { players: 1.5, peak24: -1 } }).players).toBe(
      "Unknown",
    );
    expect(model.reviewsView({ reviews: { count: 0.5, score: 101 } }).count).toBe("Unknown");
    expect(model.reviewsView({ reviews: { score: 101 } }).score).toBe("Unknown");
  });
  test("artwork enrichment matches the exact app and accepts only collected Steam capsules", () => {
    const image =
      "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/abcd/capsule_231x87.jpg?t=1";
    const reply = (url: string, appId = 620) =>
      JSON.stringify({
        results: [
          { title: "Package", href: "/sub/620", image: "https://example.com/wrong.jpg" },
          { appId, detail: "Valve", image: url },
        ],
      });
    expect(model.presentationUrl("steam:620")).toBe("https://gaugedb.com/api/search?q=620");
    expect(model.decodePresentation(reply(image), "steam:620").image).toBe(image);
    expect(model.decodePresentation(reply(image), "steam:620").detail).toBe("Valve");
    expect(model.decodePresentation(reply("file:///private/file"), "steam:620").image).toBe(
      "",
    );
    expect(
      model.decodePresentation(reply(image.replace("/620/", "/730/")), "steam:620").image,
    ).toBe("");
    expect(model.decodePresentation(reply(image, 730), "steam:620").detail).toBe("");
    expect(model.activityView({ activity: { players: 1278, peak24: null } }).players).toBe(
      "1,278",
    );
    expect(model.activityView({ activity: { players: 1278, peak24: null } }).peak).toBe(
      "Unknown",
    );
    expect(model.reviewsView({ reviews: { count: null, score: 0 } }).score).toBe("0%");
    expect(
      model.initialPrice({
        price: {
          status: "priced",
          currency: "NZD",
          initialMinor: 999,
          finalMinor: 499,
          actualStoreCountry: "NZ",
        },
      }),
    ).toBe("9.99 NZD");
  });
  test("decodes a public detail response and preserves a missing region", () => {
    const request = JSON.parse(
      model.request("get_game", { id: "steam:620", country: "NZ" }, 1),
    );
    expect(request.params.arguments).toEqual({ id: "steam:620", country: "NZ" });
    const data = model.decode(
      JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          structuredContent: {
            games: [
              {
                id: "steam:620",
                name: "Portal 2",
                price: { status: "unavailable", requestedCountry: "NZ", finalMinor: null },
              },
            ],
            coverage: "Saved observations",
          },
        },
      }),
      1,
      { gameId: "steam:620", country: "NZ" },
    );
    expect(data.games[0].price.finalMinor).toBeNull();
    expect(model.price(data.games[0])).toContain("Price unavailable for NZ");
    expect(model.price(data.games[0])).not.toContain("0.00");
  });

  test("search titles remain JSON data and links use only validated IDs", () => {
    const query = '$(touch /tmp/injected) " Portal';
    expect(
      JSON.parse(model.request("search_games", { query }, 2)).params.arguments.query,
    ).toBe(query);
    expect(model.links("steam:620").gauge).toBe("https://gaugedb.com/app/620");
    expect(() => model.links("steam:620;touch /tmp/injected")).toThrow();
    expect(() => model.links("steam:2147483648")).toThrow();
  });

  test("empty titles and invalid countries fail before transport", () => {
    expect(() => model.request("search_games", { query: " " }, 1)).toThrow();
    expect(() => model.request("find_deals", { country: "NZ;" }, 1)).toThrow();
    expect(
      JSON.parse(model.request("find_deals", { country: " nz " }, 1)).params.arguments.country,
    ).toBe("NZ");
  });

  test("stale zero prices and source country stay explicit", () => {
    const game = {
      price: {
        status: "priced",
        finalMinor: 0,
        currency: "USD",
        requestedCountry: "NZ",
        actualStoreCountry: "US",
        observation: { at: "2026-09-01T00:00:00Z", freshness: "stale" },
      },
    };
    const text = model.price(game);
    expect(text).toContain("Saved price: 0.00 USD · US");
    expect(text).toContain("2026-09-01T00:00:00Z · stale");
  });

  test("Steam hundredths are converted for both ordinary and zero-decimal currencies", () => {
    const p = {
      status: "priced",
      finalMinor: 120000,
      currency: "JPY",
      actualStoreCountry: "JP",
    };
    expect(model.price({ price: p })).toContain("1200 JPY");
    expect(model.price({ price: { ...p, finalMinor: 499, currency: "NZD" } })).toContain(
      "4.99 NZD",
    );
  });

  test("unknown players are distinct from observed zero", () => {
    expect(model.metrics({ activity: { players: null } })).toContain("players: unknown");
    expect(model.metrics({ activity: { players: 0 } })).toContain("players: 0");
  });

  test("compact detail values preserve source country, UTC dates, stale prices and missing data", () => {
    const game = {
      price: {
        status: "priced",
        finalMinor: 499,
        initialMinor: 999,
        currency: "USD",
        requestedCountry: "NZ",
        actualStoreCountry: "US",
        observation: { at: "2026-09-01T12:30:00+12:00", freshness: "stale" },
      },
      activity: { players: 0, observation: { at: null, freshness: "unknown" } },
      reviews: { count: null, score: null, observation: { at: null, freshness: "unknown" } },
    };
    const view = model.priceView(game);
    expect(view.amount).toBe("4.99 USD");
    expect(view.region).toBe("US");
    expect(view.note).toContain("1 Sep 2026, 00:30 UTC · stale");
    expect(view.discount).toBe("50% off");
    expect(model.metricView(game)[0].value).toBe("0");
    expect(model.metricView(game)[1].value).toBe("Unknown");
    expect(
      model.priceView({ price: { ...game.price, status: "unavailable", finalMinor: null } })
        .priced,
    ).toBe(false);
  });

  test("rejects failed, oversized, mismatched and malformed responses", () => {
    expect(() =>
      model.decode(JSON.stringify({ jsonrpc: "2.0", id: 1, error: { code: -1 } }), 1),
    ).toThrow();
    expect(() => model.decode("x".repeat(262145), 1)).toThrow();
    expect(() =>
      model.decode(JSON.stringify({ jsonrpc: "2.0", id: 2, result: {} }), 1),
    ).toThrow();
    expect(() =>
      model.decode(
        JSON.stringify({
          jsonrpc: "2.0",
          id: 1,
          result: {
            structuredContent: { games: [{ id: "steam:0", name: "bad" }], coverage: "saved" },
          },
        }),
        1,
      ),
    ).toThrow();
  });

  test("supports text-only results and preserves empty/partial coverage", () => {
    const data = { games: [], missingIds: ["steam:620"], coverage: "Partial coverage" };
    const reply = {
      jsonrpc: "2.0",
      id: 3,
      result: { content: [{ type: "text", text: JSON.stringify(data) }] },
    };
    const result = model.decode(JSON.stringify(reply), 3);
    expect(result.games).toHaveLength(0);
    expect(result.coverage).toBe("Partial coverage");
    expect(result.missingIds).toEqual(["steam:620"]);
  });
});
