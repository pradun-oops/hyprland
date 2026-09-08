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

    // ============================================================
    // ESCAPE KEY SHORTCUT & APP QUIT LOGIC
    // ============================================================
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

    // ============================================================
    // ADAPTIVE THEME PROPERTIES
    // ============================================================
    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 22
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.72
    property bool animEnabled: true
    property int animDuration: 220
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.04) 
    property color themeSurfaceHover: Qt.rgba(1.0, 1.0, 1.0, 0.08)

    // ============================================================
    // STRICT FOCUSED MONITOR LOCK LOGIC
    // ============================================================
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

    // ============================================================
    // CONFIG PARSERS
    // ============================================================
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
                if (speedMatch && speedMatch[1]) root.animDuration = parseFloat(speedMatch[1]) * 100
            } catch (e) {}
        }
    }

    // ============================================================
    // CALCULATOR LOGIC & SECURE HISTORY SAVING
    // ============================================================
    property string calcInput: ""
    property string calcResult: ""
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
            isCalculated = true
        } else if (type === "backspace") {
            if (isCalculated) {
                calcInput = ""
                isCalculated = false
            } else {
                calcInput = calcInput.slice(0, -1)
            }
        } else if (type === "equals") {
            calculate()
        } else {
            if (isCalculated && type === "num") {
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

    // ============================================================
    // DIALOG UI & DRAG LOGIC
    // ============================================================
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
                    implicitWidth: mainLayout.implicitWidth + 36
                    implicitHeight: mainLayout.implicitHeight + 36

                    Behavior on implicitWidth {
                        NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutCubic }
                    }

                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.35)
                    clip: true

                    RowLayout {
                        id: mainLayout
                        anchors.centerIn: parent
                        spacing: 20

                        // --- LEFT SIDE: CALCULATOR ---
                        ColumnLayout {
                            spacing: 16

                            // Header / Controls
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Text {
                                    text: "󰪚 Calculator"
                                    color: root.themeText
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }
                                
                                Rectangle {
                                    width: 90; height: 34
                                    radius: Math.max(4, root.themeRounding - 8)
                                    color: modeArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1; border.color: root.isExpertMode ? Qt.alpha(root.themePrimary, 0.4) : Qt.rgba(1, 1, 1, 0.08)
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isExpertMode ? "Expert" : "Basic"
                                        color: root.isExpertMode ? root.themePrimary : root.themeText
                                        font.pixelSize: 13; font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        id: modeArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.isExpertMode = !root.isExpertMode
                                    }
                                }

                                Rectangle {
                                    width: 34; height: 34
                                    radius: Math.max(4, root.themeRounding - 8)
                                    color: histArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
                                    border.width: 1; border.color: root.showHistory ? Qt.alpha(root.themePrimary, 0.4) : Qt.rgba(1, 1, 1, 0.08)
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰋚"
                                        color: root.showHistory ? root.themePrimary : root.themeText
                                        font.pixelSize: 15
                                    }
                                    MouseArea {
                                        id: histArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showHistory = !root.showHistory
                                    }
                                }
                            }

                            // Display Screen
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                radius: Math.max(4, root.themeRounding - 8)
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 4
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignRight
                                        text: root.calcResult !== "" ? root.calcInput : " "
                                        color: root.themeTextMuted
                                        font.pixelSize: 16
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.alignment: Qt.AlignRight
                                        text: root.calcResult !== "" ? root.calcResult : (root.calcInput !== "" ? root.calcInput : "0")
                                        color: root.calcResult === "Error" ? "#ef4444" : root.themeText
                                        font.pixelSize: root.calcInput.length > 14 ? 32 : 46
                                        font.weight: Font.Bold
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideLeft
                                    }
                                }
                            }

                            // Keypad Area
                            RowLayout {
                                spacing: 10

                                // Expert Keypad
                                GridLayout {
                                    visible: root.isExpertMode
                                    columns: 2; columnSpacing: 10; rowSpacing: 10
                                    
                                    Repeater {
                                        model: [
                                            {t: "sin(", v: "sin(", c: "expert"}, {t: "cos(", v: "cos(", c: "expert"},
                                            {t: "tan(", v: "tan(", c: "expert"}, {t: "√(", v: "√(", c: "expert"},
                                            {t: "ln(", v: "ln(", c: "expert"}, {t: "log(", v: "log(", c: "expert"},
                                            {t: "π", v: "π", c: "expert"}, {t: "e", v: "e", c: "expert"},
                                            {t: "x²", v: "^2", c: "expert"}, {t: "xʸ", v: "^", c: "expert"}
                                        ]
                                        delegate: calcBtnDelegate
                                    }
                                }

                                // Basic Keypad
                                GridLayout {
                                    columns: 4; columnSpacing: 10; rowSpacing: 10
                                    
                                    Repeater {
                                        model: [
                                            {t: "AC", v: "", c: "clear", type: "clear"}, {t: "(", v: "(", c: "op"}, {t: ")", v: ")", c: "op"}, {t: "÷", v: "÷", c: "op"},
                                            {t: "7", v: "7", c: "num"}, {t: "8", v: "8", c: "num"}, {t: "9", v: "9", c: "num"}, {t: "×", v: "×", c: "op"},
                                            {t: "4", v: "4", c: "num"}, {t: "5", v: "5", c: "num"}, {t: "6", v: "6", c: "num"}, {t: "-", v: "-", c: "op"},
                                            {t: "1", v: "1", c: "num"}, {t: "2", v: "2", c: "num"}, {t: "3", v: "3", c: "num"}, {t: "+", v: "+", c: "op"},
                                            {t: "0", v: "0", c: "num"}, {t: ".", v: ".", c: "num"}, {t: "⌫", v: "", c: "action", type: "backspace"}, {t: "=", v: "", c: "equal", type: "equals"}
                                        ]
                                        delegate: calcBtnDelegate
                                    }
                                }
                            }
                        }

                        // Vertical Divider
                        Rectangle {
                            visible: root.showHistory
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // --- RIGHT SIDE: HISTORY ---
                        ColumnLayout {
                            visible: root.showHistory
                            Layout.preferredWidth: root.showHistory ? 340 : 0
                            Layout.fillHeight: true
                            spacing: 16
                            clip: true

                            Behavior on Layout.preferredWidth {
                                NumberAnimation { duration: root.animEnabled ? root.animDuration : 0; easing.type: Easing.OutCubic }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "History"
                                    color: root.themeText
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    visible: historyModel.count > 0
                                    width: clearRow.implicitWidth + 20
                                    height: 30
                                    radius: Math.max(4, root.themeRounding - 8)
                                    color: trashArea.containsMouse ? Qt.alpha(root.themePrimary, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: trashArea.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.1)
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        id: clearRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰆴"; color: trashArea.containsMouse ? root.themePrimary : root.themeTextMuted; font.pixelSize: 13 }
                                        Text { text: "Clear"; color: trashArea.containsMouse ? root.themeText : root.themeTextMuted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    }
                                    MouseArea {
                                        id: trashArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.clearHistory()
                                    }
                                }
                            }

                            // Calculator History Card List
                            ListView {
                                id: histList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: historyModel
                                spacing: 12
                                clip: true

                                ScrollBar.vertical: ScrollBar {
                                    id: vbar
                                    active: histList.moving || histList.flicking || hovered
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: vbar.pressed ? root.themePrimary : Qt.alpha(root.themeTextMuted, 0.3)
                                    }
                                }

                                delegate: Rectangle {
                                    width: histList.width - (vbar.visible ? 12 : 0)
                                    implicitHeight: histCardLayout.implicitHeight + 24
                                    
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: histItemArea.containsMouse ? root.themeSurfaceHover : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1
                                    border.color: histItemArea.containsMouse ? Qt.alpha(root.themePrimary, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                                    
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        id: histCardLayout
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        anchors.topMargin: 12
                                        anchors.bottomMargin: 12
                                        spacing: 14

                                        // Formatted Calculator Icon
                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            width: 38
                                            height: 38
                                            radius: 10
                                            color: Qt.alpha(root.themePrimary, 0.1)
                                            border.width: 1
                                            border.color: Qt.alpha(root.themePrimary, 0.2)
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰪚"
                                                color: root.themePrimary
                                                font.pixelSize: 17
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            
                                            RowLayout {
                                                Layout.fillWidth: true
                                                
                                                Text {
                                                    text: root.formatTimeAgo(model.time)
                                                    color: Qt.alpha(root.themeTextMuted, 0.7)
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                }
                                                
                                                Item { Layout.fillWidth: true }
                                                
                                                Text {
                                                    text: model.expr + " ="
                                                    color: root.themeTextMuted
                                                    font.pixelSize: 13
                                                    horizontalAlignment: Text.AlignRight
                                                    elide: Text.ElideLeft
                                                }
                                            }
                                            
                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignRight
                                                text: model.res
                                                color: root.themeText
                                                font.pixelSize: 22
                                                font.weight: Font.Bold
                                                horizontalAlignment: Text.AlignRight
                                                elide: Text.ElideLeft
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: histItemArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { 
                                            root.calcInput = model.res; 
                                            root.calcResult = ""; 
                                            root.isCalculated = true;
                                        }
                                    }
                                }
                            }

                            // Empty State
                            Item {
                                visible: historyModel.count === 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 56; height: 56; radius: 28
                                        color: Qt.rgba(1, 1, 1, 0.03)
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                                        Text { anchors.centerIn: parent; text: "󰋚"; color: Qt.alpha(root.themeTextMuted, 0.4); font.pixelSize: 26 }
                                    }
                                    ColumnLayout {
                                        spacing: 3; Layout.alignment: Qt.AlignHCenter
                                        Text { Layout.alignment: Qt.AlignHCenter; text: "No History Yet"; color: root.themeText; font.pixelSize: 14; font.weight: Font.Bold }
                                        Text { Layout.alignment: Qt.AlignHCenter; text: "Calculations will appear here"; color: root.themeTextMuted; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // REUSABLE BUTTON DELEGATE
    // ============================================================
    Component {
        id: calcBtnDelegate
        Rectangle {
            property string btnCategory: modelData.c
            property string btnType: modelData.type !== undefined ? modelData.type : "default"
            
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 70
            Layout.minimumHeight: 60
            
            radius: Math.max(4, root.themeRounding - 8)
            
            color: {
                if (btnCategory === "equal") return btnArea.containsMouse ? Qt.darker(root.themePrimary, 1.1) : root.themePrimary
                if (btnCategory === "clear") return btnArea.containsMouse ? Qt.alpha("#ef4444", 0.25) : Qt.alpha("#ef4444", 0.15)
                if (btnCategory === "op" || btnCategory === "expert") return btnArea.containsMouse ? Qt.alpha(root.themePrimary, 0.2) : Qt.alpha(root.themePrimary, 0.1)
                return btnArea.containsMouse ? root.themeSurfaceHover : root.themeSurface
            }

            border.width: 1
            border.color: {
                if (btnCategory === "equal") return Qt.alpha(root.themeBorder, 0.5)
                if (btnCategory === "clear") return Qt.alpha("#ef4444", 0.4)
                if (btnCategory === "op" || btnCategory === "expert") return Qt.alpha(root.themePrimary, 0.35)
                return Qt.rgba(1, 1, 1, 0.08)
            }

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: modelData.t
                font.pixelSize: (modelData.t === "⌫") ? 22 : 18
                font.weight: (btnCategory === "equal" || btnCategory === "clear" || btnCategory === "num") ? Font.Bold : Font.Medium
                color: {
                    if (btnCategory === "equal") return "#11111b" 
                    if (btnCategory === "clear") return "#ef4444"
                    if (btnCategory === "op" || btnCategory === "expert") return root.themePrimary
                    return root.themeText
                }
            }

            MouseArea {
                id: btnArea; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.handleInput(modelData.v, btnType)
                }
            }
        }
    }
}