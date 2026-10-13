function decode(text, id, country) {
  if (text.length > 262144) throw new Error("History too large");
  var data = JSON.parse(text);
  if (data.gameId !== id || data.requestedCountry !== country || !/^[A-Z]{2}$/.test(data.actualStoreCountry || "") || !Array.isArray(data.points) || data.points.length > 100 || typeof data.coverage !== "string" || data.coverage.length > 1000) throw new Error("Unexpected history");
  data.points.forEach(function(p) {
    if (!p || !/^[A-Z]{3}$/.test(p.currency || "") || !isFinite(Date.parse(p.at)) || typeof p.finalMinor !== "number" || !isFinite(p.finalMinor) || p.finalMinor < 0 || p.finalMinor > 2147483647 || Math.floor(p.finalMinor) !== p.finalMinor || ["legacy", "observed"].indexOf(p.timeBasis) === -1) throw new Error("Invalid history point");
  });
  var sorted = data.points.slice().sort(function(a,b) { return Date.parse(a.at) - Date.parse(b.at); });
  var currency = sorted.length ? sorted[sorted.length-1].currency : "";
  var points = sorted.filter(function(p) { return p.currency === currency; });
  return {currency:currency,points:points,actualStoreCountry:data.actualStoreCountry,coverage:data.coverage,otherCurrencies:sorted.length !== points.length,hasLegacy:points.some(function(p) { return p.timeBasis === "legacy" })};
}
function amount(value, currency) {
  var zero = ["JPY", "KRW", "VND", "CLP", "IDR", "COP", "HUF"];
  return (value/100).toFixed(zero.indexOf(currency) >= 0 ? 0 : currency === "KWD" ? 3 : 2) + " " + currency;
}
