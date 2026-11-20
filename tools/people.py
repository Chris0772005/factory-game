"""Townspeople for the game from generated character models (docs/TECH_SPEC.md, Modul Y).

The sources are AI-generated: a studio picture of each person (Higgsfield, model GPT Image 2.6) was turned
into a rigged, textured figure with a slow walk (Meshy 7 image-to-3D through Higgsfield; clip "Casual_Walk"
of its library), and more clips were made for the first figure (Meshy rigging; the ones used here are
"Quick_Walk", "Run_02" and "Wave_One_Hand"). The source files are not in this repository (10 to 13 MB each);
the job ids are listed in game/assets/models/people/NOTICE.txt.

This script (Python without Blender) writes game/assets/models/people/<name>.glb for each person:
  - its own mesh and skeleton, and its own slow walk as the clip Stroll;
  - the walking, running and waving clips of the first figure, carried over: every rig of this
    kind has the same bones, so the clips' bone rotations fit as they are; the hips' travel is scaled to
    the person's size, and every other bone keeps the place it has in the person's own skeleton;
  - a clip of standing still, made from the waving clip (the library's own standing clip is a fighter's
    stance): the body as it stands while waving, the waving arm replaced by the mirror image of the
    other one half a clip later, both arms rolled so the palms face the legs, the head's turn softened,
    the end led back into the start;
  - every clip set on the ground: the hips are raised or lowered by what the soles of the person's own
    feet are off it in that clip (the clips come a few centimetres too high or too low);
  - clips named Stroll, Idle_Neutral, Walk, Run and Wave (the names TownFigure plays);
  - the maps laid out anew. The generator cuts the skin into thousands of small patches and packs them
    edge to edge, whatever their colour; from a few metres away the colours of neighbouring patches run
    into each other and the figure looks speckled. Here every patch keeps its size, its direction and its
    picture (so the normal map stays right) but moves: patches of like colour lie together, with GAP
    pixels between them, and the room between is filled with the nearest patch's colour;
  - the colour map at that full size, normal and roughness at half of it, as JPEG files beside the model
    (<name>_colour.jpg, <name>_normal.jpg, <name>_rough.jpg).

Needs numpy, scipy and Pillow.

    python3 -I tools/people.py <folder with <name>_walk.glb and worker_quick.glb, worker_run.glb,
                                worker_wave.glb> [folder to write to instead of the game's]

A further person needs only its own <name>_walk.glb in that folder (and its name in PEOPLE): where the
first figure's extra files are missing, its clips are taken from the finished worker.glb in the game; a
figure generated without a clip gets the first figure's slow walk as well.
"""
import io
import json
import pathlib
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.cluster.vq import kmeans2
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

ROOT = pathlib.Path(__file__).resolve().parents[1]
GAME = ROOT / "game/assets/models/people"
# Where the figures are written: the game's folder, or the folder given second (to try something out).
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else GAME
PEOPLE = ["worker", "broker", "officer", "woman", "youth"]
# Clips taken from the first figure's extra files: file suffix -> clip name in the game.
SHARED = {"quick": "Walk", "run": "Run", "wave": "Wave"}
DONOR = "worker"
# Standing still is made from this one of them (see idle_tracks).
IDLE_FROM = "wave"
ARM = ("Shoulder", "Arm", "ForeArm", "Hand")
# A left bone's rotation, mirrored for the right bone of the same name (the rig is built mirrored).
MIRROR = np.array([1.0, -1.0, -1.0, 1.0], np.float32)
# Standing still, the left arm's bones are rolled about their own length by these angles (degrees), so the
# palms face the legs instead of the front as they do in the waving clip.
ROLL = {"Arm": 25.0, "ForeArm": 45.0}
# The maps' new layout: width (px), room between patches (px), groups of like colour, and the wider room
# between two groups.
ATLAS_WIDTH = 3072
GAP = 8
GROUPS = 10
GROUP_GAP = 24
TYPES = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        raw = pathlib.Path(path).read_bytes()
        jlen = struct.unpack_from("<I", raw, 12)[0]
        self.json = json.loads(raw[20:20 + jlen])
        start = 20 + jlen
        blen = struct.unpack_from("<I", raw, start)[0]
        self.bin = raw[start + 8:start + 8 + blen]
        self.names = [n.get("name") for n in self.json["nodes"]]

    def view(self, i):
        v = self.json["bufferViews"][i]
        return self.bin[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]

    def array(self, i):
        a = self.json["accessors"][i]
        v = self.json["bufferViews"][a["bufferView"]]
        dt = np.dtype(TYPES[a["componentType"]])
        n = WIDTH[a["type"]]
        return np.frombuffer(self.bin, dtype=dt, count=a["count"] * n, offset=v.get("byteOffset", 0) + a.get("byteOffset", 0)).reshape(a["count"], n)

    def hips(self):
        return self.json["nodes"][self.names.index("Hips")]["translation"][1]


