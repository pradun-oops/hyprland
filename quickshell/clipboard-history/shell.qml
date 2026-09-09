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

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
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

    Shortcut {
        sequence: "Escape"
        onActivated: root.quitApp()
    }

    property color themeBorder: "#38bdf8"
    property color themePrimary: "#38bdf8"
    property color themeText: "#f4f4f5"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 22
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.7
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#121215" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.04) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.08)

    property string iconFontFamily: "Symbols Nerd Font, JetBrainsMono Nerd Font, Font Awesome 6 Free, Noto Color Emoji, sans-serif"

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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/) || content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    ListModel { id: clipboardModel }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false;
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    Process {
        id: fetchClipboardProcess
        running: false
        command: ["cliphist", "list"]
        stdout: StdioCollector { id: clipboardCollector }

        onExited: (exitCode) => {
            clipboardModel.clear()
            if (exitCode !== 0 || !clipboardCollector.text) return;

            let lines = clipboardCollector.text.trim().split("\n")
            let maxItems = Math.min(lines.length, 60)

            for (let i = 0; i < maxItems; i++) {
                let line = lines[i]
                let tabIndex = line.indexOf("\t")
                if (tabIndex === -1) continue;

                let cid = line.substring(0, tabIndex)
                let rawContent = line.substring(tabIndex + 1)
                
                let isImg = rawContent.includes("[[ binary data")
                let displayTxt = rawContent.trim()
                
                if (isImg) {
                    let cleanedInfo = rawContent.replace("[[ binary data ", "").replace(" ]]", "")
                    displayTxt = "Image (" + cleanedInfo + ")"
                }

                clipboardModel.append({
                    "id": cid,
                    "raw": line,
                    "content": displayTxt,
                    "isImage": isImg,
                    "charCount": isImg ? 0 : rawContent.trim().length,
                    "lineCount": isImg ? 1 : rawContent.split("\n").length
                })
            }
        }
    }

    function refreshClipboard() {
        fetchClipboardProcess.running = false
        fetchClipboardProcess.running = true
    }

    function copyItem(rawLine) {
        let safeLine = rawLine.replace(/'/g, "'\\''")
        exec("echo '" + safeLine + "' | cliphist decode | wl-copy")
        root.quitApp()
    }

    Timer {
        id: refreshTimer
        interval: 100
        repeat: false
        onTriggered: root.refreshClipboard()
    }

    function deleteItem(rawLine) {
        let safeLine = rawLine.replace(/'/g, "'\\''")
        exec("echo '" + safeLine + "' | cliphist delete")
        refreshTimer.start()
    }

    function clearAllClipboard() {
        exec("cliphist wipe")
        clipboardModel.clear()
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") fallbackMonitorTimer.start()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        refreshClipboard()
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
            WlrLayershell.namespace: "qs-clipboard"
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
                onClicked: root.quitApp()
            }

            Item {
                id: dragContainer
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 48
                anchors.rightMargin: 24
                implicitWidth: 460
                implicitHeight: 700
                
                visible: root.targetMonitorName !== "" && isTargetMonitor
                focus: isTargetMonitor

                Component.onCompleted: { if (isTargetMonitor) forceActiveFocus() }
                onFocusChanged: { if (isTargetMonitor && !focus) forceActiveFocus() }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.quitApp()
                        event.accepted = true
                    }
                }

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
                    clip: true

                    property bool shown: false
                    Component.onCompleted: shown = true

                    scale: shown ? 1.0 : 0.90
                    opacity: shown ? 1.0 : 0.0

                    transform: Translate {
                        x: container.shown ? 0 : 20
                        Behavior on x {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.animDuration : 0
                                easing.type: animStyle.bounceEasing
                                easing.overshoot: animStyle.overshoot
                            }
                        }
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

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: Math.max(4, root.themeRounding - 8)
                                color: Qt.alpha(root.themePrimary, 0.15)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.35)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅍"
                                    font.family: root.iconFontFamily
                                    color: root.themePrimary
                                    font.pixelSize: 18
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: "Clipboard History"
                                        color: root.themeText
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                    }

                                    Rectangle {
                                        visible: clipboardModel.count > 0
                                        Layout.preferredWidth: badgeText.implicitWidth + 12
                                        Layout.preferredHeight: 20
                                        radius: 10
                                        color: Qt.alpha(root.themePrimary, 0.18)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.35)

                                        scale: clipboardModel.count > 0 ? 1.0 : 0.8
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? animStyle.animDuration : 0
                                                easing.type: animStyle.bounceEasing
                                                easing.overshoot: animStyle.overshoot
                                            }
                                        }

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: clipboardModel.count
                                            color: root.themePrimary
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Text {
                                    text: "Click item to copy • Esc to close"
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: clipboardModel.count > 0
                                Layout.preferredWidth: clearRow.implicitWidth + 20
                                Layout.preferredHeight: 34
                                radius: Math.max(4, root.themeRounding - 8)
                                color: clearBtnArea.containsMouse ? Qt.alpha("#ef4444", 0.2) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: clearBtnArea.containsMouse ? Qt.alpha("#ef4444", 0.45) : Qt.rgba(1, 1, 1, 0.1)

                                scale: clearBtnArea.pressed ? 0.92 : (clearBtnArea.containsMouse ? 1.05 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? animStyle.animDuration : 0
                                        easing.type: animStyle.bounceEasing
                                        easing.overshoot: animStyle.overshoot
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                RowLayout {
                                    id: clearRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰆴"
                                        font.family: root.iconFontFamily
                                        color: clearBtnArea.containsMouse ? "#ef4444" : root.themeTextMuted
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
                                    onClicked: root.clearAllClipboard()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: clipboardModel.count === 0
                                spacing: 12

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 56
                                    height: 56
                                    radius: 28
                                    color: Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅢"
                                        font.family: root.iconFontFamily
                                        color: Qt.alpha(root.themeTextMuted, 0.4)
                                        font.pixelSize: 26
                                    }
                                }

                                ColumnLayout {
                                    spacing: 3
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Clipboard Empty"
                                        color: root.themeText
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Copied items will appear here"
                                        color: root.themeTextMuted
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            ListView {
                                id: clipList
                                anchors.fill: parent
                                model: clipboardModel
                                spacing: 10
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                add: Transition {
                                    ParallelAnimation {
                                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                        NumberAnimation {
                                            property: "scale"
                                            from: 1.0 ; to: 1.0
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                        NumberAnimation {
                                            property: "x"
                                            from: 18; to: 0
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                }

                                remove: Transition {
                                    ParallelAnimation {
                                        NumberAnimation { property: "opacity"; to: 0; duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                        NumberAnimation { property: "scale"; to: 0.88; duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                    }
                                }

                                displaced: Transition {
                                    NumberAnimation {
                                        properties: "y,x"
                                        duration: root.animEnabled ? animStyle.animDuration : 0
                                        easing.type: animStyle.bounceEasing
                                        easing.overshoot: animStyle.overshoot
                                    }
                                }

                                delegate: Item {
                                    id: delegateRoot
                                    width: clipList.width
                                    height: card.height

                                    Rectangle {
                                        id: card
                                        width: parent.width - 12
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 74

                                        radius: Math.max(4, root.themeRounding - 6)
                                        color: cardArea.containsMouse ? root.themeSurfaceHover : Qt.rgba(1, 1, 1, 0.03)
                                        border.width: 1
                                        border.color: cardArea.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.08)

                                        scale: cardArea.pressed ? 1.0 : (cardArea.containsMouse ? 1.0 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animEnabled ? animStyle.animDuration : 0
                                                easing.type: animStyle.bounceEasing
                                                easing.overshoot: animStyle.overshoot
                                            }
                                        }
                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                        MouseArea {
                                            id: cardArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.copyItem(model.raw)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: 42
                                                Layout.preferredHeight: 42
                                                radius: 10
                                                color: model.isImage ? Qt.rgba(0.95, 0.6, 0.15, 0.15) : Qt.alpha(root.themePrimary, 0.12)
                                                border.width: 1
                                                border.color: model.isImage ? Qt.rgba(0.95, 0.6, 0.15, 0.35) : Qt.alpha(root.themePrimary, 0.25)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: model.isImage ? "󰋩" : "󰈙"
                                                    font.family: root.iconFontFamily
                                                    color: model.isImage ? "#f59e0b" : root.themePrimary
                                                    font.pixelSize: 20
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 4

                                                RowLayout {
                                                    spacing: 6
                                                    Layout.alignment: Qt.AlignVCenter

                                                    Text {
                                                        text: model.isImage ? "IMAGE" : "TEXT"
                                                        color: model.isImage ? "#f59e0b" : root.themePrimary
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                    }

                                                    Text {
                                                        text: "•"
                                                        color: root.themeTextMuted
                                                        font.pixelSize: 10
                                                    }

                                                    Text {
                                                        text: model.isImage ? model.content.replace("Image (", "").replace(")", "") : (model.charCount + " chars")
                                                        color: root.themeTextMuted
                                                        font.pixelSize: 11
                                                    }
                                                }

                                                Text {
                                                    text: model.content
                                                    color: root.themeText
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }
                                            }

                                            RowLayout {
                                                spacing: 6
                                                Layout.alignment: Qt.AlignVCenter

                                                Rectangle {
                                                    Layout.preferredWidth: 34
                                                    Layout.preferredHeight: 34
                                                    radius: Math.max(4, root.themeRounding - 8)
                                                    color: copyBtnMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                                                    border.width: 1
                                                    border.color: copyBtnMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.4) : Qt.rgba(1, 1, 1, 0.08)

                                                    scale: copyBtnMouse.pressed ? 0.9 : (copyBtnMouse.containsMouse ? 1.08 : 1.0)

                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                                            easing.type: animStyle.bounceEasing
                                                            easing.overshoot: animStyle.overshoot
                                                        }
                                                    }
                                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰆏"
                                                        font.family: root.iconFontFamily
                                                        color: copyBtnMouse.containsMouse ? root.themePrimary : root.themeTextMuted
                                                        font.pixelSize: 14
                                                    }

                                                    MouseArea {
                                                        id: copyBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.copyItem(model.raw)
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 34
                                                    Layout.preferredHeight: 34
                                                    radius: Math.max(4, root.themeRounding - 8)
                                                    color: delBtnMouse.containsMouse ? Qt.alpha("#ef4444", 0.2) : Qt.rgba(1, 1, 1, 0.05)
                                                    border.width: 1
                                                    border.color: delBtnMouse.containsMouse ? Qt.alpha("#ef4444", 0.5) : Qt.rgba(1, 1, 1, 0.08)

                                                    scale: delBtnMouse.pressed ? 0.9 : (delBtnMouse.containsMouse ? 1.08 : 1.0)

                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                                            easing.type: animStyle.bounceEasing
                                                            easing.overshoot: animStyle.overshoot
                                                        }
                                                    }
                                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰆴"
                                                        font.family: root.iconFontFamily
                                                        color: delBtnMouse.containsMouse ? "#ef4444" : root.themeTextMuted
                                                        font.pixelSize: 14
                                                    }

                                                    MouseArea {
                                                        id: delBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.deleteItem(model.raw)
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
}