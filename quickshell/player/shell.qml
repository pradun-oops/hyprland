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
    property color themeTextMuted: "#C5C5C5"
    property color themeOnPrimary: "#000000"
    
    property int themeRounding: 16
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.85
    
    property color themeBackground: Qt.rgba(0.05, 0.05, 0.06, themeBgAlpha) 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.06) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.12)

    property string mediaTitle: "No media playing"
    property string mediaArtist: "Unknown Artist"
    property string mediaAlbum: "Unknown Album"
    property string mediaArtUrl: ""
    property string playerName: "firefox"
    property string mediaStatus: "Stopped"
    property bool isPlaying: false
    property bool hasActivePlayer: false
    property real trackPosition: 0
    property real trackLength: 0

    // Desktop Widget Position
    property int windowX: 100
    property int windowY: 420

    FileView {
        id: posFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/player_pos.json"
        onLoaded: {
            try {
                let d = JSON.parse(text())
                if (d.x !== undefined) root.windowX = d.x
                if (d.y !== undefined) root.windowY = d.y
            } catch(e) {}
        }
    }

    Process { id: savePosProcess }
    function saveWindowPos() {
        let jsonStr = JSON.stringify({ x: root.windowX, y: root.windowY })
        savePosProcess.command = ["bash", "-c", "mkdir -p ~/.config/quickshell/json && echo '" + jsonStr + "' > ~/.config/quickshell/json/player_pos.json"]
        savePosProcess.running = true
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let content = this.text()
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) {
                    let hex = "#" + match[1]
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
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let content = this.text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
                
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])

                let blurMatch = content.match(/blur\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
                if (blurMatch && blurMatch[1]) {
                    root.themeBgAlpha = (blurMatch[1] === "true") ? 0.65 : 0.95
                }
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        colorFile.reload();
        generalConfigFile.reload();
        posFile.reload();
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

    Process {
        id: mediaStateProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split('\n')
                    let data = JSON.parse(lines[lines.length - 1])
                    
                    root.mediaTitle = data.title || "No media playing"
                    root.mediaArtist = data.artist || "Unknown Artist"
                    root.mediaAlbum = data.album || "Unknown Album"
                    root.mediaArtUrl = data.artUrl || ""
                    root.playerName = data.playerName || "firefox"
                    root.mediaStatus = data.status || "Stopped"
                    root.isPlaying = data.status.toLowerCase() === "playing"
                    root.hasActivePlayer = data.active === true
                    root.trackPosition = data.position || 0
                    root.trackLength = data.length || 0
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let py = `
import subprocess, json
def cmd(c):
    try: return subprocess.check_output(c, shell=True, text=True).strip()
    except: return ""

players_raw = cmd("playerctl -l 2>/dev/null")
players = [p.strip() for p in players_raw.splitlines() if p.strip()]
active_player = ""

# 1. Priority: Find a player that is currently PLAYING
for p in players:
    st = cmd(f"playerctl -p {p} status 2>/dev/null")
    if st.lower() == "playing":
        active_player = p
        break

# 2. Secondary Priority: Find a player that is PAUSED
if not active_player:
    for p in players:
        st = cmd(f"playerctl -p {p} status 2>/dev/null")
        if st.lower() == "paused":
            active_player = p
            break

# 3. Fallback: Take the first available player
if not active_player and players:
    active_player = players[0]

title = "No media playing"
artist = "Unknown Artist"
album = ""
art_url = ""
status = "Stopped"
position = 0.0
length = 0.0

if active_player:
    title = cmd(f"playerctl -p {active_player} metadata xesam:title 2>/dev/null") or "No media playing"
    artist = cmd(f"playerctl -p {active_player} metadata xesam:artist 2>/dev/null") or "Unknown Artist"
    album = cmd(f"playerctl -p {active_player} metadata xesam:album 2>/dev/null") or ""
    art_url = cmd(f"playerctl -p {active_player} metadata mpris:artUrl 2>/dev/null") or ""
    status = cmd(f"playerctl -p {active_player} status 2>/dev/null") or "Stopped"
    
    try:
        pos_str = cmd(f"playerctl -p {active_player} position 2>/dev/null")
        if pos_str: position = float(pos_str)
    except: pass

    try:
        len_str = cmd(f"playerctl -p {active_player} metadata mpris:length 2>/dev/null")
        if len_str:
            length = float(len_str) / 1000000.0
        else:
            dur_str = cmd(f"playerctl -p {active_player} metadata xesam:duration 2>/dev/null")
            if dur_str:
                length = float(dur_str) / 1000000.0
    except: pass

active = bool(title != "No media playing" and status.lower() in ["playing", "paused"])

print(json.dumps({
    "title": title,
    "artist": artist,
    "album": album,
    "artUrl": art_url,
    "playerName": active_player or "firefox",
    "status": status,
    "position": position,
    "length": length,
    "active": active
}))
`
            mediaStateProcess.command = ["python3", "-c", py]
            mediaStateProcess.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: playerWidget
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "dms:desktop-widget:player"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true; left: true }
            margins {
                top: root.windowY
                left: root.windowX
            }

            implicitWidth: 440
            implicitHeight: 200
            color: "transparent"

            Rectangle {
                id: mainContainer
                anchors.fill: parent
                radius: root.themeRounding
                color: root.themeBackground
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.3)
                clip: true

                // Beautiful Soft Background Glow
                RadialGradient {
                    width: parent.width * 1.5
                    height: parent.height * 1.5
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: -width * 0.25
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(root.themePrimary, 0.25) }
                        GradientStop { position: 0.5; color: "transparent" }
                    }
                }

                // Global Desktop Widget Dragging (Handles all clicks now)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.OpenHandCursor
                    z: 5

                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false

                    onPressed: (mouse) => {
                        startX = mouse.x
                        startY = mouse.y
                        isDragging = true
                        cursorShape = Qt.ClosedHandCursor
                    }
                    onPositionChanged: (mouse) => {
                        if (isDragging) {
                            root.windowX += (mouse.x - startX)
                            root.windowY += (mouse.y - startY)
                        }
                    }
                    onReleased: {
                        isDragging = false
                        cursorShape = Qt.OpenHandCursor
                        root.saveWindowPos()
                    }
                }

                // Bottom Bouncing Audio Visualizer Wave
                Row {
                    id: bottomWave
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 8
                    spacing: 5
                    z: 1
                    opacity: root.isPlaying ? 0.6 : 0.1

                    Repeater {
                        model: 32
                        Rectangle {
                            width: 6
                            height: 12
                            radius: 3
                            color: Qt.alpha(root.themePrimary, 0.8)

                            transform: [
                                Scale {
                                    id: barScale
                                    origin.x: 3
                                    origin.y: 6
                                    yScale: 1.0
                                }
                            ]

                            SequentialAnimation {
                                running: root.isPlaying
                                loops: Animation.Infinite

                                NumberAnimation {
                                    target: barScale
                                    property: "yScale"
                                    to: 1.8 + ((index * 0.05) % 0.8)
                                    duration: 180 + (index * 20)
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    target: barScale
                                    property: "yScale"
                                    to: 0.4
                                    duration: 220 + (index * 15)
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 24
                    z: 2

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 20

                        // Top Row: Circular Album Art + Track Meta
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20

                            Rectangle {
                                Layout.preferredWidth: 84
                                Layout.preferredHeight: 84
                                radius: 42
                                color: root.themeSurface
                                border.width: 1
                                border.color: Qt.alpha(root.themeText, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    color: root.themePrimary
                                    font.pixelSize: 36
                                    visible: artImage.status !== Image.Ready
                                    opacity: 0.8
                                }

                                Image {
                                    id: artImage
                                    anchors.fill: parent
                                    source: root.mediaArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                }

                                Rectangle {
                                    id: artMask
                                    anchors.fill: parent
                                    radius: 42
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: artImage
                                    maskSource: artMask
                                    visible: artImage.status === Image.Ready
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: root.mediaTitle
                                    color: root.themeText
                                    font.pixelSize: 18
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
                                    opacity: 0.9
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.mediaAlbum !== "" ? root.mediaAlbum : "Digital Stream"
                                    color: root.themeTextMuted
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    opacity: 0.6
                                }
                            }
                        }

                        // Middle: Progress Bar & Timestamps
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item {
                                Layout.fillWidth: true
                                height: 18

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.1) // Better contrast for track background

                                    Rectangle {
                                        id: progressFill
                                        // Fixed seekbar logic to strictly respect track lengths and percentages
                                        width: root.trackLength > 0 ? parent.width * Math.max(0, Math.min(1, root.trackPosition / root.trackLength)) : 0
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.themePrimary

                                        Behavior on width {
                                            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                                        }
                                    }
                                    
                                    DropShadow {
                                        anchors.fill: progressFill
                                        source: progressFill
                                        color: root.themePrimary
                                        transparentBorder: true
                                        radius: 16
                                        samples: 25
                                        opacity: 0.5
                                    }
                                }
                                // Removed the interior MouseArea so the global drag controller always triggers on click
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: formatTime(root.trackPosition)
                                    color: root.themeTextMuted
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    opacity: 0.8
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: formatTime(root.trackLength)
                                    color: root.themeTextMuted
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    opacity: 0.8
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}