def clip_tracks(glb, hips_scale=1.0, which=0):
    """The tracks of one of a file's clips (the first, or the one of that name) that carry over:
    [(bone, path, times, values)]."""
    out = []
    clips = glb.json["animations"]
    clip = clips[which] if isinstance(which, int) else next(c for c in clips if c["name"] == which)
    for ch in clip["channels"]:
        bone = glb.names[ch["target"]["node"]]
        path = ch["target"]["path"]
        if path == "scale" or (path == "translation" and bone != "Hips"):
            continue
        sampler = clip["samplers"][ch["sampler"]]
        values = glb.array(sampler["output"]).astype(np.float32)
        if path == "translation":
            values = values * np.float32(hips_scale)
        out.append((bone, path, glb.array(sampler["input"]).astype(np.float32).ravel(), values))
    return out


def steady(values):
    """Rotations key by key on the same side of the sphere, so they can be averaged and mixed."""
    out = values.copy()
    for i in range(1, len(out)):
        if np.dot(out[i], out[i - 1]) < 0.0:
            out[i] = -out[i]
    return out


def mix(a, b, k):
    made = a + (b - a) * k
    return made / np.linalg.norm(made, axis=-1, keepdims=True) if made.shape[-1] == 4 else made


def closed(values, keys=15):
    """The clip's last `keys` keys led back into its first, so it repeats without a jump."""
    out = steady(values) if values.shape[1] == 4 else values.copy()
    first = out[0] if values.shape[1] != 4 or np.dot(out[0], out[-1]) >= 0.0 else -out[0]
    for i in range(keys):
        out[len(out) - keys + i] = mix(out[len(out) - keys + i], first, (i + 1) / keys)
    return out


def rolled(values, degrees):
    """Rotations with a roll about the bone's own length (its y axis) added."""
    half = np.radians(degrees) * 0.5
    x, y, z, w = values[:, 0], values[:, 1], values[:, 2], values[:, 3]
    s, c = np.sin(half), np.cos(half)
    # values * (0, s, 0, c)
    return np.stack([x * c - z * s, y * c + w * s, z * c + x * s, w * c - y * s], axis=1)


