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

    property int themeRounding: 22
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0, 0, 0, 0.32)
    property color themeSurfaceHover: Qt.rgba(255, 255, 255, 0.12)
    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#D4D4D8"

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    property real sysCpuUsage: 0
    property string sysCpuTemp: "0°C"
    property real sysRamTotal: 0
    property real sysRamUsed: 0
    property real sysRamPerc: 0
    property string sysRamTemp: "N/A"
    property string sysDiskTotal: "0G"
    property string sysDiskUsed: "0G"
    property real sysDiskPerc: 0
    property string sysDiskTemp: "N/A"
    property real sysGpuUsage: 0
    property string sysGpuTemp: "0°C"
    property real sysGpuMemUsed: 0
    property real sysGpuMemTotal: 0
    property string sysGpuName: "Scanning..."
    property string sysNetRx: "0 B/s"
    property string sysNetTx: "0 B/s"
    property string sysUptime: "0h 0m"
    property int sysProcsCount: 0
    
    property int sysBatCap: 0
    property string sysBatStat: "Unknown"
    property real maxNetRate: 1.0 
    
    property string procTab: "user"

    ListModel { id: cpuHistModel }
    ListModel { id: gpuHistModel }
    ListModel { id: ramHistModel }
    ListModel { id: netHistModel }
    ListModel { id: processModel }

    function initHistories() {
        for(let i = 0; i < 35; i++) {
            cpuHistModel.append({value: 0})
            gpuHistModel.append({value: 0})
            ramHistModel.append({value: 0})
            netHistModel.append({rx: 0, tx: 0})
        }
    }

    Process { id: actionProcess }
    function killProcess(pid) {
        actionProcess.running = false
        actionProcess.command = ["bash", "-c", "kill -9 " + pid]
        actionProcess.running = true
    }

    property var userProcsData: []
    property var sysProcsData: []

    Process {
        id: sysMonFetcher
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let d = JSON.parse(data)
                    
                    root.sysCpuUsage = d.cpu_usage
                    root.sysCpuTemp = d.cpu_temp
                    root.sysRamTotal = d.ram_total
                    root.sysRamUsed = d.ram_used
                    root.sysRamPerc = d.ram_perc
                    root.sysRamTemp = d.ram_temp
                    root.sysDiskTotal = d.disk_size
                    root.sysDiskUsed = d.disk_used
                    root.sysDiskPerc = d.disk_perc
                    root.sysDiskTemp = d.nvme_temp
                    root.sysGpuUsage = d.gpu_usage
                    root.sysGpuTemp = d.gpu_temp + "°C"
                    root.sysGpuMemUsed = d.gpu_mem_used
                    root.sysGpuMemTotal = d.gpu_mem_total
                    root.sysGpuName = d.gpu_name
                    root.sysNetRx = d.net_rx
                    root.sysNetTx = d.net_tx
                    root.sysUptime = d.uptime
                    root.sysProcsCount = d.procs
                    root.sysBatCap = d.bat_cap
                    root.sysBatStat = d.bat_stat

                    root.maxNetRate = Math.max(1.0, root.maxNetRate * 0.95, d.net_rx_raw, d.net_tx_raw)

                    cpuHistModel.append({value: d.cpu_usage})
                    if (cpuHistModel.count > 35) cpuHistModel.remove(0)

                    gpuHistModel.append({value: d.gpu_usage})
                    if (gpuHistModel.count > 35) gpuHistModel.remove(0)

                    ramHistModel.append({value: d.ram_perc})
                    if (ramHistModel.count > 35) ramHistModel.remove(0)

                    netHistModel.append({rx: d.net_rx_raw, tx: d.net_tx_raw})
                    if (netHistModel.count > 35) netHistModel.remove(0)

                    root.userProcsData = d.procs_user || []
                    root.sysProcsData = d.procs_sys || []
                    
                    updateProcessModel()
                } catch(e) {}
            }
        }
    }

    function updateProcessModel() {
        let activeList = root.procTab === "user" ? root.userProcsData : root.sysProcsData;
        if (activeList) {
            for (let i = 0; i < activeList.length; i++) {
                if (i < processModel.count) {
                    processModel.setProperty(i, "pid", activeList[i].pid)
                    processModel.setProperty(i, "name", activeList[i].name)
                    processModel.setProperty(i, "cpu", activeList[i].cpu)
                    processModel.setProperty(i, "mem", activeList[i].mem)
                } else {
                    processModel.append(activeList[i])
                }
            }
            while (processModel.count > activeList.length) {
                processModel.remove(processModel.count - 1)
            }
        }
    }

    onProcTabChanged: updateProcessModel()

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }

        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        initHistories()

        let pyScript = `import json, time, subprocess, os

def read_cpu():
    try:
        with open('/proc/stat') as f:
            fields = [float(col) for col in f.readline().strip().split()[1:]]
        return sum(fields), fields[3] + fields[4]
    except: return 0, 0

def read_net():
    rx = tx = 0
    try:
        with open('/proc/net/dev') as f:
            for line in f.readlines()[2:]:
                p = line.split()
                if p[0] != 'lo:': rx += int(p[1]); tx += int(p[9])
    except: pass
    return rx, tx

def format_bytes(b):
    if b < 1024: return f"{b:.0f} B/s"
    elif b < 1024**2: return f"{b/1024:.1f} KB/s"
    elif b < 1024**3: return f"{b/1024**2:.1f} MB/s"
    else: return f"{b/1024**3:.2f} GB/s"

prev_total, prev_idle = read_cpu()
prev_rx, prev_tx = read_net()

while True:
    data = {}
    
    try:
        tot, idl = read_cpu()
        data['cpu_usage'] = round(100 * (1.0 - (idl - prev_idle) / (tot - prev_total)), 1) if tot > prev_total else 0
        prev_total, prev_idle = tot, idl
    except: data['cpu_usage'] = 0

    cpu_t = "N/A"; ram_t = "N/A"; nvme_t = []
    try:
        for hw in os.listdir('/sys/class/hwmon/'):
            path = os.path.join('/sys/class/hwmon', hw)
            try:
                with open(os.path.join(path, 'name')) as f: name = f.read().strip()
                if 'coretemp' in name or 'k10temp' in name:
                    with open(os.path.join(path, 'temp1_input')) as f: cpu_t = f"{int(f.read().strip()) // 1000}°C"
                elif 'spd5118' in name:
                    with open(os.path.join(path, 'temp1_input')) as f: ram_t = f"{int(f.read().strip()) // 1000}°C"
                elif 'nvme' in name:
                    with open(os.path.join(path, 'temp1_input')) as f: nvme_t.append(f"{int(f.read().strip()) // 1000}°C")
            except: pass
    except: pass
    
    data['cpu_temp'] = cpu_t
    data['ram_temp'] = ram_t
    data['nvme_temp'] = " | ".join(nvme_t) if nvme_t else "N/A"

    bat_cap = 0; bat_stat = "Unknown"
    try:
        for p in os.listdir('/sys/class/power_supply/'):
            if p.startswith('BAT'):
                with open(f'/sys/class/power_supply/{p}/capacity') as f: bat_cap = int(f.read().strip())
                with open(f'/sys/class/power_supply/{p}/status') as f: bat_stat = f.read().strip()
                break
    except: pass
    data['bat_cap'] = bat_cap
    data['bat_stat'] = bat_stat

    try:
        with open('/proc/meminfo') as f:
            m = {p[0]: int(p[1]) for p in [line.split() for line in f][:5]}
        tot = m.get('MemTotal:', 1)
        used = tot - m.get('MemFree:', 0) - m.get('Buffers:', 0) - m.get('Cached:', 0)
        data['ram_total'] = round(tot / 1024 / 1024, 1)
        data['ram_used'] = round(used / 1024 / 1024, 1)
        data['ram_perc'] = round((used / tot) * 100, 1)
    except: pass

    try:
        st = os.statvfs('/')
        tot_b = st.f_blocks * st.f_frsize
        free_b = st.f_bavail * st.f_frsize
        used_b = tot_b - free_b
        data['disk_size'] = f"{tot_b / 1024**3:.1f}G"
        data['disk_used'] = f"{used_b / 1024**3:.1f}G"
        data['disk_perc'] = round((used_b / tot_b) * 100, 1)
    except: pass

    try:
        gpu = subprocess.check_output("nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,gpu_name --format=csv,noheader,nounits", shell=True).decode().split(',')
        if len(gpu) >= 5:
            data['gpu_usage'] = int(gpu[0].strip())
            data['gpu_temp'] = int(gpu[1].strip())
            data['gpu_mem_used'] = int(gpu[2].strip())
            data['gpu_mem_total'] = int(gpu[3].strip())
            data['gpu_name'] = gpu[4].strip()
    except:
        data['gpu_usage'] = data['gpu_temp'] = data['gpu_mem_used'] = data['gpu_mem_total'] = 0
        data['gpu_name'] = "No GPU Found"

    rx, tx = read_net()
    rx_rate = (rx - prev_rx) / 1.5
    tx_rate = (tx - prev_tx) / 1.5
    data['net_rx'] = format_bytes(rx_rate)
    data['net_tx'] = format_bytes(tx_rate)
    data['net_rx_raw'] = rx_rate / 1024 / 1024  
    data['net_tx_raw'] = tx_rate / 1024 / 1024
    prev_rx, prev_tx = rx, tx

    try:
        with open('/proc/uptime') as f:
            up = float(f.readline().split()[0])
            data['uptime'] = f"{int(up // 3600)}h {int((up % 3600) // 60)}m"
        data['procs'] = len([p for p in os.listdir('/proc') if p.isdigit()])
    except: data['uptime'] = "0h 0m"; data['procs'] = 0

    try:
        ps_out = subprocess.check_output("ps -eo pid,uid,comm,%cpu,%mem --sort=-%cpu | head -n 40", shell=True).decode().splitlines()[1:]
        u_procs, s_procs = [], []
        for line in ps_out:
            parts = line.split()
            if len(parts) >= 5:
                uid = int(parts[1])
                p_obj = {
                    "pid": parts[0],
                    "name": " ".join(parts[2:-2]),
                    "cpu": parts[-2],
                    "mem": parts[-1]
                }
                if uid >= 1000:
                    if len(u_procs) < 20: u_procs.append(p_obj)
                else:
                    if len(s_procs) < 20: s_procs.append(p_obj)
        data['procs_user'] = u_procs
        data['procs_sys'] = s_procs
    except: pass

    print(json.dumps(data), flush=True)
    time.sleep(1.5)
`
        sysMonFetcher.command = ["python3", "-c", pyScript]
        sysMonFetcher.running = true
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.namespace: "qs-sysmon"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

            Item {
                id: mainFocusWrapper
                anchors.fill: parent
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }

                Keys.onEscapePressed: Qt.quit()

                Rectangle {
                    id: mainCard
                    width: Math.min(1150, parent.width - 40)
                    height: Math.min(740, parent.height - 80)
                    anchors.centerIn: parent

                    property bool shown: false
                    Component.onCompleted: shown = true

                    scale: shown ? 1.0 : 0.90
                    opacity: shown ? 1.0 : 0.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: animStyle.fadeDuration
                            easing.type: animStyle.fadeEasing
                        }
                    }

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.42)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    antialiasing: true
                    clip: true

                    MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 650
                            spacing: 16

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Text { text: ""; font.pixelSize: 24; color: root.themePrimary }
                                ColumnLayout {
                                    spacing: 2
                                    Text { 
                                        text: "System Monitor"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                        color: "#FFFFFF"
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                    }
                                    Text { 
                                        text: "Uptime: " + root.sysUptime + "  •  Processes: " + root.sysProcsCount
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: root.themeTextMuted
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                
                                ColumnLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignRight
                                    Text { 
                                        text: (root.sysBatStat === "Charging" ? "󰂄 " : "󰁹 ") + root.sysBatCap + "%"
                                        font.pixelSize: 15; font.weight: Font.Bold
                                        color: root.sysBatStat === "Charging" ? "#a3e635" : "#FFFFFF"
                                        Layout.alignment: Qt.AlignRight
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                    }
                                    Text { 
                                        text: root.sysBatStat
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: root.themeTextMuted
                                        Layout.alignment: Qt.AlignRight
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.65)
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255, 255, 255, 0.12) }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 16

                                Rectangle {
                                    id: cpuCard
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: cpuCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: cpuCardHover.hovered ? root.themePrimary : Qt.rgba(255, 255, 255, 0.10)
                                    antialiasing: true

                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    HoverHandler { id: cpuCardHover }

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: ""; font.pixelSize: 20; color: root.themePrimary }
                                            Text { 
                                                text: "Processor"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: root.sysCpuUsage + "%"
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            }
                                        }
                                        RowLayout {
                                            Text { 
                                                text: "Temp: " + root.sysCpuTemp
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        Item { Layout.fillHeight: true }
                                        
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 4
                                            Repeater {
                                                model: cpuHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(4, (model.value / 100) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 3; color: root.themePrimary; opacity: 0.8
                                                        antialiasing: true
                                                        Behavior on height { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: gpuCard
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: gpuCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: gpuCardHover.hovered ? root.themePrimary : Qt.rgba(255, 255, 255, 0.10)
                                    antialiasing: true

                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    HoverHandler { id: gpuCardHover }

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: "󰢮"; font.pixelSize: 20; color: root.themePrimary }
                                            ColumnLayout {
                                                spacing: 2
                                                Text { 
                                                    text: "Graphics"
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    color: "#FFFFFF"
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                }
                                                Text { 
                                                    text: root.sysGpuName
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 150
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                                }
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: root.sysGpuUsage + "%"
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            }
                                        }
                                        RowLayout {
                                            Text { 
                                                text: "VRAM: " + root.sysGpuMemUsed + "MB / " + root.sysGpuMemTotal + "MB"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: root.sysGpuTemp
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: "#fb7185"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                                            }
                                        }
                                        Item { Layout.fillHeight: true }
                                        
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 4
                                            Repeater {
                                                model: gpuHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(4, (model.value / 100) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 3; color: root.themePrimary; opacity: 0.8
                                                        antialiasing: true
                                                        Behavior on height { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: ramCard
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: ramCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: ramCardHover.hovered ? root.themePrimary : Qt.rgba(255, 255, 255, 0.10)
                                    antialiasing: true

                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    HoverHandler { id: ramCardHover }

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: ""; font.pixelSize: 20; color: root.themePrimary }
                                            Text { 
                                                text: "Memory"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: root.sysRamPerc + "%"
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            }
                                        }
                                        RowLayout {
                                            Text { 
                                                text: "Used: " + root.sysRamUsed + " GB / " + root.sysRamTotal + " GB"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: "Temp: " + root.sysRamTemp
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#facc15"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                                            }
                                        }
                                        Item { Layout.fillHeight: true }
                                        
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 4
                                            Repeater {
                                                model: ramHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(4, (model.value / 100) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 3; color: root.themePrimary; opacity: 0.8
                                                        antialiasing: true
                                                        Behavior on height { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: diskCard
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: diskCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: diskCardHover.hovered ? root.themePrimary : Qt.rgba(255, 255, 255, 0.10)
                                    antialiasing: true

                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    HoverHandler { id: diskCardHover }

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: "󰋊"; font.pixelSize: 20; color: root.themePrimary }
                                            Text { 
                                                text: "Storage & NVMe"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: root.sysDiskPerc + "%"
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            }
                                        }
                                        RowLayout {
                                            Text { 
                                                text: "Used: " + root.sysDiskUsed + " / " + root.sysDiskTotal
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { 
                                                text: "Temp: " + root.sysDiskTemp
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#facc15"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                                            }
                                        }
                                        Item { Layout.fillHeight: true }
                                        Rectangle {
                                            Layout.fillWidth: true; height: 8; radius: 4; color: Qt.rgba(255, 255, 255, 0.12)
                                            antialiasing: true
                                            Rectangle { 
                                                width: parent.width * (root.sysDiskPerc / 100)
                                                height: parent.height
                                                radius: 4
                                                color: root.themePrimary
                                                antialiasing: true
                                                Behavior on width { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } } 
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: netCard
                                    Layout.fillWidth: true; Layout.columnSpan: 2; Layout.preferredHeight: 80
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: netCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: netCardHover.hovered ? root.themePrimary : Qt.rgba(255, 255, 255, 0.10)
                                    antialiasing: true

                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    HoverHandler { id: netCardHover }

                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 20
                                        Text { text: "󰈀"; font.pixelSize: 24; color: root.themePrimary }
                                        Text { 
                                            text: "Network IO"
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.8)
                                        }
                                        
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 4; spacing: 3
                                            Repeater {
                                                model: netHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(3, (model.rx / root.maxNetRate) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 2; color: "#38bdf8"; opacity: 0.6
                                                        antialiasing: true
                                                        Behavior on height { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    }
                                                    Rectangle {
                                                        width: parent.width * 0.6; height: Math.max(3, (model.tx / root.maxNetRate) * parent.height)
                                                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                                        radius: 2; color: "#fb7185"; opacity: 0.8
                                                        antialiasing: true
                                                        Behavior on height { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Rectangle { width: 1; height: 30; color: Qt.rgba(255, 255, 255, 0.15) }

                                        ColumnLayout {
                                            spacing: 2; Layout.preferredWidth: 100
                                            Text { 
                                                text: "󰇚 " + root.sysNetRx
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: "#38bdf8"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                                            }
                                            Text { 
                                                text: "Download"
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.65)
                                            }
                                        }

                                        Rectangle { width: 1; height: 30; color: Qt.rgba(255, 255, 255, 0.15) }

                                        ColumnLayout {
                                            spacing: 2; Layout.preferredWidth: 100
                                            Text { 
                                                text: "󰕒 " + root.sysNetTx
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: "#fb7185"
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                                            }
                                            Text { 
                                                text: "Upload"
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.65)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillHeight: true; width: 1; color: Qt.rgba(255, 255, 255, 0.12) }

                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 400
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle {
                                    Layout.fillWidth: true; height: 42; radius: 8; color: Qt.rgba(0, 0, 0, 0.35)
                                    border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.08)
                                    antialiasing: true

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 12
                                        
                                        Rectangle {
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
                                            radius: 6
                                            color: root.procTab === "user" ? Qt.alpha(root.themePrimary, 0.25) : (userTabMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
                                            border.width: 1
                                            border.color: root.procTab === "user" ? root.themePrimary : (userTabMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.4) : "transparent")
                                            antialiasing: true

                                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                            Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                            Text { 
                                                anchors.centerIn: parent
                                                text: "User Procs"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: root.procTab === "user" ? "#FFFFFF" : root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                            MouseArea { id: userTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.procTab = "user" }
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
                                            radius: 6
                                            color: root.procTab === "system" ? Qt.alpha(root.themePrimary, 0.25) : (sysTabMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
                                            border.width: 1
                                            border.color: root.procTab === "system" ? root.themePrimary : (sysTabMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.4) : "transparent")
                                            antialiasing: true

                                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                            Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                            Text { 
                                                anchors.centerIn: parent
                                                text: "System Procs"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: root.procTab === "system" ? "#FFFFFF" : root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                            MouseArea { id: sysTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.procTab = "system" }
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        Rectangle {
                                            width: 28; height: 28; radius: 6
                                            color: closeHover.containsMouse ? "#ff4b6e" : Qt.alpha(root.themeText, 0.08)
                                            border.width: 1
                                            border.color: closeHover.containsMouse ? "#ff4b6e" : Qt.rgba(255, 255, 255, 0.12)
                                            antialiasing: true

                                            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                            Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                            Text { 
                                                anchors.centerIn: parent
                                                text: "󰅖"
                                                font.pixelSize: 14
                                                color: closeHover.containsMouse ? "#ffffff" : root.themeText 
                                            }

                                            MouseArea {
                                                id: closeHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.quit()
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 12
                                Layout.rightMargin: 8
                                Layout.topMargin: 2
                                Layout.bottomMargin: 2
                                spacing: 10

                                Text {
                                    text: "PROCESS"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.1
                                    color: root.themeTextMuted
                                    Layout.fillWidth: true
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Text {
                                    Layout.preferredWidth: 62
                                    text: "PID"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.1
                                    color: root.themeTextMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Text {
                                    Layout.preferredWidth: 50
                                    text: "CPU"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.1
                                    color: root.themeTextMuted
                                    horizontalAlignment: Text.AlignRight
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Text {
                                    Layout.preferredWidth: 50
                                    text: "MEM"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.1
                                    color: root.themeTextMuted
                                    horizontalAlignment: Text.AlignRight
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Item {
                                    width: 32
                                    height: 1
                                }
                            }

                            ListView {
                                id: processList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: processModel
                                spacing: 6
                                clip: true

                                delegate: Rectangle {
                                    id: procRow
                                    width: processList.width
                                    height: 44
                                    radius: 8
                                    color: procRowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.28)
                                    border.width: 1
                                    border.color: killHover.containsMouse ? "#ff4b6e" : (procRowMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.4) : Qt.rgba(255, 255, 255, 0.06))
                                    antialiasing: true

                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    MouseArea {
                                        id: procRowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 10

                                        Text { 
                                            text: model.name
                                            color: "#FFFFFF"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.8)
                                        }

                                        Text {
                                            Layout.preferredWidth: 62
                                            text: model.pid
                                            color: root.themeTextMuted
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.alignment: Qt.AlignVCenter
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.65)
                                        }

                                        Text {
                                            Layout.preferredWidth: 50
                                            text: model.cpu + "%"
                                            color: root.themePrimary
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            horizontalAlignment: Text.AlignRight
                                            Layout.alignment: Qt.AlignVCenter
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                        }

                                        Text {
                                            Layout.preferredWidth: 50
                                            text: model.mem + "%"
                                            color: "#38bdf8"
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            horizontalAlignment: Text.AlignRight
                                            Layout.alignment: Qt.AlignVCenter
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                        }

                                        Rectangle {
                                            width: 32; height: 32; radius: 8
                                            color: killHover.containsMouse ? "#ff4b6e" : Qt.rgba(255, 255, 255, 0.08)
                                            border.width: 1
                                            border.color: killHover.containsMouse ? "#ff4b6e" : Qt.rgba(255, 255, 255, 0.12)
                                            antialiasing: true

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            Text { 
                                                anchors.centerIn: parent 
                                                text: "󰅖"; font.pixelSize: 14 
                                                color: killHover.containsMouse ? "#ffffff" : root.themeTextMuted 
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                            
                                            MouseArea {
                                                id: killHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.killProcess(model.pid)
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