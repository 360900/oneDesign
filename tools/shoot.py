#!/usr/bin/env python3
"""Render prototype scenes to PNG with headless Chromium.

usage: shoot.py [--scene a,b] [--mode light,dark] [--wall wave] [--accent wallpaper] [--out renders]
"""
import argparse, functools, http.server, subprocess, threading, sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
W, H = 1600, 1000


def serve():
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

    handler = functools.partial(Quiet, directory=str(ROOT))
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def shoot(port, out, scene, mode, wall, accent, scale):
    name = f"{scene}-{mode}.png"
    url = f"http://127.0.0.1:{port}/prototypes/view.html?scene={scene}&mode={mode}&wall={wall}&accent={accent}"
    tmp = Path("/tmp/opencode") / f"chrome-{scene}-{mode}"
    cmd = ["chromium", "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
           f"--user-data-dir={tmp}", f"--window-size={W},{H}", f"--force-device-scale-factor={scale}",
           "--virtual-time-budget=6000", f"--screenshot={out / name}", url]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    subprocess.run(["rm", "-rf", str(tmp)])
    return name


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--scene", default="desktop,settings,login,components,apps,rail,rail-open,edge")
    p.add_argument("--mode", default="light,dark")
    p.add_argument("--wall", default="wave")
    p.add_argument("--accent", default="wallpaper")
    p.add_argument("--scale", default="1")
    p.add_argument("--out", default="renders")
    a = p.parse_args()
    out = (ROOT / a.out)
    out.mkdir(parents=True, exist_ok=True)
    srv = serve()
    port = srv.server_address[1]
    jobs = [(s, m) for s in a.scene.split(",") for m in a.mode.split(",")]
    with ThreadPoolExecutor(8) as ex:
        for name in ex.map(lambda j: shoot(port, out, *j, a.wall, a.accent, a.scale), jobs):
            print(name, flush=True)
    srv.shutdown()


if __name__ == "__main__":
    sys.exit(main())
