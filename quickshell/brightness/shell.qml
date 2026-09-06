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
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 12
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    // ============================================================
    // OSD STATE PROPERTIES
    // ============================================================
    property int brightnessPct: 0
    property bool showOSD: false
    property string lockedMon: ""

    // Lock monitor on startup to prevent cursor-tracking monitor jumps
    Component.onCompleted: {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.lockedMon = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.lockedMon = Quickshell.screens[0].name
        }
    }

    property real animatedBrightness: 0
    Behavior on animatedBrightness { 
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic } 
    }

    property int lastBrightness: -1

    // ============================================================
    // THEME PARSERS
    // ============================================================
    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let borderMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (borderMatch && borderMatch[1]) { 
                    root.themeBorder = "#" + borderMatch[1]
                    root.themePrimary = "#" + borderMatch[1] 
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
                let textContent = text()
                let roundingMatch = textContent.match(/rounding\s*=\s*(\d+)/)
                if (roundingMatch && roundingMatch[1]) root.themeRounding = parseInt(roundingMatch[1])
            } catch (e) {}
        }
    }

    // ============================================================
    // COMMAND EXECUTION
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    // ============================================================
    // ZERO-PROCESS EVENT-DRIVEN BRIGHTNESS POLLING
    // ============================================================
    Timer {
        id: autoHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.showOSD = false
    }

    Process {
        id: fetchBriProcess
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (!out) return
                
                let parts = out.split(",")
                if (parts.length >= 4) {
                    let newBri = parseInt(parts[3].replace("%", ""))
                    if (!isNaN(newBri)) {
                        if (root.lastBrightness !== -1 && newBri !== root.lastBrightness) {
                            root.showOSD = true
                            autoHideTimer.restart()
                        }
                        root.lastBrightness = newBri
                        root.brightnessPct = newBri
                        root.animatedBrightness = newBri
                    }
                }
            }
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchBriProcess.running) {
                fetchBriProcess.running = true
            }
        }
    }

    // ============================================================
    // WAYLAND UI OSD DIALOG
    // ============================================================
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // Dynamic monitor target resolution
            property bool isTargetMonitor: {
                if (root.lockedMon !== "") return modelData.name === root.lockedMon
                if (Hyprland.focusedMonitor) return modelData.name === Hyprland.focusedMonitor.name
                return Quickshell.screens.length > 0 ? modelData.name === Quickshell.screens[0].name : true
            }

            visible: (root.showOSD || osdContainer.opacity > 0) && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-brightness-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { right: true }
            margins { right: 10 }

            implicitWidth: 72
            implicitHeight: 220
            color: "transparent"

            Rectangle {
                id: osdContainer
                anchors.fill: parent

                radius: root.themeRounding
                color: root.themeBackground
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.45)
                clip: true

                opacity: (root.showOSD && win.isTargetMonitor) ? 1.0 : 0.0
                scale: (root.showOSD && win.isTargetMonitor) ? 1.0 : 0.95
                enabled: root.showOSD && win.isTargetMonitor

                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: mainArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            root.brightnessPct = 0
                            root.animatedBrightness = 0
                            root.exec("brightnessctl set 0%")
                        }
                    }

                    onWheel: (wheel) => {
                        let step = wheel.angleDelta.y > 0 ? 2 : -2
                        root.brightnessPct = Math.max(0, Math.min(100, root.brightnessPct + step))
                        root.animatedBrightness = root.brightnessPct
                        root.exec(`brightnessctl set ${Math.abs(step)}%${step > 0 ? "+" : "-"}`)
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            autoHideTimer.stop()
                        } else if (root.showOSD) {
                            autoHideTimer.restart()
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Text {
                            anchors.centerIn: parent
                            text: root.brightnessPct > 66 ? "󰃠" : (root.brightnessPct > 33 ? "󰃟" : "󰃞")
                            color: root.themePrimary
                            font.pixelSize: 22
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 8
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: root.themeSurface

                            Rectangle {
                                width: parent.width
                                height: parent.height * (Math.min(100, root.animatedBrightness) / 100)
                                anchors.bottom: parent.bottom
                                radius: parent.radius
                                color: root.themePrimary
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(Math.min(100, root.animatedBrightness)) + "%"
                        color: root.themeText
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}