import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
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
    property real themeBgAlpha: 1.0 // FIXED: Set to 1.0 for a completely solid background
    
    property color themeBackground: Qt.rgba(0.08, 0.08, 0.09, themeBgAlpha) 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08) 
    property color themeSurfaceActive: Qt.rgba(1.0, 1.0, 1.0, 0.22)
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.14)

    // ============================================================
    // SYSTEM STATE PROPERTIES
    // ============================================================
    property bool wifiEnabled: true
    property bool btEnabled: true
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool micMuted: false
    
    property int volumeLevel: 50
    property bool volumeMuted: false
    property int brightnessLevel: 70

    property string userName: "Pradun Kumar"
    property string systemInfo: "Fedora 43 • Hyprland"
    property string avatarPath: "file://" + Quickshell.env("HOME") + "/.face"

    // NAVIGATION & EDIT STATE
    property bool editMode: false
    property string targetMonitorName: ""

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
    property var masterMods: ["wifi", "bluetooth", "dnd", "nightLight", "micMute"]
    property var toggleMods: ["wifi", "bluetooth", "dnd", "nightLight", "micMute"]
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

    // ============================================================
    // CURSOR MONITOR DETECTION PROCESS
    // ============================================================
    Process {
        id: cursorMonitorProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim();
                
                if (found !== "") {
                    root.targetMonitorName = found;
                } else {
                    // Fallbacks if Python script unexpectedly fails
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
    // PROCESS EXECUTION & REAL-TIME POLLING
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    // FAST POLLING: 200ms updates exclusively for Audio & Brightness to react instantly to keyboard shortcuts
    Process {
        id: fastUpdateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim().split('|')
                if (out.length >= 4) {
                    // Volume
                    let volStr = out[0]
                    root.volumeMuted = volStr.indexOf("MUTED") !== -1
                    let m = volStr.match(/(\d+\.\d+)/)
                    if (m) root.volumeLevel = Math.round(parseFloat(m[1]) * 100)

                    // Mic
                    root.micMuted = out[1].indexOf("MUTED") !== -1

                    // Brightness
                    let bg = parseInt(out[2]) || 0
                    let bm = parseInt(out[3]) || 1
                    root.brightnessLevel = Math.round((bg / bm) * 100)
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
            fastUpdateProcess.command = ["bash", "-c", "echo \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)|$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)|$(brightnessctl g 2>/dev/null)|$(brightnessctl m 2>/dev/null)\""]
            fastUpdateProcess.running = true
        }
    }

    // SLOW POLLING: 2000ms for status toggles (WiFi, BT, Nightlight) to save CPU
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

    // ============================================================
    // TOGGLE METADATA & ACTIONS
    // ============================================================
    function getToggleName(type) {
        switch(type) {
            case "wifi": return "Internet"
            case "bluetooth": return "Bluetooth"
            case "dnd": return "Do Not Disturb"
            case "nightLight": return "Night Light"
            case "micMute": return "Mic Mute"
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
        }
        return false
    }

    function handleToggleClick(type) {
        if (root.editMode) return

        switch(type) {
            case "wifi": 
                // Launch user's connection dialog
                root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh connection open")
                break
            case "bluetooth": 
                // Open Blueman manager
                root.exec("blueman-manager")
                break
            case "dnd": 
                root.dndEnabled = !root.dndEnabled
                root.exec("notify-send 'Do Not Disturb' '" + (root.dndEnabled ? "Enabled" : "Disabled") + "' -u normal -t 2500")
                break
            case "nightLight": 
                root.exec(root.nightLightEnabled ? "pkill hyprsunset || pkill wlsunset" : "hyprsunset -t 4500 &")
                break
            case "micMute": 
                root.exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && sleep 0.1 && wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && notify-send 'Microphone' 'Muted' -t 2000 || notify-send 'Microphone' 'Unmuted' -t 2000")
                break
        }
    }

    // ============================================================
    // CONTROL CENTER UI
    // ============================================================
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: ccWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: root.targetMonitorName !== "" && modelData.name === root.targetMonitorName
            visible: isTargetMonitor

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "dms:control_center"
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
            // FIXED: Multiplied the calculated height by 1.2 to increase the dialog height by 20%
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

                // RIGHT CLICK WINDOW DRAG AREA
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
                                            // FIXED: Executes the powermenu script and closes this widget
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

                // MAIN CONTENT PAGE
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
                                    height: 38
                                    radius: 19
                                    color: root.themeSurface
                                    border.width: 1
                                    border.color: Qt.alpha(root.themeBorder, 0.08)

                                    // Slim Fill Track
                                    Rectangle {
                                        id: volFill
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height
                                        width: Math.max(height, (parent.width * root.volumeLevel) / 100)
                                        radius: 19
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
                                    height: 38
                                    radius: 19
                                    color: root.themeSurface
                                    border.width: 1
                                    border.color: Qt.alpha(root.themeBorder, 0.08)

                                    // Slim Fill Track
                                    Rectangle {
                                        id: brightFill
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height
                                        width: Math.max(height, (parent.width * root.brightnessLevel) / 100)
                                        radius: 19
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
                        }
                    }
                }
            }
        }
    }
}