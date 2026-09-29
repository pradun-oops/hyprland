import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notifs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Scope {
    id: root

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#D4D4D8"
    
    property int themeRounding: 16
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(0, 0, 0, 0.32) 

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 0.1
        property color hoverColor: Qt.rgba(255, 255, 255, 0.14)
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

    Component.onCompleted: {
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
    }

    function getFocusedMonitorName() {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            return Hyprland.focusedMonitor.name
        }
        if (Quickshell.screens.length > 0) {
            return Quickshell.screens[0].name
        }
        return ""
    }

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
        let target = root.getFocusedMonitorName()
        let targetModel = root.screenModels[target]
        
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

            Behavior on implicitHeight {
                NumberAnimation { 
                    duration: root.animEnabled ? animStyle.animDuration : 0
                    easing.type: animStyle.bounceEasing
                    easing.overshoot: animStyle.overshoot
                }
            }

            ListView {
                id: popupList
                anchors.fill: parent
                model: localPopupModel
                spacing: 10
                interactive: false

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { 
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: animStyle.fadeDuration
                            easing.type: animStyle.fadeEasing 
                        }
                        NumberAnimation { 
                            property: "scale"
                            from: 0.88
                            to: 1.0
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        }
                        NumberAnimation {
                            property: "y"
                            from: -20
                            to: 0
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        }
                    }
                }
                
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { 
                            property: "opacity"
                            to: 0
                            duration: animStyle.fadeDuration
                            easing.type: animStyle.fadeEasing 
                        }
                        NumberAnimation { 
                            property: "scale"
                            to: 0.88
                            duration: animStyle.fadeDuration
                            easing.type: animStyle.fadeEasing 
                        }
                    }
                }
                
                displaced: Transition {
                    NumberAnimation { 
                        properties: "x,y"
                        duration: root.animEnabled ? animStyle.animDuration : 0
                        easing.type: animStyle.bounceEasing
                        easing.overshoot: animStyle.overshoot
                    }
                }

                delegate: Item {
                    width: popupList.width
                    height: card.height

                    Rectangle {
                        id: card
                        width: parent.width
                        height: cardContent.implicitHeight + 20
                        radius: root.themeRounding
                        color: Qt.rgba(root.themeBackground.r, root.themeBackground.g, root.themeBackground.b, root.themeBgAlpha)
                        border.width: root.themeBorderSize
                        border.color: Qt.rgba(root.themePrimary.r, root.themePrimary.g, root.themePrimary.b, 0.40)
                        antialiasing: true
                        clip: true

                        scale: cardMouse.containsMouse ? 1.0 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.animDuration : 0
                                easing.type: animStyle.bounceEasing
                                easing.overshoot: animStyle.overshoot
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                        }

                        Timer {
                            interval: 4000
                            running: true
                            onTriggered: root.closePopup(localPopupModel, model.notifId)
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
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

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                Layout.alignment: Qt.AlignVCenter
                                radius: 12
                                color: Qt.rgba(root.themePrimary.r, root.themePrimary.g, root.themePrimary.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(root.themePrimary.r, root.themePrimary.g, root.themePrimary.b, 0.35)
                                antialiasing: true

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
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Text {
                                    text: model.summary
                                    color: "#FFFFFF"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                }

                                Text {
                                    visible: model.body !== ""
                                    text: model.body
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                }
                            }

                            Rectangle {
                                id: closeBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignTop
                                radius: 12
                                color: closeMouse.containsMouse ? animStyle.hoverColor : "transparent"
                                antialiasing: true

                                scale: closeMouse.containsMouse ? 1.15 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? animStyle.animDuration : 0
                                        easing.type: animStyle.bounceEasing
                                        easing.overshoot: animStyle.overshoot
                                    }
                                }

                                Behavior on color { 
                                    ColorAnimation { 
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.fadeEasing 
                                    } 
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: closeMouse.containsMouse ? "#FFFFFF" : root.themeTextMuted
                                    font.pixelSize: 12
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.6)

                                    Behavior on color { 
                                        ColorAnimation { 
                                            duration: animStyle.fadeDuration
                                            easing.type: animStyle.fadeEasing 
                                        } 
                                    }
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