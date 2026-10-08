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

    if command -v chromium-browser &> /dev/null; then
        CHROME_EXEC="chromium-browser"
    elif command -v chromium &> /dev/null; then
        CHROME_EXEC="chromium"
    fi

    if [ -n "$CHROME_EXEC" ]; then
        nohup "$CHROME_EXEC" --ozone-platform-hint=auto --enable-wayland-ime --app="$SEARCH_URL" >/dev/null 2>&1 & disown
    else
        echo -n "$SEARCH_URL" | wl-copy
    fi
else
    wl-copy -t image/jpeg < "$CROPPED"
fi