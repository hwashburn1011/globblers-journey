"""
Build The Globbler 3D Character Model (v2 - Chibi Rewrite)

Chibi-proportioned hooded hacker robot with:
- MASSIVE round helmet/head (~60% of total height)
- Angular glowing V-shaped green eyes, mischievous smirk
- "GLOBBLER" text plate on forehead
- Dark green-black armor with neon green accents
- Left hand: yellow wrench
- Right hand: small laptop with green screen
- Backpack with CRT monitor showing "GPT 5.4"
- Cables trailing from backpack
- Chunky boots

Exports as .glb for Godot import.
"""

import trimesh
import numpy as np
import os

OUTPUT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "assets", "models", "globbler.glb")

# ── Color Palette ──
DARK_ARMOR = [25, 30, 25, 255]
MID_ARMOR = [40, 50, 38, 255]
VISOR_DARK = [15, 25, 15, 255]
EYE_GLOW = [80, 255, 80, 255]
ACCENT_GREEN = [60, 200, 60, 255]
BRIGHT_GREEN = [100, 255, 100, 255]
CABLE_DARK = [12, 18, 12, 255]
YELLOW_TOOL = [200, 190, 50, 255]
BOOT_DARK = [20, 25, 20, 255]
GRIN_GREEN = [80, 255, 80, 255]
PANEL_EDGE = [35, 42, 35, 255]


# ── Helpers ──

def nuscale(sx, sy, sz):
    """Non-uniform 4x4 scale matrix."""
    m = np.eye(4)
    m[0, 0] = sx
    m[1, 1] = sy
    m[2, 2] = sz
    return m


def translate(x, y, z):
    """4x4 translation matrix."""
    m = np.eye(4)
    m[0, 3] = x
    m[1, 3] = y
    m[2, 3] = z
    return m


def rotmat(angle_deg, axis):
    """Rotation matrix from axis-angle (degrees)."""
    return trimesh.transformations.rotation_matrix(np.radians(angle_deg), axis)


def paint(mesh, color):
    """Apply solid RGBA vertex color to mesh."""
    rgba = np.array(color, dtype=np.uint8)
    mesh.visual = trimesh.visual.ColorVisuals(
        mesh=mesh,
        vertex_colors=np.tile(rgba, (len(mesh.vertices), 1)),
    )
    return mesh


def sphere(radius=1.0, subdivisions=3):
    """Shorthand icosphere."""
    return trimesh.creation.icosphere(radius=radius, subdivisions=subdivisions)


def box(extents):
    """Shorthand box."""
    return trimesh.creation.box(extents=extents)


def cyl(radius, height, sections=32):
    """Shorthand cylinder."""
    return trimesh.creation.cylinder(radius=radius, height=height, sections=sections)


def capsule(height, radius):
    """Shorthand capsule."""
    return trimesh.creation.capsule(height=height, radius=radius)


def move(mesh, x, y, z):
    """Translate mesh in place, return mesh."""
    mesh.apply_translation([x, y, z])
    return mesh


def add(parts, name, mesh, color):
    """Color and append a part."""
    parts.append((name, paint(mesh, color)))


# ── Build Functions ──

