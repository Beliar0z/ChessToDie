# E:\ChessToDie\tools\blender\render_all_pieces.py
# Python / Blender bpy / Chess to Die (Ag4 - Full Batch 24 Pieces 3D-to-Pixel)
"""
Procedural 3D-to-Pixel batch renderer for all 24 Chess to Die board assets:
  - 12 Standard pieces: pawn, knight, bishop, rook, queen, king (_white, _black)
  - 10 Super pieces: super_pawn, super_knight, super_bishop, super_rook, super_queen (_white, _black)
  - 2 Special entities: scarecrow.png, heal_point.png

Inherits the exact Golden Standard camera, lighting, Freestyle #0A080C outline,
3-step CONSTANT Cel Shader, and hard-binary alpha post-process from render_golden_pawns.py.

Run with:
  & "E:\\blender\\blender.exe" --background --python E:\\ChessToDie\\tools\\blender\\render_all_pieces.py
"""

import math
import os
import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------
# Paths & Palette Constants (locked to design/art_bible.md & tasks/blender_spec.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "pieces")

RES_X = 64
RES_Y = 64

PALETTE_WHITE = {
    "dark": "#9B8A76",
    "mid": "#D8C9B4",
    "light": "#F5EFE6",
    "outline": "#100E12",
    "mid_pos": 0.24,
    "light_pos": 0.58,
    "rim_boost": 0.0,
}

PALETTE_BLACK = {
    "dark": "#14111C",
    "mid": "#2E2A3A",
    "light": "#5E667D",
    "outline": "#070609",
    "mid_pos": 0.22,
    "light_pos": 0.80,
    "rim_boost": 0.16,
}

# Super piece accent palettes (Art Bible Active Gold / Obsidian Crimson)
PALETTE_SUPER_WHITE_ACCENT = {
    "dark": "#8C4B10",
    "mid": "#F4A236",
    "light": "#FFF0C2",
    "outline": "#100E12",
    "mid_pos": 0.22,
    "light_pos": 0.62,
    "rim_boost": 0.05,
}

PALETTE_SUPER_BLACK_ACCENT = {
    "dark": "#4A1219",
    "mid": "#A83B1B",
    "light": "#F4A236",
    "outline": "#070609",
    "mid_pos": 0.20,
    "light_pos": 0.68,
    "rim_boost": 0.12,
}

# Scarecrow palettes
PALETTE_STRAW = {
    "dark": "#7A4E24",
    "mid": "#B6803C",
    "light": "#D8A85A",
    "outline": "#0A080C",
    "mid_pos": 0.24,
    "light_pos": 0.58,
    "rim_boost": 0.0,
}

PALETTE_WOOD = {
    "dark": "#2D1B12",
    "mid": "#563420",
    "light": "#7A4E24",
    "outline": "#0A080C",
    "mid_pos": 0.25,
    "light_pos": 0.62,
    "rim_boost": 0.0,
}

PALETTE_CLOTH = {
    "dark": "#221926",
    "mid": "#46344A",
    "light": "#6F5874",
    "outline": "#0A080C",
    "mid_pos": 0.24,
    "light_pos": 0.60,
    "rim_boost": 0.05,
}

# Heal Point palettes
PALETTE_STONE = {
    "dark": "#1E2430",
    "mid": "#465266",
    "light": "#7E8FA6",
    "outline": "#0A080C",
    "mid_pos": 0.24,
    "light_pos": 0.60,
    "rim_boost": 0.04,
}

PALETTE_CRYSTAL = {
    "dark": "#1E9E6E",
    "mid": "#64F6B5",
    "light": "#E3F2FD",
    "outline": "#0A080C",
    "mid_pos": 0.20,
    "light_pos": 0.56,
    "rim_boost": 0.14,
}

FREESTYLE_OUTLINE_HEX = "#0A080C"
CONTACT_SHADOW_HEX = "#0A080C"
SCARECROW_EYE_HEX = "#FFF0C2"


# ---------------------------------------------------------------------------
# Color & Render Pipeline (exact inheritance from render_golden_pawns.py)
# ---------------------------------------------------------------------------
def hex_to_srgb_tuple(hex_color: str) -> tuple[float, float, float]:
    h = hex_color.lstrip("#")
    return (
        int(h[0:2], 16) / 255.0,
        int(h[2:4], 16) / 255.0,
        int(h[4:6], 16) / 255.0,
    )


