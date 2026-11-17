"""Three-axle tipper truck for the scrapyard, built procedurally in Blender and exported as
game/assets/models/machinery/truck_hd.glb. Reference: the cab-over tippers in Construction Simulator's
screenshots (tall cab, raked windscreen, dark bumper with the lamps in it, ribbed tipper body with a cab
guard). No manufacturer marks. X forward, Y left, Z up; ground at z = 0.

Nodes: truck / body (chassis and cab), bed (tipper body, origin at the rear hinge), wheel_* (origin at the
axle, so the game can turn them), glass and interior as their own objects.

    PYTHONPATH=<dir with bpy> python3 tools/blender/truck_hd.py
"""

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import mm_kit as K  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[2] / "game/assets/models/machinery/truck_hd.glb"

K.reset()

M = {
    "cab": K.surface("cab_paint", "#2a5d9e", "paint", 512, seed=11, coat=0.45),
    "bed": K.surface("bed_paint", "#d58a1c", "paint_worn", 1024, seed=12, coat=0.15),
    "frame": K.surface("frame_graphite", "#25282b", "paint_worn", 512, seed=13),
    "liner": K.surface("bed_steel", "#6a6661", "steel", 512, seed=14),
    "rubber": K.surface("tyre_rubber", "#161616", "rubber", 512, seed=15),
    "bumper": K.surface("bumper_plastic", "#2b2d30", "plastic", 256, seed=16),
    "rim": K.material("rim_steel", "#b4b8bc", rough=0.32, metal=1.0),
    "chrome": K.material("chrome", "#e4e6e8", rough=0.08, metal=1.0),
    "alu": K.material("tank_alu", "#a9adb0", rough=0.28, metal=1.0),
    "glass": K.material("glass", "#9fb6c0", rough=0.03, alpha=0.3),
    "plastic": K.material("plastic_black", "#0f1011", rough=0.55),
    "fabric": K.material("seat_fabric", "#3a3d42", rough=0.92),
    "dash": K.material("dash_grey", "#2a2c2f", rough=0.7),
    "lens": K.material("lamp_lens", "#f4f1e4", rough=0.1, emit="#fff4dc", emit_strength=0.8),
    "red": K.material("lamp_red", "#c4161c", rough=0.2, emit="#ff2010", emit_strength=0.5),
    "amber": K.material("lamp_amber", "#f0a020", rough=0.2, emit="#ffa000", emit_strength=0.6),
    "plate": K.material("plate_white", "#e8e8e2", rough=0.4),
}

truck = K.empty("truck")
body = K.empty("body", truck)

R = 0.54  # tyre radius
AX_F, AX_R1, AX_R2 = 2.75, -1.45, -2.8  # axle positions along x
CAB_X0, CAB_X1, CAB_Y, CAB_Z0, BELT, CAB_Z1 = 1.58, 3.72, 1.23, 1.02, 2.08, 3.22


