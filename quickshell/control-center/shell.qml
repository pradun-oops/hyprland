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
    property color themeOnPrimary: "#000000" 
    
    property int themeRounding: 24
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.7 
    
    property color themeBackground: Qt.rgba(0.08, 0.08, 0.09, themeBgAlpha) 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08) 
    property color themeSurfaceActive: Qt.rgba(1.0, 1.0, 1.0, 0.22)
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.14)

    property bool wifiEnabled: true
    property bool btEnabled: true
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool micMuted: false
    property bool volumeMuted: false

    property string userName: "Pradun Kumar"
    property string systemInfo: "Fedora 43 • Hyprland"
    property string avatarPath: "file://" + Quickshell.env("HOME") + "/.face"

    property bool editMode: false
    property string targetMonitorName: ""

    property int windowMarginTop: 54
    property int windowMarginRight: 16

    function readJsonSync(path, fallback) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + path, false); 
        try {
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) {
                if (xhr.responseText.trim() !== "") {
                    return JSON.parse(xhr.responseText);
                }
            }
        } catch (e) {}
        return fallback;
    }

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
                let match = this.text().match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
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
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])
            } catch (e) {}
        }
    }

    Process {
        id: cursorMonitorProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim();
                
                if (found !== "") {
                    root.targetMonitorName = found;
                } else {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                        root.targetMonitorName = Hyprland.focusedMonitor.name;
                    } else if (Quickshell.screens.length > 0) {
                        root.targetMonitorName = Quickshell.screens[0].name;
                    }
                }
            }
        }
    }

    Component.onCompleted: { 
        exec("mkdir -p ~/.config/quickshell/json")
        colorFile.reload()
        generalFile.reload()
        modsFile.reload()
        posFile.reload()
        root.updateInactiveMods()

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

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    Process {
        id: fastUpdateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim().split('|')
                if (out.length >= 2) {
                    root.volumeMuted = out[0].indexOf("MUTED") !== -1
                    root.micMuted = out[1].indexOf("MUTED") !== -1
                }
            }
        }
    }
    Timer {
        interval: 200
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
                let out = text.trim().split('|')
                if (out.length >= 3) {
                    root.wifiEnabled = out[0].indexOf("enabled") !== -1
                    root.btEnabled = out[1].indexOf("Soft blocked: yes") === -1
                    root.nightLightEnabled = out[2] !== ""
                }
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            slowUpdateProcess.command = ["bash", "-c", "echo \"$(nmcli radio wifi 2>/dev/null)|$(rfkill list bluetooth 2>/dev/null)|$(pgrep -x hyprsunset || pgrep -x wlsunset 2>/dev/null)\""]
            slowUpdateProcess.running = true
        }
    }

    function getToggleName(type) {
        switch(type) {
            case "wifi": return "Internet"
            case "bluetooth": return "Bluetooth"
            case "dnd": return "Do Not Disturb"
            case "nightLight": return "Night Light"
            case "micMute": return "Mic Mute"
            case "speakerMute": return "Speaker Mute"
            case "settings": return "Settings"
            case "colorPicker": return "Color Picker"
        }
        return type
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
                right: true 
            }
            margins { 
                top: root.windowMarginTop
                right: root.windowMarginRight 
            }

            implicitWidth: 380
            implicitHeight: Math.min((mainColumn.implicitHeight + 96) * 1.1, Screen.height - 80)
            Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            color: "transparent"

            Shortcut {
                sequence: "Escape"
                onActivated: Qt.quit()
            }

            Rectangle {
                id: ccContainer
                anchors.fill: parent
                radius: root.themeRounding
                color: root.themeBackground
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.3)
                clip: true

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

                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

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

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: pwrMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text { 
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: root.themeText
                                        font.pixelSize: 15 
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
                    }

                    Rectangle {
                        width: parent.width - 36
                        height: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Qt.alpha(root.themeBorder, 0.15)
                    }
                }

                Item {
                    anchors.top: headerContainer.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16

                    ScrollView {
                        anchors.fill: parent
                        contentHeight: mainColumn.implicitHeight
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        clip: true

                        Column {
                            id: mainColumn
                            width: parent.width
                            spacing: 14

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
                                            
                                            scale: (tMouse.containsMouse && !dragItem.Drag.active && !root.editMode) ? 1.03 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                            
                                            color: {
                                                if (root.editMode) return root.themeSurfaceHover
                                                if (root.isToggleActive(modelData)) return root.themePrimary
                                                if (tMouse.containsMouse && !dragItem.Drag.active) return root.themeSurfaceHover
                                                return root.themeSurface
                                            }
                                            
                                            border.width: 1
                                            border.color: (root.isToggleActive(modelData) && !root.editMode) ? Qt.alpha(root.themePrimary, 0.5) : Qt.alpha(root.themeBorder, 0.12)
                                            Behavior on color { ColorAnimation { duration: 200 } }

                                            Drag.active: tMouse.dragReady && root.editMode
                                            Drag.source: dragItem
                                            Drag.keys: ["ccToggle"]
                                            Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                                            states: State {
                                                when: dragItem.Drag.active
                                                ParentChange { target: dragItem; parent: ccContainer }
                                                PropertyChanges { target: dragItem; opacity: 0.9; scale: 1.05; z: 100 } 
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
                        }
                    }
                }
            }
        }
    }
}