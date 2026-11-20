#!/usr/bin/env python3
"""Generate the optional LoupixDeck CT profile (ZIP, standard library only)."""
import json
import zipfile
import uuid
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
WHEEL_NAMESPACE = uuid.UUID(LAYOUT["profile_id"])

def wheel_uid(*parts):
    return str(uuid.uuid5(WHEEL_NAMESPACE, "/".join(str(p) for p in parts)))

def wheel_canvas(wi, mode_index, segment_index, label, x, y, shared=False):
    """Wheel artwork uses the entire 240x240 coordinate space.

    Each segment canvas is clipped by LoupixDeck to its own quadrant.
    The shared canvas paints a dark background and a centered m³ emblem.
    """
    stem = (wi, mode_index, segment_index)
    state_id = wheel_uid("wheel", *stem, "state")
    layer = {
        "kind": "text",
        "Id": wheel_uid("wheel", *stem, "text"),
        "Name": "m³ mark" if shared else "Quadrant label",
        "Text": label,
        "TextSize": 21 if shared else (15 if len(label) > 6 else 18),
        "TextColor": "#FF6EE7FF" if shared else "#FFF1F6FC",
        "Bold": True,
        "Centered": True,
        "PositionX": x,
        "PositionY": y,
        "BoxWidth": 44 if shared else 76,
        "BoxHeight": 32 if shared else 46,
        "BehindSegments": False
    }
    return {
        "Index": 1010 if shared else 1001 + segment_index,
        "DefaultStateId": state_id,
        "States": [{
            "Id": state_id, "Name": "Default",
            "Command": "",
            "BackColor": "#FF101A29",
            "BackgroundEnabled": shared,
            "Layers": [layer]
        }],
        "Command": ""
    }

def wheel_modes(wi, workspace):
    """Two split-screen modes: NAV and workspace-specific safe shortcuts.

    Wheel ring changes the active workspace; swipe opens the wheel-mode menu.
    """
    cfg = workspace["wheel"]
    modes = []
    for mi, mode in enumerate(cfg["modes"]):
        assert len(mode["segments"]) == 4
        quadrants = [(-48, -48), (48, -48), (-48, 48), (48, 48)]
        segments = []
        for si, (item, (x, y)) in enumerate(zip(mode["segments"], quadrants)):
            segments.append({
                "Command": command(item),
                "Canvas": wheel_canvas(wi, mi, si, item["label"], x, y)
            })
        modes.append({
            "Index": 6,
            "DisplayText": "m³ · " + mode["label"],
            "RotaryLeftCommand": cfg["turnLeft"],
            "RotaryRightCommand": cfg["turnRight"],
            "Command": "",
            "SplitMode": 4,  # Cross: TL, TR, BL, BR
            "ShowSplitDividers": True,
            "Segments": segments,
            "SplitCanvas": wheel_canvas(wi, mi, 9, "m³", 0, 0, shared=True)
        })
    return modes

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
                                   "Page": 1, "TouchButtons": buttons,
                                   "WheelModes": wheel_modes(wi, w),
                                   "WheelModeIndex": 0}],
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
                               "System.NextWorkspace", "System.PreviousWorkspace",
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
