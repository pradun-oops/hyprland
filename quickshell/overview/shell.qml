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

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeBackground: "#141416"
    
    property int themeRounding: 24
    property int themeBorderSize: 1
    property bool animEnabled: true
    property int animDuration: 380

    QtObject {
        id: style
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 0.5
    }

    property bool isOpened: false
    property bool isClosing: false
    property string activeCursorMonitor: ""

    property int selectedIndex: 0
    property var workspaceList: []
    property string wallpaperPath: ""
    property string wallpaperThumbPath: ""

    function formatFileUrl(pathStr) {
        if (!pathStr || pathStr.length === 0) return "";
        if (pathStr.startsWith("file://")) return pathStr;
        return "file://" + pathStr;
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
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(parseInt(rMatch[1]) + 8, 28)
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
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
                let found = text.trim();
                
                if (found !== "") {
                    root.activeCursorMonitor = found;
                } else {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                        root.activeCursorMonitor = Hyprland.focusedMonitor.name;
                    } else if (Quickshell.screens.length > 0) {
                        root.activeCursorMonitor = Quickshell.screens[0].name;
                    }
                }

                colorFile.reload()
                generalFile.reload()
                animConfigFile.reload()
                root.isOpened = true
            }
        }
    }

    Component.onCompleted: {
        let pyScript = `
import json, subprocess
try:
    c = json.loads(subprocess.check_output('hyprctl cursorpos -j', shell=True))
    m = json.loads(subprocess.check_output('hyprctl monitors -j', shell=True))
    cx, cy = c.get('x',0), c.get('y',0)
    res = ''
    
    for mon in m:
        if mon.get('focused'): 
            res = mon['name']
            
    for mon in m:
        mx, my = mon.get('x',0), mon.get('y',0)
        scale = mon.get('scale', 1.0)
        w, h = mon.get('width', 1920)/scale, mon.get('height', 1080)/scale
        
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
        interval: style.fadeDuration 
        onTriggered: Qt.quit() 
    }

    function switchToWorkspace(item) {
        if (!item || root.isClosing) return;
        root.isClosing = true;

        let targetId = item.id;
        let isSpecial = item.isSpecial || false;
        let specialName = item.rawSpecialName || "";

        let luaCmd = isSpecial 
            ? "hl.dsp.toggle_special_workspace({ name = \"" + specialName + "\" })"
            : "hl.dsp.focus({ workspace = \"" + targetId + "\" })";

        try {
            Hyprland.dispatch(luaCmd);
        } catch(e) {}

        Quickshell.execDetached(["hyprctl", "dispatch", luaCmd]);

        closeTimer.interval = style.fadeDuration;
        closeTimer.start();
    }

    function dismissMenu() {
        if (root.isClosing) return;
        root.isClosing = true;
        closeTimer.interval = style.fadeDuration;
        closeTimer.start();
    }

    Process {
        id: fetchWsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim())
                    root.workspaceList = parsed.workspaces || []
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
                    if (root.selectedIndex >= root.workspaceList.length) {
                        root.selectedIndex = Math.max(0, root.workspaceList.length - 1)
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchWsProcess.running && !root.isClosing) {
                let pyScript = `
import subprocess, json, os, re, hashlib, glob

ICON_DIRS = [
    "/usr/share/pixmaps",
    "/usr/share/icons/hicolor/scalable/apps",
    "/usr/share/icons/hicolor/512x512/apps",
    "/usr/share/icons/hicolor/256x256/apps",
    "/usr/share/icons/hicolor/128x128/apps",
    "/usr/share/icons/hicolor/64x64/apps",
    "/usr/share/icons/hicolor/48x48/apps",
    "/usr/share/icons/Papirus/48x48/apps",
    "/usr/share/icons/Papirus/scalable/apps",
    "/usr/share/icons/breeze/apps/48",
    "/usr/share/icons/breeze/apps/128",
    "/usr/share/icons/Adwaita/scalable/apps",
    os.path.expanduser("~/.local/share/icons"),
]

DESKTOP_DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    "/var/lib/snapd/desktop/applications"
]

