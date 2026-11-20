"""A street tree for the game, made from a scanned tree that is far too heavy to show as it is
(docs/TECH_SPEC.md, Modul Y).

Source: "Tree Small 02" from Poly Haven (https://polyhaven.com/a/tree_small_02, CC0), in the prepared copy
of the raisim2Lib project: one of the trees of the original line-up, 1K maps
(https://github.com/raisimTech/raisim2Lib, rsc/forest/tree_small_02 at commit
d9df2c979c9ddc44ec6b6727ff72c660688fdb62: model.gltf, mesh.bin of 95 MB and nine maps). That folder is not
in this repository: fetch it and pass its path.

The source has 2.06 million triangles, 1.94 million of them in 30,000 separate leaves and sprigs. This script
  - keeps one leaf piece in KEEP and makes each of those GROW times as large, so the crown stays about as full;
  - thins leaves, branches and trunk further (Blender's collapse decimation);
  - fills the black ground of the leaf map with the leaves' own colours, so no dark rims show from afar;
  - lays the branches' second UV set (with its texture transform) into the first, which is all Godot reads;
  - stands the tree on the ground with its foot at the origin, HEIGHT metres tall;
and writes game/assets/models/nature/street_tree.glb (about 60,000 triangles).

    PYTHONPATH=<bpy env> python3 tools/blender/tree.py <path to tree_small_02>
"""
import json
import pathlib
import sys
import tempfile

import numpy as np
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mm_kit as K

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/models/nature/street_tree.glb"
KEEP = 8          # one leaf piece in this many stays
GROW = 2.4        # and grows by this factor
THIN = {"leaves": 0.22, "branches": 0.16, "trunk": 0.2}
HEIGHT = 6.2

