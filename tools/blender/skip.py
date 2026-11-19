"""The game's scrap skip, made from a third-party model (docs/TECH_SPEC.md, Modul Y).

Source: "Old rubbish Skip" by Sousinho, CC-BY-4.0 (tools/blender/sources/old_rubbish_skip_sousinho, with
its licence file and a note on what was changed there). It is one mesh with one material: yellow paint
gone to rust, as painted maps. This script resizes it to the game's skip (3.2 m long), lays its length
along X, stands it on the ground, centred, and writes game/assets/models/machinery/skip.glb.
The shape and the maps stay as the author made them.

    PYTHONPATH=<bpy env> python3 tools/blender/skip.py
"""
import pathlib
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mm_kit as K

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/blender/sources/old_rubbish_skip_sousinho/scene.gltf"
OUT = ROOT / "game/assets/models/machinery/skip.glb"
LENGTH = 3.2

K.reset()
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
source = next(ob for ob in bpy.data.objects if ob.type == "MESH")
mat = source.data.materials[0]
mat.name = "skip_steel"

bm = bmesh.new()
bm.from_mesh(source.data)
bm.transform(source.matrix_world)
lo = Vector((min(v.co[i] for v in bm.verts) for i in range(3)))
hi = Vector((max(v.co[i] for v in bm.verts) for i in range(3)))
scale = LENGTH / (hi.y - lo.y)
# Source frame (length along y) -> game frame (length along x), scaled, centred, on the ground.
place = Matrix.Scale(scale, 4) @ Matrix(
    ((0, 1, 0, -(lo.y + hi.y) * 0.5), (-1, 0, 0, (lo.x + hi.x) * 0.5), (0, 0, 1, -lo.z), (0, 0, 0, 1)))
bm.transform(place)
bm.normal_update()
size = (hi - lo) * scale
print("scale %.5f, size %.3f long, %.3f wide, %.3f high" % (scale, size.y, size.x, size.z))
# What the game needs to know to heap scrap into it: where the floor lies and how long the skip is at
# floor and rim (measured on the faces that look up or lie at the ends).
floors = sorted((f for f in bm.faces if f.normal.z > 0.9), key=lambda f: -f.calc_area())[:6]
for f in floors:
    c = f.calc_center_median()
    xs = [v.co.x for v in f.verts]
    ys = [v.co.y for v in f.verts]
    print("  up-facing: area %.2f at z %.3f, x %.2f..%.2f, y %.2f..%.2f" % (f.calc_area(), c.z, min(xs), max(xs), min(ys), max(ys)))
top = max(v.co.z for v in bm.verts)
rim = [v.co for v in bm.verts if v.co.z > top - 0.02]
print("  rim: z %.3f, x %.2f..%.2f, y %.2f..%.2f" % (top, min(c.x for c in rim), max(c.x for c in rim), min(c.y for c in rim), max(c.y for c in rim)))

me = bpy.data.meshes.new("skip")
bm.to_mesh(me)
bm.free()
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True
# The source's hard edges were split vertices; they stay split, so its shading is kept as it is.
ob = bpy.data.objects.new("skip", me)
bpy.context.scene.collection.objects.link(ob)
for other in list(bpy.data.objects):
    if other is not ob:
        bpy.data.objects.remove(other)
K.export_glb(OUT, 'Based on "Old rubbish Skip" (https://sketchfab.com/3d-models/old-rubbish-skip-2f9aa03ede3a46a0888e76fed382667f) by '
    "Sousinho (https://sketchfab.com/sousinho), licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). "
    "Changed for MOLTEN MATES: resized, turned, maps reduced to 2048 px.")
print("WROTE", OUT, OUT.stat().st_size)