def get_app_icon(wm_class, initial_class):
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
            mapped.extend(["zen", "zen-browser", "zen-alpha"])
        elif "chrome" in c:
            mapped.extend(["google-chrome", "chrome"])
        elif "firefox" in c:
            mapped.extend(["firefox", "firefox-developer-edition"])

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
                except Exception: pass
            if desktop_icon: break
        if desktop_icon: break

    search_names = []
    if desktop_icon:
        if "/" in desktop_icon and os.path.isfile(desktop_icon):
            return desktop_icon
        search_names.append(desktop_icon)
    search_names.extend(mapped)

    for sname in search_names:
        for idir in ICON_DIRS:
            if not os.path.exists(idir): continue
            for ext in [".svg", ".png", ".xpm"]:
                filepath = os.path.join(idir, sname + ext)
                if os.path.isfile(filepath):
                    return filepath
    return ""

def make_low_quality_thumb(src_path):
    if not os.path.isfile(src_path):
        return ""
    
    cache_dir = os.path.expanduser("~/.cache")
    os.makedirs(cache_dir, exist_ok=True)
    
    try: mtime = os.path.getmtime(src_path)
    except Exception: mtime = 0
    
    path_hash = hashlib.md5(f"{src_path}_{mtime}".encode("utf-8")).hexdigest()[:10]
    thumb_path = os.path.join(cache_dir, f"qs_thumb_{path_hash}.jpg")

    if os.path.exists(thumb_path) and os.path.getsize(thumb_path) > 0:
        return thumb_path

    try:
        for f in os.listdir(cache_dir):
            if f.startswith("qs_thumb_") and f.endswith(".jpg"):
                try: os.remove(os.path.join(cache_dir, f))
                except Exception: pass
    except Exception: pass

    generated = False
    try:
        from PIL import Image
        with Image.open(src_path) as img:
            img.thumbnail((480, 270), Image.Resampling.BILINEAR)
            img.convert("RGB").save(thumb_path, "JPEG", quality=50, optimize=True)
        generated = True
    except Exception: pass

    if not generated:
        try:
            subprocess.run(f'convert "{src_path}" -resize 480x270 "{thumb_path}"', shell=True, timeout=2)
            generated = os.path.exists(thumb_path)
        except Exception: pass

    return thumb_path if generated else src_path