def build_head(parts):
    """Build the massive chibi helmet/head assembly."""
    HEAD_Y = 1.45
    HEAD_R = 0.55

    # Main helmet sphere - smooth
    helmet = sphere(HEAD_R, subdivisions=4)
    helmet.apply_transform(nuscale(1.0, 0.92, 0.95))
    move(helmet, 0, HEAD_Y, 0)
    add(parts, "helmet", helmet, DARK_ARMOR)

    # Hood cowl - larger sphere trimmed to sit on top/back
    hood = sphere(0.62, subdivisions=4)
    hood.apply_transform(nuscale(1.08, 0.82, 1.05))
    move(hood, 0, HEAD_Y + 0.08, -0.06)
    # Clip the hood: remove verts below helmet midline to form a cowl
    # We'll use a cutting plane approach via boolean difference with a box
    cutter = box([2.0, 1.2, 2.0])
    move(cutter, 0, HEAD_Y - 0.55, 0)
    try:
        hood = hood.difference(cutter)
    except Exception:
        pass  # fallback: keep unclipped hood
    add(parts, "hood", hood, DARK_ARMOR)

    # Hood brim - a thin lip around the front of the helmet
    brim = trimesh.creation.annulus(r_min=0.42, r_max=0.52, height=0.035)
    brim.apply_transform(nuscale(1.0, 1.0, 0.6))
    move(brim, 0, HEAD_Y - 0.18, 0.08)
    add(parts, "hood_brim", brim, PANEL_EDGE)

    # Hood peak - a small ridge on top
    peak = box([0.12, 0.06, 0.25])
    move(peak, 0, HEAD_Y + 0.42, -0.1)
    add(parts, "hood_peak", peak, MID_ARMOR)

    # ── Visor region ──
    visor_y = HEAD_Y - 0.05
    visor = sphere(0.52, subdivisions=3)
    visor.apply_transform(nuscale(0.85, 0.4, 0.15))
    move(visor, 0, visor_y, 0.42)
    add(parts, "visor", visor, VISOR_DARK)

    # ── Angular V-shaped eyes (evil anime style) ──
    # Each eye is a flattened parallelogram-ish shape, angled inward
    # Left eye: tilted ~20 degrees clockwise (from front view)
    for side, name in [(-1, "left"), (1, "right")]:
        # Main eye slab
        eye = box([0.16, 0.055, 0.04])
        eye.apply_transform(rotmat(side * 22, [0, 0, 1]))
        # Slight forward tilt
        eye.apply_transform(rotmat(-5, [1, 0, 0]))
        move(eye, side * 0.12, visor_y + 0.02, 0.50)
        add(parts, f"{name}_eye", eye, EYE_GLOW)

        # Eye glow halo (slightly larger, dimmer behind)
        halo = box([0.19, 0.07, 0.02])
        halo.apply_transform(rotmat(side * 22, [0, 0, 1]))
        halo.apply_transform(rotmat(-5, [1, 0, 0]))
        move(halo, side * 0.12, visor_y + 0.02, 0.48)
        add(parts, f"{name}_eye_halo", halo, ACCENT_GREEN)

        # Inner eye corner notch (makes the V shape sharper)
        notch = box([0.05, 0.035, 0.045])
        notch.apply_transform(rotmat(side * 40, [0, 0, 1]))
        move(notch, side * 0.03, visor_y - 0.01, 0.50)
        add(parts, f"{name}_eye_notch", notch, EYE_GLOW)

    # ── Mischievous smirk ──
    grin = box([0.18, 0.025, 0.035])
    # Slight curve: we approximate with 3 segments
    move(grin, 0, visor_y - 0.14, 0.50)
    add(parts, "grin_center", grin, GRIN_GREEN)

    # Grin corners curving up
    for side in [-1, 1]:
        corner = box([0.06, 0.025, 0.035])
        corner.apply_transform(rotmat(side * 25, [0, 0, 1]))
        move(corner, side * 0.11, visor_y - 0.11, 0.50)
        add(parts, f"grin_corner_{side}", corner, GRIN_GREEN)

    # ── "GLOBBLER" label plate on forehead ──
    label_plate = box([0.36, 0.065, 0.03])
    move(label_plate, 0, HEAD_Y + 0.18, 0.44)
    label_plate.apply_transform(rotmat(-8, [1, 0, 0]))
    add(parts, "label_plate", label_plate, ACCENT_GREEN)

    # Label backing (slightly larger, darker)
    label_back = box([0.39, 0.08, 0.02])
    move(label_back, 0, HEAD_Y + 0.18, 0.43)
    label_back.apply_transform(rotmat(-8, [1, 0, 0]))
    add(parts, "label_backing", label_back, MID_ARMOR)

    # ── Small rivets around helmet ──
    rivet_positions = [
        (-0.35, HEAD_Y + 0.15, 0.35),
        (0.35, HEAD_Y + 0.15, 0.35),
        (-0.40, HEAD_Y, 0.30),
        (0.40, HEAD_Y, 0.30),
        (-0.30, HEAD_Y - 0.15, 0.40),
        (0.30, HEAD_Y - 0.15, 0.40),
    ]
    for i, (rx, ry, rz) in enumerate(rivet_positions):
        rivet = sphere(0.018, subdivisions=2)
        move(rivet, rx, ry, rz)
        add(parts, f"rivet_head_{i}", rivet, MID_ARMOR)

    # ── Antenna nub on top of hood ──
    antenna_base = cyl(0.025, 0.08)
    move(antenna_base, 0.12, HEAD_Y + 0.46, -0.05)
    add(parts, "antenna_base", antenna_base, MID_ARMOR)

    antenna_tip = sphere(0.03, subdivisions=2)
    move(antenna_tip, 0.12, HEAD_Y + 0.52, -0.05)
    add(parts, "antenna_tip", antenna_tip, ACCENT_GREEN)


