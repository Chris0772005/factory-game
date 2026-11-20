"""Cars for the street, made from third-party models (docs/TECH_SPEC.md, Modul Y).

Sources: "Kiri '86", "Fairheaven LT '80" and "Fairheaven SW '84" by Daniel Zhabotinsky, CC-BY-4.0
(tools/blender/sources/zhabotinsky_cars, with their licence files and a note on their origin). Each comes as
one mesh in eight materials, lying on its side (the prepared copies are Z-up inside a Y-up file), with seats
and dashboard behind tinted panes. This script puts each together the way the game needs it:

  - X forward, Y left, Z up, standing on the ground, centred;
  - three parts: car_body (paint, underside, lamps and their lenses, plates), car_inside (seats and
    trim) and car_glass (the panes), so the game's road dirt stays outside and the sun falls in;
  - four wheels of their own (wheel_fl, wheel_fr, wheel_rl, wheel_rr: tyre and rim, the origin in the hub,
    the axle along the car's width), so they turn when the car drives (the source has them as loose
    pieces of the one mesh, all in the tyre material);
  - the panes get a material of their own called "glass", which the game's vehicle finish makes clear (in the
    source they share one dark, nearly opaque material with the lamp lenses and are told apart only by their
    place on the map);
  - the body paint is called "paint_body": the game's vehicle finish gives it a clear coat, and each parked
    car its own colour;
  - without the badges: their atlas holds invented makes, some of which resemble real ones.
Shapes and maps stay as the author made them.

    PYTHONPATH=<bpy env> python3 tools/blender/cars.py
writes game/assets/models/vehicles/car_<name>.glb.
"""
import pathlib
import sys

import bpy
import bmesh  # (comes with bpy: after it)
from mathutils import Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mm_kit as K

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = ROOT / "tools/blender/sources/zhabotinsky_cars"
OUT = ROOT / "game/assets/models/vehicles"
CARS = {
    "kiri86": ("Kiri '86 - Low poly model", "https://sketchfab.com/3d-models/kiri-86-low-poly-model-5c17c582ef9549798f694b660feea42a"),
    "fairheaven_lt80": ("Fairheaven LT '80 - Low poly model", "https://sketchfab.com/3d-models/fairheaven-lt-80-low-poly-model-e2678da920cc4be68dbc193727919ffb"),
    "fairheaven_sw84": ("Fairheaven SW '84 - Low poly model", "https://sketchfab.com/3d-models/fairheaven-sw-84-low-poly-model-aa0becb6e854422596cac6b21bf79787"),
}
# Source material -> (name in the game, part).
PARTS = {
    "glass": ("glass", "car_glass"),
    "Bodymat": ("paint_body", "car_body"),
    "UCB_BOTTOM_GT": ("car_under", "car_body"),
    "UCB_Lights_and_Glass_Transperent": ("car_clear", "car_body"),
    "UCB_Lights_and_Glass": ("car_lights", "car_body"),
    "UCB_Interior_Trim": ("car_trim", "car_inside"),
    "Numberplates_Misk_U": ("car_plates", "car_body"),
    "RB1c_Tire_1k": ("car_tyre", "wheels"),
}
# Turned half round where the source's nose points the other way (seen in the model viewer).
FLIP = set(sys.argv[1:])


def label(material_name):
    for key in sorted(PARTS, key=len, reverse=True):
        if material_name.endswith(key) or material_name == key:
            return PARTS[key]
    return None


