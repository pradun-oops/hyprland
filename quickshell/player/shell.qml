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

    property var audioSinks: []
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

    Component.onCompleted: {
        colorFile.reload()
        generalConfigFile.reload()
        posConfigFile.reload()
        audioPollProcess.running = true
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

    function switchAudioSink() {
        if (!root.audioSinks || root.audioSinks.length <= 1) return;
        let currIdx = root.audioSinks.findIndex(d => d.is_def);
        let nextIdx = (currIdx + 1) % root.audioSinks.length;
        let nextDev = root.audioSinks[nextIdx];
        exec("pactl set-default-sink " + nextDev.name + " && notify-send -a 'Audio Switcher' 'Output Changed' '" + nextDev.desc + "'");
        audioPollProcess.running = true;
    }

    function adjustVolume(percent) {
        exec("pactl set-sink-volume @DEFAULT_SINK@ " + percent)
        audioPollTimer.restart()
    }

    Timer {
        id: audioPollTimer
        interval: 100
        repeat: false
        onTriggered: audioPollProcess.running = true
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
                    root.mediaAlbum = data.album || ""
                    
                    let art = data.artUrl || ""
                    if (art.startsWith("file://") || art.startsWith("http://") || art.startsWith("https://")) {
                        root.mediaArtUrl = art
                    } else if (art.length > 0) {
                        root.mediaArtUrl = "file://" + art
                    } else {
                        root.mediaArtUrl = ""
                    }
                    
                    root.playerName = data.playerName || ""
                    root.activePlayerList = data.allPlayers || []
                    root.mediaStatus = data.status || "Stopped"
                    root.isPlaying = data.status.toLowerCase() === "playing"
                    root.trackPosition = data.position || 0
                    root.trackLength = data.length || 0
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            let py = `
import subprocess, json
def cmd(c):
    try: return subprocess.check_output(c, shell=True, text=True).strip()
    except: return ""

players = [p.strip() for p in cmd("playerctl -l 2>/dev/null").splitlines() if p.strip()]
active_player = ""

for p in players:
    if cmd(f"playerctl -p {p} status 2>/dev/null").lower() == "playing":
        active_player = p; break
if not active_player:
    for p in players:
        if cmd(f"playerctl -p {p} status 2>/dev/null").lower() == "paused":
            active_player = p; break
if not active_player and players: active_player = players[0]

title = "No media playing"
artist, album, art_url, status = "Unknown Artist", "", "", "Stopped"
position, length = 0.0, 0.0

if active_player:
    title = cmd(f"playerctl -p {active_player} metadata xesam:title 2>/dev/null") or "No media playing"
    artist = cmd(f"playerctl -p {active_player} metadata xesam:artist 2>/dev/null") or "Unknown Artist"
    album = cmd(f"playerctl -p {active_player} metadata xesam:album 2>/dev/null") or ""
    art_url = cmd(f"playerctl -p {active_player} metadata mpris:artUrl 2>/dev/null") or ""
    status = cmd(f"playerctl -p {active_player} status 2>/dev/null") or "Stopped"
    
    try:
        pos_str = cmd(f"playerctl -p {active_player} position 2>/dev/null")
        if pos_str: position = float(pos_str)
        len_str = cmd(f"playerctl -p {active_player} metadata mpris:length 2>/dev/null")
        length = float(len_str)/1000000.0 if len_str else float(cmd(f"playerctl -p {active_player} metadata xesam:duration 2>/dev/null") or 0) / 1000000.0
    except: pass

print(json.dumps({
    "title": title, 
    "artist": artist, 
    "album": album, 
    "artUrl": art_url, 
    "playerName": active_player, 
    "allPlayers": players,
    "status": status, 
    "position": position, 
    "length": length
}))
`
            mediaStateProcess.command = ["python3", "-c", py]
            mediaStateProcess.running = true
        }
    }

    Process {
        id: audioPollProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(text.trim())
                    root.audioSinks = d.sinks || []
                    if (d.volume !== undefined) root.currentVolume = d.volume
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true
        onTriggered: {
            let py = `
import subprocess, json, re
def get_list(typ):
    try:
        default = subprocess.check_output(f"pactl get-default-{typ}", shell=True, text=True).strip()
        lines = subprocess.check_output(f"pactl list {typ}s", shell=True, text=True).splitlines()
        res = []
        cur_name = ""
        for l in lines:
            if "Name:" in l: cur_name = l.split("Name:")[1].strip()
            elif "Description:" in l:
                desc = l.split("Description:")[1].strip()
                res.append({"name": cur_name, "desc": desc, "is_def": cur_name == default})
        return res
    except: return []

def get_vol():
    try:
        out = subprocess.check_output("pactl get-sink-volume @DEFAULT_SINK@", shell=True, text=True)
        m = re.search(r'(\d+)%', out)
        return int(m.group(1)) if m else 50
    except: return 50

print(json.dumps({"sinks": get_list("sink"), "volume": get_vol()}))
`
            audioPollProcess.command = ["python3", "-c", py]
            audioPollProcess.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: playerWindow
            required property var modelData
            screen: modelData

            visible: root.mediaStatus.toLowerCase() !== "stopped" && root.mediaTitle !== "No media playing" && modelData !== null

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "dms:desktop-widget:player"
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
                anchors.fill: parent

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
                    Behavior on color { ColorAnimation { duration: 300 } }
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
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36
                            radius: 18
                            color: playerMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.3) : Qt.alpha(root.themeText, 0.12)
                            border.width: 1; border.color: Qt.alpha(root.themePrimary, 0.4)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 14 }

                            MouseArea {
                                id: playerMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchMediaPlayer()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36
                            radius: 18
                            color: sinkMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.3) : Qt.alpha(root.themeText, 0.12)
                            border.width: 1; border.color: Qt.alpha(root.themePrimary, 0.4)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text { anchors.centerIn: parent; text: "🔊"; font.pixelSize: 14 }

                            MouseArea {
                                id: sinkMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchAudioSink()
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
                                        id: barLeft
                                        width: 2.5
                                        radius: 1.25
                                        color: root.themePrimary
                                        anchors.bottom: parent.bottom

                                        property real targetHeight: 4
                                        height: root.isPlaying ? targetHeight : 4

                                        Behavior on height {
                                            NumberAnimation { duration: 110; easing.type: Easing.InOutQuad }
                                        }

                                        Timer {
                                            interval: 60 + ((index % 7) * 25)
                                            running: root.isPlaying
                                            repeat: true
                                            triggeredOnStart: true
                                            onTriggered: {
                                                barLeft.targetHeight = Math.floor(Math.random() * 18) + 4
                                            }
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
                                        id: barRight
                                        width: 2.5
                                        radius: 1.25
                                        color: root.themePrimary
                                        anchors.bottom: parent.bottom

                                        property real targetHeight: 4
                                        height: root.isPlaying ? targetHeight : 4

                                        Behavior on height {
                                            NumberAnimation { duration: 110; easing.type: Easing.InOutQuad }
                                        }

                                        Timer {
                                            interval: 70 + (((19 - index) % 7) * 25)
                                            running: root.isPlaying
                                            repeat: true
                                            triggeredOnStart: true
                                            onTriggered: {
                                                barRight.targetHeight = Math.floor(Math.random() * 18) + 4
                                            }
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
                                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
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
                            property bool isMinVol: root.currentVolume <= 0

                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: isMinVol ? Qt.alpha("#ef4444", 0.3) : (volDownMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : Qt.alpha(root.themeText, 0.08))
                            border.width: isMinVol ? 1 : 0
                            border.color: "#ef4444"
                            Behavior on color { ColorAnimation { duration: 150 } }

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
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: prevMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text { anchors.centerIn: parent; text: "⏮"; color: root.themeText; font.pixelSize: 20 }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl " + root.getPlayerArg() + " previous")
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 52; Layout.preferredHeight: 52
                            radius: 26
                            color: playMouse.containsMouse ? Qt.darker(root.themePrimary, 1.15) : root.themePrimary
                            Behavior on color { ColorAnimation { duration: 150 } }

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
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: nextMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text { anchors.centerIn: parent; text: "⏭"; color: root.themeText; font.pixelSize: 20 }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.exec("playerctl " + root.getPlayerArg() + " next")
                            }
                        }

                        Rectangle {
                            property bool isMaxVol: root.currentVolume >= 100

                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 19
                            color: isMaxVol ? Qt.alpha("#ef4444", 0.3) : (volUpMouse.containsMouse ? Qt.alpha(root.themeText, 0.18) : Qt.alpha(root.themeText, 0.08))
                            border.width: isMaxVol ? 1 : 0
                            border.color: "#ef4444"
                            Behavior on color { ColorAnimation { duration: 150 } }

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