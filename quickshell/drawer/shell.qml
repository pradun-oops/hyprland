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
    // TARGET MONITOR LOCKING
    // ============================================================
    property string lockedMonitor: ""

    function updateTargetMonitor() {
        if (root.lockedMonitor !== "") return
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.lockedMonitor = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.lockedMonitor === "" && Quickshell.screens.length > 0) {
                root.lockedMonitor = Quickshell.screens[0].name
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { root.updateTargetMonitor() }
    }

    // ============================================================
    // THEME PROPERTIES (Parsed from Lua)
    // ============================================================
    property int themeRounding: 24
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.4 
    property bool animEnabled: true
    property int animDuration: 250        

    property color themeBackground: "#000000" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.05)    
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.1)    
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#ffb3af"        

    // ============================================================
    // DESIGN SYSTEM & RELAXED ANIMATION SYSTEM
    // ============================================================
    QtObject {
        id: style
        property int animDuration: 480         // Relaxed smooth expansion/movement duration
        property int fadeDuration: 380         // Relaxed fade-in/out duration
        property var defaultEasing: Easing.OutQuint
        property var fadeEasing: Easing.OutCubic
        property color hoverColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.12)
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let lines = content.split('\n')
                
                let borderLine = lines.find(l => l.includes('active_border'))
                if (borderLine) {
                    let match = borderLine.match(/([a-fA-F0-9]{6})/)
                    if (match && match[1]) {
                        root.themeBorder = "#" + match[1]
                        root.themePrimary = "#" + match[1]
                    }
                }
                
                let bgLine = lines.find(l => l.includes('background'))
                if (bgLine) {
                    let match = bgLine.match(/([a-fA-F0-9]{6})/)
                    if (match && match[1]) {
                        root.themeBackground = "#" + match[1]
                    }
                }
            } catch (e) {}
        }
    }

    FileView {
        id: generalConfigFile
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
            } catch (e) {}
        }
    }

    // ============================================================
    // PERSISTENCE: HIDDEN APPS & DOCK PINS
    // ============================================================
    property string hiddenAppsFilePath: Quickshell.env("HOME") + "/.config/quickshell/json/drawer_hidden.json"
    property string dockedAppsFilePath: Quickshell.env("HOME") + "/.config/quickshell/json/dock_pinned.json"

    property var hiddenAppsList: []
    property var dockedAppsList: []
    property var allApps: []
    property bool isLoaded: true // Instant load flag set to true by default
    property string activeSearchQuery: "" 

    FileView {
        id: hiddenAppsFile
        path: root.hiddenAppsFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text().trim()
                if (content !== "") {
                    let data = JSON.parse(content)
                    if (Array.isArray(data)) root.hiddenAppsList = data
                }
            } catch(e) { root.hiddenAppsList = [] }
            if (root.allApps.length > 0) performSearch(root.activeSearchQuery)
        }
        onLoadFailed: { root.hiddenAppsList = [] }
    }

    FileView {
        id: dockedAppsFile
        path: root.dockedAppsFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text().trim()
                if (content !== "") {
                    let data = JSON.parse(content)
                    if (Array.isArray(data)) root.dockedAppsList = data
                }
            } catch(e) { root.dockedAppsList = [] }
        }
        onLoadFailed: { root.dockedAppsList = [] }
    }

    Process { id: persistenceProcess }

    function saveHiddenApps() {
        let jsonStr = JSON.stringify(root.hiddenAppsList)
        persistenceProcess.command = ["bash", "-c", "mkdir -p $(dirname '" + root.hiddenAppsFilePath + "') && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + root.hiddenAppsFilePath + "'"]
        persistenceProcess.running = true
    }

    function saveDockedApps() {
        let jsonStr = JSON.stringify(root.dockedAppsList)
        persistenceProcess.command = ["bash", "-c", "mkdir -p $(dirname '" + root.dockedAppsFilePath + "') && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + root.dockedAppsFilePath + "'"]
        persistenceProcess.running = true
    }

    function isAppPinned(app) {
        if (!app) return false;
        let targetPath = app.filePath || ""
        let targetClass = (app.wmClass || "").toLowerCase()
        let targetCmd = (app.cmd || "").toLowerCase()
        for (let i = 0; i < root.dockedAppsList.length; i++) {
            let item = root.dockedAppsList[i]
            let pPath = item.filePath || ""
            let pClass = (item.wmClass || "").toLowerCase()
            let pCmd = (item.cmd || "").toLowerCase()
            
            if (targetPath && pPath && targetPath === pPath) return true
            if (targetClass && pClass && targetClass === pClass) return true
            if (targetCmd && pCmd && targetCmd === pCmd) return true
        }
        return false
    }

    function togglePinApp(app) {
        if (!app) return;
        let targetPath = app.filePath || ""
        let targetClass = (app.wmClass || "").toLowerCase()
        let targetCmd = (app.cmd || "").toLowerCase()
        let newList = []
        let found = false
        
        for (let i = 0; i < root.dockedAppsList.length; i++) {
            let item = root.dockedAppsList[i]
            let pPath = item.filePath || ""
            let pClass = (item.wmClass || "").toLowerCase()
            let pCmd = (item.cmd || "").toLowerCase()
            
            let isMatch = false
            if (targetPath && pPath && targetPath === pPath) {
                isMatch = true
            } else if (targetClass && pClass && targetClass === pClass) {
                isMatch = true
            } else if (targetCmd && pCmd && targetCmd === pCmd) {
                isMatch = true
            }
            
            if (isMatch) {
                found = true
            } else {
                newList.push(item)
            }
        }
        
        if (!found) {
            newList.push({
                name: app.displayName || app.name,
                iconName: app.iconName,
                cmd: app.cmd,
                wmClass: app.wmClass,
                process: app.process,
                filePath: app.filePath
            })
        }
        root.dockedAppsList = newList
        saveDockedApps()
    }

    function toggleHideApp(filePath) {
        let newList = [...root.hiddenAppsList]
        let index = newList.indexOf(filePath)
        let isHiding = false
        
        if (index > -1) {
            newList.splice(index, 1)
        } else {
            newList.push(filePath)
            isHiding = true
        }
        
        root.hiddenAppsList = newList
        saveHiddenApps()

        let q = root.activeSearchQuery 
        if (q === "") {
            if (isHiding) {
                for (let i = 0; i < drawerModel.count; i++) {
                    if (drawerModel.get(i).filePath === filePath) {
                        drawerModel.remove(i, 1)
                        break
                    }
                }
            } else {
                performSearch("")
            }
        } else {
            performSearch(q)
        }
    }

    // ============================================================
    // APP CACHING ENGINE
    // ============================================================
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
        id: appCacheFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/app_cache.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text().trim()
                if (content !== "") {
                    let parsedApps = JSON.parse(content)
                    root.allApps = parsedApps
                    performSearch(root.activeSearchQuery) 
                }
            } catch (e) {}
        }
    }

    Process {
        id: cacheBuilder
        command: ["python3", "-c", `
import os, glob, json, re

def find_icon(icon_name):
    if icon_name.startswith('/'): return icon_name
    exts = ['.svg', '.png', '.xpm']
    dirs = [
        os.path.expanduser('~/.local/share/icons/WhiteSur/apps/scalable'),
        os.path.expanduser('~/.local/share/icons/WhiteSur/apps/48'),
        os.path.expanduser('~/.local/share/icons/WhiteSur/devices/scalable'),
        '/usr/share/icons/hicolor/scalable/apps',
        '/usr/share/icons/hicolor/48x48/apps',
        '/usr/share/pixmaps'
    ]
    for d in dirs:
        for ext in exts:
            p = os.path.join(d, icon_name + ext)
            if os.path.exists(p): return p
    return icon_name

apps = []
seen = set()
app_dirs = ['/usr/share/applications', os.path.expanduser('~/.local/share/applications'), '/var/lib/flatpak/exports/share/applications', os.path.expanduser('~/.local/share/flatpak/exports/share/applications')]

for d in app_dirs:
    if not os.path.exists(d): continue
    for f in glob.glob(d + '/*.desktop'):
        try:
            with open(f, 'r', encoding='utf-8') as file:
                content = file.read()
                if 'NoDisplay=true' in content or 'Hidden=true' in content: continue
                name = next((l.split('=',1)[1].strip() for l in content.split('\\n') if l.startswith('Name=')), '')
                icon = next((l.split('=',1)[1].strip() for l in content.split('\\n') if l.startswith('Icon=')), 'application-x-executable')
                exec_l = next((l.split('=',1)[1].strip() for l in content.split('\\n') if l.startswith('Exec=')), '')
                cmd_clean = re.sub('%[fFuUikKc]', '', exec_l).strip()
                wm_class = next((l.split('=',1)[1].strip() for l in content.split('\\n') if l.startswith('StartupWMClass=')), '')
                if not wm_class:
                    wm_class = os.path.splitext(os.path.basename(f))[0]
                
                if not icon.startswith('/'):
                    if icon.lower().endswith(('.png', '.svg', '.xpm')): icon = icon.rsplit('.', 1)[0]
                
                if 'blueman' in icon.lower(): icon = 'blueman'
                elif 'bluetooth' in icon.lower(): icon = 'bluetooth'
                
                final_icon = find_icon(icon)
                
                if name and name.lower() not in seen:
                    seen.add(name.lower())
                    apps.append({
                        'itemType': 'app',
                        'filePath': f,
                        'displayName': name,
                        'fileName': os.path.basename(f),
                        'iconName': final_icon,
                        'cmd': cmd_clean if cmd_clean else name.lower(),
                        'wmClass': wm_class,
                        'process': wm_class
                    })
        except: pass
apps.sort(key=lambda x: x['displayName'].lower())
os.makedirs(os.path.expanduser('~/.config/quickshell/json'), exist_ok=True)
with open(os.path.expanduser('~/.config/quickshell/json/app_cache.json'), 'w') as out:
    json.dump(apps, out)
        `]
        onExited: {
            appCacheFile.reload()
            hiddenAppsFile.reload()
            dockedAppsFile.reload()
        }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.lockedMonitor === "") fallbackMonitorTimer.start()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        
        // Instant synchronous preload on startup so items paint immediately
        root.hiddenAppsList = readJsonSync(root.hiddenAppsFilePath, [])
        root.dockedAppsList = readJsonSync(root.dockedAppsFilePath, [])
        let cachedApps = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/app_cache.json", [])
        
        if (cachedApps.length > 0) {
            root.allApps = cachedApps
            performSearch("") 
        }

        appCacheFile.reload()
        hiddenAppsFile.reload()
        dockedAppsFile.reload()

        cacheBuilder.running = true 
    }

    // ============================================================
    // LOGIC & MODELS
    // ============================================================
    ListModel { id: drawerModel }

    Timer { id: closeTimer; interval: 60; onTriggered: Qt.quit() }
    Process { id: launchProcess }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function executeApp(filePath) {
        let cmd = ""
        if (filePath.endsWith(".desktop")) {
            let desktopBase = filePath.split('/').pop()
            cmd = "gtk-launch " + escapeShell(desktopBase) + " 2>/dev/null || gio launch " + escapeShell(filePath) + " 2>/dev/null || xdg-open " + escapeShell(filePath) + " & disown"
        } else {
            cmd = "xdg-open " + escapeShell(filePath) + " & disown"
        }
        launchProcess.command = ["bash", "-c", cmd]
        launchProcess.running = true
        closeTimer.start()
    }

    function performSearch(query) {
        let q = query ? query.trim().toLowerCase() : ""
        root.activeSearchQuery = q 
        drawerModel.clear()
        
        for (let i = 0; i < root.allApps.length; i++) {
            let app = root.allApps[i]
            let isHidden = root.hiddenAppsList.indexOf(app.filePath) > -1

            if (q === "") {
                if (!isHidden) {
                    drawerModel.append(app)
                }
            } else {
                if (app.displayName.toLowerCase().includes(q) || app.fileName.toLowerCase().includes(q)) {
                    drawerModel.append(app)
                }
            }
        }
    }

    // ============================================================
    // CONTEXT MENU STATE
    // ============================================================
    property bool contextMenuOpen: false
    property var contextMenuApp: null
    property real menuX: 0
    property real menuY: 0

    // ============================================================
    // UI RENDERING
    // ============================================================
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window
            required property var modelData
            screen: modelData

            visible: root.lockedMonitor !== "" && modelData.name === root.lockedMonitor

            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "qs-drawer"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Item {
                id: rootWindowItem 
                anchors.fill: parent

                Shortcut { 
                    sequence: "Escape" 
                    onActivated: {
                        if (root.contextMenuOpen) {
                            root.contextMenuOpen = false
                        } else {
                            Qt.quit()
                        }
                    } 
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.contextMenuOpen) {
                            root.contextMenuOpen = false
                        } else {
                            Qt.quit()
                        }
                    }
                }

                Rectangle {
                    id: mainContainer
                    width: Math.min(1000, parent.width - 80)
                    height: Math.min(760, parent.height - 80)
                    anchors.centerIn: parent

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.25)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                    // Instantly visible with no scaling or opacity delay
                    scale: 1.0
                    opacity: 1.0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => {
                            if (root.contextMenuOpen) root.contextMenuOpen = false
                            mouse.accepted = true
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        spacing: 24

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: 28
                            color: root.themeSurface
                            border.width: 1
                            border.color: Qt.alpha(root.themeBorder, searchInput.activeFocus ? 0.6 : 0.15)
                            
                            Behavior on border.color { 
                                ColorAnimation { 
                                    duration: root.animEnabled ? style.fadeDuration : 0
                                    easing.type: style.fadeEasing 
                                } 
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 16

                                Text {
                                    text: "🔍"
                                    font.pixelSize: 20
                                    color: searchInput.text !== "" ? root.themePrimary : root.themeTextMuted
                                    Layout.alignment: Qt.AlignVCenter
                                    Behavior on color { 
                                        ColorAnimation { 
                                            duration: root.animEnabled ? style.fadeDuration : 0
                                            easing.type: style.fadeEasing 
                                        } 
                                    }
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    font.pixelSize: 20
                                    font.weight: Font.Medium
                                    color: root.themeText
                                    
                                    placeholderText: "Search apps..."
                                    placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.6)
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}

                                    Component.onCompleted: searchInput.forceActiveFocus()

                                    onTextChanged: root.performSearch(text)

                                    onAccepted: {
                                        if (drawerModel.count > 0) {
                                            let item = drawerModel.get(0)
                                            executeApp(item.filePath)
                                        }
                                    }

                                    Keys.onEscapePressed: (event) => {
                                        if (root.contextMenuOpen) {
                                            root.contextMenuOpen = false
                                        } else {
                                            Qt.quit()
                                        }
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: drawerModel.count === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                
                                Text {
                                    text: "🚫"
                                    font.pixelSize: 64
                                    color: Qt.alpha(root.themeTextMuted, 0.3)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "No apps found"
                                    font.pixelSize: 18
                                    font.weight: Font.Medium
                                    color: root.themeTextMuted
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        GridView {
                            id: appGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: drawerModel.count > 0
                            
                            model: drawerModel
                            clip: true

                            // Removed entry add/displaced animations to prevent pop-in delay

                            cellWidth: 110
                            cellHeight: 145

                            leftMargin: Math.max(0, (width - (Math.floor(width / cellWidth) * cellWidth)) / 2)

                            ScrollBar.vertical: ScrollBar {
                                active: appGrid.moving || appGrid.flicking
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Item {
                                id: gridDelegate
                                width: appGrid.cellWidth
                                height: appGrid.cellHeight

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 98
                                    height: 135
                                    radius: 16
                                    color: appMouseArea.containsMouse ? root.themeSurfaceHover : "transparent"
                                    border.width: 1
                                    border.color: appMouseArea.containsMouse ? Qt.alpha(root.themeBorder, 0.2) : "transparent"

                                    scale: appMouseArea.containsMouse ? 1.05 : 1.0
                                    
                                    Behavior on color { 
                                        ColorAnimation { 
                                            duration: root.animEnabled ? style.fadeDuration : 0
                                            easing.type: style.fadeEasing 
                                        } 
                                    }
                                    Behavior on border.color { 
                                        ColorAnimation { 
                                            duration: root.animEnabled ? style.fadeDuration : 0
                                            easing.type: style.fadeEasing 
                                        } 
                                    }
                                    Behavior on scale { 
                                        NumberAnimation { 
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.defaultEasing 
                                        } 
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 64
                                            Layout.preferredHeight: 64

                                            ToolButton {
                                                anchors.fill: parent
                                                visible: !model.iconName.startsWith("/")
                                                icon.name: !model.iconName.startsWith("/") ? model.iconName : ""
                                                icon.width: 64
                                                icon.height: 64
                                                icon.color: "transparent"
                                                background: Item {}
                                                hoverEnabled: false
                                                down: false
                                                padding: 0
                                            }

                                            Image {
                                                anchors.fill: parent
                                                visible: model.iconName.startsWith("/")
                                                source: model.iconName.startsWith("/") ? "file://" + model.iconName : ""
                                                sourceSize: Qt.size(64, 64)
                                                fillMode: Image.PreserveAspectFit
                                            }
                                        }

                                        Text {
                                            text: model.displayName
                                            color: root.themeText
                                            font.pixelSize: 12
                                            font.weight: appMouseArea.containsMouse ? Font.Bold : Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignTop
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            lineHeight: 1.15
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                        }
                                    }

                                    MouseArea {
                                        id: appMouseArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                root.contextMenuOpen = false
                                                executeApp(model.filePath)
                                            } else if (mouse.button === Qt.RightButton) {
                                                root.contextMenuApp = model
                                                
                                                let pos = appMouseArea.mapToItem(mainContainer, mouse.x, mouse.y)
                                                
                                                root.menuX = Math.min(mainContainer.width - 180, pos.x)
                                                root.menuY = Math.min(mainContainer.height - 180, pos.y)
                                                root.contextMenuOpen = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 4. CONTEXT MENU POPUP DIALOG & TRAP LAYER ---
                Item {
                    anchors.fill: mainContainer
                    visible: root.contextMenuOpen
                    z: 100

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.contextMenuOpen = false
                        onWheel: root.contextMenuOpen = false
                    }

                    Rectangle {
                        id: contextMenu
                        x: root.menuX
                        y: root.menuY
                        width: 170
                        implicitHeight: menuLayout.implicitHeight + 16
                        radius: 12
                        
                        color: Qt.alpha(root.themeBackground, 0.95)
                        border.width: 1
                        border.color: Qt.alpha(root.themeBorder, 0.4)

                        ColumnLayout {
                            id: menuLayout
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 8
                                color: openMouse.containsMouse ? root.themeSurfaceHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    Text { text: "📂"; color: root.themePrimary; font.pixelSize: 14 }
                                    Text { text: "Open"; color: root.themeText; font.pixelSize: 13; font.weight: Font.Medium }
                                }

                                MouseArea {
                                    id: openMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.contextMenuOpen = false
                                        if (root.contextMenuApp) executeApp(root.contextMenuApp.filePath)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 8
                                color: pinMouse.containsMouse ? root.themeSurfaceHover : "transparent"

                                property bool isPinned: root.contextMenuApp ? root.isAppPinned(root.contextMenuApp) : false

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    Text { text: parent.parent.isPinned ? "📌" : "📍"; color: root.themeText; font.pixelSize: 14 }
                                    Text { text: parent.parent.isPinned ? "Unpin from Dock" : "Pin to Dock"; color: root.themeText; font.pixelSize: 13; font.weight: Font.Medium }
                                }

                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.contextMenuOpen = false
                                        if (root.contextMenuApp) root.togglePinApp(root.contextMenuApp)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 8
                                color: hideMouse.containsMouse ? Qt.alpha("#ff4b6e", 0.2) : "transparent"

                                property bool isHidden: root.contextMenuApp ? root.hiddenAppsList.indexOf(root.contextMenuApp.filePath) > -1 : false

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    Text { text: parent.parent.isHidden ? "👁️" : "🙈"; color: "#ff4b6e"; font.pixelSize: 14 }
                                    Text { text: parent.parent.isHidden ? "Unhide" : "Hide"; color: "#ff4b6e"; font.pixelSize: 13; font.weight: Font.Medium }
                                }

                                MouseArea {
                                    id: hideMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.contextMenuOpen = false
                                        if (root.contextMenuApp) root.toggleHideApp(root.contextMenuApp.filePath)
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