def build_body(parts):
    """Build the small compact chibi torso."""
    BODY_CENTER_Y = 0.65

    # Main torso - rounded box-ish shape
    torso = sphere(0.28, subdivisions=3)
    torso.apply_transform(nuscale(1.1, 1.0, 0.85))
    move(torso, 0, BODY_CENTER_Y, 0)
    add(parts, "torso", torso, DARK_ARMOR)

    # Chest armor plate
    chest = box([0.38, 0.25, 0.06])
    chest.apply_transform(rotmat(-5, [1, 0, 0]))
    move(chest, 0, BODY_CENTER_Y + 0.02, 0.22)
    add(parts, "chest_plate", chest, MID_ARMOR)

    # Center chest accent line
    chest_line = box([0.02, 0.22, 0.07])
    move(chest_line, 0, BODY_CENTER_Y + 0.02, 0.23)
    add(parts, "chest_line", chest_line, ACCENT_GREEN)

    # Horizontal chest detail lines
    for dy in [-0.06, 0.06]:
        detail = box([0.30, 0.015, 0.07])
        move(detail, 0, BODY_CENTER_Y + dy, 0.23)
        add(parts, f"chest_detail_{dy}", detail, PANEL_EDGE)

    # Neck connector
    neck = cyl(0.1, 0.12)
    move(neck, 0, 0.88, 0)
    add(parts, "neck", neck, DARK_ARMOR)

    # Belt
    belt = trimesh.creation.annulus(r_min=0.24, r_max=0.28, height=0.06)
    move(belt, 0, 0.42, 0)
    add(parts, "belt", belt, MID_ARMOR)

    # Belt buckle
    buckle = box([0.06, 0.06, 0.05])
    move(buckle, 0, 0.42, 0.27)
    add(parts, "belt_buckle", buckle, ACCENT_GREEN)

    # Belt pouches
    for angle_deg in [45, -45, 110, -110]:
        pouch = box([0.05, 0.06, 0.04])
        x = np.cos(np.radians(angle_deg)) * 0.28
        z = np.sin(np.radians(angle_deg)) * 0.28
        move(pouch, x, 0.42, z)
        add(parts, f"pouch_{angle_deg}", pouch, PANEL_EDGE)


def build_shoulders(parts):
    """Shoulder armor pads."""
    for side, name in [(-1, "left"), (1, "right")]:
        # Shoulder pad
        pad = sphere(0.12, subdivisions=3)
        pad.apply_transform(nuscale(1.3, 0.7, 1.0))
        move(pad, side * 0.38, 0.82, 0)
        add(parts, f"{name}_shoulder", pad, MID_ARMOR)

        # Shoulder ridge accent
        ridge = box([0.06, 0.03, 0.16])
        move(ridge, side * 0.38, 0.87, 0)
        add(parts, f"{name}_shoulder_ridge", ridge, ACCENT_GREEN)

        # Shoulder rivets
        for dz in [-0.06, 0.06]:
            rv = sphere(0.015, subdivisions=1)
            move(rv, side * 0.42, 0.82, dz)
            add(parts, f"{name}_shoulder_rivet_{dz}", rv, ACCENT_GREEN)


