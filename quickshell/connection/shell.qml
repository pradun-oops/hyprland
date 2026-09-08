import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    property string targetMonitorName: ""

    function updateTargetMonitor() {
        if (root.targetMonitorName !== "") return

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            root.targetMonitorName = Hyprland.focusedMonitor.name
        }
    }

    Timer {
        id: fallbackMonitorTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.targetMonitorName === "" && Quickshell.screens.length > 0) {
                root.targetMonitorName = Quickshell.screens[0].name
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.updateTargetMonitor()
        }
    }

    property color themeBorder: "#ff4b6e"
    property color themePrimary: "#ff4b6e"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 22
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.7
    property bool animEnabled: true
    property int animDuration: 220
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.07) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.12)

    property string expandedSsid: ""
    property string connectingSsid: ""
    property string errorSsid: ""
    property string connectErrorMsg: ""

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) { 
                    root.themeBorder = "#" + match[1]
                    root.themePrimary = "#" + match[1] 
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

    FileView {
        id: animConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/animations.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 100
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        fetchNetworkStatus()
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    property bool wifiEnabled: false
    property bool ethEnabled: false
    property bool ethConnected: false
    property string ethDev: ""
    property bool isScanning: false

    ListModel { id: wifiModel }

    Process {
        id: netFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    root.wifiEnabled = data.wifi_enabled
                    root.ethEnabled = data.eth_enabled
                    root.ethConnected = data.eth_connected
                    root.ethDev = data.eth_dev
                    
                    wifiModel.clear()
                    for (let i = 0; i < data.networks.length; i++) {
                        wifiModel.append(data.networks[i])
                    }
                } catch(e) {}
                root.isScanning = false
            }
        }
    }

    function fetchNetworkStatus() {
        root.isScanning = true
        let pyScript = `import subprocess, json
def get_net():
    wifi_on = False
    eth_on = False
    eth_conn = False
    eth_dev = ""
    networks = []
    saved_conns = set()

    try:
        r = subprocess.check_output(["nmcli", "radio", "wifi"], text=True).strip()
        wifi_on = (r == "enabled")
    except: pass

    try:
        c_out = subprocess.check_output(["nmcli", "-t", "-f", "NAME", "connection", "show"], text=True, errors="ignore").strip().split('\\n')
        saved_conns = set(line.strip() for line in c_out if line.strip())
    except: pass

    try:
        devs = subprocess.check_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev"], text=True).strip().split('\\n')
        for d in devs:
            parts = d.split(':')
            if len(parts) >= 3 and parts[1] == 'ethernet':
                eth_dev = parts[0]
                state = parts[2].lower()
                if state in ['connected', 'connecting']:
                    eth_conn = True
                    eth_on = True
                else:
                    eth_conn = False
                    eth_on = False
    except: pass

    if wifi_on:
        try:
            ap_out = subprocess.check_output(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"], text=True, errors="ignore").strip().split('\\n')
            seen = set()
            for line in ap_out:
                if not line: continue
                parts = line.replace('\\\\:', '___COLON___').split(':')
                parts = [p.replace('___COLON___', ':') for p in parts]
                if len(parts) >= 4:
                    in_use = (parts[0] == '*')
                    ssid = parts[1].strip()
                    if not ssid: continue
                    signal = int(parts[2]) if parts[2].isdigit() else 0
                    sec = parts[3].strip()
                    
                    if ssid not in seen or in_use:
                        seen.add(ssid)
                        networks.append({
                            "ssid": ssid,
                            "signal": signal,
                            "security": sec if sec else "Open",
                            "in_use": in_use,
                            "saved": ssid in saved_conns
                        })
            networks.sort(key=lambda x: (not x["in_use"], not x["saved"], -x["signal"]))
        except: pass

    return {
        "wifi_enabled": wifi_on,
        "eth_enabled": eth_on,
        "eth_connected": eth_conn,
        "eth_dev": eth_dev,
        "networks": networks
    }

print(json.dumps(get_net()))
`
        netFetcher.command = ["python3", "-c", pyScript]
        netFetcher.running = true
    }

    Process {
        id: wifiConnectProcess
        property string targetSsid: ""
        stdout: StdioCollector { id: connectStdout }
        stderr: StdioCollector { id: connectStderr }
        
        onExited: (code, exitStatus) => {
            let errText = connectStderr.text.trim()
            let outText = connectStdout.text.trim()
            let rawMsg = errText ? errText : outText

            if (code === 0) {
                root.connectErrorMsg = ""
                root.errorSsid = ""
                root.connectingSsid = ""
                root.expandedSsid = ""
                fetchNetworkStatus()
            } else {
                root.connectingSsid = ""
                root.errorSsid = targetSsid
                root.expandedSsid = targetSsid
                
                let cleaned = rawMsg.replace(/^Error:\s*/i, "").replace(/^Failed to add\/activate connection:\s*/i, "").split('\n')[0]
                root.connectErrorMsg = cleaned ? cleaned : "Connection Failed"
            }
        }
    }

    function connectWifi(ssid, password, isSaved) {
        root.connectingSsid = ssid
        root.connectErrorMsg = ""
        root.errorSsid = ""
        wifiConnectProcess.targetSsid = ssid

        let safeSsid = ssid.replace(/'/g, "'\\''")
        let safePass = password ? password.replace(/'/g, "'\\''") : ""

        let cmd = ""
        if (safePass.length > 0) {
            cmd = "nmcli connection delete id '" + safeSsid + "' >/dev/null 2>&1; " +
                  "nmcli dev wifi connect '" + safeSsid + "' password '" + safePass + "'"
        } else if (isSaved) {
            cmd = "nmcli connection up id '" + safeSsid + "'"
        } else {
            cmd = "nmcli dev wifi connect '" + safeSsid + "'"
        }

        wifiConnectProcess.command = ["bash", "-c", cmd]
        wifiConnectProcess.running = true
    }

    function disconnectWifi(ssid) {
        exec("nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE dev | grep ':wifi' | cut -d: -f1)")
        root.expandedSsid = ""
        refreshTimer.restart()
    }

    function toggleWifi() {
        if (root.wifiEnabled) {
            root.wifiEnabled = false
            wifiModel.clear()
            exec("nmcli radio wifi off")
        } else {
            root.wifiEnabled = true
            exec("nmcli radio wifi on")
            refreshTimer.restart()
        }
    }

    function toggleEthernet() {
        if (root.ethConnected || root.ethEnabled) {
            root.ethConnected = false
            root.ethEnabled = false
            if (root.ethDev) {
                exec("nmcli device disconnect " + root.ethDev)
            } else {
                exec("nmcli networking off")
            }
        } else {
            root.ethEnabled = true
            if (root.ethDev) {
                exec("nmcli device set " + root.ethDev + " managed yes && nmcli device connect " + root.ethDev)
            } else {
                exec("nmcli networking on")
            }
        }
        refreshTimer.restart()
    }

    function getSignalIcon(signal, inUse) {
        if (signal >= 75) return "󰤨"
        if (signal >= 50) return "󰤥"
        if (signal >= 25) return "󰤢"
        return "󰤟"
    }

    Timer {
        id: refreshTimer
        interval: 1200
        running: false
        repeat: false
        onTriggered: root.fetchNetworkStatus()
    }

    Timer {
        interval: 6000
        running: root.expandedSsid === "" && root.connectingSsid === ""
        repeat: true
        onTriggered: root.fetchNetworkStatus()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.namespace: "qs-network-center"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 60
                anchors.rightMargin: 20
                implicitWidth: 430
                implicitHeight: 640
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }
                Keys.onEscapePressed: Qt.quit()

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                Rectangle {
                    id: container
                    anchors.fill: parent

                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)
                    clip: true

                    layer.enabled: true
                    layer.samples: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "Networks"
                                    color: root.themeText
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    visible: wifiModel.count > 0
                                    Layout.preferredWidth: badgeText.implicitWidth + 14
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: Qt.alpha(root.themePrimary, 0.25)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.5)

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: wifiModel.count + " available"
                                        color: root.themePrimary
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: scanRow.implicitWidth + 18
                                Layout.preferredHeight: 32
                                radius: Math.max(4, root.themeRounding - 4)
                                color: scanBtnArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.08)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    id: scanRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰑐"
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                        RotationAnimation on rotation {
                                            running: root.isScanning
                                            from: 0; to: 360
                                            loops: Animation.Infinite
                                            duration: 1000
                                        }
                                    }

                                    Text {
                                        text: root.isScanning ? "Scanning" : "Rescan"
                                        color: root.themeText
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: scanBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.fetchNetworkStatus()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: Math.max(4, root.themeRounding - 6)
                                color: root.wifiEnabled ? Qt.alpha(root.themePrimary, 0.16) : root.themeSurface
                                border.width: root.themeBorderSize
                                border.color: root.wifiEnabled ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                                Behavior on color { ColorAnimation { duration: 180 } }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleWifi()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: root.wifiEnabled ? "󰤨" : "󰤭"
                                        color: root.wifiEnabled ? root.themePrimary : root.themeTextMuted
                                        font.pixelSize: 18
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            text: "Wi-Fi"
                                            color: root.themeText
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }
                                        Text {
                                            text: root.wifiEnabled ? "Enabled" : "Disabled"
                                            color: root.themeTextMuted
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        width: 38; height: 22; radius: 11
                                        color: root.wifiEnabled ? root.themePrimary : Qt.rgba(1, 1, 1, 0.15)
                                        Behavior on color { ColorAnimation { duration: 180 } }

                                        Rectangle {
                                            width: 16; height: 16; radius: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: root.wifiEnabled ? 19 : 3
                                            color: root.wifiEnabled ? "#000000" : root.themeText
                                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: Math.max(4, root.themeRounding - 6)
                                color: (root.ethConnected || root.ethEnabled) ? Qt.alpha(root.themePrimary, 0.16) : root.themeSurface
                                border.width: root.themeBorderSize
                                border.color: (root.ethConnected || root.ethEnabled) ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                                Behavior on color { ColorAnimation { duration: 180 } }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleEthernet()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: root.ethConnected ? "󰈀" : "󰈂"
                                        color: (root.ethConnected || root.ethEnabled) ? root.themePrimary : root.themeTextMuted
                                        font.pixelSize: 18
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            text: "Ethernet"
                                            color: root.themeText
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }
                                        Text {
                                            text: root.ethConnected ? "Connected" : (root.ethEnabled ? "Disconnected" : "Disabled")
                                            color: root.themeTextMuted
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        width: 38; height: 22; radius: 11
                                        color: (root.ethConnected || root.ethEnabled) ? root.themePrimary : Qt.rgba(1, 1, 1, 0.15)
                                        Behavior on color { ColorAnimation { duration: 180 } }

                                        Rectangle {
                                            width: 16; height: 16; radius: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: (root.ethConnected || root.ethEnabled) ? 19 : 3
                                            color: (root.ethConnected || root.ethEnabled) ? "#000000" : root.themeText
                                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: !root.wifiEnabled || wifiModel.count === 0
                                spacing: 12

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: !root.wifiEnabled ? "󰤭" : "󰤫"
                                    color: Qt.rgba(1, 1, 1, 0.22)
                                    font.pixelSize: 48
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: !root.wifiEnabled ? "Wi-Fi is turned off" : "No Networks Available"
                                    color: root.themeTextMuted
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }

                            ListView {
                                id: wifiList
                                visible: root.wifiEnabled && wifiModel.count > 0
                                anchors.fill: parent
                                model: wifiModel
                                spacing: 10
                                clip: true

                                delegate: Rectangle {
                                    id: card
                                    width: wifiList.width

                                    property bool isConnected: model.in_use
                                    property bool isConnecting: root.connectingSsid === model.ssid
                                    property bool hasError: root.errorSsid === model.ssid && root.connectErrorMsg !== ""
                                    property bool isProtected: model.security !== "Open" && model.security !== "--"
                                    property bool isExpanded: root.expandedSsid === model.ssid
                                    property bool isSaved: model.saved !== undefined ? model.saved : false
                                    property bool showPassword: false

                                    implicitHeight: cardCol.implicitHeight + 24
                                    height: implicitHeight

                                    Behavior on height {
                                        NumberAnimation { 
                                            duration: root.animEnabled ? root.animDuration : 0
                                            easing.type: Easing.OutCubic 
                                        }
                                    }

                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: headerMouseArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: root.themeBorderSize
                                    border.color: card.hasError ? "#ff4b6e" : (card.isConnected ? Qt.alpha(root.themePrimary, 0.6) : (card.isExpanded ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.08)))

                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    ColumnLayout {
                                        id: cardCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 10

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: headerRow.implicitHeight

                                            RowLayout {
                                                id: headerRow
                                                anchors.fill: parent
                                                spacing: 12

                                                Text {
                                                    text: root.getSignalIcon(model.signal, card.isConnected)
                                                    color: card.isConnected ? root.themePrimary : root.themeText
                                                    font.pixelSize: 18
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2

                                                    Text {
                                                        text: model.ssid
                                                        color: root.themeText
                                                        font.pixelSize: 13
                                                        font.weight: card.isConnected ? Font.Bold : Font.Medium
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    RowLayout {
                                                        spacing: 6
                                                        Text {
                                                            text: model.security
                                                            color: root.themeTextMuted
                                                            font.pixelSize: 10
                                                        }
                                                        Text {
                                                            text: "• " + model.signal + "%"
                                                            color: root.themeTextMuted
                                                            font.pixelSize: 10
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: statusText.implicitWidth + 16
                                                    Layout.preferredHeight: 26
                                                    radius: 13
                                                    color: card.hasError ? Qt.alpha("#ff4b6e", 0.22) : (card.isConnected ? Qt.alpha(root.themePrimary, 0.22) : (card.isSaved ? Qt.alpha("#38bdf8", 0.18) : Qt.rgba(1, 1, 1, 0.06)))
                                                    border.width: 1
                                                    border.color: card.hasError ? Qt.alpha("#ff4b6e", 0.6) : (card.isConnected ? Qt.alpha(root.themePrimary, 0.5) : (card.isSaved ? Qt.alpha("#38bdf8", 0.4) : Qt.rgba(1, 1, 1, 0.1)))

                                                    Text {
                                                        id: statusText
                                                        anchors.centerIn: parent
                                                        text: card.isConnecting ? "Connecting..." : (card.hasError ? "Failed" : (card.isConnected ? "Connected" : (card.isSaved ? "Saved" : (card.isProtected ? "Locked" : "Connect"))))
                                                        color: card.hasError ? "#ff4b6e" : (card.isConnected ? root.themePrimary : (card.isSaved ? "#38bdf8" : root.themeText))
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: headerMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (card.isConnected) {
                                                        root.expandedSsid = (root.expandedSsid === model.ssid) ? "" : model.ssid
                                                    } else if (card.isSaved && !card.hasError) {
                                                        root.connectWifi(model.ssid, "", true)
                                                    } else if (!card.isProtected && !card.hasError) {
                                                        root.connectWifi(model.ssid, "", false)
                                                    } else {
                                                        root.expandedSsid = (root.expandedSsid === model.ssid) ? "" : model.ssid
                                                    }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: card.isExpanded
                                            spacing: 10

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 1
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                            }

                                            RowLayout {
                                                visible: card.isConnected
                                                Layout.fillWidth: true

                                                Item { Layout.fillWidth: true }

                                                Rectangle {
                                                    Layout.preferredWidth: 110
                                                    Layout.preferredHeight: 32
                                                    radius: 8
                                                    color: "#e11d48"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "Disconnect"
                                                        color: "#ffffff"
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.disconnectWifi(model.ssid)
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                visible: !card.isConnected && card.isProtected
                                                Layout.fillWidth: true
                                                spacing: 6

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 36
                                                        radius: 8
                                                        color: root.themeBackground
                                                        border.width: 1
                                                        border.color: card.hasError ? "#ff4b6e" : (passInput.activeFocus ? Qt.alpha(root.themePrimary, 0.6) : Qt.rgba(1, 1, 1, 0.15))

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 10
                                                            anchors.rightMargin: 10
                                                            spacing: 6

                                                            TextField {
                                                                id: passInput
                                                                Layout.fillWidth: true
                                                                placeholderText: card.isSaved ? "Re-enter password to update..." : "Password..."
                                                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                                                color: root.themeText
                                                                font.pixelSize: 12
                                                                echoMode: card.showPassword ? TextInput.Normal : TextInput.Password
                                                                selectByMouse: true
                                                                focus: true
                                                                background: Item {}
                                                                onAccepted: {
                                                                    root.connectWifi(model.ssid, passInput.text, false)
                                                                }
                                                            }

                                                            Text {
                                                                text: card.showPassword ? "󰈈" : "󰈉"
                                                                color: root.themeTextMuted
                                                                font.pixelSize: 13
                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: card.showPassword = !card.showPassword
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        Layout.preferredWidth: card.isConnecting ? 100 : 84
                                                        Layout.preferredHeight: 36
                                                        radius: 8
                                                        color: card.isConnecting ? Qt.rgba(1, 1, 1, 0.2) : root.themePrimary

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: card.isConnecting ? "Connecting..." : "Connect"
                                                            color: card.isConnecting ? root.themeText : "#000000"
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            enabled: !card.isConnecting
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.connectWifi(model.ssid, passInput.text, false)
                                                            }
                                                        }
                                                    }
                                                }

                                                Text {
                                                    visible: card.hasError
                                                    text: "󰅙 " + root.connectErrorMsg
                                                    color: "#ff4b6e"
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.Wrap
                                                    Layout.topMargin: 2
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}