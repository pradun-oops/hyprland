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
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 24
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    property bool animEnabled: true
    property int animDuration: 220 
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    // ANIMATION & STATE TRACKING
    property bool isOpened: false
    property bool isClosing: false
    property string pendingCommand: ""
    property string lockedMonitor: ""

    // ============================================================
    // CONFIG PARSERS
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")
                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 80
            } catch (e) {}
        }
    }

    Component.onCompleted: { 
        if (Hyprland.focusedMonitor) {
            root.lockedMonitor = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.lockedMonitor = Quickshell.screens[0].name
        }

        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        root.isOpened = true
    }

    // ============================================================
    // COMMAND EXECUTION LOGIC
    // ============================================================
    Process { id: powerProcess }
    
    Timer { 
        id: closeTimer
        interval: 50 
        onTriggered: Qt.quit() 
    }

    function executeCommand(cmd) {
        if (root.isClosing) return
        root.pendingCommand = cmd
        root.isClosing = true
        if (cmd !== "") {
            powerProcess.command = ["bash", "-c", "nohup " + cmd + " >/dev/null 2>&1 &"]
            powerProcess.running = true
        }
        closeTimer.start()
    }

    function dismissMenu() {
        if (root.isClosing) return
        root.isClosing = true
        Qt.quit()
    }

    // ============================================================
    // REUSABLE BUTTON COMPONENT
    // ============================================================
    component PowerBtn : Item {
        id: btnRoot
        property string iconText: ""
        property string labelText: ""
        property string cmd: ""
        property color hoverColor: root.themePrimary

        width: 100; height: 110

        scale: btnMouse.containsMouse && !root.isClosing ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: Math.max(8, root.themeRounding - 8)
            color: btnMouse.containsMouse && !root.isClosing ? Qt.alpha(btnRoot.hoverColor, 0.25) : "transparent"
            border.width: 1
            border.color: btnMouse.containsMouse && !root.isClosing ? Qt.alpha(btnRoot.hoverColor, 0.6) : "transparent"
            
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btnRoot.iconText
                    color: btnMouse.containsMouse && !root.isClosing ? btnRoot.hoverColor : root.themeText
                    font.pixelSize: 32
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btnRoot.labelText
                    color: btnMouse.containsMouse && !root.isClosing ? btnRoot.hoverColor : root.themeText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.executeCommand(btnRoot.cmd)
        }
    }

    // ============================================================
    // CENTERED MODAL DIALOG WINDOW
    // ============================================================
    Variants {
        model: Quickshell.screens
        
        delegate: PanelWindow {
            id: powerWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-power-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            visible: !root.isClosing && (root.lockedMonitor !== "" ? (modelData.name === root.lockedMonitor) : true)

            // Fullscreen backdrop to catch outside clicks
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            
            // Set to transparent so Hyprland ignore_alpha ignores the backdrop
            color: "transparent"

            // Mouse click outside card closes dialog
            MouseArea {
                anchors.fill: parent
                onClicked: root.dismissMenu()
            }

            // Centered Modal Container
            Item {
                anchors.centerIn: parent
                implicitWidth: powerLayout.implicitWidth + 48
                implicitHeight: powerLayout.implicitHeight + 48
                focus: true

                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: root.dismissMenu()

                Rectangle {
                    id: cardRect
                    anchors.fill: parent
                    
                    radius: root.themeRounding
                    color: root.themeBackground 
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)

                    opacity: root.isClosing ? 0 : (root.isOpened ? 1.0 : 0.0)
                    scale: root.isClosing ? 0.95 : (root.isOpened ? 1.0 : 0.95)
                    
                    Behavior on opacity { 
                        NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutCubic } 
                    }
                    Behavior on scale { 
                        NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutBack } 
                    }

                    // Prevent clicks inside card from closing menu
                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => mouse.accepted = true
                    }

                    RowLayout {
                        id: powerLayout
                        anchors.centerIn: parent
                        spacing: 12

                        PowerBtn { iconText: "󰌾"; labelText: "Lock"; cmd: "loginctl lock-session || hyprlock" }
                        PowerBtn { iconText: "󰤄"; labelText: "Suspend"; cmd: "systemctl suspend" }
                        PowerBtn { iconText: "󰍃"; labelText: "Logout"; cmd: "loginctl terminate-user $USER" }

                        Rectangle { 
                            Layout.preferredWidth: 1 
                            Layout.fillHeight: true 
                            color: Qt.alpha(root.themeBorder, 0.2) 
                            Layout.margins: 12 
                        }

                        PowerBtn { iconText: "󰜉"; labelText: "Reboot"; cmd: "systemctl reboot"; hoverColor: "#FFCC00" }
                        PowerBtn { iconText: "󰐥"; labelText: "Shutdown"; cmd: "systemctl poweroff"; hoverColor: "#FF453A" }
                    }
                }
            }
        }
    }
}