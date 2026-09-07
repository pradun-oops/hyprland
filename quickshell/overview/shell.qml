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

    // ============================================================
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeBackground: "#141416"
    
    property int themeRounding: 24
    property int themeBorderSize: 1
    property bool animEnabled: true
    property int animDuration: 220 

    // ANIMATION & STATE TRACKING
    property bool isOpened: false
    property bool isClosing: false
    property string activeCursorMonitor: ""

    property int selectedIndex: 0
    property var workspaceList: []
    property string wallpaperPath: ""

    // ============================================================
    // WALLPAPER FAST-CACHE FILE WATCHER
    // ============================================================
    FileView {
        id: wallpaperCacheFile
        path: Quickshell.env("HOME") + "/.cache/qs_wallpaper_path"
        watchChanges: true
        onLoaded: {
            let p = text().trim()
            if (p.length > 0) {
                root.wallpaperPath = p
            }
        }
    }

    FileView {
        id: defaultWpCache
        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        watchChanges: true
        onLoaded: {
            let p = text().trim()
            if (root.wallpaperPath === "" && p.length > 0) {
                root.wallpaperPath = p
            }
        }
    }

    // ============================================================
    // CONFIG PARSERS
    // ============================================================
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
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 80
            } catch (e) {}
        }
    }

    // ============================================================
    // CURSOR MONITOR DETECTION PROCESS
    // ============================================================
    Process {
        id: cursorMonitorProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim();
                
                if (found !== "") {
                    root.activeCursorMonitor = found;
                } else {
                    // Fallbacks if Python script unexpectedly fails
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
        // Robust Python script to pinpoint the monitor based on layout coordinates & cursor position
        let pyScript = `
import json, subprocess
try:
    c = json.loads(subprocess.check_output('hyprctl cursorpos -j', shell=True))
    m = json.loads(subprocess.check_output('hyprctl monitors -j', shell=True))
    cx, cy = c.get('x',0), c.get('y',0)
    res = ''
    
    # 1. Fallback: find focused monitor first
    for mon in m:
        if mon.get('focused'): 
            res = mon['name']
            
    # 2. Strict Check: find the monitor bounds exactly matching the cursor
    for mon in m:
        mx, my = mon.get('x',0), mon.get('y',0)
        scale = mon.get('scale', 1.0)
        # Hyprland layout coordinates use logical dimensions (width/scale)
        w, h = mon.get('width', 1920)/scale, mon.get('height', 1080)/scale
        
        # Handle portrait/rotated monitors swapping width & height
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

    // ============================================================
    // DISPATCH & CLOSE LOGIC
    // ============================================================
    Timer { 
        id: closeTimer
        interval: 50 
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

        closeTimer.interval = 50;
        closeTimer.start();
    }

    function dismissMenu() {
        if (root.isClosing) return;
        root.isClosing = true;
        closeTimer.interval = 50;
        closeTimer.start();
    }

    // ============================================================
    // HYPRLAND WORKSPACE, APP ICON & WALLPAPER POLLING
    // ============================================================
    Process {
        id: fetchWsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim())
                    root.workspaceList = parsed.workspaces || []
                    if (parsed.wallpaper) {
                        root.wallpaperPath = parsed.wallpaper
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
import subprocess, json, os, re

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

def get_wallpaper():
    cached_file = os.path.expanduser("~/.cache/qs_wallpaper_path")
    
    found_path = ""
    try:
        out = subprocess.check_output("swww query 2>/dev/null", shell=True, text=True)
        for line in out.splitlines():
            for chunk in line.split():
                clean = chunk.strip(",'\\"")
                if clean.startswith("/") and os.path.isfile(clean):
                    found_path = clean
                    break
            if found_path: break
    except Exception: pass

    if not found_path:
        try:
            out = subprocess.check_output("hyprctl hyprpaper listactive 2>/dev/null", shell=True, text=True)
            for line in out.splitlines():
                if "=" in line:
                    p = line.split("=")[1].strip()
                    if os.path.isfile(p): 
                        found_path = p
                        break
                elif "/" in line and os.path.isfile(line.strip()):
                    found_path = line.strip()
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
        for p in [os.path.join(home, ".cache", "current_wallpaper"), os.path.join(home, ".config", "hypr", "wallpaper")]:
            if os.path.exists(p):
                real_p = os.path.realpath(p)
                if os.path.isfile(real_p): 
                    found_path = real_p
                    break

    if found_path:
        try:
            os.makedirs(os.path.dirname(cached_file), exist_ok=True)
            with open(cached_file, "w") as f:
                f.write(found_path)
        except Exception: pass

    return found_path

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
    ws_data = json.loads(subprocess.check_output("hyprctl workspaces -j", shell=True) or "[]")
    clients_data = json.loads(subprocess.check_output("hyprctl clients -j", shell=True) or "[]")
    active_ws = json.loads(subprocess.check_output("hyprctl activeworkspace -j", shell=True) or "{}")
except Exception:
    ws_data, clients_data, active_ws = [], [], {}

active_id = active_ws.get("id", 1)
wallpaper = get_wallpaper()

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

print(json.dumps({"wallpaper": wallpaper, "workspaces": result}))
`
                fetchWsProcess.command = ["python3", "-c", pyScript]
                fetchWsProcess.running = true
            }
        }
    }

    // ============================================================
    // MULTI-MONITOR OVERLAY & MODAL DIALOG CONTAINER
    // ============================================================
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

            visible: isTargetMonitor && !root.isClosing

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            // Fullscreen Dim Overlay
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.isOpened && !root.isClosing ? 0.65 : 0.0

                Behavior on opacity { 
                    NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutCubic } 
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismissMenu()
                }
            }

            // Centered Modal Container
            Item {
                id: mainContainer
                anchors.centerIn: parent
                implicitWidth: cardColumn.implicitWidth + 48
                implicitHeight: cardColumn.implicitHeight + 48

                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }

                // KEYBOARD NAVIGATION
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

                // MODAL CARD BOX
                Rectangle {
                    id: cardRect
                    anchors.fill: parent

                    radius: root.themeRounding
                    color: root.themeBackground
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)

                    opacity: root.isClosing ? 0 : (root.isOpened ? 1.0 : 0.0)
                    scale: root.isClosing ? 0.95 : (root.isOpened ? 1.0 : 0.95)

                    Behavior on opacity { 
                        NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutCubic } 
                    }
                    Behavior on scale { 
                        NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutBack } 
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

                                delegate: Rectangle {
                                    id: cardItem
                                    required property var modelData
                                    required property int index

                                    width: 220
                                    height: 140

                                    radius: root.themeRounding

                                    property bool isSelected: index === root.selectedIndex
                                    property bool isActiveWs: modelData.isActive

                                    z: isSelected ? 10 : 1
                                    scale: isSelected ? 1.08 : 1.0

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? 150 : 0
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    color: root.themeBackground

                                    Item {
                                        id: cardBgSource
                                        anchors.fill: parent
                                        visible: false

                                        Image {
                                            anchors.fill: parent
                                            source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#000000"
                                            opacity: 0.25
                                        }
                                    }

                                    Rectangle {
                                        id: cardBgMask
                                        anchors.fill: parent
                                        radius: root.themeRounding
                                        color: "black"
                                        visible: false
                                        layer.enabled: true
                                    }

                                    MultiEffect {
                                        anchors.fill: parent
                                        source: cardBgSource
                                        maskEnabled: true
                                        maskSource: cardBgMask
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

                                                    Image {
                                                        id: imgIcon
                                                        anchors.centerIn: parent
                                                        width: 22
                                                        height: 22
                                                        source: modelData.icon !== "" ? "file://" + modelData.icon : ""
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
                                        z: 100

                                        Behavior on border.color { ColorAnimation { duration: 150 } }
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