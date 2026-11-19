"""The game's tipper truck, made from a third-party model (docs/TECH_SPEC.md, Modul Y).

Source: "Dump Truck" by ElectroNick, CC-BY-4.0 (tools/blender/sources/dump_truck_electronick, with its
licence file). The source is one merged object in six texture groups. This script takes it apart and
puts it together the way the game needs it:

  - real size (7.6 m long), X forward, Y left, Z up, standing on the ground, centred between its ends;
  - six wheels as parts of their own (nodes wheel_fl, wheel_fr, wheel_r1l, wheel_r1r, wheel_r2l,
    wheel_r2r, each at its hub), so ScrapTruck can roll them;
  - materials by what a part is, not by texture sheet: cab_paint and bed_paint (new colours, clear coat),
    bumper and grille plastic, window rubber, cab lining, seats, tank aluminium, the source's own
    tyre-and-rim texture;
  - clear panes (cab_glass) in front of the source's seats and dashboard, lamp lenses that glow
    (head_lamps), and what the source lacks: tail lamps and two amber beacons.

    PYTHONPATH=<bpy env> python3 tools/blender/dump_truck.py
writes game/assets/models/machinery/dump_truck.glb.
"""
import math
import pathlib
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mm_kit as K

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/blender/sources/dump_truck_electronick/scene.gltf"
OUT = ROOT / "game/assets/models/machinery/dump_truck.glb"
LENGTH = 7.6

K.reset()
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
source = {ob.data.materials[0].name: ob for ob in bpy.data.objects if ob.type == "MESH"}
tyre_source = source["M_dump_truck_E_01"].data.materials[0]
tyre_source.name = "tyre_rubber"


class Part:
    """One connected piece of a source object, in the source's frame as imported (metres at viewer
    scale: x left, y back, z up)."""

    def __init__(self, bm, faces):
        self.bm = bm
        self.faces = [f.index for f in faces]
        verts = {v for f in faces for v in f.verts}
        self.lo = Vector((min(v.co[i] for v in verts) for i in range(3)))
        self.hi = Vector((max(v.co[i] for v in verts) for i in range(3)))
        self.size = self.hi - self.lo
        self.mid = (self.lo + self.hi) * 0.5


