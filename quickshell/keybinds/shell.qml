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

    // Detect cursor position and lock window to active monitor at startup
    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.lockedMonitor !== "") return

                try {
                    let parts = text.trim().split(",")
                    if (parts.length === 2) {
                        let cx = parseInt(parts[0].trim())
                        let cy = parseInt(parts[1].trim())

                        for (let i = 0; i < Quickshell.screens.length; i++) {
                            let s = Quickshell.screens[i]
                            if (cx >= s.x && cx < (s.x + s.width) && cy >= s.y && cy < (s.y + s.height)) {
                                root.lockedMonitor = s.name
                                return
                            }
                        }
                    }
                } catch (e) {}

                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                    root.lockedMonitor = Hyprland.focusedMonitor.name
                } else if (Quickshell.screens.length > 0) {
                    root.lockedMonitor = Quickshell.screens[0].name
                }
            }
        }
    }

    // Dynamic adaptive properties
    property int themeRounding: 14
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.65
    
    property color themeBackground: Qt.rgba(0.08, 0.08, 0.10, themeBgAlpha) 
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#ffb3af"        

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onLoaded: {
            try {
                let match = text.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) {
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
                }
            } catch (e) {}
        }
    }

    FileView {
        id: generalConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onLoaded: {
            try {
                let content = text
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
                
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])
            } catch (e) {}
        }
    }

    property var rawKeybinds: [
        { category: "Launchers & Widgets", keys: "SUPER + K", desc: "Keybinds Cheatsheet" },
        { category: "Launchers & Widgets", keys: "SUPER + Space", desc: "Spotlight Search" },
        { category: "Launchers & Widgets", keys: "SUPER + Return", desc: "Terminal (Kitty)" },
        { category: "Launchers & Widgets", keys: "SUPER + B", desc: "Zen Browser" },
        { category: "Launchers & Widgets", keys: "SUPER + E", desc: "File Manager" },
        { category: "Launchers & Widgets", keys: "SUPER + C", desc: "VSCodium" },
        { category: "Launchers & Widgets", keys: "SUPER + V", desc: "Clipboard History" },
        { category: "Launchers & Widgets", keys: "SUPER + X", desc: "Power Menu" },
        { category: "Launchers & Widgets", keys: "SUPER + N", desc: "Notification Center" },
        { category: "Launchers & Widgets", keys: "SUPER + I", desc: "Connections" },
        { category: "Launchers & Widgets", keys: "SUPER + ,", desc: "System Settings" },
        { category: "Launchers & Widgets", keys: "SUPER + TAB", desc: "Overview" },

        { category: "Window Management", keys: "SUPER + Q", desc: "Close Active Window" },
        { category: "Window Management", keys: "SUPER + F", desc: "Toggle Maximize" },
        { category: "Window Management", keys: "SUPER + SHIFT + F", desc: "Toggle Fullscreen" },
        { category: "Window Management", keys: "SUPER + SHIFT + T", desc: "Toggle Floating" },
        { category: "Window Management", keys: "SUPER + R", desc: "Toggle Split Direction" },
        { category: "Window Management", keys: "SUPER + H / J / L", desc: "Focus Left / Down / Right" },
        { category: "Window Management", keys: "SUPER + SHIFT + H / J / K / L", desc: "Move Window Directionally" },
        { category: "Window Management", keys: "SUPER + - / =", desc: "Resize Horizontal" },
        { category: "Window Management", keys: "SUPER + SHIFT + - / =", desc: "Resize Vertical" },

        { category: "Workspaces & Navigation", keys: "SUPER + 1..0", desc: "Switch Workspace 1 to 10" },
        { category: "Workspaces & Navigation", keys: "SUPER + SHIFT + 1..0", desc: "Move Window to Workspace" },
        { category: "Workspaces & Navigation", keys: "SUPER + S", desc: "Toggle Special Workspace" },
        { category: "Workspaces & Navigation", keys: "SUPER + CTRL + H / L", desc: "Focus Left / Right Monitor" },
        { category: "Workspaces & Navigation", keys: "SUPER + CTRL + SHIFT + H / L", desc: "Move Window to Monitor" },

        { category: "Media & Utilities", keys: "Print", desc: "Screenshot Active Window" },
        { category: "Media & Utilities", keys: "CTRL + Print", desc: "Screenshot Selected Area" },
        { category: "Media & Utilities", keys: "ALT + Print", desc: "Screenshot Fullscreen" },
        { category: "Media & Utilities", keys: "SUPER + SHIFT + R", desc: "Record Screen (Full)" },
        { category: "Media & Utilities", keys: "SUPER + SHIFT + C", desc: "Record Screen (Area)" },
        { category: "Media & Utilities", keys: "SUPER + ALT + L", desc: "Lock Screen" },
        { category: "Media & Utilities", keys: "SUPER + ALT + R", desc: "Reload Hyprland" }
    ]

    ListModel {
        id: filteredModel
    }

    function filterKeybinds(query) {
        filteredModel.clear()
        let q = query.trim().toLowerCase()
        for (let i = 0; i < rawKeybinds.length; i++) {
            let item = rawKeybinds[i]
            if (q === "" || item.desc.toLowerCase().includes(q) || item.keys.toLowerCase().includes(q) || item.category.toLowerCase().includes(q)) {
                filteredModel.append(item)
            }
        }
    }

    Component.onCompleted: {
        filterKeybinds("")
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: keybindsWindow
            required property var modelData
            screen: modelData

            visible: root.lockedMonitor !== "" && modelData.name === root.lockedMonitor

            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
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

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.quit()
                }
            }

            Rectangle {
                id: mainCard
                width: Math.min(820, parent.width - 40)
                height: Math.min(620, parent.height - 80)
                
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.40)
                color: root.themeBackground

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    z: 10
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true; }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "⌨"
                            font.pixelSize: 22
                            color: root.themePrimary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Keybinds Cheatsheet"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: root.themeText
                            Layout.alignment: Qt.AlignVCenter
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
                                    Layout.alignment: Qt.AlignVCenter
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

                                    Component.onCompleted: forceActiveFocus()

                                    onTextChanged: {
                                        filterKeybinds(text)
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            Qt.quit()
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(root.themeBorder, 0.20)
                    }

                    ListView {
                        id: keybindsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: filteredModel
                        clip: true
                        spacing: 6

                        ScrollBar.vertical: ScrollBar {
                            active: keybindsList.moving || keybindsList.flicking
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            width: keybindsList.width
                            height: 44
                            radius: Math.max(4, root.themeRounding - 6)
                            color: Qt.rgba(1, 1, 1, 0.04)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    text: model.desc
                                    color: root.themeText
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: catText.implicitWidth + 12
                                    radius: 4
                                    color: Qt.alpha(root.themePrimary, 0.15)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: model.category
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.themePrimary
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: keyCapText.implicitWidth + 16
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.35)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: keyCapText
                                        anchors.centerIn: parent
                                        text: model.keys
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.themeText
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        color: Qt.rgba(0, 0, 0, 0.18)
                        radius: Math.max(4, root.themeRounding - 6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                text: filteredModel.count + " shortcuts available"
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