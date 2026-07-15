#!/usr/bin/env python3
"""Report CLI and terminal/IDE evidence without changing the environment."""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def sanitize_process_name(value):
    basename = value.strip().rsplit("/", 1)[-1].lower()
    aliases = {
        "cursor": "cursor",
        "cursor helper": "cursor-helper",
        "cursor helper (plugin)": "cursor-helper",
        "antigravity": "antigravity",
        "antigravity helper": "antigravity-helper",
        "code": "vscode",
        "code helper": "vscode-helper",
        "visual studio code": "vscode",
    }
    return aliases.get(basename, "other")


def editor_paths(home, platform):
    base = (
        home / "Library" / "Application Support"
        if platform == "darwin"
        else home / ".config"
    )
    return {
        "cursor": base / "Cursor" / "User" / "settings.json",
        "antigravity": base / "Antigravity" / "User" / "settings.json",
        "vscode": base / "Code" / "User" / "settings.json",
    }


def parent_processes():
    override = os.environ.get("JR_DETECT_PARENT_PROCESSES")
    if override is not None:
        return [sanitize_process_name(item) for item in override.split("|") if item]

    processes = []
    pid = os.getppid()
    for _ in range(8):
        if pid <= 1:
            break
        try:
            result = subprocess.run(
                ["ps", "-o", "ppid=", "-o", "comm=", "-p", str(pid)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            break
        if not result:
            break
        fields = result.split(None, 1)
        if len(fields) != 2:
            break
        parent_pid, executable = fields
        processes.append(sanitize_process_name(executable))
        try:
            pid = int(parent_pid)
        except ValueError:
            break
    return processes


def explicit_editor_from_parents(processes):
    if any(name in {"antigravity", "antigravity-helper"} for name in processes):
        return "antigravity"
    if any(name in {"cursor", "cursor-helper"} for name in processes):
        return "cursor"
    if any(name in {"vscode", "vscode-helper"} for name in processes):
        return "vscode"
    return None


def terminal_detection(processes, term_program, paths):
    explicit = explicit_editor_from_parents(processes)
    evidence = []
    if explicit:
        evidence.append(f"parent_process:{explicit}")
        return "ide", explicit, "high", evidence

    term = term_program.strip().lower()
    ide_terms = {
        "antigravity": "antigravity",
        "antigravity-terminal": "antigravity",
        "cursor": "cursor",
        "cursor-terminal": "cursor",
    }
    if term in ide_terms:
        detected = ide_terms[term]
        evidence.append(f"term_program:{detected}")
        return "ide", detected, "medium", evidence
    if term in {"apple_terminal", "iterm.app", "iterm2"}:
        evidence.append(f"term_program:{term_program}")
        return "native", "native", "high", evidence
    if term in {"vscode", "code"}:
        evidence.append(f"term_program:{term_program}")
        existing = [name for name, path in paths.items() if path.exists()]
        if len(existing) == 1:
            evidence.append(f"settings_exists:{existing[0]}")
            return "ide", existing[0], "low", evidence
        return "ide", "vscode-family", "low", evidence

    existing = [name for name, path in paths.items() if path.exists()]
    if len(existing) == 1:
        evidence.append(f"settings_exists:{existing[0]}")
        return "unknown", existing[0], "low", evidence
    return "unknown", "unknown", "none", evidence


def main():
    home = Path(os.environ.get("JR_DETECT_HOME", str(Path.home()))).expanduser()
    platform = os.environ.get("JR_DETECT_PLATFORM", sys.platform).lower()
    search_path = os.environ.get("JR_DETECT_PATH", os.environ.get("PATH", ""))
    term_program = os.environ.get(
        "JR_DETECT_TERM_PROGRAM", os.environ.get("TERM_PROGRAM", "")
    )
    term_program_version = os.environ.get(
        "JR_DETECT_TERM_PROGRAM_VERSION", os.environ.get("TERM_PROGRAM_VERSION", "")
    )
    processes = parent_processes()
    paths = editor_paths(home, platform)

    cli = {}
    for name in ("claude", "codex"):
        path = shutil.which(name, path=search_path)
        cli[name] = {"installed": path is not None, "path": path}

    if cli["claude"]["installed"] and cli["codex"]["installed"]:
        target = "all"
    elif cli["claude"]["installed"]:
        target = "claude"
    elif cli["codex"]["installed"]:
        target = "codex"
    else:
        target = "none"

    kind, detected, confidence, evidence = terminal_detection(
        processes, term_program, paths
    )
    output = {
        "schema_version": 1,
        "cli": cli,
        "recommended_install_target": target,
        "terminal": {
            "term_program": term_program,
            "term_program_version": term_program_version,
            "parent_processes": processes,
            "kind": kind,
            "detected": detected,
            "confidence": confidence,
            "evidence": evidence,
        },
        "editors": {
            name: {"settings_path": str(path), "settings_exists": path.exists()}
            for name, path in paths.items()
        },
    }
    json.dump(output, sys.stdout, ensure_ascii=False, sort_keys=True, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
