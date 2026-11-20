"""Structural validation of the import package; no device or network access."""
import importlib.util
import json
from pathlib import Path
import unittest
import zipfile
BASE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("loupix_builder", BASE / "build_profile.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
class TestProfile(unittest.TestCase):
    def test_layout(self):
        manifest, payload = builder.documents()
        self.assertEqual(manifest["FormatVersion"], 1)
        self.assertEqual(manifest["ConfigSchemaVersion"], 13)
        self.assertEqual(manifest["SourceDeviceSlug"], "loupedeck-ct")
        self.assertEqual(len(payload["Profile"]["Workspaces"]), 5)
        for w in payload["Profile"]["Workspaces"]:
            keys = w["TouchButtonPages"][0]["TouchButtons"]
            self.assertEqual([b["Index"] for b in keys], list(range(12)))
            for key in keys:
                self.assertEqual(key["Command"], key["States"][0]["Command"])
                self.assertEqual(key["DefaultStateId"], key["States"][0]["Id"])
                self.assertEqual(key["States"][0]["Layers"][0]["kind"], "text")
    def test_archive(self):
        path = BASE / "profiles" / "m3-devops-ct.loupixprofile"
        with zipfile.ZipFile(path) as f:
            self.assertEqual(set(f.namelist()), {"manifest.json", "payload.json"})
            manifest = json.loads(f.read("manifest.json"))
            payload = json.loads(f.read("payload.json"))
        self.assertEqual((manifest, payload), builder.documents())
if __name__ == "__main__":
    unittest.main()
