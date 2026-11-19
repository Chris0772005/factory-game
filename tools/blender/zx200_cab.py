"""Opens the excavator's cab (docs/TECH_SPEC.md, Modul Y).

The third-party model game/assets/models/machinery/zx200_hd.glb (Apache 2.0) has a cab that is a
closed block with its panes laid on the outside: nothing shows behind the glass. This script reads
that file, hollows the block out, cuts an opening behind every pane and writes the result as
game/assets/models/machinery/zx200_cab_open.glb, in the frame of the original part: cab_shell (the
painted outside and the reveals) and cab_inside (the lining). DiggerRig shows them in place of the
original part; the original file stays as it is.

    PYTHONPATH=<bpy env> python3 tools/blender/zx200_cab.py
"""
import pathlib
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mm_kit as K

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/assets/models/machinery/zx200_hd.glb"
OUT = ROOT / "game/assets/models/machinery/zx200_cab_open.glb"
WALL = 0.04        # thickness of the cab's walls (m)
LIP = 0.018        # how far the frame reaches in under a pane's edge
REACH = 0.14       # half depth of the block that cuts an opening


def islands(bm):
    seen, out = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        seen.add(f)
        stack, part = [f], []
        while stack:
            g = stack.pop()
            part.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        out.append(part)
    return out


def mesh_object(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    return ob


def cut(target, cutter):
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.use_self = True
    mod.material_mode = "TRANSFER"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)


K.reset()
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
shell_src = bpy.data.objects["cab_shell"]
glass_src = bpy.data.objects["cab_glass"]

paint = K.material("paint_cab_white", "#e4e2dc", rough=0.34, coat=0.6)
lining = K.material("cab_lining", "#3a3d41", rough=0.8)

# The block, and a smaller copy of it that becomes the room inside.
outer = bmesh.new()
outer.from_mesh(shell_src.data)
bmesh.ops.remove_doubles(outer, verts=outer.verts, dist=1e-5)
lo = Vector((min(v.co[i] for v in outer.verts) for i in range(3)))
hi = Vector((max(v.co[i] for v in outer.verts) for i in range(3)))
mid = (lo + hi) * 0.5
inner = outer.copy()
for v in inner.verts:
    for i in range(3):
        half = (hi[i] - lo[i]) * 0.5
        v.co[i] = mid[i] + (v.co[i] - mid[i]) * (half - WALL) / half

# One block per pane, a little smaller than the pane and reaching through the wall. The pane in the
# roof stays shut: the roof plate above it is a part of its own.
panes = bmesh.new()
panes.from_mesh(glass_src.data)
bmesh.ops.remove_doubles(panes, verts=panes.verts, dist=1e-5)
blocks = bmesh.new()
count = 0
for part in islands(panes):
    face = max(part, key=lambda f: f.calc_area())
    n = face.normal.copy()
    verts = list({v for f in part for v in f.verts})
    c = sum((v.co for v in verts), Vector()) / len(verts)
    if abs(n.y) > 0.9 and c.y < lo.y + 0.1:
        continue
    span = max((v.co - c - n * (v.co - c).dot(n)).length for v in verts)
    made = {}
    for v in verts:
        d = (v.co - c).dot(n)
        flat = v.co - c - n * d
        made[v] = blocks.verts.new(c + flat * (1.0 - LIP / span) + n * (REACH if d > 0 else -REACH))
    for f in part:
        blocks.faces.new([made[v] for v in f.verts])
    count += 1
print("openings:", count)

shell = mesh_object("cab_shell", outer, paint)
room = mesh_object("room", inner, lining)
cutters = mesh_object("cutters", blocks, paint)
for ob in (shell, room, cutters):
    ob.select_set(False)
# The room's walls bring the lining with them, the reveals of the openings the paint.
cut(shell, room)
cut(shell, cutters)

me = shell.data
bm = bmesh.new()
bm.from_mesh(me)
for f in bm.faces:
    f.smooth = True
bmesh.ops.triangulate(bm, faces=bm.faces)
bm.to_mesh(me)
bm.free()
print("materials:", [m.name for m in me.materials], "faces:", len(me.polygons))
bevel = shell.modifiers.new("bevel", "BEVEL")
bevel.width = 0.004
bevel.segments = 2
bevel.limit_method = "ANGLE"
bevel.angle_limit = 0.7
normals = shell.modifiers.new("normals", "WEIGHTED_NORMAL")
normals.keep_sharp = True

# The lining becomes a part of its own (cab_inside): the game keeps mud off it.
inside = shell.copy()
inside.data = shell.data.copy()
inside.name = "cab_inside"
bpy.context.scene.collection.objects.link(inside)
for ob, slot in ((shell, 0), (inside, 1)):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != slot], context="FACES")
    for f in bm.faces:
        f.material_index = 0
    bm.to_mesh(ob.data)
    bm.free()
    keep = ob.data.materials[slot]
    ob.data.materials.clear()
    ob.data.materials.append(keep)

# Only the new parts go into the file.
for ob in list(bpy.data.objects):
    if ob is not shell and ob is not inside:
        bpy.data.objects.remove(ob)
shell.name = "cab_shell"
K.export_glb(OUT)
print("WROTE", OUT, OUT.stat().st_size)
