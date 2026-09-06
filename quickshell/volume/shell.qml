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
    // ADAPTIVE THEME PROPERTIES (Matched with general.lua)
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 12
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.85
    
    property color themeBackground: Qt.rgba(0.08, 0.08, 0.09, themeBgAlpha) 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    // ============================================================
    // OSD STATE PROPERTIES
    // ============================================================
    property int volumePct: 0
    property bool isMuted: false
    property bool showOSD: false
    property string lockedMon: ""

    // Lock screen display to initial focused monitor on trigger (prevents cursor tracking)
    onShowOSDChanged: {
        if (showOSD && Hyprland.focusedMonitor) {
            lockedMon = Hyprland.focusedMonitor.name
        }
    }

    // Smooth animated value for real-time fluid transitions
    property real animatedVolume: 0
    Behavior on animatedVolume { 
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
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
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let match = this.text().match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) { 
                    root.themeBorder = "#" + match[1]
                    root.themePrimary = "#" + match[1] 
                }
            } catch (e) {}
        }
    }

    FileView {
        id: generalFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let textContent = this.text()
                let roundingMatch = textContent.match(/rounding\s*=\s*(\d+)/)
                if (roundingMatch && roundingMatch[1]) {
                    root.themeRounding = parseInt(roundingMatch[1])
                }
                let opacityMatch = textContent.match(/active_opacity\s*=\s*([0-9.]+)/)
                if (opacityMatch && opacityMatch[1]) {
                    root.themeBgAlpha = parseFloat(opacityMatch[1])
                }
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        colorFile.reload();
        generalFile.reload();
    }

    // ============================================================
    // COMMAND EXECUTION
    // ============================================================
    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false;
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    // ============================================================
    // LIGHTWEIGHT STATE POLLING & AUTO-SHOW TRIGGER
    // ============================================================
    Timer {
        id: autoHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.showOSD = false
    }

    Process {
        id: stateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    let newVol = data.vol
                    let newMute = data.muted

                    if (root.lastVolume !== -1 && (newVol !== root.lastVolume || newMute !== root.lastMute)) {
                        root.showOSD = true
                        autoHideTimer.restart()
                    }

                    root.lastVolume = newVol
                    root.lastMute = newMute
                    root.volumePct = newVol
                    root.animatedVolume = newVol
                    root.isMuted = newMute
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let py = `
import subprocess, json
try:
    res = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=0.2)
    out = res.stdout
    muted = "MUTED" in out
    vol = 0
    for p in out.split():
        if "." in p:
            vol = min(100, max(0, int(float(p) * 100)))
            break
except:
    vol, muted = 0, False
print(json.dumps({"vol": vol, "muted": muted}))
`
            stateProcess.command = ["python3", "-c", py]
            stateProcess.running = true
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

            // Lock screen display to initial trigger monitor (No active cursor tracking)
            property bool isTargetMonitor: {
                if (root.lockedMon !== "") {
                    return modelData.name === root.lockedMon
                }
                return Hyprland.focusedMonitor ? (modelData.name === Hyprland.focusedMonitor.name) : true
            }

            // Controls layer surface visibility to allow Hyprland blur
            visible: (root.showOSD || osdContainer.opacity > 0) && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-volume-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            // Fixed positioning: Right side, vertically centered by default, 30px edge distance
            anchors { right: true }
            margins { right: 10 }

            implicitWidth: 72
            implicitHeight: 220
            color: "transparent"

            Rectangle {
                id: osdContainer
                anchors.fill: parent

                radius: root.themeRounding
                color: root.themeBackground
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.45)
                clip: true

                opacity: root.showOSD ? 1.0 : 0.0
                scale: root.showOSD ? 1.0 : 0.95
                enabled: root.showOSD

                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                // ============================================================
                // MUTE TOGGLE & SCROLL VOLUME CONTROL
                // ============================================================
                MouseArea {
                    id: mainArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            root.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                        }
                        // Right and Middle clicks perform no action
                    }

                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+")
                        } else if (wheel.angleDelta.y < 0) {
                            root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-")
                        }
                    }
                }

                // Hover keeps OSD alive
                HoverHandler {
                    id: hoverHandler
                    onHoveredChanged: {
                        if (hovered) {
                            autoHideTimer.stop()
                        } else if (root.showOSD) {
                            autoHideTimer.restart()
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Speaker Icon
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

                    // Vertical Slider Track (Display-only)
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

                    // Smooth Percentage Text
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