def srgb_channel_to_linear(c: float) -> float:
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear_rgba(hex_color: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    r, g, b = hex_to_srgb_tuple(hex_color)
    return (
        srgb_channel_to_linear(r),
        srgb_channel_to_linear(g),
        srgb_channel_to_linear(b),
        alpha,
    )


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def select_render_engine(scene: bpy.types.Scene) -> str:
    available = [
        e.identifier
        for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
    ]
    for preferred in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        if preferred in available:
            scene.render.engine = preferred
            return preferred
    scene.render.engine = available[0]
    return available[0]


def configure_render(
    scene: bpy.types.Scene,
    view_layer: bpy.types.ViewLayer,
    piece_collection: bpy.types.Collection,
) -> None:
    engine = select_render_engine(scene)
    print(f"[Ag4] Selected Render Engine: {engine}")

    scene.render.resolution_x = RES_X
    scene.render.resolution_y = RES_Y
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.filter_size = 0.01

    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15

    if hasattr(scene, "eevee"):
        eevee = scene.eevee
        for attr, val in (
            ("taa_render_samples", 1),
            ("use_taa_reprojection", False),
            ("use_bloom", False),
            ("use_gtao", False),
            ("use_ssr", False),
            ("use_raytracing", False),
            ("use_volumetric_shadows", False),
        ):
            if hasattr(eevee, attr):
                setattr(eevee, attr, val)

    if engine == "CYCLES" and hasattr(scene, "cycles"):
        scene.cycles.device = "CPU"
        scene.cycles.samples = 2
        scene.cycles.use_denoising = False
        scene.cycles.pixel_filter_type = "BOX"
        scene.cycles.filter_width = 0.01

    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    world = bpy.data.worlds.new("PieceWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.04, 0.04, 0.05, 1.0)
        bg.inputs[1].default_value = 0.15

    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.35

    fs = view_layer.freestyle_settings
    fs.use_culling = True
    fs.crease_angle = math.radians(128.0)

    while len(fs.linesets) > 0:
        fs.linesets.remove(fs.linesets[0])

    ls = fs.linesets.new("PieceOutline")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_external_contour = True
    ls.select_edge_mark = True
    ls.select_by_collection = True
    ls.collection = piece_collection
    ls.collection_negation = "INCLUSIVE"

    style = ls.linestyle
    style.color = hex_to_linear_rgba(FREESTYLE_OUTLINE_HEX)[:3]
    style.alpha = 1.0
    style.thickness = 1.35
    style.caps = "ROUND"
    style.use_chaining = True


def setup_camera_and_lights(scene: bpy.types.Scene) -> None:
    cam_data = bpy.data.cameras.new("OrthoCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.56
    cam_data.clip_start = 0.1
    cam_data.clip_end = 50.0

    cam_obj = bpy.data.objects.new("OrthoCam", cam_data)
    scene.collection.objects.link(cam_obj)

    cam_pos = Vector((0.0, -4.6, 2.35))
    target = Vector((0.0, 0.0, 0.57))
    direction = target - cam_pos
    cam_obj.location = cam_pos
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    key_data = bpy.data.lights.new("KeySun", type="SUN")
    key_data.energy = 2.6
    key_data.angle = math.radians(0.5)
    key_obj = bpy.data.objects.new("KeySun", key_data)
    scene.collection.objects.link(key_obj)
    key_obj.rotation_euler = (
        math.radians(52.0),
        math.radians(8.0),
        math.radians(-38.0),
    )

    fill_data = bpy.data.lights.new("FillSun", type="SUN")
    fill_data.energy = 0.55
    fill_data.angle = math.radians(2.0)
    fill_obj = bpy.data.objects.new("FillSun", fill_data)
    scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (
        math.radians(65.0),
        math.radians(-10.0),
        math.radians(135.0),
    )


def create_cel_material(name: str, palette: dict) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out_node = nodes.new("ShaderNodeOutputMaterial")
    out_node.location = (700, 0)

    emit_node = nodes.new("ShaderNodeEmission")
    emit_node.location = (480, 0)
    emit_node.inputs["Strength"].default_value = 1.0

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (200, 0)
    ramp.color_ramp.interpolation = "CONSTANT"

    elems = ramp.color_ramp.elements
    elems[0].position = 0.0
    elems[0].color = hex_to_linear_rgba(palette["dark"])

    elems[1].position = float(palette.get("mid_pos", 0.24))
    elems[1].color = hex_to_linear_rgba(palette["mid"])

    e_light = elems.new(float(palette.get("light_pos", 0.58)))
    e_light.color = hex_to_linear_rgba(palette["light"])

    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.location = (-360, 80)
    diffuse.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    diffuse.inputs["Roughness"].default_value = 1.0

    s2rgb = nodes.new("ShaderNodeShaderToRGB")
    s2rgb.location = (-160, 80)

    rgb2bw = nodes.new("ShaderNodeRGBToBW")
    rgb2bw.location = (0, 80)

    links.new(diffuse.outputs["BSDF"], s2rgb.inputs["Shader"])
    links.new(s2rgb.outputs["Color"], rgb2bw.inputs["Color"])

    rim_boost = float(palette.get("rim_boost", 0.0))
    if rim_boost > 0.0:
        layer_w = nodes.new("ShaderNodeLayerWeight")
        layer_w.location = (-360, -140)
        layer_w.inputs["Blend"].default_value = 0.35

        rim_power = nodes.new("ShaderNodeMath")
        rim_power.operation = "POWER"
        rim_power.location = (-180, -140)
        rim_power.inputs[1].default_value = 2.6

        rim_mul = nodes.new("ShaderNodeMath")
        rim_mul.operation = "MULTIPLY"
        rim_mul.location = (-20, -140)
        rim_mul.inputs[1].default_value = rim_boost

        add_node = nodes.new("ShaderNodeMath")
        add_node.operation = "ADD"
        add_node.use_clamp = True
        add_node.location = (100, 0)

        links.new(layer_w.outputs["Facing"], rim_power.inputs[0])
        links.new(rim_power.outputs["Value"], rim_mul.inputs[0])
        links.new(rgb2bw.outputs["Val"], add_node.inputs[0])
        links.new(rim_mul.outputs["Value"], add_node.inputs[1])
        links.new(add_node.outputs["Value"], ramp.inputs["Fac"])
    else:
        links.new(rgb2bw.outputs["Val"], ramp.inputs["Fac"])

    links.new(ramp.outputs["Color"], emit_node.inputs["Color"])
    links.new(emit_node.outputs["Emission"], out_node.inputs["Surface"])
    return mat


def create_flat_emission_material(name: str, hex_color: str) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out_node = nodes.new("ShaderNodeOutputMaterial")
    emit_node = nodes.new("ShaderNodeEmission")
    emit_node.inputs["Color"].default_value = hex_to_linear_rgba(hex_color)
    emit_node.inputs["Strength"].default_value = 1.0
    links.new(emit_node.outputs["Emission"], out_node.inputs["Surface"])
    return mat


def build_contact_shadow_disc() -> bpy.types.Object:
    mesh = bpy.data.meshes.new("ContactShadow_Mesh")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, radius=0.47, segments=24)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("ContactShadow", mesh)
    obj.location = (0.04, 0.04, -0.008)
    obj.scale = (1.06, 0.92, 1.0)
    obj.data.materials.append(create_flat_emission_material("Mat_ContactShadow", CONTACT_SHADOW_HEX))
    return obj


def enforce_hard_pixel_alpha(filepath: str, outline_hex: str) -> None:
    img = bpy.data.images.load(filepath, check_existing=False)
    try:
        w, h = img.size[0], img.size[1]
        pixels = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))

        alpha = pixels[:, :, 3]
        outline_r, outline_g, outline_b = hex_to_srgb_tuple(outline_hex)

        opaque_mask = alpha >= 0.42
        fringe_mask = opaque_mask & (alpha < 0.92)

        pixels[fringe_mask, 0] = outline_r
        pixels[fringe_mask, 1] = outline_g
        pixels[fringe_mask, 2] = outline_b

        pixels[opaque_mask, 3] = 1.0
        pixels[~opaque_mask, :] = 0.0

        img.pixels.foreach_set(pixels.ravel())
        img.filepath_raw = filepath
        img.file_format = "PNG"
        img.save()
    finally:
        bpy.data.images.remove(img)


# ---------------------------------------------------------------------------
# Procedural BMesh Primitives (clean sharp/smooth control + material slots)
# ---------------------------------------------------------------------------
def finalize_bmesh_object(name: str, bm: bmesh.types.BMesh, max_z: float | None = 1.28) -> bpy.types.Object:
    if max_z is not None and len(bm.verts) > 0:
        cur_max_z = max(v.co.z for v in bm.verts)
        if cur_max_z > max_z:
            z_scale = max_z / cur_max_z
            for v in bm.verts:
                v.co.z *= z_scale
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    edge_split = obj.modifiers.new(name="SharpSplit", type="EDGE_SPLIT")
    edge_split.use_edge_angle = False
    edge_split.use_edge_sharp = True
    return obj


