import importlib.util, json, unittest, sys
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
