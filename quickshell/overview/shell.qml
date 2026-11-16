import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"
    property color themeBackground: "#141416"

    property int themeRounding: 22
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 220

    QtObject {
        id: style
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 240) : 200
        property int fadeDuration: 180
        property var smoothEasing: Easing.OutCubic
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property bool isOpened: false
    property bool isClosing: false
    property string activeCursorMonitor: ""

    property int selectedIndex: 0
    property bool initialSelectionDone: false
    property var workspaceList: []
    property int totalWindowsCount: 0
    property string wallpaperPath: ""
    property string wallpaperThumbPath: ""

    function formatFileUrl(pathStr) {
        if (!pathStr || pathStr.length === 0) return ""
        if (pathStr.startsWith("file://")) return pathStr
        return "file://" + pathStr
    }

    FileView {
        id: wallpaperCacheFile
        path: Quickshell.env("HOME") + "/.cache/qs_wallpaper_path"
        watchChanges: true
        onLoaded: {
            let p = text().trim()
            if (p.length > 0 && p !== root.wallpaperPath) {
                root.wallpaperPath = p
            }
        }
    }

    FileView {
        id: fallbackWallpaperCacheFile
        path: Quickshell.env("HOME") + "/.cache/quickshell_last_wallpaper.txt"
        watchChanges: false
        onLoaded: {
            let p = text().trim()
            if (p.length > 0 && root.wallpaperPath === "") {
                root.wallpaperPath = p
            }
        }
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let borderMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (borderMatch && borderMatch[1]) {
                    root.themeBorder = "#" + borderMatch[1]
                    root.themePrimary = "#" + borderMatch[1]
                }
                let bgMatch = content.match(/background\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/background\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (bgMatch && bgMatch[1]) {
                    root.themeBackground = "#" + bgMatch[1]
                }
            } catch (e) {}
        }
    }

    FileView {
        id: generalFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(Math.max(parseInt(rMatch[1]) + 4, 16), 28)
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = Math.max(2, parseInt(bMatch[1]))
            } catch (e) {}
        }
    }

    FileView {
        id: animConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/animations.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/) || content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    Process {
        id: cursorMonitorProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim()
                if (found !== "") {
                    root.activeCursorMonitor = found
                }
            }
        }
    }

    Component.onCompleted: {
        let defaultList = []
        for (let i = 1; i <= 10; i++) {
            defaultList.push({
                id: i,
                name: "Workspace " + i,
                isSpecial: false,
                isActive: i === 1,
                windows: []
            })
        }
        root.workspaceList = defaultList

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.activeCursorMonitor = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.activeCursorMonitor = Quickshell.screens[0].name
        }

        wallpaperCacheFile.reload()
        fallbackWallpaperCacheFile.reload()
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        root.isOpened = true

        let pyScript = `
import json, subprocess
try:
    c = json.loads(subprocess.check_output(['hyprctl', 'cursorpos', '-j'], text=True))
    m = json.loads(subprocess.check_output(['hyprctl', 'monitors', '-j'], text=True))
    cx, cy = c.get('x', 0), c.get('y', 0)
    res = ''
    for mon in m:
        if mon.get('focused'):
            res = mon['name']
    for mon in m:
        mx, my = mon.get('x', 0), mon.get('y', 0)
        scale = mon.get('scale', 1.0)
        w, h = mon.get('width', 1920) / scale, mon.get('height', 1080) / scale
        transform = mon.get('transform', 0)
        if transform % 2 != 0:
            w, h = h, w
        if cx >= mx and cx <= mx + w and cy >= my and cy <= my + h:
            res = mon['name']
            break
    print(res)
except Exception:
    pass
`
        cursorMonitorProcess.command = ["python3", "-c", pyScript]
        cursorMonitorProcess.running = true
    }

    Timer {
        id: closeTimer
        interval: 50
        onTriggered: Qt.quit()
    }

    function switchToWorkspace(item) {
        if (!item || root.isClosing) return
        root.isClosing = true
        root.isOpened = false

        let targetId = item.id
        let isSpecial = item.isSpecial || false
        let specialName = item.rawSpecialName || ""

        if (isSpecial) {
            try { Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + specialName + "\")") } catch (e) {}
            try { Hyprland.dispatch("hl.dsp.toggle_special_workspace({ name = \"" + specialName + "\" })") } catch (e) {}
            try { Hyprland.dispatch("togglespecialworkspace " + specialName) } catch (e) {}
        } else {
            try { Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + targetId + "\" })") } catch (e) {}
            try { Hyprland.dispatch("hl.dsp.focus({ workspace = " + targetId + " })") } catch (e) {}
            try { Hyprland.dispatch("workspace " + targetId) } catch (e) {}
        }

        let envPrefix = "export HYPRLAND_INSTANCE_SIGNATURE='" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") + "'; " +
                        "export WAYLAND_DISPLAY='" + (Quickshell.env("WAYLAND_DISPLAY") || "") + "'; " +
                        "export XDG_RUNTIME_DIR='" + (Quickshell.env("XDG_RUNTIME_DIR") || "") + "'; "

        let bashCmd = ""
        if (isSpecial) {
            bashCmd = "hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"" + specialName + "\")' 2>/dev/null || " +
                      "hyprctl dispatch 'hl.dsp.toggle_special_workspace({ name = \"" + specialName + "\" })' 2>/dev/null || " +
                      "hyprctl dispatch togglespecialworkspace '" + specialName + "' 2>/dev/null"
        } else {
            bashCmd = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + targetId + "\" })' 2>/dev/null || " +
                      "hyprctl dispatch 'hl.dsp.focus({ workspace = " + targetId + " })' 2>/dev/null || " +
                      "hyprctl dispatch workspace '" + targetId + "' 2>/dev/null"
        }

        Quickshell.execDetached(["bash", "-c", envPrefix + "nohup " + bashCmd + " >/dev/null 2>&1 &"])

        closeTimer.interval = 50
        closeTimer.start()
    }

    function dismissMenu() {
        if (root.isClosing) return
        root.isClosing = true
        root.isOpened = false
        closeTimer.interval = 20
        closeTimer.start()
    }

    Process {
        id: fetchWsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim())
                    let wsList = parsed.workspaces || []
                    root.workspaceList = wsList

                    let totalWins = 0
                    for (let i = 0; i < wsList.length; i++) {
                        totalWins += (wsList[i].windows ? wsList[i].windows.length : 0)
                    }
                    root.totalWindowsCount = totalWins

                    if (parsed.wallpaper && parsed.wallpaper.length > 0) {
                        if (root.wallpaperPath !== parsed.wallpaper) {
                            root.wallpaperPath = parsed.wallpaper
                        }
                    }
                    if (parsed.thumb && parsed.thumb.length > 0) {
                        if (root.wallpaperThumbPath !== parsed.thumb) {
                            root.wallpaperThumbPath = parsed.thumb
                        }
                    }
                    if (!root.initialSelectionDone && wsList.length > 0) {
                        for (let i = 0; i < wsList.length; i++) {
                            if (wsList[i].isActive) {
                                root.selectedIndex = i
                                root.initialSelectionDone = true
                                break
                            }
                        }
                    }
                    if (root.selectedIndex >= wsList.length) {
                        root.selectedIndex = Math.max(0, wsList.length - 1)
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 350
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchWsProcess.running && !root.isClosing) {
                let pyScript = `
import subprocess, json, os, re, hashlib, glob

ICON_CACHE_FILE = "/tmp/qs_overview_icons.json"
try:
    with open(ICON_CACHE_FILE, "r", encoding="utf-8") as f:
        ICON_CACHE = json.load(f)
except Exception:
    ICON_CACHE = {}

HOME = os.path.expanduser("~")

ICON_DIRS = [
    os.path.join(HOME, ".local/share/icons/WhiteSur/apps/scalable"),
    os.path.join(HOME, ".local/share/icons/WhiteSur-dark/apps/scalable"),
    os.path.join(HOME, ".local/share/icons/WhiteSur/apps/48"),
    "/usr/share/icons/WhiteSur/apps/scalable",
    "/usr/share/icons/WhiteSur-dark/apps/scalable",
    "/usr/share/icons/Papirus/scalable/apps",
    "/usr/share/icons/Papirus/48x48/apps",
    "/usr/share/icons/hicolor/scalable/apps",
    "/usr/share/icons/hicolor/512x512/apps",
    "/usr/share/icons/hicolor/256x256/apps",
    "/usr/share/icons/hicolor/128x128/apps",
    "/usr/share/icons/hicolor/64x64/apps",
    "/usr/share/icons/hicolor/48x48/apps",
    "/usr/share/icons/Adwaita/scalable/apps",
    "/usr/share/pixmaps",
    os.path.join(HOME, ".local/share/icons"),
]

DESKTOP_DIRS = [
    os.path.join(HOME, ".local/share/applications"),
    "/usr/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    os.path.join(HOME, ".local/share/flatpak/exports/share/applications"),
    "/var/lib/snapd/desktop/applications"
]

def get_app_icon(wm_class, initial_class):
    cache_key = f"{wm_class}|{initial_class}"
    if cache_key in ICON_CACHE:
        cached = ICON_CACHE[cache_key]
        if cached and os.path.isfile(cached):
            return cached

    candidates = []
    for cls in [wm_class, initial_class]:
        if cls:
            candidates.append(cls)
            candidates.append(cls.lower())
            if "." in cls:
                candidates.append(cls.split(".")[-1])
                candidates.append(cls.split(".")[-1].lower())

    mapped = []
    for c in candidates:
        mapped.append(c)
        if "codium" in c or "code" in c:
            mapped.extend(["vscodium", "vscode", "code", "com.visualstudio.code"])
        elif "zen" in c:
            mapped.extend(["zen", "zen-browser", "zen-alpha", "app.zen_browser.zen"])
        elif "chrome" in c:
            mapped.extend(["google-chrome", "chrome"])
        elif "firefox" in c:
            mapped.extend(["firefox", "firefox-developer-edition"])
        elif "nautilus" in c or "files" in c:
            mapped.extend(["org.gnome.Nautilus", "nautilus", "system-file-manager"])

    desktop_icon = None
    for ddir in DESKTOP_DIRS:
        if not os.path.exists(ddir): continue
        for name in mapped:
            df = os.path.join(ddir, f"{name}.desktop")
            if os.path.isfile(df):
                try:
                    with open(df, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if line.startswith("Icon="):
                                desktop_icon = line.split("=")[1].strip()
                                break
                except Exception:
                    pass
            if desktop_icon: break
        if desktop_icon: break

    search_names = []
    if desktop_icon:
        if "/" in desktop_icon and os.path.isfile(desktop_icon):
            ICON_CACHE[cache_key] = desktop_icon
            return desktop_icon
        search_names.append(desktop_icon)
    search_names.extend(mapped)

    for sname in search_names:
        for idir in ICON_DIRS:
            if not os.path.exists(idir): continue
            for ext in [".svg", ".png", ".xpm"]:
                filepath = os.path.join(idir, sname + ext)
                if os.path.isfile(filepath):
                    ICON_CACHE[cache_key] = filepath
                    return filepath

    return ""

def make_low_quality_thumb(src_path):
    if not os.path.isfile(src_path):
        return ""

    cache_dir = os.path.join(HOME, ".cache")
    os.makedirs(cache_dir, exist_ok=True)

    try:
        mtime = os.path.getmtime(src_path)
    except Exception:
        mtime = 0

    path_hash = hashlib.md5(f"{src_path}_{mtime}".encode("utf-8")).hexdigest()[:10]
    thumb_path = os.path.join(cache_dir, f"qs_thumb_{path_hash}.jpg")

    if os.path.exists(thumb_path) and os.path.getsize(thumb_path) > 0:
        return thumb_path

    try:
        for f in os.listdir(cache_dir):
            if f.startswith("qs_thumb_") and f.endswith(".jpg"):
                try:
                    os.remove(os.path.join(cache_dir, f))
                except Exception:
                    pass
    except Exception:
        pass

    generated = False
    try:
        from PIL import Image
        with Image.open(src_path) as img:
            img.thumbnail((480, 270), Image.Resampling.BILINEAR)
            img.convert("RGB").save(thumb_path, "JPEG", quality=65, optimize=True)
        generated = True
    except Exception:
        pass

    if not generated:
        try:
            subprocess.run(f'convert "{src_path}" -resize 480x270 "{thumb_path}"', shell=True, timeout=2)
            generated = os.path.exists(thumb_path)
        except Exception:
            pass

    return thumb_path if generated else src_path

def get_wallpaper():
    found_path = ""
    candidates = [
        os.path.join(HOME, ".cache", "qs_wallpaper_path"),
        os.path.join(HOME, ".cache", "quickshell_last_wallpaper.txt"),
        os.path.join(HOME, ".cache", "current_wallpaper"),
        os.path.join(HOME, ".cache", "wallpaper"),
        os.path.join(HOME, ".config", "hypr", "wallpaper")
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                if p.endswith(".txt") or p.endswith("qs_wallpaper_path"):
                    with open(p, "r", encoding="utf-8") as f:
                        line = f.read().strip()
                        if line and os.path.isfile(line):
                            found_path = line
                            break
                else:
                    real_p = os.path.realpath(p)
                    if os.path.isfile(real_p):
                        found_path = real_p
                        break
            except Exception:
                pass

    if not found_path:
        for cmd in ["swww query 2>/dev/null", "awww query 2>/dev/null"]:
            try:
                out = subprocess.check_output(cmd, shell=True, text=True, timeout=1)
                m = re.findall(r'(/.*?\.(?:png|jpg|jpeg|webp|gif))', out, re.IGNORECASE)
                for p in m:
                    p_clean = p.strip().strip('"').strip("'")
                    if os.path.isfile(p_clean):
                        found_path = p_clean
                        break
                if found_path:
                    break
            except Exception:
                pass

    if not found_path:
        try:
            wp_cfg = os.path.join(HOME, ".config/waypaper/config.ini")
            if os.path.isfile(wp_cfg):
                with open(wp_cfg, "r") as f:
                    for line in f:
                        if line.startswith("wallpaper"):
                            p = line.split("=")[1].strip().replace("~", HOME)
                            if os.path.isfile(p):
                                found_path = p
                                break
        except Exception:
            pass

    thumb_path = ""
    if found_path:
        found_path = os.path.realpath(found_path)
        cached_file = os.path.join(HOME, ".cache/qs_wallpaper_path")
        try:
            os.makedirs(os.path.dirname(cached_file), exist_ok=True)
            with open(cached_file, "w") as f:
                f.write(found_path)
        except Exception:
            pass
        thumb_path = make_low_quality_thumb(found_path)

    return found_path, thumb_path

def parse_workspace_id(ws_info):
    if isinstance(ws_info, int): return ws_info
    if isinstance(ws_info, str): return int(ws_info) if ws_info.isdigit() else ws_info
    if isinstance(ws_info, dict):
        wid = ws_info.get("id")
        if wid is not None and wid != 0: return wid
        wname = str(ws_info.get("name", ""))
        if wname.isdigit(): return int(wname)
        match = re.search(r'\\d+', wname)
        if match and not wname.startswith("special:"): return int(match.group())
        return wname
    return None

try:
    ws_data = json.loads(subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True) or "[]")
    clients_data = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True) or "[]")
    active_ws = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True) or "{}")
except Exception:
    ws_data, clients_data, active_ws = [], [], {}

active_id = active_ws.get("id", 1)
wallpaper, thumb = get_wallpaper()

ws_windows = {}
for c in clients_data:
    if not c.get("mapped", True) or c.get("hidden", False):
        continue
    wid = parse_workspace_id(c.get("workspace"))
    if wid is None: continue

    try:
        wid_key = int(wid)
    except (ValueError, TypeError):
        wid_key = str(wid)

    title = c.get("title", "").strip()
    initial_title = c.get("initialTitle", "").strip()
    wm_class = c.get("class", "").strip()
    initial_class = c.get("initialClass", "").strip()

    raw_class = wm_class or initial_class or "App"
    app_name = raw_class.split(".")[-1].capitalize()
    display_title = title or initial_title or app_name
    icon_path = get_app_icon(wm_class, initial_class)

    ws_windows.setdefault(wid_key, []).append({
        "title": display_title,
        "class": app_name,
        "icon": icon_path
    })

try:
    with open(ICON_CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(ICON_CACHE, f)
except Exception:
    pass

regular_ids = set(range(1, 11))
for w in ws_data:
    w_id = w.get("id", 0)
    if w_id > 0:
        regular_ids.add(w_id)

result = []
for wid in sorted(list(regular_ids)):
    result.append({
        "id": wid,
        "name": "Workspace " + str(wid),
        "isSpecial": False,
        "isActive": (wid == active_id),
        "windows": ws_windows.get(wid, [])
    })

special_ws = [w for w in ws_data if w.get("id", 0) < 0 or str(w.get("name", "")).startswith("special:")]
for w in special_ws:
    wid = w.get("id")
    raw_name = str(w.get("name", "")).replace("special:", "") or "special"
    windows = ws_windows.get(wid, []) or ws_windows.get(str(wid), []) or ws_windows.get("special:" + raw_name, [])
    if len(windows) > 0:
        result.append({
            "id": wid,
            "name": "★ " + raw_name.capitalize(),
            "rawSpecialName": raw_name,
            "isSpecial": True,
            "isActive": False,
            "windows": windows
        })

print(json.dumps({"wallpaper": wallpaper, "thumb": thumb, "workspaces": result}))
`
                fetchWsProcess.command = ["python3", "-c", pyScript]
                fetchWsProcess.running = true
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: overviewWindow
            required property var modelData

            property bool isTargetMonitor: root.activeCursorMonitor !== "" && modelData.name === root.activeCursorMonitor

            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-overview"

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            visible: root.isOpened && !root.isClosing && isTargetMonitor

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Item {
                anchors.fill: parent
                visible: isTargetMonitor

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismissMenu()
                }

                Item {
                    id: mainContainer
                    anchors.centerIn: parent
                    implicitWidth: cardColumn.implicitWidth + 52
                    implicitHeight: cardColumn.implicitHeight + 48

                    focus: isTargetMonitor

                    Component.onCompleted: {
                        if (isTargetMonitor) forceActiveFocus()
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.dismissMenu()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                            if (root.workspaceList.length > 0) {
                                root.selectedIndex = (root.selectedIndex - 1 + root.workspaceList.length) % root.workspaceList.length
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                            if (root.workspaceList.length > 0) {
                                root.selectedIndex = (root.selectedIndex + 1) % root.workspaceList.length
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backtab) {
                            if (root.workspaceList.length > 0) {
                                root.selectedIndex = (root.selectedIndex - 1 + root.workspaceList.length) % root.workspaceList.length
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                            if (root.selectedIndex - 5 >= 0) {
                                root.selectedIndex -= 5
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                            if (root.selectedIndex + 5 < root.workspaceList.length) {
                                root.selectedIndex += 5
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            if (root.workspaceList && root.workspaceList.length > root.selectedIndex) {
                                root.switchToWorkspace(root.workspaceList[root.selectedIndex])
                            }
                            event.accepted = true
                        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                            let targetNum = event.key - Qt.Key_1 + 1
                            for (let i = 0; i < root.workspaceList.length; i++) {
                                if (root.workspaceList[i].id === targetNum && !root.workspaceList[i].isSpecial) {
                                    root.selectedIndex = i
                                    root.switchToWorkspace(root.workspaceList[i])
                                    event.accepted = true
                                    return
                                }
                            }
                        } else if (event.key === Qt.Key_0) {
                            for (let i = 0; i < root.workspaceList.length; i++) {
                                if (root.workspaceList[i].id === 10 && !root.workspaceList[i].isSpecial) {
                                    root.selectedIndex = i
                                    root.switchToWorkspace(root.workspaceList[i])
                                    event.accepted = true
                                    return
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: cardRect
                        anchors.fill: parent

                        radius: root.themeRounding
                        color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.themePrimary, 0.42)
                        antialiasing: true
                        clip: true

                        opacity: root.isClosing ? 0.0 : (root.isOpened ? 1.0 : 0.0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.animEnabled ? style.fadeDuration : 0
                                easing.type: style.smoothEasing
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: root.themeBorderSize
                            radius: Math.max(0, parent.radius - root.themeBorderSize)
                            antialiasing: true
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                                GradientStop { position: 0.35; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        ColumnLayout {
                            id: cardColumn
                            anchors.centerIn: parent
                            spacing: 20

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 12
                                    color: Qt.alpha(root.themePrimary, 0.18)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.40)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰕮"
                                        font.family: root.iconFontFamily
                                        color: root.themePrimary
                                        font.pixelSize: 19
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter

                                    RowLayout {
                                        spacing: 10

                                        Text {
                                            text: "Workspace Overview"
                                            font.family: root.fontFamily
                                            color: "#FFFFFF"
                                            font.pixelSize: 20
                                            font.weight: Font.Bold
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.85)
                                        }

                                        Rectangle {
                                            visible: root.totalWindowsCount > 0
                                            Layout.preferredWidth: winCountBadge.implicitWidth + 14
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            color: Qt.alpha(root.themePrimary, 0.24)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.45)
                                            antialiasing: true

                                            Text {
                                                id: winCountBadge
                                                anchors.centerIn: parent
                                                text: root.totalWindowsCount + (root.totalWindowsCount === 1 ? " window" : " windows")
                                                font.family: root.fontFamily
                                                color: root.themePrimary
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Select a workspace to switch focus"
                                        font.family: root.fontFamily
                                        color: root.themeTextMuted
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: escRow.implicitWidth + 20
                                    Layout.preferredHeight: 32
                                    radius: 10
                                    color: closeBtnArea.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.rgba(0, 0, 0, 0.38)
                                    border.width: 1
                                    border.color: closeBtnArea.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.16)
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation { duration: style.fadeDuration; easing.type: style.smoothEasing }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation { duration: style.fadeDuration; easing.type: style.smoothEasing }
                                    }

                                    RowLayout {
                                        id: escRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            width: 28
                                            height: 18
                                            radius: 5
                                            color: Qt.alpha(root.themePrimary, 0.20)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.45)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "ESC"
                                                font.family: root.fontFamily
                                                color: root.themePrimary
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            text: "Close"
                                            font.family: root.fontFamily
                                            color: "#FFFFFF"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                        }
                                    }

                                    MouseArea {
                                        id: closeBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.dismissMenu()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(255, 255, 255, 0.12)
                            }

                            Grid {
                                columns: 5
                                spacing: 14
                                Layout.alignment: Qt.AlignHCenter

                                Repeater {
                                    model: root.workspaceList

                                    delegate: Item {
                                        id: cardItem
                                        required property var modelData
                                        required property int index

                                        width: 224
                                        height: 142

                                        property bool isSelected: index === root.selectedIndex
                                        property bool isActiveWs: modelData.isActive
                                        property int winCount: modelData.windows ? modelData.windows.length : 0
                                        property int cardRadius: Math.max(12, root.themeRounding - 6)

                                        scale: cardMouse.containsMouse || cardItem.isSelected ? 1.05 : 1.0
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? 180 : 0
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Item {
                                            id: bgContainer
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: cardMask
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.alpha(root.themeBackground, 0.75)
                                            }

                                            Image {
                                                id: cardWpImg
                                                anchors.fill: parent
                                                source: root.formatFileUrl(root.wallpaperThumbPath !== "" ? root.wallpaperThumbPath : root.wallpaperPath)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready && source !== ""
                                                antialiasing: true
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: "#000000"
                                                opacity: cardItem.isSelected ? 0.22 : (cardItem.isActiveWs ? 0.28 : 0.42)

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: style.fadeDuration
                                                        easing.type: style.smoothEasing
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: 54
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.72) }
                                                    GradientStop { position: 0.65; color: Qt.rgba(0, 0, 0, 0.28) }
                                                    GradientStop { position: 1.0; color: "transparent" }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.alpha(root.themePrimary, cardItem.isSelected ? 0.12 : 0.0)

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: style.fadeDuration
                                                        easing.type: style.smoothEasing
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: cardMask
                                            anchors.fill: parent
                                            radius: cardItem.cardRadius
                                            color: "black"
                                            visible: false
                                            layer.enabled: true
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8
                                            z: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: modelData.name
                                                    font.family: root.fontFamily
                                                    color: modelData.isSpecial ? "#facc15" : "#FFFFFF"
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.9)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Rectangle {
                                                    visible: cardItem.isActiveWs
                                                    Layout.preferredWidth: activeLabel.implicitWidth + 12
                                                    Layout.preferredHeight: 18
                                                    radius: 9
                                                    color: root.themePrimary
                                                    antialiasing: true

                                                    Text {
                                                        id: activeLabel
                                                        text: "ACTIVE"
                                                        font.family: root.fontFamily
                                                        color: "#000000"
                                                        font.pixelSize: 9
                                                        font.weight: Font.Bold
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                            }

                                            Item { Layout.fillHeight: true }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 7
                                                visible: cardItem.winCount > 0

                                                Repeater {
                                                    model: modelData.windows.slice(0, 7)

                                                    delegate: Rectangle {
                                                        required property var modelData

                                                        width: 36
                                                        height: 36
                                                        radius: 10
                                                        color: iconMouse.containsMouse
                                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.25, 0.85)
                                                               : Qt.rgba(0.05, 0.05, 0.07, 0.76)
                                                        border.width: 1
                                                        border.color: iconMouse.containsMouse
                                                                      ? root.themePrimary
                                                                      : Qt.rgba(255, 255, 255, 0.22)
                                                        antialiasing: true

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: style.fadeDuration
                                                                easing.type: style.smoothEasing
                                                            }
                                                        }
                                                        Behavior on border.color {
                                                            ColorAnimation {
                                                                duration: style.fadeDuration
                                                                easing.type: style.smoothEasing
                                                            }
                                                        }

                                                        Image {
                                                            id: imgIcon
                                                            anchors.centerIn: parent
                                                            width: 22
                                                            height: 22
                                                            sourceSize: Qt.size(44, 44)
                                                            source: root.formatFileUrl(modelData.icon)
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            asynchronous: true
                                                            visible: modelData.icon !== "" && status === Image.Ready
                                                            antialiasing: true
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: modelData.icon === "" || imgIcon.status !== Image.Ready
                                                            text: modelData.class.substring(0, 2).toUpperCase()
                                                            font.family: root.fontFamily
                                                            color: "#FFFFFF"
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                        }

                                                        ToolTip.visible: iconMouse.containsMouse
                                                        ToolTip.delay: 150
                                                        ToolTip.text: modelData.class + (modelData.title ? ": " + modelData.title : "")

                                                        MouseArea {
                                                            id: iconMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            acceptedButtons: Qt.NoButton
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    visible: cardItem.winCount > 7
                                                    width: 36
                                                    height: 36
                                                    radius: 10
                                                    color: Qt.rgba(0.05, 0.05, 0.07, 0.82)
                                                    border.width: 1
                                                    border.color: root.themePrimary
                                                    antialiasing: true

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "+" + (cardItem.winCount - 7)
                                                        font.family: root.fontFamily
                                                        color: "#FFFFFF"
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: cardItem.cardRadius
                                            color: "transparent"
                                            border.width: cardItem.isSelected ? Math.max(2, root.themeBorderSize + 1) : (cardItem.isActiveWs ? 2 : 1)
                                            border.color: cardItem.isSelected
                                                          ? root.themePrimary
                                                          : (cardItem.isActiveWs
                                                             ? Qt.alpha(root.themePrimary, 0.78)
                                                             : Qt.rgba(255, 255, 255, 0.22))
                                            antialiasing: true
                                            z: 10

                                            Behavior on border.color {
                                                ColorAnimation {
                                                    duration: root.animEnabled ? style.fadeDuration : 0
                                                    easing.type: style.smoothEasing
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: cardMouse
                                            anchors.fill: parent
                                            z: 100
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPositionChanged: {
                                                if (root.selectedIndex !== index) {
                                                    root.selectedIndex = index
                                                }
                                            }
                                            onClicked: {
                                                let wsTarget = (root.workspaceList && root.workspaceList.length > index) ? root.workspaceList[index] : modelData
                                                root.switchToWorkspace(wsTarget)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: footerRow.implicitWidth + 28
                                Layout.preferredHeight: 32
                                radius: 10
                                color: Qt.rgba(0, 0, 0, 0.38)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.12)
                                antialiasing: true

                                RowLayout {
                                    id: footerRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: "Arrow Keys / 0-9 / Mouse to navigate  •  Enter / Click to switch  •  Esc to exit"
                                        font.family: root.fontFamily
                                        color: root.themeTextMuted
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}