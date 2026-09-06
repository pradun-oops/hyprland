import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications as Notifs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Scope {
    id: root

    // ============================================================
    // ADAPTIVE THEME PROPERTIES (MATCHED WITH BAR & DOCK)
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 16
    property int themeBorderSize: 1
    property real themeBgAlpha: 1.0
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

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
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        colorFile.reload()
        generalFile.reload()
    }

    // ============================================================
    // ACTIVE MONITOR DETECTOR (TRACKS CURSOR SCREEN)
    // ============================================================
    property string activeMonitorName: ""

    Process {
        id: monitorDetectProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let name = text.trim()
                if (name !== "") {
                    root.activeMonitorName = name
                }
            }
        }
    }

    Timer {
        id: monitorDetectTimer
        interval: 300
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!monitorDetectProcess.running) {
                let pyScript = `
import json, subprocess
try:
    cursor = json.loads(subprocess.check_output(["hyprctl", "cursorpos", "-j"], text=True))
    cx, cy = cursor.get("x", 0), cursor.get("y", 0)
    mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
    focused_mon = None
    found_mon = None
    for m in mons:
        if m.get("focused"):
            focused_mon = m.get("name")
        mx, my = m.get("x", 0), m.get("y", 0)
        mw = m.get("width", 0) / m.get("scale", 1.0)
        mh = m.get("height", 0) / m.get("scale", 1.0)
        if mx <= cx <= mx + mw and my <= cy <= my + mh:
            found_mon = m.get("name")
    print(found_mon or focused_mon or (mons[0]["name"] if mons else ""))
except Exception:
    print("")
`
                monitorDetectProcess.command = ["python3", "-c", pyScript]
                monitorDetectProcess.running = true
            }
        }
    }

    // ============================================================
    // SCREEN MODEL REGISTRATION & DISPATCHING
    // ============================================================
    property var screenModels: ({})

    function registerScreenModel(name, model) {
        let models = root.screenModels
        models[name] = model
        root.screenModels = models
    }

    function unregisterScreenModel(name) {
        let models = root.screenModels
        delete models[name]
        root.screenModels = models
    }

    function dispatchNotification(notifObj) {
        let target = root.activeMonitorName
        let targetModel = root.screenModels[target]
        
        // Fallback to first available monitor model if monitor name not mapped
        if (!targetModel) {
            let keys = Object.keys(root.screenModels)
            if (keys.length > 0) targetModel = root.screenModels[keys[0]]
        }

        if (targetModel) {
            targetModel.insert(0, {
                notifId: notifObj.id,
                appName: notifObj.appName,
                summary: notifObj.summary,
                body: notifObj.body
            })
        }
        root.saveToHistory(notifObj)
    }

    function closePopup(localModel, id) {
        for (let i = 0; i < localModel.count; i++) {
            if (localModel.get(i).notifId === id) {
                localModel.remove(i)
                break
            }
        }
    }

    // ============================================================
    // COMMAND EXECUTION & HISTORY SAVER
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    Process { id: historyProcess }
    function saveToHistory(notif) {
        let path = Quickshell.env("HOME") + "/.config/quickshell/notification_history.json"
        let item = JSON.stringify({
            id: notif.id,
            appName: notif.appName || "System",
            summary: notif.summary || "New Notification",
            body: notif.body || "",
            time: Math.floor(Date.now() / 1000)
        })
        let py = `import sys, json, os
path = sys.argv[1]
item = json.loads(sys.argv[2])
data = []
if os.path.exists(path):
    try:
        with open(path, 'r') as f: data = json.load(f)
    except: data = []
data.insert(0, item)
data = data[:100]
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f: json.dump(data, f, indent=2)
`
        historyProcess.command = ["python3", "-c", py, path, item]
        historyProcess.running = true
    }

    // ============================================================
    // NOTIFICATION SERVER
    // ============================================================
    Notifs.NotificationServer {
        id: notifServer
        onNotification: (notification) => {
            let notifObj = {
                id: notification.id,
                appName: notification.appName || "System",
                summary: notification.summary || "New Notification",
                body: notification.body || ""
            }
            root.dispatchNotification(notifObj)
        }
    }

    // ============================================================
    // WAYLAND UI NOTIFICATION POPUP WINDOW (PER MONITOR)
    // ============================================================
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property string screenName: win.screen ? win.screen.name : ""

            ListModel { id: localPopupModel }

            Component.onCompleted: {
                if (win.screenName !== "") {
                    root.registerScreenModel(win.screenName, localPopupModel)
                }
            }

            Component.onDestruction: {
                if (win.screenName !== "") {
                    root.unregisterScreenModel(win.screenName)
                }
            }

            visible: localPopupModel.count > 0

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true }
            margins { top: 50 }

            implicitWidth: 360
            implicitHeight: popupList.contentHeight
            color: "transparent"

            // Smoothly animate the total window height so Hyprland's blur doesn't jitter
            Behavior on implicitHeight {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            ListView {
                id: popupList
                anchors.fill: parent
                model: localPopupModel
                spacing: 10
                interactive: false

                // FIXED: Removed the Y overlap animation. Now scales and fades in cleanly.
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.85; to: 1; duration: 250; easing.type: Easing.OutBack }
                    }
                }
                
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutQuad }
                        NumberAnimation { property: "scale"; to: 0.85; duration: 200; easing.type: Easing.OutQuad }
                    }
                }
                
                // FIXED: Automatically slides existing notifications down smoothly without overlapping
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    // Wrapper to keep the ListView spacing intact during scale animations
                    width: popupList.width
                    height: card.height

                    Rectangle {
                        id: card
                        width: parent.width
                        height: cardContent.implicitHeight + 20
                        radius: root.themeRounding
                        color: root.themeBackground
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.themeBorder, 0.45)
                        clip: true

                        // Auto-dismissal timer (4 seconds)
                        Timer {
                            interval: 4000
                            running: true
                            onTriggered: root.closePopup(localPopupModel, model.notifId)
                        }

                        RowLayout {
                            id: cardContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 10
                            }
                            spacing: 12

                            // Modern Accent Icon Badge
                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                Layout.alignment: Qt.AlignVCenter
                                radius: 12
                                color: Qt.alpha(root.themePrimary, 0.12)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        let app = model.appName.toLowerCase()
                                        let sum = model.summary.toLowerCase()
                                        if (app.includes("grim") || sum.includes("screenshot")) return "󰄄"
                                        if (app.includes("discord") || app.includes("vesktop")) return "󰙯"
                                        if (app.includes("spotify") || app.includes("music")) return "󰓇"
                                        if (app.includes("terminal") || app.includes("foot") || app.includes("kitty")) return "󰞷"
                                        return "󰂚"
                                    }
                                    color: root.themePrimary
                                    font.pixelSize: 18
                                }
                            }

                            // Compact Info Layout
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: model.appName.toUpperCase()
                                    color: root.themePrimary
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.summary
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    visible: model.body !== ""
                                    text: model.body
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }

                            // Close Button
                            Rectangle {
                                id: closeBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignTop
                                radius: 12
                                color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: closeMouse.containsMouse ? root.themeText : root.themeTextMuted
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(localPopupModel, model.notifId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}