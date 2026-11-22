"""Capture production Godot player images; never report desktop FPS as Android FPS.

Uses an existing DISPLAY, or a private authenticated software Xorg server.
The X server and Godot run in the same process/network environment. No system
settings, existing display servers, user save games or credentials are changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import struct
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)
XORG_CONFIG = '''Section "ServerFlags"
 Option "AutoAddDevices" "false"
 Option "AutoEnableDevices" "false"
EndSection
Section "Device"
 Identifier "ReviewDevice"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "ReviewMonitor"
 HorizSync 30.0-80.0
 VertRefresh 50.0-75.0
 Modeline "1920x1080" 148.5 1920 2008 2052 2200 1080 1084 1089 1125
EndSection
Section "Screen"
 Identifier "ReviewScreen"
 Device "ReviewDevice"
 Monitor "ReviewMonitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "1920x1080"
  Virtual 1920 1080
 EndSubSection
EndSection
'''


def start_display(directory: Path, env: dict[str, str]):
    binary = Path("/usr/lib/xorg/Xorg")
    driver = Path("/usr/lib/xorg/modules/drivers/dummy_drv.so")
    if not binary.is_file() or not driver.is_file():
        raise RuntimeError("A graphical DISPLAY or Xorg with its dummy driver is required.")
    display = None
    for candidate in range(91, 121):
        with socket.socket() as probe:
            try:
                probe.bind(("127.0.0.1", 6000 + candidate))
                display = candidate
                break
            except OSError:
                continue
    if display is None:
        raise RuntimeError("No local display port is available.")
    (directory / "xorg.conf").write_text(XORG_CONFIG, encoding="utf-8")
    auth = directory / "Xauthority"
    fields = [b"", str(display).encode(), b"MIT-MAGIC-COOKIE-1", secrets.token_bytes(16)]
    auth.write_bytes(struct.pack(">H", 65535) + b"".join(struct.pack(">H", len(x)) + x for x in fields))
    auth.chmod(0o600)
    log = (directory / "xorg-output.log").open("w", encoding="utf-8")
    server = subprocess.Popen(
        [str(binary), f":{display}", "-config", "xorg.conf", "-nolock", "-noreset",
         "-nolisten", "local", "-nolisten", "unix", "-listen", "tcp", "-nolisten", "inet6",
         "-auth", str(auth), "-logfile", str(directory / "xorg.log"), "-novtswitch", "-pn"],
        cwd=directory, stdout=log, stderr=subprocess.STDOUT,
    )
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if server.poll() is not None:
            log.close()
            raise RuntimeError("Xorg could not start; " + (directory / "xorg-output.log").read_text()[-1500:])
        try:
            with socket.create_connection(("127.0.0.1", 6000 + display), timeout=0.2):
                env.update({"DISPLAY": f"127.0.0.1:{display}", "XAUTHORITY": str(auth),
                            "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2"})
                return server, log
        except OSError:
            time.sleep(0.1)
    server.terminate()
    server.wait(timeout=5)
    log.close()
    raise RuntimeError("The private display did not become ready.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--motion", action="store_true")
    parser.add_argument("--software-x11", action="store_true")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if not engine:
        raise SystemExit("Godot executable is missing.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-hero-review-") as temporary:
        directory = Path(temporary)
        env = os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            env[f"XDG_{kind}_HOME"] = str(location)
        server = log = None
        try:
            if args.software_x11 or not env.get("DISPLAY"):
                server, log = start_display(directory, env)
            command = [engine, "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1600x900", "--max-fps", "30", "--script",
                       "res://tests/hero_graphics_review.gd", "--", str(output)]
            if args.baseline:
                command.append("--baseline")
            if args.motion:
                command.append("--motion")
            try:
                result = subprocess.run(command, env=env, cwd=ROOT, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
            except subprocess.TimeoutExpired as error:
                captured = error.stdout or ""
                if isinstance(captured, bytes):
                    captured = captured.decode("utf-8", errors="replace")
                (output / "runtime.log").write_text(captured + "\nTIMEOUT after 240 seconds\n", encoding="utf-8")
                print(json.dumps({"passed": False, "reason": "timeout", "output": str(output),
                                  "android_device_test": False}))
                return 1
            (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
            passed = result.returncode == 0 and FAILURE.search(result.stdout) is None
            passed = passed and 'HERO_GRAPHICS_REVIEW []' in result.stdout
            receipt = output / "runtime-review.json"
            if passed and receipt.is_file():
                review = json.loads(receipt.read_text(encoding="utf-8"))
                sources = {"prototype/" + item["asset"].removeprefix("res://")
                           for item in review["captures"]}
                sources.update({"prototype/scripts/visuals/village_person.gd",
                                "prototype/scripts/visuals/facial_motion.gd",
                                "prototype/tests/hero_graphics_review.gd",
                                "prototype/scripts/ui/runtime_display.gd",
                                "prototype/assets/quality_profiles.json",
                                "prototype/project.godot"})
                review["source_sha256"] = {source: hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
                                           for source in sorted(sources)}
                receipt.write_text(json.dumps(review, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            elif passed:
                passed = False
            print(json.dumps({"passed": passed, "exit_code": result.returncode,
                              "output": str(output), "android_device_test": False}))
            if not passed:
                print(result.stdout[-6000:])
            return 0 if passed else 1
        finally:
            if server:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
            if log:
                log.close()


if __name__ == "__main__":
    raise SystemExit(main())