def add_lathe(
    bm: bmesh.types.BMesh,
    profile: list[tuple[float, float, bool]],
    segments: int = 24,
    mat_idx: int = 0,
    offset: tuple[float, float, float] = (0.0, 0.0, 0.0),
    scale_xy: tuple[float, float] = (1.0, 1.0),
    smooth_faces: bool = True,
) -> None:
    ox, oy, oz = offset
    sx, sy = scale_xy
    rings: list[list[bmesh.types.BMVert]] = []

    for idx, (r, z, _sharp) in enumerate(profile):
        if (idx == 0 or idx == len(profile) - 1) and r <= 1e-6:
            rings.append([bm.verts.new((ox, oy, oz + z))])
        else:
            ring = []
            for s in range(segments):
                ang = (2.0 * math.pi * s) / segments
                x = ox + r * sx * math.cos(ang)
                y = oy + r * sy * math.sin(ang)
                ring.append(bm.verts.new((x, y, oz + z)))
            rings.append(ring)

    new_faces = []
    for i in range(len(rings) - 1):
        r0 = rings[i]
        r1 = rings[i + 1]
        if len(r0) == 1 and len(r1) == segments:
            c = r0[0]
            for s in range(segments):
                f = bm.faces.new((c, r1[(s + 1) % segments], r1[s]))
                new_faces.append(f)
        elif len(r0) == segments and len(r1) == 1:
            c = r1[0]
            for s in range(segments):
                f = bm.faces.new((r0[s], r0[(s + 1) % segments], c))
                new_faces.append(f)
        else:
            for s in range(segments):
                sn = (s + 1) % segments
                f = bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
                new_faces.append(f)

    for f in new_faces:
        f.material_index = mat_idx
        f.smooth = smooth_faces

    for i, (_r, _z, sharp) in enumerate(profile):
        if sharp and len(rings[i]) == segments:
            ring = rings[i]
            for s in range(segments):
                e = bm.edges.get((ring[s], ring[(s + 1) % segments]))
                if e:
                    e.smooth = False


def add_box(
    bm: bmesh.types.BMesh,
    size: tuple[float, float, float],
    center: tuple[float, float, float] = (0.0, 0.0, 0.0),
    rot_euler: tuple[float, float, float] = (0.0, 0.0, 0.0),
    mat_idx: int = 0,
    sharp: bool = True,
) -> None:
    mat = (
        Matrix.Translation(center)
        @ Matrix.Rotation(rot_euler[2], 4, "Z")
        @ Matrix.Rotation(rot_euler[1], 4, "Y")
        @ Matrix.Rotation(rot_euler[0], 4, "X")
        @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    )
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
    verts = set(res["verts"])
    for f in bm.faces:
        if all(v in verts for v in f.verts):
            f.material_index = mat_idx
            f.smooth = not sharp
    if sharp:
        for e in bm.edges:
            if e.verts[0] in verts and e.verts[1] in verts:
                e.smooth = False


def add_cone(
    bm: bmesh.types.BMesh,
    radius1: float,
    radius2: float,
    depth: float,
    segments: int = 12,
    center: tuple[float, float, float] = (0.0, 0.0, 0.0),
    rot_euler: tuple[float, float, float] = (0.0, 0.0, 0.0),
    mat_idx: int = 0,
    sharp: bool = False,
) -> None:
    mat = (
        Matrix.Translation(center)
        @ Matrix.Rotation(rot_euler[2], 4, "Z")
        @ Matrix.Rotation(rot_euler[1], 4, "Y")
        @ Matrix.Rotation(rot_euler[0], 4, "X")
    )
    res = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        matrix=mat,
    )
    verts = set(res["verts"])
    for f in bm.faces:
        if all(v in verts for v in f.verts):
            f.material_index = mat_idx
            f.smooth = not sharp
    if sharp:
        for e in bm.edges:
            if e.verts[0] in verts and e.verts[1] in verts:
                e.smooth = False


def add_uv_sphere(
    bm: bmesh.types.BMesh,
    radius: float,
    center: tuple[float, float, float] = (0.0, 0.0, 0.0),
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
    u_segments: int = 16,
    v_rings: int = 10,
    mat_idx: int = 0,
) -> None:
    mat = Matrix.Translation(center) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    res = bmesh.ops.create_uvsphere(
        bm, u_segments=u_segments, v_segments=v_rings, radius=radius, matrix=mat
    )
    verts = set(res["verts"])
    for f in bm.faces:
        if all(v in verts for v in f.verts):
            f.material_index = mat_idx
            f.smooth = True


def add_extruded_xz_polygon(
    bm: bmesh.types.BMesh,
    points_xz: list[tuple[float, float]],
    half_thickness: float,
    taper_front: float = 1.0,
    rot_z: float = 0.0,
    offset: tuple[float, float, float] = (0.0, 0.0, 0.0),
    mat_idx: int = 0,
    sharp: bool = True,
) -> None:
    """Extrude a 2D polygon in XZ along Y in [-half_thickness, +half_thickness]."""
    rot_m = Matrix.Rotation(rot_z, 4, "Z")
    off_v = Vector(offset)
    cx = sum(p[0] for p in points_xz) / len(points_xz)
    cz = sum(p[1] for p in points_xz) / len(points_xz)

    front_verts = []
    back_verts = []
    for x, z in points_xz:
        fx = cx + (x - cx) * taper_front
        fz = cz + (z - cz) * taper_front
        vf = rot_m @ Vector((fx, -half_thickness, fz)) + off_v
        vb = rot_m @ Vector((x, +half_thickness, z)) + off_v
        front_verts.append(bm.verts.new(vf))
        back_verts.append(bm.verts.new(vb))

    n = len(points_xz)
    created_faces = []
    created_faces.append(bm.faces.new(front_verts))
    created_faces.append(bm.faces.new(list(reversed(back_verts))))
    for i in range(n):
        j = (i + 1) % n
        created_faces.append(bm.faces.new((front_verts[j], front_verts[i], back_verts[i], back_verts[j])))

    for f in created_faces:
        f.material_index = mat_idx
        f.smooth = not sharp
    if sharp:
        vset = set(front_verts + back_verts)
        for e in bm.edges:
            if e.verts[0] in vset and e.verts[1] in vset:
                e.smooth = False


def add_torus_ring(
    bm: bmesh.types.BMesh,
    major_r: float,
    minor_r: float,
    major_seg: int = 24,
    minor_seg: int = 8,
    center: tuple[float, float, float] = (0.0, 0.0, 0.0),
    rot_euler: tuple[float, float, float] = (0.0, 0.0, 0.0),
    mat_idx: int = 0,
    sharp: bool = False,
) -> None:
    mat = (
        Matrix.Translation(center)
        @ Matrix.Rotation(rot_euler[2], 4, "Z")
        @ Matrix.Rotation(rot_euler[1], 4, "Y")
        @ Matrix.Rotation(rot_euler[0], 4, "X")
    )
    rings = []
    for i in range(major_seg):
        theta = 2.0 * math.pi * i / major_seg
        ct, st = math.cos(theta), math.sin(theta)
        ring = []
        for j in range(minor_seg):
            phi = 2.0 * math.pi * j / minor_seg
            cp, sp = math.cos(phi), math.sin(phi)
            r = major_r + minor_r * cp
            p = mat @ Vector((r * ct, r * st, minor_r * sp))
            ring.append(bm.verts.new(p))
        rings.append(ring)

    new_faces = []
    for i in range(major_seg):
        inext = (i + 1) % major_seg
        for j in range(minor_seg):
            jnext = (j + 1) % minor_seg
            f = bm.faces.new((rings[i][j], rings[inext][j], rings[inext][jnext], rings[i][jnext]))
            new_faces.append(f)

    for f in new_faces:
        f.material_index = mat_idx
        f.smooth = not sharp


