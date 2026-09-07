import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // ============================================================
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 12
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.7
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    // ============================================================
    // OSD STATE PROPERTIES
    // ============================================================
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
    }

    property real animatedVolume: 0
    Behavior on animatedVolume { 
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic } 
    }

    property int lastVolume: -1
    property bool lastMute: false

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

    // ============================================================
    // COMMAND EXECUTION
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    // ============================================================
    // EVENT-DRIVEN AUDIO STATE MONITORING
    // ============================================================
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
                    // Capture the monitor where the cursor/focus is right when the OSD triggers
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

    // ============================================================
    // WAYLAND UI OSD DIALOG
    // ============================================================
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // Dynamic lookup with fallback logic: if lockedMon is invalid/disconnected, fallback gracefully
            property bool isTargetMonitor: {
                let target = root.lockedMon;
                let activeScreen = Quickshell.screens.find(s => s.name === target);
                if (!activeScreen) {
                    target = Hyprland.focusedMonitor?.name ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
                }
                return modelData.name === target;
            }

            visible: (root.showOSD || osdContainer.opacity > 0) && isTargetMonitor

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
                clip: true

                opacity: root.showOSD ? 1.0 : 0.0
                scale: root.showOSD ? 1.0 : 0.95
                enabled: root.showOSD

                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

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
                            anchors.centerIn: parent
                            text: root.isMuted ? "󰖁" : (root.volumePct > 50 ? "󰕾" : (root.volumePct > 0 ? "󰖀" : "󰝟"))
                            color: root.isMuted ? "#FF453A" : root.themePrimary
                            font.pixelSize: 22
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 8
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: root.themeSurface

                            Rectangle {
                                width: parent.width
                                height: parent.height * (root.isMuted ? 0 : Math.min(100, root.animatedVolume) / 100)
                                anchors.bottom: parent.bottom
                                radius: parent.radius
                                color: root.isMuted ? "#FF453A" : root.themePrimary
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.isMuted ? "Mute" : Math.round(Math.min(100, root.animatedVolume)) + "%"
                        color: root.themeText
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}