# ------------------------------------------------------------------ chassis
def chassis():
    def rails(bm):
        for s in (-1, 1):
            K.add_box(bm, (-3.75, s * 0.38, 0.82), (3.4, s * 0.47, 1.06))
        for x in (-3.6, -2.1, -0.7, 0.6, 1.9, 3.2):
            K.add_box(bm, (x - 0.06, -0.38, 0.86), (x + 0.06, 0.38, 1.02))
        # subframe under the tipper body
        for s in (-1, 1):
            K.add_box(bm, (-3.6, s * 0.4, 1.06), (1.25, s * 0.5, 1.26))

    K.make("frame_rails", body, M["frame"], rails, bevel=0.012)

    def axles(bm):
        K.add_cyl(bm, 0.06, (AX_F, -0.95, R), (AX_F, 0.95, R), 16)
        for x in (AX_R1, AX_R2):
            K.add_cyl(bm, 0.085, (x, -0.8, R), (x, 0.8, R), 16)
            K.add_sphere(bm, 0.25, (x, 0, R), 20, 12)
        K.add_tube(bm, [(1.3, 0, 0.78), (AX_R1 + 0.25, 0, R + 0.05)], 0.05, 12)
        K.add_tube(bm, [(AX_R1 - 0.25, 0, R + 0.05), (AX_R2 + 0.25, 0, R + 0.05)], 0.05, 12)
        K.add_box(bm, (1.2, -0.3, 0.55), (2.2, 0.3, 0.95))  # gearbox and engine sump under the cab
        for s in (-1, 1):  # leaf springs
            for x in (AX_F, (AX_R1 + AX_R2) / 2):
                for k in range(4):
                    half = 0.62 - 0.09 * k
                    K.add_box(bm, (x - half, s * 0.5, 0.68 + 0.025 * k), (x + half, s * 0.58, 0.7 + 0.025 * k))

    K.make("axles", body, M["frame"], axles, bevel=0.01)

    # left: fuel tank with straps; right: battery box, air tanks, silencer with tail pipe
    K.make("fuel_tank", body, M["alu"], lambda bm: K.add_cyl(bm, 0.31, (0.1, 0.95, 0.74), (1.3, 0.95, 0.74), 40), bevel=0.03)

    def tank_parts(bm):
        for x in (0.35, 1.05):
            K.add_cyl(bm, 0.318, (x - 0.03, 0.95, 0.74), (x + 0.03, 0.95, 0.74), 40)
        K.add_cyl(bm, 0.05, (0.7, 0.95, 1.05), (0.7, 0.95, 1.1), 16)
        K.add_box(bm, (0.45, -1.2, 0.5), (1.25, -0.72, 0.98))  # battery box
        K.add_box(bm, (0.1, 0.62, 0.78), (1.3, 0.72, 0.84))

    K.make("tank_straps", body, M["frame"], tank_parts, bevel=0.012)

    def right_side(bm):
        for z in (0.62, 0.9):
            K.add_cyl(bm, 0.12, (-0.75, -0.95, z), (0.3, -0.95, z), 24)
        K.add_cyl(bm, 0.19, (-3.3, -0.3, 0.62), (-2.3, -0.3, 0.62), 28)
        K.add_tube(bm, [(-3.3, -0.3, 0.62), (-3.55, -0.3, 0.6), (-3.8, -0.5, 0.52)], 0.045, 12)

    K.make("air_tanks", body, M["alu"], right_side, bevel=0.02)

    # mudguards over the rear axles, mud flaps, rear underrun bar, lamp housings
    outer = [(-3.55, 0.62), (-3.5, 0.95), (-3.3, 1.15), (-3.0, 1.2), (-1.25, 1.2), (-0.95, 1.15), (-0.75, 0.95), (-0.7, 0.62)]
    inner = [(-3.515, 0.62), (-3.468, 0.94), (-3.285, 1.117), (-3.0, 1.165), (-1.25, 1.165), (-0.965, 1.117), (-0.782, 0.94), (-0.735, 0.62)]

    def guards(bm):
        for s in (-1, 1):
            K.add_prism(bm, outer + inner[::-1], "y", s * 0.66, s * 1.26)
            K.add_box(bm, (-3.56, s * 0.7, 0.2), (-3.535, s * 1.24, 0.66))
        K.add_box(bm, (-3.9, -1.2, 0.5), (-3.8, 1.2, 0.62))
        for s in (-1, 1):
            K.add_box(bm, (-3.8, s * 0.42, 0.56), (-3.7, s * 0.5, 0.9))
            K.add_box(bm, (-3.9, s * 0.78, 0.82), (-3.84, s * 1.22, 1.0))

    K.make("mudguards", body, M["plastic"], guards, bevel=0.012)
    K.make("tail_red", body, M["red"], lambda bm: [K.add_box(bm, (-3.915, s * 1.02, 0.84), (-3.9, s * 1.2, 0.98)) for s in (-1, 1)], smooth=False)
    K.make("tail_amber", body, M["amber"], lambda bm: [K.add_box(bm, (-3.915, s * 0.9, 0.84), (-3.9, s * 1.0, 0.98)) for s in (-1, 1)], smooth=False)
    K.make("tail_white", body, M["lens"], lambda bm: [K.add_box(bm, (-3.915, s * 0.8, 0.84), (-3.9, s * 0.88, 0.98)) for s in (-1, 1)], smooth=False)
    K.make("plate_rear", body, M["plate"], lambda bm: K.add_box(bm, (-3.905, -0.26, 0.66), (-3.9, 0.26, 0.78)), smooth=False)


