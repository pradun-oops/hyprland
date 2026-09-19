import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 18 // Slightly higher for a better pill shape
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.65 // Slightly more opaque for better text contrast
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    QtObject {
        id: style
        property int moduleSpacing: 6
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 250
        property var smoothEasing: Easing.OutQuart
        property var fadeEasing: Easing.OutCubic
        property color hoverColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.12)
        property color separatorColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.15)
    }

    property string currentTime: ""
    property string currentDate: ""
    
    property string rxSpeed: "0"
    property string rxUnit: "KB/s"
    property string txSpeed: "0"
    property string txUnit: "KB/s"
    property real lastRx: 0
    property real lastTx: 0
    
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
    property int islandHeight: 38

    // --- Helper Functions for Dynamic Icons ---
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
        if (pct > 60) return ""
        if (pct > 25) return ""
        return ""
    }
    // ------------------------------------------

    function switchToWorkspace(wsId) {
        if (!wsId) return
        root.activeWs = wsId
        let targetId = String(wsId)
        let luaCmd = "hl.dsp.focus({ workspace = \"" + targetId + "\" })"

        try {
            Hyprland.dispatch(luaCmd)
        } catch(e) {}

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
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
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
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
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

    function updateClock() {
        let now = new Date()
        let rawHours = now.getHours()
        let period = rawHours >= 12 ? "PM" : "AM"
        let hours12 = rawHours % 12 || 12
        let mins = now.getMinutes().toString().padStart(2, '0')
        root.currentTime = hours12.toString().padStart(2, '0') + ":" + mins + " " + period
        
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        root.currentDate = days[now.getDay()] + ", " + now.getDate().toString().padStart(2, '0') + " " + months[now.getMonth()]
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

    Process {
        id: runningAppsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    if (Array.isArray(data)) {
                        root.runningAppsList = data
                    }
                } catch(e) {}
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

app_defs = [
    {"process": "easyeffects", "icon_names": ["easyeffects", "audio-adjust", "com.github.wwmm.easyeffects"]},
    {"process": "discord", "icon_names": ["discord", "com.discordapp.Discord"]},
    {"process": "spotify", "icon_names": ["spotify", "spotify-client", "spotify-desktop"]},
    {"process": "telegram-desktop", "icon_names": ["telegram", "telegram-desktop", "org.telegram.desktop"]},
    {"process": "steam", "icon_names": ["steam", "com.valvesoftware.Steam"]}
]

def get_icon_path(icon_names):
    for name in icon_names:
        for ext in ['.png', '.svg', '.xpm']:
            p = f"/usr/share/pixmaps/{name}{ext}"
            if os.path.exists(p):
                return "file://" + p
        for root_dir in ["/usr/share/icons/hicolor", "/usr/share/icons/Papirus", "/usr/share/icons/Breeze", "/usr/share/icons/Adwaita"]:
            for sub in ["scalable/apps", "48x48/apps", "64x64/apps", "128x128/apps", "32x32/apps", "symbolic/apps"]:
                for ext in ['svg', 'png']:
                    p = f"{root_dir}/{sub}/{name}.{ext}"
                    if os.path.exists(p):
                        return "file://" + p
    return ""

running = []
for app in app_defs:
    try:
        res = subprocess.run(["pgrep", "-x", app["process"]], stdout=subprocess.DEVNULL)
        if res.returncode == 0:
            ipath = get_icon_path(app["icon_names"])
            running.append({"process": app["process"], "icon": ipath})
    except:
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
        interval: 500
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
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 400
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
    ws.add(active)
    for x in w:
        if x.get('id', 0) > 0:
            ws.add(x['id'])
    print(json.dumps({'active': active, 'list': sorted(list(ws))}))
except:
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

                    if (root.lastRx > 0 && root.lastTx > 0) {
                        let rxDiff = Math.max(0, data.rx - root.lastRx) / 1024
                        let txDiff = Math.max(0, data.tx - root.lastTx) / 1024
                        
                        root.rxSpeed = rxDiff > 1024 ? (rxDiff / 1024).toFixed(1) : rxDiff.toFixed(0)
                        root.rxUnit  = rxDiff > 1024 ? "MB/s" : "KB/s"
                        
                        root.txSpeed = txDiff > 1024 ? (txDiff / 1024).toFixed(1) : txDiff.toFixed(0)
                        root.txUnit  = txDiff > 1024 ? "MB/s" : "KB/s"
                    }
                    root.lastRx = data.rx
                    root.lastTx = data.tx

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
            if any(x in t for x in ['x86_pkg_temp', 'coretemp', 'Tdie']):
                with open(tz + '/temp') as tf:
                    cpu = int(tf.read().strip()) // 1000
                    break
    except: pass
if cpu == 0:
    try:
        with open('/sys/class/thermal/thermal_zone0/temp') as f:
            cpu = int(f.read().strip()) // 1000
    except: cpu = 0

gpu = "0"
try:
    res = subprocess.run(["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader"], capture_output=True, text=True)
    if res.returncode == 0 and res.stdout.strip():
        gpu = res.stdout.strip()
except: pass

bat = "100"
for b in glob.glob('/sys/class/power_supply/BAT*/capacity'):
    try:
        with open(b) as f:
            bat = f.read().strip()
            break
    except: pass

charging = False
for s in glob.glob('/sys/class/power_supply/BAT*/status'):
    try:
        with open(s) as f:
            if "Charging" in f.read():
                charging = True
                break
    except: pass

rx = 0
tx = 0
for path in glob.glob('/sys/class/net/[ew]*/statistics/rx_bytes'):
    try:
        with open(path) as f:
            rx += int(f.read().strip())
    except: pass

for path in glob.glob('/sys/class/net/[ew]*/statistics/tx_bytes'):
    try:
        with open(path) as f:
            tx += int(f.read().strip())
    except: pass

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
            
            exclusiveZone: 40

            anchors {
                top: true
                left: true
                right: true
            }
            
            implicitHeight: 46 
            color: "transparent"

            Item {
                anchors.fill: parent

                Rectangle {
                    id: barIsland
                    
                    x: (parent.width / 2) - (width / 2)
                    y: root.barY
                    height: root.islandHeight
                    
                    HoverHandler { id: islandHover }
                    property bool isPinned: false
                    property bool isExpanded: isPinned || islandHover.hovered
                    
                    property int expandedWidth: expandedRow.implicitWidth + 32
                    property int collapsedWidth: collapsedRow.implicitWidth + 32
                    
                    width: isExpanded ? expandedWidth : collapsedWidth
                    
                    Behavior on width { 
                        NumberAnimation { 
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.smoothEasing
                        } 
                    }

                    Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                    Behavior on border.color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                    
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: barIsland.isPinned = !barIsland.isPinned
                    }

                    // --- COLLAPSED STATE ---
                    Row {
                        id: collapsedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: 12
                        opacity: barIsland.isExpanded ? 0.0 : 1.0
                        scale: barIsland.isExpanded ? 0.90 : 1.0
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                        Behavior on scale { NumberAnimation { duration: root.animEnabled ? style.animDuration : 0; easing.type: style.smoothEasing } }

                        Row {
                            spacing: 3
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
                                        NumberAnimation { to: 4 + ((index * 3) % 8); duration: 320 + index * 50; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 14 - ((index * 2) % 6); duration: 380 - index * 40; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.currentTime !== "" ? root.currentTime : "12:00 PM"
                            color: root.themeText
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // --- EXPANDED STATE ---
                    Row {
                        id: expandedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: style.moduleSpacing
                        opacity: barIsland.isExpanded ? 1.0 : 0.0
                        scale: barIsland.isExpanded ? 1.0 : 0.94
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                        Behavior on scale { NumberAnimation { duration: root.animEnabled ? style.animDuration : 0; easing.type: style.smoothEasing } }

                        // Workspaces
                        Row {
                            height: root.islandHeight
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: root.activeWorkspaces
                                delegate: Rectangle {
                                    width: 26; height: 26
                                    radius: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData === root.activeWs ? root.themePrimary : (wsMouse.containsMouse ? style.hoverColor : "transparent")
                                    
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }

                                    Text {
                                        text: modelData
                                        color: modelData === root.activeWs ? "#000000" : (wsMouse.containsMouse ? root.themeText : root.themeTextMuted)
                                        font.pixelSize: 12
                                        font.weight: modelData === root.activeWs ? Font.ExtraBold : Font.Bold
                                        anchors.centerIn: parent
                                        Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
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

                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter }

                        // Network Speeds
                        Row {
                            height: root.islandHeight
                            spacing: 12
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text { text: "↓"; color: root.themePrimary; font.pixelSize: 14; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                    Text { text: root.rxSpeed; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.rxUnit; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter; anchors.baseline: parent.baseline }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text { text: "↑"; color: root.themePrimary; font.pixelSize: 14; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                    Text { text: root.txSpeed; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.txUnit; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter; anchors.baseline: parent.baseline }
                                }
                            }
                        }

                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter }

                        // Time & Date (Center Block)
                        Rectangle {
                            height: parent.height - 10
                            width: centerRow.implicitWidth + 24
                            radius: height / 2
                            color: centerMouse.containsMouse ? style.hoverColor : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: centerRow
                                anchors.centerIn: parent
                                spacing: 10

                                Row {
                                    spacing: 3
                                    visible: root.isPlaying
                                    anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: 5
                                        delegate: Rectangle {
                                            width: 3.5; height: 12; radius: 1.75; color: root.themePrimary
                                            anchors.verticalCenter: parent.verticalCenter

                                            SequentialAnimation on height {
                                                running: root.isPlaying && barIsland.isExpanded
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 4 + ((index * 4) % 10); duration: 320 + index * 50; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 16 - ((index * 3) % 8); duration: 380 - index * 40; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: (root.currentTime !== "" ? root.currentTime : "12:00 PM")
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.ExtraBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "•"
                                    color: root.themeTextMuted
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: (root.currentDate !== "" ? root.currentDate : "Sat, 05 Sep")
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: centerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => { if (mouse.button === Qt.LeftButton) root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh calendar open") }
                                onDoubleClicked: (mouse) => { if (mouse.button === Qt.LeftButton) barIsland.isPinned = !barIsland.isPinned }
                            }
                        }

                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter }

                        // Hardware (CPU/GPU)
                        Row {
                            height: root.islandHeight
                            spacing: 12
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                Text { text: ""; color: root.themePrimary; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: root.cpuTemp; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "°C"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                Text { text: "󰢮"; color: root.themePrimary; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: root.gpuTemp; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "°C"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }

                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter }

                        // Volume Module
                        Rectangle {
                            height: parent.height - 10
                            width: volRow.implicitWidth + 16
                            radius: height / 2
                            color: volMouse.containsMouse ? style.hoverColor : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: volRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { 
                                    text: root.getVolIcon(root.volumePct, root.isMuted)
                                    color: root.isMuted ? "#FF453A" : root.themePrimary
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration } }
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: root.volumePct; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "%"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }

                            MouseArea {
                                id: volMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                                    else root.exec("pavucontrol")
                                }
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) {
                                        if (root.volumePct < 100) root.exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
                                    } else {
                                        root.exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-")
                                    }
                                }
                            }
                        }

                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter }

                        // Battery Module
                        Rectangle {
                            height: parent.height - 10
                            width: batRow.implicitWidth + 16
                            radius: height / 2
                            color: batMouse.containsMouse ? style.hoverColor : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: batRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { 
                                    text: root.getBatIcon(parseInt(root.batCap), root.isCharging)
                                    color: root.isCharging ? "#32D74B" : (parseInt(root.batCap) <= 20 ? "#FF453A" : root.themePrimary)
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration } }
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: root.batCap; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "%"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }

                            MouseArea {
                                id: batMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => { if (mouse.button === Qt.LeftButton) root.exec("gnome-power-statistics") }
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

                        // Running Apps Drawer (Only visible if apps exist)
                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter; visible: root.runningAppsList.length > 0 }

                        Item {
                            id: appsDrawer
                            height: root.islandHeight
                            width: root.runningAppsList.length > 0 ? (appsHover.hovered ? appsRow.implicitWidth + 36 : 26) : 0
                            visible: root.runningAppsList.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Behavior on width { NumberAnimation { duration: root.animEnabled ? style.animDuration : 0; easing.type: style.smoothEasing } }

                            HoverHandler { id: appsHover }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                x: 6

                                Text {
                                    text: appsHover.hovered ? "󰁔" : "󰁍"
                                    color: root.themePrimary
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: style.fadeDuration } }
                                }

                                Row {
                                    id: appsRow
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: appsHover.hovered ? 1.0 : 0.0
                                    visible: opacity > 0.01

                                    Behavior on opacity { NumberAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }

                                    Repeater {
                                        model: root.runningAppsList
                                        delegate: Rectangle {
                                            width: 28; height: 28; radius: 14
                                            color: appItemMouse.containsMouse ? style.hoverColor : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Image {
                                                anchors.centerIn: parent
                                                width: 16; height: 16
                                                source: modelData.icon
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
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

                        Rectangle { width: 4; height: 4; radius: 2; color: style.separatorColor; anchors.verticalCenter: parent.verticalCenter }

                        // Quick Actions (Wifi & Power)
                        Row {
                            height: root.islandHeight
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: netMouse.containsMouse ? style.hoverColor : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖩"
                                    color: root.themePrimary
                                    font.pixelSize: 15
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
                                width: 30; height: 30; radius: 15
                                color: pwrBarMouse.containsMouse ? "#FF453A" : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐥"
                                    color: pwrBarMouse.containsMouse ? "#ffffff" : root.themePrimary
                                    font.pixelSize: 15
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