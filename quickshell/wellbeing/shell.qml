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
    property color themeBorder: "#d6bbfb"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property color themePrimary: "#d6bbfb"

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

    property real dailyLimit: 14400
    property real todayTotal: 0
    property real maxHistoryTotal: 1
    property int appSwitches: 0
    property string peakHour: "--:--"

    property int selectedDayIndex: -1
    property real selectedTotal: 0
    property var fullData: null

    property var cachedIconMap: ({})
    property var cachedNameMap: ({})

    ListModel { id: appModel }
    ListModel { id: historyModel }

    FileView {
        id: appCacheFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/app_cache.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let raw = text().trim()
                if (!raw) return
                let list = JSON.parse(raw)
                let iMap = {}
                let nMap = {}
                for (let i = 0; i < list.length; i++) {
                    let entry = list[i]
                    let dName = String(entry.displayName || "").trim()
                    let icon = String(entry.iconName || "").trim()
                    let wm = String(entry.wmClass || "").trim().toLowerCase()
                    let fName = String(entry.fileName || "").trim().toLowerCase()
                    if (fName.endsWith(".desktop")) fName = fName.slice(0, -8)

                    if (wm !== "") {
                        if (icon !== "") iMap[wm] = icon
                        if (dName !== "") nMap[wm] = dName
                    }
                    if (fName !== "") {
                        if (icon !== "") iMap[fName] = icon
                        if (dName !== "") nMap[fName] = dName
                    }
                    if (dName !== "") {
                        let dLower = dName.toLowerCase()
                        if (icon !== "") iMap[dLower] = icon
                        nMap[dLower] = dName
                    }
                }
                root.cachedIconMap = iMap
                root.cachedNameMap = nMap
            } catch (e) {}
        }
    }

    function loadAppBreakdown(dayIndex) {
        root.selectedDayIndex = dayIndex
        appModel.clear()
        let sourceApps = []

        if (dayIndex === -1) {
            root.selectedTotal = root.todayTotal
            sourceApps = root.fullData ? root.fullData.today_apps : []
        } else if (root.fullData && root.fullData.history[dayIndex]) {
            root.selectedTotal = root.fullData.history[dayIndex].total
            sourceApps = root.fullData.history[dayIndex].apps || []
        }

        for (let i = 0; i < sourceApps.length; i++) {
            appModel.append(sourceApps[i])
        }
    }

    Process {
        id: dataFetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/wellbeing_aggregator.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim())
                    root.fullData = data
                    root.todayTotal = data.today_total || 0
                    root.appSwitches = data.app_switches || 0
                    root.peakHour = data.peak_hour || "--:--"

                    root.loadAppBreakdown(root.selectedDayIndex)

                    historyModel.clear()
                    let mTotal = 1
                    for (let i = 0; i < data.history.length; i++) {
                        historyModel.append(data.history[i])
                        if (data.history[i].total > mTotal) {
                            mTotal = data.history[i].total
                        }
                    }
                    root.maxHistoryTotal = mTotal
                } catch (e) {}
            }
        }
    }

    Process {
        id: resetDataProcess
        command: ["sqlite3", Quickshell.env("HOME") + "/.local/share/wellbeing/wellbeing.db", "DELETE FROM usage;"]
        running: false
        onExited: {
            root.todayTotal = 0
            root.selectedTotal = 0
            root.appSwitches = 0
            root.peakHour = "--:--"
            root.selectedDayIndex = -1
            appModel.clear()
            dataFetcher.running = false
            dataFetcher.running = true
        }
    }

    function formatTime(secs) {
        if (!secs || secs <= 0) return "0m"
        let totalMins = Math.floor(secs / 60)
        if (totalMins < 1) return "< 1m"
        let h = Math.floor(totalMins / 60)
        let m = totalMins % 60
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function formatPercent(duration, total) {
        if (!total || total <= 0 || !duration || duration <= 0) return "0%"
        let pct = Math.round((duration / total) * 100)
        return (pct < 1 ? "<1" : pct) + "%"
    }

    function formatAppName(appName) {
        if (!appName) return "Unknown"
        let str = appName.trim()
        let lower = str.toLowerCase()

        if (root.cachedNameMap[lower]) return root.cachedNameMap[lower]

        const nameMap = {
            "zen": "Zen Browser",
            "zen-alpha": "Zen Browser",
            "zen-beta": "Zen Browser",
            "zen-browser": "Zen Browser",
            "codium": "VSCodium",
            "vscodium": "VSCodium",
            "code": "VS Code",
            "code-oss": "Code OSS",
            "code - oss": "Code OSS",
            "vscode": "VS Code",
            "visual-studio-code": "VS Code",
            "org.gnome.nautilus": "Files",
            "nautilus": "Files",
            "org.gnome.texteditor": "Text Editor",
            "gnome-text-editor": "Text Editor",
            "texteditor": "Text Editor",
            "text-editor": "Text Editor",
            "gedit": "Gedit",
            "org.gnome.gedit": "Gedit",
            "gcr-prompter": "Authentication Prompt",
            "polkit-gnome-authentication-agent-1": "Authentication Agent",
            "polkit-kde-authentication-agent-1": "Authentication Agent",
            "kitty": "Kitty",
            "wezterm": "WezTerm",
            "org.wezfurlong.wezterm": "WezTerm",
            "alacritty": "Alacritty",
            "foot": "Foot",
            "com.github.wwmm.easyeffects": "EasyEffects",
            "easyeffects": "EasyEffects",
            "org.gnome.calculator": "Calculator",
            "calculator": "Calculator",
            "gnome-calculator": "Calculator",
            "org.gnome.calendar": "Calendar",
            "calendar": "Calendar",
            "gnome-calendar": "Calendar",
            "org.gnome.systemmonitor": "System Monitor",
            "gnome-system-monitor": "System Monitor",
            "system-monitor": "System Monitor",
            "systemmonitor": "System Monitor",
            "org.gnome.loupe": "Image Viewer",
            "loupe": "Image Viewer",
            "org.gnome.papers": "Document Viewer",
            "papers": "Document Viewer",
            "org.gnome.settings": "Settings",
            "gnome-control-center": "Settings",
            "settings": "Settings",
            "org.gnome.software": "Software",
            "gnome-software": "Software",
            "software": "Software",
            "org.gnome.terminal": "Terminal",
            "gnome-terminal": "Terminal",
            "org.gnome.ptyxis": "Terminal",
            "ptyxis": "Terminal",
            "org.gnome.boxes": "Boxes",
            "gnome-boxes": "Boxes",
            "org.gnome.diskutility": "Disks",
            "gnome-disks": "Disks",
            "disks": "Disks",
            "pavucontrol": "Volume Control",
            "org.pulseaudio.pavucontrol": "Volume Control",
            "google-chrome": "Google Chrome",
            "google-chrome-stable": "Google Chrome",
            "chromium": "Chromium",
            "firefox": "Firefox",
            "firefox-esr": "Firefox",
            "brave-browser": "Brave Browser",
            "brave": "Brave Browser",
            "discord": "Discord",
            "vesktop": "Vesktop",
            "webcord": "WebCord",
            "spotify": "Spotify",
            "slack": "Slack",
            "telegramdesktop": "Telegram",
            "org.telegram.desktop": "Telegram",
            "obsidian": "Obsidian",
            "wireshark": "Wireshark",
            "org.wireshark.wireshark": "Wireshark",
            "burp-startburp": "Burp Suite",
            "burpsuite": "Burp Suite",
            "virtualbox": "VirtualBox",
            "virtualbox manager": "VirtualBox",
            "virtualbox machine": "VirtualBox VM",
            "virtualboxvm": "VirtualBox VM",
            "virtual box vm": "VirtualBox VM",
            "mpv": "MPV",
            "vlc": "VLC",
            "gimp": "GIMP",
            "inkscape": "Inkscape",
            "baobab": "Disk Usage Analyzer",
            "org.gnome.baobab": "Disk Usage Analyzer",
            "gparted": "GParted",
            "gpartedbin": "GParted",
            "qt5ct": "Qt5 Settings",
            "qt6ct": "Qt6 Settings",
            "nwg-look": "GTK Settings",
            "legionaura": "Legion Aura",
            "nvidia-settings": "NVIDIA Settings",
            "org.gnome.powerstats": "Power Statistics",
            "gnome-power-statistics": "Power Statistics",
            "power stats": "Power Statistics",
            "powerstats": "Power Statistics",
            "blueman-manager": "Bluetooth Manager",
            "blueman-adapters": "Bluetooth Adapters",
            "blueman manager": "Bluetooth Manager",
            "xdg-desktop-portal-gtk": "File Chooser Portal",
            "xdg desktop portal gtk": "File Chooser Portal",
            "xdg-desktop-portal-gnome": "GNOME Portal",
            "xdg-desktop-portal-hyprland": "Hyprland Portal",
            "xdg-desktop-portal": "Desktop Portal"
        }

        if (nameMap[lower]) return nameMap[lower]

        if (lower.indexOf("virtualbox") !== -1 || lower.indexOf("vbox") !== -1) {
            if (lower.indexOf("vm") !== -1 || lower.indexOf("machine") !== -1) return "VirtualBox VM"
            return "VirtualBox"
        }
        if (lower.indexOf("portal") !== -1) {
            if (lower.indexOf("gtk") !== -1) return "File Chooser Portal"
            return "Desktop Portal"
        }
        if (lower.indexOf("baobab") !== -1) return "Disk Usage Analyzer"
        if (lower.indexOf("ptyxis") !== -1) return "Terminal"
        if (lower.indexOf("gparted") !== -1) return "GParted"
        if (lower.indexOf("powerstats") !== -1 || lower.indexOf("power stats") !== -1) return "Power Statistics"
        if (lower.indexOf("blueman") !== -1) return "Bluetooth Manager"
        if (lower.indexOf("nvidia") !== -1) return "NVIDIA Settings"
        if (lower.indexOf("qt5ct") !== -1) return "Qt5 Settings"
        if (lower.indexOf("qt6ct") !== -1) return "Qt6 Settings"
        if (lower.indexOf("nwg-look") !== -1) return "GTK Settings"
        if (lower.indexOf("legionaura") !== -1) return "Legion Aura"

        let parts = str.split(".")
        let base = parts[parts.length - 1]
        if (!base && parts.length > 1) base = parts[parts.length - 2]
        if (!base) base = str

        base = base.replace(/([a-z])([A-Z])/g, "$1 $2")
        base = base.replace(/[-_]+/g, " ")

        let words = base.trim().split(/\s+/)
        return words.map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")
    }

    function getSysIcon(appName) {
        if (!appName) return ""
        let str = appName.trim()
        let lower = str.toLowerCase()

        if (root.cachedIconMap[lower]) return root.cachedIconMap[lower]
        let formattedLower = root.formatAppName(str).toLowerCase()
        if (root.cachedIconMap[formattedLower]) return root.cachedIconMap[formattedLower]

        const iconMap = {
            "zen": "zen-browser",
            "zen-alpha": "zen-browser",
            "zen-beta": "zen-browser",
            "zen-browser": "zen-browser",
            "codium": "vscodium",
            "vscodium": "vscodium",
            "code": "vscodium",
            "code-oss": "vscodium",
            "code - oss": "vscodium",
            "vscode": "visual-studio-code",
            "visual-studio-code": "visual-studio-code",
            "nautilus": "org.gnome.Nautilus",
            "org.gnome.nautilus": "org.gnome.Nautilus",
            "org.gnome.texteditor": "org.gnome.TextEditor",
            "gnome-text-editor": "org.gnome.TextEditor",
            "texteditor": "org.gnome.TextEditor",
            "text-editor": "org.gnome.TextEditor",
            "gedit": "org.gnome.gedit",
            "org.gnome.gedit": "org.gnome.gedit",
            "gcr-prompter": "dialog-password",
            "polkit-gnome-authentication-agent-1": "dialog-password",
            "polkit-kde-authentication-agent-1": "dialog-password",
            "kitty": "kitty",
            "wezterm": "org.wezfurlong.wezterm",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "alacritty": "Alacritty",
            "foot": "foot",
            "easyeffects": "com.github.wwmm.easyeffects",
            "com.github.wwmm.easyeffects": "com.github.wwmm.easyeffects",
            "calculator": "org.gnome.Calculator",
            "org.gnome.calculator": "org.gnome.Calculator",
            "gnome-calculator": "org.gnome.Calculator",
            "calendar": "org.gnome.Calendar",
            "org.gnome.calendar": "org.gnome.Calendar",
            "gnome-calendar": "org.gnome.Calendar",
            "system-monitor": "org.gnome.SystemMonitor",
            "systemmonitor": "org.gnome.SystemMonitor",
            "org.gnome.systemmonitor": "org.gnome.SystemMonitor",
            "gnome-system-monitor": "org.gnome.SystemMonitor",
            "loupe": "org.gnome.Loupe",
            "org.gnome.loupe": "org.gnome.Loupe",
            "papers": "org.gnome.Papers",
            "org.gnome.papers": "org.gnome.Papers",
            "settings": "org.gnome.Settings",
            "org.gnome.settings": "org.gnome.Settings",
            "gnome-control-center": "org.gnome.Settings",
            "software": "org.gnome.Software",
            "org.gnome.software": "org.gnome.Software",
            "gnome-software": "org.gnome.Software",
            "terminal": "org.gnome.Ptyxis",
            "org.gnome.terminal": "org.gnome.Ptyxis",
            "gnome-terminal": "org.gnome.Ptyxis",
            "ptyxis": "org.gnome.Ptyxis",
            "org.gnome.ptyxis": "org.gnome.Ptyxis",
            "boxes": "org.gnome.Boxes",
            "org.gnome.boxes": "org.gnome.Boxes",
            "disks": "org.gnome.DiskUtility",
            "org.gnome.diskutility": "org.gnome.DiskUtility",
            "gnome-disks": "org.gnome.DiskUtility",
            "pavucontrol": "org.pulseaudio.pavucontrol",
            "org.pulseaudio.pavucontrol": "org.pulseaudio.pavucontrol",
            "virtualbox": "virtualbox",
            "virtualbox manager": "virtualbox",
            "virtualbox machine": "virtualbox",
            "virtualboxvm": "virtualbox",
            "virtual box vm": "virtualbox",
            "google-chrome": "google-chrome",
            "google-chrome-stable": "google-chrome",
            "firefox": "firefox",
            "firefox-esr": "firefox",
            "brave-browser": "brave-browser",
            "brave": "brave-browser",
            "discord": "discord",
            "vesktop": "vesktop",
            "spotify": "spotify",
            "obsidian": "obsidian",
            "wireshark": "wireshark",
            "org.wireshark.wireshark": "wireshark",
            "baobab": "org.gnome.baobab",
            "org.gnome.baobab": "org.gnome.baobab",
            "gparted": "gparted",
            "gpartedbin": "gparted",
            "qt5ct": "qt5ct",
            "qt6ct": "qt6ct",
            "nwg-look": "nwg-look",
            "legionaura": "preferences-desktop-keyboard",
            "nvidia-settings": "nvidia-settings",
            "org.gnome.powerstats": "org.gnome.PowerStats",
            "gnome-power-statistics": "org.gnome.PowerStats",
            "power stats": "org.gnome.PowerStats",
            "powerstats": "org.gnome.PowerStats",
            "blueman-manager": "blueman",
            "blueman-adapters": "blueman",
            "blueman manager": "blueman",
            "xdg-desktop-portal-gtk": "preferences-system",
            "xdg desktop portal gtk": "preferences-system",
            "xdg-desktop-portal-gnome": "preferences-system",
            "xdg-desktop-portal-hyprland": "preferences-system",
            "xdg-desktop-portal": "preferences-system"
        }

        if (iconMap[lower]) return iconMap[lower]
        if (lower.indexOf("code") !== -1 || lower.indexOf("codium") !== -1) return "vscodium"
        if (lower.indexOf("virtualbox") !== -1 || lower.indexOf("vbox") !== -1) return "virtualbox"
        if (lower.indexOf("portal") !== -1) return "preferences-system"
        if (lower.indexOf("baobab") !== -1) return "org.gnome.baobab"
        if (lower.indexOf("gparted") !== -1) return "gparted"
        if (lower.indexOf("powerstats") !== -1 || lower.indexOf("power stats") !== -1) return "org.gnome.PowerStats"
        if (lower.indexOf("blueman") !== -1 || lower.indexOf("bluetooth") !== -1) return "blueman"
        if (lower.indexOf("nvidia") !== -1) return "nvidia-settings"
        if (lower.indexOf("ptyxis") !== -1) return "org.gnome.Ptyxis"
        if (lower.indexOf("qt5ct") !== -1) return "qt5ct"
        if (lower.indexOf("qt6ct") !== -1) return "qt6ct"
        if (lower.indexOf("nwg-look") !== -1) return "nwg-look"
        if (lower.indexOf("legionaura") !== -1) return "preferences-desktop-keyboard"

        if (str.indexOf(".") !== -1) return str
        return lower.replace(/\s+/g, "-")
    }

    function getFallbackGlyph(appName) {
        let lower = (appName || "").toLowerCase()
        if (lower.indexOf("code") !== -1 || lower.indexOf("codium") !== -1) return "󰨞"
        if (lower.indexOf("zen") !== -1 || lower.indexOf("firefox") !== -1 || lower.indexOf("chrome") !== -1 || lower.indexOf("brave") !== -1) return "󰈹"
        if (lower.indexOf("kitty") !== -1 || lower.indexOf("term") !== -1 || lower.indexOf("ptyxis") !== -1 || lower.indexOf("foot") !== -1) return "󰞷"
        if (lower.indexOf("nautilus") !== -1 || lower.indexOf("files") !== -1) return "󰉋"
        if (lower.indexOf("virtualbox") !== -1 || lower.indexOf("vbox") !== -1) return "󰢹"
        if (lower.indexOf("spotify") !== -1 || lower.indexOf("music") !== -1 || lower.indexOf("vlc") !== -1 || lower.indexOf("mpv") !== -1) return "󰓇"
        if (lower.indexOf("discord") !== -1 || lower.indexOf("vesktop") !== -1 || lower.indexOf("telegram") !== -1) return "󰙯"
        if (lower.indexOf("settings") !== -1 || lower.indexOf("control") !== -1) return "󰒓"
        return "󰀻"
    }

    function resolveIconSource(iconVal) {
        if (!iconVal || iconVal === "") return ""
        if (iconVal.startsWith("/")) return "file://" + iconVal
        if (iconVal.startsWith("file://")) return iconVal
        return "image://icon/" + iconVal
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
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
                }
                let bgMatch = content.match(/background\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/background\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (bgMatch && bgMatch[1]) root.themeBackground = "#" + bgMatch[1]
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

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }
        appCacheFile.reload()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: selectorWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-wellbeing"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            Shortcut {
                sequence: "Escape"
                onActivated: root.quitApp()
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: root.quitApp()
            }

            Rectangle {
                id: mainCard
                width: Math.min(980, parent.width - 48)
                height: Math.min(680, parent.height - 80)
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.42)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                antialiasing: true
                clip: true

                property bool shown: false
                Component.onCompleted: shown = true

                opacity: shown ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

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

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 11
                            color: Qt.alpha(root.themePrimary, 0.16)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.38)
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                text: "󰓏"
                                font.family: root.iconFontFamily
                                font.pixelSize: 19
                                color: root.themePrimary
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Digital Wellbeing"
                                font.family: root.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: root.themeText
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                            }

                            Text {
                                text: "Screen time & application activity"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.themeTextMuted
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: goalRow.implicitWidth + 20
                            Layout.preferredHeight: 32
                            radius: 9
                            color: Qt.alpha(root.themePrimary, 0.14)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.35)
                            antialiasing: true

                            RowLayout {
                                id: goalRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰥔"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 13
                                    color: root.themePrimary
                                }

                                Text {
                                    text: "Daily Goal: " + root.formatTime(root.dailyLimit)
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: root.themePrimary
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        ColumnLayout {
                            Layout.preferredWidth: 344
                            Layout.minimumWidth: 344
                            Layout.maximumWidth: 344
                            Layout.fillHeight: true
                            spacing: 16

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 266
                                radius: Math.max(12, root.themeRounding - 4)
                                color: root.themeSurface
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                antialiasing: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "TODAY'S SCREEN TIME"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.9
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            Layout.preferredWidth: statusBadgeText.implicitWidth + 14
                                            Layout.preferredHeight: 20
                                            radius: 6
                                            color: root.todayTotal > root.dailyLimit
                                                   ? Qt.rgba(0.93, 0.26, 0.26, 0.22)
                                                   : Qt.alpha(root.themePrimary, 0.18)
                                            border.width: 1
                                            border.color: root.todayTotal > root.dailyLimit
                                                          ? "#ff6b6b"
                                                          : Qt.alpha(root.themePrimary, 0.42)

                                            Text {
                                                id: statusBadgeText
                                                anchors.centerIn: parent
                                                text: root.todayTotal > root.dailyLimit ? "Over Limit" : "On Track"
                                                color: root.todayTotal > root.dailyLimit ? "#ff6b6b" : root.themePrimary
                                                font.family: root.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 8

                                        Text {
                                            text: root.formatTime(root.todayTotal)
                                            color: root.todayTotal > root.dailyLimit ? "#ff6b6b" : root.themePrimary
                                            font.family: root.fontFamily
                                            font.pixelSize: 42
                                            font.weight: Font.Bold
                                            Layout.alignment: Qt.AlignHCenter
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.65)
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 210
                                            height: 7
                                            radius: 3.5
                                            color: Qt.rgba(1, 1, 1, 0.10)
                                            clip: true

                                            Rectangle {
                                                width: root.todayTotal > 0 ? Math.min(parent.width, parent.width * (root.todayTotal / root.dailyLimit)) : 0
                                                height: parent.height
                                                radius: 3.5
                                                color: root.todayTotal > root.dailyLimit ? "#ff6b6b" : root.themePrimary
                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: root.animEnabled ? 420 : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: root.formatPercent(root.todayTotal, root.dailyLimit) + " of daily goal"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 62
                                        radius: 12
                                        color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.09)
                                        antialiasing: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 1
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "App Switches"
                                                    color: root.themeTextMuted
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    Layout.alignment: Qt.AlignHCenter
                                                }

                                                Text {
                                                    text: root.appSwitches.toString()
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 1
                                                Layout.preferredHeight: 34
                                                Layout.alignment: Qt.AlignVCenter
                                                color: Qt.rgba(1, 1, 1, 0.14)
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 1
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    text: "Peak Hour"
                                                    color: root.themeTextMuted
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    Layout.alignment: Qt.AlignHCenter
                                                }

                                                Text {
                                                    text: root.peakHour
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Math.max(12, root.themeRounding - 4)
                                color: root.themeSurface
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                antialiasing: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "PAST 7 DAYS"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.9
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "Click bar to filter"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            opacity: 0.75
                                        }
                                    }

                                    RowLayout {
                                        id: barsRow
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8

                                        Repeater {
                                            model: historyModel
                                            Item {
                                                id: barColItem
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                property bool isBarSelected: root.selectedDayIndex === index
                                                property bool isBarHovered: barMouse.containsMouse

                                                Rectangle {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: dayLabel.top
                                                    anchors.bottomMargin: 8
                                                    width: 26
                                                    height: Math.max(0, barColItem.height - 28)
                                                    radius: 6
                                                    color: Qt.rgba(1, 1, 1, 0.04)
                                                }

                                                Rectangle {
                                                    id: barRect
                                                    width: 26
                                                    property real maxBarH: Math.max(0, barColItem.height - 28)
                                                    property real targetHeight: model.total > 0 ? Math.max(6, (model.total / root.maxHistoryTotal) * maxBarH) : 4
                                                    height: mainCard.shown ? targetHeight : 0
                                                    anchors.bottom: dayLabel.top
                                                    anchors.bottomMargin: 8
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: barColItem.isBarSelected
                                                           ? "#ffffff"
                                                           : (barColItem.isBarHovered ? Qt.lighter(root.themePrimary, 1.1) : root.themePrimary)
                                                    radius: 6
                                                    opacity: barColItem.isBarSelected || barColItem.isBarHovered ? 1.0 : (model.total > 0 ? 0.78 : 0.25)
                                                    antialiasing: true

                                                    Behavior on height {
                                                        NumberAnimation {
                                                            duration: root.animEnabled ? 380 : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: animStyle.fadeDuration
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: animStyle.fadeDuration
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                }

                                                Text {
                                                    id: dayLabel
                                                    text: model.day
                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: barColItem.isBarSelected ? root.themePrimary : root.themeTextMuted
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: barColItem.isBarSelected ? Font.Bold : Font.Medium
                                                }

                                                MouseArea {
                                                    id: barMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.loadAppBreakdown(root.selectedDayIndex === index ? -1 : index)
                                                    }
                                                }

                                                Rectangle {
                                                    id: barTooltip
                                                    visible: barMouse.containsMouse && model.total > 0
                                                    width: Math.max(tooltipLayout.implicitWidth + 22, 110)
                                                    height: tooltipLayout.implicitHeight + 14
                                                    anchors.bottom: barRect.top
                                                    anchors.bottomMargin: 8
                                                    x: Math.max(-barColItem.x, Math.min((barColItem.width - width) / 2, barsRow.width - barColItem.x - width))
                                                    color: Qt.rgba(0.05, 0.05, 0.07, 0.94)
                                                    radius: 9
                                                    border.width: 1
                                                    border.color: Qt.alpha(root.themePrimary, 0.55)
                                                    z: 20
                                                    antialiasing: true

                                                    ColumnLayout {
                                                        id: tooltipLayout
                                                        anchors.centerIn: parent
                                                        spacing: 3

                                                        Text {
                                                            text: root.formatTime(model.total)
                                                            color: root.themePrimary
                                                            font.family: root.fontFamily
                                                            font.pixelSize: 12
                                                            font.weight: Font.Bold
                                                            Layout.alignment: Qt.AlignHCenter
                                                        }

                                                        RowLayout {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            spacing: 5
                                                            visible: model.top_app !== ""

                                                            Item {
                                                                width: 14
                                                                height: 14
                                                                Layout.alignment: Qt.AlignVCenter

                                                                Image {
                                                                    id: tooltipIcon
                                                                    anchors.fill: parent
                                                                    property string resolvedSrc: model.top_app ? root.resolveIconSource(root.getSysIcon(model.top_app)) : ""
                                                                    source: resolvedSrc
                                                                    sourceSize: Qt.size(28, 28)
                                                                    fillMode: Image.PreserveAspectFit
                                                                    smooth: true
                                                                    asynchronous: true
                                                                    visible: status === Image.Ready
                                                                }

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    visible: tooltipIcon.status !== Image.Ready
                                                                    text: root.getFallbackGlyph(model.top_app)
                                                                    font.family: root.iconFontFamily
                                                                    font.pixelSize: 12
                                                                    color: root.themePrimary
                                                                }
                                                            }

                                                            Text {
                                                                text: root.formatAppName(model.top_app)
                                                                color: root.themeText
                                                                font.family: root.fontFamily
                                                                font.pixelSize: 10
                                                                font.weight: Font.Medium
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 300
                            Layout.fillHeight: true
                            radius: Math.max(12, root.themeRounding - 4)
                            color: root.themeSurface
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            clip: true
                            antialiasing: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.selectedDayIndex === -1
                                              ? "APP USAGE BREAKDOWN"
                                              : ("BREAKDOWN • " + historyModel.get(root.selectedDayIndex).day.toUpperCase())
                                        color: root.selectedDayIndex === -1 ? root.themeTextMuted : root.themePrimary
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.9
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        visible: root.selectedDayIndex !== -1
                                        Layout.preferredWidth: backBtnText.implicitWidth + 16
                                        Layout.preferredHeight: 24
                                        radius: 7
                                        color: backBtnMouse.containsMouse
                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.25, 0.8)
                                               : Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.45)
                                        antialiasing: true

                                        Text {
                                            id: backBtnText
                                            anchors.centerIn: parent
                                            text: "Today"
                                            color: root.themeText
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: backBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.loadAppBreakdown(-1)
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: appModel.count === 0

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 10

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 52
                                            height: 52
                                            radius: 15
                                            color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.28)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰓏"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 22
                                                color: root.themePrimary
                                                opacity: 0.75
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "No activity recorded"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                ListView {
                                    id: appList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: appModel.count > 0
                                    spacing: 8
                                    model: appModel
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    ScrollBar.vertical: ScrollBar {
                                        id: vbar
                                        visible: appList.visible && vbar.size < 1.0
                                        active: appList.moving || appList.flicking || hovered
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                        }
                                    }

                                    delegate: Item {
                                        width: appList.width - (vbar.visible ? 10 : 0)
                                        height: 56

                                        MouseArea {
                                            id: appMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 11
                                            color: appMouse.containsMouse
                                                   ? Qt.rgba(1, 1, 1, 0.07)
                                                   : Qt.rgba(0.02, 0.02, 0.03, 0.45)
                                            border.width: 1
                                            border.color: appMouse.containsMouse
                                                          ? Qt.alpha(root.themePrimary, 0.45)
                                                          : Qt.rgba(1, 1, 1, 0.08)
                                            antialiasing: true
                                            clip: true

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                            Behavior on border.color {
                                                ColorAnimation {
                                                    duration: animStyle.fadeDuration
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: root.selectedTotal > 0 ? parent.width * Math.min(1.0, model.duration / root.selectedTotal) : 0
                                                color: Qt.alpha(root.themePrimary, 0.16)
                                                antialiasing: true
                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: root.animEnabled ? 420 : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 14
                                                spacing: 12

                                                Rectangle {
                                                    width: 36
                                                    height: 36
                                                    radius: 9
                                                    color: Qt.rgba(1, 1, 1, 0.07)
                                                    border.width: 1
                                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    antialiasing: true

                                                    Image {
                                                        id: appIcon
                                                        anchors.centerIn: parent
                                                        width: 24
                                                        height: 24
                                                        property string resolvedSrc: root.resolveIconSource(root.getSysIcon(model.app))
                                                        source: resolvedSrc
                                                        sourceSize: Qt.size(48, 48)
                                                        fillMode: Image.PreserveAspectFit
                                                        smooth: true
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: appIcon.status !== Image.Ready
                                                        text: root.getFallbackGlyph(model.app)
                                                        font.family: root.iconFontFamily
                                                        font.pixelSize: 17
                                                        color: root.themePrimary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        text: root.formatAppName(model.app)
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 13
                                                        font.weight: Font.Bold
                                                        color: root.themeText
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                    }

                                                    Text {
                                                        text: root.formatPercent(model.duration, root.selectedTotal) + " of active time"
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: root.themeTextMuted
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Text {
                                                    text: root.formatTime(model.duration)
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: root.themePrimary
                                                    Layout.alignment: Qt.AlignVCenter
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        radius: 10
                        antialiasing: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                text: "󰆼"
                                font.family: root.iconFontFamily
                                font.pixelSize: 13
                                color: root.themePrimary
                            }

                            Text {
                                text: "Local SQLite Wellbeing Database"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.themeTextMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: clearText.implicitWidth + 18
                                    Layout.preferredHeight: 24
                                    radius: 7
                                    color: clearMouse.containsMouse
                                           ? Qt.rgba(0.93, 0.26, 0.26, 0.32)
                                           : Qt.rgba(0.93, 0.26, 0.26, 0.18)
                                    border.width: 1
                                    border.color: "#ff6b6b"
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: animStyle.fadeDuration
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Text {
                                        id: clearText
                                        anchors.centerIn: parent
                                        text: "Clear Data"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: "#ff6b6b"
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: resetDataProcess.running = true
                                    }
                                }

                                Rectangle {
                                    width: 34
                                    height: 24
                                    radius: 7
                                    color: Qt.alpha(root.themePrimary, 0.16)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.40)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ESC"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: root.themePrimary
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    text: "Close"
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: root.themeTextMuted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}