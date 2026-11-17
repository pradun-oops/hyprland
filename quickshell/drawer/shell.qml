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
        function onFocusedMonitorChanged() { root.updateTargetMonitor() }
    }

    property int themeRounding: 22
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25
    property bool animEnabled: true
    property int animDuration: 240

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.56)
    property color themeSurfaceHover: Qt.rgba(0.10, 0.10, 0.14, 0.74)
    property color themeBorder: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themePrimary: "#ffb3af"
    property color themeOnPrimary: "#141416"

    QtObject {
        id: style
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 260) : 220
        property int fadeDuration: 190
        property var smoothEasing: Easing.OutCubic
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property string searchQuery: ""
    property int selectedIndex: 0

    property var pinnedApps: []
    property var allApps: []

    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/pinned_apps.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text().trim()
                if (content !== "") {
                    let d = JSON.parse(content)
                    if (Array.isArray(d)) root.pinnedApps = d
                }
            } catch (e) {}
            root.updatePinnedModel()
        }
    }

    Process { id: savePinnedProcess }
    function savePinnedApps() {
        let path = Quickshell.env("HOME") + "/.config/quickshell/json/pinned_apps.json"
        let jsonStr = JSON.stringify(root.pinnedApps)
        savePinnedProcess.running = false
        savePinnedProcess.command = [
            "python3", "-c",
            "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])",
            path,
            jsonStr
        ]
        savePinnedProcess.running = true
    }

    function isPinned(filePath) {
        return root.pinnedApps.indexOf(filePath) !== -1
    }

    function togglePin(filePath) {
        let list = root.pinnedApps.slice()
        let idx = list.indexOf(filePath)
        if (idx !== -1) {
            list.splice(idx, 1)
        } else {
            list.push(filePath)
        }
        root.pinnedApps = list
        root.savePinnedApps()
        root.updatePinnedModel()
    }

    function updatePinnedModel() {
        pinnedModel.clear()
        for (let p = 0; p < root.pinnedApps.length; p++) {
            let targetPath = root.pinnedApps[p]
            for (let i = 0; i < root.allApps.length; i++) {
                let app = root.allApps[i]
                if (app.filePath === targetPath || app.fileName === targetPath) {
                    pinnedModel.append(app)
                    break
                }
            }
        }
    }

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
        root.selectedIndex = drawerModel.count > 0 ? 0 : -1
        root.updatePinnedModel()
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
    if not icon_name: return "application-x-executable"
    if icon_name.startswith("/"): return icon_name
    exts = [".svg", ".png", ".xpm"]
    dirs = [
        os.path.expanduser("~/.local/share/icons/WhiteSur/apps/scalable"),
        os.path.expanduser("~/.local/share/icons/WhiteSur/apps/48"),
        os.path.expanduser("~/.local/share/icons/WhiteSur/devices/scalable"),
        "/usr/share/icons/hicolor/scalable/apps",
        "/usr/share/icons/hicolor/128x128/apps",
        "/usr/share/icons/hicolor/48x48/apps",
        "/usr/share/pixmaps"
    ]
    for d in dirs:
        for ext in exts:
            p = os.path.join(d, icon_name + ext)
            if os.path.exists(p): return p
    return icon_name

apps = []
seen = set()
app_dirs = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
]

for d in app_dirs:
    if not os.path.exists(d): continue
    for f in glob.glob(d + "/*.desktop"):
        try:
            with open(f, "r", encoding="utf-8", errors="ignore") as file:
                content = file.read()
                if "NoDisplay=true" in content or "Hidden=true" in content: continue
                name = next((l.split("=",1)[1].strip() for l in content.split("\\n") if l.startswith("Name=")), "")
                icon = next((l.split("=",1)[1].strip() for l in content.split("\\n") if l.startswith("Icon=")), "application-x-executable")
                exec_l = next((l.split("=",1)[1].strip() for l in content.split("\\n") if l.startswith("Exec=")), "")
                cmd_clean = re.sub("%[fFuUikKc]", "", exec_l).strip()
                wm_class = next((l.split("=",1)[1].strip() for l in content.split("\\n") if l.startswith("StartupWMClass=")), "")
                if not wm_class:
                    wm_class = os.path.splitext(os.path.basename(f))[0]

                if not icon.startswith("/"):
                    if icon.lower().endswith((".png", ".svg", ".xpm")):
                        icon = icon.rsplit(".", 1)[0]

                if "blueman" in icon.lower(): icon = "blueman"
                elif "bluetooth" in icon.lower(): icon = "bluetooth"

                final_icon = find_icon(icon)

                if name and name.lower() not in seen:
                    seen.add(name.lower())
                    apps.append({
                        "itemType": "app",
                        "filePath": f,
                        "displayName": name,
                        "fileName": os.path.basename(f),
                        "iconName": final_icon,
                        "cmd": cmd_clean if cmd_clean else name.lower(),
                        "wmClass": wm_class,
                        "process": wm_class
                    })
        except Exception:
            pass

