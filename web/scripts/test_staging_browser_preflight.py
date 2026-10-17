"""Stale deployments and missing providers cannot produce a green browser gate."""

import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("staging_browser", Path(__file__).with_name("validate_lyo_one_staging_browser.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class BrowserPreflightTests(unittest.TestCase):
    def setUp(self):
        env = patch.dict(os.environ, {
            "LYO_ONE_STAGING_BROWSER": "1",
            "LYO_ONE_EXPECTED_BACKEND_SHA": "a" * 40,
            "LYO_ONE_EXPECTED_CLIENT_SHA": "b" * 40,
            "LYO_ONE_TEST_PREP_PROVIDER_READY": "no",
        })
        env.start()
        self.addCleanup(env.stop)

    def health(self, *, sha="a" * 40, provider=True):
        return {"environment": "staging", "commit_sha": sha,
                "services": {"ai": {"models": {"gemini-2.5-flash": {"configured": provider}}}}}

    def client(self, sha="b" * 40):
        return io.BytesIO(json.dumps({"commit": sha}).encode())

    def test_both_live_revisions_match_the_intended_pair(self):
        with patch.object(runner, "request", return_value=self.health()), \
                patch.object(runner.urllib.request, "urlopen", return_value=self.client()):
            self.assertEqual(runner.verify_deployed_pair(), ("a" * 40, "b" * 40))

    def test_healthy_previous_backend_is_rejected(self):
        with patch.object(runner, "request", return_value=self.health(sha="c" * 40)), \
                patch.object(runner.urllib.request, "urlopen", return_value=self.client()), \
                self.assertRaisesRegex(AssertionError, "pair mismatch"):
            runner.verify_deployed_pair()

    def test_healthy_previous_client_is_rejected(self):
        with patch.object(runner, "request", return_value=self.health()), \
                patch.object(runner.urllib.request, "urlopen", return_value=self.client("c" * 40)), \
                self.assertRaisesRegex(AssertionError, "pair mismatch"):
            runner.verify_deployed_pair()

    def test_provider_gate_stops_before_creating_a_learner_when_gemini_is_missing(self):
        with patch.dict(os.environ, {"LYO_ONE_TEST_PREP_PROVIDER_READY": "yes"}), \
                patch.object(runner, "request", return_value=self.health(provider=False)), \
                patch.object(runner.urllib.request, "urlopen", return_value=self.client()), \
                patch.object(runner, "new_learner") as create, \
                self.assertRaisesRegex(RuntimeError, "separate staging Gemini key"):
            runner.run()
        create.assert_not_called()

    def test_missing_or_partial_revision_is_rejected_without_network_access(self):
        for key in ("LYO_ONE_EXPECTED_BACKEND_SHA", "LYO_ONE_EXPECTED_CLIENT_SHA"):
            with self.subTest(key=key), patch.dict(os.environ, {key: "aaaaaaa"}), \
                    patch.object(runner, "request") as request, \
                    self.assertRaises(ValueError):
                runner.verify_deployed_pair()
            request.assert_not_called()

    def test_incomplete_real_intake_cannot_be_replaced_with_a_seeded_plan(self):
        with patch.object(runner, "request", side_effect=[{"profile_id": "exam-a"}, {},
                         {"test_profile_id": "exam-a", "intake_complete": False}]) as request, \
                self.assertRaisesRegex(AssertionError, "intake did not complete"):
            runner.planned_exam("synthetic-token", "Linear equations", 10)
        self.assertEqual(request.call_count, 3)
        self.assertFalse(any("/plans/generate" in call.args[0] for call in request.call_args_list))


if __name__ == "__main__":
    unittest.main()
