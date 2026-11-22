import {test,expect} from "bun:test";
import {readFileSync} from "node:fs";
import {runInNewContext} from "node:vm";
const Watch=runInNewContext(readFileSync(new URL("Watch.js",import.meta.url),"utf8")+";({quote,update,notificationText,targetAmount})");
const now=Date.now();const watch={id:"steam:620",name:"Portal 2",country:"NZ",currency:"NZD",baseline:999,last:999,observedAt:now-1000};
const game={id:"steam:620",price:{status:"priced",requestedCountry:"NZ",actualStoreCountry:"NZ",currency:"NZD",finalMinor:499,observation:{at:new Date(now).toISOString(),freshness:"fresh"}}};
test("watches deduplicate observations and reject foreign, stale and changed-currency prices",()=>{
 const changed=Watch.update(watch,game,now);expect(changed.notify).toBe(true);expect(Watch.update(changed.watch,game,now).notify).toBe(false);
 for(const price of [{...game.price,actualStoreCountry:"US"},{...game.price,currency:"USD"},{...game.price,observation:{at:new Date(now-2*86400000).toISOString(),freshness:"stale"}}]) expect(Watch.update(watch,{...game,price},now).notify).toBe(false);
 expect(Watch.notificationText("<b>Sale</b>\n")).toBe("&lt;b&gt;Sale&lt;/b&gt; ");
});

test("a target alerts once at or below its price and survives later observations", () => {
  const target = { ...watch, target: 499, targetReached: false };
  const quote = (finalMinor: number, offset: number, currency = "NZD") => ({
    ...game,
    price: { ...game.price, finalMinor, currency, observation: { ...game.price.observation, at: new Date(now + offset).toISOString() } },
  });
  const above = Watch.update(target, quote(500, 0), now);
  expect(above.notify).toBe(false);
  expect(Watch.update(above.watch, quote(499, 1, "USD"), now).notify).toBe(false);
  const hit = Watch.update(above.watch, quote(499, 1), now);
  expect(hit.notify).toBe(true);
  expect(hit.watch.targetReached).toBe(true);
  const rebounded = Watch.update(hit.watch, quote(999, 2), now);
  expect(Watch.update(rebounded.watch, quote(399, 3), now).notify).toBe(false);
  expect(Watch.update({ ...target, last: 499 }, quote(499, 0), now).notify).toBe(true);
});

test("target input parses exact hundredths, including free, and rejects invalid amounts", () => {
  expect(Watch.targetAmount("0")).toBe(0);
  expect(Watch.targetAmount(" 30,05 ")).toBe(3005);
  expect(Watch.targetAmount("21474836.47")).toBe(2147483647);
  for (const input of ["", "-1", "1.005", "1e2", "1,000.00", "21474836.48"])
    expect(Watch.targetAmount(input)).toBeNull();
});
