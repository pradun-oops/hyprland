import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

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

    property bool isFullscreen: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen) || hyprFullscreen
    property bool hyprFullscreen: false

    Process {
        id: fullscreenChecker
        command: ["bash", "-c", "hyprctl activewindow -j | grep -q '\"fullscreen\": true' && echo '1' || echo '0'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.hyprFullscreen = (data.trim() === "1")
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: fullscreenChecker.running = true
    }

    property string connectingAddress: ""
    property string errorAddress: ""
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
        fetchBluetoothStatus()
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    property bool btPowered: false
    property bool isScanning: false
    property string btName: "Bluetooth"
    property int scanTicks: 0

    ListModel { id: bluetoothModel }

    Process {
        id: btFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    root.btPowered = data.powered
                    root.btName = data.name
                    
                    bluetoothModel.clear()
                    if (root.btPowered) {
                        for (let i = 0; i < data.devices.length; i++) {
                            bluetoothModel.append(data.devices[i])
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function fetchBluetoothStatus() {
        btFetcher.running = false
        let pyScript = `import subprocess, json
def get_bt():
    powered = False
    devices = {}
    name = "Bluetooth"

    try:
        status_out = subprocess.check_output(["bluetoothctl", "show"], text=True, errors="ignore")
        for line in status_out.splitlines():
            if "Powered: yes" in line: powered = True
            if "Alias:" in line: name = line.split(":", 1)[1].strip()
    except: pass

    if powered:
        try:
            # 1. Fetch strictly paired devices first
            try:
                paired_out = subprocess.check_output(["bluetoothctl", "paired-devices"], text=True, errors="ignore")
                for line in paired_out.splitlines():
                    if line.startswith("Device "):
                        parts = line.split(" ", 2)
                        addr = parts[1]
                        dname = parts[2] if len(parts) >= 3 else addr
                        devices[addr] = {"address": addr, "name": dname, "connected": False, "paired": True}
            except: pass

            # 2. Fetch all known/scanned devices
            try:
                dev_out = subprocess.check_output(["bluetoothctl", "devices"], text=True, errors="ignore")
                for line in dev_out.splitlines():
                    if line.startswith("Device "):
                        parts = line.split(" ", 2)
                        addr = parts[1]
                        dname = parts[2] if len(parts) >= 3 else addr
                        if addr not in devices:
                            devices[addr] = {"address": addr, "name": dname, "connected": False, "paired": False}
                        elif dname and dname != addr:
                            devices[addr]["name"] = dname
            except: pass

            # 3. Quickly resolve connections (works universally)
            try:
                conn_out = subprocess.check_output(["bluetoothctl", "devices", "Connected"], text=True, errors="ignore")
                for line in conn_out.splitlines():
                    if line.startswith("Device "):
                        addr = line.split(" ", 2)[1]
                        if addr in devices:
                            devices[addr]["connected"] = True
            except: pass

            # 4. Fallback connection check for paired devices
            for addr, dev in devices.items():
                if dev["paired"] and not dev["connected"]:
                    try:
                        info_out = subprocess.check_output(["bluetoothctl", "info", addr], text=True, errors="ignore")
                        if "Connected: yes" in info_out:
                            dev["connected"] = True
                    except: pass

        except Exception as e:
            pass

    dev_list = list(devices.values())
    dev_list.sort(key=lambda x: (not x["connected"], not x["paired"], x["name"]))
    
    return {
        "powered": powered,
        "name": name,
        "devices": dev_list
    }

print(json.dumps(get_bt()))
`
        btFetcher.command = ["python3", "-c", pyScript]
        btFetcher.running = true
    }

    Timer {
        id: activeScanTimer
        interval: 1500
        repeat: true
        running: false
        onTriggered: {
            root.fetchBluetoothStatus()
            root.scanTicks++
            if (root.scanTicks >= 5) {
                running = false
                root.isScanning = false
            }
        }
    }

    function startScan() {
        if (!root.btPowered || root.isScanning) return
        root.isScanning = true
        root.scanTicks = 0
        exec("bluetoothctl --timeout 8 scan on")
        activeScanTimer.start()
    }

    Process {
        id: btActionProcess
        property string targetAddress: ""
        stdout: StdioCollector { id: btActionStdout }
        stderr: StdioCollector { id: btActionStderr }
        
        onExited: (code, exitStatus) => {
            let errText = btActionStderr.text.trim()
            let outText = btActionStdout.text.trim()
            let rawMsg = errText ? errText : outText

            if (code === 0) {
                root.connectErrorMsg = ""
                root.errorAddress = ""
                root.connectingAddress = ""
                fetchBluetoothStatus()
            } else {
                root.connectingAddress = ""
                root.errorAddress = targetAddress
                
                let cleaned = rawMsg.split('\n')[0]
                root.connectErrorMsg = cleaned ? cleaned : "Action Failed"
            }
        }
    }

    function connectBt(address) {
        root.connectingAddress = address
        root.connectErrorMsg = ""
        root.errorAddress = ""
        btActionProcess.targetAddress = address
        btActionProcess.command = ["bluetoothctl", "connect", address]
        btActionProcess.running = true
    }

    function disconnectBt(address) {
        root.connectingAddress = address
        root.connectErrorMsg = ""
        root.errorAddress = ""
        btActionProcess.targetAddress = address
        btActionProcess.command = ["bluetoothctl", "disconnect", address]
        btActionProcess.running = true
    }

    function changeBtName(newName) {
        if (newName.trim() === "") return
        root.btName = newName
        exec("bluetoothctl system-alias '" + newName.replace(/'/g, "'\\''") + "'")
    }

    function toggleBluetooth() {
        btFetcher.running = false
        activeScanTimer.running = false
        root.isScanning = false
        
        if (root.btPowered) {
            root.btPowered = false
            bluetoothModel.clear()
            exec("bluetoothctl power off")
        } else {
            root.btPowered = true
            exec("bluetoothctl power on")
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: root.fetchBluetoothStatus()
    }

    Timer {
        interval: 6000
        running: root.connectingAddress === "" && !root.isScanning
        repeat: true
        onTriggered: root.fetchBluetoothStatus()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: !root.isFullscreen && root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.namespace: "qs-bluetooth-center"
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
                                    text: "Bluetooth"
                                    color: root.themeText
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    visible: bluetoothModel.count > 0
                                    Layout.preferredWidth: badgeText.implicitWidth + 14
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: Qt.alpha(root.themePrimary, 0.25)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.5)

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: bluetoothModel.count + " devices"
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
                                opacity: root.btPowered ? 1.0 : 0.5

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
                                        text: root.isScanning ? "Scanning..." : "Rescan"
                                        color: root.themeText
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: scanBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: root.btPowered && !root.isScanning
                                    cursorShape: (root.btPowered && !root.isScanning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.startScan()
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
                                color: root.btPowered ? Qt.alpha(root.themePrimary, 0.16) : root.themeSurface
                                border.width: root.themeBorderSize
                                border.color: root.btPowered ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                                Behavior on color { ColorAnimation { duration: 180 } }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: nameStack.currentIndex === 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: nameStack.currentIndex === 0
                                    onClicked: root.toggleBluetooth()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: root.btPowered ? "󰂯" : "󰂲"
                                        color: root.btPowered ? root.themePrimary : root.themeTextMuted
                                        font.pixelSize: 18
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StackLayout {
                                            id: nameStack
                                            currentIndex: 0
                                            Layout.fillWidth: true

                                            // View Name Mode
                                            RowLayout {
                                                spacing: 6
                                                Text {
                                                    text: root.btName
                                                    color: root.themeText
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 160
                                                }
                                                
                                                Rectangle {
                                                    width: 22; height: 22; radius: 4
                                                    color: editArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰏫"
                                                        color: root.themeTextMuted
                                                        font.pixelSize: 11
                                                    }
                                                    MouseArea {
                                                        id: editArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            nameInput.text = root.btName
                                                            nameStack.currentIndex = 1
                                                            nameInput.forceActiveFocus()
                                                        }
                                                    }
                                                }
                                            }

                                            // Edit Name Mode
                                            TextField {
                                                id: nameInput
                                                Layout.fillWidth: true
                                                Layout.maximumWidth: 200
                                                color: root.themeText
                                                font.pixelSize: 12
                                                selectByMouse: true
                                                background: Rectangle { 
                                                    color: root.themeSurfaceHover
                                                    border.color: root.themePrimary
                                                    border.width: 1
                                                    radius: 4 
                                                }
                                                onAccepted: {
                                                    root.changeBtName(text)
                                                    nameStack.currentIndex = 0
                                                }
                                                onEditingFinished: nameStack.currentIndex = 0
                                            }
                                        }

                                        Text {
                                            text: root.btPowered ? "Enabled" : "Disabled"
                                            color: root.themeTextMuted
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        width: 38; height: 22; radius: 11
                                        color: root.btPowered ? root.themePrimary : Qt.rgba(1, 1, 1, 0.15)
                                        Behavior on color { ColorAnimation { duration: 180 } }

                                        Rectangle {
                                            width: 16; height: 16; radius: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: root.btPowered ? 19 : 3
                                            color: root.btPowered ? "#000000" : root.themeText
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
                                visible: !root.btPowered || bluetoothModel.count === 0
                                spacing: 12

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: !root.btPowered ? "󰂲" : "󰂯"
                                    color: Qt.rgba(1, 1, 1, 0.22)
                                    font.pixelSize: 48
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: !root.btPowered ? "Bluetooth is turned off" : "No Devices Found"
                                    color: root.themeTextMuted
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }

                            ListView {
                                id: btList
                                visible: root.btPowered && bluetoothModel.count > 0
                                anchors.fill: parent
                                model: bluetoothModel
                                spacing: 10
                                clip: true

                                delegate: Rectangle {
                                    id: card
                                    width: btList.width

                                    property bool isConnected: model.connected
                                    property bool isConnecting: root.connectingAddress === model.address
                                    property bool hasError: root.errorAddress === model.address && root.connectErrorMsg !== ""
                                    property bool isPaired: model.paired

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
                                    border.color: card.hasError ? "#ff4b6e" : (card.isConnected ? Qt.alpha(root.themePrimary, 0.6) : Qt.rgba(1, 1, 1, 0.08))

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
                                                    text: "󰂱"
                                                    color: card.isConnected ? root.themePrimary : root.themeText
                                                    font.pixelSize: 18
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2

                                                    Text {
                                                        text: model.name
                                                        color: root.themeText
                                                        font.pixelSize: 13
                                                        font.weight: card.isConnected ? Font.Bold : Font.Medium
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        text: model.address
                                                        color: root.themeTextMuted
                                                        font.pixelSize: 10
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: statusText.implicitWidth + 16
                                                    Layout.preferredHeight: 26
                                                    radius: 13
                                                    color: card.hasError ? Qt.alpha("#ff4b6e", 0.22) : (card.isConnected ? Qt.alpha(root.themePrimary, 0.22) : (card.isPaired ? Qt.alpha("#38bdf8", 0.18) : Qt.rgba(1, 1, 1, 0.06)))
                                                    border.width: 1
                                                    border.color: card.hasError ? Qt.alpha("#ff4b6e", 0.6) : (card.isConnected ? Qt.alpha(root.themePrimary, 0.5) : (card.isPaired ? Qt.alpha("#38bdf8", 0.4) : Qt.rgba(1, 1, 1, 0.1)))

                                                    Text {
                                                        id: statusText
                                                        anchors.centerIn: parent
                                                        text: card.isConnecting ? "Connecting..." : (card.hasError ? "Failed" : (card.isConnected ? "Connected" : (card.isPaired ? "Paired" : "Connect")))
                                                        color: card.hasError ? "#ff4b6e" : (card.isConnected ? root.themePrimary : (card.isPaired ? "#38bdf8" : root.themeText))
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
                                                        root.disconnectBt(model.address)
                                                    } else {
                                                        root.connectBt(model.address)
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