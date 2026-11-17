import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        Qt.quit()
    }

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.04, 0.04, 0.06, 0.55)
    property color themeSurfaceHover: Qt.rgba(0.12, 0.12, 0.15, 0.70)
    property color themePrimary: "#ffffff"
    property color themeBorder: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    FileView {
        id: colorsLuaFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let activeMatch = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (activeMatch && activeMatch[1]) {
                    let hex = "#" + activeMatch[1]
                    root.themePrimary = hex
                    root.themeBorder = hex
                }
                let bgMatch = content.match(/background\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/) || content.match(/background\s*=\s*"#([a-fA-F0-9]{6})"/)
                if (bgMatch && bgMatch[1]) {
                    root.themeBackground = "#" + bgMatch[1]
                }
            } catch (e) {}
        }
    }

    FileView {
        id: generalLuaFile
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

    property date currentDate: new Date()
    property date selectedDate: new Date()
    property date displayedDate: new Date()

    property var userEvents: ({})
    property var apiEvents: ({})
    property string targetMonitorName: ""

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date()
            if (now.getDate() !== root.currentDate.getDate() || now.getMonth() !== root.currentDate.getMonth()) {
                root.currentDate = now
            }
        }
    }

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

    function formatDateKey(d) {
        if (!d) return ""
        let y = d.getFullYear()
        let m = (d.getMonth() + 1).toString().padStart(2, '0')
        let day = d.getDate().toString().padStart(2, '0')
        return y + "-" + m + "-" + day
    }

    Process {
        id: holidaySyncProcess
        command: [
            "python3", "-c",
            "import urllib.request, json, os, re\ncache = os.path.expanduser('~/.config/quickshell/json/holidays_cache.json')\nos.makedirs(os.path.dirname(cache), exist_ok=True)\nout = {}\nif os.path.exists(cache):\n    try: out = json.load(open(cache, encoding='utf-8'))\n    except Exception: out = {}\ntry:\n    url = 'https://calendar.google.com/calendar/ical/en.indian%23holiday%40group.v.calendar.google.com/public/basic.ics'\n    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})\n    ics = urllib.request.urlopen(req, timeout=5).read().decode('utf-8', errors='ignore')\n    fresh = {}\n    for ev in ics.split('BEGIN:VEVENT')[1:]:\n        d = re.search(r'DTSTART(?:;[^:]*)?:(\\d{4})(\\d{2})(\\d{2})', ev)\n        s = re.search(r'SUMMARY(?:;[^:]*)?:(.+)', ev)\n        if d and s:\n            k = f'{d.group(1)}-{d.group(2)}-{d.group(3)}'\n            name = s.group(1).strip().replace('\\\\,', ',')\n            fresh.setdefault(k, [])\n            if name not in fresh[k]: fresh[k].append(name)\n    if fresh:\n        out = fresh\n        json.dump(out, open(cache, 'w', encoding='utf-8'))\nexcept Exception: pass\nprint(json.dumps(out))"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim())
                    if (parsed) root.apiEvents = parsed
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        holidaySyncProcess.running = true
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }
        colorsLuaFile.reload()
        generalLuaFile.reload()
        animConfigFile.reload()
        eventsConfigFile.reload()
    }

    FileView {
        id: eventsConfigFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/calendar_events.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let raw = text().trim()
                if (raw) root.userEvents = JSON.parse(raw)
            } catch (e) {}
        }
    }

    Process { id: saveEventsProcess }

    function saveUserEvents() {
        let path = Quickshell.env("HOME") + "/.config/quickshell/json/calendar_events.json"
        let jsonStr = JSON.stringify(root.userEvents)

        saveEventsProcess.running = false
        saveEventsProcess.command = [
            "python3", "-c",
            "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])",
            path,
            jsonStr
        ]
        saveEventsProcess.running = true
    }

    function addEventForSelectedDate(taskText) {
        if (!taskText || taskText.trim() === "") return
        let key = formatDateKey(root.selectedDate)
        let updated = Object.assign({}, root.userEvents)
        if (!updated[key] || !Array.isArray(updated[key])) updated[key] = []
        updated[key].push(taskText.trim())
        root.userEvents = updated
        saveUserEvents()
    }

    function removeEventForSelectedDate(index) {
        let key = formatDateKey(root.selectedDate)
        let updated = Object.assign({}, root.userEvents)
        if (updated[key] && Array.isArray(updated[key])) {
            updated[key].splice(index, 1)
            if (updated[key].length === 0) delete updated[key]
            root.userEvents = updated
            saveUserEvents()
        }
    }

    function getEventsForDate(cellDate) {
        let key = formatDateKey(cellDate)
        let list = []

        if (root.apiEvents[key] && Array.isArray(root.apiEvents[key])) {
            for (let i = 0; i < root.apiEvents[key].length; i++) {
                let t = root.apiEvents[key][i]
                if (!list.some(e => e.text === t)) {
                    list.push({ type: "holiday", text: t })
                }
            }
        }

        if (root.userEvents[key] && Array.isArray(root.userEvents[key])) {
            for (let i = 0; i < root.userEvents[key].length; i++) {
                list.push({ type: "todo", text: root.userEvents[key][i], index: i })
            }
        }

        return list
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: calendarWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-calendar"
            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            Shortcut {
                sequence: "Escape"
                onActivated: root.quitApp()
            }

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Item {
                id: dragContainer
                width: mainCard.width
                height: mainCard.height
                x: (calendarWindow.width - width) / 2
                y: 52

                DragHandler {
                    target: dragContainer
                    enabled: !root.isClosing
                    cursorShape: Qt.ClosedHandCursor
                }

                Rectangle {
                    id: mainCard
                    width: 440
                    height: cardLayout.implicitHeight + 44
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.color: Qt.alpha(root.themePrimary, 0.40)
                    border.width: root.themeBorderSize
                    antialiasing: true
                    clip: true

                    focus: true

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
                        onTriggered: mainCard.shown = true
                    }

                    Timer {
                        id: settleTimer
                        interval: animStyle.enterDuration + 60
                        repeat: false
                        onTriggered: mainCard.settled = true
                    }

                    opacity: panelVisible ? 1.0 : 0.0
                    enabled: !root.isClosing

                    transform: [
                        Scale {
                            origin.x: mainCard.width / 2
                            origin.y: 0
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
                            y: mainCard.panelVisible ? 0 : -12

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

                    Behavior on height {
                        NumberAnimation {
                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                            easing.type: animStyle.expoEasing
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => mouse.accepted = true
                    }

                    Keys.onPressed: (event) => {
                        if (root.isClosing) return
                        if (event.key === Qt.Key_Escape) {
                            root.quitApp()
                            event.accepted = true
                            return
                        }

                        let d = new Date(root.selectedDate)
                        let changed = false

                        if (event.key === Qt.Key_Left) { d.setDate(d.getDate() - 1); changed = true }
                        else if (event.key === Qt.Key_Right) { d.setDate(d.getDate() + 1); changed = true }
                        else if (event.key === Qt.Key_Up) { d.setDate(d.getDate() - 7); changed = true }
                        else if (event.key === Qt.Key_Down) { d.setDate(d.getDate() + 7); changed = true }

                        if (changed) {
                            root.selectedDate = d
                            if (d.getMonth() !== root.displayedDate.getMonth() || d.getFullYear() !== root.displayedDate.getFullYear()) {
                                root.displayedDate = new Date(d.getFullYear(), d.getMonth(), 1)
                                gridAnim.restart()
                            }
                            event.accepted = true
                        }
                    }

                    function getDayInfo(idx, baseDate) {
                        let year = baseDate.getFullYear()
                        let month = baseDate.getMonth()

                        let firstDay = new Date(year, month, 1).getDay()
                        let daysInMonth = new Date(year, month + 1, 0).getDate()
                        let daysInPrevMonth = new Date(year, month, 0).getDate()

                        let dayNum = 0
                        let isCurrentMonth = false
                        let cellDate = new Date()

                        if (idx < firstDay) {
                            dayNum = daysInPrevMonth - (firstDay - 1 - idx)
                            isCurrentMonth = false
                            cellDate = new Date(year, month - 1, dayNum)
                        } else if (idx < firstDay + daysInMonth) {
                            dayNum = idx - firstDay + 1
                            isCurrentMonth = true
                            cellDate = new Date(year, month, dayNum)
                        } else {
                            dayNum = idx - (firstDay + daysInMonth) + 1
                            isCurrentMonth = false
                            cellDate = new Date(year, month + 1, dayNum)
                        }

                        let now = root.currentDate
                        let isToday = isCurrentMonth &&
                                      (dayNum === now.getDate()) &&
                                      (month === now.getMonth()) &&
                                      (year === now.getFullYear())

                        let key = root.formatDateKey(cellDate)
                        let isSelected = (key === root.formatDateKey(root.selectedDate))
                        let eventList = root.getEventsForDate(cellDate)

                        return {
                            day: dayNum,
                            dateObj: cellDate,
                            isCurrent: isCurrentMonth,
                            isToday: isToday,
                            isSelected: isSelected,
                            events: eventList
                        }
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 22
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 40
                                height: 40
                                radius: 12
                                color: Qt.alpha(root.themePrimary, 0.16)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.35)
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰃭"
                                    color: root.themePrimary
                                    font.pixelSize: 20
                                    font.family: root.iconFontFamily
                                }
                            }

                            ColumnLayout {
                                spacing: 2

                                Text {
                                    text: root.displayedDate.toLocaleDateString(Qt.locale(), "MMMM")
                                    color: root.themeText
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Text {
                                    text: root.displayedDate.toLocaleDateString(Qt.locale(), "yyyy")
                                    color: root.themePrimary
                                    opacity: 0.85
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                                }
                            }

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: prevNav.containsMouse ? 12 : 10
                                    color: prevNav.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: prevNav.containsMouse ? Qt.alpha(root.themePrimary, 0.5) : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true

                                    scale: prevNav.pressed ? 0.92 : (prevNav.containsMouse ? 1.05 : 1.0)

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
                                        anchors.centerIn: parent
                                        text: "󰅁"
                                        color: prevNav.containsMouse ? root.themePrimary : root.themeText
                                        font.pixelSize: 16
                                        font.family: root.iconFontFamily
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: prevNav
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let newD = new Date(root.displayedDate.getFullYear(), root.displayedDate.getMonth() - 1, 1)
                                            root.displayedDate = newD
                                            gridAnim.restart()
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: todayNav.containsMouse ? 12 : 10
                                    color: todayNav.containsMouse
                                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.28, 0.75)
                                           : root.themeSurface
                                    border.width: 1
                                    border.color: todayNav.containsMouse ? Qt.alpha(root.themePrimary, 0.6) : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true

                                    scale: todayNav.pressed ? 0.92 : (todayNav.containsMouse ? 1.05 : 1.0)

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
                                        anchors.centerIn: parent
                                        text: "󰃯"
                                        color: root.themePrimary
                                        font.pixelSize: 15
                                        font.family: root.iconFontFamily
                                    }

                                    MouseArea {
                                        id: todayNav
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.displayedDate = new Date()
                                            root.selectedDate = new Date()
                                            gridAnim.restart()
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: nextNav.containsMouse ? 12 : 10
                                    color: nextNav.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1
                                    border.color: nextNav.containsMouse ? Qt.alpha(root.themePrimary, 0.5) : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true

                                    scale: nextNav.pressed ? 0.92 : (nextNav.containsMouse ? 1.05 : 1.0)

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
                                        anchors.centerIn: parent
                                        text: "󰅂"
                                        color: nextNav.containsMouse ? root.themePrimary : root.themeText
                                        font.pixelSize: 16
                                        font.family: root.iconFontFamily
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: nextNav
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let newD = new Date(root.displayedDate.getFullYear(), root.displayedDate.getMonth() + 1, 1)
                                            root.displayedDate = newD
                                            gridAnim.restart()
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: Math.max(8, root.themeRounding - 6)
                            color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.25)
                            antialiasing: true
                            implicitHeight: calBoxCol.implicitHeight + 24

                            ColumnLayout {
                                id: calBoxCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Repeater {
                                        model: 7
                                        Text {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: Qt.locale().dayName(index, Locale.ShortFormat).slice(0, 2)
                                            color: index === 0 || index === 6 ? root.themePrimary : root.themeTextMuted
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            font.family: root.fontFamily
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.65)
                                        }
                                    }
                                }

                                Grid {
                                    id: daysGrid
                                    columns: 7
                                    spacing: 5
                                    Layout.alignment: Qt.AlignHCenter

                                    ParallelAnimation {
                                        id: gridAnim
                                        NumberAnimation {
                                            target: daysGrid
                                            property: "opacity"
                                            from: 0.0
                                            to: 1.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                        NumberAnimation {
                                            target: daysGrid
                                            property: "scale"
                                            from: 0.96
                                            to: 1.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                            easing.type: animStyle.expoEasing
                                        }
                                    }

                                    Repeater {
                                        model: 42
                                        delegate: Rectangle {
                                            id: dayCell
                                            width: 48
                                            height: 44
                                            radius: Math.max(6, root.themeRounding - 10)
                                            antialiasing: true
                                            z: cellHover.containsMouse ? 5 : (dayInfo.isSelected || dayInfo.isToday ? 2 : 1)

                                            property var dayInfo: mainCard.getDayInfo(index, root.displayedDate)

                                            color: dayInfo.isToday
                                                 ? root.themePrimary
                                                 : (dayInfo.isSelected
                                                    ? root.mixColor(root.themeBackground, root.themePrimary, 0.28, 0.78)
                                                    : (cellHover.containsMouse ? root.themeSurfaceHover : "transparent"))

                                            border.color: dayInfo.isToday
                                                        ? Qt.rgba(1, 1, 1, 0.45)
                                                        : (dayInfo.isSelected
                                                           ? root.themePrimary
                                                           : (cellHover.containsMouse ? Qt.alpha(root.themePrimary, 0.45) : "transparent"))
                                            border.width: dayInfo.isSelected || dayInfo.isToday ? 1.5 : 1

                                            scale: cellHover.pressed ? 0.92 : (cellHover.containsMouse ? 1.05 : 1.0)

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

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: dayCell.dayInfo.day.toString()
                                                    font.pixelSize: 13
                                                    font.family: root.fontFamily
                                                    font.weight: dayCell.dayInfo.isToday || dayCell.dayInfo.isSelected ? Font.Bold : Font.Medium
                                                    color: dayCell.dayInfo.isToday
                                                         ? "#141416"
                                                         : (dayCell.dayInfo.isCurrent ? root.themeText : Qt.rgba(1.0, 1.0, 1.0, 0.30))
                                                    style: dayCell.dayInfo.isToday ? Text.Normal : Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                            easing.type: animStyle.smoothEasing
                                                        }
                                                    }
                                                }

                                                Row {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    spacing: 3

                                                    property bool hasHoliday: dayCell.dayInfo.events.some(e => e.type === "holiday")
                                                    property bool hasTodo: dayCell.dayInfo.events.some(e => e.type === "todo")

                                                    Rectangle {
                                                        width: 10
                                                        height: 4
                                                        radius: 2
                                                        color: dayCell.dayInfo.isToday ? "#141416" : root.themePrimary
                                                        visible: parent.hasHoliday
                                                        antialiasing: true
                                                    }
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        color: dayCell.dayInfo.isToday ? "#141416" : root.themeText
                                                        visible: parent.hasTodo
                                                        antialiasing: true
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: cellHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.selectedDate = dayCell.dayInfo.dateObj

                                                    if (dayCell.dayInfo.dateObj.getMonth() !== root.displayedDate.getMonth()) {
                                                        root.displayedDate = new Date(dayCell.dayInfo.dateObj.getFullYear(), dayCell.dayInfo.dateObj.getMonth(), 1)
                                                        gridAnim.restart()
                                                    }

                                                    taskInputField.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "󰃰"
                                    color: root.themePrimary
                                    font.pixelSize: 15
                                    font.family: root.iconFontFamily
                                }

                                Text {
                                    text: root.selectedDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                                }

                                Rectangle {
                                    opacity: eventListCol.activeEvents.length > 0 ? 1.0 : 0.0
                                    visible: opacity > 0
                                    width: countLabel.implicitWidth + 14
                                    height: 22
                                    radius: 6
                                    color: Qt.alpha(root.themePrimary, 0.18)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.4)

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Text {
                                        id: countLabel
                                        anchors.centerIn: parent
                                        text: eventListCol.activeEvents.length.toString()
                                        color: root.themePrimary
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.family: root.fontFamily
                                    }
                                }
                            }

                            ScrollView {
                                id: eventsScrollView
                                Layout.fillWidth: true
                                Layout.maximumHeight: 148
                                Layout.preferredHeight: Math.min(Math.max(eventListCol.implicitHeight, 44), 148)
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                        easing.type: animStyle.expoEasing
                                    }
                                }

                                ColumnLayout {
                                    id: eventListCol
                                    width: eventsScrollView.availableWidth > 0 ? eventsScrollView.availableWidth : eventsScrollView.width
                                    spacing: 8

                                    property var activeEvents: root.getEventsForDate(root.selectedDate)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 44
                                        radius: 10
                                        color: Qt.rgba(0.02, 0.02, 0.03, 0.40)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.08)
                                        visible: parent.activeEvents.length === 0

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Text {
                                                text: "󰄬"
                                                color: root.themeTextMuted
                                                font.pixelSize: 14
                                                font.family: root.iconFontFamily
                                            }

                                            Text {
                                                text: root.selectedDate.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                                                color: root.themeTextMuted
                                                font.pixelSize: 12
                                                font.family: root.fontFamily
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: parent.activeEvents
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            height: 38
                                            radius: 10
                                            color: modelData.type === "holiday"
                                                 ? root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.72)
                                                 : (eventRowHover.containsMouse ? Qt.rgba(0.06, 0.06, 0.09, 0.68) : Qt.rgba(0.03, 0.03, 0.05, 0.58))
                                            border.color: modelData.type === "holiday"
                                                        ? Qt.alpha(root.themePrimary, 0.55)
                                                        : (eventRowHover.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.14))
                                            border.width: 1
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

                                            MouseArea {
                                                id: eventRowHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 10
                                                spacing: 10

                                                Text {
                                                    text: modelData.type === "holiday" ? "󰃰" : "󰄱"
                                                    color: root.themePrimary
                                                    font.pixelSize: 15
                                                    font.family: root.iconFontFamily
                                                }

                                                Text {
                                                    text: modelData.text
                                                    color: modelData.type === "holiday" ? root.themePrimary : root.themeText
                                                    font.pixelSize: 12
                                                    font.weight: modelData.type === "holiday" ? Font.Bold : Font.Medium
                                                    font.family: root.fontFamily
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 26
                                                    Layout.preferredHeight: 26
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    radius: delBtnMouse.containsMouse ? 9 : 8
                                                    color: delBtnMouse.containsMouse ? Qt.rgba(0.93, 0.26, 0.26, 0.35) : "transparent"
                                                    border.width: 1
                                                    border.color: delBtnMouse.containsMouse ? "#ff6b6b" : "transparent"
                                                    visible: modelData.type === "todo"
                                                    antialiasing: true

                                                    scale: delBtnMouse.pressed ? 0.90 : (delBtnMouse.containsMouse ? 1.06 : 1.0)

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
                                                        anchors.centerIn: parent
                                                        text: "󰅖"
                                                        color: delBtnMouse.containsMouse ? "#ff6b6b" : root.themeTextMuted
                                                        font.pixelSize: 13
                                                        font.family: root.iconFontFamily
                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: delBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.removeEventForSelectedDate(modelData.index)
                                                    }
                                                }
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
                                    implicitHeight: 40
                                    radius: 10
                                    color: Qt.rgba(0.02, 0.02, 0.03, 0.58)
                                    border.color: taskInputField.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.16)
                                    border.width: taskInputField.activeFocus ? 1.5 : 1
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Text {
                                            text: "󰏫"
                                            color: taskInputField.activeFocus ? root.themePrimary : root.themeTextMuted
                                            font.pixelSize: 14
                                            font.family: root.iconFontFamily
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                    easing.type: animStyle.smoothEasing
                                                }
                                            }
                                        }

                                        TextInput {
                                            id: taskInputField
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            verticalAlignment: Text.AlignVCenter
                                            color: root.themeText
                                            font.pixelSize: 13
                                            font.family: root.fontFamily
                                            selectionColor: Qt.alpha(root.themePrimary, 0.4)
                                            selectedTextColor: root.themeText
                                            clip: true

                                            Text {
                                                text: root.selectedDate.toLocaleDateString(Qt.locale(), "MMM d")
                                                color: Qt.rgba(1.0, 1.0, 1.0, 0.38)
                                                font.pixelSize: 12
                                                font.family: root.fontFamily
                                                anchors.verticalCenter: parent.verticalCenter
                                                opacity: !taskInputField.text && !taskInputField.activeFocus ? 1.0 : 0.0
                                                visible: opacity > 0
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                        easing.type: animStyle.smoothEasing
                                                    }
                                                }
                                            }

                                            onAccepted: {
                                                root.addEventForSelectedDate(taskInputField.text)
                                                taskInputField.text = ""
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: addBtnMouse.containsMouse ? 12 : 10
                                    color: addBtnMouse.containsMouse ? Qt.lighter(root.themePrimary, 1.1) : root.themePrimary
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.4)
                                    antialiasing: true

                                    scale: addBtnMouse.pressed ? 0.92 : (addBtnMouse.containsMouse ? 1.05 : 1.0)

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
                                        anchors.centerIn: parent
                                        text: "󰐕"
                                        color: "#141416"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                        font.family: root.iconFontFamily
                                    }

                                    MouseArea {
                                        id: addBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.addEventForSelectedDate(taskInputField.text)
                                            taskInputField.text = ""
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