def parts_of(name):
    ob = source[name]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.transform(ob.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.faces.ensure_lookup_table()
    bm.faces.index_update()
    seen, out = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        seen.add(f)
        stack, group = [f], []
        while stack:
            g = stack.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        out.append(Part(bm, group))
    return out


everything = {name: parts_of(name) for name in source}
lo = Vector((min(p.lo[i] for ps in everything.values() for p in ps) for i in range(3)))
hi = Vector((max(p.hi[i] for ps in everything.values() for p in ps) for i in range(3)))
scale = LENGTH / (hi.y - lo.y)
tyres = [p for p in everything["M_dump_truck_E_01"] if p.size.y > 0.7 and p.size.z > 0.7]
track_mid = sum(p.mid.x for p in tyres) / len(tyres)
# Source frame -> game frame: front (-y) to +x, left (+x) to +y, scaled, centred, on the ground.
PLACE = Matrix.Translation(Vector((0.0, 0.0, -lo.z * scale))) @ Matrix.Scale(scale, 4) @ Matrix(
    ((0, -1, 0, (lo.y + hi.y) * 0.5), (1, 0, 0, -track_mid), (0, 0, 1, 0), (0, 0, 0, 1)))
print("scale %.3f, %d tyres, wheel radius %.3f m" % (scale, len(tyres), tyres[0].size.z * 0.5 * scale))


def build(name, parent, mat, parts, origin=None, prepare=None):
    """An object from parts (all of one source object), in the game frame; `origin` moves its own zero.
    `mat` is one material or a list; `prepare(bm)` may edit the mesh first, still in the source frame."""
    if not parts:
        return None
    bm = parts[0].bm.copy()
    bm.faces.ensure_lookup_table()
    keep = set()
    for p in parts:
        assert p.bm is parts[0].bm
        keep.update(p.faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
    if prepare:
        prepare(bm)
    bm.transform(PLACE)
    if origin is not None:
        bmesh.ops.translate(bm, verts=bm.verts, vec=-origin)
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # The source's hard edges were split vertices; after welding, edges sharper than 40 degrees stay hard.
    me.set_sharp_from_angle(angle=math.radians(40))
    for m in mat if isinstance(mat, (list, tuple)) else [mat]:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


M = {
    "cab": K.material("cab_paint", "#cf4022", rough=0.33, coat=0.6, one_sided=True),
    "bed": K.surface("bed_paint", "#454b50", "paint_worn", 1024, seed=12, coat=0.15),
    "chassis": K.surface("frame_graphite", "#25282b", "paint_worn", 512, seed=13),
    "bumper": K.material("bumper_plastic", "#34373b", rough=0.6),
    "black": K.material("plastic_black", "#121314", rough=0.5),
    "matte": K.material("plastic_matte", "#151617", rough=0.9),
    "rubber": K.material("seal_black", "#0c0c0d", rough=0.8),
    "lining": K.material("cab_lining", "#3b3e42", rough=0.85),
    "fabric": K.material("seat_fabric", "#40444b", rough=0.95),
    "dash": K.material("dash_grey", "#27292c", rough=0.7),
    "steel": K.material("stack_steel", "#8d9195", rough=0.35, metal=1.0),
    "alu": K.material("tank_alu", "#aeb2b5", rough=0.3, metal=1.0),
    "glass": K.material("glass", "#6f8894", rough=0.03, alpha=0.3),
    "lens": K.material("lamp_lens", "#f6f2e6", rough=0.1, emit="#fff4dc", emit_strength=1.0),
    "red": K.material("lamp_red", "#c4161c", rough=0.2, emit="#ff2010", emit_strength=0.5),
    "amber": K.material("lamp_amber", "#f0a020", rough=0.2, emit="#ffa000", emit_strength=0.6),
}

truck = K.empty("truck")
body = K.empty("body", truck)

# --- Cab: paint above, plastic below, rubber round the panes -----------------------------------
cab = {"cab": [], "bumper": [], "black": [], "matte": [], "rubber": [], "lining": []}
for p in everything["M_dumb_truck_B_01.1"]:
    wide = p.size.x > 1.2
    if wide and p.lo.z < 0.45 and p.hi.z < 1.0:
        cab["bumper"].append(p)                      # bumper and lower front
    elif wide and p.size.z < 0.2 and p.hi.z < 1.1:
        cab["black"].append(p)                       # grille bars
    elif wide and p.lo.z > 1.9 and p.size.z < 0.2:
        cab["matte"].append(p)                       # sun visor
    elif wide and p.lo.z > 1.25 and p.size.y > 1.0 and p.hi.z < 2.12:
        cab["lining"].append(p)                      # the cab's inside
    elif p.lo.z > 1.3 and p.hi.z < 2.05 and (p.size.y < 0.3 or p.size.x < 0.05):
        cab["rubber"].append(p)                      # frames of the windscreen and side windows
    elif p.hi.z < 1.0 and p.size.x < 0.6:
        cab["black"].append(p)                       # mudguards behind the front wheels
    else:
        cab["cab"].append(p)                         # shell, doors, front panel


def facing_in(f):
    to_centre = Vector((0.0, -2.1, 1.5)) - f.calc_center_median()
    return f.normal.dot(to_centre) > 0.2 * to_centre.length


def painted(bm):
    """The painted shell is what faces out; it is seen from outside only."""
    bm.normal_update()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if facing_in(f)], context="FACES")


def lined(bm):
    """What faces into the cab, and a second skin just under the paint: through the panes the cab is
    dark inside, not painted."""
    bm.normal_update()
    outer = [f for f in bm.faces if not facing_in(f)]
    made = bmesh.ops.duplicate(bm, geom=outer)["geom"]
    bmesh.ops.delete(bm, geom=outer, context="FACES")
    bm.normal_update()
    for v in (g for g in made if isinstance(g, bmesh.types.BMVert)):
        v.co -= v.normal * (0.02 / scale)
    bmesh.ops.reverse_faces(bm, faces=[g for g in made if isinstance(g, bmesh.types.BMFace)])


for key, parts in cab.items():
    if key == "cab":
        build("cab_shell", body, M["cab"], parts, prepare=painted)
        build("cab_inside", body, M["lining"], parts, prepare=lined)
    else:
        build("cab_" + key, body, M[key], parts)
print("cab:", {k: len(v) for k, v in cab.items()})

# --- What sits in and on the cab ---------------------------------------------------------------
detail = {"fabric": [], "dash": [], "steel": [], "black": []}
for p in everything["M_dump_truck_D_01"]:
    inside = abs(p.mid.x) < 0.82 and -2.62 < p.mid.y < -1.52 and 0.85 < p.mid.z < 1.95
    if inside and (p.size.y < 0.2 and p.size.z > 0.45 or p.size.z < 0.25 and p.size.y > 0.4 and p.hi.z < 1.2):
        detail["fabric"].append(p)                   # seat backs and cushions
    elif inside or (p.mid.y < -2.2 and 0.9 < p.mid.z < 1.45 and p.size.x > 1.0):
        detail["dash"].append(p)                     # dashboard, wheel, levers
    elif p.mid.y > -1.5 and p.mid.z > 1.0 and p.size.z > 0.6:
        detail["steel"].append(p)                    # intake and exhaust stack behind the cab
    else:
        detail["black"].append(p)                    # mirrors, lamp housings, steps, grilles