def add_wedge_merlon(
    bm: bmesh.types.BMesh,
    r_in: float,
    r_out: float,
    z0: float,
    z1: float,
    ang_center: float,
    ang_width: float,
    mat_idx: int = 0,
) -> None:
    a0 = ang_center - ang_width * 0.5
    a1 = ang_center + ang_width * 0.5
    pts = [
        (r_in * math.cos(a0), r_in * math.sin(a0), z0),
        (r_out * math.cos(a0), r_out * math.sin(a0), z0),
        (r_out * math.cos(a1), r_out * math.sin(a1), z0),
        (r_in * math.cos(a1), r_in * math.sin(a1), z0),
        (r_in * math.cos(a0), r_in * math.sin(a0), z1),
        (r_out * math.cos(a0), r_out * math.sin(a0), z1),
        (r_out * math.cos(a1), r_out * math.sin(a1), z1),
        (r_in * math.cos(a1), r_in * math.sin(a1), z1),
    ]
    v = [bm.verts.new(p) for p in pts]
    faces = [
        bm.faces.new((v[0], v[3], v[2], v[1])),
        bm.faces.new((v[4], v[5], v[6], v[7])),
        bm.faces.new((v[0], v[1], v[5], v[4])),
        bm.faces.new((v[1], v[2], v[6], v[5])),
        bm.faces.new((v[2], v[3], v[7], v[6])),
        bm.faces.new((v[3], v[0], v[4], v[7])),
    ]
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    vset = set(v)
    for e in bm.edges:
        if e.verts[0] in vset and e.verts[1] in vset:
            e.smooth = False


# ---------------------------------------------------------------------------
# 1. PAWN & SUPER PAWN
# ---------------------------------------------------------------------------
PAWN_PROFILE = [
    (0.000, 0.000, False),
    (0.440, 0.000, True),
    (0.440, 0.085, True),
    (0.395, 0.135, True),
    (0.355, 0.165, False),
    (0.365, 0.215, True),
    (0.315, 0.265, False),
    (0.250, 0.360, False),
    (0.200, 0.500, False),
    (0.165, 0.650, True),
    (0.275, 0.695, True),
    (0.285, 0.735, True),
    (0.235, 0.775, True),
    (0.155, 0.805, True),
    (0.205, 0.855, False),
    (0.245, 0.935, False),
    (0.252, 1.015, False),
    (0.225, 1.095, False),
    (0.160, 1.160, False),
    (0.085, 1.200, False),
    (0.000, 1.215, False),
]


def build_pawn() -> bpy.types.Object:
    bm = bmesh.new()
    add_lathe(bm, PAWN_PROFILE, segments=24, mat_idx=0)
    return finalize_bmesh_object("Pawn", bm)


def build_super_pawn() -> bpy.types.Object:
    bm = bmesh.new()
    scaled_profile = [(r * 1.07, z * 1.02, s) for (r, z, s) in PAWN_PROFILE]
    add_lathe(bm, scaled_profile, segments=24, mat_idx=0)

    # Armored shoulder pauldrons (accent)
    for side in (-1.0, 1.0):
        add_box(
            bm,
            size=(0.17, 0.20, 0.15),
            center=(side * 0.28, 0.0, 0.73),
            rot_euler=(0.0, side * math.radians(24.0), 0.0),
            mat_idx=1,
            sharp=True,
        )

    # Horned Gothic Vanguard Helm + crest on head (accent)
    add_torus_ring(bm, major_r=0.265, minor_r=0.048, center=(0.0, 0.0, 1.08), mat_idx=1, sharp=True)
    for side in (-1.0, 1.0):
        add_cone(
            bm,
            radius1=0.085,
            radius2=0.014,
            depth=0.30,
            segments=8,
            center=(side * 0.26, 0.0, 1.20),
            rot_euler=(0.0, side * math.radians(32.0), 0.0),
            mat_idx=1,
            sharp=True,
        )
    # Central helm spike
    add_cone(bm, radius1=0.075, radius2=0.012, depth=0.22, segments=6, center=(0.0, 0.0, 1.26), mat_idx=1, sharp=True)

    # Front Gothic Kite Shield (accent border + body boss)
    shield_pts = [
        (-0.20, 0.68),
        (0.20, 0.68),
        (0.21, 0.45),
        (0.00, 0.24),
        (-0.21, 0.45),
    ]
    add_extruded_xz_polygon(
        bm, shield_pts, half_thickness=0.045, offset=(0.0, -0.27, 0.0), mat_idx=1, sharp=True
    )
    inner_shield = [
        (-0.13, 0.62),
        (0.13, 0.62),
        (0.13, 0.47),
        (0.00, 0.33),
        (-0.13, 0.47),
    ]
    add_extruded_xz_polygon(
        bm, inner_shield, half_thickness=0.025, offset=(0.0, -0.305, 0.0), mat_idx=0, sharp=True
    )
    return finalize_bmesh_object("SuperPawn", bm)


# ---------------------------------------------------------------------------
# 2. ROOK & SUPER ROOK
# ---------------------------------------------------------------------------
def build_rook() -> bpy.types.Object:
    bm = bmesh.new()
    profile = [
        (0.000, 0.000, False),
        (0.450, 0.000, True),
        (0.450, 0.090, True),
        (0.405, 0.145, True),
        (0.365, 0.200, True),
        (0.320, 0.255, True),
        (0.295, 0.520, False),
        (0.265, 0.780, True),
        (0.365, 0.870, True),
        (0.365, 0.990, True),
        (0.235, 0.990, True),
        (0.235, 0.935, True),
        (0.000, 0.935, False),
    ]
    add_lathe(bm, profile, segments=24, mat_idx=0)

    # 5 bold battlements (merlons) rotated for strong 3/4 silhouette
    num_merlons = 5
    for i in range(num_merlons):
        ang = math.radians(-90.0) + (2.0 * math.pi * i) / num_merlons
        add_wedge_merlon(
            bm, r_in=0.235, r_out=0.370, z0=0.985, z1=1.205, ang_center=ang, ang_width=math.radians(40.0), mat_idx=0
        )
    return finalize_bmesh_object("Rook", bm)


def build_super_rook() -> bpy.types.Object:
    bm = bmesh.new()
    profile = [
        (0.000, 0.000, False),
        (0.490, 0.000, True),
        (0.490, 0.095, True),
        (0.440, 0.160, True),
        (0.385, 0.230, True),
        (0.340, 0.680, True),
        (0.420, 0.760, True),
        (0.420, 0.880, True),
        (0.290, 0.880, True),
        (0.275, 1.110, True),
        (0.335, 1.165, True),
        (0.335, 1.220, True),
        (0.210, 1.220, True),
        (0.000, 1.220, False),
    ]
    add_lathe(bm, profile, segments=24, mat_idx=0)

    # 4 heavy armored corner buttress pillars (accent)
    for ang_deg in (35.0, 145.0, 215.0, 325.0):
        ang = math.radians(ang_deg)
        x = 0.375 * math.cos(ang)
        y = 0.375 * math.sin(ang)
        add_box(bm, size=(0.13, 0.13, 0.62), center=(x, y, 0.44), rot_euler=(0.0, 0.0, ang), mat_idx=1, sharp=True)

    # Lower tier 6 crenellations (accent)
    for i in range(6):
        ang = math.radians(30.0) + (2.0 * math.pi * i) / 6
        add_wedge_merlon(
            bm, r_in=0.310, r_out=0.430, z0=0.875, z1=1.015, ang_center=ang, ang_width=math.radians(32.0), mat_idx=1
        )

    # Upper keep 4 tall crenellations (accent)
    for i in range(4):
        ang = math.radians(45.0) + (2.0 * math.pi * i) / 4
        add_wedge_merlon(
            bm, r_in=0.215, r_out=0.345, z0=1.215, z1=1.345, ang_center=ang, ang_width=math.radians(46.0), mat_idx=1
        )
    return finalize_bmesh_object("SuperRook", bm, max_z=1.22)


