import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property string targetMonitorName: ""
    property bool hudMode: false
    property bool editMode: false
    property int scheduleFilter: 0
    property int rightTab: 0

    property bool autoRoutineMode: true
    property string activeRoutineMode: "weekday"

    property int editingBlockIndex: -1
    property string editBlockStartStr: "7:00 AM"
    property string editBlockEndStr: "7:30 AM"
    property string editBlockTitle: ""
    property string editBlockDetails: ""
    property string editBlockSection: "morning"
    property string editBlockCat: "study"

    property string newChecklistTitle: ""
    property string newChecklistGroup: "ACADEMICS"

    property bool stateLoadedOnce: false
    property bool stateDirty: false
    property bool pendingQuit: false
    property int scrollRequestCounter: 0

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

    property int themeRounding: 15
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.60

    property bool animEnabled: true
    property int animDuration: 380

    property color themeBackground: "#121214"
    property color themeCardBg: Qt.rgba(0.09, 0.09, 0.12, 0.85)
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#D4D4D8"
    property color themePrimary: "#ffb3af"

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 260
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.3
    }

    property string currentTimeStr: "--:--:--"
    property string currentDateStr: ""
    property string todayIsoDate: ""
    property int currentDayOfWeek: (new Date()).getDay()
    property int currentMinutes: 0
    property int currentSeconds: 0

    property int activeBlockIndex: -1
    property string activeTaskTitle: "Sleep & Recovery Window"
    property string activeTaskDesc: "Protect your sleep. Rest well for the 7:00 AM wake-up target."
    property string activeTaskTimeRange: "10:30 PM - 7:00 AM"
    property string activeTaskCategory: "sleep"
    property real activeBlockProgress: 0.0
    property string activeRemainingStr: ""

    property string nextTaskTitle: "Wake up & get ready"
    property string nextTaskTime: "7:00 - 7:30 AM"

    property int completedChecklistCount: 0
    property int totalChecklistCount: 11

    property var modeProfiles: ({})
    property string footerMantra: "Focus on output, not just hours. Two tools practised well beat three rushed. Protect your sleep."

    property string priority1: ""
    property string priority2: ""
    property string priority3: ""
    property bool priority1Done: false
    property bool priority2Done: false
    property bool priority3Done: false
    property string notesTomorrow: ""

    property string stateFilePath: Quickshell.env("HOME") + "/.config/quickshell/json/daily_planner_state.json"

    ListModel { id: scheduleModel }
    ListModel { id: checklistModel }

    readonly property var defaultWeekdaySchedule: [
        { blockId: "w01", startMin: 420, endMin: 450, timeLabel: "7:00 - 7:30 AM", section: "morning", cat: "routine", title: "Wake up & get ready", details: "Freshen up, drink water, get sunlight, and set up your desk.", manualDone: false },
        { blockId: "w02", startMin: 450, endMin: 495, timeLabel: "7:30 - 8:15 AM", section: "morning", cat: "study", title: "Academic subject 1", details: "Understand concepts and make short, useful notes.", manualDone: false },
        { blockId: "w03", startMin: 495, endMin: 505, timeLabel: "8:15 - 8:25 AM", section: "morning", cat: "break", title: "Short break", details: "Stand up, stretch, and rest your eyes.", manualDone: false },
        { blockId: "w04", startMin: 505, endMin: 550, timeLabel: "8:25 - 9:10 AM", section: "morning", cat: "study", title: "Academic subject 2", details: "Work on theory, numerical problems, or revision.", manualDone: false },
        { blockId: "w05", startMin: 550, endMin: 565, timeLabel: "9:10 - 9:25 AM", section: "morning", cat: "break", title: "Break", details: "Move around; avoid getting pulled into phone scrolling.", manualDone: false },
        { blockId: "w06", startMin: 565, endMin: 635, timeLabel: "9:25 - 10:35 AM", section: "morning", cat: "cyber", title: "Cisco networking 1 unit", details: "Learn the concepts, draw diagrams, take notes, and self-test.", manualDone: false },
        { blockId: "w07", startMin: 635, endMin: 645, timeLabel: "10:35 - 10:45 AM", section: "morning", cat: "break", title: "Short break", details: "Hydrate and reset.", manualDone: false },
        { blockId: "w08", startMin: 645, endMin: 675, timeLabel: "10:45 - 11:15 AM", section: "morning", cat: "study", title: "Academic book 1", details: "Read the matching lecture topic and fill gaps in your notes.", manualDone: false },
        { blockId: "w09", startMin: 675, endMin: 705, timeLabel: "11:15 - 11:45 AM", section: "morning", cat: "study", title: "Academic book 2", details: "Read the same topic in your second book; mark important questions.", manualDone: false },
        { blockId: "w10", startMin: 705, endMin: 720, timeLabel: "11:45 - 12:00 PM", section: "morning", cat: "break", title: "Snack / reset", details: "Take a short break away from your desk.", manualDone: false },
        { blockId: "w11", startMin: 720, endMin: 780, timeLabel: "12:00 - 1:00 PM", section: "morning", cat: "cyber", title: "Kali Linux practicals", details: "Practise 2-3 tools in an authorised lab; record commands and results.", manualDone: false },
        { blockId: "w12", startMin: 780, endMin: 795, timeLabel: "1:00 - 1:15 PM", section: "morning", cat: "review", title: "Daily review", details: "Recall key points, tick off tasks, and choose tomorrow's topics.", manualDone: false },
        { blockId: "w13", startMin: 795, endMin: 840, timeLabel: "1:15 - 2:00 PM", section: "afternoon", cat: "break", title: "Lunch & rest", details: "Eat properly and take a real break away from your desk.", manualDone: false },
        { blockId: "w14", startMin: 840, endMin: 930, timeLabel: "2:00 - 3:30 PM", section: "afternoon", cat: "growth", title: "Hyprland / Quickshell", details: "Build one widget, fix a bug, or polish your desktop workflow.", manualDone: false },
        { blockId: "w15", startMin: 930, endMin: 960, timeLabel: "3:30 - 4:00 PM", section: "afternoon", cat: "break", title: "Refresh break", details: "Walk, stretch, get fresh air, or have a snack.", manualDone: false },
        { blockId: "w16", startMin: 960, endMin: 1020, timeLabel: "4:00 - 5:00 PM", section: "afternoon", cat: "cyber", title: "Learn something new", details: "Linux, scripting, cybersecurity fundamentals, or another chosen skill.", manualDone: false },
        { blockId: "w17", startMin: 1020, endMin: 1080, timeLabel: "5:00 - 6:00 PM", section: "afternoon", cat: "growth", title: "Flexible project time", details: "Continue your project, document progress, or catch up on unfinished work.", manualDone: false },
        { blockId: "w18", startMin: 1080, endMin: 1140, timeLabel: "6:00 - 7:00 PM", section: "afternoon", cat: "routine", title: "Dinner & class prep", details: "Eat, prepare notes, open class materials, and settle in.", manualDone: false },
        { blockId: "w19", startMin: 1140, endMin: 1260, timeLabel: "7:00 - 9:00 PM", section: "afternoon", cat: "study", title: "Scheduled Classes (Mon-Thu)", details: "Attend scheduled classes; stay attentive and note topics to revise.", manualDone: false },
        { blockId: "w20", startMin: 1260, endMin: 1350, timeLabel: "9:00 - 10:30 PM", section: "afternoon", cat: "routine", title: "Wind down", details: "Brief recap, relax, prepare for tomorrow, and aim to sleep at 10:30 PM.", manualDone: false }
    ]

    readonly property var defaultWeekendSchedule: [
        { blockId: "e01", startMin: 420, endMin: 450, timeLabel: "7:00 - 7:30 AM", section: "morning", cat: "routine", title: "Wake up & get ready", details: "Freshen up, drink water, get sunlight, and set up your desk.", manualDone: false },
        { blockId: "e02", startMin: 450, endMin: 495, timeLabel: "7:30 - 8:15 AM", section: "morning", cat: "study", title: "Academic subject 1", details: "Understand concepts and make short, useful notes.", manualDone: false },
        { blockId: "e03", startMin: 495, endMin: 505, timeLabel: "8:15 - 8:25 AM", section: "morning", cat: "break", title: "Short break", details: "Stand up, stretch, and rest your eyes.", manualDone: false },
        { blockId: "e04", startMin: 505, endMin: 550, timeLabel: "8:25 - 9:10 AM", section: "morning", cat: "study", title: "Academic subject 2", details: "Work on theory, numerical problems, or revision.", manualDone: false },
        { blockId: "e05", startMin: 550, endMin: 565, timeLabel: "9:10 - 9:25 AM", section: "morning", cat: "break", title: "Break", details: "Move around; avoid getting pulled into phone scrolling.", manualDone: false },
        { blockId: "e06", startMin: 565, endMin: 635, timeLabel: "9:25 - 10:35 AM", section: "morning", cat: "cyber", title: "Cisco networking 1 unit", details: "Learn the concepts, draw diagrams, take notes, and self-test.", manualDone: false },
        { blockId: "e07", startMin: 635, endMin: 645, timeLabel: "10:35 - 10:45 AM", section: "morning", cat: "break", title: "Short break", details: "Hydrate and reset.", manualDone: false },
        { blockId: "e08", startMin: 645, endMin: 675, timeLabel: "10:45 - 11:15 AM", section: "morning", cat: "study", title: "Academic book 1", details: "Read the matching lecture topic and fill gaps in your notes.", manualDone: false },
        { blockId: "e09", startMin: 675, endMin: 705, timeLabel: "11:15 - 11:45 AM", section: "morning", cat: "study", title: "Academic book 2", details: "Read the same topic in your second book; mark important questions.", manualDone: false },
        { blockId: "e10", startMin: 705, endMin: 720, timeLabel: "11:45 - 12:00 PM", section: "morning", cat: "break", title: "Snack / reset", details: "Take a short break away from your desk.", manualDone: false },
        { blockId: "e11", startMin: 720, endMin: 780, timeLabel: "12:00 - 1:00 PM", section: "morning", cat: "cyber", title: "Kali Linux practicals", details: "Practise 2-3 tools in an authorised lab; record commands and results.", manualDone: false },
        { blockId: "e12", startMin: 780, endMin: 795, timeLabel: "1:00 - 1:15 PM", section: "morning", cat: "review", title: "Daily review", details: "Recall key points, tick off tasks, and choose tomorrow's topics.", manualDone: false },
        { blockId: "e13", startMin: 795, endMin: 840, timeLabel: "1:15 - 2:00 PM", section: "afternoon", cat: "break", title: "Lunch & rest", details: "Eat properly and take a real break away from your desk.", manualDone: false },
        { blockId: "e14", startMin: 840, endMin: 930, timeLabel: "2:00 - 3:30 PM", section: "afternoon", cat: "growth", title: "Hyprland / Quickshell", details: "Build one widget, fix a bug, or polish your desktop workflow.", manualDone: false },
        { blockId: "e15", startMin: 930, endMin: 960, timeLabel: "3:30 - 4:00 PM", section: "afternoon", cat: "break", title: "Refresh break", details: "Walk, stretch, get fresh air, or have a snack.", manualDone: false },
        { blockId: "e16", startMin: 960, endMin: 1020, timeLabel: "4:00 - 5:00 PM", section: "afternoon", cat: "cyber", title: "Learn something new", details: "Linux, scripting, cybersecurity fundamentals, or another chosen skill.", manualDone: false },
        { blockId: "e17", startMin: 1020, endMin: 1080, timeLabel: "5:00 - 6:00 PM", section: "afternoon", cat: "growth", title: "Flexible project time", details: "Continue your project, document progress, or catch up on unfinished work.", manualDone: false },
        { blockId: "e18", startMin: 1080, endMin: 1140, timeLabel: "6:00 - 7:00 PM", section: "afternoon", cat: "routine", title: "Dinner & evening reset", details: "Classes are closed Fri-Sun. Enjoy dinner and recharge.", manualDone: false },
        { blockId: "e19", startMin: 1140, endMin: 1260, timeLabel: "7:00 - 9:00 PM", section: "afternoon", cat: "cyber", title: "Deep Lab / Weekly Revision", details: "No classes today (Fri-Sun). Use this window for extra Kali labs, scripting, or revision.", manualDone: false },
        { blockId: "e20", startMin: 1260, endMin: 1350, timeLabel: "9:00 - 10:30 PM", section: "afternoon", cat: "routine", title: "Wind down", details: "Brief recap, relax, prepare for tomorrow, and aim to sleep at 10:30 PM.", manualDone: false }
    ]

    readonly property var defaultTravelSchedule: [
        { blockId: "t01", startMin: 420, endMin: 540, timeLabel: "7:00 - 9:00 AM", section: "morning", cat: "routine", title: "Travel Prep & Departure", details: "Pack essentials, charger, tickets, water, and verify travel schedule.", manualDone: false },
        { blockId: "t02", startMin: 540, endMin: 720, timeLabel: "9:00 - 12:00 PM", section: "morning", cat: "study", title: "Transit Reading / Offline Study", details: "Read downloaded PDFs, review lecture notes, or listen to audio material.", manualDone: false },
        { blockId: "t03", startMin: 720, endMin: 840, timeLabel: "12:00 - 2:00 PM", section: "afternoon", cat: "break", title: "Midday Meal & Rest", details: "Eat properly, hydrate, and rest your eyes during transit.", manualDone: false },
        { blockId: "t04", startMin: 840, endMin: 1020, timeLabel: "2:00 - 5:00 PM", section: "afternoon", cat: "cyber", title: "Light Review / Concept Notes", details: "Review networking concepts, command cheatsheets, or plan upcoming labs.", manualDone: false },
        { blockId: "t05", startMin: 1020, endMin: 1140, timeLabel: "5:00 - 7:00 PM", section: "afternoon", cat: "routine", title: "Arrival, Dinner & Settle In", details: "Unpack, freshen up, have dinner, and organize your space.", manualDone: false },
        { blockId: "t06", startMin: 1140, endMin: 1260, timeLabel: "7:00 - 9:00 PM", section: "afternoon", cat: "review", title: "Light Catch-up / Next Day Plan", details: "Check messages, review class updates, and set priorities for tomorrow.", manualDone: false },
        { blockId: "t07", startMin: 1260, endMin: 1350, timeLabel: "9:00 - 10:30 PM", section: "afternoon", cat: "routine", title: "Early Recovery & Sleep", details: "Recover from travel fatigue and aim to sleep by 10:30 PM.", manualDone: false }
    ]

    readonly property var defaultStandardChecklist: [
        { itemId: "c01", group: "ACADEMICS", title: "Study academic subject 1", done: false },
        { itemId: "c02", group: "ACADEMICS", title: "Study academic subject 2", done: false },
        { itemId: "c03", group: "ACADEMICS", title: "Read academic book 1", done: false },
        { itemId: "c04", group: "ACADEMICS", title: "Read academic book 2", done: false },
        { itemId: "c05", group: "CYBERSECURITY", title: "Complete one Cisco networking unit", done: false },
        { itemId: "c06", group: "CYBERSECURITY", title: "Practise Kali Linux tool 1", done: false },
        { itemId: "c07", group: "CYBERSECURITY", title: "Practise Kali Linux tool 2", done: false },
        { itemId: "c08", group: "CYBERSECURITY", title: "Practise Kali Linux tool 3 OR review results", done: false },
        { itemId: "c09", group: "PERSONAL GROWTH", title: "Work on Hyprland / Quickshell", done: false },
        { itemId: "c10", group: "PERSONAL GROWTH", title: "Learn or build something new", done: false },
        { itemId: "c11", group: "PERSONAL GROWTH", title: "Review today and plan tomorrow", done: false }
    ]

    readonly property var defaultTravelChecklist: [
        { itemId: "tc01", group: "ACADEMICS", title: "Read 1 chapter or lecture PDF offline", done: false },
        { itemId: "tc02", group: "ACADEMICS", title: "Review short notes or flashcards during transit", done: false },
        { itemId: "tc03", group: "CYBERSECURITY", title: "Review networking diagrams or Kali command notes", done: false },
        { itemId: "tc04", group: "PERSONAL GROWTH", title: "Keep daily consistency streak alive", done: false },
        { itemId: "tc05", group: "PERSONAL GROWTH", title: "Set up workspace & plan tomorrow's full routine", done: false }
    ]

    function cloneArray(arr) {
        let out = []
        for (let i = 0; i < arr.length; i++) {
            out.push(Object.assign({}, arr[i]))
        }
        return out
    }

    function createDefaultProfiles() {
        return {
            "weekday": {
                wakeUp: "7:00 AM",
                coreStudy: "7:30 - 1:15 PM",
                classes: "7:00 - 9:00 PM",
                sleep: "10:30 PM",
                schedule: root.cloneArray(root.defaultWeekdaySchedule),
                checklist: root.cloneArray(root.defaultStandardChecklist)
            },
            "weekend": {
                wakeUp: "7:00 AM",
                coreStudy: "7:30 - 1:15 PM",
                classes: "Closed (Fri-Sun)",
                sleep: "10:30 PM",
                schedule: root.cloneArray(root.defaultWeekendSchedule),
                checklist: root.cloneArray(root.defaultStandardChecklist)
            },
            "travel": {
                wakeUp: "Flexible",
                coreStudy: "Transit / Light",
                classes: "Travel Mode",
                sleep: "10:30 PM",
                schedule: root.cloneArray(root.defaultTravelSchedule),
                checklist: root.cloneArray(root.defaultTravelChecklist)
            }
        }
    }

    property string targetWakeUp: "7:00 AM"
    property string targetCoreStudy: "7:30 - 1:15 PM"
    property string targetClasses: "7:00 - 9:00 PM"
    property string targetSleep: "10:30 PM"

    function getAutoModeForToday() {
        let day = root.currentDayOfWeek
        return (day >= 1 && day <= 4) ? "weekday" : "weekend"
    }

    function syncActiveModelsToProfile() {
        if (!root.modeProfiles || !root.modeProfiles[root.activeRoutineMode]) return
        let prof = root.modeProfiles[root.activeRoutineMode]
        prof.wakeUp = root.targetWakeUp
        prof.coreStudy = root.targetCoreStudy
        prof.classes = root.targetClasses
        prof.sleep = root.targetSleep

        let sArr = []
        for (let i = 0; i < scheduleModel.count; i++) {
            let b = scheduleModel.get(i)
            sArr.push({
                blockId: b.blockId,
                startMin: b.startMin,
                endMin: b.endMin,
                timeLabel: b.timeLabel,
                section: b.section,
                cat: b.cat,
                title: b.title,
                details: b.details,
                manualDone: Boolean(b.manualDone)
            })
        }
        prof.schedule = sArr

        let cArr = []
        for (let j = 0; j < checklistModel.count; j++) {
            let c = checklistModel.get(j)
            cArr.push({
                itemId: c.itemId,
                group: c.group,
                title: c.title,
                done: Boolean(c.done)
            })
        }
        prof.checklist = cArr
    }

    function loadProfileIntoActiveModels(modeKey) {
        if (!root.modeProfiles || !root.modeProfiles[modeKey]) {
            root.modeProfiles = root.createDefaultProfiles()
        }
        root.activeRoutineMode = modeKey
        let prof = root.modeProfiles[modeKey]

        root.targetWakeUp = prof.wakeUp || "7:00 AM"
        root.targetCoreStudy = prof.coreStudy || "7:30 - 1:15 PM"
        root.targetClasses = prof.classes || (modeKey === "weekday" ? "7:00 - 9:00 PM" : (modeKey === "weekend" ? "Closed (Fri-Sun)" : "Travel Mode"))
        root.targetSleep = prof.sleep || "10:30 PM"

        scheduleModel.clear()
        let sList = prof.schedule || []
        for (let i = 0; i < sList.length; i++) {
            let sb = sList[i]
            scheduleModel.append({
                blockId: String(sb.blockId || ("b_" + i)),
                startMin: Number(sb.startMin),
                endMin: Number(sb.endMin),
                timeLabel: String(sb.timeLabel),
                section: String(sb.section || "morning"),
                cat: String(sb.cat || "study"),
                title: String(sb.title || "Task"),
                details: String(sb.details || ""),
                manualDone: Boolean(sb.manualDone)
            })
        }

        checklistModel.clear()
        let cList = prof.checklist || []
        for (let j = 0; j < cList.length; j++) {
            let sc = cList[j]
            checklistModel.append({
                itemId: String(sc.itemId || ("c_" + j)),
                group: String(sc.group || "ACADEMICS"),
                title: String(sc.title || "Task"),
                done: Boolean(sc.done)
            })
        }

        root.editingBlockIndex = -1
        root.recalculateChecklistProgress()
        root.updateLiveClock()
        root.scrollRequestCounter++
    }

    function switchRoutineMode(modeKey, enableAuto) {
        if (root.stateLoadedOnce) {
            root.syncActiveModelsToProfile()
        }
        root.autoRoutineMode = Boolean(enableAuto)
        let targetMode = enableAuto ? root.getAutoModeForToday() : modeKey
        root.loadProfileIntoActiveModels(targetMode)
        root.saveStateNow()
    }

    function populateDefaults() {
        root.modeProfiles = root.createDefaultProfiles()
        root.footerMantra = "Focus on output, not just hours. Two tools practised well beat three rushed. Protect your sleep."
        let targetMode = root.autoRoutineMode ? root.getAutoModeForToday() : root.activeRoutineMode
        root.loadProfileIntoActiveModels(targetMode)
    }

    function minsToSingleTime(totalMins) {
        let m = ((totalMins % 1440) + 1440) % 1440
        let hrs24 = Math.floor(m / 60)
        let mins = m % 60
        let ampm = hrs24 >= 12 ? "PM" : "AM"
        let hrs12 = hrs24 % 12
        if (hrs12 === 0) hrs12 = 12
        return hrs12 + ":" + String(mins).padStart(2, '0') + " " + ampm
    }

    function formatRangeLabel(startM, endM) {
        let s = ((startM % 1440) + 1440) % 1440
        let e = ((endM % 1440) + 1440) % 1440
        let sH24 = Math.floor(s / 60), sMin = s % 60
        let eH24 = Math.floor(e / 60), eMin = e % 60
        let sAmPm = sH24 >= 12 ? "PM" : "AM"
        let eAmPm = eH24 >= 12 ? "PM" : "AM"
        let sH12 = sH24 % 12 === 0 ? 12 : sH24 % 12
        let eH12 = eH24 % 12 === 0 ? 12 : eH24 % 12
        let sStr = sH12 + ":" + String(sMin).padStart(2, '0')
        let eStr = eH12 + ":" + String(eMin).padStart(2, '0') + " " + eAmPm
        return sStr + " - " + eStr
    }

    function parseTimeInput(inputStr, fallbackMins) {
        if (!inputStr) return fallbackMins
        let clean = String(inputStr).trim().toUpperCase()
        let match = clean.match(/^(\d{1,2})(?:\s*:\s*(\d{2}))?\s*(AM|PM)?$/)
        if (!match) return fallbackMins
        let h = parseInt(match[1], 10)
        let m = match[2] !== undefined ? parseInt(match[2], 10) : 0
        let mer = match[3] || ""
        if (m < 0 || m > 59 || h < 0 || h > 23) return fallbackMins
        if (mer === "PM" && h < 12) h += 12
        if (mer === "AM" && h === 12) h = 0
        return h * 60 + m
    }

    function openBlockEditor(index) {
        if (index < 0 || index >= scheduleModel.count) {
            root.editingBlockIndex = -1
            return
        }
        let blk = scheduleModel.get(index)
        root.editingBlockIndex = index
        root.editBlockStartStr = root.minsToSingleTime(blk.startMin)
        root.editBlockEndStr = root.minsToSingleTime(blk.endMin)
        root.editBlockTitle = blk.title
        root.editBlockDetails = blk.details
        root.editBlockSection = blk.section
        root.editBlockCat = blk.cat
    }

    function saveEditedBlock() {
        if (root.editingBlockIndex < 0 || root.editingBlockIndex >= scheduleModel.count) return
        let current = scheduleModel.get(root.editingBlockIndex)
        let sMin = root.parseTimeInput(root.editBlockStartStr, current.startMin)
        let eMin = root.parseTimeInput(root.editBlockEndStr, current.endMin)
        if (eMin <= sMin) eMin = sMin + 30

        scheduleModel.setProperty(root.editingBlockIndex, "startMin", sMin)
        scheduleModel.setProperty(root.editingBlockIndex, "endMin", eMin)
        scheduleModel.setProperty(root.editingBlockIndex, "timeLabel", root.formatRangeLabel(sMin, eMin))
        scheduleModel.setProperty(root.editingBlockIndex, "title", root.editBlockTitle.trim() !== "" ? root.editBlockTitle.trim() : "Untitled Block")
        scheduleModel.setProperty(root.editingBlockIndex, "details", root.editBlockDetails.trim())
        scheduleModel.setProperty(root.editingBlockIndex, "section", root.editBlockSection)
        scheduleModel.setProperty(root.editingBlockIndex, "cat", root.editBlockCat)

        root.editingBlockIndex = -1
        root.updateLiveClock()
        root.saveStateNow()
    }

    function addNewScheduleBlock() {
        let lastEnd = 420
        let sec = root.scheduleFilter === 2 ? "afternoon" : "morning"
        if (scheduleModel.count > 0) {
            let lastBlk = scheduleModel.get(scheduleModel.count - 1)
            lastEnd = Math.min(1380, lastBlk.endMin)
            sec = lastEnd >= 795 ? "afternoon" : "morning"
        }
        let newEnd = Math.min(1435, lastEnd + 30)
        let newId = "b_custom_" + Date.now()
        scheduleModel.append({
            blockId: newId,
            startMin: lastEnd,
            endMin: newEnd,
            timeLabel: root.formatRangeLabel(lastEnd, newEnd),
            section: sec,
            cat: "study",
            title: "New Study Block",
            details: "Describe what to focus on during this block.",
            manualDone: false
        })
        let newIdx = scheduleModel.count - 1
        root.openBlockEditor(newIdx)
        root.updateLiveClock()
        root.saveStateNow()
    }

    function deleteScheduleBlock(index) {
        if (index < 0 || index >= scheduleModel.count) return
        scheduleModel.remove(index)
        if (root.editingBlockIndex === index) {
            root.editingBlockIndex = -1
        } else if (root.editingBlockIndex > index) {
            root.editingBlockIndex--
        }
        root.updateLiveClock()
        root.saveStateNow()
    }

    function sortScheduleByTime() {
        let arr = []
        for (let i = 0; i < scheduleModel.count; i++) {
            let it = scheduleModel.get(i)
            arr.push({
                blockId: it.blockId,
                startMin: it.startMin,
                endMin: it.endMin,
                timeLabel: it.timeLabel,
                section: it.section,
                cat: it.cat,
                title: it.title,
                details: it.details,
                manualDone: it.manualDone
            })
        }
        arr.sort((a, b) => a.startMin - b.startMin)
        scheduleModel.clear()
        for (let j = 0; j < arr.length; j++) {
            scheduleModel.append(arr[j])
        }
        root.editingBlockIndex = -1
        root.updateLiveClock()
        root.saveStateNow()
    }

    function getCategoryColor(cat) {
        if (cat === "cyber") return "#38bdf8"
        if (cat === "study") return root.themePrimary
        if (cat === "growth") return "#a78bfa"
        if (cat === "break") return "#4ade80"
        if (cat === "review") return "#fbbf24"
        return "#94a3b8"
    }

    function recalculateChecklistProgress() {
        let count = 0
        let total = checklistModel.count
        for (let i = 0; i < total; i++) {
            if (checklistModel.get(i).done) count++
        }
        root.completedChecklistCount = count
        root.totalChecklistCount = Math.max(1, total)
    }

    function addChecklistItem() {
        let t = root.newChecklistTitle.trim()
        if (t === "") return
        let grp = root.newChecklistGroup
        let insertIndex = checklistModel.count
        for (let i = checklistModel.count - 1; i >= 0; i--) {
            if (checklistModel.get(i).group === grp) {
                insertIndex = i + 1
                break
            }
        }
        checklistModel.insert(insertIndex, {
            itemId: "c_custom_" + Date.now(),
            group: grp,
            title: t,
            done: false
        })
        root.newChecklistTitle = ""
        root.recalculateChecklistProgress()
        root.saveStateNow()
    }

    function cycleChecklistGroup(index) {
        if (index < 0 || index >= checklistModel.count) return
        const groups = ["ACADEMICS", "CYBERSECURITY", "PERSONAL GROWTH"]
        let item = checklistModel.get(index)
        let currentGrp = item.group
        let nextGrp = groups[(groups.indexOf(currentGrp) + 1) % groups.length]
        let cloned = {
            itemId: item.itemId,
            group: nextGrp,
            title: item.title,
            done: Boolean(item.done)
        }
        checklistModel.remove(index)
        let insertIndex = checklistModel.count
        for (let i = checklistModel.count - 1; i >= 0; i--) {
            if (checklistModel.get(i).group === nextGrp) {
                insertIndex = i + 1
                break
            }
        }
        checklistModel.insert(insertIndex, cloned)
        root.saveStateNow()
    }

    Process {
        id: stateWriter
        onExited: {
            if (root.pendingQuit) {
                Qt.quit()
            } else if (root.stateDirty) {
                root.saveStateNow()
            }
        }
    }

    Timer {
        id: saveDebounceTimer
        interval: 200
        repeat: false
        onTriggered: root.saveStateNow()
    }

    function scheduleSave() {
        root.stateDirty = true
        saveDebounceTimer.restart()
    }

    function safeQuit() {
        if (saveDebounceTimer.running || root.stateDirty) {
            saveDebounceTimer.stop()
            root.pendingQuit = true
            root.saveStateNow()
        } else if (stateWriter.running) {
            root.pendingQuit = true
        } else {
            Qt.quit()
        }
    }

    function saveStateNow() {
        if (!root.stateLoadedOnce) return
        if (stateWriter.running) {
            root.stateDirty = true
            return
        }

        root.stateDirty = false
        root.syncActiveModelsToProfile()

        let now = new Date()
        root.todayIsoDate = now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, '0') + "-" + String(now.getDate()).padStart(2, '0')

        let payload = {
            date: root.todayIsoDate,
            hudMode: root.hudMode,
            autoRoutineMode: root.autoRoutineMode,
            activeRoutineMode: root.activeRoutineMode,
            modeProfiles: root.modeProfiles,
            footerMantra: root.footerMantra,
            priority1: root.priority1,
            priority2: root.priority2,
            priority3: root.priority3,
            priority1Done: root.priority1Done,
            priority2Done: root.priority2Done,
            priority3Done: root.priority3Done,
            notesTomorrow: root.notesTomorrow
        }

        let jsonStr = JSON.stringify(payload)
        stateWriter.command = [
            "sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "sh",
            root.stateFilePath,
            jsonStr
        ]
        stateWriter.running = true
    }

    function applyLoadedState(rawText) {
        if (root.stateLoadedOnce) return
        root.stateLoadedOnce = true

        let now = new Date()
        let iso = now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, '0') + "-" + String(now.getDate()).padStart(2, '0')
        root.todayIsoDate = iso
        root.currentDayOfWeek = now.getDay()

        root.modeProfiles = root.createDefaultProfiles()

        let saved = null
        try {
            let trimmed = (rawText || "").trim()
            if (trimmed !== "") {
                saved = JSON.parse(trimmed)
            }
        } catch (e) {
            saved = null
        }

        if (!saved) {
            root.autoRoutineMode = true
            root.loadProfileIntoActiveModels(root.getAutoModeForToday())
            return
        }

        let isSameDay = (saved.date === iso)

        if (saved.hudMode !== undefined) root.hudMode = Boolean(saved.hudMode)
        if (saved.notesTomorrow !== undefined) root.notesTomorrow = String(saved.notesTomorrow)
        if (saved.footerMantra) root.footerMantra = String(saved.footerMantra)
        if (saved.autoRoutineMode !== undefined) root.autoRoutineMode = Boolean(saved.autoRoutineMode)

        if (saved.modeProfiles && typeof saved.modeProfiles === "object") {
            const keys = ["weekday", "weekend", "travel"]
            for (let k = 0; k < keys.length; k++) {
                let mKey = keys[k]
                if (saved.modeProfiles[mKey]) {
                    let sp = saved.modeProfiles[mKey]
                    let dp = root.modeProfiles[mKey]
                    if (sp.wakeUp) dp.wakeUp = String(sp.wakeUp)
                    if (sp.coreStudy) dp.coreStudy = String(sp.coreStudy)
                    if (sp.classes) dp.classes = String(sp.classes)
                    if (sp.sleep) dp.sleep = String(sp.sleep)

                    if (Array.isArray(sp.schedule) && sp.schedule.length > 0) {
                        dp.schedule = sp.schedule.map((sb, idx) => ({
                            blockId: String(sb.blockId || ("b_" + idx)),
                            startMin: Number(sb.startMin),
                            endMin: Number(sb.endMin),
                            timeLabel: String(sb.timeLabel),
                            section: String(sb.section || "morning"),
                            cat: String(sb.cat || "study"),
                            title: String(sb.title || "Task"),
                            details: String(sb.details || ""),
                            manualDone: isSameDay ? Boolean(sb.manualDone) : false
                        }))
                    }

                    if (Array.isArray(sp.checklist) && sp.checklist.length > 0) {
                        dp.checklist = sp.checklist.map((sc, idx) => ({
                            itemId: String(sc.itemId || ("c_" + idx)),
                            group: String(sc.group || "ACADEMICS"),
                            title: String(sc.title || "Task"),
                            done: isSameDay ? Boolean(sc.done) : false
                        }))
                    }
                }
            }
        } else if (saved.scheduleData && Array.isArray(saved.scheduleData) && saved.scheduleData.length > 0) {
            root.modeProfiles.weekday.schedule = saved.scheduleData.map((sb, idx) => ({
                blockId: String(sb.blockId || ("b_" + idx)),
                startMin: Number(sb.startMin),
                endMin: Number(sb.endMin),
                timeLabel: String(sb.timeLabel),
                section: String(sb.section || "morning"),
                cat: String(sb.cat || "study"),
                title: String(sb.title || "Task"),
                details: String(sb.details || ""),
                manualDone: isSameDay ? Boolean(sb.manualDone) : false
            }))
            if (saved.checklistData && Array.isArray(saved.checklistData) && saved.checklistData.length > 0) {
                let migratedChecklist = saved.checklistData.map((sc, idx) => ({
                    itemId: String(sc.itemId || ("c_" + idx)),
                    group: String(sc.group || "ACADEMICS"),
                    title: String(sc.title || "Task"),
                    done: isSameDay ? Boolean(sc.done) : false
                }))
                root.modeProfiles.weekday.checklist = root.cloneArray(migratedChecklist)
                root.modeProfiles.weekend.checklist = root.cloneArray(migratedChecklist)
            }
        }

        if (isSameDay) {
            root.priority1 = saved.priority1 || ""
            root.priority2 = saved.priority2 || ""
            root.priority3 = saved.priority3 || ""
            root.priority1Done = Boolean(saved.priority1Done)
            root.priority2Done = Boolean(saved.priority2Done)
            root.priority3Done = Boolean(saved.priority3Done)
        }

        let initialMode = root.autoRoutineMode
            ? root.getAutoModeForToday()
            : (saved.activeRoutineMode || root.getAutoModeForToday())

        root.loadProfileIntoActiveModels(initialMode)
    }

    FileView {
        id: stateFile
        path: root.stateFilePath
        watchChanges: false
        onLoaded: {
            root.applyLoadedState(text())
        }
        onLoadFailed: {
            if (!root.stateLoadedOnce) {
                root.stateLoadedOnce = true
                root.populateDefaults()
                root.updateLiveClock()
            }
        }
    }

    function resetDailyProgress() {
        for (let i = 0; i < checklistModel.count; i++) {
            checklistModel.setProperty(i, "done", false)
        }
        for (let j = 0; j < scheduleModel.count; j++) {
            scheduleModel.setProperty(j, "manualDone", false)
        }
        const keys = ["weekday", "weekend", "travel"]
        for (let k = 0; k < keys.length; k++) {
            let prof = root.modeProfiles[keys[k]]
            if (prof) {
                if (Array.isArray(prof.schedule)) {
                    for (let s = 0; s < prof.schedule.length; s++) prof.schedule[s].manualDone = false
                }
                if (Array.isArray(prof.checklist)) {
                    for (let c = 0; c < prof.checklist.length; c++) prof.checklist[c].done = false
                }
            }
        }
        root.priority1Done = false
        root.priority2Done = false
        root.priority3Done = false
        root.recalculateChecklistProgress()
        root.saveStateNow()
    }

    function updateLiveClock() {
        let now = new Date()
        let hrs = now.getHours()
        let mins = now.getMinutes()
        let secs = now.getSeconds()

        let nowIso = now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, '0') + "-" + String(now.getDate()).padStart(2, '0')
        root.currentDayOfWeek = now.getDay()

        if (root.stateLoadedOnce && root.todayIsoDate !== "" && root.todayIsoDate !== nowIso) {
            root.todayIsoDate = nowIso
            root.resetDailyProgress()
        }

        if (root.stateLoadedOnce && root.autoRoutineMode) {
            let expectedAuto = root.getAutoModeForToday()
            if (root.activeRoutineMode !== expectedAuto) {
                root.syncActiveModelsToProfile()
                root.loadProfileIntoActiveModels(expectedAuto)
            }
        }

        let ampm = hrs >= 12 ? "PM" : "AM"
        let h12 = hrs % 12
        if (h12 === 0) h12 = 12
        root.currentTimeStr = String(h12).padStart(2, '0') + ":" + String(mins).padStart(2, '0') + ":" + String(secs).padStart(2, '0') + " " + ampm

        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        root.currentDateStr = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()

        let totalMins = hrs * 60 + mins
        root.currentMinutes = totalMins
        root.currentSeconds = secs

        let foundIdx = -1
        for (let i = 0; i < scheduleModel.count; i++) {
            let blk = scheduleModel.get(i)
            if (totalMins >= blk.startMin && totalMins < blk.endMin) {
                foundIdx = i
                break
            }
        }

        let prevActiveIdx = root.activeBlockIndex
        root.activeBlockIndex = foundIdx
        if (prevActiveIdx !== foundIdx && foundIdx !== -1) {
            root.scrollRequestCounter++
        }

        if (foundIdx !== -1) {
            let activeBlk = scheduleModel.get(foundIdx)
            root.activeTaskTitle = activeBlk.title
            root.activeTaskDesc = activeBlk.details
            root.activeTaskTimeRange = activeBlk.timeLabel
            root.activeTaskCategory = activeBlk.cat

            let durationSecs = (activeBlk.endMin - activeBlk.startMin) * 60
            let elapsedSecs = ((totalMins - activeBlk.startMin) * 60) + secs
            let remSecs = Math.max(0, durationSecs - elapsedSecs)

            root.activeBlockProgress = durationSecs > 0 ? Math.min(1.0, elapsedSecs / durationSecs) : 0.0

            let remMins = Math.floor(remSecs / 60)
            let remS = remSecs % 60
            if (remMins >= 60) {
                let rh = Math.floor(remMins / 60)
                let rm = remMins % 60
                root.activeRemainingStr = rh + "h " + rm + "m " + remS + "s left"
            } else {
                root.activeRemainingStr = remMins + "m " + String(remS).padStart(2, '0') + "s left"
            }

            if (foundIdx + 1 < scheduleModel.count) {
                let nextBlk = scheduleModel.get(foundIdx + 1)
                root.nextTaskTitle = nextBlk.title
                root.nextTaskTime = nextBlk.timeLabel
            } else {
                root.nextTaskTitle = "Sleep Target"
                root.nextTaskTime = root.targetSleep
            }
        } else {
            let firstStart = scheduleModel.count > 0 ? scheduleModel.get(0).startMin : 420
            let lastEnd = scheduleModel.count > 0 ? scheduleModel.get(scheduleModel.count - 1).endMin : 1350

            let nextTodayIdx = -1
            if (totalMins >= firstStart && totalMins < lastEnd) {
                for (let g = 0; g < scheduleModel.count; g++) {
                    if (scheduleModel.get(g).startMin > totalMins) {
                        nextTodayIdx = g
                        break
                    }
                }
            }

            if (nextTodayIdx !== -1) {
                let upcomingBlk = scheduleModel.get(nextTodayIdx)
                let prevEnd = nextTodayIdx > 0 ? scheduleModel.get(nextTodayIdx - 1).endMin : firstStart
                let gapDurationSecs = Math.max(60, (upcomingBlk.startMin - prevEnd) * 60)
                let gapElapsedSecs = ((totalMins - prevEnd) * 60) + secs
                let gapRemSecs = Math.max(0, (upcomingBlk.startMin * 60) - (totalMins * 60 + secs))

                root.activeTaskTitle = "Transition / Unscheduled Break"
                root.activeTaskDesc = "Prepare for your next scheduled block: " + upcomingBlk.title + "."
                root.activeTaskTimeRange = root.formatRangeLabel(prevEnd, upcomingBlk.startMin)
                root.activeTaskCategory = "break"
                root.activeBlockProgress = Math.min(1.0, Math.max(0.0, gapElapsedSecs / gapDurationSecs))

                let gMins = Math.floor(gapRemSecs / 60)
                let gSecs = gapRemSecs % 60
                root.activeRemainingStr = gMins + "m " + String(gSecs).padStart(2, '0') + "s left"
                root.nextTaskTitle = upcomingBlk.title
                root.nextTaskTime = upcomingBlk.timeLabel
            } else {
                let parsedSleep = root.parseTimeInput(root.targetSleep, -1)
                let parsedWake = root.parseTimeInput(root.targetWakeUp, -1)
                let sleepStartMin = parsedSleep !== -1 ? parsedSleep : lastEnd
                let wakeUpMin = parsedWake !== -1 ? parsedWake : firstStart
                let wakeLabel = parsedWake !== -1 ? root.targetWakeUp : root.minsToSingleTime(wakeUpMin)
                let sleepLabel = parsedSleep !== -1 ? root.targetSleep : root.minsToSingleTime(sleepStartMin)

                root.activeTaskTitle = "Sleep & Recovery Window"
                root.activeTaskDesc = "Protect your sleep. Focus on rest so you're ready for " + wakeLabel + "."
                root.activeTaskTimeRange = sleepLabel + " - " + wakeLabel
                root.activeTaskCategory = "sleep"

                let totalSleepWindow = wakeUpMin > sleepStartMin
                    ? (wakeUpMin - sleepStartMin)
                    : ((1440 - sleepStartMin) + wakeUpMin)
                if (totalSleepWindow <= 0) totalSleepWindow = 510

                let minsSinceSleep = totalMins >= sleepStartMin
                    ? (totalMins - sleepStartMin)
                    : ((1440 - sleepStartMin) + totalMins)

                let elapsedSleepSecs = (minsSinceSleep * 60) + secs
                let totalSleepSecs = totalSleepWindow * 60
                root.activeBlockProgress = Math.min(1.0, Math.max(0.0, elapsedSleepSecs / totalSleepSecs))

                let remSleepSecs = Math.max(0, totalSleepSecs - elapsedSleepSecs)
                let minsLeft = Math.ceil(remSleepSecs / 60)
                let rh = Math.floor(minsLeft / 60)
                let rm = minsLeft % 60
                root.activeRemainingStr = rh + "h " + rm + "m until " + wakeLabel

                if (scheduleModel.count > 0) {
                    let firstBlk = scheduleModel.get(0)
                    root.nextTaskTitle = firstBlk.title
                    root.nextTaskTime = firstBlk.timeLabel
                } else {
                    root.nextTaskTitle = "Wake up & get ready"
                    root.nextTaskTime = wakeLabel
                }
            }
        }
    }

    Timer {
        id: liveClockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateLiveClock()
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

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") {
            fallbackMonitorTimer.start()
        }
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        stateFile.reload()
        root.updateLiveClock()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: dashboardWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.hudMode

            WlrLayershell.keyboardFocus: (visible && isTargetMonitor) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-daily-planner"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (root.editingBlockIndex !== -1) {
                        root.editingBlockIndex = -1
                    } else if (root.editMode) {
                        root.editMode = false
                        root.saveStateNow()
                    } else {
                        root.safeQuit()
                    }
                }
            }

            Shortcut {
                sequence: "Alt+M"
                onActivated: {
                    root.hudMode = !root.hudMode
                    root.saveStateNow()
                }
            }

            Shortcut {
                sequence: "Alt+E"
                onActivated: {
                    root.editMode = !root.editMode
                    if (!root.editMode) root.editingBlockIndex = -1
                    root.saveStateNow()
                }
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
                onClicked: root.safeQuit()
            }

            Rectangle {
                id: mainCard
                width: Math.min(1180, parent.width - 40)
                height: Math.min(790, parent.height - 40)
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: root.editMode ? "#4ade80" : Qt.alpha(root.themePrimary, 0.45)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                antialiasing: true
                clip: true

                property bool shown: false
                Component.onCompleted: shown = true

                scale: shown ? 1.0 : 0.92
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

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        mainCard.forceActiveFocus()
                        mouse.accepted = true
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.minimumHeight: 44
                        Layout.maximumHeight: 44
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 10
                            color: Qt.alpha(root.themePrimary, 0.16)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.40)

                            Text {
                                anchors.centerIn: parent
                                text: root.activeRoutineMode === "travel" ? "🚆" : "󰃭"
                                font.pixelSize: 18
                                color: root.themePrimary
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: "Daily Study Planner"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: modeSwitcherRow.implicitWidth + 10
                            radius: 10
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.10)

                            RowLayout {
                                id: modeSwitcherRow
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: [
                                        { key: "auto", label: "Auto (" + ((root.currentDayOfWeek >= 1 && root.currentDayOfWeek <= 4) ? "Mon-Thu" : "Fri-Sun") + ")", isAuto: true },
                                        { key: "weekday", label: "Mon–Thu", isAuto: false },
                                        { key: "weekend", label: "Fri–Sun", isAuto: false },
                                        { key: "travel", label: "🚆 Travel", isAuto: false }
                                    ]
                                    delegate: Rectangle {
                                        property bool isSelected: modelData.isAuto
                                            ? root.autoRoutineMode
                                            : (!root.autoRoutineMode && root.activeRoutineMode === modelData.key)

                                        Layout.preferredHeight: 28
                                        Layout.preferredWidth: modePillTxt.implicitWidth + 16
                                        radius: 7
                                        color: isSelected
                                            ? (modelData.key === "travel" ? Qt.rgba(56, 189, 248, 0.28) : Qt.alpha(root.themePrimary, 0.28))
                                            : (modePillMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                                        border.width: isSelected ? 1 : 0
                                        border.color: modelData.key === "travel" ? "#38bdf8" : root.themePrimary

                                        Text {
                                            id: modePillTxt
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.pixelSize: 11
                                            font.weight: parent.isSelected ? Font.Bold : Font.Medium
                                            color: parent.isSelected ? "#FFFFFF" : root.themeTextMuted
                                        }

                                        MouseArea {
                                            id: modePillMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.isAuto) {
                                                    root.switchRoutineMode(root.getAutoModeForToday(), true)
                                                } else {
                                                    root.switchRoutineMode(modelData.key, false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: 78
                            radius: 10
                            color: root.editMode
                                ? Qt.rgba(74, 222, 128, 0.24)
                                : (editBtnMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.rgba(255, 255, 255, 0.08))
                            border.width: 1
                            border.color: root.editMode ? "#4ade80" : Qt.alpha(root.themePrimary, 0.45)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: root.editMode ? "✓" : "✎"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.editMode ? "#4ade80" : root.themePrimary
                                }
                                Text {
                                    text: root.editMode ? "Done" : "Edit"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: editBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.editMode = !root.editMode
                                    if (!root.editMode) root.editingBlockIndex = -1
                                    root.saveStateNow()
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: 94
                            radius: 10
                            color: hudBtnMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            border.color: Qt.alpha(root.themePrimary, 0.45)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰐃"
                                    font.pixelSize: 13
                                    color: root.themePrimary
                                }
                                Text {
                                    text: "Pin HUD"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: hudBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.hudMode = true
                                    root.saveStateNow()
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        Layout.minimumHeight: 54
                        Layout.maximumHeight: 54
                        spacing: 15

                        Repeater {
                            model: [
                                { key: "wake", label: "WAKE UP TARGET", val: root.targetWakeUp, icon: "󰖙", accent: root.themePrimary },
                                { key: "core", label: "CORE STUDY BLOCK", val: root.targetCoreStudy, icon: "󰂺", accent: "#38bdf8" },
                                { key: "class", label: "EVENING CLASSES (MON–THU)", val: root.targetClasses, icon: "󰑴", accent: root.activeRoutineMode === "weekend" ? "#4ade80" : (root.activeRoutineMode === "travel" ? "#fbbf24" : root.themePrimary) },
                                { key: "sleep", label: "SLEEP TARGET", val: root.targetSleep, icon: "󰤄", accent: "#a78bfa" }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 54
                                radius: 12
                                color: Qt.rgba(0, 0, 0, 0.28)
                                border.width: 1
                                border.color: root.editMode ? Qt.alpha("#4ade80", 0.55) : Qt.rgba(255, 255, 255, 0.08)
                                antialiasing: true
                                clip: true

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 8
                                        color: Qt.alpha(modelData.accent, 0.16)
                                        border.width: 1
                                        border.color: Qt.alpha(modelData.accent, 0.35)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.pixelSize: 15
                                            color: modelData.accent
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        Text {
                                            text: modelData.label
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.6
                                            color: root.themeTextMuted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            visible: !root.editMode
                                            text: modelData.val
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: modelData.key === "class" && root.activeRoutineMode !== "weekday" ? modelData.accent : "#FFFFFF"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        TextField {
                                            visible: root.editMode
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22
                                            text: modelData.val
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: "#4ade80"
                                            leftPadding: 6
                                            rightPadding: 6
                                            topPadding: 0
                                            bottomPadding: 0
                                            background: Rectangle {
                                                radius: 4
                                                color: Qt.rgba(255, 255, 255, 0.06)
                                                border.width: 1
                                                border.color: parent.activeFocus ? "#4ade80" : Qt.rgba(255, 255, 255, 0.15)
                                            }
                                            onTextEdited: {
                                                if (modelData.key === "wake") root.targetWakeUp = text
                                                else if (modelData.key === "core") root.targetCoreStudy = text
                                                else if (modelData.key === "class") root.targetClasses = text
                                                else if (modelData.key === "sleep") root.targetSleep = text
                                                root.updateLiveClock()
                                                root.scheduleSave()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(255, 255, 255, 0.10)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 590
                            Layout.minimumWidth: 460
                            Layout.maximumWidth: 640
                            Layout.fillHeight: true
                            spacing: 12

                            Rectangle {
                                visible: root.editingBlockIndex === -1
                                Layout.fillWidth: true
                                Layout.preferredHeight: 168
                                Layout.minimumHeight: 168
                                Layout.maximumHeight: 168
                                radius: root.themeRounding
                                color: Qt.rgba(0, 0, 0, 0.30)
                                border.width: 1
                                border.color: Qt.alpha(root.getCategoryColor(root.activeTaskCategory), 0.48)
                                antialiasing: true
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 22
                                        Layout.minimumHeight: 22
                                        Layout.maximumHeight: 22
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 56
                                            Layout.preferredHeight: 20
                                            radius: 5
                                            color: Qt.alpha(root.getCategoryColor(root.activeTaskCategory), 0.22)
                                            border.width: 1
                                            border.color: root.getCategoryColor(root.activeTaskCategory)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 5
                                                Rectangle {
                                                    Layout.preferredWidth: 6
                                                    Layout.preferredHeight: 6
                                                    radius: 3
                                                    color: root.getCategoryColor(root.activeTaskCategory)
                                                }
                                                Text {
                                                    text: "LIVE"
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                    color: "#FFFFFF"
                                                }
                                            }
                                        }

                                        Text {
                                            text: root.activeTaskTimeRange
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: root.themePrimary
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: root.activeRemainingStr
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                    }

                                    Text {
                                        text: root.activeTaskTitle
                                        font.pixelSize: 20
                                        font.weight: Font.Bold
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        verticalAlignment: Text.AlignVCenter
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    }

                                    Text {
                                        text: root.activeTaskDesc
                                        font.pixelSize: 12
                                        color: root.themeTextMuted
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 6
                                        Layout.minimumHeight: 6
                                        Layout.maximumHeight: 6
                                        Layout.topMargin: 4
                                        Layout.bottomMargin: 2
                                        radius: 3
                                        color: Qt.rgba(255, 255, 255, 0.09)
                                        clip: true

                                        Rectangle {
                                            width: parent.width * root.activeBlockProgress
                                            height: parent.height
                                            radius: 3
                                            color: root.getCategoryColor(root.activeTaskCategory)
                                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 20
                                        Layout.minimumHeight: 20
                                        Layout.maximumHeight: 20
                                        spacing: 6

                                        Text {
                                            text: "NEXT UP:"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: root.themePrimary
                                        }

                                        Text {
                                            text: root.nextTaskTitle + "  •  " + root.nextTaskTime
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: root.themeTextMuted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.editingBlockIndex !== -1
                                Layout.fillWidth: true
                                Layout.preferredHeight: 200
                                Layout.minimumHeight: 200
                                Layout.maximumHeight: 200
                                radius: root.themeRounding
                                color: Qt.rgba(0.06, 0.10, 0.08, 0.94)
                                border.width: 1.5
                                border.color: "#4ade80"
                                antialiasing: true
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24
                                        spacing: 8

                                        Text {
                                            text: "✎ EDIT BLOCK #" + (root.editingBlockIndex + 1)
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: "#4ade80"
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 22
                                            Layout.preferredWidth: secTxt.implicitWidth + 16
                                            radius: 5
                                            color: Qt.rgba(255, 255, 255, 0.10)
                                            border.width: 1
                                            border.color: Qt.rgba(255, 255, 255, 0.22)
                                            Text {
                                                id: secTxt
                                                anchors.centerIn: parent
                                                text: root.editBlockSection === "morning" ? "Section: 01 Morning" : "Section: 02 Afternoon"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.editBlockSection = (root.editBlockSection === "morning" ? "afternoon" : "morning")
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            Layout.preferredWidth: 68
                                            Layout.preferredHeight: 24
                                            radius: 5
                                            color: "#4ade80"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Save"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#121214"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.saveEditedBlock()
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 60
                                            Layout.preferredHeight: 24
                                            radius: 5
                                            color: Qt.rgba(255, 255, 255, 0.12)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Cancel"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.editingBlockIndex = -1
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 60
                                            Layout.preferredHeight: 24
                                            radius: 5
                                            color: Qt.rgba(239, 68, 68, 0.2)
                                            border.width: 1
                                            border.color: "#ef4444"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Delete"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#ef4444"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.deleteScheduleBlock(root.editingBlockIndex)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 22
                                        spacing: 6

                                        Text {
                                            text: "CATEGORY:"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: root.themeTextMuted
                                        }

                                        Repeater {
                                            model: ["study", "cyber", "growth", "break", "routine", "review"]
                                            delegate: Rectangle {
                                                Layout.preferredHeight: 20
                                                Layout.preferredWidth: catLbl.implicitWidth + 14
                                                radius: 4
                                                color: root.editBlockCat === modelData ? Qt.alpha(root.getCategoryColor(modelData), 0.3) : Qt.rgba(255, 255, 255, 0.06)
                                                border.width: 1
                                                border.color: root.editBlockCat === modelData ? root.getCategoryColor(modelData) : "transparent"
                                                Text {
                                                    id: catLbl
                                                    anchors.centerIn: parent
                                                    text: modelData.toUpperCase()
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                    color: root.editBlockCat === modelData ? "#FFFFFF" : root.themeTextMuted
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.editBlockCat = modelData
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.preferredWidth: 100
                                            Layout.maximumWidth: 100
                                            spacing: 2
                                            Text { text: "Start Time"; font.pixelSize: 9; color: root.themeTextMuted }
                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                text: root.editBlockStartStr
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                leftPadding: 8
                                                rightPadding: 8
                                                background: Rectangle {
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.07)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? "#4ade80" : Qt.rgba(255, 255, 255, 0.15)
                                                }
                                                onTextEdited: root.editBlockStartStr = text
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.preferredWidth: 100
                                            Layout.maximumWidth: 100
                                            spacing: 2
                                            Text { text: "End Time"; font.pixelSize: 9; color: root.themeTextMuted }
                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                text: root.editBlockEndStr
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                leftPadding: 8
                                                rightPadding: 8
                                                background: Rectangle {
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.07)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? "#4ade80" : Qt.rgba(255, 255, 255, 0.15)
                                                }
                                                onTextEdited: root.editBlockEndStr = text
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 80
                                            spacing: 2
                                            Text { text: "Task Title"; font.pixelSize: 9; color: root.themeTextMuted }
                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 80
                                                Layout.preferredHeight: 28
                                                text: root.editBlockTitle
                                                color: "#FFFFFF"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                leftPadding: 8
                                                rightPadding: 8
                                                background: Rectangle {
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.07)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? "#4ade80" : Qt.rgba(255, 255, 255, 0.15)
                                                }
                                                onTextEdited: root.editBlockTitle = text
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 80
                                        spacing: 2
                                        Text { text: "What To Do / Instructions"; font.pixelSize: 9; color: root.themeTextMuted }
                                        TextField {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 80
                                            Layout.preferredHeight: 28
                                            text: root.editBlockDetails
                                            placeholderText: "What to do during this block..."
                                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                            color: "#FFFFFF"
                                            font.pixelSize: 11
                                            leftPadding: 8
                                            rightPadding: 8
                                            background: Rectangle {
                                                radius: 6
                                                color: Qt.rgba(255, 255, 255, 0.07)
                                                border.width: 1
                                                border.color: parent.activeFocus ? "#4ade80" : Qt.rgba(255, 255, 255, 0.15)
                                            }
                                            onTextEdited: root.editBlockDetails = text
                                            onAccepted: root.saveEditedBlock()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: root.themeRounding
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                clip: true
                                antialiasing: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: root.activeRoutineMode === "travel"
                                                ? "Travel Timeline"
                                                : (root.activeRoutineMode === "weekend" ? "Fri–Sun Timeline" : "Mon–Thu Timeline")
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            visible: root.editMode
                                            Layout.preferredHeight: 24
                                            Layout.preferredWidth: addBlkTxt.implicitWidth + 14
                                            radius: 6
                                            color: Qt.rgba(74, 222, 128, 0.2)
                                            border.width: 1
                                            border.color: "#4ade80"
                                            Text {
                                                id: addBlkTxt
                                                anchors.centerIn: parent
                                                text: "+ Add Block"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#4ade80"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.addNewScheduleBlock()
                                            }
                                        }

                                        Rectangle {
                                            visible: root.editMode
                                            Layout.preferredHeight: 24
                                            Layout.preferredWidth: sortBlkTxt.implicitWidth + 14
                                            radius: 6
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                            border.width: 1
                                            border.color: Qt.rgba(255, 255, 255, 0.2)
                                            Text {
                                                id: sortBlkTxt
                                                anchors.centerIn: parent
                                                text: "⇅ Sort"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.sortScheduleByTime()
                                            }
                                        }

                                        Repeater {
                                            model: [
                                                { label: "All Blocks", idx: 0 },
                                                { label: "01 Morning", idx: 1 },
                                                { label: "02 Afternoon", idx: 2 }
                                            ]
                                            delegate: Rectangle {
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: filterTxt.implicitWidth + 14
                                                radius: 6
                                                color: root.scheduleFilter === modelData.idx ? Qt.alpha(root.themePrimary, 0.25) : Qt.rgba(255, 255, 255, 0.06)
                                                border.width: 1
                                                border.color: root.scheduleFilter === modelData.idx ? root.themePrimary : "transparent"

                                                Text {
                                                    id: filterTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    font.pixelSize: 11
                                                    font.weight: root.scheduleFilter === modelData.idx ? Font.Bold : Font.Medium
                                                    color: root.scheduleFilter === modelData.idx ? "#FFFFFF" : root.themeTextMuted
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.scheduleFilter = modelData.idx
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 24
                                            Layout.preferredWidth: jumpTxt.implicitWidth + 14
                                            radius: 6
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                            border.width: 1
                                            border.color: Qt.rgba(255, 255, 255, 0.14)
                                            visible: root.activeBlockIndex !== -1 && !root.editMode

                                            Text {
                                                id: jumpTxt
                                                anchors.centerIn: parent
                                                text: "Jump to Live"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: root.themePrimary
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.scheduleFilter = 0
                                                    scrollTimelineTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    ListView {
                                        id: timelineList
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        model: scheduleModel
                                        clip: true
                                        spacing: 0

                                        Timer {
                                            id: scrollTimelineTimer
                                            interval: 60
                                            repeat: false
                                            onTriggered: {
                                                if (root.activeBlockIndex >= 0 && root.activeBlockIndex < scheduleModel.count) {
                                                    timelineList.positionViewAtIndex(root.activeBlockIndex, ListView.Center)
                                                }
                                            }
                                        }

                                        Connections {
                                            target: root
                                            function onScrollRequestCounterChanged() {
                                                scrollTimelineTimer.restart()
                                            }
                                        }

                                        Component.onCompleted: {
                                            scrollTimelineTimer.restart()
                                        }

                                        ScrollBar.vertical: ScrollBar {
                                            id: timelineScrollBar
                                            active: timelineList.moving || timelineList.flicking
                                            policy: ScrollBar.AsNeeded
                                        }

                                        delegate: Item {
                                            id: blockDelegate
                                            property bool matchesFilter: root.scheduleFilter === 0 || (root.scheduleFilter === 1 && model.section === "morning") || (root.scheduleFilter === 2 && model.section === "afternoon")
                                            property bool isLive: index === root.activeBlockIndex
                                            property bool isBeingEdited: index === root.editingBlockIndex
                                            property bool isPast: root.currentMinutes >= model.endMin
                                            property bool isDone: model.manualDone || isPast

                                            visible: matchesFilter
                                            width: timelineList.width - (timelineScrollBar.size < 1.0 ? 10 : 0)
                                            height: matchesFilter ? 64 : 0

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.bottomMargin: 6
                                                radius: 8
                                                color: blockDelegate.isBeingEdited
                                                    ? Qt.rgba(74, 222, 128, 0.18)
                                                    : (blockDelegate.isLive
                                                        ? Qt.alpha(root.themePrimary, 0.18)
                                                        : (rowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.025)))
                                                border.width: (blockDelegate.isLive || blockDelegate.isBeingEdited) ? 1.5 : 1
                                                border.color: blockDelegate.isBeingEdited
                                                    ? "#4ade80"
                                                    : (blockDelegate.isLive ? root.themePrimary : Qt.rgba(255, 255, 255, 0.06))
                                                antialiasing: true

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 12

                                                    Rectangle {
                                                        Layout.preferredWidth: 22
                                                        Layout.preferredHeight: 22
                                                        radius: 6
                                                        color: root.editMode
                                                            ? Qt.rgba(74, 222, 128, 0.2)
                                                            : (model.manualDone
                                                                ? root.themePrimary
                                                                : (blockDelegate.isLive ? Qt.alpha(root.themePrimary, 0.25) : Qt.rgba(255, 255, 255, 0.06)))
                                                        border.width: 1
                                                        border.color: root.editMode
                                                            ? "#4ade80"
                                                            : ((model.manualDone || blockDelegate.isLive) ? root.themePrimary : Qt.rgba(255, 255, 255, 0.2))

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: root.editMode
                                                                ? "✎"
                                                                : (model.manualDone ? "✓" : (blockDelegate.isLive ? "●" : (blockDelegate.isPast ? "✓" : "")))
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: root.editMode
                                                                ? "#4ade80"
                                                                : (model.manualDone ? "#121214" : (blockDelegate.isLive ? root.themePrimary : root.themeTextMuted))
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.preferredWidth: 114
                                                        Layout.minimumWidth: 114
                                                        spacing: 2
                                                        Text {
                                                            text: model.timeLabel
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: blockDelegate.isLive ? root.themePrimary : (blockDelegate.isDone && !root.editMode ? root.themeTextMuted : "#FFFFFF")
                                                        }
                                                        Text {
                                                            text: model.section === "morning" ? "01 MORNING" : "02 AFTERNOON"
                                                            font.pixelSize: 8
                                                            font.weight: Font.Bold
                                                            color: root.getCategoryColor(model.cat)
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 80
                                                        spacing: 2
                                                        Text {
                                                            text: model.title
                                                            font.pixelSize: 14
                                                            font.weight: blockDelegate.isLive ? Font.Bold : Font.DemiBold
                                                            color: (blockDelegate.isDone && !blockDelegate.isLive && !root.editMode) ? root.themeTextMuted : "#FFFFFF"
                                                            font.strikeout: model.manualDone && !root.editMode
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                        Text {
                                                            text: model.details
                                                            font.pixelSize: 11
                                                            color: root.themeTextMuted
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: blockDelegate.isLive && !root.editMode
                                                        Layout.preferredWidth: 50
                                                        Layout.preferredHeight: 20
                                                        radius: 4
                                                        color: root.themePrimary
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "ACTIVE"
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                            color: "#121214"
                                                        }
                                                    }

                                                    RowLayout {
                                                        visible: root.editMode
                                                        spacing: 4
                                                        z: 5

                                                        Rectangle {
                                                            Layout.preferredWidth: 22
                                                            Layout.preferredHeight: 22
                                                            radius: 4
                                                            color: Qt.rgba(255, 255, 255, 0.08)
                                                            Text { anchors.centerIn: parent; text: "↑"; font.pixelSize: 11; color: "#FFFFFF" }
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    if (index > 0) {
                                                                        scheduleModel.move(index, index - 1, 1)
                                                                        root.updateLiveClock()
                                                                        root.saveStateNow()
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Rectangle {
                                                            Layout.preferredWidth: 22
                                                            Layout.preferredHeight: 22
                                                            radius: 4
                                                            color: Qt.rgba(255, 255, 255, 0.08)
                                                            Text { anchors.centerIn: parent; text: "↓"; font.pixelSize: 11; color: "#FFFFFF" }
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    if (index < scheduleModel.count - 1) {
                                                                        scheduleModel.move(index, index + 1, 1)
                                                                        root.updateLiveClock()
                                                                        root.saveStateNow()
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Rectangle {
                                                            Layout.preferredWidth: 22
                                                            Layout.preferredHeight: 22
                                                            radius: 4
                                                            color: Qt.rgba(239, 68, 68, 0.18)
                                                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: "#ef4444"; font.weight: Font.Bold }
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.deleteScheduleBlock(index)
                                                            }
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: rowMouse
                                                    anchors.fill: parent
                                                    anchors.rightMargin: root.editMode ? 84 : 0
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.editMode) {
                                                            root.openBlockEditor(index)
                                                        } else {
                                                            scheduleModel.setProperty(index, "manualDone", !model.manualDone)
                                                            root.saveStateNow()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 460
                            Layout.minimumWidth: 360
                            Layout.fillHeight: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 68
                                Layout.minimumHeight: 68
                                Layout.maximumHeight: 68
                                radius: root.themeRounding
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                antialiasing: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Daily Checklist Progress"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: root.completedChecklistCount + " / " + checklistModel.count + " Completed (" + Math.round((root.completedChecklistCount / root.totalChecklistCount) * 100) + "%)"
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: root.themePrimary
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 8
                                        radius: 4
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                        clip: true

                                        Rectangle {
                                            width: parent.width * (root.completedChecklistCount / root.totalChecklistCount)
                                            height: parent.height
                                            radius: 4
                                            color: root.completedChecklistCount === checklistModel.count && checklistModel.count > 0 ? "#4ade80" : root.themePrimary
                                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                Layout.minimumHeight: 34
                                Layout.maximumHeight: 34
                                spacing: 8

                                Repeater {
                                    model: [
                                        { title: "✓  Daily Checklist (" + checklistModel.count + ")", idx: 0 },
                                        { title: "★  Top 3 Priorities & Notes", idx: 1 }
                                    ]
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: 8
                                        color: root.rightTab === modelData.idx ? Qt.alpha(root.themePrimary, 0.22) : Qt.rgba(0, 0, 0, 0.25)
                                        border.width: 1
                                        border.color: root.rightTab === modelData.idx ? root.themePrimary : Qt.rgba(255, 255, 255, 0.08)
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.title
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: root.rightTab === modelData.idx ? "#FFFFFF" : root.themeTextMuted
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.rightTab = modelData.idx
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.rightTab === 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: root.themeRounding
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                clip: true
                                antialiasing: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        visible: root.editMode
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: grpCycleTxt.implicitWidth + 18
                                            Layout.minimumWidth: grpCycleTxt.implicitWidth + 18
                                            radius: 6
                                            color: Qt.alpha(root.themePrimary, 0.22)
                                            border.width: 1
                                            border.color: root.themePrimary
                                            Text {
                                                id: grpCycleTxt
                                                anchors.centerIn: parent
                                                text: root.newChecklistGroup
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const g = ["ACADEMICS", "CYBERSECURITY", "PERSONAL GROWTH"]
                                                    root.newChecklistGroup = g[(g.indexOf(root.newChecklistGroup) + 1) % g.length]
                                                }
                                            }
                                        }

                                        TextField {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 80
                                            Layout.preferredHeight: 30
                                            text: root.newChecklistTitle
                                            placeholderText: "Add new checklist task..."
                                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                            color: "#FFFFFF"
                                            font.pixelSize: 12
                                            leftPadding: 10
                                            rightPadding: 10
                                            background: Rectangle {
                                                radius: 6
                                                color: Qt.rgba(255, 255, 255, 0.06)
                                                border.width: 1
                                                border.color: parent.activeFocus ? "#4ade80" : Qt.rgba(255, 255, 255, 0.14)
                                            }
                                            onTextEdited: root.newChecklistTitle = text
                                            onAccepted: root.addChecklistItem()
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 62
                                            Layout.minimumWidth: 62
                                            Layout.preferredHeight: 30
                                            radius: 6
                                            color: "#4ade80"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "+ Add"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#121214"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.addChecklistItem()
                                            }
                                        }
                                    }

                                    ListView {
                                        id: checklistView
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        model: checklistModel
                                        spacing: 4
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        ScrollBar.vertical: ScrollBar {
                                            id: checklistScrollBar
                                            active: true
                                            policy: ScrollBar.AsNeeded
                                        }

                                        delegate: ColumnLayout {
                                            id: chkDelegate
                                            width: checklistView.width - (checklistScrollBar.size < 1.0 ? 12 : 0)
                                            spacing: 3

                                            property bool showGroupHeader: {
                                                if (index < 0 || index >= checklistModel.count) return false
                                                if (index === 0) return true
                                                let prev = checklistModel.get(index - 1)
                                                return prev ? (prev.group !== model.group) : true
                                            }

                                            Text {
                                                visible: chkDelegate.showGroupHeader
                                                text: model.group
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                font.letterSpacing: 1.0
                                                color: root.themePrimary
                                                Layout.topMargin: index === 0 ? 0 : 6
                                                Layout.leftMargin: 4
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 34
                                                radius: 8
                                                color: chkMouse.containsMouse && !root.editMode ? Qt.rgba(255, 255, 255, 0.07) : Qt.rgba(255, 255, 255, 0.03)
                                                border.width: 1
                                                border.color: model.done && !root.editMode ? Qt.alpha(root.themePrimary, 0.38) : Qt.rgba(255, 255, 255, 0.06)
                                                antialiasing: true

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 10

                                                    Rectangle {
                                                        visible: !root.editMode
                                                        Layout.preferredWidth: 18
                                                        Layout.preferredHeight: 18
                                                        radius: 5
                                                        color: model.done ? root.themePrimary : "transparent"
                                                        border.width: 1.5
                                                        border.color: model.done ? root.themePrimary : Qt.rgba(255, 255, 255, 0.35)

                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: model.done
                                                            text: "✓"
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: "#121214"
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: root.editMode
                                                        Layout.preferredHeight: 20
                                                        Layout.preferredWidth: itemGrpTxt.implicitWidth + 12
                                                        Layout.minimumWidth: itemGrpTxt.implicitWidth + 12
                                                        radius: 4
                                                        color: Qt.alpha(root.themePrimary, 0.18)
                                                        border.width: 1
                                                        border.color: Qt.alpha(root.themePrimary, 0.45)
                                                        Text {
                                                            id: itemGrpTxt
                                                            anchors.centerIn: parent
                                                            text: model.group === "ACADEMICS" ? "ACAD" : (model.group === "CYBERSECURITY" ? "CYBER" : "GROWTH")
                                                            font.pixelSize: 8
                                                            font.weight: Font.Bold
                                                            color: root.themePrimary
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.cycleChecklistGroup(index)
                                                        }
                                                    }

                                                    Text {
                                                        visible: !root.editMode
                                                        text: model.title
                                                        font.pixelSize: 13
                                                        font.weight: Font.Medium
                                                        color: model.done ? root.themeTextMuted : "#FFFFFF"
                                                        font.strikeout: model.done
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }

                                                    TextField {
                                                        visible: root.editMode
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 60
                                                        Layout.preferredHeight: 26
                                                        text: model.title
                                                        color: "#FFFFFF"
                                                        font.pixelSize: 12
                                                        leftPadding: 6
                                                        rightPadding: 6
                                                        background: Rectangle {
                                                            radius: 4
                                                            color: Qt.rgba(255, 255, 255, 0.06)
                                                            border.width: 1
                                                            border.color: parent.activeFocus ? "#4ade80" : "transparent"
                                                        }
                                                        onTextEdited: {
                                                            checklistModel.setProperty(index, "title", text)
                                                            root.scheduleSave()
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: root.editMode
                                                        Layout.preferredWidth: 22
                                                        Layout.preferredHeight: 22
                                                        radius: 4
                                                        color: Qt.rgba(239, 68, 68, 0.18)
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "✕"
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                            color: "#ef4444"
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                checklistModel.remove(index)
                                                                root.recalculateChecklistProgress()
                                                                root.saveStateNow()
                                                            }
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: chkMouse
                                                    enabled: !root.editMode
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        checklistModel.setProperty(index, "done", !model.done)
                                                        root.recalculateChecklistProgress()
                                                        root.saveStateNow()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: root.rightTab === 1
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 195
                                    radius: root.themeRounding
                                    color: Qt.rgba(0, 0, 0, 0.25)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                    antialiasing: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        Text {
                                            text: "MY TOP 3 PRIORITIES TODAY"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.9
                                            color: root.themePrimary
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 6
                                                color: root.priority1Done ? root.themePrimary : Qt.rgba(255, 255, 255, 0.08)
                                                border.width: 1; border.color: root.themePrimary
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.priority1Done ? "✓" : "1"
                                                    font.pixelSize: 11; font.weight: Font.Bold
                                                    color: root.priority1Done ? "#121214" : "#FFFFFF"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { root.priority1Done = !root.priority1Done; root.saveStateNow() }
                                                }
                                            }
                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 60
                                                Layout.preferredHeight: 34
                                                text: root.priority1
                                                placeholderText: "Priority #1 for today..."
                                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                                color: root.priority1Done ? root.themeTextMuted : "#FFFFFF"
                                                font.pixelSize: 13
                                                font.strikeout: root.priority1Done
                                                leftPadding: 10
                                                rightPadding: 10
                                                background: Rectangle {
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.05)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? root.themePrimary : Qt.rgba(255, 255, 255, 0.1)
                                                }
                                                onTextEdited: { root.priority1 = text; root.scheduleSave() }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 6
                                                color: root.priority2Done ? root.themePrimary : Qt.rgba(255, 255, 255, 0.08)
                                                border.width: 1; border.color: root.themePrimary
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.priority2Done ? "✓" : "2"
                                                    font.pixelSize: 11; font.weight: Font.Bold
                                                    color: root.priority2Done ? "#121214" : "#FFFFFF"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { root.priority2Done = !root.priority2Done; root.saveStateNow() }
                                                }
                                            }
                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 60
                                                Layout.preferredHeight: 34
                                                text: root.priority2
                                                placeholderText: "Priority #2 for today..."
                                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                                color: root.priority2Done ? root.themeTextMuted : "#FFFFFF"
                                                font.pixelSize: 13
                                                font.strikeout: root.priority2Done
                                                leftPadding: 10
                                                rightPadding: 10
                                                background: Rectangle {
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.05)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? root.themePrimary : Qt.rgba(255, 255, 255, 0.1)
                                                }
                                                onTextEdited: { root.priority2 = text; root.scheduleSave() }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 6
                                                color: root.priority3Done ? root.themePrimary : Qt.rgba(255, 255, 255, 0.08)
                                                border.width: 1; border.color: root.themePrimary
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.priority3Done ? "✓" : "3"
                                                    font.pixelSize: 11; font.weight: Font.Bold
                                                    color: root.priority3Done ? "#121214" : "#FFFFFF"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { root.priority3Done = !root.priority3Done; root.saveStateNow() }
                                                }
                                            }
                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 60
                                                Layout.preferredHeight: 34
                                                text: root.priority3
                                                placeholderText: "Priority #3 for today..."
                                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                                color: root.priority3Done ? root.themeTextMuted : "#FFFFFF"
                                                font.pixelSize: 13
                                                font.strikeout: root.priority3Done
                                                leftPadding: 10
                                                rightPadding: 10
                                                background: Rectangle {
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.05)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? root.themePrimary : Qt.rgba(255, 255, 255, 0.1)
                                                }
                                                onTextEdited: { root.priority3 = text; root.scheduleSave() }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: root.themeRounding
                                    color: Qt.rgba(0, 0, 0, 0.25)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                    antialiasing: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "NOTES FOR TOMORROW"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.9
                                            color: root.themePrimary
                                        }

                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true

                                            TextArea {
                                                text: root.notesTomorrow
                                                placeholderText: "Write topics to revise, Kali tools to explore next, or unfinished tasks for tomorrow..."
                                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                                color: "#FFFFFF"
                                                font.pixelSize: 13
                                                wrapMode: TextEdit.Wrap
                                                leftPadding: 10
                                                rightPadding: 10
                                                topPadding: 8
                                                bottomPadding: 8
                                                background: Rectangle {
                                                    radius: 8
                                                    color: Qt.rgba(255, 255, 255, 0.04)
                                                    border.width: 1
                                                    border.color: parent.activeFocus ? root.themePrimary : Qt.rgba(255, 255, 255, 0.08)
                                                }
                                                onTextChanged: {
                                                    if (root.stateLoadedOnce && root.notesTomorrow !== text) {
                                                        root.notesTomorrow = text
                                                        root.scheduleSave()
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
                        Layout.preferredHeight: 36
                        Layout.minimumHeight: 36
                        Layout.maximumHeight: 36
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        radius: Math.max(4, root.themeRounding - 6)
                        antialiasing: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                visible: !root.editMode
                                text: "💡 \"" + root.footerMantra + "\""
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.themeTextMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                            }

                            TextField {
                                visible: root.editMode
                                Layout.fillWidth: true
                                Layout.minimumWidth: 100
                                Layout.preferredHeight: 24
                                text: root.footerMantra
                                placeholderText: "Enter daily mantra..."
                                color: "#4ade80"
                                font.pixelSize: 11
                                leftPadding: 6
                                rightPadding: 6
                                background: Rectangle {
                                    radius: 4
                                    color: Qt.rgba(255, 255, 255, 0.06)
                                    border.width: 1
                                    border.color: "#4ade80"
                                }
                                onTextEdited: {
                                    root.footerMantra = text
                                    root.scheduleSave()
                                }
                            }

                            Rectangle {
                                visible: root.editMode
                                Layout.preferredWidth: 124
                                Layout.preferredHeight: 22
                                radius: 4
                                color: Qt.rgba(251, 191, 36, 0.16)
                                border.width: 1; border.color: "#fbbf24"
                                antialiasing: true
                                Text {
                                    anchors.centerIn: parent
                                    text: "RESTORE DEFAULTS"
                                    font.pixelSize: 9
                                    color: "#fbbf24"
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.populateDefaults()
                                        root.updateLiveClock()
                                        root.saveStateNow()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 78
                                Layout.preferredHeight: 22
                                radius: 4
                                color: Qt.rgba(239, 68, 68, 0.15)
                                border.width: 1; border.color: Qt.rgba(239, 68, 68, 0.35)
                                antialiasing: true
                                Text {
                                    anchors.centerIn: parent
                                    text: "RESET DAY"
                                    font.pixelSize: 10
                                    color: "#ef4444"
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.resetDailyProgress()
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 22
                                radius: 4
                                color: Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.15)
                                antialiasing: true
                                Text {
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    font.pixelSize: 10
                                    color: "#FFFFFF"
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.safeQuit()
                                }
                            }

                            Text {
                                text: "Close"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: root.themeTextMuted
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.safeQuit()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: miniHudWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor && root.hudMode

            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-daily-planner-hud"
            WlrLayershell.layer: WlrLayer.Top
            exclusiveZone: 0

            anchors {
                top: true
                right: true
            }

            margins {
                top: 16
                right: 16
            }

            implicitWidth: 390
            implicitHeight: 178
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.55)
                color: Qt.alpha(root.themeBackground, 0.82)
                antialiasing: true
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10
                            radius: 5
                            color: root.getCategoryColor(root.activeTaskCategory)
                        }

                        Text {
                            text: root.activeTaskTimeRange
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.themePrimary
                        }

                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: hudModeTxt.implicitWidth + 10
                            radius: 4
                            color: Qt.rgba(255, 255, 255, 0.08)
                            Text {
                                id: hudModeTxt
                                anchors.centerIn: parent
                                text: root.activeRoutineMode === "travel" ? "🚆 TRAVEL" : (root.activeRoutineMode === "weekend" ? "FRI-SUN" : "MON-THU")
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: root.themeTextMuted
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.activeRemainingStr
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                        }

                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 22
                            radius: 5
                            color: Qt.alpha(root.themePrimary, 0.22)
                            border.width: 1
                            border.color: root.themePrimary

                            Text {
                                anchors.centerIn: parent
                                text: "Expand"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.hudMode = false
                                    root.scrollRequestCounter++
                                    root.saveStateNow()
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 5
                            color: Qt.rgba(255, 255, 255, 0.1)
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 10
                                color: root.themeTextMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.safeQuit()
                            }
                        }
                    }

                    Text {
                        text: root.activeTaskTitle
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: root.activeTaskDesc
                        font.pixelSize: 11
                        color: root.themeTextMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        Layout.minimumHeight: 5
                        Layout.maximumHeight: 5
                        Layout.topMargin: 4
                        Layout.bottomMargin: 2
                        radius: 2.5
                        color: Qt.rgba(255, 255, 255, 0.1)
                        clip: true

                        Rectangle {
                            width: parent.width * root.activeBlockProgress
                            height: parent.height
                            radius: 2.5
                            color: root.getCategoryColor(root.activeTaskCategory)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        spacing: 8

                        Text {
                            text: "Next: " + root.nextTaskTitle + " (" + root.nextTaskTime + ")"
                            font.pixelSize: 10
                            color: root.themeTextMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "✓ " + root.completedChecklistCount + "/" + checklistModel.count
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.themePrimary
                        }
                    }
                }
            }
        }
    }
}