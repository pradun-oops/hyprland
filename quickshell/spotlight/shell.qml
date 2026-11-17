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

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property bool animEnabled: true
    property int animDuration: 220
    property bool isClosing: false
    property bool surfaceHidden: false

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

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        if (!root.animEnabled) {
            root.surfaceHidden = true
            Qt.quit()
            return
        }
        hideSurfaceTimer.start()
        quitTimer.start()
    }

    Timer {
        id: hideSurfaceTimer
        interval: animStyle.exitDuration
        repeat: false
        onTriggered: root.surfaceHidden = true
    }

    Timer {
        id: quitTimer
        interval: animStyle.exitDuration + 50
        repeat: false
        onTriggered: Qt.quit()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.quitApp()
    }

    property string lockedMonitor: ""

    function updateTargetMonitor() {
        if (root.lockedMonitor !== "") return

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.lockedMonitor = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (root.lockedMonitor === "" && Quickshell.screens.length > 0) {
                root.lockedMonitor = Quickshell.screens[0].name
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.updateTargetMonitor()
        }
    }

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.36

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.68)
    property color themeSurfaceHover: Qt.rgba(0.08, 0.08, 0.12, 0.78)
    property color themeBorder: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"
    property color themePrimary: "#ffb3af"

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property string searchMode: "apps"

    function switchMode(newMode) {
        if (root.searchMode === newMode) return
        root.searchMode = newMode
        debounceSearchTimer.stop()
        performSearch(root.activeSearchQuery)
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
                if (rMatch && rMatch[1]) root.themeRounding = Math.max(16, parseInt(rMatch[1]))

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

    property var allApps: []
    property bool isLoaded: false

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
                    root.isLoaded = true
                    if (root.searchMode === "apps") {
                        performSearch(root.activeSearchQuery)
                    }
                }
            } catch (e) {}
        }
    }

    Process {
        id: cacheBuilder
        command: ["python3", "-c", `
import os, glob, json

def find_icon(icon_name):
    if icon_name.startswith('/'): return icon_name
    exts = ['.svg', '.png', '.xpm']
    dirs = [
        os.path.expanduser('~/.local/share/icons/WhiteSur/apps/scalable'),
        os.path.expanduser('~/.local/share/icons/WhiteSur/apps/48'),
        os.path.expanduser('~/.local/share/icons/WhiteSur/devices/scalable'),
        '/usr/share/icons/Papirus/scalable/apps',
        '/usr/share/icons/Papirus/48x48/apps',
        '/usr/share/icons/hicolor/scalable/apps',
        '/usr/share/icons/hicolor/48x48/apps',
        '/usr/share/icons/hicolor/128x128/apps',
        '/usr/share/icons/hicolor/256x256/apps',
        '/usr/share/icons/hicolor/scalable/devices',
        '/usr/share/pixmaps'
    ]
    for d in dirs:
        for ext in exts:
            p = os.path.join(d, icon_name + ext)
            if os.path.exists(p): return p
    return icon_name

apps = []
seen = set()
app_dirs = [
    '/usr/share/applications',
    os.path.expanduser('~/.local/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    os.path.expanduser('~/.local/share/flatpak/exports/share/applications')
]

for d in app_dirs:
    if not os.path.exists(d): continue
    for f in glob.glob(d + '/*.desktop'):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                if 'NoDisplay=true' in content or 'Hidden=true' in content: continue
                name = next((l.split('=', 1)[1].strip() for l in content.split('\n') if l.startswith('Name=')), '')
                icon = next((l.split('=', 1)[1].strip() for l in content.split('\n') if l.startswith('Icon=')), 'application-x-executable')

                if not icon.startswith('/'):
                    if icon.lower().endswith(('.png', '.svg', '.xpm')):
                        icon = icon.rsplit('.', 1)[0]

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
                        'subtitle': '',
                        'iconName': final_icon
                    })
        except Exception:
            pass

apps.sort(key=lambda x: x['displayName'].lower())
os.makedirs(os.path.expanduser('~/.config/quickshell/json'), exist_ok=True)
with open(os.path.expanduser('~/.config/quickshell/json/app_cache.json'), 'w', encoding='utf-8') as out:
    json.dump(apps, out)
        `]
        onExited: {
            appCacheFile.reload()
        }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.lockedMonitor === "") {
            fallbackMonitorTimer.start()
        }
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()

        let cached = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/app_cache.json", [])
        if (cached && cached.length > 0) {
            root.allApps = cached
            root.isLoaded = true
            appCacheFile.reload()
        } else {
            cacheBuilder.running = true
        }
    }

    ListModel {
        id: searchResultsModel
    }

    Process { id: launchProcess }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function executeResult(itemType, filePath, fileName) {
        if (!filePath || root.isClosing) return
        let cmd = ""
        if (itemType === "app" || filePath.endsWith(".desktop")) {
            let desktopBase = filePath.split("/").pop()
            cmd = "(gtk-launch " + escapeShell(desktopBase) + " 2>/dev/null || gio launch " + escapeShell(filePath) + " 2>/dev/null || xdg-open " + escapeShell(filePath) + ") >/dev/null 2>&1 & disown"
        } else {
            cmd = "(xdg-open " + escapeShell(filePath) + ") >/dev/null 2>&1 & disown"
        }
        launchProcess.running = false
        launchProcess.command = ["bash", "-c", cmd]
        launchProcess.running = true
        root.quitApp()
    }

    property string activeSearchQuery: ""

    Process {
        id: fileSearchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.searchMode !== "files") return
                if (debounceSearchTimer.pendingQuery.trim().toLowerCase() !== root.activeSearchQuery) return

                let lines = text.split("\n")
                let activeQ = root.activeSearchQuery.toLowerCase()
                let homeDir = Quickshell.env("HOME")

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line !== "") {
                        let parts = line.split("|")
                        if (parts.length >= 4) {
                            let fullPath = parts[1].trim()
                            let fname = parts[2].trim()
                            let fnameLower = fname.toLowerCase()
                            let cleanFname = fnameLower.replace(/^\./, "")

                            if (fnameLower.includes(activeQ) || cleanFname.includes(activeQ)) {
                                let parentDir = fullPath.substring(0, fullPath.lastIndexOf("/"))
                                if (homeDir && parentDir.startsWith(homeDir)) {
                                    parentDir = "~" + parentDir.substring(homeDir.length)
                                }
                                if (parentDir === "") parentDir = "~"

                                searchResultsModel.append({
                                    "itemType": "file",
                                    "filePath": fullPath,
                                    "displayName": fname,
                                    "fileName": fname,
                                    "subtitle": parentDir,
                                    "iconName": parts[3].trim()
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: debounceSearchTimer
        interval: 75
        repeat: false
        property string pendingQuery: ""
        onTriggered: {
            performSearch(pendingQuery)
        }
    }

    function performSearch(query) {
        let q = query ? query.trim().toLowerCase() : ""
        root.activeSearchQuery = q
        searchResultsModel.clear()

        if (fileSearchProcess.running) {
            fileSearchProcess.running = false
        }

        if (q === "") {
            return
        }

        if (root.searchMode === "apps") {
            let maxApps = 14
            let prefixMatches = []
            let partialMatches = []

            for (let i = 0; i < root.allApps.length; i++) {
                let app = root.allApps[i]
                let dName = (app.displayName || "").trim().toLowerCase()
                let fName = (app.fileName || "").trim().toLowerCase()
                if (fName.endsWith(".desktop")) fName = fName.slice(0, -8)
                let baseFile = fName.split(".").pop()

                if (dName.startsWith(q) || fName.startsWith(q) || baseFile.startsWith(q)) {
                    prefixMatches.push(app)
                } else if (dName.includes(q) || fName.includes(q) || baseFile.includes(q)) {
                    partialMatches.push(app)
                }
            }

            let combined = prefixMatches.concat(partialMatches)
            let limit = Math.min(combined.length, maxApps)
            for (let j = 0; j < limit; j++) {
                searchResultsModel.append({
                    "itemType": "app",
                    "filePath": combined[j].filePath || "",
                    "displayName": combined[j].displayName || "",
                    "fileName": combined[j].fileName || "",
                    "subtitle": "",
                    "iconName": combined[j].iconName || "application-x-executable"
                })
            }
        } else {
            let pruneFlag = q.startsWith(".") ? "" : "-not -path '*/.*'"
            let bashCmd = `
                q='` + q.replace(/'/g, "'\\''") + `'
                find "$HOME" -maxdepth 5 ` + pruneFlag + ` -type f -iname "*$q*" 2>/dev/null | head -n 25 | while read -r f; do
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
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: spotlightWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: root.lockedMonitor !== "" && modelData.name === root.lockedMonitor
            visible: isTargetMonitor && !root.surfaceHidden

            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-spotlight"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            Shortcut {
                sequence: "Escape"
                onActivated: root.quitApp()
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            mask: Region { item: searchContainer }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Rectangle {
                id: searchContainer
                width: Math.min(760, parent.width - 40)

                property real targetHeight: mainLayout.implicitHeight + 24
                height: targetHeight

                anchors.top: parent.top
                anchors.topMargin: 190
                anchors.horizontalCenter: parent.horizontalCenter

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.48)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                antialiasing: true
                clip: true
                enabled: !root.isClosing

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.12) }
                        GradientStop { position: 0.25; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.0, 0.12) }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.themeBorderSize
                    radius: Math.max(0, parent.radius - root.themeBorderSize)
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                    antialiasing: true
                }

                property bool shown: false
                property bool panelVisible: shown && !root.isClosing

                Component.onCompleted: {
                    shown = true
                }

                opacity: panelVisible ? 1.0 : 0.0

                transform: [
                    Scale {
                        origin.x: searchContainer.width / 2
                        origin.y: 35
                        xScale: searchContainer.panelVisible ? 1.0 : 0.94
                        yScale: searchContainer.panelVisible ? 1.0 : 0.94

                        Behavior on xScale {
                            NumberAnimation {
                                duration: root.animEnabled ? (searchContainer.panelVisible ? animStyle.enterDuration : animStyle.exitDuration) : 0
                                easing.type: searchContainer.panelVisible ? animStyle.expoEasing : animStyle.exitEasing
                            }
                        }
                        Behavior on yScale {
                            NumberAnimation {
                                duration: root.animEnabled ? (searchContainer.panelVisible ? animStyle.enterDuration : animStyle.exitDuration) : 0
                                easing.type: searchContainer.panelVisible ? animStyle.expoEasing : animStyle.exitEasing
                            }
                        }
                    },
                    Translate {
                        y: searchContainer.panelVisible ? 0 : -14
                        Behavior on y {
                            NumberAnimation {
                                duration: root.animEnabled ? (searchContainer.panelVisible ? animStyle.enterDuration : animStyle.exitDuration) : 0
                                easing.type: searchContainer.panelVisible ? animStyle.expoEasing : animStyle.exitEasing
                            }
                        }
                    }
                ]

                Behavior on height {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.morphDuration : 0
                        easing.type: animStyle.expoEasing
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? (searchContainer.panelVisible ? animStyle.fadeDuration : animStyle.exitDuration) : 0
                        easing.type: searchContainer.panelVisible ? animStyle.smoothEasing : animStyle.exitEasing
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: animStyle.fadeDuration
                        easing.type: animStyle.smoothEasing
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: animStyle.fadeDuration
                        easing.type: animStyle.smoothEasing
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
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        spacing: 10

                        Rectangle {
                            width: 34
                            height: 34
                            radius: root.searchMode === "apps" ? 10 : 12
                            color: Qt.alpha(root.themePrimary, 0.22)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.42)
                            Layout.alignment: Qt.AlignVCenter
                            antialiasing: true

                            Behavior on radius {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.microDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.searchMode === "apps" ? "󰍉" : "󰉋"
                                font.family: root.iconFontFamily
                                font.pixelSize: 16
                                color: root.themePrimary

                                Behavior on color {
                                    ColorAnimation {
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            font.family: root.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: root.themeText
                            selectionColor: Qt.alpha(root.themePrimary, 0.35)
                            selectedTextColor: root.themeText

                            placeholderText: root.searchMode === "apps" ? "Search applications..." : "Search files..."
                            placeholderTextColor: Qt.rgba(1.0, 1.0, 1.0, 0.52)
                            verticalAlignment: TextInput.AlignVCenter

                            background: Item {}

                            Component.onCompleted: {
                                searchInput.forceActiveFocus()
                            }

                            Keys.onTabPressed: (event) => {
                                root.switchMode(root.searchMode === "apps" ? "files" : "apps")
                                event.accepted = true
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
                                root.quitApp()
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
                            property bool hasText: searchInput.text !== ""
                            width: 28
                            height: 28
                            radius: 8
                            color: clearBtnMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface
                            border.width: 1
                            border.color: clearBtnMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1.0, 1.0, 1.0, 0.18)
                            antialiasing: true
                            visible: opacity > 0.01
                            opacity: hasText ? 1.0 : 0.0
                            scale: hasText ? (clearBtnMouse.pressed ? 0.92 : (clearBtnMouse.containsMouse ? 1.05 : 1.0)) : 0.75
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.microDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: animStyle.microDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: animStyle.microDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: root.iconFontFamily
                                color: clearBtnMouse.containsMouse ? root.themeText : root.themeTextMuted
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: clearBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = ""
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }

                        Rectangle {
                            id: modeSwitcher
                            Layout.preferredWidth: 162
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignVCenter
                            radius: 10
                            color: Qt.rgba(0.02, 0.02, 0.03, 0.72)
                            border.width: 1
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                            antialiasing: true

                            Rectangle {
                                id: activeModePill
                                width: (parent.width - 6) / 2
                                height: parent.height - 6
                                y: 3
                                x: root.searchMode === "apps" ? 3 : (parent.width / 2)
                                radius: 8
                                color: root.mixColor(root.themeBackground, root.themePrimary, 0.28, 0.88)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.72)
                                antialiasing: true

                                Behavior on x {
                                    NumberAnimation {
                                        duration: root.animEnabled ? animStyle.morphDuration : 0
                                        easing.type: animStyle.expoEasing
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: "󰀻"
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 12
                                            color: root.searchMode === "apps" ? root.themePrimary : root.themeTextMuted

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Apps"
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: root.searchMode === "apps" ? root.themeText : root.themeTextMuted

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.switchMode("apps")
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: "󰉋"
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 12
                                            color: root.searchMode === "files" ? root.themePrimary : root.themeTextMuted

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Files"
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: root.searchMode === "files" ? root.themeText : root.themeTextMuted

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.switchMode("files")
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignVCenter
                            radius: 9
                            color: escBadgeMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface
                            border.width: 1
                            border.color: escBadgeMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1.0, 1.0, 1.0, 0.18)
                            antialiasing: true
                            scale: escBadgeMouse.pressed ? 0.92 : (escBadgeMouse.containsMouse ? 1.05 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: animStyle.microDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: animStyle.microDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "ESC"
                                font.family: root.fontFamily
                                color: escBadgeMouse.containsMouse ? root.themePrimary : root.themeTextMuted
                                font.pixelSize: 10
                                font.weight: Font.Bold

                                Behavior on color {
                                    ColorAnimation {
                                        duration: animStyle.microDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }

                            MouseArea {
                                id: escBadgeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.quitApp()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                        visible: searchResultsModel.count > 0 || searchInput.text.trim() !== ""
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        property bool showEmpty: searchResultsModel.count === 0 && searchInput.text.trim() !== ""
                        visible: showEmpty
                        opacity: showEmpty ? 1.0 : 0.0
                        scale: showEmpty ? 1.0 : 0.96

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.fadeDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.scaleDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: root.searchMode === "apps" ? "󰀻" : "󰉋"
                                font.family: root.iconFontFamily
                                color: root.themePrimary
                                opacity: 0.85
                                font.pixelSize: 16
                            }

                            Text {
                                text: (root.searchMode === "apps" ? "No applications matching \"" : "No files matching \"") + searchInput.text + "\""
                                font.family: root.fontFamily
                                color: root.themeTextMuted
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                            }
                        }
                    }

                    ListView {
                        id: resultsList
                        Layout.fillWidth: true
                        Layout.leftMargin: -4
                        Layout.rightMargin: -4
                        Layout.preferredHeight: Math.min(searchResultsModel.count * 48, 384)
                        visible: searchResultsModel.count > 0
                        model: searchResultsModel
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        opacity: searchResultsModel.count > 0 ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.fadeDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0.0
                                    to: 1.0
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.96
                                    to: 1.0
                                    duration: root.animEnabled ? animStyle.morphDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        }

                        remove: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0.0
                                duration: root.animEnabled ? animStyle.microDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        displaced: Transition {
                            NumberAnimation {
                                properties: "x,y"
                                duration: root.animEnabled ? animStyle.morphDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }

                        onCountChanged: {
                            if (count > 0) currentIndex = 0
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: vbar
                            visible: resultsList.visible && vbar.size < 1.0
                            active: resultsList.moving || resultsList.flicking || hovered
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: animStyle.microDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }
                        }

                        delegate: Item {
                            id: itemCardWrapper
                            width: resultsList.width - (vbar.visible ? 10 : 0)
                            height: 46

                            property bool isSelected: ListView.isCurrentItem

                            MouseArea {
                                id: itemCardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: resultsList.currentIndex = index
                                onClicked: {
                                    resultsList.currentIndex = index
                                    executeResult(model.itemType, model.filePath, model.fileName)
                                }
                            }

                            Rectangle {
                                id: itemCard
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                anchors.topMargin: 1
                                anchors.bottomMargin: 1

                                radius: Math.max(8, root.themeRounding - 10)
                                color: itemCardWrapper.isSelected
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.78)
                                       : (itemCardMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                border.width: 1
                                border.color: itemCardWrapper.isSelected
                                              ? Qt.alpha(root.themePrimary, 0.65)
                                              : (itemCardMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.48) : Qt.rgba(1.0, 1.0, 1.0, 0.16))
                                antialiasing: true
                                scale: itemCardMouse.pressed
                                       ? 0.985
                                       : ((itemCardWrapper.isSelected || itemCardMouse.containsMouse) ? 1.008 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    ToolButton {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        Layout.alignment: Qt.AlignVCenter

                                        icon.name: model.iconName.indexOf("/") === 0 ? "" : model.iconName
                                        icon.source: model.iconName.indexOf("/") === 0 ? "file://" + model.iconName : ""

                                        icon.width: 24
                                        icon.height: 24
                                        icon.color: "transparent"

                                        background: Item {}
                                        hoverEnabled: false
                                        down: false
                                        padding: 0
                                        scale: (itemCardWrapper.isSelected || itemCardMouse.containsMouse) ? 1.06 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    Text {
                                        text: model.displayName
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.weight: itemCardWrapper.isSelected ? Font.Bold : Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: model.subtitle === ""
                                        Layout.maximumWidth: model.subtitle !== "" ? 320 : 1000
                                        Layout.alignment: Qt.AlignVCenter
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                    }

                                    Text {
                                        visible: model.subtitle !== ""
                                        text: model.subtitle
                                        color: root.themeTextMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 20
                                        Layout.preferredWidth: typeText.implicitWidth + 12
                                        radius: 5
                                        color: model.itemType === "app" ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                        border.width: 1
                                        border.color: model.itemType === "app" ? Qt.alpha(root.themePrimary, 0.48) : Qt.rgba(1.0, 1.0, 1.0, 0.16)
                                        antialiasing: true
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            id: typeText
                                            anchors.centerIn: parent
                                            text: model.itemType === "app" ? "APP" : "FILE"
                                            font.family: root.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.6
                                            color: model.itemType === "app" ? root.themePrimary : root.themeTextMuted
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