# ---------------------------------------------------------------------------
# 3. KNIGHT & SUPER KNIGHT
# ---------------------------------------------------------------------------
def build_knight() -> bpy.types.Object:
    bm = bmesh.new()
    base_profile = [
        (0.000, 0.000, False),
        (0.450, 0.000, True),
        (0.450, 0.085, True),
        (0.400, 0.145, True),
        (0.365, 0.215, True),
        (0.310, 0.280, True),
        (0.285, 0.355, True),
        (0.000, 0.355, False),
    ]
    add_lathe(bm, base_profile, segments=24, mat_idx=0)

    rot_z = math.radians(-16.0)
    # Angular Gothic sculpted horse head & arched neck
    horse_body = [
        (-0.24, 0.32),
        (0.23, 0.32),
        (0.24, 0.50),
        (0.14, 0.64),
        (0.22, 0.68),
        (0.37, 0.64),
        (0.42, 0.74),
        (0.35, 0.87),
        (0.18, 1.00),
        (0.06, 1.12),
        (-0.14, 1.12),
        (-0.28, 0.96),
        (-0.33, 0.72),
        (-0.30, 0.48),
    ]
    add_extruded_xz_polygon(
        bm, horse_body, half_thickness=0.165, taper_front=0.90, rot_z=rot_z, mat_idx=0, sharp=True
    )

    # Sculpted nose/muzzle ridge (slightly narrower front block for 3D depth)
    muzzle = [
        (0.15, 0.70),
        (0.40, 0.67),
        (0.44, 0.75),
        (0.37, 0.86),
        (0.18, 0.95),
    ]
    add_extruded_xz_polygon(
        bm, muzzle, half_thickness=0.115, taper_front=0.85, rot_z=rot_z, mat_idx=0, sharp=True
    )

    # Two sharp Gothic ears
    for y_off in (-0.09, 0.09):
        ear = [(-0.08, 1.08), (0.08, 1.08), (0.04, 1.28), (-0.06, 1.24)]
        add_extruded_xz_polygon(
            bm, ear, half_thickness=0.042, rot_z=rot_z, offset=(0.0, y_off, 0.0), mat_idx=0, sharp=True
        )

    # Jagged Gothic mane spikes down the back of the neck
    mane = [
        (-0.20, 1.08),
        (-0.35, 1.04),
        (-0.29, 0.92),
        (-0.41, 0.84),
        (-0.32, 0.72),
        (-0.40, 0.60),
        (-0.31, 0.48),
        (-0.22, 0.44),
    ]
    add_extruded_xz_polygon(bm, mane, half_thickness=0.075, rot_z=rot_z, mat_idx=0, sharp=True)

    return finalize_bmesh_object("Knight", bm)


def build_super_knight() -> bpy.types.Object:
    bm = bmesh.new()
    base_profile = [
        (0.000, 0.000, False),
        (0.490, 0.000, True),
        (0.490, 0.095, True),
        (0.435, 0.160, True),
        (0.390, 0.230, True),
        (0.335, 0.300, True),
        (0.305, 0.375, True),
        (0.000, 0.375, False),
    ]
    add_lathe(bm, base_profile, segments=24, mat_idx=0)

    rot_z = math.radians(-16.0)
    horse_body = [
        (-0.26, 0.34),
        (0.25, 0.34),
        (0.26, 0.52),
        (0.15, 0.66),
        (0.24, 0.70),
        (0.40, 0.66),
        (0.45, 0.77),
        (0.37, 0.90),
        (0.19, 1.04),
        (0.06, 1.15),
        (-0.15, 1.15),
        (-0.30, 0.98),
        (-0.35, 0.74),
        (-0.32, 0.49),
    ]
    add_extruded_xz_polygon(
        bm, horse_body, half_thickness=0.175, taper_front=0.90, rot_z=rot_z, mat_idx=0, sharp=True
    )

    # Armored chamfron (head plate) + war gorget chest armor (accent)
    chamfron = [
        (0.14, 0.99),
        (0.42, 0.87),
        (0.47, 0.76),
        (0.38, 0.71),
        (0.16, 0.86),
    ]
    add_extruded_xz_polygon(bm, chamfron, half_thickness=0.135, rot_z=rot_z, mat_idx=1, sharp=True)

    gorget = [
        (-0.29, 0.34),
        (0.28, 0.34),
        (0.29, 0.50),
        (-0.31, 0.50),
    ]
    add_extruded_xz_polygon(bm, gorget, half_thickness=0.20, rot_z=rot_z, mat_idx=1, sharp=True)

    # Prominent Unicorn / War Horn projecting up-forward (accent)
    add_cone(
        bm,
        radius1=0.075,
        radius2=0.012,
        depth=0.36,
        segments=8,
        center=(0.24, -0.05, 1.18),
        rot_euler=(0.0, math.radians(38.0), rot_z),
        mat_idx=1,
        sharp=True,
    )

    # Armored ears
    for y_off in (-0.095, 0.095):
        ear = [(-0.08, 1.12), (0.07, 1.12), (0.02, 1.31), (-0.08, 1.27)]
        add_extruded_xz_polygon(
            bm, ear, half_thickness=0.042, rot_z=rot_z, offset=(0.0, y_off, 0.0), mat_idx=0, sharp=True
        )

    # Blazing spiked battle mane (accent)
    flame_mane = [
        (-0.18, 1.14),
        (-0.42, 1.15),
        (-0.31, 0.98),
        (-0.49, 0.90),
        (-0.34, 0.76),
        (-0.48, 0.62),
        (-0.33, 0.48),
        (-0.22, 0.44),
    ]
    add_extruded_xz_polygon(bm, flame_mane, half_thickness=0.085, rot_z=rot_z, mat_idx=1, sharp=True)

    return finalize_bmesh_object("SuperKnight", bm)


