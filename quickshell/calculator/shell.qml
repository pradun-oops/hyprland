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

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 240
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 0.15
    }

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    function quitApp() {
        if (!isCalculated && calcInput.trim() !== "" && calcResult !== "Error") {
            calculate()
        }
        quitTimer.start()
    }

    Timer {
        id: quitTimer
        interval: 100
        repeat: false
        onTriggered: Qt.quit()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.quitApp()
    }

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 20
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(0.04, 0.04, 0.06, 0.55) 
    property color themeSurfaceHover: Qt.rgba(0.12, 0.12, 0.15, 0.70)

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
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

    property string calcInput: ""
    property string calcResult: ""
    property string prevExpr: ""
    property bool isCalculated: true
    property bool isExpertMode: false
    property bool showHistory: false

    ListModel { id: historyModel }

    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.config/quickshell/calculator_history.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text())
                historyModel.clear()
                for (let i = 0; i < data.length; i++) {
                    historyModel.append(data[i])
                }
            } catch(e) {
                historyModel.clear()
            }
        }
    }

    Process { id: saveHistoryProcess; running: false }
    
    function saveHistoryToFile() {
        let arr = []
        for (let i = 0; i < historyModel.count; i++) {
            arr.push({ expr: historyModel.get(i).expr, res: historyModel.get(i).res, time: historyModel.get(i).time })
        }
        let safeJson = JSON.stringify(arr)
        let path = Quickshell.env("HOME") + "/.config/quickshell/calculator_history.json"
        
        saveHistoryProcess.running = false
        saveHistoryProcess.command = [
            "python3", "-c", 
            "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", 
            path, 
            safeJson
        ]
        saveHistoryProcess.running = true
    }

    function clearHistory() {
        historyModel.clear()
        saveHistoryToFile()
    }

    function formatTimeAgo(timestamp) {
        if (!timestamp) return ""
        let diff = Math.floor(Date.now() / 1000) - timestamp
        if (diff < 60) return "Just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }

    function handleInput(val, type) {
        if (calcResult === "Error") calcResult = ""
        
        if (type === "clear") {
            if (!isCalculated && calcInput.trim() !== "") {
                calculate()
            }
            calcInput = ""
            calcResult = ""
            prevExpr = ""
            isCalculated = true
        } else if (type === "backspace") {
            if (isCalculated) {
                calcInput = ""
                prevExpr = ""
                isCalculated = false
            } else {
                calcInput = calcInput.slice(0, -1)
            }
        } else if (type === "equals") {
            calculate()
        } else {
            if (isCalculated && type === "num") {
                prevExpr = ""
                calcInput = val
            } else {
                calcInput += val
            }
            isCalculated = false
        }
    }

    function calculate() {
        if (calcInput.trim() === "") return
        if (isCalculated) return
        
        let safeExpr = calcInput.replace(/÷/g, "/")
                                .replace(/×/g, "*")
                                .replace(/π/g, "Math.PI")
                                .replace(/e/g, "Math.E")
                                .replace(/sin\(/g, "Math.sin(")
                                .replace(/cos\(/g, "Math.cos(")
                                .replace(/tan\(/g, "Math.tan(")
                                .replace(/√\(/g, "Math.sqrt(")
                                .replace(/ln\(/g, "Math.log(")
                                .replace(/log\(/g, "Math.log10(")
                                .replace(/\^/g, "**")
                                .replace(/%/g, "/100")

        try {
            let res = Function('"use strict";return (' + safeExpr + ')')()
            if (res === undefined || isNaN(res) || !isFinite(res)) throw "Error"
            
            res = parseFloat(res.toFixed(10)).toString()
            calcResult = res
            prevExpr = calcInput + " ="
            
            historyModel.insert(0, {
                expr: calcInput,
                res: calcResult,
                time: Math.floor(Date.now() / 1000)
            })
            saveHistoryToFile()
            
            calcInput = res
            calcResult = ""
            isCalculated = true
        } catch(err) {
            calcResult = "Error"
            isCalculated = false
        }
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") fallbackMonitorTimer.start()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        historyFile.reload()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-calculator"
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            MouseArea {
                width: win.width
                height: win.height
                onClicked: root.quitApp()
            }

            Item {
                id: dragContainer
                width: container.implicitWidth
                height: container.implicitHeight
                
                x: (win.width - width) / 2
                y: (win.height - height) / 2
                
                focus: isTargetMonitor

                Component.onCompleted: { if (isTargetMonitor) forceActiveFocus() }
                onFocusChanged: { if (isTargetMonitor && !focus) forceActiveFocus() }

                DragHandler {
                    target: dragContainer
                    cursorShape: Qt.ClosedHandCursor
                }

                Keys.onPressed: (event) => {
                    let k = event.key
                    let t = event.text
                    
                    if (k === Qt.Key_Escape) root.quitApp()
                    else if ((t >= "0" && t <= "9") || t === ".") root.handleInput(t, "num")
                    else if (t === "+" || t === "-") root.handleInput(t, "op")
                    else if (t === "*" || k === Qt.Key_Asterisk) root.handleInput("×", "op")
                    else if (t === "/" || k === Qt.Key_Slash) root.handleInput("÷", "op")
                    else if (t === "(" || t === ")") root.handleInput(t, "op")
                    else if (k === Qt.Key_Enter || k === Qt.Key_Return || t === "=") root.handleInput("", "equals")
                    else if (k === Qt.Key_Backspace) root.handleInput("", "backspace")
                    else if (k === Qt.Key_Delete || t === "c" || t === "C") root.handleInput("", "clear")
                    else return 
                    
                    event.accepted = true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                Rectangle {
                    id: container
                    implicitWidth: mainLayout.implicitWidth + 40
                    implicitHeight: mainLayout.implicitHeight + 40

                    Behavior on implicitWidth {
                        NumberAnimation { 
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        }
                    }

                    Behavior on implicitHeight {
                        NumberAnimation { 
                            duration: root.animEnabled ? animStyle.animDuration : 0
                            easing.type: animStyle.bounceEasing
                            easing.overshoot: animStyle.overshoot
                        }
                    }

                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themePrimary, 0.40)
                    antialiasing: true
                    clip: true

                    RowLayout {
                        id: mainLayout
                        anchors.centerIn: parent
                        spacing: 18

                        ColumnLayout {
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    width: 34
                                    height: 34
                                    radius: 10
                                    color: Qt.alpha(root.themePrimary, 0.16)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.35)
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰪚"
                                        color: root.themePrimary
                                        font.pixelSize: 18
                                        font.family: root.iconFontFamily
                                    }
                                }
                                
                                Text {
                                    text: "Calculator"
                                    color: root.themeText
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                    Layout.fillWidth: true
                                }
                                
                                Rectangle {
                                    width: 88
                                    height: 34
                                    radius: 10
                                    color: root.isExpertMode 
                                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.25, 0.75) 
                                           : (modeArea.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                    border.width: 1
                                    border.color: root.isExpertMode ? Qt.alpha(root.themePrimary, 0.6) : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true
                                    scale: modeArea.pressed ? 0.95 : (modeArea.containsMouse ? 1.03 : 1.0)
                                    
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: root.isExpertMode ? root.themePrimary : root.themeTextMuted
                                        }

                                        Text {
                                            text: root.isExpertMode ? "Expert" : "Basic"
                                            color: root.isExpertMode ? root.themePrimary : root.themeText
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            font.family: root.fontFamily
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.6)
                                        }
                                    }

                                    MouseArea {
                                        id: modeArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.isExpertMode = !root.isExpertMode
                                    }
                                }

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 10
                                    color: root.showHistory 
                                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.25, 0.75) 
                                           : (histArea.containsMouse ? root.themeSurfaceHover : root.themeSurface)
                                    border.width: 1
                                    border.color: root.showHistory ? Qt.alpha(root.themePrimary, 0.6) : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true
                                    scale: histArea.pressed ? 0.95 : (histArea.containsMouse ? 1.05 : 1.0)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰋚"
                                        color: root.showHistory ? root.themePrimary : root.themeText
                                        font.pixelSize: 16
                                        font.family: root.iconFontFamily
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    }

                                    MouseArea {
                                        id: histArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showHistory = !root.showHistory
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 112
                                radius: Math.max(8, root.themeRounding - 6)
                                color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
                                border.width: 1
                                border.color: Qt.alpha(root.themePrimary, 0.28)
                                antialiasing: true
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 18
                                    anchors.topMargin: 14
                                    anchors.bottomMargin: 14
                                    spacing: 4
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignRight
                                        text: root.calcResult !== "" ? root.calcInput : (root.prevExpr !== "" ? root.prevExpr : " ")
                                        color: root.themePrimary
                                        opacity: 0.85
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        font.family: root.fontFamily
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                        
                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.alignment: Qt.AlignRight
                                        text: root.calcResult !== "" ? root.calcResult : (root.calcInput !== "" ? root.calcInput : "0")
                                        color: root.calcResult === "Error" ? "#ff6b6b" : root.themeText
                                        font.pixelSize: root.calcInput.length > 12 ? 28 : 40
                                        font.weight: Font.Bold
                                        font.family: root.fontFamily
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideLeft
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.7)

                                        Behavior on font.pixelSize {
                                            NumberAnimation {
                                                duration: root.animEnabled ? animStyle.animDuration : 0
                                                easing.type: animStyle.bounceEasing
                                                easing.overshoot: animStyle.overshoot
                                            }
                                        }
                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 10

                                GridLayout {
                                    visible: root.isExpertMode
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    
                                    Repeater {
                                        model: [
                                            {t: "sin", v: "sin(", c: "expert"}, {t: "cos", v: "cos(", c: "expert"},
                                            {t: "tan", v: "tan(", c: "expert"}, {t: "√x", v: "√(", c: "expert"},
                                            {t: "ln", v: "ln(", c: "expert"}, {t: "log", v: "log(", c: "expert"},
                                            {t: "π", v: "π", c: "expert"}, {t: "e", v: "e", c: "expert"},
                                            {t: "x²", v: "^2", c: "expert"}, {t: "xʸ", v: "^", c: "expert"}
                                        ]
                                        delegate: calcBtnDelegate
                                    }
                                }

                                GridLayout {
                                    columns: 4
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    
                                    Repeater {
                                        model: [
                                            {t: "AC", v: "", c: "clear", type: "clear"}, {t: "(", v: "(", c: "op"}, {t: ")", v: ")", c: "op"}, {t: "÷", v: "÷", c: "op"},
                                            {t: "7", v: "7", c: "num"}, {t: "8", v: "8", c: "num"}, {t: "9", v: "9", c: "num"}, {t: "×", v: "×", c: "op"},
                                            {t: "4", v: "4", c: "num"}, {t: "5", v: "5", c: "num"}, {t: "6", v: "6", c: "num"}, {t: "-", v: "-", c: "op"},
                                            {t: "1", v: "1", c: "num"}, {t: "2", v: "2", c: "num"}, {t: "3", v: "3", c: "num"}, {t: "+", v: "+", c: "op"},
                                            {t: "0", v: "0", c: "num"}, {t: ".", v: ".", c: "num"}, {t: "󰁮", v: "", c: "action", type: "backspace"}, {t: "=", v: "", c: "equal", type: "equals"}
                                        ]
                                        delegate: calcBtnDelegate
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: root.showHistory
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Qt.alpha(root.themePrimary, 0.22)
                        }

                        ColumnLayout {
                            visible: root.showHistory
                            Layout.preferredWidth: root.showHistory ? 320 : 0
                            Layout.fillHeight: true
                            spacing: 14
                            clip: true

                            Behavior on Layout.preferredWidth {
                                NumberAnimation { 
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "History"
                                    color: root.themeText
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    font.family: root.fontFamily
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    visible: historyModel.count > 0
                                    width: clearRow.implicitWidth + 20
                                    height: 30
                                    radius: 8
                                    color: trashArea.containsMouse 
                                           ? Qt.rgba(0.93, 0.26, 0.26, 0.35) 
                                           : Qt.rgba(0.04, 0.04, 0.06, 0.55)
                                    border.width: 1
                                    border.color: trashArea.containsMouse ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.14)
                                    antialiasing: true
                                    scale: trashArea.pressed ? 0.95 : (trashArea.containsMouse ? 1.04 : 1.0)
                                    
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    RowLayout {
                                        id: clearRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { 
                                            text: "󰆴"
                                            color: trashArea.containsMouse ? "#ff6b6b" : root.themeTextMuted
                                            font.pixelSize: 13
                                            font.family: root.iconFontFamily
                                        }
                                        Text { 
                                            text: "Clear"
                                            color: trashArea.containsMouse ? "#ff6b6b" : root.themeText
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            font.family: root.fontFamily
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.6)
                                        }
                                    }
                                    MouseArea {
                                        id: trashArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.clearHistory()
                                    }
                                }
                            }

                            ListView {
                                id: histList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: historyModel
                                spacing: 10
                                clip: true

                                ScrollBar.vertical: ScrollBar {
                                    id: vbar
                                    active: histList.moving || histList.flicking || hovered
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.35)
                                    }
                                }

                                delegate: Rectangle {
                                    width: histList.width - (vbar.visible ? 10 : 0)
                                    implicitHeight: histCardLayout.implicitHeight + 22
                                    
                                    radius: Math.max(8, root.themeRounding - 8)
                                    color: histItemArea.containsMouse 
                                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.20, 0.72) 
                                           : Qt.rgba(0.03, 0.03, 0.05, 0.52)
                                    border.width: 1
                                    border.color: histItemArea.containsMouse ? Qt.alpha(root.themePrimary, 0.65) : Qt.rgba(1, 1, 1, 0.12)
                                    antialiasing: true
                                    
                                    scale: histItemArea.pressed ? 0.97 : (histItemArea.containsMouse ? 1.01 : 1.0)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: root.animEnabled ? animStyle.animDuration : 0
                                            easing.type: animStyle.bounceEasing
                                            easing.overshoot: animStyle.overshoot
                                        }
                                    }
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                                    RowLayout {
                                        id: histCardLayout
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        anchors.topMargin: 11
                                        anchors.bottomMargin: 11
                                        spacing: 12

                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            width: 34
                                            height: 34
                                            radius: 9
                                            color: Qt.alpha(root.themePrimary, 0.16)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.35)
                                            antialiasing: true
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰪚"
                                                color: root.themePrimary
                                                font.pixelSize: 16
                                                font.family: root.iconFontFamily
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            
                                            RowLayout {
                                                Layout.fillWidth: true
                                                
                                                Text {
                                                    text: root.formatTimeAgo(model.time)
                                                    color: Qt.alpha(root.themeTextMuted, 0.85)
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    font.family: root.fontFamily
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                                                }
                                                
                                                Item { Layout.fillWidth: true }
                                                
                                                Text {
                                                    text: model.expr + " ="
                                                    color: root.themePrimary
                                                    opacity: 0.85
                                                    font.pixelSize: 12
                                                    font.family: root.fontFamily
                                                    horizontalAlignment: Text.AlignRight
                                                    elide: Text.ElideLeft
                                                    style: Text.Raised
                                                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                                                }
                                            }
                                            
                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignRight
                                                text: model.res
                                                color: root.themeText
                                                font.pixelSize: 20
                                                font.weight: Font.Bold
                                                font.family: root.fontFamily
                                                horizontalAlignment: Text.AlignRight
                                                elide: Text.ElideLeft
                                                style: Text.Raised
                                                styleColor: Qt.rgba(0, 0, 0, 0.7)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: histItemArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { 
                                            root.prevExpr = model.expr + " ="
                                            root.calcInput = model.res
                                            root.calcResult = ""
                                            root.isCalculated = true
                                        }
                                    }
                                }
                            }

                            Item {
                                visible: historyModel.count === 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 54
                                        height: 54
                                        radius: 16
                                        color: Qt.rgba(0.03, 0.03, 0.05, 0.5)
                                        border.width: 1
                                        border.color: Qt.alpha(root.themePrimary, 0.25)
                                        antialiasing: true
                                        Text { 
                                            anchors.centerIn: parent
                                            text: "󰋚"
                                            color: root.themePrimary
                                            opacity: 0.65
                                            font.pixelSize: 24
                                            font.family: root.iconFontFamily
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 3
                                        Layout.alignment: Qt.AlignHCenter
                                        Text { 
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "No History Yet"
                                            color: root.themeText
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            font.family: root.fontFamily
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.65)
                                        }
                                        Text { 
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Calculations will appear here"
                                            color: root.themeTextMuted
                                            font.pixelSize: 11
                                            font.family: root.fontFamily
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.5)
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

    Component {
        id: calcBtnDelegate
        Rectangle {
            property string btnCategory: modelData.c
            property string btnType: modelData.type !== undefined ? modelData.type : "default"
            
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 68
            Layout.minimumHeight: 56
            
            radius: Math.max(8, root.themeRounding - 8)
            antialiasing: true
            
            scale: btnArea.pressed ? 0.93 : (btnArea.containsMouse ? 1.04 : 1.0)

            Behavior on scale {
                NumberAnimation {
                    duration: root.animEnabled ? animStyle.animDuration : 0
                    easing.type: animStyle.bounceEasing
                    easing.overshoot: animStyle.overshoot
                }
            }

            color: {
                if (btnCategory === "equal") {
                    return btnArea.containsMouse ? Qt.lighter(root.themePrimary, 1.1) : root.themePrimary
                }
                if (btnCategory === "clear") {
                    return btnArea.containsMouse 
                           ? Qt.rgba(0.45, 0.10, 0.12, 0.80) 
                           : Qt.rgba(0.28, 0.06, 0.08, 0.70)
                }
                if (btnCategory === "op") {
                    return btnArea.containsMouse 
                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.35, 0.78) 
                           : root.mixColor(root.themeBackground, root.themePrimary, 0.22, 0.68)
                }
                if (btnCategory === "expert") {
                    return btnArea.containsMouse 
                           ? root.mixColor(root.themeBackground, root.themePrimary, 0.25, 0.72) 
                           : Qt.rgba(0.03, 0.03, 0.05, 0.62)
                }
                return btnArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
            }

            border.width: 1
            border.color: {
                if (btnCategory === "equal") return Qt.rgba(1, 1, 1, 0.45)
                if (btnCategory === "clear") return Qt.rgba(1.0, 0.42, 0.42, 0.55)
                if (btnCategory === "op") return Qt.alpha(root.themePrimary, btnArea.containsMouse ? 0.75 : 0.45)
                if (btnCategory === "expert") return Qt.alpha(root.themePrimary, btnArea.containsMouse ? 0.55 : 0.28)
                return btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
            }

            Behavior on color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
            Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

            Text {
                anchors.centerIn: parent
                text: modelData.t
                font.family: btnType === "backspace" ? root.iconFontFamily : root.fontFamily
                font.pixelSize: (btnCategory === "expert") ? 15 : 18
                font.weight: (btnCategory === "equal" || btnCategory === "clear" || btnCategory === "num" || btnCategory === "op") ? Font.Bold : Font.DemiBold
                style: btnCategory === "equal" ? Text.Normal : Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.65)
                color: {
                    if (btnCategory === "equal") return "#141416"
                    if (btnCategory === "clear") return "#ff7b7b"
                    if (btnCategory === "op") return root.themePrimary
                    if (btnCategory === "expert") return Qt.lighter(root.themePrimary, 1.15)
                    return root.themeText
                }

                scale: btnArea.containsMouse ? 1.08 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.animDuration : 0
                        easing.type: animStyle.bounceEasing
                        easing.overshoot: animStyle.overshoot
                    }
                }
            }

            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.handleInput(modelData.v, btnType)
                }
            }
        }
    }
}