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
    
    property int themeRounding: 12
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    QtObject {
        id: style
        property int moduleSpacing: 8
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var smoothEasing: Easing.OutCubic
        property var fadeEasing: Easing.OutCubic
        property color hoverColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.08)
        property color separatorColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.18)
    }

    property string currentTime: ""
    property string currentDate: ""
    
    property string rxSpeed: "0 KB/s"
    property string txSpeed: "0 KB/s"
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

    property int barY: 5 
    property int islandHeight: 36

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
                        
                        root.rxSpeed = (rxDiff > 1024 ? (rxDiff / 1024).toFixed(1) + " MB/s" : rxDiff.toFixed(0) + " KB/s")
                        root.txSpeed = (txDiff > 1024 ? (txDiff / 1024).toFixed(1) + " MB/s" : txDiff.toFixed(0) + " KB/s")
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
                    
                    property int expandedWidth: expandedRow.implicitWidth + 28
                    property int collapsedWidth: collapsedRow.implicitWidth + 28
                    
                    width: isExpanded ? expandedWidth : collapsedWidth
                    
                    Behavior on width { 
                        NumberAnimation { 
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.smoothEasing
                        } 
                    }

                    Behavior on color {
                        ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing }
                    }
                    
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: barIsland.isPinned = !barIsland.isPinned
                    }

                    Row {
                        id: collapsedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: barIsland.isExpanded ? 0.0 : 1.0
                        scale: barIsland.isExpanded ? 0.90 : 1.0
                        visible: opacity > 0.01

                        Behavior on opacity { 
                            NumberAnimation { 
                                duration: style.fadeDuration
                                easing.type: style.fadeEasing 
                            } 
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? style.animDuration : 0
                                easing.type: style.smoothEasing
                            }
                        }

                        Row {
                            spacing: 2.5
                            visible: root.isPlaying
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: 5
                                delegate: Rectangle {
                                    width: 2.5
                                    height: 10
                                    radius: 1
                                    color: root.themePrimary
                                    anchors.verticalCenter: parent.verticalCenter

                                    SequentialAnimation on height {
                                        running: root.isPlaying && !barIsland.isExpanded
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 4 + ((index * 3) % 8); duration: 320 + index * 50; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 13 - ((index * 2) % 6); duration: 380 - index * 40; easing.type: Easing.InOutSine }
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

                            Behavior on color {
                                ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing }
                            }
                        }
                    }

                    Row {
                        id: expandedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: 12
                        opacity: barIsland.isExpanded ? 1.0 : 0.0
                        scale: barIsland.isExpanded ? 1.0 : 0.94
                        visible: opacity > 0.01

                        Behavior on opacity { 
                            NumberAnimation { 
                                duration: style.fadeDuration
                                easing.type: style.fadeEasing 
                            } 
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? style.animDuration : 0
                                easing.type: style.smoothEasing
                            }
                        }

                        Row {
                            id: leftRow
                            height: parent.height
                            spacing: style.moduleSpacing

                            Row {
                                height: root.islandHeight
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: root.activeWorkspaces
                                    delegate: Rectangle {
                                        id: wsPill
                                        width: modelData === root.activeWs ? 25 : 25
                                        height: 25
                                        radius: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData === root.activeWs ? root.themePrimary : (wsMouse.containsMouse ? Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.28) : Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.15))

                                        scale: wsMouse.containsMouse ? 1.08 : 1.0

                                        Behavior on scale { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.smoothEasing
                                            } 
                                        }

                                        Behavior on width { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? style.animDuration : 0
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
                                            color: modelData === root.activeWs ? "#000000" : root.themeText
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            anchors.centerIn: parent

                                            Behavior on color { 
                                                ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } 
                                            }
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

                            Rectangle {
                                width: 1; height: 14; color: style.separatorColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Row {
                                height: root.islandHeight
                                spacing: 2

                                Item {
                                    width: 76
                                    height: root.islandHeight
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text { text: "↓"; color: root.themePrimary; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: root.rxSpeed; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }

                                Item {
                                    width: 76
                                    height: root.islandHeight
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text { text: "↑"; color: root.themePrimary; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: root.txSpeed; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 16
                            color: style.separatorColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            id: centerBlock
                            height: parent.height
                            implicitWidth: centerRow.implicitWidth + 8

                            scale: centerMouse.containsMouse ? 1.03 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? style.animDuration : 0
                                    easing.type: style.smoothEasing
                                }
                            }

                            Row {
                                id: centerRow
                                anchors.centerIn: parent
                                spacing: 8

                                Row {
                                    spacing: 2.5
                                    visible: root.isPlaying
                                    anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: 5
                                        delegate: Rectangle {
                                            width: 3
                                            height: 12
                                            radius: 1.5
                                            color: root.themePrimary
                                            anchors.verticalCenter: parent.verticalCenter

                                            SequentialAnimation on height {
                                                running: root.isPlaying && barIsland.isExpanded
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 4 + ((index * 4) % 10); duration: 320 + index * 50; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 15 - ((index * 3) % 8); duration: 380 - index * 40; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    id: timeText
                                    text: (root.currentTime !== "" ? root.currentTime : "12:00 PM") + "  •  " + (root.currentDate !== "" ? root.currentDate : "Sat, 05 Sep")
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
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
                                    if (mouse.button === Qt.LeftButton) barIsland.isPinned = !barIsland.isPinned
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 16
                            color: style.separatorColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: rightRow
                            height: parent.height
                            spacing: style.moduleSpacing

                            Row {
                                height: root.islandHeight
                                spacing: 2

                                Item {
                                    width: 52
                                    height: root.islandHeight
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text { text: ""; color: root.themePrimary; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: root.cpuTemp + "°C"; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }

                                Item {
                                    width: 52
                                    height: root.islandHeight
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text { text: "󰢮"; color: root.themePrimary; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: root.gpuTemp + "°C"; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }

                            Rectangle {
                                width: 1; height: 14; color: style.separatorColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                height: root.islandHeight
                                width: 56

                                scale: volMouse.containsMouse ? 1.05 : 1.0
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.smoothEasing
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { 
                                        text: root.isMuted ? "󰖁" : ""
                                        color: root.isMuted ? "#FF453A" : root.themePrimary
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                                    }
                                    Text { text: root.volumePct + "%"; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
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
                                            if (root.volumePct < 100) {
                                                root.exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
                                            }
                                        } else {
                                            root.exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 1; height: 14; color: style.separatorColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                height: root.islandHeight
                                width: 56

                                scale: batMouse.containsMouse ? 1.05 : 1.0
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.smoothEasing
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { 
                                        text: root.isCharging ? "󰂄" : "󰁹"
                                        color: root.isCharging ? "#32D74B" : root.themePrimary
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                                    }
                                    Text { text: root.batCap + "%"; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: batMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            root.exec("gnome-power-statistics")
                                        }
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
                                width: 1; height: 14; color: style.separatorColor
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.runningAppsList.length > 0
                            }

                            Item {
                                id: appsDrawer
                                height: root.islandHeight
                                width: root.runningAppsList.length > 0 ? (appsHover.hovered ? appsRow.implicitWidth + 32 : 24) : 0
                                visible: root.runningAppsList.length > 0
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on width { 
                                    NumberAnimation { 
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.smoothEasing
                                    } 
                                }

                                HoverHandler { id: appsHover }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    x: 4

                                    Text {
                                        text: appsHover.hovered ? "󰁔" : "󰁍"
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter

                                        scale: appsHover.hovered ? 1.08 : 1.0
                                        Behavior on scale { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.smoothEasing
                                            } 
                                        }
                                        Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                                    }

                                    Row {
                                        id: appsRow
                                        spacing: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: appsHover.hovered ? 1.0 : 0.0
                                        scale: appsHover.hovered ? 1.0 : 0.92
                                        visible: opacity > 0.01

                                        Behavior on opacity { 
                                            NumberAnimation { 
                                                duration: style.fadeDuration
                                                easing.type: style.fadeEasing 
                                            } 
                                        }
                                        Behavior on scale { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.smoothEasing
                                            } 
                                        }

                                        Repeater {
                                            model: root.runningAppsList
                                            delegate: Item {
                                                width: 20; height: 20
                                                anchors.verticalCenter: parent.verticalCenter

                                                scale: appItemMouse.containsMouse ? 1.10 : 1.0
                                                Behavior on scale { 
                                                    NumberAnimation { 
                                                        duration: root.animEnabled ? style.animDuration : 0
                                                        easing.type: style.smoothEasing
                                                    } 
                                                }

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
                                                        if (mouse.button === Qt.RightButton) {
                                                            root.exec("pkill -x " + modelData.process)
                                                        } else {
                                                            root.exec(modelData.process)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 1; height: 14; color: style.separatorColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Row {
                                height: root.islandHeight
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter

                                Item {
                                    width: 24; height: 24
                                    anchors.verticalCenter: parent.verticalCenter

                                    scale: netMouse.containsMouse ? 1.08 : 1.0
                                    Behavior on scale { 
                                        NumberAnimation { 
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.smoothEasing
                                        } 
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰖩"
                                        color: root.themePrimary
                                        font.pixelSize: 15

                                        Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
                                    }
                                    MouseArea {
                                        id: netMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh connection open")
                                    }
                                }

                                Item {
                                    width: 24; height: 24
                                    anchors.verticalCenter: parent.verticalCenter

                                    scale: pwrBarMouse.containsMouse ? 1.08 : 1.0
                                    Behavior on scale { 
                                        NumberAnimation { 
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.smoothEasing
                                        } 
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: pwrBarMouse.containsMouse ? "#FF453A" : root.themePrimary
                                        font.pixelSize: 15

                                        Behavior on color { ColorAnimation { duration: style.fadeDuration; easing.type: style.fadeEasing } }
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
}