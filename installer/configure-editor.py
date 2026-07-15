#!/usr/bin/env python3
"""Set the tab-title template for one user-confirmed VS Code-family editor."""

import json
import os
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from editor_settings import resolve


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {
        "cursor",
        "antigravity",
        "vscode",
        "native",
    }:
        print(
            "usage: configure-editor.py cursor|antigravity|vscode|native",
            file=sys.stderr,
        )
        return 2

    editor = sys.argv[1]
    if editor == "native":
        print("Native/other terminal confirmed; editor settings unchanged.")
        return 0

    home = Path(os.environ.get("JR_INSTALL_HOME", str(Path.home()))).expanduser()
    platform = os.environ.get("JR_INSTALL_PLATFORM", sys.platform).lower()
    xdg = os.environ.get("JR_INSTALL_XDG_CONFIG_HOME", os.environ.get("XDG_CONFIG_HOME"))
    path = resolve(editor, home, platform, xdg)
    config = {}
    original = None
    if path.exists():
        original = path.read_bytes()
        config = json.loads(original)
    config["terminal.integrated.tabs.title"] = "${sequence}"
    serialized = (json.dumps(config, indent=2, ensure_ascii=False) + "\n").encode()
    if serialized == original:
        print(f"Already configured {editor}: {path}")
        return 0

    path.parent.mkdir(parents=True, exist_ok=True)
    if original is not None:
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        backup = path.with_name(f"{path.name}.bak.{timestamp}.{os.getpid()}")
        shutil.copy2(path, backup)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
            temporary_name = temporary.name
            temporary.write(serialized)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)
    print(f"Configured {editor}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
