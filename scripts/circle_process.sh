#!/bin/bash

if [ "$#" -ne 4 ]; then
    exit 1
fi

X=${1%.*}
Y=${2%.*}
WIDTH=${3%.*}
HEIGHT=${4%.*}

ORIGINAL="/tmp/circle_screen.png"
CROPPED="/tmp/circle_crop.jpg"

if [ ! -f "$ORIGINAL" ]; then
    exit 1
fi

magick "$ORIGINAL" -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" +repage -quality 80 "$CROPPED" || exit 1

IMAGE_URL=$(curl -s -A "Mozilla/5.0" --max-time 15 -F "reqtype=fileupload" -F "fileToUpload=@$CROPPED" https://catbox.moe/user/api.php | tr -d '[:space:]')

if [[ "$IMAGE_URL" == http* ]]; then
    SEARCH_URL="https://lens.google.com/uploadbyurl?url=$IMAGE_URL"

    BROWSER_EXEC=""

    for b in zen-browser zen firefox chromium-browser chromium google-chrome-stable google-chrome brave-browser; do
        if command -v "$b" &> /dev/null; then
            BROWSER_EXEC="$b"
            break
        fi
    done

    if [ -n "$BROWSER_EXEC" ]; then
        case "$BROWSER_EXEC" in
            chromium*|google-chrome*|brave*)
                nohup "$BROWSER_EXEC" --ozone-platform-hint=auto --enable-wayland-ime --app="$SEARCH_URL" >/dev/null 2>&1 & disown
                ;;
            zen*|firefox*)
                nohup "$BROWSER_EXEC" --new-window "$SEARCH_URL" >/dev/null 2>&1 & disown
                ;;
            *)
                nohup "$BROWSER_EXEC" "$SEARCH_URL" >/dev/null 2>&1 & disown
                ;;
        esac
    elif command -v xdg-open &> /dev/null; then
        nohup xdg-open "$SEARCH_URL" >/dev/null 2>&1 & disown
    else
        echo -n "$SEARCH_URL" | wl-copy
    fi
else
    wl-copy -t image/jpeg < "$CROPPED"
fi