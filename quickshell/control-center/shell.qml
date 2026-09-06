import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Scope {
    id: root

    // ============================================================
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeOnPrimary: "#000000" 
    
    property int themeRounding: 24
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.82
    
    property color themeBackground: Qt.rgba(0.08, 0.08, 0.09, themeBgAlpha) 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08) 
    property color themeSurfaceActive: Qt.rgba(1.0, 1.0, 1.0, 0.22)
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.14)

    // ============================================================
    // SYSTEM STATE PROPERTIES
    // ============================================================
    property bool wifiEnabled: true
    property bool wiredEnabled: true
    property bool btEnabled: true
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool stayAwakeEnabled: false
    property bool micMuted: false
    
    property int volumeLevel: 50
    property bool volumeMuted: false
    property int brightnessLevel: 70

    property string mediaTitle: "No Media Playing"
    property string mediaArtist: "System Audio"
    property bool mediaPlaying: false

    property string userName: "Pradun Kumar"
    property string systemInfo: "Fedora 43 • Hyprland"
    property string avatarPath: "file://" + Quickshell.env("HOME") + "/.face"

    // NAVIGATION & EDIT STATE
    property string pageState: "main" 
    property bool editMode: false
    property bool powerMenuOpen: false

    // ============================================================
    // WINDOW POSITION PERSISTENCE
    // ============================================================
    property int windowMarginTop: 54
    property int windowMarginRight: 16

    FileView {
        id: posFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/cc_pos.json"
        onLoaded: {
            try {
                let d = JSON.parse(text())
                if (d.top !== undefined) root.windowMarginTop = d.top
                if (d.right !== undefined) root.windowMarginRight = d.right
            } catch(e) {}
        }
    }

    Process { id: savePosProcess }
    function saveWindowPos() {
        let jsonStr = JSON.stringify({ top: root.windowMarginTop, right: root.windowMarginRight })
        savePosProcess.command = ["bash", "-c", "mkdir -p ~/.config/quickshell/json && echo '" + jsonStr + "' > ~/.config/quickshell/json/cc_pos.json"]
        savePosProcess.running = true
    }

    // ============================================================
    // EDIT MODE & TOGGLE CONFIGURATION
    // ============================================================
    property var masterMods: ["wifi", "wired", "bluetooth", "dnd", "nightLight", "micMute", "stayAwake", "settings"]
    property var toggleMods: ["wifi", "bluetooth", "dnd", "nightLight", "micMute", "settings", "wired", "stayAwake"]
    property var inactiveMods: []

    function updateInactiveMods() {
        let inactive = []
        for (let i = 0; i < root.masterMods.length; i++) {
            if (!root.toggleMods.includes(root.masterMods[i])) {
                inactive.push(root.masterMods[i])
            }
        }
        root.inactiveMods = inactive
    }

    FileView {
        id: modsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/cc_mods.json"
        onLoaded: {
            try {
                let d = JSON.parse(text())
                if (d.toggles && Array.isArray(d.toggles) && d.toggles.length > 0) root.toggleMods = d.toggles
            } catch(e) {}
            root.updateInactiveMods()
        }
    }

    Process { id: saveToggleProcess }
    function saveToggleMods() {
        let jsonStr = JSON.stringify({ toggles: root.toggleMods })
        saveToggleProcess.command = ["bash", "-c", "mkdir -p ~/.config/quickshell/json && echo '" + jsonStr + "' > ~/.config/quickshell/json/cc_mods.json"]
        saveToggleProcess.running = true
        root.updateInactiveMods()
    }

    function moveToggle(srcIdx, dstIdx) {
        if (srcIdx === dstIdx || srcIdx < 0 || dstIdx < 0) return
        let list = root.toggleMods.slice()
        let item = list.splice(srcIdx, 1)[0]
        list.splice(dstIdx, 0, item)
        root.toggleMods = list
        root.saveToggleMods()
    }

    function addToggle(modName) {
        let list = root.toggleMods.slice()
        if (!list.includes(modName)) {
            list.push(modName)
            root.toggleMods = list
            root.saveToggleMods()
        }
    }

    function removeToggle(modName) {
        let list = root.toggleMods.slice()
        let idx = list.indexOf(modName)
        if (idx !== -1) {
            list.splice(idx, 1)
            root.toggleMods = list
            root.saveToggleMods()
        }
    }

    // ============================================================
    // THEME PARSERS
    // ============================================================
    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let match = this.text().match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) { 
                    root.themeBorder = "#" + match[1]
                    root.themePrimary = "#" + match[1] 
                }
            } catch (e) {}
        }
    }

    Component.onCompleted: { 
        exec("mkdir -p ~/.config/quickshell/json")
        colorFile.reload()
        modsFile.reload()
        posFile.reload()
        root.updateInactiveMods()
    }

    // ============================================================
    // PROCESS EXECUTION & SYSTEM SCRAPING
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    Process {
        id: stateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    root.wifiEnabled = data.wifi
                    root.wiredEnabled = data.wired
                    root.btEnabled = data.bt
                    root.nightLightEnabled = data.night
                    root.stayAwakeEnabled = data.stayAwake
                    root.micMuted = data.mic_muted
                    root.volumeLevel = data.volume
                    root.volumeMuted = data.vol_muted
                    root.brightnessLevel = data.brightness
                    root.mediaTitle = data.media_title || "No Media Playing"
                    root.mediaArtist = data.media_artist || "System Audio"
                    root.mediaPlaying = data.media_playing
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let py = `
import json, subprocess, os
def cmd(c):
    try: return subprocess.check_output(c, shell=True, text=True).strip()
    except: return ""

mic_out = cmd("wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null")
mic_muted = "MUTED" in mic_out

vol_out = cmd("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null")
vol_val = 50
vol_muted = "MUTED" in vol_out
if vol_out:
    parts = vol_out.split()
    if len(parts) >= 2:
        try: vol_val = int(float(parts[1]) * 100)
        except: pass

bright_out = cmd("brightnessctl g 2>/dev/null")
bright_max = cmd("brightnessctl m 2>/dev/null")
bright_val = 70
if bright_out and bright_max and int(bright_max) > 0:
    bright_val = int((int(bright_out) / int(bright_max)) * 100)

wifi = "enabled" in cmd("nmcli radio wifi 2>/dev/null")
wired = "connected" in cmd("nmcli -t -f TYPE,STATE d | grep ethernet 2>/dev/null")
bt = "yes" not in cmd("rfkill list bluetooth | grep 'Soft blocked'")
night = bool(cmd("pgrep -x hyprsunset || pgrep -x wlsunset"))
stay_awake = bool(cmd("pgrep -f 'wayland-idle-inhibitor' || pgrep -x hypridle || ls /tmp/dms_awake 2>/dev/null"))

media_title = cmd("playerctl metadata title 2>/dev/null")
media_artist = cmd("playerctl metadata artist 2>/dev/null")
media_status = cmd("playerctl status 2>/dev/null")

print(json.dumps({
    "mic_muted": mic_muted, "wifi": wifi, "wired": wired, "bt": bt, "night": night, 
    "stayAwake": stay_awake, "volume": vol_val, "vol_muted": vol_muted,
    "brightness": bright_val, "media_title": media_title, "media_artist": media_artist,
    "media_playing": media_status.lower() == "playing"
}))
`
            stateProcess.command = ["python3", "-c", py]
            stateProcess.running = true
        }
    }

    // ============================================================
    // WI-FI SCANNER LOGIC
    // ============================================================
    ListModel { id: wifiModel }

    Process {
        id: wifiScanProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    wifiModel.clear()
                    for (let i = 0; i < data.length; i++) {
                        wifiModel.append(data[i])
                    }
                } catch(e) {}
            }
        }
    }

    function scanWifi() {
        let py = `
import subprocess, json
try:
    out = subprocess.check_output(['nmcli', '-t', '-f', 'ACTIVE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'], text=True)
    nets = []
    seen = set()
    for line in out.splitlines():
        parts = line.replace('\\\\:', '&&COLON&&').split(':')
        if len(parts) >= 4:
            act = parts[0] == 'yes'
            ssid = parts[1].replace('&&COLON&&', ':')
            sig = int(parts[2]) if parts[2].isdigit() else 0
            sec = parts[3]
            if ssid and ssid not in seen:
                seen.add(ssid)
                nets.append({"ssid": ssid, "signal": sig, "security": sec, "active": act})
    print(json.dumps(nets))
except:
    print("[]")
`
        wifiScanProcess.command = ["python3", "-c", py]
        wifiScanProcess.running = true
    }

    function connectWifi(ssid, password) {
        if (password === "") {
            root.exec("nmcli dev wifi connect '" + ssid + "'")
        } else {
            root.exec("nmcli dev wifi connect '" + ssid + "' password '" + password + "'")
        }
        root.pageState = "main"
    }

    // ============================================================
    // TOGGLE METADATA & ACTIONS
    // ============================================================
    function getToggleName(type) {
        switch(type) {
            case "wifi": return "Internet"
            case "wired": return "Ethernet"
            case "bluetooth": return "Bluetooth"
            case "dnd": return "Do Not Disturb"
            case "nightLight": return "Night Light"
            case "stayAwake": return "Stay Awake"
            case "micMute": return "Mic Mute"
            case "settings": return "Settings"
        }
        return type
    }

    function getToggleIcon(type) {
        switch(type) {
            case "wifi": return root.wifiEnabled ? "󰤨" : "󰤭"
            case "wired": return root.wiredEnabled ? "󰈀" : "󰈂"
            case "bluetooth": return root.btEnabled ? "󰂯" : "󰂲"
            case "dnd": return root.dndEnabled ? "󰍶" : "󰍷"
            case "nightLight": return root.nightLightEnabled ? "󰖔" : "󰖕"
            case "stayAwake": return root.stayAwakeEnabled ? "󰅶" : "󰾪"
            case "micMute": return root.micMuted ? "󰍭" : "󰍬"
            case "settings": return "󰒓"
        }
        return "󰐥"
    }

    function isToggleActive(type) {
        switch(type) {
            case "wifi": return root.wifiEnabled
            case "wired": return root.wiredEnabled
            case "bluetooth": return root.btEnabled
            case "dnd": return root.dndEnabled
            case "nightLight": return root.nightLightEnabled
            case "stayAwake": return root.stayAwakeEnabled
            case "micMute": return root.micMuted
            case "settings": return false
        }
        return false
    }

    function handleToggleClick(type) {
        if (root.editMode) return

        switch(type) {
            case "wifi": 
                root.pageState = "wifi"
                root.scanWifi()
                break
            case "wired": 
                root.exec("DEV=$(nmcli -t -f DEVICE,TYPE d | grep ethernet | cut -d: -f1 | head -n 1); if [ -n \"$DEV\" ]; then STATE=$(nmcli -t -f STATE d show $DEV | grep -q 'connected' && echo 'up' || echo 'down'); if [ \"$STATE\" = 'up' ]; then nmcli dev disconnect $DEV; else nmcli dev connect $DEV; fi; fi")
                break
            case "bluetooth": 
                root.exec("bluetoothctl power " + (root.btEnabled ? "off" : "on"))
                root.btEnabled = !root.btEnabled
                break
            case "dnd": 
                root.dndEnabled = !root.dndEnabled
                break
            case "nightLight": 
                root.exec(root.nightLightEnabled ? "pkill hyprsunset || pkill wlsunset" : "hyprsunset &")
                root.nightLightEnabled = !root.nightLightEnabled
                break
            case "stayAwake": 
                root.exec(root.stayAwakeEnabled ? "rm -f /tmp/dms_awake && pkill wayland-idle-in || pkill hypridle" : "touch /tmp/dms_awake && wayland-idle-inhibitor &")
                root.stayAwakeEnabled = !root.stayAwakeEnabled
                break
            case "micMute": 
                root.exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
                root.micMuted = !root.micMuted
                break
            case "settings": 
                root.exec("gnome-control-center || systemsettings")
                break
        }
    }

    // ============================================================
    // CONTROL CENTER UI (MULTI-MONITOR SUPPORTED)
    // ============================================================
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: ccWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "dms:control_center"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusiveZone: -1

            anchors { 
                top: true
                right: true 
            }
            margins { 
                top: root.windowMarginTop
                right: root.windowMarginRight 
            }

            implicitWidth: 380
            implicitHeight: root.pageState === "main" ? Math.min(mainColumn.implicitHeight + 36, Screen.height - 80) : Math.min(520, Screen.height - 80)
            Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            color: "transparent"

            Rectangle {
                id: ccContainer
                anchors.fill: parent
                radius: root.themeRounding
                color: root.themeBackground
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.3)
                clip: true

                // RIGHT CLICK WINDOW DRAG AREA (Left click is free for UI)
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor

                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            startX = mouse.x
                            startY = mouse.y
                            isDragging = true
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (isDragging) {
                            root.windowMarginRight -= (mouse.x - startX)
                            root.windowMarginTop += (mouse.y - startY)
                        }
                    }
                    onReleased: (mouse) => {
                        if (isDragging) {
                            isDragging = false
                            root.saveWindowPos()
                        }
                    }
                }

                // DYNAMIC HEADER WITH USER PROFILE
                Column {
                    id: headerContainer
                    width: parent.width
                    z: 10

                    Rectangle {
                        width: parent.width
                        height: 64
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 12

                            // Avatar Circle
                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: root.themeSurfaceActive
                                border.width: 1
                                border.color: Qt.alpha(root.themeBorder, 0.25)
                                clip: true
                                
                                Image {
                                    id: profilePic
                                    source: root.avatarPath + ".icon"
                                    visible: false 

                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            let currentSource = source.toString()
                                            if (currentSource.indexOf(".face.icon") !== -1) {
                                                source = root.avatarPath
                                            } else if (currentSource.indexOf(".face") !== -1) {
                                                source = "file:///var/lib/AccountsService/icons/" + (Quickshell.env("USER") || "pradun")
                                            } else {
                                                fallbackText.visible = true
                                            }
                                        } else if (status === Image.Ready) {
                                            fallbackText.visible = false
                                            avatarCanvas.requestPaint()
                                        }
                                    }
                                }

                                Canvas {
                                    id: avatarCanvas
                                    anchors.fill: parent
                                    anchors.margins: root.themeBorderSize
                                    
                                    onPaint: {
                                        if (profilePic.status !== Image.Ready) return
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.imageSmoothingEnabled = true
                                        
                                        var r = width / 2
                                        ctx.beginPath()
                                        ctx.arc(r, r, r, 0, 2 * Math.PI)
                                        ctx.clip()
                                        ctx.drawImage(profilePic.source, 0, 0, width, height)
                                    }
                                }

                                Text {
                                    id: fallbackText
                                    anchors.centerIn: parent
                                    text: "PK" 
                                    color: root.themePrimary
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    visible: false
                                }
                            }

                            // User Info
                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text { 
                                    text: root.userName
                                    color: root.themeText
                                    font.pixelSize: 15
                                    font.weight: Font.Bold 
                                }
                                Text { 
                                    text: root.systemInfo
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Medium 
                                }
                            }

                            // Action Controls (Edit & Power)
                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                // Edit Button
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: root.editMode ? root.themePrimary : (editMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text { 
                                        anchors.centerIn: parent
                                        text: root.editMode ? "󰄬" : "󰏫"
                                        color: root.editMode ? root.themeOnPrimary : root.themeText
                                        font.pixelSize: 15 
                                    }
                                    MouseArea {
                                        id: editMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.editMode = !root.editMode
                                    }
                                }

                                // Power Menu Button
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: root.powerMenuOpen ? "#FF453A" : (pwrMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text { 
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: root.powerMenuOpen ? "#ffffff" : root.themeText
                                        font.pixelSize: 15 
                                    }
                                    MouseArea {
                                        id: pwrMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.powerMenuOpen = !root.powerMenuOpen
                                    }
                                }
                            }
                        }
                    }

                    // POWER ACTION DROPDOWN
                    Rectangle {
                        width: parent.width - 32
                        height: root.powerMenuOpen ? 46 : 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 14
                        color: root.themeSurfaceActive
                        clip: true
                        visible: height > 0

                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            // Lock
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: lockM.containsMouse ? root.themeSurfaceHover : "transparent"
                                Row { 
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰌾"; color: root.themeText; font.pixelSize: 13 }
                                    Text { text: "Lock"; color: root.themeText; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                                MouseArea { 
                                    id: lockM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerMenuOpen = false
                                        root.exec("hyprlock || swaylock")
                                    }
                                }
                            }
                            // Sleep
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: sleepM.containsMouse ? root.themeSurfaceHover : "transparent"
                                Row { 
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰤄"; color: root.themeText; font.pixelSize: 13 }
                                    Text { text: "Sleep"; color: root.themeText; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                                MouseArea { 
                                    id: sleepM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerMenuOpen = false
                                        root.exec("systemctl suspend")
                                    }
                                }
                            }
                            // Reboot
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: rebM.containsMouse ? root.themeSurfaceHover : "transparent"
                                Row { 
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰜉"; color: root.themeText; font.pixelSize: 13 }
                                    Text { text: "Reboot"; color: root.themeText; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                                MouseArea { 
                                    id: rebM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerMenuOpen = false
                                        root.exec("systemctl reboot")
                                    }
                                }
                            }
                            // Power Off
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: offM.containsMouse ? "#FF453A" : "transparent"
                                Row { 
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰐥"; color: root.themeText; font.pixelSize: 13 }
                                    Text { text: "Shutdown"; color: root.themeText; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                                MouseArea { 
                                    id: offM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerMenuOpen = false
                                        root.exec("systemctl poweroff")
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 36
                        height: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Qt.alpha(root.themeBorder, 0.15)
                    }
                }

                // MAIN CONTENT PAGES
                StackLayout {
                    id: pageStack
                    anchors.top: headerContainer.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    currentIndex: root.pageState === "wifi" ? 1 : 0

                    // 1. MAIN CONTROL CENTER PAGE
                    Item {
                        ScrollView {
                            anchors.fill: parent
                            contentHeight: mainColumn.implicitHeight
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            clip: true

                            Column {
                                id: mainColumn
                                width: parent.width
                                spacing: 14

                                // QUICK SETTINGS TOGGLE GRID
                                Flow {
                                    width: parent.width
                                    spacing: 10

                                    Repeater {
                                        model: root.toggleMods
                                        
                                        DropArea {
                                            id: toggleDropArea
                                            width: (parent.width - 10) / 2
                                            height: 58
                                            keys: ["ccToggle"]
                                            property int dragIndex: index

                                            onDropped: (drag) => { 
                                                root.moveToggle(drag.source.originIndex, dragIndex)
                                                drag.accept(Qt.MoveAction)
                                            }

                                            Rectangle {
                                                id: dragItem
                                                width: toggleDropArea.width
                                                height: toggleDropArea.height 
                                                radius: 16 
                                                property int originIndex: index
                                                
                                                color: {
                                                    if (root.editMode) return root.themeSurfaceHover
                                                    if (root.isToggleActive(modelData)) return root.themePrimary
                                                    if (tMouse.containsMouse && !dragItem.Drag.active) return root.themeSurfaceHover
                                                    return root.themeSurface
                                                }
                                                
                                                border.width: 1
                                                border.color: (root.isToggleActive(modelData) && !root.editMode) ? Qt.alpha(root.themePrimary, 0.5) : Qt.alpha(root.themeBorder, 0.12)
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                Drag.active: tMouse.dragReady && root.editMode
                                                Drag.source: dragItem
                                                Drag.keys: ["ccToggle"]
                                                Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                                                states: State {
                                                    when: dragItem.Drag.active
                                                    ParentChange { target: dragItem; parent: ccContainer }
                                                    PropertyChanges { target: dragItem; opacity: 0.9; scale: 1.02; z: 100 } 
                                                }

                                                Item {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 14
                                                    anchors.rightMargin: 12

                                                    Text {
                                                        id: tIcon
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.getToggleIcon(modelData)
                                                        color: (root.isToggleActive(modelData) && !root.editMode) ? root.themeOnPrimary : root.themeText
                                                        font.pixelSize: 20
                                                    }

                                                    Text {
                                                        anchors.left: tIcon.right
                                                        anchors.leftMargin: 10
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.getToggleName(modelData)
                                                        color: (root.isToggleActive(modelData) && !root.editMode) ? root.themeOnPrimary : root.themeText
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                // REMOVE BUTTON IN EDIT MODE
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    anchors.margins: -4
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: "#FF453A"
                                                    visible: root.editMode
                                                    z: 10
                                                    
                                                    Text { anchors.centerIn: parent; text: "✕"; color: "#fff"; font.pixelSize: 10; font.weight: Font.Bold }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.removeToggle(modelData) }
                                                }

                                                // TILE CLICK HANDLER
                                                MouseArea {
                                                    id: tMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: root.editMode ? (dragReady ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                                                    property bool dragReady: false
                                                    
                                                    onPressAndHold: { if (root.editMode) dragReady = true; }
                                                    onReleased: { 
                                                        if (dragReady) { 
                                                            dragItem.Drag.drop()
                                                            dragReady = false 
                                                        } 
                                                    }
                                                    onClicked: { 
                                                        if (!dragReady && !root.editMode) { 
                                                            root.handleToggleClick(modelData) 
                                                        } 
                                                    }
                                                    drag.target: dragReady ? dragItem : null
                                                }
                                            }
                                        }
                                    }
                                }

                                // INACTIVE TILES FOR ADDING (EDIT MODE)
                                Column {
                                    width: parent.width
                                    spacing: 8
                                    visible: root.editMode && root.inactiveMods.length > 0

                                    Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.themeBorder, 0.15) }
                                    Text { text: "Tap '+' to add to Control Center:"; color: root.themeTextMuted; font.pixelSize: 11; font.weight: Font.Medium }

                                    Flow {
                                        width: parent.width
                                        spacing: 10
                                        Repeater {
                                            model: root.inactiveMods
                                            Rectangle {
                                                width: (parent.width - 10) / 2
                                                height: 58
                                                radius: 16
                                                color: Qt.alpha(root.themeSurface, 0.4)
                                                border.width: 1
                                                border.color: Qt.alpha(root.themeBorder, 0.2)
                                                
                                                Item {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 14
                                                    anchors.rightMargin: 12
                                                    Text { id: iIcon; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.getToggleIcon(modelData); color: root.themeTextMuted; font.pixelSize: 20 }
                                                    Text { anchors.left: iIcon.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.getToggleName(modelData); color: root.themeTextMuted; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                }
                                                
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    anchors.margins: -4
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: "#32D74B"
                                                    Text { anchors.centerIn: parent; text: "＋"; color: "#fff"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.addToggle(modelData) }
                                                }
                                            }
                                        }
                                    }
                                }

                                // SLIDERS SECTION (VOLUME & BRIGHTNESS) - SLIM & BUTTERY SMOOTH
                                Column {
                                    width: parent.width
                                    spacing: 10
                                    visible: !root.editMode

                                    // VOLUME SLIDER
                                    Rectangle {
                                        width: parent.width
                                        height: 44
                                        radius: 14
                                        color: root.themeSurface
                                        border.width: 1
                                        border.color: Qt.alpha(root.themeBorder, 0.08)

                                        // Slim Fill Track
                                        Rectangle {
                                            id: volFill
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 4
                                            height: parent.height - 8
                                            width: Math.max(height, ((parent.width - 8) * root.volumeLevel) / 100)
                                            radius: 10
                                            color: root.volumeMuted ? root.themeSurfaceActive : root.themePrimary
                                            
                                            Behavior on width {
                                                NumberAnimation { duration: volMouse.pressed ? 0 : 120; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14

                                            Text {
                                                text: root.volumeMuted ? "󰖁" : (root.volumeLevel > 50 ? "" : "")
                                                color: (volFill.width > 35 && !root.volumeMuted) ? root.themeOnPrimary : root.themeText
                                                font.pixelSize: 15
                                            }

                                            Text {
                                                text: "Volume"
                                                color: (volFill.width > 80 && !root.volumeMuted) ? root.themeOnPrimary : root.themeText
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: root.volumeLevel + "%"
                                                color: (volFill.width > parent.width - 50 && !root.volumeMuted) ? root.themeOnPrimary : root.themeText
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }
                                        }

                                        MouseArea {
                                            id: volMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true

                                            function updateVolume(mouseX) {
                                                let pct = Math.min(100, Math.max(0, Math.round((mouseX / width) * 100)))
                                                root.volumeLevel = pct
                                                root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (pct / 100).toFixed(2))
                                            }

                                            onPressed: (mouse) => updateVolume(mouse.x)
                                            onPositionChanged: (mouse) => {
                                                if (pressed) updateVolume(mouse.x)
                                            }
                                        }
                                    }

                                    // BRIGHTNESS SLIDER
                                    Rectangle {
                                        width: parent.width
                                        height: 44
                                        radius: 14
                                        color: root.themeSurface
                                        border.width: 1
                                        border.color: Qt.alpha(root.themeBorder, 0.08)

                                        // Slim Fill Track
                                        Rectangle {
                                            id: brightFill
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 4
                                            height: parent.height - 8
                                            width: Math.max(height, ((parent.width - 8) * root.brightnessLevel) / 100)
                                            radius: 10
                                            color: root.themePrimary
                                            
                                            Behavior on width {
                                                NumberAnimation { duration: brightMouse.pressed ? 0 : 120; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14

                                            Text {
                                                text: "󰃠"
                                                color: brightFill.width > 35 ? root.themeOnPrimary : root.themeText
                                                font.pixelSize: 15
                                            }

                                            Text {
                                                text: "Brightness"
                                                color: brightFill.width > 80 ? root.themeOnPrimary : root.themeText
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: root.brightnessLevel + "%"
                                                color: brightFill.width > parent.width - 50 ? root.themeOnPrimary : root.themeText
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }
                                        }

                                        MouseArea {
                                            id: brightMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true

                                            function updateBrightness(mouseX) {
                                                let pct = Math.min(100, Math.max(5, Math.round((mouseX / width) * 100)))
                                                root.brightnessLevel = pct
                                                root.exec("brightnessctl set " + pct + "%")
                                            }

                                            onPressed: (mouse) => updateBrightness(mouse.x)
                                            onPositionChanged: (mouse) => {
                                                if (pressed) updateBrightness(mouse.x)
                                            }
                                        }
                                    }
                                }

                                // REDESIGNED MUSIC PLAYER WIDGET
                                Rectangle {
                                    width: parent.width
                                    implicitHeight: 112
                                    radius: 18
                                    color: root.themeSurface
                                    border.width: 1
                                    border.color: Qt.alpha(root.themeBorder, 0.12)
                                    visible: !root.editMode

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        // Top Row: Album Art + Info
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: root.themeSurfaceActive
                                                border.width: 1
                                                border.color: Qt.alpha(root.themeBorder, 0.15)
                                                clip: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰎈"
                                                    color: root.themePrimary
                                                    font.pixelSize: 22
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    text: root.mediaTitle
                                                    color: root.themeText
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: root.mediaArtist
                                                    color: root.themeTextMuted
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        // Bottom Row: Centered Controls
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 16

                                            Item { Layout.fillWidth: true }

                                            // Previous Button
                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 18
                                                color: prevM.containsMouse ? root.themeSurfaceHover : root.themeSurfaceActive
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                Text { anchors.centerIn: parent; text: "󰒮"; color: root.themeText; font.pixelSize: 15 }
                                                MouseArea {
                                                    id: prevM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.exec("playerctl previous")
                                                }
                                            }

                                            // Play / Pause Button
                                            Rectangle {
                                                width: 42
                                                height: 42
                                                radius: 21
                                                color: root.themePrimary
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.mediaPlaying ? "󰏤" : "󰐊"
                                                    color: root.themeOnPrimary
                                                    font.pixelSize: 18
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.exec("playerctl play-pause")
                                                }
                                            }

                                            // Next Button
                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 18
                                                color: nextM.containsMouse ? root.themeSurfaceHover : root.themeSurfaceActive
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                Text { anchors.centerIn: parent; text: "󰒡"; color: root.themeText; font.pixelSize: 15 }
                                                MouseArea {
                                                    id: nextM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.exec("playerctl next")
                                                }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. WI-FI SUBPAGE
                    Item {
                        Column {
                            id: wifiColumn
                            width: parent.width
                            spacing: 14

                            RowLayout {
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    width: 34; height: 34; radius: 17
                                    color: backMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    Text { anchors.centerIn: parent; text: "󰁍"; color: root.themeText; font.pixelSize: 18 }
                                    MouseArea { 
                                        id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.pageState = "main" 
                                    }
                                }

                                Text { text: "Wi-Fi Networks"; color: root.themeText; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true }

                                Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: root.wifiEnabled ? root.themePrimary : root.themeSurface
                                    Rectangle { 
                                        anchors.verticalCenter: parent.verticalCenter; x: root.wifiEnabled ? 22 : 2; width: 20; height: 20; radius: 10 
                                        color: root.wifiEnabled ? root.themeOnPrimary : root.themeTextMuted
                                        Behavior on x { NumberAnimation { duration: 150 } } 
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.exec("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")) }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.themeBorder, 0.15) }

                            ListView {
                                id: wifiList
                                width: parent.width; height: ccWindow.implicitHeight - 120; clip: true
                                model: wifiModel; spacing: 6
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                
                                delegate: Rectangle {
                                    width: parent.width; height: isExpanded ? 104 : 52; radius: 14
                                    color: root.themeSurface
                                    border.width: 1
                                    border.color: model.active ? Qt.alpha(root.themePrimary, 0.4) : Qt.alpha(root.themeBorder, 0.1)
                                    clip: true
                                    property bool isExpanded: ListView.isCurrentItem

                                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    Item {
                                        width: parent.width; height: 52
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                                            Text { text: model.signal > 75 ? "󰤨" : (model.signal > 50 ? "󰤥" : "󰤢"); color: model.active ? root.themePrimary : root.themeText; font.pixelSize: 18 }
                                            Column {
                                                Layout.fillWidth: true; spacing: 1
                                                Text { text: model.ssid; color: model.active ? root.themePrimary : root.themeText; font.pixelSize: 13; font.weight: Font.Bold }
                                                Text { text: model.active ? "Connected" : (model.security ? "Secured" : "Open"); color: root.themeTextMuted; font.pixelSize: 11 }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (model.active) return
                                                if (isExpanded) { wifiList.currentIndex = -1 } 
                                                else { wifiList.currentIndex = index; passInput.forceActiveFocus() }
                                            }
                                        }
                                    }

                                    Item {
                                        anchors.bottom: parent.bottom; width: parent.width; height: 48; opacity: isExpanded ? 1 : 0
                                        visible: isExpanded; Behavior on opacity { NumberAnimation { duration: 180 } }
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                                            TextField {
                                                id: passInput; Layout.fillWidth: true; Layout.fillHeight: true
                                                placeholderText: "Password..."; color: root.themeText; echoMode: TextInput.Password
                                                background: Rectangle { color: root.themeBackground; radius: 8; border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.2) }
                                                onAccepted: root.connectWifi(model.ssid, text)
                                            }
                                            Rectangle {
                                                width: 76; height: parent.height; radius: 8; color: root.themePrimary
                                                Text { anchors.centerIn: parent; text: "Connect"; color: root.themeOnPrimary; font.pixelSize: 11; font.weight: Font.Bold }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.connectWifi(model.ssid, passInput.text) }
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
    }
}