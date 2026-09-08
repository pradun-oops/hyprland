import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Scope {
    id: root

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08)
    property color themePrimary: "#a2d398"
    property color themeBorder: "#a2d398"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#8E8E93"
    property color themeAccent: "#f5a97f" 
    property int themeRounding: 15
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.7

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
            } catch(e) {}
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
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])
            } catch(e) {}
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

    property var indianStaticHolidays: ({
        "2026-01-14": ["Makar Sankranti / Pongal"],
        "2026-01-26": ["Republic Day"],
        "2026-03-03": ["Holika Dahan"],
        "2026-03-04": ["Holi"],
        "2026-03-19": ["Ugadi / Gudi Padwa"],
        "2026-03-21": ["Eid al-Fitr"],
        "2026-03-26": ["Ram Navami"],
        "2026-04-03": ["Good Friday"],
        "2026-04-14": ["Vaisakhi / Ambedkar Jayanti"],
        "2026-05-01": ["Buddha Purnima"],
        "2026-05-27": ["Bakrid / Eid al-Adha"],
        "2026-06-26": ["Muharram"],
        "2026-08-15": ["Independence Day"],
        "2026-08-26": ["Onam / Id-e-Milad"],
        "2026-08-28": ["Raksha Bandhan"],
        "2026-09-04": ["Janmashtami"],
        "2026-09-14": ["Ganesh Chaturthi"],
        "2026-10-02": ["Mahatma Gandhi Jayanti"],
        "2026-10-18": ["Durga Puja (Ashtami)"],
        "2026-10-20": ["Dussehra (Vijayadashami)"],
        "2026-11-08": ["Diwali (Deepavali)"],
        "2026-11-09": ["Govardhan Puja"],
        "2026-11-11": ["Bhai Dooj"],
        "2026-11-15": ["Chhath Puja"],
        "2026-11-24": ["Guru Nanak Jayanti"],
        "2026-12-25": ["Christmas Day"]
    })

    function formatDateKey(d) {
        if (!d) return ""
        let y = d.getFullYear()
        let m = (d.getMonth() + 1).toString().padStart(2, '0')
        let day = d.getDate().toString().padStart(2, '0')
        return y + "-" + m + "-" + day
    }

    function fetchIndianHolidays(year) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://date.nager.at/api/v3/PublicHolidays/" + year + "/IN")
        xhr.timeout = 5000 
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var holidays = JSON.parse(xhr.responseText)
                    var fetched = {}
                    for (var i = 0; i < holidays.length; i++) {
                        var item = holidays[i]
                        var key = item.date
                        if (!fetched[key]) fetched[key] = []
                        fetched[key].push(item.localName)
                    }
                    root.apiEvents = fetched
                } catch(e) {}
            }
        }
        xhr.onerror = function() {}
        xhr.ontimeout = function() {}
        xhr.send()
    }

    Component.onCompleted: {
        fetchIndianHolidays(displayedDate.getFullYear())
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }
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
            } catch(e) {}
        }
    }

    Process { id: saveEventsProcess }

    function saveUserEvents() {
        let jsonDir = Quickshell.env("HOME") + "/.config/quickshell/json"
        let jsonFile = jsonDir + "/calendar_events.json"
        let jsonTmp = jsonFile + ".tmp"
        let jsonStr = JSON.stringify(root.userEvents)

        let cmd = "mkdir -p '" + jsonDir + "' && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + jsonTmp + "' && mv '" + jsonTmp + "' '" + jsonFile + "'"

        saveEventsProcess.running = false
        saveEventsProcess.command = ["bash", "-c", cmd]
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

        if (root.indianStaticHolidays[key]) {
            for (let i = 0; i < root.indianStaticHolidays[key].length; i++) {
                list.push({ type: "holiday", text: root.indianStaticHolidays[key][i] })
            }
        }

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
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-calendar"
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true }
            margins { top: 50 }

            implicitWidth: mainCard.width
            implicitHeight: mainCard.height
            color: "transparent"

            Shortcut {
                sequence: "Escape"
                onActivated: Qt.quit()
            }

            Rectangle {
                id: mainCard
                width: 440
                height: cardLayout.implicitHeight + 48
                radius: root.themeRounding
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                border.color: root.themeBorder
                border.width: root.themeBorderSize

                focus: true 

                Keys.onPressed: (event) => {
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
                            root.fetchIndianHolidays(d.getFullYear())
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
                    anchors.margins: 24
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: root.displayedDate.toLocaleDateString(Qt.locale(), "MMMM")
                                color: root.themeText
                                font.pixelSize: 24
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.displayedDate.toLocaleDateString(Qt.locale(), "yyyy")
                                color: root.themeTextMuted
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: prevNav.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : root.themeSurface

                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: root.themeText
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                    anchors.verticalCenterOffset: -1
                                }

                                MouseArea {
                                    id: prevNav
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let newD = new Date(root.displayedDate.getFullYear(), root.displayedDate.getMonth() - 1, 1)
                                        root.displayedDate = newD
                                        root.fetchIndianHolidays(newD.getFullYear())
                                        gridAnim.restart()
                                    }
                                }
                            }

                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: todayNav.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : root.themeSurface

                                Text {
                                    anchors.centerIn: parent
                                    text: "•"
                                    color: root.themePrimary
                                    font.pixelSize: 18
                                    font.weight: Font.Black
                                }

                                MouseArea {
                                    id: todayNav
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.displayedDate = new Date()
                                        root.selectedDate = new Date()
                                        root.fetchIndianHolidays(root.displayedDate.getFullYear())
                                        gridAnim.restart()
                                    }
                                }
                            }

                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: nextNav.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : root.themeSurface

                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    color: root.themeText
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                    anchors.verticalCenterOffset: -1
                                }

                                MouseArea {
                                    id: nextNav
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let newD = new Date(root.displayedDate.getFullYear(), root.displayedDate.getMonth() + 1, 1)
                                        root.displayedDate = newD
                                        root.fetchIndianHolidays(newD.getFullYear())
                                        gridAnim.restart()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: index === 0 || index === 6 ? root.themePrimary : root.themeTextMuted
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Grid {
                        id: daysGrid
                        columns: 7
                        spacing: 8
                        Layout.alignment: Qt.AlignHCenter

                        NumberAnimation { 
                            id: gridAnim 
                            target: daysGrid 
                            property: "opacity" 
                            from: 0.0 
                            to: 1.0 
                            duration: 300 
                            easing.type: Easing.OutCubic 
                        }

                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: dayCell
                                width: 48
                                height: 48
                                radius: 12

                                property var dayInfo: mainCard.getDayInfo(index, root.displayedDate)

                                color: dayInfo.isToday 
                                     ? root.themePrimary 
                                     : (dayInfo.isSelected ? Qt.rgba(root.themePrimary.r, root.themePrimary.g, root.themePrimary.b, 0.25) : (cellHover.containsMouse ? root.themeSurface : "transparent"))

                                border.color: dayInfo.isSelected && !dayInfo.isToday ? root.themePrimary : "transparent"
                                border.width: 1.5

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: dayCell.dayInfo.day.toString()
                                        font.pixelSize: 15
                                        font.weight: dayCell.dayInfo.isToday || dayCell.dayInfo.isSelected ? Font.Bold : Font.Medium
                                        color: dayCell.dayInfo.isToday 
                                             ? root.themeBackground 
                                             : (dayCell.dayInfo.isCurrent ? root.themeText : Qt.rgba(1.0, 1.0, 1.0, 0.25))
                                    }

                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 3

                                        property bool hasHoliday: dayCell.dayInfo.events.some(e => e.type === "holiday")
                                        property bool hasTodo: dayCell.dayInfo.events.some(e => e.type === "todo")

                                        Rectangle {
                                            width: 5; height: 5; radius: 2.5
                                            color: dayCell.dayInfo.isToday ? root.themeBackground : root.themePrimary
                                            visible: parent.hasHoliday
                                        }
                                        Rectangle {
                                            width: 5; height: 5; radius: 2.5
                                            color: dayCell.dayInfo.isToday ? root.themeBackground : root.themeAccent
                                            visible: parent.hasTodo
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
                                            root.fetchIndianHolidays(root.displayedDate.getFullYear())
                                            gridAnim.restart()
                                        }
                                        
                                        taskInputField.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.themeSurface }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Events & Tasks for " + root.selectedDate.toLocaleDateString(Qt.locale(), "MMM d, yyyy")
                            color: root.themePrimary
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.maximumHeight: 150
                            Layout.preferredHeight: Math.min(eventListCol.implicitHeight, 150)
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                id: eventListCol
                                width: parent.width
                                spacing: 8

                                property var activeEvents: root.getEventsForDate(root.selectedDate)

                                Text {
                                    text: "No events or tasks scheduled for this date."
                                    color: root.themeTextMuted
                                    font.pixelSize: 13
                                    visible: parent.activeEvents.length === 0
                                }

                                Repeater {
                                    model: parent.activeEvents
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: 6
                                        color: modelData.type === "holiday" ? Qt.rgba(root.themePrimary.r, root.themePrimary.g, root.themePrimary.b, 0.15) : "transparent"
                                        border.color: modelData.type === "holiday" ? root.themePrimary : "transparent"
                                        border.width: modelData.type === "holiday" ? 1 : 0

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: modelData.type === "holiday" ? 10 : 0
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Text {
                                                text: modelData.type === "holiday" ? ("🇮🇳 " + modelData.text) : ("•  " + modelData.text)
                                                color: modelData.type === "holiday" ? root.themePrimary : root.themeText
                                                font.pixelSize: 13
                                                font.weight: modelData.type === "holiday" ? Font.Bold : Font.Normal
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                width: 24; height: 24; radius: 12
                                                color: delBtnMouse.containsMouse ? Qt.rgba(1.0, 0.3, 0.3, 0.15) : "transparent"
                                                visible: modelData.type === "todo"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: delBtnMouse.containsMouse ? "#ff4d4d" : root.themeTextMuted
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
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
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                radius: 8
                                color: root.themeSurface
                                border.color: taskInputField.activeFocus ? root.themeAccent : "transparent"
                                border.width: 1

                                TextInput {
                                    id: taskInputField
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: Text.AlignVCenter
                                    color: root.themeText
                                    font.pixelSize: 13
                                    clip: true

                                    Text {
                                        text: "Enter task for " + root.selectedDate.toLocaleDateString(Qt.locale(), "MMM d") + "..."
                                        color: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.55)
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !taskInputField.text && !taskInputField.activeFocus
                                    }

                                    onAccepted: {
                                        root.addEventForSelectedDate(taskInputField.text)
                                        taskInputField.text = ""
                                    }
                                }
                            }

                            Rectangle {
                                width: 38; height: 38; radius: 8
                                color: addBtnMouse.containsMouse ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.8) : root.themeAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: root.themeBackground
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
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