# ------------------------------------------------------------------ cab
def cab():
    arch = K.arc((AX_F, R), 0.74, 139.0, 41.0, 12)
    lower = [(CAB_X0, CAB_Z0), (arch[0][0] - 0.02, CAB_Z0)] + arch + [(arch[-1][0] + 0.02, CAB_Z0), (3.64, CAB_Z0), (CAB_X1, 1.14),
        (CAB_X1, BELT), (CAB_X0, BELT)]
    K.make("cab_lower", body, M["cab"], lambda bm: K.add_prism(bm, lower, "y", -CAB_Y, CAB_Y), bevel=0.085, segs=5)
    # greenhouse: roof, pillars, rear wall
    rake = (3.5 - CAB_X1) / (3.08 - BELT)  # x per z along the windscreen
    fx = lambda z: CAB_X1 + rake * (z - BELT)  # noqa: E731
    roof = K.fillet([(CAB_X0, 3.06), (fx(3.06), 3.06), (fx(3.06) - 0.12, CAB_Z1), (CAB_X0, CAB_Z1)], 0.05, 4)
    K.make("cab_roof", body, M["cab"], lambda bm: K.add_prism(bm, roof, "y", -CAB_Y, CAB_Y), bevel=0.075, segs=5)

    def pillars(bm):
        for s in (-1, 1):
            mid = ((CAB_X1 + fx(3.07)) / 2 - 0.04, s * (CAB_Y - 0.05), (BELT + 3.07) / 2)
            K.add_obox(bm, mid, (rake, 0, 1), (0, 1, 0), ((3.07 - BELT) / 2 * math.hypot(1, rake), 0.05, 0.055))
            K.add_box(bm, (2.47, s * (CAB_Y - 0.07), BELT), (2.56, s * CAB_Y, 3.07))
            K.add_box(bm, (CAB_X0, s * (CAB_Y - 0.08), BELT), (CAB_X0 + 0.1, s * CAB_Y, 3.07))
        K.add_box(bm, (CAB_X0, -CAB_Y, BELT), (CAB_X0 + 0.07, CAB_Y, 3.07))

    K.make("cab_pillars", body, M["cab"], pillars, bevel=0.02)

    def glass(bm):
        e = 0.004
        mid = ((CAB_X1 + fx(3.06)) / 2 - 0.045, 0, (BELT + 3.06) / 2)
        K.add_obox(bm, mid, (rake, 0, 1), (0, 1, 0), ((3.06 - BELT) / 2 * math.hypot(1, rake), CAB_Y - 0.1, e))
        for s in (-1, 1):
            y = s * (CAB_Y - 0.035)
            K.add_prism(bm, [(2.56, BELT + 0.02), (fx(BELT + 0.02) - 0.1, BELT + 0.02), (fx(3.05) - 0.1, 3.05), (2.56, 3.05)], "y", y - e, y + e)
            K.add_prism(bm, [(CAB_X0 + 0.1, BELT + 0.02), (2.47, BELT + 0.02), (2.47, 3.05), (CAB_X0 + 0.1, 3.05)], "y", y - e, y + e)

    K.make("cab_glass", body, M["glass"], glass, smooth=False)

    # interior seen through the glass: floor at the belt line, dashboard, steering wheel, two seats
    def dash(bm):
        K.add_box(bm, (CAB_X0 + 0.08, -CAB_Y + 0.08, BELT - 0.01), (CAB_X1 - 0.05, CAB_Y - 0.08, BELT + 0.012))
        K.add_box(bm, (3.02, -1.1, BELT), (3.6, 1.1, BELT + 0.3))
        K.add_box(bm, (2.9, 0.3, BELT + 0.3), (3.3, 0.95, BELT + 0.44))
        K.add_box(bm, (2.75, -0.18, BELT), (3.05, 0.18, BELT + 0.22))

    K.make("cab_dash", body, M["dash"], dash, bevel=0.035, segs=3)

    def wheel(bm):
        c, n = (2.84, 0.62, BELT + 0.5), 28
        th = math.radians(24)
        u, v = (0, 1, 0), (math.cos(th), 0, math.sin(th))
        ring = [tuple(c[i] + 0.22 * (math.cos(2 * math.pi * k / n) * u[i] + math.sin(2 * math.pi * k / n) * v[i]) for i in range(3)) for k in range(n + 1)]
        K.add_tube(bm, ring, 0.018, 8)
        for k in (0, 9, 19):
            K.add_tube(bm, [c, ring[k]], 0.012, 6)
        K.add_tube(bm, [c, (3.1, 0.62, BELT + 0.36)], 0.03, 10)

    K.make("steering_wheel", body, M["plastic"], wheel)

    def seats(bm):
        for s in (-1, 1):
            y = s * 0.62
            K.add_box(bm, (2.02, y - 0.27, BELT), (2.6, y + 0.27, BELT + 0.17))
            K.add_obox(bm, (2.03, y, BELT + 0.5), (-0.14, 0, 1), (0, 1, 0), (0.38, 0.26, 0.07))
            K.add_box(bm, (1.86, y - 0.15, BELT + 0.82), (1.99, y + 0.15, BELT + 0.97))

    K.make("seats", body, M["fabric"], seats, bevel=0.045, segs=3)

    # front: bumper, grille, lamps, plate, steps, visor, wipers, mirrors, roof lights
    def bumper(bm):
        K.add_box(bm, (3.5, -1.25, 0.42), (3.88, 1.25, 1.0))
        K.add_box(bm, (3.6, -1.1, 0.3), (3.84, 1.1, 0.42))
        for s in (-1, 1):  # steps in the bumper corners, ahead of the wheel
            K.add_box(bm, (3.36, s * 1.02, 0.52), (3.6, s * 1.25, 0.56))
            K.add_box(bm, (3.36, s * 1.02, 0.82), (3.6, s * 1.25, 0.86))

    K.make("bumper", body, M["bumper"], bumper, bevel=0.05, segs=4)

    def grille(bm):
        K.add_box(bm, (CAB_X1 - 0.01, -0.95, 1.22), (CAB_X1 + 0.012, 0.95, 1.98))
        for s in (-1, 1):
            K.add_box(bm, (2.52, s * (CAB_Y + 0.001), 1.26), (2.535, s * (CAB_Y + 0.008), BELT))  # door seams
            K.add_box(bm, (3.6, s * (CAB_Y + 0.001), 1.26), (3.615, s * (CAB_Y + 0.008), BELT))
            K.add_box(bm, (2.62, s * (CAB_Y + 0.002), 1.94), (2.8, s * (CAB_Y + 0.03), 1.985))  # handles
            # mirrors: arms and housings
            K.add_tube(bm, [(3.6, s * CAB_Y, 2.95), (3.72, s * (CAB_Y + 0.2), 2.95), (3.72, s * (CAB_Y + 0.24), 2.4), (3.62, s * CAB_Y, 2.3)], 0.014, 8)
            K.add_box(bm, (3.69, s * (CAB_Y + 0.17), 2.45), (3.75, s * (CAB_Y + 0.33), 2.93))
        K.add_obox(bm, (fx(3.07) + 0.1, 0, 3.07), (1, 0, -0.22), (0, 1, 0), (0.17, CAB_Y - 0.06, 0.018))  # sun visor
        for y in (0.45, -0.35):  # wipers
            K.add_tube(bm, [(CAB_X1 + 0.01, y, BELT + 0.03), (fx(2.6) + 0.012, y + 0.45, 2.6)], 0.008, 6)

    K.make("cab_trim", body, M["plastic"], grille, bevel=0.012)
    K.make("grille_bars", body, M["chrome"], lambda bm: [K.add_box(bm, (CAB_X1 + 0.012, -0.9, 1.28 + 0.115 * k), (CAB_X1 + 0.03, 0.9, 1.31 + 0.115 * k)) for k in range(6)], bevel=0.006)
    K.make("mirror_glass", body, M["chrome"], lambda bm: [K.add_box(bm, (3.685, s * (CAB_Y + 0.185), 2.47), (3.69, s * (CAB_Y + 0.315), 2.91)) for s in (-1, 1)], smooth=False)

    def lamps(bm):
        for s in (-1, 1):
            K.add_box(bm, (3.88, s * 0.72, 0.6), (3.895, s * 1.1, 0.84))
            K.add_cyl(bm, 0.06, (3.84, s * 0.45, 0.38), (3.85, s * 0.45, 0.38), 20)

    K.make("head_lamps", body, M["lens"], lamps, bevel=0.004)

    def ambers(bm):
        for s in (-1, 1):
            K.add_box(bm, (3.88, s * 1.11, 0.6), (3.895, s * 1.22, 0.84))
            for k in range(2):
                K.add_box(bm, (fx(3.07) - 0.1, s * (0.35 + 0.5 * k) - 0.05, CAB_Z1), (fx(3.07) - 0.04, s * (0.35 + 0.5 * k) + 0.05, CAB_Z1 + 0.03))
            K.add_cyl(bm, 0.065, (2.2, s * 0.75, CAB_Z1), (2.2, s * 0.75, CAB_Z1 + 0.11), 20)
            K.add_sphere(bm, 0.065, (2.2, s * 0.75, CAB_Z1 + 0.11), 16, 8)

    K.make("amber_lamps", body, M["amber"], ambers)
    K.make("plate_front", body, M["plate"], lambda bm: K.add_box(bm, (3.88, -0.26, 0.62), (3.887, 0.26, 0.74)), smooth=False)


