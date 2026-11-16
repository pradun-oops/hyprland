import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 240) : 200
        property int fadeDuration: 180
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

    property string targetMonitorName: ""

    function updateTargetMonitor() {
        if (root.targetMonitorName !== "") return

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.targetMonitorName = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 120
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

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 220

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.56)
    property color themeSurfaceHover: Qt.rgba(0.10, 0.10, 0.14, 0.74)
    property color themeBorder: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themePrimary: "#ffb3af"

    property var fullKeybindsList: [
        { category: "Application Launchers", keys: "SUPER + Return", desc: "Terminal (Kitty)" },
        { category: "Application Launchers", keys: "SUPER + T", desc: "Floating Terminal" },
        { category: "Application Launchers", keys: "SUPER + B", desc: "Web Browser" },
        { category: "Application Launchers", keys: "SUPER + E", desc: "File Manager (Nautilus)" },
        { category: "Application Launchers", keys: "SUPER + C", desc: "Code Editor (VSCodium)" },
        { category: "Application Launchers", keys: "SUPER + O", desc: "VirtualBox Manager" },
        { category: "Application Launchers", keys: "SUPER + A", desc: "EasyEffects" },
        { category: "Application Launchers", keys: "SUPER + SHIFT + B", desc: "Bluetooth Manager" },
        { category: "Application Launchers", keys: "SUPER + SHIFT + G", desc: "Update GDM Script" },

        { category: "Widgets & Overlays", keys: "SUPER + Space", desc: "Spotlight Search" },
        { category: "Widgets & Overlays", keys: "SUPER + Tab", desc: "Window Overview" },
        { category: "Widgets & Overlays", keys: "SUPER + X", desc: "Power Menu" },
        { category: "Widgets & Overlays", keys: "SUPER + I", desc: "Connections" },
        { category: "Widgets & Overlays", keys: "SUPER + P", desc: "Settings Widget" },
        { category: "Widgets & Overlays", keys: "SUPER + N", desc: "Notification History" },
        { category: "Widgets & Overlays", keys: "SUPER + V", desc: "Clipboard History" },
        { category: "Widgets & Overlays", keys: "SUPER + W", desc: "Wallpaper Picker" },
        { category: "Widgets & Overlays", keys: "SUPER + M", desc: "System Monitor" },
        { category: "Widgets & Overlays", keys: "SUPER + /", desc: "Keybinds Cheatsheet" },
        { category: "Widgets & Overlays", keys: "SUPER + ALT + E", desc: "File Manager Widget" },
        { category: "Widgets & Overlays", keys: "SUPER + ALT + C", desc: "Toggle Control Center" },
        { category: "Widgets & Overlays", keys: "SUPER + ALT + L", desc: "Lockscreen" },
        { category: "Widgets & Overlays", keys: "SUPER + SHIFT + C", desc: "Calendar Widget" },
        { category: "Widgets & Overlays", keys: "SUPER + SHIFT + W", desc: "Weather Widget" },
        { category: "Widgets & Overlays", keys: "SUPER + ALT + W", desc: "Wellbeing Widget" },
        { category: "Widgets & Overlays", keys: "SUPER + ALT + S", desc: "Circle to Search" },
        { category: "Widgets & Overlays", keys: "SUPER + SHIFT + CTRL + C", desc: "Calculator Widget" },

        { category: "System & Shell Controls", keys: "SUPER + ALT + Space", desc: "Toggle Backlight" },
        { category: "System & Shell Controls", keys: "SUPER + ALT + B", desc: "Toggle Topbar" },
        { category: "System & Shell Controls", keys: "SUPER + ALT + Q", desc: "Restart Quickshell" },
        { category: "System & Shell Controls", keys: "SUPER + ALT + K", desc: "Lenovo LOQ RGB Controller" },

        { category: "Screenshots & Recording", keys: "Print", desc: "Screenshot Active Window" },
        { category: "Screenshots & Recording", keys: "CTRL + Print", desc: "Screenshot Selected Area" },
        { category: "Screenshots & Recording", keys: "ALT + Print", desc: "Screenshot Fullscreen" },
        { category: "Screenshots & Recording", keys: "SUPER + CTRL + R", desc: "Record Screen (Area)" },
        { category: "Screenshots & Recording", keys: "SUPER + SHIFT + R", desc: "Record Screen (Full)" },

        { category: "Audio & Media", keys: "XF86AudioRaiseVolume", desc: "Raise Volume" },
        { category: "Audio & Media", keys: "XF86AudioLowerVolume", desc: "Lower Volume" },
        { category: "Audio & Media", keys: "XF86AudioMute", desc: "Toggle Audio Mute" },
        { category: "Audio & Media", keys: "XF86AudioMicMute", desc: "Toggle Mic Mute" },
        { category: "Audio & Media", keys: "XF86AudioPlay", desc: "Play / Pause Media" },
        { category: "Audio & Media", keys: "XF86AudioNext", desc: "Next Track" },
        { category: "Audio & Media", keys: "XF86AudioPrev", desc: "Previous Track" },

        { category: "Brightness", keys: "XF86MonBrightnessUp", desc: "Laptop Brightness Up" },
        { category: "Brightness", keys: "XF86MonBrightnessDown", desc: "Laptop Brightness Down" },
        { category: "Brightness", keys: "ALT + XF86MonBrightnessUp", desc: "Acer Monitor Brightness Up" },
        { category: "Brightness", keys: "ALT + XF86MonBrightnessDown", desc: "Acer Monitor Brightness Down" },

        { category: "Window Management", keys: "SUPER + Q", desc: "Close Focused Window" },
        { category: "Window Management", keys: "SUPER + SHIFT + E", desc: "Exit Hyprland Session" },
        { category: "Window Management", keys: "SUPER + SHIFT + P", desc: "Toggle DPMS (Screen Sleep)" },
        { category: "Window Management", keys: "SUPER + ALT + R", desc: "Reload Hyprland" },
        { category: "Window Management", keys: "SUPER + SHIFT + T", desc: "Toggle Floating Mode" },
        { category: "Window Management", keys: "SUPER + R", desc: "Toggle Split Direction" },
        { category: "Window Management", keys: "SUPER + F", desc: "Toggle Maximized" },
        { category: "Window Management", keys: "SUPER + SHIFT + F", desc: "Toggle Fullscreen" },
        { category: "Window Management", keys: "SUPER + Mouse Drag", desc: "Move Window" },
        { category: "Window Management", keys: "SUPER + Right Click Drag", desc: "Resize Window" },
        { category: "Window Management", keys: "SUPER + =", desc: "Resize Horizontal (Expand)" },
        { category: "Window Management", keys: "SUPER + -", desc: "Resize Horizontal (Shrink)" },
        { category: "Window Management", keys: "SUPER + SHIFT + =", desc: "Resize Vertical (Expand)" },
        { category: "Window Management", keys: "SUPER + SHIFT + -", desc: "Resize Vertical (Shrink)" },

        { category: "Navigation & Focus", keys: "SUPER + H", desc: "Focus Left" },
        { category: "Navigation & Focus", keys: "SUPER + J", desc: "Focus Down" },
        { category: "Navigation & Focus", keys: "SUPER + K", desc: "Focus Up" },
        { category: "Navigation & Focus", keys: "SUPER + L", desc: "Focus Right" },
        { category: "Navigation & Focus", keys: "ALT + TAB", desc: "Cycle Next Window" },
        { category: "Navigation & Focus", keys: "SUPER + SHIFT + H", desc: "Move Window Left" },
        { category: "Navigation & Focus", keys: "SUPER + SHIFT + J", desc: "Move Window Down" },
        { category: "Navigation & Focus", keys: "SUPER + SHIFT + K", desc: "Move Window Up" },
        { category: "Navigation & Focus", keys: "SUPER + SHIFT + L", desc: "Move Window Right" },
        { category: "Navigation & Focus", keys: "SUPER + CTRL + H", desc: "Focus Left Monitor" },
        { category: "Navigation & Focus", keys: "SUPER + CTRL + L", desc: "Focus Right Monitor" },
        { category: "Navigation & Focus", keys: "SUPER + CTRL + SHIFT + H", desc: "Move Window to Left Monitor" },
        { category: "Navigation & Focus", keys: "SUPER + CTRL + SHIFT + L", desc: "Move Window to Right Monitor" },

        { category: "Workspaces", keys: "SUPER + CTRL + J", desc: "Switch Next Workspace" },
        { category: "Workspaces", keys: "SUPER + CTRL + K", desc: "Switch Previous Workspace" },
        { category: "Workspaces", keys: "SUPER + Mouse Scroll Up", desc: "Cycle Workspace Next" },
        { category: "Workspaces", keys: "SUPER + Mouse Scroll Down", desc: "Cycle Workspace Prev" },
        { category: "Workspaces", keys: "SUPER + S", desc: "Toggle Special Workspace ('super')" },
        { category: "Workspaces", keys: "SUPER + SHIFT + S", desc: "Move Window to Special Workspace" },
        { category: "Workspaces", keys: "SUPER + 1..0", desc: "Switch to Workspace 1-10" },
        { category: "Workspaces", keys: "SUPER + SHIFT + 1..0", desc: "Move Window to Workspace 1-10" },
        { category: "Workspaces", keys: "SUPER + ALT + 1..9", desc: "Apply Workspace Preset 1-9" }
    ]

    property var activeKeybinds: fullKeybindsList

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
            root.filterKeybinds(root.currentSearch)
        }
    }

    property string currentSearch: ""

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        root.filterKeybinds("")
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        bindsFile.reload()
    }

    ListModel { id: filteredModel }

    function filterKeybinds(query) {
        root.currentSearch = query
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
                width: Math.min(860, parent.width - 48)
                height: Math.min(640, parent.height - 80)
                anchors.centerIn: parent

                property bool shown: false
                Component.onCompleted: shown = true

                opacity: shown ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.42)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                antialiasing: true
                clip: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 11
                            color: Qt.alpha(root.themePrimary, 0.16)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.35)
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                text: "󰌌"
                                font.family: root.iconFontFamily
                                font.pixelSize: 18
                                color: root.themePrimary
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Keybinds"
                                font.family: root.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: root.themeText
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                            }

                            Text {
                                text: "Hyprland & Quickshell shortcuts"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.themeTextMuted
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.65)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 280
                            Layout.preferredHeight: 38
                            radius: 10
                            color: Qt.rgba(0.02, 0.02, 0.03, 0.58)
                            border.width: searchInput.activeFocus ? 1.5 : 1
                            border.color: searchInput.activeFocus ? Qt.alpha(root.themePrimary, 0.70) : Qt.rgba(1, 1, 1, 0.14)
                            antialiasing: true

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: animStyle.fadeDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "󰍉"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 15
                                    color: searchInput.activeFocus ? root.themePrimary : root.themeTextMuted
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: root.themeText
                                    placeholderText: "Search shortcuts..."
                                    placeholderTextColor: Qt.rgba(1.0, 1.0, 1.0, 0.38)
                                    selectionColor: Qt.alpha(root.themePrimary, 0.35)
                                    selectedTextColor: root.themeText
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}

                                    Timer {
                                        id: focusTimer
                                        interval: 20
                                        repeat: false
                                        onTriggered: {
                                            if (keybindsWindow.isTargetMonitor) {
                                                searchInput.forceActiveFocus()
                                            }
                                        }
                                    }

                                    Component.onCompleted: {
                                        focusTimer.start()
                                    }

                                    Connections {
                                        target: keybindsWindow
                                        function onVisibleChanged() {
                                            if (keybindsWindow.visible && keybindsWindow.isTargetMonitor) {
                                                focusTimer.start()
                                            }
                                        }
                                    }

                                    onTextChanged: root.filterKeybinds(text)

                                    Keys.onDownPressed: keybindsList.incrementCurrentIndex()
                                    Keys.onUpPressed: keybindsList.decrementCurrentIndex()
                                    Keys.onEscapePressed: Qt.quit()
                                }

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 6
                                    color: clearSearchMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                    visible: searchInput.text !== ""

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: root.iconFontFamily
                                        color: root.themeTextMuted
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: clearSearchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: filteredModel.count === 0
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 54
                                height: 54
                                radius: 16
                                color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.28)
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌌"
                                    font.family: root.iconFontFamily
                                    color: root.themePrimary
                                    opacity: 0.75
                                    font.pixelSize: 24
                                }
                            }

                            ColumnLayout {
                                spacing: 3
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No Matching Shortcuts"
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: root.themeText
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Try searching by key, action, or category"
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                                }
                            }
                        }

                        ListView {
                            id: keybindsList
                            anchors.fill: parent
                            visible: filteredModel.count > 0
                            model: filteredModel
                            clip: true
                            spacing: 7
                            boundsBehavior: Flickable.StopAtBounds
                            highlightFollowsCurrentItem: true

                            add: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0
                                    to: 1
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            remove: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    to: 0
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            displaced: Transition {
                                NumberAnimation {
                                    properties: "y"
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                id: vbar
                                visible: keybindsList.visible && vbar.size < 1.0
                                active: keybindsList.moving || keybindsList.flicking || hovered
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: 4
                                    radius: 2
                                    color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                }
                            }

                            delegate: Rectangle {
                                id: delegateItem
                                width: keybindsList.width - (vbar.visible ? 10 : 0)
                                height: 46
                                radius: 10
                                color: ListView.isCurrentItem
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.76)
                                       : (rowMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                border.width: 1
                                border.color: ListView.isCurrentItem
                                              ? Qt.alpha(root.themePrimary, 0.70)
                                              : (rowMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.42) : Qt.rgba(1, 1, 1, 0.10))
                                antialiasing: true

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

                                property string rawKeys: model.itemKeys || ""

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keybindsList.currentIndex = index
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    Text {
                                        text: model.itemDesc
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }

                                    Row {
                                        spacing: 5
                                        Layout.alignment: Qt.AlignVCenter

                                        Repeater {
                                            model: delegateItem.rawKeys ? delegateItem.rawKeys.split("+") : []
                                            delegate: Rectangle {
                                                property string trimmedKey: modelData.trim()
                                                property bool isModifier: trimmedKey === "SUPER" || trimmedKey === "CTRL" || trimmedKey === "ALT" || trimmedKey === "SHIFT"
                                                height: 25
                                                width: keyText.implicitWidth + 14
                                                radius: 6
                                                color: isModifier
                                                       ? Qt.alpha(root.themePrimary, 0.18)
                                                       : Qt.rgba(0.02, 0.02, 0.03, 0.72)
                                                border.width: 1
                                                border.color: isModifier
                                                              ? Qt.alpha(root.themePrimary, 0.55)
                                                              : Qt.rgba(1, 1, 1, 0.18)
                                                antialiasing: true

                                                Text {
                                                    id: keyText
                                                    anchors.centerIn: parent
                                                    text: parent.trimmedKey
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: parent.isModifier ? root.themePrimary : root.themeText
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 22
                                        Layout.preferredWidth: catText.implicitWidth + 14
                                        radius: 6
                                        color: Qt.alpha(root.themePrimary, 0.14)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.35)
                                        antialiasing: true

                                        Text {
                                            id: catText
                                            anchors.centerIn: parent
                                            text: model.itemCategory
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: root.themePrimary
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                        radius: 10
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        antialiasing: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                text: "󰌌"
                                font.family: root.iconFontFamily
                                font.pixelSize: 13
                                color: root.themePrimary
                            }

                            Text {
                                text: filteredModel.count + " shortcuts"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.themeTextMuted
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                            }

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 6

                                Rectangle {
                                    width: 34
                                    height: 20
                                    radius: 5
                                    color: Qt.alpha(root.themePrimary, 0.16)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.40)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ESC"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: root.themePrimary
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    text: "Close"
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}