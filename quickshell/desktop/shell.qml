import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Scope {
    id: root

    // ============================================================
    // POSITION PERSISTENCE VIA JSON
    // ============================================================
    property string savedScreenName: ""
    property int savedMarginTop: 50
    property int savedMarginRight: 50

    FileView {
        id: posConfigFile
        path: Quickshell.env("HOME") + "/.config/quickshell/dashboard_pos.json"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let data = JSON.parse(this.text())
                if (data.screenName !== undefined) root.savedScreenName = data.screenName
                if (data.marginTop !== undefined) root.savedMarginTop = data.marginTop
                if (data.marginRight !== undefined) root.savedMarginRight = data.marginRight
            } catch(e) {}
        }
    }

    function savePosition(scrName, top, right) {
        root.savedScreenName = scrName
        root.savedMarginTop = top
        root.savedMarginRight = right
        let jsonStr = JSON.stringify({ screenName: scrName, marginTop: top, marginRight: right })
        exec("mkdir -p ~/.config/quickshell && echo '" + jsonStr + "' > ~/.config/quickshell/dashboard_pos.json")
    }

    // ============================================================
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#C5C5C5" 
    
    // Geometry & Animation Defaults (overridden by .lua files)
    property int themeRounding: 12
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.65
    property bool animEnabled: true
    property int animDuration: 500

    // Dynamic Colors based on blur settings
    property color themeBackground: Qt.rgba(0.08, 0.08, 0.09, themeBgAlpha) 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08) 

    // --- STATE PROPERTIES ---
    property string currentHour: "00"
    property string currentMinute: "00"
    property string currentPeriod: "AM"
    property string currentDate: "Loading..."
    property string currentDay: "Monday"
    property string currentTimeExact: "00:00"

    // --- WEATHER CONFIG & STATE ---
    property string weatherLat: "23.3441" // Ranchi, Jharkhand
    property string weatherLon: "85.3096"
    
    property string currentWeatherIcon: "☁️"
    property int currentWeatherTemp: 0
    property int currentWeatherFeelsLike: 0
    property string currentWeatherDesc: "Fetching..."
    property string currentWeatherHumidity: "--"
    property string currentWeatherWind: "--"
    property string currentWeatherPressure: "--"

    // --- SYSTEM HARDWARE TELEMETRY ---
    property int cpuPercent: 0
    property int ramPercent: 0
    property string ramUsedTotal: "0 GB / 0 GB"
    property int diskPercent: 0
    property int gpuPercent: 0

    // --- MUSIC PLAYER TELEMETRY ---
    property string mprisTitle: "No Media Playing"
    property string mprisArtist: ""
    property string mprisArtUrl: ""
    property bool mprisIsPlaying: false
    
    // ============================================================
    // CONFIG PARSERS
    // ============================================================
    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let content = this.text()
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) {
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
                }
            } catch (e) { console.log("Error loading theme colors: " + e) }
        }
    }

    FileView {
        id: generalConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let content = this.text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
                
                let bMatch = content.match(/border_size\s*=\s*(\d+)/)
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])

                let blurMatch = content.match(/blur\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
                if (blurMatch && blurMatch[1]) {
                    root.themeBgAlpha = (blurMatch[1] === "true") ? 0.65 : 0.90
                }
            } catch (e) {}
        }
    }

    FileView {
        id: animConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/animations.lua"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                let content = this.text()
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/)
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
    }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false;
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    // ============================================================
    // BACKGROUND PROCESSES
    // ============================================================
    
    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let cmd = "playerctl metadata --format '{{title}}|{{artist}}|{{mpris:artUrl}}|{{status}}' 2>/dev/null || echo ''"
            musicProcess.command = ["bash", "-c", cmd]
            musicProcess.running = true
        }
    }

    Process {
        id: musicProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim()
                if (out === "") {
                    root.mprisTitle = "No Media Playing"
                    root.mprisArtist = ""
                    root.mprisArtUrl = ""
                    root.mprisIsPlaying = false
                } else {
                    let parts = out.split('|')
                    root.mprisTitle = parts[0] || "Unknown Title"
                    root.mprisArtist = parts[1] || "Unknown Artist"
                    
                    let art = parts[2] || ""
                    if (art.startsWith("file://")) root.mprisArtUrl = art
                    else if (art.length > 0) root.mprisArtUrl = "file://" + art
                    else root.mprisArtUrl = ""
                    
                    root.mprisIsPlaying = (parts[3] === "Playing")
                }
            }
        }
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

    Process {
        id: statProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split('|')
                if (parts.length >= 5) {
                    root.cpuPercent = parseInt(parts[0]) || 0;
                    root.ramUsedTotal = parts[1] + " GB";
                    root.ramPercent = parseInt(parts[2]) || 0;
                    root.diskPercent = parseInt(parts[3]) || 0;
                    root.gpuPercent = parseInt(parts[4]) || 0;
                }
            }
        }
    }

    Timer {
        interval: 2500 
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let pyScript = `
import os, time, subprocess
def get_cpu():
    with open('/proc/stat') as f: p1 = [int(x) for x in f.readline().split()[1:8]]
    time.sleep(0.1)
    with open('/proc/stat') as f: p2 = [int(x) for x in f.readline().split()[1:8]]
    t1, t2 = sum(p1), sum(p2)
    return int(100 - (p2[3]-p1[3])/(t2-t1)*100) if t2 > t1 else 0

def get_mem():
    with open('/proc/meminfo') as f: l = f.readlines()
    t = int(l[0].split()[1]); a = int(l[2].split()[1]); u = t - a
    return u, t

c = get_cpu()
mu, mt = get_mem()
st = os.statvfs('/')
dp = int((st.f_blocks - st.f_bavail) / st.f_blocks * 100)
try: gp = int(subprocess.check_output("nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null", shell=True))
except: gp = 0

print(f"{c}|{mu/1048576:.1f} / {mt/1048576:.1f}|{int((mu/mt)*100)}|{dp}|{gp}")
`
            statProcess.command = ["python3", "-c", pyScript]
            statProcess.running = true
        }
    }

    Timer {
        interval: 1800000 // 30 mins
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
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
                    } catch(e) { console.log("Weather error: " + e) }
                }
            }
            xhr.send();
        }
    }

    // ============================================================
    // REUSABLE COMPONENTS
    // ============================================================
    component CircularGauge : Item {
        id: gaugeRoot
        property string label: "CPU"
        property real percent: 0
        
        property real animatedPercent: 0
        onPercentChanged: animatedPercent = percent

        onAnimatedPercentChanged: canvas.requestPaint()

        Behavior on animatedPercent {
            NumberAnimation {
                duration: root.animEnabled ? root.animDuration : 0
                easing.type: Easing.OutQuint
            }
        }
        
        width: 70
        height: 70

        Canvas {
            id: canvas
            anchors.fill: parent
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
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + (2 * Math.PI * Math.min(Math.max(gaugeRoot.animatedPercent / 100, 0), 1)));
                ctx.lineWidth = 6;
                ctx.strokeStyle = root.themePrimary;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: gaugeRoot.percent.toFixed(0) + "%"
                color: root.themeText
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: gaugeRoot.label
                color: root.themeTextMuted
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }

    component AudioBar : Rectangle {
        id: barItem
        property int minH: 6
        property int maxH: 32
        property int dur: 300
        
        width: 8
        height: minH
        radius: 4
        color: root.themePrimary
        anchors.verticalCenter: parent.verticalCenter
        
        SequentialAnimation {
            running: root.mprisIsPlaying
            loops: Animation.Infinite
            NumberAnimation { target: barItem; property: "height"; to: barItem.maxH; duration: barItem.dur; easing.type: Easing.InOutQuad }
            NumberAnimation { target: barItem; property: "height"; to: barItem.minH; duration: barItem.dur; easing.type: Easing.InOutQuad }
        }
        Behavior on height { enabled: !root.mprisIsPlaying; NumberAnimation { duration: 200 } }
    }

    // ============================================================
    // UI LAYOUT
    // ============================================================
    Variants {
        model: Quickshell.screens
        
        delegate: PanelWindow {
            id: desktopDashboard
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "dms:desktop-widget:dashboard"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            // WAYLAND BACKGROUND BLUR EFFECT
            BackgroundEffect.blurRegion: Region { item: bgCard }

            anchors { top: true; right: true }
            margins { top: root.savedMarginTop; right: root.savedMarginRight }

            implicitWidth: 440
            implicitHeight: cardLayout.implicitHeight + 40
            color: "transparent"

            Rectangle {
                id: bgCard
                anchors.fill: parent
                radius: root.themeRounding 
                border.color: Qt.alpha(root.themePrimary, 0.4)
                border.width: root.themeBorderSize
                color: root.themeBackground

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation { duration: root.animEnabled ? root.animDuration : 0 }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton 
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    
                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false

                    onPressed: (mouse) => {
                        startX = mouse.x
                        startY = mouse.y
                        isDragging = true
                    }
                    onPositionChanged: (mouse) => {
                        if (isDragging) {
                            root.savedMarginRight -= (mouse.x - startX)
                            root.savedMarginTop += (mouse.y - startY)
                        }
                    }
                    onReleased: {
                        if (isDragging) {
                            isDragging = false
                            root.savePosition(
                                desktopDashboard.screen ? desktopDashboard.screen.name : "default",
                                root.savedMarginTop,
                                root.savedMarginRight
                            )
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
                    
                    // --- 1. USER PROFILE HEADER ---
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
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.themeSurface }

                    // --- 2. CLOCK & MAIN WEATHER ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 0
                            
                            RowLayout {
                                spacing: 4
                                Text {
                                    text: root.currentTimeExact
                                    color: root.themeText
                                    font.pixelSize: 48
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: root.currentPeriod
                                    color: root.themePrimary
                                    font.pixelSize: 16
                                    font.weight: Font.Black
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 8
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
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            spacing: -2
                            
                            RowLayout {
                                spacing: 8
                                Text {
                                    text: root.currentWeatherIcon
                                    font.pixelSize: 32
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: root.currentWeatherTemp + "°C"
                                        color: root.themeText
                                        font.pixelSize: 22
                                        font.weight: Font.Bold
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

                    // --- 3. WEATHER DETAILS GRID ---
                    Rectangle {
                        Layout.fillWidth: true
                        height: 50
                        radius: Math.max(4, root.themeRounding - 4) 
                        color: root.themeSurface
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "💧 Humidity"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.currentWeatherHumidity; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "💨 Wind"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.currentWeatherWind; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "⏲️ Pressure"; color: root.themeTextMuted; font.pixelSize: 10; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.currentWeatherPressure; color: root.themeText; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }

                    // --- 4. MUSIC PLAYER ---
                    Rectangle {
                        id: musicContainer
                        Layout.fillWidth: true
                        implicitHeight: musicLayout.implicitHeight + 24 
                        radius: root.themeRounding - 2
                        color: root.themeSurface
                        border.color: Qt.alpha(root.themePrimary, 0.1)
                        border.width: 1

                        // Smooth Circular Mask Layer
                        Rectangle {
                            id: maskRect
                            anchors.fill: parent
                            radius: parent.radius
                            color: "black"
                            visible: false
                        }

                        // Background Album Art
                        Image {
                            id: bgAlbumArt
                            anchors.fill: parent
                            source: root.mprisArtUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            asynchronous: true
                        }

                        // Fast Blur Effect for Album Art
                        FastBlur {
                            id: albumArtBlur
                            anchors.fill: bgAlbumArt
                            source: bgAlbumArt
                            radius: 32
                            visible: false
                        }

                        // High-quality clipping for smooth rounded corners
                        OpacityMask {
                            anchors.fill: bgAlbumArt
                            source: albumArtBlur
                            maskSource: maskRect
                            visible: root.mprisArtUrl !== ""
                        }

                        // Dark overlay to maintain readability of text and controls
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "black"
                            opacity: root.mprisArtUrl !== "" ? 0.6 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }

                        ColumnLayout {
                            id: musicLayout
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 16

                            // TOP ROW: Centered Song Info Only
                            RowLayout {
                                Layout.fillWidth: true

                                Item { Layout.fillWidth: true } // Left Spacer

                                ColumnLayout {
                                    spacing: 4
                                    Layout.maximumWidth: 300 
                                    Layout.alignment: Qt.AlignHCenter
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.mprisTitle
                                        color: root.themeText
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.mprisArtist || "Unknown Artist"
                                        color: root.themeTextMuted
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        visible: root.mprisTitle !== "No Media Playing"
                                    }
                                }

                                Item { Layout.fillWidth: true } // Right Spacer
                            }

                            // BOTTOM ROW: Mirrored 5-bar Rhythm & Centered Controls
                            RowLayout {
                                Layout.fillWidth: true

                                // Left Rhythm
                                Row {
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: root.mprisTitle !== "No Media Playing"
                                    
                                    AudioBar { maxH: 16; dur: 450 }
                                    AudioBar { maxH: 24; dur: 380 }
                                    AudioBar { maxH: 32; dur: 300 }
                                    AudioBar { maxH: 40; dur: 250 }
                                    AudioBar { maxH: 20; dur: 400 }
                                }

                                Item { Layout.fillWidth: true } // Left spacer

                                // Centered Controls
                                RowLayout {
                                    spacing: 12
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                    
                                    Rectangle {
                                        width: 36; height: 36; radius: 18; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "⏮"; color: root.themeText; font.pixelSize: 16 }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl previous")
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 44; height: 44; radius: 22; color: root.themePrimary
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.mprisIsPlaying ? "⏸" : "▶"
                                            color: root.themeBackground
                                            font.pixelSize: 18
                                            anchors.horizontalCenterOffset: root.mprisIsPlaying ? 0 : 2
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl play-pause")
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 36; height: 36; radius: 18; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "⏭"; color: root.themeText; font.pixelSize: 16 }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl next")
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true } // Right spacer

                                // Right Rhythm (Mirrored)
                                Row {
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: root.mprisTitle !== "No Media Playing"
                                    
                                    AudioBar { maxH: 20; dur: 400 }
                                    AudioBar { maxH: 40; dur: 250 }
                                    AudioBar { maxH: 32; dur: 300 }
                                    AudioBar { maxH: 24; dur: 380 }
                                    AudioBar { maxH: 16; dur: 450 }
                                }
                            }
                        }
                    }

                    // --- 5. HARDWARE TELEMETRY ---
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 0 

                        Item { Layout.fillWidth: true; height: 70; CircularGauge { anchors.centerIn: parent; label: "CPU"; percent: root.cpuPercent } }
                        Item { Layout.fillWidth: true; height: 70; CircularGauge { anchors.centerIn: parent; label: "RAM"; percent: root.ramPercent } }
                        Item { Layout.fillWidth: true; height: 70; CircularGauge { anchors.centerIn: parent; label: "GPU"; percent: root.gpuPercent } }
                        Item { Layout.fillWidth: true; height: 70; CircularGauge { anchors.centerIn: parent; label: "DISK"; percent: root.diskPercent } }
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
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