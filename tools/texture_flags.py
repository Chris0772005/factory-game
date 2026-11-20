#!/usr/bin/env python3
"""Sets the import settings that model and scan textures need (docs/TECH_SPEC.md, Modul Y).

Godot writes a <file>.import beside every new texture on its first import. For textures that lie on
models and walls this tool then sets: compressed for the graphics card (compress/mode=2), with mipmaps
(mipmaps/generate=true), normal maps in high quality (compress/high_quality=true; a normal map is a
file whose name holds _nor_, _normal or ends in _n). Import again afterwards.

    python3 tools/texture_flags.py game/assets/models/polyhaven/jug_01 game/assets/textures/scan/floor_tiles_06

Each argument is a folder (every texture below it) or the start of a file name (every texture that
begins so). Prints what it changed.
"""
import pathlib
import re
import sys


def is_normal(name):
    stem = name.lower().split(".")[0]
    return "_nor_" in stem or "_normal" in stem or stem.endswith("_n") or stem.endswith("_nor")


def main():
    files = []
    for arg in sys.argv[1:]:
        path = pathlib.Path(arg)
        if path.is_dir():
            files += sorted(path.rglob("*.import"))
        else:
            files += sorted(path.parent.glob(path.name + "*.import"))
    changed = 0
    for file in files:
        text = file.read_text()
        if 'importer="texture"' not in text:
            continue
        normal = is_normal(file.name[: -len(".import")])
        new = re.sub(r"compress/mode=\d", "compress/mode=2", text)
        new = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", new)
        new = re.sub(r"compress/high_quality=\w+", "compress/high_quality=" + ("true" if normal else "false"), new)
        if new != text:
            file.write_text(new)
            changed += 1
            print(("normal  " if normal else "        ") + str(file))
    print("%d of %d texture settings changed" % (changed, len(files)))


if __name__ == "__main__":
    main()
