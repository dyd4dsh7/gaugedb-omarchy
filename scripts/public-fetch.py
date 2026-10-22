#!/usr/bin/env python3
"""Bounded, credential-free reads from fixed public GaugeDB/Valve endpoints."""
import base64, json, re, signal, sys, time, urllib.request, urllib.parse, urllib.error
LIMIT = 262144
IMAGE_LIMIT = 131072
class FixedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # The base handler drains redirect bodies with an unbounded fp.read().
        # Reject before it can do so, including same-origin redirects.
        if fp is not None: fp.close()
        raise ValueError("Redirects are not allowed")

def jpeg_size(raw):
    if not raw.startswith(b"\xff\xd8"): raise ValueError("Not a JPEG")
    offset = 2
    while offset < len(raw):
        if raw[offset] != 255: raise ValueError("Invalid JPEG header")
        while offset < len(raw) and raw[offset] == 255: offset += 1
        if offset >= len(raw): break
        marker = raw[offset]; offset += 1
        if marker in (0, 0xd8, 0xd9, 0xda) or 0xd0 <= marker <= 0xd7:
            raise ValueError("Missing JPEG frame")
        if offset + 2 > len(raw): break
        length = int.from_bytes(raw[offset:offset+2], "big")
        if length < 2 or offset + length > len(raw): break
        if marker in (0xc0, 0xc1, 0xc2):
            if length < 8: break
            height = int.from_bytes(raw[offset+3:offset+5], "big")
            width = int.from_bytes(raw[offset+5:offset+7], "big")
            if not 1 <= width <= 1024 or not 1 <= height <= 1024:
                raise ValueError("JPEG dimensions too large")
            return width, height
        # Other frame encodings are not supported by this capsule transport.
        if 0xc0 <= marker <= 0xcf and marker not in (0xc4, 0xc8, 0xcc): break
        offset += length
    raise ValueError("Invalid JPEG frame")

def capsule_bytes(url, budget):
    # Reserve time to emit metadata before the panel's eight-second deadline.
    # A socket timeout alone does not stop a continuously trickling response.
    def expired(signum, frame): raise TimeoutError("Image deadline")
    previous = signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, budget)
    try:
        req = urllib.request.Request(url, headers={"Accept":"image/jpeg", "User-Agent":"GaugeDB-Omarchy/0.4.4"})
        with urllib.request.build_opener(FixedRedirect()).open(req, timeout=budget) as response:
            raw = response.read(IMAGE_LIMIT+1)
        if len(raw) > IMAGE_LIMIT: raise ValueError("Image too large")
        jpeg_size(raw)
        return raw
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)

def presentation(data, app, budget=6):
    if not isinstance(data, dict) or not isinstance(data.get("results"), list):
        raise ValueError("Invalid presentation")
    for item in data["results"]:
        if not isinstance(item, dict) or type(item.get("appId")) is not int or item["appId"] != int(app): continue
        result = {"appId":int(app), "detail":item["detail"][:300] if isinstance(item.get("detail"), str) else "", "imageData":""}
        url = item.get("image")
        pattern = r"https://(?:shared\.(?:akamai|fastly)|cdn\.(?:akamai|cloudflare))\.steamstatic\.com/(?:store_item_assets/)?steam/apps/" + app + r"/(?:[a-f0-9]+/)?(?:capsule_231x87|capsule_sm_120)(?:_alt_assets_\d+)?(?:_2x)?\.jpg(?:\?[^\s]*)?"
        if budget > 0 and isinstance(url, str) and len(url) <= 2048 and re.fullmatch(pattern, url):
            try:
                raw = capsule_bytes(url, budget)
                result["imageData"] = "data:image/jpeg;base64," + base64.b64encode(raw).decode("ascii")
            except urllib.error.HTTPError as error:
                error.close()
                if error.code == 429: raise
            except Exception:
                pass  # Optional image failure must preserve the matched game detail.
        return {"results":[result]}
    return {"results":[]}

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
    started = time.monotonic()
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
    req = urllib.request.Request(url, data=body, headers={"Accept":"application/json, text/event-stream" if action in ("watch", "mcp") else "application/json", "Content-Type":"application/json", "User-Agent":"GaugeDB-Omarchy/0.4.4"})
    if action == "mcp": req.add_header("MCP-Protocol-Version", "2025-03-26")
    with urllib.request.build_opener(FixedRedirect()).open(req, timeout=12) as response:
        if action == "wishlist" and response.headers.get("x-eresult", "1") != "1":
            raise ValueError("Wishlist unavailable")
        raw = response.read(LIMIT+1)
    if len(raw) > LIMIT: raise ValueError("Response too large")
    data = json.loads(raw.decode("utf-8"))
    if action == "presentation": data = presentation(data, values[0], max(0, min(6, 7 - (time.monotonic() - started))))
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
        error.close()
        sys.exit(29 if error.code == 429 else 1)
    except Exception:
        sys.exit(1)
