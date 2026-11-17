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

    property bool animEnabled: true
    property int animDuration: 220
    property bool isClosing: false

    QtObject {
        id: animStyle
        property int base: root.animDuration > 0 ? Math.min(root.animDuration, 260) : 220
        property int enterDuration: Math.round(base * 1.35)
        property int exitDuration: Math.round(base * 0.85)
        property int animDuration: base
        property int morphDuration: Math.round(base * 1.25)
        property int barDuration: Math.round(base * 2.0)
        property int fadeDuration: Math.round(base * 0.8)
        property int microDuration: Math.round(base * 0.65)
        property int scaleDuration: Math.round(base * 1.1)
        property var smoothEasing: Easing.OutQuint
        property var expoEasing: Easing.OutExpo
        property var exitEasing: Easing.InCubic
    }

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        dataFetcher.running = false
        resetDataProcess.running = false
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

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.68)
    property color themeSurfaceHover: Qt.rgba(0.08, 0.08, 0.12, 0.78)
    property color themeBorder: "#d6bbfb"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"
    property color themePrimary: "#d6bbfb"

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
                if (root.isClosing) return
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
            if (root.isClosing) return
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

    function clipRoundedRect(ctx, x, y, w, h, r) {
        r = Math.min(r, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y, x + w, y + r, r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x, y + h, x, y + h - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
        ctx.clip()
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

            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

            mask: Region { item: mainCard }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Rectangle {
                id: mainCard
                width: Math.min(980, parent.width - 48)
                height: Math.min(680, parent.height - 80)
                anchors.centerIn: parent
                enabled: !root.isClosing

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.4)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                antialiasing: true
                clip: true

                property bool shown: false
                property bool panelVisible: shown && !root.isClosing
                Component.onCompleted: enterTriggerTimer.start()

                Timer {
                    id: enterTriggerTimer
                    interval: 16
                    repeat: false
                    onTriggered: mainCard.shown = true
                }

                opacity: panelVisible ? 1.0 : 0.0

                transform: [
                    Scale {
                        origin.x: mainCard.width / 2
                        origin.y: mainCard.height / 2
                        xScale: mainCard.panelVisible ? 1.0 : 0.94
                        yScale: mainCard.panelVisible ? 1.0 : 0.94

                        Behavior on xScale {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                        Behavior on yScale {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                    },
                    Translate {
                        y: mainCard.panelVisible ? 0 : 14

                        Behavior on y {
                            NumberAnimation {
                                duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.enterDuration : 0
                                easing.type: animStyle.expoEasing
                            }
                        }
                    }
                ]

                Behavior on opacity {
                    NumberAnimation {
                        duration: (root.animEnabled && !root.isClosing && mainCard.panelVisible) ? animStyle.fadeDuration : 0
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
                            radius: headerIconMouse.containsMouse ? 13 : 11
                            color: Qt.alpha(root.themePrimary, headerIconMouse.containsMouse ? 0.24 : 0.18)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, headerIconMouse.containsMouse ? 0.65 : 0.35)
                            antialiasing: true
                            scale: headerIconMouse.containsMouse ? 1.05 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                            Behavior on radius {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
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
                                anchors.centerIn: parent
                                text: "󰓏"
                                font.family: root.iconFontFamily
                                font.pixelSize: 19
                                color: root.themePrimary
                            }

                            MouseArea {
                                id: headerIconMouse
                                anchors.fill: parent
                                hoverEnabled: true
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
                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                            }

                            Text {
                                text: "Screen time & application activity"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.themeTextMuted
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: goalRow.implicitWidth + 20
                            Layout.preferredHeight: 32
                            radius: 9
                            color: Qt.alpha(root.themePrimary, goalMouse.containsMouse ? 0.24 : 0.18)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, goalMouse.containsMouse ? 0.60 : 0.35)
                            antialiasing: true
                            scale: goalMouse.containsMouse ? 1.03 : 1.0

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

                            RowLayout {
                                id: goalRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰥔"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 13
                                    color: root.themePrimary
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }

                                Text {
                                    text: "Daily Goal: " + root.formatTime(root.dailyLimit)
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: root.themePrimary
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }
                            }

                            MouseArea {
                                id: goalMouse
                                anchors.fill: parent
                                hoverEnabled: true
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
                                radius: Math.max(10, root.themeRounding - 6)
                                color: todayCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                border.width: 1
                                border.color: todayCardHover.hovered ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                antialiasing: true

                                HoverHandler { id: todayCardHover }

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
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
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
                                                          : Qt.alpha(root.themePrimary, 0.40)
                                            antialiasing: true

                                            Behavior on Layout.preferredWidth {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.animDuration : 0
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
                                                id: statusBadgeText
                                                anchors.centerIn: parent
                                                text: root.todayTotal > root.dailyLimit ? "Over Limit" : "On Track"
                                                color: root.todayTotal > root.dailyLimit ? "#ff6b6b" : root.themePrimary
                                                font.family: root.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
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
                                            styleColor: Qt.rgba(0, 0, 0, 0.85)
                                            scale: mainCard.shown ? 1.0 : 0.92

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.enterDuration : 0
                                                    easing.type: animStyle.expoEasing
                                                }
                                            }
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 210
                                            height: 7
                                            radius: 3.5
                                            color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                                            antialiasing: true

                                            Canvas {
                                                id: goalBarCanvas
                                                anchors.fill: parent
                                                antialiasing: true

                                                property real targetRatio: root.todayTotal > 0 ? Math.min(1.0, root.todayTotal / root.dailyLimit) : 0
                                                property real animRatio: mainCard.shown ? targetRatio : 0
                                                property color barColor: root.todayTotal > root.dailyLimit ? "#ff6b6b" : root.themePrimary

                                                Behavior on animRatio {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.barDuration : 0
                                                        easing.type: animStyle.expoEasing
                                                    }
                                                }
                                                Behavior on barColor {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }

                                                onAnimRatioChanged: requestPaint()
                                                onBarColorChanged: requestPaint()
                                                onWidthChanged: requestPaint()
                                                onHeightChanged: requestPaint()
                                                onAvailableChanged: if (available) requestPaint()

                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    if (animRatio <= 0 || width <= 0 || height <= 0) return
                                                    ctx.save()
                                                    root.clipRoundedRect(ctx, 0, 0, width, height, 3.5)
                                                    ctx.fillStyle = barColor
                                                    ctx.fillRect(0, 0, width * animRatio, height)
                                                    ctx.restore()
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
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 62
                                        radius: 12
                                        color: statsHover.hovered ? Qt.rgba(0.05, 0.05, 0.08, 0.80) : Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                        border.width: 1
                                        border.color: statsHover.hovered ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                        antialiasing: true

                                        HoverHandler { id: statsHover }

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
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                                }

                                                Text {
                                                    text: root.appSwitches.toString()
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    Layout.alignment: Qt.AlignHCenter
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 1
                                                Layout.preferredHeight: 34
                                                Layout.alignment: Qt.AlignVCenter
                                                color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
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
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                                }

                                                Text {
                                                    text: root.peakHour
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    Layout.alignment: Qt.AlignHCenter
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Math.max(10, root.themeRounding - 6)
                                color: historyCardHover.hovered ? root.themeSurfaceHover : root.themeSurface
                                border.width: 1
                                border.color: historyCardHover.hovered ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                antialiasing: true

                                HoverHandler { id: historyCardHover }

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
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "Click bar to filter"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            opacity: 0.85
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
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
                                                    width: barColItem.isBarHovered || barColItem.isBarSelected ? 28 : 26
                                                    height: Math.max(0, barColItem.height - 28)
                                                    radius: 7
                                                    color: barColItem.isBarHovered ? Qt.rgba(1.0, 1.0, 1.0, 0.12) : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                                                    antialiasing: true

                                                    Behavior on width {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                }

                                                Canvas {
                                                    id: barCanvas
                                                    width: barColItem.isBarHovered || barColItem.isBarSelected ? 28 : 26
                                                    height: Math.max(0, barColItem.height - 28)
                                                    anchors.bottom: dayLabel.top
                                                    anchors.bottomMargin: 8
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    antialiasing: true

                                                    property real targetHeight: model.total > 0 ? Math.max(6, (model.total / root.maxHistoryTotal) * height) : 4
                                                    property real animHeight: mainCard.shown ? targetHeight : 0
                                                    property color barColor: barColItem.isBarSelected
                                                                             ? "#ffffff"
                                                                             : (barColItem.isBarHovered ? Qt.lighter(root.themePrimary, 1.12) : root.themePrimary)
                                                    opacity: barColItem.isBarSelected || barColItem.isBarHovered ? 1.0 : (model.total > 0 ? 0.85 : 0.30)

                                                    Behavior on width {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on animHeight {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.barDuration : 0
                                                            easing.type: animStyle.expoEasing
                                                        }
                                                    }
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on barColor {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }

                                                    onAnimHeightChanged: requestPaint()
                                                    onBarColorChanged: requestPaint()
                                                    onWidthChanged: requestPaint()
                                                    onHeightChanged: requestPaint()
                                                    onAvailableChanged: if (available) requestPaint()

                                                    onPaint: {
                                                        var ctx = getContext("2d")
                                                        ctx.reset()
                                                        if (animHeight <= 0 || width <= 0 || height <= 0) return
                                                        ctx.save()
                                                        root.clipRoundedRect(ctx, 0, 0, width, height, 7)
                                                        ctx.fillStyle = barColor
                                                        ctx.fillRect(0, height - animHeight, width, animHeight)
                                                        ctx.restore()
                                                    }
                                                }

                                                Text {
                                                    id: dayLabel
                                                    text: model.day
                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: barColItem.isBarSelected || barColItem.isBarHovered ? root.themePrimary : root.themeTextMuted
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: barColItem.isBarSelected ? Font.Bold : Font.Medium
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.75)

                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
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
                                                    property bool showTip: barMouse.containsMouse && model.total > 0
                                                    property real targetBarTop: barCanvas.height - barCanvas.animHeight
                                                    visible: opacity > 0.01
                                                    opacity: showTip ? 1.0 : 0.0
                                                    scale: showTip ? 1.0 : 0.92
                                                    width: Math.max(tooltipLayout.implicitWidth + 22, 110)
                                                    height: tooltipLayout.implicitHeight + 14
                                                    y: Math.max(0, barCanvas.y + targetBarTop - height - (showTip ? 8 : 2))
                                                    x: Math.max(-barColItem.x, Math.min((barColItem.width - width) / 2, barsRow.width - barColItem.x - width))
                                                    color: Qt.rgba(0.04, 0.04, 0.06, 0.96)
                                                    radius: 9
                                                    border.width: 1
                                                    border.color: Qt.alpha(root.themePrimary, 0.55)
                                                    z: 20
                                                    antialiasing: true

                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.scaleDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                    Behavior on y {
                                                        NumberAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }

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
                                                            style: Text.Raised
                                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
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
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 300
                            Layout.fillHeight: true
                            radius: Math.max(10, root.themeRounding - 6)
                            color: root.themeSurface
                            border.width: 1
                            border.color: root.selectedDayIndex !== -1 ? Qt.alpha(root.themePrimary, 0.38) : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                            clip: true
                            antialiasing: true

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }

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
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    Rectangle {
                                        property bool showBack: root.selectedDayIndex !== -1
                                        visible: opacity > 0.01
                                        opacity: showBack ? 1.0 : 0.0
                                        scale: showBack ? (backBtnMouse.pressed ? 0.92 : (backBtnMouse.containsMouse ? 1.05 : 1.0)) : 0.85
                                        Layout.preferredWidth: backBtnText.implicitWidth + 16
                                        Layout.preferredHeight: 24
                                        radius: 7
                                        color: backBtnMouse.containsMouse
                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.28, 0.85)
                                               : Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                        border.width: 1
                                        border.color: backBtnMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themePrimary, 0.45)
                                        antialiasing: true

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
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Text {
                                            id: backBtnText
                                            anchors.centerIn: parent
                                            text: "Today"
                                            color: root.themeText
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
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
                                    visible: opacity > 0.01
                                    opacity: appModel.count === 0 ? 1.0 : 0.0
                                    scale: appModel.count === 0 ? 1.0 : 0.95

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

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 10

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 52
                                            height: 52
                                            radius: 15
                                            color: Qt.rgba(0.02, 0.02, 0.03, 0.65)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.32)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰓏"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 22
                                                color: root.themePrimary
                                                opacity: 0.85
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "No activity recorded"
                                            color: root.themeTextMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                        }
                                    }
                                }

                                ListView {
                                    id: appList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.leftMargin: -4
                                    Layout.rightMargin: -4
                                    visible: appModel.count > 0
                                    spacing: 4
                                    model: appModel
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

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

                                    displaced: Transition {
                                        NumberAnimation {
                                            properties: "x,y"
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }

                                    ScrollBar.vertical: ScrollBar {
                                        id: vbar
                                        visible: appList.visible && vbar.size < 1.0
                                        active: appList.moving || appList.flicking || hovered
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.45)

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }
                                    }

                                    delegate: Item {
                                        id: appRowWrapper
                                        width: appList.width - (vbar.visible ? 10 : 0)
                                        height: 60

                                        property bool rowReady: false
                                        Component.onCompleted: rowReady = true

                                        MouseArea {
                                            id: appMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        Rectangle {
                                            id: rowCard
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            anchors.topMargin: 2
                                            anchors.bottomMargin: 2
                                            radius: 11
                                            color: appMouse.containsMouse
                                                   ? Qt.rgba(0.08, 0.08, 0.12, 0.72)
                                                   : Qt.rgba(0.02, 0.02, 0.03, 0.58)
                                            border.width: 1
                                            border.color: appMouse.containsMouse
                                                          ? Qt.alpha(root.themePrimary, 0.48)
                                                          : Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                            antialiasing: true
                                            scale: appMouse.containsMouse ? 1.012 : 1.0

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

                                            Canvas {
                                                id: rowFillCanvas
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                antialiasing: true

                                                property real targetRatio: root.selectedTotal > 0 ? Math.min(1.0, model.duration / root.selectedTotal) : 0
                                                property real animRatio: (appRowWrapper.rowReady && mainCard.shown) ? targetRatio : 0
                                                property color fillColor: Qt.alpha(root.themePrimary, appMouse.containsMouse ? 0.24 : 0.18)

                                                Behavior on animRatio {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.barDuration : 0
                                                        easing.type: animStyle.expoEasing
                                                    }
                                                }
                                                Behavior on fillColor {
                                                    ColorAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }

                                                onAnimRatioChanged: requestPaint()
                                                onFillColorChanged: requestPaint()
                                                onWidthChanged: requestPaint()
                                                onHeightChanged: requestPaint()
                                                onAvailableChanged: if (available) requestPaint()

                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    if (animRatio <= 0 || width <= 0 || height <= 0) return
                                                    ctx.save()
                                                    root.clipRoundedRect(ctx, 0, 0, width, height, 10)
                                                    ctx.fillStyle = fillColor
                                                    ctx.fillRect(0, 0, width * animRatio, height)
                                                    ctx.restore()
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
                                                    radius: appMouse.containsMouse ? 11 : 9
                                                    color: appMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.20) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                                    border.width: 1
                                                    border.color: appMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.42) : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    antialiasing: true
                                                    scale: appMouse.containsMouse ? 1.06 : 1.0

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
                                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                                    }

                                                    Text {
                                                        text: root.formatPercent(model.duration, root.selectedTotal) + " of active time"
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: appMouse.containsMouse ? root.themeText : root.themeTextMuted
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.7)

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
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
                                                    styleColor: Qt.rgba(0, 0, 0, 0.8)
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
                        color: root.themeSurface
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                        radius: Math.max(10, root.themeRounding - 10)
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
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.7)
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
                                    scale: clearMouse.pressed ? 0.92 : (clearMouse.containsMouse ? 1.04 : 1.0)

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

                                    Text {
                                        id: clearText
                                        anchors.centerIn: parent
                                        text: "Clear Data"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: "#ff6b6b"
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (!root.isClosing) resetDataProcess.running = true
                                    }
                                }

                                Rectangle {
                                    width: 34
                                    height: 24
                                    radius: 7
                                    color: escMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.alpha(root.themePrimary, 0.18)
                                    border.width: 1
                                    border.color: escMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themePrimary, 0.40)
                                    antialiasing: true
                                    scale: escMouse.pressed ? 0.92 : (escMouse.containsMouse ? 1.05 : 1.0)

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
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ESC"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: root.themePrimary
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    MouseArea {
                                        id: escMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.quitApp()
                                    }
                                }

                                Text {
                                    text: "Close"
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}