for name, (title, url) in CARS.items():
    K.reset()
    bpy.ops.import_scene.gltf(filepath=str(SOURCES / name / "model.gltf"))
    source = next(ob for ob in bpy.data.objects if ob.type == "MESH")
    world = source.matrix_world.copy()
    source.parent = None
    source.data.transform(world)
    source.matrix_world = Matrix.Identity(4)
    pts = [v.co for v in source.data.vertices]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    # As imported: length along x, height along -y, width along z. -> x forward, y left, z up.
    turn = -1.0 if name in FLIP else 1.0
    place = Matrix(((turn, 0, 0, -turn * (lo.x + hi.x) * 0.5), (0, 0, turn, -turn * (lo.z + hi.z) * 0.5), (0, -1, 0, hi.y), (0, 0, 0, 1)))
    source.data.transform(place)
    print(name, "size %.2f x %.2f x %.2f m" % (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y))
    # The panes: the faces of the clear material that lie in the map's upper left quarter.
    me = source.data
    clear = next(i for i, m in enumerate(me.materials) if m.name.endswith("UCB_Lights_and_Glass_Transperent"))
    me.materials.append(K.material("glass", "#6f8894", rough=0.03, alpha=0.3))
    pane = len(me.materials) - 1
    uv = me.uv_layers.active.data
    panes = 0
    for poly in me.polygons:
        if poly.material_index != clear:
            continue
        u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
        v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
        if u < 0.5 and v > 0.5:
            poly.material_index = pane
            panes += 1
    print("  panes:", panes, "faces")
    # One object per material, then joined into the two parts; the badges go.
    for ob in bpy.data.objects:
        ob.select_set(False)
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {}
    for ob in [o for o in bpy.data.objects if o.type == "MESH"]:
        used = ob.data.materials[ob.data.polygons[0].material_index] if ob.data.polygons else None
        target = label(used.name) if used else None
        if target is None:
            print("  left out:", used.name if used else "(empty)", len(ob.data.polygons), "faces")
            bpy.data.objects.remove(ob)
            continue
        used.name = target[0]
        groups.setdefault(target[1], []).append(ob)
    car = K.empty("car_" + name)
    # The wheels: every piece in the tyre material belongs to the wheel in its quarter of the car.
    for tyres in groups.pop("wheels", []):
        centres = [p.center for p in tyres.data.polygons]
        mid_x = (min(c.x for c in centres) + max(c.x for c in centres)) * 0.5
        for front, left, wheel_name in ((True, True, "wheel_fl"), (True, False, "wheel_fr"), (False, True, "wheel_rl"), (False, False, "wheel_rr")):
            wheel = tyres.copy()
            wheel.data = tyres.data.copy()
            bpy.context.collection.objects.link(wheel)
            bm = bmesh.new()
            bm.from_mesh(wheel.data)
            away = [f for f in bm.faces if ((f.calc_center_median().x > mid_x) != front) or ((f.calc_center_median().y > 0.0) != left)]
            bmesh.ops.delete(bm, geom=away, context="FACES")
            pts = [v.co.copy() for v in bm.verts]
            hub = Vector(((min(q[i] for q in pts) + max(q[i] for q in pts)) * 0.5 for i in range(3)))
            bmesh.ops.translate(bm, verts=bm.verts, vec=-hub)
            bm.to_mesh(wheel.data)
            bm.free()
            wheel.name = wheel_name
            wheel.data.name = wheel_name
            wheel.parent = car
            wheel.location = hub
            radius = max(max(abs(q.x - hub.x), abs(q.z - hub.z)) for q in pts)
            print("  %s hub (%.3f, %.3f, %.3f), radius %.3f m, %d faces" % (wheel_name, hub.x, hub.y, hub.z, radius, len(wheel.data.polygons)))
        bpy.data.objects.remove(tyres)
    for part_name, objects in sorted(groups.items()):
        for ob in bpy.data.objects:
            ob.select_set(False)
        for ob in objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        part = bpy.context.view_layer.objects.active
        part.name = part_name
        part.data.name = part_name
        part.parent = car
        # Only the materials still in use stay on the part.
        bpy.ops.object.material_slot_remove_unused()
        print(" ", part_name, len(part.data.polygons), "faces", [m.name for m in part.data.materials])
    out = OUT / ("car_%s.glb" % name)
    K.export_glb(out, 'Based on "%s" (%s) by Daniel Zhabotinsky (https://sketchfab.com/DanielZhabotinsky), licensed under '
        "CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/); prepared copy from raisimTech/raisim2Lib (one mesh, 1K maps, "
        "plain body paint). Changed for MOLTEN MATES: turned upright and centred, split into body, inside and four wheels, badges left out." % (title, url))
    print("WROTE", out, out.stat().st_size)
