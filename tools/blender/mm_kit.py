"""MOLTEN MATES model kit: small helpers to build vehicles and machines procedurally in Blender (bpy) and
export them as GLB for Godot. Own code. Conventions: metres, X forward, Y left, Z up; ground at z = 0.

    PYTHONPATH=<dir with bpy> python3 tools/blender/<model>.py

Shapes are added to a bmesh inside a builder function; `make` turns the bmesh into an object with rounded
edges (bevel modifier, applied on export), smooth shading and box-projected UVs, so textures have the same
scale everywhere. `surface` makes a PBR material with generated albedo, roughness/metal and normal maps.
"""

import math

import bpy  # first: it provides bmesh and mathutils

import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

UV_TILE = 2.0  # metres per texture tile


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _link(ob, parent, loc):
    bpy.context.scene.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    if loc is not None:
        ob.location = loc
    return ob


def empty(name, parent=None, loc=None):
    return _link(bpy.data.objects.new(name, None), parent, loc)


# ------------------------------------------------------------------ materials

def srgb(hexstr):
    """'#rrggbb' -> linear RGB."""
    h = hexstr.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def _principled(m):
    m.use_nodes = True
    nt = m.node_tree
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return n
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(p.outputs["BSDF"], out.inputs["Surface"])
    return p


def material(name, color, rough=0.5, metal=0.0, coat=0.0, alpha=1.0, emit=None, emit_strength=1.0, one_sided=False):
    """`one_sided`: back faces are not drawn (a shell seen from inside shows what lies behind it)."""
    m = bpy.data.materials.new(name)
    m.use_backface_culling = one_sided
    p = _principled(m)
    p.inputs["Base Color"].default_value = (*srgb(color), 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if coat and "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = coat
        p.inputs["Coat Roughness"].default_value = 0.08
    if alpha < 1:
        p.inputs["Alpha"].default_value = alpha
        for attr, value in (("blend_method", "BLEND"), ("surface_render_method", "BLENDED")):
            try:
                setattr(m, attr, value)
            except (AttributeError, TypeError):
                pass
    if emit:
        p.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        p.inputs["Emission Strength"].default_value = emit_strength
    return m


# kind: colour variation, grime, chipped share, chip colour, roughness (base, spread), metal, bump
KINDS = {
    "paint": dict(var=0.04, grime=0.08, chips=0.012, chip="#3a3835", rough=(0.34, 0.07), metal=0.0, bump=0.3),
    "paint_worn": dict(var=0.07, grime=0.26, chips=0.07, chip="#494643", rough=(0.44, 0.1), metal=0.0, bump=0.5),
    "steel": dict(var=0.12, grime=0.3, chips=0.1, chip="#5b3b24", rough=(0.52, 0.15), metal=0.7, bump=0.8),
    "rubber": dict(var=0.06, grime=0.28, chips=0.0, chip="#000000", rough=(0.84, 0.05), metal=0.0, bump=0.6),
    "plastic": dict(var=0.04, grime=0.12, chips=0.0, chip="#000000", rough=(0.6, 0.06), metal=0.0, bump=0.5),
}


def _noise(n, beta, rng):
    """Tileable noise with a 1/f^beta spectrum, normalised to 0..1."""
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    spec = np.fft.fft2(rng.standard_normal((n, n))) / r ** (beta / 2)
    spec[0, 0] = 0
    a = np.real(np.fft.ifft2(spec))
    lo, hi = np.percentile(a, 1), np.percentile(a, 99)
    return np.clip((a - lo) / (hi - lo), 0, 1)


def _image(name, rgb, colour):
    n = rgb.shape[0]
    img = bpy.data.images.new(name, n, n, alpha=False)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    px = np.ones((n, n, 4), dtype=np.float32)
    px[..., :3] = np.clip(rgb, 0, 1)
    img.pixels.foreach_set(px.ravel())
    try:
        img.pack()
    except RuntimeError:
        pass
    return img


def surface(name, color, kind, size=512, seed=0, coat=0.0, one_sided=False, chips=None):
    """A textured PBR material: albedo, occlusion/roughness/metal and normal maps generated for `kind`."""
    k = dict(KINDS[kind])
    if chips is not None:
        k["chips"] = chips
    rng = np.random.default_rng(seed)
    n = size
    h = color.lstrip("#")
    base = np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])
    chip = np.array([int(k["chip"].lstrip("#")[i : i + 2], 16) / 255 for i in (0, 2, 4)])
    lo, mid, hi = _noise(n, 2.6, rng), _noise(n, 1.7, rng), _noise(n, 0.9, rng)
    alb = np.ones((n, n, 3)) * base * (1 + k["var"] * (lo - 0.5) * 2 + 0.3 * k["var"] * (hi - 0.5))[..., None]
    grime = np.clip((lo * 0.7 + mid * 0.3 - 0.45) * 2.2, 0, 1) * k["grime"]
    alb = alb * (1 - grime[..., None]) + np.array([0.3, 0.26, 0.2]) * grime[..., None]
    rough = k["rough"][0] + k["rough"][1] * (mid - 0.5) * 2 + 0.25 * grime
    metal = np.full((n, n), k["metal"])
    height = 0.15 * (hi - 0.5)
    if k["chips"] > 0:
        field = _noise(n, 1.4, rng) * 0.7 + hi * 0.3
        mask = np.clip((field - np.quantile(field, 1 - k["chips"])) * 40, 0, 1)
        alb = alb * (1 - mask[..., None]) + chip * mask[..., None]
        rough = rough * (1 - mask) + 0.6 * mask
        metal = metal * (1 - mask) + (0.5 if kind != "steel" else 0.2) * mask
        height -= 0.6 * mask
    height *= k["bump"]
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 2.0
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 2.0
    nz = 1.0 / np.sqrt(dx * dx + dy * dy + 1)
    normal = np.stack([0.5 - 0.5 * dx * nz, 0.5 - 0.5 * dy * nz, 0.5 + 0.5 * nz], axis=-1)
    orm = np.stack([np.ones((n, n)), np.clip(rough, 0.04, 1), np.clip(metal, 0, 1)], axis=-1)

    m = material(name, color, rough=k["rough"][0], metal=k["metal"], coat=coat, one_sided=one_sided)
    nt = m.node_tree
    p = _principled(m)
    uv = nt.nodes.new("ShaderNodeUVMap")

    def tex(suffix, data, colour):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = _image(f"{name}_{suffix}", data, colour)
        nt.links.new(uv.outputs["UV"], t.inputs["Vector"])
        return t

    nt.links.new(tex("albedo", alb, True).outputs["Color"], p.inputs["Base Color"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tex("orm", orm, False).outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], p.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], p.inputs["Metallic"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex("normal", normal, False).outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], p.inputs["Normal"])
    return m


