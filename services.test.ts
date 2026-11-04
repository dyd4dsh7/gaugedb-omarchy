import {expect, test} from "bun:test";
import {readFileSync} from "node:fs";
import {runInNewContext} from "node:vm";

// Run shipped service methods with deterministic transport/timer substitutes.
// Native QML parsing and event ordering remain covered by the native smoke suite.
function methods(file: string) {
  const source = readFileSync(new URL(file, import.meta.url), "utf8");
  return source.match(/^  function \w+\([^)]*\) \{(?:[^\n]*\}\n|[\s\S]*?^  \}\n)/gm)?.join("\n") || "";
}
const Model = runInNewContext(readFileSync(new URL("Model.js", import.meta.url), "utf8") + ";({decode,gameId})");
const Watch = runInNewContext(readFileSync(new URL("Watch.js", import.meta.url), "utf8") + ";({update})");
function cooldown() {
  const state: any = {until:0, remainingSeconds:0}; state.root = state;
  runInNewContext(methods("RequestCooldown.qml"), state);
  return state;
}
function service(file: string, shared = cooldown()) {
  const calls: string[][] = [];
  const values: any[] = [];
  const state: any = {
    Model, Watch, cooldown:shared, country:"NZ", queue:[], activeId:"", active:null,
    watches:[], enabled:true, notifications:[], resultStatus:"", unavailable:0, completed:0,
    outcomes:{updated:0, unchanged:0, unavailable:0, failed:0}, notificationError:"",
    next:{interval:2000, running:false, restart(){this.running=true}, stop(){this.running=false}},
    request:{busy:false, rateLimited:false, process:{running:false},
      request(args: string[]){if(this.busy || this.process.running) return false; calls.push(args); this.busy=true;this.process.running=true;return true},
      cancel(){this.busy=false}},
    notify:{running:false}, Qt:{callLater(){}},
    updated(v: any){state.watches=v;values.push(v)},
    resolved(id: string,name: string){values.push({id,name})},
  }; state.root=state;
  const qml = readFileSync(new URL(file, import.meta.url), "utf8");
  for (const name of ["busy", "status"]) {
    const expression = qml.match(new RegExp("readonly property (?:bool|string) " + name + ": ([^\\n]+)"))?.[1];
    if (!expression) throw new Error("Missing QML binding: " + name);
    Object.defineProperty(state, name, {get:()=>runInNewContext(expression, state)});
  }
  runInNewContext(methods(file), state);
  const notificationHandler = qml.match(/onExited: (function\(code, status\) \{[\s\S]*?^    \})/m)?.[1];
  const notificationExit = notificationHandler ? runInNewContext("(" + notificationHandler + ")", state) : null;
  function finish(value: string, success=true, limited=false) {
    state.request.busy=false;state.request.process.running=false;state.request.rateLimited=limited;
    state.finish(value,success);
  }
  return {state,calls,values,finish,notificationExit};
}
const names=[{id:"steam:620",name:"Steam app 620"},{id:"steam:730",name:"Steam app 730"}];
const now=Date.now();
const watch={id:"steam:620",name:"Portal 2",country:"NZ",currency:"NZD",baseline:999,last:999,observedAt:now-10000};
const reply=(price: any, games=true)=>JSON.stringify({jsonrpc:"2.0",id:1,result:{structuredContent:{coverage:"Fixture",games:games?[{id:watch.id,name:watch.name,price}]:[]}}});
const price={status:"priced",requestedCountry:"NZ",actualStoreCountry:"NZ",currency:"NZD",finalMinor:499,observation:{at:new Date(now).toISOString(),freshness:"fresh"}};

test("wishlist restart retains all IDs until cancelled child exits",()=>{
  const h=service("WishlistService.qml");
  h.state.start(names,"NZ");
  h.state.start(names,"NZ"); // cancel returns before process.running clears
  expect(h.calls).toHaveLength(1);expect(h.state.queue).toEqual(names.map(x=>x.id));
  h.state.request.process.running=false;h.state.fetchNext();
  expect(h.calls).toHaveLength(2);expect(h.state.activeId).toBe(names[0].id);
  h.finish(reply(null));expect(h.values).toEqual([{id:watch.id,name:watch.name}]);
  expect(h.state.queue).toEqual([names[1].id]);
});

