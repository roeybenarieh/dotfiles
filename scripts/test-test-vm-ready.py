"""Run with: python3 scripts/test-test-vm-ready.py"""

import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import call, patch

spec = importlib.util.spec_from_file_location("ready", Path(__file__).with_name("test-vm-ready.py"))
assert spec is not None and spec.loader is not None
ready = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ready)


class Response(io.BytesIO):
    headers: dict[str, str]


class ReadinessTests(unittest.TestCase):
    def test_waits_for_every_service(self):
        with patch.object(ready, "ssh_ready") as ssh, \
             patch.object(ready, "vnc_ready", side_effect=[OSError(), None]) as vnc, \
             patch.object(ready, "mcp_ready") as mcp, \
             patch.object(ready.os, "kill"), patch.object(ready.time, "sleep"):
            ready.wait_ready([123])
        self.assertEqual(ssh.call_count, 2)
        self.assertEqual(vnc.call_count, 2)
        self.assertEqual(mcp.call_args_list, [call(8081), call(8082)] * 2)

    def test_timeout_names_failed_service(self):
        with patch.object(ready, "ssh_ready"), patch.object(ready, "vnc_ready"), \
             patch.object(ready, "mcp_ready", side_effect=OSError()):
            with self.assertRaisesRegex(TimeoutError, "Hypruse MCP, NixOS MCP"):
                ready.wait_ready([], timeout=0)

    def test_dead_process_fails_immediately(self):
        with patch.object(ready.os, "kill", side_effect=ProcessLookupError()):
            with self.assertRaises(ProcessLookupError):
                ready.wait_ready([123])

    def test_mcp_json_and_sse_and_session_cleanup(self):
        for content_type, body in [
            ("application/json", b'{"id":1,"result":{"protocolVersion":"2025-03-26"}}'),
            ("text/event-stream", b': keepalive\n\nevent: message\ndata: {"id":1,"result":{"protocolVersion":"2025-03-26"}}\n\n'),
        ]:
            with self.subTest(content_type=content_type):
                response = Response(body)
                response.headers = {"Content-Type": content_type, "Mcp-Session-Id": "test-session"}
                with patch.object(ready.urllib.request, "urlopen", side_effect=[response, io.BytesIO()]) as request:
                    ready.mcp_ready(8081)
                self.assertEqual(request.call_args.args[0].method, "DELETE")

    def test_mcp_error_is_not_ready(self):
        response = Response(b'{"id":1,"error":{"code":-32603}}')
        response.headers = {"Content-Type": "application/json"}
        with patch.object(ready.urllib.request, "urlopen", return_value=response):
            with self.assertRaises(ValueError):
                ready.mcp_ready(8081)


if __name__ == "__main__":
    unittest.main()
