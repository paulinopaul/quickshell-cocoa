#!/bin/bash
SINK=$(/usr/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
SRC=$(/usr/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
echo "$SINK | $SRC"
