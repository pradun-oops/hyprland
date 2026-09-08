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

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 22
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.72
    property bool animEnabled: true
    property int animDuration: 220
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.04) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.08)

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
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 100
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
        execProcess.running = false;
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
            } catch(e) {
                historyModel.clear()
            }
        }
    }

    function clearAllHistory() {
        let path = Quickshell.env("HOME") + "/.config/quickshell/notification_history.json"
        exec("echo '[]' > " + path)
    }

    function removeNotification(idx) {
        if (idx >= 0 && idx < historyModel.count) {
            historyModel.remove(idx)
            let arr = []
            for (let i = 0; i < historyModel.count; i++) {
                arr.push(historyModel.get(i))
            }
            let path = Quickshell.env("HOME") + "/.config/quickshell/notification_history.json"
            let jsonStr = JSON.stringify(arr).replace(/"/g, '\\"')
            exec("echo \"" + jsonStr + "\" > " + path)
        }
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

            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-notification-center"
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                onClicked: Qt.quit()
            }

            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 56
                anchors.rightMargin: 20
                implicitWidth: 440
                implicitHeight: 680
                
                visible: root.targetMonitorName !== "" && isTargetMonitor
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }
                Keys.onEscapePressed: Qt.quit()

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
                    border.color: Qt.alpha(root.themeBorder, 0.35)

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
                                radius: 12
                                color: Qt.alpha(root.themePrimary, 0.12)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.28)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂚"
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
                                        color: root.themeText
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                    }

                                    Rectangle {
                                        visible: historyModel.count > 0
                                        Layout.preferredWidth: badgeText.implicitWidth + 12
                                        Layout.preferredHeight: 18
                                        radius: 9
                                        color: Qt.alpha(root.themePrimary, 0.2)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.4)

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: historyModel.count
                                            color: root.themePrimary
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Text {
                                    text: historyModel.count > 0 ? "Recent system alerts & messages" : "All caught up"
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: historyModel.count > 0
                                Layout.preferredWidth: clearRow.implicitWidth + 20
                                Layout.preferredHeight: 32
                                radius: 10
                                color: clearBtnArea.containsMouse ? Qt.alpha(root.themePrimary, 0.16) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: clearBtnArea.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.1)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    id: clearRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰆴"
                                        color: clearBtnArea.containsMouse ? root.themePrimary : root.themeTextMuted
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: "Clear All"
                                        color: clearBtnArea.containsMouse ? root.themeText : root.themeTextMuted
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }

                                MouseArea {
                                    id: clearBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearAllHistory()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.alpha(root.themeBorder, 0.14)
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: historyModel.count === 0
                                spacing: 12

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 64
                                    height: 64
                                    radius: 32
                                    color: Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂛"
                                        color: Qt.alpha(root.themeTextMuted, 0.4)
                                        font.pixelSize: 30
                                    }
                                }

                                ColumnLayout {
                                    spacing: 3
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "No New Notifications"
                                        color: root.themeText
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Your notification center is clear"
                                        color: root.themeTextMuted
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            ListView {
                                id: historyList
                                anchors.fill: parent
                                model: historyModel
                                spacing: 10
                                clip: true

                                delegate: Rectangle {
                                    id: card
                                    width: historyList.width
                                    
                                    property bool isExpanded: false
                                    property bool hasBody: model.body !== undefined && model.body.trim() !== ""

                                    implicitHeight: notifCardLayout.implicitHeight + 24
                                    height: implicitHeight

                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: cardArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: cardArea.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.08)

                                    Behavior on height {
                                        NumberAnimation { 
                                            duration: root.animEnabled ? root.animDuration : 0
                                            easing.type: Easing.OutCubic 
                                        }
                                    }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

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
                                            width: 36
                                            height: 36
                                            radius: 10
                                            color: Qt.alpha(root.themePrimary, 0.12)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.25)

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getAppGlyph(model.appName, model.summary)
                                                color: root.themePrimary
                                                font.pixelSize: 17
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
                                                    color: root.themePrimary
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 0.8
                                                }

                                                Text {
                                                    text: "•"
                                                    color: Qt.alpha(root.themeTextMuted, 0.4)
                                                    font.pixelSize: 10
                                                }

                                                Text {
                                                    text: root.formatTimeAgo(model.time)
                                                    color: root.themeTextMuted
                                                    font.pixelSize: 10
                                                    Layout.fillWidth: true
                                                }

                                                Rectangle {
                                                    visible: card.hasBody
                                                    width: 22
                                                    height: 22
                                                    radius: 6
                                                    color: expandHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: card.isExpanded ? "󰅃" : "󰅀"
                                                        color: card.isExpanded ? root.themePrimary : root.themeTextMuted
                                                        font.pixelSize: 11
                                                    }

                                                    MouseArea {
                                                        id: expandHover
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: card.isExpanded = !card.isExpanded
                                                    }
                                                }
                                            }

                                            Text {
                                                text: model.summary || ""
                                                color: root.themeText
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: card.hasBody
                                                text: model.body || ""
                                                color: root.themeTextMuted
                                                font.pixelSize: 11
                                                lineHeight: 1.25
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: card.isExpanded ? 12 : 1
                                                elide: Text.ElideRight
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