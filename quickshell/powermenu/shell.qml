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

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"

    property int themeRounding: 24
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.06)

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 240
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
    }

    property bool isOpened: false
    property bool isClosing: false
    property string pendingCommand: ""
    property string targetMonitorName: ""
    property int selectedIndex: 3
    property string uptimeString: "System Active"

    readonly property color activeAccentColor: {
        if (root.selectedIndex === 3) return "#FF453A"
        if (root.selectedIndex === 2) return "#FFCC00"
        return root.themePrimary
    }

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

    property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/qs_dialog.sh"

    Process {
        id: uptimeProcess
        command: [
            "bash", "-c",
            "UP=$(uptime -p 2>/dev/null | sed 's/^up //; s/ hours\\?/h/; s/ minutes\\?/m/; s/ days\\?/d/; s/,//g'); [ -z \"$UP\" ] && UP='Active'; printf 'Uptime: %s\\n' \"$UP\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = text.trim()
                if (s !== "") root.uptimeString = s
            }
        }
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
        id: generalFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(Math.max(parseInt(rMatch[1]) + 6, 18), 28)
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

    Timer {
        id: openAnimTimer
        interval: 16
        repeat: false
        onTriggered: root.isOpened = true
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        uptimeProcess.running = true
        openAnimTimer.start()
    }

    Timer {
        id: closeTimer
        interval: animStyle.fadeDuration
        onTriggered: Qt.quit()
    }

    function executeCommand(cmd) {
        if (root.isClosing) return
        root.pendingCommand = cmd
        root.isClosing = true
        if (cmd !== "") {
            let envPrefix = "export HYPRLAND_INSTANCE_SIGNATURE='" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") + "'; " +
                             "export WAYLAND_DISPLAY='" + (Quickshell.env("WAYLAND_DISPLAY") || "") + "'; " +
                             "export XDG_RUNTIME_DIR='" + (Quickshell.env("XDG_RUNTIME_DIR") || "") + "'; "

            Quickshell.execDetached(["bash", "-c", envPrefix + "nohup " + cmd + " >/dev/null 2>&1 &"])
        }
        closeTimer.interval = animStyle.fadeDuration
        closeTimer.start()
    }

    function executeByIndex(idx) {
        switch (idx) {
            case 0:
                root.executeCommand(root.scriptPath + " lockscreen open")
                break
            case 1:
                root.executeCommand("loginctl terminate-user $USER")
                break
            case 2:
                root.executeCommand("systemctl reboot")
                break
            case 3:
                root.executeCommand("systemctl poweroff")
                break
        }
    }

    function dismissMenu() {
        if (root.isClosing) return
        root.isClosing = true
        closeTimer.interval = animStyle.fadeDuration
        closeTimer.start()
    }

    component PowerBtn : Item {
        id: btnRoot
        property int btnIndex: 0
        property string iconText: ""
        property string labelText: ""
        property string shortcutKey: ""
        property string cmd: ""
        property color hoverColor: root.themePrimary
        property bool isSelected: root.selectedIndex === btnIndex
        property bool isHighlighted: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing

        width: 118
        height: 146
        z: isHighlighted ? 10 : 1

        scale: btnMouse.pressed ? 0.94 : (isHighlighted ? 1.08 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: root.animEnabled ? animStyle.animDuration : 0
                easing.type: animStyle.bounceEasing
                easing.overshoot: animStyle.overshoot
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.max(12, root.themeRounding - 6)
            color: btnRoot.isHighlighted
                   ? Qt.alpha(btnRoot.hoverColor, 0.22)
                   : Qt.rgba(0.0, 0.0, 0.0, 0.28)
            border.width: btnRoot.isHighlighted ? 1.5 : 1
            border.color: btnRoot.isHighlighted
                          ? Qt.alpha(btnRoot.hoverColor, 0.75)
                          : Qt.rgba(1.0, 1.0, 1.0, 0.10)
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
            }
            Behavior on border.color {
                ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                opacity: btnRoot.isHighlighted ? 1.0 : 0.0
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(btnRoot.hoverColor, 0.16) }
                    GradientStop { position: 0.5; color: "transparent" }
                }
                Behavior on opacity {
                    NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 14
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 48
                    height: 48
                    radius: 15
                    color: btnRoot.isHighlighted
                           ? Qt.alpha(btnRoot.hoverColor, 0.24)
                           : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                    border.width: 1
                    border.color: btnRoot.isHighlighted
                                  ? Qt.alpha(btnRoot.hoverColor, 0.55)
                                  : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    antialiasing: true

                    scale: btnRoot.isHighlighted ? 1.06 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        }
                    }
                    Behavior on color {
                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: btnRoot.iconText
                        font.family: root.iconFontFamily
                        color: btnRoot.isHighlighted ? btnRoot.hoverColor : root.themeText
                        font.pixelSize: 24
                        Behavior on color {
                            ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btnRoot.labelText
                    font.family: root.fontFamily
                    color: btnRoot.isHighlighted ? btnRoot.hoverColor : root.themeText
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                    Behavior on color {
                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 28
                    height: 20
                    radius: 6
                    color: btnRoot.isHighlighted
                           ? Qt.alpha(btnRoot.hoverColor, 0.28)
                           : Qt.rgba(0.0, 0.0, 0.0, 0.45)
                    border.width: 1
                    border.color: btnRoot.isHighlighted
                                  ? Qt.alpha(btnRoot.hoverColor, 0.65)
                                  : Qt.rgba(1.0, 1.0, 1.0, 0.18)
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: btnRoot.shortcutKey
                        font.family: root.fontFamily
                        color: btnRoot.isHighlighted ? "#FFFFFF" : root.themeTextMuted
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        Behavior on color {
                            ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.selectedIndex = btnRoot.btnIndex
            onClicked: root.executeCommand(btnRoot.cmd)
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: powerWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-power-menu"

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            visible: root.targetMonitorName !== "" && isTargetMonitor

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.isClosing ? 0.0 : (root.isOpened ? 0.58 : 0.0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: animStyle.fadeDuration
                        easing.type: animStyle.fadeEasing
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismissMenu()
                }
            }

            Item {
                id: keyHandlerItem
                anchors.fill: parent
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }

                onVisibleChanged: {
                    if (visible && isTargetMonitor) forceActiveFocus()
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.dismissMenu()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                        root.selectedIndex = (root.selectedIndex - 1 + 4) % 4
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.selectedIndex = (root.selectedIndex + 1) % 4
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.executeByIndex(root.selectedIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_P || event.text.toLowerCase() === "p") {
                        root.selectedIndex = 3
                        root.executeCommand("systemctl poweroff")
                        event.accepted = true
                    } else if (event.key === Qt.Key_R || event.text.toLowerCase() === "r") {
                        root.selectedIndex = 2
                        root.executeCommand("systemctl reboot")
                        event.accepted = true
                    } else if (event.key === Qt.Key_L || event.text.toLowerCase() === "l") {
                        root.selectedIndex = 0
                        root.executeCommand(root.scriptPath + " lockscreen open")
                        event.accepted = true
                    } else if (event.key === Qt.Key_E || event.text.toLowerCase() === "e") {
                        root.selectedIndex = 1
                        root.executeCommand("loginctl terminate-user $USER")
                        event.accepted = true
                    }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: mainColumn.implicitWidth + 48
                    implicitHeight: mainColumn.implicitHeight + 44

                    visible: root.targetMonitorName !== "" && isTargetMonitor

                    Rectangle {
                        id: cardRect
                        anchors.fill: parent

                        radius: root.themeRounding
                        color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.activeAccentColor, 0.50)
                        antialiasing: true

                        opacity: root.isClosing ? 0.0 : (root.isOpened ? 1.0 : 0.0)
                        scale: root.isClosing ? 0.88 : (root.isOpened ? 1.0 : 0.88)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.animDuration : 0
                                easing.type: animStyle.bounceEasing
                                easing.overshoot: animStyle.overshoot
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: root.themeBorderSize
                            radius: Math.max(0, parent.radius - root.themeBorderSize)
                            antialiasing: true
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                                GradientStop { position: 0.4; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        ColumnLayout {
                            id: mainColumn
                            anchors.centerIn: parent
                            spacing: 18

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 10
                                    color: Qt.alpha(root.activeAccentColor, 0.18)
                                    border.width: 1
                                    border.color: Qt.alpha(root.activeAccentColor, 0.45)
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        font.family: root.iconFontFamily
                                        color: root.activeAccentColor
                                        font.pixelSize: 16
                                        Behavior on color {
                                            ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: "Power Menu"
                                        font.family: root.fontFamily
                                        color: "#FFFFFF"
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                                    }

                                    Text {
                                        text: root.uptimeString
                                        font.family: root.fontFamily
                                        color: root.themeTextMuted
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: escRow.implicitWidth + 16
                                    Layout.preferredHeight: 28
                                    radius: 8
                                    color: escMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.35)
                                    border.width: 1
                                    border.color: escMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.5) : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true

                                    scale: escMouse.pressed ? 0.92 : (escMouse.containsMouse ? 1.06 : 1.0)
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                    }

                                    RowLayout {
                                        id: escRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: "ESC"
                                            font.family: root.fontFamily
                                            color: root.themePrimary
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            text: "Cancel"
                                            font.family: root.fontFamily
                                            color: root.themeTextMuted
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                        }
                                    }

                                    MouseArea {
                                        id: escMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.dismissMenu()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(1, 1, 1, 0.10)
                            }

                            RowLayout {
                                id: powerLayout
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                PowerBtn {
                                    btnIndex: 0
                                    iconText: "󰌾"
                                    labelText: "Lock"
                                    shortcutKey: "L"
                                    cmd: root.scriptPath + " lockscreen open"
                                }

                                PowerBtn {
                                    btnIndex: 1
                                    iconText: "󰍃"
                                    labelText: "Logout"
                                    shortcutKey: "E"
                                    cmd: "loginctl terminate-user $USER"
                                }

                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 88
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                    Layout.leftMargin: 4
                                    Layout.rightMargin: 4
                                }

                                PowerBtn {
                                    btnIndex: 2
                                    iconText: "󰜉"
                                    labelText: "Reboot"
                                    shortcutKey: "R"
                                    cmd: "systemctl reboot"
                                    hoverColor: "#FFCC00"
                                }

                                PowerBtn {
                                    btnIndex: 3
                                    iconText: "󰐥"
                                    labelText: "Shutdown"
                                    shortcutKey: "P"
                                    cmd: "systemctl poweroff"
                                    hoverColor: "#FF453A"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}