def build_left_arm(parts):
    """Left arm holding a yellow wrench."""
    # Upper arm
    upper = capsule(0.18, 0.06)
    upper.apply_transform(rotmat(30, [0, 0, 1]))
    move(upper, -0.42, 0.68, 0.05)
    add(parts, "l_upper_arm", upper, MID_ARMOR)

    # Elbow joint
    elbow = sphere(0.055, subdivisions=2)
    move(elbow, -0.50, 0.52, 0.08)
    add(parts, "l_elbow", elbow, DARK_ARMOR)

    # Lower arm
    lower = capsule(0.16, 0.05)
    lower.apply_transform(rotmat(10, [0, 0, 1]))
    lower.apply_transform(rotmat(-15, [1, 0, 0]))
    move(lower, -0.54, 0.38, 0.14)
    add(parts, "l_lower_arm", lower, MID_ARMOR)

    # Hand (fist)
    hand = sphere(0.055, subdivisions=2)
    hand.apply_transform(nuscale(1.0, 0.9, 1.1))
    move(hand, -0.57, 0.24, 0.20)
    add(parts, "l_hand", hand, DARK_ARMOR)

    # ── Wrench ──
    # Handle
    w_handle = cyl(0.018, 0.32)
    w_handle.apply_transform(rotmat(55, [0, 0, 1]))
    w_handle.apply_transform(rotmat(-10, [1, 0, 0]))
    move(w_handle, -0.64, 0.38, 0.20)
    add(parts, "wrench_handle", w_handle, YELLOW_TOOL)

    # Wrench head (open-end style)
    w_head = box([0.09, 0.06, 0.03])
    w_head.apply_transform(rotmat(55, [0, 0, 1]))
    move(w_head, -0.76, 0.52, 0.20)
    add(parts, "wrench_head", w_head, YELLOW_TOOL)

    # Wrench jaw gap
    w_gap = box([0.025, 0.035, 0.035])
    w_gap.apply_transform(rotmat(55, [0, 0, 1]))
    move(w_gap, -0.76, 0.55, 0.20)
    add(parts, "wrench_jaw", w_gap, [120, 115, 40, 255])

    # Wrench bottom nub
    w_nub = cyl(0.022, 0.04)
    w_nub.apply_transform(rotmat(55, [0, 0, 1]))
    move(w_nub, -0.54, 0.24, 0.20)
    add(parts, "wrench_nub", w_nub, YELLOW_TOOL)


