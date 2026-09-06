import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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
    property int brightnessPct: 0
    property bool showOSD: false
    property string osdTargetMonitor: ""

    // Smooth animated value for real-time fluid transitions
    property real animatedBrightness: 0
    Behavior on animatedBrightness { 
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
    }

    property int lastBrightness: -1

    // ============================================================
    // ACTIVE MONITOR DETECTOR (TRACKS CURSOR / FOCUS SCREEN)
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
        colorFile.reload()
        generalFile.reload()
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
    // LAPTOP BRIGHTNESS POLLING
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
                    let newBri = data.bri

                    if (root.lastBrightness !== -1 && newBri !== root.lastBrightness) {
                        // Lock OSD to current active monitor when triggered
                        if (!root.showOSD) {
                            root.osdTargetMonitor = root.activeMonitorName
                        }
                        root.showOSD = true
                        autoHideTimer.restart()
                    }

                    root.lastBrightness = newBri
                    root.brightnessPct = newBri
                    root.animatedBrightness = newBri
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let py = `
import subprocess, json

def cmd(c):
    try: return subprocess.check_output(c, shell=True, text=True, timeout=0.2).strip()
    except: return ""

bri = 0
try:
    bri_out = cmd("brightnessctl -m 2>/dev/null")
    if bri_out:
        bri = min(100, max(0, int(bri_out.split(',')[3].replace('%', ''))))
    else:
        cur = int(cmd("brightnessctl get"))
        max_b = int(cmd("brightnessctl max"))
        bri = min(100, max(0, int((cur / max_b) * 100)))
except: pass

print(json.dumps({"bri": bri}))
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

            property string screenName: win.screen ? win.screen.name : ""
            property bool isTargetMonitor: win.screenName === root.osdTargetMonitor || (root.osdTargetMonitor === "" && win.screenName === root.activeMonitorName)

            visible: isTargetMonitor && (root.showOSD || osdContainer.opacity > 0)

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-brightness-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            // Fixed positioning: Right edge, vertically centered, 10px margin
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

                opacity: (root.showOSD && win.isTargetMonitor) ? 1.0 : 0.0
                scale: (root.showOSD && win.isTargetMonitor) ? 1.0 : 0.95
                enabled: root.showOSD && win.isTargetMonitor

                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                // ============================================================
                // MOUSE CLICK & WHEEL ACTIONS
                // ============================================================
                MouseArea {
                    id: mainArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            root.exec("brightnessctl set 0%")
                        }
                    }

                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            root.exec("brightnessctl set +2%")
                        } else if (wheel.angleDelta.y < 0) {
                            root.exec("brightnessctl set 2%-")
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

                    // Brightness Icon Indicator
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Text {
                            anchors.centerIn: parent
                            text: root.brightnessPct > 66 ? "󰃠" : (root.brightnessPct > 33 ? "󰃟" : "󰃞")
                            color: root.themePrimary
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
                                height: parent.height * (Math.min(100, root.animatedBrightness) / 100)
                                anchors.bottom: parent.bottom
                                radius: parent.radius
                                color: root.themePrimary
                            }
                        }
                    }

                    // Smooth Percentage Text
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(Math.min(100, root.animatedBrightness)) + "%"
                        color: root.themeText
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}