#!/usr/bin/env python3
"""Disable Codex's built-in title so the session-name watcher owns the tab."""

import os
import re
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path


SECTION_RE = re.compile(r"^\s*\[([^]]+)]\s*(?:#.*)?$")
TITLE_RE = re.compile(r"^(\s*)terminal_title\s*=.*$")


def configured(text):
    section = None
    for line in text.splitlines():
        match = SECTION_RE.match(line)
        if match:
            section = match.group(1).strip()
            continue
        if section == "tui" and TITLE_RE.match(line):
            return line.split("#", 1)[0].split("=", 1)[1].strip() == "[]"
    return False


def update(text):
    if configured(text):
        return text
    lines = text.splitlines(keepends=True)
    tui_start = None
    tui_end = len(lines)
    for index, line in enumerate(lines):
        match = SECTION_RE.match(line.rstrip("\r\n"))
        if not match:
            continue
        if tui_start is not None:
            tui_end = index
            break
        if match.group(1).strip() == "tui":
            tui_start = index
    if tui_start is None:
        separator = "" if not text or text.endswith(("\n\n", "\r\n\r\n")) else "\n"
        return f"{text}{separator}[tui]\nterminal_title = []\n"
    for index in range(tui_start + 1, tui_end):
        match = TITLE_RE.match(lines[index].rstrip("\r\n"))
        if match:
            newline = "\r\n" if lines[index].endswith("\r\n") else "\n"
            lines[index] = f"{match.group(1)}terminal_title = []{newline}"
            return "".join(lines)
    lines.insert(tui_end, "terminal_title = []\n")
    return "".join(lines)


def main():
    home = Path(os.environ.get("JR_INSTALL_HOME", str(Path.home()))).expanduser()
    path = home / ".codex" / "config.toml"
    old = path.read_text() if path.exists() else ""
    if len(sys.argv) == 2 and sys.argv[1] == "--check":
        return 0 if configured(old) else 1
    if len(sys.argv) != 1:
        print("usage: configure-codex.py [--check]", file=sys.stderr)
        return 2
    new = update(old)
    if new == old:
        print(f"  Codex terminal title already disabled: {path}")
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        stamp = datetime.now().strftime("%Y%m%d%H%M%S")
        shutil.copy2(path, path.with_name(f"{path.name}.bak.{stamp}.{os.getpid()}"))
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as temporary:
            temporary_name = temporary.name
            temporary.write(new)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)
    print(f"  disabled Codex built-in terminal title: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
