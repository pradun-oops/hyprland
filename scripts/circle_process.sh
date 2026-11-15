#!/usr/bin/env bash

set -u

if [[ "$#" -lt 4 ]]; then
    exit 1
fi

X="${1%.*}"
Y="${2%.*}"
WIDTH="${3%.*}"
HEIGHT="${4%.*}"

[[ "$X" =~ ^-?[0-9]+$ ]] || X=0
[[ "$Y" =~ ^-?[0-9]+$ ]] || Y=0
[[ "$WIDTH" =~ ^-?[0-9]+$ ]] || WIDTH=0
[[ "$HEIGHT" =~ ^-?[0-9]+$ ]] || HEIGHT=0

(( X < 0 )) && X=0
(( Y < 0 )) && Y=0

if (( WIDTH <= 5 || HEIGHT <= 5 )); then
    exit 0
fi

ORIGINAL="/tmp/circle_screen.png"
CROPPED="/tmp/circle_crop.jpg"

if [[ ! -f "$ORIGINAL" ]]; then
    exit 1
fi

rm -f "$CROPPED"

if command -v magick >/dev/null 2>&1; then
    magick "$ORIGINAL" -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" +repage -quality 90 "$CROPPED"
elif command -v convert >/dev/null 2>&1; then
    convert "$ORIGINAL" -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" +repage -quality 90 "$CROPPED"
elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -loglevel error -i "$ORIGINAL" -vf "crop=${WIDTH}:${HEIGHT}:${X}:${Y}" -q:v 2 "$CROPPED"
else
    exit 1
fi

if [[ ! -s "$CROPPED" ]]; then
    exit 1
fi

SEARCH_URL="$(python3 - "$CROPPED" << 'EOF'
import subprocess, sys, time, re, urllib.parse

img = sys.argv[1]
cmds = [
    ["curl", "-sS", "-L", "-A", "CircleSearch/1.0", "--connect-timeout", "4", "--max-time", "10", "-F", f"file=@{img}", "https://0x0.st"],
    ["curl", "-sS", "-L", "-A", "CircleSearch/1.0", "--connect-timeout", "4", "--max-time", "10", "-F", f"file=@{img}", "https://x0.at"],
    ["curl", "-sS", "-L", "-A", "Mozilla/5.0", "--connect-timeout", "4", "--max-time", "10", "-F", f"files[]=@{img}", "https://uguu.se/upload?output=text"],
    ["curl", "-sS", "-L", "-A", "Mozilla/5.0", "--connect-timeout", "4", "--max-time", "10", "-F", "reqtype=fileupload", "-F", "time=1h", "-F", f"fileToUpload=@{img}", "https://litterbox.catbox.moe/resources/internals/api.php"],
    ["curl", "-sS", "-L", "-A", "Mozilla/5.0", "--connect-timeout", "4", "--max-time", "10", "-F", "reqtype=fileupload", "-F", f"fileToUpload=@{img}", "https://catbox.moe/user/api.php"]
]

procs = [subprocess.Popen(c, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True) for c in cmds]
found = ""
pattern = re.compile(r"https://(?:0x0\.st|x0\.at|[^\s\"\'<>]*uguu\.se|[^\s\"\'<>]*catbox\.moe)/[^\s\"\'<>]+")
deadline = time.time() + 11.0

while procs and time.time() < deadline:
    for p in list(procs):
        if p.poll() is not None:
            procs.remove(p)
            out = (p.stdout.read() or "").strip().replace("\\/", "/")
            m = pattern.search(out)
            if m:
                found = m.group(0)
                break
    if found:
        break
    time.sleep(0.04)

for p in procs:
    try:
        p.kill()
    except Exception:
        pass

if found:
    print("https://lens.google.com/uploadbyurl?url=" + urllib.parse.quote(found, safe=""))
EOF
)"

if [[ -n "$SEARCH_URL" ]]; then
    BROWSER_EXEC=""
    for b in zen-browser zen firefox chromium-browser chromium google-chrome-stable google-chrome brave-browser; do
        if command -v "$b" >/dev/null 2>&1; then
            BROWSER_EXEC="$b"
            break
        fi
    done

    if [[ -n "$BROWSER_EXEC" ]]; then
        case "$BROWSER_EXEC" in
            chromium*|google-chrome*|brave*)
                nohup "$BROWSER_EXEC" --ozone-platform-hint=auto --enable-wayland-ime --app="$SEARCH_URL" </dev/null >/dev/null 2>&1 &
                ;;
            zen*|firefox*)
                nohup "$BROWSER_EXEC" --new-window "$SEARCH_URL" </dev/null >/dev/null 2>&1 &
                ;;
            *)
                nohup "$BROWSER_EXEC" "$SEARCH_URL" </dev/null >/dev/null 2>&1 &
                ;;
        esac
    elif command -v xdg-open >/dev/null 2>&1; then
        nohup xdg-open "$SEARCH_URL" </dev/null >/dev/null 2>&1 &
    fi
else
    if command -v wl-copy >/dev/null 2>&1; then
        nohup bash -c "sleep 0.2 && wl-copy --type image/jpeg < '$CROPPED'" </dev/null >/dev/null 2>&1 &
    fi
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -i edit-copy "Circle Search" "Upload failed. Cropped image copied to clipboard."
    fi
fi

exit 0