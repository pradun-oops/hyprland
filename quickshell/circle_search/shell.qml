import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 240
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 0.15
    }

    property string fontFamily: "FiraCode Nerd Font"

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.04, 0.04, 0.06, 0.65)
    property color themePrimary: "#ffffff"
    property color themeBorder: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.55
    property bool animEnabled: true
    property int animDuration: 380

    property bool isProcessing: false
    property string imageTimestamp: Date.now().toString()
    property string targetMonitorName: Quickshell.env("CIRCLE_MONITOR") || ""

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let borderMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
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

    Process {
        id: execProcess
        onRunningChanged: {
            if (!execProcess.running && root.isProcessing) {
                safetyTimeout.stop()
                root.quitApp()
            }
        }
    }

    Timer {
        id: safetyTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.isProcessing) {
                execProcess.running = false
                root.quitApp()
            }
        }
    }

    function quitApp() {
        execProcess.running = false
        quitTimer.start()
    }

    Timer {
        id: quitTimer
        interval: 60
        repeat: false
        onTriggered: Qt.quit()
    }

    function updateTargetMonitor() {
        if (root.targetMonitorName !== "") return
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.targetMonitorName = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 80
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
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
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

            Shortcut {
                sequence: "Escape"
                onActivated: root.quitApp()
            }

            Item {
                anchors.fill: parent
                focus: isTargetMonitor

                Component.onCompleted: { if (isTargetMonitor) forceActiveFocus() }
                onFocusChanged: { if (isTargetMonitor && !focus) forceActiveFocus() }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.quitApp()
                        event.accepted = true
                    }
                }

                Image {
                    id: bg
                    anchors.fill: parent
                    source: "file:///tmp/circle_screen.png?t=" + root.imageTimestamp
                    cache: false
                    smooth: true

                    scale: 1.015
                    opacity: 0.0

                    Component.onCompleted: {
                        scale = 1.0
                        opacity = 1.0
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.fadeEasing
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: animStyle.fadeDuration
                            easing.type: animStyle.fadeEasing
                        }
                    }

                    Rectangle {
                        id: dimOverlay
                        anchors.fill: parent
                        color: Qt.rgba(0.02, 0.02, 0.04, 0.56)
                        opacity: 0.0

                        Component.onCompleted: opacity = 1.0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing
                            }
                        }
                    }

                    Rectangle {
                        id: flashOverlay
                        anchors.fill: parent
                        color: root.themePrimary
                        opacity: 0.18

                        Component.onCompleted: opacity = 0.0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 380
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        id: statusPill
                        anchors.top: parent.top
                        anchors.topMargin: 42
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: pillContent.implicitWidth + 36
                        height: 46
                        radius: Math.max(14, root.themeRounding)

                        color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                        border.color: root.isProcessing ? root.themePrimary : Qt.alpha(root.themePrimary, 0.45)
                        border.width: root.themeBorderSize
                        antialiasing: true

                        scale: 0.90
                        opacity: 0.0

                        Component.onCompleted: {
                            scale = 1.0
                            opacity = 1.0
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.animDuration : 0
                                easing.type: animStyle.bounceEasing
                                easing.overshoot: animStyle.overshoot
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing
                            }
                        }

                        RowLayout {
                            id: pillContent
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: Qt.alpha(root.themePrimary, 0.18)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.35)
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isProcessing ? "󰑮" : "󰆦"
                                    font.family: root.fontFamily
                                    color: root.themePrimary
                                    font.pixelSize: 15

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
                                color: root.themeText
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.65)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Rectangle {
                                visible: !root.isProcessing
                                width: escText.implicitWidth + 14
                                height: 24
                                radius: 7
                                color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                border.color: Qt.alpha(root.themePrimary, 0.3)
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: escText
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    color: root.themePrimary
                                    font.family: root.fontFamily
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
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: root.isProcessing ? Qt.BusyCursor : Qt.CrossCursor

                        property real startX: 0
                        property real startY: 0
                        property bool drawing: false

                        onPressed: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                root.quitApp()
                                return
                            }
                            if (root.isProcessing) return
                            startX = Math.max(0, Math.min(bg.width, mouse.x))
                            startY = Math.max(0, Math.min(bg.height, mouse.y))
                            drawing = true
                            selectionBox.visible = true
                            selectionBox.x = startX
                            selectionBox.y = startY
                            selectionBox.width = 0
                            selectionBox.height = 0
                        }

                        onPositionChanged: (mouse) => {
                            if (drawing && !root.isProcessing) {
                                let curX = Math.max(0, Math.min(bg.width, mouse.x))
                                let curY = Math.max(0, Math.min(bg.height, mouse.y))
                                selectionBox.x = Math.min(startX, curX)
                                selectionBox.y = Math.min(startY, curY)
                                selectionBox.width = Math.abs(curX - startX)
                                selectionBox.height = Math.abs(curY - startY)
                            }
                        }

                        onReleased: (mouse) => {
                            if (mouse.button === Qt.RightButton || root.isProcessing) return
                            drawing = false
                            if (selectionBox.width > 12 && selectionBox.height > 12) {
                                root.isProcessing = true
                                safetyTimeout.restart()

                                let scaleX = (bg.sourceSize.width > 0 && bg.width > 0) ? (bg.sourceSize.width / bg.width) : 1.0
                                let scaleY = (bg.sourceSize.height > 0 && bg.height > 0) ? (bg.sourceSize.height / bg.height) : 1.0

                                let cropX = Math.max(0, Math.round(selectionBox.x * scaleX))
                                let cropY = Math.max(0, Math.round(selectionBox.y * scaleY))
                                let cropW = Math.max(1, Math.round(selectionBox.width * scaleX))
                                let cropH = Math.max(1, Math.round(selectionBox.height * scaleY))

                                let scriptPath = Quickshell.env("HOME") + "/.config/hypr/scripts/circle_process.sh"

                                execProcess.running = false
                                execProcess.command = [
                                    "bash",
                                    scriptPath,
                                    cropX.toString(),
                                    cropY.toString(),
                                    cropW.toString(),
                                    cropH.toString()
                                ]
                                execProcess.running = true
                            } else {
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
                            source: bg.source
                            cache: false
                            smooth: true
                            x: -selectionBox.x
                            y: -selectionBox.y
                            width: bg.width
                            height: bg.height
                        }
                    }

                    Item {
                        visible: selectionBox.visible
                        x: selectionBox.x
                        y: selectionBox.y
                        width: selectionBox.width
                        height: selectionBox.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 4
                            color: "transparent"
                            border.color: Qt.alpha(root.themePrimary, 0.35)
                            border.width: 4
                            antialiasing: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: root.themePrimary
                            border.width: 2
                            antialiasing: true
                        }

                        Rectangle {
                            visible: !root.isProcessing && parent.width > 60 && parent.height > 60
                            x: parent.width / 3
                            y: 0
                            width: 1
                            height: parent.height
                            color: Qt.alpha(root.themePrimary, 0.22)
                        }
                        Rectangle {
                            visible: !root.isProcessing && parent.width > 60 && parent.height > 60
                            x: (parent.width / 3) * 2
                            y: 0
                            width: 1
                            height: parent.height
                            color: Qt.alpha(root.themePrimary, 0.22)
                        }
                        Rectangle {
                            visible: !root.isProcessing && parent.width > 60 && parent.height > 60
                            x: 0
                            y: parent.height / 3
                            width: parent.width
                            height: 1
                            color: Qt.alpha(root.themePrimary, 0.22)
                        }
                        Rectangle {
                            visible: !root.isProcessing && parent.width > 60 && parent.height > 60
                            x: 0
                            y: (parent.height / 3) * 2
                            width: parent.width
                            height: 1
                            color: Qt.alpha(root.themePrimary, 0.22)
                        }

                        component SelectionHandle: Rectangle {
                            visible: !root.isProcessing
                            width: 12
                            height: 12
                            radius: 6
                            color: root.themeBackground
                            border.color: root.themePrimary
                            border.width: 2.5
                            antialiasing: true
                        }

                        SelectionHandle { x: -6; y: -6 }
                        SelectionHandle { anchors.right: parent.right; anchors.rightMargin: -6; y: -6 }
                        SelectionHandle { x: -6; anchors.bottom: parent.bottom; anchors.bottomMargin: -6 }
                        SelectionHandle { anchors.right: parent.right; anchors.rightMargin: -6; anchors.bottom: parent.bottom; anchors.bottomMargin: -6 }

                        Rectangle {
                            anchors.top: (parent.y + parent.height + 42 < bg.height) ? parent.bottom : undefined
                            anchors.bottom: (parent.y + parent.height + 42 >= bg.height) ? parent.top : undefined
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter

                            width: dimContent.implicitWidth + 22
                            height: 28
                            radius: 9

                            color: Qt.alpha(root.themeBackground, 0.82)
                            border.color: Qt.alpha(root.themePrimary, 0.65)
                            border.width: 1.5
                            antialiasing: true

                            visible: !root.isProcessing && parent.width > 32 && parent.height > 24

                            RowLayout {
                                id: dimContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰩭"
                                    color: root.themePrimary
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: Math.round(selectionBox.width) + " × " + Math.round(selectionBox.height)
                                    color: root.themeText
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}