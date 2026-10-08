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
    property real themeBgAlpha: 0.5
    
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#121214" 
    property color themeCardBg: Qt.rgba(0.09, 0.09, 0.12, 0.85)
    property color themeBorder: "#d6bbfb"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#D4D4D8"
    property color themePrimary: "#d6bbfb"        

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
    }

    property real dailyLimit: 14400 
    property real todayTotal: 0
    property real maxHistoryTotal: 1
    property int appSwitches: 0
    property string peakHour: "--:--"
    
    property int selectedDayIndex: -1
    property real selectedTotal: 0
    property var fullData: null

    ListModel { id: appModel }
    ListModel { id: historyModel }

    function loadAppBreakdown(dayIndex) {
        root.selectedDayIndex = dayIndex;
        appModel.clear();
        let sourceApps = [];
        
        if (dayIndex === -1) {
            root.selectedTotal = root.todayTotal;
            sourceApps = root.fullData ? root.fullData.today_apps : [];
        } else if (root.fullData && root.fullData.history[dayIndex]) {
            root.selectedTotal = root.fullData.history[dayIndex].total;
            sourceApps = root.fullData.history[dayIndex].apps || [];
        }
        
        for (let i = 0; i < sourceApps.length; i++) {
            appModel.append(sourceApps[i]);
        }
    }

    Process {
        id: dataFetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/wellbeing_aggregator.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    root.fullData = data;
                    root.todayTotal = data.today_total;
                    root.appSwitches = data.app_switches || 0;
                    root.peakHour = data.peak_hour || "--:--";
                    
                    root.loadAppBreakdown(-1);
                    
                    historyModel.clear();
                    let mTotal = 1;
                    for (let i = 0; i < data.history.length; i++) {
                        historyModel.append(data.history[i]);
                        if (data.history[i].total > mTotal) {
                            mTotal = data.history[i].total;
                        }
                    }
                    root.maxHistoryTotal = mTotal;
                } catch (e) {}
            }
        }
    }

    Process {
        id: resetDataProcess
        command: ["sqlite3", Quickshell.env("HOME") + "/.local/share/wellbeing/wellbeing.db", "DELETE FROM usage;"]
        running: false
        onExited: {
            dataFetcher.running = true;
        }
    }

    function formatTime(secs) {
        let totalMins = Math.floor(secs / 60);
        if (totalMins < 1) return "< 1m";
        let h = Math.floor(totalMins / 60);
        let m = totalMins % 60;
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function getSysIcon(appName) {
        if (!appName) return "application-x-executable";
        let lower = appName.toLowerCase();
        if (lower === "zen") return "zen-browser";
        if (lower === "codium") return "vscodium";
        if (lower === "wezterm") return "org.wezfurlong.wezterm";
        if (lower === "nautilus") return "org.gnome.Nautilus";
        if (lower.includes("virtualbox")) return "virtualbox";
        return lower;
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
                onActivated: Qt.quit()
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
                onClicked: Qt.quit()
            }

            Rectangle {
                id: mainCard
                width: Math.min(960, parent.width - 40)
                height: Math.min(680, parent.height - 80)
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themePrimary, 0.40)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                antialiasing: true

                property bool shown: false
                Component.onCompleted: shown = true

                scale: shown ? 1.0 : 0.90
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
                    onClicked: (mouse) => mouse.accepted = true 
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        RowLayout {
                            spacing: 10
                            Text { 
                                text: "󰓏"
                                font.pixelSize: 22
                                color: root.themePrimary
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text { 
                                text: "Digital Wellbeing"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.12)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 20

                        ColumnLayout {
                            Layout.preferredWidth: 320
                            Layout.minimumWidth: 320
                            Layout.maximumWidth: 320
                            Layout.fillHeight: true
                            spacing: 20

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 260
                                radius: root.themeRounding
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                antialiasing: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 24
                                    spacing: 0
                                    
                                    Text {
                                        text: "Today's Screen Time"
                                        color: root.themeTextMuted
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Item { Layout.fillHeight: true }
                                    
                                    Text {
                                        text: formatTime(root.todayTotal)
                                        color: root.todayTotal > root.dailyLimit ? "#ef4444" : root.themePrimary
                                        font.pixelSize: 46
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignHCenter
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: 16
                                        width: 180
                                        height: 6
                                        radius: 3
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                        clip: true
                                        
                                        Rectangle {
                                            width: root.todayTotal > 0 ? Math.min(parent.width, parent.width * (root.todayTotal / root.dailyLimit)) : 0
                                            height: parent.height
                                            radius: 3
                                            color: root.todayTotal > root.dailyLimit ? "#ef4444" : root.themePrimary
                                            Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 0
                                        
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text { text: "App Switches"; color: root.themeTextMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: root.appSwitches.toString(); color: root.themeText; font.pixelSize: 15; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                                        }
                                        
                                        Rectangle {
                                            width: 1; height: 36
                                            color: Qt.rgba(255, 255, 255, 0.1)
                                        }
                                        
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text { text: "Peak Activity"; color: root.themeTextMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: root.peakHour; color: root.themeText; font.pixelSize: 15; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
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
                                    anchors.margins: 18
                                    spacing: 12

                                    Text {
                                        text: "Past 7 Days"
                                        color: root.themeTextMuted
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 10

                                        Repeater {
                                            model: historyModel
                                            Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    id: barRect
                                                    width: 24
                                                    property real targetHeight: Math.max(4, (model.total / root.maxHistoryTotal) * (parent.height - 30))
                                                    height: mainCard.shown ? targetHeight : 0
                                                    anchors.bottom: dayLabel.top
                                                    anchors.bottomMargin: 8
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: root.selectedDayIndex === index ? "#FFFFFF" : root.themePrimary
                                                    radius: 4
                                                    opacity: barMouse.containsMouse || root.selectedDayIndex === index ? 1.0 : (model.total > 0 ? 0.7 : 0.2)
                                                    antialiasing: true
                                                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }

                                                Text {
                                                    id: dayLabel
                                                    text: model.day
                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: root.selectedDayIndex === index ? "#FFFFFF" : root.themeTextMuted
                                                    font.pixelSize: 11
                                                    font.weight: root.selectedDayIndex === index ? Font.Bold : Font.Medium
                                                }

                                                MouseArea {
                                                    id: barMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.loadAppBreakdown(index);
                                                    }
                                                }

                                                Rectangle {
                                                    visible: barMouse.containsMouse && model.total > 0
                                                    width: tooltipLayout.implicitWidth + 24
                                                    height: tooltipLayout.implicitHeight + 16
                                                    anchors.bottom: barRect.top
                                                    anchors.bottomMargin: 10
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                                                    radius: 8
                                                    border.width: 1
                                                    border.color: Qt.alpha(root.themePrimary, 0.5)
                                                    z: 10
                                                    antialiasing: true

                                                    ColumnLayout {
                                                        id: tooltipLayout
                                                        anchors.centerIn: parent
                                                        spacing: 4
                                                        Text {
                                                            text: formatTime(model.total)
                                                            color: "#FFFFFF"
                                                            font.pixelSize: 13
                                                            font.weight: Font.Bold
                                                            Layout.alignment: Qt.AlignHCenter
                                                        }
                                                        RowLayout {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            spacing: 6
                                                            visible: model.top_app !== ""
                                                            Image {
                                                                source: model.top_app ? "image://icon/" + getSysIcon(model.top_app) : ""
                                                                width: 14
                                                                height: 14
                                                                sourceSize: Qt.size(14, 14)
                                                                fillMode: Image.PreserveAspectFit
                                                            }
                                                            Text {
                                                                text: model.top_app ? model.top_app.charAt(0).toUpperCase() + model.top_app.slice(1) : ""
                                                                color: root.themeTextMuted
                                                                font.pixelSize: 11
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
                            radius: root.themeRounding
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)
                            clip: true
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                visible: appModel.count === 0
                                text: "No activity recorded."
                                color: root.themeTextMuted
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            ListView {
                                id: appList
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8
                                model: appModel
                                clip: true

                                ScrollBar.vertical: ScrollBar {
                                    active: appList.moving || appList.flicking
                                    policy: ScrollBar.AsNeeded
                                }

                                header: Item {
                                    width: appList.width
                                    height: 42
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        
                                        Text {
                                            text: root.selectedDayIndex === -1 ? "App Usage Breakdown" : "Breakdown: " + historyModel.get(root.selectedDayIndex).day
                                            color: root.selectedDayIndex === -1 ? root.themeTextMuted : "#FFFFFF"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            Layout.fillWidth: true
                                        }
                                        
                                        Rectangle {
                                            visible: root.selectedDayIndex !== -1
                                            width: 90
                                            height: 24
                                            radius: 4
                                            color: Qt.rgba(255, 255, 255, 0.1)
                                            border.width: 1
                                            border.color: Qt.rgba(255, 255, 255, 0.15)
                                            antialiasing: true
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Back to Today"
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.loadAppBreakdown(-1)
                                            }
                                        }
                                    }
                                }

                                delegate: Item {
                                    width: appList.width
                                    height: 54

                                    MouseArea {
                                        id: appMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: Qt.rgba(255, 255, 255, appMouse.containsMouse ? 0.06 : 0.02)
                                        antialiasing: true
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: root.selectedTotal > 0 ? parent.width * (model.duration / root.selectedTotal) : 0
                                            radius: 8
                                            color: Qt.alpha(root.themePrimary, 0.20)
                                            antialiasing: true
                                            Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            spacing: 16

                                            Image {
                                                source: "image://icon/" + getSysIcon(model.app)
                                                width: 24
                                                height: 24
                                                sourceSize: Qt.size(24, 24)
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            Text {
                                                text: model.app.charAt(0).toUpperCase() + model.app.slice(1)
                                                font.pixelSize: 15
                                                font.weight: Font.Medium
                                                color: root.themeText
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: formatTime(model.duration)
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: root.themeText
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        radius: Math.max(4, root.themeRounding - 6)
                        antialiasing: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14

                            Text {
                                text: "Data stored locally in SQLite"
                                font.pixelSize: 12
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
                                    width: 60; height: 20; radius: 4
                                    color: Qt.rgba(239, 68, 68, 0.15)
                                    border.width: 1; border.color: Qt.rgba(239, 68, 68, 0.3)
                                    antialiasing: true
                                    Text {
                                        anchors.centerIn: parent
                                        text: "CLEAR"
                                        font.pixelSize: 10
                                        color: "#ef4444"
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: resetDataProcess.running = true
                                    }
                                }
                                
                                Rectangle { 
                                    width: 34; height: 20; radius: 4
                                    color: Qt.rgba(255, 255, 255, 0.12)
                                    border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.15)
                                    antialiasing: true
                                    Text { 
                                        anchors.centerIn: parent
                                        text: "ESC"
                                        font.pixelSize: 10
                                        color: "#FFFFFF"
                                        font.weight: Font.Bold
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    } 
                                }
                                Text { 
                                    text: "Close"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: root.themeTextMuted
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}