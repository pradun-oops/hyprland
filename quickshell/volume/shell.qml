import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 0.1
    }

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 12
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    property int volumePct: 0
    property bool isMuted: false
    property bool showOSD: false
    property string lockedMon: ""

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
            duration: root.animEnabled ? animStyle.animDuration : 0
            easing.type: animStyle.fadeEasing 
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

    Timer {
        id: autoHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.showOSD = false
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
                    root.showOSD = true
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                        root.lockedMon = Hyprland.focusedMonitor.name
                    } else if (Quickshell.screens.length > 0) {
                        root.lockedMon = Quickshell.screens[0].name
                    }
                    autoHideTimer.restart()
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
                let target = root.lockedMon;
                let activeScreen = Quickshell.screens.find(s => s.name === target);
                if (!activeScreen) {
                    target = Hyprland.focusedMonitor?.name ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
                }
                return modelData.name === target;
            }

            // Immediately unmap surface on close to vanish blur without delay
            visible: root.showOSD && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-volume-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { right: true }
            margins { right: 12 }

            implicitWidth: 72
            implicitHeight: 220
            color: "transparent"

            Rectangle {
                id: osdContainer
                anchors.fill: parent

                radius: root.themeRounding
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.45)
                
                // Enables smooth GPU layer scaling to eliminate sub-pixel border stroke misalignment during bounce animations
                layer.enabled: root.animEnabled
                layer.smooth: true

                opacity: root.showOSD ? 1.0 : 0.0
                scale: root.showOSD ? 1.0 : 0.1
                enabled: root.showOSD

                transform: Translate {
                    x: root.showOSD ? 0 : 16
                    Behavior on x { 
                        NumberAnimation { 
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        } 
                    }
                }

                Behavior on opacity { 
                    NumberAnimation { 
                        duration: animStyle.fadeDuration
                        easing.type: animStyle.fadeEasing 
                    } 
                }
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
                Behavior on border.color { 
                    ColorAnimation { 
                        duration: animStyle.fadeDuration
                        easing.type: animStyle.fadeEasing 
                    } 
                }

                MouseArea {
                    id: mainArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            root.isMuted = !root.isMuted
                            root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                        }
                    }

                    onWheel: (wheel) => {
                        let delta = wheel.angleDelta.y > 0 ? 2 : -2
                        root.volumePct = Math.max(0, Math.min(100, root.volumePct + delta))
                        root.animatedVolume = root.volumePct
                        root.exec(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${Math.abs(delta)}%${delta > 0 ? "+" : "-"}`)
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) autoHideTimer.stop()
                        else if (root.showOSD) autoHideTimer.restart()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        
                        Text {
                            id: iconText
                            anchors.centerIn: parent
                            text: root.isMuted ? "󰖁" : (root.volumePct > 50 ? "󰕾" : (root.volumePct > 0 ? "󰖀" : "󰝟"))
                            color: root.isMuted ? "#FF453A" : root.themePrimary
                            font.pixelSize: 22

                            scale: root.isMuted ? 0.92 : (mainArea.containsMouse ? 1.08 : 1.0)

                            Behavior on color { 
                                ColorAnimation { 
                                    duration: animStyle.fadeDuration
                                    easing.type: animStyle.fadeEasing 
                                } 
                            }
                            Behavior on scale { 
                                NumberAnimation { 
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                } 
                            }
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 10
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: root.themeSurface

                            Behavior on color { 
                                ColorAnimation { 
                                    duration: animStyle.fadeDuration
                                    easing.type: animStyle.fadeEasing 
                                } 
                            }

                            Rectangle {
                                id: fillBar
                                width: parent.width
                                height: parent.height * (root.isMuted ? 0 : Math.min(100, root.animatedVolume) / 100)
                                anchors.bottom: parent.bottom
                                radius: parent.radius
                                color: root.isMuted ? "#FF453A" : root.themePrimary

                                Behavior on color { 
                                    ColorAnimation { 
                                        duration: animStyle.fadeDuration
                                        easing.type: animStyle.fadeEasing 
                                    } 
                                }
                            }
                        }
                    }

                    Text {
                        id: labelText
                        Layout.alignment: Qt.AlignHCenter
                        text: root.isMuted ? "Mute" : Math.round(Math.min(100, root.animatedVolume)) + "%"
                        color: root.isMuted ? "#FF453A" : root.themeText
                        font.pixelSize: 12
                        font.weight: Font.Bold

                        Behavior on color { 
                            ColorAnimation { 
                                duration: animStyle.fadeDuration
                                easing.type: animStyle.fadeEasing 
                            } 
                        }
                    }
                }
            }
        }
    }
}