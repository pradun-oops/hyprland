import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // ============================================================
    // STRICT FOCUSED MONITOR LOCK LOGIC
    // ============================================================
    property string targetMonitorName: ""

    function updateTargetMonitor() {
        if (root.targetMonitorName !== "") return

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.targetMonitorName = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.targetMonitorName === "" && Quickshell.screens.length > 0) {
                root.targetMonitorName = Quickshell.screens[0].name
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.updateTargetMonitor()
        }
    }

    // Adaptive Theme Properties (Solid Background & Real-time updates)
    property int themeRounding: 14
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.7
    
    property color themeBackground: "#141416" 
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"         
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#ffb3af"         

    // Full Complete Shortcuts List synchronized with binds.lua
    property var fullKeybindsList: [
        // Screenshots & Recording
        { category: "Screenshots & Recording", keys: "Print", desc: "Screenshot Active Window" },
        { category: "Screenshots & Recording", keys: "CTRL + Print", desc: "Screenshot Selected Area" },
        { category: "Screenshots & Recording", keys: "ALT + Print", desc: "Screenshot Fullscreen" },
        { category: "Screenshots & Recording", keys: "SUPER + SHIFT + R", desc: "Record Screen (Full)" },
        { category: "Screenshots & Recording", keys: "SUPER + CTRL + R", desc: "Record Screen (Area)" },

        // Widget Toggles & Launchers
        { category: "Widgets & Launchers", keys: "SUPER + Space", desc: "Spotlight Search" },
        { category: "Widgets & Launchers", keys: "SUPER + X", desc: "Power Menu" },
        { category: "Widgets & Launchers", keys: "SUPER + I", desc: "Connections" },
        { category: "Widgets & Launchers", keys: "SUPER + ALT + C", desc: "Toggle Control Center" },
        { category: "Widgets & Launchers", keys: "SUPER + SHIFT + C", desc: "Calendar Widget" },
        { category: "Widgets & Launchers", keys: "SUPER + N", desc: "Notification History" },
        { category: "Widgets & Launchers", keys: "SUPER + K", desc: "Keybinds Cheatsheet" },
        { category: "Widgets & Launchers", keys: "SUPER + Tab", desc: "Window Overview" },
        { category: "Widgets & Launchers", keys: "SUPER + L", desc: "Lockscreen" },
        { category: "Widgets & Launchers", keys: "SUPER + W", desc: "Wallpaper Picker" },
        { category: "Widgets & Launchers", keys: "SUPER + SHIFT + B", desc: "Bluetooth Settings" },
        { category: "Widgets & Launchers", keys: "SUPER + M", desc: "System Monitor" },
        { category: "Widgets & Launchers", keys: "SUPER + SHIFT + W", desc: "Weather Widget" },

        // Audio & Media Controls
        { category: "Audio & Media", keys: "XF86AudioRaiseVolume", desc: "Raise Volume" },
        { category: "Audio & Media", keys: "XF86AudioLowerVolume", desc: "Lower Volume" },
        { category: "Audio & Media", keys: "XF86AudioMute", desc: "Toggle Audio Mute" },
        { category: "Audio & Media", keys: "XF86AudioMicMute", desc: "Toggle Mic Mute" },
        { category: "Audio & Media", keys: "XF86AudioPlay", desc: "Play / Pause Media" },
        { category: "Audio & Media", keys: "XF86AudioNext", desc: "Next Track" },
        { category: "Audio & Media", keys: "XF86AudioPrev", desc: "Previous Track" },

        // Brightness Controls
        { category: "Brightness", keys: "XF86MonBrightnessUp", desc: "Laptop Brightness Up" },
        { category: "Brightness", keys: "XF86MonBrightnessDown", desc: "Laptop Brightness Down" },
        { category: "Brightness", keys: "ALT + XF86MonBrightnessUp", desc: "External Monitor Brightness Up" },
        { category: "Brightness", keys: "ALT + XF86MonBrightnessDown", desc: "External Monitor Brightness Down" },
        { category: "Brightness", keys: "SUPER + ALT + space", desc: "Toggle Backlight" },

        // Application Launchers
        { category: "Application Launchers", keys: "SUPER + Return", desc: "Terminal (Kitty)" },
        { category: "Application Launchers", keys: "SUPER + B", desc: "Zen Browser" },
        { category: "Application Launchers", keys: "SUPER + E", desc: "File Manager (Nautilus)" },
        { category: "Application Launchers", keys: "SUPER + C", desc: "VSCodium" },
        { category: "Application Launchers", keys: "SUPER + O", desc: "VirtualBox Manager" },
        { category: "Application Launchers", keys: "SUPER + A", desc: "EasyEffects" },
        { category: "Application Launchers", keys: "SUPER + T", desc: "Floating Terminal" },

        // System & Session Commands
        { category: "System & Session", keys: "SUPER + Q", desc: "Close Active Window" },
        { category: "System & Session", keys: "SUPER + SHIFT + E", desc: "Exit Hyprland Session" },
        { category: "System & Session", keys: "SUPER + SHIFT + P", desc: "Toggle DPMS (Screen Sleep)" },
        { category: "System & Session", keys: "SUPER + ALT + R", desc: "Reload Hyprland" },

        // Window Management & Layouts
        { category: "Window Management", keys: "SUPER + F", desc: "Toggle Maximized" },
        { category: "Window Management", keys: "SUPER + SHIFT + F", desc: "Toggle Fullscreen" },
        { category: "Window Management", keys: "SUPER + R", desc: "Toggle Split Direction" },
        { category: "Window Management", keys: "SUPER + SHIFT + T", desc: "Toggle Floating" },
        { category: "Window Management", keys: "SUPER + H", desc: "Focus Left" },
        { category: "Window Management", keys: "SUPER + L", desc: "Focus Right" },
        { category: "Window Management", keys: "SUPER + K", desc: "Focus Up" },
        { category: "Window Management", keys: "SUPER + J", desc: "Focus Down" },
        { category: "Window Management", keys: "ALT + TAB", desc: "Cycle Next Window" },
        { category: "Window Management", keys: "SUPER + SHIFT + H", desc: "Move Window Left" },
        { category: "Window Management", keys: "SUPER + SHIFT + L", desc: "Move Window Right" },
        { category: "Window Management", keys: "SUPER + SHIFT + K", desc: "Move Window Up" },
        { category: "Window Management", keys: "SUPER + SHIFT + J", desc: "Move Window Down" },
        { category: "Window Management", keys: "SUPER + -", desc: "Resize Horizontal (Shrink)" },
        { category: "Window Management", keys: "SUPER + =", desc: "Resize Horizontal (Expand)" },
        { category: "Window Management", keys: "SUPER + SHIFT + -", desc: "Resize Vertical (Shrink)" },
        { category: "Window Management", keys: "SUPER + SHIFT + =", desc: "Resize Vertical (Expand)" },
        { category: "Window Management", keys: "SUPER + Mouse:272", desc: "Move Window (Mouse)" },
        { category: "Window Management", keys: "SUPER + Mouse:273", desc: "Resize Window (Mouse)" },

        // Multi-Monitor Controls
        { category: "Multi-Monitor", keys: "SUPER + CTRL + H", desc: "Focus Left Monitor" },
        { category: "Multi-Monitor", keys: "SUPER + CTRL + L", desc: "Focus Right Monitor" },
        { category: "Multi-Monitor", keys: "SUPER + CTRL + SHIFT + H", desc: "Move Window to Left Monitor" },
        { category: "Multi-Monitor", keys: "SUPER + CTRL + SHIFT + L", desc: "Move Window to Right Monitor" },

        // Workspace Navigation
        { category: "Workspaces", keys: "SUPER + CTRL + J", desc: "Switch Next Workspace" },
        { category: "Workspaces", keys: "SUPER + CTRL + K", desc: "Switch Previous Workspace" },
        { category: "Workspaces", keys: "SUPER + Mouse_down", desc: "Cycle Workspace Next (Mouse)" },
        { category: "Workspaces", keys: "SUPER + Mouse_up", desc: "Cycle Workspace Prev (Mouse)" },
        { category: "Workspaces", keys: "SUPER + S", desc: "Toggle Special Workspace ('super')" },
        { category: "Workspaces", keys: "SUPER + SHIFT + S", desc: "Move Window to Special Workspace" },
        { category: "Workspaces", keys: "SUPER + 1", desc: "Switch to Workspace 1" },
        { category: "Workspaces", keys: "SUPER + 2", desc: "Switch to Workspace 2" },
        { category: "Workspaces", keys: "SUPER + 3", desc: "Switch to Workspace 3" },
        { category: "Workspaces", keys: "SUPER + 4", desc: "Switch to Workspace 4" },
        { category: "Workspaces", keys: "SUPER + 5", desc: "Switch to Workspace 5" },
        { category: "Workspaces", keys: "SUPER + 6", desc: "Switch to Workspace 6" },
        { category: "Workspaces", keys: "SUPER + 7", desc: "Switch to Workspace 7" },
        { category: "Workspaces", keys: "SUPER + 8", desc: "Switch to Workspace 8" },
        { category: "Workspaces", keys: "SUPER + 9", desc: "Switch to Workspace 9" },
        { category: "Workspaces", keys: "SUPER + 0", desc: "Switch to Workspace 10" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 1", desc: "Move Window to Workspace 1" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 2", desc: "Move Window to Workspace 2" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 3", desc: "Move Window to Workspace 3" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 4", desc: "Move Window to Workspace 4" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 5", desc: "Move Window to Workspace 5" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 6", desc: "Move Window to Workspace 6" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 7", desc: "Move Window to Workspace 7" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 8", desc: "Move Window to Workspace 8" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 9", desc: "Move Window to Workspace 9" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 0", desc: "Move Window to Workspace 10" },
        { category: "Workspaces", keys: "SUPER + SHIFT + G", desc: "Update GDM Script" },
        { category: "Workspaces", keys: "SUPER + ALT + 1", desc: "Apply Preset 1" },
        { category: "Workspaces", keys: "SUPER + ALT + 2", desc: "Apply Preset 2" },
        { category: "Workspaces", keys: "SUPER + ALT + 3", desc: "Apply Preset 3" },
        { category: "Workspaces", keys: "SUPER + ALT + 4", desc: "Apply Preset 4" },
        { category: "Workspaces", keys: "SUPER + ALT + 5", desc: "Apply Preset 5" },
        { category: "Workspaces", keys: "SUPER + ALT + 6", desc: "Apply Preset 6" },
        { category: "Workspaces", keys: "SUPER + ALT + 7", desc: "Apply Preset 7" },
        { category: "Workspaces", keys: "SUPER + ALT + 8", desc: "Apply Preset 8" },
        { category: "Workspaces", keys: "SUPER + ALT + 9", desc: "Apply Preset 9" }
    ]

    property var activeKeybinds: []

    // Dynamic Theme File Parsing with Real-time Reloading
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
        id: bindsFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/binds.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let parsed = []

                let regexTable = /\{\s*(?:keys|key|bind)\s*=\s*["']([^"']+)["']\s*,\s*(?:desc|description)\s*=\s*["']([^"']+)["'](?:\s*,\s*(?:category|cat)\s*=\s*["']([^"']+)["'])?\s*\}/gi
                let match

                while ((match = regexTable.exec(content)) !== null) {
                    parsed.push({
                        keys: match[1],
                        desc: match[2],
                        category: match[3] ? match[3] : "General"
                    })
                }

                if (parsed.length === 0) {
                    let regexFunc = /bind\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["'](?:\s*,\s*["']([^"']+)["'])?\s*\)/gi
                    while ((match = regexFunc.exec(content)) !== null) {
                        parsed.push({
                            keys: match[1],
                            desc: match[2],
                            category: match[3] ? match[3] : "General"
                        })
                    }
                }

                if (parsed.length > 0) {
                    root.activeKeybinds = parsed
                } else {
                    root.activeKeybinds = root.fullKeybindsList
                }
            } catch (e) {
                root.activeKeybinds = root.fullKeybindsList
            }
            root.filterKeybinds(searchInput ? searchInput.text : "")
        }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        colorFile.reload()
        generalConfigFile.reload()
        bindsFile.reload()
    }

    ListModel { id: filteredModel }

    function filterKeybinds(query) {
        filteredModel.clear()
        let q = query.trim().toLowerCase()
        let sourceList = (root.activeKeybinds && root.activeKeybinds.length > 0) ? root.activeKeybinds : root.fullKeybindsList

        for (let i = 0; i < sourceList.length; i++) {
            let item = sourceList[i]
            let itemDesc = String(item.desc || "")
            let itemKeys = String(item.keys || "")
            let itemCat = String(item.category || "General")

            if (q === "" || itemDesc.toLowerCase().indexOf(q) !== -1 || itemKeys.toLowerCase().indexOf(q) !== -1 || itemCat.toLowerCase().indexOf(q) !== -1) {
                filteredModel.append({
                    itemDesc: itemDesc,
                    itemKeys: itemKeys,
                    itemCategory: itemCat
                })
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: keybindsWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-keybinds"
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
                id: mainCard
                width: Math.min(820, parent.width - 40)
                height: Math.min(620, parent.height - 80)
                anchors.centerIn: parent

                visible: root.targetMonitorName !== "" && isTargetMonitor
                focus: isTargetMonitor

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.40)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "⌨"
                            font.pixelSize: 22
                            color: root.themePrimary
                        }

                        Text {
                            text: "Keybinds Cheatsheet"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: root.themeText
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 260
                            Layout.preferredHeight: 36
                            radius: Math.max(4, root.themeRounding - 4)
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: searchInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.1)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: ""
                                    font.pixelSize: 13
                                    color: root.themeTextMuted
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    font.pixelSize: 13
                                    color: root.themeText
                                    placeholderText: "Search shortcuts..."
                                    placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.5)
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}

                                    Component.onCompleted: {
                                        if (keybindsWindow.isTargetMonitor) {
                                            forceActiveFocus()
                                        }
                                        root.activeKeybinds = root.fullKeybindsList
                                        root.filterKeybinds("")
                                    }

                                    onTextChanged: root.filterKeybinds(text)

                                    Keys.onDownPressed: keybindsList.incrementCurrentIndex()
                                    Keys.onUpPressed: keybindsList.decrementCurrentIndex()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(root.themeBorder, 0.20)
                    }

                    // Keybind List
                    ListView {
                        id: keybindsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: filteredModel
                        clip: true
                        spacing: 6
                        highlightFollowsCurrentItem: true

                        ScrollBar.vertical: ScrollBar {
                            active: keybindsList.moving || keybindsList.flicking
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            id: delegateItem
                            width: keybindsList.width
                            height: 42
                            radius: Math.max(4, root.themeRounding - 6)
                            color: ListView.isCurrentItem ? Qt.alpha(root.themePrimary, 0.15) : Qt.rgba(1, 1, 1, 0.04)

                            // Explicit role binding to prevent scoping loss
                            property string rawKeys: model.itemKeys || ""

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    text: model.itemDesc
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Key Badges Combo (Placed before Category tag)
                                Row {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignVCenter

                                    Repeater {
                                        model: delegateItem.rawKeys ? delegateItem.rawKeys.split("+") : []
                                        delegate: Rectangle {
                                            height: 24
                                            width: keyText.implicitWidth + 12
                                            radius: 5
                                            color: Qt.rgba(0, 0, 0, 0.55)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.4)

                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: modelData.trim()
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: root.themeText
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: catText.implicitWidth + 10
                                    radius: 4
                                    color: Qt.alpha(root.themePrimary, 0.12)

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: model.itemCategory
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.themePrimary
                                    }
                                }
                            }
                        }
                    }

                    // Footer Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        color: Qt.rgba(0, 0, 0, 0.18)
                        radius: Math.max(4, root.themeRounding - 6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                text: filteredModel.count + " shortcuts loaded"
                                font.pixelSize: 11
                                color: root.themeTextMuted
                            }

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 28; height: 18; radius: 4
                                    color: Qt.alpha(root.themeText, 0.1)
                                    Text { anchors.centerIn: parent; text: "ESC"; font.pixelSize: 9; color: root.themeTextMuted; font.weight: Font.Bold }
                                }
                                Text { text: "Close"; font.pixelSize: 11; color: root.themeTextMuted }
                            }
                        }
                    }
                }
            }
        }
    }
}