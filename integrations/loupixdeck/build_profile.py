#!/usr/bin/env python3
"""Generate the optional LoupixDeck CT profile (ZIP, standard library only)."""
import json
import zipfile
from pathlib import Path
BASE = Path(__file__).resolve().parent
LAYOUT = json.loads((BASE / "layout.json").read_text(encoding="utf-8"))
IDS = {w["key"]: w["id"] for w in LAYOUT["workspaces"]}
def uid(number):
    return "0a03d3ec-30d0-4c70-8e12-" + format(number, "012x")
def command(b):
    if b["kind"] == "go":
        return "System.GotoWorkspace(" + IDS[b["value"]] + ")"
    if b["kind"] == "home":
        return "System.GoHomeWorkspace"
    if b["kind"] == "url":
        assert b["value"].startswith(("https://", "http://localhost:"))
        return "System.OpenUrl(" + b["value"] + ")"
    if b["kind"] == "run":
        assert b["value"].replace("-", "").isalnum()
        return "System.Shell($HOME/.local/bin/m3-deck " + b["value"] + ")"
    raise ValueError("Unexpected action kind")
def documents():
    workspaces = []
    for wi, w in enumerate(LAYOUT["workspaces"]):
        assert len(w["buttons"]) == 12
        buttons = []
        for bi, item in enumerate(w["buttons"]):
            sid = uid(wi * 100 + 10 + bi)
            cmd = command(item)
            label = item["label"]
            buttons.append({
                "Index": bi, "DefaultStateId": sid,
                "States": [{"Id": sid, "Name": "Default", "Command": cmd,
                            "BackColor": item["color"], "BackgroundEnabled": True,
                            "Layers": [{"kind": "text", "Id": uid(wi * 100 + 30 + bi),
                                        "Name": "Label", "Text": label,
                                        "TextSize": 13 if len(label) > 11 else 16,
                                        "TextColor": "#FFFFFFFF", "Centered": True}]}],
                "Command": cmd
            })
        workspaces.append({
            "Id": w["id"], "Name": w["name"], "StartupTouchPageIndex": 0,
            "TouchButtonPages": [{"Id": uid(wi * 100 + 1), "Name": w["name"],
                                   "Page": 1, "TouchButtons": buttons}],
            "RotaryButtonPages": [], "LeftRotaryButtonPages": [], "RightRotaryButtonPages": []
        })
    manifest = {
        "FormatVersion": 1, "ConfigSchemaVersion": 13, "Kind": "Profile",
        "Name": LAYOUT["name"], "Description": "Read-only Fedora DevOps layout for Loupedeck CT",
        "SourceDeviceSlug": "loupedeck-ct", "SourceDeviceName": "Loupedeck CT",
        "SourceTouchButtonCount": 12, "SourceRotaryButtonCount": 6,
        "SourceHasSideStrips": False, "AppVersion": "community-generated",
        "ExportedUtc": "2026-11-20T19:00:00+00:00",
        "RequiredPlugins": [],
        "ReferencedCommands": ["System.GoHomeWorkspace", "System.GotoWorkspace",
                               "System.OpenUrl", "System.Shell"],
        "Assets": [], "Macros": [], "PayloadFile": "payload.json"
    }
    payload = {"Profile": {"Id": LAYOUT["profile_id"], "Name": LAYOUT["name"],
                           "HomeWorkspaceId": IDS["home"], "Workspaces": workspaces}}
    return manifest, payload
def main():
    manifest, payload = documents()
    dest = BASE / "profiles" / "m3-devops-ct.loupixprofile"
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for name, doc in (("manifest.json", manifest), ("payload.json", payload)):
            z.writestr(name, json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print(dest)
if __name__ == "__main__":
    main()
