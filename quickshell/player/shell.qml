import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#D4D4D8"
    property color themeBackground: "#0d0e11"

    property int themeRounding: 22
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property bool animEnabled: true
    property int animDuration: 220

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

    property string mediaTitle: "No media playing"
    property string mediaArtist: "Unknown Artist"
    property string mediaAlbum: ""
    property string mediaArtUrl: ""
    property string playerName: ""
    property var activePlayerList: []
    property string mediaStatus: "Stopped"
    property bool isPlaying: false
    property real trackPosition: 0
    property real trackLength: 0

    property int currentVolume: 50
    property bool showVolPill: false

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
            } catch (e) {}
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

    function formatPlayerLabel() {
        if (!root.playerName || root.playerName.trim() === "") return "MEDIA PLAYER"
        let clean = root.playerName.split(".")[0]
        return clean.toUpperCase()
    }

    function switchMediaPlayer() {
        if (!root.activePlayerList || root.activePlayerList.length <= 1) return
        let currIdx = root.activePlayerList.indexOf(root.playerName)
        let nextIdx = (currIdx + 1) % root.activePlayerList.length
        let nextPlayer = root.activePlayerList[nextIdx]
        root.playerName = nextPlayer
        exec("playerctl -p " + nextPlayer + " play 2>/dev/null && notify-send -a 'Media Switcher' 'Switched Player' '" + nextPlayer + "'")
    }

    function adjustVolume(delta) {
        exec("pactl set-sink-volume @DEFAULT_SINK@ " + delta)
        root.showVolPill = true
        volPillHideTimer.restart()
        audioDebounceTimer.restart()
    }

    function seekToFraction(frac) {
        if (root.trackLength <= 0) return
        let clamped = Math.max(0, Math.min(1, frac))
        let targetSec = clamped * root.trackLength
        root.trackPosition = targetSec
        exec("playerctl" + root.getPlayerArg() + " position " + targetSec.toFixed(2))
    }

    Timer {
        id: volPillHideTimer
        interval: 1600
        repeat: false
        onTriggered: root.showVolPill = false
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
                } catch (e) {}
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

    property real visualizerPhase: 0
    Timer {
        interval: 90
        running: root.isPlaying
        repeat: true
        onTriggered: root.visualizerPhase += 0.42
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
            implicitHeight: 334
            color: "transparent"

            Item {
                id: widgetCard
                anchors.fill: parent

                property bool settled: false
                property bool cardVisible: playerWindow.shouldShow

                layer.enabled: root.animEnabled && !settled
                layer.smooth: true

                onCardVisibleChanged: {
                    settled = false
                    settleTimer.restart()
                }

                Timer {
                    id: settleTimer
                    interval: animStyle.enterDuration + 40
                    repeat: false
                    onTriggered: widgetCard.settled = true
                }

                scale: cardVisible ? 1.0 : 0.94
                opacity: cardVisible ? 1.0 : 0.0

                transform: Translate {
                    y: widgetCard.cardVisible ? 0 : 10
                    Behavior on y {
                        NumberAnimation {
                            duration: root.animEnabled ? animStyle.enterDuration : 0
                            easing.type: animStyle.expoEasing
                        }
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.enterDuration : 0
                        easing.type: animStyle.expoEasing
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.35)
                    antialiasing: true
                    clip: true
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
                    anchors.margins: 20
                    spacing: 14
                    z: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 38
                            height: 38
                            radius: headerIconHover.hovered ? 13 : 11
                            color: Qt.alpha(root.themePrimary, headerIconHover.hovered ? 0.24 : 0.16)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, headerIconHover.hovered ? 0.6 : 0.35)
                            antialiasing: true
                            scale: headerIconHover.hovered ? 1.05 : 1.0

                            HoverHandler { id: headerIconHover }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on radius {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.microDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                font.family: root.iconFontFamily
                                font.pixelSize: 18
                                color: root.themePrimary
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                spacing: 8

                                Text {
                                    text: "Now Playing"
                                    font.family: root.fontFamily
                                    color: root.themeText
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                }

                                Rectangle {
                                    visible: opacity > 0.01
                                    opacity: root.showVolPill ? 1.0 : 0.0
                                    scale: root.showVolPill ? 1.0 : 0.85
                                    Layout.preferredWidth: volBadgeText.implicitWidth + 12
                                    Layout.preferredHeight: 18
                                    radius: 9
                                    color: Qt.alpha(root.themePrimary, 0.24)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.45)
                                    antialiasing: true

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.scaleDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Text {
                                        id: volBadgeText
                                        anchors.centerIn: parent
                                        text: "VOL " + root.currentVolume + "%"
                                        font.family: root.fontFamily
                                        color: root.themePrimary
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            Text {
                                text: root.formatPlayerLabel() + " • " + (root.isPlaying ? "Playing" : "Paused")
                                font.family: root.fontFamily
                                color: root.themeTextMuted
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: playerBtn
                            property bool canSwitch: root.activePlayerList && root.activePlayerList.length > 1
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: playerMouse.containsMouse ? 12 : 10
                            color: playerMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.rgba(0, 0, 0, 0.45)
                            border.width: 1
                            border.color: playerMouse.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.14)
                            antialiasing: true
                            opacity: canSwitch ? 1.0 : 0.65
                            scale: playerMouse.pressed ? 0.92 : (playerMouse.containsMouse ? 1.06 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on radius {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.microDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰓦"
                                font.family: root.iconFontFamily
                                font.pixelSize: 16
                                color: playerMouse.containsMouse ? root.themePrimary : root.themeText
                            }

                            MouseArea {
                                id: playerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: playerBtn.canSwitch ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.switchMediaPlayer()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Math.max(10, root.themeRounding - 6)
                        color: Qt.rgba(0, 0, 0, 0.42)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.10)
                        antialiasing: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Item {
                                    width: 56
                                    height: 56

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "#111216"
                                        border.color: Qt.alpha(root.themePrimary, 0.55)
                                        border.width: 1.5
                                        antialiasing: true

                                        Item {
                                            id: cdRotator
                                            anchors.fill: parent
                                            anchors.margins: 2

                                            RotationAnimation on rotation {
                                                from: 0
                                                to: 360
                                                duration: 6000
                                                loops: Animation.Infinite
                                                running: root.isPlaying
                                            }

                                            Item {
                                                id: artMaskWrapper
                                                anchors.fill: parent
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: cdMaskRect
                                                }

                                                Image {
                                                    id: cdArtImg
                                                    anchors.fill: parent
                                                    source: root.mediaArtUrl
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                    antialiasing: true
                                                    visible: root.mediaArtUrl !== "" && status === Image.Ready
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: Qt.alpha(root.themePrimary, 0.16)
                                                    visible: root.mediaArtUrl === "" || cdArtImg.status !== Image.Ready

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰎈"
                                                        font.family: root.iconFontFamily
                                                        font.pixelSize: 22
                                                        color: root.themePrimary
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: cdMaskRect
                                                anchors.fill: artMaskWrapper
                                                radius: width / 2
                                                color: "black"
                                                visible: false
                                                layer.enabled: true
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width * 0.64
                                                height: width
                                                radius: width / 2
                                                color: "transparent"
                                                border.color: Qt.rgba(1, 1, 1, 0.22)
                                                border.width: 1
                                                antialiasing: true
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: "#0d0e11"
                                                border.color: Qt.alpha(root.themePrimary, 0.85)
                                                border.width: 1.5
                                                antialiasing: true
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.mediaTitle
                                        font.family: root.fontFamily
                                        color: root.themeText
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.mediaArtist
                                        font.family: root.fontFamily
                                        color: root.themeTextMuted
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.mediaAlbum !== ""
                                        text: root.mediaAlbum
                                        font.family: root.fontFamily
                                        color: Qt.alpha(root.themeTextMuted, 0.72)
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    height: 22

                                    Repeater {
                                        model: 34
                                        delegate: Rectangle {
                                            property real edgeFade: 1.0 - Math.pow(Math.abs(index - 16.5) / 17.5, 2.2) * 0.55
                                            width: 3
                                            radius: 1.5
                                            color: root.themePrimary
                                            opacity: root.isPlaying ? (0.45 + 0.55 * edgeFade) : 0.3
                                            anchors.verticalCenter: parent.verticalCenter
                                            antialiasing: true

                                            height: root.isPlaying
                                                    ? Math.max(4, Math.min(22, Math.round((4 + Math.abs(Math.sin(index * 0.55 + root.visualizerPhase)) * 12 + Math.abs(Math.cos(index * 0.32 - root.visualizerPhase * 0.8)) * 6) * edgeFade)))
                                                    : 4

                                            Behavior on height {
                                                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                                            }
                                            Behavior on opacity {
                                                NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.smoothEasing }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                spacing: 10

                                Text {
                                    text: formatTime(root.trackPosition)
                                    font.family: root.fontFamily
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 16

                                    property real progressRatio: root.trackLength > 0 ? Math.max(0, Math.min(1, root.trackPosition / root.trackLength)) : 0

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: seekMouse.containsMouse ? 7 : 5
                                        radius: height / 2
                                        color: Qt.rgba(255, 255, 255, 0.14)
                                        antialiasing: true

                                        Behavior on height {
                                            NumberAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing }
                                        }

                                        Rectangle {
                                            width: parent.width * parent.parent.progressRatio
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.themePrimary
                                            antialiasing: true

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: seekMouse.pressed ? 0 : animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: seekMouse.containsMouse ? 13 : 0
                                        height: width
                                        radius: width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(parent.width - width, parent.progressRatio * parent.width - width / 2))
                                        color: "#FFFFFF"
                                        border.width: 2
                                        border.color: root.themePrimary
                                        antialiasing: true
                                        visible: width > 0

                                        Behavior on width {
                                            NumberAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing }
                                        }
                                    }

                                    MouseArea {
                                        id: seekMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.trackLength > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onPressed: (mouse) => root.seekToFraction(mouse.x / width)
                                        onPositionChanged: (mouse) => {
                                            if (pressed) root.seekToFraction(mouse.x / width)
                                        }
                                    }
                                }

                                Text {
                                    text: formatTime(root.trackLength)
                                    font.family: root.fontFamily
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 14

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: volDownBtn
                            property bool isMinVol: root.currentVolume <= 0

                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: isMinVol ? Qt.alpha("#ef4444", 0.25) : (volDownMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(0, 0, 0, 0.42))
                            border.width: 1
                            border.color: isMinVol ? "#ef4444" : (volDownMouse.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.12))
                            antialiasing: true
                            scale: volDownMouse.pressed ? 0.92 : (volDownMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }
                            Behavior on border.color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }

                            Text {
                                anchors.centerIn: parent
                                text: parent.isMinVol ? "󰖁" : "󰕿"
                                font.family: root.iconFontFamily
                                font.pixelSize: 16
                                color: parent.isMinVol ? "#ef4444" : (volDownMouse.containsMouse ? root.themePrimary : root.themeText)
                            }

                            MouseArea {
                                id: volDownMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.adjustVolume("-5%")
                            }
                        }

                        Rectangle {
                            id: prevBtn
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: prevMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(0, 0, 0, 0.42)
                            border.width: 1
                            border.color: prevMouse.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.12)
                            antialiasing: true
                            scale: prevMouse.pressed ? 0.92 : (prevMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }
                            Behavior on border.color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family: root.iconFontFamily
                                color: prevMouse.containsMouse ? root.themePrimary : root.themeText
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl" + root.getPlayerArg() + " previous")
                            }
                        }

                        Rectangle {
                            id: playBtn
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            radius: 25
                            color: playMouse.containsMouse ? Qt.lighter(root.themePrimary, 1.1) : root.themePrimary
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.35)
                            antialiasing: true
                            scale: playMouse.pressed ? 0.93 : (playMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "󰏤" : "󰐊"
                                font.family: root.iconFontFamily
                                color: "#000000"
                                font.pixelSize: 22
                                anchors.horizontalCenterOffset: root.isPlaying ? 0 : 1
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl" + root.getPlayerArg() + " play-pause")
                            }
                        }

                        Rectangle {
                            id: nextBtn
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: nextMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(0, 0, 0, 0.42)
                            border.width: 1
                            border.color: nextMouse.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.12)
                            antialiasing: true
                            scale: nextMouse.pressed ? 0.92 : (nextMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }
                            Behavior on border.color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family: root.iconFontFamily
                                color: nextMouse.containsMouse ? root.themePrimary : root.themeText
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl" + root.getPlayerArg() + " next")
                            }
                        }

                        Rectangle {
                            id: volUpBtn
                            property bool isMaxVol: root.currentVolume >= 100

                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: isMaxVol ? Qt.alpha("#ef4444", 0.25) : (volUpMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(0, 0, 0, 0.42))
                            border.width: 1
                            border.color: isMaxVol ? "#ef4444" : (volUpMouse.containsMouse ? root.themePrimary : Qt.rgba(255, 255, 255, 0.12))
                            antialiasing: true
                            scale: volUpMouse.pressed ? 0.92 : (volUpMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }
                            Behavior on border.color { ColorAnimation { duration: animStyle.microDuration; easing.type: animStyle.smoothEasing } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰕾"
                                font.family: root.iconFontFamily
                                font.pixelSize: 16
                                color: parent.isMaxVol ? "#ef4444" : (volUpMouse.containsMouse ? root.themePrimary : root.themeText)
                            }

                            MouseArea {
                                id: volUpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.adjustVolume("+5%")
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}