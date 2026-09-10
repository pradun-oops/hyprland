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

    property int themeRounding: 24
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.65
    property bool animEnabled: true

    property color themeBackground: "#0d0e15" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.06)    
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.12)    
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#ffb3af"        

    QtObject {
        id: style
        property int animDuration: 380         
        property int fadeDuration: 280         
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.5
    }

    property string searchQuery: ""
    property string searchMode: "apps"
    property string activeSearchQuery: ""

    function filterApps() {
        drawerModel.clear()
        let q = searchQuery.trim().toLowerCase()
        for (let i = 0; i < root.allApps.length; i++) {
            let app = root.allApps[i]
            let dName = (app.displayName || "").trim().toLowerCase()
            let fName = (app.fileName || "").trim().toLowerCase()
            if (fName.endsWith(".desktop")) fName = fName.slice(0, -8)
            let baseFile = fName.split(".").pop()

            if (q === "" || dName.includes(q) || fName.includes(q) || baseFile.includes(q)) {
                drawerModel.append(app)
            }
        }
    }

    Timer {
        id: debounceSearchTimer
        interval: 80
        repeat: false
        property string pendingQuery: ""
        onTriggered: {
            performFileSearch(pendingQuery)
        }
    }

    Process {
        id: fileSearchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (debounceSearchTimer.pendingQuery.trim().toLowerCase() !== root.activeSearchQuery) return

                let lines = text.split('\n')
                let activeQ = root.activeSearchQuery.toLowerCase()

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line !== "") {
                        let parts = line.split('|')
                        if (parts.length >= 4) {
                            let fname = parts[2].trim()
                            let fnameLower = fname.toLowerCase()
                            let cleanFname = fnameLower.replace(/^\./, '')

                            if (fnameLower.includes(activeQ) || cleanFname.includes(activeQ)) {
                                fileModel.append({
                                    "itemType": parts[0],
                                    "filePath": parts[1],
                                    "displayName": parts[2],
                                    "fileName": parts[1].split('/').pop(),
                                    "iconName": parts[3],
                                    "isDir": false
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    function triggerFileSearch() {
        debounceSearchTimer.pendingQuery = root.searchQuery
        debounceSearchTimer.restart()
    }

    function performFileSearch(query) {
        let q = query ? query.trim().toLowerCase() : ""
        root.activeSearchQuery = q
        fileModel.clear()

        if (q === "") {
            if (fileSearchProcess.running) {
                fileSearchProcess.running = false
            }
            return
        }

        if (fileSearchProcess.running) {
            fileSearchProcess.running = false
        }

        let bashCmd = `
            q='` + q.replace(/'/g, "'\\''") + `'
            find "$HOME" -maxdepth 5 -type f -iname "*$q*" 2>/dev/null | head -n 60 | while read -r f; do
                fname=$(basename "$f")
                ext="\${fname##*.}"
                case "\${ext,,}" in
                    pdf) icon="application-pdf" ;;
                    png|jpg|jpeg|webp|gif|svg) icon="image-x-generic" ;;
                    zip|tar|gz|xz|7z|bz2|iso) icon="package-x-generic" ;;
                    txt|md|log|csv|json|py|sh|c|cpp|rs|qml|html|js|lua|conf|cfg) icon="text-x-generic" ;;
                    mp3|flac|wav|ogg|m4a) icon="audio-x-generic" ;;
                    mp4|mkv|mov|avi) icon="video-x-generic" ;;
                    doc|docx|odt|xls|xlsx|ppt|pptx) icon="x-office-document" ;;
                    *) icon="text-x-generic" ;;
                esac
                echo "file|$f|$fname|$icon"
            done
        `
        fileSearchProcess.command = ["bash", "-c", bashCmd]
        fileSearchProcess.running = true
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let borderLine = content.split('\n').find(l => l.includes('active_border'))
                if (borderLine) {
                    let match = borderLine.match(/([a-fA-F0-9]{6})/)
                    if (match && match[1]) {
                        root.themeBorder = "#" + match[1]
                        root.themePrimary = "#" + match[1]
                    }
                }
                let bgLine = content.split('\n').find(l => l.includes('background'))
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

    property var allApps: []

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
                    root.allApps = JSON.parse(content)
                    root.filterApps()
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
        onExited: { appCacheFile.reload() }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.lockedMonitor === "") fallbackMonitorTimer.start()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        
        let cachedApps = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/app_cache.json", [])
        if (cachedApps.length > 0) {
            root.allApps = cachedApps
            root.filterApps()
        }

        appCacheFile.reload()
        cacheBuilder.running = true 
    }

    ListModel { id: drawerModel }
    ListModel { id: fileModel }

    Timer { id: closeTimer; interval: 60; onTriggered: Qt.quit() }
    Process { id: launchProcess }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function executeItem(filePath) {
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
                    onActivated: Qt.quit() 
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.quit()
                }

                Rectangle {
                    id: mainContainer
                    width: Math.min(1000, parent.width - 80)
                    height: Math.min(780, parent.height - 80)
                    anchors.centerIn: parent

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.3)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                    scale: window.visible ? 1.0 : 0.85
                    opacity: window.visible ? 1.0 : 0.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.bounceEasing
                            easing.overshoot: style.overshoot
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animEnabled ? style.fadeDuration : 0
                            easing.type: style.fadeEasing
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => { mouse.accepted = true }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 20

                        Rectangle {
                            id: searchBarContainer
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: 18
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                            border.width: searchInput.activeFocus ? 2 : 1
                            border.color: searchInput.activeFocus ? root.themePrimary : Qt.rgba(1.0, 1.0, 1.0, 0.12)

                            scale: searchInput.activeFocus ? 1.01 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? style.animDuration : 0
                                    easing.type: style.bounceEasing
                                    easing.overshoot: 1.2
                                }
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: style.fadeDuration }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 10
                                spacing: 12

                                Text {
                                    text: root.searchMode === "apps" ? "🔍" : "📁"
                                    font.pixelSize: 18
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    placeholderText: root.searchMode === "apps" ? "Search apps starting with..." : "Search files starting with..."
                                    placeholderTextColor: root.themeTextMuted
                                    color: root.themeText
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    background: Item {}
                                    focus: true

                                    onTextChanged: {
                                        root.searchQuery = text
                                        if (root.searchMode === "apps") {
                                            root.filterApps()
                                        } else {
                                            root.triggerFileSearch()
                                        }
                                    }

                                    Keys.onEscapePressed: Qt.quit()
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: clearMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.2) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                    visible: searchInput.text !== ""
                                    scale: visible ? 1.0 : 0.0

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: style.animDuration
                                            easing.type: style.bounceEasing
                                        }
                                    }

                                    Text {
                                        text: "✕"
                                        color: root.themeText
                                        anchors.centerIn: parent
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }

                                Rectangle {
                                    id: modeSegment
                                    Layout.preferredWidth: 160
                                    Layout.preferredHeight: 38
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    border.width: 1
                                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.1)

                                    Rectangle {
                                        id: activePill
                                        width: (parent.width - 6) / 2
                                        height: parent.height - 6
                                        y: 3
                                        x: root.searchMode === "apps" ? 3 : (parent.width / 2) + 0
                                        radius: 10
                                        color: Qt.alpha(root.themePrimary, 0.25)
                                        border.color: root.themePrimary
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.bounceEasing
                                                easing.overshoot: style.overshoot
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Apps"
                                                color: root.searchMode === "apps" ? root.themeText : root.themeTextMuted
                                                font.weight: root.searchMode === "apps" ? Font.Bold : Font.Normal
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.searchMode = "apps"
                                                    root.filterApps()
                                                    searchInput.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Files"
                                                color: root.searchMode === "files" ? root.themeText : root.themeTextMuted
                                                font.weight: root.searchMode === "files" ? Font.Bold : Font.Normal
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.searchMode = "files"
                                                    root.triggerFileSearch()
                                                    searchInput.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: (root.searchMode === "apps" && drawerModel.count === 0) || (root.searchMode === "files" && fileModel.count === 0)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                
                                Text {
                                    text: root.searchMode === "apps" ? "🚫" : "🔎"
                                    font.pixelSize: 56
                                    color: Qt.alpha(root.themeTextMuted, 0.4)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: root.searchMode === "apps" ? "No applications found" : (root.searchQuery === "" ? "Type to search system files..." : "No matching files found")
                                    font.pixelSize: 16
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
                            visible: root.searchMode === "apps" && drawerModel.count > 0
                            
                            model: drawerModel
                            clip: true

                            cellWidth: 110
                            cellHeight: 150

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
                                    width: 100
                                    height: 140
                                    radius: 18
                                    color: appMouseArea.containsMouse ? root.themeSurfaceHover : "transparent"
                                    border.width: 1
                                    border.color: appMouseArea.containsMouse ? Qt.alpha(root.themeBorder, 0.3) : "transparent"

                                    scale: appMouseArea.pressed ? 0.94 : (appMouseArea.containsMouse ? 1.08 : 1.0)
                                    
                                    Behavior on scale { 
                                        NumberAnimation { 
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.bounceEasing
                                            easing.overshoot: style.overshoot
                                        } 
                                    }
                                    Behavior on color { 
                                        ColorAnimation { duration: style.fadeDuration } 
                                    }
                                    Behavior on border.color { 
                                        ColorAnimation { duration: style.fadeDuration } 
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 56
                                            Layout.preferredHeight: 56

                                            ToolButton {
                                                anchors.fill: parent
                                                visible: !model.iconName.startsWith("/")
                                                icon.name: !model.iconName.startsWith("/") ? model.iconName : ""
                                                icon.width: 56
                                                icon.height: 56
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
                                                sourceSize: Qt.size(56, 56)
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
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2 
                                            lineHeight: 1.15
                                            Layout.fillWidth: true
                                            Layout.maximumWidth: 88
                                            Layout.preferredHeight: 36
                                        }
                                    }

                                    MouseArea {
                                        id: appMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: executeItem(model.filePath)
                                    }
                                }
                            }
                        }

                        ListView {
                            id: fileListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.searchMode === "files" && fileModel.count > 0
                            
                            model: fileModel
                            clip: true
                            spacing: 8

                            ScrollBar.vertical: ScrollBar {
                                active: fileListView.moving || fileListView.flicking
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                width: fileListView.width
                                height: 52
                                radius: 14
                                color: fileMouseArea.containsMouse ? root.themeSurfaceHover : Qt.rgba(1.0, 1.0, 1.0, 0.03)
                                border.width: 1
                                border.color: fileMouseArea.containsMouse ? Qt.alpha(root.themeBorder, 0.3) : "transparent"

                                scale: fileMouseArea.pressed ? 0.98 : (fileMouseArea.containsMouse ? 1.02 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.bounceEasing
                                        easing.overshoot: 1.2
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: style.fadeDuration } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 14

                                    ToolButton {
                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: model.iconName !== undefined && model.iconName !== ""
                                        icon.name: model.iconName ? (model.iconName.indexOf("/") === 0 ? "" : model.iconName) : ""
                                        icon.source: model.iconName && model.iconName.indexOf("/") === 0 ? "file://" + model.iconName : ""
                                        icon.width: 26
                                        icon.height: 26
                                        icon.color: "transparent"
                                        background: Item {}
                                        hoverEnabled: false
                                        down: false
                                        padding: 0
                                    }

                                    Text {
                                        visible: !model.iconName
                                        text: model.isDir ? "📁" : "📄"
                                        font.pixelSize: 22
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: model.displayName
                                            color: root.themeText
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: model.filePath
                                            color: root.themeTextMuted
                                            font.pixelSize: 11
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: fileMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: executeItem(model.filePath)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}