# ---------------------------------------------------------------------------
# 4. BISHOP & SUPER BISHOP
# ---------------------------------------------------------------------------
def build_bishop() -> bpy.types.Object:
    bm = bmesh.new()
    # Lower body up to collar
    body_profile = [
        (0.000, 0.000, False),
        (0.440, 0.000, True),
        (0.440, 0.085, True),
        (0.395, 0.140, True),
        (0.355, 0.200, True),
        (0.305, 0.260, False),
        (0.235, 0.400, False),
        (0.185, 0.560, False),
        (0.160, 0.680, True),
        (0.285, 0.725, True),
        (0.295, 0.765, True),
        (0.225, 0.805, True),
        (0.165, 0.830, True),
        (0.000, 0.830, False),
    ]
    add_lathe(bm, body_profile, segments=24, mat_idx=0)

    # Pointed Gothic mitre with unmistakable diagonal cleft cut into right-upper silhouette
    mitre_main = [
        (-0.17, 0.81),
        (0.17, 0.81),
        (0.25, 0.93),
        (0.24, 1.00),
        (0.04, 0.98),   # Cleft bottom-inner notch
        (0.21, 1.09),   # Cleft upper lip
        (0.13, 1.19),
        (0.00, 1.25),
        (-0.15, 1.17),
        (-0.25, 1.04),
        (-0.25, 0.92),
    ]
    add_extruded_xz_polygon(bm, mitre_main, half_thickness=0.175, taper_front=0.88, mat_idx=0, sharp=True)

    # Rounded front/back mitre belly for 3D volume (stays below cleft)
    add_uv_sphere(bm, radius=0.22, center=(-0.03, 0.0, 0.97), scale=(0.92, 0.95, 1.05), mat_idx=0)

    # Top finial orb
    add_uv_sphere(bm, radius=0.072, center=(0.0, 0.0, 1.285), mat_idx=0)

    return finalize_bmesh_object("Bishop", bm)


def build_super_bishop() -> bpy.types.Object:
    bm = bmesh.new()
    body_profile = [
        (0.000, 0.000, False),
        (0.480, 0.000, True),
        (0.480, 0.090, True),
        (0.430, 0.150, True),
        (0.380, 0.220, True),
        (0.320, 0.285, False),
        (0.250, 0.430, False),
        (0.200, 0.590, False),
        (0.175, 0.690, True),
        (0.325, 0.740, True),
        (0.335, 0.785, True),
        (0.245, 0.825, True),
        (0.180, 0.850, True),
        (0.000, 0.850, False),
    ]
    add_lathe(bm, body_profile, segments=24, mat_idx=0)

    # Armored clerical shoulder mantle (accent)
    add_torus_ring(bm, major_r=0.285, minor_r=0.055, center=(0.0, 0.0, 0.76), mat_idx=1, sharp=True)

    # Two-tier ornate mitre with diagonal cleft
    mitre_pts = [
        (-0.18, 0.83),
        (0.18, 0.83),
        (0.27, 0.96),
        (0.26, 1.03),
        (0.04, 1.01),
        (0.23, 1.12),
        (0.14, 1.24),
        (0.00, 1.31),
        (-0.16, 1.22),
        (-0.27, 1.06),
        (-0.27, 0.94),
    ]
    add_extruded_xz_polygon(bm, mitre_pts, half_thickness=0.18, taper_front=0.88, mat_idx=0, sharp=True)

    # Mid mitre crown band (accent)
    add_box(bm, size=(0.48, 0.34, 0.075), center=(0.0, 0.0, 0.90), mat_idx=1, sharp=True)

    # Top finial cross/orb (accent)
    add_uv_sphere(bm, radius=0.075, center=(0.0, 0.0, 1.32), mat_idx=1)

    # Radiant Halo Ring behind the mitre apex (accent)
    add_torus_ring(
        bm,
        major_r=0.35,
        minor_r=0.052,
        major_seg=24,
        minor_seg=8,
        center=(0.0, 0.16, 1.04),
        rot_euler=(math.radians(90.0), 0.0, 0.0),
        mat_idx=1,
        sharp=False,
    )
    # 4 halo cardinal spikes
    for ang_deg in (0.0, 45.0, 135.0, 180.0):
        ang = math.radians(ang_deg)
        sx = 0.44 * math.cos(ang)
        sz = 1.04 + 0.44 * math.sin(ang)
        add_cone(
            bm,
            radius1=0.055,
            radius2=0.010,
            depth=0.16,
            segments=6,
            center=(sx, 0.16, sz),
            rot_euler=(0.0, math.radians(90.0) - ang, 0.0),
            mat_idx=1,
            sharp=True,
        )

    return finalize_bmesh_object("SuperBishop", bm)


# ---------------------------------------------------------------------------
# 5. QUEEN & SUPER QUEEN
# ---------------------------------------------------------------------------
def build_queen() -> bpy.types.Object:
    bm = bmesh.new()
    profile = [
        (0.000, 0.000, False),
        (0.450, 0.000, True),
        (0.450, 0.085, True),
        (0.400, 0.145, True),
        (0.360, 0.210, True),
        (0.300, 0.285, False),
        (0.220, 0.460, False),
        (0.165, 0.660, False),
        (0.180, 0.800, True),
        (0.300, 0.855, True),
        (0.305, 0.895, True),
        (0.215, 0.935, True),
        (0.295, 1.090, True),
        (0.215, 1.090, True),
        (0.165, 1.150, False),
        (0.000, 1.180, False),
    ]
    add_lathe(bm, profile, segments=24, mat_idx=0)

    # 6 sharp coronet spikes around crown rim
    for i in range(6):
        ang = math.radians(30.0) + (2.0 * math.pi * i) / 6
        x = 0.275 * math.cos(ang)
        y = 0.275 * math.sin(ang)
        add_cone(
            bm,
            radius1=0.068,
            radius2=0.012,
            depth=0.22,
            segments=6,
            center=(x, y, 1.16),
            rot_euler=(0.0, 0.0, ang),
            mat_idx=0,
            sharp=True,
        )

    # Royal gem orb on top
    add_uv_sphere(bm, radius=0.088, center=(0.0, 0.0, 1.255), mat_idx=0)
    return finalize_bmesh_object("Queen", bm)


def build_super_queen() -> bpy.types.Object:
    bm = bmesh.new()
    profile = [
        (0.000, 0.000, False),
        (0.490, 0.000, True),
        (0.490, 0.090, True),
        (0.435, 0.155, True),
        (0.385, 0.225, True),
        (0.320, 0.300, False),
        (0.235, 0.480, False),
        (0.180, 0.675, False),
        (0.200, 0.815, True),
        (0.335, 0.870, True),
        (0.340, 0.915, True),
        (0.235, 0.955, True),
        (0.325, 1.115, True),
        (0.230, 1.115, True),
        (0.180, 1.175, False),
        (0.000, 1.205, False),
    ]
    add_lathe(bm, profile, segments=24, mat_idx=0)

    # Accent imperial collar ring
    add_torus_ring(bm, major_r=0.315, minor_r=0.050, center=(0.0, 0.0, 0.89), mat_idx=1, sharp=True)

    # 7 tall Imperial Crown spikes (accent)
    for i in range(7):
        ang = math.radians(15.0) + (2.0 * math.pi * i) / 7
        x = 0.305 * math.cos(ang)
        y = 0.305 * math.sin(ang)
        add_cone(
            bm,
            radius1=0.072,
            radius2=0.012,
            depth=0.26,
            segments=6,
            center=(x, y, 1.20),
            rot_euler=(0.0, 0.0, ang),
            mat_idx=1,
            sharp=True,
        )

    # Elevated Imperial top gem (accent)
    add_uv_sphere(bm, radius=0.095, center=(0.0, 0.0, 1.27), mat_idx=1)

    # Dramatic Spread Gothic Wings behind shoulders (accent)
    for side in (-1.0, 1.0):
        wing_pts = [
            (side * 0.16, 0.72),
            (side * 0.56, 0.92),
            (side * 0.62, 1.18),
            (side * 0.44, 1.12),
            (side * 0.48, 1.25),
            (side * 0.24, 1.02),
            (side * 0.16, 0.88),
        ]
        # Ensure consistent CCW winding for both sides
        if side < 0.0:
            wing_pts = list(reversed(wing_pts))
        add_extruded_xz_polygon(
            bm, wing_pts, half_thickness=0.050, offset=(0.0, 0.14, 0.0), mat_idx=1, sharp=True
        )

    return finalize_bmesh_object("SuperQueen", bm)