# ------------------------------------------------------------------ objects

def _box_uv(bm):
    layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != axis]
        for loop in f.loops:
            co = loop.vert.co
            loop[layer].uv = (co[a] / UV_TILE, co[b] / UV_TILE)


def make(name, parent, mat, build, bevel=0.0, segs=3, smooth=True, loc=None, angle=35, subsurf=0):
    """Object from a bmesh builder. `mat` is one material or a list (the builder sets face.material_index).
    `bevel` rounds every edge sharper than `angle` degrees. `subsurf` > 0 treats the mesh as a control
    cage and smooths it that many times (Catmull-Clark): for curved bodies such as a cab."""
    bm = bmesh.new()
    build(bm)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    _box_uv(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if smooth and subsurf == 0 and hasattr(mesh, "set_sharp_from_angle"):
        mesh.set_sharp_from_angle(angle=math.radians(angle))
    for m in mat if isinstance(mat, (list, tuple)) else [mat]:
        mesh.materials.append(m)
    ob = _link(bpy.data.objects.new(name, mesh), parent, loc)
    if subsurf > 0:
        sub = ob.modifiers.new("subsurf", "SUBSURF")
        sub.levels = subsurf
        sub.render_levels = subsurf
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        mod.harden_normals = True
        # Flat faces stay flat next to the rounded edges (otherwise big panels shade unevenly).
        wn = ob.modifiers.new("weighted_normal", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
        wn.weight = 100
    return ob


def add_box(bm, lo, hi):
    lo, hi = Vector(lo), Vector(hi)
    c, s = (lo + hi) / 2, hi - lo
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(c) @ Matrix.Diagonal((abs(s.x), abs(s.y), abs(s.z), 1)))


def add_obox(bm, center, u, v, half):
    """Box with axes u, v and u x v (unit vectors are made from them), half sizes along the three."""
    u = Vector(u).normalized()
    w = u.cross(Vector(v)).normalized()
    v = w.cross(u)
    M = Matrix.Identity(4)
    for k, axis in enumerate((u, v, w)):
        for r in range(3):
            M[r][k] = axis[r] * 2 * half[k]
    M.translation = Vector(center)
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)


