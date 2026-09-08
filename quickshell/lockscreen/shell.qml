import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam

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
            onStreamFinished: {
                let res = text.trim()
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
import subprocess, os

def get_wallpaper():
    try:
        out = subprocess.check_output("swww query 2>/dev/null", shell=True, text=True)
        for line in out.splitlines():
            for chunk in line.split():
                clean = chunk.strip(",'\\"")
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

print(get_wallpaper())
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
            Item {
                anchors.fill: parent

                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }

                MultiEffect {
                    anchors.fill: parent
                    source: bgWallpaper
                    blurEnabled: true
                    blur: 0.5
                    blurMax: 32
                    brightness: -0.05
                    saturation: 0.1
                    visible: bgWallpaper.status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.themeBackground
                    visible: bgWallpaper.status !== Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.55
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20

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

                    Item { Layout.preferredHeight: 8 }

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