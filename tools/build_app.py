#!/usr/bin/env python3
"""Build the pill_app APK with a live progress bar and (optionally) deploy it
to a connected Android device via adb.

Usage:
  python3 tools/build_app.py [--release] [--device <serial>]
"""

import argparse
import os
import re
import subprocess
import sys
import time

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(_ROOT, "pill_app")
ADB = os.environ.get("ADB", "adb")
FLUTTER = os.environ.get("FLUTTER", "flutter")


def fmt_time(secs: float) -> str:
    return f"{int(secs // 60)}m{int(secs % 60):02d}s"


class Progress:
    WIDTH = 24

    def __init__(self, is_tty: bool):
        self.is_tty = is_tty
        self.pct = 0.0
        self.label = "Starting build"
        self.last_line_pct = -10
        self.start = time.monotonic()
        self.deploy_phase = False

    def update(self, pct: float, label: str) -> None:
        self.pct = max(self.pct, min(pct, 100.0))
        self.label = label

    def render(self) -> None:
        elapsed = time.monotonic() - self.start
        if self.pct >= 100:
            pct = 100.0
        elif self.deploy_phase:
            pct = 100.0
        else:
            pct = self.pct
        filled = int(self.WIDTH * pct / 100.0)
        bar = "█" * filled + "░" * (self.WIDTH - filled)
        tail = self.label if not self.deploy_phase else f"Deploying: {self.label}"
        line = f"\r[{bar}] {pct:5.1f}%  {tail}  (elapsed {fmt_time(elapsed)})"
        if self.is_tty:
            sys.stdout.write(line)
            sys.stdout.flush()
        else:
            # Emit throttled, line-oriented progress for non-TTY / captured logs.
            bucket = int(pct // 5) * 5
            if bucket > self.last_line_pct:
                self.last_line_pct = bucket
                sys.stdout.write(f"[{bar}] {pct:5.1f}%  {tail}  (elapsed {fmt_time(elapsed)})\n")
                sys.stdout.flush()

    def done(self) -> None:
        if self.is_tty:
            sys.stdout.write("\r" + " " * 120 + "\r")
        pct = 100.0
        filled = self.WIDTH
        bar = "█" * filled
        elapsed = time.monotonic() - self.start
        sys.stdout.write(
            f"\r[{bar}] {pct:5.1f}%  Build finished in {fmt_time(elapsed)}\n"
        )
        sys.stdout.flush()


def map_line(p: Progress, line: str) -> None:
    # Dependency / pub phases
    if re.search(r"Resolving dependencies|Running .*pub get|changed pubspec", line):
        p.update(3, "Resolving packages / pub get")
    if re.search(r"Kernel Snapshottee|incremental .*kernel|Compiling Dart code|kernel_snapshot", line):
        p.update(8, "Compiling Dart code")
    if re.search(r"Generating .*medicine\.g\.dart|build_runner|hive_generator", line):
        p.update(6, "Codegen (hive)")

    # Gradle running
    m = re.search(r"Running Gradle task '([a-zA-Z:]+)'", line)
    if m:
        p.update(30, f"Gradle: {m.group(1)}")

    # Individual gradle tasks
    m = re.search(r"> Task (\S+)", line)
    if m:
        task = m.group(1)
        known = {
            ":app:processDebugResources": 40,
            ":app:processReleaseResources": 40,
            ":app:compileDebugKotlin": 45,
            ":app:compileReleaseKotlin": 45,
            ":app:compileDebugJavaWithJavac": 50,
            ":app:compileReleaseJavaWithJavac": 50,
            ":app:desugarDebugFileDependencies": 55,
            ":app:desugarReleaseFileDependencies": 55,
            ":app:dexBuilderDebug": 60,
            ":app:dexBuilderRelease": 60,
            ":app:mergeDexDebug": 65,
            ":app:mergeDexRelease": 65,
            ":app:packageDebug": 80,
            ":app:packageRelease": 80,
        }
        base = known.get(task, 35)
        if task not in getattr(map_line, "_seen", set()):
            map_line._seen = getattr(map_line, "_seen", set())
            map_line._seen.add(task)
        p.update(base, f"Gradle: {task}")

    # AOT / native link (release)
    if re.search(r"assembleAot|compile.*aot|libapp\.so", line):
        p.update(70, "Compiling native AOT")

    # Asset bundling / final assembly
    if re.search(r"merge.*assets|kernel_snapshot .*|List of assets", line):
        p.update(72, "Bundling assets")

    if re.search(r"Built build/app/outputs", line):
        p.update(100, "Built APK")
    if "error" in line.lower() and "no issue" not in line.lower():
        p.update(max(p.pct, 99.0), f"Possible error: {line.strip()[:60]}")


def build(device: str | None, release: bool) -> int:
    mode = "release" if release else "debug"
    apk = os.path.join(
        PROJECT, "build", "app", "outputs", "flutter-apk", f"app-{mode}.apk"
    )
    cmd = [FLUTTER, "build", "apk", f"--{mode}", "-v"]
    p = Progress(sys.stdout.isatty())

    p.update(1, "Starting Flutter build")
    proc = subprocess.Popen(
        cmd,
        cwd=PROJECT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert proc.stdout is not None
    last_tick = time.monotonic()
    for raw in proc.stdout:
        line = raw.rstrip("\n")
        if line.strip():
            map_line(p, line)
        now = time.monotonic()
        if now - last_tick >= 1.0:
            last_tick = now
            # Gentle smoothing while a phase is active so the bar keeps moving.
            if not p.label.endswith("…"):
                p.label = f"{p.label} …"
        p.render()
    proc.wait()
    if proc.returncode != 0:
        p.update(99, "Build FAILED (see output above)")
        p.render()
        return proc.returncode

    if not os.path.exists(apk):
        p.update(99, "APK not found after build")
        p.render()
        return 2

    p.update(100, "Built APK")
    p.done()
    print(f"APK: {apk}")

    if device:
        return deploy(p, apk, device)
    return 0


def deploy(p: Progress, apk: str, serial: str) -> int:
    p.deploy_phase = True
    p.label = f"Checking device {serial}"
    p.render()

    rc = subprocess.run([ADB, "devices"]).returncode
    if rc != 0:
        print("adb not found on PATH; set ADB=/path/to/adb")
        return 3

    connected = subprocess.check_output(
        [ADB, "-s", serial, "get-state"], text=True
    ).strip() == "device"
    if not connected:
        print(f"Device {serial} not connected.")
        return 4

    p.label = f"Installing APK to {serial}"
    p.render()
    inst = subprocess.run([ADB, "-s", serial, "install", "-r", apk])
    if inst.returncode != 0:
        p.done()
        print("Install failed.")
        return inst.returncode

    p.label = "Launching app"
    p.render()
    subprocess.run(
        [ADB, "-s", serial, "shell", "am", "start",
         "-n", "com.example.pill_app/.MainActivity"]
    )
    p.done()
    print(f"Launched on device {serial}")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build pill_app APK with progress bar")
    parser.add_argument("--release", action="store_true", help="Build a release APK")
    parser.add_argument("--device", help="adb device serial to install & launch on")
    args = parser.parse_args()
    sys.exit(build(args.device, args.release))