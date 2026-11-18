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

    property int clockFontSize: 300
    property string hourText: "00"
    property string minuteText: "00"
    property string ampmText: "AM"
    property string dateText: ""
    property string weatherIcon: ""
    property string weatherTemp: ""
    property string weatherLat: "23.3441"
    property string weatherLon: "85.3096"

    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeBackground: "#141416"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themeOnPrimary: "#141416"
    property int themeRounding: 20
    property int themeBorderSize: 2

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property color clockDigitColor: mixColor("#FFFFFF", themePrimary, 0.38, 1.0)
    property color clockAccentColor: Qt.lighter(themePrimary, 1.08)
    property color clockOutlineColor: Qt.rgba(0.03, 0.035, 0.05, 0.88)
    property color clockShadowColor: Qt.rgba(0.02, 0.025, 0.04, 0.62)

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

            let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            root.dateText = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()

            let drift = 1000 - now.getMilliseconds()
            interval = drift > 40 ? drift : 1000
        }
    }

    function fetchWeather() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", `https://api.open-meteo.com/v1/forecast?latitude=${root.weatherLat}&longitude=${root.weatherLon}&current=temperature_2m,weather_code&timezone=auto`)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText).current
                    var temp = Math.round(d.temperature_2m)
                    var code = d.weather_code
                    var icon = "󰖙"
                    if (code === 1 || code === 2) icon = "󰖕"
                    else if (code === 3) icon = "󰖐"
                    else if (code >= 45 && code <= 48) icon = "󰖑"
                    else if (code >= 51 && code <= 67) icon = "󰖗"
                    else if (code >= 71 && code <= 77) icon = "󰖘"
                    else if (code >= 95 && code <= 99) icon = "󰙾"
                    root.weatherIcon = icon
                    root.weatherTemp = temp + "°"
                } catch (e) {}
            }
        }
        xhr.send()
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
                let borderMatch = content.match(/active_border\s*=\s*"rgba?\(([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}\)"/) ||
                                  content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}"/) ||
                                  content.match(/(?:primary|accent)\s*=\s*"rgba?\(([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}\)"/) ||
                                  content.match(/(?:primary|accent)\s*=\s*"#([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}"/)
                if (borderMatch && borderMatch[1]) {
                    root.themeBorder = "#" + borderMatch[1]
                    root.themePrimary = "#" + borderMatch[1]
                }
                let bgMatch = content.match(/background\s*=\s*"rgba?\(([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}\)"/) ||
                              content.match(/background\s*=\s*"#([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}"/)
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
        command: [
            "bash", "-c",
            "WP=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1); " +
            "[ -z \"$WP\" ] && WP=$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1); " +
            "[ -z \"$WP\" ] && WP=$(hyprctl hyprpaper listactive 2>/dev/null | awk -F'=' 'NF>1 {gsub(/^ +| +$/,\"\",$2); print $2; exit}'); " +
            "[ -z \"$WP\" ] && [ -f \"$HOME/.config/waypaper/config.ini\" ] && WP=$(awk -F'=' '/^wallpaper/ {gsub(/^ +| +$/,\"\",$2); sub(/^~/, ENVIRON[\"HOME\"], $2); print $2; exit}' \"$HOME/.config/waypaper/config.ini\"); " +
            "if [ -n \"$WP\" ] && [ -f \"$WP\" ]; then mkdir -p \"$HOME/.cache\"; printf '%s' \"$WP\" > \"$HOME/.cache/quickshell_last_wallpaper.txt\"; printf '%s\\n' \"$WP\"; fi"
        ]
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
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.activeScreenName = Hyprland.focusedMonitor.name
        } else if (Quickshell.screens.length > 0) {
            root.activeScreenName = Quickshell.screens[0].name
        }

        cachedWpFile.reload()
        colorFile.reload()
        generalFile.reload()
        userInfoProcess.running = true
        fetchWpProcess.running = true
        root.fetchWeather()
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
                    z: 1
                    visible: lockSurface.isPrimary
                    width: clockColumn.implicitWidth
                    height: clockColumn.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.authVisible ? Math.max(32, parent.height * 0.045) : 100
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
                        spacing: -Math.round(root.clockFontSize * 0.11)

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Text {
                                text: root.dateText
                                color: "#FFFFFF"
                                font.family: root.fontFamily
                                font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.11))
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                style: Text.Outline
                                styleColor: root.clockOutlineColor
                            }

                            Text {
                                visible: root.weatherTemp !== ""
                                text: "•"
                                color: root.clockAccentColor
                                font.family: root.fontFamily
                                font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.11))
                                font.weight: Font.Black
                                style: Text.Outline
                                styleColor: root.clockOutlineColor
                            }

                            RowLayout {
                                visible: root.weatherTemp !== ""
                                spacing: 6

                                Text {
                                    text: root.weatherIcon
                                    color: root.clockAccentColor
                                    font.family: root.iconFontFamily
                                    font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.105))
                                    style: Text.Outline
                                    styleColor: root.clockOutlineColor
                                }

                                Text {
                                    text: root.weatherTemp
                                    color: "#FFFFFF"
                                    font.family: root.fontFamily
                                    font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.11))
                                    font.weight: Font.Bold
                                    style: Text.Outline
                                    styleColor: root.clockOutlineColor
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Item {
                                implicitWidth: hourText.implicitWidth
                                implicitHeight: hourText.implicitHeight

                                Text {
                                    x: 0
                                    y: 7
                                    text: root.hourText
                                    color: root.clockShadowColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.clockFontSize
                                    font.weight: Font.Bold
                                    font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                                }

                                Text {
                                    id: hourText
                                    text: root.hourText
                                    color: root.clockDigitColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.clockFontSize
                                    font.weight: Font.Bold
                                    font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                                    style: Text.Outline
                                    styleColor: root.clockOutlineColor
                                }
                            }

                            Item {
                                implicitWidth: colonText.implicitWidth
                                implicitHeight: colonText.implicitHeight
                                Layout.alignment: Qt.AlignVCenter
                                Layout.bottomMargin: Math.round(root.clockFontSize * 0.08)

                                Text {
                                    x: 0
                                    y: 7
                                    text: ":"
                                    color: root.clockShadowColor
                                    opacity: colonText.opacity
                                    font.family: root.fontFamily
                                    font.pixelSize: Math.round(root.clockFontSize * 0.90)
                                    font.weight: Font.Bold
                                }

                                Text {
                                    id: colonText
                                    text: ":"
                                    color: root.clockAccentColor
                                    font.family: root.fontFamily
                                    font.pixelSize: Math.round(root.clockFontSize * 0.90)
                                    font.weight: Font.Bold
                                    style: Text.Outline
                                    styleColor: root.clockOutlineColor

                                    SequentialAnimation on opacity {
                                        running: true
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.65; duration: 1000; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                                    }
                                }
                            }

                            Item {
                                implicitWidth: minuteText.implicitWidth
                                implicitHeight: minuteText.implicitHeight

                                Text {
                                    x: 0
                                    y: 7
                                    text: root.minuteText
                                    color: root.clockShadowColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.clockFontSize
                                    font.weight: Font.Bold
                                    font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                                }

                                Text {
                                    id: minuteText
                                    text: root.minuteText
                                    color: root.clockDigitColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.clockFontSize
                                    font.weight: Font.Bold
                                    font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                                    style: Text.Outline
                                    styleColor: root.clockOutlineColor
                                }
                            }

                            Item {
                                implicitWidth: periodText.implicitWidth
                                implicitHeight: periodText.implicitHeight
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: Math.round(root.clockFontSize * 0.19)
                                Layout.leftMargin: 6

                                Text {
                                    x: 0
                                    y: 3
                                    text: root.ampmText
                                    color: root.clockShadowColor
                                    font.family: root.fontFamily
                                    font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.12))
                                    font.weight: Font.Black
                                    font.letterSpacing: 1.4
                                }

                                Text {
                                    id: periodText
                                    text: root.ampmText
                                    color: root.clockAccentColor
                                    font.family: root.fontFamily
                                    font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.12))
                                    font.weight: Font.Black
                                    font.letterSpacing: 1.4
                                    style: Text.Outline
                                    styleColor: root.clockOutlineColor
                                }
                            }
                        }
                    }
                }

                Item {
                    id: authSection
                    z: 2
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
                    z: 2
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