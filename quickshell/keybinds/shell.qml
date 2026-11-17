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

    QtObject {
        id: animStyle
        property int base: root.animDuration > 0 ? Math.min(root.animDuration, 260) : 220
        property int enterDuration: Math.round(base * 1.35)
        property int exitDuration: Math.round(base * 1.05)
        property int animDuration: base
        property int morphDuration: Math.round(base * 1.25)
        property int fadeDuration: Math.round(base * 0.85)
        property int microDuration: Math.round(base * 0.65)
        property int scaleDuration: Math.round(base * 1.1)
        property var smoothEasing: Easing.OutQuint
        property var expoEasing: Easing.OutExpo
        property var exitEasing: Easing.OutQuint
    }

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        Qt.quit()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.quitApp()
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
    property real themeBgAlpha: 0.25

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

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
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

            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-keybinds"
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

            color: "transparent"

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Rectangle {
                id: mainCard
                width: Math.min(860, parent.width - 48)
                height: Math.min(640, parent.height - 80)
                anchors.centerIn: parent

                property bool shown: false
                property bool settled: false
                property bool panelVisible: shown && !root.isClosing

                layer.enabled: root.animEnabled && !settled && !root.isClosing
                layer.smooth: true

                Component.onCompleted: {
                    enterTriggerTimer.start()
                    settleTimer.start()
                }

                Timer {
                    id: enterTriggerTimer
                    interval: 16
                    repeat: false
                    onTriggered: mainCard.shown = true
                }

                Timer {
                    id: settleTimer
                    interval: animStyle.enterDuration + 60
                    repeat: false
                    onTriggered: mainCard.settled = true
                }

                opacity: panelVisible ? 1.0 : 0.0
                enabled: !root.isClosing

                transform: [
                    Scale {
                        origin.x: mainCard.width / 2
                        origin.y: mainCard.height / 2
                        xScale: mainCard.panelVisible ? 1.0 : 0.94
                        yScale: mainCard.panelVisible ? 1.0 : 0.94

                        Behavior on xScale {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                        Behavior on yScale {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                    },
                    Translate {
                        y: mainCard.panelVisible ? 0 : 12

                        Behavior on y {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                    }
                ]

                Behavior on opacity {
                    NumberAnimation {
                        duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.fadeDuration : 0
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
                            radius: headerIconHover.hovered ? 14 : 11
                            color: Qt.alpha(root.themePrimary, headerIconHover.hovered ? 0.24 : 0.16)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, headerIconHover.hovered ? 0.65 : 0.35)
                            antialiasing: true
                            scale: headerIconHover.hovered ? 1.05 : 1.0

                            HoverHandler { id: headerIconHover }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on radius {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

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
                            color: searchInput.activeFocus ? Qt.rgba(0.03, 0.03, 0.05, 0.72) : Qt.rgba(0.02, 0.02, 0.03, 0.58)
                            border.width: searchInput.activeFocus ? 1.5 : 1
                            border.color: searchInput.activeFocus ? Qt.alpha(root.themePrimary, 0.78) : Qt.rgba(1, 1, 1, 0.14)
                            antialiasing: true

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
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

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
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
                                            if (keybindsWindow.isTargetMonitor && !root.isClosing) {
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
                                            if (keybindsWindow.visible && keybindsWindow.isTargetMonitor && !root.isClosing) {
                                                focusTimer.start()
                                            }
                                        }
                                    }

                                    onTextChanged: root.filterKeybinds(text)

                                    Keys.onDownPressed: keybindsList.incrementCurrentIndex()
                                    Keys.onUpPressed: keybindsList.decrementCurrentIndex()
                                    Keys.onEscapePressed: root.quitApp()
                                }

                                Rectangle {
                                    property bool hasText: searchInput.text !== ""
                                    width: 22
                                    height: 22
                                    radius: 6
                                    color: clearSearchMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                    visible: opacity > 0.01
                                    opacity: hasText ? 1.0 : 0.0
                                    scale: hasText ? (clearSearchMouse.pressed ? 0.90 : (clearSearchMouse.containsMouse ? 1.06 : 1.0)) : 0.75
                                    antialiasing: true

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

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
                            property bool isEmpty: filteredModel.count === 0
                            visible: opacity > 0.01
                            opacity: isEmpty ? 1.0 : 0.0
                            scale: isEmpty ? 1.0 : 0.94
                            spacing: 12

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

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
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            highlightFollowsCurrentItem: true

                            add: Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "opacity"
                                        from: 0.0
                                        to: 1.0
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                    NumberAnimation {
                                        property: "scale"
                                        from: 0.96
                                        to: 1.0
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                        easing.type: animStyle.expoEasing
                                    }
                                }
                            }

                            remove: Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "opacity"
                                        to: 0.0
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                    NumberAnimation {
                                        property: "scale"
                                        to: 0.95
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }

                            displaced: Transition {
                                NumberAnimation {
                                    properties: "y,x"
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                    easing.type: animStyle.expoEasing
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

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                }
                            }

                            delegate: Item {
                                id: delegateItem
                                width: keybindsList.width - (vbar.visible ? 10 : 0)
                                height: 48

                                property bool isSelected: ListView.isCurrentItem
                                property string rawKeys: model.itemKeys || ""

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keybindsList.currentIndex = index
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    anchors.topMargin: 1
                                    anchors.bottomMargin: 1
                                    radius: 10
                                    color: delegateItem.isSelected
                                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.78)
                                           : (rowMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                    border.width: 1
                                    border.color: delegateItem.isSelected
                                                  ? Qt.alpha(root.themePrimary, 0.65)
                                                  : (rowMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.08))
                                    antialiasing: true
                                    scale: rowMouse.pressed
                                           ? 0.985
                                           : ((delegateItem.isSelected || rowMouse.containsMouse) ? 1.008 : 1.0)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
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
                                            font.weight: delegateItem.isSelected ? Font.Bold : Font.DemiBold
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