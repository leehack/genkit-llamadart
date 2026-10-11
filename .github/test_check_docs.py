from pathlib import Path
import tempfile
import unittest

from check_docs import anchors, check_links, destinations


class DocumentationTest(unittest.TestCase):
    def test_links_resolve_relative_canonical_and_encoded_targets(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "doc").mkdir()
            (root / "doc/guide name.md").write_text("# Useful `API`\n# Useful `API`\n")
            readme = root / "README.md"
            readme.write_text(
                "[local](doc/guide%20name.md#useful-api)\n"
                "[canonical](https://github.com/leehack/genkit-llamadart/blob/main/"
                "doc/guide%20name.md#useful-api-1)\n"
                "[reference]: doc/guide%20name.md#useful-api\n"
                "[remote](https://example.invalid/does-not-exist)\n"
            )
            self.assertEqual(check_links(root, readme), [])
            readme.write_text("[bad](doc/missing.md)\n[bad](doc/guide%20name.md#missing)\n")
            errors = check_links(root, readme)
            self.assertEqual(len(errors), 2)
            self.assertIn("missing target", errors[0])
            self.assertIn("missing anchor", errors[1])

    def test_code_examples_do_not_create_links_or_anchors(self):
        markdown = "# Real\n```dart\n# Fake\n[bad](missing.md)\n```\n[good](#real)\n"
        self.assertEqual(destinations(markdown), ["#real"])
        self.assertEqual(anchors(markdown), {"real"})

    def test_same_document_anchor_is_validated(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            readme = root / "README.md"
            readme.write_text("# Real\n[good](#real)\n[bad](#missing)\n")
            self.assertEqual(len(check_links(root, readme)), 1)
