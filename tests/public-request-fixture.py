#!/usr/bin/env python3
# Disposable native test provider. Inputs must arrive via stdin, never argv.
import base64, json, sys
from pathlib import Path
from datetime import datetime, timezone
assert len(sys.argv) == 1
args = json.loads(sys.stdin.readline(4097))
if args[0] == "mcp":
    request = json.loads(args[1])
    values = request["params"]["arguments"]
    if values.get("query") == "limited": sys.exit(29)
    if values.get("query") == "slow":
        import time, signal
        def delayed_exit(*args):
            time.sleep(0.3)
            sys.exit(1)
        signal.signal(signal.SIGTERM, delayed_exit)
        time.sleep(1.0)
    ids = values.get("ids", [values.get("id", "steam:620")])
    result = {"jsonrpc":"2.0","id":request["id"],"result":{"structuredContent":{"coverage":"Controlled MCP","games":[{"id":game,"name":"Controlled MCP game"} for game in ids]}}}
elif args[0] == "presentation":
    if args[1] == "730": sys.exit(29)
    if args[1] == "440":
        import time, signal
        def delayed_exit(*args):
            time.sleep(0.3)
            sys.exit(1)
        signal.signal(signal.SIGTERM, delayed_exit)
        time.sleep(1.0)
    result = {"results":[{"appId":int(args[1]),"detail":"Controlled artwork", "imageData":"data:image/jpeg;base64,"+base64.b64encode((Path(__file__).parent/"capsule.jpg").read_bytes()).decode()}]}
elif args == ["wishlist", "76561197960265729"]:
    result = {"ids": ["steam:730", "steam:440"], "total": 2}
elif args[0] == "watch" and args[1] in ["730", "440"] and args[2] == "NZ":
    result = {"jsonrpc":"2.0","id":1,"result":{"structuredContent":{"coverage":"Controlled names","games":[{"id":"steam:"+args[1],"name":"Counter-Strike 2" if args[1] == "730" else "Team Fortress 2"}]}}}
else:
    assert args == ["watch", "620", "NZ"]
    result = {"jsonrpc":"2.0","id":1,"result":{"structuredContent":{"coverage":"Controlled fixture","games":[{"id":"steam:620","name":"PRIVATE WATCH NAME","price":{"status":"priced","requestedCountry":"NZ","actualStoreCountry":"NZ","currency":"NZD","finalMinor":499,"observation":{"at":datetime.now(timezone.utc).isoformat(),"freshness":"fresh"}}}]}}}
print(json.dumps(result))