# ---------------------------------------------------------------------------
# 6. KING
# ---------------------------------------------------------------------------
def build_king() -> bpy.types.Object:
    bm = bmesh.new()
    profile = [
        (0.000, 0.000, False),
        (0.470, 0.000, True),
        (0.470, 0.090, True),
        (0.420, 0.155, True),
        (0.380, 0.220, True),
        (0.320, 0.295, False),
        (0.245, 0.475, False),
        (0.200, 0.675, False),
        (0.215, 0.790, True),
        (0.335, 0.840, True),
        (0.340, 0.885, True),
        (0.245, 0.920, True),
        (0.330, 1.055, True),
        (0.320, 1.105, True),
        (0.220, 1.145, False),
        (0.110, 1.165, False),
        (0.000, 1.170, False),
    ]
    add_lathe(bm, profile, segments=24, mat_idx=0)

    # Large, unmistakable Gothic Cross on top
    add_box(bm, size=(0.105, 0.105, 0.26), center=(0.0, 0.0, 1.235), mat_idx=0, sharp=True)
    add_box(bm, size=(0.295, 0.100, 0.095), center=(0.0, 0.0, 1.265), mat_idx=0, sharp=True)
    return finalize_bmesh_object("King", bm)


# ---------------------------------------------------------------------------
# 7. SCARECROW (Special Entity)
# ---------------------------------------------------------------------------
def build_scarecrow() -> bpy.types.Object:
    """
    Material slots:
      0 = Straw (hat, head, straw cuffs)
      1 = Wood (cross stake, arms, base mound)
      2 = Tattered Gothic Cloth (cloak/tunic)
      3 = Glowing Eyes (#FFF0C2)
    """
    bm = bmesh.new()

    # Dirt/wood base mound
    mound = [
        (0.000, 0.000, False),
        (0.400, 0.000, True),
        (0.370, 0.070, True),
        (0.240, 0.130, False),
        (0.000, 0.145, False),
    ]
    add_lathe(bm, mound, segments=16, mat_idx=1)

    # Wooden vertical stake & horizontal crossbar arms
    add_cone(bm, radius1=0.072, radius2=0.060, depth=0.90, segments=10, center=(0.0, 0.0, 0.50), mat_idx=1, sharp=True)
    add_box(
        bm,
        size=(1.04, 0.095, 0.095),
        center=(0.0, 0.0, 0.72),
        rot_euler=(0.0, math.radians(-3.0), 0.0),
        mat_idx=1,
        sharp=True,
    )

    # Tattered Gothic cloak draped on stake
    cloak_profile = [
        (0.000, 0.240, False),
        (0.285, 0.240, True),
        (0.255, 0.420, False),
        (0.210, 0.620, False),
        (0.245, 0.740, True),
        (0.140, 0.790, True),
        (0.000, 0.790, False),
    ]
    add_lathe(bm, cloak_profile, segments=12, mat_idx=2, smooth_faces=False)

    # Draped sleeve rags + straw tufts sticking out of sleeves
    for side in (-1.0, 1.0):
        add_box(
            bm,
            size=(0.24, 0.16, 0.19),
            center=(side * 0.30, 0.0, 0.69),
            rot_euler=(0.0, side * math.radians(10.0), 0.0),
            mat_idx=2,
            sharp=True,
        )
        add_cone(
            bm,
            radius1=0.095,
            radius2=0.145,
            depth=0.16,
            segments=8,
            center=(side * 0.49, 0.0, 0.71),
            rot_euler=(0.0, side * math.radians(90.0), 0.0),
            mat_idx=0,
            sharp=True,
        )

    # Burlap / straw head
    add_uv_sphere(bm, radius=0.175, center=(0.0, 0.0, 0.91), scale=(1.0, 0.95, 1.06), mat_idx=0)

    # Two bright glowing eyes facing camera (-Y), clearly visible under the hat brim
    for side in (-1.0, 1.0):
        add_box(
            bm,
            size=(0.078, 0.068, 0.062),
            center=(side * 0.076, -0.172, 0.885),
            rot_euler=(0.0, side * math.radians(-10.0), 0.0),
            mat_idx=3,
            sharp=True,
        )

    # Wide-brimmed tattered pointed straw hat (tilted slightly back so eyes shine)
    add_cone(
        bm,
        radius1=0.37,
        radius2=0.21,
        depth=0.060,
        segments=14,
        center=(0.0, 0.02, 1.055),
        rot_euler=(math.radians(-6.0), math.radians(-5.0), 0.0),
        mat_idx=0,
        sharp=True,
    )
    add_cone(
        bm,
        radius1=0.20,
        radius2=0.025,
        depth=0.32,
        segments=10,
        center=(0.04, 0.04, 1.225),
        rot_euler=(math.radians(-4.0), math.radians(14.0), 0.0),
        mat_idx=0,
        sharp=True,
    )

    return finalize_bmesh_object("Scarecrow", bm)


# ---------------------------------------------------------------------------
# 8. HEAL POINT (Special Entity)
# ---------------------------------------------------------------------------
def build_heal_point() -> bpy.types.Object:
    """
    Material slots:
      0 = Stone Pedestal
      1 = Glowing Emerald/Ice Crystal
    """
    bm = bmesh.new()

    # Octagonal carved stone pedestal
    pedestal_profile = [
        (0.000, 0.000, False),
        (0.450, 0.000, True),
        (0.450, 0.085, True),
        (0.390, 0.145, True),
        (0.335, 0.255, True),
        (0.385, 0.310, True),
        (0.355, 0.355, True),
        (0.000, 0.355, False),
    ]
    add_lathe(bm, pedestal_profile, segments=8, mat_idx=0, smooth_faces=False)

    # Glowing rune ring seated on pedestal top
    add_torus_ring(bm, major_r=0.24, minor_r=0.036, major_seg=12, minor_seg=6, center=(0.0, 0.0, 0.365), mat_idx=1, sharp=True)

    # Central floating faceted healing crystal (octagonal diamond obelisk, clearly levitating)
    crystal_profile = [
        (0.000, 0.470, False),
        (0.245, 0.720, True),
        (0.275, 0.900, True),
        (0.210, 1.070, True),
        (0.000, 1.340, False),
    ]
    add_lathe(bm, crystal_profile, segments=6, mat_idx=1, smooth_faces=False)

    # Two smaller orbiting crystal shards flanking left & right
    for side, z_off, tilt in ((-1.0, 0.88, -14.0), (1.0, 0.82, 16.0)):
        add_cone(
            bm,
            radius1=0.095,
            radius2=0.008,
            depth=0.20,
            segments=6,
            center=(side * 0.43, 0.0, z_off + 0.09),
            rot_euler=(0.0, math.radians(tilt), 0.0),
            mat_idx=1,
            sharp=True,
        )
        add_cone(
            bm,
            radius1=0.008,
            radius2=0.095,
            depth=0.14,
            segments=6,
            center=(side * 0.43, 0.0, z_off - 0.08),
            rot_euler=(0.0, math.radians(tilt), 0.0),
            mat_idx=1,
            sharp=True,
        )

    return finalize_bmesh_object("HealPoint", bm)


