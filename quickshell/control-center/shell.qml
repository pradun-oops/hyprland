import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root

    property color themeBorder: "#ffffff"
    property color themePrimary: "#a2d398"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"
    property color themeOnPrimary: "#000000" 
    
    property int themeRounding: 24
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    
    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0, 0, 0, 0.32) 
    property color themeSurfaceActive: Qt.rgba(255, 255, 255, 0.22)
    property color themeSurfaceHover: Qt.rgba(255, 255, 255, 0.12)

    property bool animEnabled: true
    property int animDuration: 220

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
    }

    property bool wifiEnabled: true
    property bool btEnabled: true
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool micMuted: false
    property bool volumeMuted: false

    property real volumeLevel: 0.5
    property real brightnessLevel: 0.5
    property bool isDraggingVolume: false
    property bool isDraggingBrightness: false

    property string mediaStatus: "Stopped"
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""

    // Dynamic properties (OS info removed)
    property string userName: Quickshell.env("USER") || "User"
    property string avatarPath: "file://" + Quickshell.env("HOME") + "/.face"

    property bool editMode: false
    property string targetMonitorName: ""

    property int windowMarginTop: 54
    property int windowMarginRight: 20

    function readJsonSync(path, fallback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path, false)
        try {
            xhr.send()
            if (xhr.status === 200 || xhr.status === 0) {
                if (xhr.responseText.trim() !== "") {
                    return JSON.parse(xhr.responseText)
                }
            }
        } catch (e) {}
        return fallback
    }

    // Process to dynamically fetch User Display Name only
    Process {
        id: sysInfoProcess
        command: [
            "bash", "-c", 
            "NAME=$(getent passwd $USER | cut -d: -f5 | cut -d, -f1); [ -z \"$NAME\" ] && NAME=$USER; echo \"$NAME\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let fName = text.trim()
                    root.userName = fName !== "" ? fName : (Quickshell.env("USER") || "User")
                } catch(e) {}
            }
        }
    }

    Process { id: saveStateProcess }
    function saveState() {
        let jsonStr = JSON.stringify({ dnd: root.dndEnabled, nightLight: root.nightLightEnabled })
        saveStateProcess.command = ["bash", "-c", "mkdir -p ~/.config/quickshell/json && echo '" + jsonStr + "' > ~/.config/quickshell/json/cc_state.json"]
        saveStateProcess.running = true
    }

    property var masterMods: ["wifi", "bluetooth", "dnd", "nightLight", "micMute", "speakerMute", "settings", "colorPicker"]
    property var toggleMods: ["wifi", "bluetooth", "dnd", "nightLight", "micMute", "settings"]
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

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let match = this.text().match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || this.text().match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (match && match[1]) { 
                    root.themeBorder = "#" + match[1]
                    root.themePrimary = "#" + match[1] 
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
                let rMatch = text().match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
                let bMatch = text().match(/border_size\s*=\s*(\d+)/)
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 100
            } catch (e) {}
        }
    }

    Process {
        id: cursorMonitorProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim()
                if (found !== "") {
                    root.targetMonitorName = found
                } else {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                        root.targetMonitorName = Hyprland.focusedMonitor.name
                    } else if (Quickshell.screens.length > 0) {
                        root.targetMonitorName = Quickshell.screens[0].name
                    }
                }
            }
        }
    }

    Component.onCompleted: { 
        exec("mkdir -p ~/.config/quickshell/json")
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        modsFile.reload()
        root.updateInactiveMods()

        sysInfoProcess.running = true // Kick off dynamic fetch

        let state = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/cc_state.json", {dnd: false, nightLight: false})
        root.dndEnabled = state.dnd === true
        root.nightLightEnabled = state.nightLight === true

        if (root.dndEnabled) root.exec("makoctl mode -a dnd 2>/dev/null || dunstctl set-paused true 2>/dev/null || swaync-client -dn 2>/dev/null")
        if (root.nightLightEnabled) root.exec("pgrep -x hyprsunset || hyprsunset -t 4500 &")

        let pyScript = `
import json, subprocess
try:
    c = json.loads(subprocess.check_output('hyprctl cursorpos -j', shell=True))
    m = json.loads(subprocess.check_output('hyprctl monitors -j', shell=True))
    cx, cy = c.get('x',0), c.get('y',0)
    res = ''
    for mon in m:
        if mon.get('focused'): res = mon['name']
    for mon in m:
        mx, my = mon.get('x',0), mon.get('y',0)
        scale = mon.get('scale', 1.0)
        w, h = mon.get('width', 1920)/scale, mon.get('height', 1080)/scale
        transform = mon.get('transform', 0)
        if transform % 2 != 0: w, h = h, w
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

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    function setVolume(val) {
        let clamped = Math.max(0.0, Math.min(1.0, val))
        root.volumeLevel = clamped
        root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(clamped * 100) + "%")
    }

    function setBrightness(val) {
        let clamped = Math.max(0.05, Math.min(1.0, val))
        root.brightnessLevel = clamped
        root.exec("brightnessctl set " + Math.round(clamped * 100) + "%")
    }

    Process {
        id: fastUpdateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim().split('|')
                if (out.length >= 2) {
                    root.volumeMuted = out[0].indexOf("MUTED") !== -1
                    root.micMuted = out[1].indexOf("MUTED") !== -1

                    if (!root.isDraggingVolume) {
                        let match = out[0].match(/Volume:\s*([\d.]+)/)
                        if (match && match[1]) {
                            root.volumeLevel = Math.min(1.0, parseFloat(match[1]))
                        }
                    }
                }
            }
        }
    }
    Timer {
        interval: 220
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fastUpdateProcess.command = ["bash", "-c", "echo \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)|$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)\""]
            fastUpdateProcess.running = true
        }
    }

    Process {
        id: slowUpdateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim().split(':::')
                if (out.length >= 4) {
                    root.wifiEnabled = out[0].indexOf("enabled") !== -1
                    root.btEnabled = out[1].indexOf("Soft blocked: yes") === -1
                    root.nightLightEnabled = out[2] !== ""
                    if (!root.isDraggingBrightness) {
                        let b = parseInt(out[3])
                        if (!isNaN(b)) root.brightnessLevel = Math.max(0.05, b / 100.0)
                    }
                }
                if (out.length >= 8) {
                    root.mediaStatus = out[4].trim()
                    root.mediaTitle = out[5].trim()
                    root.mediaArtist = out[6].trim()
                    root.mediaArt = out[7].trim()
                }
            }
        }
    }
    Timer {
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            slowUpdateProcess.command = ["bash", "-c", "echo \"$(nmcli radio wifi 2>/dev/null):::$(rfkill list bluetooth 2>/dev/null):::$(pgrep -x hyprsunset || pgrep -x wlsunset 2>/dev/null):::$(brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'):::$(playerctl status 2>/dev/null):::$(playerctl metadata title 2>/dev/null):::$(playerctl metadata artist 2>/dev/null):::$(playerctl metadata mpris:artUrl 2>/dev/null)\""]
            slowUpdateProcess.running = true
        }
    }

    function getToggleName(type) {
        switch(type) {
            case "wifi": return "Wi-Fi"
            case "bluetooth": return "Bluetooth"
            case "dnd": return "Do Not Disturb"
            case "nightLight": return "Night Shift"
            case "micMute": return "Microphone"
            case "speakerMute": return "Sound"
            case "settings": return "Settings"
            case "colorPicker": return "Color Picker"
        }
        return type
    }

    function getToggleSubtext(type) {
        switch(type) {
            case "wifi": return root.wifiEnabled ? "Connected" : "Off"
            case "bluetooth": return root.btEnabled ? "On" : "Off"
            case "dnd": return root.dndEnabled ? "On" : "Off"
            case "nightLight": return root.nightLightEnabled ? "On" : "Off"
            case "micMute": return root.micMuted ? "Muted" : "Active"
            case "speakerMute": return root.volumeMuted ? "Muted" : "Active"
            case "settings": return "System"
            case "colorPicker": return "Pipette"
        }
        return ""
    }

    function getToggleIcon(type) {
        switch(type) {
            case "wifi": return root.wifiEnabled ? "󰤨" : "󰤭"
            case "bluetooth": return root.btEnabled ? "󰂯" : "󰂲"
            case "dnd": return root.dndEnabled ? "󰍶" : "󰍷"
            case "nightLight": return root.nightLightEnabled ? "󰖔" : "󰖕"
            case "micMute": return root.micMuted ? "󰍭" : "󰍬"
            case "speakerMute": return root.volumeMuted ? "󰖁" : "󰕾"
            case "settings": return "󰒓"
            case "colorPicker": return "󰏘"
        }
        return "󰐥"
    }

    function isToggleActive(type) {
        switch(type) {
            case "wifi": return root.wifiEnabled
            case "bluetooth": return root.btEnabled
            case "dnd": return root.dndEnabled
            case "nightLight": return root.nightLightEnabled
            case "micMute": return root.micMuted
            case "speakerMute": return root.volumeMuted
            case "settings": return false
            case "colorPicker": return false
        }
        return false
    }

    function handleToggleClick(type) {
        if (root.editMode) return

        switch(type) {
            case "wifi": 
                root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh connection open")
                break
            case "bluetooth": 
                root.exec("blueman-manager")
                break
            case "dnd": 
                root.dndEnabled = !root.dndEnabled
                if (root.dndEnabled) {
                    root.exec("makoctl mode -a dnd 2>/dev/null || dunstctl set-paused true 2>/dev/null || swaync-client -dn 2>/dev/null")
                    root.exec("notify-send 'Do Not Disturb' 'Enabled' -u normal -t 2500")
                } else {
                    root.exec("makoctl mode -r dnd 2>/dev/null || dunstctl set-paused false 2>/dev/null || swaync-client -df 2>/dev/null")
                    root.exec("notify-send 'Do Not Disturb' 'Disabled' -u normal -t 2500")
                }
                root.saveState()
                break
            case "nightLight": 
                root.nightLightEnabled = !root.nightLightEnabled
                root.exec(root.nightLightEnabled ? "hyprsunset -t 4500 &" : "pkill hyprsunset || pkill wlsunset")
                root.saveState()
                break
            case "micMute": 
                root.exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && sleep 0.1 && (wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && notify-send 'Microphone' 'Muted' -t 2000 || notify-send 'Microphone' 'Unmuted' -t 2000)")
                break
            case "speakerMute":
                root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                break
            case "settings": 
                root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh setting open")
                break
            case "colorPicker": 
                root.exec("hyprpicker -a &")
                Qt.quit() 
                break
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: ccWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: root.targetMonitorName !== "" && modelData.name === root.targetMonitorName
            visible: isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-control-center"
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { 
                top: true
                bottom: true
                left: true
                right: true 
            }

            color: "transparent"

            Shortcut {
                sequence: "Escape"
                onActivated: Qt.quit()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: ccContainer
                width: 380
                implicitHeight: mainColumn.implicitHeight + 40
                height: Math.min(implicitHeight, parent.height - 70)
                
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.windowMarginTop
                anchors.rightMargin: root.windowMarginRight

                radius: root.themeRounding
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.40)
                antialiasing: true
                clip: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 18
                    contentHeight: mainColumn.implicitHeight
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    clip: true

                    Column {
                        id: mainColumn
                        width: parent.width
                        spacing: 14

                        RowLayout {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: Qt.rgba(0, 0, 0, 0.4)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.35)
                                antialiasing: true
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
                                                source = "file:///var/lib/AccountsService/icons/" + (Quickshell.env("USER") || "user")
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
                                    anchors.margins: 1
                                    antialiasing: true
                                    
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
                                    text: root.userName.charAt(0).toUpperCase() 
                                    color: root.themePrimary
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    visible: false
                                }
                            }

                            Text { 
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: root.userName
                                color: "#FFFFFF"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: root.editMode ? root.themePrimary : (editMouse.containsMouse ? root.themeSurfaceHover : Qt.rgba(0, 0, 0, 0.35))
                                    border.width: 1
                                    border.color: root.editMode ? root.themePrimary : Qt.rgba(255, 255, 255, 0.12)
                                    antialiasing: true
                                    scale: editMouse.pressed ? 0.92 : 1.0

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    Text { 
                                        anchors.centerIn: parent
                                        text: root.editMode ? "󰄬" : "󰏫"
                                        color: root.editMode ? root.themeOnPrimary : root.themeText
                                        font.pixelSize: 14 
                                    }
                                    MouseArea {
                                        id: editMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.editMode = !root.editMode
                                    }
                                }

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: pwrMouse.containsMouse ? Qt.alpha("#ef4444", 0.3) : Qt.rgba(0, 0, 0, 0.35)
                                    border.width: 1
                                    border.color: pwrMouse.containsMouse ? "#ef4444" : Qt.rgba(255, 255, 255, 0.12)
                                    antialiasing: true
                                    scale: pwrMouse.pressed ? 0.92 : 1.0

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    Text { 
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: pwrMouse.containsMouse ? "#ef4444" : root.themeText
                                        font.pixelSize: 14 
                                    }
                                    MouseArea {
                                        id: pwrMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh powermenu open")
                                            Qt.quit() 
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.1)
                        }

                        Flow {
                            width: parent.width
                            spacing: 10

                            Repeater {
                                model: root.toggleMods
                                
                                DropArea {
                                    id: toggleDropArea
                                    width: (parent.width - 10) / 2
                                    height: 64
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
                                        antialiasing: true
                                        
                                        scale: (tMouse.pressed && !root.editMode) ? 0.96 : 1.0
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? animStyle.animDuration : 0
                                                easing.type: animStyle.bounceEasing
                                                easing.overshoot: animStyle.overshoot
                                            }
                                        }
                                        
                                        color: {
                                            if (root.editMode) return Qt.rgba(0, 0, 0, 0.45)
                                            if (root.isToggleActive(modelData)) return root.themePrimary
                                            if (tMouse.containsMouse && !dragItem.Drag.active) return Qt.rgba(255, 255, 255, 0.14)
                                            return Qt.rgba(0, 0, 0, 0.32)
                                        }
                                        
                                        border.width: 1
                                        border.color: (root.isToggleActive(modelData) && !root.editMode) ? root.themePrimary : (tMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.08))

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                        Drag.active: tMouse.dragReady && root.editMode
                                        Drag.source: dragItem
                                        Drag.keys: ["ccToggle"]
                                        Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                                        states: State {
                                            when: dragItem.Drag.active
                                            ParentChange { target: dragItem; parent: ccContainer }
                                            PropertyChanges { target: dragItem; opacity: 0.9; scale: 1.05; z: 100 } 
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 12

                                            Rectangle {
                                                Layout.preferredWidth: 38
                                                Layout.preferredHeight: 38
                                                radius: 19
                                                color: (root.isToggleActive(modelData) && !root.editMode) 
                                                       ? Qt.rgba(0, 0, 0, 0.18) 
                                                       : Qt.rgba(255, 255, 255, 0.10)
                                                border.width: 1
                                                border.color: (root.isToggleActive(modelData) && !root.editMode) 
                                                              ? Qt.rgba(0, 0, 0, 0.15) 
                                                              : Qt.rgba(255, 255, 255, 0.14)
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.getToggleIcon(modelData)
                                                    color: (root.isToggleActive(modelData) && !root.editMode) ? root.themeOnPrimary : root.themeText
                                                    font.pixelSize: 18
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 2

                                                Text {
                                                    text: root.getToggleName(modelData)
                                                    color: (root.isToggleActive(modelData) && !root.editMode) ? root.themeOnPrimary : "#FFFFFF"
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    style: (root.isToggleActive(modelData) && !root.editMode) ? Text.Normal : Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                }

                                                Text {
                                                    text: root.getToggleSubtext(modelData)
                                                    color: (root.isToggleActive(modelData) && !root.editMode) ? Qt.rgba(0, 0, 0, 0.65) : root.themeTextMuted
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: -4
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: "#FF453A"
                                            visible: root.editMode
                                            z: 10
                                            antialiasing: true

                                            scale: removeMouse.pressed ? 0.88 : 1.0

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                                    easing.type: animStyle.bounceEasing
                                                    easing.overshoot: animStyle.overshoot
                                                }
                                            }
                                            
                                            Text { anchors.centerIn: parent; text: "✕"; color: "#fff"; font.pixelSize: 9; font.weight: Font.Bold }
                                            MouseArea {
                                                id: removeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.removeToggle(modelData)
                                            }
                                        }

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

                        Column {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                id: volSliderCard
                                width: parent.width
                                height: 44
                                radius: 16
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.1)
                                antialiasing: true

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: volIconMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                                        antialiasing: true
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.volumeMuted ? "󰖁" : (root.volumeLevel > 0.5 ? "󰕾" : (root.volumeLevel > 0 ? "󰖀" : "󰕿"))
                                            color: root.volumeMuted ? "#ff6b6b" : root.themeText
                                            font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: volIconMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.handleToggleClick("speakerMute")
                                        }
                                    }

                                    Item {
                                        id: volTrackContainer
                                        Layout.fillWidth: true
                                        height: parent.height

                                        Rectangle {
                                            id: volTrough
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 6
                                            radius: 3
                                            color: Qt.rgba(255, 255, 255, 0.15)
                                            antialiasing: true

                                            Rectangle {
                                                id: volActiveBar
                                                height: parent.height
                                                width: Math.max(0, Math.min(parent.width, parent.width * root.volumeLevel))
                                                radius: 3
                                                color: root.volumeMuted ? root.themeTextMuted : root.themePrimary
                                                antialiasing: true

                                                Behavior on width {
                                                    enabled: !root.isDraggingVolume && root.animEnabled
                                                    NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.horizontalCenter: parent.right
                                                    width: (volMouse.containsMouse || root.isDraggingVolume) ? 14 : 10
                                                    height: width
                                                    radius: width / 2
                                                    color: "#ffffff"
                                                    visible: root.volumeLevel > 0.02
                                                    antialiasing: true

                                                    Behavior on width {
                                                        NumberAnimation { duration: 100 }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: volMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateFromMouse(mouse) {
                                                let pct = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                                root.setVolume(pct)
                                            }

                                            onPressed: (mouse) => {
                                                root.isDraggingVolume = true
                                                updateFromMouse(mouse)
                                            }
                                            onPositionChanged: (mouse) => {
                                                if (pressed) updateFromMouse(mouse)
                                            }
                                            onReleased: {
                                                root.isDraggingVolume = false
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignRight
                                        text: root.volumeMuted ? "0%" : Math.round(root.volumeLevel * 100) + "%"
                                        color: root.volumeMuted ? root.themeTextMuted : "#FFFFFF"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }
                                }
                            }

                            Rectangle {
                                id: brightSliderCard
                                width: parent.width
                                height: 44
                                radius: 16
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.1)
                                antialiasing: true

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: brightIconMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                                        antialiasing: true
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.brightnessLevel > 0.5 ? "󰃠" : "󰃞"
                                            color: root.themeText
                                            font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: brightIconMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setBrightness(root.brightnessLevel < 0.9 ? root.brightnessLevel + 0.15 : 0.15)
                                        }
                                    }

                                    Item {
                                        id: brightTrackContainer
                                        Layout.fillWidth: true
                                        height: parent.height

                                        Rectangle {
                                            id: brightTrough
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 6
                                            radius: 3
                                            color: Qt.rgba(255, 255, 255, 0.15)
                                            antialiasing: true

                                            Rectangle {
                                                id: brightActiveBar
                                                height: parent.height
                                                width: Math.max(0, Math.min(parent.width, parent.width * root.brightnessLevel))
                                                radius: 3
                                                color: root.themePrimary
                                                antialiasing: true

                                                Behavior on width {
                                                    enabled: !root.isDraggingBrightness && root.animEnabled
                                                    NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.horizontalCenter: parent.right
                                                    width: (brightMouse.containsMouse || root.isDraggingBrightness) ? 14 : 10
                                                    height: width
                                                    radius: width / 2
                                                    color: "#ffffff"
                                                    visible: root.brightnessLevel > 0.02
                                                    antialiasing: true

                                                    Behavior on width {
                                                        NumberAnimation { duration: 100 }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: brightMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateFromMouse(mouse) {
                                                let pct = Math.max(0.05, Math.min(1.0, mouse.x / width))
                                                root.setBrightness(pct)
                                            }

                                            onPressed: (mouse) => {
                                                root.isDraggingBrightness = true
                                                updateFromMouse(mouse)
                                            }
                                            onPositionChanged: (mouse) => {
                                                if (pressed) updateFromMouse(mouse)
                                            }
                                            onReleased: {
                                                root.isDraggingBrightness = false
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(root.brightnessLevel * 100) + "%"
                                        color: "#FFFFFF"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: modernMediaCard
                            width: parent.width
                            height: 74
                            radius: 18
                            color: Qt.rgba(0, 0, 0, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.12)
                            antialiasing: true
                            clip: true
                            visible: root.mediaStatus === "Playing" || root.mediaStatus === "Paused"

                            Image {
                                id: bgAlbumArt
                                anchors.fill: parent
                                source: root.mediaArt
                                fillMode: Image.PreserveAspectCrop
                                opacity: 0.16
                                visible: status === Image.Ready
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 10
                                anchors.bottomMargin: 10
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 52
                                    Layout.preferredHeight: 52
                                    radius: 12
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.22)
                                    clip: true
                                    antialiasing: true

                                    Image {
                                        id: albumThumb
                                        anchors.fill: parent
                                        source: root.mediaArt
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🎵"
                                        font.pixelSize: 22
                                        visible: albumThumb.status !== Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        text: root.mediaTitle !== "" ? root.mediaTitle : "Unknown Track"
                                        color: "#FFFFFF"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                                    }

                                    Text {
                                        text: root.mediaArtist !== "" ? root.mediaArtist : (root.mediaStatus === "Playing" ? "Playing" : "Paused")
                                        color: root.themeTextMuted
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    }
                                }

                                Row {
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: prevBtnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.1)
                                        antialiasing: true
                                        scale: prevBtnMouse.pressed ? 0.9 : 1.0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒮"
                                            color: root.themeText
                                            font.pixelSize: 15
                                        }
                                        MouseArea {
                                            id: prevBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl previous")
                                        }
                                    }

                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: root.themePrimary
                                        antialiasing: true
                                        scale: playBtnMouse.pressed ? 0.92 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 140
                                                easing.type: animStyle.bounceEasing
                                                easing.overshoot: animStyle.overshoot
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: root.mediaStatus === "Playing" ? 0 : 1
                                            text: root.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                            color: root.themeOnPrimary
                                            font.pixelSize: 19
                                        }
                                        MouseArea {
                                            id: playBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl play-pause")
                                        }
                                    }

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: nextBtnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.1)
                                        antialiasing: true
                                        scale: nextBtnMouse.pressed ? 0.9 : 1.0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒭"
                                            color: root.themeText
                                            font.pixelSize: 15
                                        }
                                        MouseArea {
                                            id: nextBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl next")
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 8
                            visible: root.editMode && root.inactiveMods.length > 0

                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(255, 255, 255, 0.1) }
                            Text { text: "Add to Control Center:"; color: root.themeTextMuted; font.pixelSize: 11; font.weight: Font.Medium }

                            Flow {
                                width: parent.width
                                spacing: 10
                                Repeater {
                                    model: root.inactiveMods
                                    Rectangle {
                                        width: (parent.width - 10) / 2
                                        height: 64
                                        radius: 16
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.1)
                                        antialiasing: true
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: Qt.rgba(255, 255, 255, 0.08)
                                                antialiasing: true
                                                Text { anchors.centerIn: parent; text: root.getToggleIcon(modelData); color: root.themeTextMuted; font.pixelSize: 16 }
                                            }
                                            Text { Layout.fillWidth: true; text: root.getToggleName(modelData); color: root.themeTextMuted; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                        }
                                        
                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: -4
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: "#32D74B"
                                            antialiasing: true

                                            scale: addMouse.pressed ? 0.88 : 1.0

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                                    easing.type: animStyle.bounceEasing
                                                    easing.overshoot: animStyle.overshoot
                                                }
                                            }

                                            Text { anchors.centerIn: parent; text: "＋"; color: "#fff"; font.pixelSize: 10; font.weight: Font.Bold }
                                            MouseArea {
                                                id: addMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.addToggle(modelData)
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