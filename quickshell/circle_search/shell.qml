import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property color themeAccent: "#38bdf8"
    property color themeAccentGlow: Qt.rgba(0.22, 0.74, 0.97, 0.35)
    property color themeSurface: Qt.rgba(0.06, 0.07, 0.10, 0.82)
    property color themeBorder: Qt.rgba(1, 1, 1, 0.12)
    property string iconFont: "Symbols Nerd Font, JetBrainsMono Nerd Font, sans-serif"
    property bool isProcessing: false

    Process {
        id: execProcess
    }

    function quitApp() {
        quitTimer.start()
    }

    Timer {
        id: quitTimer
        interval: 100
        repeat: false
        onTriggered: Qt.quit()
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

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") fallbackMonitorTimer.start()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData && modelData.name ? (modelData.name === root.targetMonitorName) : false
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-circle-search"
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Item {
                anchors.fill: parent
                focus: isTargetMonitor

                Component.onCompleted: { if (isTargetMonitor) forceActiveFocus() }
                onFocusChanged: { if (isTargetMonitor && !focus) forceActiveFocus() }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape && !root.isProcessing) {
                        root.quitApp()
                        event.accepted = true
                    }
                }

                Image {
                    id: bg
                    anchors.fill: parent
                    source: "file:///tmp/circle_screen.png"
                    cache: false

                    scale: 1.02
                    opacity: 0.0

                    Component.onCompleted: {
                        scale = 1.0
                        opacity = 1.0
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        id: dimOverlay
                        anchors.fill: parent
                        color: Qt.rgba(0.02, 0.03, 0.05, 0.52)
                        opacity: 0.0

                        Component.onCompleted: opacity = 1.0
                        Behavior on opacity {
                            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        id: flashOverlay
                        anchors.fill: parent
                        color: "white"
                        opacity: 0.22

                        Component.onCompleted: opacity = 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        id: statusPill
                        anchors.top: parent.top
                        anchors.topMargin: 44
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: pillContent.implicitWidth + 38
                        height: 42
                        radius: 21

                        color: root.themeSurface
                        border.color: root.isProcessing ? root.themeAccent : root.themeBorder
                        border.width: 1
                        antialiasing: true

                        scale: 0.94
                        opacity: 0.0

                        Component.onCompleted: {
                            scale = 1.0
                            opacity = 1.0
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: 300 }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: parent.radius + 3
                            color: "transparent"
                            border.color: root.isProcessing ? root.themeAccentGlow : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 3
                            opacity: root.isProcessing ? 1.0 : 0.6
                            z: -1
                            antialiasing: true
                            Behavior on border.color {
                                ColorAnimation { duration: 300 }
                            }
                        }

                        RowLayout {
                            id: pillContent
                            anchors.centerIn: parent
                            spacing: 11

                            Item {
                                width: 18
                                height: 18
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isProcessing ? "󰑮" : "󰆦"
                                    font.family: root.iconFont
                                    color: root.themeAccent
                                    font.pixelSize: 17

                                    RotationAnimator on rotation {
                                        running: root.isProcessing
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                    }
                                }
                            }

                            Text {
                                text: root.isProcessing ? "Searching with Google Lens..." : "Select area to search"
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Rectangle {
                                visible: !root.isProcessing
                                width: escText.implicitWidth + 10
                                height: 20
                                radius: 5
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: escText
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: captureArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.isProcessing ? Qt.BusyCursor : Qt.CrossCursor

                        property int startX: 0
                        property int startY: 0
                        property bool drawing: false

                        onPressed: (mouse) => {
                            if (root.isProcessing) return
                            startX = mouse.x
                            startY = mouse.y
                            drawing = true
                            selectionBox.visible = true
                            selectionBox.x = startX
                            selectionBox.y = startY
                            selectionBox.width = 0
                            selectionBox.height = 0
                        }

                        onPositionChanged: (mouse) => {
                            if (drawing && !root.isProcessing) {
                                selectionBox.x = Math.min(startX, mouse.x)
                                selectionBox.y = Math.min(startY, mouse.y)
                                selectionBox.width = Math.abs(mouse.x - startX)
                                selectionBox.height = Math.abs(mouse.y - startY)
                            }
                        }

                        onReleased: (mouse) => {
                            if (root.isProcessing) return
                            drawing = false
                            if (selectionBox.width > 12 && selectionBox.height > 12) {
                                root.isProcessing = true
                                let cmd = "/home/pradun/.config/hypr/scripts/circle_process.sh " +
                                          selectionBox.x + " " + selectionBox.y + " " +
                                          selectionBox.width + " " + selectionBox.height

                                execProcess.running = false
                                execProcess.command = ["bash", "-c", cmd]
                                execProcess.running = true
                            } else {
                                root.quitApp()
                            }
                        }
                    }

                    Connections {
                        target: execProcess
                        function onRunningChanged() {
                            if (!execProcess.running && root.isProcessing) {
                                root.quitApp()
                            }
                        }
                    }

                    Rectangle {
                        id: selectionBox
                        visible: false
                        color: "transparent"
                        clip: true

                        Image {
                            source: "file:///tmp/circle_screen.png"
                            cache: false
                            x: -selectionBox.x
                            y: -selectionBox.y
                            width: bg.width
                            height: bg.height
                        }
                    }

                    Item {
                        visible: selectionBox.visible && !root.isProcessing
                        x: selectionBox.x
                        y: selectionBox.y
                        width: selectionBox.width
                        height: selectionBox.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            color: "transparent"
                            border.color: root.themeAccentGlow
                            border.width: 3
                            antialiasing: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: root.themeAccent
                            border.width: 2
                            antialiasing: true
                        }

                        component SelectionHandle: Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: "white"
                            border.color: root.themeAccent
                            border.width: 2
                            antialiasing: true
                        }

                        SelectionHandle { x: -5; y: -5 }
                        SelectionHandle { anchors.right: parent.right; anchors.rightMargin: -5; y: -5 }
                        SelectionHandle { x: -5; anchors.bottom: parent.bottom; anchors.bottomMargin: -5 }
                        SelectionHandle { anchors.right: parent.right; anchors.rightMargin: -5; anchors.bottom: parent.bottom; anchors.bottomMargin: -5 }

                        Rectangle {
                            anchors.top: parent.bottom
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter

                            width: dimContent.implicitWidth + 20
                            height: 26
                            radius: 13

                            color: root.themeSurface
                            border.color: root.themeAccent
                            border.width: 1
                            antialiasing: true

                            visible: captureArea.drawing && parent.width > 28

                            RowLayout {
                                id: dimContent
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: Math.round(selectionBox.width) + " × " + Math.round(selectionBox.height)
                                    color: "white"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: "px"
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}