def build_right_arm(parts):
    """Right arm holding a small laptop."""
    # Upper arm
    upper = capsule(0.18, 0.06)
    upper.apply_transform(rotmat(-30, [0, 0, 1]))
    move(upper, 0.42, 0.68, 0.05)
    add(parts, "r_upper_arm", upper, MID_ARMOR)

    # Elbow
    elbow = sphere(0.055, subdivisions=2)
    move(elbow, 0.50, 0.52, 0.12)
    add(parts, "r_elbow", elbow, DARK_ARMOR)

    # Lower arm - angled forward to hold laptop
    lower = capsule(0.16, 0.05)
    lower.apply_transform(rotmat(-45, [0, 0, 1]))
    lower.apply_transform(rotmat(-25, [1, 0, 0]))
    move(lower, 0.54, 0.36, 0.22)
    add(parts, "r_lower_arm", lower, MID_ARMOR)

    # Hand
    hand = sphere(0.055, subdivisions=2)
    hand.apply_transform(nuscale(1.0, 0.9, 1.1))
    move(hand, 0.52, 0.22, 0.30)
    add(parts, "r_hand", hand, DARK_ARMOR)

    # ── Laptop ──
    # Base
    laptop_base = box([0.22, 0.015, 0.16])
    move(laptop_base, 0.52, 0.20, 0.30)
    add(parts, "laptop_base", laptop_base, [30, 35, 30, 255])

    # Screen (tilted back)
    laptop_screen_frame = box([0.22, 0.16, 0.012])
    laptop_screen_frame.apply_transform(rotmat(-20, [1, 0, 0]))
    move(laptop_screen_frame, 0.52, 0.32, 0.22)
    add(parts, "laptop_frame", laptop_screen_frame, [30, 35, 30, 255])

    # Screen glow surface
    screen_glow = box([0.18, 0.12, 0.008])
    screen_glow.apply_transform(rotmat(-20, [1, 0, 0]))
    move(screen_glow, 0.52, 0.32, 0.225)
    add(parts, "laptop_screen", screen_glow, BRIGHT_GREEN)

    # Keyboard dots on base
    for kx in np.linspace(-0.07, 0.07, 5):
        for kz in np.linspace(-0.04, 0.04, 3):
            key = box([0.018, 0.006, 0.018])
            move(key, 0.52 + kx, 0.212, 0.30 + kz)
            add(parts, f"key_{kx:.2f}_{kz:.2f}", key, MID_ARMOR)


def build_legs(parts):
    """Short stubby chibi legs with chunky boots."""
    for side, name in [(-1, "left"), (1, "right")]:
        LEG_X = side * 0.14

        # Upper leg
        upper = capsule(0.10, 0.08)
        upper.apply_transform(nuscale(1.0, 1.0, 0.9))
        move(upper, LEG_X, 0.28, 0)
        add(parts, f"{name}_upper_leg", upper, DARK_ARMOR)

        # Knee pad
        knee = box([0.09, 0.06, 0.10])
        move(knee, LEG_X, 0.22, 0.06)
        add(parts, f"{name}_knee", knee, MID_ARMOR)

        # Knee accent
        knee_dot = sphere(0.018, subdivisions=1)
        move(knee_dot, LEG_X, 0.22, 0.12)
        add(parts, f"{name}_knee_dot", knee_dot, ACCENT_GREEN)

        # Lower leg / shin
        shin = capsule(0.08, 0.07)
        move(shin, LEG_X, 0.12, 0)
        add(parts, f"{name}_shin", shin, DARK_ARMOR)

        # ── Chunky Boot ──
        # Main boot block
        boot = box([0.12, 0.10, 0.20])
        boot.apply_transform(nuscale(1.0, 1.0, 1.0))
        move(boot, LEG_X, 0.01, 0.02)
        add(parts, f"{name}_boot", boot, BOOT_DARK)

        # Boot toe (rounded front)
        toe = sphere(0.065, subdivisions=2)
        toe.apply_transform(nuscale(0.9, 0.7, 1.2))
        move(toe, LEG_X, 0.00, 0.11)
        add(parts, f"{name}_boot_toe", toe, BOOT_DARK)

        # Boot sole
        sole = box([0.13, 0.025, 0.22])
        move(sole, LEG_X, -0.045, 0.02)
        add(parts, f"{name}_sole", sole, [15, 18, 15, 255])

        # Boot sole treads
        for tz in np.linspace(-0.06, 0.10, 4):
            tread = box([0.11, 0.008, 0.03])
            move(tread, LEG_X, -0.055, tz)
            add(parts, f"{name}_tread_{tz:.2f}", tread, [10, 14, 10, 255])

        # Boot straps
        strap = box([0.13, 0.018, 0.22])
        move(strap, LEG_X, 0.04, 0.02)
        add(parts, f"{name}_boot_strap", strap, MID_ARMOR)

        # Boot accent line
        accent = box([0.005, 0.08, 0.005])
        move(accent, LEG_X + side * 0.055, 0.02, 0.10)
        add(parts, f"{name}_boot_accent", accent, ACCENT_GREEN)


