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

    // ============================================================
    // STRICT FOCUSED MONITOR LOCK LOGIC
    // ============================================================
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

    // ============================================================
    // THEME & STYLING PROPERTIES
    // ============================================================
    property int themeRounding: 22
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.65
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.05) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.12)
    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"

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

    // ============================================================
    // SYSTEM MONITOR DATA PROPERTIES
    // ============================================================
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
    
    // New Battery & Network Graph Properties
    property int sysBatCap: 0
    property string sysBatStat: "Unknown"
    property real maxNetRate: 1.0 // for auto-scaling the network graph
    
    // Process Tab State ("user" or "system")
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

                    // Auto-scale network graph bounds with slow decay
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
        initHistories()

        // EXTREMELY OPTIMIZED KERNEL-DIRECT FETCHING SCRIPT
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
    
    # CPU
    try:
        tot, idl = read_cpu()
        data['cpu_usage'] = round(100 * (1.0 - (idl - prev_idle) / (tot - prev_total)), 1) if tot > prev_total else 0
        prev_total, prev_idle = tot, idl
    except: data['cpu_usage'] = 0

    # Hardware Temps via /sys/class/hwmon
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

    # Battery Fetching
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

    # RAM
    try:
        with open('/proc/meminfo') as f:
            m = {p[0]: int(p[1]) for p in [line.split() for line in f][:5]}
        tot = m.get('MemTotal:', 1)
        used = tot - m.get('MemFree:', 0) - m.get('Buffers:', 0) - m.get('Cached:', 0)
        data['ram_total'] = round(tot / 1024 / 1024, 1)
        data['ram_used'] = round(used / 1024 / 1024, 1)
        data['ram_perc'] = round((used / tot) * 100, 1)
    except: pass

    # DISK
    try:
        st = os.statvfs('/')
        tot_b = st.f_blocks * st.f_frsize
        free_b = st.f_bavail * st.f_frsize
        used_b = tot_b - free_b
        data['disk_size'] = f"{tot_b / 1024**3:.1f}G"
        data['disk_used'] = f"{used_b / 1024**3:.1f}G"
        data['disk_perc'] = round((used_b / tot_b) * 100, 1)
    except: pass

    # GPU
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

    # NETWORK
    rx, tx = read_net()
    rx_rate = (rx - prev_rx) / 1.5
    tx_rate = (tx - prev_tx) / 1.5
    data['net_rx'] = format_bytes(rx_rate)
    data['net_tx'] = format_bytes(tx_rate)
    data['net_rx_raw'] = rx_rate / 1024 / 1024  # Send raw megabytes for scaling graph
    data['net_tx_raw'] = tx_rate / 1024 / 1024
    prev_rx, prev_tx = rx, tx

    # UPTIME & PROCS
    try:
        with open('/proc/uptime') as f:
            up = float(f.readline().split()[0])
            data['uptime'] = f"{int(up // 3600)}h {int((up % 3600) // 60)}m"
        data['procs'] = len([p for p in os.listdir('/proc') if p.isdigit()])
    except: data['uptime'] = "0h 0m"; data['procs'] = 0

    # PROCESS LIST
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

                // Explicit Focus Bindings to Ensure ESC Closes the Widget
                Keys.onEscapePressed: Qt.quit()

                Rectangle {
                    id: mainCard
                    width: Math.min(1150, parent.width - 40)
                    height: Math.min(740, parent.height - 80)
                    anchors.centerIn: parent

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.40)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                    MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 20

                        // ============================================================
                        // LEFT COLUMN (HARDWARE GRIDS)
                        // ============================================================
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 650
                            spacing: 16

                            // Header with new Battery UI
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Text { text: ""; font.pixelSize: 24; color: root.themePrimary }
                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "System Monitor"; font.pixelSize: 18; font.weight: Font.Bold; color: root.themeText }
                                    Text { text: "Uptime: " + root.sysUptime + "  •  Processes: " + root.sysProcsCount; font.pixelSize: 11; color: root.themeTextMuted }
                                }
                                Item { Layout.fillWidth: true }
                                
                                // Battery Tracking Module
                                ColumnLayout {
                                    spacing: 0
                                    Layout.alignment: Qt.AlignRight
                                    Text { 
                                        text: (root.sysBatStat === "Charging" ? "󰂄 " : "󰁹 ") + root.sysBatCap + "%"
                                        font.pixelSize: 15; font.weight: Font.Bold
                                        color: root.sysBatStat === "Charging" ? "#a3e635" : root.themeText
                                        Layout.alignment: Qt.AlignRight
                                    }
                                    Text { 
                                        text: root.sysBatStat
                                        font.pixelSize: 10; color: root.themeTextMuted
                                        Layout.alignment: Qt.AlignRight
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.themeBorder, 0.15) }

                            // Hardware Grid
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 16

                                // CPU CARD
                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: root.themeSurface
                                    border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.15)

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: ""; font.pixelSize: 20; color: root.themePrimary }
                                            Text { text: "Processor"; font.pixelSize: 14; font.weight: Font.Bold; color: root.themeText }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.sysCpuUsage + "%"; font.pixelSize: 15; font.weight: Font.Bold; color: root.themeText }
                                        }
                                        RowLayout {
                                            Text { text: "Temp: " + root.sysCpuTemp; font.pixelSize: 11; color: root.themeTextMuted }
                                            Item { Layout.fillWidth: true }
                                        }
                                        Item { Layout.fillHeight: true }
                                        
                                        // Animated Graph
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 4
                                            Repeater {
                                                model: cpuHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(4, (model.value / 100) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 3; color: root.themePrimary; opacity: 0.8
                                                        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // GPU CARD
                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: root.themeSurface
                                    border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.15)

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: "󰢮"; font.pixelSize: 20; color: root.themePrimary }
                                            ColumnLayout {
                                                spacing: 2
                                                Text { text: "Graphics"; font.pixelSize: 14; font.weight: Font.Bold; color: root.themeText }
                                                Text { text: root.sysGpuName; font.pixelSize: 10; color: root.themeTextMuted; elide: Text.ElideRight; Layout.maximumWidth: 150 }
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.sysGpuUsage + "%"; font.pixelSize: 15; font.weight: Font.Bold; color: root.themeText }
                                        }
                                        RowLayout {
                                            Text { text: "VRAM: " + root.sysGpuMemUsed + "MB / " + root.sysGpuMemTotal + "MB"; font.pixelSize: 11; color: root.themeTextMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.sysGpuTemp; font.pixelSize: 12; font.weight: Font.Bold; color: "#fb7185" }
                                        }
                                        Item { Layout.fillHeight: true }
                                        
                                        // Animated Graph
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 4
                                            Repeater {
                                                model: gpuHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(4, (model.value / 100) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 3; color: root.themePrimary; opacity: 0.8
                                                        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // RAM CARD
                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: root.themeSurface
                                    border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.15)

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: ""; font.pixelSize: 20; color: root.themePrimary }
                                            Text { text: "Memory"; font.pixelSize: 14; font.weight: Font.Bold; color: root.themeText }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.sysRamPerc + "%"; font.pixelSize: 15; font.weight: Font.Bold; color: root.themeText }
                                        }
                                        RowLayout {
                                            Text { text: "Used: " + root.sysRamUsed + " GB / " + root.sysRamTotal + " GB"; font.pixelSize: 11; color: root.themeTextMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Temp: " + root.sysRamTemp; font.pixelSize: 11; font.weight: Font.Bold; color: "#facc15" }
                                        }
                                        Item { Layout.fillHeight: true }
                                        
                                        // Animated Graph
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 4
                                            Repeater {
                                                model: ramHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(4, (model.value / 100) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 3; color: root.themePrimary; opacity: 0.8
                                                        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // DISK CARD
                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: root.themeSurface
                                    border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.15)

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout {
                                            Text { text: "󰋊"; font.pixelSize: 20; color: root.themePrimary }
                                            Text { text: "Storage & NVMe"; font.pixelSize: 14; font.weight: Font.Bold; color: root.themeText }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.sysDiskPerc + "%"; font.pixelSize: 15; font.weight: Font.Bold; color: root.themeText }
                                        }
                                        RowLayout {
                                            Text { text: "Used: " + root.sysDiskUsed + " / " + root.sysDiskTotal; font.pixelSize: 11; color: root.themeTextMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Temp: " + root.sysDiskTemp; font.pixelSize: 11; font.weight: Font.Bold; color: "#facc15" }
                                        }
                                        Item { Layout.fillHeight: true }
                                        Rectangle {
                                            Layout.fillWidth: true; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1)
                                            Rectangle { width: parent.width * (root.sysDiskPerc / 100); height: parent.height; radius: 4; color: root.themePrimary; Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }
                                        }
                                    }
                                }

                                // NETWORK CARD WITH NEW GRAPH
                                Rectangle {
                                    Layout.fillWidth: true; Layout.columnSpan: 2; Layout.preferredHeight: 80
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: root.themeSurface
                                    border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.15)

                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 18; spacing: 20
                                        Text { text: "󰈀"; font.pixelSize: 24; color: root.themePrimary }
                                        Text { text: "Network IO"; font.pixelSize: 14; font.weight: Font.Bold; color: root.themeText }
                                        
                                        // Network History Bar Chart (Fills previously empty space)
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 4; spacing: 3
                                            Repeater {
                                                model: netHistModel
                                                Rectangle {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                                                    // Download Bar (Blue)
                                                    Rectangle {
                                                        width: parent.width; height: Math.max(3, (model.rx / root.maxNetRate) * parent.height)
                                                        anchors.bottom: parent.bottom; radius: 2; color: "#38bdf8"; opacity: 0.6
                                                        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                                    }
                                                    // Upload Bar Overlaid (Red)
                                                    Rectangle {
                                                        width: parent.width * 0.6; height: Math.max(3, (model.tx / root.maxNetRate) * parent.height)
                                                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                                        radius: 2; color: "#fb7185"; opacity: 0.8
                                                        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Rectangle { width: 1; height: 30; color: Qt.rgba(1,1,1,0.15) }

                                        ColumnLayout {
                                            spacing: 4; Layout.preferredWidth: 100
                                            Text { text: "󰇚 " + root.sysNetRx; font.pixelSize: 14; font.weight: Font.Bold; color: "#38bdf8" }
                                            Text { text: "Download"; font.pixelSize: 10; color: root.themeTextMuted }
                                        }

                                        Rectangle { width: 1; height: 30; color: Qt.rgba(1,1,1,0.15) }

                                        ColumnLayout {
                                            spacing: 4; Layout.preferredWidth: 100
                                            Text { text: "󰕒 " + root.sysNetTx; font.pixelSize: 14; font.weight: Font.Bold; color: "#fb7185" }
                                            Text { text: "Upload"; font.pixelSize: 10; color: root.themeTextMuted }
                                        }
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle { Layout.fillHeight: true; width: 1; color: Qt.alpha(root.themeBorder, 0.15) }

                        // ============================================================
                        // RIGHT COLUMN (PROCESS MANAGER)
                        // ============================================================
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 400
                            spacing: 12

                            // Process Header & Tabs
                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle {
                                    Layout.fillWidth: true; height: 42; radius: 8; color: Qt.rgba(1,1,1,0.04)
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 12
                                        
                                        // User Processes Tab
                                        Rectangle {
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
                                            radius: 6
                                            color: root.procTab === "user" ? Qt.alpha(root.themePrimary, 0.2) : "transparent"
                                            Text { anchors.centerIn: parent; text: "User Procs"; font.pixelSize: 12; font.weight: Font.Bold; color: root.procTab === "user" ? root.themePrimary : root.themeTextMuted }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.procTab = "user" }
                                        }

                                        // System Processes Tab
                                        Rectangle {
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
                                            radius: 6
                                            color: root.procTab === "system" ? Qt.alpha(root.themePrimary, 0.2) : "transparent"
                                            Text { anchors.centerIn: parent; text: "System Procs"; font.pixelSize: 12; font.weight: Font.Bold; color: root.procTab === "system" ? root.themePrimary : root.themeTextMuted }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.procTab = "system" }
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        // App Close Button
                                        Rectangle {
                                            width: 28; height: 28; radius: 6
                                            color: Qt.alpha(root.themeText, 0.08)
                                            Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 14; color: root.themeText }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.quit()
                                            }
                                        }
                                    }
                                }
                            }

                            // Process List
                            ListView {
                                id: processList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: processModel
                                spacing: 6
                                clip: true

                                delegate: Rectangle {
                                    width: processList.width
                                    height: 44
                                    radius: 8
                                    color: Qt.rgba(1, 1, 1, 0.02)
                                    border.width: 1
                                    border.color: killHover.containsMouse ? Qt.alpha("#ff4b6e", 0.4) : "transparent"

                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 10

                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { text: model.name; color: root.themeText; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "PID: " + model.pid; color: root.themeTextMuted; font.pixelSize: 10 }
                                        }

                                        ColumnLayout {
                                            Layout.preferredWidth: 45; spacing: 2; Layout.alignment: Qt.AlignRight
                                            Text { text: model.cpu + "%"; color: root.themePrimary; font.pixelSize: 11; font.weight: Font.Bold }
                                            Text { text: "CPU"; color: root.themeTextMuted; font.pixelSize: 9 }
                                        }

                                        ColumnLayout {
                                            Layout.preferredWidth: 45; spacing: 2; Layout.alignment: Qt.AlignRight
                                            Text { text: model.mem + "%"; color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Bold }
                                            Text { text: "MEM"; color: root.themeTextMuted; font.pixelSize: 9 }
                                        }

                                        Rectangle {
                                            width: 32; height: 32; radius: 8
                                            color: killHover.containsMouse ? "#ff4b6e" : Qt.rgba(1, 1, 1, 0.05)
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text { 
                                                anchors.centerIn: parent; 
                                                text: "󰅖"; font.pixelSize: 14; 
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