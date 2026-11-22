// Local watches only; prices never cross countries or currencies.
function targetAmount(input) {
  var parts = /^(\d{1,8})(?:[.,](\d{1,2}))?$/.exec(input.trim());
  if (!parts) return null;
  var minor = Number(parts[1]) * 100 + Number(((parts[2] || "") + "00").slice(0, 2));
  return minor <= 2147483647 ? minor : null;
}
function targetInput(amount) {
  return (amount / 100).toFixed(2);
}
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
  if (!game || game.id !== watch.id) return { watch: Object.assign({}, watch, {checkedAt:now}), notify: false, outcome: "unavailable" };
  var p = quote(game, watch.country, now);
  if (!p || p.currency !== watch.currency) return { watch: Object.assign({}, watch, {checkedAt:now}), notify: false, outcome: "unavailable" };
  if (p.at <= watch.observedAt) return {watch:Object.assign({}, watch, {checkedAt:now}), notify:false, outcome:"unchanged"};
  var changed = p.amount !== watch.last;
  var next = Object.assign({}, watch, {
    last: p.amount, observedAt: p.at, checkedAt: now,
    previous: changed || watch.previous === undefined ? watch.last : watch.previous,
  });
  var notify = p.amount < watch.last && p.amount < watch.baseline;
  if (watch.target !== undefined) {
    notify = !watch.targetReached && p.amount <= watch.target;
    next.targetReached = watch.targetReached || notify;
  }
  return { watch: next, outcome: changed ? "updated" : "unchanged", notify: notify };
}
function notificationText(value) {
  return String(value).replace(/[\x00-\x1f\x7f]/g, " ").slice(0, 500).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
