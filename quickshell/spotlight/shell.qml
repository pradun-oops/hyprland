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

    // Target monitor property
    property string lockedMonitor: ""

    // --- STRICT MONITOR PINNING LOGIC ---
    function updateTargetMonitor() {
        if (Quickshell.screens.length === 0) return

        let external = Quickshell.screens.find(s => !s.name.startsWith("eDP") && !s.name.startsWith("LVDS"))
        
        if (external) {
            root.lockedMonitor = external.name
        } else if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.lockedMonitor = Hyprland.focusedMonitor.name
        } else {
            root.lockedMonitor = Quickshell.screens[0].name
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.updateTargetMonitor()
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.updateTargetMonitor()
        }
    }

    // --- DYNAMIC ADAPTIVE PROPERTIES ---
    property int themeRounding: 14
    property int themeBorderSize: 2
    property real themeBgAlpha: 1.0
    property bool animEnabled: true
    property int animDuration: 220       

    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08)    
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#ffb3af"        

    // ============================================================
    // DYNAMIC CONFIG PARSERS
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
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
                }
                let bgMatch = content.match(/background\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/background\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (bgMatch && bgMatch[1]) {
                    root.themeBackground = "#" + bgMatch[1]
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
                let enabledMatch = content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let winInMatch = content.match(/leaf\s*=\s*"windowsIn"[\s\S]*?speed\s*=\s*([0-9.]+)/)
                if (winInMatch && winInMatch[1]) {
                    root.animDuration = Math.round(parseFloat(winInMatch[1]) * 40)
                }
            } catch (e) {}
        }
    }

    // ============================================================
    // APP CACHING ENGINE
    // ============================================================
    property var allApps: []
    property bool isLoaded: false 

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
                    performSearch("") 
                    root.isLoaded = true
                }
            } catch (e) {}
        }
        onLoadFailed: {
            root.isLoaded = true 
        }
    }

    Process {
        id: cacheBuilder
        command: ["python3", "-c", `
import os, glob, json
apps = []
seen = set()

dirs = [
    '/usr/share/applications',
    os.path.expanduser('~/.local/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    os.path.expanduser('~/.local/share/flatpak/exports/share/applications')
]

for d in dirs:
    if not os.path.exists(d): continue
    for f in glob.glob(d + '/*.desktop'):
        try:
            with open(f, 'r', encoding='utf-8') as file:
                content = file.read()
                if 'NoDisplay=true' in content or 'Hidden=true' in content: continue
                name = next((l.split('=',1)[1].strip() for l in content.split('\\n') if l.startswith('Name=')), '')
                icon = next((l.split('=',1)[1].strip() for l in content.split('\\n') if l.startswith('Icon=')), 'application-x-executable')
                if name and name.lower() not in seen:
                    seen.add(name.lower())
                    apps.append({'itemType': 'app', 'filePath': f, 'displayName': name, 'fileName': os.path.basename(f), 'iconName': icon})
        except: pass
apps.sort(key=lambda x: x['displayName'].lower())
os.makedirs(os.path.expanduser('~/.config/quickshell/json'), exist_ok=True)
with open(os.path.expanduser('~/.config/quickshell/json/app_cache.json'), 'w') as out:
    json.dump(apps, out)
        `]
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        appCacheFile.reload()
        cacheBuilder.running = true 
    }

    Timer {
        id: closeTimer
        interval: 60
        onTriggered: Qt.quit()
    }

    ListModel {
        id: searchResultsModel
    }

    // ============================================================
    // SEARCH & EXECUTION LOGIC
    // ============================================================
    Process { id: launchProcess }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function executeResult(itemType, filePath, fileName) {
        let cmd = ""
        if (itemType === "app" || filePath.endsWith(".desktop")) {
            let desktopBase = filePath.split('/').pop()
            cmd = "gtk-launch " + escapeShell(desktopBase) + " 2>/dev/null || gio launch " + escapeShell(filePath) + " 2>/dev/null || xdg-open " + escapeShell(filePath) + " & disown"
        } else {
            cmd = "xdg-open " + escapeShell(filePath) + " & disown"
        }
        launchProcess.command = ["bash", "-c", cmd]
        launchProcess.running = true
        closeTimer.start()
    }

    Process {
        id: fileSearchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split('\n')
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line !== "") {
                        let parts = line.split('|')
                        if (parts.length >= 4) {
                            searchResultsModel.append({
                                "itemType": parts[0],
                                "filePath": parts[1],
                                "displayName": parts[2],
                                "fileName": parts[1].split('/').pop(),
                                "iconName": parts[3]
                            })
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: debounceSearchTimer
        interval: 80
        repeat: false
        property string pendingQuery: ""
        onTriggered: {
            performSearch(pendingQuery)
        }
    }

    function performSearch(query) {
        let q = query ? query.trim().toLowerCase() : ""
        searchResultsModel.clear()
        
        let count = 0
        let maxApps = (q === "") ? root.allApps.length : 12;
        
        for (let i = 0; i < root.allApps.length; i++) {
            if (count >= maxApps) break; 
            let app = root.allApps[i]
            if (q === "" || app.displayName.toLowerCase().includes(q) || app.fileName.toLowerCase().includes(q)) {
                searchResultsModel.append(app)
                count++
            }
        }

        if (q.length > 0) {
            if (fileSearchProcess.running) {
                fileSearchProcess.running = false
            }

            let bashCmd = `
                q='` + q.replace(/'/g, "'\\''") + `'
                find "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Videos" "$HOME/Desktop" "$HOME" -maxdepth 3 -type f -not -path '*/.*' -iname "*$q*" 2>/dev/null | grep -v -E "(\\.desktop|\\.cache|\\.local|\\.git|node_modules)" | head -n 10 | while read -r f; do
                    fname=$(basename "$f")
                    ext="\${fname##*.}"
                    case "\${ext,,}" in
                        pdf) icon="application-pdf" ;;
                        png|jpg|jpeg|webp|gif|svg) icon="image-x-generic" ;;
                        zip|tar|gz|xz|7z|bz2|iso) icon="package-x-generic" ;;
                        txt|md|log|csv|json|py|sh|c|cpp|rs|qml|html|js) icon="text-x-generic" ;;
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
    }

    // ============================================================
    // PANEL WINDOW PER SCREEN
    // ============================================================
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: spotlightWindow
            required property var modelData
            screen: modelData

            visible: root.lockedMonitor !== "" && modelData.name === root.lockedMonitor

            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "qs-spotlight"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            Shortcut {
                sequence: "Escape"
                onActivated: Qt.quit()
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: searchContainer
                width: Math.min(720, parent.width - 40)
                implicitHeight: mainLayout.implicitHeight + 24
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.35)
                color: root.themeBackground

                scale: root.isLoaded ? 1.0 : 0.96
                opacity: root.isLoaded ? 1.0 : 0.0

                Behavior on scale {
                    enabled: root.animEnabled
                    NumberAnimation {
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    enabled: root.animEnabled
                    NumberAnimation { 
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    id: mainLayout
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 10

                    // 1. SEARCH BAR
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        spacing: 12

                        Text {
                            text: "" 
                            font.pixelSize: 18
                            color: root.themePrimary
                            Layout.leftMargin: 8
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            font.pixelSize: 18
                            font.weight: Font.Medium
                            color: root.themeText
                            
                            placeholderText: "Search apps, documents, and files..."
                            placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.5)
                            verticalAlignment: TextInput.AlignVCenter

                            background: Item {}

                            Component.onCompleted: {
                                searchInput.forceActiveFocus()
                            }

                            Keys.onDownPressed: (event) => {
                                if (resultsList.count > 0) {
                                    resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, resultsList.count - 1)
                                    resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            }

                            Keys.onUpPressed: (event) => {
                                if (resultsList.count > 0) {
                                    resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0)
                                    resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            }

                            Keys.onEscapePressed: (event) => {
                                Qt.quit()
                                event.accepted = true
                            }

                            onTextChanged: {
                                debounceSearchTimer.pendingQuery = text
                                debounceSearchTimer.restart()
                            }

                            onAccepted: {
                                if (resultsList.count > 0 && resultsList.currentIndex >= 0 && resultsList.currentIndex < resultsList.count) {
                                    let item = searchResultsModel.get(resultsList.currentIndex)
                                    executeResult(item.itemType, item.filePath, item.fileName)
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 22
                            Layout.rightMargin: 4
                            radius: 6 
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "ESC"
                                color: root.themeTextMuted
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(root.themeBorder, 0.20)
                        visible: searchResultsModel.count > 0 || searchInput.text.trim() !== ""
                    }

                    // 3. NO RESULTS ALERT VIEW
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        visible: searchResultsModel.count === 0 && searchInput.text.trim() !== ""

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "󰅚"
                                color: root.themeTextMuted
                                font.pixelSize: 16
                            }

                            Text {
                                text: "No results found for \"" + searchInput.text + "\""
                                color: root.themeTextMuted
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // 2. RESULTS LISTVIEW
                    ListView {
                        id: resultsList
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(searchResultsModel.count * 50, 400)
                        visible: searchResultsModel.count > 0
                        model: searchResultsModel
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        onCountChanged: {
                            if (count > 0) currentIndex = 0
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: resultsList.moving || resultsList.flicking
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            id: itemCard
                            width: resultsList.width
                            height: 46
                            
                            radius: Math.max(4, root.themeRounding - 4)
                            property bool isSelected: ListView.isCurrentItem

                            color: isSelected ? Qt.alpha(root.themePrimary, 0.16) : "transparent"
                            
                            Behavior on color {
                                enabled: root.animEnabled
                                ColorAnimation { 
                                    duration: 120 
                                    easing.type: Easing.OutQuad 
                                }
                            }

                            Rectangle {
                                width: 3
                                height: itemCard.isSelected ? 20 : 0
                                radius: 1.5
                                color: root.themePrimary
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: itemCard.isSelected ? 1 : 0
                                
                                Behavior on height {
                                    enabled: root.animEnabled
                                    NumberAnimation { 
                                        duration: 180 
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on opacity {
                                    enabled: root.animEnabled
                                    NumberAnimation { duration: 120 }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 14
                                spacing: 12

                                ToolButton {
                                    icon.name: model.iconName
                                    icon.width: 24
                                    icon.height: 24
                                    icon.color: "transparent"
                                    background: Item {}
                                    hoverEnabled: false
                                    down: false
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: model.displayName
                                    color: itemCard.isSelected ? root.themeText : Qt.alpha(root.themeText, 0.85)
                                    font.pixelSize: 14
                                    font.weight: itemCard.isSelected ? Font.Bold : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: typeText.implicitWidth + 10
                                    radius: 4
                                    color: model.itemType === "app" ? Qt.alpha(root.themePrimary, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: typeText
                                        anchors.centerIn: parent
                                        text: model.itemType === "app" ? "APP" : "FILE"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: model.itemType === "app" ? root.themePrimary : root.themeTextMuted
                                    }
                                }

                                RowLayout {
                                    spacing: 4
                                    opacity: itemCard.isSelected ? 1 : 0
                                    Layout.alignment: Qt.AlignVCenter

                                    Behavior on opacity {
                                        enabled: root.animEnabled
                                        NumberAnimation { duration: 120 }
                                    }

                                    Text {
                                        text: "↵"
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: resultsList.currentIndex = index
                                onClicked: {
                                    resultsList.currentIndex = index
                                    executeResult(model.itemType, model.filePath, model.fileName)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}