#!/usr/bin/env python3
"""Resolve VS Code-family settings paths across supported platforms."""

import os
import sys
from pathlib import Path


APP_DIRS = {
    "cursor": ("Cursor",),
    # Current Antigravity builds use "Antigravity IDE" on macOS, while older
    # builds and Linux packages may use "Antigravity".
    "antigravity": ("Antigravity IDE", "Antigravity"),
    "vscode": ("Code",),
}


def config_root(home, platform, xdg_config_home=None):
    if platform.lower() == "darwin":
        return Path(home) / "Library" / "Application Support"
    if xdg_config_home:
        return Path(xdg_config_home).expanduser()
    return Path(home) / ".config"


def candidates(editor, home, platform, xdg_config_home=None):
    base = config_root(home, platform, xdg_config_home)
    return [base / app / "User" / "settings.json" for app in APP_DIRS[editor]]


def resolve(editor, home, platform, xdg_config_home=None):
    paths = candidates(editor, home, platform, xdg_config_home)
    for path in paths:
        if path.is_file():
            return path
    for path in paths:
        if path.parent.parent.is_dir():
            return path
    return paths[0]


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "resolve" or sys.argv[2] not in APP_DIRS:
        print("usage: editor_settings.py resolve cursor|antigravity|vscode", file=sys.stderr)
        return 2
    home = Path(os.environ.get("JR_INSTALL_HOME", str(Path.home()))).expanduser()
    platform = os.environ.get("JR_INSTALL_PLATFORM", sys.platform)
    xdg = os.environ.get("JR_INSTALL_XDG_CONFIG_HOME", os.environ.get("XDG_CONFIG_HOME"))
    print(resolve(sys.argv[2], home, platform, xdg))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
