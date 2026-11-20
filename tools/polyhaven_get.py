#!/usr/bin/env python3
"""Fetches scanned models from Poly Haven (https://polyhaven.com, CC0) for PhotoProp.

Each model comes as a glTF file with its buffer and its 1k maps and lands in
game/assets/models/polyhaven/<name>/ the way PhotoProp expects it (<name>_1k.gltf, <name>.bin,
textures/). With --small the maps are scaled down to 512 px (small things on shelves and tables).
--dry only lists what would be fetched and how big it is.

    python3 -I tools/polyhaven_get.py [--small] [--dry] name [name ...]

After fetching: let Godot import them, then run tools/texture_flags.py on the new folders (it sets
compress/mode=2 and mipmaps/generate=true in the textures' .import files, normal maps also
compress/high_quality=true) and import again (docs/TECH_SPEC.md, Modul Y). Add the names to CREDITS.md.
Needs Pillow for --small. Nothing of the downloaded files is run; they are only stored.
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/models/polyhaven"
AGENT = "asset-browser/1.0"


def fetch(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(["curl", "-sS", "-A", AGENT, "-o", str(path), "-w", "%{http_code}", url], capture_output=True, text=True)
    if done.stdout.strip() != "200":
        raise SystemExit("%s: HTTP %s %s" % (url, done.stdout, done.stderr[:200]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    small = "--small" in sys.argv
    dry = "--dry" in sys.argv
    for name in args:
        listing = OUT / name / "files.json"
        fetch("https://api.polyhaven.com/files/" + name, listing)
        files = json.loads(listing.read_text())
        listing.unlink()
        pack = files["gltf"]["1k"]["gltf"]
        parts = {"%s_1k.gltf" % name: pack["url"]}
        total = pack["size"]
        for rel, entry in pack.get("include", {}).items():
            parts[rel] = entry["url"]
            total += entry["size"]
        print("%s: %d files, %.1f MB" % (name, len(parts), total / 1e6), ", ".join(sorted(parts)))
        if dry:
            if not any((OUT / name).iterdir()):
                (OUT / name).rmdir()
            continue
        for rel, url in parts.items():
            # Only plain relative paths inside the model's own folder.
            target = (OUT / name / rel).resolve()
            if (OUT / name).resolve() not in target.parents:
                raise SystemExit("unexpected path in the listing: " + rel)
            fetch(url, target)
        if small:
            from PIL import Image
            for picture in sorted((OUT / name / "textures").glob("*.jpg")) + sorted((OUT / name / "textures").glob("*.png")):
                im = Image.open(picture)
                if max(im.size) > 512:
                    im = im.resize((512, 512 * im.size[1] // im.size[0]), Image.LANCZOS)
                    im.save(picture, quality=90) if picture.suffix == ".jpg" else im.save(picture)


if __name__ == "__main__":
    main()
