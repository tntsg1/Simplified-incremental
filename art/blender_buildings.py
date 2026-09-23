"""zengliang · 自制 Blender 建筑渲染管线（六个建筑，统一场景规范）

设计语言: 石墨蓝结构 + 钢件 + 青色能量光 / 琥珀工业光，统一 3/4 正交视角、
三点光（暖主光 · 冷补光 · 蓝轮廓光），透明底出图。每个建筑一个"一眼可辨"的核心符号:
  miner   → 井架桅杆 + 贯穿台面的钻头 + 矿仓矿石
  solar   → 三面同角度光伏板 + 变换器
  fusion  → 双环磁约束 + 等离子核心
  lab     → 穹顶 + 大口径望远镜筒
  commerce→ 三层塔 + 环形招牌 + 货柜吊臂
  colony  → 主穹顶 + 居住舱群 + 信标塔尖

Run:
  "G:/blender/blender.exe" --background --factory-startup --python E:/godot/zengliang/art/blender_buildings.py
Output: art/renders/<name>.png (768×768, RGBA)
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "renders"
OUT.mkdir(parents=True, exist_ok=True)


# ---------------- 场景 ----------------

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
                  bpy.data.lights, bpy.data.cameras):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def setup_scene(ortho=5.6, target_z=0.95):
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "AgX"
    except TypeError:
        pass
    scene.world.color = (0.10, 0.13, 0.18)

    bpy.ops.object.camera_add(location=(6.2, -7.8, 5.6))
    cam = bpy.context.object
    tgt = Vector((0.0, 0.0, target_z))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    scene.camera = cam

    def area(name, loc, power, color, size):
        bpy.ops.object.light_add(type="AREA", location=loc)
        L = bpy.context.object
        L.name = name
        L.data.energy = power
        L.data.color = color
        L.data.shape = "DISK"
        L.data.size = size
        L.rotation_euler = (tgt - L.location).to_track_quat("-Z", "Y").to_euler()

    area("key · warm", (3.6, -4.6, 7.2), 950, (1.0, 0.84, 0.70), 5.0)
    area("fill · cool", (-4.2, -1.2, 4.6), 480, (0.55, 0.80, 1.0), 5.5)
    area("rim · blue", (-0.6, 4.2, 5.2), 720, (0.40, 0.72, 1.0), 3.0)


# ---------------- 材质 ----------------

def material(name, color, metallic=0.4, roughness=0.4, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if glow:
        for key in ("Emission Color", "Emission"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = (*color, 1.0)
                break
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = glow
    return mat


GRAPHITE = None
STEEL = None
DARK = None
CYAN = None
AMBER = None
AMBER_D = None
MAGENTA = None
HULL = None
PLASMA = None
WINDOW_WARM = None
PANEL = None


def make_palette():
    global GRAPHITE, STEEL, DARK, CYAN, AMBER, AMBER_D, MAGENTA, HULL, PLASMA, WINDOW_WARM, PANEL
    GRAPHITE = material("graphite", (0.085, 0.115, 0.16), 0.5, 0.38)
    STEEL = material("steel", (0.42, 0.48, 0.56), 0.7, 0.28)
    DARK = material("dark recess", (0.015, 0.03, 0.045), 0.3, 0.5)
    CYAN = material("cyan light", (0.20, 0.85, 0.95), 0.1, 0.2, glow=2.5)
    AMBER = material("amber light", (1.0, 0.62, 0.20), 0.2, 0.3, glow=1.8)
    AMBER_D = material("amber casing", (0.72, 0.42, 0.10), 0.4, 0.45)
    MAGENTA = material("magenta", (0.85, 0.35, 0.75), 0.2, 0.35, glow=1.4)
    HULL = material("hull light", (0.55, 0.62, 0.72), 0.45, 0.4)
    PLASMA = material("plasma", (0.55, 0.95, 1.0), 0.0, 0.15, glow=6.0)
    WINDOW_WARM = material("window warm", (1.0, 0.75, 0.45), 0.0, 0.3, glow=2.2)
    PANEL = material("panel", (0.10, 0.16, 0.24), 0.6, 0.25)


# ---------------- 建模工具 ----------------

def finish(obj, name, mat, bevel=0.04, smooth=True):
    obj.name = name
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    if bevel and hasattr(obj.data, "polygons"):
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
    if smooth and hasattr(obj.data, "polygons"):
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def box(name, loc, size, mat, bevel=0.04, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(obj, name, mat, bevel)


def cyl(name, loc, r, depth, mat, verts=48, bevel=0.02, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    obj = bpy.context.object
    if rot:
        obj.rotation_euler = rot
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(obj, name, mat, bevel)


def cone(name, loc, r_bottom, r_top, depth, mat, verts=48, bevel=0.01, rot=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r_bottom, radius2=r_top,
                                    depth=depth, location=loc)
    obj = bpy.context.object
    if rot:
        obj.rotation_euler = rot
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(obj, name, mat, bevel)


def sphere(name, loc, r, mat, scale=(1, 1, 1), segments=48):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segments,
                                         ring_count=segments // 2, location=loc)
    obj = bpy.context.object
    if scale != (1, 1, 1):
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, 0.0)


def ico(name, loc, r, mat, subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    return finish(bpy.context.object, name, mat, 0.0, smooth=False)


def torus(name, loc, R, r, mat, rot=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r,
                                     major_segments=48, minor_segments=12, location=loc)
    obj = bpy.context.object
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat, 0.0)


def rod(name, a, b, r, mat, verts=16):
    a_v, b_v = Vector(a), Vector(b)
    center = (a_v + b_v) * 0.5
    direction = b_v - a_v
    obj = cyl(name, center, r, direction.length, mat, verts)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


# ---------------- 建筑 ----------------

def build_miner():
    cyl("deck", (0, 0, 0.34), 1.55, 0.22, GRAPHITE, verts=8, bevel=0.05)
    cyl("deck rim", (0, 0, 0.47), 1.62, 0.07, STEEL, verts=8, bevel=0.02)
    # 桅杆与斜撑
    box("mast", (0, 0, 1.55), (0.26, 0.26, 2.1), STEEL, 0.03)
    for z in (1.05, 1.75):
        box("mast band", (0, 0, z), (0.34, 0.34, 0.10), GRAPHITE, 0.02)
    rod("brace l", (-1.15, 0.55, 0.55), (-0.14, 0.10, 1.55), 0.045, STEEL)
    rod("brace r", (1.15, 0.55, 0.55), (0.14, 0.10, 1.55), 0.045, STEEL)
    box("head", (0, 0, 2.72), (0.70, 0.70, 0.34), GRAPHITE, 0.06)
    cyl("beacon", (0, 0, 3.02), 0.09, 0.16, CYAN, verts=24, bevel=0.02)
    # 钻头（贯穿台面向下）
    cone("drill body", (0, 0, 0.15), 0.12, 0.52, 1.10, STEEL, verts=40, bevel=0.01)
    for i, z in enumerate((0.05, 0.28, 0.51)):
        r = 0.46 - i * 0.13
        cone("flight", (0, 0, z), r - 0.10, r, 0.08, GRAPHITE, verts=40)
    cone("drill tip", (0, 0, -0.52), 0.02, 0.14, 0.28, AMBER, verts=24, bevel=0.0)
    # 矿仓 + 传送带 + 矿石
    box("hopper", (1.35, 0.55, 0.60), (0.9, 0.9, 0.9), GRAPHITE, 0.07)
    cone("hopper funnel", (1.35, 0.55, 1.12), 0.30, 0.62, 0.45, STEEL, verts=24)
    for i, (x, y, z, r) in enumerate([(1.15, 0.42, 1.48, 0.20),
                                      (1.45, 0.62, 1.52, 0.17),
                                      (1.32, 0.78, 1.44, 0.15)]):
        ico("ore", (x, y, z), r, AMBER)
    box("chute", (0.90, 0.40, 0.98), (1.55, 0.34, 0.09), DARK, 0.02,
        rot=(0, math.radians(-20), 0))
    # 台面工作灯
    for ang in (20, 140, 260):
        a = math.radians(ang)
        box("deck light", (1.40 * math.cos(a), 1.40 * math.sin(a), 0.52),
            (0.18, 0.18, 0.06), CYAN, 0.01)


def build_solar():
    box("base rail", (0, 0, 0.14), (2.9, 0.62, 0.28), GRAPHITE, 0.05)
    box("base top", (0, 0, 0.30), (2.6, 0.50, 0.06), STEEL, 0.02)
    for i, x in enumerate((-0.95, 0.0, 0.95)):
        rod("post", (x, 0, 0.30), (x, 0, 1.02), 0.07, STEEL)
        rot = (math.radians(26), 0, 0)
        box("panel frame", (x, 0, 1.30), (0.92, 0.10, 1.15), STEEL, 0.03, rot=rot)
        box("panel face", (x, 0.045, 1.30), (0.82, 0.055, 1.02), PANEL, 0.02, rot=rot)
        for k in range(3):
            zz = 1.30 + (k - 1) * 0.30
            box("panel rib", (x, 0.085, zz), (0.80, 0.02, 0.035), DARK, 0.005, rot=rot)
        box("panel edge glow", (x, 0.03, 1.86), (0.84, 0.05, 0.05), CYAN, 0.008, rot=rot)
    box("converter", (1.35, -0.55, 0.52), (0.55, 0.45, 0.50), GRAPHITE, 0.05)
    box("converter light", (1.35, -0.79, 0.60), (0.30, 0.02, 0.10), CYAN, 0.005)
    rod("cable", (1.35, -0.32, 0.36), (0.55, 0.18, 0.30), 0.03, DARK)


def build_fusion():
    cyl("pedestal", (0, 0, 0.35), 1.50, 0.68, GRAPHITE, verts=48, bevel=0.06)
    cyl("pedestal rim", (0, 0, 0.70), 1.56, 0.08, STEEL, verts=48, bevel=0.02)
    cyl("housing lower", (0, 0, 1.11), 0.85, 0.62, GRAPHITE, verts=48, bevel=0.08)
    cyl("housing upper", (0, 0, 1.99), 0.85, 0.62, GRAPHITE, verts=48, bevel=0.08)
    sphere("plasma core", (0, 0, 1.55), 0.66, PLASMA)
    torus("magnet ring low", (0, 0, 1.06), 1.02, 0.055, STEEL)
    torus("magnet ring high", (0, 0, 2.04), 1.02, 0.055, STEEL)
    for k in range(4):
        a = math.radians(45 + k * 90)
        box("fin", (0.88 * math.cos(a), 0.88 * math.sin(a), 1.55),
            (0.08, 0.30, 1.30), STEEL, 0.02, rot=(0, 0, a))
    cyl("cap", (0, 0, 2.40), 0.55, 0.18, STEEL, verts=32, bevel=0.03)
    sphere("cap beacon", (0, 0, 2.56), 0.10, AMBER)
    for sx in (-1.30, 1.30):
        cyl("pylon", (sx, 0, 1.15), 0.16, 2.30, GRAPHITE, verts=24, bevel=0.03)
        sphere("pylon light", (sx, 0, 2.38), 0.09, AMBER)
        rod("pylon brace", (sx, 0.22, 0.75), (0.62 * (1 if sx > 0 else -1), 0.10, 1.05),
            0.04, STEEL)


def build_lab():
    cyl("base", (0, 0, 0.30), 1.50, 0.58, GRAPHITE, verts=8, bevel=0.06)
    cyl("base rim", (0, 0, 0.60), 1.56, 0.06, STEEL, verts=8, bevel=0.02)
    cyl("dome collar", (0, 0, 0.70), 1.02, 0.18, STEEL, verts=48, bevel=0.02)
    sphere("dome", (0, 0, 1.05), 1.02, HULL, scale=(1, 1, 0.74))
    # 望远镜：整体抬高压出穹顶轮廓之外，单筒+配重+镜面
    rod("scope body", (-0.30, -0.20, 1.65), (1.05, -0.50, 2.55), 0.26, STEEL)
    rod("scope back", (-0.62, -0.12, 1.34), (-0.30, -0.20, 1.65), 0.20, GRAPHITE)
    rod("scope lens", (0.95, -0.47, 2.48), (1.13, -0.53, 2.62), 0.32, CYAN)
    rod("scope mount", (0.12, -0.05, 1.62), (0.42, -0.30, 1.98), 0.11, GRAPHITE)
    # 前方三扇窗（清爽）
    for x in (-0.52, 0.0, 0.52):
        box("window", (x, -0.97, 0.92), (0.34, 0.10, 0.16), CYAN, 0.012,
            rot=(math.radians(8), 0, 0))
    # 样本罐（右侧，缩小）
    cyl("sample tank", (1.22, -0.10, 0.78), 0.19, 0.95, STEEL, verts=24, bevel=0.03)
    sphere("tank cap", (1.22, -0.10, 1.28), 0.19, CYAN, scale=(1, 1, 0.6), segments=24)
    rod("lab spire", (0, 0, 1.55), (0, 0, 2.05), 0.04, STEEL)
    sphere("lab beacon", (0, 0, 2.12), 0.08, AMBER)


def build_commerce():
    box("floor 1", (0, 0, 0.55), (2.5, 2.0, 1.1), GRAPHITE, 0.12)
    box("floor 2", (0, 0, 1.75), (2.0, 1.7, 1.3), HULL, 0.12)
    box("floor 3", (0, 0, 2.85), (1.5, 1.3, 0.9), GRAPHITE, 0.10)
    box("strip 1", (0, 0, 1.13), (2.54, 2.04, 0.06), CYAN, 0.01)
    box("strip 2", (0, 0, 2.42), (2.04, 1.74, 0.05), AMBER, 0.01)
    box("strip 3", (0, 0, 3.32), (1.54, 1.34, 0.05), MAGENTA, 0.01)
    # 环形招牌
    rod("sign pole", (0, 0, 3.3), (0, 0, 3.62), 0.06, STEEL)
    torus("sign ring", (0, 0, 4.15), 0.52, 0.075, CYAN, rot=(math.radians(90), 0, 0))
    sphere("sign core", (0, 0, 4.15), 0.15, CYAN)
    # 底层橱窗（面向 -y）
    for k, x in enumerate((-0.8, 0.0, 0.8)):
        box("storefront", (x, -1.02, 0.52), (0.62, 0.06, 0.72), WINDOW_WARM, 0.02)
    # 货柜与吊臂
    box("cargo amber", (-1.55, -0.55, 0.32), (0.8, 0.6, 0.6), AMBER_D, 0.04)
    box("cargo magenta", (1.55, -0.60, 0.32), (0.8, 0.6, 0.6), MAGENTA, 0.04)
    box("cargo steel", (1.45, 0.55, 0.32), (0.8, 0.6, 0.6), STEEL, 0.04)
    rod("crane mast", (1.72, 0.95, 0.6), (1.72, 0.95, 2.6), 0.08, GRAPHITE)
    rod("crane arm", (1.72, 0.95, 2.52), (0.95, 0.35, 2.52), 0.07, GRAPHITE)
    rod("crane cable", (1.0, 0.38, 2.50), (1.0, 0.38, 1.95), 0.02, DARK)
    box("crane hook", (1.0, 0.38, 1.86), (0.30, 0.30, 0.18), STEEL, 0.02)


def build_colony():
    cyl("terrace", (0, 0, 0.22), 1.70, 0.30, GRAPHITE, verts=8, bevel=0.05)
    cyl("terrace rim", (0, 0, 0.40), 1.74, 0.05, STEEL, verts=8, bevel=0.02)
    cyl("dome collar", (0, 0, 0.52), 1.02, 0.22, STEEL, verts=48, bevel=0.03)
    sphere("main dome", (0, 0, 0.95), 1.05, HULL, scale=(1, 1, 0.78))
    for i, (x, y) in enumerate(((-1.28, 0.48), (1.28, 0.48), (0.0, -1.15))):
        sphere("pod dome", (x, y, 0.62), 0.55, HULL, scale=(1, 1, 0.72), segments=32)
        cyl("pod collar", (x, y, 0.40), 0.54, 0.14, STEEL, verts=32, bevel=0.02)
        rod("tube", (x * 0.72, y * 0.72, 0.55), (x, y, 0.62), 0.13, DARK)
    # 穹顶窗灯
    for k in range(10):
        a = math.radians(k * 36)
        box("window", (0.95 * math.cos(a), 0.95 * math.sin(a), 1.02),
            (0.10, 0.16, 0.10), WINDOW_WARM, 0.008, rot=(0, 0, a))
    # 平台灯
    for k in range(6):
        a = math.radians(k * 60 + 30)
        box("terrace light", (1.62 * math.cos(a), 1.62 * math.sin(a), 0.44),
            (0.10, 0.16, 0.06), CYAN, 0.006, rot=(0, 0, a))
    rod("spire", (0, 0, 1.70), (0, 0, 2.60), 0.05, STEEL)
    sphere("beacon", (0, 0, 2.68), 0.11, CYAN)
    torus("beacon ring", (0, 0, 2.44), 0.17, 0.030, CYAN)


# ---------------- 渲染循环 ----------------

BUILDERS = [
    ("miner", build_miner, 5.8, 1.10),
    ("solar", build_solar, 5.6, 0.90),
    ("fusion", build_fusion, 5.8, 1.15),
    ("lab", build_lab, 5.6, 1.00),
    ("commerce", build_commerce, 6.2, 1.60),
    ("colony", build_colony, 6.0, 1.10),
]


def main():
    for name, fn, ortho, tz in BUILDERS:
        reset()
        make_palette()          # reset 会清掉未使用的数据块，所以每轮重建材质
        setup_scene(ortho=ortho, target_z=tz)
        fn()
        scene = bpy.context.scene
        scene.render.filepath = str(OUT / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        print("RENDERED", name, "->", scene.render.filepath)
    print("ALL DONE")


if __name__ == "__main__":
    main()