import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

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

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"

    property int themeRounding: 16
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08)

    property int volumePct: 0
    property bool isMuted: false
    property bool osdActive: false
    property bool osdShown: false
    property bool osdVisible: osdActive && osdShown
    property string lockedMon: ""

    function clipRoundedRect(ctx, x, y, w, h, r) {
        r = Math.min(r, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y, x + w, y + r, r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x, y + h, x, y + h - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
        ctx.clip()
    }

    function openOSD() {
        if (!root.osdActive) {
            root.osdShown = false
            root.osdActive = true
            enterTriggerTimer.restart()
        } else {
            root.osdShown = true
        }
        autoHideTimer.restart()
    }

    function closeOSD() {
        enterTriggerTimer.stop()
        autoHideTimer.stop()
        root.osdActive = false
        root.osdShown = false
    }

    Timer {
        id: enterTriggerTimer
        interval: 16
        repeat: false
        onTriggered: root.osdShown = true
    }

    Timer {
        id: autoHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.closeOSD()
    }

    Component.onCompleted: {
        root.updateAudioState()
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.lockedMon = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.lockedMon = Quickshell.screens[0].name
        }
        colorFile.reload()
        generalFile.reload()
        animConfigFile.reload()
    }

    property real animatedVolume: 0
    Behavior on animatedVolume {
        NumberAnimation {
            duration: (root.animEnabled && root.osdActive) ? animStyle.morphDuration : 0
            easing.type: animStyle.expoEasing
        }
    }

    property int lastVolume: -1
    property bool lastMute: false

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let borderMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (borderMatch && borderMatch[1]) {
                    root.themeBorder = "#" + borderMatch[1]
                    root.themePrimary = "#" + borderMatch[1]
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
                let textContent = text()
                let roundingMatch = textContent.match(/rounding\s*=\s*(\d+)/)
                if (roundingMatch && roundingMatch[1]) root.themeRounding = parseInt(roundingMatch[1])
                let bMatch = textContent.match(/border_size\s*=\s*(\d+)/)
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

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    function updateAudioState() {
        fetchStateProcess.running = true
    }

    Process {
        id: fetchStateProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (!out) return

                let muted = out.indexOf("MUTED") !== -1
                let vol = 0
                let parts = out.split(/\s+/)
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i].indexOf(".") !== -1) {
                        vol = Math.min(100, Math.max(0, Math.round(parseFloat(parts[i]) * 100)))
                        break
                    }
                }

                if (root.lastVolume !== -1 && (vol !== root.lastVolume || muted !== root.lastMute)) {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                        root.lockedMon = Hyprland.focusedMonitor.name
                    } else if (Quickshell.screens.length > 0) {
                        root.lockedMon = Quickshell.screens[0].name
                    }
                    root.openOSD()
                }

                root.lastVolume = vol
                root.lastMute = muted
                root.volumePct = vol
                root.animatedVolume = vol
                root.isMuted = muted
            }
        }
    }

    Process {
        id: pipewireEvents
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("sink") !== -1) {
                    root.updateAudioState()
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: {
                let target = root.lockedMon
                let activeScreen = Quickshell.screens.find(s => s.name === target)
                if (!activeScreen) {
                    target = Hyprland.focusedMonitor?.name ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
                }
                return modelData.name === target
            }

            visible: root.osdActive && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-volume-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { right: true }

            implicitWidth: 92
            implicitHeight: 268
            color: "transparent"

            Rectangle {
                id: osdContainer
                width: 60
                height: 236
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                radius: root.themeRounding
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                border.width: root.themeBorderSize
                border.color: root.isMuted
                              ? Qt.rgba(1.0, 0.27, 0.23, 0.55)
                              : (mainArea.containsMouse ? Qt.alpha(root.themePrimary, 0.65) : Qt.alpha(root.themePrimary, 0.40))
                antialiasing: true
                clip: true

                opacity: root.osdVisible ? 1.0 : 0.0
                scale: root.osdVisible
                       ? (mainArea.pressed ? 0.96 : (mainArea.containsMouse ? 1.025 : 1.0))
                       : 0.92
                enabled: root.osdVisible

                transform: Translate {
                    x: root.osdVisible ? 0 : 18
                    Behavior on x {
                        NumberAnimation {
                            duration: (root.animEnabled && root.osdVisible) ? animStyle.enterDuration : 0
                            easing.type: animStyle.expoEasing
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: (root.animEnabled && root.osdVisible) ? animStyle.scaleDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                MouseArea {
                    id: mainArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: {
                        autoHideTimer.stop()
                    }

                    onExited: {
                        if (root.osdActive) {
                            autoHideTimer.restart()
                        }
                    }

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            root.isMuted = !root.isMuted
                            root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                            autoHideTimer.restart()
                        }
                    }

                    onWheel: (wheel) => {
                        let delta = wheel.angleDelta.y > 0 ? 2 : -2
                        root.volumePct = Math.max(0, Math.min(100, root.volumePct + delta))
                        root.animatedVolume = root.volumePct
                        root.exec(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${Math.abs(delta)}%${delta > 0 ? "+" : "-"}`)
                        autoHideTimer.restart()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: mainArea.containsMouse ? 12 : 10
                        color: Qt.alpha(root.isMuted ? "#FF453A" : root.themePrimary, mainArea.containsMouse ? 0.24 : 0.18)
                        border.width: 1
                        border.color: Qt.alpha(root.isMuted ? "#FF453A" : root.themePrimary, mainArea.containsMouse ? 0.52 : 0.35)
                        antialiasing: true
                        scale: root.isMuted ? 0.94 : (mainArea.containsMouse ? 1.06 : 1.0)

                        Behavior on scale {
                            NumberAnimation {
                                duration: (root.animEnabled && root.osdVisible) ? animStyle.scaleDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }
                        Behavior on radius {
                            NumberAnimation {
                                duration: (root.animEnabled && root.osdVisible) ? animStyle.microDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        Text {
                            id: iconText
                            anchors.centerIn: parent
                            text: root.isMuted ? "󰖁" : (root.volumePct > 50 ? "󰕾" : (root.volumePct > 0 ? "󰖀" : "󰝟"))
                            color: root.isMuted ? "#FF453A" : root.themePrimary
                            font.pixelSize: 19
                            font.family: root.iconFontFamily
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.65)

                            Behavior on color {
                                ColorAnimation {
                                    duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: mainArea.containsMouse ? 10 : 8
                        Layout.alignment: Qt.AlignHCenter

                        Behavior on Layout.preferredWidth {
                            NumberAnimation {
                                duration: (root.animEnabled && root.osdVisible) ? animStyle.microDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        Rectangle {
                            id: volTrough
                            anchors.fill: parent
                            radius: width / 2
                            color: root.themeSurface
                            border.width: 1
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                            antialiasing: true

                            Behavior on color {
                                ColorAnimation {
                                    duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            Canvas {
                                id: fillCanvas
                                anchors.fill: parent
                                antialiasing: true

                                property real fillRatio: root.isMuted ? 0 : Math.max(0, Math.min(100, root.animatedVolume)) / 100
                                property color fillColor: root.isMuted ? "#FF453A" : root.themePrimary

                                Behavior on fillColor {
                                    ColorAnimation {
                                        duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                onFillRatioChanged: requestPaint()
                                onFillColorChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onAvailableChanged: if (available) requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    if (fillRatio <= 0 || width <= 0 || height <= 0) return
                                    ctx.save()
                                    root.clipRoundedRect(ctx, 0, 0, width, height, width / 2)
                                    var fh = height * fillRatio
                                    ctx.fillStyle = fillColor
                                    ctx.fillRect(0, height - fh, width, fh)
                                    ctx.restore()
                                }
                            }
                        }
                    }

                    Text {
                        id: labelText
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.isMuted ? "Mute" : Math.round(Math.min(100, root.animatedVolume)) + "%"
                        color: root.isMuted ? "#FF453A" : root.themeText
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.family: root.fontFamily
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.75)

                        Behavior on color {
                            ColorAnimation {
                                duration: (root.animEnabled && root.osdVisible) ? animStyle.fadeDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }
                    }
                }
            }
        }
    }
}