# ---------------------------------------------------------------------------
# Batch Orchestration
# ---------------------------------------------------------------------------
def clear_collection(col: bpy.types.Collection) -> None:
    for obj in list(col.objects):
        mesh_data = obj.data if isinstance(obj.data, bpy.types.Mesh) else None
        col.objects.unlink(obj)
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh_data and mesh_data.users == 0:
            bpy.data.meshes.remove(mesh_data)


def render_all_pieces() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    clear_scene()
    scene = bpy.context.scene
    view_layer = bpy.context.view_layer

    piece_col = bpy.data.collections.new("PieceCollection")
    scene.collection.children.link(piece_col)

    shadow_obj = build_contact_shadow_disc()
    scene.collection.objects.link(shadow_obj)

    setup_camera_and_lights(scene)
    configure_render(scene, view_layer, piece_col)

    # Materials
    mat_white = create_cel_material("Mat_White", PALETTE_WHITE)
    mat_black = create_cel_material("Mat_Black", PALETTE_BLACK)
    mat_super_w = create_cel_material("Mat_SuperWhiteAccent", PALETTE_SUPER_WHITE_ACCENT)
    mat_super_b = create_cel_material("Mat_SuperBlackAccent", PALETTE_SUPER_BLACK_ACCENT)

    mat_straw = create_cel_material("Mat_Straw", PALETTE_STRAW)
    mat_wood = create_cel_material("Mat_Wood", PALETTE_WOOD)
    mat_cloth = create_cel_material("Mat_Cloth", PALETTE_CLOTH)
    mat_eye = create_flat_emission_material("Mat_ScarecrowEye", SCARECROW_EYE_HEX)

    mat_stone = create_cel_material("Mat_Stone", PALETTE_STONE)
    mat_crystal = create_cel_material("Mat_Crystal", PALETTE_CRYSTAL)

    # Render queue: (piece_key, builder_fn, shadow_scale, variants[(filename, mats, outline_hex)])
    jobs = [
        ("pawn", build_pawn, 1.00, [
            ("pawn_white.png", [mat_white], PALETTE_WHITE["outline"]),
            ("pawn_black.png", [mat_black], PALETTE_BLACK["outline"]),
        ]),
        ("knight", build_knight, 1.02, [
            ("knight_white.png", [mat_white], PALETTE_WHITE["outline"]),
            ("knight_black.png", [mat_black], PALETTE_BLACK["outline"]),
        ]),
        ("bishop", build_bishop, 1.00, [
            ("bishop_white.png", [mat_white], PALETTE_WHITE["outline"]),
            ("bishop_black.png", [mat_black], PALETTE_BLACK["outline"]),
        ]),
        ("rook", build_rook, 1.02, [
            ("rook_white.png", [mat_white], PALETTE_WHITE["outline"]),
            ("rook_black.png", [mat_black], PALETTE_BLACK["outline"]),
        ]),
        ("queen", build_queen, 1.02, [
            ("queen_white.png", [mat_white], PALETTE_WHITE["outline"]),
            ("queen_black.png", [mat_black], PALETTE_BLACK["outline"]),
        ]),
        ("king", build_king, 1.06, [
            ("king_white.png", [mat_white], PALETTE_WHITE["outline"]),
            ("king_black.png", [mat_black], PALETTE_BLACK["outline"]),
        ]),
        ("super_pawn", build_super_pawn, 1.08, [
            ("super_pawn_white.png", [mat_white, mat_super_w], PALETTE_WHITE["outline"]),
            ("super_pawn_black.png", [mat_black, mat_super_b], PALETTE_BLACK["outline"]),
        ]),
        ("super_knight", build_super_knight, 1.10, [
            ("super_knight_white.png", [mat_white, mat_super_w], PALETTE_WHITE["outline"]),
            ("super_knight_black.png", [mat_black, mat_super_b], PALETTE_BLACK["outline"]),
        ]),
        ("super_bishop", build_super_bishop, 1.08, [
            ("super_bishop_white.png", [mat_white, mat_super_w], PALETTE_WHITE["outline"]),
            ("super_bishop_black.png", [mat_black, mat_super_b], PALETTE_BLACK["outline"]),
        ]),
        ("super_rook", build_super_rook, 1.10, [
            ("super_rook_white.png", [mat_white, mat_super_w], PALETTE_WHITE["outline"]),
            ("super_rook_black.png", [mat_black, mat_super_b], PALETTE_BLACK["outline"]),
        ]),
        ("super_queen", build_super_queen, 1.10, [
            ("super_queen_white.png", [mat_white, mat_super_w], PALETTE_WHITE["outline"]),
            ("super_queen_black.png", [mat_black, mat_super_b], PALETTE_BLACK["outline"]),
        ]),
        ("scarecrow", build_scarecrow, 0.92, [
            ("scarecrow.png", [mat_straw, mat_wood, mat_cloth, mat_eye], PALETTE_STRAW["outline"]),
        ]),
        ("heal_point", build_heal_point, 1.02, [
            ("heal_point.png", [mat_stone, mat_crystal], PALETTE_STONE["outline"]),
        ]),
    ]

    total = 0
    for piece_key, builder_fn, shadow_scale, variants in jobs:
        clear_collection(piece_col)
        obj = builder_fn()
        piece_col.objects.link(obj)
        shadow_obj.scale = (1.06 * shadow_scale, 0.92 * shadow_scale, 1.0)

        for filename, mats, outline_hex in variants:
            # Never call materials.clear() because Blender resets face material_index to 0!
            while len(obj.data.materials) < len(mats):
                obj.data.materials.append(None)
            for slot_idx, m in enumerate(mats):
                obj.data.materials[slot_idx] = m

            out_path = os.path.join(OUTPUT_DIR, filename)
            scene.render.filepath = out_path
            bpy.ops.render.render(write_still=True)

            enforce_hard_pixel_alpha(out_path, outline_hex)
            total += 1
            print(f"[Ag4] ({total:02d}/24) Exported: {filename}")

    clear_collection(piece_col)
    print(f"[Ag4] Batch complete: {total}/24 sprites rendered to {OUTPUT_DIR}")


if __name__ == "__main__":
    render_all_pieces()
