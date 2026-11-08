#!/usr/bin/env python3
"""
Locate the "UI Scale" slider inside Flotsam's serialized scene files.

This is a *maintainer* tool: install.ps1 hard-codes the byte offsets it finds,
so when Flotsam is updated (or when porting to another store build) run this
script again to get the new offsets and SHA-256 hashes.

Requirements
------------
    Python 3.9+ and UnityPy

    pip install UnityPy

Usage
-----
    python find_ui_scale_slider.py "C:\\Program Files\\Epic Games\\Flotsam\\Flotsam_Data"
    python find_ui_scale_slider.py /path/to/Flotsam_Data

Output
------
For every scene that contains it:

    level1  object=0xa5dc0  min=0.5  max=1.25  value=1.0

`object=` is the byte offset of the MonoBehaviour inside the file; the field
Slider.m_MaxValue sits at object + 0x154.
"""

import hashlib
import os
import struct
import sys

try:
    import UnityPy
except ImportError:
    sys.exit("UnityPy is missing. Install it with: pip install UnityPy")

# MonoBehaviour header: m_GameObject (12) + m_Enabled (4) + m_Script (12)
SCRIPT_ID_OFFSET = 16
MIN_VALUE_OFFSET = 0x150
MAX_VALUE_OFFSET = 0x154
WHOLE_NUMBERS_OFFSET = 0x158
VALUE_OFFSET = 0x15C


def read_header(raw):
    """Return (game_object_path_id, script_path_id) from a MonoBehaviour blob."""
    _, game_object = struct.unpack("<iq", raw[:12])
    _, script = struct.unpack("<iq", raw[SCRIPT_ID_OFFSET:SCRIPT_ID_OFFSET + 12])
    return game_object, script


def slider_script_id(env):
    for obj in env.objects:
        if obj.type.name == "MonoScript":
            try:
                data = obj.read()
            except Exception:
                continue
            if getattr(data, "m_ClassName", "") == "Slider":
                return obj.path_id
    return None


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: python find_ui_scale_slider.py <Flotsam_Data folder>")

    game_data = sys.argv[1]
    managers = os.path.join(game_data, "globalgamemanagers.assets")
    if not os.path.exists(managers):
        sys.exit(f"not found: {managers}")

    slider_id = slider_script_id(UnityPy.load(managers))
    if slider_id is None:
        sys.exit("no 'Slider' MonoScript found - unsupported game build?")

    print(f"Slider script path_id: {slider_id}")
    print()

    for name in sorted(os.listdir(game_data)):
        if not (name.startswith("level") or name.endswith(".assets")):
            continue
        path = os.path.join(game_data, name)
        if not os.path.isfile(path) or os.path.getsize(path) < 1024:
            continue

        # Cheap pre-filter: skip files that cannot contain the slider object.
        with open(path, "rb") as handle:
            if b"UIScaleSlider" not in handle.read():
                continue

        try:
            env = UnityPy.load(path)
        except Exception:
            continue

        names = {}
        for obj in env.objects:
            if obj.type.name == "GameObject":
                try:
                    names[obj.path_id] = obj.read().m_Name
                except Exception:
                    pass

        hits = 0
        for obj in env.objects:
            if obj.type.name != "MonoBehaviour":
                continue
            raw = obj.get_raw_data()
            if len(raw) < VALUE_OFFSET + 4:
                continue
            game_object, script = read_header(raw)
            if script != slider_id:
                continue
            if "UIScale" not in str(names.get(game_object, "")):
                continue

            minimum = struct.unpack("<f", raw[MIN_VALUE_OFFSET:MIN_VALUE_OFFSET + 4])[0]
            maximum = struct.unpack("<f", raw[MAX_VALUE_OFFSET:MAX_VALUE_OFFSET + 4])[0]
            whole = raw[WHOLE_NUMBERS_OFFSET]
            value = struct.unpack("<f", raw[VALUE_OFFSET:VALUE_OFFSET + 4])[0]
            print(
                f"{name:20s} object=0x{obj.byte_start:x}  "
                f"min={minimum:g}  max={maximum:g}  whole={whole}  value={value:g}"
            )
            hits += 1

        if hits:
            with open(path, "rb") as handle:
                print(f"{'':20s} sha256={hashlib.sha256(handle.read()).hexdigest().upper()}")


if __name__ == "__main__":
    main()
