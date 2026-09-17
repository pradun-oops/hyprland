import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.10)

    property int themeRounding: 16
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.2
    }

    property real secAngle: 0
    property real minAngle: 0
    property real hourAngle: 0

    property string dateString: ""
    property string timeDigitalString: ""
    property string ampmString: "AM"

    property string lockedMon: ""
    property bool showOnAllScreens: false

    property int savedMarginTop: 120
    property int savedMarginLeft: 100

    FileView {
        id: posConfigFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/clock_pos.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let raw = text().trim()
                if (!raw) return
                let data = JSON.parse(raw)
                if (data.marginTop !== undefined && !isNaN(data.marginTop)) {
                    root.savedMarginTop = Math.max(0, parseInt(data.marginTop))
                }
                if (data.marginLeft !== undefined && !isNaN(data.marginLeft)) {
                    root.savedMarginLeft = Math.max(0, parseInt(data.marginLeft))
                }
            } catch (e) {}
        }
    }

    Process { id: savePosProcess }

    function savePosition(top, left) {
        let validTop = Math.max(0, Math.round(top))
        let validLeft = Math.max(0, Math.round(left))

        root.savedMarginTop = validTop
        root.savedMarginLeft = validLeft

        let jsonDir = Quickshell.env("HOME") + "/.config/quickshell/json"
        let jsonFile = jsonDir + "/clock_pos.json"
        let jsonTmp = jsonFile + ".tmp"
        let jsonStr = JSON.stringify({ marginTop: validTop, marginLeft: validLeft })

        let cmd = "mkdir -p '" + jsonDir + "' && echo '" + jsonStr + "' > '" + jsonTmp + "' && mv '" + jsonTmp + "' '" + jsonFile + "'"

        savePosProcess.running = false
        savePosProcess.command = ["bash", "-c", cmd]
        savePosProcess.running = true
    }

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
                    let hex = "#" + borderMatch[1]
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
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.lockedMon = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.lockedMon = Quickshell.screens[0].name
        }
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
        posConfigFile.reload()
        root.updateClock()
    }

    function updateClock() {
        let now = new Date()
        let s = now.getSeconds()
        let m = now.getMinutes()
        let h = now.getHours()

        let targetSec = s * 6
        let diffSec = (targetSec - (root.secAngle % 360) + 540) % 360 - 180
        root.secAngle += diffSec

        let targetMin = (m * 6) + (s * 0.1)
        let diffMin = (targetMin - (root.minAngle % 360) + 540) % 360 - 180
        root.minAngle += diffMin

        let targetHour = ((h % 12) * 30) + (m * 0.5)
        let diffHour = (targetHour - (root.hourAngle % 360) + 540) % 360 - 180
        root.hourAngle += diffHour

        let h12 = h % 12
        if (h12 === 0) h12 = 12
        let hStr = (h12 < 10 ? "0" : "") + h12
        let mStr = (m < 10 ? "0" : "") + m

        root.dateString = Qt.formatDateTime(now, "ddd, dd MMM").toUpperCase()
        root.timeDigitalString = hStr + ":" + mStr
        root.ampmString = h >= 12 ? "PM" : "AM"
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.updateClock()
            let drift = 1000 - (new Date()).getMilliseconds()
            interval = drift > 40 ? drift : 1000
        }
    }

    Behavior on secAngle {
        enabled: root.animEnabled
        NumberAnimation {
            duration: 190
            easing.type: animStyle.bounceEasing
            easing.overshoot: animStyle.overshoot
        }
    }

    Behavior on minAngle {
        enabled: root.animEnabled
        NumberAnimation {
            duration: animStyle.fadeDuration
            easing.type: animStyle.fadeEasing
        }
    }

    Behavior on hourAngle {
        enabled: root.animEnabled
        NumberAnimation {
            duration: animStyle.fadeDuration
            easing.type: animStyle.fadeEasing
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: clockWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: {
                if (root.showOnAllScreens) return true
                let target = root.lockedMon
                let activeScreen = Quickshell.screens.find(s => s.name === target)
                if (!activeScreen) {
                    target = Hyprland.focusedMonitor?.name ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
                }
                return modelData.name === target
            }

            visible: isTargetMonitor

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-analog-clock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true; left: true }
            margins {
                top: root.savedMarginTop
                left: root.savedMarginLeft
            }

            implicitWidth: 236
            implicitHeight: 304
            color: "transparent"

            Rectangle {
                id: clockCard
                anchors.fill: parent

                radius: root.themeRounding
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                border.width: root.themeBorderSize
                border.color: dragArea.isDragging ? root.themePrimary : Qt.alpha(root.themeBorder, 0.40)

                scale: dragArea.isDragging ? 1.02 : 1.0
                layer.enabled: root.animEnabled
                layer.smooth: true

                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: animStyle.bounceEasing
                        easing.overshoot: animStyle.overshoot
                    }
                }
                Behavior on border.color {
                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                }
                Behavior on color {
                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    pressAndHoldInterval: 120
                    z: 20

                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false

                    onPressed: (mouse) => {
                        startX = mouse.x
                        startY = mouse.y
                    }

                    onPressAndHold: (mouse) => {
                        isDragging = true
                        startX = mouse.x
                        startY = mouse.y
                    }

                    onPositionChanged: (mouse) => {
                        let dx = mouse.x - startX
                        let dy = mouse.y - startY
                        if (!isDragging && (Math.abs(dx) > 3 || Math.abs(dy) > 3)) {
                            isDragging = true
                        }
                        if (isDragging) {
                            if (Math.abs(dx) > 0 || Math.abs(dy) > 0) {
                                root.savedMarginLeft = Math.max(0, root.savedMarginLeft + dx)
                                root.savedMarginTop = Math.max(0, root.savedMarginTop + dy)
                            }
                        }
                    }

                    onReleased: {
                        if (isDragging) {
                            isDragging = false
                            root.savePosition(root.savedMarginTop, root.savedMarginLeft)
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Item {
                        id: dialContainer
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 182
                        Layout.preferredHeight: 182

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.alpha(root.themeSurface, 0.42)
                            border.width: 1
                            border.color: Qt.alpha(root.themeBorder, 0.18)
                        }

                        Repeater {
                            model: 12
                            Item {
                                anchors.centerIn: parent
                                rotation: index * 30

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: -dialContainer.height / 2 + 7
                                    width: (index % 3 === 0) ? 3.5 : 1.5
                                    height: (index % 3 === 0) ? 9 : 5
                                    radius: (index % 3 === 0) ? 1.75 : 0.75
                                    color: (index % 3 === 0) ? root.themePrimary : Qt.alpha(root.themeText, 0.45)

                                    Behavior on color {
                                        ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                    }
                                }
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            rotation: root.hourAngle

                            Rectangle {
                                x: -width / 2
                                y: -height + 7
                                width: 4.5
                                height: 50
                                radius: 2.25
                                color: root.themeText

                                Behavior on color {
                                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                }
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            rotation: root.minAngle

                            Rectangle {
                                x: -width / 2
                                y: -height + 9
                                width: 2.5
                                height: 72
                                radius: 1.25
                                color: Qt.alpha(root.themeText, 0.92)

                                Behavior on color {
                                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                }
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            rotation: root.secAngle

                            Rectangle {
                                x: -width / 2
                                y: -height + 18
                                width: 1.5
                                height: 88
                                radius: 0.75
                                color: root.themePrimary

                                Behavior on color {
                                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 11
                                width: 5
                                height: 5
                                radius: 2.5
                                color: root.themePrimary

                                Behavior on color {
                                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: root.themePrimary

                            Behavior on color {
                                ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 4
                            height: 4
                            radius: 2
                            color: root.themeBackground

                            Behavior on color {
                                ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: Math.max(6, root.themeRounding - 4)
                        color: root.themeSurface
                        border.width: 1
                        border.color: Qt.alpha(root.themeBorder, 0.12)

                        Behavior on color {
                            ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 6

                            Text {
                                text: root.dateString
                                color: root.themeTextMuted
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignVCenter

                                Behavior on color {
                                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.timeDigitalString
                                color: root.themeText
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignVCenter

                                Behavior on color {
                                    ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 26
                                height: 18
                                radius: 4
                                color: Qt.alpha(root.themePrimary, 0.20)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.45)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.ampmString
                                    color: root.themePrimary
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}