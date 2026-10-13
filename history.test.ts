import {test,expect} from "bun:test";
import {readFileSync} from "node:fs";import {runInNewContext} from "node:vm";
const History=runInNewContext(readFileSync(new URL("History.js",import.meta.url),"utf8")+";({decode})");
test("history rejects mismatched scope and keeps currencies separate",()=>{
 const data={gameId:"steam:620",requestedCountry:"NZ",actualStoreCountry:"NZ",coverage:"Saved observations",points:[{at:"2026-10-12T00:00:00Z",finalMinor:999,currency:"USD",timeBasis:"legacy"},{at:"2026-10-13T00:00:00Z",finalMinor:499,currency:"NZD",timeBasis:"observed"}]};
 const result=History.decode(JSON.stringify(data),"steam:620","NZ");expect(result.points).toHaveLength(1);expect(result.currency).toBe("NZD");expect(result.otherCurrencies).toBe(true);
 expect(()=>History.decode(JSON.stringify(data),"steam:730","NZ")).toThrow();expect(()=>History.decode(JSON.stringify(data),"steam:620","US")).toThrow();
});
