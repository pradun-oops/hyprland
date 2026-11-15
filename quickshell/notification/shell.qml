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

    property string fontFamily: "FiraCode Nerd Font"

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"

    property int themeRounding: 18
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.62
    property bool animEnabled: true
    property int animDuration: 220

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.58)

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 240) : 200
        property int fadeDuration: 180
        property var smoothEasing: Easing.OutCubic
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
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
                if (rMatch && rMatch[1]) root.themeRounding = Math.max(14, parseInt(rMatch[1]))
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

    function getNotificationIcon(appName, summary) {
        let app = (appName || "").toLowerCase()
        let sum = (summary || "").toLowerCase()
        if (app.includes("grim") || app.includes("slurp") || app.includes("swappy") || sum.includes("screenshot")) return "󰄄"
        if (app.includes("wf-recorder") || app.includes("obs") || sum.includes("recording")) return "󰕧"
        if (app.includes("discord") || app.includes("vesktop") || app.includes("telegram")) return "󰙯"
        if (app.includes("spotify") || app.includes("music") || app.includes("player") || app.includes("mpv") || app.includes("vlc")) return "󰓇"
        if (app.includes("audio") || app.includes("volume") || app.includes("pulse") || app.includes("pipewire") || sum.includes("output") || sum.includes("volume")) return "󰕾"
        if (app.includes("mic") || sum.includes("microphone")) return "󰍬"
        if (app.includes("network") || app.includes("nm") || app.includes("wifi") || sum.includes("wi-fi") || sum.includes("connected")) return "󰤨"
        if (app.includes("bluetooth") || app.includes("blueman")) return "󰂯"
        if (app.includes("terminal") || app.includes("foot") || app.includes("kitty") || app.includes("alacritty")) return "󰞷"
        if (app.includes("firefox") || app.includes("zen") || app.includes("brave") || app.includes("chromium")) return "󰈹"
        if (app.includes("nautilus") || app.includes("files") || app.includes("thunar")) return "󰉋"
        if (app.includes("battery") || app.includes("power") || sum.includes("battery")) return "󰁹"
        if (sum.includes("do not disturb") || app.includes("dnd")) return "󰍶"
        return "󰂚"
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
            if (targetModel.count >= 4) {
                targetModel.remove(targetModel.count - 1)
            }
            targetModel.insert(0, {
                notifId: notifObj.id,
                appName: notifObj.appName,
                summary: notifObj.summary,
                body: notifObj.body,
                imagePath: notifObj.imagePath
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
        execProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
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
        with open(path, 'r', encoding='utf-8') as f: data = json.load(f)
    except Exception: data = []
data.insert(0, item)
data = data[:100]
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w', encoding='utf-8') as f: json.dump(data, f, indent=2)
`
        historyProcess.running = false
        historyProcess.command = ["python3", "-c", py, path, item]
        historyProcess.running = true
    }

    Notifs.NotificationServer {
        id: notifServer
        onNotification: (notification) => {
            let img = ""
            if (notification.image && String(notification.image).trim() !== "") {
                img = String(notification.image).trim()
            } else if (notification.appIcon && String(notification.appIcon).startsWith("/")) {
                img = String(notification.appIcon).trim()
            }

            let rawBody = (notification.body || "").replace(/<[^>]*>/g, "").trim()

            let notifObj = {
                id: notification.id,
                appName: notification.appName || "System",
                summary: notification.summary || "Notification",
                body: rawBody,
                imagePath: img
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
            margins { top: 52 }

            implicitWidth: 392
            implicitHeight: popupList.contentHeight
            color: "transparent"

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: root.animEnabled ? animStyle.animDuration : 0
                    easing.type: animStyle.smoothEasing
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
                            duration: root.animEnabled ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                        NumberAnimation {
                            property: "y"
                            from: -14
                            to: 0
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: root.animEnabled ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                        NumberAnimation {
                            property: "y"
                            to: -10
                            duration: root.animEnabled ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: root.animEnabled ? animStyle.animDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                delegate: Item {
                    id: delegateRoot
                    width: popupList.width
                    height: card.height

                    property real lifeProgress: 1.0

                    NumberAnimation on lifeProgress {
                        from: 1.0
                        to: 0.0
                        duration: 4200
                        running: true
                        paused: cardMouse.containsMouse || closeMouse.containsMouse
                        onFinished: root.closePopup(localPopupModel, model.notifId)
                    }

                    Rectangle {
                        id: card
                        width: parent.width
                        height: cardContent.implicitHeight + 26
                        radius: root.themeRounding
                        color: (cardMouse.containsMouse || closeMouse.containsMouse)
                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.14, 0.76)
                               : Qt.alpha(root.themeBackground, root.themeBgAlpha)
                        border.width: root.themeBorderSize
                        border.color: (cardMouse.containsMouse || closeMouse.containsMouse)
                                      ? Qt.alpha(root.themePrimary, 0.68)
                                      : Qt.alpha(root.themePrimary, 0.42)
                        antialiasing: true
                        clip: true

                        Behavior on color {
                            ColorAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: root.themeBorderSize
                            radius: Math.max(0, parent.radius - root.themeBorderSize)
                            antialiasing: true
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                                GradientStop { position: 0.45; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    root.closePopup(localPopupModel, model.notifId)
                                }
                            }
                        }

                        RowLayout {
                            id: cardContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: 14
                                rightMargin: 12
                                topMargin: 12
                            }
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                Layout.alignment: Qt.AlignTop
                                radius: 11
                                color: Qt.alpha(root.themePrimary, 0.16)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.38)
                                antialiasing: true
                                clip: true

                                Image {
                                    id: notifThumb
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: model.imagePath && model.imagePath !== ""
                                            ? (model.imagePath.startsWith("file://") ? model.imagePath : "file://" + model.imagePath)
                                            : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: notifThumb.status !== Image.Ready
                                    text: root.getNotificationIcon(model.appName, model.summary)
                                    font.family: root.fontFamily
                                    color: root.themePrimary
                                    font.pixelSize: 18
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: model.appName.toUpperCase()
                                        color: root.themePrimary
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.8
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 180
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }

                                    Text {
                                        text: "•"
                                        color: root.themeTextMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        text: "now"
                                        color: root.themeTextMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.65)
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                Text {
                                    text: model.summary
                                    color: root.themeText
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                }

                                Text {
                                    visible: model.body !== ""
                                    text: model.body
                                    color: root.themeTextMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    lineHeight: 1.15
                                    Layout.fillWidth: true
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }
                            }

                            Rectangle {
                                id: closeBtn
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignTop
                                radius: 8
                                color: closeMouse.containsMouse
                                       ? Qt.rgba(1.0, 1.0, 1.0, 0.16)
                                       : Qt.rgba(0.02, 0.02, 0.03, 0.42)
                                border.width: 1
                                border.color: closeMouse.containsMouse
                                              ? Qt.alpha(root.themePrimary, 0.55)
                                              : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                                antialiasing: true

                                Behavior on color {
                                    ColorAnimation {
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: root.fontFamily
                                    color: closeMouse.containsMouse ? root.themePrimary : root.themeTextMuted
                                    font.pixelSize: 12

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: animStyle.fadeDuration
                                            easing.type: animStyle.smoothEasing
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

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: root.themeRounding * 0.6
                            anchors.bottomMargin: root.themeBorderSize
                            height: 2
                            radius: 1
                            width: Math.max(0, (parent.width - root.themeRounding * 1.2) * delegateRoot.lifeProgress)
                            color: Qt.alpha(root.themePrimary, 0.55)
                            antialiasing: true
                        }
                    }
                }
            }
        }
    }
}