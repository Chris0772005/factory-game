"""Cloth and leather for the worker's own arms and legs in first person (docs/TECH_SPEC.md, Modul Y).

Sources: "Denim Fabric 02" (https://polyhaven.com/a/denmin_fabric_02) and "Brown Leather"
(https://polyhaven.com/a/brown_leather) from Poly Haven, CC0, 1k JPG maps (diff/albedo, nor_gl, arm).
This script writes game/assets/textures/pbr/cloth_*.jpg and leather_*.jpg:
  - *_d.jpg: the colour map without its colour, only light and dark, as bright as it goes without
    clipping more than its brightest half per cent, so that the game can give the cloth each player's
    colour and the leather any brown. The script prints each map's mean (linear light): the game
    divides the wanted colour by it (FpMaterials.MEAN);
  - *_n.jpg and *_arm.jpg: the normal map and the occlusion/roughness/metal map as they are.

    python3 -I tools/fp_textures.py <folder with the eight Poly Haven files>
"""
import pathlib
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/textures/pbr"
SETS = {
    "cloth": ("denmin_fabric_02_diff_1k.jpg", "denmin_fabric_02_nor_gl_1k.jpg", "denmin_fabric_02_arm_1k.jpg"),
    "leather": ("brown_leather_albedo_1k.jpg", "brown_leather_nor_gl_1k.jpg", "brown_leather_arm_1k.jpg"),
}
source = pathlib.Path(sys.argv[1])
for name, (colour, normal, arm) in SETS.items():
    srgb = np.asarray(Image.open(source / colour).convert("RGB")).astype(np.float64) / 255.0
    linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
    light = linear @ np.array([0.2126, 0.7152, 0.0722])
    light = np.clip(light / np.percentile(light, 99.5), 0.0, 1.0)
    back = np.where(light <= 0.0031308, light * 12.92, 1.055 * light ** (1 / 2.4) - 0.055)
    grey = (np.clip(back, 0, 1) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([grey] * 3, axis=2)).save(OUT / (name + "_d.jpg"), quality=92)
    shutil.copyfile(source / normal, OUT / (name + "_n.jpg"))
    shutil.copyfile(source / arm, OUT / (name + "_arm.jpg"))
    print(name, "mean (linear light) %.4f" % light.mean())
