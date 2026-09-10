import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Qt5Compat.GraphicalEffects

Scope {
    id: root

    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#A1A1AA"
    property color themeBackground: "#141416"
    
    property int themeRounding: 16
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.7
    property bool animEnabled: true
    property int animDuration: 380

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
    }

    property string mediaTitle: "No media playing"
    property string mediaArtist: "Unknown Artist"
    property string mediaAlbum: "Unknown Album"
    property string mediaArtUrl: ""
    property string playerName: ""
    property var activePlayerList: []
    property string mediaStatus: "Stopped"
    property bool isPlaying: false
    property real trackPosition: 0
    property real trackLength: 0

    property int currentVolume: 50

    property int savedMarginTop: 420
    property int savedMarginLeft: 100

    FileView {
        id: posConfigFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/player_pos.json"
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
            } catch(e) {}
        }
    }

    Process {
        id: savePosProcess
    }

    function savePosition(top, left) {
        let validTop = Math.max(0, Math.round(top))
        let validLeft = Math.max(0, Math.round(left))

        root.savedMarginTop = validTop
        root.savedMarginLeft = validLeft

        let jsonDir = Quickshell.env("HOME") + "/.config/quickshell/json"
        let jsonFile = jsonDir + "/player_pos.json"
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

    Component.onCompleted: {
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        posConfigFile.reload()
        refreshAudio()
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd]
        execProcess.running = true
    }

    function formatTime(seconds) {
        if (!seconds || isNaN(seconds) || seconds <= 0) return "0:00"
        let m = Math.floor(seconds / 60)
        let s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function getPlayerArg() {
        return root.playerName !== "" ? (" -p " + root.playerName) : ""
    }

    function switchMediaPlayer() {
        if (!root.activePlayerList || root.activePlayerList.length <= 1) return;
        let currIdx = root.activePlayerList.indexOf(root.playerName);
        let nextIdx = (currIdx + 1) % root.activePlayerList.length;
        let nextPlayer = root.activePlayerList[nextIdx];
        root.playerName = nextPlayer;
        exec("playerctl -p " + nextPlayer + " play 2>/dev/null && notify-send -a 'Media Switcher' 'Switched Player' '" + nextPlayer + "'");
    }

    function adjustVolume(percent) {
        exec("pactl set-sink-volume @DEFAULT_SINK@ " + percent)
        audioDebounceTimer.restart()
    }

    Process {
        id: mediaMetadataProcess
        command: ["playerctl", "metadata", "--format", "{{status}}\t{{playerName}}\t{{title}}\t{{artist}}\t{{album}}\t{{mpris:artUrl}}\t{{position}}\t{{mpris:length}}", "-F"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim()
                if (!line) return
                let parts = line.split("\t")
                if (parts.length >= 8) {
                    root.mediaStatus = parts[0] || "Stopped"
                    root.isPlaying = root.mediaStatus.toLowerCase() === "playing"
                    root.playerName = parts[1] || ""
                    root.mediaTitle = parts[2] || "No media playing"
                    root.mediaArtist = parts[3] || "Unknown Artist"
                    root.mediaAlbum = parts[4] || ""
                    
                    let art = parts[5] || ""
                    if (art.startsWith("file://") || art.startsWith("http://") || art.startsWith("https://")) {
                        root.mediaArtUrl = art
                    } else if (art.length > 0) {
                        root.mediaArtUrl = "file://" + art
                    } else {
                        root.mediaArtUrl = ""
                    }

                    root.trackPosition = (parseFloat(parts[6]) || 0) / 1000000.0
                    root.trackLength = (parseFloat(parts[7]) || 0) / 1000000.0
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.trackLength > 0 && root.trackPosition < root.trackLength) {
                root.trackPosition += 1
            }
        }
    }

    Process {
        id: playerListProcess
        command: ["playerctl", "-l"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(p => p.trim().length > 0)
                root.activePlayerList = lines
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!playerListProcess.running) {
                playerListProcess.running = true
            }
        }
    }

    Process {
        id: audioPollProcess
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]\\+%' | head -1 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let vol = parseInt(text.trim())
                    if (!isNaN(vol)) root.currentVolume = vol
                } catch(e) {}
            }
        }
    }

    function refreshAudio() {
        if (!audioPollProcess.running) {
            audioPollProcess.running = true
        }
    }

    Timer {
        id: audioDebounceTimer
        interval: 100
        repeat: false
        onTriggered: refreshAudio()
    }

    Process {
        id: pactlSubscriber
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.indexOf("sink") !== -1) {
                    audioDebounceTimer.restart()
                }
            }
        }
    }

    property real visualizerTick: 0
    Timer {
        interval: 120
        running: root.isPlaying
        repeat: true
        onTriggered: root.visualizerTick = Math.random()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: playerWindow
            required property var modelData
            screen: modelData

            property bool shouldShow: root.mediaStatus.toLowerCase() !== "stopped" && root.mediaTitle !== "No media playing" && modelData !== null
            visible: shouldShow || widgetCard.opacity > 0.01

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-desktop-dashboard"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true; left: true }
            margins {
                top: root.savedMarginTop
                left: root.savedMarginLeft
            }

            implicitWidth: 437
            implicitHeight: 320
            color: "transparent"

            Item {
                id: widgetCard
                anchors.fill: parent

                scale: playerWindow.shouldShow ? 1.0 : 0.90
                opacity: playerWindow.shouldShow ? 1.0 : 0.0

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

                Rectangle {
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    antialiasing: true
                }

                Image {
                    id: bgArt
                    anchors.fill: parent
                    source: root.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: false 
                }

                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: "black"
                    visible: false
                    antialiasing: true
                }

                OpacityMask {
                    anchors.fill: parent
                    source: bgArt
                    maskSource: maskRect
                    visible: root.mediaArtUrl !== "" && bgArt.status === Image.Ready
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: root.mediaArtUrl !== "" ? Qt.rgba(0, 0, 0, 0.75) : "transparent"
                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: "transparent"
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.5)
                    antialiasing: true
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    pressAndHoldInterval: 150
                    z: 1 

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
                        if (isDragging) {
                            let dx = mouse.x - startX
                            let dy = mouse.y - startY
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
                    anchors.margins: 22
                    spacing: 12
                    z: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        
                        Text {
                            text: "Now Playing"
                            color: root.themePrimary
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            font.letterSpacing: 1.0
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: playerBtn
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36
                            radius: 18
                            color: playerMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.3) : Qt.alpha(root.themeText, 0.12)
                            border.width: 1; border.color: Qt.alpha(root.themePrimary, 0.4)
                            
                            scale: playerMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                            Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 14 }

                            MouseArea {
                                id: playerMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchMediaPlayer()
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.mediaTitle
                            color: root.themeText
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.mediaArtist
                            color: root.themeTextMuted
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            height: 36

                            Row {
                                spacing: 2.5
                                anchors.verticalCenter: parent.verticalCenter
                                height: 24

                                Repeater {
                                    model: 20
                                    delegate: Rectangle {
                                        width: 2.5
                                        radius: 1.25
                                        color: root.themePrimary
                                        anchors.bottom: parent.bottom

                                        height: root.isPlaying ? Math.max(4, Math.min(22, Math.floor(Math.abs(Math.sin((index + 1) * 0.7 + root.visualizerTick * 10)) * 18) + 4)) : 4

                                        Behavior on height {
                                            NumberAnimation { duration: 110; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: 36
                                height: 36
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#18181c"
                                    border.color: Qt.alpha(root.themePrimary, 0.6)
                                    border.width: 1
                                    antialiasing: true

                                    Item {
                                        id: cdRotator
                                        anchors.fill: parent

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 3500
                                            loops: Animation.Infinite
                                            running: root.isPlaying
                                        }

                                        Image {
                                            id: cdArtImg
                                            anchors.fill: parent
                                            source: root.mediaArtUrl
                                            fillMode: Image.PreserveAspectCrop
                                            visible: false
                                        }

                                        Rectangle {
                                            id: cdMaskRect
                                            anchors.fill: parent
                                            radius: width / 2
                                            visible: false
                                        }

                                        OpacityMask {
                                            anchors.fill: parent
                                            source: cdArtImg
                                            maskSource: cdMaskRect
                                            visible: root.mediaArtUrl !== "" && cdArtImg.status === Image.Ready
                                            antialiasing: true
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.65
                                            height: width
                                            radius: width / 2
                                            color: "transparent"
                                            border.color: Qt.rgba(1, 1, 1, 0.25)
                                            border.width: 1
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: root.themeBackground
                                            border.color: Qt.alpha(root.themePrimary, 0.8)
                                            border.width: 1.5
                                        }
                                    }
                                }
                            }

                            Row {
                                spacing: 2.5
                                anchors.verticalCenter: parent.verticalCenter
                                height: 24

                                Repeater {
                                    model: 20
                                    delegate: Rectangle {
                                        width: 2.5
                                        radius: 1.25
                                        color: root.themePrimary
                                        anchors.bottom: parent.bottom

                                        height: root.isPlaying ? Math.max(4, Math.min(22, Math.floor(Math.abs(Math.cos((20 - index) * 0.7 + root.visualizerTick * 10)) * 18) + 4)) : 4

                                        Behavior on height {
                                            NumberAnimation { duration: 110; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        spacing: 12

                        Text {
                            text: formatTime(root.trackPosition)
                            color: root.themeTextMuted
                            font.pixelSize: 12; font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.2)

                            Rectangle {
                                width: root.trackLength > 0 ? parent.width * Math.max(0, Math.min(1, root.trackPosition / root.trackLength)) : 0
                                height: parent.height
                                radius: parent.radius
                                color: root.themePrimary
                                Behavior on width { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                            }
                        }

                        Text {
                            text: formatTime(root.trackLength)
                            color: root.themeTextMuted
                            font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: volDownBtn
                            property bool isMinVol: root.currentVolume <= 0

                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: isMinVol ? Qt.alpha("#ef4444", 0.3) : (volDownMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : Qt.alpha(root.themeText, 0.08))
                            border.width: isMinVol ? 1 : 0
                            border.color: "#ef4444"

                            scale: volDownMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                            Text { 
                                anchors.centerIn: parent
                                text: "󰕿"
                                font.family: "Nerd Font, Symbols Nerd Font, sans-serif"
                                font.pixelSize: 18
                                color: parent.isMinVol ? "#ef4444" : root.themeText
                            }

                            MouseArea {
                                id: volDownMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.adjustVolume("-5%")
                            }
                        }

                        Rectangle {
                            id: prevBtn
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: prevMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : "transparent"

                            scale: prevMouse.containsMouse ? 1.14 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                            Text { anchors.centerIn: parent; text: "⏮"; color: root.themeText; font.pixelSize: 20 }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl " + root.getPlayerArg() + " previous")
                            }
                        }

                        Rectangle {
                            id: playBtn
                            Layout.preferredWidth: 52; Layout.preferredHeight: 52
                            radius: 26
                            color: playMouse.containsMouse ? Qt.darker(root.themePrimary, 1.15) : root.themePrimary

                            scale: playMouse.containsMouse ? 1.10 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "⏸" : "▶"
                                color: root.themeBackground
                                font.pixelSize: 22
                                anchors.horizontalCenterOffset: root.isPlaying ? 0 : 2
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl " + root.getPlayerArg() + " play-pause")
                            }
                        }

                        Rectangle {
                            id: nextBtn
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: nextMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : "transparent"

                            scale: nextMouse.containsMouse ? 1.14 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                            Text { anchors.centerIn: parent; text: "⏭"; color: root.themeText; font.pixelSize: 20 }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl " + root.getPlayerArg() + " next")
                            }
                        }

                        Rectangle {
                            id: volUpBtn
                            property bool isMaxVol: root.currentVolume >= 100

                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: isMaxVol ? Qt.alpha("#ef4444", 0.3) : (volUpMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : Qt.alpha(root.themeText, 0.08))
                            border.width: isMaxVol ? 1 : 0
                            border.color: "#ef4444"

                            scale: volUpMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                            Text { 
                                anchors.centerIn: parent
                                text: "󰕾"
                                font.family: "Nerd Font, Symbols Nerd Font, sans-serif"
                                font.pixelSize: 18
                                color: parent.isMaxVol ? "#ef4444" : root.themeText
                            }

                            MouseArea {
                                id: volUpMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("pactl set-sink-volume @DEFAULT_SINK@ +5%")
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}