# ------------------------------------------------------------------ tipper body
def tipper():
    hinge = (-3.45, 0.0, 1.2)
    bed = K.empty("bed", truck, hinge)
    o = lambda p: (p[0] - hinge[0], p[1], p[2] - hinge[2])  # noqa: E731  body coordinates -> bed frame

    def shell(bm):
        K.add_box(bm, o((-3.8, -1.2, 1.3)), o((1.3, 1.2, 1.36)))
        K.add_box(bm, o((1.3, -1.25, 1.3)), o((1.38, 1.25, 3.3)))
        K.add_box(bm, o((1.3, -1.25, 3.3)), o((2.32, 1.25, 3.36)))
        K.add_box(bm, o((2.28, -1.25, 3.22)), o((2.32, 1.25, 3.3)))
        for s in (-1, 1):
            K.add_box(bm, o((-3.8, s * 1.2, 1.3)), o((1.3, s * 1.25, 2.72)))
            K.add_box(bm, o((-3.82, s * 1.17, 2.68)), o((1.34, s * 1.31, 2.8)))
            K.add_box(bm, o((-3.8, s * 1.2, 1.24)), o((1.3, s * 1.3, 1.34)))
            for k in range(7):
                x = -3.5 + k * 0.75
                K.add_prism(bm, [(o((x - 0.06, 0, 0))[0], 0.14), (o((x + 0.06, 0, 0))[0], 0.14), (o((x + 0.04, 0, 0))[0], 1.48), (o((x - 0.04, 0, 0))[0], 1.48)], "y", s * 1.25, s * 1.31)
            K.add_prism(bm, [o((1.38, 0, 2.7))[::2], o((1.38, 0, 3.3))[::2], o((2.0, 0, 3.3))[::2]], "y", s * 1.2, s * 1.25)
        for y in (-0.7, 0.0, 0.7):
            K.add_box(bm, o((1.38, y - 0.05, 1.4)), o((1.44, y + 0.05, 3.25)))

    K.make("bed_shell", bed, M["bed"], shell, bevel=0.014, segs=2)

    def gate(bm):
        K.add_box(bm, o((-3.87, -1.22, 1.34)), o((-3.8, 1.22, 2.74)))
        for z in (1.45, 2.05, 2.62):
            K.add_box(bm, o((-3.93, -1.2, z)), o((-3.87, 1.2, z + 0.1)))
        for y in (-0.75, 0.0, 0.75):
            K.add_box(bm, o((-3.92, y - 0.05, 1.4)), o((-3.87, y + 0.05, 2.7)))
        for s in (-1, 1):
            K.add_cyl(bm, 0.05, o((-3.84, s * 1.1, 2.8)), o((-3.84, s * 1.3, 2.8)), 16)

    K.make("tailgate", bed, M["bed"], gate, bevel=0.012, segs=2)

    def liner(bm):
        K.add_box(bm, o((-3.78, -1.19, 1.36)), o((1.29, 1.19, 1.368)))
        for s in (-1, 1):
            K.add_box(bm, o((-3.78, s * 1.192, 1.36)), o((1.29, s * 1.2, 2.68)))
        K.add_box(bm, o((1.292, -1.19, 1.36)), o((1.3, 1.19, 3.28)))

    K.make("bed_liner", bed, M["liner"], liner, smooth=False)
    K.make("tip_ram", body, M["chrome"], lambda bm: K.add_cyl(bm, 0.05, (0.9, 0, 1.0), (1.22, 0, 1.3), 16))


