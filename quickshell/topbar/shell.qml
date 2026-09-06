import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Scope {
    id: root

    // ============================================================
    // ADAPTIVE THEME PROPERTIES (Matched with general.lua)
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 12
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    // ============================================================
    // DESIGN SYSTEM
    // ============================================================
    QtObject {
        id: style
        property int moduleSpacing: 8
        property int animDuration: 220
        property color hoverColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.08)
        property color separatorColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.18)
    }

    // ============================================================
    // DYNAMIC STATE PROPERTIES
    // ============================================================
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

    // Running background apps list
    property var runningAppsList: []

    property int barY: 5 
    property int islandHeight: 36

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
    }

    // ============================================================
    // COMMAND EXECUTION
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    // ============================================================
    // ROBUST BACKGROUND APP ICON RESOLVER & POLLING
    // ============================================================
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
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!runningAppsProcess.running) {
                let py = `
import subprocess, json, os, glob

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
        for root_dir in ["/usr/share/icons/hicolor", "/usr/share/icons/Adwaita", "/usr/share/icons/Papirus", "/usr/share/icons/breeze"]:
            for ext in ['png', 'svg']:
                found = glob.glob(f"{root_dir}/**/{name}.{ext}", recursive=True)
                if found:
                    return "file://" + found[0]
        for ext in ['png', 'svg']:
            found = glob.glob(f"/usr/share/icons/*/*/*/*/{name}.{ext}", recursive=True)
            if found:
                return "file://" + found[0]
    return ""

running = []
for app in app_defs:
    try:
        res = subprocess.run(["pgrep", "-x", app["process"]], stdout=subprocess.PIPE)
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

    // ============================================================
    // MEDIA PLAYER STATUS POLLING
    // ============================================================
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
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!mediaProcess.running) {
                mediaProcess.command = ["bash", "-c", "playerctl status 2>/dev/null || echo 'Stopped'"]
                mediaProcess.running = true
            }
        }
    }

    // ============================================================
    // FAST DATA POLLING (Time, Volume, Workspaces)
    // ============================================================
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
                    let parts = out.split(" ")
                    if (parts.length >= 2) {
                        root.volumePct = Math.min(100, parseInt(parseFloat(parts[1]) * 100) || 0)
                        root.isMuted = out.includes("MUTED")
                    }
                }
            }
        }
    }
    
    Timer {
        interval: 250
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!volProcess.running) {
                volProcess.command = ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
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
        interval: 200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!wsProcess.running) {
                let wsCmd = "python3 -c \"import subprocess, json; a=json.loads(subprocess.check_output('hyprctl activeworkspace -j', shell=True) or '{}'); w=json.loads(subprocess.check_output('hyprctl workspaces -j', shell=True) or '[]'); active=a.get('id', 1); ws=set(range(1, 6)); ws.add(active); [ws.add(x['id']) for x in w if x.get('id', 0) > 0]; print(json.dumps({'active': active, 'list': sorted(list(ws))}))\" 2>/dev/null"
                wsProcess.command = ["bash", "-c", wsCmd]
                wsProcess.running = true
            }
        }
    }

    // ============================================================
    // SLOW DATA POLLING (Hardware & Network)
    // ============================================================
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
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!hardwareProcess.running) {
                let pyScript = `
import glob, json, subprocess
def cmd(c):
    try: return subprocess.check_output(c, shell=True, text=True).strip()
    except: return ""

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
    c_str = cmd("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
    cpu = int(c_str)//1000 if c_str else 0

gpu = cmd("nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null") or "0"
bat = cmd("cat /sys/class/power_supply/BAT*/capacity | head -1") or "100"
charging = "Charging" in cmd("cat /sys/class/power_supply/BAT*/status | head -1")

rx = cmd("cat /sys/class/net/[ew]*/statistics/rx_bytes | awk '{s+=$1} END {print s}'") or "0"
tx = cmd("cat /sys/class/net/[ew]*/statistics/tx_bytes | awk '{s+=$1} END {print s}'") or "0"

print(json.dumps({
    "cpu": str(cpu), "gpu": gpu, "bat": bat, "charging": charging, 
    "rx": int(rx), "tx": int(tx)
}))
`
                hardwareProcess.command = ["python3", "-c", pyScript]
                hardwareProcess.running = true
            }
        }
    }

    // ============================================================
    // MULTI-MONITOR DELEGATION
    // ============================================================
    Variants {
        model: Quickshell.screens
        
        delegate: PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-bar" 
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            exclusiveZone: 46

            anchors {
                top: true
                left: true
                right: true
            }
            
            implicitHeight: 46 
            color: "transparent"

            Item {
                anchors.fill: parent

                // DYNAMIC ISLAND CONTAINER
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
                            duration: 220
                            easing.type: Easing.OutCubic 
                        } 
                    }
                    
                    radius: root.themeRounding
                    color: root.themeBackground
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: barIsland.isPinned = !barIsland.isPinned
                    }

                    // 1. COLLAPSED CONTENT (MUSIC RHYTHM + TIME)
                    Row {
                        id: collapsedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: barIsland.isExpanded ? 0.0 : 1.0
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: style.animDuration; easing.type: Easing.InOutQuad } }

                        // Collapsed 5-Bar Rhythm Visualizer
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
                                        running: root.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 4 + ((index * 3) % 8); duration: 220 + index * 40; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 13 - ((index * 2) % 6); duration: 280 - index * 30; easing.type: Easing.InOutSine }
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

                    // 2. EXPANDED CONTENT
                    Row {
                        id: expandedRow
                        height: root.islandHeight
                        anchors.centerIn: parent
                        spacing: 12
                        opacity: barIsland.isExpanded ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: style.animDuration; easing.type: Easing.InOutQuad } }

                        // ==========================================
                        // LEFT SIDE: Workspaces & Network
                        // ==========================================
                        Row {
                            id: leftRow
                            height: parent.height
                            spacing: style.moduleSpacing

                            // Workspaces (Display Only - No Click/Switch Logic)
                            Row {
                                height: root.islandHeight
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: root.activeWorkspaces
                                    delegate: Rectangle {
                                        width: modelData === root.activeWs ? 24 : 20
                                        height: 20
                                        radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData === root.activeWs ? root.themePrimary : Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.15)

                                        Behavior on width { NumberAnimation { duration: 150 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            text: modelData
                                            color: modelData === root.activeWs ? "#000000" : root.themeText
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            anchors.centerIn: parent
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 1; height: 14; color: style.separatorColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Network Speed (Fixed bounding containers to eliminate jitter)
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

                        // LEFT MAIN SEPARATOR
                        Rectangle {
                            width: 1
                            height: 16
                            color: style.separatorColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // ==========================================
                        // CENTER: Time & Date + Music Visualizer
                        // ==========================================
                        Item {
                            id: centerBlock
                            height: parent.height
                            implicitWidth: centerRow.implicitWidth + 8

                            Row {
                                id: centerRow
                                anchors.centerIn: parent
                                spacing: 8

                                // Expanded 5-Bar Rhythm Visualizer
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
                                                running: root.isPlaying
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 4 + ((index * 4) % 10); duration: 250 + index * 50; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 15 - ((index * 3) % 8); duration: 300 - index * 40; easing.type: Easing.InOutSine }
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
                                anchors.fill: parent
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

                        // RIGHT MAIN SEPARATOR
                        Rectangle {
                            width: 1
                            height: 16
                            color: style.separatorColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // ==========================================
                        // RIGHT SIDE: Temp, Volume, Battery + Background Apps Drawer + Action Buttons
                        // ==========================================
                        Row {
                            id: rightRow
                            height: parent.height
                            spacing: style.moduleSpacing

                            // Temperature (Fixed bounding containers to eliminate jitter)
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

                            // Volume Container (Scroll wheel capped at 100% max)
                            Item {
                                height: root.islandHeight
                                width: 56

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: root.isMuted ? "󰖁" : ""; color: root.isMuted ? "#FF453A" : root.themePrimary; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.volumePct + "%"; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    anchors.fill: parent
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

                            // Battery Container (Fixed power profile cycle logic with string cleanup)
                            Item {
                                height: root.islandHeight
                                width: 56

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: root.isCharging ? "󰂄" : "󰁹"; color: root.isCharging ? "#32D74B" : root.themePrimary; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.batCap + "%"; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    anchors.fill: parent
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

                            // ==========================================
                            // RUNNING BACKGROUND APPS DRAWER (HOVER TO EXPAND)
                            // ==========================================
                            Item {
                                id: appsDrawer
                                height: root.islandHeight
                                width: root.runningAppsList.length > 0 ? (appsHover.hovered ? appsRow.implicitWidth + 32 : 24) : 0
                                visible: root.runningAppsList.length > 0
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on width {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                HoverHandler { id: appsHover }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    x: 4

                                    // Expand Arrow Indicator
                                    Text {
                                        text: appsHover.hovered ? "󰁔" : "󰁍"
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // App Icons Row (Revealed on hover)
                                    Row {
                                        id: appsRow
                                        spacing: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: appsHover.hovered ? 1.0 : 0.0
                                        visible: opacity > 0.01

                                        Behavior on opacity { NumberAnimation { duration: 180 } }

                                        Repeater {
                                            model: root.runningAppsList
                                            delegate: Item {
                                                width: 20; height: 20
                                                anchors.verticalCenter: parent.verticalCenter

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 16; height: 16
                                                    source: modelData.icon
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
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

                            // ==========================================
                            // EXTRA ACTION BUTTONS (Network & Power)
                            // ==========================================
                            Row {
                                height: root.islandHeight
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter

                                // 1. Network Button
                                Item {
                                    width: 24; height: 24
                                    anchors.verticalCenter: parent.verticalCenter
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

                                // 2. Power Button
                                Item {
                                    width: 24; height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: pwrBarMouse.containsMouse ? "#FF453A" : root.themePrimary
                                        font.pixelSize: 15
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