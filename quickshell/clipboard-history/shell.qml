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

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"

    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(0.03, 0.03, 0.05, 0.58)
    property color themeSurfaceHover: Qt.rgba(0.10, 0.10, 0.14, 0.74)

    property string searchQuery: ""
    property int selectedIndex: 0
    property var allItems: []

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    function quitApp() {
        if (root.isClosing) return
        root.isClosing = true
        Qt.quit()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
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

    ListModel { id: clipboardModel }

    Process { id: execProcess }
    function exec(cmd) {
        execProcess.running = false
        execProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        execProcess.running = true
    }

    function applyFilter() {
        let q = root.searchQuery.trim().toLowerCase()
        clipboardModel.clear()
        for (let i = 0; i < root.allItems.length; i++) {
            let item = root.allItems[i]
            if (q === "" || item.content.toLowerCase().indexOf(q) !== -1 || item.meta.toLowerCase().indexOf(q) !== -1) {
                clipboardModel.append(item)
            }
        }
        root.selectedIndex = clipboardModel.count > 0 ? 0 : -1
    }

    Process {
        id: fetchClipboardProcess
        running: false
        command: ["cliphist", "list"]
        stdout: StdioCollector { id: clipboardCollector }

        onExited: (exitCode) => {
            root.allItems = []
            clipboardModel.clear()
            if (exitCode !== 0 || !clipboardCollector.text) return

            let rawText = clipboardCollector.text.replace(/\r/g, "")
            let lines = rawText.split("\n")
            let parsed = []
            let maxItems = Math.min(lines.length, 80)

            for (let i = 0; i < maxItems; i++) {
                let line = lines[i]
                if (!line || line.trim() === "") continue
                let tabIndex = line.indexOf("\t")
                if (tabIndex === -1) continue

                let cid = line.substring(0, tabIndex).trim()
                let rawContent = line.substring(tabIndex + 1)
                let isImg = rawContent.indexOf("[[ binary data") !== -1
                let displayTxt = rawContent.trim()
                let metaText = ""

                if (isImg) {
                    let cleanedInfo = rawContent.replace("[[ binary data ", "").replace(" ]]", "").trim()
                    let parts = cleanedInfo.split(/\s+/)
                    if (parts.length >= 4) {
                        let sizeStr = parts[0] + " " + parts[1]
                        let fmtStr = parts[2].toUpperCase()
                        let dimStr = parts[3].replace("x", " × ")
                        displayTxt = fmtStr + " Image (" + dimStr + ")"
                        metaText = sizeStr
                    } else {
                        displayTxt = "Clipboard Image"
                        metaText = cleanedInfo
                    }
                } else {
                    metaText = "#" + cid + " • " + displayTxt.length + " chars"
                }

                parsed.push({
                    "id": cid,
                    "raw": line,
                    "content": displayTxt,
                    "meta": metaText,
                    "isImage": isImg
                })
            }

            root.allItems = parsed
            root.applyFilter()
        }
    }

    function refreshClipboard() {
        fetchClipboardProcess.running = false
        fetchClipboardProcess.running = true
    }

    function copyItem(rawLine) {
        if (!rawLine) return
        let safeLine = rawLine.replace(/'/g, "'\\''")
        exec("printf '%s\\n' '" + safeLine + "' | cliphist decode | wl-copy")
        root.quitApp()
    }

    function deleteItem(index, rawLine) {
        if (!rawLine) return
        let safeLine = rawLine.replace(/'/g, "'\\''")
        exec("printf '%s\\n' '" + safeLine + "' | cliphist delete")

        let updated = []
        for (let i = 0; i < root.allItems.length; i++) {
            if (root.allItems[i].raw !== rawLine) {
                updated.push(root.allItems[i])
            }
        }
        root.allItems = updated

        if (index >= 0 && index < clipboardModel.count) {
            clipboardModel.remove(index)
        }
        if (root.selectedIndex >= clipboardModel.count) {
            root.selectedIndex = Math.max(0, clipboardModel.count - 1)
        }
    }

    function clearAllClipboard() {
        exec("cliphist wipe")
        root.allItems = []
        clipboardModel.clear()
        root.selectedIndex = -1
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") fallbackMonitorTimer.start()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        refreshClipboard()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData && modelData.name ? (modelData.name === root.targetMonitorName) : false
            visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing

            onVisibleChanged: {
                if (visible && isTargetMonitor) {
                    searchInput.forceActiveFocus()
                }
            }

            onIsTargetMonitorChanged: {
                if (isTargetMonitor) {
                    searchInput.forceActiveFocus()
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: root.quitApp()
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-clipboard"
            WlrLayershell.keyboardFocus: (isTargetMonitor && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                enabled: !root.isClosing
                onClicked: root.quitApp()
            }

            Item {
                id: dragContainer
                width: 470
                height: 660
                x: (win.width - width) / 2
                y: (win.height - height) / 2

                visible: root.targetMonitorName !== "" && isTargetMonitor && !root.isClosing
                focus: isTargetMonitor

                Keys.onEscapePressed: (event) => {
                    if (root.isClosing) return
                    event.accepted = true
                    root.quitApp()
                }

                Keys.onPressed: (event) => {
                    if (root.isClosing) return
                    if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        root.quitApp()
                    } else if (event.key === Qt.Key_Down) {
                        if (clipboardModel.count > 0) {
                            root.selectedIndex = Math.min(clipboardModel.count - 1, root.selectedIndex + 1)
                            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (clipboardModel.count > 0) {
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.selectedIndex >= 0 && root.selectedIndex < clipboardModel.count) {
                            root.copyItem(clipboardModel.get(root.selectedIndex).raw)
                        }
                        event.accepted = true
                    }
                }

                DragHandler {
                    target: dragContainer
                    enabled: !root.isClosing
                    cursorShape: Qt.ClosedHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        mouse.accepted = true
                        searchInput.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: container
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.40)
                    antialiasing: true
                    clip: true

                    property bool shown: false
                    property bool settled: false
                    property bool panelVisible: shown && !root.isClosing

                    layer.enabled: root.animEnabled && !settled && !root.isClosing
                    layer.smooth: true

                    Component.onCompleted: {
                        enterTriggerTimer.start()
                        settleTimer.start()
                        if (win.isTargetMonitor) searchInput.forceActiveFocus()
                    }

                    Timer {
                        id: enterTriggerTimer
                        interval: 16
                        repeat: false
                        onTriggered: container.shown = true
                    }

                    Timer {
                        id: settleTimer
                        interval: animStyle.enterDuration + 60
                        repeat: false
                        onTriggered: container.settled = true
                    }

                    opacity: panelVisible ? 1.0 : 0.0
                    enabled: !root.isClosing

                    transform: [
                        Scale {
                            origin.x: container.width / 2
                            origin.y: container.height / 2
                            xScale: container.panelVisible ? 1.0 : 0.94
                            yScale: container.panelVisible ? 1.0 : 0.94

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        },
                        Translate {
                            y: container.panelVisible ? 0 : 12

                            Behavior on y {
                                NumberAnimation {
                                    duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.enterDuration : 0
                                    easing.type: animStyle.expoEasing
                                }
                            }
                        }
                    ]

                    Behavior on opacity {
                        NumberAnimation {
                            duration: (root.animEnabled && !root.isClosing && container.panelVisible) ? animStyle.fadeDuration : 0
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
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 11
                                color: Qt.alpha(root.themePrimary, 0.16)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.35)
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅍"
                                    font.family: root.iconFontFamily
                                    color: root.themePrimary
                                    font.pixelSize: 18
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: "Clipboard"
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    Rectangle {
                                        opacity: clipboardModel.count > 0 ? 1.0 : 0.0
                                        visible: opacity > 0
                                        Layout.preferredWidth: badgeText.implicitWidth + 14
                                        Layout.preferredHeight: 20
                                        radius: 6
                                        color: Qt.alpha(root.themePrimary, 0.18)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.4)
                                        antialiasing: true

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }

                                        Behavior on Layout.preferredWidth {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.morphDuration : 0
                                                easing.type: animStyle.expoEasing
                                            }
                                        }

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: clipboardModel.count.toString()
                                            color: root.themePrimary
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Text {
                                    text: "Click or press Enter to copy"
                                    color: root.themeTextMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: root.allItems.length > 0
                                Layout.preferredWidth: clearRow.implicitWidth + 20
                                Layout.preferredHeight: 34
                                radius: clearBtnArea.containsMouse ? 11 : 9
                                color: clearBtnArea.containsMouse
                                       ? Qt.rgba(0.93, 0.26, 0.26, 0.32)
                                       : root.themeSurface
                                border.width: 1
                                border.color: clearBtnArea.containsMouse ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.14)
                                antialiasing: true
                                scale: clearBtnArea.pressed ? 0.95 : (clearBtnArea.containsMouse ? 1.04 : 1.0)

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

                                RowLayout {
                                    id: clearRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰆴"
                                        font.family: root.iconFontFamily
                                        color: clearBtnArea.containsMouse ? "#ff6b6b" : root.themeTextMuted
                                        font.pixelSize: 13
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Clear All"
                                        color: clearBtnArea.containsMouse ? "#ff6b6b" : root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: clearBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearAllClipboard()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 10
                            color: Qt.rgba(0.02, 0.02, 0.03, 0.58)
                            border.width: searchInput.activeFocus ? 1.5 : 1
                            border.color: searchInput.activeFocus ? Qt.alpha(root.themePrimary, 0.7) : Qt.rgba(1, 1, 1, 0.14)
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
                                    text: "󰍉"
                                    font.family: root.iconFontFamily
                                    color: searchInput.activeFocus ? root.themePrimary : root.themeTextMuted
                                    font.pixelSize: 15
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: Text.AlignVCenter
                                    color: root.themeText
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    selectionColor: Qt.alpha(root.themePrimary, 0.35)
                                    selectedTextColor: root.themeText
                                    clip: true

                                    Text {
                                        text: "Search clipboard history..."
                                        color: Qt.rgba(1, 1, 1, 0.38)
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: !searchInput.text ? 1.0 : 0.0
                                        visible: opacity > 0
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    onTextChanged: {
                                        root.searchQuery = text
                                        root.applyFilter()
                                    }

                                    Keys.onEscapePressed: (event) => {
                                        if (root.isClosing) return
                                        event.accepted = true
                                        root.quitApp()
                                    }

                                    Keys.onPressed: (event) => {
                                        if (root.isClosing) return
                                        if (event.key === Qt.Key_Escape) {
                                            event.accepted = true
                                            root.quitApp()
                                        } else if (event.key === Qt.Key_Down) {
                                            if (clipboardModel.count > 0) {
                                                root.selectedIndex = Math.min(clipboardModel.count - 1, root.selectedIndex + 1)
                                                clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                            }
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Up) {
                                            if (clipboardModel.count > 0) {
                                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                                                clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                            }
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (root.selectedIndex >= 0 && root.selectedIndex < clipboardModel.count) {
                                                root.copyItem(clipboardModel.get(root.selectedIndex).raw)
                                            }
                                            event.accepted = true
                                        }
                                    }
                                }

                                Rectangle {
                                    opacity: searchInput.text !== "" ? 1.0 : 0.0
                                    visible: opacity > 0
                                    width: 22
                                    height: 22
                                    radius: 6
                                    color: clearSearchMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                    scale: clearSearchMouse.pressed ? 0.90 : (clearSearchMouse.containsMouse ? 1.08 : 1.0)

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
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: root.iconFontFamily
                                        color: clearSearchMouse.containsMouse ? root.themeText : root.themeTextMuted
                                        font.pixelSize: 12
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                easing.type: animStyle.smoothEasing
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: clearSearchMouse
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

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                opacity: clipboardModel.count === 0 ? 1.0 : 0.0
                                visible: opacity > 0
                                spacing: 12

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 54
                                    height: 54
                                    radius: 16
                                    color: Qt.rgba(0.02, 0.02, 0.03, 0.5)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.25)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅢"
                                        font.family: root.iconFontFamily
                                        color: root.themePrimary
                                        opacity: 0.65
                                        font.pixelSize: 24
                                    }
                                }

                                ColumnLayout {
                                    spacing: 3
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.searchQuery !== "" ? "No Matching Items" : "Clipboard Empty"
                                        color: root.themeText
                                        font.family: root.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.searchQuery !== "" ? "Try a different search term" : "Copied items will appear here"
                                        color: root.themeTextMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                                    }
                                }
                            }

                            ListView {
                                id: clipList
                                anchors.fill: parent
                                opacity: clipboardModel.count > 0 ? 1.0 : 0.0
                                visible: opacity > 0
                                model: clipboardModel
                                spacing: 2
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    id: vbar
                                    visible: clipboardModel.count > 0 && vbar.size < 1.0
                                    active: clipList.moving || clipList.flicking || hovered
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                    }
                                }

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

                                remove: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            to: 0.0
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            to: 0.96
                                            duration: (root.animEnabled && !root.isClosing) ? animStyle.fadeDuration : 0
                                            easing.type: animStyle.smoothEasing
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

                                delegate: Item {
                                    id: delegateRoot
                                    width: clipList.width
                                    height: 74

                                    property bool isHighlighted: cardArea.containsMouse || (index === root.selectedIndex)

                                    Rectangle {
                                        id: card
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: vbar.visible ? 12 : 4
                                        anchors.topMargin: 3
                                        anchors.bottomMargin: 3
                                        radius: Math.max(8, root.themeRounding - 8)
                                        color: delegateRoot.isHighlighted
                                               ? root.mixColor(root.themeBackground, root.themePrimary, 0.18, 0.72)
                                               : root.themeSurface
                                        border.width: 1
                                        border.color: delegateRoot.isHighlighted
                                                      ? Qt.alpha(root.themePrimary, 0.65)
                                                      : Qt.rgba(1, 1, 1, 0.12)
                                        antialiasing: true

                                        scale: cardArea.pressed ? 0.98 : (delegateRoot.isHighlighted ? 1.012 : 1.0)

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

                                        MouseArea {
                                            id: cardArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: root.selectedIndex = index
                                            onClicked: root.copyItem(model.raw)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 12

                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: 40
                                                Layout.preferredHeight: 40
                                                radius: 10
                                                color: model.isImage
                                                       ? Qt.rgba(0.96, 0.62, 0.04, 0.18)
                                                       : Qt.alpha(root.themePrimary, 0.16)
                                                border.width: 1
                                                border.color: model.isImage
                                                              ? Qt.rgba(0.96, 0.62, 0.04, 0.45)
                                                              : Qt.alpha(root.themePrimary, 0.35)
                                                antialiasing: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: model.isImage ? "󰋩" : "󰈙"
                                                    font.family: root.iconFontFamily
                                                    color: model.isImage ? "#f59e0b" : root.themePrimary
                                                    font.pixelSize: 18
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 3

                                                RowLayout {
                                                    spacing: 6
                                                    Layout.alignment: Qt.AlignVCenter

                                                    Text {
                                                        text: model.isImage ? "IMAGE" : "TEXT"
                                                        color: model.isImage ? "#f59e0b" : root.themePrimary
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.65)
                                                    }

                                                    Text {
                                                        text: "•"
                                                        color: root.themeTextMuted
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                    }

                                                    Text {
                                                        text: model.meta
                                                        color: root.themeTextMuted
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        style: Text.Raised
                                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                                    }
                                                }

                                                Text {
                                                    text: model.content
                                                    color: root.themeText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                                }
                                            }

                                            RowLayout {
                                                spacing: 6
                                                Layout.alignment: Qt.AlignVCenter

                                                Rectangle {
                                                    Layout.preferredWidth: 32
                                                    Layout.preferredHeight: 32
                                                    radius: copyBtnMouse.containsMouse ? 10 : 8
                                                    color: copyBtnMouse.containsMouse
                                                           ? Qt.alpha(root.themePrimary, 0.25)
                                                           : Qt.rgba(0.02, 0.02, 0.03, 0.45)
                                                    border.width: 1
                                                    border.color: copyBtnMouse.containsMouse
                                                                  ? root.themePrimary
                                                                  : Qt.rgba(1, 1, 1, 0.12)
                                                    antialiasing: true
                                                    scale: copyBtnMouse.pressed ? 0.90 : (copyBtnMouse.containsMouse ? 1.06 : 1.0)

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
                                                        text: "󰆏"
                                                        font.family: root.iconFontFamily
                                                        color: copyBtnMouse.containsMouse ? root.themePrimary : root.themeTextMuted
                                                        font.pixelSize: 14
                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: (root.animEnabled && !root.isClosing) ? animStyle.microDuration : 0
                                                                easing.type: animStyle.smoothEasing
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: copyBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.copyItem(model.raw)
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 32
                                                    Layout.preferredHeight: 32
                                                    radius: delBtnMouse.containsMouse ? 10 : 8
                                                    color: delBtnMouse.containsMouse
                                                           ? Qt.rgba(0.93, 0.26, 0.26, 0.32)
                                                           : Qt.rgba(0.02, 0.02, 0.03, 0.45)
                                                    border.width: 1
                                                    border.color: delBtnMouse.containsMouse
                                                                  ? "#ff6b6b"
                                                                  : Qt.rgba(1, 1, 1, 0.12)
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
                                                        text: "󰆴"
                                                        font.family: root.iconFontFamily
                                                        color: delBtnMouse.containsMouse ? "#ff6b6b" : root.themeTextMuted
                                                        font.pixelSize: 14
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
                                                        onClicked: root.deleteItem(index, model.raw)
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
    }
}