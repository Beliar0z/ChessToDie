# E:\ChessToDie\tools\blender\render_golden_pawns.py
# Python / Blender 5.3.0 bpy / Chess to Die (Ag4 - Golden Standard 3D-to-Pixel Pawns)
"""
Procedural 3D-to-Pixel renderer for Chess to Die Golden Standard pawns:
  - assets/sprites/pieces/pawn_white.png (64x64 RGBA, hard alpha, Freestyle outline)
  - assets/sprites/pieces/pawn_black.png (64x64 RGBA, hard alpha, Freestyle outline)

Run with:
  & "E:\\blender\\blender.exe" --background --python E:\\ChessToDie\\tools\\blender\\render_golden_pawns.py
"""

import math
import os
import bpy
import bmesh
import numpy as np
from mathutils import Vector

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

FREESTYLE_OUTLINE_HEX = "#0A080C"
CONTACT_SHADOW_HEX = "#0A080C"


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


def configure_render(scene: bpy.types.Scene, view_layer: bpy.types.ViewLayer, pawn_collection: bpy.types.Collection) -> None:
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

    # Disable anti-aliasing / temporal jitter & denoising on EEVEE / Cycles
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

    # Exact sRGB color management (no Filmic/AgX desaturation)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    # World background (black transparent, slight ambient handled by cel shader)
    world = bpy.data.worlds.new("PawnWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.04, 0.04, 0.05, 1.0)
        bg.inputs[1].default_value = 0.15

    # Freestyle dark silhouette + crease lines
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.35

    fs = view_layer.freestyle_settings
    fs.use_culling = True
    fs.crease_angle = math.radians(128.0)

    # Clear existing line sets
    while len(fs.linesets) > 0:
        fs.linesets.remove(fs.linesets[0])

    ls = fs.linesets.new("PawnOutline")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_external_contour = True
    ls.select_edge_mark = True
    ls.select_by_collection = True
    ls.collection = pawn_collection
    ls.collection_negation = "INCLUSIVE"

    style = ls.linestyle
    style.color = hex_to_linear_rgba(FREESTYLE_OUTLINE_HEX)[:3]
    style.alpha = 1.0
    style.thickness = 1.35
    style.caps = "ROUND"
    style.use_chaining = True


def build_gothic_pawn_mesh(name: str = "GothicPawn") -> bpy.types.Object:
    """
    Procedural classic-Gothic chess pawn with chunky proportions
    tuned for high readability at 64x64 pixel resolution.
    Profile: (radius, z_height, mark_sharp_ring)
    Total height ~1.20 units, base diameter ~0.88 units.
    """
    profile = [
        (0.000, 0.000, False),  # Bottom center
        (0.440, 0.000, True),   # Base outer bottom
        (0.440, 0.085, True),   # Base vertical plinth
        (0.395, 0.135, True),   # First Gothic step
        (0.355, 0.165, False),  # Base bevel
        (0.365, 0.215, True),   # Lower torus ridge
        (0.315, 0.265, False),  # Transition to waist
        (0.250, 0.360, False),  # Lower waist
        (0.200, 0.500, False),  # Mid waist
        (0.165, 0.650, True),   # Upper neck below collar
        (0.275, 0.695, True),   # Sharp Gothic collar flange (bottom)
        (0.285, 0.735, True),   # Collar outer rim
        (0.235, 0.775, True),   # Collar top ledge
        (0.155, 0.805, True),   # Neck under head
        # Spherical head (center ~0.995, radius ~0.245)
        (0.205, 0.855, False),
        (0.245, 0.935, False),
        (0.252, 1.015, False),
        (0.225, 1.095, False),
        (0.160, 1.160, False),
        (0.085, 1.200, False),
        (0.000, 1.215, False),  # Top apex
    ]

    segments = 24
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm = bmesh.new()

    rings: list[list[bmesh.types.BMVert]] = []
    bottom_vert = None
    top_vert = None

    for idx, (r, z, _sharp) in enumerate(profile):
        if idx == 0 and r == 0.0:
            bottom_vert = bm.verts.new((0.0, 0.0, z))
            rings.append([bottom_vert])
        elif idx == len(profile) - 1 and r == 0.0:
            top_vert = bm.verts.new((0.0, 0.0, z))
            rings.append([top_vert])
        else:
            ring = []
            for s in range(segments):
                angle = (2.0 * math.pi * s) / segments
                x = r * math.cos(angle)
                y = r * math.sin(angle)
                ring.append(bm.verts.new((x, y, z)))
            rings.append(ring)

    bm.verts.ensure_lookup_table()

    # Connect rings into faces
    for i in range(len(rings) - 1):
        r0 = rings[i]
        r1 = rings[i + 1]
        if len(r0) == 1 and len(r1) == segments:
            # Bottom fan
            center = r0[0]
            for s in range(segments):
                v1 = r1[(s + 1) % segments]
                v2 = r1[s]
                bm.faces.new((center, v1, v2))
        elif len(r0) == segments and len(r1) == 1:
            # Top fan
            center = r1[0]
            for s in range(segments):
                v1 = r0[s]
                v2 = r0[(s + 1) % segments]
                bm.faces.new((v1, v2, center))
        else:
            for s in range(segments):
                s_next = (s + 1) % segments
                bm.faces.new((r0[s], r0[s_next], r1[s_next], r1[s]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # Mark crisp horizontal rings for Freestyle crease/edge mark
    for i, (_r, _z, sharp) in enumerate(profile):
        if sharp and len(rings[i]) == segments:
            ring = rings[i]
            for s in range(segments):
                v1 = ring[s]
                v2 = ring[(s + 1) % segments]
                edge = bm.edges.get((v1, v2))
                if edge:
                    edge.smooth = False

    # Smooth all faces by default (sharp edges stay crisp via edge.smooth)
    for face in bm.faces:
        face.smooth = True

    bm.to_mesh(mesh)
    bm.free()

    # Add edge split modifier on sharp edges so normals stay crisp on collar & plinth
    obj = bpy.data.objects.new(name, mesh)
    edge_split = obj.modifiers.new(name="SharpSplit", type="EDGE_SPLIT")
    edge_split.use_edge_angle = False
    edge_split.use_edge_sharp = True

    return obj


def build_contact_shadow_disc() -> bpy.types.Object:
    """Flat grounding disc beneath the pawn base for crisp pixel contact shadow."""
    mesh = bpy.data.meshes.new("ContactShadow_Mesh")
    bm = bmesh.new()
    bmesh.ops.create_circle(
        bm,
        cap_ends=True,
        radius=0.47,
        segments=24,
    )
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("ContactShadow", mesh)
    obj.location = (0.04, 0.04, -0.008)
    obj.scale = (1.06, 0.92, 1.0)

    mat = bpy.data.materials.new("Mat_ContactShadow")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out_node = nodes.new("ShaderNodeOutputMaterial")
    emit_node = nodes.new("ShaderNodeEmission")
    emit_node.inputs["Color"].default_value = hex_to_linear_rgba(CONTACT_SHADOW_HEX)
    emit_node.inputs["Strength"].default_value = 1.0
    links.new(emit_node.outputs["Emission"], out_node.inputs["Surface"])

    obj.data.materials.append(mat)
    return obj


def create_cel_material(name: str, palette: dict) -> bpy.types.Material:
    """
    3-step CONSTANT Cel Shader (Balatro-inspired hard block shading).
    Uses Diffuse -> ShaderToRGB -> ColorRamp(CONSTANT) -> Emission
    so output colors stay locked to the Art Bible hex palette.
    Optional Fresnel rim boost for Black piece readability.
    """
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

    # Configure 3 stepped stops: dark -> mid -> light
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


def setup_camera_and_lights(scene: bpy.types.Scene) -> None:
    # Orthographic 3/4 front-top camera
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

    # Key directional sun from upper-left-front for crisp block shading
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

    # Subtle fill light from lower-right to prevent crushed midtones
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


def enforce_hard_pixel_alpha(filepath: str, outline_hex: str) -> None:
    """
    Post-process rendered 64x64 RGBA PNG to guarantee 100% hard alpha
    (only 0 or 255, zero blurry semi-transparent halo pixels).
    """
    img = bpy.data.images.load(filepath, check_existing=False)
    try:
        w, h = img.size[0], img.size[1]
        pixels = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))

        alpha = pixels[:, :, 3]
        outline_r, outline_g, outline_b = hex_to_srgb_tuple(outline_hex)

        # Hard alpha threshold: >= 0.42 becomes fully opaque, < 0.42 becomes fully transparent
        opaque_mask = alpha >= 0.42
        fringe_mask = opaque_mask & (alpha < 0.92)

        # Snap semi-transparent edge pixels to crisp dark outline color to avoid light halo
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


def render_golden_pawns() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    clear_scene()
    scene = bpy.context.scene
    view_layer = bpy.context.view_layer

    # Separate collection for pawn mesh so Freestyle outlines ONLY the pawn, not contact shadow
    pawn_col = bpy.data.collections.new("PawnCollection")
    scene.collection.children.link(pawn_col)

    pawn_obj = build_gothic_pawn_mesh("GoldenPawn")
    pawn_col.objects.link(pawn_obj)

    shadow_obj = build_contact_shadow_disc()
    scene.collection.objects.link(shadow_obj)

    setup_camera_and_lights(scene)
    configure_render(scene, view_layer, pawn_col)

    mat_white = create_cel_material("Mat_PawnWhite", PALETTE_WHITE)
    mat_black = create_cel_material("Mat_PawnBlack", PALETTE_BLACK)

    renders = [
        ("pawn_white.png", mat_white, PALETTE_WHITE["outline"]),
        ("pawn_black.png", mat_black, PALETTE_BLACK["outline"]),
    ]

    for filename, material, outline_hex in renders:
        pawn_obj.data.materials.clear()
        pawn_obj.data.materials.append(material)

        out_path = os.path.join(OUTPUT_DIR, filename)
        scene.render.filepath = out_path
        bpy.ops.render.render(write_still=True)

        enforce_hard_pixel_alpha(out_path, outline_hex)
        print(f"[Ag4] Exported: {out_path}")


if __name__ == "__main__":
    render_golden_pawns()
