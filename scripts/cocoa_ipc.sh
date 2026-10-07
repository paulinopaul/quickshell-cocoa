#!/usr/bin/env bash
# cocoa_ipc.sh — Canonical per-user IPC directory for Cocoa Shell.
#
# All Cocoa writers/readers (bash via this helper, python via
# scripts/cocoa_ipc.py, QML via the same one-shot probe) resolve the same
# directory so files never collide between concurrent users:
#   1. $XDG_RUNTIME_DIR when set and writable (already per-user).
#   2. Otherwise /tmp/cocoa-<uid> (created as needed).
#   3. Fail-soft to legacy /tmp ONLY when neither candidate is writable.
#
# Filenames stay identical; only the directory changes.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/cocoa_ipc.sh"
#        IPC_DIR="$(cocoa_ipc_dir)"

cocoa_ipc_dir() {
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        if mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && [[ -w "$XDG_RUNTIME_DIR" ]]; then
            printf '%s' "$XDG_RUNTIME_DIR"
            return 0
        fi
    fi
    local uid
    uid="$(id -u 2>/dev/null || echo "${UID:-0}")"
    local userdir="/tmp/cocoa-${uid}"
    if mkdir -p "$userdir" 2>/dev/null && [[ -w "$userdir" ]]; then
        printf '%s' "$userdir"
        return 0
    fi
    # Fail-soft to legacy /tmp ONLY when neither candidate is writable.
    printf '/tmp'
}
