import {test,expect} from "bun:test";
import {readFileSync} from "node:fs";
import {runInNewContext} from "node:vm";
const Watch=runInNewContext(readFileSync(new URL("Watch.js",import.meta.url),"utf8")+";({quote,update,notificationText})");
const now=Date.now();const watch={id:"steam:620",name:"Portal 2",country:"NZ",currency:"NZD",baseline:999,last:999,observedAt:now-1000};
const game={id:"steam:620",price:{status:"priced",requestedCountry:"NZ",actualStoreCountry:"NZ",currency:"NZD",finalMinor:499,observation:{at:new Date(now).toISOString(),freshness:"fresh"}}};
test("watches deduplicate observations and reject foreign, stale and changed-currency prices",()=>{
 const changed=Watch.update(watch,game,now);expect(changed.notify).toBe(true);expect(Watch.update(changed.watch,game,now).notify).toBe(false);
 for(const price of [{...game.price,actualStoreCountry:"US"},{...game.price,currency:"USD"},{...game.price,observation:{at:new Date(now-2*86400000).toISOString(),freshness:"stale"}}]) expect(Watch.update(watch,{...game,price},now).notify).toBe(false);
 expect(Watch.notificationText("<b>Sale</b>\n")).toBe("&lt;b&gt;Sale&lt;/b&gt; ");
});
