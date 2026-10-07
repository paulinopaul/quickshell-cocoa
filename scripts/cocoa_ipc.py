#!/usr/bin/env python3
"""cocoa_ipc.py — Canonical per-user IPC directory for Cocoa Shell.

All Cocoa writers/readers (python via this module, bash via
scripts/cocoa_ipc.sh, QML via the same one-shot probe) resolve the same
directory so files never collide between concurrent users:
  1. $XDG_RUNTIME_DIR when set and writable (already per-user).
  2. Otherwise /tmp/cocoa-<uid> (created as needed).
  3. Fail-soft to legacy /tmp ONLY when neither candidate is writable.

Filenames stay identical; only the directory changes.
"""

import os


def ipc_dir() -> str:
    """Resolves the per-user IPC directory, creating it as needed."""
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime:
        try:
            os.makedirs(runtime, exist_ok=True)
            if os.access(runtime, os.W_OK):
                return runtime
        except Exception:
            pass
    try:
        uid = os.getuid()
    except Exception:
        uid = None
    if uid is not None:
        userdir = f"/tmp/cocoa-{uid}"
        try:
            os.makedirs(userdir, exist_ok=True)
            if os.access(userdir, os.W_OK):
                return userdir
        except Exception:
            pass
    # Fail-soft to legacy /tmp ONLY when neither candidate is writable.
    return "/tmp"


def ipc_path(filename: str) -> str:
    """Joins a stable IPC filename onto the per-user IPC directory."""
    return os.path.join(ipc_dir(), filename)
