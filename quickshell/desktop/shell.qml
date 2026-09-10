import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Scope {
    id: root

    property int savedMarginTop: 50
    property int savedMarginRight: 50

    FileView {
        id: posConfigFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/dashboard_pos.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let raw = text().trim()
                if (!raw) return
                let data = JSON.parse(raw)
                if (data.marginTop !== undefined && !isNaN(data.marginTop)) {
                    root.savedMarginTop = Math.max(0, parseInt(data.marginTop))
                }
                if (data.marginRight !== undefined && !isNaN(data.marginRight)) {
                    root.savedMarginRight = Math.max(0, parseInt(data.marginRight))
                }
            } catch(e) {}
        }
    }

    Process {
        id: savePosProcess
    }

    function savePosition(top, right) {
        let validTop = Math.max(0, Math.round(top))
        let validRight = Math.max(0, Math.round(right))

        root.savedMarginTop = validTop
        root.savedMarginRight = validRight

        let jsonDir = Quickshell.env("HOME") + "/.config/quickshell/json"
        let jsonFile = jsonDir + "/dashboard_pos.json"
        let jsonTmp = jsonFile + ".tmp"
        let jsonStr = JSON.stringify({ marginTop: validTop, marginRight: validRight })

        let cmd = "mkdir -p '" + jsonDir + "' && echo '" + jsonStr + "' > '" + jsonTmp + "' && mv '" + jsonTmp + "' '" + jsonFile + "'"

        savePosProcess.running = false
        savePosProcess.command = ["bash", "-c", cmd]
        savePosProcess.running = true
    }

    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#C5C5C5" 
    
    property int themeRounding: 12
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.7
    property bool animEnabled: true
    property int animDuration: 500

    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08) 

    property string currentHour: "00"
    property string currentMinute: "00"
    property string currentPeriod: "AM"
    property string currentDate: "Loading..."
    property string currentDay: "Monday"
    property string currentTimeExact: "00:00"

    property string weatherLat: "23.3441" 
    property string weatherLon: "85.3096"
    
    property string currentWeatherIcon: "☁️"
    property int currentWeatherTemp: 0
    property int currentWeatherFeelsLike: 0
    property string currentWeatherDesc: "Fetching..."
    property string currentWeatherHumidity: "--"
    property string currentWeatherWind: "--"
    property string currentWeatherPressure: "--"

    property int cpuPercent: 0
    property int ramPercent: 0
    property string ramUsedTotal: "0 GB / 0 GB"
    property int diskPercent: 0
    property int gpuPercent: 0

    property int cpuTemp: 0
    property int ramTemp: 0
    property int gpuTemp: 0
    property int diskTemp: 0

    property var prevCpuTimes: [0, 0]

    property var audioSinks: []
    property string currentSinkName: "Audio"
    property string currentSinkFullName: "Detecting audio..."
    property string currentSinkIcon: "󰕾"
    property string currentSinkId: ""

    function getSinkInfo(name, desc) {
        let raw = (desc || name || "").trim()
        let lower = raw.toLowerCase()

        let shortName = raw
        let icon = "󰕾"

        if (lower.indexOf("hdmi") !== -1 || lower.indexOf("displayport") !== -1 || lower.indexOf("acer") !== -1) {
            icon = "󰍹"
            shortName = "Monitor"
        } else if (lower.indexOf("headphone") !== -1 || lower.indexOf("headset") !== -1 || lower.indexOf("ear") !== -1 || lower.indexOf("buds") !== -1 || lower.indexOf("iem") !== -1 || lower.indexOf("usb") !== -1 || lower.indexOf("dac") !== -1 || lower.indexOf("type-c") !== -1) {
            icon = "󰋋"
            shortName = "IEMs"
        } else if (lower.indexOf("analog") !== -1 || lower.indexOf("speaker") !== -1 || lower.indexOf("built-in") !== -1 || lower.indexOf("pci") !== -1) {
            icon = "󰓃"
            shortName = "Speakers"
        } else {
            let words = raw.split(/\s+/)
            shortName = words.length > 2 ? words.slice(0, 2).join(" ") : raw
        }

        return { shortName: shortName, icon: icon }
    }

    Process {
        id: audioPollProcess
        command: ["bash", "-c", "def=$(pactl get-default-sink 2>/dev/null); pactl list sinks 2>/dev/null | awk -v d=\"$def\" '/Name:/ {n=$2} /Description:/ {sub(/^[ \t]*Description:[ \t]*/, \"\"); print n \"\\t\" $0 \"\\t\" (n==d?1:0)}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split("\n")
                    if (lines.length === 0) return
                    let sinks = []
                    for (let i = 0; i < lines.length; i++) {
                        let p = lines[i].split("\t")
                        if (p.length >= 3) {
                            let sName = p[0]
                            let sDesc = p[1]
                            let isDef = (p[2] === "1")

                            let lower = (sDesc + " " + sName).toLowerCase()
                            if (lower.indexOf("easyeffects") !== -1 || lower.indexOf("easy effects") !== -1) {
                                continue
                            }

                            let info = root.getSinkInfo(sName, sDesc)
                            sinks.push({
                                name: sName,
                                desc: sDesc,
                                is_def: isDef,
                                shortName: info.shortName,
                                icon: info.icon
                            })
                        }
                    }
                    root.audioSinks = sinks

                    if (sinks.length > 0) {
                        let active = sinks.find(s => s.is_def)
                        if (!active && root.currentSinkId) {
                            active = sinks.find(s => s.name === root.currentSinkId)
                        }
                        if (!active) {
                            active = sinks[0]
                        }

                        root.currentSinkId = active.name
                        root.currentSinkName = active.shortName
                        root.currentSinkFullName = active.desc
                        root.currentSinkIcon = active.icon
                    } else {
                        root.currentSinkName = "No Sinks"
                        root.currentSinkFullName = "No audio sinks found"
                        root.currentSinkIcon = "󰝟"
                    }
                } catch(e) {}
            }
        }
    }

    function refreshAudio() {
        if (!audioPollProcess.running) {
            audioPollProcess.running = true
        }
    }

    Timer {
        id: audioDebounceTimer
        interval: 100
        repeat: false
        onTriggered: refreshAudio()
    }

    Process {
        id: pactlSubscriber
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.indexOf("sink") !== -1) {
                    audioDebounceTimer.restart()
                }
            }
        }
    }

    function cycleAudioSink() {
        if (!root.audioSinks || root.audioSinks.length <= 1) {
            refreshAudio()
            return
        }

        let currIdx = root.audioSinks.findIndex(s => s.is_def || s.name === root.currentSinkId)
        if (currIdx === -1) currIdx = 0

        let nextIdx = (currIdx + 1) % root.audioSinks.length
        let target = root.audioSinks[nextIdx]

        let safeDesc = target.desc.replace(/'/g, "'\\''")
        root.exec("pactl set-default-sink " + target.name + " && notify-send -a 'Audio Switcher' 'Output Changed' '" + safeDesc + "'")

        root.currentSinkId = target.name
        root.currentSinkName = target.shortName
        root.currentSinkFullName = target.desc
        root.currentSinkIcon = target.icon

        for (let i = 0; i < root.audioSinks.length; i++) {
            root.audioSinks[i].is_def = (i === nextIdx)
        }

        refreshAudio()
    }

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
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/) || content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")

                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 100
            } catch (e) {}
        }
    }
    
    Component.onCompleted: {
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        posConfigFile.reload() 
        procStatFile.reload()
        procMemFile.reload()
        metricsProcess.running = true
        refreshAudio()
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false;
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date()
            let rawHours = now.getHours()
            root.currentPeriod = rawHours >= 12 ? "PM" : "AM"
            let hours12 = rawHours % 12 || 12
            
            root.currentHour = hours12.toString().padStart(2, '0')
            root.currentMinute = now.getMinutes().toString().padStart(2, '0')
            root.currentTimeExact = root.currentHour + ":" + root.currentMinute

            let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
            
            root.currentDay = days[now.getDay()]
            root.currentDate = now.getDate().toString().padStart(2, '0') + " " + months[now.getMonth()] + " " + now.getFullYear()
        }
    }

    FileView {
        id: procStatFile
        path: "/proc/stat"
        onLoaded: {
            try {
                let firstLine = text().split("\n")[0]
                let parts = firstLine.trim().split(/\s+/).slice(1).map(Number)
                let idle = parts[3] + (parts[4] || 0)
                let total = parts.reduce((a, b) => a + b, 0)

                if (root.prevCpuTimes[1] > 0) {
                    let totalDiff = total - root.prevCpuTimes[1]
                    let idleDiff = idle - root.prevCpuTimes[0]
                    if (totalDiff > 0) {
                        root.cpuPercent = Math.max(0, Math.min(100, Math.round(100 * (1 - idleDiff / totalDiff))))
                    }
                }
                root.prevCpuTimes = [idle, total]
            } catch(e) {}
        }
    }

    FileView {
        id: procMemFile
        path: "/proc/meminfo"
        onLoaded: {
            try {
                let lines = text().split("\n")
                let totalKb = 0
                let availKb = 0
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("MemTotal:")) totalKb = parseInt(lines[i].replace(/\D/g, ""))
                    else if (lines[i].startsWith("MemAvailable:")) availKb = parseInt(lines[i].replace(/\D/g, ""))
                    if (totalKb > 0 && availKb > 0) break
                }
                if (totalKb > 0) {
                    let usedKb = totalKb - availKb
                    let totalGb = totalKb / 1048576
                    let usedGb = usedKb / 1048576
                    root.ramPercent = Math.max(0, Math.min(100, Math.round((usedKb / totalKb) * 100)))
                    root.ramUsedTotal = usedGb.toFixed(1) + " / " + totalGb.toFixed(1) + " GB"
                }
            } catch(e) {}
        }
    }

    Process {
        id: metricsProcess
        command: [
            "python3", "-c",
            "import os, subprocess, json\n" +
            "data = {'cpu_t': 0, 'ram_t': 0, 'gpu_t': 0, 'disk_t': 0, 'disk_p': 0, 'gpu_u': 0}\n" +
            "try:\n" +
            "    for hw in os.listdir('/sys/class/hwmon/'):\n" +
            "        path = os.path.join('/sys/class/hwmon', hw)\n" +
            "        try:\n" +
            "            with open(os.path.join(path, 'name')) as f: name = f.read().strip()\n" +
            "            if 'coretemp' in name or 'k10temp' in name:\n" +
            "                with open(os.path.join(path, 'temp1_input')) as f: data['cpu_t'] = int(f.read().strip()) // 1000\n" +
            "            elif 'spd5118' in name:\n" +
            "                with open(os.path.join(path, 'temp1_input')) as f: data['ram_t'] = int(f.read().strip()) // 1000\n" +
            "            elif 'nvme' in name:\n" +
            "                with open(os.path.join(path, 'temp1_input')) as f: data['disk_t'] = int(f.read().strip()) // 1000\n" +
            "        except: pass\n" +
            "except: pass\n" +
            "if data['cpu_t'] == 0:\n" +
            "    try:\n" +
            "        with open('/sys/class/thermal/thermal_zone0/temp') as f: data['cpu_t'] = int(f.read().strip()) // 1000\n" +
            "    except: pass\n" +
            "try:\n" +
            "    gpu = subprocess.check_output('nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null', shell=True).decode().split(',')\n" +
            "    if len(gpu) >= 2:\n" +
            "        data['gpu_u'] = int(gpu[0].strip())\n" +
            "        data['gpu_t'] = int(gpu[1].strip())\n" +
            "except: pass\n" +
            "try:\n" +
            "    st = os.statvfs('/')\n" +
            "    data['disk_p'] = int((st.f_blocks - st.f_bavail) / st.f_blocks * 100)\n" +
            "except: pass\n" +
            "print(json.dumps(data))"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(text.trim())
                    root.cpuTemp = d.cpu_t || 0
                    root.ramTemp = d.ram_t || 0
                    root.gpuTemp = d.gpu_t || 0
                    root.diskTemp = d.disk_t || 0
                    root.diskPercent = d.disk_p || 0
                    root.gpuPercent = d.gpu_u || 0
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procStatFile.reload()
            procMemFile.reload()
            if (!metricsProcess.running) {
                metricsProcess.running = true
            }
            refreshAudio()
        }
    }

    function fetchWeather() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", `https://api.open-meteo.com/v1/forecast?latitude=${root.weatherLat}&longitude=${root.weatherLon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,wind_speed_10m&timezone=auto`);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText).current;
                    root.currentWeatherTemp = Math.round(d.temperature_2m);
                    root.currentWeatherFeelsLike = Math.round(d.apparent_temperature);
                    root.currentWeatherHumidity = d.relative_humidity_2m + "%";
                    root.currentWeatherWind = Math.round(d.wind_speed_10m) + " km/h";
                    root.currentWeatherPressure = Math.round(d.surface_pressure) + " hPa";
                    
                    var code = d.weather_code;
                    var desc = "Clear";
                    var icon = "☀️";
                    
                    if (code === 1 || code === 2 || code === 3) { desc = "Cloudy"; icon = "☁️"; }
                    if (code >= 45 && code <= 48) { desc = "Fog"; icon = "🌫️"; }
                    if (code >= 51 && code <= 67) { desc = "Rain"; icon = "🌧️"; }
                    if (code >= 71 && code <= 77) { desc = "Snow"; icon = "❄️"; }
                    if (code >= 95 && code <= 99) { desc = "Storm"; icon = "⛈️"; }
                    if (code === 3) { desc = "Overcast"; } 
                    
                    root.currentWeatherDesc = desc;
                    root.currentWeatherIcon = icon;
                } catch(e) {}
            }
        }
        xhr.send();
    }

    function fetchLocation() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://ip-api.com/json/");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        if (d && d.lat !== undefined && d.lon !== undefined) {
                            root.weatherLat = d.lat.toString();
                            root.weatherLon = d.lon.toString();
                        }
                    } catch(e) {}
                }
                root.fetchWeather();
            }
        }
        xhr.send();
    }

    Timer {
        interval: 1800000 
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.fetchLocation();
        }
    }

    component CircularGauge : Item {
        id: gaugeRoot
        property string label: "CPU"
        property real value: 0
        property string unit: "%"
        
        property real animatedValue: 0
        onValueChanged: animatedValue = value
        onAnimatedValueChanged: canvas.requestPaint()

        function getTlpColor(val) {
            if (gaugeRoot.unit === "°C") {
                if (val < 55) return "#4ade80"       
                if (val < 80) return "#facc15"       
                return "#f87171"   
            } else {
                if (val < 60) return "#4ade80"       
                if (val < 85) return "#facc15"       
                return "#f87171"                     
            }
        }

        Behavior on animatedValue {
            NumberAnimation {
                duration: root.animEnabled ? root.animDuration : 0
                easing.type: Easing.OutQuint
            }
        }
        
        width: 78
        height: 78

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = Math.min(width, height) / 2 - 5;
                
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                ctx.lineWidth = 6;
                ctx.strokeStyle = root.themeSurface;
                ctx.stroke();
                
                ctx.beginPath();
                var maxVal = 100;
                var fillRatio = Math.min(Math.max(gaugeRoot.animatedValue / maxVal, 0), 1);
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + (2 * Math.PI * fillRatio));
                ctx.lineWidth = 6;
                ctx.strokeStyle = gaugeRoot.getTlpColor(gaugeRoot.animatedValue);
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: gaugeRoot.value.toFixed(0) + gaugeRoot.unit
                color: root.themeText
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: gaugeRoot.label
                color: root.themeTextMuted
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
        }
    }

    Variants {
        model: Quickshell.screens
        
        delegate: PanelWindow {
            id: desktopDashboard
            required property var modelData
            screen: modelData

            visible: modelData !== null

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-desktop-dashboard"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true; right: true }
            margins { top: root.savedMarginTop; right: root.savedMarginRight }

            implicitWidth: 440
            implicitHeight: cardLayout.implicitHeight + 64
            
            color: "transparent"

            Item {
                id: bgCard
                anchors.fill: parent

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation { duration: root.animEnabled ? root.animDuration : 0 }
                }

                Rectangle {
                    id: bgCardShape
                    anchors.fill: parent
                    radius: root.themeRounding 
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.4)
                    antialiasing: true 
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    pressAndHoldInterval: 150 
                    
                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false

                    onPressed: (mouse) => {
                        startX = mouse.x
                        startY = mouse.y
                    }
                    
                    onPressAndHold: (mouse) => {
                        isDragging = true
                        startX = mouse.x
                        startY = mouse.y
                    }

                    onPositionChanged: (mouse) => {
                        if (isDragging) {
                            let dx = mouse.x - startX
                            let dy = mouse.y - startY
                            if (Math.abs(dx) > 0 || Math.abs(dy) > 0) {
                                root.savedMarginRight = Math.max(0, root.savedMarginRight - dx)
                                root.savedMarginTop = Math.max(0, root.savedMarginTop + dy)
                            }
                        }
                    }
                    
                    onReleased: {
                        if (isDragging) {
                            isDragging = false
                            root.savePosition(root.savedMarginTop, root.savedMarginRight)
                        }
                    }
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 24 
                    spacing: 20 
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            color: root.themeSurface
                            border.color: root.themePrimary
                            border.width: root.themeBorderSize
                            antialiasing: true
                            
                            Image {
                                id: profilePic
                                source: "file://" + Quickshell.env("HOME") + "/.face.icon"
                                visible: false 
                                
                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        let currentSource = source.toString();
                                        if (currentSource.indexOf(".face.icon") !== -1) {
                                            source = "file://" + Quickshell.env("HOME") + "/.face";
                                        } else if (currentSource.indexOf(".face") !== -1) {
                                            source = "file:///var/lib/AccountsService/icons/" + (Quickshell.env("USER") || "pradun");
                                        } else {
                                            fallbackText.visible = true;
                                        }
                                    } else if (status === Image.Ready) {
                                        fallbackText.visible = false;
                                        avatarCanvas.loadImage(source);
                                    }
                                }
                            }
                            
                            Canvas {
                                id: avatarCanvas
                                anchors.fill: parent
                                anchors.margins: root.themeBorderSize 
                                antialiasing: true
                                renderTarget: Canvas.FramebufferObject
                                
                                onImageLoaded: requestPaint()
                                onPaint: {
                                    if (profilePic.status !== Image.Ready) return;
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.imageSmoothingEnabled = true;
                                    
                                    var r = width / 2;
                                    ctx.beginPath();
                                    ctx.arc(r, r, r, 0, 2 * Math.PI);
                                    ctx.clip();
                                    
                                    ctx.drawImage(profilePic.source, 0, 0, width, height);
                                }
                            }
                            
                            Text {
                                id: fallbackText
                                anchors.centerIn: parent
                                text: "PK" 
                                color: root.themePrimary
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                visible: false
                            }
                        }
                        
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "Pradun Kumar"
                                color: root.themeText
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                            Text {
                                text: (Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland") + " • Fedora 43"
                                color: root.themePrimary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                        
                        Item { Layout.fillWidth: true } 

                        Rectangle {
                            id: audioSwitchBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: audioBtnLayout.implicitWidth + 22
                            radius: 16
                            color: audioBtnMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : root.themeSurface
                            border.width: 1
                            border.color: audioBtnMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themeBorder, 0.25)
                            scale: audioBtnMouse.pressed ? 0.94 : (audioBtnMouse.containsMouse ? 1.04 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.animEnabled ? 180 : 0
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: audioBtnLayout
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: root.currentSinkIcon
                                    font.pixelSize: 14
                                    color: root.themePrimary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: root.currentSinkName
                                    color: root.themeText
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.maximumWidth: 100
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: "⇄"
                                    color: root.themeTextMuted
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: audioBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cycleAudioSink()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.themeSurface }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 16

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 0
                            
                            RowLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 4
                                Text {
                                    text: root.currentTimeExact
                                    color: root.themeText
                                    font.pixelSize: 48
                                    font.weight: Font.Bold
                                    lineHeight: 0.9
                                }
                                Text {
                                    text: root.currentPeriod
                                    color: root.themePrimary
                                    font.pixelSize: 16
                                    font.weight: Font.Black
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 8
                                }
                            }
                            Text {
                                text: root.currentDay + ", " + root.currentDate
                                color: root.themeTextMuted
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.0
                            }
                        }

                        Item { Layout.fillWidth: true } 

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 0
                            
                            RowLayout {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                spacing: 8
                                Text {
                                    text: root.currentWeatherIcon
                                    font.pixelSize: 32
                                    Layout.alignment: Qt.AlignTop
                                }
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 0
                                    Text {
                                        text: root.currentWeatherTemp + "°C"
                                        color: root.themeText
                                        font.pixelSize: 22
                                        font.weight: Font.Bold
                                        lineHeight: 0.9
                                    }
                                    Text {
                                        text: root.currentWeatherDesc
                                        color: root.themeTextMuted
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                            Text {
                                text: "Feels like " + root.currentWeatherFeelsLike + "°C"
                                color: root.themeTextMuted
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignRight
                                Layout.topMargin: 4
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: weatherGrid.implicitHeight + 24 
                        radius: Math.max(6, root.themeRounding - 4) 
                        color: root.themeSurface
                        antialiasing: true
                        
                        RowLayout {
                            id: weatherGrid
                            anchors.fill: parent
                            anchors.margins: 12 
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text { text: "💧 Humidity"; color: root.themeTextMuted; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.currentWeatherHumidity; color: root.themeText; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text { text: "💨 Wind"; color: root.themeTextMuted; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.currentWeatherWind; color: root.themeText; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text { text: "⏲️ Pressure"; color: root.themeTextMuted; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.currentWeatherPressure; color: root.themeText; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 0 

                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "CPU"; value: root.cpuPercent; unit: "%" } }
                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "RAM"; value: root.ramPercent; unit: "%" } }
                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "GPU"; value: root.gpuPercent; unit: "%" } }
                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "DISK"; value: root.diskPercent; unit: "%" } }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        spacing: 0 

                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "CPU TEMP"; value: root.cpuTemp; unit: "°C" } }
                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "RAM TEMP"; value: root.ramTemp; unit: "°C" } }
                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "GPU TEMP"; value: root.gpuTemp; unit: "°C" } }
                        Item { Layout.fillWidth: true; height: 78; CircularGauge { anchors.centerIn: parent; label: "DISK TEMP"; value: root.diskTemp; unit: "°C" } }
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        text: "Memory Used: " + root.ramUsedTotal
                        color: root.themeTextMuted
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}