apps.sort(key=lambda x: x["displayName"].lower())
os.makedirs(os.path.expanduser("~/.config/quickshell/json"), exist_ok=True)
with open(os.path.expanduser("~/.config/quickshell/json/app_cache.json"), "w", encoding="utf-8") as out:
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
        pinnedFile.reload()

        let cachedPinned = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/pinned_apps.json", [])
        if (Array.isArray(cachedPinned)) {
            root.pinnedApps = cachedPinned
        }

        let cachedApps = readJsonSync(Quickshell.env("HOME") + "/.config/quickshell/json/app_cache.json", [])
        if (cachedApps && cachedApps.length > 0) {
            root.allApps = cachedApps
            root.filterApps()
            appCacheFile.reload()
        }
        cacheBuilder.running = true
    }

    ListModel { id: drawerModel }
    ListModel { id: pinnedModel }

    Timer { id: closeTimer; interval: 80; onTriggered: Qt.quit() }
    Process { id: launchProcess }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function executeItem(filePath) {
        if (!filePath) return
        let desktopBase = filePath.split("/").pop()
        let cmd = "(gtk-launch " + escapeShell(desktopBase) + " 2>/dev/null || gio launch " + escapeShell(filePath) + " 2>/dev/null || xdg-open " + escapeShell(filePath) + ") >/dev/null 2>&1 & disown"
        launchProcess.running = false
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

            property bool isTargetMonitor: root.lockedMonitor !== "" && modelData.name === root.lockedMonitor
            visible: isTargetMonitor

            onVisibleChanged: {
                if (visible && isTargetMonitor) {
                    mainContainer.shown = true
                    searchInput.forceActiveFocus()
                }
            }

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                focus: window.isTargetMonitor

                Shortcut {
                    sequence: "Escape"
                    context: Qt.ApplicationShortcut
                    onActivated: Qt.quit()
                }

                Keys.onEscapePressed: (event) => {
                    event.accepted = true
                    Qt.quit()
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.quit()
                }

                Rectangle {
                    id: mainContainer
                    width: Math.min(980, parent.width - 80)
                    height: Math.min(740, parent.height - 80)
                    anchors.centerIn: parent

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.42)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    antialiasing: true
                    clip: true

                    property bool shown: false
                    Component.onCompleted: {
                        if (window.visible) {
                            shown = true
                            searchInput.forceActiveFocus()
                        }
                    }

                    scale: shown ? 1.0 : 0.93
                    opacity: shown ? 1.0 : 0.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.smoothEasing
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animEnabled ? style.fadeDuration : 0
                            easing.type: style.smoothEasing
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => {
                            mouse.accepted = true
                            searchInput.forceActiveFocus()
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16

                        Rectangle {
                            id: searchBarContainer
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Math.max(12, root.themeRounding - 6)
                            color: Qt.rgba(0.02, 0.02, 0.03, 0.58)
                            border.width: searchInput.activeFocus ? 1.5 : 1
                            border.color: searchInput.activeFocus ? Qt.alpha(root.themePrimary, 0.70) : Qt.rgba(1, 1, 1, 0.14)
                            antialiasing: true

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: style.fadeDuration
                                    easing.type: style.smoothEasing
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 9
                                    color: Qt.alpha(root.themePrimary, 0.16)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.35)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰍉"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 16
                                        color: root.themePrimary
                                    }
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    placeholderText: "Search applications..."
                                    placeholderTextColor: Qt.rgba(1.0, 1.0, 1.0, 0.38)
                                    color: root.themeText
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    selectionColor: Qt.alpha(root.themePrimary, 0.35)
                                    selectedTextColor: root.themeText
                                    background: Item {}
                                    focus: true

                                    onTextChanged: {
                                        root.searchQuery = text
                                        root.filterApps()
                                    }

                                    Keys.onEscapePressed: (event) => {
                                        event.accepted = true
                                        Qt.quit()
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            Qt.quit()
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (root.selectedIndex >= 0 && root.selectedIndex < drawerModel.count) {
                                                root.executeItem(drawerModel.get(root.selectedIndex).filePath)
                                            }
                                            event.accepted = true
                                        } else if (drawerModel.count > 0) {
                                            let cols = Math.max(1, Math.floor(appGrid.width / appGrid.cellWidth))
                                            if (event.key === Qt.Key_Right) {
                                                root.selectedIndex = Math.min(drawerModel.count - 1, root.selectedIndex + 1)
                                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Left) {
                                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Down) {
                                                root.selectedIndex = Math.min(drawerModel.count - 1, root.selectedIndex + cols)
                                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Up) {
                                                root.selectedIndex = Math.max(0, root.selectedIndex - cols)
                                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                                event.accepted = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    antialiasing: true
                                    visible: searchInput.text !== ""
                                    scale: clearMouse.pressed ? 0.92 : (clearMouse.containsMouse ? 1.06 : 1.0)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.smoothEasing
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: style.fadeDuration
                                            easing.type: style.smoothEasing
                                        }
                                    }

                                    Text {
                                        text: "󰅖"
                                        font.family: root.iconFontFamily
                                        color: root.themeTextMuted
                                        anchors.centerIn: parent
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: clearMouse
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
                                    visible: drawerModel.count > 0
                                    Layout.preferredWidth: countBadgeText.implicitWidth + 16
                                    Layout.preferredHeight: 28
                                    radius: 8
                                    color: Qt.alpha(root.themePrimary, 0.15)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.35)
                                    antialiasing: true

                                    Text {
                                        id: countBadgeText
                                        anchors.centerIn: parent
                                        text: drawerModel.count + " apps"
                                        color: root.themePrimary
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: drawerModel.count === 0 && (root.searchQuery !== "" || pinnedModel.count === 0)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 60
                                    height: 60
                                    radius: 18
                                    color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.28)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰀻"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 26
                                        color: root.themePrimary
                                        opacity: 0.75
                                    }
                                }

                                ColumnLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        text: "No Applications Found"
                                        font.family: root.fontFamily
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        color: root.themeText
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: "Try a different application name"
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        color: root.themeTextMuted
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id: appsViewContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: drawerModel.count > 0 || (root.searchQuery === "" && pinnedModel.count > 0)
                            spacing: 14

                            Rectangle {
                                id: pinnedSectionCard
                                Layout.fillWidth: true
                                visible: root.searchQuery === "" && pinnedModel.count > 0
                                implicitHeight: pinnedColumn.implicitHeight + 24
                                radius: Math.max(12, root.themeRounding - 6)
                                color: Qt.rgba(0.02, 0.02, 0.03, 0.50)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                antialiasing: true

                                ColumnLayout {
                                    id: pinnedColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 4
                                        Layout.rightMargin: 4
                                        spacing: 8

                                        Text {
                                            text: "󰐃"
                                            color: root.themePrimary
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: "PINNED"
                                            color: root.themePrimary
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            font.letterSpacing: 1.0
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
                                        }

                                        Rectangle {
                                            width: pinnedCountText.implicitWidth + 12
                                            height: 18
                                            radius: 6
                                            color: Qt.alpha(root.themePrimary, 0.18)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.4)
                                            antialiasing: true

                                            Text {
                                                id: pinnedCountText
                                                anchors.centerIn: parent
                                                text: pinnedModel.count.toString()
                                                color: root.themePrimary
                                                font.family: root.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "Right-click to unpin"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.65)
                                        }
                                    }

                                    Flickable {
                                        id: pinnedFlickable
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 118
                                        contentWidth: pinnedRow.implicitWidth
                                        leftMargin: 4
                                        rightMargin: 4
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        WheelHandler {
                                            target: pinnedFlickable
                                            orientation: Qt.Horizontal
                                            rotationScale: 50
                                        }

                                        Row {
                                            id: pinnedRow
                                            spacing: 6

                                            Repeater {
                                                model: pinnedModel

                                                delegate: Item {
                                                    width: 108
                                                    height: 116

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 100
                                                        height: 108
                                                        radius: 14
                                                        color: pMouseArea.containsMouse
                                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.65)
                                                               : "transparent"
                                                        border.width: 1
                                                        border.color: pMouseArea.containsMouse ? Qt.alpha(root.themePrimary, 0.60) : "transparent"
                                                        antialiasing: true
                                                        scale: pMouseArea.pressed ? 0.94 : (pMouseArea.containsMouse ? 1.04 : 1.0)

                                                        Behavior on scale {
                                                            NumberAnimation {
                                                                duration: root.animEnabled ? style.animDuration : 0
                                                                easing.type: style.smoothEasing
                                                            }
                                                        }

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: style.fadeDuration
                                                                easing.type: style.smoothEasing
                                                            }
                                                        }
                                                        Behavior on border.color {
                                                            ColorAnimation {
                                                                duration: style.fadeDuration
                                                                easing.type: style.smoothEasing
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 8
                                                            spacing: 6

                                                            Item {
                                                                Layout.alignment: Qt.AlignHCenter
                                                                Layout.preferredWidth: 46
                                                                Layout.preferredHeight: 46

                                                                ToolButton {
                                                                    anchors.centerIn: parent
                                                                    visible: !model.iconName.startsWith("/")
                                                                    icon.name: !model.iconName.startsWith("/") ? model.iconName : ""
                                                                    icon.width: 44
                                                                    icon.height: 44
                                                                    icon.color: "transparent"
                                                                    background: Item {}
                                                                    hoverEnabled: false
                                                                    down: false
                                                                    padding: 0
                                                                }

                                                                Image {
                                                                    anchors.centerIn: parent
                                                                    visible: model.iconName.startsWith("/")
                                                                    source: model.iconName.startsWith("/") ? "file://" + model.iconName : ""
                                                                    sourceSize: Qt.size(88, 88)
                                                                    width: 44
                                                                    height: 44
                                                                    fillMode: Image.PreserveAspectFit
                                                                    smooth: true
                                                                    antialiasing: true
                                                                }
                                                            }

                                                            Text {
                                                                text: model.displayName
                                                                color: root.themeText
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 11
                                                                font.weight: Font.Bold
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                                wrapMode: Text.Wrap
                                                                elide: Text.ElideRight
                                                                maximumLineCount: 2
                                                                lineHeight: 1.1
                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true
                                                                style: Text.Raised
                                                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: pMouseArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: (mouse) => {
                                                                if (mouse.button === Qt.LeftButton) {
                                                                    root.executeItem(model.filePath)
                                                                } else if (mouse.button === Qt.RightButton) {
                                                                    root.togglePin(model.filePath)
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

                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.searchQuery === "" && pinnedModel.count > 0
                                spacing: 8

                                Text {
                                    text: "ALL APPLICATIONS"
                                    color: root.themeTextMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.10)
                                }
                            }

                            GridView {
                                id: appGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                model: drawerModel
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                cellWidth: 116
                                cellHeight: 124

                                leftMargin: Math.max(0, (width - (Math.floor(width / cellWidth) * cellWidth)) / 2)

                                add: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            from: 0
                                            to: 1
                                            duration: root.animEnabled ? style.fadeDuration : 0
                                            easing.type: style.smoothEasing
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            from: 0.92
                                            to: 1.0
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.smoothEasing
                                        }
                                    }
                                }

                                remove: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            to: 0
                                            duration: root.animEnabled ? style.fadeDuration : 0
                                            easing.type: style.smoothEasing
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            to: 0.92
                                            duration: root.animEnabled ? style.animDuration : 0
                                            easing.type: style.smoothEasing
                                        }
                                    }
                                }

                                displaced: Transition {
                                    NumberAnimation {
                                        properties: "x,y"
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.smoothEasing
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    id: appScroll
                                    visible: appGrid.visible && appScroll.size < 1.0
                                    active: appGrid.moving || appGrid.flicking || hovered
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: appScroll.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                    }
                                }

                                delegate: Item {
                                    id: gridDelegate
                                    width: appGrid.cellWidth
                                    height: appGrid.cellHeight

                                    property bool isHighlighted: appMouseArea.containsMouse || (index === root.selectedIndex)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 106
                                        height: 114
                                        radius: 14
                                        color: gridDelegate.isHighlighted
                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.65)
                                               : "transparent"
                                        border.width: 1
                                        border.color: gridDelegate.isHighlighted
                                                      ? Qt.alpha(root.themePrimary, 0.60)
                                                      : "transparent"
                                        antialiasing: true
                                        scale: appMouseArea.pressed ? 0.94 : (gridDelegate.isHighlighted ? 1.04 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.smoothEasing
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: style.fadeDuration
                                                easing.type: style.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: style.fadeDuration
                                                easing.type: style.smoothEasing
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.topMargin: 12
                                            anchors.bottomMargin: 8
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6
                                            spacing: 6

                                            Item {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth: 52
                                                Layout.preferredHeight: 52

                                                ToolButton {
                                                    anchors.centerIn: parent
                                                    visible: !model.iconName.startsWith("/")
                                                    icon.name: !model.iconName.startsWith("/") ? model.iconName : ""
                                                    icon.width: 48
                                                    icon.height: 48
                                                    icon.color: "transparent"
                                                    background: Item {}
                                                    hoverEnabled: false
                                                    down: false
                                                    padding: 0
                                                }

                                                Image {
                                                    anchors.centerIn: parent
                                                    visible: model.iconName.startsWith("/")
                                                    source: model.iconName.startsWith("/") ? "file://" + model.iconName : ""
                                                    sourceSize: Qt.size(96, 96)
                                                    width: 48
                                                    height: 48
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    antialiasing: true
                                                }
                                            }

                                            Text {
                                                text: model.displayName
                                                color: root.themeText
                                                font.family: root.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                wrapMode: Text.Wrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                lineHeight: 1.1
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            }
                                        }

                                        MouseArea {
                                            id: appMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: root.selectedIndex = index
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    root.executeItem(model.filePath)
                                                } else if (mouse.button === Qt.RightButton) {
                                                    root.togglePin(model.filePath)
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
}