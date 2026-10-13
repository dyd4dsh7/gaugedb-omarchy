// biome-ignore-all lint/correctness/noUnusedVariables: QML imports this local persistence model.
// Public catalogue data only. Never store credentials, cookies or private account responses.
function empty() {
  return { version: 1, country: "", startView: "", watches: [], wishlist: [], backgroundWatches: false, favourites: [], recent: [], cache: [] };
}
function identity(game) {
  if (
    !game ||
    typeof game.id !== "string" ||
    !/^steam:[1-9]\d{0,9}$/.test(game.id) ||
    Number(game.id.slice(6)) > 2147483647 ||
    typeof game.name !== "string" ||
    game.name.length > 300
  )
    throw new Error("Invalid saved game.");
  return { id: game.id, name: game.name };
}
function identities(items, limit) {
  if (!Array.isArray(items) || items.length > limit) throw new Error("Invalid saved games.");
  var result = items.map(identity);
  if (
    result.some(function (item, i) {
      return result.slice(0, i).some(function (previous) {
        return previous.id === item.id;
      });
    })
  )
    throw new Error("Duplicate saved game.");
  return result;
}
function watches(items, registry) {
  if (!Array.isArray(items) || items.length > 10) throw new Error("Invalid price watches.");
  var result = items.map(function (value) {
    var game = identity(value);
    if (!/^[A-Z]{2}$/.test(value.country || "") || (registry && !registry.supported(value.country))
      || !/^[A-Z]{3}$/.test(value.currency || "")
      || [value.baseline, value.last].some(function(n) { return typeof n !== "number" || !isFinite(n) || n < 0 || Math.floor(n) !== n || n > 2147483647; })
      || typeof value.observedAt !== "number" || !isFinite(value.observedAt) || value.observedAt <= 0 || value.observedAt > Date.now() + 60000)
      throw new Error("Invalid price watch.");
    return { id: game.id, name: game.name, country: value.country, currency: value.currency, baseline: value.baseline, last: value.last, observedAt: value.observedAt };
  });
  if (result.some(function(value,i) { return result.slice(0,i).some(function(old) { return value.id === old.id && value.country === old.country; }); })) throw new Error("Duplicate price watch.");
  return result;
}
function key(body) {
  var request = JSON.parse(body);
  return JSON.stringify(request.params);
}
function publicResult(result) {
  return {
    games: result.games.map(function (game) {
      return {
        id: game.id,
        name: game.name,
        metadata: game.metadata,
        activity: game.activity,
        reviews: game.reviews,
        price: game.price,
      };
    }),
    coverage: result.coverage,
    missingIds: result.missingIds || [],
  };
}
function read(text, model, registry) {
  if (typeof text !== "string" || text.length > 1048576)
    throw new Error("Saved data is too large.");
  var data = JSON.parse(text);
  if (
    !data ||
    data.version !== 1 ||
    (data.country !== "" && !registry.supported(data.country)) ||
    (data.startView !== undefined && ["", "search", "saved", "deals"].indexOf(data.startView) === -1) ||
    (data.backgroundWatches !== undefined && typeof data.backgroundWatches !== "boolean") ||
    !Array.isArray(data.cache) ||
    data.cache.length > 20
  )
    throw new Error("Unsupported saved data.");
  var result = {
    version: 1,
    country: data.country,
    startView: data.startView || "",
    watches: watches(data.watches === undefined ? [] : data.watches, registry),
    wishlist: identities(data.wishlist === undefined ? [] : data.wishlist, 40),
    backgroundWatches: data.backgroundWatches === true,
    favourites: identities(data.favourites, 40),
    recent: identities(data.recent, 12),
    cache: [],
  };
  result.cache = data.cache.map(function (entry) {
    if (
      !entry ||
      typeof entry.key !== "string" ||
      entry.key.length > 1000 ||
      typeof entry.savedAt !== "number" ||
      !isFinite(entry.savedAt) ||
      entry.savedAt <= 0 ||
      entry.savedAt > Date.now() + 60000
    )
      throw new Error("Invalid cached summary.");
    var params = JSON.parse(entry.key);
    if (!params || params.name === undefined || !params.arguments)
      throw new Error("Invalid cached request.");
    var canonical = key(model.request(params.name, params.arguments, 0));
    if (canonical !== entry.key) throw new Error("Invalid cached request.");
    var args = params.arguments;
    var decoded = model.decode(
      JSON.stringify({ jsonrpc: "2.0", id: 0, result: { structuredContent: entry.result } }),
      0,
      { gameId: args.id, ids: args.ids, country: args.country },
    );
    return { key: canonical, savedAt: entry.savedAt, result: publicResult(decoded) };
  });
  return result;
}
function encode(data) {
  var next = {
    version: 1,
    country: data.country,
    startView: data.startView || "",
    watches: watches(data.watches || []),
    wishlist: identities(data.wishlist === undefined ? [] : data.wishlist, 40),
    backgroundWatches: data.backgroundWatches === true,
    favourites: identities(data.favourites, 40),
    recent: identities(data.recent, 12),
    cache: data.cache.slice(0, 20),
  };
  while (JSON.stringify(next).length > 1048576 && next.cache.length) next.cache.pop();
  return JSON.stringify(next);
}
function toggle(data, game) {
  var item = identity(game);
  var next = Object.assign({}, data);
  if (
    data.favourites.some(function (value) {
      return value.id === item.id;
    })
  )
    next.favourites = data.favourites.filter(function (value) {
      return value.id !== item.id;
    });
  else {
    if (data.favourites.length >= 40) throw new Error("You can save up to 40 favourites.");
    next.favourites = [item].concat(data.favourites);
  }
  return next;
}
function remember(data, game) {
  var next = Object.assign({}, data);
  var item = identity(game);
  next.recent = [item]
    .concat(
      data.recent.filter(function (value) {
        return value.id !== item.id;
      }),
    )
    .slice(0, 12);
  return next;
}
function put(data, body, result, now) {
  var next = Object.assign({}, data);
  var requestKey = key(body);
  next.cache = [{ key: requestKey, savedAt: now, result: publicResult(result) }]
    .concat(
      data.cache.filter(function (entry) {
        return entry.key !== requestKey;
      }),
    )
    .slice(0, 20);
  return next;
}
function get(data, body, now) {
  var requestKey = key(body);
  var entry = data.cache.filter(function (value) {
    return (
      value.key === requestKey &&
      now - value.savedAt <= 30 * 86400000 &&
      value.savedAt <= now + 60000
    );
  })[0];
  if (!entry) return null;
  var result = JSON.parse(JSON.stringify(entry.result));
  result.games.forEach(function (game) {
    [
      game.metadata,
      game.activity && game.activity.observation,
      game.reviews && game.reviews.observation,
      game.price && game.price.observation,
    ].forEach(function (observation) {
      if (observation) observation.freshness = observation.at ? "stale" : "unknown";
    });
  });
  return { result: result, savedAt: entry.savedAt };
}
function savedGames(data, section) {
  var items = section === "wishlist" ? (data.wishlist || []) : section === "recent" ? data.recent : data.favourites;
  return items.map(function (item) {
    return { id: item.id, name: item.name, price: null };
  });
}
function mergeLoaded(loaded, current) {
  var next = Object.assign({}, loaded);
  next.country = current.country || loaded.country;
  next.startView = current.startView || loaded.startView || "";
  next.recent = current.recent
    .concat(
      loaded.recent.filter(function (game) {
        return !current.recent.some(function (item) {
          return item.id === game.id;
        });
      }),
    )
    .slice(0, 12);
  next.cache = current.cache
    .concat(
      loaded.cache.filter(function (entry) {
        return !current.cache.some(function (item) {
          return item.key === entry.key;
        });
      }),
    )
    .slice(0, 20);
  return next;
}
