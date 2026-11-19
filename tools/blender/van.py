"""A delivery van for the street, made from a third-party model (docs/TECH_SPEC.md, Modul Y).

Source: "European Delivery Van" by Evan Hiltz, CC-BY-4.0 (tools/blender/sources/european_delivery_van_hiltz,
with its licence file and a note on what was changed there). It comes as 61 small meshes in five materials,
in metres, with seats, dashboard, steering wheel and pedals behind its panes. This script puts it together
the way the game needs it:

  - X forward, Y left, Z up, standing on the ground, centred between its ends;
  - one part per material (van_body, van_trim, van_under), the panes as a part of their own (van_glass), and
    the four wheels as parts at their hubs (nodes wheel_fl, wheel_fr, wheel_rl, wheel_rr), so a van can roll;
  - the pane material is called "glass", which the game's vehicle finish makes clear.
Shapes and maps stay as the author made them.

    PYTHONPATH=<bpy env> python3 tools/blender/van.py
writes game/assets/models/vehicles/delivery_van.glb.
"""
import pathlib
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mm_kit as K

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/blender/sources/european_delivery_van_hiltz/scene.gltf"
OUT = ROOT / "game/assets/models/vehicles/delivery_van.glb"
NAMES = {
    "van_european_delivery_body_shd": "van_body",
    "van_european_delivery_trim_shd": "van_trim",
    "van_european_delivery_undercarriage_shd": "van_under",
    "van_european_delivery_wheels_shd": "van_wheels",
    "van_european_delivery_glass_shd": "glass",
}

K.reset()
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
# Every mesh into the world frame, free of its parents.
for ob in meshes:
    world = ob.matrix_world.copy()
    ob.parent = None
    ob.data = ob.data.copy()
    ob.data.transform(world)
    ob.matrix_world = Matrix.Identity(4)
for ob in list(bpy.data.objects):
    if ob.type != "MESH":
        bpy.data.objects.remove(ob)


def bounds(objects):
    pts = [v.co for ob in objects for v in ob.data.vertices]
    return (Vector((min(p[i] for p in pts) for i in range(3))), Vector((max(p[i] for p in pts) for i in range(3))))


lo, hi = bounds(meshes)
print("source size %.2f x %.2f x %.2f m" % tuple(hi - lo))
# Source frame (front towards -y, left towards +x) -> game frame (front +x, left +y), centred, on the ground.
PLACE = Matrix(((0, -1, 0, (lo.y + hi.y) * 0.5), (1, 0, 0, -(lo.x + hi.x) * 0.5), (0, 0, 1, -lo.z), (0, 0, 0, 1)))
for ob in meshes:
    ob.data.transform(PLACE)


def join(name, objects):
    for ob in bpy.data.objects:
        ob.select_set(False)
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    out.data.name = name
    return out


van = K.empty("delivery_van")
by_material = {}
wheels = []
for ob in meshes:
    label = ob.data.materials[0].name
    if label == "van_european_delivery_wheels_shd":
        wheels.append(ob)
    else:
        by_material.setdefault(label, []).append(ob)
for label, objects in sorted(by_material.items()):
    part = join("van_glass" if NAMES[label] == "glass" else NAMES[label], objects)
    part.parent = van
    print(part.name, len(part.data.polygons), "faces")
for ob in wheels:
    w_lo, w_hi = bounds([ob])
    hub = (w_lo + w_hi) * 0.5
    label = ("f" if hub.x > 0 else "r") + ("l" if hub.y > 0 else "r")
    ob.data.transform(Matrix.Translation(-hub))
    node = K.empty("wheel_" + label, van, hub)
    ob.name = "tyre_" + label
    ob.parent = node
    print("wheel_" + label, tuple(round(c, 3) for c in hub), "radius %.3f" % ((w_hi.z - w_lo.z) * 0.5))
for old, new in NAMES.items():
    bpy.data.materials[old].name = new

OUT.parent.mkdir(parents=True, exist_ok=True)
K.export_glb(OUT, 'Based on "European Delivery Van" (https://sketchfab.com/3d-models/european-delivery-van-0b2f1ad95a79419f9a092420024d329c) by '
    "Evan Hiltz (https://sketchfab.com/evan.hiltz), licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). "
    "Changed for MOLTEN MATES: turned and centred, parts joined by material, wheels as parts of their own, "
    "maps re-encoded as JPEG, three of them reduced to 2048 px.")
print("WROTE", OUT, OUT.stat().st_size)