for key, parts in detail.items():
    build("detail_" + key, body, M[key], parts)
print("detail:", {k: len(v) for k, v in detail.items()})

panes, lamps = [], []
for p in everything["old_lamp_glass_inst"]:
    (panes if p.lo.z > 1.2 else lamps).append(p)
build("cab_glass", body, M["glass"], panes)
build("head_lamps", body, M["lens"], lamps)

# --- Chassis, tank, tipper body ----------------------------------------------------------------
frame, tank = [], []
for p in everything["M_dumb_truck_B_01"]:
    (tank if len(p.faces) > 900 else frame).append(p)
build("chassis", body, M["chassis"], frame)
build("fuel_tank", body, M["alu"], tank)
build("bed", body, M["bed"], everything["M_dump_truck_A_01"])

# --- Wheels: tyre, rim and hub of each go to that wheel's node ---------------------------------
axles = sorted({round(p.mid.y, 1) for p in tyres})
names = {axles[0]: "f", axles[1]: "r1", axles[2]: "r2"}
rest = []
wheel_parts = {}
for p in everything["M_dump_truck_E_01"]:
    home = None
    for t in tyres:
        if (p.mid.x > 0) == (t.mid.x > 0) and abs(p.mid.y - t.mid.y) < 0.2 and abs(p.mid.z - t.mid.z) < 0.2 \
                and p.size.y <= t.size.y + 0.01 and abs(p.mid.x - t.mid.x) < 0.3:
            home = t
    if home is None:
        rest.append(p)
    else:
        wheel_parts.setdefault(names[round(home.mid.y, 1)] + ("l" if home.mid.x > 0 else "r"), (home, []))[1].append(p)
for label, (tyre, parts) in sorted(wheel_parts.items()):
    hub = PLACE @ Vector((tyre.mid.x, tyre.mid.y, tyre.mid.z))
    node = K.empty("wheel_" + label, truck, hub)
    build("tyre_" + label, node, tyre_source, parts, origin=hub)
    print("wheel_" + label, tuple(round(c, 2) for c in hub), len(parts), "parts")
build("axles", body, tyre_source, rest)

# --- What the source lacks: tail lamps on the underrun bar, beacons on the roof ----------------
bar = max((p for p in everything["M_dumb_truck_B_01"] if p.size.x > 1.5 and p.size.y < 0.3), key=lambda p: p.mid.y)
rear = (PLACE @ Vector((0, bar.hi.y, 0))).x
lamp_z = (PLACE @ Vector((0, 0, bar.mid.z))).z


def tail(bm, y0, y1):
    for side in (-1.0, 1.0):
        K.add_box(bm, (rear - 0.03, min(side * y0, side * y1), lamp_z - 0.06), (rear + 0.02, max(side * y0, side * y1), lamp_z + 0.06))


K.make("tail_red", body, M["red"], lambda bm: tail(bm, 0.86, 1.06), bevel=0.004)
K.make("tail_amber", body, M["amber"], lambda bm: tail(bm, 0.74, 0.84), bevel=0.004)
K.make("tail_white", body, M["lens"], lambda bm: tail(bm, 0.64, 0.72), bevel=0.004)

roof = max(cab["cab"], key=lambda p: p.hi.z)
top = (PLACE @ Vector((0, roof.mid.y, roof.hi.z))).z
front = (PLACE @ Vector((0, roof.lo.y, 0))).x
half = roof.size.x * 0.5 * scale


def beacons(bm):
    for side in (-1.0, 1.0):
        c = (front - 0.75, side * (half - 0.32), top - 0.03)
        K.add_cyl(bm, 0.07, c, (c[0], c[1], c[2] + 0.12), segs=20)
        K.add_sphere(bm, 0.07, (c[0], c[1], c[2] + 0.12), segs=20, rings=8)


def beacon_feet(bm):
    for side in (-1.0, 1.0):
        c = (front - 0.75, side * (half - 0.32), top - 0.2)
        K.add_cyl(bm, 0.085, c, (c[0], c[1], top - 0.015), segs=20)


K.make("beacons", body, M["amber"], beacons)
K.make("beacon_feet", body, M["black"], beacon_feet, bevel=0.004)

for ob in list(bpy.data.objects):
    if ob.name.startswith("dump_truck_01") or ob.name in ("Sketchfab_model", "RootNode") or ob.name.endswith(".fbx"):
        bpy.data.objects.remove(ob)
K.export_glb(OUT)
print("WROTE", OUT, OUT.stat().st_size)