test("wishlist 429 retains active item and shared cooldown prevents watch traffic",()=>{
  const shared=cooldown(), h=service("WishlistService.qml",shared), w=service("WatchService.qml",shared);
  h.state.start(names,"NZ");h.finish("",false,true);
  expect(shared.remainingSeconds).toBe(60);expect(h.state.queue).toEqual(names.map(x=>x.id));
  expect(h.state.unavailable).toBe(0);
  w.state.watches=[watch];w.state.check();h.state.fetchNext();
  expect(w.calls).toHaveLength(0);expect(h.calls).toHaveLength(1);
  shared.until=Date.now()-1;shared.refresh();h.state.fetchNext();w.state.fetchNext();
  expect(h.calls).toHaveLength(2);expect(w.calls).toHaveLength(1);
});

test("watch 429 retains unfinished checks without marking them failed",()=>{
  const h=service("WatchService.qml");h.state.watches=[watch];h.state.check();h.finish("",false,true);
  expect(h.state.queue).toEqual([watch]);expect(h.state.completed).toBe(0);
  expect(h.state.outcomes.failed).toBe(0);h.state.fetchNext();expect(h.calls).toHaveLength(1);
  h.state.cooldown.remainingSeconds=0;h.state.fetchNext();h.finish(reply(price));
  expect(h.state.outcomes.updated).toBe(1);expect(h.state.watches[0].last).toBe(499);
});

test("watch summaries distinguish updated unchanged unavailable and failed prices",()=>{
  for(const [body,success,outcome] of [[reply(price),true,"updated"],[reply({...price,finalMinor:999}),true,"unchanged"],[reply(null),true,"unavailable"],[reply(null,false),true,"unavailable"],[reply({...price,actualStoreCountry:"US"}),true,"unavailable"],[reply({...price,currency:"USD"}),true,"unavailable"],[reply({...price,observation:{at:new Date(now-2*86400000).toISOString(),freshness:"stale"}}),true,"unavailable"],["bad",true,"failed"],["",false,"failed"]] as const){
    const h=service("WatchService.qml");h.state.watches=[watch];h.state.check();h.finish(body,success);
    expect(h.state.outcomes[outcome]).toBe(1);expect(h.state.watches[0].checkedAt).toBeGreaterThanOrEqual(now);
    if(outcome!=="updated")expect(h.state.watches[0].last).toBe(999);
  }
});

test("cancelling paused work prevents resume and removed watches are skipped",()=>{
  const h=service("WishlistService.qml");h.state.start(names,"NZ");h.finish("",false,true);h.state.cancel();h.state.cooldown.remainingSeconds=0;h.state.fetchNext();expect(h.calls).toHaveLength(1);
  const w=service("WatchService.qml");w.state.watches=[watch];w.state.check();w.finish("",false,true);w.state.watches=[];w.state.cooldown.remainingSeconds=0;w.state.fetchNext();expect(w.calls).toHaveLength(1);
});


test("temporary transport rejection and late cancelled replies preserve wishlist work",()=>{
  const h=service("WishlistService.qml");
  const send=h.state.request.request;
  h.state.request.request=()=>false;
  h.state.start(names,"NZ");expect(h.state.queue).toEqual(names.map(x=>x.id));expect(h.state.unavailable).toBe(0);
  h.state.request.request=send;h.state.fetchNext();expect(h.calls).toHaveLength(1);
  h.state.cancel();h.finish(reply(null));expect(h.values).toHaveLength(0);expect(h.state.queue).toHaveLength(0);
});


test("later watch results preserve notification delivery failures",()=>{
  const h=service("WatchService.qml");h.state.watches=[watch];h.state.check();
  h.notificationExit(1,0);
  h.finish(reply(price));
  expect(h.state.status).toContain("Desktop notification could not be sent.");
  expect(h.state.outcomes.updated).toBe(1);
  h.notificationExit(0,0);expect(h.state.status).not.toContain("could not be sent");
});

test("cancelling or removing paused watches clears stale retry status",()=>{
  for (const cancel of [true,false]) {
    const h=service("WatchService.qml");h.state.watches=[watch];h.state.check();h.finish("",false,true);
    expect(h.state.status).toContain("retry");
    if(cancel)h.state.cancel();else {h.state.watches=[];h.state.fetchNext();h.state.next.stop()}
    expect(h.state.busy).toBe(false);expect(h.state.status).not.toContain("retry");
  }
});

test("manual recheck cannot replace a paused batch and restart respects shared cooldown",()=>{
  const h=service("WatchService.qml");h.state.watches=[watch];h.state.check();h.finish("",false,true);
  h.state.check();expect(h.state.queue).toEqual([watch]);expect(h.calls).toHaveLength(1);
  h.state.cancel();h.state.check();expect(h.calls).toHaveLength(1);expect(h.state.queue).toEqual([watch]);
});
