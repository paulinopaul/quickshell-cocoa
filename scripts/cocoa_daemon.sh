#!/bin/bash
NET_COUNTER=0
WIFI=""
ETH=0
NVD=0
SERIAL_DEV=""

# Lectura inicial de red
WIFI=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -E '^(sí|yes):' | cut -d: -f2 | head -n1)
ETH=$(nmcli -t -f type,state dev 2>/dev/null | grep -E 'ethernet:connected|ethernet:conectado' | wc -l)
NVD=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0")
SERIAL_DEV=$(ls /dev/serial/by-id/* 2>/dev/null | head -n1 | xargs -r basename || true)
if [ -z "$SERIAL_DEV" ]; then
    SERIAL_DEV=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -n1 | xargs -r basename || true)
fi

while true; do
    # Volume & Mic (Rápido: 20-30ms)
    SINK=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
    SRC=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo "Volume: 0.00")
    
    # Network & Hardware (Lento: ejecutar cada 30 ciclos = ~2.5 segundos)
    NET_COUNTER=$((NET_COUNTER + 1))
    if [ $NET_COUNTER -ge 30 ]; then
        NET_COUNTER=0
        WIFI=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -E '^(sí|yes):' | cut -d: -f2 | head -n1)
        ETH=$(nmcli -t -f type,state dev 2>/dev/null | grep -E 'ethernet:connected|ethernet:conectado' | wc -l)
        
        # NVIDIA GPU
        NVD_RAW=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0")
        NVD=$(echo "$NVD_RAW" | tr -dc '0-9')
        [ -z "$NVD" ] && NVD=0
        
        # Puerto Serial
        SERIAL_DEV=$(ls /dev/serial/by-id/* 2>/dev/null | head -n1 | xargs -r basename || true)
        if [ -z "$SERIAL_DEV" ]; then
            SERIAL_DEV=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -n1 | xargs -r basename || true)
        fi
    fi
    
    echo "$SINK|$SRC|$WIFI|$ETH|$NVD|$SERIAL_DEV" > /tmp/cocoa_status.tmp
    mv /tmp/cocoa_status.tmp /tmp/cocoa_status.txt
    
    # Antigravity CLI status (cada 5 ciclos = ~500ms)
    if [ $((NET_COUNTER % 5)) -eq 0 ]; then
        LATEST_BRAIN=$(ls -td ~/.gemini/antigravity-cli/brain/*/ 2>/dev/null | head -1)
        if [ -n "$LATEST_BRAIN" ]; then
            tail -n 1 "${LATEST_BRAIN}.system_generated/logs/transcript.jsonl" 2>/dev/null > /tmp/agy_status.tmp
            mv /tmp/agy_status.tmp /tmp/agy_status.txt
        fi
    fi
    
    sleep 0.08
done

