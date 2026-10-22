#!/usr/bin/env python3
"""Bounded, credential-free reads from fixed public GaugeDB/Valve endpoints."""
import json, re, sys, urllib.request, urllib.parse, urllib.error
LIMIT = 262144
class FixedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        old, new = urllib.parse.urlsplit(req.full_url), urllib.parse.urlsplit(newurl)
        if new.scheme != "https" or new.netloc != old.netloc:
            raise ValueError("Unexpected redirect")
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def mcp_body(raw):
    data = json.loads(raw)
    if not isinstance(data, dict) or set(data) != {"jsonrpc", "id", "method", "params"} or data["jsonrpc"] != "2.0" or data["method"] != "tools/call":
        raise ValueError("Invalid MCP request")
    if type(data["id"]) is not int or not 0 <= data["id"] <= 9007199254740991:
        raise ValueError("Invalid request ID")
    params = data["params"]
    if not isinstance(params, dict) or set(params) != {"name", "arguments"} or not isinstance(params["arguments"], dict):
        raise ValueError("Invalid MCP parameters")
    name, args = params["name"], params["arguments"]
    def game(value):
        return isinstance(value, str) and re.fullmatch(r"steam:[1-9][0-9]{0,9}", value) and int(value[6:]) <= 2147483647
    if name == "search_games":
        if set(args) != {"query", "limit"} or not isinstance(args["query"], str) or not 1 <= len(args["query"].strip()) <= 100 or type(args["limit"]) is not int or args["limit"] != 5:
            raise ValueError("Invalid search")
    elif name in ("get_game", "find_deals", "compare_games"):
        country = args.get("country")
        if not isinstance(country, str) or not re.fullmatch(r"[A-Z]{2}", country):
            raise ValueError("Invalid country")
        if name == "get_game":
            valid = set(args) == {"id", "country"} and game(args["id"])
        elif name == "find_deals":
            valid = set(args) == {"country", "limit"} and type(args["limit"]) is int and args["limit"] == 5
        else:
            ids = args.get("ids")
            valid = set(args) == {"ids", "country"} and isinstance(ids, list) and 2 <= len(ids) <= 4 and all(game(value) for value in ids) and len(set(ids)) == len(ids)
        if not valid: raise ValueError("Invalid game request")
    else:
        raise ValueError("Unsupported MCP tool")
    return raw.encode("utf-8")

def request(args):
    action, values = args[0], args[1:]
    body = None
    if action == "mcp" and len(values) == 1:
        url = "https://gaugedb.com/integrations/public-games/mcp"
        body = mcp_body(values[0])
    elif action == "wishlist" and len(values) == 1:
        sid = values[0]
        if not re.fullmatch(r"[0-9]{17}", sid) or not 76561197960265729 <= int(sid) <= 76561202255233023:
            raise ValueError("Enter an individual SteamID64")
        url = "https://api.steampowered.com/IWishlistService/GetWishlist/v1/?steamid=" + sid
    elif action == "presentation" and len(values) == 1:
        app = values[0]
        if not re.fullmatch(r"[1-9][0-9]{0,9}", app) or int(app) > 2147483647:
            raise ValueError("Invalid game")
        url = "https://gaugedb.com/api/search?q=" + app
    elif action in ("history", "watch") and len(values) == 2:
        app, country = values
        if not re.fullmatch(r"[1-9][0-9]{0,9}", app) or int(app) > 2147483647 or not re.fullmatch(r"[A-Z]{2}", country):
            raise ValueError("Invalid game or country")
        if action == "history":
            url = "https://gaugedb.com/api/app/" + app + "/price-history?country=" + country
        else:
            url = "https://gaugedb.com/integrations/public-games/mcp"
            body = json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_game","arguments":{"id":"steam:"+app,"country":country}}}).encode()
    else:
        raise ValueError("Unsupported action")
    req = urllib.request.Request(url, data=body, headers={"Accept":"application/json, text/event-stream" if action in ("watch", "mcp") else "application/json", "Content-Type":"application/json", "User-Agent":"GaugeDB-Omarchy/0.4.2"})
    if action == "mcp": req.add_header("MCP-Protocol-Version", "2025-03-26")
    with urllib.request.build_opener(FixedRedirect()).open(req, timeout=12) as response:
        if action == "wishlist" and response.headers.get("x-eresult", "1") != "1":
            raise ValueError("Wishlist unavailable")
        raw = response.read(LIMIT+1)
    if len(raw) > LIMIT: raise ValueError("Response too large")
    data = json.loads(raw.decode("utf-8"))
    if action == "wishlist":
        items = data.get("response", {}).get("items")
        if not isinstance(items, list) or len(items) > 5000:
            raise ValueError("Wishlist private, unavailable or too large")
        ids = []
        for item in items:
            app = item.get("appid") if isinstance(item, dict) else None
            if not isinstance(app, int) or isinstance(app, bool) or not 0 < app <= 2147483647: raise ValueError("Invalid wishlist item")
            sid = "steam:" + str(app)
            if sid not in ids: ids.append(sid)
        data = {"ids":ids[:40], "total":len(ids)}
    result = json.dumps(data, separators=(",", ":"), ensure_ascii=True)
    if len(result.encode("utf-8")) > LIMIT: raise ValueError("Output too large")
    return result
def read_arguments(stream):
    raw = stream.readline(4097)
    if len(raw.encode("utf-8")) > 4096 or not raw.endswith("\n"):
        raise ValueError("Invalid request input")
    args = json.loads(raw)
    if not isinstance(args, list) or not 2 <= len(args) <= 3 or any(not isinstance(value, str) for value in args):
        raise ValueError("Invalid request arguments")
    return args

if __name__ == "__main__":
    try:
        if len(sys.argv) != 1: raise ValueError("Arguments must use stdin")
        print(request(read_arguments(sys.stdin)))
    except urllib.error.HTTPError as error:
        sys.exit(29 if error.code == 429 else 1)
    except Exception:
        sys.exit(1)
