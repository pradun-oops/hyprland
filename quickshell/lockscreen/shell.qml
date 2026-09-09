import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property string pendingPassword: ""
    property string authStatus: ""
    property color authStatusColor: "#ff6b6b"
    property bool showPassword: false
    property string greetingText: "Welcome Back"
    property real shakeOffset: 0
    property string wallpaperPath: ""

    property string timeText: ""
    property string dateText: ""

    property color themeBorder: "#a2d398"
    property color themePrimary: "#a2d398"
    property color themeBackground: "#141416"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property int themeRounding: 16
    property int themeBorderSize: 2

    // MPRIS Active Media Player Selection
    readonly property var activePlayer: {
        if (!Mpris || !Mpris.players) return null
        let list = Mpris.players.values || []
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date()
            root.timeText = Qt.formatDateTime(now, "hh:mm A")
            root.dateText = Qt.formatDateTime(now, "dddd, MMMM d")
        }
    }

    // Fast initial wallpaper load from cache
    FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell_last_wallpaper.txt"
        watchChanges: false
        onLoaded: {
            try {
                let cached = text().trim()
                if (cached && cached.length > 0 && root.wallpaperPath === "") {
                    root.wallpaperPath = cached
                }
            } catch (e) {}
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let borderMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
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

    Process {
        id: fetchWpProcess
        stdout: StdioCollector {
            id: wpCollector
            onStreamFinished: {
                let res = wpCollector.text.trim()
                if (res && res.length > 0) {
                    root.wallpaperPath = res
                }
            }
        }
    }

    Component.onCompleted: {
        let greetings = [
            "Welcome back, Pradun!",
            "Good to see you again!",
            "Ready to focus?",
            "Hope you're having a great day!",
            "System Locked — Standing By"
        ];
        greetingText = greetings[Math.floor(Math.random() * greetings.length)];

        let pyScript = `
import subprocess, os, glob

def get_wallpaper():
    for cmd in ["awww query", "swww query"]:
        try:
            out = subprocess.check_output(cmd, shell=True, text=True)
            cleaned_out = out.replace(":", " ")
            for chunk in cleaned_out.split():
                clean = chunk.strip("',\\" ")
                if clean.startswith("/") and os.path.isfile(clean):
                    return clean
        except Exception: pass

    try:
        out = subprocess.check_output("hyprctl hyprpaper listactive 2>/dev/null", shell=True, text=True)
        for line in out.splitlines():
            if "=" in line:
                p = line.split("=")[1].strip()
                if os.path.isfile(p): return p
            elif "/" in line and os.path.isfile(line.strip()):
                return line.strip()
    except Exception: pass

    try:
        wp_cfg = os.path.expanduser("~/.config/waypaper/config.ini")
        if os.path.isfile(wp_cfg):
            with open(wp_cfg, "r") as f:
                for line in f:
                    if line.startswith("wallpaper"):
                        p = line.split("=")[1].strip().replace("~", os.path.expanduser("~"))
                        if os.path.isfile(p): return p
    except Exception: pass

    home = os.path.expanduser("~")
    for p in [
        os.path.join(home, ".cache", "current_wallpaper"),
        os.path.join(home, ".config", "hypr", "wallpaper"),
        os.path.join(home, "Pictures", "wallpaper.jpg"),
        os.path.join(home, "Pictures", "wallpaper.png")
    ]:
        if os.path.exists(p):
            real_p = os.path.realpath(p)
            if os.path.isfile(real_p): return real_p

    return ""

wp = get_wallpaper()
if wp:
    try:
        cache_file = os.path.expanduser("~/.cache/quickshell_last_wallpaper.txt")
        os.makedirs(os.path.dirname(cache_file), exist_ok=True)
        with open(cache_file, "w") as f:
            f.write(wp)
    except Exception: pass

print(wp)
`
        fetchWpProcess.command = ["python3", "-c", pyScript]
        fetchWpProcess.running = true
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: root; property: "shakeOffset"; to: -14; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 14; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 10; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -5; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.InOutQuad }
    }

    ParallelAnimation {
        id: successAnimation
        NumberAnimation { target: authSection; property: "scale"; to: 1.08; duration: 280; easing.type: Easing.OutBack }
        NumberAnimation { target: authSection; property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutCubic }
        onFinished: root.unlockAndQuit()
    }

    function unlockAndQuit() {
        sessionLock.locked = false
        Qt.quit()
    }

    function attemptAuth(pwd) {
        if (!pwd || pwd.length === 0) return;
        root.pendingPassword = pwd
        root.authStatus = "Authenticating..."
        root.authStatusColor = root.themeBorder

        if (pam.active) {
            pam.abort()
        }

        let success = pam.start()
        if (!success) {
            root.authStatus = "PAM failed to start"
            root.authStatusColor = "#ff6b6b"
            shakeAnimation.start()
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            id: lockSurface

            // Check if current screen is the Primary screen
            readonly property bool isPrimary: lockSurface.screen === Quickshell.screens[0]

            Item {
                anchors.fill: parent

                // 1. Solid Fallback Background (Displayed on ALL Monitors)
                Rectangle {
                    anchors.fill: parent
                    color: root.themeBackground
                }

                // 2. Blurred Desktop Wallpaper Image (Displayed on ALL Monitors)
                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: root.wallpaperPath !== "" ? (root.wallpaperPath.startsWith("file://") ? root.wallpaperPath : "file://" + root.wallpaperPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.8
                        blurMax: 32
                        brightness: -0.05
                        saturation: 0.1
                    }
                }

                // 3. Dark Overlay for Readability (Displayed on ALL Monitors)
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.45
                }

                // 4. Lock Screen Interface (ONLY Displayed on Primary Monitor)
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 18
                    visible: lockSurface.isPrimary
                    enabled: lockSurface.isPrimary

                    // Date & Time
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.timeText
                            color: root.themeText
                            font.pixelSize: 76
                            font.bold: true
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.4)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.dateText
                            color: root.themeBorder
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.4)
                        }
                    }

                    Item { Layout.preferredHeight: 4 }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.greetingText
                        color: Qt.alpha(root.themeText, 0.9)
                        font.pixelSize: 22
                        font.weight: Font.Medium
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }

                    Item {
                        id: authSection
                        Layout.alignment: Qt.AlignHCenter
                        width: 320
                        implicitHeight: authLayout.implicitHeight
                        x: root.shakeOffset

                        ColumnLayout {
                            id: authLayout
                            anchors.fill: parent
                            spacing: 16

                            ClippingRectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 96
                                height: 96
                                radius: width / 2
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: root.themeBorder
                                border.width: root.themeBorderSize

                                Text {
                                    anchors.centerIn: parent
                                    text: "P"
                                    color: root.themeBorder
                                    font.pixelSize: 40
                                    font.bold: true
                                    visible: userAvatar.status !== Image.Ready
                                }

                                Image {
                                    id: userAvatar
                                    anchors.fill: parent
                                    source: "file://" + Quickshell.env("HOME") + "/.face"
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    visible: status === Image.Ready

                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            let home = Quickshell.env("HOME");
                                            if (source.toString() === "file://" + home + "/.face") {
                                                source = "file://" + home + "/.face.icon"
                                            } else if (source.toString() === "file://" + home + "/.face.icon") {
                                                source = "file:///var/lib/AccountsService/icons/pradun"
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "pradun"
                                color: root.themeText
                                font.pixelSize: 22
                                font.bold: true
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.4)
                            }

                            Item { Layout.preferredHeight: 2 }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: Math.max(8, root.themeRounding - 6)
                                color: Qt.rgba(0, 0, 0, 0.5)
                                border.color: passwordField.activeFocus ? root.themeBorder : Qt.alpha(root.themeBorder, 0.3)
                                border.width: root.themeBorderSize

                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on radius { NumberAnimation { duration: 200 } }

                                TextField {
                                    id: passwordField
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 42
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    placeholderText: "Enter password..."
                                    placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.7)
                                    color: root.themeText
                                    font.pixelSize: 14
                                    verticalAlignment: Text.AlignVCenter
                                    focus: true
                                    background: null

                                    onAccepted: root.attemptAuth(passwordField.text)
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.showPassword ? "👁" : "🔒"
                                        font.pixelSize: 15
                                        color: eyeMouseArea.containsMouse ? root.themeBorder : Qt.alpha(root.themeText, 0.6)

                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: eyeMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showPassword = !root.showPassword
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.authStatus
                                color: root.authStatusColor
                                font.pixelSize: 12
                                opacity: text.length > 0 ? 1 : 0
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.4)

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }

                    // Modern Redesigned Music Player Widget
                    Rectangle {
                        id: musicCard
                        Layout.alignment: Qt.AlignHCenter
                        width: 320
                        height: 72
                        radius: root.themeRounding
                        color: Qt.rgba(0, 0, 0, 0.45)
                        border.color: Qt.alpha(root.themeBorder, 0.25)
                        border.width: 1
                        visible: root.activePlayer !== null && (root.activePlayer.trackTitle !== "" || root.activePlayer.isPlaying)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            // Album Art Container
                            ClippingRectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                radius: Math.max(6, root.themeRounding - 6)
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1

                                Image {
                                    id: albumArt
                                    anchors.fill: parent
                                    source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    visible: albumArt.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🎵"
                                        font.pixelSize: 22
                                        opacity: 0.8
                                    }
                                }
                            }

                            // Track Info Details
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: root.activePlayer ? root.activePlayer.trackTitle : ""
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.activePlayer ? root.activePlayer.trackArtist : "Unknown Artist"
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Normal
                                    elide: Text.ElideRight
                                }
                            }

                            // Interactive Playback Controls
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4

                                // Previous Button
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: prevBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "⏮"
                                        font.pixelSize: 12
                                        color: prevBtnMouse.containsMouse ? root.themeBorder : Qt.alpha(root.themeText, 0.85)
                                    }

                                    MouseArea {
                                        id: prevBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous()
                                    }
                                }

                                // Play / Pause Pill Button
                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: Qt.alpha(root.themeBorder, playBtnMouse.containsMouse ? 0.35 : 0.2)
                                    border.color: Qt.alpha(root.themeBorder, 0.5)
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: (root.activePlayer && root.activePlayer.isPlaying) ? 0 : 1
                                        text: (root.activePlayer && root.activePlayer.isPlaying) ? "⏸" : "▶"
                                        font.pixelSize: 13
                                        color: root.themeText
                                    }

                                    MouseArea {
                                        id: playBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
                                    }
                                }

                                // Next Button
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: nextBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "⏭"
                                        font.pixelSize: 12
                                        color: nextBtnMouse.containsMouse ? root.themeBorder : Qt.alpha(root.themeText, 0.85)
                                    }

                                    MouseArea {
                                        id: nextBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PamContext {
        id: pam
        config: "login"

        onResponseRequiredChanged: {
            if (responseRequired) {
                pam.respond(root.pendingPassword)
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                root.authStatus = "Success"
                root.authStatusColor = root.themeBorder
                successAnimation.start()
            } else {
                root.pendingPassword = ""
                passwordField.text = ""
                root.authStatus = "Authentication failed"
                root.authStatusColor = "#ff6b6b"
                shakeAnimation.start()
            }
        }

        onError: (err) => {
            root.pendingPassword = ""
            passwordField.text = ""
            root.authStatus = "Authentication error"
            root.authStatusColor = "#ff6b6b"
            shakeAnimation.start()
        }
    }
}