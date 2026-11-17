import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property bool animEnabled: true
    property int animDuration: 220
    property bool isClosing: false

    QtObject {
        id: animStyle
        property int base: root.animDuration > 0 ? Math.min(root.animDuration, 260) : 220
        property int enterDuration: Math.round(base * 1.35)
        property int exitDuration: Math.round(base * 1.05)
        property int animDuration: base
        property int morphDuration: Math.round(base * 1.25)
        property int fadeDuration: Math.round(base * 0.85)
        property int microDuration: Math.round(base * 0.65)
        property int scaleDuration: Math.round(base * 1.1)
        property var smoothEasing: Easing.OutQuint
        property var expoEasing: Easing.OutExpo
        property var exitEasing: Easing.OutQuint
    }

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.58)
    property color themeSurfaceHover: Qt.rgba(0.10, 0.10, 0.14, 0.74)

    property string expandedSsid: ""
    property string connectingSsid: ""
    property string errorSsid: ""
    property string connectErrorMsg: ""

    property bool wifiEnabled: true
    property bool ethConnected: false
    property string ethState: "unavailable"
    property string ethDev: ""
    property bool isScanning: false
    property bool liveStateFetched: false

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        Qt.quit()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.quitApp()
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
        interval: 120
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

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
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
                if (bMatch && bMatch[1]) root.themeBorderSize = Math.max(2, parseInt(bMatch[1]))
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/) || content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    FileView {
        id: cacheReader
        path: Quickshell.env("HOME") + "/.cache/qs_network_cache.json"
        onLoaded: {
            try {
                let data = JSON.parse(text())
                if (!root.liveStateFetched) {
                    root.wifiEnabled = data.wifi_enabled === true
                    root.ethConnected = data.eth_connected === true
                    if (data.eth_state) root.ethState = data.eth_state
                    if (data.eth_dev) root.ethDev = data.eth_dev
                }

                if (wifiModel.count === 0 && data.networks && root.wifiEnabled) {
                    for (let i = 0; i < data.networks.length; i++) {
                        let item = data.networks[i]
                        wifiModel.append({
                            "ssid": String(item.ssid || ""),
                            "signal": Number(item.signal || 0),
                            "security": String(item.security || "Open"),
                            "in_use": Boolean(item.in_use),
                            "saved": Boolean(item.saved)
                        })
                    }
                }
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
        cacheReader.reload()

        fetchFastState()
        fetchNetworkStatus(false)
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    ListModel { id: wifiModel }

    Process {
        id: fastStateFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    root.wifiEnabled = Boolean(data.wifi_enabled)
                    root.ethConnected = Boolean(data.eth_connected)
                    root.ethState = String(data.eth_state || "unavailable")
                    root.ethDev = String(data.eth_dev || "")
                    root.liveStateFetched = true
                    if (!root.wifiEnabled) {
                        wifiModel.clear()
                    }
                } catch (e) {}
            }
        }
    }

    function fetchFastState() {
        fastStateFetcher.running = false
        let fastPyScript = `import subprocess, json
def get_fast():
    wifi_on = True
    eth_conn = False
    eth_state = "unavailable"
    eth_dev = ""
    try:
        r = subprocess.check_output(["nmcli", "radio", "wifi"], text=True, timeout=2).strip()
        wifi_on = (r == "enabled")
    except Exception:
        pass
    try:
        devs = subprocess.check_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev"], text=True, timeout=2).strip().split("\\n")
        priority = {"connected": 4, "connecting": 3, "disconnected": 2, "unavailable": 1}
        best_score = 0
        for d in devs:
            parts = d.split(":")
            if len(parts) >= 3 and parts[1] == "ethernet":
                dev_name = parts[0]
                st = parts[2].lower()
                if "(" in st:
                    st = st.split("(")[0].strip()
                score = priority.get(st, 1)
                if score > best_score:
                    best_score = score
                    eth_dev = dev_name
                    eth_state = st
                    eth_conn = st in ("connected", "connecting")
    except Exception:
        pass
    return {"wifi_enabled": wifi_on, "eth_connected": eth_conn, "eth_state": eth_state, "eth_dev": eth_dev}
print(json.dumps(get_fast()))
`
        fastStateFetcher.command = ["python3", "-c", fastPyScript]
        fastStateFetcher.running = true
    }

    Process {
        id: netFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    root.wifiEnabled = Boolean(data.wifi_enabled)
                    root.ethConnected = Boolean(data.eth_connected)
                    root.ethState = String(data.eth_state || "unavailable")
                    root.ethDev = String(data.eth_dev || "")
                    root.liveStateFetched = true

                    wifiModel.clear()
                    if (root.wifiEnabled && data.networks) {
                        for (let i = 0; i < data.networks.length; i++) {
                            let item = data.networks[i]
                            wifiModel.append({
                                "ssid": String(item.ssid || ""),
                                "signal": Number(item.signal || 0),
                                "security": String(item.security || "Open"),
                                "in_use": Boolean(item.in_use),
                                "saved": Boolean(item.saved)
                            })
                        }
                    }
                } catch (e) {}
                root.isScanning = false
            }
        }
    }

    function fetchNetworkStatus(forceRescan) {
        root.isScanning = true
        netFetcher.running = false
        let rescanFlag = forceRescan ? "yes" : "auto"
        let cmdTimeout = forceRescan ? 10 : 5
        let pyScript = `import subprocess, json, os
def get_net():
    wifi_on = False
    eth_conn = False
    eth_state = "unavailable"
    eth_dev = ""
    networks = []
    saved_conns = set()

    try:
        r = subprocess.check_output(["nmcli", "radio", "wifi"], text=True, timeout=3).strip()
        wifi_on = (r == "enabled")
    except Exception:
        pass

    try:
        c_out = subprocess.check_output(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], text=True, errors="ignore", timeout=3).strip().split("\\n")
        for line in c_out:
            if not line:
                continue
            parts = line.replace("\\\\:", "___COLON___").split(":")
            if len(parts) >= 2 and ("wireless" in parts[1] or "802-11-wireless" in parts[1]):
                saved_conns.add(parts[0].replace("___COLON___", ":"))
    except Exception:
        pass

    try:
        devs = subprocess.check_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev"], text=True, timeout=3).strip().split("\\n")
        priority = {"connected": 4, "connecting": 3, "disconnected": 2, "unavailable": 1}
        best_score = 0
        for d in devs:
            parts = d.split(":")
            if len(parts) >= 3 and parts[1] == "ethernet":
                dev_name = parts[0]
                st = parts[2].lower()
                if "(" in st:
                    st = st.split("(")[0].strip()
                score = priority.get(st, 1)
                if score > best_score:
                    best_score = score
                    eth_dev = dev_name
                    eth_state = st
                    eth_conn = st in ("connected", "connecting")
    except Exception:
        pass

    if wifi_on:
        try:
            ap_out = subprocess.check_output(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "${rescanFlag}"], text=True, errors="ignore", timeout=${cmdTimeout}).strip().split("\\n")
            seen = {}
            for line in ap_out:
                if not line:
                    continue
                parts = line.replace("\\\\:", "___COLON___").split(":")
                parts = [p.replace("___COLON___", ":") for p in parts]
                if len(parts) >= 4:
                    in_use = (parts[0].strip() == "*")
                    ssid = parts[1].strip()
                    if not ssid:
                        continue
                    signal = int(parts[2]) if parts[2].strip().isdigit() else 0
                    sec = parts[3].strip()
                    entry = {
                        "ssid": ssid,
                        "signal": signal,
                        "security": sec if (sec and sec != "--") else "Open",
                        "in_use": in_use,
                        "saved": ssid in saved_conns
                    }
                    if ssid not in seen or in_use or (not seen[ssid]["in_use"] and signal > seen[ssid]["signal"]):
                        seen[ssid] = entry
            networks = list(seen.values())
            networks.sort(key=lambda x: (not x["in_use"], not x["saved"], -x["signal"], x["ssid"].lower()))
        except Exception:
            pass

    res = {
        "wifi_enabled": wifi_on,
        "eth_connected": eth_conn,
        "eth_state": eth_state,
        "eth_dev": eth_dev,
        "networks": networks
    }

    try:
        cache_dir = os.path.expanduser("~/.cache")
        os.makedirs(cache_dir, exist_ok=True)
        with open(os.path.join(cache_dir, "qs_network_cache.json"), "w") as f:
            json.dump(res, f)
    except Exception:
        pass

    return res

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
                fetchNetworkStatus(false)
            } else {
                root.connectingSsid = ""
                root.errorSsid = targetSsid
                root.expandedSsid = targetSsid

                if (code === 124) {
                    root.connectErrorMsg = "Connection timed out"
                } else {
                    let cleaned = rawMsg.replace(/^Error:\s*/i, "").replace(/^Failed to add\/activate connection:\s*/i, "").split("\n")[0]
                    root.connectErrorMsg = cleaned ? cleaned : "Connection failed"
                }
            }
        }
    }

    function connectWifi(ssid, password, isSaved) {
        if (!ssid) return
        root.connectingSsid = ssid
        root.connectErrorMsg = ""
        root.errorSsid = ""

        wifiConnectProcess.running = false
        wifiConnectProcess.targetSsid = ssid

        let safeSsid = ssid.replace(/'/g, "'\\''")
        let safePass = password ? password.replace(/'/g, "'\\''") : ""

        let cmd = ""
        if (safePass.length > 0) {
            cmd = "nmcli connection delete id '" + safeSsid + "' >/dev/null 2>&1 || true; " +
                  "timeout 20 nmcli dev wifi connect '" + safeSsid + "' password '" + safePass + "'"
        } else if (isSaved) {
            cmd = "timeout 15 nmcli connection up id '" + safeSsid + "' >/dev/null 2>&1 || " +
                  "timeout 20 nmcli dev wifi connect '" + safeSsid + "'"
        } else {
            cmd = "timeout 20 nmcli dev wifi connect '" + safeSsid + "'"
        }

        wifiConnectProcess.command = ["bash", "-c", cmd]
        wifiConnectProcess.running = true
    }

    function disconnectWifi() {
        exec("nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE dev | grep -i ':wifi' | head -n 1 | cut -d: -f1)")
        root.expandedSsid = ""
        refreshTimer.restart()
    }

    function forgetWifi(ssid) {
        if (!ssid) return
        let safeSsid = ssid.replace(/'/g, "'\\''")
        exec("nmcli connection delete id '" + safeSsid + "'")
        root.expandedSsid = ""
        root.errorSsid = ""
        root.connectErrorMsg = ""
        refreshTimer.restart()
    }

    function toggleWifi() {
        if (root.wifiEnabled) {
            root.wifiEnabled = false
            root.expandedSsid = ""
            wifiModel.clear()
            exec("nmcli radio wifi off")
        } else {
            root.wifiEnabled = true
            exec("nmcli radio wifi on")
            refreshTimer.restart()
        }
    }

    function toggleEthernet() {
        if (!root.ethDev) return

        if (root.ethConnected) {
            root.ethConnected = false
            root.ethState = "disconnected"
            exec("nmcli device disconnect '" + root.ethDev + "'")
        } else {
            exec("nmcli device set '" + root.ethDev + "' managed yes && nmcli device connect '" + root.ethDev + "'")
        }
        refreshTimer.restart()
    }

    function getSignalIcon(signal) {
        if (signal >= 75) return "󰤨"
        if (signal >= 50) return "󰤥"
        if (signal >= 25) return "󰤢"
        return "󰤟"
    }

    function getEthSubtitle() {
        if (root.ethConnected) return root.ethDev ? root.ethDev : "Connected"
        if (root.ethState === "disconnected") return "Disconnected"
        return "Unplugged"
    }

    Timer {
        id: refreshTimer
        interval: 1100
        running: false
        repeat: false
        onTriggered: {
            root.fetchFastState()
            root.fetchNetworkStatus(false)
        }
    }

    Timer {
        interval: 7000
        running: root.expandedSsid === "" && root.connectingSsid === "" && !root.isScanning
        repeat: true
        onTriggered: {
            root.fetchFastState()
            root.fetchNetworkStatus(false)
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            WlrLayershell.namespace: "qs-network-center"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Item {
                id: dragContainer
                width: 450
                height: 650
                x: (win.width - width) / 2
                y: (win.height - height) / 2
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }
                Keys.onEscapePressed: {
                    if (!root.isClosing) root.quitApp()
                }

                DragHandler {
                    target: dragContainer
                    enabled: !root.isClosing
                    cursorShape: Qt.ClosedHandCursor
                }

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
                    border.color: Qt.alpha(root.themePrimary, 0.40)
                    antialiasing: true
                    clip: true

                    property bool shown: false
                    property bool settled: false
                    property bool panelVisible: shown && !root.isClosing

                    layer.enabled: root.animEnabled && !settled && !root.isClosing
                    layer.smooth: true

                    Component.onCompleted: {
                        enterTriggerTimer.start()
                        settleTimer.start()
                    }

                    Timer {
                        id: enterTriggerTimer
                        interval: 16
                        repeat: false
                        onTriggered: container.shown = true
                    }

                    Timer {
                        id: settleTimer
                        interval: animStyle.enterDuration + 60
                        repeat: false
                        onTriggered: container.settled = true
                    }

                    opacity: panelVisible ? 1.0 : 0.0
                    enabled: !root.isClosing

                    transform: [
                        Scale {
                            origin.x: container.width / 2
                            origin.y: container.height / 2
                            xScale: container.panelVisible ? 1.0 : 0.94
                            yScale: container.panelVisible ? 1.0 : 0.94

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        },
                        Translate {
                            y: container.panelVisible ? 0 : 12

                            Behavior on y {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        }
                    ]

                    Behavior on opacity {
                        NumberAnimation {
                            duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 11
                                color: Qt.alpha(root.themePrimary, 0.16)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.35)
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖩"
                                    font.family: root.iconFontFamily
                                    color: root.themePrimary
                                    font.pixelSize: 18
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: "Networks"
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    Rectangle {
                                        opacity: (root.wifiEnabled && wifiModel.count > 0) ? 1.0 : 0.0
                                        visible: opacity > 0
                                        Layout.preferredWidth: badgeText.implicitWidth + 14
                                        Layout.preferredHeight: 20
                                        radius: 6
                                        color: Qt.alpha(root.themePrimary, 0.18)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.4)
                                        antialiasing: true

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Behavior on Layout.preferredWidth {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: wifiModel.count.toString()
                                            color: root.themePrimary
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Text {
                                    text: root.wifiEnabled ? "Select a network to connect" : "Wireless radio disabled"
                                    color: root.themeTextMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                opacity: root.wifiEnabled ? 1.0 : 0.0
                                visible: opacity > 0
                                Layout.preferredWidth: scanRow.implicitWidth + 20
                                Layout.preferredHeight: 34
                                radius: scanBtnArea.containsMouse ? 11 : 9
                                color: scanBtnArea.containsMouse
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.72)
                                       : root.themeSurface
                                border.width: 1
                                border.color: scanBtnArea.containsMouse ? Qt.alpha(root.themePrimary, 0.6) : Qt.rgba(1, 1, 1, 0.14)
                                antialiasing: true
                                scale: scanBtnArea.pressed ? 0.95 : (scanBtnArea.containsMouse ? 1.04 : 1.0)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on radius {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                RowLayout {
                                    id: scanRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰑐"
                                        font.family: root.iconFontFamily
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                        RotationAnimation on rotation {
                                            running: root.isScanning && !root.isClosing
                                            from: 0
                                            to: 360
                                            loops: Animation.Infinite
                                            duration: 900
                                        }
                                    }

                                    Text {
                                        text: root.isScanning ? "Scanning" : "Rescan"
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    }
                                }

                                MouseArea {
                                    id: scanBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.isScanning) {
                                            root.fetchNetworkStatus(true)
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Math.max(10, root.themeRounding - 8)
                                color: root.wifiEnabled
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.74)
                                       : (wifiBtnMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                border.width: 1
                                border.color: root.wifiEnabled ? Qt.alpha(root.themePrimary, 0.65) : (wifiBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12))
                                antialiasing: true
                                scale: wifiBtnMouse.pressed ? 0.97 : (wifiBtnMouse.containsMouse ? 1.015 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                MouseArea {
                                    id: wifiBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleWifi()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 9
                                        color: root.wifiEnabled ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        border.color: root.wifiEnabled ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.10)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.wifiEnabled ? "󰤨" : "󰤭"
                                            font.family: root.iconFontFamily
                                            color: root.wifiEnabled ? root.themePrimary : root.themeTextMuted
                                            font.pixelSize: 16
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: "Wi-Fi"
                                            color: root.themeText
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
                                        }

                                        Text {
                                            text: root.wifiEnabled ? "Enabled" : "Disabled"
                                            color: root.wifiEnabled ? root.themePrimary : root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.55)
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 36
                                        height: 20
                                        radius: 10
                                        color: root.wifiEnabled ? root.themePrimary : Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                        border.width: 1
                                        border.color: root.wifiEnabled ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                        antialiasing: true

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: root.wifiEnabled ? 19 : 3
                                            color: root.wifiEnabled ? "#141416" : root.themeTextMuted
                                            antialiasing: true

                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                    easing.type: animStyle.expoEasing
                                                }
                                            }
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Math.max(10, root.themeRounding - 8)
                                color: root.ethConnected
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.74)
                                       : (ethBtnMouse.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                border.width: 1
                                border.color: root.ethConnected ? Qt.alpha(root.themePrimary, 0.65) : (ethBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12))
                                antialiasing: true
                                scale: (root.ethDev !== "" && ethBtnMouse.pressed) ? 0.97 : ((root.ethDev !== "" && ethBtnMouse.containsMouse) ? 1.015 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                MouseArea {
                                    id: ethBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: root.ethDev !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.toggleEthernet()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 9
                                        color: root.ethConnected ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        border.color: root.ethConnected ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.10)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.ethConnected ? "󰈀" : "󰈂"
                                            font.family: root.iconFontFamily
                                            color: root.ethConnected ? root.themePrimary : root.themeTextMuted
                                            font.pixelSize: 16
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: "Ethernet"
                                            color: root.themeText
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
                                        }

                                        Text {
                                            text: root.getEthSubtitle()
                                            color: root.ethConnected ? root.themePrimary : root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.55)
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 36
                                        height: 20
                                        radius: 10
                                        color: root.ethConnected ? root.themePrimary : Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                        border.width: 1
                                        border.color: root.ethConnected ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                        antialiasing: true

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: root.ethConnected ? 19 : 3
                                            color: root.ethConnected ? "#141416" : root.themeTextMuted
                                            antialiasing: true

                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                    easing.type: animStyle.expoEasing
                                                }
                                            }
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                opacity: (!root.wifiEnabled || wifiModel.count === 0) ? 1.0 : 0.0
                                visible: opacity > 0
                                spacing: 12

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 56
                                    height: 56
                                    radius: 16
                                    color: Qt.rgba(0.02, 0.02, 0.03, 0.58)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.30)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: !root.wifiEnabled ? "󰤭" : "󰤫"
                                        font.family: root.iconFontFamily
                                        color: root.themePrimary
                                        opacity: 0.75
                                        font.pixelSize: 24
                                    }
                                }

                                ColumnLayout {
                                    spacing: 3
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: !root.wifiEnabled ? "Wi-Fi Disabled" : (root.isScanning ? "Scanning Networks..." : "No Networks Found")
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: !root.wifiEnabled ? "Enable Wi-Fi above to scan nearby access points" : "Click Rescan to search again"
                                        color: root.themeTextMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.65)
                                    }
                                }
                            }

                            ListView {
                                id: wifiList
                                opacity: (root.wifiEnabled && wifiModel.count > 0) ? 1.0 : 0.0
                                visible: opacity > 0
                                anchors.fill: parent
                                model: wifiModel
                                spacing: 2
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    id: vbar
                                    visible: wifiList.visible && vbar.size < 1.0
                                    active: wifiList.moving || wifiList.flicking || hovered
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                    }
                                }

                                add: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            from: 0.0
                                            to: 1.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            from: 0.96
                                            to: 1.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }
                                }

                                remove: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            to: 0.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            to: 0.96
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                }

                                displaced: Transition {
                                    NumberAnimation {
                                        properties: "x,y"
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                        easing.type: animStyle.expoEasing
                                    }
                                }

                                delegate: Item {
                                    id: delegateRoot
                                    width: wifiList.width
                                    implicitHeight: card.height + 6
                                    height: implicitHeight

                                    Rectangle {
                                        id: card
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: vbar.visible ? 12 : 4
                                        anchors.topMargin: 3

                                        property bool isConnected: model.in_use
                                        property bool isConnecting: root.connectingSsid === model.ssid
                                        property bool hasError: root.errorSsid === model.ssid && root.connectErrorMsg !== ""
                                        property bool isProtected: model.security !== "Open" && model.security !== "--"
                                        property bool isExpanded: root.expandedSsid === model.ssid
                                        property bool isSaved: model.saved
                                        property bool showPassword: false

                                        onIsExpandedChanged: {
                                            if (isExpanded && !isConnected && isProtected) {
                                                passFocusTimer.restart()
                                            }
                                        }

                                        Timer {
                                            id: passFocusTimer
                                            interval: 60
                                            repeat: false
                                            onTriggered: passInput.forceActiveFocus()
                                        }

                                        implicitHeight: cardCol.implicitHeight + 24
                                        height: implicitHeight
                                        antialiasing: true
                                        clip: true

                                        scale: headerMouseArea.pressed ? 0.985 : ((headerMouseArea.containsMouse && !card.isExpanded) ? 1.012 : 1.0)

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }

                                        radius: Math.max(8, root.themeRounding - 8)
                                        color: card.isConnected
                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.18, 0.74)
                                               : (headerMouseArea.containsMouse || card.isExpanded ? root.themeSurfaceHover : root.themeSurface)
                                        border.width: 1
                                        border.color: card.hasError
                                                      ? "#ff6b6b"
                                                      : (card.isConnected
                                                         ? Qt.alpha(root.themePrimary, 0.70)
                                                         : (card.isExpanded ? Qt.alpha(root.themePrimary, 0.45) : (headerMouseArea.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.12))))

                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

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

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignVCenter
                                                        width: 36
                                                        height: 36
                                                        radius: 9
                                                        color: card.isConnected ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                                                        border.width: 1
                                                        border.color: card.isConnected ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.10)

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: root.getSignalIcon(model.signal)
                                                            font.family: root.iconFontFamily
                                                            color: card.isConnected ? root.themePrimary : root.themeText
                                                            font.pixelSize: 16
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 3

                                                        Text {
                                                            text: model.ssid
                                                            color: root.themeText
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 13
                                                            font.weight: card.isConnected ? Font.Bold : Font.DemiBold
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                            style: Text.Raised
                                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                        }

                                                        RowLayout {
                                                            spacing: 6

                                                            RowLayout {
                                                                spacing: 4

                                                                Text {
                                                                    text: card.isProtected ? "󰌾" : "󰌿"
                                                                    color: root.themeTextMuted
                                                                    font.family: root.iconFontFamily
                                                                    font.pixelSize: 10
                                                                    style: Text.Raised
                                                                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                                                                }

                                                                Text {
                                                                    text: card.isProtected ? model.security : "Open"
                                                                    color: root.themeTextMuted
                                                                    font.family: root.fontFamily
                                                                    font.pixelSize: 10
                                                                    font.weight: Font.Medium
                                                                    style: Text.Raised
                                                                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                                                                }
                                                            }

                                                            Text {
                                                                text: "•"
                                                                color: root.themeTextMuted
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 10
                                                            }

                                                            Text {
                                                                text: model.signal + "%"
                                                                color: root.themeTextMuted
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 10
                                                                font.weight: Font.Medium
                                                                style: Text.Raised
                                                                styleColor: Qt.rgba(0, 0, 0, 0.55)
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        Layout.preferredWidth: statusText.implicitWidth + 16
                                                        Layout.preferredHeight: 24
                                                        radius: 7
                                                        color: card.hasError
                                                               ? Qt.rgba(0.93, 0.26, 0.26, 0.28)
                                                               : (card.isConnected
                                                                  ? Qt.alpha(root.themePrimary, 0.24)
                                                                  : (card.isSaved ? Qt.rgba(0.22, 0.74, 0.97, 0.20) : Qt.rgba(0.02, 0.02, 0.03, 0.55)))
                                                        border.width: 1
                                                        border.color: card.hasError
                                                                      ? "#ff6b6b"
                                                                      : (card.isConnected
                                                                         ? Qt.alpha(root.themePrimary, 0.65)
                                                                         : (card.isSaved ? Qt.rgba(0.22, 0.74, 0.97, 0.45) : Qt.rgba(1, 1, 1, 0.14)))
                                                        antialiasing: true

                                                        Behavior on Layout.preferredWidth {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                                easing.type: animStyle.expoEasing
                                                            }
                                                        }
                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on border.color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }

                                                        Text {
                                                            id: statusText
                                                            anchors.centerIn: parent
                                                            text: card.isConnecting ? "Connecting" : (card.hasError ? "Failed" : (card.isConnected ? "Connected" : (card.isSaved ? "Saved" : "Connect")))
                                                            color: card.hasError ? "#ff6b6b" : (card.isConnected ? root.themePrimary : (card.isSaved ? "#38bdf8" : root.themeText))
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                            style: Text.Raised
                                                            styleColor: Qt.rgba(0, 0, 0, 0.65)
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: headerMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (card.isConnected || card.isSaved) {
                                                            if (!card.isConnected && card.isSaved && !card.hasError && root.expandedSsid !== model.ssid) {
                                                                root.connectWifi(model.ssid, "", true)
                                                            } else {
                                                                root.expandedSsid = (root.expandedSsid === model.ssid) ? "" : model.ssid
                                                            }
                                                        } else if (!card.isProtected && !card.hasError) {
                                                            root.connectWifi(model.ssid, "", false)
                                                        } else {
                                                            root.expandedSsid = (root.expandedSsid === model.ssid) ? "" : model.ssid
                                                        }
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                id: expandedContent
                                                Layout.fillWidth: true
                                                visible: card.isExpanded
                                                opacity: card.isExpanded ? 1.0 : 0.0
                                                spacing: 10

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 1
                                                    color: Qt.rgba(1, 1, 1, 0.10)
                                                }

                                                RowLayout {
                                                    visible: card.isConnected || card.isSaved
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Item { Layout.fillWidth: true }

                                                    Rectangle {
                                                        visible: card.isSaved
                                                        Layout.preferredWidth: forgetText.implicitWidth + 22
                                                        Layout.preferredHeight: 32
                                                        radius: forgetBtnMouse.containsMouse ? 10 : 8
                                                        color: forgetBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                                        border.width: 1
                                                        border.color: forgetBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.14)
                                                        antialiasing: true
                                                        scale: forgetBtnMouse.pressed ? 0.94 : (forgetBtnMouse.containsMouse ? 1.04 : 1.0)

                                                        Behavior on scale {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on radius {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on border.color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }

                                                        Text {
                                                            id: forgetText
                                                            anchors.centerIn: parent
                                                            text: "Forget"
                                                            color: root.themeText
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                        }

                                                        MouseArea {
                                                            id: forgetBtnMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.forgetWifi(model.ssid)
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: card.isConnected
                                                        Layout.preferredWidth: discText.implicitWidth + 24
                                                        Layout.preferredHeight: 32
                                                        radius: disconnectBtnMouse.containsMouse ? 10 : 8
                                                        color: disconnectBtnMouse.containsMouse
                                                               ? Qt.rgba(0.93, 0.26, 0.26, 0.38)
                                                               : Qt.rgba(0.93, 0.26, 0.26, 0.24)
                                                        border.width: 1
                                                        border.color: "#ff6b6b"
                                                        antialiasing: true
                                                        scale: disconnectBtnMouse.pressed ? 0.94 : (disconnectBtnMouse.containsMouse ? 1.04 : 1.0)

                                                        Behavior on scale {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on radius {
                                                            NumberAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }

                                                        Text {
                                                            id: discText
                                                            anchors.centerIn: parent
                                                            text: "Disconnect"
                                                            color: "#ff6b6b"
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                        }

                                                        MouseArea {
                                                            id: disconnectBtnMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.disconnectWifi()
                                                        }
                                                    }
                                                }

                                                ColumnLayout {
                                                    visible: !card.isConnected && card.isProtected
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 8

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 36
                                                            radius: 8
                                                            color: Qt.rgba(0.02, 0.02, 0.03, 0.60)
                                                            border.width: passInput.activeFocus ? 1.5 : 1
                                                            border.color: card.hasError
                                                                          ? "#ff6b6b"
                                                                          : (passInput.activeFocus ? Qt.alpha(root.themePrimary, 0.75) : Qt.rgba(1, 1, 1, 0.14))
                                                            antialiasing: true

                                                            Behavior on border.color {
                                                                ColorAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                    easing.type: animStyle.smoothEasing
                                                                }
                                                            }

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: 10
                                                                anchors.rightMargin: 10
                                                                spacing: 6

                                                                TextField {
                                                                    id: passInput
                                                                    Layout.fillWidth: true
                                                                    enabled: !card.isConnecting
                                                                    placeholderText: card.isSaved ? "New password..." : "Enter password..."
                                                                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.40)
                                                                    color: root.themeText
                                                                    font.family: root.fontFamily
                                                                    font.pixelSize: 12
                                                                    echoMode: card.showPassword ? TextInput.Normal : TextInput.Password
                                                                    selectByMouse: true
                                                                    background: Item {}
                                                                    onAccepted: {
                                                                        root.connectWifi(model.ssid, passInput.text, card.isSaved)
                                                                    }
                                                                }

                                                                Rectangle {
                                                                    implicitWidth: 24
                                                                    implicitHeight: 24
                                                                    radius: 6
                                                                    color: eyeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                                                    scale: eyeMouse.pressed ? 0.90 : (eyeMouse.containsMouse ? 1.08 : 1.0)

                                                                    Behavior on scale {
                                                                        NumberAnimation {
                                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                                            easing.type: animStyle.smoothEasing
                                                                        }
                                                                    }
                                                                    Behavior on color {
                                                                        ColorAnimation {
                                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                            easing.type: animStyle.smoothEasing
                                                                        }
                                                                    }

                                                                    Text {
                                                                        anchors.centerIn: parent
                                                                        text: card.showPassword ? "󰈈" : "󰈉"
                                                                        font.family: root.iconFontFamily
                                                                        color: eyeMouse.containsMouse ? root.themePrimary : root.themeTextMuted
                                                                        font.pixelSize: 14
                                                                        Behavior on color {
                                                                            ColorAnimation {
                                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                                easing.type: animStyle.smoothEasing
                                                                            }
                                                                        }
                                                                    }

                                                                    MouseArea {
                                                                        id: eyeMouse
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: card.showPassword = !card.showPassword
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Rectangle {
                                                            Layout.preferredWidth: connectBtnText.implicitWidth + 24
                                                            Layout.preferredHeight: 36
                                                            radius: connectBtnMouse.containsMouse ? 10 : 8
                                                            color: card.isConnecting
                                                                   ? Qt.rgba(1, 1, 1, 0.16)
                                                                   : (connectBtnMouse.containsMouse ? Qt.lighter(root.themePrimary, 1.08) : root.themePrimary)
                                                            antialiasing: true
                                                            scale: (!card.isConnecting && connectBtnMouse.pressed) ? 0.94 : ((!card.isConnecting && connectBtnMouse.containsMouse) ? 1.04 : 1.0)

                                                            Behavior on scale {
                                                                NumberAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                                    easing.type: animStyle.smoothEasing
                                                                }
                                                            }
                                                            Behavior on radius {
                                                                NumberAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                    easing.type: animStyle.smoothEasing
                                                                }
                                                            }
                                                            Behavior on color {
                                                                ColorAnimation {
                                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                                    easing.type: animStyle.smoothEasing
                                                                }
                                                            }

                                                            Text {
                                                                id: connectBtnText
                                                                anchors.centerIn: parent
                                                                text: card.isConnecting ? "Connecting" : "Connect"
                                                                color: card.isConnecting ? root.themeText : "#141416"
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 11
                                                                font.weight: Font.Bold
                                                            }

                                                            MouseArea {
                                                                id: connectBtnMouse
                                                                anchors.fill: parent
                                                                enabled: !card.isConnecting
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    root.connectWifi(model.ssid, passInput.text, card.isSaved)
                                                                }
                                                            }
                                                        }
                                                    }

                                                    RowLayout {
                                                        visible: card.hasError
                                                        Layout.fillWidth: true
                                                        spacing: 5

                                                        Text {
                                                            text: "󰅙"
                                                            color: "#ff6b6b"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 11
                                                        }

                                                        Text {
                                                            text: root.connectErrorMsg
                                                            color: "#ff6b6b"
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Medium
                                                            Layout.fillWidth: true
                                                            wrapMode: Text.Wrap
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
    }
}