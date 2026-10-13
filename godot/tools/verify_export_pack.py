#!/usr/bin/env python3
"""Validate a standalone Godot 4.6/4.7 (PCK v3/v4) release without running Godot.

From the repository root:
    python3 godot/tools/verify_export_pack.py [godot-play/index.pck]

The project defaults to the script's parent Godot directory. Use --project when
checking another checkout. This reads only: no import, export, or save writes.
Encrypted packs and embedded executable packs are deliberately unsupported.
"""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys


PROP_NAMES = ("altar", "stela", "grain_rack", "lantern")
FORBIDDEN = {"art_source", "tests", "tools"}


def read_pack(path):
    data = path.read_bytes()
    if len(data) < 104 or data[:4] != b"GDPC":
        raise ValueError("Expected a standalone Godot PCK file (GDPC header).")
    version, major, minor, patch, flags = struct.unpack_from("<5I", data, 4)
    # Non-sparse, unencrypted v3/v4 use the same payload and directory layout.
    # See Godot 4.7.2 core/io/file_access_pack.cpp: PackedSourcePCK::try_open_pack.
    if version not in (3, 4):
        raise ValueError(f"Unsupported PCK version {version}; this checker supports v3/v4.")
    if flags & ~2:
        raise ValueError(f"Encrypted or unknown pack flags are unsupported: {flags:#x}.")
    file_base, directory = struct.unpack_from("<2Q", data, 24)
    if not 104 <= directory <= len(data) - 4:
        raise ValueError("Invalid PCK directory offset.")
    count = struct.unpack_from("<I", data, directory)[0]
    cursor = directory + 4
    entries = {}
    for _ in range(count):
        if cursor + 4 > len(data):
            raise ValueError("Truncated PCK directory entry.")
        length = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        if cursor + length + 36 > len(data):
            raise ValueError("Truncated PCK filename or metadata.")
        name = data[cursor:cursor + length].rstrip(b"\0").decode("utf-8")
        cursor += length
        offset, size = struct.unpack_from("<2Q", data, cursor)
        digest = data[cursor + 16:cursor + 32]
        entry_flags = struct.unpack_from("<I", data, cursor + 32)[0]
        cursor += 36
        if name.startswith("res://"):
            name = name[6:]
        parts = PurePosixPath(name).parts
        if not parts or name.startswith("/") or ".." in parts or "\\" in name:
            raise ValueError(f"Unsafe resource path: {name!r}.")
        if name in entries:
            raise ValueError(f"Duplicate resource path: {name}.")
        if entry_flags:
            raise ValueError(f"Unsupported resource flags {entry_flags:#x}: {name}.")
        start = offset + (file_base if flags & 2 else 0)
        if start < 104 or start + size > directory:
            raise ValueError(f"Resource extends outside the payload area: {name}.")
        entries[name] = (data[start:start + size], digest)
    return entries, f"{major}.{minor}.{patch}"


def validate(entries, project):
    errors = []
    json_count = 0
    for name, (payload, digest) in entries.items():
        if FORBIDDEN.intersection(PurePosixPath(name).parts):
            errors.append(f"Forbidden authoring/test resource is exported: {name}")
        if hashlib.md5(payload).digest() != digest:
            errors.append(f"PCK checksum mismatch: {name}")
        if name.endswith(".json"):
            json_count += 1
            try:
                json.loads(payload)
            except (ValueError, UnicodeDecodeError) as error:
                errors.append(f"Invalid exported JSON {name}: {error}")
            source = project / name
            if not source.is_file():
                errors.append(f"Exported JSON has no current source: {name}")
            elif source.read_bytes() != payload:
                errors.append(f"Exported JSON differs from current source: {name}")

    required_json = ["data/chapter1.json", "data/map_details.json", "data/atlas.json",
                     "assets/maps/scenery.json", "assets/props/landmarks.json"]
    required_json += [f"assets/props/{prop}.json" for prop in PROP_NAMES]
    for name in required_json:
        if name not in entries:
            errors.append(f"Missing required JSON: {name}")

    manifest_entry = entries.get("assets/props/landmarks.json")
    manifest = {}
    if manifest_entry:
        try:
            manifest = json.loads(manifest_entry[0]).get("props", {})
            if not isinstance(manifest, dict):
                raise ValueError("props must be an object")
        except (AttributeError, ValueError, UnicodeDecodeError) as error:
            errors.append(f"Invalid landmark manifest structure: {error}")
            manifest = {}
    for prop in PROP_NAMES:
        frame = manifest.get(prop)
        image = f"assets/props/{prop}.png"
        if not isinstance(frame, dict) or frame.get("image") != "res://" + image:
            errors.append(f"Missing or incorrect manifest image for prop: {prop}")
        # Godot exports imported texture data rather than the source PNG. Follow
        # the actual remap instead of assuming the generated .ctex hash/name.
        if image in entries:
            continue
        imported = entries.get(image + ".import")
        if imported is None:
            errors.append(f"Missing prop texture/import remap: {image}")
            continue
        try:
            text = imported[0].decode("utf-8")
        except UnicodeDecodeError:
            errors.append(f"Invalid texture import remap: {image}.import")
            continue
        remaps = re.findall(r'^path(?:\.[^=]+)?="res://([^"\r\n]+)"\s*$', text, re.M)
        if not remaps:
            errors.append(f"Texture import has no resource path: {image}.import")
        for target in remaps:
            if target not in entries or not entries[target][0]:
                errors.append(f"Missing imported prop texture payload: {target}")

    for script in ("map_atmosphere", "map_details"):
        name = f"scripts/{script}.gd"
        if name not in entries and not all(
                resource in entries for resource in (name + ".remap", name + "c")):
            errors.append(f"Missing runtime script or compiled remap: {name}")
    return errors, json_count


def main():
    project_default = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("pack", nargs="?", type=Path,
                        default=project_default.parent / "godot-play/index.pck")
    parser.add_argument("--project", type=Path, default=project_default)
    args = parser.parse_args()
    try:
        entries, engine = read_pack(args.pack)
        errors, json_count = validate(entries, args.project.resolve())
    except (OSError, ValueError, struct.error) as error:
        print(f"EXPORT_PACK_FAIL: {error}", file=sys.stderr)
        return 1
    for error in errors:
        print(f"EXPORT_PACK_FAIL: {error}", file=sys.stderr)
    if errors:
        print(f"EXPORT_PACK_VERIFY {len(errors)} failures", file=sys.stderr)
        return 1
    print(f"EXPORT_PACK_VERIFY {len(entries)} resources, {json_count} JSON files, "
          f"4 prop textures; all checksums and JSON source bytes match; "
          f"no forbidden resources; Godot {engine}; 0 failures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