# ------------------------------------------------------------------ wheels (outside is +y in the wheel's frame)
def tyre(bm, w, y):
    hw = w / 2
    prof = [(0.3, y - hw + 0.03), (0.44, y - hw), (0.505, y - hw + 0.012), (0.533, y - hw + 0.045)]
    for g in (-0.075, 0.0, 0.075):
        prof += [(0.54, y + g - 0.014), (0.526, y + g - 0.008), (0.526, y + g + 0.008), (0.54, y + g + 0.014)]
    prof += [(0.533, y + hw - 0.045), (0.505, y + hw - 0.012), (0.44, y + hw), (0.3, y + hw - 0.03), (0.3, y - hw + 0.03)]
    K.add_lathe_y(bm, prof, segs=56)


def rim(bm, w, y, dished):
    hw = w / 2
    K.add_lathe_y(bm, [(0.285, y - hw + 0.03), (0.312, y - hw + 0.03), (0.312, y + hw - 0.03), (0.285, y + hw - 0.03), (0.285, y - hw + 0.03)], segs=48)
    if dished:  # rear twin: deep dish with the hub standing in it
        K.add_lathe_y(bm, [(0.11, y - 0.03), (0.2, y - 0.02), (0.288, y + hw - 0.05), (0.288, y + hw - 0.08), (0.2, y - 0.05), (0.11, y - 0.06), (0.11, y - 0.03)], segs=48)
        K.add_lathe_y(bm, [(0.0, y + 0.07), (0.085, y + 0.07), (0.105, y + 0.04), (0.105, y - 0.06), (0.0, y - 0.06)], segs=32)
        ny = y - 0.02
    else:  # front: domed disc with a hub cap
        K.add_lathe_y(bm, [(0.0, y + hw - 0.04), (0.07, y + hw - 0.04), (0.09, y + hw - 0.06), (0.09, y + hw - 0.09), (0.16, y + hw - 0.1), (0.2, y + hw - 0.14),
            (0.288, y + hw - 0.15), (0.288, y + hw - 0.18), (0.0, y + hw - 0.18)], segs=48)
        ny = y + hw - 0.1
    for k in range(10):
        a = 2 * math.pi * k / 10
        K.add_cyl(bm, 0.014, (0.15 * math.cos(a), ny, 0.15 * math.sin(a)), (0.15 * math.cos(a), ny + 0.03, 0.15 * math.sin(a)), 8)