def add_cyl(bm, r, p0, p1, segs=24, r1=None):
    """Closed cylinder or cone between two points (radius r at p0, r1 at p1)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    M = Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r1 is None else r1, depth=d.length, matrix=M)


def add_sphere(bm, r, c, segs=16, rings=8):
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r, matrix=Matrix.Translation(Vector(c)))


def add_prism(bm, pts, axis, a0, a1):
    """Polygon extruded along `axis` ('x' or 'y') from a0 to a1. For 'y' the points are (x, z), for 'x' (y, z)."""
    def at(p, a):
        return (p[0], a, p[1]) if axis == "y" else (a, p[0], p[1])

    lo = [bm.verts.new(at(p, a0)) for p in pts]
    hi = [bm.verts.new(at(p, a1)) for p in pts]
    n = len(pts)
    bm.faces.new(lo)
    bm.faces.new(hi[::-1])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], hi[i], hi[j], lo[j]))


def add_tube(bm, pts, r, segs=10, closed=False):
    """Round tube along a polyline: capped, or a closed loop."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    rings = []
    side = None
    for i, p in enumerate(pts):
        before = pts[(i - 1) % n] if closed else pts[max(i - 1, 0)]
        after = pts[(i + 1) % n] if closed else pts[min(i + 1, n - 1)]
        t = (after - before).normalized()
        if side is None:
            side = t.cross(Vector((0, 0, 1)))
            if side.length < 1e-4:
                side = t.cross(Vector((0, 1, 0)))
        # Carry the frame along the path so the tube does not twist.
        side = side - t * side.dot(t)
        if side.length < 1e-5:
            side = t.cross(Vector((0, 0, 1)))
        side.normalize()
        top = side.cross(t)
        rings.append([bm.verts.new(p + r * (math.cos(2 * math.pi * k / segs) * side + math.sin(2 * math.pi * k / segs) * top)) for k in range(segs)])
    pairs = list(zip(rings, rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for a, b in pairs:
        for k in range(segs):
            k1 = (k + 1) % segs
            bm.faces.new((a[k], a[k1], b[k1], b[k]))
    if not closed:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])


def add_lathe_y(bm, profile, center=(0, 0, 0), segs=48):
    """Solid of revolution about the Y axis through `center`: profile is (radius, y) pairs. Close the profile
    (end on the axis or repeat the first point) for a solid."""
    cx, cy, cz = center
    rings = []
    for r, y in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((cx, cy + y, cz))])
        else:
            rings.append([bm.verts.new((cx + r * math.cos(2 * math.pi * k / segs), cy + y, cz + r * math.sin(2 * math.pi * k / segs))) for k in range(segs)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for k in range(segs):
            k1 = (k + 1) % segs
            if len(a) == 1:
                bm.faces.new((a[0], b[k1], b[k]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[k1], b[0]))
            else:
                bm.faces.new((a[k], a[k1], b[k1], b[k]))


def arc(c, r, a0, a1, n=12):
    """Points on a circle around c from angle a0 to a1 (degrees)."""
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def fillet(pts, r, n=4):
    """Rounds the corners of a closed polygon with radius r (n segments per corner)."""
    out = []
    count = len(pts)
    for i in range(count):
        p0, p, p1 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % count])
        a, b = (p0 - p), (p1 - p)
        d = min(r, a.length * 0.45, b.length * 0.45)
        s, e = p + a.normalized() * d, p + b.normalized() * d
        for k in range(n + 1):
            t = k / n
            out.append(tuple((1 - t) ** 2 * s + 2 * (1 - t) * t * p + t * t * e))
    return out


def export_glb(path):
    """Everything in the scene as one GLB, Y-up, modifiers applied, textures as JPEG."""
    args = dict(filepath=str(path), export_format="GLB", export_yup=True, export_apply=True, export_cameras=False,
        export_lights=False, export_animations=False, export_image_format="JPEG")
    try:
        bpy.ops.export_scene.gltf(export_jpeg_quality=88, **args)
    except TypeError:
        bpy.ops.export_scene.gltf(**args)
    _strip_colour_profiles(path)


def _strip_colour_profiles(path):
    """Blender embeds an ICC profile in sRGB JPEGs; Godot's JPEG reader rejects those. Re-encodes such
    images without the profile and rewrites the GLB's binary chunk."""
    import io
    import json
    import struct

    from PIL import Image

    raw = open(path, "rb").read()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    js = json.loads(raw[20 : 20 + jlen])
    off = 20 + jlen
    blen = struct.unpack_from("<I", raw, off)[0]
    blob = raw[off + 8 : off + 8 + blen]
    image_views = {im["bufferView"] for im in js.get("images", []) if "bufferView" in im}
    out = bytearray()
    for i, view in enumerate(js["bufferViews"]):
        start = view.get("byteOffset", 0)
        data = blob[start : start + view["byteLength"]]
        if i in image_views:
            img = Image.open(io.BytesIO(data))
            if img.info.get("icc_profile"):
                buf = io.BytesIO()
                img.convert("RGB").save(buf, "JPEG", quality=90)
                data = buf.getvalue()
        out += b"\0" * (-len(out) % 4)
        view["byteOffset"] = len(out)
        view["byteLength"] = len(data)
        out += data
    out += b"\0" * (-len(out) % 4)
    js["buffers"][0]["byteLength"] = len(out)
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * (-len(jb) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(out)))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A))
        f.write(jb)
        f.write(struct.pack("<II", len(out), 0x004E4942))
        f.write(out)
