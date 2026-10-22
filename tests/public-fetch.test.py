import importlib.util, json, unittest, sys, io, subprocess
sys.dont_write_bytecode = True
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request
spec=importlib.util.spec_from_file_location("fetch",Path(__file__).parent.parent/"scripts/public-fetch.py")
fetch=importlib.util.module_from_spec(spec);spec.loader.exec_module(fetch)
class Response:
    headers={"x-eresult":"1"}
    def __init__(self,value): self.value=value
    def __enter__(self): return self
    def __exit__(self,*args): pass
    def read(self,size): return self.value[:size]
class Opener:
    def __init__(self,value): self.value=value
    def open(self,req,timeout): return Response(self.value)
class Reads(unittest.TestCase):
    def mcp(self, name="search_games", arguments=None):
        return json.dumps({"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":name,"arguments":arguments or {"query":"Portal 雪", "limit":5}}})

    def test_mcp_tools_preserve_post_body_protocol_and_fixed_origin(self):
        for name, args in [("search_games", {"query":"Portal 雪", "limit":5}), ("get_game", {"id":"steam:620","country":"NZ"}), ("find_deals", {"country":"US","limit":5}), ("compare_games", {"ids":["steam:620","steam:730"],"country":"NZ"})]:
            body = self.mcp(name, args)
            class StrictOpener:
                def open(inner, req, timeout):
                    self.assertEqual(req.full_url,"https://gaugedb.com/integrations/public-games/mcp")
                    self.assertEqual(req.get_method(),"POST")
                    self.assertEqual(req.data,body.encode())
                    self.assertEqual(req.get_header("Mcp-protocol-version"),"2025-03-26")
                    self.assertEqual(req.get_header("Accept"),"application/json, text/event-stream")
                    return Response(b'{"jsonrpc":"2.0","id":42,"result":{}}')
            with patch.object(fetch.urllib.request,"build_opener",return_value=StrictOpener()):
                self.assertEqual(json.loads(fetch.request(["mcp",body]))["id"],42)
        for name, args in [("private_tool",{}),("get_game",{"id":"steam:0","country":"NZ"}),("compare_games",{"ids":["steam:620","steam:620"],"country":"NZ"}),("find_deals",{"country":"NZ","limit":500}),("search_games",{"query":"", "limit":5})]:
            with patch.object(fetch.urllib.request,"build_opener") as network:
                with self.assertRaises(ValueError): fetch.request(["mcp",self.mcp(name,args)])
                network.assert_not_called()

    def test_mcp_rejects_oversized_input_before_response_decode_or_shell_delivery(self):
        body = self.mcp()
        real_loads = json.loads
        with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(b'x'*(fetch.LIMIT+1))), patch.object(fetch.json,"loads", wraps=real_loads) as decode:
            with self.assertRaisesRegex(ValueError,"Response too large"): fetch.request(["mcp",body])
            self.assertEqual(decode.call_count,1)  # Only trusted bounded request input parsed.
        raw = json.dumps({"result":"雪"*50000},ensure_ascii=False).encode()
        with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(raw)):
            with self.assertRaisesRegex(ValueError,"Output too large"): fetch.request(["mcp",body])

    def test_mcp_http_streams_and_errors_emit_no_unbounded_stdout(self):
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        from threading import Thread
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args): pass
            def do_POST(self):
                chunked = self.path == "/chunked"
                self.send_response(200)
                self.send_header("Transfer-Encoding" if chunked else "Content-Length", "chunked" if chunked else str(fetch.LIMIT*4))
                self.end_headers()
                try:
                    for unused in range(256):
                        self.wfile.write((b"1000\r\n" if chunked else b"")+b"x"*4096+(b"\r\n" if chunked else b""))
                    if chunked: self.wfile.write(b"0\r\n\r\n")
                except (BrokenPipeError,ConnectionResetError): pass
        server=ThreadingHTTPServer(("127.0.0.1",0),Handler)
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        script=str(Path(__file__).parent.parent/"scripts/public-fetch.py")
        try:
            for path in ["/chunked","/length"]:
                wrapper="import runpy,urllib.request; original=urllib.request.OpenerDirector.open; urllib.request.OpenerDirector.open=lambda self,req,timeout: original(self,urllib.request.Request('http://127.0.0.1:"+str(server.server_port)+path+"',data=req.data),timeout=timeout); runpy.run_path("+repr(script)+",run_name='__main__')"
                result=subprocess.run([sys.executable,"-c",wrapper],input=json.dumps(["mcp",self.mcp()])+"\n",capture_output=True,text=True,timeout=5)
                self.assertEqual(result.returncode,1)
                self.assertEqual(result.stdout+result.stderr,"")
            wrapper="import runpy,urllib.request,urllib.error; urllib.request.OpenerDirector.open=lambda *a,**k: (_ for _ in ()).throw(urllib.error.HTTPError('https://gaugedb.com',429,'limited',{},None)); runpy.run_path("+repr(script)+",run_name='__main__')"
            result=subprocess.run([sys.executable,"-c",wrapper],input=json.dumps(["mcp",self.mcp()])+"\n",capture_output=True,text=True)
            self.assertEqual(result.returncode,29)
            self.assertEqual(result.stdout+result.stderr,"")
        finally:
            server.shutdown();server.server_close();thread.join()

    def jpeg(self, width=231, height=87):
        return b"\xff\xd8\xff\xc0\x00\x0b\x08"+height.to_bytes(2,"big")+width.to_bytes(2,"big")+b"\x01\x01\x11\x00\xff\xd9"

    def test_capsule_bytes_are_bounded_and_only_jpeg_data_reaches_shell(self):
        import base64
        url="https://shared.akamai.steamstatic.com/steam/apps/620/capsule_231x87.jpg"
        metadata={"results":[{"appId":730,"image":url},{"appId":620,"detail":"Valve","image":url,"imageData":"data:image/svg+xml,bad"}]}
        seen=[]
        raw=self.jpeg()
        class ImageOpener:
            def open(inner,req,timeout):
                seen.append(req.full_url)
                return Response(json.dumps(metadata).encode() if len(seen)==1 else raw)
        with patch.object(fetch.urllib.request,"build_opener",return_value=ImageOpener()):
            item=json.loads(fetch.request(["presentation","620"]))["results"][0]
        self.assertEqual(seen,["https://gaugedb.com/api/search?q=620",url])
        self.assertEqual(base64.b64decode(item["imageData"].split(",")[1]),raw)
        self.assertNotIn("image",item)
        for raw in [b"x"*(fetch.IMAGE_LIMIT+1),self.jpeg(65535,65535),b"<svg></svg>",b"\xff\xd8",self.jpeg(0,1)]:
            seen.clear()
            with patch.object(fetch.urllib.request,"build_opener",return_value=ImageOpener()):
                item=json.loads(fetch.request(["presentation","620"]))["results"][0]
                self.assertEqual(item,{"appId":620,"detail":"Valve","imageData":""})
        for invalid in [url.replace("/620/","/730/"),url.replace("shared.akamai.steamstatic.com","example.com"),"file:///private/file","data:image/jpeg;base64,/9j/"]:
            metadata["results"][1]["image"]=invalid
            seen.clear()
            with patch.object(fetch.urllib.request,"build_opener",return_value=ImageOpener()):
                self.assertEqual(json.loads(fetch.request(["presentation","620"]))["results"][0]["imageData"],"")
            self.assertEqual(len(seen),1)

    def test_streamed_capsules_stop_at_image_limit_and_preserve_detail(self):
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        from threading import Thread
        url="https://shared.akamai.steamstatic.com/steam/apps/620/capsule_231x87.jpg"
        reads=[]
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args): pass
            def do_GET(self):
                self.send_response(200)
                if self.path == "/metadata":
                    body=json.dumps({"results":[{"appId":620,"detail":"Valve","image":url}]}).encode()
                    self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body);return
                self.send_header("Transfer-Encoding","chunked");self.end_headers()
                try:
                    for unused in range(1024): self.wfile.write(b"1000\r\n"+b"x"*4096+b"\r\n")
                    self.wfile.write(b"0\r\n\r\n")
                except (BrokenPipeError,ConnectionResetError): pass
        server=ThreadingHTTPServer(("127.0.0.1",0),Handler)
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        real=fetch.urllib.request.build_opener()
        class LocalOpener:
            def open(inner,req,timeout):
                path="/metadata" if req.full_url=="https://gaugedb.com/api/search?q=620" else "/image"
                if path=="/image": self.assertEqual(req.full_url,url)
                response=real.open("http://127.0.0.1:"+str(server.server_port)+path,timeout=timeout)
                original=response.read
                def bounded(size): reads.append(size);return original(size)
                response.read=bounded
                return response
        try:
            with patch.object(fetch.urllib.request,"build_opener",return_value=LocalOpener()):
                self.assertEqual(json.loads(fetch.request(["presentation","620"]))["results"][0],{"appId":620,"detail":"Valve","imageData":""})
            self.assertEqual(reads,[fetch.LIMIT+1,fetch.IMAGE_LIMIT+1])
        finally:
            server.shutdown();server.server_close();thread.join()

    def test_real_jpeg_control_and_image_rate_limit(self):
        raw=(Path(__file__).parent/"capsule.jpg").read_bytes()
        self.assertEqual(fetch.jpeg_size(raw),(1,1))
        url="https://cdn.cloudflare.steamstatic.com/steam/apps/620/capsule_sm_120.jpg"
        metadata={"results":[{"appId":620,"detail":"Valve","image":url}]}
        with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(raw)):
            result=fetch.presentation(metadata,"620")
        self.assertTrue(result["results"][0]["imageData"].startswith("data:image/jpeg;base64,/9j/"))
        with patch.object(fetch.urllib.request,"build_opener") as factory:
            factory.return_value.open.side_effect=fetch.urllib.error.HTTPError(url,429,"limited",{},None)
            with self.assertRaises(fetch.urllib.error.HTTPError): fetch.presentation(metadata,"620")

    def test_slow_image_deadline_preserves_detail_within_remaining_budget(self):
        import time
        metadata={"results":[{"appId":620,"detail":"Valve","image":"https://shared.akamai.steamstatic.com/steam/apps/620/capsule_231x87.jpg"}]}
        class SlowImage:
            def open(self,*args,**kwargs): time.sleep(1);raise AssertionError("Image deadline did not fire")
        started=time.monotonic()
        with patch.object(fetch.urllib.request,"build_opener",return_value=SlowImage()):
            result=fetch.presentation(metadata,"620",0.05)
        self.assertEqual(result["results"][0],{"appId":620,"detail":"Valve","imageData":""})
        self.assertLess(time.monotonic()-started,0.5)
        with patch.object(fetch.time,"monotonic",side_effect=[10,16.5]), patch.object(fetch.urllib.request,"build_opener",return_value=Opener(json.dumps(metadata).encode())), patch.object(fetch,"capsule_bytes",side_effect=TimeoutError) as image:
            self.assertEqual(json.loads(fetch.request(["presentation","620"]))["results"][0]["detail"],"Valve")
            self.assertEqual(image.call_args.args[1],0.5)
        with patch.object(fetch.urllib.request,"build_opener") as network:
            self.assertEqual(fetch.presentation(metadata,"620",0)["results"][0]["detail"],"Valve")
            network.assert_not_called()

    def test_all_redirect_statuses_close_without_reading_any_body(self):
        class Body:
            closed=False
            def read(self,*args): raise AssertionError("redirect body must never be read")
            def close(self): self.closed=True
        for code in [301,302,303,307,308]:
            for location in ["https://gaugedb.com/next","https://example.com/next"]:
                body=Body()
                handler=fetch.FixedRedirect()
                callback=getattr(handler,"http_error_"+str(code))
                with self.assertRaisesRegex(ValueError,"Redirects are not allowed"):
                    callback(Request("https://gaugedb.com/test"),body,code,"redirect",{"location":location})
                self.assertTrue(body.closed)

    def test_artwork_uses_fixed_origin_and_bounds_bytes_before_decode(self):
        seen = {}
        class BoundedResponse(Response):
            def read(self, size):
                seen["size"] = size
                return b"x" * size
        class BoundedOpener:
            def open(self, req, timeout):
                seen["url"] = req.full_url
                return BoundedResponse(b"")
        with patch.object(fetch.urllib.request, "build_opener", return_value=BoundedOpener()), patch.object(fetch.json, "loads") as decode:
            with self.assertRaisesRegex(ValueError, "Response too large"):
                fetch.request(["presentation", "620"])
            decode.assert_not_called()
        self.assertEqual(seen, {"url":"https://gaugedb.com/api/search?q=620", "size":fetch.LIMIT+1})
        for app in ["0", "0620", "2147483648", "620?url=https://example.com", "../620"]:
            with self.assertRaises(ValueError): fetch.request(["presentation", app])

    def test_artwork_valid_metadata_and_output_expansion_limit(self):
        raw = b'{"results":[{"appId":620,"detail":"Valve"}]}'
        with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(raw)):
            self.assertEqual(json.loads(fetch.request(["presentation","620"]))["results"][0]["appId"],620)
        raw = json.dumps({"results":[],"extra":"\u00e9"*60000},ensure_ascii=False).encode()
        with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(raw)):
            self.assertEqual(json.loads(fetch.request(["presentation","620"])), {"results":[]})

    def test_artwork_chunked_http_is_bounded_before_json_decode(self):
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        from threading import Thread
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args): pass
            def do_GET(self):
                self.send_response(200)
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                try:
                    for unused in range(1024):
                        self.wfile.write(b"1000\r\n" + b"x"*4096 + b"\r\n")
                    self.wfile.write(b"0\r\n\r\n")
                except (BrokenPipeError, ConnectionResetError): pass
        server = ThreadingHTTPServer(("127.0.0.1",0),Handler)
        thread = Thread(target=server.serve_forever,daemon=True); thread.start()
        real_opener = fetch.urllib.request.build_opener()
        class LocalOpener:
            def open(self, req, timeout):
                assert req.full_url == "https://gaugedb.com/api/search?q=620"
                return real_opener.open("http://127.0.0.1:"+str(server.server_port),timeout=timeout)
        try:
            with patch.object(fetch.urllib.request,"build_opener",return_value=LocalOpener()), patch.object(fetch.json,"loads") as decode:
                with self.assertRaisesRegex(ValueError,"Response too large"): fetch.request(["presentation","620"])
                decode.assert_not_called()
        finally:
            server.shutdown(); server.server_close(); thread.join()

    def test_rate_limit_exits_with_bounded_status_and_no_body(self):
        script = str(Path(__file__).parent.parent/"scripts/public-fetch.py")
        wrapper = "import runpy,urllib.request,urllib.error; urllib.request.OpenerDirector.open=lambda *a,**k: (_ for _ in ()).throw(urllib.error.HTTPError('https://gaugedb.com',429,'rate limited',{},None)); runpy.run_path("+repr(script)+",run_name='__main__')"
        result = subprocess.run([sys.executable,"-c",wrapper],input='["presentation","620"]\n',capture_output=True,text=True)
        self.assertEqual(result.returncode,29)
        self.assertEqual(result.stdout+result.stderr,"")

    def test_private_request_inputs_use_bounded_stdin(self):
        self.assertEqual(fetch.read_arguments(io.StringIO('["watch","620","NZ"]\n')), ["watch","620","NZ"])
        for raw in ['["watch","620","NZ"]', '["watch",620,"NZ"]\n', '{}\n', '["watch","'+"x"*4100+'","NZ"]\n']:
            with self.assertRaises(ValueError): fetch.read_arguments(io.StringIO(raw))

    def test_cli_arguments_are_rejected_without_disclosing_input(self):
        result = subprocess.run([sys.executable, str(Path(__file__).parent.parent/"scripts/public-fetch.py"), "watch", "620", "NZ"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout + result.stderr, "")

    def test_watch_negotiates_the_public_mcp_media_types(self):
        class StrictMcpOpener:
            def open(self,req,timeout):
                accepted={value.strip() for value in req.get_header("Accept", "").split(",")}
                if not {"application/json","text/event-stream"}.issubset(accepted):
                    raise ValueError("MCP endpoint rejects incomplete Accept negotiation")
                return Response(b'{"jsonrpc":"2.0","id":1,"result":{}}')
        with patch.object(fetch.urllib.request,"build_opener",return_value=StrictMcpOpener()):
            self.assertEqual(json.loads(fetch.request(["watch","620","US"]))["id"],1)

    def test_public_wishlist_caps_import_without_saving_account_id(self):
        raw=json.dumps({"response":{"items":[{"appid":i} for i in range(1,42)]}}).encode()
        with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(raw)):
            value=json.loads(fetch.request(["wishlist","76561197960265729"]))
        self.assertEqual(len(value["ids"]),40);self.assertEqual(value["total"],41)
        self.assertNotIn("76561197960265729",json.dumps(value))
    def test_unavailable_and_oversized_results_fail_closed(self):
        for raw in [b'{"response":{}}',b'x'*(fetch.LIMIT+1),b'{"response":{"items":[{"appid":true}]}}']:
            with patch.object(fetch.urllib.request,"build_opener",return_value=Opener(raw)):
                with self.assertRaises((ValueError,TypeError)): fetch.request(["wishlist","76561197960265729"])
    def test_ids_and_cross_origin_redirects_are_rejected(self):
        for args in [["wishlist","../../private"],["watch","620;echo","NZ"],["history","620","NZ?token=secret"]]:
            with self.assertRaises(ValueError): fetch.request(args)
        with self.assertRaises(ValueError): fetch.FixedRedirect().redirect_request(Request("https://gaugedb.com/test"),None,302,"",{},"https://example.com/test")
if __name__=="__main__": unittest.main()
