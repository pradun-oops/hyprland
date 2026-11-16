import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeOnPrimary: "#141416"

    property int themeRounding: 18
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25
    property bool animEnabled: true
    property int animDuration: 260

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.52)

    QtObject {
        id: style
        property int moduleSpacing: 6
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 280) : 240
        property int fadeDuration: 180
        property var smoothEasing: Easing.OutCubic
        property var fadeEasing: Easing.OutCubic
        property color hoverColor: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        property color pillBg: Qt.rgba(0.02, 0.02, 0.03, 0.46)
        property color pillBorder: Qt.rgba(1.0, 1.0, 1.0, 0.09)
        property color separatorColor: Qt.rgba(1.0, 1.0, 1.0, 0.14)
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property string currentTime: ""
    property string currentDate: ""

    property string rxSpeed: "0"
    property string rxUnit: "KB/s"
    property string txSpeed: "0"
    property string txUnit: "KB/s"
    property real lastRx: 0
    property real lastTx: 0
    property real lastNetTime: 0

    property string cpuTemp: "0"
    property string gpuTemp: "0"
    property int volumePct: 0
    property bool isMuted: false
    property string batCap: "100"
    property bool isCharging: false
    property bool isPlaying: false

    property int activeWs: 1
    property var activeWorkspaces: [1, 2, 3, 4, 5]

    property var runningAppsList: []

    property int barY: 8
    property int islandHeight: 40

    function getBatIcon(pct, charging) {
        if (charging) return "󰂄"
        if (pct > 90) return "󰁹"
        if (pct > 80) return "󰂂"
        if (pct > 60) return "󰁿"
        if (pct > 40) return "󰁽"
        if (pct > 20) return "󰁻"
        return "󰂃"
    }

    function getVolIcon(pct, muted) {
        if (muted || pct === 0) return "󰖁"
        if (pct > 60) return "󰕾"
        if (pct > 25) return "󰖀"
        return "󰕿"
    }

    function switchToWorkspace(wsId) {
        if (!wsId) return
        root.activeWs = wsId
        let targetId = String(wsId)
        let luaCmd = "hl.dsp.focus({ workspace = \"" + targetId + "\" })"

        try {
            Hyprland.dispatch(luaCmd)
        } catch (e) {}

        Quickshell.execDetached(["hyprctl", "dispatch", luaCmd])
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", targetId])
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
                    root.themeBorder = "#" + match[1]
                    root.themePrimary = "#" + match[1]
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

    function updateClock() {
        let now = new Date()
        let rawHours = now.getHours()
        let period = rawHours >= 12 ? "PM" : "AM"
        let hours12 = rawHours % 12 || 12
        let mins = now.getMinutes().toString().padStart(2, "0")
        root.currentTime = hours12.toString().padStart(2, "0") + ":" + mins + " " + period

        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        root.currentDate = days[now.getDay()] + ", " + now.getDate().toString().padStart(2, "0") + " " + months[now.getMonth()]
    }

    Component.onCompleted: {
        updateClock()
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    function refreshVolumeSoon() {
        volRefreshDelay.restart()
    }

    Timer {
        id: volRefreshDelay
        interval: 60
        repeat: false
        onTriggered: {
            if (!volProcess.running) {
                volProcess.command = ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                volProcess.running = true
            }
        }
    }

    Process {
        id: runningAppsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    if (Array.isArray(data)) {
                        root.runningAppsList = data
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!runningAppsProcess.running) {
                let py = `
import subprocess, json, os

HOME = os.path.expanduser("~")

app_defs = [
    {"process": "easyeffects", "glyph": "󰺢", "icon_names": ["com.github.wwmm.easyeffects", "easyeffects", "audio-adjust"]},
    {"process": "discord", "glyph": "󰙯", "icon_names": ["discord", "com.discordapp.Discord"]},
    {"process": "vesktop", "glyph": "󰙯", "icon_names": ["vesktop", "discord"]},
    {"process": "spotify", "glyph": "󰓇", "icon_names": ["spotify", "spotify-client", "spotify-desktop"]},
    {"process": "telegram-desktop", "glyph": "󰔁", "icon_names": ["telegram", "telegram-desktop", "org.telegram.desktop"]},
    {"process": "steam", "glyph": "󰓓", "icon_names": ["steam", "com.valvesoftware.Steam"]}
]

icon_roots = [
    os.path.join(HOME, ".local/share/icons/WhiteSur"),
    os.path.join(HOME, ".local/share/icons/WhiteSur-dark"),
    "/usr/share/icons/WhiteSur",
    "/usr/share/icons/Papirus",
    "/usr/share/icons/hicolor",
    "/usr/share/icons/Adwaita"
]

sub_dirs = [
    "apps/scalable",
    "scalable/apps",
    "48x48/apps",
    "apps/48",
    "64x64/apps",
    "128x128/apps",
    "32x32/apps"
]

def get_icon_path(icon_names):
    for name in icon_names:
        for root_dir in icon_roots:
            if not os.path.exists(root_dir):
                continue
            for sub in sub_dirs:
                for ext in ['svg', 'png']:
                    p = os.path.join(root_dir, sub, f"{name}.{ext}")
                    if os.path.exists(p):
                        return "file://" + p
        for ext in ['.svg', '.png', '.xpm']:
            p = f"/usr/share/pixmaps/{name}{ext}"
            if os.path.exists(p):
                return "file://" + p
    return ""

running = []
for app in app_defs:
    try:
        res = subprocess.run(["pgrep", "-x", app["process"]], stdout=subprocess.DEVNULL)
        if res.returncode == 0:
            ipath = get_icon_path(app["icon_names"])
            running.append({"process": app["process"], "icon": ipath, "glyph": app["glyph"]})
    except Exception:
        pass
print(json.dumps(running))
`
                runningAppsProcess.command = ["python3", "-c", py]
                runningAppsProcess.running = true
            }
        }
    }

    Process {
        id: mediaProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let status = text.trim()
                root.isPlaying = (status === "Playing")
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!mediaProcess.running) {
                mediaProcess.command = ["playerctl", "status"]
                mediaProcess.running = true
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateClock()
    }

    Process {
        id: volProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (out.includes("Volume:")) {
                    let parts = out.split(/\s+/)
                    if (parts.length >= 2) {
                        root.volumePct = Math.min(100, Math.round(parseFloat(parts[1]) * 100) || 0)
                        root.isMuted = out.includes("[MUTED]") || out.includes("MUTED")
                    }
                }
            }
        }
    }

    Timer {
        interval: 600
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!volProcess.running) {
                volProcess.command = ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                volProcess.running = true
            }
        }
    }

    Process {
        id: wsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    if (data.active !== undefined) root.activeWs = data.active
                    if (data.list && data.list.length > 0) root.activeWorkspaces = data.list
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
            if (!wsProcess.running) {
                let pyScript = `
import subprocess, json
try:
    a_raw = subprocess.run(["hyprctl", "activeworkspace", "-j"], capture_output=True, text=True).stdout
    w_raw = subprocess.run(["hyprctl", "workspaces", "-j"], capture_output=True, text=True).stdout
    a = json.loads(a_raw) if a_raw else {}
    w = json.loads(w_raw) if w_raw else []
    active = a.get('id', 1)
    ws = set(range(1, 6))
    if active > 0:
        ws.add(active)
    for x in w:
        if x.get('id', 0) > 0:
            ws.add(x['id'])
    print(json.dumps({'active': active, 'list': sorted(list(ws))}))
except Exception:
    print(json.dumps({'active': 1, 'list': [1, 2, 3, 4, 5]}))
`
                wsProcess.command = ["python3", "-c", pyScript]
                wsProcess.running = true
            }
        }
    }

    Process {
        id: hardwareProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let output = text.trim()
                    if (!output) return
                    let data = JSON.parse(output)

                    root.cpuTemp = data.cpu
                    root.gpuTemp = data.gpu
                    root.batCap = data.bat
                    root.isCharging = data.charging

                    let nowMs = Date.now()
                    if (root.lastRx > 0 && root.lastTx > 0 && root.lastNetTime > 0) {
                        let dt = Math.max(0.2, (nowMs - root.lastNetTime) / 1000.0)
                        let rxDiff = Math.max(0, (data.rx - root.lastRx) / dt) / 1024.0
                        let txDiff = Math.max(0, (data.tx - root.lastTx) / dt) / 1024.0

                        root.rxSpeed = rxDiff >= 1000 ? (rxDiff / 1024.0).toFixed(1) : rxDiff.toFixed(0)
                        root.rxUnit = rxDiff >= 1000 ? "MB/s" : "KB/s"

                        root.txSpeed = txDiff >= 1000 ? (txDiff / 1024.0).toFixed(1) : txDiff.toFixed(0)
                        root.txUnit = txDiff >= 1000 ? "MB/s" : "KB/s"
                    }
                    root.lastRx = data.rx
                    root.lastTx = data.tx
                    root.lastNetTime = nowMs
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!hardwareProcess.running) {
                let pyScript = `
import glob, json, os, subprocess

cpu = 0
for tz in glob.glob('/sys/class/thermal/thermal_zone*'):
    try:
        with open(tz + '/type') as f:
            t = f.read().strip()
            if any(x in t for x in ['x86_pkg_temp', 'coretemp', 'Tdie', 'cpu']):
                with open(tz + '/temp') as tf:
                    cpu = int(tf.read().strip()) // 1000
                    break
    except Exception:
        pass
if cpu == 0:
    try:
        with open('/sys/class/thermal/thermal_zone0/temp') as f:
            cpu = int(f.read().strip()) // 1000
    except Exception:
        cpu = 0

gpu = "0"
try:
    res = subprocess.run(["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader"], capture_output=True, text=True, timeout=1)
    if res.returncode == 0 and res.stdout.strip():
        gpu = res.stdout.strip()
except Exception:
    pass

bat = "100"
for b in glob.glob('/sys/class/power_supply/BAT*/capacity'):
    try:
        with open(b) as f:
            bat = f.read().strip()
            break
    except Exception:
        pass

charging = False
for s in glob.glob('/sys/class/power_supply/BAT*/status'):
    try:
        with open(s) as f:
            st = f.read().strip()
            if "Charging" in st or "Full" in st:
                charging = ("Charging" in st)
                break
    except Exception:
        pass

rx = 0
tx = 0
for path in glob.glob('/sys/class/net/[ew]*/statistics/rx_bytes'):
    try:
        with open(path) as f:
            rx += int(f.read().strip())
    except Exception:
        pass

for path in glob.glob('/sys/class/net/[ew]*/statistics/tx_bytes'):
    try:
        with open(path) as f:
            tx += int(f.read().strip())
    except Exception:
        pass

print(json.dumps({
    "cpu": str(cpu), "gpu": gpu, "bat": bat, "charging": charging,
    "rx": rx, "tx": tx
}))
`
                hardwareProcess.command = ["python3", "-c", pyScript]
                hardwareProcess.running = true
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-bar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusiveZone: 42

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 50
            color: "transparent"

            Item {
                anchors.fill: parent

                Rectangle {
                    id: barIsland

                    x: Math.round((parent.width - width) / 2)
                    y: root.barY
                    height: root.islandHeight

                    HoverHandler { id: islandHover }
                    property bool isPinned: false
                    property bool isExpanded: isPinned || islandHover.hovered

                    property int expandedWidth: expandedRow.implicitWidth + 20
                    property int collapsedWidth: collapsedRow.implicitWidth + 28

                    width: isExpanded ? expandedWidth : collapsedWidth

                    Behavior on width {
                        NumberAnimation {
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.smoothEasing
                        }
                    }

                    Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                    Behavior on border.color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }

                    radius: Math.min(height / 2, root.themeRounding)
                    color: Qt.alpha(root.themeBackground, barIsland.isExpanded ? Math.min(0.76, root.themeBgAlpha + 0.12) : root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: barIsland.isPinned
                                  ? Qt.alpha(root.themePrimary, 0.78)
                                  : Qt.alpha(root.themeBorder, barIsland.isExpanded ? 0.55 : 0.42)
                    antialiasing: true
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.themeBorderSize
                        radius: Math.max(0, parent.radius - root.themeBorderSize)
                        antialiasing: true
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                            GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: barIsland.isPinned = !barIsland.isPinned
                    }

                    Row {
                        id: collapsedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: 10
                        opacity: barIsland.isExpanded ? 0.0 : 1.0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation {
                                duration: style.fadeDuration
                                easing.type: style.fadeEasing
                            }
                        }

                        Row {
                            spacing: 2.5
                            visible: root.isPlaying
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    width: 3
                                    height: 10
                                    radius: 1.5
                                    color: root.themePrimary
                                    anchors.verticalCenter: parent.verticalCenter

                                    SequentialAnimation on height {
                                        running: root.isPlaying && !barIsland.isExpanded
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 4 + ((index * 3) % 8); duration: 300 + index * 45; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 14 - ((index * 2) % 6); duration: 350 - index * 35; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.currentTime !== "" ? root.currentTime : "12:00 PM"
                            color: root.themeText
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.family: root.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                        }
                    }

                    Row {
                        id: expandedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: style.moduleSpacing
                        opacity: barIsland.isExpanded ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation {
                                duration: style.fadeDuration
                                easing.type: style.fadeEasing
                            }
                        }

                        Rectangle {
                            height: root.islandHeight - 10
                            width: wsRow.implicitWidth + 10
                            radius: height / 2
                            color: style.pillBg
                            border.width: 1
                            border.color: style.pillBorder
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    let list = root.activeWorkspaces
                                    if (!list || list.length === 0) return
                                    let idx = list.indexOf(root.activeWs)
                                    if (idx === -1) idx = 0
                                    if (wheel.angleDelta.y < 0) {
                                        root.switchToWorkspace(list[(idx + 1) % list.length])
                                    } else if (wheel.angleDelta.y > 0) {
                                        root.switchToWorkspace(list[(idx - 1 + list.length) % list.length])
                                    }
                                }
                            }

                            Row {
                                id: wsRow
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: root.activeWorkspaces
                                    delegate: Rectangle {
                                        property bool isCurrent: modelData === root.activeWs
                                        width: isCurrent ? 28 : 22
                                        height: 22
                                        radius: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: isCurrent
                                               ? root.themePrimary
                                               : (wsMouse.containsMouse ? style.hoverColor : "transparent")
                                        antialiasing: true

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: root.animEnabled ? 180 : 0
                                                easing.type: style.smoothEasing
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: style.fadeDuration
                                                easing.type: style.fadeEasing
                                            }
                                        }

                                        Text {
                                            text: modelData
                                            color: parent.isCurrent
                                                   ? root.themeOnPrimary
                                                   : (wsMouse.containsMouse ? root.themeText : root.themeTextMuted)
                                            font.pixelSize: 11
                                            font.weight: parent.isCurrent ? Font.ExtraBold : Font.Bold
                                            font.family: root.fontFamily
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: wsMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.switchToWorkspace(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: root.islandHeight - 10
                            width: netRow.implicitWidth + 18
                            radius: height / 2
                            color: style.pillBg
                            border.width: 1
                            border.color: style.pillBorder
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true

                            Row {
                                id: netRow
                                anchors.centerIn: parent
                                spacing: 10

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        text: "󰁅"
                                        color: "#38bdf8"
                                        font.pixelSize: 12
                                        font.family: root.iconFontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.rxSpeed
                                        color: root.themeText
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.family: root.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.rxUnit
                                        color: root.themeTextMuted
                                        font.pixelSize: 9
                                        font.weight: Font.SemiBold
                                        font.family: root.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Rectangle {
                                    width: 1
                                    height: 12
                                    color: style.separatorColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        text: "󰁝"
                                        color: root.themePrimary
                                        font.pixelSize: 12
                                        font.family: root.iconFontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.txSpeed
                                        color: root.themeText
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.family: root.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.txUnit
                                        color: root.themeTextMuted
                                        font.pixelSize: 9
                                        font.weight: Font.SemiBold
                                        font.family: root.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: root.islandHeight - 10
                            width: centerRow.implicitWidth + 20
                            radius: height / 2
                            color: centerMouse.containsMouse
                                   ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.72)
                                   : style.pillBg
                            border.width: 1
                            border.color: centerMouse.containsMouse
                                          ? Qt.alpha(root.themePrimary, 0.55)
                                          : style.pillBorder
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                id: centerRow
                                anchors.centerIn: parent
                                spacing: 8

                                Row {
                                    spacing: 2.5
                                    visible: root.isPlaying
                                    anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: 4
                                        delegate: Rectangle {
                                            width: 3
                                            height: 11
                                            radius: 1.5
                                            color: root.themePrimary
                                            anchors.verticalCenter: parent.verticalCenter

                                            SequentialAnimation on height {
                                                running: root.isPlaying && barIsland.isExpanded
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 4 + ((index * 4) % 9); duration: 300 + index * 45; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 15 - ((index * 3) % 7); duration: 360 - index * 35; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: root.currentTime !== "" ? root.currentTime : "12:00 PM"
                                    color: root.themeText
                                    font.pixelSize: 12
                                    font.weight: Font.ExtraBold
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "•"
                                    color: root.themePrimary
                                    font.pixelSize: 11
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.currentDate !== "" ? root.currentDate : "Sun, 15 Nov"
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: barIsland.isPinned
                                    text: "󰐃"
                                    color: root.themePrimary
                                    font.pixelSize: 11
                                    font.family: root.iconFontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: centerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh calendar open")
                                    }
                                }
                                onDoubleClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        barIsland.isPinned = !barIsland.isPinned
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: root.islandHeight - 10
                            width: tempRow.implicitWidth + 18
                            radius: height / 2
                            color: style.pillBg
                            border.width: 1
                            border.color: style.pillBorder
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true

                            Row {
                                id: tempRow
                                anchors.centerIn: parent
                                spacing: 10

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        text: ""
                                        color: parseInt(root.cpuTemp) >= 80 ? "#ff6b6b" : root.themePrimary
                                        font.pixelSize: 12
                                        font.family: root.iconFontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.cpuTemp + "°C"
                                        color: root.themeText
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.family: root.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Rectangle {
                                    width: 1
                                    height: 12
                                    color: style.separatorColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        text: "󰢮"
                                        color: parseInt(root.gpuTemp) >= 80 ? "#ff6b6b" : root.themePrimary
                                        font.pixelSize: 13
                                        font.family: root.iconFontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.gpuTemp + "°C"
                                        color: root.themeText
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.family: root.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: root.islandHeight - 10
                            width: volRow.implicitWidth + 16
                            radius: height / 2
                            color: volMouse.containsMouse
                                   ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.72)
                                   : style.pillBg
                            border.width: 1
                            border.color: volMouse.containsMouse
                                          ? Qt.alpha(root.themePrimary, 0.55)
                                          : style.pillBorder
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                id: volRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: root.getVolIcon(root.volumePct, root.isMuted)
                                    color: root.isMuted ? "#ff6b6b" : root.themePrimary
                                    font.pixelSize: 13
                                    font.family: root.iconFontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration } }
                                }
                                Text {
                                    text: root.volumePct + "%"
                                    color: root.isMuted ? root.themeTextMuted : root.themeText
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: volMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                                        root.refreshVolumeSoon()
                                    } else {
                                        root.exec("pavucontrol")
                                    }
                                }
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) {
                                        if (root.volumePct < 100) {
                                            root.exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
                                            root.refreshVolumeSoon()
                                        }
                                    } else {
                                        root.exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-")
                                        root.refreshVolumeSoon()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: root.islandHeight - 10
                            width: batRow.implicitWidth + 16
                            radius: height / 2
                            color: batMouse.containsMouse
                                   ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.72)
                                   : style.pillBg
                            border.width: 1
                            border.color: batMouse.containsMouse
                                          ? Qt.alpha(root.themePrimary, 0.55)
                                          : style.pillBorder
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                id: batRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: root.getBatIcon(parseInt(root.batCap), root.isCharging)
                                    color: root.isCharging ? "#4ade80" : (parseInt(root.batCap) <= 20 ? "#ff6b6b" : root.themePrimary)
                                    font.pixelSize: 13
                                    font.family: root.iconFontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration } }
                                }
                                Text {
                                    text: root.batCap + "%"
                                    color: root.themeText
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: batMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) root.exec("gnome-power-statistics")
                                }
                                onDoubleClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        let profileCmd = "curr=$(powerprofilesctl get 2>/dev/null | tr -d '[:space:]' || echo 'balanced'); " +
                                                         "if [ \"$curr\" = \"balanced\" ]; then next='performance'; " +
                                                         "elif [ \"$curr\" = \"performance\" ]; then next='power-saver'; " +
                                                         "else next='balanced'; fi; " +
                                                         "powerprofilesctl set $next && notify-send 'Power Profile' \"Switched to $next\" -t 2000"
                                        root.exec(profileCmd)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: appsDrawer
                            height: root.islandHeight - 10
                            width: root.runningAppsList.length > 0 ? (appsHover.hovered ? appsRow.implicitWidth + 36 : 28) : 0
                            radius: height / 2
                            color: appsHover.hovered ? style.pillBg : Qt.rgba(1, 1, 1, 0.05)
                            border.width: root.runningAppsList.length > 0 ? 1 : 0
                            border.color: appsHover.hovered ? Qt.alpha(root.themePrimary, 0.45) : style.pillBorder
                            visible: root.runningAppsList.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                            clip: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: root.animEnabled ? style.animDuration : 0
                                    easing.type: style.smoothEasing
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            HoverHandler { id: appsHover }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                x: 7

                                Text {
                                    text: appsHover.hovered ? "󰅁" : "󰅂"
                                    color: root.themePrimary
                                    font.pixelSize: 13
                                    font.family: root.iconFontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Row {
                                    id: appsRow
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: appsHover.hovered ? 1.0 : 0.0
                                    visible: opacity > 0.01

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: style.fadeDuration
                                            easing.type: style.fadeEasing
                                        }
                                    }

                                    Repeater {
                                        model: root.runningAppsList
                                        delegate: Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: appItemMouse.containsMouse ? style.hoverColor : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            antialiasing: true
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Image {
                                                id: trayIconImg
                                                anchors.centerIn: parent
                                                width: 15
                                                height: 15
                                                sourceSize: Qt.size(30, 30)
                                                source: modelData.icon || ""
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                visible: modelData.icon !== "" && status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !trayIconImg.visible
                                                text: modelData.glyph || "󰀻"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 12
                                                color: root.themePrimary
                                            }

                                            MouseArea {
                                                id: appItemMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: (mouse) => {
                                                    if (mouse.button === Qt.RightButton) root.exec("pkill -x " + modelData.process)
                                                    else root.exec(modelData.process)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            height: root.islandHeight - 10
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: netMouse.containsMouse
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.78)
                                       : style.pillBg
                                border.width: 1
                                border.color: netMouse.containsMouse
                                              ? Qt.alpha(root.themePrimary, 0.60)
                                              : style.pillBorder
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖩"
                                    color: root.themePrimary
                                    font.pixelSize: 14
                                    font.family: root.iconFontFamily
                                }
                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh connection open")
                                }
                            }

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: pwrBarMouse.containsMouse
                                       ? Qt.rgba(0.93, 0.26, 0.26, 0.34)
                                       : style.pillBg
                                border.width: 1
                                border.color: pwrBarMouse.containsMouse ? "#ff6b6b" : style.pillBorder
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐥"
                                    color: pwrBarMouse.containsMouse ? "#ff6b6b" : root.themePrimary
                                    font.pixelSize: 14
                                    font.family: root.iconFontFamily
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration } }
                                }
                                MouseArea {
                                    id: pwrBarMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh powermenu open")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}