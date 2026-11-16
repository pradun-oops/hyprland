import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property bool authVisible: false
    property bool unlocking: false
    property string activeScreenName: ""

    property string passwordInput: ""
    property string pendingPassword: ""
    property string authStatus: ""
    property color authStatusColor: "#ff6b6b"
    property bool showPassword: false
    property bool isAuthenticating: false

    property string userName: Quickshell.env("USER") || "user"
    property string userDisplayName: Quickshell.env("USER") || "User"
    property string greetingText: "Welcome Back"
    property real shakeOffset: 0
    property string wallpaperPath: ""

    property string hourText: "00"
    property string minuteText: "00"
    property string ampmText: "AM"
    property string dateText: ""

    property color themeBorder: "#a2d398"
    property color themePrimary: "#a2d398"
    property color themeBackground: "#141416"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeOnPrimary: "#141416"
    property int themeRounding: 20
    property int themeBorderSize: 2

    readonly property var activePlayer: {
        if (!Mpris || !Mpris.players) return null
        let list = Mpris.players.values || []
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    function openAuth(screenName, initialChar) {
        if (screenName && screenName !== "") {
            root.activeScreenName = screenName
        }
        if (!root.authVisible) {
            root.authVisible = true
            root.authStatus = ""
        }
        if (initialChar && initialChar.length > 0) {
            root.passwordInput += initialChar
        }
        idleResetTimer.restart()
    }

    function closeAuth() {
        if (root.isAuthenticating || root.unlocking) return
        root.authVisible = false
        root.passwordInput = ""
        root.pendingPassword = ""
        root.authStatus = ""
        root.showPassword = false
        idleResetTimer.stop()
    }

    Timer {
        id: idleResetTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (root.authVisible && !root.isAuthenticating && !root.unlocking && root.passwordInput.length === 0) {
                root.closeAuth()
            }
        }
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date()
            let h = now.getHours()
            let m = now.getMinutes()
            let h12 = h % 12
            if (h12 === 0) h12 = 12
            root.hourText = (h12 < 10 ? "0" : "") + h12
            root.minuteText = (m < 10 ? "0" : "") + m
            root.ampmText = h >= 12 ? "PM" : "AM"
            root.dateText = Qt.formatDateTime(now, "dddd, MMMM d")
            let drift = 1000 - now.getMilliseconds()
            interval = drift > 40 ? drift : 1000
        }
    }

    FileView {
        id: cachedWpFile
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
        id: colorFile
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
        id: generalFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = Math.max(14, parseInt(rMatch[1]))
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = Math.max(2, parseInt(bMatch[1]))
            } catch (e) {}
        }
    }

    Process {
        id: userInfoProcess
        command: [
            "bash", "-c",
            "NAME=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); [ -z \"$NAME\" ] && NAME=\"$USER\"; printf '%s\\n' \"$NAME\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = text.trim()
                if (name !== "") {
                    root.userDisplayName = name
                }
                let hr = (new Date()).getHours()
                let timeGreeting = hr < 12 ? "Good Morning" : (hr < 18 ? "Good Afternoon" : "Good Evening")
                let greetings = [
                    timeGreeting + ", " + root.userDisplayName,
                    "Welcome back, " + root.userDisplayName,
                    "Ready when you are, " + root.userDisplayName
                ]
                root.greetingText = greetings[Math.floor(Math.random() * greetings.length)]
            }
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
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.activeScreenName = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.activeScreenName = Quickshell.screens[0].name
        }

        cachedWpFile.reload()
        colorFile.reload()
        generalFile.reload()
        userInfoProcess.running = true

        let pyScript = `
import subprocess, os

def get_wallpaper():
    for cmd in ["awww query", "swww query"]:
        try:
            out = subprocess.check_output(cmd, shell=True, text=True)
            cleaned_out = out.replace(":", " ")
            for chunk in cleaned_out.split():
                clean = chunk.strip("',\\" ")
                if clean.startswith("/") and os.path.isfile(clean):
                    return clean
        except Exception:
            pass

    try:
        out = subprocess.check_output("hyprctl hyprpaper listactive 2>/dev/null", shell=True, text=True)
        for line in out.splitlines():
            if "=" in line:
                p = line.split("=")[1].strip()
                if os.path.isfile(p): return p
            elif "/" in line and os.path.isfile(line.strip()):
                return line.strip()
    except Exception:
        pass

    try:
        wp_cfg = os.path.expanduser("~/.config/waypaper/config.ini")
        if os.path.isfile(wp_cfg):
            with open(wp_cfg, "r") as f:
                for line in f:
                    if line.startswith("wallpaper"):
                        p = line.split("=")[1].strip().replace("~", os.path.expanduser("~"))
                        if os.path.isfile(p): return p
    except Exception:
        pass

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
    except Exception:
        pass

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

    Timer {
        id: unlockFinishTimer
        interval: 120
        repeat: false
        onTriggered: {
            sessionLock.locked = false
            Qt.quit()
        }
    }

    function attemptAuth() {
        let pwd = root.passwordInput
        if (!pwd || pwd.length === 0 || root.isAuthenticating || root.unlocking) return
        root.isAuthenticating = true
        root.pendingPassword = pwd
        root.authStatus = "Verifying..."
        root.authStatusColor = root.themePrimary

        if (pam.active) {
            pam.abort()
        }

        let success = pam.start()
        if (!success) {
            root.isAuthenticating = false
            root.authStatus = "Authentication service unavailable"
            root.authStatusColor = "#ff6b6b"
            shakeAnimation.start()
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            id: lockSurface
            color: root.themeBackground

            readonly property bool isPrimary: {
                if (root.activeScreenName !== "") {
                    return lockSurface.screen && lockSurface.screen.name === root.activeScreenName
                }
                return lockSurface.screen === Quickshell.screens[0]
            }

            Item {
                id: surfaceRoot
                anchors.fill: parent
                focus: lockSurface.isPrimary

                Component.onCompleted: {
                    if (lockSurface.isPrimary) {
                        surfaceRoot.forceActiveFocus()
                    }
                }

                Connections {
                    target: root
                    function onAuthVisibleChanged() {
                        if (lockSurface.isPrimary) {
                            if (root.authVisible) {
                                focusDelayTimer.restart()
                            } else {
                                surfaceRoot.forceActiveFocus()
                            }
                        }
                    }
                }

                Timer {
                    id: focusDelayTimer
                    interval: 30
                    repeat: false
                    onTriggered: {
                        if (lockSurface.isPrimary && root.authVisible) {
                            passwordField.forceActiveFocus()
                        }
                    }
                }

                Keys.onPressed: (event) => {
                    if (root.unlocking) return
                    if (event.key === Qt.Key_Escape) {
                        if (root.authVisible) {
                            root.closeAuth()
                        }
                        event.accepted = true
                        return
                    }
                    if (!root.authVisible) {
                        let isModifierOnly = (
                            event.key === Qt.Key_Shift ||
                            event.key === Qt.Key_Control ||
                            event.key === Qt.Key_Alt ||
                            event.key === Qt.Key_Meta ||
                            event.key === Qt.Key_CapsLock ||
                            event.key === Qt.Key_NumLock ||
                            event.key === Qt.Key_Super_L ||
                            event.key === Qt.Key_Super_R
                        )
                        if (!isModifierOnly) {
                            let ch = (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) ? event.text : ""
                            root.openAuth(lockSurface.screen ? lockSurface.screen.name : "", ch)
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.themeBackground
                }

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
                        blur: root.authVisible ? 0.85 : 0.20
                        blurMax: 36
                        brightness: root.authVisible ? -0.06 : 0.0
                        saturation: 0.12

                        Behavior on blur {
                            NumberAnimation {
                                duration: 340
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on brightness {
                            NumberAnimation {
                                duration: 340
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: root.authVisible ? 0.48 : 0.22

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 340
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        if (!root.authVisible) {
                            root.openAuth(lockSurface.screen ? lockSurface.screen.name : "", "")
                        } else if (lockSurface.isPrimary) {
                            passwordField.forceActiveFocus()
                            idleResetTimer.restart()
                        } else {
                            root.openAuth(lockSurface.screen ? lockSurface.screen.name : "", "")
                        }
                    }
                }

                Item {
                    id: clockBlock
                    visible: lockSurface.isPrimary
                    width: clockColumn.implicitWidth
                    height: clockColumn.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.authVisible ? Math.max(36, parent.height * 0.06) : Math.max(40, (parent.height - height) * 0.34)
                    scale: root.authVisible ? 0.36 : 1.0
                    opacity: root.unlocking ? 0.0 : 1.0
                    transformOrigin: Item.Top

                    Behavior on y {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        id: clockColumn
                        anchors.centerIn: parent
                        spacing: -14

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.dateText
                            color: Qt.alpha(root.themePrimary, 0.92)
                            font.family: root.fontFamily
                            font.pixelSize: 32
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.38)
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 0

                            Text {
                                text: root.hourText
                                color: Qt.alpha(root.themeText, 0.94)
                                font.family: root.fontFamily
                                font.pixelSize: 224
                                font.weight: Font.Bold
                                font.letterSpacing: -6
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.32)
                            }

                            Text {
                                text: ":"
                                color: Qt.alpha(root.themePrimary, 0.92)
                                font.family: root.fontFamily
                                font.pixelSize: 224
                                font.weight: Font.Bold
                                font.letterSpacing: -6
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.32)
                            }

                            Text {
                                text: root.minuteText
                                color: Qt.alpha(root.themeText, 0.94)
                                font.family: root.fontFamily
                                font.pixelSize: 224
                                font.weight: Font.Bold
                                font.letterSpacing: -6
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.32)
                            }

                            Text {
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 44
                                Layout.leftMargin: 14
                                text: root.ampmText
                                color: Qt.alpha(root.themePrimary, 0.92)
                                font.family: root.fontFamily
                                font.pixelSize: 34
                                font.weight: Font.Bold
                                font.letterSpacing: 1.6
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.38)
                            }
                        }
                    }
                }

                Item {
                    id: authSection
                    visible: lockSurface.isPrimary
                    enabled: lockSurface.isPrimary && root.authVisible && !root.unlocking
                    width: 360
                    height: authLayout.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.shakeOffset
                    y: root.authVisible ? (parent.height * 0.48 - height * 0.38) : (parent.height * 0.48 - height * 0.38 + 26)
                    opacity: (root.authVisible && !root.unlocking) ? 1.0 : 0.0

                    Behavior on y {
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.unlocking ? 110 : 280
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        id: authLayout
                        anchors.fill: parent
                        spacing: 14

                        ClippingRectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 96
                            height: 96
                            radius: 48
                            color: Qt.alpha(root.themeBackground, 0.65)
                            border.color: root.themePrimary
                            border.width: root.themeBorderSize

                            Text {
                                anchors.centerIn: parent
                                text: root.userDisplayName.charAt(0).toUpperCase()
                                color: root.themePrimary
                                font.family: root.fontFamily
                                font.pixelSize: 38
                                font.weight: Font.Bold
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
                                        let home = Quickshell.env("HOME")
                                        let u = Quickshell.env("USER") || "user"
                                        if (source.toString() === "file://" + home + "/.face") {
                                            source = "file://" + home + "/.face.icon"
                                        } else if (source.toString() === "file://" + home + "/.face.icon") {
                                            source = "file:///var/lib/AccountsService/icons/" + u
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.userDisplayName
                                color: root.themeText
                                font.family: root.fontFamily
                                font.pixelSize: 21
                                font.weight: Font.Bold
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.greetingText
                                color: root.themePrimary
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                            }
                        }

                        Rectangle {
                            id: passwordBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: Math.max(12, root.themeRounding - 6)
                            color: Qt.alpha(root.themeBackground, 0.70)
                            border.color: root.isAuthenticating
                                          ? root.themePrimary
                                          : (passwordField.activeFocus ? Qt.alpha(root.themePrimary, 0.85) : Qt.alpha(root.themePrimary, 0.35))
                            border.width: root.themeBorderSize
                            antialiasing: true

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "󰌾"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 15
                                    color: passwordField.activeFocus ? root.themePrimary : root.themeTextMuted
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextField {
                                    id: passwordField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    enabled: !root.isAuthenticating && !root.unlocking
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    placeholderText: "Enter password..."
                                    placeholderTextColor: Qt.rgba(1.0, 1.0, 1.0, 0.40)
                                    color: root.themeText
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    selectionColor: Qt.alpha(root.themePrimary, 0.35)
                                    selectedTextColor: root.themeText
                                    verticalAlignment: Text.AlignVCenter
                                    background: Item {}
                                    text: root.passwordInput

                                    onTextEdited: {
                                        root.passwordInput = text
                                        if (root.authStatus !== "" && !root.isAuthenticating) {
                                            root.authStatus = ""
                                        }
                                        idleResetTimer.restart()
                                    }

                                    onAccepted: root.attemptAuth()

                                    Keys.onEscapePressed: {
                                        root.closeAuth()
                                    }
                                }

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 8
                                    color: eyeMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.showPassword ? "󰈈" : "󰈉"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 15
                                        color: eyeMouseArea.containsMouse ? root.themePrimary : root.themeTextMuted
                                    }

                                    MouseArea {
                                        id: eyeMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showPassword = !root.showPassword
                                    }
                                }

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 9
                                    color: root.passwordInput.length > 0
                                           ? (submitMouse.containsMouse ? Qt.lighter(root.themePrimary, 1.08) : root.themePrimary)
                                           : Qt.rgba(1, 1, 1, 0.08)
                                    Layout.alignment: Qt.AlignVCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isAuthenticating ? "󰑮" : "󰁔"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        color: root.passwordInput.length > 0 ? root.themeOnPrimary : root.themeTextMuted

                                        RotationAnimator on rotation {
                                            running: root.isAuthenticating
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                        }
                                    }

                                    MouseArea {
                                        id: submitMouse
                                        anchors.fill: parent
                                        enabled: root.passwordInput.length > 0 && !root.isAuthenticating
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.attemptAuth()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.authStatus
                            color: root.authStatusColor
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            opacity: text.length > 0 ? 1.0 : 0.0
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.7)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: lockSurface.isPrimary
                    opacity: root.unlocking ? 0.0 : 1.0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 44
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: musicCard
                        Layout.alignment: Qt.AlignHCenter
                        width: 360
                        height: 76
                        radius: Math.max(14, root.themeRounding - 2)
                        color: Qt.alpha(root.themeBackground, 0.56)
                        border.color: Qt.alpha(root.themePrimary, 0.38)
                        border.width: 1
                        antialiasing: true
                        visible: root.activePlayer !== null && (root.activePlayer.trackTitle !== "" || root.activePlayer.isPlaying)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            ClippingRectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                radius: 11
                                color: Qt.alpha(root.themePrimary, 0.16)
                                border.color: Qt.alpha(root.themePrimary, 0.35)
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

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝚"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 20
                                    color: root.themePrimary
                                    visible: albumArt.status !== Image.Ready
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: root.activePlayer ? root.activePlayer.trackTitle : ""
                                    color: root.themeText
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.activePlayer && root.activePlayer.trackArtist !== "" ? root.activePlayer.trackArtist : "Unknown Artist"
                                    color: root.themePrimary
                                    opacity: 0.88
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 9
                                    color: prevBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒮"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 14
                                        color: root.themeText
                                    }

                                    MouseArea {
                                        id: prevBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous()
                                    }
                                }

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 10
                                    color: playBtnMouse.containsMouse ? Qt.lighter(root.themePrimary, 1.08) : root.themePrimary

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.activePlayer && root.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 17
                                        color: root.themeOnPrimary
                                    }

                                    MouseArea {
                                        id: playBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
                                    }
                                }

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 9
                                    color: nextBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒭"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 14
                                        color: root.themeText
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

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: hintRow.implicitWidth + 24
                        height: 32
                        radius: 16
                        color: Qt.alpha(root.themeBackground, 0.45)
                        border.width: 1
                        border.color: Qt.alpha(root.themePrimary, 0.30)
                        opacity: root.authVisible ? 0.0 : 1.0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 240
                                easing.type: Easing.OutCubic
                            }
                        }

                        RowLayout {
                            id: hintRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "󰌾"
                                font.family: root.iconFontFamily
                                font.pixelSize: 12
                                color: root.themePrimary
                            }

                            Text {
                                text: "Tap anywhere or press any key to unlock"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.themeTextMuted
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
            root.isAuthenticating = false
            if (result === PamResult.Success) {
                root.authStatus = "Unlocked"
                root.authStatusColor = root.themePrimary
                root.unlocking = true
                unlockFinishTimer.start()
            } else {
                root.passwordInput = ""
                root.pendingPassword = ""
                root.authStatus = "Incorrect password"
                root.authStatusColor = "#ff6b6b"
                shakeAnimation.start()
            }
        }

        onError: (err) => {
            root.isAuthenticating = false
            root.passwordInput = ""
            root.pendingPassword = ""
            root.authStatus = "Authentication error"
            root.authStatusColor = "#ff6b6b"
            shakeAnimation.start()
        }
    }
}