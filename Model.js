// biome-ignore-all lint/correctness/noUnusedVariables: QML imports these functions and endpoint.

var endpoint = "https://gaugedb.com/integrations/public-games/mcp";

function gameId(id) {
  return (
    typeof id === "string" && /^steam:[1-9]\d{0,9}$/.test(id) && Number(id.slice(6)) <= 2147483647
  );
}

function request(name, args, id) {
  if (name === "search_games") {
    if (typeof args.query !== "string" || !args.query.trim() || args.query.trim().length > 100)
      throw new Error("Enter a game title (1–100 characters).");
    args = { query: args.query.trim(), limit: 5 };
  } else if (name === "get_game" || name === "find_deals" || name === "compare_games") {
    var country = String(args.country || "")
      .trim()
      .toUpperCase();
    if (!/^[A-Z]{2}$/.test(country))
      throw new Error("Enter a two-letter store country, such as NZ.");
    if (name === "get_game") {
      if (!gameId(args.id)) throw new Error("Invalid Steam game ID.");
      args = { id: args.id, country: country };
    } else if (name === "compare_games") {
      if (
        !Array.isArray(args.ids) ||
        args.ids.length < 2 ||
        args.ids.length > 4 ||
        args.ids.some(function (value, index) {
          return !gameId(value) || args.ids.indexOf(value) !== index;
        })
      )
        throw new Error("Select two to four different games.");
      args = { ids: args.ids.slice(), country: country };
    } else args = { country: country, limit: 5 };
  } else throw new Error("Unsupported action.");
  return JSON.stringify({
    jsonrpc: "2.0",
    id: id,
    method: "tools/call",
    params: { name: name, arguments: args },
  });
}

function decode(text, id, expected) {
  if (text.length > 262144) throw new Error("GaugeDB returned too much data.");
  var reply = JSON.parse(text);
  if (reply.jsonrpc !== "2.0" || reply.id !== id || reply.error || !reply.result)
    throw new Error("GaugeDB could not complete this request.");
  if (reply.result.isError) {
    var code = reply.result.content && reply.result.content[0] ? reply.result.content[0].text : "";
    throw new Error(
      code === "INVALID_ARGUMENT" || code === "invalid_input"
        ? "Check the game title and store country."
        : "GaugeDB is unavailable. Try again.",
    );
  }
  var result = reply.result.structuredContent;
  if (!result && reply.result.content && reply.result.content[0])
    result = JSON.parse(reply.result.content[0].text);
  if (
    !result ||
    !Array.isArray(result.games) ||
    result.games.length > 10 ||
    typeof result.coverage !== "string"
  )
    throw new Error("GaugeDB returned an unexpected response.");
  for (var i = 0; i < result.games.length; i++) {
    var game = result.games[i];
    if (!game || !gameId(game.id) || typeof game.name !== "string" || game.name.length > 300)
      throw new Error("GaugeDB returned an invalid game.");
    if (expected && expected.gameId && game.id !== expected.gameId)
      throw new Error("GaugeDB returned a different game. Try again.");
    if (expected && expected.ids && expected.ids.indexOf(game.id) === -1)
      throw new Error("GaugeDB returned a different comparison. Try again.");
    if (
      result.games.slice(0, i).some(function (previous) {
        return previous.id === game.id;
      })
    )
      throw new Error("GaugeDB returned a duplicate game.");
    if (
      expected &&
      expected.country &&
      game.price &&
      game.price.requestedCountry !== expected.country
    )
      throw new Error("GaugeDB returned a different store country. Try again.");
  }
  if (expected && expected.gameId && result.games.length > 1)
    throw new Error("GaugeDB returned an unexpected game summary.");
  return result;
}

function validCount(value) {
  return (
    typeof value === "number" &&
    isFinite(value) &&
    value >= 0 &&
    Math.floor(value) === value &&
    value <= 9007199254740991
  );
}

// Construct links from validated IDs, never execute server-supplied URLs or titles.
function links(id) {
  if (!gameId(id)) throw new Error("Invalid Steam game ID.");
  var app = id.slice(6);
  return {
    gauge: "https://gaugedb.com/app/" + app,
    steam: "https://store.steampowered.com/app/" + app + "/",
    proton: "https://www.protondb.com/app/" + app,
    history: "https://gaugedb.com/app/" + app + "?tab=prices",
    alerts: "https://gaugedb.com/app/" + app + "#price-alert",
  };
}

function wishlistLink() {
  return "https://gaugedb.com/watchlist?tab=steam-wishlist";
}

function observation(value) {
  if (!value || !value.at) return "date unknown";
  return value.at + " · " + (value.freshness || "unknown");
}

function price(game) {
  var p = game.price;
  if (!p) return "Select Details for a regional price.";
  if (p.status !== "priced" || typeof p.finalMinor !== "number" || p.finalMinor < 0 || !p.currency)
    return "Price unavailable for " + p.requestedCountry + " · " + observation(p.observation);
  // Steam values use hundredths even for currencies displayed without decimals.
  var zero = { JPY: true, KRW: true, VND: true, CLP: true, IDR: true, COP: true, HUF: true };
  var digits = zero[p.currency] ? 0 : p.currency === "KWD" ? 3 : 2;
  var amount = (p.finalMinor / 100).toFixed(digits);
  return (
    "Saved price: " +
    amount +
    " " +
    p.currency +
    " · " +
    p.actualStoreCountry +
    "\n" +
    observation(p.observation) +
    (p.endsAt ? "\nRecorded offer end: " + p.endsAt : "")
  );
}