def build_backpack(parts):
    """Backpack with GPT 5.4 CRT monitor and cables."""
    BP_Y = 0.65
    BP_Z = -0.28

    # Main backpack body
    bp = box([0.36, 0.40, 0.18])
    move(bp, 0, BP_Y, BP_Z)
    add(parts, "backpack", bp, MID_ARMOR)

    # Backpack rounded top
    bp_top = sphere(0.18, subdivisions=2)
    bp_top.apply_transform(nuscale(1.0, 0.5, 0.5))
    move(bp_top, 0, BP_Y + 0.20, BP_Z)
    add(parts, "backpack_top", bp_top, MID_ARMOR)

    # Backpack face plate (rear face detail)
    face = box([0.30, 0.34, 0.02])
    move(face, 0, BP_Y, BP_Z - 0.09)
    add(parts, "backpack_face", face, DARK_ARMOR)

    # Backpack edge trim
    for dx in [-0.175, 0.175]:
        edge = box([0.015, 0.38, 0.19])
        move(edge, dx, BP_Y, BP_Z)
        add(parts, f"bp_edge_{dx}", edge, PANEL_EDGE)

    # Backpack horizontal stripes
    for dy in [-0.10, 0.0, 0.10]:
        stripe = box([0.34, 0.012, 0.19])
        move(stripe, 0, BP_Y + dy, BP_Z)
        add(parts, f"bp_stripe_{dy}", stripe, PANEL_EDGE)

    # ── Straps connecting backpack to body ──
    for side in [-1, 1]:
        strap = box([0.04, 0.35, 0.04])
        strap.apply_transform(rotmat(side * 8, [0, 0, 1]))
        move(strap, side * 0.16, BP_Y, BP_Z + 0.20)
        add(parts, f"bp_strap_{side}", strap, PANEL_EDGE)

    # ── CRT Monitor (mounted on top-right of backpack) ──
    MON_X = 0.26
    MON_Y = BP_Y + 0.28
    MON_Z = BP_Z - 0.02

    # Monitor mount arm
    arm = cyl(0.02, 0.14)
    arm.apply_transform(rotmat(90, [0, 0, 1]))
    move(arm, MON_X - 0.10, MON_Y, MON_Z)
    add(parts, "monitor_arm", arm, CABLE_DARK)

    # CRT body (boxy with slight depth)
    crt = box([0.16, 0.13, 0.10])
    move(crt, MON_X, MON_Y, MON_Z)
    add(parts, "crt_body", crt, [30, 36, 30, 255])

    # CRT screen bezel
    bezel = box([0.14, 0.11, 0.02])
    move(bezel, MON_X, MON_Y, MON_Z + 0.05)
    add(parts, "crt_bezel", bezel, DARK_ARMOR)

    # CRT screen glow (shows "GPT 5.4")
    screen = box([0.11, 0.08, 0.015])
    move(screen, MON_X, MON_Y, MON_Z + 0.058)
    add(parts, "crt_screen", screen, BRIGHT_GREEN)

    # CRT scanlines (horizontal bars on screen)
    for sy in np.linspace(-0.025, 0.025, 4):
        scanline = box([0.10, 0.005, 0.016])
        move(scanline, MON_X, MON_Y + sy, MON_Z + 0.062)
        add(parts, f"crt_scanline_{sy:.3f}", scanline, ACCENT_GREEN)

    # CRT rear bulge
    rear = sphere(0.06, subdivisions=2)
    rear.apply_transform(nuscale(1.2, 1.0, 0.8))
    move(rear, MON_X, MON_Y, MON_Z - 0.06)
    add(parts, "crt_rear", rear, [30, 36, 30, 255])

    # ── Cables trailing from backpack ──
    cable_configs = [
        # (start_x, start_y, start_z, angle_x, angle_z, length)
        (0.0, BP_Y - 0.10, BP_Z - 0.08, -30, 0, 0.22),
        (-0.10, BP_Y - 0.05, BP_Z - 0.08, -40, 10, 0.18),
        (0.10, BP_Y - 0.08, BP_Z - 0.08, -25, -8, 0.20),
        (-0.05, BP_Y + 0.08, BP_Z - 0.08, -50, 5, 0.16),
        (0.05, BP_Y + 0.02, BP_Z - 0.08, -35, -5, 0.19),
    ]
    for i, (cx, cy, cz, ax, az, length) in enumerate(cable_configs):
        cable = cyl(0.014, length)
        cable.apply_transform(rotmat(ax, [1, 0, 0]))
        cable.apply_transform(rotmat(az, [0, 0, 1]))
        move(cable, cx, cy, cz)
        add(parts, f"cable_{i}", cable, CABLE_DARK)

        # Cable end connector
        conn = sphere(0.02, subdivisions=1)
        # Position roughly at cable end
        end_y = cy - np.sin(np.radians(-ax)) * length * 0.5
        end_z = cz - np.cos(np.radians(-ax)) * length * 0.5
        move(conn, cx, end_y, end_z)
        add(parts, f"cable_end_{i}", conn, MID_ARMOR)

    # Backpack power indicator light
    light = sphere(0.02, subdivisions=2)
    move(light, -0.12, BP_Y + 0.12, BP_Z - 0.10)
    add(parts, "bp_power_light", light, BRIGHT_GREEN)

    # Second indicator
    light2 = sphere(0.015, subdivisions=2)
    move(light2, -0.12, BP_Y + 0.06, BP_Z - 0.10)
    add(parts, "bp_status_light", light2, ACCENT_GREEN)


