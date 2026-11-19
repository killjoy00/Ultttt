#!/usr/bin/env python3
"""Capture real Android gameplay screenshots on a test emulator.

Never generate mock game screenshots; all pixels come from the running
Compose app. Requires adb and a debug APK already installed.
"""
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

OUTPUT = Path(__file__).parent / "screenshots"
OUTPUT.mkdir(parents=True, exist_ok=True)
PACKAGE = "com.killjoy00.ultttt"
EXAMPLE_MOVES = [
    (3,6),(6,4),(4,2),(2,3),(3,2),(2,4),
    (4,3),(3,1),(1,1),(1,4),(4,7),(7,4),
    (4,0),(0,6),(6,2),(2,8),(8,0),(0,4),
    (4,4),(4,1),(1,8),(8,5),(5,7),(7,7),
    (7,1),(1,3),(3,4),(4,5),(5,8),(8,8),
    (8,6),(6,6),(6,5),(5,5),(5,2),(2,5),
    (5,3),(1,0),(0,2),(6,0),(0,8),(8,4),
    (4,6),(6,8),(8,7),(7,6),(1,2),(5,1),
    (1,5),(5,0),(0,7),(7,3),(5,4),(7,0),
]
# This sequence was verified as 54 legal moves by the iOS real-game fixture.

def adb(*args, capture=False):
    result = subprocess.run(["adb", *args], check=True, stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.PIPE if capture else None)
    return result.stdout if capture else None

def nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/window.xml", capture=True)
    xml = adb("exec-out", "cat", "/sdcard/window.xml", capture=True).decode("utf-8")
    return [n.attrib for n in ET.fromstring(xml).iter("node")]

def tap_node(predicate, reason):
    for _ in range(4):
        tree = nodes()
        match = next((n for n in tree if predicate(n)), None)
        if match:
            coords = re.findall(r"\d+", match.get("bounds", ""))
            if len(coords) == 4:
                a,b,c,d = map(int,coords)
                adb("shell", "input", "tap", str((a+c)//2), str((b+d)//2))
                time.sleep(0.2)
                return
        time.sleep(0.5)
    labels=[(n.get("text",""),n.get("content-desc","")) for n in tree if n.get("text") or n.get("content-desc")]
    raise RuntimeError("Missing tappable " + reason + "; sample labels: " + repr(labels[:45]))

def tap_text(label):
    # Avoid matching "Play" inside "Two players" in the new-game dialog.
    exact = label.lower() != "skip"
    def is_target(node):
        values = [node.get("text", "").lower(), node.get("content-desc", "").lower()]
        return any(v == label.lower() if exact else label.lower() in v for v in values)
    tap_node(is_target, label)

def capture(name):
    time.sleep(0.4)
    png = adb("exec-out", "screencap", "-p", capture=True)
    if not png or png[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError("Could not capture PNG for " + name)
    target = OUTPUT / (name + ".png")
    target.write_bytes(png)
    print("Real Android screenshot:", target.name, len(png), "bytes", flush=True)

adb("shell", "pm", "clear", PACKAGE)
adb("shell", "am", "start", "-n", PACKAGE + "/.MainActivity")
time.sleep(4)
tap_node(lambda n: "Nine boards" in n.get("text",""), "first-run tutorial visible")
capture("01-first-launch")
tap_text("Skip")
time.sleep(1)
tap_text("New game")
tap_text("Two players")
tap_text("Play")
time.sleep(0.5)

capture("02-game-start")
for i,(board,cell) in enumerate(EXAMPLE_MOVES, start=1):
    phrase = f"Board {board+1}, square {cell+1},"
    tap_node(lambda n,p=phrase: n.get("content-desc","").startswith(p) and
             "playable" in n.get("content-desc",""), phrase)
    if i == 18:
        capture("03-midgame")
capture("04-late-game")
tap_text("Statistics")
capture("05-statistics")
adb("shell","input","keyevent","4")
time.sleep(0.4)
tap_text("Settings")
capture("06-appearance")
print("Finished real emulator captures",flush=True)
