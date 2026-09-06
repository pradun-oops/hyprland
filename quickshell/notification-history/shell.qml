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
    // ESCAPE KEY SHORTCUT
    // ============================================================
    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    // ============================================================
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    // Geometry & Animation Defaults (overridden by .lua files)
    property int themeRounding: 22
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    property bool animEnabled: true
    property int animDuration: 220
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.07) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.12)

    // ============================================================
    // MONITOR LOCK VIA CURSOR POSITION
    // ============================================================
    property string lockedMonitor: ""

    Process {
        id: monitorDetector
        command: [
            "python3", "-c",
            "import json, subprocess\n" +
            "try:\n" +
            "    monitors = json.loads(subprocess.check_output(['hyprctl', 'monitors', '-j']))\n" +
            "    cursor = json.loads(subprocess.check_output(['hyprctl', 'cursorpos', '-j']))\n" +
            "    cx, cy = cursor['x'], cursor['y']\n" +
            "    sel = None\n" +
            "    for m in monitors:\n" +
            "        scale = m.get('scale', 1.0)\n" +
            "        w = m['width'] / scale if scale > 0 else m['width']\n" +
            "        h = m['height'] / scale if scale > 0 else m['height']\n" +
            "        if m['x'] <= cx < m['x'] + w and m['y'] <= cy < m['y'] + h:\n" +
            "            sel = m['name']\n" +
            "            break\n" +
            "    if not sel:\n" +
            "        for m in monitors:\n" +
            "            if m.get('focused'): sel = m['name']; break\n" +
            "    print(sel or (monitors[0]['name'] if monitors else ''))\n" +
            "except Exception:\n" +
            "    pass"
        ]
        stdout: SplitParser {
            onRead: data => {
                let mName = data.trim()
                if (mName !== "") {
                    root.lockedMonitor = mName
                } else {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                        root.lockedMonitor = String(Hyprland.focusedMonitor.name)
                    } else if (Quickshell.screens.length > 0) {
                        root.lockedMonitor = String(Quickshell.screens[0].name)
                    }
                }
            }
        }
    }

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
        // Trigger exact cursor monitor detection immediately on launch
        monitorDetector.running = true

        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        historyFile.reload()
    }

    // ============================================================
    // COMMAND EXECUTION & HISTORY MANAGEMENT
    // ============================================================
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

    function formatTimeAgo(timestamp) {
        if (!timestamp) return ""
        let diff = Math.floor(Date.now() / 1000) - timestamp
        if (diff < 60) return "Just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }

    // ============================================================
    // TOP RIGHT NOTIFICATION CENTER DIALOG
    // ============================================================
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // Stay hidden until lockedMonitor is set, then display only on the cursor monitor
            visible: root.lockedMonitor !== "" && modelData.name === root.lockedMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dms:notification-center"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusiveZone: -1

            // Fullscreen backdrop layer
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            // Click outside dialog to dismiss
            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            // Top-Right Positioned Container
            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 60
                anchors.rightMargin: 20
                implicitWidth: 430
                implicitHeight: 640
                focus: true

                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: Qt.quit()

                // Block clicks inside dialog card from dismissing the menu
                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                Rectangle {
                    id: container
                    anchors.fill: parent

                    radius: root.themeRounding
                    color: root.themeBackground
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        // Header
                        RowLayout {
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "Notifications"
                                    color: root.themeText
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    visible: historyModel.count > 0
                                    Layout.preferredWidth: badgeText.implicitWidth + 12
                                    Layout.preferredHeight: 20
                                    radius: 10
                                    color: Qt.alpha(root.themePrimary, 0.25)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.5)

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

                            Item { Layout.fillWidth: true }

                            // Clear All Button
                            Rectangle {
                                visible: historyModel.count > 0
                                Layout.preferredWidth: clearRow.implicitWidth + 18
                                Layout.preferredHeight: 30
                                radius: Math.max(4, root.themeRounding - 4)
                                color: clearBtnArea.containsMouse ? root.themeSurfaceHover : root.themeSurface

                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    id: clearRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰎟"
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: "Clear All"
                                        color: root.themeText
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
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
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Notification History List
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Empty State Visual
                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: historyModel.count === 0
                                spacing: 10

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "󰂛"
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    font.pixelSize: 48
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No Notifications"
                                    color: root.themeTextMuted
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
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
                                    property bool hasBody: model.body !== undefined && model.body !== ""

                                    implicitHeight: notifCardCol.implicitHeight + 24
                                    height: implicitHeight

                                    Behavior on height {
                                        NumberAnimation { 
                                            duration: root.animEnabled ? root.animDuration : 0
                                            easing.type: Easing.OutCubic 
                                        }
                                    }

                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: cardArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: root.themeBorderSize
                                    border.color: card.isExpanded ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.08)

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

                                    ColumnLayout {
                                        id: notifCardCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: {
                                                    let app = (model.appName || "").toLowerCase()
                                                    let sum = (model.summary || "").toLowerCase()
                                                    if (app.includes("grim") || sum.includes("screenshot")) return "󰄄"
                                                    if (app.includes("record") || sum.includes("record")) return "󰕧"
                                                    if (app.includes("term") || app.includes("kitty")) return "󰆍"
                                                    if (app.includes("firefox") || app.includes("chrome")) return "󰈹"
                                                    return "󰂚"
                                                }
                                                color: root.themePrimary
                                                font.pixelSize: 14
                                            }

                                            Text {
                                                text: model.appName
                                                color: root.themePrimary
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: root.formatTimeAgo(model.time)
                                                color: root.themeTextMuted
                                                font.pixelSize: 10
                                            }

                                            Text {
                                                visible: card.hasBody
                                                text: card.isExpanded ? "󰅃" : "󰅀"
                                                color: card.isExpanded ? root.themePrimary : root.themeTextMuted
                                                font.pixelSize: 12

                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        Text {
                                            text: model.summary
                                            color: root.themeText
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            visible: card.isExpanded && card.hasBody
                                            implicitHeight: bodyText.implicitHeight + 4

                                            Text {
                                                id: bodyText
                                                width: parent.width
                                                text: model.body
                                                color: root.themeTextMuted
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 8
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