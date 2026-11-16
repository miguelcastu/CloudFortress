"""Offline behavior tests. No Google Cloud credentials or API calls."""

import contextlib
import importlib.util
import io
from pathlib import Path
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer


SCRIPTS = Path(__file__).resolve().parents[1] / "infra" / "terraform" / "scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


health = load("health_server")
network = load("network_probe")
storage = load("storage_probe")


class ProbeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), health.HealthHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_health_returns_200(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(network.probe(self.url + "/health", attempts=1), 0)

    def test_other_paths_do_not_serve_files(self):
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(self.url + "/etc/passwd")
        self.assertEqual(error.exception.code, 404)
        error.exception.close()

    def test_blocked_network_fails_after_retries(self):
        with patch.object(network.urllib.request, "urlopen", side_effect=TimeoutError), \
                patch.object(network.time, "sleep") as sleep, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(network.probe(self.url, attempts=3), 1)
            self.assertEqual(sleep.call_count, 2)

    def check_storage(self, statuses, expected, result):
        output = io.StringIO()
        with patch.object(storage, "access_token", return_value="secret-token"), \
                patch.object(storage, "object_status", side_effect=statuses) as reads, \
                contextlib.redirect_stdout(output):
            self.assertEqual(storage.run("allowed", "restricted", expected), result)
            self.assertEqual(reads.call_count, 2)
        self.assertNotIn("secret-token", output.getvalue())

    def test_authorized_and_restricted(self):
        self.check_storage([200, 403], 200, 0)

    def test_revoked_reader(self):
        self.check_storage([403, 403], 403, 0)

    def test_unexpected_restricted_access_fails(self):
        self.check_storage([200, 200], 200, 1)

    def test_missing_object_is_not_authorization_evidence(self):
        self.check_storage([200, 404], 200, 1)

    def test_storage_http_error_preserves_status(self):
        failure = urllib.error.HTTPError("https://storage.googleapis.com", 403, "Forbidden", {}, None)
        with patch.object(storage.urllib.request, "urlopen", side_effect=failure):
            self.assertEqual(storage.object_status("restricted", "token"), 403)


if __name__ == "__main__":
    unittest.main()
