// Local watches only; prices never cross countries or currencies.
function quote(game, country, now) {
  var p = game && game.price;
  var at = p && p.observation && Date.parse(p.observation.at);
  if (!p || p.status !== "priced" || p.requestedCountry !== country || p.actualStoreCountry !== country
    || !/^[A-Z]{3}$/.test(p.currency || "") || typeof p.finalMinor !== "number"
    || !isFinite(p.finalMinor) || p.finalMinor < 0 || p.finalMinor > 2147483647 || Math.floor(p.finalMinor) !== p.finalMinor
    || !isFinite(at) || at > now + 60000 || now - at > 86400000
    || p.observation.freshness === "stale") return null;
  return { amount: p.finalMinor, currency: p.currency, at: at };
}
function update(watch, game, now) {
  if (!game || game.id !== watch.id) return { watch: watch, notify: false };
  var p = quote(game, watch.country, now);
  if (!p || p.currency !== watch.currency || p.at <= watch.observedAt) return { watch: watch, notify: false };
  return { watch: { id: watch.id, name: watch.name, country: watch.country, currency: watch.currency,
    baseline: watch.baseline, last: p.amount, observedAt: p.at }, notify: p.amount < watch.last && p.amount < watch.baseline };
}
function notificationText(value) {
  return String(value).replace(/[\x00-\x1f\x7f]/g, " ").slice(0, 500).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
