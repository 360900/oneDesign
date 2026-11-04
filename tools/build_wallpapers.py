#!/usr/bin/env python3
"""Render the One wallpapers (light/dark) as procedural 3D scenes in Blender Cycles.

usage: build_wallpapers.py [--only dune,lagoon] [--mode light,dark] [--scale 1] [--samples 512] [--out DIR]
       build_wallpapers.py --blend DIR [--only wave] [--mode light,dark]   save scenes to tweak, 7680x4800
       build_wallpapers.py --convert PNG NAME-MODE   turn a finished render into its webp as is

Run with plain python3; it re-runs itself inside `blender -b` per wallpaper.
Needs Blender 4.2+; uses OptiX/CUDA when available, CPU otherwise (slow).
"""
import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "prototypes" / "assets" / "wallpapers"
W, H = 5120, 3200

# id: accent hue (drives dynamic accent), secondary, tertiary
SETS = {
    "dune": (55, 25, 85),
    "lagoon": (220, 185, 265),
    "orchid": (320, 285, 15),
    "moss": (150, 115, 195),
    "wave": (200, 170, 255),
}


def oklab_to_linear(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_**3, m_**3, s_**3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def oklch(L, C, h):
    """OKLCH to linear sRGB, reducing chroma until in gamut."""
    for _ in range(40):
        r, g, b = oklab_to_linear(L, C * math.cos(math.radians(h)), C * math.sin(math.radians(h)))
        if min(r, g, b) >= -1e-4 and max(r, g, b) <= 1 + 1e-4:
            break
        C *= 0.94
    return tuple(min(max(v, 0.0), 1.0) for v in (r, g, b))


# ---------------------------------------------------------------- outside Blender

def to_webp(png, dst, grain=True):
    import numpy as np
    from PIL import Image
    if not grain:
        Image.open(png).convert("RGB").save(dst, quality=95, method=6, use_sharp_yuv=True)
        return
    im = np.asarray(Image.open(png).convert("RGB")).astype(np.float32)
    # Fine grain; lossy webp smooths away plain dither and gradients band again.
    im += np.random.default_rng(0).normal(0, 1.5, im.shape[:2] + (1,)).astype(np.float32)
    Image.fromarray(np.clip(np.rint(im), 0, 255).astype(np.uint8)).save(
        dst, quality=95, method=6, use_sharp_yuv=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", default=",".join(SETS))
    p.add_argument("--mode", default="light,dark")
    p.add_argument("--scale", type=float, default=1.0, help="resolution scale for previews")
    p.add_argument("--samples", type=int, default=512)
    p.add_argument("--out", type=Path, default=OUT)
    p.add_argument("--blender", default=os.environ.get("BLENDER", "blender"))
    p.add_argument("--blend", type=Path, help="save .blend files here instead of rendering")
    p.add_argument("--convert", nargs=2, metavar=("PNG", "NAME-MODE"), help="make a webp from a finished render")
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    if a.convert:
        to_webp(a.convert[0], a.out / f"{a.convert[1]}.webp", grain=False)
        return
    if a.blend:
        a.blend.mkdir(parents=True, exist_ok=True)
    for name in SETS:
        if name not in a.only.split(","):
            continue
        for mode in a.mode.split(","):
            png = a.blend / f"{name}-{mode}.blend" if a.blend else a.out / f".{name}-{mode}.png"
            cmd = [a.blender, "-b", "--factory-startup", "--python", __file__, "--",
                   name, mode, str(png), str(a.scale), str(a.samples)]
            r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            if r.returncode or not png.exists():
                sys.exit(r.stdout[-4000:])
            if a.blend:
                print(png, flush=True)
                continue
            to_webp(png, a.out / f"{name}-{mode}.webp")
            png.unlink()
            print(name, mode, "ok", flush=True)
    if a.out == OUT and not a.blend:
        manifest = [{"id": k, "hue": v[0]} for k, v in SETS.items()]
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))


# ---------------------------------------------------------------- inside Blender

