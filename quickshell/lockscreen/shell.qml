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

    // Root properties & state management
    property string pendingPassword: ""
    property string authStatus: ""
    property color authStatusColor: "#ff6b6b"
    property bool showPassword: false
    property string greetingText: "Welcome Back"
    property real shakeOffset: 0

    // Dynamic Theme initialized with defaults matching your Lua files
    QtObject {
        id: theme
        property color activeBorder: "#a2d398"
        property color inactiveBorder: "#42493f"
        property real rounding: 15
        property real activeOpacity: 0.85

        function parseColors(content) {
            if (!content) return;
            let activeMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]+)\)"/);
            if (activeMatch) activeBorder = "#" + activeMatch[1];

            let inactiveMatch = content.match(/inactive_border\s*=\s*"rgb\(([a-fA-F0-9]+)\)"/);
            if (inactiveMatch) inactiveBorder = "#" + inactiveMatch[1];
        }

        function parseGeneral(content) {
            if (!content) return;
            let roundingMatch = content.match(/rounding\s*=\s*(\d+)/);
            if (roundingMatch) rounding = parseInt(roundingMatch[1]);

            let opacityMatch = content.match(/active_opacity\s*=\s*([\d.]+)/);
            if (opacityMatch) activeOpacity = parseFloat(opacityMatch[1]);
        }
    }

    // Pick random greeting on startup
    Component.onCompleted: {
        let greetings = [
            "Welcome back, Pradun!",
            "Good to see you again!",
            "Ready to focus?",
            "Hope you're having a great day!",
            "System Locked — Standing By"
        ];
        greetingText = greetings[Math.floor(Math.random() * greetings.length)];
    }

    // Dynamic File Watchers (Live Reloading from your Lua config files)
    FileView {
        path: "/home/pradun/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.parseColors(text())
    }

    FileView {
        path: "/home/pradun/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.parseGeneral(text())
    }

    // Shake animation for failed authentication
    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: root; property: "shakeOffset"; to: -14; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 14; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 10; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -5; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.InOutQuad }
    }

    // Success animation before exiting lockscreen
    ParallelAnimation {
        id: successAnimation
        NumberAnimation { target: cardContainer; property: "scale"; to: 1.08; duration: 280; easing.type: Easing.OutBack }
        NumberAnimation { target: cardContainer; property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutCubic }
        onFinished: root.unlockAndQuit()
    }

    // Actions
    function unlockAndQuit() {
        sessionLock.locked = false
        Qt.quit()
    }

    function attemptAuth(pwd) {
        if (!pwd || pwd.length === 0) return;
        root.pendingPassword = pwd
        root.authStatus = "Authenticating..."
        root.authStatusColor = theme.activeBorder

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

    // Global Emergency Exit Shortcut (Esc Key)
    Shortcut {
        sequences: ["Esc", "Escape"]
        onActivated: root.unlockAndQuit()
    }

    // Wayland Session Lock
    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            Item {
                anchors.fill: parent

                // Background Wallpaper Image
                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: "file:///home/pradun/Pictures/wallpaper.jpg"
                    fillMode: Image.PreserveAspectCrop
                    visible: true

                    onStatusChanged: {
                        if (status === Image.Error) {
                            if (source.toString() === "file:///home/pradun/Pictures/wallpaper.jpg") {
                                source = "file:///home/pradun/Pictures/wallpaper.png"
                            } else if (source.toString() === "file:///home/pradun/Pictures/wallpaper.png") {
                                source = "file:///home/pradun/.config/hypr/wallpaper"
                            }
                        }
                    }
                }

                // Blur Effect applied to Wallpaper
                MultiEffect {
                    anchors.fill: bgWallpaper
                    source: bgWallpaper
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 48
                    brightness: -0.12
                    saturation: 0.15
                }

                // Dark Glass Overlay
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.05, 0.07, 0.08, 0.55)
                }

                // Card Center Container
                Item {
                    id: cardWrapper
                    anchors.centerIn: parent
                    width: 350
                    height: 440

                    Rectangle {
                        id: cardContainer
                        anchors.fill: parent
                        x: root.shakeOffset
                        radius: theme.rounding
                        color: Qt.rgba(0.08, 0.1, 0.09, theme.activeOpacity)
                        border.color: theme.activeBorder
                        border.width: 2

                        Behavior on radius { NumberAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28
                            spacing: 16

                            // Greeting Text Header
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.greetingText
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            // Circular Profile Picture Container
                            ClippingRectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 96
                                height: 96
                                radius: width / 2
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: theme.activeBorder
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "P"
                                    color: theme.activeBorder
                                    font.pixelSize: 40
                                    font.bold: true
                                    visible: userAvatar.status !== Image.Ready
                                }

                                Image {
                                    id: userAvatar
                                    anchors.fill: parent
                                    source: "file:///home/pradun/.face"
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    visible: status === Image.Ready

                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            if (source.toString() === "file:///home/pradun/.face") {
                                                source = "file:///home/pradun/.face.icon"
                                            } else if (source.toString() === "file:///home/pradun/.face.icon") {
                                                source = "file:///var/lib/AccountsService/icons/pradun"
                                            }
                                        }
                                    }
                                }
                            }

                            // Username
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "pradun"
                                color: "#ffffff"
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Item { Layout.preferredHeight: 4 }

                            // Password Input Container
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: theme.rounding
                                color: Qt.rgba(0, 0, 0, 0.45)
                                border.color: passwordField.activeFocus ? theme.activeBorder : theme.inactiveBorder
                                border.width: 2

                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on radius { NumberAnimation { duration: 200 } }

                                TextField {
                                    id: passwordField
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 42
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    placeholderText: "Enter password..."
                                    placeholderTextColor: "#70ffffff"
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    verticalAlignment: Text.AlignVCenter
                                    focus: true
                                    background: null

                                    onAccepted: root.attemptAuth(passwordField.text)

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            root.unlockAndQuit()
                                            event.accepted = true
                                        }
                                    }
                                }

                                // Password Eye Show/Hide Toggle
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
                                        color: eyeMouseArea.containsMouse ? theme.activeBorder : "#90ffffff"

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

                            // Status Feedback Message
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.authStatus
                                color: root.authStatusColor
                                font.pixelSize: 12
                                opacity: text.length > 0 ? 1 : 0

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }
        }
    }

    // System PAM Authentication Context
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
                root.authStatusColor = theme.activeBorder
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