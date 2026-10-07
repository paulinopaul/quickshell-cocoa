#!/usr/bin/env bash
# agy_state_writer.sh — Productor de estado canónico de Antigravity para Cocoa Shell.
#
# Recibe un JSON de evento del hook de Antigravity por stdin y escribe
# <ipc-dir>/agy_state.json con el esquema canónico (<ipc-dir> is the
# per-user IPC directory from cocoa_ipc.sh: $XDG_RUNTIME_DIR or
# /tmp/cocoa-<uid>, fail-soft to legacy /tmp).
#
# Esquema de salida:
#   { "state": "idle|thinking|working|awaiting_approval",
#     "action": "Descripción legible",
#     "tool": "nombre_herramienta | null",
#     "command": "línea de comando | null",
#     "summary": "toolSummary | null",
#     "history": ["cmd1", "cmd2", ...],  ← últimos 5
#     "ts": 1727218830 }
#
# Uso: echo '{"event":"PreToolUse",...}' | agy_state_writer.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cocoa_ipc.sh"
IPC_DIR="$(cocoa_ipc_dir)"
STATE_FILE="$IPC_DIR/agy_state.json"
TMP_FILE="$IPC_DIR/agy_state.tmp.$$"

# ── Assertion de dependencias ───────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    echo '{"state":"idle","action":"jq no encontrado","tool":null,"command":null,"summary":null,"history":[],"ts":0}' > "$STATE_FILE"
    exit 0
fi

# ── Leer evento desde stdin ─────────────────────────────────────────────
INPUT=$(cat)

EVENT="${1:-}"  # Primer argumento: nombre del evento (PreToolUse, PostToolUse, etc.)

# ── Leer historial previo ────────────────────────────────────────────────
PREV_HISTORY="[]"
if [[ -f "$STATE_FILE" ]]; then
    PREV_HISTORY=$(jq -r '.history // []' "$STATE_FILE" 2>/dev/null || echo "[]")
fi

# ── Generar estado canónico según evento ─────────────────────────────────
TS=$(date +%s)

case "$EVENT" in

    PreToolUse)
        TOOL=$(echo "$INPUT" | jq -r '.toolCall.name // "unknown"' 2>/dev/null || echo "unknown")
        SUMMARY=$(echo "$INPUT" | jq -r '.toolCall.args.toolSummary // .toolCall.args.Instruction // ""' 2>/dev/null || echo "")
        CMD=$(echo "$INPUT" | jq -r '.toolCall.args.CommandLine // ""' 2>/dev/null || echo "")

        # Construir entrada de historial
        if [[ -n "$CMD" ]]; then
            HISTORY_ENTRY="$TOOL: $CMD"
        elif [[ -n "$SUMMARY" ]]; then
            HISTORY_ENTRY="$TOOL: $SUMMARY"
        else
            HISTORY_ENTRY="$TOOL"
        fi

        # Acumular últimos 5 en historial
        NEW_HISTORY=$(echo "$PREV_HISTORY" | jq --arg e "$HISTORY_ENTRY" '. + [$e] | .[-5:]' 2>/dev/null || echo "[]")

        # Detectar si es awaiting_approval por el campo de decision del hook
        # (cuando Antigravity pregunta al usuario, el event llega con decision=ask)
        DECISION=$(echo "$INPUT" | jq -r '.decision // ""' 2>/dev/null || echo "")
        if [[ "$DECISION" == "ask" || "$DECISION" == "force_ask" ]]; then
            STATE="awaiting_approval"
            ACTION="Esperando aprobación"
        else
            STATE="working"
            if [[ -n "$CMD" ]]; then
                ACTION="$CMD"
            elif [[ -n "$SUMMARY" ]]; then
                ACTION="$SUMMARY"
            else
                ACTION="Ejecutando: $TOOL"
            fi
        fi

        jq -n \
            --arg state "$STATE" \
            --arg action "$ACTION" \
            --arg tool "$TOOL" \
            --arg command "$CMD" \
            --arg summary "$SUMMARY" \
            --argjson history "$NEW_HISTORY" \
            --argjson ts "$TS" \
            '{state:$state, action:$action, tool:$tool, command:$command, summary:$summary, history:$history, ts:$ts}' \
            > "$TMP_FILE" && mv "$TMP_FILE" "$STATE_FILE"
        ;;

    PreInvocation)
        jq -n \
            --argjson history "$PREV_HISTORY" \
            --argjson ts "$TS" \
            '{state:"thinking", action:"Pensando...", tool:null, command:null, summary:null, history:$history, ts:$ts}' \
            > "$TMP_FILE" && mv "$TMP_FILE" "$STATE_FILE"
        ;;

    PostToolUse)
        # Herramienta completada, AGY sigue trabajando (aún no terminó el turno)
        jq -n \
            --argjson history "$PREV_HISTORY" \
            --argjson ts "$TS" \
            '{state:"thinking", action:"Procesando resultado...", tool:null, command:null, summary:null, history:$history, ts:$ts}' \
            > "$TMP_FILE" && mv "$TMP_FILE" "$STATE_FILE"
        ;;

    Stop)
        REASON=$(echo "$INPUT" | jq -r '.terminationReason // "model_stop"' 2>/dev/null || echo "model_stop")
        if [[ "$REASON" == "error" ]]; then
            ACTION="Terminó con error"
        else
            ACTION="Listo."
        fi
        jq -n \
            --arg action "$ACTION" \
            --argjson history "$PREV_HISTORY" \
            --argjson ts "$TS" \
            '{state:"idle", action:$action, tool:null, command:null, summary:null, history:$history, ts:$ts}' \
            > "$TMP_FILE" && mv "$TMP_FILE" "$STATE_FILE"
        ;;

    *)
        # Evento desconocido → sin cambio de estado, solo stdout vacío para no bloquear
        echo '{}' 
        exit 0
        ;;
esac

# ── Output requerido por el contrato de hooks ────────────────────────────
# PreToolUse espera {"decision":"allow"}, los demás esperan {}
if [[ "$EVENT" == "PreToolUse" ]]; then
    echo '{"decision":"allow"}'
else
    echo '{}'
fi