def build_details(parts):
    """Extra decorative details - panel lines, vents, etc."""
    # Collar ring at neck
    collar = trimesh.creation.annulus(r_min=0.09, r_max=0.13, height=0.03)
    move(collar, 0, 0.92, 0)
    add(parts, "collar", collar, MID_ARMOR)

    # Chest vent slits (side of torso)
    for side in [-1, 1]:
        for i in range(3):
            vent = box([0.03, 0.04, 0.008])
            move(vent, side * 0.28, 0.60 + i * 0.06, 0.15)
            add(parts, f"vent_{side}_{i}", vent, PANEL_EDGE)

    # Hip armor plates
    for side in [-1, 1]:
        hip = box([0.10, 0.08, 0.12])
        move(hip, side * 0.20, 0.38, 0.02)
        add(parts, f"hip_plate_{side}", hip, MID_ARMOR)


# ── Main Assembly ──

def build_globbler():
    """Assemble the complete Globbler character model."""
    parts = []

    print("Building The Globbler 3D model (v2 - Chibi)...")
    print()

    print("  [1/7] Head & helmet...")
    build_head(parts)

    print("  [2/7] Body & torso...")
    build_body(parts)

    print("  [3/7] Shoulders...")
    build_shoulders(parts)

    print("  [4/7] Left arm + wrench...")
    build_left_arm(parts)

    print("  [5/7] Right arm + laptop...")
    build_right_arm(parts)

    print("  [6/7] Legs & boots...")
    build_legs(parts)

    print("  [7/7] Backpack + cables...")
    build_backpack(parts)

    print("  [+]   Extra details...")
    build_details(parts)

    print(f"\n  Total parts: {len(parts)}")

    scene = trimesh.Scene()
    for name, mesh in parts:
        scene.add_geometry(mesh, node_name=name)

    return scene


def main():
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    scene = build_globbler()

    print(f"\nExporting to: {OUTPUT_PATH}")
    scene.export(OUTPUT_PATH, file_type="glb")

    file_size = os.path.getsize(OUTPUT_PATH)
    print(f"Model exported! Size: {file_size / 1024:.1f} KB")
    print("The Globbler is ready for Godot!")


if __name__ == "__main__":
    main()
