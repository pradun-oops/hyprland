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
    notify_error "Usage: screenrecord.sh full | area"
    echo "Usage: $0 full | area"
}

for cmd in wf-recorder notify-send hyprctl jq; do
    if ! has_cmd "$cmd"; then
        echo "Missing command: $cmd"
        notify_error "Missing command: $cmd"
        exit 1
    fi
done

if [ "${1:-}" = "area" ] && ! has_cmd slurp; then
    echo "Missing command: slurp"
    notify_error "Missing command: slurp"
    exit 1
fi

mkdir -p "$SAVE_DIR"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    pkill -INT wf-recorder
    notify_stop "Recording saved in Videos/Screencasts."
    exit 0
fi

AUDIO_ARGS=()

MODE="${1:-}"

case "$MODE" in
    area)
        GEOM="$(slurp || true)"

        if [ -z "$GEOM" ]; then
            notify_error "Area selection cancelled."
            exit 1
        fi

        wf-recorder -g "$GEOM" "${AUDIO_ARGS[@]}" -f "$FILENAME" &
        notify_start "Area recording started."
        ;;

    full)
        ACTIVE_MONITOR="$(
            hyprctl monitors -j \
                | jq -r '.[] | select(.focused == true) | .name' \
                | xargs
        )"

        if [ -z "$ACTIVE_MONITOR" ] || [ "$ACTIVE_MONITOR" = "null" ]; then
            notify_error "Could not detect focused monitor."
            exit 1
        fi

        wf-recorder -o "$ACTIVE_MONITOR" "${AUDIO_ARGS[@]}" -f "$FILENAME" &
        notify_start "Recording started on $ACTIVE_MONITOR."
        ;;

    *)
        usage
        exit 1
        ;;
esac