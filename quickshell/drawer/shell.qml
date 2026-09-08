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
    // APP DATA STATE
    // ============================================================
    property var allApps: []
    property bool isLoaded: true 

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
                    loadApps() 
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
        }
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
            loadApps() 
        }

        appCacheFile.reload()
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

    function loadApps() {
        drawerModel.clear()
        for (let i = 0; i < root.allApps.length; i++) {
            drawerModel.append(root.allApps[i])
        }
    }

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
                    onActivated: Qt.quit() 
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.quit()
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

                    scale: 1.0
                    opacity: 1.0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => { mouse.accepted = true }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        spacing: 24

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

                            // Slightly increased dimensions to accommodate beautiful multiline wrap
                            cellWidth: 110
                            cellHeight: 160

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
                                    height: 150
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
                                            wrapMode: Text.WordWrap // Break on spaces naturally
                                            elide: Text.ElideRight
                                            maximumLineCount: 3 
                                            lineHeight: 1.15
                                            Layout.fillWidth: true
                                            // 100px (Rectangle width) - 16px (8px left + 8px right margins) = 84px maximum width
                                            Layout.maximumWidth: 84
                                            Layout.preferredHeight: 46 
                                        }
                                    }

                                    MouseArea {
                                        id: appMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        // Left click only to launch the app
                                        onClicked: {
                                            executeApp(model.filePath)
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