def wheels():
    spots = [("fl", AX_F, 1.04, False), ("fr", AX_F, -1.04, False), ("r1l", AX_R1, 0.925, True), ("r1r", AX_R1, -0.925, True),
        ("r2l", AX_R2, 0.925, True), ("r2r", AX_R2, -0.925, True)]
    for name, x, y, twin in spots:
        hub = K.empty(f"wheel_{name}", truck, (x, y, R))
        if y < 0:
            hub.rotation_euler = (0, 0, math.pi)
        if twin:
            K.make(f"tyre_{name}", hub, M["rubber"], lambda bm: (tyre(bm, 0.3, 0.165), tyre(bm, 0.3, -0.165)))
            K.make(f"rim_{name}", hub, M["rim"], lambda bm: (rim(bm, 0.3, 0.165, True), K.add_lathe_y(bm, [(0.285, -0.285), (0.312, -0.285), (0.312, -0.045), (0.285, -0.045), (0.285, -0.285)], segs=48)))
        else:
            K.make(f"tyre_{name}", hub, M["rubber"], lambda bm: tyre(bm, 0.34, 0.0))
            K.make(f"rim_{name}", hub, M["rim"], lambda bm: rim(bm, 0.34, 0.0, False))


chassis()
cab()
tipper()
wheels()
OUT.parent.mkdir(parents=True, exist_ok=True)
K.export_glb(OUT)
print("WROTE", OUT, OUT.stat().st_size)
