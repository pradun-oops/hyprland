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

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"

    property int themeRounding: 22
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#0d0e11"
    property color themeSurface: Qt.rgba(0, 0, 0, 0.45)
    property color themeSurfaceHover: Qt.rgba(255, 255, 255, 0.12)

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

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        historyFile.reload()
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    ListModel { id: historyModel }

    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.config/quickshell/notification_history.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text())
                historyModel.clear()
                for (let i = 0; i < data.length; i++) {
                    historyModel.append(data[i])
                }
            } catch (e) {
                historyModel.clear()
            }
        }
    }

    function clearAllHistory() {
        historyModel.clear()
        let path = Quickshell.env("HOME") + "/.config/quickshell/notification_history.json"
        exec("echo '[]' > '" + path + "'")
    }

    function formatTimeAgo(timestamp) {
        if (!timestamp) return ""
        let diff = Math.floor(Date.now() / 1000) - timestamp
        if (diff < 60) return "Just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }

    function getAppGlyph(app, sum) {
        let a = (app || "").toLowerCase()
        let s = (sum || "").toLowerCase()
        if (a.includes("grim") || s.includes("screenshot")) return "󰄄"
        if (a.includes("record") || s.includes("record")) return "󰕧"
        if (a.includes("term") || a.includes("kitty") || a.includes("wezterm")) return "󰆍"
        if (a.includes("firefox") || a.includes("chrome") || a.includes("zen")) return "󰈹"
        if (a.includes("spotify") || a.includes("music") || a.includes("audio")) return "󰝚"
        if (a.includes("discord") || a.includes("slack") || a.includes("telegram")) return "󰒱"
        if (a.includes("update") || a.includes("package") || a.includes("system")) return "󰚰"
        if (a.includes("bluetooth") || a.includes("device")) return "󰂯"
        if (a.includes("battery") || a.includes("power")) return "󰂄"
        return "󰂚"
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-notification-center"
            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

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

            Item {
                anchors.centerIn: parent
                implicitWidth: 440
                implicitHeight: 680

                visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }
                Keys.onEscapePressed: root.quitApp()

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                Rectangle {
                    id: container
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.35)
                    antialiasing: true
                    clip: true
                    enabled: !root.isClosing

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
                        onTriggered: container.shown = true
                    }

                    Timer {
                        id: settleTimer
                        interval: animStyle.enterDuration + 60
                        repeat: false
                        onTriggered: container.settled = true
                    }

                    opacity: panelVisible ? 1.0 : 0.0

                    transform: [
                        Scale {
                            origin.x: container.width / 2
                            origin.y: container.height / 2
                            xScale: container.panelVisible ? 1.0 : 0.94
                            yScale: container.panelVisible ? 1.0 : 0.94

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        },
                        Translate {
                            y: container.panelVisible ? 0 : 12

                            Behavior on y {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        }
                    ]

                    Behavior on opacity {
                        NumberAnimation {
                            duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 40
                                height: 40
                                radius: headerIconHover.hovered ? 14 : 12
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
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
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
                                    text: "󰂚"
                                    font.family: root.iconFontFamily
                                    color: root.themePrimary
                                    font.pixelSize: 20
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: "Notifications"
                                        font.family: root.fontFamily
                                        color: "#FFFFFF"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.9)
                                    }

                                    Rectangle {
                                        property bool hasNotifs: historyModel.count > 0
                                        visible: opacity > 0.01
                                        opacity: hasNotifs ? 1.0 : 0.0
                                        scale: hasNotifs ? 1.0 : 0.75
                                        Layout.preferredWidth: badgeText.implicitWidth + 12
                                        Layout.preferredHeight: 18
                                        radius: 9
                                        color: Qt.alpha(root.themePrimary, 0.28)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.5)
                                        antialiasing: true

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
                                        Behavior on Layout.preferredWidth {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: historyModel.count
                                            font.family: root.fontFamily
                                            color: root.themePrimary
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Text {
                                    text: historyModel.count > 0 ? "Recent system alerts & messages" : "All caught up"
                                    font.family: root.fontFamily
                                    color: root.themeTextMuted
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                property bool hasNotifs: historyModel.count > 0
                                visible: opacity > 0.01
                                opacity: hasNotifs ? 1.0 : 0.0
                                scale: hasNotifs ? (clearBtnArea.pressed ? 0.92 : (clearBtnArea.containsMouse ? 1.04 : 1.0)) : 0.85
                                Layout.preferredWidth: clearRow.implicitWidth + 20
                                Layout.preferredHeight: 32
                                radius: 10
                                color: clearBtnArea.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.rgba(0, 0, 0, 0.45)
                                border.width: 1
                                border.color: clearBtnArea.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.14)
                                antialiasing: true

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
                                Behavior on color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0; easing.type: animStyle.smoothEasing } }
                                Behavior on border.color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0; easing.type: animStyle.smoothEasing } }

                                RowLayout {
                                    id: clearRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰆴"
                                        font.family: root.iconFontFamily
                                        color: clearBtnArea.containsMouse ? root.themePrimary : root.themeTextMuted
                                        font.pixelSize: 13

                                        Behavior on color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0; easing.type: animStyle.smoothEasing } }
                                    }

                                    Text {
                                        text: "Clear All"
                                        font.family: root.fontFamily
                                        color: clearBtnArea.containsMouse ? "#FFFFFF" : root.themeTextMuted
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)

                                        Behavior on color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0; easing.type: animStyle.smoothEasing } }
                                    }
                                }

                                MouseArea {
                                    id: clearBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: hasNotifs
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearAllHistory()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(255, 255, 255, 0.1)
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                property bool isEmpty: historyModel.count === 0
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
                                    width: 64
                                    height: 64
                                    radius: 32
                                    color: Qt.rgba(0, 0, 0, 0.45)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.12)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂛"
                                        font.family: root.iconFontFamily
                                        color: Qt.alpha(root.themeTextMuted, 0.6)
                                        font.pixelSize: 30
                                    }
                                }

                                ColumnLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "No New Notifications"
                                        font.family: root.fontFamily
                                        color: "#FFFFFF"
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Your notification center is clear"
                                        font.family: root.fontFamily
                                        color: root.themeTextMuted
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }
                                }
                            }

                            ListView {
                                id: historyList
                                anchors.fill: parent
                                anchors.leftMargin: -4
                                anchors.rightMargin: -4
                                visible: historyModel.count > 0
                                model: historyModel
                                spacing: 6
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {
                                    id: vbar
                                    visible: historyModel.count > 0 && vbar.size < 1.0
                                    active: historyList.moving || historyList.flicking || hovered
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

                                delegate: Item {
                                    id: delegateRoot
                                    width: historyList.width - (vbar.visible ? 8 : 0)
                                    height: card.height + 4

                                    MouseArea {
                                        id: cardArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: card.hasBody ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (card.hasBody) {
                                                card.isExpanded = !card.isExpanded
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: card
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter

                                        property bool isExpanded: false
                                        property bool hasBody: model.body !== undefined && model.body.trim() !== ""

                                        implicitHeight: notifCardLayout.implicitHeight + 24
                                        height: implicitHeight

                                        radius: Math.max(4, root.themeRounding - 6)
                                        color: cardArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: cardArea.containsMouse ? Qt.alpha(root.themePrimary, 0.65) : Qt.rgba(255, 255, 255, 0.1)
                                        antialiasing: true
                                        scale: cardArea.pressed && card.hasBody
                                               ? 0.985
                                               : (cardArea.containsMouse ? 1.01 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on height {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }
                                        Behavior on border.color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0; easing.type: animStyle.smoothEasing } }
                                        Behavior on color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0; easing.type: animStyle.smoothEasing } }

                                        RowLayout {
                                            id: notifCardLayout
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 12
                                            spacing: 12

                                            Rectangle {
                                                Layout.alignment: Qt.AlignTop
                                                Layout.topMargin: 2
                                                width: 38
                                                height: 38
                                                radius: cardArea.containsMouse ? 14 : 12
                                                color: Qt.alpha(root.themePrimary, cardArea.containsMouse ? 0.24 : 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha(root.themePrimary, cardArea.containsMouse ? 0.55 : 0.35)
                                                antialiasing: true
                                                scale: cardArea.containsMouse ? 1.05 : 1.0

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                                Behavior on radius {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                                Behavior on color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0; easing.type: animStyle.smoothEasing } }
                                                Behavior on border.color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0; easing.type: animStyle.smoothEasing } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.getAppGlyph(model.appName, model.summary)
                                                    font.family: root.iconFontFamily
                                                    color: root.themePrimary
                                                    font.pixelSize: 18
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 4

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    Text {
                                                        text: (model.appName || "System").toUpperCase()
                                                        font.family: root.fontFamily
                                                        color: root.themePrimary
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                        font.letterSpacing: 0.9
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                    }

                                                    Text {
                                                        text: "•"
                                                        font.family: root.fontFamily
                                                        color: Qt.alpha(root.themeTextMuted, 0.6)
                                                        font.pixelSize: 11
                                                    }

                                                    Text {
                                                        text: root.formatTimeAgo(model.time)
                                                        font.family: root.fontFamily
                                                        color: root.themeTextMuted
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                        Layout.fillWidth: true
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.65)
                                                    }

                                                    Rectangle {
                                                        visible: card.hasBody
                                                        width: 24
                                                        height: 24
                                                        radius: 8
                                                        color: expandHover.containsMouse ? Qt.rgba(255, 255, 255, 0.16) : "transparent"
                                                        antialiasing: true

                                                        Behavior on color { ColorAnimation { duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0; easing.type: animStyle.smoothEasing } }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "󰅀"
                                                            font.family: root.iconFontFamily
                                                            color: card.isExpanded ? root.themePrimary : root.themeTextMuted
                                                            font.pixelSize: 14
                                                            rotation: card.isExpanded ? 180 : 0

                                                            Behavior on rotation {
                                                                NumberAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                                    easing.type: animStyle.expoEasing
                                                                }
                                                            }
                                                            Behavior on color {
                                                                ColorAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                    easing.type: animStyle.smoothEasing
                                                                }
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: expandHover
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: card.isExpanded = !card.isExpanded
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: model.summary || ""
                                                    font.family: root.fontFamily
                                                    color: "#FFFFFF"
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                }

                                                Text {
                                                    visible: card.hasBody
                                                    text: model.body || ""
                                                    font.family: root.fontFamily
                                                    color: root.themeTextMuted
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    lineHeight: 1.3
                                                    Layout.fillWidth: true
                                                    wrapMode: card.isExpanded ? Text.WrapAnywhere : Text.NoWrap
                                                    maximumLineCount: card.isExpanded ? 12 : 1
                                                    elide: Text.ElideRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}