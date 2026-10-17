#!/usr/bin/env python3
# Disposable native test provider. Inputs must arrive via stdin, never argv.
import json, sys
from datetime import datetime, timezone
assert len(sys.argv) == 1
args = json.loads(sys.stdin.readline(4097))
if args == ["wishlist", "76561197960265729"]:
    result = {"ids": ["steam:730", "steam:440"], "total": 2}
elif args[0] == "watch" and args[1] in ["730", "440"] and args[2] == "NZ":
    result = {"jsonrpc":"2.0","id":1,"result":{"structuredContent":{"coverage":"Controlled names","games":[{"id":"steam:"+args[1],"name":"Counter-Strike 2" if args[1] == "730" else "Team Fortress 2"}]}}}
else:
    assert args == ["watch", "620", "NZ"]
    result = {"jsonrpc":"2.0","id":1,"result":{"structuredContent":{"coverage":"Controlled fixture","games":[{"id":"steam:620","name":"PRIVATE WATCH NAME","price":{"status":"priced","requestedCountry":"NZ","actualStoreCountry":"NZ","currency":"NZD","finalMinor":499,"observation":{"at":datetime.now(timezone.utc).isoformat(),"freshness":"fresh"}}}]}}}
print(json.dumps(result))
