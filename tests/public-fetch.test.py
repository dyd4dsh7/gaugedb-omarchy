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
            with self.assertRaisesRegex(ValueError,"Output too large"): fetch.request(["presentation","620"])

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