source = pathlib.Path(sys.argv[1])
g = json.load(open(source / "model.gltf"))
blob = np.memmap(source / g["buffers"][0]["uri"], dtype=np.uint8, mode="r")
TYPES = {5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def accessor(i):
    a = g["accessors"][i]
    view = g["bufferViews"][a["bufferView"]]
    dt = np.dtype(TYPES[a["componentType"]])
    n = WIDTH[a["type"]]
    assert view.get("byteStride", 0) in (0, dt.itemsize * n)
    data = np.frombuffer(blob, dtype=dt, count=a["count"] * n, offset=view.get("byteOffset", 0) + a.get("byteOffset", 0))
    return data.reshape(a["count"], n) if n > 1 else data


parts = {}
for prim in g["meshes"][0]["primitives"]:
    mat = g["materials"][prim["material"]]
    label = mat["name"].replace("tree_small_02_", "")
    pos = accessor(prim["attributes"]["POSITION"]).astype(np.float64)
    nor = accessor(prim["attributes"]["NORMAL"]).astype(np.float64)
    tris = accessor(prim["indices"]).reshape(-1, 3).astype(np.int64)
    tex = mat["pbrMetallicRoughness"]["baseColorTexture"]
    uv = accessor(prim["attributes"]["TEXCOORD_%d" % tex.get("texCoord", 0)]).astype(np.float64)
    move = tex.get("extensions", {}).get("KHR_texture_transform")
    if move:
        uv = uv * np.array(move.get("scale", [1, 1])) + np.array(move.get("offset", [0, 0]))
    if label == "leaves":
        # Pieces: what hangs together once vertices at one place count as one.
        _, weld = np.unique(np.round(pos * 20000).astype(np.int64), axis=0, return_inverse=True)
        weld = weld.ravel()
        w = weld[tris]
        n = int(weld.max()) + 1
        count, piece_of = connected_components(coo_matrix((np.ones(len(w) * 2, np.int8),
            (np.concatenate([w[:, 0], w[:, 1]]), np.concatenate([w[:, 1], w[:, 2]]))), shape=(n, n)), directed=False)
        stays = np.random.default_rng(7).random(count) < 1.0 / KEEP
        kept = tris[stays[piece_of[w[:, 0]]]]
        used, inverse = np.unique(kept.ravel(), return_inverse=True)
        pos, nor, uv, tris = pos[used], nor[used], uv[used], inverse.reshape(-1, 3)
        # Each piece grows about its own middle.
        _, local = np.unique(piece_of[weld[used]], return_inverse=True)
        middle = np.zeros((local.max() + 1, 3))
        np.add.at(middle, local, pos)
        middle /= np.bincount(local)[:, None]
        pos = middle[local] + (pos - middle[local]) * GROW
        print("leaves: %d pieces of %d stay, %d triangles" % (local.max() + 1, count, len(tris)))
    parts[label] = (pos, nor, uv, tris, mat)

# The source's mesh stands upright along y, as glTF has it; its node only lays it over for a world
# whose z points up. That turn is left out here.
work = pathlib.Path(tempfile.mkdtemp(prefix="tree_"))
buffer = bytearray()
views, accessors, meshes, nodes, materials, images, textures = [], [], [], [], [], [], []


def push(data, target=None):
    while len(buffer) % 4:
        buffer.append(0)
    views.append({"buffer": 0, "byteOffset": len(buffer), "byteLength": data.nbytes, **({"target": target} if target else {})})
    buffer.extend(data.tobytes())
    return len(views) - 1


def image(uri):
    images.append({"uri": uri})
    textures.append({"source": len(images) - 1})
    return len(textures) - 1


for label, (pos, nor, uv, tris, mat) in parts.items():
    pos = pos.astype(np.float32)
    nor = nor.astype(np.float32)
    uv = uv.astype(np.float32)
    tris = tris.astype(np.uint32)
    a0 = len(accessors)
    accessors.append({"bufferView": push(pos, 34962), "componentType": 5126, "count": len(pos), "type": "VEC3", "min": pos.min(0).tolist(), "max": pos.max(0).tolist()})
    accessors.append({"bufferView": push(nor, 34962), "componentType": 5126, "count": len(nor), "type": "VEC3"})
    accessors.append({"bufferView": push(uv, 34962), "componentType": 5126, "count": len(uv), "type": "VEC2"})
    accessors.append({"bufferView": push(tris.ravel(), 34963), "componentType": 5125, "count": tris.size, "type": "SCALAR"})
    pbr = mat["pbrMetallicRoughness"]
    colour = str((source / g["images"][g["textures"][pbr["baseColorTexture"]["index"]]["source"]]["uri"]).resolve())
    if label == "leaves":
        # The leaf map's ground is black: give every such pixel the colour of the nearest leaf.
        from PIL import Image
        picture = np.asarray(Image.open(colour).convert("RGB")).astype(np.int32)
        ground = picture.sum(2) < 40
        nearest = ndimage.distance_transform_edt(ground, return_distances=False, return_indices=True)
        filled = picture[nearest[0], nearest[1]].astype(np.uint8)
        colour = str(work / "leaves_diff.jpg")
        Image.fromarray(filled).save(colour, quality=92)
    made = {"name": "tree_" + label, "doubleSided": True, "pbrMetallicRoughness": {"baseColorTexture": {"index": image(colour)}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}
    if "normalTexture" in mat:
        made["normalTexture"] = {"index": image(str((source / g["images"][g["textures"][mat["normalTexture"]["index"]]["source"]]["uri"]).resolve()))}
    if "metallicRoughnessTexture" in pbr:
        made["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": image(str((source / g["images"][g["textures"][pbr["metallicRoughnessTexture"]["index"]]["source"]]["uri"]).resolve()))}
    materials.append(made)
    meshes.append({"name": label, "primitives": [{"attributes": {"POSITION": a0, "NORMAL": a0 + 1, "TEXCOORD_0": a0 + 2}, "indices": a0 + 3, "material": len(materials) - 1}]})
    nodes.append({"name": "tree_" + label, "mesh": len(meshes) - 1})
(work / "tree.bin").write_bytes(bytes(buffer))
json.dump({"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes, "meshes": meshes,
    "materials": materials, "textures": textures, "images": images, "accessors": accessors, "bufferViews": views,
    "buffers": [{"uri": "tree.bin", "byteLength": len(buffer)}]}, open(work / "tree.gltf", "w"))

K.reset()
bpy.ops.import_scene.gltf(filepath=str(work / "tree.gltf"))
objects = {ob.name.replace("tree_", ""): ob for ob in bpy.data.objects if ob.type == "MESH"}
for label, ob in objects.items():
    before = len(ob.data.polygons)
    thin = ob.modifiers.new("thin", "DECIMATE")
    thin.ratio = THIN[label]
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=thin.name)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    print(label, before, "->", len(ob.data.polygons), "triangles")
# Foot of the trunk to the origin, the whole tree to HEIGHT.
trunk = objects["trunk"]
low = min((trunk.matrix_world @ v.co).z for v in trunk.data.vertices)
foot = [trunk.matrix_world @ v.co for v in trunk.data.vertices if (trunk.matrix_world @ v.co).z < low + 0.15]
middle = sum(foot, Vector()) / len(foot)
top = max((ob.matrix_world @ v.co).z for ob in objects.values() for v in ob.data.vertices)
scale = HEIGHT / (top - low)
place = Matrix.Scale(scale, 4) @ Matrix.Translation(Vector((-middle.x, -middle.y, -low - 0.04)))
tree = K.empty("street_tree")
for label, ob in objects.items():
    ob.data.transform(place @ ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)
    ob.parent = tree
print("height %.2f m, scale %.2f" % (HEIGHT, scale))
OUT.parent.mkdir(parents=True, exist_ok=True)
K.export_glb(OUT, 'Made from "Tree Small 02" (https://polyhaven.com/a/tree_small_02), Poly Haven, CC0, in the prepared copy of '
    "raisimTech/raisim2Lib (rsc/forest/tree_small_02). Changed for MOLTEN MATES: one leaf piece in %d kept and enlarged, all parts "
    "thinned, the leaf map's black ground filled, resized." % KEEP)
print("WROTE", OUT, OUT.stat().st_size)
