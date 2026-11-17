import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"
    property string targetMonitorName: ""

    property bool animEnabled: true
    property int animDuration: 220
    property bool isClosing: false

    QtObject {
        id: animStyle
        property int base: root.animDuration > 0 ? Math.min(root.animDuration, 260) : 220
        property int enterDuration: Math.round(base * 1.35)
        property int exitDuration: Math.round(base * 0.85)
        property int animDuration: base
        property int morphDuration: Math.round(base * 1.25)
        property int fadeDuration: Math.round(base * 0.8)
        property int microDuration: Math.round(base * 0.65)
        property int scaleDuration: Math.round(base * 1.1)
        property var smoothEasing: Easing.OutQuint
        property var expoEasing: Easing.OutExpo
        property var exitEasing: Easing.InCubic
    }

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        cacheGeneratorProcess.running = false
        Qt.quit()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.quitApp()
    }

    function updateTargetMonitor() {
        if (root.targetMonitorName !== "") return

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.targetMonitorName = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (root.targetMonitorName === "" && Quickshell.screens.length > 0) {
                root.targetMonitorName = Quickshell.screens[0].name
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.updateTargetMonitor()
        }
    }

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.68)
    property color themeSurfaceHover: Qt.rgba(0.08, 0.08, 0.12, 0.78)
    property color themeBorder: "#d6bbfb"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"
    property color themePrimary: "#d6bbfb"
    property color themeOnPrimary: "#141416"

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property string currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string activeWallpaperPath: ""
    property string selectedEngine: "awww"
    property int cacheEpoch: 0

    function formatTitle(filename) {
        if (!filename) return ""
        let dotIdx = filename.lastIndexOf(".")
        let stem = dotIdx > 0 ? filename.substring(0, dotIdx) : filename
        return stem.replace(/[_-]+/g, " ").replace(/\b\w/g, c => c.toUpperCase())
    }

    readonly property string cachePythonScript: `
import os, sys, hashlib, subprocess, json, colorsys
from concurrent.futures import ThreadPoolExecutor

CACHE_DIR = os.path.expanduser("~/.cache/qs_wallpaper_thumbs")
os.makedirs(CACHE_DIR, exist_ok=True)

target_dir = sys.argv[1] if len(sys.argv) > 1 else ""
if not target_dir or not os.path.isdir(target_dir):
    print("[]")
    sys.exit(0)

has_pil = False
try:
    from PIL import Image
    has_pil = True
except ImportError:
    pass

EXTS = ('.png', '.jpg', '.jpeg', '.webp', '.gif')

def rgb_hex(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(max(0, min(255, int(r))), max(0, min(255, int(g))), max(0, min(255, int(b))))

def extract_palette(img_path):
    primary = "#a78bfa"
    secondary = "#38bdf8"
    tertiary = "#f472b6"
    surface = "#18181b"
    if not has_pil or not os.path.exists(img_path):
        return primary, secondary, tertiary, surface
    try:
        with Image.open(img_path) as im:
            small = im.convert("RGB").resize((32, 32))
            pixels = list(small.getdata())
            scored = []
            avg_r = sum(p[0] for p in pixels) / len(pixels)
            avg_g = sum(p[1] for p in pixels) / len(pixels)
            avg_b = sum(p[2] for p in pixels) / len(pixels)
            surface = rgb_hex(avg_r * 0.22, avg_g * 0.22, avg_b * 0.26)

            for r, g, b in pixels:
                h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                if 0.18 < v < 0.96 and s > 0.18:
                    scored.append((s * (1.0 - abs(v - 0.65)), h, r, g, b))
            scored.sort(reverse=True, key=lambda x: x[0])

            chosen = []
            for _, h, r, g, b in scored:
                if all(min(abs(h - ch), 1.0 - abs(h - ch)) > 0.10 for ch, _, _, _ in chosen):
                    chosen.append((h, r, g, b))
                if len(chosen) >= 3:
                    break

            if len(chosen) >= 1:
                primary = rgb_hex(*chosen[0][1:])
            if len(chosen) >= 2:
                secondary = rgb_hex(*chosen[1][1:])
            elif len(chosen) == 1:
                h, r, g, b = chosen[0]
                nr, ng, nb = colorsys.hsv_to_rgb((h + 0.12) % 1.0, 0.55, 0.85)
                secondary = rgb_hex(nr * 255, ng * 255, nb * 255)
            if len(chosen) >= 3:
                tertiary = rgb_hex(*chosen[2][1:])
            else:
                h = chosen[0][0] if chosen else 0.75
                nr, ng, nb = colorsys.hsv_to_rgb((h + 0.28) % 1.0, 0.50, 0.80)
                tertiary = rgb_hex(nr * 255, ng * 255, nb * 255)
    except Exception:
        pass
    return primary, secondary, tertiary, surface

def process_image(filepath):
    try:
        h = hashlib.md5(filepath.encode('utf-8')).hexdigest()
        out_file = os.path.join(CACHE_DIR, f"{h}.jpg")
        filename = os.path.basename(filepath)
        name_no_ext = os.path.splitext(filename)[0].replace('_', ' ').replace('-', ' ').title()

        mtime = os.path.getmtime(filepath)
        needs_update = not os.path.exists(out_file) or os.path.getmtime(out_file) < mtime

        if needs_update:
            if has_pil:
                with Image.open(filepath) as img:
                    if img.mode != "RGB":
                        img = img.convert("RGB")
                    img.thumbnail((420, 260))
                    img.save(out_file, "JPEG", quality=80)
            else:
                cmd = ["ffmpeg", "-y", "-loglevel", "quiet", "-i", filepath, "-vf", "scale=420:-1", "-vframes", "1", "-q:v", "4", out_file]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        p_col, s_col, t_col, surf_col = extract_palette(out_file if os.path.exists(out_file) else filepath)

        return {
            "name": name_no_ext,
            "fullPath": filepath,
            "thumbFile": out_file,
            "colorPlate": p_col,
            "colorSecondary": s_col,
            "colorTertiary": t_col,
            "colorSurface": surf_col
        }
    except Exception:
        return None

files = []
try:
    for entry in os.scandir(target_dir):
        if entry.is_file() and entry.name.lower().endswith(EXTS):
            files.append(entry.path)
except Exception:
    pass

results = []
if files:
    with ThreadPoolExecutor(max_workers=8) as executor:
        res = list(executor.map(process_image, files))
        results = [r for r in res if r is not None]

results.sort(key=lambda x: x['name'])
print(json.dumps(results))
`

    ListModel {
        id: dynamicThemeModel
    }

    Process {
        id: cacheGeneratorProcess
        property string folderPath: ""
        running: false
        command: ["python3", "-c", root.cachePythonScript, cacheGeneratorProcess.folderPath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isClosing) return
                try {
                    let data = JSON.parse(this.text.trim())
                    dynamicThemeModel.clear()
                    for (let i = 0; i < data.length; i++) {
                        dynamicThemeModel.append(data[i])
                    }
                } catch (e) {}
                root.cacheEpoch++
            }
        }
    }

    function triggerCacheGeneration() {
        if (root.isClosing) return
        let path = String(root.currentFolder).replace("file://", "")
        if (path.length > 0 && path !== "/") {
            if (cacheGeneratorProcess.running) {
                cacheGeneratorProcess.running = false
            }
            cacheGeneratorProcess.folderPath = path
            cacheGeneratorProcess.running = true
        }
    }

    onCurrentFolderChanged: {
        root.triggerCacheGeneration()
    }

    FileView {
        id: activeWpCache1
        path: Quickshell.env("HOME") + "/.cache/qs_wallpaper_path"
        watchChanges: false
        onLoaded: {
            let p = text().trim()
            if (p.length > 0 && root.activeWallpaperPath === "") {
                root.activeWallpaperPath = p
            }
        }
    }

    FileView {
        id: activeWpCache2
        path: Quickshell.env("HOME") + "/.cache/quickshell_last_wallpaper.txt"
        watchChanges: false
        onLoaded: {
            let p = text().trim()
            if (p.length > 0 && root.activeWallpaperPath === "") {
                root.activeWallpaperPath = p
            }
        }
    }

    Process {
        id: detectActiveWpProcess
        command: [
            "bash", "-c",
            "out=$(awww query 2>/dev/null || swww query 2>/dev/null); printf '%s\\n' \"$out\" | grep -oE '/[^\"'\'' ]+\\.(png|jpg|jpeg|webp|gif)' | head -n 1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim()
                if (p.length > 0) {
                    root.activeWallpaperPath = p
                }
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
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (match && match[1]) {
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
                }
                let bgMatch = content.match(/background\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/background\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (bgMatch && bgMatch[1]) root.themeBackground = "#" + bgMatch[1]
            } catch (e) {}
        }
    }

    FileView {
        id: generalConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = Math.max(14, parseInt(rMatch[1]))

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
        id: initFolderCheck
        command: [
            "sh", "-c",
            "if [ -d \"$HOME/Pictures/Wallpapers\" ]; then echo \"$HOME/Pictures/Wallpapers\"; " +
            "elif [ -d \"$HOME/Pictures/wallpapers\" ]; then echo \"$HOME/Pictures/wallpapers\"; " +
            "elif [ -d \"$HOME/wallpapers\" ]; then echo \"$HOME/wallpapers\"; " +
            "else echo \"$HOME/Pictures\"; fi"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isClosing) return
                let dir = this.text.trim()
                if (dir.length > 0 && dir.startsWith("/")) {
                    let targetUrl = "file://" + dir
                    if (root.currentFolder !== targetUrl) {
                        root.currentFolder = targetUrl
                    }
                    root.triggerCacheGeneration()
                }
            }
        }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }
        activeWpCache1.reload()
        activeWpCache2.reload()
        detectActiveWpProcess.running = true
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        root.triggerCacheGeneration()
    }

    Process {
        id: applyWallpaper
        running: false
    }

    function applySelectedWallpaper(path) {
        if (!path || path.length === 0 || root.isClosing) return
        root.activeWallpaperPath = path

        let script =
            "ENGINE=\"$1\"\n" +
            "IMG=\"$2\"\n" +
            "ANIM=\"$3\"\n" +
            "export PATH=\"$PATH:$HOME/.cargo/bin:$HOME/.local/bin\"\n" +
            "if [ ! -f \"$IMG\" ]; then exit 0; fi\n" +
            "mkdir -p \"$HOME/.cache\"\n" +
            "printf '%s\\n' \"$IMG\" > \"$HOME/.cache/qs_wallpaper_path\"\n" +
            "printf '%s\\n' \"$IMG\" > \"$HOME/.cache/quickshell_last_wallpaper.txt\"\n" +
            "if command -v matugen >/dev/null 2>&1; then\n" +
            "    mkdir -p \"$HOME/.config/qt5ct/colors\" \"$HOME/.config/qt6ct/colors\" \"$HOME/.config/gtk-3.0\" \"$HOME/.config/gtk-4.0\" \"$HOME/.config/hypr/configs\"\n" +
            "    matugen image \"$IMG\" -m \"dark\" --source-color-index 0\n" +
            "    cp -a \"$HOME/.config/qt5ct/colors/.\" \"$HOME/.config/qt6ct/colors/\" 2>/dev/null || true\n" +
            "fi\n" +
            "if [ \"$ENGINE\" = \"awww\" ]; then\n" +
            "    if awww -h 2>&1 | grep -q -- '--transition-type'; then\n" +
            "        awww img \"$IMG\" --transition-type \"$ANIM\" --transition-pos 0.5,0.5 --transition-duration 0.5 2>/dev/null || " +
            "        awww -i \"$IMG\" --transition-type \"$ANIM\" 2>/dev/null || " +
            "        awww \"$IMG\" --transition-type \"$ANIM\"\n" +
            "    elif awww -h 2>&1 | grep -q -- '-i'; then\n" +
            "        awww -i \"$IMG\"\n" +
            "    elif awww -h 2>&1 | grep -q 'load'; then\n" +
            "        awww load \"$IMG\"\n" +
            "    else\n" +
            "        awww img \"$IMG\" --transition-type \"$ANIM\" 2>/dev/null || awww \"$IMG\" 2>/dev/null\n" +
            "    fi\n" +
            "fi\n" +
            "hyprctl reload 2>/dev/null || true\n"

        applyWallpaper.running = false
        applyWallpaper.command = [
            "bash",
            "-c",
            script,
            "bash",
            root.selectedEngine,
            path,
            "fade"
        ]
        applyWallpaper.running = true
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: selectorWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-wallselect"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            Shortcut {
                sequence: "Tab"
                onActivated: if (!root.isClosing) mainCard.activeTab = (mainCard.activeTab === 0 ? 1 : 0)
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            mask: Region { item: mainCard }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Item {
                id: mainFocusWrapper
                anchors.fill: parent
                visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }

                Keys.onEscapePressed: root.quitApp()

                Rectangle {
                    id: mainCard
                    width: Math.min(1160, parent.width - 40)
                    height: Math.min(760, parent.height - 64)
                    anchors.centerIn: parent

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.4)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    antialiasing: true
                    clip: true
                    enabled: !root.isClosing

                    property bool shown: false
                    property bool panelVisible: shown && !root.isClosing
                    property int activeTab: 0

                    onActiveTabChanged: {
                        if (activeTab === 0) imageGrid.forceActiveFocus()
                        else themeGrid.forceActiveFocus()
                    }

                    Component.onCompleted: enterTriggerTimer.start()

                    Timer {
                        id: enterTriggerTimer
                        interval: 16
                        repeat: false
                        onTriggered: mainCard.shown = true
                    }

                    opacity: panelVisible ? 1.0 : 0.0

                    transform: [
                        Scale {
                            origin.x: mainCard.width / 2
                            origin.y: mainCard.height / 2
                            xScale: mainCard.panelVisible ? 1.0 : 0.94
                            yScale: mainCard.panelVisible ? 1.0 : 0.94

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        },
                        Translate {
                            y: mainCard.panelVisible ? 0 : 14

                            Behavior on y {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        }
                    ]

                    Behavior on opacity {
                        NumberAnimation {
                            duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => mouse.accepted = true
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 42
                                height: 42
                                radius: headerIconMouse.containsMouse ? 14 : 12
                                color: Qt.alpha(root.themePrimary, headerIconMouse.containsMouse ? 0.24 : 0.18)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, headerIconMouse.containsMouse ? 0.65 : 0.35)
                                Layout.alignment: Qt.AlignVCenter
                                antialiasing: true
                                scale: headerIconMouse.containsMouse ? 1.05 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on radius {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: mainCard.activeTab === 0 ? "󰋩" : "󰏘"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 20
                                    color: root.themePrimary
                                }

                                MouseArea {
                                    id: headerIconMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: mainCard.activeTab === 0 ? "Wallpapers" : "Color Themes"
                                        font.family: root.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        color: root.themeText
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                    }

                                    Rectangle {
                                        visible: opacity > 0.01
                                        opacity: applyWallpaper.running ? 1.0 : 0.0
                                        scale: applyWallpaper.running ? 1.0 : 0.9
                                        Layout.preferredWidth: applyingRow.implicitWidth + 14
                                        Layout.preferredHeight: 20
                                        radius: 6
                                        color: Qt.alpha(root.themePrimary, 0.20)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.45)
                                        antialiasing: true

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        RowLayout {
                                            id: applyingRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                id: syncIcon
                                                text: "󰑮"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 11
                                                color: root.themePrimary

                                                RotationAnimator {
                                                    target: syncIcon
                                                    from: 0
                                                    to: 360
                                                    duration: 900
                                                    loops: Animation.Infinite
                                                    running: applyWallpaper.running && !root.isClosing
                                                }
                                            }

                                            Text {
                                                text: "Applying Matugen..."
                                                font.family: root.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: root.themePrimary
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: root.activeWallpaperPath !== ""
                                          ? ("Active: " + root.formatTitle(root.activeWallpaperPath.split("/").pop()))
                                          : "Select a wallpaper to apply & generate theme"
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 420
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                id: tabSegment
                                Layout.preferredWidth: 214
                                Layout.preferredHeight: 38
                                Layout.alignment: Qt.AlignVCenter
                                radius: 10
                                color: Qt.rgba(0.02, 0.02, 0.03, 0.72)
                                border.width: 1
                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                antialiasing: true

                                Rectangle {
                                    width: (parent.width - 6) / 2
                                    height: parent.height - 6
                                    y: 3
                                    x: mainCard.activeTab === 0 ? 3 : (parent.width / 2)
                                    radius: 8
                                    color: root.mixColor(root.themeBackground, root.themePrimary, 0.28, 0.88)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.72)
                                    antialiasing: true

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "󰋩"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 13
                                                color: mainCard.activeTab === 0 ? root.themePrimary : root.themeTextMuted

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }

                                            Text {
                                                text: "Wallpapers"
                                                font.family: root.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: mainCard.activeTab === 0 ? root.themeText : root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mainCard.activeTab = 0
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "󰏘"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 13
                                                color: mainCard.activeTab === 1 ? root.themePrimary : root.themeTextMuted

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }

                                            Text {
                                                text: "Themes"
                                                font.family: root.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: mainCard.activeTab === 1 ? root.themeText : root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mainCard.activeTab = 1
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 38
                                height: 38
                                radius: closeHover.containsMouse ? 13 : 10
                                color: closeHover.containsMouse
                                       ? Qt.rgba(0.93, 0.26, 0.26, 0.34)
                                       : root.themeSurface
                                border.width: 1
                                border.color: closeHover.containsMouse ? "#ff6b6b" : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                Layout.alignment: Qt.AlignVCenter
                                antialiasing: true
                                scale: closeHover.pressed ? 0.92 : (closeHover.containsMouse ? 1.05 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on radius {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 14
                                    color: closeHover.containsMouse ? "#ff6b6b" : root.themeText

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                }

                                MouseArea {
                                    id: closeHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.quitApp()
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Item {
                                id: wpTabContainer
                                anchors.fill: parent
                                property bool isTabActive: mainCard.activeTab === 0
                                visible: opacity > 0.01
                                opacity: isTabActive ? 1.0 : 0.0
                                scale: isTabActive ? 1.0 : 0.985

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                        easing.type: animStyle.expoEasing
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: folderModel.count === 0
                                    spacing: 12

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 58
                                        height: 58
                                        radius: 16
                                        color: root.themeSurface
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.28)
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰋩"
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 26
                                            color: root.themePrimary
                                            opacity: 0.75
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "No images found in " + String(root.currentFolder).replace("file://", "")
                                        horizontalAlignment: Text.AlignHCenter
                                        color: root.themeTextMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }
                                }

                                GridView {
                                    id: imageGrid
                                    anchors.fill: parent
                                    visible: folderModel.count > 0
                                    clip: true
                                    cacheBuffer: 600
                                    boundsBehavior: Flickable.StopAtBounds

                                    focus: mainCard.activeTab === 0
                                    keyNavigationEnabled: true
                                    keyNavigationWraps: true

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (currentItem) {
                                                root.applySelectedWallpaper(currentItem.fullPath)
                                            }
                                            event.accepted = true
                                        }
                                    }

                                    readonly property int columns: Math.max(1, Math.floor(width / 256))
                                    cellWidth: width > 0 ? Math.floor(width / columns) : 256
                                    cellHeight: Math.floor(cellWidth * 0.65)

                                    add: Transition {
                                        ParallelAnimation {
                                            NumberAnimation {
                                                property: "opacity"
                                                from: 0.0
                                                to: 1.0
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                            NumberAnimation {
                                                property: "scale"
                                                from: 0.95
                                                to: 1.0
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }
                                    }

                                    displaced: Transition {
                                        NumberAnimation {
                                            properties: "x,y"
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }

                                    model: FolderListModel {
                                        id: folderModel
                                        folder: root.currentFolder
                                        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp"]
                                        showDirs: false
                                        caseSensitive: false
                                        sortField: FolderListModel.Time
                                        sortReversed: true
                                    }

                                    ScrollBar.vertical: ScrollBar {
                                        id: wpScroll
                                        visible: imageGrid.visible && wpScroll.size < 1.0
                                        active: imageGrid.moving || imageGrid.flicking || hovered
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: wpScroll.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.45)

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    delegate: Item {
                                        id: cardDelegate
                                        width: imageGrid.cellWidth
                                        height: imageGrid.cellHeight

                                        property string fullPath: model.filePath ? model.filePath : (model.fileUrl ? model.fileUrl.toString().replace("file://", "") : "")
                                        property string thumbFile: Quickshell.env("HOME") + "/.cache/qs_wallpaper_thumbs/" + Qt.md5(fullPath) + ".jpg"
                                        property string niceTitle: root.formatTitle(model.fileName || "")

                                        property bool isActive: root.activeWallpaperPath === fullPath
                                        property bool isHovered: itemMouse.containsMouse || GridView.isCurrentItem

                                        z: isHovered ? 20 : (isActive ? 5 : 1)
                                        scale: itemMouse.pressed ? 0.97 : (isHovered ? 1.035 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Component.onCompleted: {
                                            if (isActive && imageGrid.currentIndex !== index) {
                                                imageGrid.currentIndex = index
                                            }
                                        }

                                        ClippingRectangle {
                                            id: wpClipBox
                                            anchors.fill: parent
                                            anchors.margins: 11
                                            radius: Math.max(10, root.themeRounding - 6)
                                            color: Qt.rgba(0.02, 0.02, 0.03, 0.72)
                                            antialiasing: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰋩"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 24
                                                color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
                                                visible: imgItem.status !== Image.Ready
                                            }

                                            Image {
                                                id: imgItem
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                                sourceSize: Qt.size(420, 260)
                                                smooth: true
                                                antialiasing: true
                                                opacity: status === Image.Ready ? 1.0 : 0.0

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }

                                                property bool fallbackToOriginal: false
                                                source: fallbackToOriginal ? ("file://" + fullPath) : ("file://" + thumbFile)

                                                onStatusChanged: {
                                                    if (status === Image.Error && !fallbackToOriginal) {
                                                        fallbackToOriginal = true
                                                    }
                                                }

                                                Connections {
                                                    target: root
                                                    function onCacheEpochChanged() {
                                                        if (imgItem.fallbackToOriginal) {
                                                            imgItem.fallbackToOriginal = false
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: 48
                                                opacity: (isHovered || isActive) ? 1.0 : 0.78
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: "transparent" }
                                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.86) }
                                                }

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    anchors.bottomMargin: 9
                                                    text: cardDelegate.niceTitle
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: isActive ? root.themePrimary : root.themeText
                                                    elide: Text.ElideRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)

                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: opacity > 0.01
                                                opacity: isActive ? 1.0 : 0.0
                                                scale: isActive ? 1.0 : 0.6
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 10
                                                width: 24
                                                height: 24
                                                radius: 12
                                                color: root.themePrimary
                                                antialiasing: true

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰄬"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: root.themeOnPrimary
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: wpClipBox
                                            radius: wpClipBox.radius
                                            color: "transparent"
                                            border.width: isActive ? 2.5 : (isHovered ? 2 : 1)
                                            border.color: isActive
                                                          ? root.themePrimary
                                                          : (isHovered ? Qt.alpha(root.themePrimary, 0.82) : Qt.rgba(1.0, 1.0, 1.0, 0.14))
                                            antialiasing: true
                                            z: 10

                                            Behavior on border.color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: itemMouse
                                            anchors.fill: wpClipBox
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: imageGrid.currentIndex = index
                                            onClicked: {
                                                imageGrid.currentIndex = index
                                                root.applySelectedWallpaper(fullPath)
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: themeTabContainer
                                anchors.fill: parent
                                property bool isTabActive: mainCard.activeTab === 1
                                visible: opacity > 0.01
                                opacity: isTabActive ? 1.0 : 0.0
                                scale: isTabActive ? 1.0 : 0.985

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                        easing.type: animStyle.expoEasing
                                    }
                                }

                                GridView {
                                    id: themeGrid
                                    anchors.fill: parent
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    focus: mainCard.activeTab === 1
                                    keyNavigationEnabled: true
                                    keyNavigationWraps: true

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (currentItem) {
                                                root.applySelectedWallpaper(currentItem.fullPath)
                                            }
                                            event.accepted = true
                                        }
                                    }

                                    readonly property int columns: Math.max(1, Math.floor(width / 256))
                                    cellWidth: width > 0 ? Math.floor(width / columns) : 256
                                    cellHeight: Math.floor(cellWidth * 0.65)

                                    add: Transition {
                                        ParallelAnimation {
                                            NumberAnimation {
                                                property: "opacity"
                                                from: 0.0
                                                to: 1.0
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                            NumberAnimation {
                                                property: "scale"
                                                from: 0.95
                                                to: 1.0
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }
                                    }

                                    displaced: Transition {
                                        NumberAnimation {
                                            properties: "x,y"
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }

                                    model: dynamicThemeModel

                                    ScrollBar.vertical: ScrollBar {
                                        id: themeScroll
                                        visible: themeGrid.visible && themeScroll.size < 1.0
                                        active: themeGrid.moving || themeGrid.flicking || hovered
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: themeScroll.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.45)

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    delegate: Item {
                                        id: themeDelegate
                                        width: themeGrid.cellWidth
                                        height: themeGrid.cellHeight

                                        property string fullPath: model.fullPath
                                        property bool isActive: root.activeWallpaperPath === model.fullPath
                                        property bool isHovered: themeMouse.containsMouse || GridView.isCurrentItem

                                        z: isHovered ? 20 : (isActive ? 5 : 1)
                                        scale: themeMouse.pressed ? 0.97 : (isHovered ? 1.035 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        ClippingRectangle {
                                            id: themeClipBox
                                            anchors.fill: parent
                                            anchors.margins: 11
                                            radius: Math.max(10, root.themeRounding - 6)
                                            color: model.colorSurface || root.themeSurface
                                            antialiasing: true

                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0

                                                Item {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: model.colorPlate }
                                                            GradientStop { position: 0.55; color: model.colorSecondary || model.colorPlate }
                                                            GradientStop { position: 1.0; color: model.colorTertiary || model.colorPlate }
                                                        }
                                                    }

                                                    Image {
                                                        id: themeThumbImg
                                                        anchors.fill: parent
                                                        source: model.thumbFile ? ("file://" + model.thumbFile) : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        opacity: status === Image.Ready ? (isHovered ? 0.42 : 0.32) : 0.0
                                                        asynchronous: true
                                                        smooth: true

                                                        Behavior on opacity {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: opacity > 0.01
                                                        opacity: isActive ? 1.0 : 0.0
                                                        scale: isActive ? 1.0 : 0.6
                                                        anchors.top: parent.top
                                                        anchors.right: parent.right
                                                        anchors.margins: 10
                                                        width: 24
                                                        height: 24
                                                        radius: 12
                                                        color: root.themePrimary
                                                        antialiasing: true

                                                        Behavior on opacity {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on scale {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "󰄬"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 13
                                                            font.weight: Font.Bold
                                                            color: root.themeOnPrimary
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 54
                                                    color: Qt.rgba(0.02, 0.02, 0.03, 0.84)

                                                    Rectangle {
                                                        anchors.top: parent.top
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        height: 1
                                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 12
                                                        anchors.rightMargin: 12
                                                        spacing: 10

                                                        Row {
                                                            spacing: isHovered ? -2 : -5
                                                            Layout.alignment: Qt.AlignVCenter

                                                            Behavior on spacing {
                                                                NumberAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                                    easing.type: animStyle.smoothEasing
                                                                }
                                                            }

                                                            Rectangle {
                                                                width: 20
                                                                height: 20
                                                                radius: 10
                                                                color: model.colorPlate
                                                                border.width: 1.5
                                                                border.color: "#141416"
                                                                antialiasing: true
                                                            }

                                                            Rectangle {
                                                                width: 20
                                                                height: 20
                                                                radius: 10
                                                                color: model.colorSecondary || model.colorPlate
                                                                border.width: 1.5
                                                                border.color: "#141416"
                                                                antialiasing: true
                                                            }

                                                            Rectangle {
                                                                width: 20
                                                                height: 20
                                                                radius: 10
                                                                color: model.colorTertiary || model.colorPlate
                                                                border.width: 1.5
                                                                border.color: "#141416"
                                                                antialiasing: true
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            spacing: 1

                                                            Text {
                                                                text: model.name
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 11
                                                                font.weight: Font.Bold
                                                                color: isActive ? root.themePrimary : root.themeText
                                                                style: Text.Raised
                                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                                elide: Text.ElideRight
                                                                Layout.fillWidth: true

                                                                Behavior on color {
                                                                    ColorAnimation {
                                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                        easing.type: animStyle.smoothEasing
                                                                    }
                                                                }
                                                            }

                                                            Text {
                                                                text: String(model.colorPlate).toUpperCase()
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 9
                                                                font.weight: Font.Medium
                                                                color: root.themeTextMuted
                                                                style: Text.Raised
                                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: themeClipBox
                                            radius: themeClipBox.radius
                                            color: "transparent"
                                            border.width: isActive ? 2.5 : (isHovered ? 2 : 1)
                                            border.color: isActive
                                                          ? root.themePrimary
                                                          : (isHovered ? model.colorPlate : Qt.rgba(1.0, 1.0, 1.0, 0.14))
                                            antialiasing: true
                                            z: 10

                                            Behavior on border.color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: themeMouse
                                            anchors.fill: themeClipBox
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: themeGrid.currentIndex = index
                                            onClicked: {
                                                themeGrid.currentIndex = index
                                                root.applySelectedWallpaper(model.fullPath)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: root.themeSurface
                            border.width: 1
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                            radius: 10
                            antialiasing: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: "󰉋"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 13
                                    color: root.themePrimary
                                }

                                Text {
                                    text: (mainCard.activeTab === 0 ? folderModel.count : dynamicThemeModel.count) + " items • " + String(root.currentFolder).replace("file://", "")
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 8

                                    Rectangle {
                                        width: 34
                                        height: 22
                                        radius: 6
                                        color: tabKeyMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.alpha(root.themePrimary, 0.18)
                                        border.width: 1
                                        border.color: tabKeyMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themePrimary, 0.35)
                                        antialiasing: true
                                        scale: tabKeyMouse.pressed ? 0.92 : (tabKeyMouse.containsMouse ? 1.05 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "TAB"
                                            font.family: root.fontFamily
                                            font.pixelSize: 9
                                            color: root.themePrimary
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: tabKeyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mainCard.activeTab = (mainCard.activeTab === 0 ? 1 : 0)
                                        }
                                    }

                                    Text {
                                        text: "Switch"
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.themeTextMuted
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    Rectangle {
                                        width: 30
                                        height: 22
                                        radius: 6
                                        color: Qt.alpha(root.themePrimary, 0.18)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.35)
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰌑"
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 12
                                            color: root.themePrimary
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Text {
                                        text: "Apply"
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.themeTextMuted
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    Rectangle {
                                        width: 34
                                        height: 22
                                        radius: 6
                                        color: escKeyMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.alpha(root.themePrimary, 0.18)
                                        border.width: 1
                                        border.color: escKeyMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themePrimary, 0.35)
                                        antialiasing: true
                                        scale: escKeyMouse.pressed ? 0.92 : (escKeyMouse.containsMouse ? 1.05 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "ESC"
                                            font.family: root.fontFamily
                                            font.pixelSize: 9
                                            color: root.themePrimary
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: escKeyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.quitApp()
                                        }
                                    }

                                    Text {
                                        text: "Close"
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.themeTextMuted
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
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