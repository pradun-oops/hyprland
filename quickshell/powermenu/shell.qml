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

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 24
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    property bool animEnabled: true
    property int animDuration: 380 
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
    }

    property bool isOpened: false
    property bool isClosing: false
    property string pendingCommand: ""
    property string targetMonitorName: ""
    property int selectedIndex: 3

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
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(parseInt(rMatch[1]) + 8, 28)
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/) || content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    Component.onCompleted: { 
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        root.isOpened = true
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
                             "export XDG_RUNTIME_DIR='" + (Quickshell.env("XDG_RUNTIME_DIR") || "") + "'; ";
            
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

        width: 104
        height: 126

        scale: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? 1.08 : 1.0
        Behavior on scale { 
            NumberAnimation { 
                duration: root.animEnabled ? animStyle.animDuration : 0
                easing.type: animStyle.bounceEasing
                easing.overshoot: animStyle.overshoot 
            } 
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.max(8, root.themeRounding - 8)
            color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? Qt.alpha(btnRoot.hoverColor, 0.22) : "transparent"
            border.width: 1
            border.color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? Qt.alpha(btnRoot.hoverColor, 0.6) : "transparent"
            
            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
            Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 14
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    
                    Text {
                        anchors.centerIn: parent
                        text: btnRoot.iconText
                        color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? btnRoot.hoverColor : root.themeText
                        font.pixelSize: 30
                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btnRoot.labelText
                    color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? btnRoot.hoverColor : root.themeText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 26
                    height: 20
                    radius: 5
                    color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? Qt.alpha(btnRoot.hoverColor, 0.25) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                    border.width: 1
                    border.color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? Qt.alpha(btnRoot.hoverColor, 0.5) : Qt.rgba(1.0, 1.0, 1.0, 0.18)

                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: btnRoot.shortcutKey
                        color: (btnMouse.containsMouse || btnRoot.isSelected) && !root.isClosing ? btnRoot.hoverColor : root.themeTextMuted
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                    }
                }
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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

            visible: root.isOpened

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.isClosing ? 0.0 : (root.isOpened ? 0.6 : 0.0)

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
                    } else if (event.key === Qt.Key_Left) {
                        root.selectedIndex = (root.selectedIndex - 1 + 4) % 4
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        root.selectedIndex = (root.selectedIndex + 1) % 4
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.executeByIndex(root.selectedIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_P || event.text.toLowerCase() === "p") {
                        root.executeCommand("systemctl poweroff")
                        event.accepted = true
                    } else if (event.key === Qt.Key_R || event.text.toLowerCase() === "r") {
                        root.executeCommand("systemctl reboot")
                        event.accepted = true
                    } else if (event.key === Qt.Key_L || event.text.toLowerCase() === "l") {
                        root.executeCommand(root.scriptPath + " lockscreen open")
                        event.accepted = true
                    } else if (event.key === Qt.Key_E || event.text.toLowerCase() === "e") {
                        root.executeCommand("loginctl terminate-user $USER")
                        event.accepted = true
                    }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: powerLayout.implicitWidth + 48
                    implicitHeight: powerLayout.implicitHeight + 48
                    
                    visible: root.targetMonitorName !== "" && isTargetMonitor

                    Rectangle {
                        id: cardRect
                        anchors.fill: parent
                        
                        radius: root.themeRounding
                        color: root.themeBackground 
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.themeBorder, 0.45)

                        opacity: root.isClosing ? 0.0 : (root.isOpened ? 1.0 : 0.0)
                        scale: root.isClosing ? 0.90 : (root.isOpened ? 1.0 : 0.90)
                        
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

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        RowLayout {
                            id: powerLayout
                            anchors.centerIn: parent
                            spacing: 12

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
                                Layout.preferredHeight: 70
                                Layout.alignment: Qt.AlignVCenter
                                color: Qt.alpha(root.themeBorder, 0.2) 
                                Layout.margins: 10 
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