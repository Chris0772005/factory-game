#!/usr/bin/env python3
"""Fetches scanned models and surfaces from Poly Haven (https://polyhaven.com, CC0).

Models (for PhotoProp): each comes as a glTF file with its buffer and its 1k maps and lands in
game/assets/models/polyhaven/<name>/ the way PhotoProp expects it (<name>_1k.gltf, <name>.bin,
textures/). With --small the maps are scaled down to 512 px (small things on shelves and tables).
--dry only lists what would be fetched and how big it is.

    python3 -I tools/polyhaven_get.py [--small] [--dry] name [name ...]

Surfaces (for EnvMesh.scan): with --scan each name is a texture set. Its 1k colour, normal and
occlusion-roughness-metal maps land in game/assets/textures/scan/ as <name>_d.jpg, <name>_n.jpg and
<name>_arm.jpg, and the line for EnvMesh.SCANS is printed (edge length in metres, mean colour).

    python3 -I tools/polyhaven_get.py --scan name [name ...]

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
SCANS = ROOT / "game/assets/textures/scan"
AGENT = "asset-browser/1.0"


def fetch(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(["curl", "-sS", "-A", AGENT, "-o", str(path), "-w", "%{http_code}", url], capture_output=True, text=True)
    if done.stdout.strip() != "200":
        raise SystemExit("%s: HTTP %s %s" % (url, done.stdout, done.stderr[:200]))


def linear(value):
    value /= 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def scan(name):
    """One texture set for EnvMesh.scan: three maps and the line for EnvMesh.SCANS."""
    from PIL import Image
    info = SCANS / (name + "_info.json")
    fetch("https://api.polyhaven.com/info/" + name, info)
    size = (json.loads(info.read_text()).get("dimensions") or [2000])[0] / 1000.0
    info.unlink()
    for theirs, ours in (("diff", "d"), ("nor_gl", "n"), ("arm", "arm")):
        fetch("https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/%s/%s_%s_1k.jpg" % (name, name, theirs),
              SCANS / ("%s_%s.jpg" % (name, ours)))
    pixels = list(Image.open(SCANS / (name + "_d.jpg")).convert("RGB").resize((64, 64), Image.BOX).tobytes())
    mean = [sum(linear(v) for v in pixels[c::3]) / (len(pixels) / 3) for c in range(3)]
    print('\t"%s": [%.1f, Color(%.3f, %.3f, %.3f)],' % (name, size, mean[0], mean[1], mean[2]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    small = "--small" in sys.argv
    dry = "--dry" in sys.argv
    if "--scan" in sys.argv:
        for name in args:
            scan(name)
        return
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
