#!/usr/bin/env bash

set -euo pipefail

SAVE_DIR="$HOME/Videos/Screencasts"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
FILENAME="$SAVE_DIR/$TIMESTAMP.mp4"

ICON_START="media-record"
ICON_STOP="media-playback-stop"
ICON_ERROR="dialog-error"

RECORD_AUDIO=false

notify_start() {
    notify-send -u low -i "$ICON_START" "Screen Record" "$1"
}

notify_stop() {
    notify-send -u low -i "$ICON_STOP" "Screen Record" "$1"
}

notify_error() {
    notify-send -u critical -i "$ICON_ERROR" "Screen Record Error" "$1"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    notify_error "Usage: $0 {full|area}"
    echo "Usage: $0 {full|area}" >&2
    exit 1
}

for cmd in wf-recorder notify-send hyprctl jq; do
    if ! has_cmd "$cmd"; then
        notify_error "Missing command: $cmd"
        exit 1
    fi
done

if pgrep -x wf-recorder >/dev/null 2>&1; then
    pkill -INT wf-recorder
    while pgrep -x wf-recorder >/dev/null 2>&1; do
        sleep 0.1
    done
    notify_stop "Recording saved to Videos/Screencasts."
    exit 0
fi

MODE="${1:-}"

if [[ "$MODE" == "area" ]] && ! has_cmd slurp; then
    notify_error "Missing command: slurp"
    exit 1
fi

mkdir -p "$SAVE_DIR"

AUDIO_ARGS=()
if [[ "$RECORD_AUDIO" == true ]]; then
    AUDIO_ARGS+=(--audio)
fi

case "$MODE" in
    area)
        if ! GEOM=$(slurp 2>/dev/null) || [[ -z "$GEOM" ]]; then
            exit 0
        fi

        wf-recorder --pixel-format yuv420p -g "$GEOM" "${AUDIO_ARGS[@]}" -f "$FILENAME" >/dev/null 2>&1 &
        notify_start "Area recording started."
        ;;
    full)
        ACTIVE_MONITOR="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"

        if [[ -z "$ACTIVE_MONITOR" || "$ACTIVE_MONITOR" == "null" ]]; then
            notify_error "Could not detect focused monitor."
            exit 1
        fi

        wf-recorder --pixel-format yuv420p -o "$ACTIVE_MONITOR" "${AUDIO_ARGS[@]}" -f "$FILENAME" >/dev/null 2>&1 &
        notify_start "Recording started on $ACTIVE_MONITOR."
        ;;
    *)
        usage
        ;;
esac