function metrics(game) {
  var a = game.activity;
  var r = game.reviews;
  var lines = [];
  if (a)
    lines.push(
      "Global players: " +
        (a.players === null ? "unknown" : a.players) +
        " · " +
        observation(a.observation),
    );
  if (r)
    lines.push(
      "Reviews: " +
        (r.count === null ? "unknown" : r.count) +
        (r.score === null ? "" : " · " + r.score + "% positive") +
        " · " +
        observation(r.observation),
    );
  return lines.join("\n");
}

function compactObservation(value) {
  if (!value || !value.at) return "Date unknown · " + ((value && value.freshness) || "unknown");
  var at = new Date(value.at);
  if (isNaN(at.getTime())) return "Date unknown · " + (value.freshness || "unknown");
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var hours = ("0" + at.getUTCHours()).slice(-2);
  var minutes = ("0" + at.getUTCMinutes()).slice(-2);
  return (
    at.getUTCDate() +
    " " +
    months[at.getUTCMonth()] +
    " " +
    at.getUTCFullYear() +
    ", " +
    hours +
    ":" +
    minutes +
    " UTC · " +
    (value.freshness || "unknown")
  );
}

function priceView(game) {
  var p = game.price;
  if (!p) return { amount: "Price not loaded", region: "", note: "", discount: "", priced: false };
  var valid =
    p.status === "priced" &&
    validCount(p.finalMinor) &&
    typeof p.currency === "string" &&
    /^[A-Z]{3}$/.test(p.currency);
  var region = p.actualStoreCountry || p.requestedCountry || "Country unknown";
  var note = "Saved " + compactObservation(p.observation);
  if (p.endsAt)
    note +=
      "\nRecorded offer end: " +
      compactObservation({ at: p.endsAt, freshness: "unknown" }).split(" · ")[0];
  if (!valid)
    return { amount: "Price unavailable", region: region, note: note, discount: "", priced: false };
  var zero = { JPY: true, KRW: true, VND: true, CLP: true, IDR: true, COP: true, HUF: true };
  var digits = zero[p.currency] ? 0 : p.currency === "KWD" ? 3 : 2;
  var amount = (p.finalMinor / 100).toFixed(digits) + " " + p.currency;
  var reduction =
    validCount(p.initialMinor) && p.initialMinor > p.finalMinor && p.initialMinor > 0
      ? Math.round((1 - p.finalMinor / p.initialMinor) * 100) + "% off"
      : "";
  return { amount: amount, region: region, note: note, discount: reduction, priced: true };
}

function metricView(game) {
  var rows = [];
  if (game.activity)
    rows.push({
      label: "Global players",
      value: game.activity.players === null ? "Unknown" : String(game.activity.players),
      note: compactObservation(game.activity.observation),
    });
  if (game.reviews) {
    var r = game.reviews;
    rows.push({
      label: "Reviews",
      value: r.count === null ? "Unknown" : String(r.count),
      note: (r.score === null ? "" : r.score + "% positive · ") + compactObservation(r.observation),
    });
  }
  return rows;
}

function presentationUrl(id) {
  if (!gameId(id)) throw new Error("Invalid Steam game ID.");
  return "https://gaugedb.com/api/search?q=" + id.slice(6);
}

function decodePresentation(text, id) {
  if (!gameId(id) || text.length > 262144) throw new Error("Invalid catalogue response.");
  var data = JSON.parse(text);
  if (!data || !Array.isArray(data.results)) throw new Error("Invalid catalogue response.");
  var appId = Number(id.slice(6));
  for (var i = 0; i < data.results.length; i++) {
    var item = data.results[i];
    if (!item || item.appId !== appId) continue;
    var image = typeof item.imageData === "string" ? item.imageData : "";
    // Only bounded helper-produced JPEG bytes may reach Qt; never a remote URL.
    var trusted = image.length <= 174787 && /^data:image\/jpeg;base64,\/9j\/[A-Za-z0-9+/]*={0,2}$/.test(image);
    return {
      image: trusted ? image : "",
      detail: typeof item.detail === "string" ? item.detail.slice(0, 300) : "",
    };
  }
  return { image: "", detail: "" };
}

function countText(value) {
  if (!validCount(value)) return "Unknown";
  return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function activityView(game) {
  var a = game.activity || {};
  return {
    players: countText(a.players),
    peak: countText(a.peak24),
    note: compactObservation(a.observation),
  };
}

function reviewsView(game) {
  var r = game.reviews || {};
  return {
    count: countText(r.count),
    score: validCount(r.score) && r.score <= 100 ? r.score + "%" : "Unknown",
    note: compactObservation(r.observation),
  };
}

function initialPrice(game) {
  var p = game.price;
  if (
    !p ||
    !priceView(game).priced ||
    !validCount(p.initialMinor) ||
    p.initialMinor <= p.finalMinor
  )
    return "";
  return priceView({
    price: {
      status: "priced",
      finalMinor: p.initialMinor,
      currency: p.currency,
      actualStoreCountry: p.actualStoreCountry,
      requestedCountry: p.requestedCountry,
    },
  }).amount;
}