def get_wallpaper():
    found_path = ""
    
    try:
        out = subprocess.check_output("swww query 2>/dev/null", shell=True, text=True)
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) >= 2:
                p = parts[1].strip().strip('"').strip("'").replace("~", os.path.expanduser("~"))
                if os.path.isfile(p):
                    found_path = p
                    break
    except Exception: pass

    if not found_path:
        try:
            out = subprocess.check_output("awww query 2>/dev/null", shell=True, text=True)
            m = re.findall(r'(?:image:)?\s*"?(/.*?\.(?:png|jpg|jpeg|webp|gif))"?', out, re.IGNORECASE)
            if m:
                for p in m:
                    p_clean = p.strip().strip('"').strip("'").replace("~", os.path.expanduser("~"))
                    if os.path.isfile(p_clean):
                        found_path = p_clean
                        break
        except Exception: pass

    if not found_path:
        try:
            out = subprocess.check_output("hyprctl hyprpaper listactive 2>/dev/null", shell=True, text=True)
            for line in out.splitlines():
                if "=" in line:
                    p = line.split("=")[1].strip().replace("~", os.path.expanduser("~"))
                    if os.path.isfile(p): 
                        found_path = p
                        break
        except Exception: pass

    if not found_path:
        try:
            wp_cfg = os.path.expanduser("~/.config/waypaper/config.ini")
            if os.path.isfile(wp_cfg):
                with open(wp_cfg, "r") as f:
                    for line in f:
                        if line.startswith("wallpaper"):
                            p = line.split("=")[1].strip().replace("~", os.path.expanduser("~"))
                            if os.path.isfile(p): 
                                found_path = p
                                break
        except Exception: pass

    if not found_path:
        home = os.path.expanduser("~")
        candidates = [
            os.path.join(home, ".cache", "qs_wallpaper_path"),
            os.path.join(home, ".cache", "current_wallpaper"),
            os.path.join(home, ".cache", "wallpaper"),
            os.path.join(home, ".cache", "wallust", "wallpaper"),
            os.path.join(home, ".config", "hypr", "wallpaper")
        ]
        for p in candidates:
            if os.path.exists(p):
                real_p = os.path.realpath(p)
                if os.path.isfile(real_p): 
                    found_path = real_p
                    break

    if not found_path:
        home = os.path.expanduser("~")
        search_dirs = [
            os.path.join(home, "Pictures", "Wallpapers"),
            os.path.join(home, "Pictures", "wallpaper"),
            os.path.join(home, "Pictures")
        ]
        for d in search_dirs:
            if os.path.isdir(d):
                files = glob.glob(os.path.join(d, "*"))
                imgs = [f for f in files if os.path.isfile(f) and f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
                if imgs:
                    imgs.sort(key=lambda x: os.path.getmtime(x), reverse=True)
                    found_path = imgs[0]
                    break

    thumb_path = ""
    if found_path:
        found_path = os.path.realpath(found_path)
        cached_file = os.path.expanduser("~/.cache/qs_wallpaper_path")
        try:
            os.makedirs(os.path.dirname(cached_file), exist_ok=True)
            with open(cached_file, "w") as f:
                f.write(found_path)
        except Exception: pass

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
        match = re.search(r'\d+', wname)
        if match and not wname.startswith("special:"): return int(match.group())
        return wname
    return None

try:
    ws_data = json.loads(subprocess.check_output("hyprctl workspaces -j", shell=True) or "[]")
    clients_data = json.loads(subprocess.check_output("hyprctl clients -j", shell=True) or "[]")
    active_ws = json.loads(subprocess.check_output("hyprctl activeworkspace -j", shell=True) or "{}")
except Exception:
    ws_data, clients_data, active_ws = [], [], {}

active_id = active_ws.get("id", 1)
wallpaper, thumb = get_wallpaper()

ws_windows = {}
for c in clients_data:
    wid = parse_workspace_id(c.get("workspace"))
    if wid is None: continue

    try: wid_key = int(wid)
    except (ValueError, TypeError): wid_key = str(wid)

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

regular_ids = set(range(1, 11))
for w in ws_data:
    w_id = w.get("id", 0)
    if w_id > 0: regular_ids.add(w_id)

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

            visible: root.isOpened

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
                    implicitWidth: cardColumn.implicitWidth + 48
                    implicitHeight: cardColumn.implicitHeight + 48

                    focus: isTargetMonitor

                    Component.onCompleted: {
                        if (isTargetMonitor) forceActiveFocus()
                    }

                    Keys.onEscapePressed: root.dismissMenu()

                    Keys.onLeftPressed: {
                        if (root.workspaceList.length > 0) {
                            root.selectedIndex = (root.selectedIndex - 1 + root.workspaceList.length) % root.workspaceList.length
                        }
                    }
                    Keys.onRightPressed: {
                        if (root.workspaceList.length > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % root.workspaceList.length
                        }
                    }
                    Keys.onUpPressed: {
                        if (root.selectedIndex - 5 >= 0) {
                            root.selectedIndex -= 5
                        }
                    }
                    Keys.onDownPressed: {
                        if (root.selectedIndex + 5 < root.workspaceList.length) {
                            root.selectedIndex += 5
                        }
                    }
                    Keys.onReturnPressed: {
                        if (root.workspaceList && root.workspaceList.length > root.selectedIndex) {
                            root.switchToWorkspace(root.workspaceList[root.selectedIndex])
                        }
                    }
                    Keys.onSpacePressed: {
                        if (root.workspaceList && root.workspaceList.length > root.selectedIndex) {
                            root.switchToWorkspace(root.workspaceList[root.selectedIndex])
                        }
                    }

                    Rectangle {
                        id: cardRect
                        anchors.fill: parent

                        radius: root.themeRounding
                        color: Qt.alpha(root.themeBackground, 0.78)
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.themeBorder, 0.45)

                        opacity: root.isClosing ? 0.0 : (root.isOpened ? 1.0 : 0.0)
                        scale: root.isClosing ? 0.90 : (root.isOpened ? 1.0 : 0.90)

                        Behavior on opacity { 
                            NumberAnimation { 
                                duration: root.animEnabled ? style.fadeDuration : 0 
                                easing.type: style.fadeEasing 
                            } 
                        }
                        Behavior on scale { 
                            NumberAnimation { 
                                duration: root.animEnabled ? style.animDuration : 0 
                                easing.type: style.bounceEasing
                                easing.overshoot: style.overshoot
                            } 
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        Column {
                            id: cardColumn
                            anchors.centerIn: parent
                            spacing: 24

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12

                                Text {
                                    text: "Workspace Overview"
                                    color: root.themeText
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 1
                                    height: 20
                                    color: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.3)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "ESC to close"
                                    color: root.themeTextMuted
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Grid {
                                columns: 5
                                spacing: 16
                                anchors.horizontalCenter: parent.horizontalCenter

                                Repeater {
                                    model: root.workspaceList

                                    delegate: Item {
                                        id: cardItem
                                        required property var modelData
                                        required property int index

                                        width: 220
                                        height: 140

                                        property bool isSelected: index === root.selectedIndex
                                        property bool isActiveWs: modelData.isActive

                                        z: isSelected ? 10 : 1
                                        scale: isSelected ? 1.08 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.bounceEasing
                                                easing.overshoot: style.overshoot
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
                                                color: Qt.alpha(root.themeBackground, 0.6)
                                            }

                                            Image {
                                                id: cardWpImg
                                                anchors.fill: parent
                                                source: root.formatFileUrl(root.wallpaperThumbPath !== "" ? root.wallpaperThumbPath : root.wallpaperPath)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                                visible: status === Image.Ready && source !== ""
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: "#000000"
                                                opacity: cardWpImg.visible ? 0.35 : 0.0
                                                Behavior on opacity {
                                                    NumberAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: cardMask
                                            anchors.fill: parent
                                            radius: root.themeRounding
                                            color: "black"
                                            visible: false
                                            layer.enabled: true
                                        }

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            z: 2

                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                Text {
                                                    text: modelData.name
                                                    color: modelData.isSpecial ? "#facc15" : root.themeText
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    style: Text.Outline
                                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                    elide: Text.ElideRight
                                                    width: parent.width - (isActiveWs ? 52 : 0)
                                                }

                                                Rectangle {
                                                    visible: isActiveWs
                                                    width: 46
                                                    height: 18
                                                    radius: 9
                                                    color: root.themePrimary
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Text {
                                                        text: "ACTIVE"
                                                        color: "#000000"
                                                        font.pixelSize: 9
                                                        font.weight: Font.Bold
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                            }

                                            Flow {
                                                width: parent.width
                                                spacing: 8
                                                visible: modelData.windows.length > 0

                                                Repeater {
                                                    model: modelData.windows.slice(0, 7)

                                                    delegate: Rectangle {
                                                        required property var modelData

                                                        width: 34
                                                        height: 34
                                                        radius: 8
                                                        color: Qt.rgba(0, 0, 0, 0.65)
                                                        border.width: 1
                                                        border.color: Qt.rgba(255, 255, 255, 0.2)

                                                        scale: iconMouse.containsMouse ? 1.15 : 1.0
                                                        Behavior on scale {
                                                            NumberAnimation {
                                                                duration: root.animEnabled ? style.animDuration : 0
                                                                easing.type: style.bounceEasing
                                                                easing.overshoot: style.overshoot
                                                            }
                                                        }

                                                        Image {
                                                            id: imgIcon
                                                            anchors.centerIn: parent
                                                            width: 22
                                                            height: 22
                                                            source: root.formatFileUrl(modelData.icon)
                                                            fillMode: Image.PreserveAspectFit
                                                            asynchronous: true
                                                            visible: modelData.icon !== "" && status === Image.Ready
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: modelData.icon === "" || imgIcon.status !== Image.Ready
                                                            text: modelData.class.substring(0, 2).toUpperCase()
                                                            color: root.themeText
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                        }

                                                        ToolTip.visible: iconMouse.containsMouse
                                                        ToolTip.delay: 200
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
                                                    visible: modelData.windows.length > 7
                                                    width: 34
                                                    height: 34
                                                    radius: 8
                                                    color: Qt.rgba(0, 0, 0, 0.75)
                                                    border.width: 1
                                                    border.color: root.themePrimary

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "+" + (modelData.windows.length - 7)
                                                        color: root.themeText
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: root.themeRounding
                                            color: "transparent"
                                            border.width: cardItem.isSelected ? Math.max(2, root.themeBorderSize + 1) : Math.max(1, root.themeBorderSize)
                                            border.color: cardItem.isSelected 
                                                ? root.themePrimary 
                                                : (cardItem.isActiveWs ? Qt.alpha(root.themeBorder, 0.9) : Qt.alpha(root.themeBorder, 0.45))
                                            z: 10

                                            Behavior on border.color { 
                                                ColorAnimation { 
                                                    duration: root.animEnabled ? style.fadeDuration : 0 
                                                    easing.type: style.fadeEasing 
                                                } 
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: root.selectedIndex = index
                                            onClicked: root.switchToWorkspace(modelData)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Arrow Keys / Mouse to navigate  •  Enter / Click to switch  •  Esc to exit"
                                color: root.themeTextMuted
                                font.pixelSize: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}