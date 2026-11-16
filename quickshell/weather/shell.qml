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

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    function quitApp() {
        quitTimer.start()
    }

    Timer {
        id: quitTimer
        interval: 60
        repeat: false
        onTriggered: Qt.quit()
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

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 220

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.56)
    property color themeSurfaceHover: Qt.rgba(0.10, 0.10, 0.14, 0.74)
    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 240) : 200
        property int fadeDuration: 180
        property var smoothEasing: Easing.OutCubic
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
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
                if (rMatch && rMatch[1]) root.themeRounding = Math.max(14, parseInt(rMatch[1]))

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

    property bool isFetching: false
    property bool isFetchingApi: false
    property bool hasData: false
    property string fetchError: ""
    property string activeCityQuery: ""

    property string locName: "Locating..."
    property string currTemp: "--"
    property string currFeel: "--"
    property string currHigh: "--"
    property string currLow: "--"
    property string currDesc: "--"
    property string currIcon: "󰖐"
    property string currWind: "-- km/h"
    property string currWindGust: "-- km/h"
    property string currWindDir: "--"
    property string currHum: "--%"
    property string currDewPoint: "--°C"
    property string currUV: "--"
    property string currUVDesc: "--"
    property string currPress: "-- hPa"
    property string currClouds: "--%"
    property string currSunrise: "--:--"
    property string currSunset: "--:--"

    ListModel { id: hourlyModel }
    ListModel { id: forecastModel }

    function applyWeatherData(d) {
        if (d.error) {
            root.fetchError = d.error
            root.isFetching = false
            root.isFetchingApi = false
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
        root.currWindDir = d.current.wind_dir || "--"
        root.currHum = d.current.humidity
        root.currDewPoint = d.current.dew_point || "--°C"
        root.currUV = d.current.uv
        root.currUVDesc = d.current.uv_desc
        root.currPress = d.current.pressure
        root.currClouds = d.current.clouds
        root.currSunrise = d.current.sunrise
        root.currSunset = d.current.sunset

        hourlyModel.clear()
        if (d.hourly) {
            for (let h = 0; h < d.hourly.length; h++) {
                hourlyModel.append(d.hourly[h])
            }
        }

        forecastModel.clear()
        if (d.daily) {
            for (let i = 0; i < d.daily.length; i++) {
                forecastModel.append(d.daily[i])
            }
        }

        root.hasData = true
        root.isFetching = false
        root.isFetchingApi = false
    }

    FileView {
        id: localCacheReader
        path: "/tmp/qs_weather_cache.json"
        onLoaded: {
            try {
                let d = JSON.parse(text().trim())
                if (d && !d.error && d.current) {
                    root.applyWeatherData(d)
                }
            } catch (e) {}
        }
    }

    Process {
        id: weatherFetcher
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let d = JSON.parse(data.trim())

                    if (d.status === "fetching_api") {
                        root.isFetchingApi = true
                        return
                    }

                    root.applyWeatherData(d)
                } catch (e) {
                    root.isFetching = false
                    root.isFetchingApi = false
                }
            }
        }
    }

    function fetchWeather(city, forceRefresh) {
        weatherFetcher.running = false
        root.isFetching = true
        root.fetchError = ""

        let trimmed = city ? city.trim() : ""
        root.activeCityQuery = trimmed
        let bypassFlag = (trimmed !== "" || forceRefresh === true) ? "1" : "0"

        if (bypassFlag === "1") {
            root.isFetchingApi = true
        } else {
            root.isFetchingApi = false
        }

        let safeQuery = trimmed.replace(/\\/g, "\\\\").replace(/"/g, '\\"')

        let pyScript = `import urllib.request, json, urllib.parse, datetime, os, time, sys, math

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

def get_wind_dir(deg):
    if deg is None: return "--"
    dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    idx = int((float(deg) + 22.5) / 45.0) % 8
    return f"{dirs[idx]} ({int(round(float(deg)))}°)"

def calc_dew_point(temp_c, rh):
    try:
        a, b = 17.625, 243.04
        alpha = math.log(max(1.0, float(rh)) / 100.0) + (a * float(temp_c)) / (b + float(temp_c))
        return f"{round((b * alpha) / (a - alpha))}°C"
    except Exception:
        return "--°C"

try:
    query = "${safeQuery}"
    bypass = "${bypassFlag}" == "1"
    lat, lon, loc_name = None, None, ""

    if not bypass and not query:
        if os.path.exists(CACHE_FILE) and (time.time() - os.path.getmtime(CACHE_FILE)) < CACHE_EXPIRY:
            with open(CACHE_FILE, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content:
                    print(content, flush=True)
                    sys.exit(0)

    print(json.dumps({"status": "fetching_api"}), flush=True)

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
                print(json.dumps({"error": "Location not found. Try another city."}), flush=True)
                sys.exit(0)
    else:
        try:
            req = urllib.request.Request("http://ip-api.com/json/", headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=5) as resp:
                ip_data = json.loads(resp.read().decode())
                lat, lon = ip_data["lat"], ip_data["lon"]
                loc_name = f"{ip_data['city']}, {ip_data.get('country', '')}"
        except Exception:
            req = urllib.request.Request("https://ipapi.co/json/", headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=5) as resp:
                ip_data = json.loads(resp.read().decode())
                lat, lon = ip_data["latitude"], ip_data["longitude"]
                loc_name = f"{ip_data['city']}, {ip_data.get('country_name', '')}"

    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_gusts_10m,wind_direction_10m,surface_pressure,cloud_cover"
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
                "wind_dir": get_wind_dir(c.get('wind_direction_10m')),
                "humidity": f"{c['relative_humidity_2m']}%",
                "dew_point": calc_dew_point(c['temperature_2m'], c['relative_humidity_2m']),
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
                with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                    f.write(out_str)
            except Exception:
                pass

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
        animConfigFile.reload()
        localCacheReader.reload()
        root.fetchWeather("", false)
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

            MouseArea { anchors.fill: parent; onClicked: root.quitApp() }

            Item {
                id: mainFocusWrapper
                anchors.fill: parent
                focus: isTargetMonitor

                Component.onCompleted: {
                    if (isTargetMonitor) forceActiveFocus()
                }

                Keys.onEscapePressed: root.quitApp()

                Rectangle {
                    id: mainCard
                    width: Math.min(1220, parent.width - 40)
                    height: Math.min(820, parent.height - 48)
                    anchors.centerIn: parent

                    property bool shown: false
                    Component.onCompleted: shown = true

                    opacity: shown ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animEnabled ? animStyle.fadeDuration : 0
                            easing.type: animStyle.smoothEasing
                        }
                    }

                    radius: root.themeRounding
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.42)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    antialiasing: true
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.themeBorderSize
                        radius: Math.max(0, parent.radius - root.themeBorderSize)
                        antialiasing: true
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.09) }
                            GradientStop { position: 0.35; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 42
                                height: 42
                                radius: 12
                                color: Qt.alpha(root.themePrimary, 0.16)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.38)
                                Layout.alignment: Qt.AlignVCenter
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖐"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 20
                                    color: root.themePrimary
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: "Weather Telemetry"
                                    font.family: root.fontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: root.themeText
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                }

                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: "󰍎"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 11
                                        color: root.themePrimary
                                    }

                                    Text {
                                        text: root.isFetchingApi ? "Syncing live telemetry..." : root.locName
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: root.themeTextMuted
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.65)
                                    }

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: root.isFetchingApi ? "#facc15" : "#4ade80"
                                        Layout.alignment: Qt.AlignVCenter
                                        antialiasing: true
                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: 270
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Qt.rgba(0.02, 0.02, 0.03, 0.60)
                                border.width: searchInput.activeFocus ? 1.5 : 1
                                border.color: searchInput.activeFocus ? Qt.alpha(root.themePrimary, 0.75) : Qt.rgba(1, 1, 1, 0.14)
                                Layout.alignment: Qt.AlignVCenter
                                antialiasing: true
                                Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "󰍉"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 14
                                        color: searchInput.activeFocus ? root.themePrimary : root.themeTextMuted
                                    }

                                    TextField {
                                        id: searchInput
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: root.themeText
                                        placeholderText: "Search city or region..."
                                        placeholderTextColor: Qt.rgba(1.0, 1.0, 1.0, 0.40)
                                        selectionColor: Qt.alpha(root.themePrimary, 0.35)
                                        selectedTextColor: root.themeText
                                        verticalAlignment: TextInput.AlignVCenter
                                        background: Item {}
                                        onAccepted: {
                                            if (text.trim() !== "") {
                                                root.fetchWeather(text, true)
                                                text = ""
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: searchInput.text !== ""
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: clearSearchHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 11
                                            color: root.themeTextMuted
                                        }

                                        MouseArea {
                                            id: clearSearchHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                searchInput.text = ""
                                                searchInput.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 38
                                height: 38
                                radius: 10
                                color: autoGpsHover.containsMouse
                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.76)
                                       : root.themeSurface
                                border.width: 1
                                border.color: autoGpsHover.containsMouse ? Qt.alpha(root.themePrimary, 0.65) : Qt.rgba(1, 1, 1, 0.14)
                                Layout.alignment: Qt.AlignVCenter
                                antialiasing: true

                                Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                Text {
                                    id: gpsIconText
                                    anchors.centerIn: parent
                                    text: "󰤉"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 16
                                    color: root.themePrimary

                                    RotationAnimator {
                                        target: gpsIconText
                                        from: 0
                                        to: 360
                                        duration: 950
                                        loops: Animation.Infinite
                                        running: root.isFetchingApi
                                    }
                                }

                                MouseArea {
                                    id: autoGpsHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.fetchWeather("", true)
                                }
                            }

                            Rectangle {
                                width: 38
                                height: 38
                                radius: 10
                                color: closeHover.containsMouse
                                       ? Qt.rgba(0.93, 0.26, 0.26, 0.34)
                                       : root.themeSurface
                                border.width: 1
                                border.color: closeHover.containsMouse ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.14)
                                Layout.alignment: Qt.AlignVCenter
                                antialiasing: true

                                Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 14
                                    color: closeHover.containsMouse ? "#ff6b6b" : root.themeText
                                }

                                MouseArea {
                                    id: closeHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.quitApp()
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: opacity > 0
                            opacity: (root.isFetchingApi && !root.hasData) ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: animStyle.fadeDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 16

                                Item {
                                    Layout.preferredWidth: 58
                                    Layout.preferredHeight: 58
                                    Layout.alignment: Qt.AlignHCenter

                                    Canvas {
                                        id: spinnerCanvas
                                        anchors.fill: parent
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            var cx = width / 2
                                            var cy = height / 2
                                            var r = width / 2 - 5

                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, 0, 2 * Math.PI, false)
                                            ctx.lineWidth = 4
                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10)
                                            ctx.stroke()

                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI * 0.6, false)
                                            ctx.lineWidth = 4
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = root.themePrimary
                                            ctx.stroke()
                                        }

                                        RotationAnimator {
                                            target: spinnerCanvas
                                            from: 0
                                            to: 360
                                            duration: 950
                                            loops: Animation.Infinite
                                            running: root.isFetchingApi
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰖐"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 21
                                        color: root.themePrimary
                                    }
                                }

                                Text {
                                    text: "Fetching live weather telemetry..."
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: opacity > 0
                            opacity: (!root.isFetching && root.fetchError !== "") ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: animStyle.fadeDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 56
                                    height: 56
                                    radius: 16
                                    color: Qt.rgba(0.93, 0.26, 0.26, 0.18)
                                    border.width: 1
                                    border.color: "#ff6b6b"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅙"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 26
                                        color: "#ff6b6b"
                                    }
                                }

                                Text {
                                    text: root.fetchError
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    color: "#ff6b6b"
                                    Layout.alignment: Qt.AlignHCenter
                                    font.weight: Font.Bold
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 18
                            visible: opacity > 0
                            opacity: (root.hasData && root.fetchError === "") ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: animStyle.fadeDuration
                                    easing.type: animStyle.smoothEasing
                                }
                            }

                            ColumnLayout {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                Layout.preferredWidth: 660
                                spacing: 14

                                Rectangle {
                                    id: heroCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 152
                                    radius: Math.max(12, root.themeRounding - 4)
                                    color: root.mixColor(root.themeBackground, root.themePrimary, 0.14, 0.68)
                                    border.width: 1
                                    border.color: heroHover.containsMouse
                                                  ? Qt.alpha(root.themePrimary, 0.68)
                                                  : Qt.alpha(root.themePrimary, 0.32)
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: animStyle.fadeDuration
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    MouseArea {
                                        id: heroHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 20
                                        anchors.rightMargin: 24
                                        anchors.topMargin: 16
                                        anchors.bottomMargin: 16
                                        spacing: 18

                                        Rectangle {
                                            width: 78
                                            height: 78
                                            radius: 20
                                            color: Qt.alpha(root.themePrimary, 0.16)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.38)
                                            Layout.alignment: Qt.AlignVCenter
                                            antialiasing: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.currIcon
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 42
                                                color: root.themePrimary
                                            }
                                        }

                                        ColumnLayout {
                                            spacing: 6
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                text: root.currDesc
                                                font.family: root.fontFamily
                                                font.pixelSize: 21
                                                font.weight: Font.Bold
                                                color: root.themeText
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            }

                                            Text {
                                                text: "Feels like " + root.currFeel
                                                font.family: root.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }

                                            RowLayout {
                                                spacing: 8
                                                Layout.topMargin: 2

                                                Rectangle {
                                                    radius: 7
                                                    color: Qt.rgba(0.98, 0.44, 0.52, 0.20)
                                                    border.width: 1
                                                    border.color: Qt.rgba(0.98, 0.44, 0.52, 0.45)
                                                    antialiasing: true
                                                    implicitWidth: highRow.implicitWidth + 16
                                                    implicitHeight: 24

                                                    RowLayout {
                                                        id: highRow
                                                        anchors.centerIn: parent
                                                        spacing: 4

                                                        Text {
                                                            text: "󰁝"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 11
                                                            color: "#fb7185"
                                                        }

                                                        Text {
                                                            text: "High " + root.currHigh
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: "#fb7185"
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    radius: 7
                                                    color: Qt.rgba(0.22, 0.74, 0.97, 0.20)
                                                    border.width: 1
                                                    border.color: Qt.rgba(0.22, 0.74, 0.97, 0.45)
                                                    antialiasing: true
                                                    implicitWidth: lowRow.implicitWidth + 16
                                                    implicitHeight: 24

                                                    RowLayout {
                                                        id: lowRow
                                                        anchors.centerIn: parent
                                                        spacing: 4

                                                        Text {
                                                            text: "󰁅"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 11
                                                            color: "#38bdf8"
                                                        }

                                                        Text {
                                                            text: "Low " + root.currLow
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: "#38bdf8"
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: root.currTemp
                                            font.family: root.fontFamily
                                            font.pixelSize: 56
                                            font.weight: Font.Bold
                                            font.letterSpacing: -2
                                            color: root.themeText
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: "󱑂"
                                            font.family: root.iconFontFamily
                                            font.pixelSize: 12
                                            color: root.themePrimary
                                        }

                                        Text {
                                            text: "HOURLY FORECAST"
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.9
                                            color: root.themeTextMuted
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "Next 16 hours"
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            color: root.themeTextMuted
                                            opacity: 0.75
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 114

                                        ListView {
                                            id: hourlyList
                                            anchors.fill: parent
                                            orientation: ListView.Horizontal
                                            model: hourlyModel
                                            spacing: 8
                                            clip: true
                                            boundsBehavior: Flickable.StopAtBounds

                                            delegate: Rectangle {
                                                width: 78
                                                height: 114
                                                radius: 12
                                                color: model.time === "Now"
                                                       ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.76)
                                                       : (hourlyHover.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                                border.width: 1
                                                border.color: model.time === "Now"
                                                              ? Qt.alpha(root.themePrimary, 0.72)
                                                              : (hourlyHover.containsMouse ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.10))
                                                antialiasing: true

                                                Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                                Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                                MouseArea {
                                                    id: hourlyHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 4

                                                    Text {
                                                        text: model.time
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: model.time === "Now" ? root.themePrimary : root.themeTextMuted
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }

                                                    Text {
                                                        text: model.icon
                                                        font.family: root.iconFontFamily
                                                        font.pixelSize: 21
                                                        color: root.themePrimary
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }

                                                    Text {
                                                        text: model.temp
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 13
                                                        font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.alignment: Qt.AlignHCenter
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                    }

                                                    RowLayout {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        spacing: 3
                                                        opacity: model.pop === "0%" ? 0.38 : 1.0

                                                        Text {
                                                            text: "󰖗"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 9
                                                            color: "#38bdf8"
                                                        }

                                                        Text {
                                                            text: model.pop
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                            color: "#38bdf8"
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            onWheel: (wheel) => {
                                                let maxScroll = Math.max(0, hourlyList.contentWidth - hourlyList.width)
                                                let delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y
                                                hourlyList.contentX = Math.max(0, Math.min(maxScroll, hourlyList.contentX - delta * 0.8))
                                            }
                                        }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    columns: 2
                                    columnSpacing: 12
                                    rowSpacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 96
                                        radius: 13
                                        color: windHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: windHover.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea { id: windHover; anchors.fill: parent; hoverEnabled: true }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 18
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.alpha("#38bdf8", 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha("#38bdf8", 0.35)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰖝"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 21
                                                    color: "#38bdf8"
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "WIND"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }

                                                Text {
                                                    text: root.currWind
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 17
                                                    font.weight: Font.Bold
                                                    color: root.themeText
                                                    Layout.alignment: Qt.AlignRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                }

                                                Text {
                                                    text: "Gusts " + root.currWindGust + " • " + root.currWindDir
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 96
                                        radius: 13
                                        color: uvHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: uvHover.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea { id: uvHover; anchors.fill: parent; hoverEnabled: true }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 18
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.alpha("#facc15", 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha("#facc15", 0.35)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰖙"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 21
                                                    color: "#facc15"
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "UV INDEX"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }

                                                Text {
                                                    text: root.currUV
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 17
                                                    font.weight: Font.Bold
                                                    color: root.themeText
                                                    Layout.alignment: Qt.AlignRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                }

                                                Text {
                                                    text: root.currUVDesc
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: "#facc15"
                                                    Layout.alignment: Qt.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 96
                                        radius: 13
                                        color: humHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: humHover.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea { id: humHover; anchors.fill: parent; hoverEnabled: true }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 18
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.alpha("#a78bfa", 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha("#a78bfa", 0.35)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰖎"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 21
                                                    color: "#a78bfa"
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "HUMIDITY"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }

                                                Text {
                                                    text: root.currHum
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 17
                                                    font.weight: Font.Bold
                                                    color: root.themeText
                                                    Layout.alignment: Qt.AlignRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                }

                                                Text {
                                                    text: "Dew Point " + root.currDewPoint
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 96
                                        radius: 13
                                        color: pressHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: pressHover.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea { id: pressHover; anchors.fill: parent; hoverEnabled: true }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 18
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.alpha("#fb923c", 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha("#fb923c", 0.35)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰡴"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 21
                                                    color: "#fb923c"
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "PRESSURE"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }

                                                Text {
                                                    text: root.currPress
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 17
                                                    font.weight: Font.Bold
                                                    color: root.themeText
                                                    Layout.alignment: Qt.AlignRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                }

                                                Text {
                                                    text: "Surface Barometric"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 96
                                        radius: 13
                                        color: cloudsHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: cloudsHover.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea { id: cloudsHover; anchors.fill: parent; hoverEnabled: true }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 18
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.alpha("#38bdf8", 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha("#38bdf8", 0.35)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅟"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 21
                                                    color: "#38bdf8"
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "CLOUD COVER"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }

                                                Text {
                                                    text: root.currClouds
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 17
                                                    font.weight: Font.Bold
                                                    color: root.themeText
                                                    Layout.alignment: Qt.AlignRight
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                }

                                                Text {
                                                    text: "Sky Coverage"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 96
                                        radius: 13
                                        color: sunHover.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                        border.width: 1
                                        border.color: sunHover.containsMouse ? Qt.alpha(root.themePrimary, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea { id: sunHover; anchors.fill: parent; hoverEnabled: true }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 18
                                            spacing: 12

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.alpha("#f59e0b", 0.16)
                                                border.width: 1
                                                border.color: Qt.alpha("#f59e0b", 0.35)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰖚"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 21
                                                    color: "#f59e0b"
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "SUN SCHEDULE"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignRight
                                                    spacing: 7

                                                    RowLayout {
                                                        spacing: 3
                                                        Text {
                                                            text: "󰅶"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 12
                                                            color: "#f59e0b"
                                                        }
                                                        Text {
                                                            text: root.currSunrise
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 13
                                                            font.weight: Font.Bold
                                                            color: root.themeText
                                                            style: Text.Raised
                                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                        }
                                                    }

                                                    Text {
                                                        text: "•"
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        color: root.themeTextMuted
                                                    }

                                                    RowLayout {
                                                        spacing: 3
                                                        Text {
                                                            text: "󰅔"
                                                            font.family: root.iconFontFamily
                                                            font.pixelSize: 12
                                                            color: "#f97316"
                                                        }
                                                        Text {
                                                            text: root.currSunset
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 13
                                                            font.weight: Font.Bold
                                                            color: root.themeText
                                                            style: Text.Raised
                                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Sunrise & Sunset"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                    Layout.alignment: Qt.AlignRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillHeight: true
                                width: 1
                                color: Qt.rgba(1, 1, 1, 0.10)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 460
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "󰸗"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 12
                                        color: root.themePrimary
                                    }

                                    Text {
                                        text: "7-DAY FORECAST"
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.9
                                        color: root.themeTextMuted
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "Weekly outlook"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: root.themeTextMuted
                                        opacity: 0.75
                                    }
                                }

                                ListView {
                                    id: forecastListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: forecastModel
                                    spacing: 8
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    ScrollBar.vertical: ScrollBar {
                                        id: vbar
                                        visible: forecastListView.visible && vbar.size < 1.0
                                        active: forecastListView.moving || forecastListView.flicking || hovered
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                        }
                                    }

                                    delegate: Rectangle {
                                        width: forecastListView.width - (vbar.visible ? 10 : 0)
                                        height: 64
                                        radius: 12
                                        color: model.day === "Today"
                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.18, 0.74)
                                               : (forecastItemHover.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                        border.width: 1
                                        border.color: model.day === "Today"
                                                      ? Qt.alpha(root.themePrimary, 0.65)
                                                      : (forecastItemHover.containsMouse ? Qt.alpha(root.themePrimary, 0.45) : Qt.rgba(1, 1, 1, 0.10))
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

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
                                                Layout.preferredWidth: 56
                                                spacing: 2
                                                Layout.alignment: Qt.AlignVCenter

                                                Text {
                                                    text: model.day
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: model.day === "Today" ? root.themePrimary : root.themeText
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                }

                                                Text {
                                                    text: model.date
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 126
                                                spacing: 8
                                                Layout.alignment: Qt.AlignVCenter

                                                Text {
                                                    text: model.icon
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 19
                                                    color: root.themePrimary
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                Text {
                                                    text: model.desc
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    color: root.themeText
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.preferredWidth: 58
                                                spacing: 2
                                                Layout.alignment: Qt.AlignVCenter

                                                RowLayout {
                                                    spacing: 3
                                                    Text {
                                                        text: "󰖗"
                                                        font.family: root.iconFontFamily
                                                        font.pixelSize: 10
                                                        color: "#38bdf8"
                                                        opacity: model.pop === "0%" ? 0.38 : 1.0
                                                    }
                                                    Text {
                                                        text: model.pop
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: model.pop === "0%" ? root.themeTextMuted : "#38bdf8"
                                                    }
                                                }

                                                Text {
                                                    text: model.precip
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 9
                                                    font.weight: Font.Medium
                                                    color: root.themeTextMuted
                                                }
                                            }

                                            Text {
                                                text: model.min
                                                font.family: root.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: root.themeTextMuted
                                                Layout.preferredWidth: 28
                                                horizontalAlignment: Text.AlignRight
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 68
                                                Layout.preferredHeight: 6
                                                radius: 3
                                                color: Qt.rgba(1, 1, 1, 0.12)
                                                Layout.alignment: Qt.AlignVCenter
                                                antialiasing: true
                                                clip: true

                                                Rectangle {
                                                    x: parent.width * model.left_ratio
                                                    width: parent.width * model.width_ratio
                                                    height: parent.height
                                                    radius: 3
                                                    antialiasing: true
                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: "#38bdf8" }
                                                        GradientStop { position: 0.5; color: root.themePrimary }
                                                        GradientStop { position: 1.0; color: "#fb7185" }
                                                    }
                                                }
                                            }

                                            Text {
                                                text: model.max
                                                font.family: root.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: root.themeText
                                                Layout.preferredWidth: 28
                                                horizontalAlignment: Text.AlignLeft
                                                Layout.alignment: Qt.AlignVCenter
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.8)
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