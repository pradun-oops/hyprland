import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtCore

Scope {
    id: root

    // ============================================================
    // ADAPTIVE THEME PROPERTIES (MATCHED WITH BAR DESIGN)
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 20
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    property bool animEnabled: true
    property int animDuration: 120 
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    Process { id: rootExecProcess }
    function exec(cmd) {
        rootExecProcess.running = false
        rootExecProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        rootExecProcess.running = true
    }

    // ============================================================
    // PERSISTENCE & PINNED APPS MODEL (FILE-BASED)
    // ============================================================
    property string savedAppsFilePath: Quickshell.env("HOME") + "/.config/quickshell/json/dock_pinned.json"

    ListModel { 
        id: pinnedAppsModel 
    }

    FileView {
        id: savedAppsFile
        path: root.savedAppsFilePath
        watchChanges: false
        onLoaded: {
            try {
                let apps = JSON.parse(text())
                if (apps && apps.length > 0) {
                    pinnedAppsModel.clear()
                    for (let i = 0; i < apps.length; i++) {
                        pinnedAppsModel.append(apps[i])
                    }
                    return
                }
            } catch(e) {}
            root.loadDefaultApps()
        }
        onLoadFailed: {
            root.loadDefaultApps()
        }
    }

    Process { id: saveProcess }

    function loadDefaultApps() {
        pinnedAppsModel.clear()
        pinnedAppsModel.append({ name: "Zen Browser", iconName: "zen-browser", cmd: "zen-browser", wmClass: "zen", process: "zen" })
        pinnedAppsModel.append({ name: "Terminal", iconName: "kitty", cmd: "kitty", wmClass: "kitty", process: "kitty" })
        pinnedAppsModel.append({ name: "Files", iconName: "org.gnome.Nautilus", cmd: "nautilus", wmClass: "org.gnome.nautilus", process: "nautilus" })
        pinnedAppsModel.append({ name: "VSCodium", iconName: "vscodium", cmd: "codium", wmClass: "codium", process: "codium" })
        pinnedAppsModel.append({ name: "VirtualBox", iconName: "virtualbox", cmd: "virtualbox", wmClass: "virtualbox", process: "virtualbox" })
        pinnedAppsModel.append({ name: "Calculator", iconName: "org.gnome.Calculator", cmd: "gnome-calculator", wmClass: "org.gnome.calculator", process: "gnome-calculator" })
        pinnedAppsModel.append({ name: "Disks", iconName: "org.gnome.DiskUtility", cmd: "gnome-disks", wmClass: "org.gnome.diskutility", process: "gnome-disks" })
        pinnedAppsModel.append({ name: "Document Viewer", iconName: "org.gnome.Evince", cmd: "evince", wmClass: "org.gnome.evince", process: "evince" })
        pinnedAppsModel.append({ name: "Settings", iconName: "org.gnome.Settings", cmd: "gnome-control-center", wmClass: "org.gnome.settings", process: "gnome-control-center" })
        pinnedAppsModel.append({ name: "Easy Effects", iconName: "com.github.wwmm.easyeffects", cmd: "easyeffects", wmClass: "com.github.wwmm.easyeffects", process: "easyeffects" })
        root.savePinnedApps()
    }

    function savePinnedApps() {
        let apps = []
        for (let i = 0; i < pinnedAppsModel.count; i++) {
            let item = pinnedAppsModel.get(i)
            apps.push({ name: item.name, iconName: item.iconName, cmd: item.cmd, wmClass: item.wmClass, process: item.process })
        }
        let jsonStr = JSON.stringify(apps)
        
        saveProcess.command = ["bash", "-c", "mkdir -p $(dirname '" + root.savedAppsFilePath + "') && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + root.savedAppsFilePath + "'"]
        saveProcess.running = true
    }

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
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(parseInt(rMatch[1]) + 4, 28)
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
            } catch (e) {}
        }
    }

    Timer {
        id: bootTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: { 
            savedAppsFile.reload()
            colorFile.reload()
            generalFile.reload()
            animConfigFile.reload() 
        }
    }

    // ============================================================
    // MULTI-MONITOR DELEGATION
    // ============================================================
    Variants {
        model: Quickshell.screens
        
        delegate: PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { 
                bottom: true
            }
            
            implicitWidth: Math.max(masterDockLayout.implicitWidth + 48, 260)
            
            property int currentHitboxHeight: 8
            implicitHeight: currentHitboxHeight
            color: "transparent"

            property string outputName: dockWindow.screen ? dockWindow.screen.name : ""

            // ============================================================
            // DOCK STATE LOGIC
            // ============================================================
            property bool isOverlapped: false
            property bool dockPinnedOpen: false 
            
            property bool dockHovered: dockHoverHandler.hovered
            property bool bottomHovered: bottomHoverHandler.hovered
            property bool anyHovered: dockHovered || bottomHovered
            
            property bool dockLatchedOpen: false

            onAnyHoveredChanged: {
                if (anyHovered) { 
                    dockHideTimer.stop()
                    dockLatchedOpen = true 
                } else { 
                    dockHideTimer.restart() 
                }
            }
            
            Timer {
                id: dockHideTimer
                interval: 800 
                repeat: false
                onTriggered: {
                    if (!dockWindow.anyHovered) {
                        dockWindow.dockLatchedOpen = false
                    }
                }
            }

            property bool dockShouldBeVisible: dockPinnedOpen || dockLatchedOpen || !isOverlapped
            property var runningClients: []
            property var unpinnedApps: []

            Timer {
                id: hitboxShrinkTimer
                interval: root.animDuration + 10 
                onTriggered: {
                    if (!dockWindow.dockShouldBeVisible) {
                        dockWindow.currentHitboxHeight = 8
                    }
                }
            }

            onDockShouldBeVisibleChanged: {
                if (dockShouldBeVisible) {
                    hitboxShrinkTimer.stop()
                    currentHitboxHeight = 110
                } else {
                    hitboxShrinkTimer.restart()
                }
            }

            // ============================================================
            // APP ACTIONS
            // ============================================================
            Process { id: launchProcess }

            function launchApp(app) {
                if (!app) return
                launchProcess.command = ["bash", "-c", app.cmd + " >/dev/null 2>&1 & disown"]
                launchProcess.running = true
            }
            
            function togglePin(app) {
                if (!app) return
                let targetClass = (app.wmClass || "").toLowerCase()
                let targetCmd = (app.cmd || "").toLowerCase()
                let foundIndex = -1
                
                for (let i = 0; i < pinnedAppsModel.count; i++) {
                    let pClass = (pinnedAppsModel.get(i).wmClass || "").toLowerCase()
                    let pCmd = (pinnedAppsModel.get(i).cmd || "").toLowerCase()
                    if (targetClass === pClass || targetClass === pCmd || pClass.includes(targetClass) || targetClass.includes(pClass)) {
                        foundIndex = i
                        break
                    }
                }
                
                if (foundIndex !== -1) {
                    pinnedAppsModel.remove(foundIndex)
                } else {
                    pinnedAppsModel.append({
                        name: app.name,
                        iconName: app.iconName,
                        cmd: app.cmd,
                        wmClass: app.wmClass,
                        process: app.process
                    })
                }
                root.savePinnedApps()
            }

            function commitDragOrder(vModel) {
                let newOrder = []
                for (let i = 0; i < vModel.items.count; i++) {
                    let m = vModel.items.get(i).model
                    newOrder.push({ 
                        name: m.name, 
                        iconName: m.iconName, 
                        cmd: m.cmd, 
                        wmClass: m.wmClass, 
                        process: m.process 
                    })
                }
                pinnedAppsModel.clear()
                for (let i = 0; i < newOrder.length; i++) {
                    pinnedAppsModel.append(newOrder[i])
                }
                root.savePinnedApps()
            }

            Timer {
                id: persistTimer
                interval: 50
                onTriggered: dockWindow.commitDragOrder(visualModel)
            }

            // ============================================================
            // SMART HIDE & RUNNING APPS PARSER
            // ============================================================
            Process {
                id: clientProcess
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let output = text.trim()
                            if (!output) return
                            let data = JSON.parse(output)
                            
                            dockWindow.runningClients = data.clients || []
                            dockWindow.isOverlapped = data.overlap === true

                            let info = data.running_info || []
                            let unpinned = []
                            
                            for (let i = 0; i < info.length; i++) {
                                let app = info[i]
                                let isPinned = false
                                let rClass = app.wmClass.toLowerCase()
                                
                                for (let j = 0; j < pinnedAppsModel.count; j++) {
                                    let pClass = pinnedAppsModel.get(j).wmClass.toLowerCase()
                                    let pCmd = pinnedAppsModel.get(j).cmd.toLowerCase()
                                    
                                    if (rClass === pClass || rClass === pCmd || pClass.includes(rClass) || rClass.includes(pClass)) {
                                        isPinned = true
                                        break
                                    }
                                }
                                if (!isPinned) unpinned.push(app)
                            }
                            dockWindow.unpinnedApps = unpinned

                        } catch (e) {}
                    }
                }
            }

            Timer {
                id: clientTimer
                interval: 350
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    let pyScript = `
import json, subprocess, sys
try:
    target_mon_name = sys.argv[1] if len(sys.argv) > 1 else ""
    mon_data = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
    my_mon = next((m for m in mon_data if m.get("name") == target_mon_name), None)
    if not my_mon:
        my_mon = next((m for m in mon_data if m.get("focused")), mon_data[0] if mon_data else None)

    logical_height = my_mon.get("height", 1080) / my_mon.get("scale", 1.0)
    my_ws_id = my_mon.get("activeWorkspace", {}).get("id", 1)

    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
    classes = []
    running_info = []
    overlap = False
    seen = set()

    for c in clients:
        if not c.get("mapped") or c.get("hidden"): continue
        cls = str(c.get("class", ""))
        initial_cls = str(c.get("initialClass", ""))
        icon_name = initial_cls if initial_cls else cls
        
        if cls:
            classes.append(cls.lower())
            if cls.lower() not in seen:
                seen.add(cls.lower())
                disp = initial_cls if initial_cls else cls.capitalize()
                disp = disp.split(".")[-1] 
                running_info.append({"name": disp.capitalize(), "wmClass": cls, "process": cls, "cmd": cls, "iconName": icon_name})
        
        if c.get("workspace", {}).get("id") == my_ws_id:
            if c.get("fullscreen"):
                overlap = True
            else:
                y = c.get("at", [0,0])[1]
                h = c.get("size", [0,0])[1]
                if y + h > logical_height - 120:
                    overlap = True

    print(json.dumps({"clients": classes, "overlap": overlap, "running_info": running_info}))
except Exception:
    print(json.dumps({"clients": [], "overlap": False, "running_info": []}))
`
                    clientProcess.command = ["python3", "-c", pyScript, dockWindow.outputName]
                    clientProcess.running = true
                }
            }

            // ============================================================
            // ROOT UI
            // ============================================================
            Item {
                id: rootContainer
                anchors.fill: parent

                Item {
                    id: bottomRevealArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 8
                    z: 1
                    
                    HoverHandler { id: bottomHoverHandler }
                }

                Rectangle {
                    id: dockContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    
                    anchors.bottomMargin: dockWindow.dockShouldBeVisible ? 8 : -(dockContainer.height + 20)
                    Behavior on anchors.bottomMargin { 
                        NumberAnimation { 
                            duration: root.animEnabled ? root.animDuration : 0
                            easing.type: Easing.OutCubic // Smooth non-springy movement
                        } 
                    }
                    
                    width: masterDockLayout.implicitWidth + 28
                    height: 84
                    radius: root.themeRounding
                    color: root.themeBackground
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)

                    opacity: dockWindow.dockShouldBeVisible ? 1.0 : 0.0
                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: root.animEnabled ? root.animDuration : 0
                            easing.type: Easing.OutCubic 
                        } 
                    }

                    HoverHandler { id: dockHoverHandler }
                    
                    // DOUBLE LEFT CLICK ON EMPTY DOCK AREA TO TOGGLE DOCK PIN
                    MouseArea {
                        id: dockBackgroundClickArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        z: 1 
                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                dockWindow.dockPinnedOpen = !dockWindow.dockPinnedOpen
                            }
                        }
                    }

                    // ====================================================
                    // DOCK MASTER LAYOUT
                    // ====================================================
                    RowLayout {
                        id: masterDockLayout
                        anchors.centerIn: parent
                        spacing: 8
                        z: 10

                        // 0. APP LAUNCHER GRID ICON (LEFTMOST - 3x3 DOT GRID STYLE)
                        Item {
                            width: 52
                            height: 52

                            scale: launcherMouse.containsMouse ? 1.15 : 1.0
                            Behavior on scale { 
                                NumberAnimation { 
                                    duration: root.animEnabled ? 120 : 0
                                    easing.type: Easing.OutCubic // Completely non-springy smooth scale
                                } 
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: "#27272a"
                                border.width: 1
                                border.color: Qt.alpha("#ffffff", 0.15)

                                // 3x3 App Drawer Grid Dots
                                Grid {
                                    anchors.centerIn: parent
                                    columns: 3
                                    rows: 3
                                    spacing: 5
                                    Repeater {
                                        model: 9
                                        delegate: Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: root.themePrimary
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: launcherMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.exec(Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh spotlight open")
                                }
                            }
                        }

                        // GLASS SEPARATOR AFTER LAUNCHER
                        Rectangle {
                            Layout.preferredWidth: 2
                            Layout.preferredHeight: 40
                            radius: 1
                            color: Qt.alpha(root.themeBorder, 0.25)
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                        }

                        // 1. PINNED APPS
                        ListView {
                            id: dockList
                            Layout.preferredWidth: pinnedAppsModel.count * 72 - 8 
                            Layout.preferredHeight: 64
                            orientation: ListView.Horizontal
                            spacing: 8
                            interactive: false 

                            model: DelegateModel {
                                id: visualModel
                                model: pinnedAppsModel
                                
                                delegate: DropArea {
                                    id: delegateRoot
                                    width: 64
                                    height: 64
                                    keys: ["app"]
                                    property int visualIndex: DelegateModel.itemsIndex

                                    onEntered: (drag) => {
                                        let from = drag.source.visualIndex
                                        let to = delegateRoot.visualIndex
                                        if (from !== to) visualModel.items.move(from, to)
                                    }

                                    Item {
                                        id: iconContainer
                                        width: 64
                                        height: 64
                                        
                                        Drag.active: itemMouse.dragActive
                                        Drag.source: delegateRoot
                                        Drag.hotSpot.x: 32
                                        Drag.hotSpot.y: 32
                                        Drag.keys: ["app"]

                                        property int instanceCount: {
                                            let count = 0
                                            let target = model.wmClass.toLowerCase()
                                            for (let i = 0; i < dockWindow.runningClients.length; i++) {
                                                if (dockWindow.runningClients[i].includes(target)) count++
                                            }
                                            return count
                                        }

                                        scale: itemMouse.containsMouse && !Drag.active ? 1.15 : (Drag.active ? 1.05 : 1.0)
                                        Behavior on scale { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? 120 : 0
                                                easing.type: Easing.OutCubic // Non-springy scale
                                            } 
                                        }

                                        states: [
                                            State {
                                                when: iconContainer.Drag.active
                                                ParentChange { target: iconContainer; parent: dockContainer }
                                                PropertyChanges { target: iconContainer; opacity: 0.85 }
                                            }
                                        ]

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 16
                                            color: "transparent"

                                            ToolButton {
                                                anchors.centerIn: parent
                                                icon.name: model.iconName
                                                icon.width: 52
                                                icon.height: 52
                                                icon.color: "transparent"
                                                background: Item {}
                                                hoverEnabled: false
                                                down: false
                                            }
                                            
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 2
                                                spacing: 4
                                                visible: iconContainer.instanceCount > 0
                                                Repeater {
                                                    model: Math.min(iconContainer.instanceCount, 3)
                                                    Rectangle { 
                                                        width: 5
                                                        height: 5
                                                        radius: 2.5
                                                        color: root.themePrimary 
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: itemMouse
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            hoverEnabled: true
                                            cursorShape: dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            
                                            property bool dragActive: false

                                            drag.target: dragActive ? iconContainer : null
                                            drag.axis: Drag.XAxis
                                            
                                            // LONG LEFT CLICK -> TRIGGER POSITION REORDERING
                                            onPressAndHold: (mouse) => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    itemMouse.dragActive = true
                                                }
                                            }

                                            // SINGLE LEFT CLICK -> LAUNCH APP
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.LeftButton && !itemMouse.dragActive) {
                                                    dockWindow.launchApp(model)
                                                }
                                            }
                                            
                                            // DOUBLE RIGHT CLICK -> TOGGLE PIN / UNPIN
                                            onDoubleClicked: (mouse) => {
                                                if (mouse.button === Qt.RightButton) {
                                                    dockWindow.togglePin(model)
                                                }
                                            }
                                            
                                            onReleased: {
                                                if (itemMouse.dragActive) {
                                                    iconContainer.Drag.drop()
                                                    persistTimer.restart()
                                                    itemMouse.dragActive = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. GLASS SEPARATOR
                        Rectangle {
                            Layout.preferredWidth: 2
                            Layout.preferredHeight: 40
                            radius: 1
                            color: Qt.alpha(root.themeBorder, 0.25)
                            visible: dockWindow.unpinnedApps.length > 0
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                        }

                        // 3. UNPINNED RUNNING APPS
                        Row {
                            spacing: 8
                            visible: dockWindow.unpinnedApps.length > 0
                            
                            Repeater {
                                model: dockWindow.unpinnedApps
                                Item {
                                    width: 64
                                    height: 64
                                    
                                    scale: unpinnedMouse.containsMouse ? 1.15 : 1.0
                                    Behavior on scale { 
                                        NumberAnimation { 
                                            duration: root.animEnabled ? 120 : 0
                                            easing.type: Easing.OutCubic // Non-springy scale
                                        } 
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 16
                                        color: "transparent"

                                        ToolButton {
                                            anchors.centerIn: parent
                                            icon.name: modelData.iconName
                                            icon.width: 52
                                            icon.height: 52
                                            icon.color: "transparent"
                                            background: Item {}
                                            hoverEnabled: false
                                            down: false
                                        }
                                        
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 2
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: root.themePrimary
                                        }
                                    }

                                    MouseArea {
                                        id: unpinnedMouse
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        // SINGLE LEFT CLICK -> LAUNCH APP
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                dockWindow.launchApp(modelData)
                                            }
                                        }
                                        
                                        // DOUBLE RIGHT CLICK -> PIN APP
                                        onDoubleClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                dockWindow.togglePin(modelData)
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