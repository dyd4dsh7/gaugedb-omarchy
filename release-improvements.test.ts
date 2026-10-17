import {expect,test} from "bun:test";
import {readFileSync} from "node:fs";
import {runInNewContext} from "node:vm";
function module(name:string, exports:string) { return runInNewContext(readFileSync(new URL(name,import.meta.url),"utf8")+`;({${exports}})`); }
const Store=module("Store.js","empty,importWishlist,wishlistName,encode,read");
const Model=module("Model.js","request,decode");
const Countries=module("Countries.js","supported");
const Watch=module("Watch.js","update");
const History=module("History.js","decode,summary,dateLabel");
test("wishlist names persist across imports, reject invalid identities and cannot add removed games",()=>{
 let data=Store.empty(); data.favourites=[{id:"steam:620",name:"Portal 2"}];
 data=Store.importWishlist(data,["steam:620","steam:730"]);
 expect(data.wishlist[0].name).toBe("Portal 2");
 data=Store.wishlistName(data,"steam:730","Counter-Strike 2");
 data=Store.importWishlist(data,["steam:730"]);
 data=Store.wishlistName(data,"steam:620","Late reply");
 expect(data.wishlist).toEqual([{id:"steam:730",name:"Counter-Strike 2"}]);
 expect(Store.wishlistName(data,"steam:620","")).toBe(data);
 expect(Store.read(Store.encode(data),Model,Countries).wishlist).toEqual(data.wishlist);
 expect(()=>Store.wishlistName(data,"steam:730"," ")).toThrow();
 expect(()=>Store.importWishlist(data,["steam:730","steam:730"])).toThrow();
});
test("watch history survives repeated observations and saved-state migration",()=>{
 const now=Date.now();const old={id:"steam:620",name:"Portal 2",country:"NZ",currency:"NZD",baseline:999,last:999,observedAt:now-10000};
 const game={id:old.id,price:{status:"priced",requestedCountry:"NZ",actualStoreCountry:"NZ",currency:"NZD",finalMinor:499,observation:{at:new Date(now-1000).toISOString(),freshness:"fresh"}}};
 const drop=Watch.update(old,game,now);expect(drop.notify).toBe(true);expect(drop.watch.previous).toBe(999);
 const repeated=Watch.update(drop.watch,game,now+1000);expect(repeated.notify).toBe(false);expect(repeated.watch.previous).toBe(999);expect(repeated.watch.checkedAt).toBe(now+1000);
 const data=Store.empty();data.watches=[repeated.watch];
 expect(Store.read(Store.encode(data),Model,Countries).watches[0].previous).toBe(999);
 data.watches=[old];expect(Store.read(Store.encode(data),Model,Countries).watches[0].previous).toBe(999);
 data.watches=[{...old,checkedAt:now+3600000}];expect(()=>Store.encode(data)).toThrow();
});
test("history summary uses only the selected currency and supports one observation",()=>{
 const data={gameId:"steam:620",requestedCountry:"NZ",actualStoreCountry:"NZ",coverage:"Partial",points:[{at:"2026-10-12T00:00:00Z",finalMinor:1,currency:"USD",timeBasis:"legacy"},{at:"2026-10-13T00:00:00Z",finalMinor:499,currency:"NZD",timeBasis:"observed"}]};
 const decoded=History.decode(JSON.stringify(data),"steam:620","NZ");
 expect(History.summary(decoded)).toContain("4.99 NZD");expect(History.summary(decoded)).not.toContain("USD");expect(History.dateLabel(decoded.points[0].at)).toBe("2026-10-13");expect(History.summary({points:[]})).toBe("No saved observations");
});