def blender_main(name, mode, out, scale, samples):
    import bpy
    import numpy as np
    from mathutils import Vector

    dark = mode == "dark"
    hues = SETS[name]
    rng = np.random.default_rng(sum(map(ord, name)))
    scn = bpy.context.scene
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)

    # -- render setup
    scn.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA", "HIP", "METAL", "ONEAPI"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
        except TypeError:
            continue
        devs = [d for d in prefs.devices if d.type == kind]
        if devs:
            for d in prefs.devices:
                d.use = d.type == kind
            scn.cycles.device = "GPU"
            break
    c = scn.cycles
    c.samples = samples
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.005
    c.use_denoising = True
    c.denoiser = "OPENIMAGEDENOISE"
    c.max_bounces = 24
    c.transmission_bounces = 24
    c.glossy_bounces = 12
    c.transparent_max_bounces = 16
    c.diffuse_bounces = 4
    c.caustics_reflective = True
    c.caustics_refractive = True
    c.blur_glossy = 0.5
    c.sample_clamp_indirect = 20
    scn.render.resolution_x = round(W * scale)
    scn.render.resolution_y = round(H * scale)
    scn.render.resolution_percentage = 100
    scn.render.film_transparent = False
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_depth = "8"
    scn.render.dither_intensity = 1.0
    scn.view_settings.view_transform = "Khronos PBR Neutral"
    scn.render.filepath = out

    # -- helpers
    def col(L, C, h):
        return (*oklch(L, C, h), 1.0)

    def node_mat(mname):
        m = bpy.data.materials.new(mname)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        return m, nt, o

    def principled(mname, **kw):
        m, nt, o = node_mat(mname)
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        for k, v in kw.items():
            b.inputs[k].default_value = v
        nt.links.new(b.outputs[0], o.inputs[0])
        return m

    def glass(mname, tint=(1, 1, 1, 1), rough=0.0, ior=1.45, spread=0.04, film=0.0):
        """Glass with cheap dispersion: three tinted glass lobes at different IORs."""
        m, nt, o = node_mat(mname)
        add = None
        for i, (rgb, di) in enumerate((((1, 0, 0), -spread), ((0, 1, 0), 0.0), ((0, 0, 1), spread))):
            g = nt.nodes.new("ShaderNodeBsdfGlass")
            g.inputs["Color"].default_value = (rgb[0] * tint[0], rgb[1] * tint[1], rgb[2] * tint[2], 1)
            g.inputs["Roughness"].default_value = rough
            g.inputs["IOR"].default_value = ior + di
            if film:
                g.inputs["Thin Film Thickness"].default_value = film
            if add is None:
                add = g
            else:
                s = nt.nodes.new("ShaderNodeAddShader")
                nt.links.new(add.outputs[0], s.inputs[0])
                nt.links.new(g.outputs[0], s.inputs[1])
                add = s
        nt.links.new(add.outputs[0], o.inputs[0])
        return m

    def resample(pts, n):
        """Catmull-Rom through pts, resampled to n points evenly by arc length."""
        P = np.asarray(pts, float)
        P = np.vstack([2 * P[0] - P[1], P, 2 * P[-1] - P[-2]])
        dense = []
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            t = np.linspace(0, 1, 64, endpoint=False)[:, None]
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t**2
                                + (-p0 + 3 * p1 - 3 * p2 + p3) * t**3))
        dense.append(P[-2][None])
        D = np.vstack(dense)
        s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(D, axis=0), axis=1))])
        u = np.linspace(0, s[-1], n)
        return np.stack([np.interp(u, s, D[:, k]) for k in range(3)], 1)

    def frames(C, up=(0, 0, 1)):
        T = np.gradient(C, axis=0)
        T /= np.linalg.norm(T, axis=1, keepdims=True)
        N = np.zeros_like(C)
        n = np.cross(T[0], up)
        if np.linalg.norm(n) < 1e-6:
            n = np.cross(T[0], (1, 0, 0))
        N[0] = n / np.linalg.norm(n)
        for i in range(1, len(C)):
            v = N[i - 1] - np.dot(N[i - 1], T[i]) * T[i]
            N[i] = v / np.linalg.norm(v)
        B = np.cross(T, N)
        return T, N, B

    def mesh_obj(oname, verts, faces, mat, smooth=True):
        me = bpy.data.meshes.new(oname)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        if smooth:
            me.shade_smooth()
        me.materials.append(mat)
        ob = bpy.data.objects.new(oname, me)
        scn.collection.objects.link(ob)
        return ob

    def ribbon(oname, pts, width, thick, mat, twist=0.0, n=900, nv=72, power=6.0, up=(0, 0, 1)):
        """Thick sculpted ribbon: superellipse cross-section swept along a spline.
        width/thick/twist may be callables of u in [0, 1]."""
        C = resample(pts, n)
        _, N, B = frames(C, up)
        u = np.linspace(0, 1, n)
        f = lambda v: v(u) if callable(v) else np.full(n, float(v))
        w, t, tw = f(width), f(thick), f(twist)
        phi = np.linspace(0, math.tau, nv, endpoint=False)
        cx = np.sign(np.cos(phi)) * np.abs(np.cos(phi)) ** (2 / power)
        cy = np.sign(np.sin(phi)) * np.abs(np.sin(phi)) ** (2 / power)
        ct, st = np.cos(tw)[:, None, None], np.sin(tw)[:, None, None]
        A = ct * N[:, None] + st * B[:, None]
        Bb = -st * N[:, None] + ct * B[:, None]
        V = (C[:, None] + (w[:, None, None] / 2) * cx[None, :, None] * A
             + (t[:, None, None] / 2) * cy[None, :, None] * Bb).reshape(-1, 3)
        faces = []
        for i in range(n - 1):
            for j in range(nv):
                a, b2 = i * nv + j, i * nv + (j + 1) % nv
                faces.append((a, b2, b2 + nv, a + nv))
        faces.append(tuple(range(nv))[::-1])
        faces.append(tuple(range((n - 1) * nv, n * nv)))
        return mesh_obj(oname, V, faces, mat)

    def area(lname, loc, target, size, energy, color, shape="DISK", spread=180, size_y=None):
        ld = bpy.data.lights.new(lname, "AREA")
        ld.shape = shape if size_y is None else "RECTANGLE"
        ld.size = size
        if size_y is not None:
            ld.size_y = size_y
        ld.energy = energy
        ld.color = color[:3]
        ld.spread = math.radians(spread)
        ob = bpy.data.objects.new(lname, ld)
        ob.location = loc
        d = Vector(target) - Vector(loc)
        ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        ob.visible_camera = False
        ob.visible_transmission = False
        scn.collection.objects.link(ob)
        return ob

    def camera(loc, target, lens=50, dof=None, fstop=4.0):
        cd = bpy.data.cameras.new("cam")
        cd.lens = lens
        cd.sensor_fit = "HORIZONTAL"
        cd.sensor_width = 36
        ob = bpy.data.objects.new("cam", cd)
        ob.location = loc
        ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scn.collection.objects.link(ob)
        scn.camera = ob
        if dof:
            cd.dof.use_dof = True
            cd.dof.focus_distance = dof
            cd.dof.aperture_fstop = fstop
        return ob

    def backdrop_image(spec, res=(1024, 640)):
        """Mesh-gradient backdrop in OKLab: base linear gradient plus soft blobs.
        spec = dict(a=(L,C,h), b=(L,C,h), angle=deg, blobs=[(x, y, r, (L,C,h), k)])."""
        w, h = res
        y, x = np.mgrid[0:h, 0:w].astype(np.float64)
        x, y = x / w, 1 - y / h
        ang = math.radians(spec.get("angle", 30))
        t = np.clip((x - 0.5) * math.cos(ang) * 1.6 + (y - 0.5) * math.sin(ang) + 0.5, 0, 1)
        t = t * t * (3 - 2 * t)

        def lab(L, C, hh):
            return np.array([L, C * math.cos(math.radians(hh)), C * math.sin(math.radians(hh))])
        A, Bc = lab(*spec["a"]), lab(*spec["b"])
        img = A[None, None] * (1 - t[..., None]) + Bc[None, None] * t[..., None]
        for bx, by, br, bc, k in spec.get("blobs", []):
            d2 = ((x - bx) * 1.6) ** 2 + (y - by) ** 2
            m = np.exp(-d2 / (br * br)) * k
            img = img * (1 - m[..., None]) + lab(*bc)[None, None] * m[..., None]
        L, a, b = img[..., 0], img[..., 1], img[..., 2]
        rgb = np.stack(oklab_to_linear(L, a, b), -1).clip(0, 1)
        pix = np.concatenate([rgb, np.ones((h, w, 1))], -1)[::-1].astype(np.float32)
        im = bpy.data.images.new("backdrop", w, h, float_buffer=True)
        im.colorspace_settings.name = "Linear Rec.709"
        im.pixels.foreach_set(pix.ravel())
        return im

    def world(img, top, bottom, strength, bg_strength=1.0):
        """Camera, glossy and refraction rays see the screen-space backdrop; diffuse and glossy rays see a
        soft studio dome (top to bottom gradient) so forms get shading."""
        wd = bpy.data.worlds.new("w")
        scn.world = wd
        wd.use_nodes = True
        nt = wd.node_tree
        nt.nodes.clear()
        L = nt.links.new
        o = nt.nodes.new("ShaderNodeOutputWorld")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.extension = "EXTEND"
        L(tc.outputs["Window"], tex.inputs[0])
        bg_cam = nt.nodes.new("ShaderNodeBackground")
        bg_cam.inputs[1].default_value = bg_strength
        L(tex.outputs[0], bg_cam.inputs[0])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        L(tc.outputs["Generated"], sep.inputs[0])
        rmp = nt.nodes.new("ShaderNodeMapRange")
        rmp.inputs[1].default_value = -0.3
        rmp.inputs[2].default_value = 0.9
        L(sep.outputs[2], rmp.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs[6].default_value = bottom
        mix.inputs[7].default_value = top
        L(rmp.outputs[0], mix.inputs[0])
        bg_fill = nt.nodes.new("ShaderNodeBackground")
        bg_fill.inputs[1].default_value = strength
        L(mix.outputs[2], bg_fill.inputs[0])
        lp = nt.nodes.new("ShaderNodeLightPath")
        mx = nt.nodes.new("ShaderNodeMixShader")
        L(lp.outputs["Is Diffuse Ray"], mx.inputs[0])
        L(bg_cam.outputs[0], mx.inputs[1])
        L(bg_fill.outputs[0], mx.inputs[2])
        L(mx.outputs[0], o.inputs[0])

    ctx = dict(np=np, rng=rng, dark=dark, hues=hues, col=col, principled=principled, glass=glass,
               ribbon=ribbon, area=area, camera=camera, backdrop_image=backdrop_image, world=world,
               mesh_obj=mesh_obj, node_mat=node_mat, resample=resample, scn=scn, bpy=bpy)
    SCENES[name](**ctx)
    if out.endswith(".blend"):
        scn.render.resolution_x, scn.render.resolution_y = 7680, 4800
        scn.render.filepath = f"//{name}-{mode}.png"
        for im in bpy.data.images:
            if im.name == "backdrop":
                im.pack()
        bpy.ops.wm.save_as_mainfile(filepath=out)
        return
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- scenes

def scene_lagoon(np, rng, dark, hues, col, principled, glass, ribbon, area, camera, backdrop_image,
                 world, **_):
    h1, h2, h3 = hues
    if dark:
        bg = dict(a=(0.20, 0.10, h3), b=(0.12, 0.06, h1 + 10), angle=-25,
                  blobs=[(0.55, 0.55, 0.30, (0.45, 0.17, h1), 0.9), (0.15, 0.85, 0.25, (0.38, 0.13, h2), 0.8),
                         (0.9, 0.15, 0.25, (0.30, 0.15, h3 + 15), 0.8)])
    else:
        bg = dict(a=(0.86, 0.09, h2), b=(0.62, 0.17, h1 + 10), angle=-25,
                  blobs=[(0.12, 0.88, 0.32, (0.95, 0.05, h2 - 10), 0.9), (0.9, 0.1, 0.35, (0.55, 0.17, h3), 0.8),
                         (0.62, 0.72, 0.22, (0.82, 0.10, h1 - 20), 0.6)])
    world(backdrop_image(bg), col(0.98, 0.03, h2), col(0.25, 0.08, h1), 1.0 if not dark else 0.3)
    camera((0, -10, 0), (0, 0, 0), lens=55, dof=10, fstop=4)
    g = glass("g", ior=1.5, spread=0.06)
    ribbon("glass1", [(-5, 0.6, -3.2), (-2.2, -0.2, -1.0), (0, 0, -0.1), (2.2, -0.3, 0.9), (5, 0.6, 3.0)],
           lambda u: 0.75 + 0.35 * np.sin(u * np.pi), 0.28, g,
           twist=lambda u: 1.6 * np.sin(u * np.pi * 1.2) + 0.4)
    ribbon("glass2", [(-5, 1.2, -1.6), (-2.5, 0.8, -0.8), (0.2, 0.9, 0.7), (2.6, 0.7, 1.4), (5, 1.4, 3.6)],
           0.5, 0.22, g, twist=lambda u: -1.3 * np.cos(u * np.pi * 1.4))
    ribbon("satin1", [(-6, 3.5, 1.2), (-3, 3.0, 2.2), (0.5, 3.2, 1.0), (3.5, 3.0, -1.2), (6, 3.6, -2.4)],
           1.6, 0.2, principled("s1", **{"Base Color": col(0.70 if not dark else 0.52, 0.17, h2),
                                          "Roughness": 0.35, "Coat Weight": 0.8}),
           twist=lambda u: 0.9 * np.sin(u * np.pi * 2))
    ribbon("satin2", [(-6, 4.2, -2.8), (-2.5, 4.0, -1.5), (1.0, 4.4, -2.0), (6, 4.0, -0.2)],
           2.0, 0.2, principled("s2", **{"Base Color": col(0.60 if not dark else 0.40, 0.18, h3),
                                          "Roughness": 0.35, "Coat Weight": 0.8}),
           twist=lambda u: 0.7 * np.cos(u * np.pi * 1.5))
    if dark:
        area("strip", (-1, -3, 6), (0, 0, 0), 12, 700, col(0.9, 0.1, h2), size_y=2.5).visible_glossy = False
        area("rim", (4, 6, 4), (0, 0, 0), 3, 2600, col(0.75, 0.18, h2))
        area("rim2", (-6, 5, -3), (0, 0, 0), 3, 2000, col(0.65, 0.2, h3))
        area("fill", (6, -8, -4), (0, 0, 0), 6, 150, col(0.9, 0.06, h3))
    else:
        area("strip", (-1, -3, 6), (0, 0, 0), 12, 1100, col(0.99, 0.02, h2), size_y=2.5).visible_glossy = False
        area("key", (-5, -6, 7), (0, 0, 0), 5, 900, col(0.98, 0.02, h2))
        area("rim", (5, 7, 5), (0, 2, 0), 4, 1500, col(0.9, 0.08, h2))
        area("fill", (6, -8, -4), (0, 0, 0), 6, 400, col(0.9, 0.06, h3))


def scene_dune(np, rng, dark, hues, col, principled, glass, ribbon, area, camera, backdrop_image,
               world, **_):
    h1, h2, h3 = hues
    if dark:
        bg = dict(a=(0.16, 0.05, h2), b=(0.28, 0.09, h1), angle=80,
                  blobs=[(0.75, 0.25, 0.35, (0.45, 0.13, h1), 0.8), (0.2, 0.2, 0.3, (0.30, 0.10, h2), 0.7)])
    else:
        bg = dict(a=(0.95, 0.04, h3), b=(0.84, 0.10, h1), angle=80,
                  blobs=[(0.78, 0.22, 0.35, (0.97, 0.05, h3), 0.9), (0.15, 0.75, 0.3, (0.80, 0.12, h2), 0.6)])
    world(backdrop_image(bg), col(0.97, 0.03, h3), col(0.35, 0.08, h2), 0.9 if not dark else 0.25)
    camera((0, -10, 3.2), (0, 0, -0.6), lens=50, dof=10, fstop=3.5)
    layers = [(4.5, -0.1, h3, 0.84), (3.0, -0.5, h1, 0.76), (1.5, -0.9, h2, 0.68),
              (0.0, -1.3, h1 + 12, 0.74), (-1.5, -1.7, h2 + 8, 0.64), (-3.0, -2.1, h1 - 8, 0.70)]
    for i, (y, z, h, L) in enumerate(layers):
        ph = rng.uniform(0, 2 * np.pi)
        xs = np.linspace(-8, 8, 11)
        pts = [(x, y + 0.6 * np.sin(x * 0.35 + ph), z + 0.45 * np.sin(x * 0.5 + ph * 1.7)) for x in xs]
        Ld = L - (0.40 if dark else 0.0)
        m = principled(f"d{i}", **{"Base Color": col(Ld, 0.15, h), "Roughness": 0.45,
                                   "Sheen Weight": 0.7, "Sheen Tint": col(0.95, 0.05, h3),
                                   "Coat Weight": 0.35, "Coat Roughness": 0.12})
        ribbon(f"dune{i}", pts, 3.0, 0.1, m, twist=lambda u, p=ph: 0.45 * np.sin(u * np.pi * 2.4 + p) + 0.25,
               power=4)
    if dark:
        area("sun", (-10, 3, 0.6), (0, 0, -1.0), 2.0, 5000, col(0.85, 0.14, h1 + 10))
        area("sky", (2, -6, 8), (0, 0, 0), 8, 60, col(0.6, 0.08, h2))
        area("rim", (7, 6, 3), (0, 0, 0), 3, 1800, col(0.7, 0.16, h2))
    else:
        area("sun", (-10, 3, 1.2), (0, 0, -1.0), 2.5, 14000, col(0.96, 0.07, h3))
        area("sky", (2, -6, 8), (0, 0, 0), 8, 700, col(0.96, 0.03, h3))
        area("fill", (6, -8, -3), (0, 0, 0), 6, 300, col(0.9, 0.06, h2))


def scene_orchid(np, rng, dark, hues, col, principled, glass, ribbon, area, camera, backdrop_image,
                 world, **_):
    h1, h2, h3 = hues
    if dark:
        bg = dict(a=(0.14, 0.08, h2), b=(0.20, 0.10, h1), angle=30,
                  blobs=[(0.62, 0.48, 0.32, (0.42, 0.18, h1), 0.9), (0.1, 0.1, 0.35, (0.24, 0.09, h2 - 15), 0.6)])
    else:
        bg = dict(a=(0.92, 0.05, h2), b=(0.80, 0.11, h1), angle=30,
                  blobs=[(0.62, 0.48, 0.3, (0.97, 0.03, h1), 0.9), (0.1, 0.15, 0.35, (0.82, 0.09, h3), 0.45),
                         (0.92, 0.9, 0.3, (0.70, 0.14, h2), 0.6)])
    world(backdrop_image(bg), col(0.97, 0.03, h1), col(0.3, 0.1, h2), 0.9 if not dark else 0.25)
    camera((-3.0, -10.5, 2.4), (0.3, 0, -0.3), lens=44, dof=10.8, fstop=3.2)
    cx, cz = 1.6, -0.7
    rings = [(8, 3.3, 1.8, 0.0, h2, 0.62), (7, 2.4, 1.4, 0.45, h1, 0.68), (5, 1.6, 1.0, 0.2, h3, 0.78)]
    for r_i, (n, length, wmax, rot, hh, L) in enumerate(rings):
        for i in range(n):
            a = 2 * np.pi * i / n + rot + rng.normal(0, 0.06)
            sweep = 0.35 + rng.normal(0, 0.05)
            ln = length * rng.uniform(0.9, 1.08)
            rr = np.linspace(0.05, ln, 8)
            ang = a + sweep * (rr / ln) ** 1.5
            lift = -(0.2 + 0.45 * r_i) * rr + 0.04 * rr ** 2 - 0.15 * r_i
            pts = [(cx + r * np.cos(t), d, cz + r * np.sin(t)) for r, t, d in zip(rr, ang, lift)]
            h = hh + rng.normal(0, 7) + 10 * np.cos(a)
            m = principled(f"p{r_i}_{i}", **{
                "Base Color": col(L - (0.16 if dark else 0.0), 0.18, h), "Roughness": 0.22,
                "Transmission Weight": 0.55, "IOR": 1.45, "Coat Weight": 0.8, "Coat Roughness": 0.04,
                "Thin Film Thickness": 420.0, "Thin Film IOR": 1.35,
                "Subsurface Weight": 0.25, "Subsurface Radius": (0.35, 0.2, 0.35)})
            ribbon(f"petal{r_i}_{i}", pts,
                   lambda u, w=wmax: 0.05 + w * np.sin(np.pi * np.clip(u, 0, 1) ** 0.7) ** 0.9 * (1 - 0.25 * u),
                   0.05, m, twist=lambda u, k=i: 0.25 * np.sin(u * np.pi + k), power=3, n=400,
                   up=(0, -1, 0))
    if dark:
        area("key", (-4, -5, 5), (cx, 0, cz), 4, 1400, col(0.85, 0.08, h1))
        area("rim", (5, 6, 4), (cx, 0, cz), 3, 3000, col(0.7, 0.2, h3))
        area("rim2", (-5, 6, -4), (cx, 0, cz), 3, 2500, col(0.6, 0.2, h2))
    else:
        area("key", (-4, -6, 6), (cx, 0, cz), 6, 1600, col(0.98, 0.02, h1))
        area("rim", (5, 6, 4), (cx, 0, cz), 4, 2200, col(0.9, 0.1, h3))
        area("fill", (6, -8, -4), (0, 0, 0), 6, 400, col(0.9, 0.06, h2))


def scene_moss(np, rng, dark, hues, col, principled, glass, ribbon, area, camera, backdrop_image,
               world, **_):
    h1, h2, h3 = hues
    if dark:
        bg = dict(a=(0.13, 0.05, h1), b=(0.20, 0.08, h3), angle=-15,
                  blobs=[(0.5, 0.5, 0.35, (0.38, 0.12, h1), 0.8), (0.9, 0.85, 0.25, (0.32, 0.10, h3), 0.7)])
    else:
        bg = dict(a=(0.95, 0.04, h2), b=(0.80, 0.10, h3), angle=-15,
                  blobs=[(0.3, 0.7, 0.35, (0.97, 0.04, h2), 0.9), (0.85, 0.2, 0.3, (0.72, 0.12, h1), 0.6)])
    world(backdrop_image(bg), col(0.97, 0.03, h2), col(0.3, 0.08, h1), 0.9 if not dark else 0.25)
    camera((0, -10, 0), (0, 0, 0), lens=55, dof=10, fstop=3.0)
    n = 26
    xs = np.linspace(-7, 7, 11)
    for i in range(n):
        f = i / (n - 1) - 0.5
        off = rng.normal(0, 0.12)
        spread = 1.0 + 0.7 * np.cos(xs * 0.45)
        pts = [(x, 0.8 * f * spread[k] * 2 + 0.3 * np.sin(x * 0.6 + i),
                -0.6 + 1.3 * np.sin(x * 0.42 + 0.6) + f * 2.6 * spread[k] + off) for k, x in enumerate(xs)]
        hh = h2 - 10 + (h3 - h2 + 25) * (i / n) + rng.normal(0, 6)
        if i % 5 == 2:
            m = glass(f"mg{i}", tint=col(0.95, 0.05, hh), ior=1.5, spread=0.05)
        else:
            L = 0.55 + 0.25 * rng.random() - (0.2 if dark else 0.0)
            m = principled(f"m{i}", **{"Base Color": col(L, 0.17, hh), "Roughness": 0.25,
                                       "Coat Weight": 1.0, "Coat Roughness": 0.03})
        ribbon(f"strand{i}", pts, 0.16 + 0.05 * rng.random(), 0.05, m,
               twist=lambda u, k=i: 0.5 * np.sin(u * np.pi * 2 + k * 0.4), power=3, n=600, nv=32)
    if dark:
        area("strip", (-1, -4, 6), (0, 0, 0), 12, 600, col(0.9, 0.08, h2), size_y=1.5)
        area("rim", (4, 6, 4), (0, 0, 0), 3, 2600, col(0.75, 0.18, h1))
        area("rim2", (-6, 5, -3), (0, 0, 0), 3, 2000, col(0.65, 0.18, h3))
    else:
        area("strip", (-1, -4, 6), (0, 0, 0), 12, 1100, col(0.99, 0.02, h2), size_y=1.5)
        area("key", (-5, -6, 7), (0, 0, 0), 5, 800, col(0.98, 0.02, h2))
        area("rim", (5, 7, 5), (0, 2, 0), 4, 1500, col(0.9, 0.08, h1))


def scene_wave(np, rng, dark, hues, col, node_mat, mesh_obj, area, camera, backdrop_image, world, **_):
    h1, h2, h3 = hues
    if dark:
        bg = dict(a=(0.17, 0.025, h3), b=(0.11, 0.02, h1), angle=35,
                  blobs=[(0.42, 0.62, 0.34, (0.25, 0.035, h1), 0.8)])
    else:
        bg = dict(a=(0.93, 0.025, h2), b=(0.84, 0.04, h1), angle=35,
                  blobs=[(0.42, 0.62, 0.34, (0.97, 0.012, h2), 0.9), (0.95, 0.1, 0.3, (0.80, 0.05, h3), 0.5)])
    world(backdrop_image(bg), col(0.98, 0.02, h2), col(0.3, 0.05, h1), 0.9 if not dark else 0.22)
    camera((0, -14, 0.4), (0, 0, 0), lens=50, dof=13.5, fstop=5.6)

    def satin(mname, shift):
        """Base color runs along the sheet, teal on the left to violet blue on the right."""
        m, nt, o = node_mat(mname)
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        for k, v in {"Roughness": 0.34, "Coat Weight": 0.45, "Coat Roughness": 0.16, "Sheen Weight": 0.5}.items():
            b.inputs[k].default_value = v
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        rng_x = nt.nodes.new("ShaderNodeMapRange")
        rng_x.inputs[1].default_value = -7.5 + shift
        rng_x.inputs[2].default_value = 7.5 + shift
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        dim = 0.14 if dark else 0.0
        ramp.color_ramp.elements[0].position = 0.08
        ramp.color_ramp.elements[0].color = col(0.72 - dim, 0.12, h2)
        ramp.color_ramp.elements[1].position = 0.92
        ramp.color_ramp.elements[1].color = col(0.50 - dim, 0.17, h3)
        mid = ramp.color_ramp.elements.new(0.52)
        mid.color = col(0.62 - dim, 0.14, h1)
        L = nt.links.new
        L(geo.outputs["Position"], sep.inputs[0])
        L(sep.outputs[0], rng_x.inputs[0])
        L(rng_x.outputs[0], ramp.inputs[0])
        L(ramp.outputs[0], b.inputs["Base Color"])
        L(b.outputs[0], o.inputs[0])
        return m

    # Layered sheets: each spans a top and bottom edge that swell apart and pinch together, a smooth grid
    # rather than a swept ribbon, so wide folds can't kink. A crest on the left falls to the lower right.
    nu, nv = 700, 90
    x = np.linspace(-9.5, 9.5, nu)[:, None]
    v = np.linspace(-1, 1, nv)[None, :]
    for i in range(6):
        center = 0.55 - 0.25 * x + 0.95 * np.sin(0.52 * x + 1.75 + 0.2 * i) - 0.34 * (i - 2.5)
        half = 0.38 + 0.72 * (0.5 + 0.5 * np.sin(0.62 * x + 0.5 + 0.55 * i))
        y = (0.42 * i - 1.0 + 0.3 * np.sin(0.45 * x + i * 0.8)
             + v * (0.55 * np.sin(0.8 * x + 0.5 * i) + 0.25) + 0.22 * v * v)
        z = center + half * (v + 0.12 * np.sin(1.5 * v + x))
        V = np.stack([np.broadcast_to(x, y.shape), y, z], -1).reshape(-1, 3)
        faces = [(a * nv + b, a * nv + b + 1, (a + 1) * nv + b + 1, (a + 1) * nv + b)
                 for a in range(nu - 1) for b in range(nv - 1)]
        ob = mesh_obj(f"sheet{i}", V, faces, satin(f"w{i}", 0.5 * i))
        ob.modifiers.new("thickness", "SOLIDIFY").thickness = 0.025
    if dark:
        area("key", (-5, -7, 7), (0, 0, 0), 7, 620, col(0.92, 0.04, h2))
        area("rim", (6, 6, 5), (0, 0, 0), 4, 2600, col(0.75, 0.14, h1))
        area("rim2", (-7, 5, -4), (0, 0, 0), 4, 1500, col(0.7, 0.14, h2))
    else:
        area("key", (-5, -7, 7), (0, 0, 0), 7, 1500, col(0.99, 0.015, h2))
        area("rim", (6, 6, 5), (0, 0, 0), 4, 1800, col(0.92, 0.06, h1))
        area("fill", (6, -8, -4), (0, 0, 0), 7, 420, col(0.92, 0.04, h3))


SCENES = {"dune": scene_dune, "lagoon": scene_lagoon, "orchid": scene_orchid, "moss": scene_moss, "wave": scene_wave}

if __name__ == "__main__":
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
        blender_main(args[0], args[1], args[2], float(args[3]), int(args[4]))
    else:
        main()
