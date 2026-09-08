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
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.72
    
    property color themeBackground: "#121318" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.04) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.08)
    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#94a3b8"

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

    property bool isFetching: true
    property string fetchError: ""
    
    property string locName: "Locating..."
    property string currTemp: "--"
    property string currFeel: "--"
    property string currHigh: "--"
    property string currLow: "--"
    property string currDesc: "--"
    property string currIcon: "󰖐"
    property string currWind: "-- km/h"
    property string currWindGust: "-- km/h"
    property string currHum: "--%"
    property string currUV: "--"
    property string currUVDesc: "--"
    property string currPress: "-- hPa"
    property string currClouds: "--%"
    property string currSunrise: "--:--"
    property string currSunset: "--:--"
    
    ListModel { id: hourlyModel }
    ListModel { id: forecastModel }

    Process {
        id: weatherFetcher
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let d = JSON.parse(data)
                    
                    if (d.error) {
                        root.fetchError = d.error
                        root.isFetching = false
                        return
                    }

                    root.fetchError = ""
                    root.locName = d.location
                    root.currTemp = d.current.temp
                    root.currFeel = d.current.feels_like
                    root.currHigh = d.current.high
                    root.currLow = d.current.low
                    root.currDesc = d.current.desc
                    root.currIcon = d.current.icon
                    root.currWind = d.current.wind
                    root.currWindGust = d.current.wind_gust
                    root.currHum = d.current.humidity
                    root.currUV = d.current.uv
                    root.currUVDesc = d.current.uv_desc
                    root.currPress = d.current.pressure
                    root.currClouds = d.current.clouds
                    root.currSunrise = d.current.sunrise
                    root.currSunset = d.current.sunset

                    hourlyModel.clear()
                    for (let h = 0; h < d.hourly.length; h++) {
                        hourlyModel.append(d.hourly[h])
                    }

                    forecastModel.clear()
                    for (let i = 0; i < d.daily.length; i++) {
                        forecastModel.append(d.daily[i])
                    }
                } catch(e) {}
                root.isFetching = false
            }
        }
    }

    function fetchWeather(city) {
        root.isFetching = true
        root.fetchError = ""
        let safeQuery = city.trim().replace(/"/g, '\\"')
        
        let pyScript = `import urllib.request, json, urllib.parse, datetime, os, time

CACHE_FILE = "/tmp/qs_weather_cache.json"
CACHE_EXPIRY = 1800

def get_icon(code, is_day):
    if code == 0: return "󰖙" if is_day else "󰖔"
    if code in [1,2]: return "󰖕" if is_day else "󰼱"
    if code == 3: return "󰖐"
    if code in [45,48]: return "󰖑"
    if code in [51,53,55,56,57]: return "󰖗"
    if code in [61,63,65,66,67]: return "󰖖"
    if code in [71,73,75,77,85,86]: return "󰖘"
    if code in [80,81,82]: return "󰖖"
    if code in [95,96,99]: return "󰖓"
    return "󰖐"

def get_desc(code):
    m = {0: "Clear Sky", 1: "Mainly Clear", 2: "Partly Cloudy", 3: "Overcast", 45: "Foggy", 48: "Rime Fog", 51: "Light Drizzle", 53: "Drizzle", 55: "Heavy Drizzle", 61: "Slight Rain", 63: "Moderate Rain", 65: "Heavy Rain", 71: "Slight Snow", 73: "Snowfall", 75: "Heavy Snow", 80: "Rain Showers", 81: "Heavy Showers", 82: "Violent Rain", 95: "Thunderstorm", 96: "Storm w/ Hail", 99: "Severe Storm"}
    return m.get(code, "Unknown")

def get_uv_desc(uv):
    if uv <= 2: return "Low"
    if uv <= 5: return "Moderate"
    if uv <= 7: return "High"
    if uv <= 10: return "Very High"
    return "Extreme"

try:
    query = "${safeQuery}"
    lat, lon, loc_name = None, None, ""

    if not query:
        if os.path.exists(CACHE_FILE) and (time.time() - os.path.getmtime(CACHE_FILE)) < CACHE_EXPIRY:
            with open(CACHE_FILE, 'r') as f:
                print(f.read(), flush=True)
            exit(0)

    if query:
        geo_url = "https://geocoding-api.open-meteo.com/v1/search?name=" + urllib.parse.quote(query) + "&count=1&format=json"
        req = urllib.request.Request(geo_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=6) as resp:
            geo = json.loads(resp.read().decode())
            if "results" in geo and len(geo["results"]) > 0:
                res = geo["results"][0]
                lat, lon = res["latitude"], res["longitude"]
                loc_name = f"{res['name']}, {res.get('country', '')}"
            else:
                print(json.dumps({"error": "Location not found. Try another city."}))
                exit(0)
    else:
        req = urllib.request.Request("http://ip-api.com/json/", headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=6) as resp:
            ip_data = json.loads(resp.read().decode())
            lat, lon = ip_data["lat"], ip_data["lon"]
            loc_name = f"{ip_data['city']}, {ip_data.get('country', '')}"

    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_gusts_10m,surface_pressure,cloud_cover"
        "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max"
        "&timezone=auto&forecast_days=8"
    )
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=8) as resp:
        w = json.loads(resp.read().decode())
        
        c = w['current']
        d = w['daily']
        h = w['hourly']
        
        sunrise_raw = d['sunrise'][0].split('T')[1]
        sunset_raw = d['sunset'][0].split('T')[1]
        uv_val = d['uv_index_max'][0] if d['uv_index_max'][0] is not None else 0.0

        data = {
            "error": "",
            "location": loc_name,
            "current": {
                "temp": f"{round(c['temperature_2m'])}°C",
                "feels_like": f"{round(c['apparent_temperature'])}°C",
                "high": f"{round(d['temperature_2m_max'][0])}°",
                "low": f"{round(d['temperature_2m_min'][0])}°",
                "desc": get_desc(c['weather_code']),
                "icon": get_icon(c['weather_code'], c['is_day']),
                "wind": f"{c['wind_speed_10m']} km/h",
                "wind_gust": f"{c.get('wind_gusts_10m', c['wind_speed_10m'])} km/h",
                "humidity": f"{c['relative_humidity_2m']}%",
                "uv": str(round(uv_val, 1)),
                "uv_desc": get_uv_desc(uv_val),
                "pressure": f"{round(c['surface_pressure'])} hPa",
                "clouds": f"{c.get('cloud_cover', 0)}%",
                "sunrise": sunrise_raw,
                "sunset": sunset_raw
            },
            "hourly": [],
            "daily": []
        }

        now_dt = datetime.datetime.now()
        cur_hour = now_dt.hour
        for idx in range(cur_hour, min(cur_hour + 16, len(h['time']))):
            t_dt = datetime.datetime.strptime(h['time'][idx], "%Y-%m-%dT%H:%M")
            t_label = "Now" if idx == cur_hour else t_dt.strftime("%I %p").lstrip("0")
            data["hourly"].append({
                "time": t_label,
                "icon": get_icon(h['weather_code'][idx], h['is_day'][idx]),
                "temp": f"{round(h['temperature_2m'][idx])}°",
                "pop": f"{h['precipitation_probability'][idx]}%"
            })

        global_min = min(d['temperature_2m_min'])
        global_max = max(d['temperature_2m_max'])
        spread = max(1.0, global_max - global_min)

        for i in range(7):
            date_obj = datetime.datetime.strptime(d['time'][i], "%Y-%m-%d")
            day_name = "Today" if i == 0 else date_obj.strftime("%a")
            d_min = d['temperature_2m_min'][i]
            d_max = d['temperature_2m_max'][i]
            
            data["daily"].append({
                "day": day_name,
                "date": date_obj.strftime("%d %b"),
                "desc": get_desc(d['weather_code'][i]),
                "icon": get_icon(d['weather_code'][i], 1),
                "max": f"{round(d_max)}°",
                "min": f"{round(d_min)}°",
                "pop": f"{d['precipitation_probability_max'][i]}%",
                "precip": f"{d['precipitation_sum'][i]:.1f} mm",
                "wind": f"{round(d['wind_speed_10m_max'][i])} km/h",
                "left_ratio": (d_min - global_min) / spread,
                "width_ratio": max(0.12, (d_max - d_min) / spread)
            })

        out_str = json.dumps(data)
        print(out_str, flush=True)

        if not query:
            try:
                with open(CACHE_FILE, 'w') as f:
                    f.write(out_str)
            except: pass

except Exception as e:
    print(json.dumps({"error": "Failed to fetch weather data. Check your connection."}), flush=True)
`
        weatherFetcher.command = ["python3", "-c", pyScript]
        weatherFetcher.running = true
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }
        colorFile.reload()
        generalConfigFile.reload()
        root.fetchWeather("")
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.namespace: "qs-weather"
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
                    width: Math.min(1220, parent.width - 40)
                    height: Math.min(840, parent.height - 40)
                    anchors.centerIn: parent

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.30)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                    MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                width: 42; height: 42; radius: 12
                                color: Qt.alpha(root.themePrimary, 0.12)
                                border.width: 1; border.color: Qt.alpha(root.themePrimary, 0.28)
                                Layout.alignment: Qt.AlignVCenter

                                Text { 
                                    anchors.centerIn: parent
                                    text: "󰖐"
                                    font.pixelSize: 22; color: root.themePrimary
                                }
                            }
                            
                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter
                                Text { text: "Weather Telemetry"; font.pixelSize: 18; font.weight: Font.Bold; color: root.themeText }
                                RowLayout {
                                    spacing: 6
                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        color: root.isFetching ? "#facc15" : "#4ade80"
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text { text: root.isFetching ? "Locating station..." : root.locName; font.pixelSize: 12; color: root.themeTextMuted }
                                }
                            }

                            Item { Layout.fillWidth: true }
                            
                            Rectangle {
                                width: 38; height: 38; radius: 10
                                color: autoGpsHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                border.width: 1
                                border.color: autoGpsHover.containsMouse ? Qt.alpha(root.themePrimary, 0.4) : Qt.alpha(root.themeBorder, 0.2)
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                
                                Text { anchors.centerIn: parent; text: "󰤉"; font.pixelSize: 16; color: root.themePrimary }
                                
                                MouseArea {
                                    id: autoGpsHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.fetchWeather("")
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 260
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: searchInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.12)
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text { text: "󰍉"; font.pixelSize: 14; color: searchInput.activeFocus ? root.themePrimary : root.themeTextMuted }

                                    TextField {
                                        id: searchInput
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        font.pixelSize: 13
                                        color: root.themeText
                                        placeholderText: "Type city or region..."
                                        placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.5)
                                        verticalAlignment: TextInput.AlignVCenter
                                        background: Item {}
                                        onAccepted: {
                                            if (text.trim() !== "") {
                                                root.fetchWeather(text)
                                                text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 38; height: 38; radius: 10
                                color: closeHover.containsMouse ? "#ff4b6e" : Qt.alpha(root.themeText, 0.08)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Layout.alignment: Qt.AlignVCenter

                                Text { 
                                    anchors.centerIn: parent
                                    text: "󰅖"; font.pixelSize: 14
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

                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.themeBorder, 0.15) }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.fetchError !== ""
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                Text { text: "󰖙"; font.pixelSize: 48; color: Qt.alpha(root.themeText, 0.3); Layout.alignment: Qt.AlignHCenter }
                                Text { text: root.fetchError; font.pixelSize: 15; color: "#fb7185"; Layout.alignment: Qt.AlignHCenter; font.weight: Font.Bold }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 20
                            visible: root.fetchError === ""

                            ScrollView {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                Layout.preferredWidth: 650
                                clip: true
                                contentWidth: availableWidth
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                ColumnLayout {
                                    width: parent.width
                                    spacing: 16

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 160
                                        radius: Math.max(4, root.themeRounding - 6)
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.alpha(root.themePrimary, 0.08) }
                                            GradientStop { position: 1.0; color: root.themeSurface }
                                        }
                                        border.width: 1
                                        border.color: Qt.alpha(root.themeBorder, 0.20)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.topMargin: 16
                                            anchors.bottomMargin: 16
                                            anchors.leftMargin: 22
                                            anchors.rightMargin: 26
                                            spacing: 18

                                            Text { 
                                                text: root.currIcon
                                                font.pixelSize: 58
                                                color: root.themePrimary 
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            
                                            ColumnLayout {
                                                spacing: 6
                                                Layout.alignment: Qt.AlignVCenter
                                                
                                                Text { text: root.currDesc; font.pixelSize: 22; font.weight: Font.Bold; color: root.themeText }
                                                Text { text: "Feels like " + root.currFeel; font.pixelSize: 13; color: root.themeTextMuted }
                                                
                                                RowLayout {
                                                    spacing: 10
                                                    Rectangle {
                                                        radius: 6; color: Qt.alpha("#fb7185", 0.15)
                                                        border.width: 1; border.color: Qt.alpha("#fb7185", 0.35)
                                                        implicitWidth: highTxt.implicitWidth + 16; implicitHeight: 24
                                                        Text { id: highTxt; anchors.centerIn: parent; text: "󰖙 High: " + root.currHigh; font.pixelSize: 11; font.weight: Font.Bold; color: "#fb7185" }
                                                    }
                                                    Rectangle {
                                                        radius: 6; color: Qt.alpha("#38bdf8", 0.15)
                                                        border.width: 1; border.color: Qt.alpha("#38bdf8", 0.35)
                                                        implicitWidth: lowTxt.implicitWidth + 16; implicitHeight: 24
                                                        Text { id: lowTxt; anchors.centerIn: parent; text: "󰖔 Low: " + root.currLow; font.pixelSize: 11; font.weight: Font.Bold; color: "#38bdf8" }
                                                    }
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text { 
                                                text: root.currTemp
                                                font.pixelSize: 62; font.weight: Font.Bold
                                                color: root.themeText
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text { 
                                            text: "󱑂 Hourly Forecast (Next 16 Hours)"
                                            font.pixelSize: 13; font.weight: Font.Bold
                                            color: root.themeText
                                        }

                                        ListView {
                                            id: hourlyList
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 112
                                            orientation: ListView.Horizontal
                                            model: hourlyModel
                                            spacing: 8
                                            clip: true

                                            delegate: Rectangle {
                                                width: 78
                                                height: 112
                                                radius: 12
                                                color: hourlyHover.containsMouse ? root.themeSurfaceHover : (model.time === "Now" ? Qt.alpha(root.themePrimary, 0.09) : root.themeSurface)
                                                border.width: 1
                                                border.color: model.time === "Now" ? Qt.alpha(root.themePrimary, 0.45) : (hourlyHover.containsMouse ? Qt.alpha(root.themeBorder, 0.28) : Qt.alpha(root.themeBorder, 0.12))
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                                MouseArea {
                                                    id: hourlyHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 2

                                                    Text { 
                                                        text: model.time
                                                        font.pixelSize: 11; font.weight: model.time === "Now" ? Font.Bold : Font.Medium
                                                        color: model.time === "Now" ? root.themePrimary : root.themeTextMuted
                                                        Layout.alignment: Qt.AlignHCenter 
                                                    }
                                                    Text { 
                                                        text: model.icon
                                                        font.pixelSize: 22; color: root.themePrimary
                                                        Layout.alignment: Qt.AlignHCenter 
                                                    }
                                                    Text { 
                                                        text: model.temp
                                                        font.pixelSize: 13; font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignHCenter 
                                                    }
                                                    Text { 
                                                        text: model.pop
                                                        font.pixelSize: 10; color: "#38bdf8"
                                                        opacity: model.pop === "0%" ? 0.3 : 1.0
                                                        Layout.alignment: Qt.AlignHCenter 
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 12

                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 14
                                            color: windHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: windHover.containsMouse ? Qt.alpha("#38bdf8", 0.4) : Qt.alpha(root.themeBorder, 0.14)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea { id: windHover; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 18
                                                spacing: 12

                                                Rectangle {
                                                    width: 44; height: 44; radius: 12
                                                    color: Qt.alpha("#38bdf8", 0.12)
                                                    border.width: 1; border.color: Qt.alpha("#38bdf8", 0.28)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text { anchors.centerIn: parent; text: "󰖝"; font.pixelSize: 22; color: "#38bdf8" }
                                                }

                                                Item { Layout.fillWidth: true }

                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 3

                                                    Text { 
                                                        text: "WIND"
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        font.letterSpacing: 1.1
                                                        color: root.themeTextMuted
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: root.currWind
                                                        font.pixelSize: 18; font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: "Gusts: " + root.currWindGust
                                                        font.pixelSize: 11; color: Qt.alpha(root.themeTextMuted, 0.85)
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 14
                                            color: uvHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: uvHover.containsMouse ? Qt.alpha("#facc15", 0.4) : Qt.alpha(root.themeBorder, 0.14)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea { id: uvHover; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 18
                                                spacing: 12

                                                Rectangle {
                                                    width: 44; height: 44; radius: 12
                                                    color: Qt.alpha("#facc15", 0.12)
                                                    border.width: 1; border.color: Qt.alpha("#facc15", 0.28)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text { anchors.centerIn: parent; text: "󰖙"; font.pixelSize: 22; color: "#facc15" }
                                                }

                                                Item { Layout.fillWidth: true }

                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 3

                                                    Text { 
                                                        text: "UV INDEX"
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        font.letterSpacing: 1.1
                                                        color: root.themeTextMuted
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: root.currUV
                                                        font.pixelSize: 18; font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: root.currUVDesc
                                                        font.pixelSize: 11; font.weight: Font.Medium
                                                        color: "#facc15"
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 14
                                            color: humHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: humHover.containsMouse ? Qt.alpha("#a78bfa", 0.4) : Qt.alpha(root.themeBorder, 0.14)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea { id: humHover; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 18
                                                spacing: 12

                                                Rectangle {
                                                    width: 44; height: 44; radius: 12
                                                    color: Qt.alpha("#a78bfa", 0.12)
                                                    border.width: 1; border.color: Qt.alpha("#a78bfa", 0.28)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text { anchors.centerIn: parent; text: "󰖎"; font.pixelSize: 22; color: "#a78bfa" }
                                                }

                                                Item { Layout.fillWidth: true }

                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 3

                                                    Text { 
                                                        text: "HUMIDITY"
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        font.letterSpacing: 1.1
                                                        color: root.themeTextMuted
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: root.currHum
                                                        font.pixelSize: 18; font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: "Relative Dew Point"
                                                        font.pixelSize: 11; color: Qt.alpha(root.themeTextMuted, 0.85)
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 14
                                            color: pressHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: pressHover.containsMouse ? Qt.alpha("#fb923c", 0.4) : Qt.alpha(root.themeBorder, 0.14)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea { id: pressHover; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 18
                                                spacing: 12

                                                Rectangle {
                                                    width: 44; height: 44; radius: 12
                                                    color: Qt.alpha("#fb923c", 0.12)
                                                    border.width: 1; border.color: Qt.alpha("#fb923c", 0.28)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text { anchors.centerIn: parent; text: "󰖜"; font.pixelSize: 22; color: "#fb923c" }
                                                }

                                                Item { Layout.fillWidth: true }

                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 3

                                                    Text { 
                                                        text: "PRESSURE"
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        font.letterSpacing: 1.1
                                                        color: root.themeTextMuted
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: root.currPress
                                                        font.pixelSize: 18; font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: "Barometric Sea Level"
                                                        font.pixelSize: 11; color: Qt.alpha(root.themeTextMuted, 0.85)
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 14
                                            color: cloudsHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: cloudsHover.containsMouse ? Qt.alpha("#38bdf8", 0.4) : Qt.alpha(root.themeBorder, 0.14)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea { id: cloudsHover; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 18
                                                spacing: 12

                                                Rectangle {
                                                    width: 44; height: 44; radius: 12
                                                    color: Qt.alpha("#38bdf8", 0.12)
                                                    border.width: 1; border.color: Qt.alpha("#38bdf8", 0.28)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text { anchors.centerIn: parent; text: "󰅟"; font.pixelSize: 22; color: "#38bdf8" }
                                                }

                                                Item { Layout.fillWidth: true }

                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 3

                                                    Text { 
                                                        text: "CLOUD COVER"
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        font.letterSpacing: 1.1
                                                        color: root.themeTextMuted
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: root.currClouds
                                                        font.pixelSize: 18; font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text { 
                                                        text: "Sky Obscuration"
                                                        font.pixelSize: 11; color: Qt.alpha(root.themeTextMuted, 0.85)
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 14
                                            color: sunHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                            border.width: 1
                                            border.color: sunHover.containsMouse ? Qt.alpha("#f59e0b", 0.4) : Qt.alpha(root.themeBorder, 0.14)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea { id: sunHover; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 18
                                                spacing: 12

                                                Rectangle {
                                                    width: 44; height: 44; radius: 12
                                                    color: Qt.alpha("#f59e0b", 0.12)
                                                    border.width: 1; border.color: Qt.alpha("#f59e0b", 0.28)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text { anchors.centerIn: parent; text: "󰖚"; font.pixelSize: 22; color: "#f59e0b" }
                                                }

                                                Item { Layout.fillWidth: true }

                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 3

                                                    Text { 
                                                        text: "SUN SCHEDULE"
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        font.letterSpacing: 1.1
                                                        color: root.themeTextMuted
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    
                                                    RowLayout {
                                                        Layout.alignment: Qt.AlignRight
                                                        spacing: 8
                                                        
                                                        RowLayout {
                                                            spacing: 3
                                                            Text { text: "󰅶"; font.pixelSize: 12; color: "#f59e0b" }
                                                            Text { text: root.currSunrise; font.pixelSize: 13; font.weight: Font.Bold; color: root.themeText }
                                                        }
                                                        Text { text: "•"; font.pixelSize: 10; color: root.themeTextMuted }
                                                        RowLayout {
                                                            spacing: 3
                                                            Text { text: "󰅔"; font.pixelSize: 12; color: "#f97316" }
                                                            Text { text: root.currSunset; font.pixelSize: 13; font.weight: Font.Bold; color: root.themeText }
                                                        }
                                                    }
                                                    
                                                    Text { 
                                                        text: "Sunrise & Sunset"
                                                        font.pixelSize: 11; color: Qt.alpha(root.themeTextMuted, 0.85)
                                                        Layout.alignment: Qt.AlignRight
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillHeight: true; width: 1; color: Qt.alpha(root.themeBorder, 0.15) }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 450
                                spacing: 10

                                Text { 
                                    text: "󰸗 7-Day Extended Forecast"
                                    font.pixelSize: 15; font.weight: Font.Bold; color: root.themeText
                                    Layout.bottomMargin: 8
                                }

                                ListView {
                                    id: forecastListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: forecastModel
                                    spacing: 8
                                    clip: true
                                    
                                    ScrollBar.vertical: ScrollBar { 
                                        active: forecastListView.moving || forecastListView.flicking
                                        policy: ScrollBar.AsNeeded 
                                    }

                                    delegate: Rectangle {
                                        width: forecastListView.width
                                        height: 62
                                        radius: 12
                                        color: forecastItemHover.containsMouse ? root.themeSurfaceHover : (model.day === "Today" ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.025))
                                        border.width: 1
                                        border.color: forecastItemHover.containsMouse ? Qt.alpha(root.themeBorder, 0.28) : (model.day === "Today" ? Qt.alpha(root.themeBorder, 0.22) : Qt.alpha(root.themeBorder, 0.08))
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        MouseArea {
                                            id: forecastItemHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.preferredWidth: 55
                                                spacing: 2
                                                Layout.alignment: Qt.AlignVCenter
                                                Text { text: model.day; font.pixelSize: 13; font.weight: Font.Bold; color: model.day === "Today" ? root.themePrimary : root.themeText }
                                                Text { text: model.date; font.pixelSize: 10; color: root.themeTextMuted }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 125
                                                spacing: 8
                                                Layout.alignment: Qt.AlignVCenter
                                                Text { text: model.icon; font.pixelSize: 20; color: root.themePrimary; Layout.alignment: Qt.AlignVCenter }
                                                Text { 
                                                    text: model.desc
                                                    font.pixelSize: 12; color: root.themeTextMuted
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true 
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.preferredWidth: 55
                                                spacing: 2
                                                Layout.alignment: Qt.AlignVCenter
                                                RowLayout {
                                                    spacing: 3
                                                    Text { text: "󰖗"; font.pixelSize: 11; color: "#38bdf8"; opacity: model.pop === "0%" ? 0.3 : 1.0 }
                                                    Text { text: model.pop; font.pixelSize: 11; font.weight: Font.Bold; color: root.themeText }
                                                }
                                                Text { text: model.precip; font.pixelSize: 10; color: root.themeTextMuted }
                                            }

                                            Text { 
                                                text: model.min
                                                font.pixelSize: 13; color: root.themeTextMuted
                                                Layout.preferredWidth: 26; horizontalAlignment: Text.AlignRight
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 65
                                                Layout.preferredHeight: 6
                                                radius: 3
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                                Layout.alignment: Qt.AlignVCenter

                                                Rectangle {
                                                    x: parent.width * model.left_ratio
                                                    width: parent.width * model.width_ratio
                                                    height: parent.height
                                                    radius: 3
                                                    color: root.themePrimary
                                                }
                                            }

                                            Text { 
                                                text: model.max
                                                font.pixelSize: 13; font.weight: Font.Bold; color: root.themeText
                                                Layout.preferredWidth: 26
                                                Layout.alignment: Qt.AlignVCenter
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