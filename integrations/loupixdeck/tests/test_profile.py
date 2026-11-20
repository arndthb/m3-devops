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

    def test_wheel_modes(self):
        manifest, payload = builder.documents()
        self.assertIn("System.PreviousWorkspace", manifest["ReferencedCommands"])
        self.assertIn("System.NextWorkspace", manifest["ReferencedCommands"])
        for workspace in payload["Profile"]["Workspaces"]:
            page = workspace["TouchButtonPages"][0]
            self.assertEqual(page["WheelModeIndex"], 0)
            self.assertEqual(len(page["WheelModes"]), 2)
            for mode in page["WheelModes"]:
                self.assertEqual(mode["Index"], 6)
                self.assertEqual(mode["SplitMode"], 4)
                self.assertEqual(mode["RotaryLeftCommand"], "System.PreviousWorkspace")
                self.assertEqual(mode["RotaryRightCommand"], "System.NextWorkspace")
                self.assertEqual(len(mode["Segments"]), 4)
                self.assertTrue(mode["SplitCanvas"]["States"][0]["BackgroundEnabled"])
                self.assertEqual(
                    [s["Canvas"]["States"][0]["Layers"][0]["PositionX"] for s in mode["Segments"]],
                    [-48, 48, -48, 48])
                for segment in mode["Segments"]:
                    cmd = segment["Command"]
                    self.assertTrue(cmd.startswith((
                        "System.GotoWorkspace(", "System.OpenUrl(", "System.Shell(")))
                    self.assertEqual(
                        segment["Canvas"]["States"][0]["Layers"][0]["kind"], "text")
    def test_archive(self):
        path = BASE / "profiles" / "m3-devops-ct.loupixprofile"
        with zipfile.ZipFile(path) as f:
            self.assertEqual(set(f.namelist()), {"manifest.json", "payload.json"})
            manifest = json.loads(f.read("manifest.json"))
            payload = json.loads(f.read("payload.json"))
        self.assertEqual((manifest, payload), builder.documents())
if __name__ == "__main__":
    unittest.main()