def idle_tracks(wave, hips_scale):
    """Standing still, from the waving clip: see the top of this file."""
    tracks = {(bone, path): (times, values) for bone, path, times, values in clip_tracks(wave, hips_scale)}

    def left_arm(part):
        values = closed(tracks[("Left" + part, "rotation")][1])
        return rolled(values, ROLL[part]) if part in ROLL else values

    out = []
    for (bone, path), (times, values) in tracks.items():
        if path == "rotation" and bone.startswith("Left") and bone[4:] in ARM:
            values = left_arm(bone[4:])
        elif path == "rotation" and bone.startswith("Right") and bone[5:] in ARM:
            # The waving arm: the other one's mirror image, half a clip later.
            left = left_arm(bone[5:])
            values = np.roll(left, len(left) // 2, axis=0) * MIRROR
        else:
            values = closed(values)
            if bone == "Head" and path == "rotation":
                middle = values.mean(axis=0)
                values = mix(middle / np.linalg.norm(middle), values, 0.4)
        out.append((bone, path, times, values.astype(np.float32)))
    return out


def looping(tracks):
    """A clip that ends on the picture it starts with would stand still for one key each time round:
    without that last key it runs on. Other clips stay as they are."""
    same = all(np.abs(values[-1] - values[0]).max() < 2e-3 or (values.shape[1] == 4 and np.abs(values[-1] + values[0]).max() < 2e-3)
        for _bone, _path, _times, values in tracks)
    if not same:
        return tracks
    return [(bone, path, times[:-1], values[:-1]) for bone, path, times, values in tracks]


def turn(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


class Body:
    """A person's skeleton with the skin below the knees, to find the soles' height in a clip."""

    def __init__(self, glb):
        g = glb.json
        self.nodes = g["nodes"]
        self.names = glb.names
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        self.order = []
        todo = [i for i in range(len(self.nodes)) if i not in self.parent]
        while todo:
            n = todo.pop()
            self.order.append(n)
            todo.extend(self.nodes[n].get("children", []))
        skin = g["skins"][0]
        self.joints = skin["joints"]
        self.inverse = glb.array(skin["inverseBindMatrices"]).astype(np.float64).reshape(-1, 4, 4).transpose(0, 2, 1)
        prim = g["meshes"][0]["primitives"][0]
        position = glb.array(prim["attributes"]["POSITION"]).astype(np.float64)
        low = position[:, 1] < position[:, 1].min() + 0.3
        self.points = np.concatenate([position[low], np.ones((int(low.sum()), 1))], axis=1)
        self.bones = glb.array(prim["attributes"]["JOINTS_0"]).astype(np.int64)[low]
        self.weights = glb.array(prim["attributes"]["WEIGHTS_0"]).astype(np.float64)[low]

    def world(self, tracks, key):
        """Every node's place in the world at that key of the clip's tracks ({(bone, path): values})."""
        out = {}
        for n in self.order:
            node = self.nodes[n]
            move = np.array(node.get("translation", [0, 0, 0]), np.float64)
            spin = np.array(node.get("rotation", [0, 0, 0, 1]), np.float64)
            size = np.array(node.get("scale", [1, 1, 1]), np.float64)
            if (self.names[n], "translation") in tracks:
                values = tracks[(self.names[n], "translation")]
                move = values[min(key, len(values) - 1)].astype(np.float64)
            if (self.names[n], "rotation") in tracks:
                values = tracks[(self.names[n], "rotation")]
                spin = values[min(key, len(values) - 1)].astype(np.float64)
            local = np.eye(4)
            local[:3, :3] = turn(spin) * size
            local[:3, 3] = move
            out[n] = out[self.parent[n]] @ local if n in self.parent else local
        return out

    def grounded(self, tracks):
        """The clip's tracks with the hips moved up or down so that the soles meet the ground: the height
        of the lowest point of the feet, at the keys where the feet are lowest (the lowest three in ten)."""
        by_name = {(bone, path): values for bone, path, _times, values in tracks}
        hips = self.names.index("Hips")
        lows = []
        for key in range(0, max(len(v) for v in by_name.values()), 2):
            world = self.world(by_name, key)
            bones = np.array([world[j] @ self.inverse[i] for i, j in enumerate(self.joints)])
            skinned = np.zeros(len(self.points))
            for c in range(4):
                skinned += self.weights[:, c] * np.einsum("nj,nj->n", bones[self.bones[:, c]][:, 1, :], self.points)
            lows.append(skinned.min())
        off = float(np.percentile(lows, 30))
        # That much in the world, seen from the hips' parent.
        rest = self.world({}, 0)
        lift = np.linalg.inv(rest[self.parent[hips]][:3, :3]) @ np.array([0.0, -off, 0.0])
        out = []
        for bone, path, times, values in tracks:
            if bone == "Hips" and path == "translation":
                values = (values + lift).astype(np.float32)
            out.append((bone, path, times, values))
        return out, off


def repacked(glb):
    """The figure's maps laid out anew (see the top of this file).
    Returns the new texture coordinates and {image index: picture at full size}."""
    g = glb.json
    prim = g["meshes"][0]["primitives"][0]
    uv = glb.array(prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    tris = glb.array(prim["indices"]).reshape(-1, 3).astype(np.int64)
    material = g["materials"][prim["material"]]
    colour_index = g["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
    pictures = {i: Image.open(io.BytesIO(glb.view(im["bufferView"]))).convert("RGB") for i, im in enumerate(g["images"])}
    width, height = pictures[colour_index].size
    for i, picture in pictures.items():
        if picture.size != (width, height):
            pictures[i] = picture.resize((width, height), Image.LANCZOS)
    # Patches: triangles that hang together (the mesh is split wherever the map is cut).
    n = len(uv)
    _count, label = connected_components(coo_matrix((np.ones(len(tris) * 2, np.int8),
        (np.concatenate([tris[:, 0], tris[:, 1]]), np.concatenate([tris[:, 1], tris[:, 2]]))), shape=(n, n)), directed=False)
    names, patch_of = np.unique(label, return_inverse=True)
    patch_of = patch_of.ravel() + 1
    # Which patch each pixel belongs to: the patch drawn there, or else the nearest one within 2 px
    # (the generator's own padding, which the patch's edge needs when it is sampled).
    drawn = Image.new("I", (width, height), 0)
    pen = ImageDraw.Draw(drawn)
    at = np.stack([uv[:, 0] * width, uv[:, 1] * height], axis=1)
    for a, b, c in tris:
        pen.polygon([tuple(at[a]), tuple(at[b]), tuple(at[c])], fill=int(patch_of[a]), outline=int(patch_of[a]))
    core = np.asarray(drawn)
    distance, (near_y, near_x) = ndimage.distance_transform_edt(core == 0, return_indices=True)
    owner = np.where(distance <= 2.0, core[near_y, near_x], 0)
    boxes = ndimage.find_objects(owner, max_label=len(names))
    colour = np.asarray(pictures[colour_index]).astype(np.float64)
    patches = []
    for index, box in enumerate(boxes):
        if box is None:
            continue
        mask = owner[box] == index + 1
        inside = core[box] == index + 1
        mean = colour[box][inside if inside.any() else mask].mean(axis=0)
        patches.append({"id": index + 1, "box": box, "mask": mask, "mean": mean, "h": mask.shape[0], "w": mask.shape[1]})
    # Groups of like colour, the darkest first; inside a group the tallest patches first.
    means = np.array([p["mean"] for p in patches])
    _centres, group = kmeans2(means, GROUPS, minit="++", seed=7)
    darkness = [means[group == k].mean() if (group == k).any() else 1e9 for k in range(GROUPS)]
    rank = {k: r for r, k in enumerate(np.argsort(darkness))}
    for patch, k in zip(patches, group):
        patch["group"] = rank[int(k)]
    patches.sort(key=lambda p: (p["group"], -p["h"], -p["w"]))
    # Shelves: left to right, a new shelf when the row is full, a new one with more room for each group.
    x = y = GAP
    shelf = 0
    last_group = patches[0]["group"]
    for patch in patches:
        if patch["group"] != last_group:
            x = GAP
            y += shelf + GROUP_GAP
            shelf = 0
            last_group = patch["group"]
        elif x + patch["w"] + GAP > ATLAS_WIDTH:
            x = GAP
            y += shelf + GAP
            shelf = 0
        patch["x"], patch["y"] = x, y
        x += patch["w"] + GAP
        shelf = max(shelf, patch["h"])
    new_height = int(np.ceil((y + shelf + GAP) / 8.0) * 8)
    # The pictures.
    filled = np.zeros((new_height, ATLAS_WIDTH), bool)
    made = {i: np.zeros((new_height, ATLAS_WIDTH, 3), np.uint8) for i in pictures}
    sources = {i: np.asarray(picture) for i, picture in pictures.items()}
    shift = np.zeros((len(names) + 1, 2))
    for patch in patches:
        rows, cols = patch["box"]
        to = (slice(patch["y"], patch["y"] + patch["h"]), slice(patch["x"], patch["x"] + patch["w"]))
        filled[to] |= patch["mask"]
        for i in pictures:
            made[i][to][patch["mask"]] = sources[i][rows, cols][patch["mask"]]
        shift[patch["id"]] = (patch["x"] - cols.start, patch["y"] - rows.start)
    _distance, (near_y, near_x) = ndimage.distance_transform_edt(~filled, return_indices=True)
    out = {i: Image.fromarray(picture[near_y, near_x]) for i, picture in made.items()}
    moved = (at + shift[patch_of]) / np.array([ATLAS_WIDTH, new_height], np.float64)
    print("  maps: %d patches in %d groups, %d x %d px laid out anew as %d x %d px" % (len(patches), GROUPS, width, height, ATLAS_WIDTH, new_height))
    return moved.astype(np.float32), out


def build(name, source):
    person = Glb(source / ("%s_walk.glb" % name))
    g = person.json
    blob = bytearray()
    views = []

    def push(data, target=None):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), **({"target": target} if target else {})})
        blob.extend(data)
        return len(views) - 1

    # Mesh and skin data as they are (every accessor that is not an animation's).
    animated = set()
    for clip in g.get("animations", []):
        for s in clip["samplers"]:
            animated.update((s["input"], s["output"]))
    walk = clip_tracks(person) if g.get("animations") else None
    coordinates, pictures = repacked(person)
    coordinates_at = g["meshes"][0]["primitives"][0]["attributes"]["TEXCOORD_0"]
    accessors = []
    remap = {}
    for i, a in enumerate(g["accessors"]):
        if i in animated:
            continue
        v = g["bufferViews"][a["bufferView"]]
        size = np.dtype(TYPES[a["componentType"]]).itemsize * WIDTH[a["type"]] * a["count"]
        start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        made = {k: val for k, val in a.items() if k not in ("bufferView", "byteOffset")}
        data = person.bin[start:start + size]
        if i == coordinates_at:
            assert a["componentType"] == 5126 and a["type"] == "VEC2" and v.get("byteStride", 0) in (0, 8)
            data = coordinates.tobytes()
            made["min"] = coordinates.min(axis=0).tolist()
            made["max"] = coordinates.max(axis=0).tolist()
        made["bufferView"] = push(data, v.get("target"))
        remap[i] = len(accessors)
        accessors.append(made)
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: remap[v] for k, v in prim["attributes"].items()}
            prim["indices"] = remap[prim["indices"]]
    for skin in g.get("skins", []):
        skin["inverseBindMatrices"] = remap[skin["inverseBindMatrices"]]

    # Maps: colour at full size, the others at half; as files beside the model, which only names them
    # (inside the model Godot would write a second copy of each next to it).
    material = g["materials"][g["meshes"][0]["primitives"][0]["material"]]
    roles = {
        g["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]: "colour",
        g["textures"][material["normalTexture"]["index"]]["source"]: "normal",
        g["textures"][material["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"]]["source"]: "rough",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for index in range(len(g["images"])):
        picture = pictures[index]
        role = roles[index]
        if role != "colour":
            picture = picture.resize((picture.size[0] // 2, picture.size[1] // 2), Image.LANCZOS)
        file_name = "%s_%s.jpg" % (name, role)
        picture.save(OUT / file_name, "JPEG", quality=88 if role == "colour" else 90)
        g["images"][index] = {"uri": file_name, "name": "%s_%s" % (name, role)}

    # Clips.
    def add_clip(label, tracks):
        channels, samplers = [], []
        for bone, path, times, values in tracks:
            if bone not in person.names:
                continue
            accessors.append({"bufferView": push(times.tobytes()), "componentType": 5126, "count": len(times), "type": "SCALAR",
                "min": [float(times.min())], "max": [float(times.max())]})
            accessors.append({"bufferView": push(values.tobytes()), "componentType": 5126, "count": len(values),
                "type": "VEC4" if path == "rotation" else "VEC3"})
            samplers.append({"input": len(accessors) - 2, "output": len(accessors) - 1, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": person.names.index(bone), "path": path}})
        return {"name": label, "channels": channels, "samplers": samplers}

    body = Body(person)
    clips = []
    off = {}
    keys = {}

    def clip(label, tracks):
        if label != "Wave":
            tracks = looping(tracks)
        tracks, off[label] = body.grounded(tracks)
        clips.append(add_clip(label, tracks))
        keys[label] = len(tracks[0][2])

    extra = {suffix: source / ("%s_%s.glb" % (DONOR, suffix)) for suffix in SHARED}
    if all(path.exists() for path in extra.values()) and walk is not None:
        clip("Stroll", walk)
        for suffix, label in SHARED.items():
            donor = Glb(extra[suffix])
            size = person.hips() / donor.hips()
            clip(label, clip_tracks(donor, size))
            if suffix == IDLE_FROM:
                clip("Idle_Neutral", idle_tracks(donor, size))
    else:
        # Without the first figure's extra files (or for a figure that came without a walk of its own):
        # the first figure's finished file in the game holds every clip.
        donor = Glb(GAME / (DONOR + ".glb"))
        size = person.hips() / donor.hips()
        clip("Stroll", walk if walk is not None else clip_tracks(donor, size, "Stroll"))
        for label in list(SHARED.values()) + ["Idle_Neutral"]:
            clip(label, clip_tracks(donor, size, label))
    g["animations"] = clips
    g["accessors"] = accessors
    g["bufferViews"] = views
    g["buffers"] = [{"byteLength": len(blob)}]
    g["asset"]["copyright"] = "AI-generated for MOLTEN MATES (Higgsfield: GPT Image 2.6, Meshy 7 image-to-3D and rigging); see NOTICE.txt"
    text = json.dumps(g, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    while len(blob) % 4:
        blob.append(0)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / ("%s.glb" % name)
    with open(out, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(blob)))
        f.write(struct.pack("<I4s", len(text), b"JSON") + text)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0") + bytes(blob))
    print(name, "hips %.1f cm," % person.hips(), out.stat().st_size, "bytes; clips and what their soles were off the ground (cm):",
        ", ".join("%s %+.1f (%d keys)" % (label, value * 100.0, keys[label]) for label, value in off.items()))


if __name__ == "__main__":
    folder = pathlib.Path(sys.argv[1])
    for who in PEOPLE:
        if (folder / ("%s_walk.glb" % who)).exists():
            build(who, folder)
        else:
            print(who, "missing: skipped")
