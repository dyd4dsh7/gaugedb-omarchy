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

def request(args):
    action, values = args[0], args[1:]
    body = None
    if action == "wishlist" and len(values) == 1:
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
    req = urllib.request.Request(url, data=body, headers={"Accept":"application/json, text/event-stream" if action == "watch" else "application/json", "Content-Type":"application/json", "User-Agent":"GaugeDB-Omarchy/0.4.1"})
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
