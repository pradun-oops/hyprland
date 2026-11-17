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
    property color themePrimary: "#a2d398"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeOnPrimary: "#141416"

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.58)
    property color themeSurfaceHover: Qt.rgba(0.10, 0.10, 0.14, 0.74)

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

    property string userName: Quickshell.env("USER") || "User"
    property string avatarPath: "file://" + Quickshell.env("HOME") + "/.face"

    property bool editMode: false
    property string targetMonitorName: ""

    property int windowMarginTop: 54
    property int windowMarginRight: 20

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        Qt.quit()
    }

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

    property int procIndex: 0
    Process { id: execProc0 }
    Process { id: execProc1 }
    Process { id: execProc2 }
    Process { id: execProc3 }

    function exec(cmd) {
        let pool = [execProc0, execProc1, execProc2, execProc3]
        let p = pool[root.procIndex]
        root.procIndex = (root.procIndex + 1) % pool.length
        p.running = false
        p.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        p.running = true
    }

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
                } catch (e) {}
            }
        }
    }

    Process { id: saveStateProcess }
    function saveState() {
        let jsonStr = JSON.stringify({ dnd: root.dndEnabled, nightLight: root.nightLightEnabled })
        saveStateProcess.running = false
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
            } catch (e) {}
            root.updateInactiveMods()
        }
    }

    Process { id: saveToggleProcess }
    function saveToggleMods() {
        let jsonStr = JSON.stringify({ toggles: root.toggleMods })
        saveToggleProcess.running = false
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
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
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
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.targetMonitorName = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.targetMonitorName = Quickshell.screens[0].name
        }

        root.exec("mkdir -p ~/.config/quickshell/json")
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        modsFile.reload()
        root.updateInactiveMods()

        sysInfoProcess.running = true

        let state = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/cc_state.json", { dnd: false, nightLight: false })
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

    Process { id: volSetProc }
    function setVolume(val) {
        let clamped = Math.max(0.0, Math.min(1.0, val))
        root.volumeLevel = clamped
        volSetProc.running = false
        volSetProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(clamped * 100) + "% >/dev/null 2>&1"]
        volSetProc.running = true
    }

    Process { id: briSetProc }
    function setBrightness(val) {
        let clamped = Math.max(0.05, Math.min(1.0, val))
        root.brightnessLevel = clamped
        briSetProc.running = false
        briSetProc.command = ["bash", "-c", "brightnessctl set " + Math.round(clamped * 100) + "% >/dev/null 2>&1"]
        briSetProc.running = true
    }

    Process {
        id: fastUpdateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim().split("|")
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
        running: !root.isClosing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fastUpdateProcess.running) {
                fastUpdateProcess.command = ["bash", "-c", "echo \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)|$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)\""]
                fastUpdateProcess.running = true
            }
        }
    }

    Process {
        id: slowUpdateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim().split(":::")
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
        running: !root.isClosing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!slowUpdateProcess.running) {
                slowUpdateProcess.command = ["bash", "-c", "echo \"$(nmcli radio wifi 2>/dev/null):::$(rfkill list bluetooth 2>/dev/null):::$(pgrep -x hyprsunset || pgrep -x wlsunset 2>/dev/null):::$(brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'):::$(playerctl status 2>/dev/null):::$(playerctl metadata title 2>/dev/null):::$(playerctl metadata artist 2>/dev/null):::$(playerctl metadata mpris:artUrl 2>/dev/null)\""]
                slowUpdateProcess.running = true
            }
        }
    }

    function getToggleName(type) {
        switch (type) {
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
        switch (type) {
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
        switch (type) {
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
        switch (type) {
            case "wifi": return root.wifiEnabled
            case "bluetooth": return root.btEnabled
            case "dnd": return root.dndEnabled
            case "nightLight": return root.nightLightEnabled
            case "micMute": return !root.micMuted
            case "speakerMute": return !root.volumeMuted
            case "settings": return false
            case "colorPicker": return false
        }
        return false
    }

    function handleToggleClick(type) {
        if (root.editMode) return

        switch (type) {
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
                root.micMuted = !root.micMuted
                root.exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && sleep 0.1 && (wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && notify-send 'Microphone' 'Muted' -t 2000 || notify-send 'Microphone' 'Unmuted' -t 2000)")
                break
            case "speakerMute":
                root.volumeMuted = !root.volumeMuted
                root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                break
            case "settings":
                root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh setting open")
                break
            case "colorPicker":
                root.exec("sleep 0.15 && hyprpicker -a")
                root.quitApp()
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
            visible: isTargetMonitor && !root.isClosing

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-control-center"
            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
                onActivated: root.quitApp()
            }

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Rectangle {
                id: ccContainer
                width: 400
                implicitHeight: mainColumn.implicitHeight + 40
                height: Math.min(implicitHeight, parent.height - 70)

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.windowMarginTop
                anchors.rightMargin: root.windowMarginRight

                radius: root.themeRounding
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                border.width: root.themeBorderSize
                border.color: root.editMode ? Qt.alpha(root.themePrimary, 0.72) : Qt.alpha(root.themePrimary, 0.40)
                antialiasing: true
                clip: true

                property bool shown: false
                property bool layoutReady: false
                property bool panelVisible: shown && !root.isClosing

                Component.onCompleted: {
                    shown = true
                    readyTimer.start()
                }

                Timer {
                    id: readyTimer
                    interval: animStyle.enterDuration
                    repeat: false
                    onTriggered: ccContainer.layoutReady = true
                }

                opacity: panelVisible ? 1.0 : 0.0
                enabled: !root.isClosing

                transform: [
                    Scale {
                        origin.x: ccContainer.width / 2
                        origin.y: 0
                        xScale: ccContainer.panelVisible ? 1.0 : 0.94
                        yScale: ccContainer.panelVisible ? 1.0 : 0.94

                        Behavior on xScale {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && ccContainer.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                        Behavior on yScale {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && ccContainer.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                    },
                    Translate {
                        x: 0
                        y: ccContainer.panelVisible ? 0 : -12

                        Behavior on y {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && ccContainer.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                    }
                ]

                Behavior on opacity {
                    NumberAnimation {
                        duration: (root.animEnabled && !root.isClosing && ccContainer.panelVisible) ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                Behavior on height {
                    enabled: ccContainer.layoutReady && root.animEnabled && !root.isClosing
                    NumberAnimation {
                        duration: animStyle.morphDuration
                        easing.type: animStyle.expoEasing
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

                Flickable {
                    id: ccFlick
                    anchors.fill: parent
                    anchors.margins: root.themeBorderSize + 2
                    contentWidth: width
                    contentHeight: mainColumn.implicitHeight + 32
                    interactive: contentHeight > height && !root.isDraggingVolume && !root.isDraggingBrightness && !root.editMode
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Behavior on contentY {
                        NumberAnimation {
                            duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    Column {
                        id: mainColumn
                        x: 16
                        y: 16
                        width: parent.width - 32
                        spacing: 14

                        move: Transition {
                            NumberAnimation {
                                properties: "x,y"
                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                id: avatarRing
                                width: 44
                                height: 44
                                radius: 22
                                color: Qt.alpha(root.themePrimary, avatarMouse.containsMouse ? 0.24 : 0.16)
                                border.width: 1.5
                                border.color: Qt.alpha(root.themePrimary, avatarMouse.containsMouse ? 0.80 : 0.45)
                                antialiasing: true
                                clip: true
                                scale: avatarMouse.containsMouse ? 1.04 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
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
                                    anchors.margins: 2
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
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    visible: false
                                }

                                MouseArea {
                                    id: avatarMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: root.userName
                                color: root.themeText
                                font.family: root.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: root.editMode ? 17 : 10
                                    color: root.editMode
                                           ? root.themePrimary
                                           : (editMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                    border.width: 1
                                    border.color: root.editMode
                                                  ? root.themePrimary
                                                  : (editMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.14))
                                    antialiasing: true
                                    scale: editMouse.pressed ? 0.92 : (editMouse.containsMouse ? 1.05 : 1.0)

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
                                        text: root.editMode ? "󰄬" : "󰏫"
                                        font.family: root.iconFontFamily
                                        color: root.editMode ? root.themeOnPrimary : root.themeText
                                        font.pixelSize: 14
                                        rotation: root.editMode ? 360 : 0

                                        Behavior on rotation {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
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
                                    radius: pwrMouse.containsMouse ? 14 : 10
                                    color: pwrMouse.containsMouse
                                           ? Qt.rgba(0.93, 0.26, 0.26, 0.32)
                                           : root.themeSurface
                                    border.width: 1
                                    border.color: pwrMouse.containsMouse ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true
                                    scale: pwrMouse.pressed ? 0.92 : (pwrMouse.containsMouse ? 1.05 : 1.0)

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
                                        text: "󰐥"
                                        font.family: root.iconFontFamily
                                        color: pwrMouse.containsMouse ? "#ff6b6b" : root.themeText
                                        font.pixelSize: 15

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: pwrMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh powermenu open")
                                            root.quitApp()
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.10)
                        }

                        Flow {
                            id: activeTogglesFlow
                            width: parent.width
                            spacing: 10

                            move: Transition {
                                NumberAnimation {
                                    properties: "x,y"
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }

                            add: Transition {
                                NumberAnimation {
                                    properties: "opacity,scale"
                                    from: 0.6
                                    to: 1.0
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Repeater {
                                model: root.toggleMods

                                DropArea {
                                    id: toggleDropArea
                                    width: (parent.width - 10) / 2
                                    height: 62
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
                                        radius: Math.max(10, root.themeRounding - 6)
                                        property int originIndex: index
                                        property bool activeState: root.isToggleActive(modelData) && !root.editMode
                                        antialiasing: true

                                        scale: dragItem.Drag.active
                                               ? 1.03
                                               : (tMouse.pressed && !root.editMode
                                                  ? 0.97
                                                  : (tMouse.containsMouse && !root.editMode
                                                     ? 1.015
                                                     : (toggleDropArea.containsDrag ? 0.96 : 1.0)))

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        color: {
                                            if (root.editMode) return Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                            if (activeState) {
                                                return tMouse.containsMouse
                                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.28, 0.82)
                                                       : root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.74)
                                            }
                                            return (tMouse.containsMouse && !dragItem.Drag.active) ? root.themeSurfaceHover : root.themeSurface
                                        }

                                        border.width: 1
                                        border.color: {
                                            if (toggleDropArea.containsDrag) return root.themePrimary
                                            if (activeState) return Qt.alpha(root.themePrimary, tMouse.containsMouse ? 0.82 : 0.65)
                                            if (tMouse.containsMouse) return Qt.rgba(1, 1, 1, 0.24)
                                            return Qt.rgba(1, 1, 1, 0.12)
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

                                        Drag.active: tMouse.dragReady && root.editMode
                                        Drag.source: dragItem
                                        Drag.keys: ["ccToggle"]
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2

                                        states: State {
                                            when: dragItem.Drag.active
                                            ParentChange { target: dragItem; parent: ccContainer }
                                            PropertyChanges { target: dragItem; opacity: 0.94; z: 100 }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 11
                                            anchors.rightMargin: 11
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: dragItem.activeState ? 12 : 10
                                                color: dragItem.activeState
                                                       ? root.themePrimary
                                                       : Qt.rgba(1, 1, 1, 0.08)
                                                border.width: 1
                                                border.color: dragItem.activeState
                                                              ? Qt.rgba(1, 1, 1, 0.35)
                                                              : Qt.rgba(1, 1, 1, 0.12)
                                                antialiasing: true
                                                scale: (tMouse.containsMouse && !root.editMode) ? 1.06 : 1.0

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
                                                    text: root.getToggleIcon(modelData)
                                                    font.family: root.iconFontFamily
                                                    color: dragItem.activeState ? root.themeOnPrimary : root.themeText
                                                    font.pixelSize: 16

                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 2

                                                Text {
                                                    text: root.getToggleName(modelData)
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                                }

                                                Text {
                                                    text: root.getToggleSubtext(modelData)
                                                    color: dragItem.activeState ? root.themePrimary : root.themeTextMuted
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.6)

                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: tMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: root.editMode ? (dragReady ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                                            property bool dragReady: false

                                            onPressAndHold: {
                                                if (root.editMode) dragReady = true
                                            }
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

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 6
                                            width: 20
                                            height: 20
                                            radius: 6
                                            color: removeMouse.containsMouse ? "#ff6b6b" : Qt.rgba(0.93, 0.26, 0.26, 0.85)
                                            opacity: root.editMode ? 1.0 : 0.0
                                            scale: root.editMode ? (removeMouse.pressed ? 0.90 : (removeMouse.containsMouse ? 1.08 : 1.0)) : 0.0
                                            visible: opacity > 0.01
                                            z: 10
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
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅖"
                                                font.family: root.iconFontFamily
                                                color: "#ffffff"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: removeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.removeToggle(modelData)
                                            }
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
                                height: 46
                                radius: Math.max(10, root.themeRounding - 6)
                                color: (volMouse.containsMouse || root.isDraggingVolume) ? root.themeSurfaceHover : root.themeSurface
                                border.width: 1
                                border.color: (volMouse.containsMouse || root.isDraggingVolume)
                                              ? Qt.alpha(root.themePrimary, 0.55)
                                              : Qt.rgba(1, 1, 1, 0.12)
                                antialiasing: true

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

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 8
                                        color: root.volumeMuted
                                               ? Qt.rgba(0.93, 0.26, 0.26, 0.22)
                                               : (volIconMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                                        border.width: 1
                                        border.color: root.volumeMuted
                                                      ? Qt.rgba(1.0, 0.42, 0.42, 0.45)
                                                      : Qt.rgba(1, 1, 1, 0.12)
                                        antialiasing: true
                                        scale: volIconMouse.pressed ? 0.92 : (volIconMouse.containsMouse ? 1.06 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
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
                                            text: root.volumeMuted ? "󰖁" : (root.volumeLevel > 0.5 ? "󰕾" : (root.volumeLevel > 0 ? "󰖀" : "󰕿"))
                                            font.family: root.iconFontFamily
                                            color: root.volumeMuted ? "#ff6b6b" : root.themePrimary
                                            font.pixelSize: 15

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
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
                                            height: (volMouse.containsMouse || root.isDraggingVolume) ? 10 : 8
                                            radius: height / 2
                                            color: Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.08)
                                            antialiasing: true

                                            Behavior on height {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }

                                            Rectangle {
                                                id: volActiveBar
                                                height: parent.height
                                                width: Math.max(0, Math.min(parent.width, parent.width * (root.volumeMuted ? 0 : root.volumeLevel)))
                                                radius: parent.radius
                                                color: root.volumeMuted ? root.themeTextMuted : root.themePrimary
                                                antialiasing: true

                                                Behavior on width {
                                                    enabled: !root.isDraggingVolume && root.animEnabled && !root.isClosing
                                                    NumberAnimation {
                                                        duration: 130
                                                        easing.type: animStyle.expoEasing
                                                    }
                                                }
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 7
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Math.max(0, Math.min(parent.width - width, volActiveBar.width - width / 2))
                                                color: "#ffffff"
                                                border.width: 2
                                                border.color: root.themePrimary
                                                antialiasing: true
                                                scale: root.volumeMuted
                                                       ? 0.0
                                                       : (root.isDraggingVolume ? 1.12 : (volMouse.containsMouse ? 1.0 : 0.0))
                                                opacity: (volMouse.containsMouse || root.isDraggingVolume) && !root.volumeMuted ? 1.0 : 0.0

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                        easing.type: animStyle.smoothEasing
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
                                                root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(root.volumeLevel * 100) + "%")
                                            }
                                            onWheel: (wheel) => {
                                                let delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                                                root.setVolume(root.volumeLevel + delta)
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignRight
                                        text: root.volumeMuted ? "Mute" : Math.round(root.volumeLevel * 100) + "%"
                                        color: root.volumeMuted ? "#ff6b6b" : root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: brightSliderCard
                                width: parent.width
                                height: 46
                                radius: Math.max(10, root.themeRounding - 6)
                                color: (brightMouse.containsMouse || root.isDraggingBrightness) ? root.themeSurfaceHover : root.themeSurface
                                border.width: 1
                                border.color: (brightMouse.containsMouse || root.isDraggingBrightness)
                                              ? Qt.alpha(root.themePrimary, 0.55)
                                              : Qt.rgba(1, 1, 1, 0.12)
                                antialiasing: true

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

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 8
                                        color: brightIconMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.12)
                                        antialiasing: true
                                        scale: brightIconMouse.pressed ? 0.92 : (brightIconMouse.containsMouse ? 1.06 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.brightnessLevel > 0.66 ? "󰃠" : (root.brightnessLevel > 0.33 ? "󰃟" : "󰃞")
                                            font.family: root.iconFontFamily
                                            color: root.themePrimary
                                            font.pixelSize: 15
                                            rotation: Math.round(root.brightnessLevel * 90)

                                            Behavior on rotation {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
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
                                            height: (brightMouse.containsMouse || root.isDraggingBrightness) ? 10 : 8
                                            radius: height / 2
                                            color: Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.08)
                                            antialiasing: true

                                            Behavior on height {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }

                                            Rectangle {
                                                id: brightActiveBar
                                                height: parent.height
                                                width: Math.max(0, Math.min(parent.width, parent.width * root.brightnessLevel))
                                                radius: parent.radius
                                                color: root.themePrimary
                                                antialiasing: true

                                                Behavior on width {
                                                    enabled: !root.isDraggingBrightness && root.animEnabled && !root.isClosing
                                                    NumberAnimation {
                                                        duration: 130
                                                        easing.type: animStyle.expoEasing
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 7
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Math.max(0, Math.min(parent.width - width, brightActiveBar.width - width / 2))
                                                color: "#ffffff"
                                                border.width: 2
                                                border.color: root.themePrimary
                                                antialiasing: true
                                                scale: root.isDraggingBrightness ? 1.12 : (brightMouse.containsMouse ? 1.0 : 0.0)
                                                opacity: (brightMouse.containsMouse || root.isDraggingBrightness) ? 1.0 : 0.0

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                        easing.type: animStyle.smoothEasing
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
                                                root.exec("brightnessctl set " + Math.round(root.brightnessLevel * 100) + "%")
                                            }
                                            onWheel: (wheel) => {
                                                let delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                                                root.setBrightness(root.brightnessLevel + delta)
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(root.brightnessLevel * 100) + "%"
                                        color: root.themeText
                                        font.family: root.fontFamily
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
                            property bool mediaActive: root.mediaStatus === "Playing" || root.mediaStatus === "Paused"
                            width: parent.width
                            height: mediaActive ? 80 : 0
                            opacity: mediaActive ? 1.0 : 0.0
                            scale: mediaActive ? 1.0 : 0.96
                            visible: height > 0.5
                            radius: Math.max(12, root.themeRounding - 4)
                            color: mediaCardHover.containsMouse
                                   ? root.mixColor(root.themeBackground, root.themePrimary, 0.14, 0.72)
                                   : root.themeSurface
                            antialiasing: true

                            function paintRoundedArt(canvas, img, cornerRadius) {
                                var ctx = canvas.getContext("2d")
                                ctx.reset()
                                if (!img || img.status !== Image.Ready || canvas.width <= 0 || canvas.height <= 0) return

                                ctx.save()
                                ctx.imageSmoothingEnabled = true
                                var w = canvas.width
                                var h = canvas.height
                                var r = Math.min(cornerRadius, w / 2, h / 2)

                                ctx.beginPath()
                                ctx.moveTo(r, 0)
                                ctx.lineTo(w - r, 0)
                                ctx.arcTo(w, 0, w, r, r)
                                ctx.lineTo(w, h - r)
                                ctx.arcTo(w, h, w - r, h, r)
                                ctx.lineTo(r, h)
                                ctx.arcTo(0, h, 0, h - r, r)
                                ctx.lineTo(0, r)
                                ctx.arcTo(0, 0, r, 0, r)
                                ctx.closePath()
                                ctx.clip()

                                var iw = img.implicitWidth
                                var ih = img.implicitHeight
                                if (iw > 0 && ih > 0) {
                                    var sc = Math.max(w / iw, h / ih)
                                    var sw = w / sc
                                    var sh = h / sc
                                    var sx = (iw - sw) / 2
                                    var sy = (ih - sh) / 2
                                    ctx.drawImage(img.source, sx, sy, sw, sh, 0, 0, w, h)
                                } else {
                                    ctx.drawImage(img.source, 0, 0, w, h)
                                }
                                ctx.restore()
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
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
                            Behavior on color {
                                ColorAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            MouseArea {
                                id: mediaCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            Image {
                                id: albumArtLoader
                                source: root.mediaArt
                                visible: false
                                onStatusChanged: {
                                    bgArtCanvas.requestPaint()
                                    thumbArtCanvas.requestPaint()
                                }
                                onSourceChanged: {
                                    bgArtCanvas.requestPaint()
                                    thumbArtCanvas.requestPaint()
                                }
                            }

                            Canvas {
                                id: bgArtCanvas
                                anchors.fill: parent
                                antialiasing: true
                                opacity: albumArtLoader.status === Image.Ready ? (root.mediaStatus === "Playing" ? 0.24 : 0.14) : 0.0
                                visible: opacity > 0.01

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: modernMediaCard.paintRoundedArt(bgArtCanvas, albumArtLoader, modernMediaCard.radius)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: albumArtLoader.status === Image.Ready
                                antialiasing: true
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.alpha(root.themeBackground, 0.42) }
                                    GradientStop { position: 0.58; color: Qt.alpha(root.themeBackground, 0.22) }
                                    GradientStop { position: 1.0; color: Qt.alpha(root.themeBackground, 0.54) }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: root.mediaStatus === "Playing"
                                              ? Qt.alpha(root.themePrimary, mediaCardHover.containsMouse ? 0.72 : 0.52)
                                              : Qt.alpha(root.themePrimary, mediaCardHover.containsMouse ? 0.42 : 0.26)
                                antialiasing: true
                                z: 5

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 11
                                anchors.bottomMargin: 11
                                spacing: 12
                                z: 2

                                Item {
                                    Layout.preferredWidth: 56
                                    Layout.preferredHeight: 56
                                    scale: root.mediaStatus === "Playing" ? 1.0 : 0.95

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 13
                                        color: Qt.alpha(root.themePrimary, 0.16)
                                        antialiasing: true
                                        visible: albumArtLoader.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰝚"
                                            font.family: root.iconFontFamily
                                            color: root.themePrimary
                                            font.pixelSize: 22
                                        }
                                    }

                                    Canvas {
                                        id: thumbArtCanvas
                                        anchors.fill: parent
                                        antialiasing: true
                                        visible: albumArtLoader.status === Image.Ready

                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: modernMediaCard.paintRoundedArt(thumbArtCanvas, albumArtLoader, 13)
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 13
                                        color: "transparent"
                                        border.width: 1
                                        border.color: root.mediaStatus === "Playing"
                                                      ? Qt.alpha(root.themePrimary, 0.55)
                                                      : Qt.rgba(1, 1, 1, 0.18)
                                        antialiasing: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    Text {
                                        text: root.mediaTitle !== "" ? root.mediaTitle : "Unknown Track"
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: root.mediaStatus === "Playing" ? root.themePrimary : root.themeTextMuted
                                            antialiasing: true

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        Text {
                                            text: root.mediaArtist !== "" ? root.mediaArtist : (root.mediaStatus === "Playing" ? "Playing" : "Paused")
                                            color: root.mediaStatus === "Playing" ? root.themePrimary : root.themeTextMuted
                                            opacity: 0.92
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.65)

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: prevBtnMouse.containsMouse
                                               ? Qt.alpha(root.themePrimary, 0.22)
                                               : Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        border.color: prevBtnMouse.containsMouse
                                                      ? Qt.alpha(root.themePrimary, 0.55)
                                                      : Qt.rgba(1, 1, 1, 0.14)
                                        antialiasing: true
                                        scale: prevBtnMouse.pressed ? 0.90 : (prevBtnMouse.containsMouse ? 1.06 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
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
                                            text: "󰒮"
                                            font.family: root.iconFontFamily
                                            color: prevBtnMouse.containsMouse ? root.themePrimary : root.themeText
                                            font.pixelSize: 13

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
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
                                        radius: root.mediaStatus === "Playing" ? 13 : 19
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: playBtnMouse.containsMouse ? Qt.lighter(root.themePrimary, 1.08) : root.themePrimary
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.35)
                                        antialiasing: true
                                        scale: playBtnMouse.pressed ? 0.90 : (playBtnMouse.containsMouse ? 1.06 : 1.0)

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

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                            font.family: root.iconFontFamily
                                            color: root.themeOnPrimary
                                            font.pixelSize: 17
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
                                        width: 30
                                        height: 30
                                        radius: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: nextBtnMouse.containsMouse
                                               ? Qt.alpha(root.themePrimary, 0.22)
                                               : Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        border.color: nextBtnMouse.containsMouse
                                                      ? Qt.alpha(root.themePrimary, 0.55)
                                                      : Qt.rgba(1, 1, 1, 0.14)
                                        antialiasing: true
                                        scale: nextBtnMouse.pressed ? 0.90 : (nextBtnMouse.containsMouse ? 1.06 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
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
                                            text: "󰒭"
                                            font.family: root.iconFontFamily
                                            color: nextBtnMouse.containsMouse ? root.themePrimary : root.themeText
                                            font.pixelSize: 13

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
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

                        Item {
                            id: availControlsWrapper
                            property bool showAvail: root.editMode && root.inactiveMods.length > 0
                            width: parent.width
                            implicitHeight: showAvail ? availInnerCol.implicitHeight : 0
                            height: implicitHeight
                            opacity: showAvail ? 1.0 : 0.0
                            visible: height > 0.5

                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Column {
                                id: availInnerCol
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.10)
                                }

                                Text {
                                    text: "Available Controls"
                                    color: root.themePrimary
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 10

                                    move: Transition {
                                        NumberAnimation {
                                            properties: "x,y"
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }

                                    add: Transition {
                                        NumberAnimation {
                                            properties: "opacity,scale"
                                            from: 0.6
                                            to: 1.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Repeater {
                                        model: root.inactiveMods
                                        Rectangle {
                                            width: (parent.width - 10) / 2
                                            height: 58
                                            radius: Math.max(10, root.themeRounding - 6)
                                            color: addMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: addMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.5) : Qt.rgba(1, 1, 1, 0.12)
                                            antialiasing: true
                                            scale: addMouse.pressed ? 0.97 : (addMouse.containsMouse ? 1.015 : 1.0)

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
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

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 11
                                                anchors.rightMargin: 11
                                                spacing: 10

                                                Rectangle {
                                                    Layout.preferredWidth: 34
                                                    Layout.preferredHeight: 34
                                                    radius: 9
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                    antialiasing: true

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.getToggleIcon(modelData)
                                                        font.family: root.iconFontFamily
                                                        color: root.themeTextMuted
                                                        font.pixelSize: 15
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: root.getToggleName(modelData)
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    width: 22
                                                    height: 22
                                                    radius: 7
                                                    color: addMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themePrimary, 0.22)
                                                    border.width: 1
                                                    border.color: root.themePrimary
                                                    antialiasing: true
                                                    scale: addMouse.containsMouse ? 1.08 : 1.0

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

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰐕"
                                                        font.family: root.iconFontFamily
                                                        color: addMouse.containsMouse ? root.themeOnPrimary : root.themePrimary
                                                        font.pixelSize: 12
                                                        font.weight: Font.Bold

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                    }
                                                }
                                            }

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