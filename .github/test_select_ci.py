import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from select_ci import changed_paths, select


class DiffTest(unittest.TestCase):
    def test_non_pr_and_missing_revisions_keep_all_checks(self):
        for env in ({}, {"EVENT_NAME": "push"}, {"EVENT_NAME": "workflow_dispatch"},
                    {"EVENT_NAME": "pull_request"}):
            with self.subTest(env=env), patch.dict(os.environ, env, clear=True):
                self.assertTrue(all(select(changed_paths()).values()))

    def test_rename_deletion_and_base_only_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            def git(*args):
                return subprocess.check_output(["git", "-C", folder, *args], stderr=subprocess.DEVNULL).decode().strip()

            def commit():
                git("add", "-A")
                git("-c", "user.name=CI test", "-c", "user.email=ci@example.invalid", "commit", "-qm", "fixture")
                return git("rev-parse", "HEAD")

            git("init", "-q")
            root = Path(folder)
            (root / "lib").mkdir()
            (root / "lib/runtime.dart").write_text("runtime\n")
            (root / "README.md").write_text("docs\n")
            base = commit()
            git("checkout", "-qb", "pr")
            (root / "lib/runtime.dart").rename(root / "doc.md")
            (root / "README.md").unlink()
            head = commit()
            git("checkout", "-q", base)
            (root / "base-only.txt").write_text("unrelated base change\n")
            advanced_base = commit()
            env = {"EVENT_NAME": "pull_request", "BASE_SHA": advanced_base, "HEAD_SHA": head}
            original_run = subprocess.run

            def run_in_repo(*args, **kwargs):
                return original_run(*args, cwd=folder, **kwargs)

            with patch.dict(os.environ, env), patch("select_ci.subprocess.run", side_effect=run_in_repo):
                paths = changed_paths()
                self.assertEqual(set(paths), {"README.md", "lib/runtime.dart", "doc.md"})
                self.assertTrue(all(select(paths).values()))
            with patch.dict(os.environ, {**env, "BASE_SHA": "0" * 40}), patch(
                "select_ci.subprocess.run", side_effect=run_in_repo
            ):
                self.assertTrue(all(select(changed_paths()).values()))


class SelectionTest(unittest.TestCase):
    def test_only_known_prose_skips_runtime(self):
        self.assertFalse(select(["README.md", "CHANGELOG.md", "LICENSE"])["runtime"])
        for path in ("lib/plugin.dart", "test/unit_test.dart", "example/demo.dart",
                     "test/integration/genkit/test_support/real_model_test_support.dart",
                     "pubspec.yaml", "pubspec.lock", "pubspec_overrides.yaml",
                     "analysis_options.yaml", "dart_test.yaml", ".github/workflows/ci.yml",
                     ".github/select_ci.py", "new-file.md", "README.md\nlib/runtime.dart"):
            for paths in ([path], ["README.md", path], [path, "README.md"]):
                with self.subTest(paths=paths):
                    self.assertTrue(select(paths)["runtime"])

    def test_empty_or_unknown_diff_keeps_runtime(self):
        self.assertTrue(select([])["runtime"])
        self.assertTrue(select(None)["runtime"])
