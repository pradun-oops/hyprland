import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window

Scope {
    id: root

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
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

    property int themeRounding: 16
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.85
    property bool animEnabled: true
    property int animDuration: 350
    
    property color themeBackground: "#0d0d11" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.03) 
    property color themeBorder: "#ff4b6e"
    property color themePrimary: "#ff4b6e"
    property string rawThemeHex: "ff4b6e" 
    property color themeText: "#ffffff"
    property color themeTextMuted: "#8a8a93"

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 350
        property int fadeDuration: 200
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.2
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onLoaded: {
            try {
                let content = text()
                let match = content.match(/active_border\s*=\s*"rgb\(([a-fA-F0-9]{6})\)"/)
                if (match && match[1]) { 
                    root.rawThemeHex = match[1]
                    root.themeBorder = "#" + match[1]
                    root.themePrimary = "#" + match[1] 
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

    property int rgbBrightness: 2
    property int rgbSpeed: 2
    property bool rgbPowerState: false 
    
    property string savedName: "Ocean Wave"
    property string savedType: "wave"
    property string savedColors: ""

    Process { id: actionProcess }
    Process { id: fileProcess }
    
    Process {
        id: initProcess
        command: ["bash", "-c", `mkdir -p "${Quickshell.env("HOME")}/.config/quickshell/json" && if [ ! -f "${Quickshell.env("HOME")}/.config/quickshell/json/rgb_custom.json" ]; then echo "[]" > "${Quickshell.env("HOME")}/.config/quickshell/json/rgb_custom.json"; fi`]
        running: true
        onExited: {
            customPresetsReader.path = root.customPresetsFile
            customPresetsReader.reload()
        }
    }

    function togglePower() {
        root.rgbPowerState = !root.rgbPowerState
        if (!root.rgbPowerState) {
            actionProcess.running = false
            actionProcess.command = ["bash", "-c", "legionaura off"]
            actionProcess.running = true
        } else {
            executeAuraCommand(root.savedName, root.savedType, root.savedColors, true) 
        }
    }

    function applyCurrentSettings() {
        if (!root.rgbPowerState) return 
        executeAuraCommand(root.savedName, root.savedType, root.savedColors, true)
    }

    function executeAuraCommand(cmdName, cmdType, cmdColors, skipSave) {
        if (!skipSave) {
            root.savedName = cmdName
            root.savedType = cmdType
            root.savedColors = cmdColors
            root.rgbPowerState = true 
        }
        
        let finalCmd = ""
        if (cmdType === "dynamic") {
            finalCmd = `legionaura static ${root.rawThemeHex} ${root.rawThemeHex} ${root.rawThemeHex} ${root.rawThemeHex} --brightness ${root.rgbBrightness}`
        } else if (cmdType === "static") {
            finalCmd = `legionaura static ${cmdColors} --brightness ${root.rgbBrightness}`
        } else if (cmdType === "wave") {
            finalCmd = `legionaura wave ltr --speed ${root.rgbSpeed} --brightness ${root.rgbBrightness}`
        } else if (cmdType === "hue") {
            finalCmd = `legionaura hue --speed ${root.rgbSpeed} --brightness ${root.rgbBrightness}`
        } else if (cmdType === "breath") {
            finalCmd = `legionaura breath ${cmdColors} --speed ${root.rgbSpeed} --brightness ${root.rgbBrightness}`
        }
        
        actionProcess.running = false
        actionProcess.command = ["bash", "-c", finalCmd]
        actionProcess.running = true
    }

    function rgbToHex(r, g, b) {
        return ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toLowerCase()
    }
    function hexToRgb(hex) {
        let clean = hex.replace("#", "")
        if (clean.length === 3) clean = clean.split('').map(c => c + c).join('')
        let num = parseInt(clean, 16)
        return {
            r: (num >> 16) & 255,
            g: (num >> 8) & 255,
            b: num & 255
        }
    }

    property string customPresetsFile: Quickshell.env("HOME") + "/.config/quickshell/json/rgb_custom.json"
    property var defaultPresets: [
        { name: "Dynamic Theme", type: "dynamic", colors: "", icon: "󰏘", isCustom: false },
        { name: "Matrix Green", type: "static", colors: "00ff44 00cc33 00ff88 00aa22", icon: "󰘧", isCustom: false },
        { name: "Cyberpunk", type: "static", colors: "ff00ff 00ffff ff00ff 00ffff", icon: "󰢹", isCustom: false },
        { name: "Hacker Red", type: "static", colors: "ff0033 cc0000 ff4444 990000", icon: "󰞋", isCustom: false },
        { name: "Neon Mix", type: "static", colors: "00ffff ff00ff 00aaff ff44cc", icon: "󰹑", isCustom: false },
        { name: "RGB Classic", type: "static", colors: "ff0000 00ff00 0000ff ffff00", icon: "󰴾", isCustom: false },
        { name: "Sunset Fire", type: "static", colors: "ff2200 ff6600 ffaa00 ffff00", icon: "󰖨", isCustom: false },
        { name: "Forest", type: "static", colors: "00ff00 228b22 32cd32 00fa9a", icon: "󰔎", isCustom: false },
        { name: "Blood Moon", type: "static", colors: "ff0000 8b0000 800000 4b0082", icon: "󰸌", isCustom: false },
        { name: "Miami", type: "static", colors: "ff00cc 00ffff ff00cc 00ffff", icon: "󰽉", isCustom: false },
        { name: "Toxic", type: "static", colors: "adff2f 7fff00 32cd32 00ff00", icon: "󰜡", isCustom: false },
        { name: "Royal Gold", type: "static", colors: "ffd700 ddaa00 ffd700 ddaa00", icon: "󰠓", isCustom: false },
        { name: "Vaporwave", type: "static", colors: "ff00ff 00ffff ff00ff 00ffff", icon: "󰽉", isCustom: false },
        { name: "Ice Frost", type: "static", colors: "aaddff ffffff aaddff ffffff", icon: "󰜡", isCustom: false },
        { name: "Lavender", type: "static", colors: "e6a8d7 c8a2c8 e6a8d7 c8a2c8", icon: "󰆤", isCustom: false },
        { name: "Cotton Candy", type: "static", colors: "ffbcd9 b2e1ff ffbcd9 b2e1ff", icon: "󰋋", isCustom: false },
        { name: "Outrun", type: "static", colors: "ff0055 5500ff ff0055 5500ff", icon: "󰐎", isCustom: false },
        { name: "Deep Sea", type: "static", colors: "000055 0055aa 00aaff 00ffff", icon: "󰝤", isCustom: false },
        { name: "Volcano", type: "static", colors: "330000 ff0000 ff5500 ffaa00", icon: "󰈸", isCustom: false },
        { name: "Aurora", type: "static", colors: "00ff88 00ffff aaffff 00ff88", icon: "󰼓", isCustom: false },
        { name: "Amethyst", type: "static", colors: "8800ff aa00ff dd00ff ff00ff", icon: "󰋉", isCustom: false },
        { name: "Emerald", type: "static", colors: "00aa55 00ff55 55ff55 00aa55", icon: "󰴿", isCustom: false },
        { name: "Ruby", type: "static", colors: "aa0022 ff0022 ff5555 aa0022", icon: "󰓎", isCustom: false },
        { name: "Silver", type: "static", colors: "aaaaaa cccccc eeeeee aaaaaa", icon: "󰢹", isCustom: false },
        { name: "Ocean Wave", type: "wave", colors: "", icon: "󰈈", isCustom: false },
        { name: "Rainbow Hue", type: "hue", colors: "", icon: "󰮯", isCustom: false },
        { name: "Breath Green", type: "breath", colors: "00ff88 00ff88 00ff88 00ff88", icon: "󰖔", isCustom: false },
        { name: "Breath Fire", type: "breath", colors: "ff2200 ff2200 ff2200 ff2200", icon: "󰖔", isCustom: false },
        { name: "Breath Ice", type: "breath", colors: "00ffff 00ffff 00ffff 00ffff", icon: "󰖔", isCustom: false },
        { name: "Breath Void", type: "breath", colors: "5500ff 5500ff 5500ff 5500ff", icon: "󰖔", isCustom: false }
    ]

    ListModel { id: presetModel }

    function rebuildPresetModel(jsonText) {
        presetModel.clear()
        defaultPresets.forEach(p => presetModel.append(p))
        if (!jsonText || jsonText.trim() === "") return
        
        try {
            let parsed = JSON.parse(jsonText)
            if (Array.isArray(parsed)) {
                parsed.forEach(p => {
                    if (p.name && p.type && p.colors !== undefined) {
                        presetModel.append({
                            name: p.name,
                            type: p.type,
                            colors: p.colors,
                            icon: "",
                            isCustom: true
                        })
                    }
                })
            }
        } catch(e) {}
    }

    FileView {
        id: customPresetsReader
        watchChanges: false 
        onLoaded: root.rebuildPresetModel(text())
    }

    function syncCustomPresetsToFile() {
        let arr = []
        for (let i = 0; i < presetModel.count; i++) {
            let item = presetModel.get(i)
            if (item.isCustom) {
                arr.push({ name: item.name, type: item.type, colors: item.colors })
            }
        }
        let jsonStr = JSON.stringify(arr)
        let cmd = `cat << 'EOF' > "${root.customPresetsFile}"\n${jsonStr}\nEOF`
        fileProcess.running = false
        fileProcess.command = ["bash", "-c", cmd]
        fileProcess.running = true
    }

    function saveNewCustomPreset(name, type, colors) {
        let safeName = name.trim() === "" ? "Custom Preset" : name.trim()
        root.executeAuraCommand(safeName, type, colors, false)
        presetModel.append({ name: safeName, type: type, colors: colors, icon: "", isCustom: true })
        syncCustomPresetsToFile()
        root.isEditingCustom = false
    }

    function deleteCustomPreset(idx) {
        presetModel.remove(idx)
        syncCustomPresetsToFile()
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") fallbackMonitorTimer.start()
        colorFile.reload(); generalConfigFile.reload()
    }

    property bool isEditingCustom: false
    property bool isPickingColor: false
    property int activeZoneIndex: -1
    property int pickerR: 255
    property int pickerG: 0
    property int pickerB: 0
    property string pickerHex: "#" + root.rgbToHex(pickerR, pickerG, pickerB)

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.namespace: "qs-rgbcontrol"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

            Item {
                id: mainFocusWrapper
                anchors.fill: parent
                focus: isTargetMonitor
                Component.onCompleted: if (isTargetMonitor) forceActiveFocus()
                Keys.onEscapePressed: {
                    if (root.isPickingColor) root.isPickingColor = false
                    else if (root.isEditingCustom) root.isEditingCustom = false
                    else Qt.quit()
                }

                Rectangle {
                    id: mainCard
                    width: 1100
                    height: 800
                    anchors.centerIn: parent

                    property bool shown: false
                    Component.onCompleted: shown = true

                    scale: shown ? 1.0 : 0.95
                    opacity: shown ? 1.0 : 0.0

                    Behavior on scale { NumberAnimation { duration: root.animEnabled ? animStyle.animDuration : 0; easing.type: animStyle.bounceEasing; easing.overshoot: animStyle.overshoot } }
                    Behavior on opacity { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }

                    radius: root.themeRounding > 0 ? root.themeRounding : 16
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.25)
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(root.themePrimary, 0.15) }
                        GradientStop { position: 0.4; color: Qt.alpha(root.themeBackground, root.themeBgAlpha) }
                        GradientStop { position: 1.0; color: Qt.alpha(root.themeBackground, root.themeBgAlpha + 0.1) }
                    }

                    MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            Rectangle {
                                width: 44; height: 44; radius: Math.max(8, root.themeRounding - 4)
                                color: Qt.alpha(root.themePrimary, 0.1)
                                border.width: root.themeBorderSize; border.color: Qt.alpha(root.themePrimary, 0.3)
                                Text { anchors.centerIn: parent; text: "󰌌"; font.pixelSize: 22; color: root.themePrimary }
                            }
                            
                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter
                                Text { text: "Lenovo LOQ RGB Controller"; font.pixelSize: 20; font.weight: Font.Bold; color: root.themeText; font.family: "sans-serif" }
                                Text { text: "Legionaura Service Integration"; font.pixelSize: 13; color: root.themeTextMuted; font.family: "sans-serif" }
                            }
                            
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: addHover.containsMouse ? Qt.alpha(root.themePrimary, 0.2) : Qt.alpha(root.themeText, 0.05)
                                border.width: 1; border.color: Qt.alpha(root.themeBorder, 0.2)
                                Text { anchors.centerIn: parent; text: "󰐕"; font.pixelSize: 18; color: addHover.containsMouse ? root.themePrimary : root.themeText }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                MouseArea { 
                                    id: addHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; 
                                    onClicked: root.isEditingCustom = true 
                                }
                            }
                            
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: closeHover.containsMouse ? Qt.alpha(root.themePrimary, 0.2) : "transparent"
                                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 18; color: closeHover.containsMouse ? root.themePrimary : root.themeTextMuted }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: root.themeRounding > 0 ? root.themeRounding : 12
                            color: Qt.alpha(root.themeText, 0.03)
                            border.width: root.themeBorderSize; border.color: Qt.alpha(root.themeBorder, 0.1)
                            
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 20
                                
                                RowLayout {
                                    spacing: 12
                                    Text { text: "󰃠"; font.pixelSize: 20; color: root.themePrimary; Layout.alignment: Qt.AlignVCenter }
                                    Text { text: "Brightness"; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.themeText; Layout.alignment: Qt.AlignVCenter }
                                    RowLayout {
                                        spacing: 6
                                        Repeater {
                                            model: [1, 2]
                                            Rectangle {
                                                width: 40; height: 34; radius: Math.max(4, root.themeRounding - 6)
                                                color: root.rgbBrightness === modelData ? root.themePrimary : Qt.alpha(root.themeText, 0.05)
                                                border.width: root.themeBorderSize; border.color: root.rgbBrightness === modelData ? root.themePrimary : Qt.alpha(root.themeText, 0.1)
                                                Text { anchors.centerIn: parent; text: modelData; font.weight: Font.Bold; font.pixelSize: 14; color: root.rgbBrightness === modelData ? "#000000" : root.themeText }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.rgbBrightness = modelData; root.applyCurrentSettings() } }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: 1; height: 24; color: Qt.alpha(root.themeBorder, 0.15); Layout.alignment: Qt.AlignVCenter }

                                RowLayout {
                                    spacing: 12
                                    Text { text: "󰓅"; font.pixelSize: 20; color: root.themePrimary; Layout.alignment: Qt.AlignVCenter }
                                    Text { text: "Speed"; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.themeText; Layout.alignment: Qt.AlignVCenter }
                                    RowLayout {
                                        spacing: 6
                                        Repeater {
                                            model: [1, 2, 3, 4]
                                            Rectangle {
                                                width: 40; height: 34; radius: Math.max(4, root.themeRounding - 6)
                                                color: root.rgbSpeed === modelData ? root.themePrimary : Qt.alpha(root.themeText, 0.05)
                                                border.width: root.themeBorderSize; border.color: root.rgbSpeed === modelData ? root.themePrimary : Qt.alpha(root.themeText, 0.1)
                                                Text { anchors.centerIn: parent; text: modelData; font.weight: Font.Bold; font.pixelSize: 14; color: root.rgbSpeed === modelData ? "#000000" : root.themeText }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.rgbSpeed = modelData; root.applyCurrentSettings() } }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    width: 56; height: 36; radius: Math.max(8, root.themeRounding)
                                    color: root.rgbPowerState ? Qt.alpha(root.themePrimary, 0.15) : Qt.alpha(root.themeText, 0.05)
                                    border.width: root.themeBorderSize > 1 ? root.themeBorderSize : 2 
                                    border.color: root.rgbPowerState ? root.themePrimary : Qt.alpha(root.themeText, 0.2)
                                    
                                    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    
                                    Text { 
                                        anchors.centerIn: parent; text: "󰐥"; font.pixelSize: 18
                                        color: root.rgbPowerState ? root.themePrimary : root.themeTextMuted
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePower() }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            GridView {
                                id: presetGrid
                                anchors.fill: parent
                                model: presetModel
                                cellWidth: width / 5
                                cellHeight: height / 6
                                clip: true
                                interactive: true 
                                
                                delegate: Item {
                                    id: presetDelegate
                                    property int itemIndex: index
                                    width: GridView.view.cellWidth
                                    height: GridView.view.cellHeight

                                    Rectangle {
                                        id: cardRect
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        radius: root.themeRounding
                                        
                                        property bool isActive: root.savedName === model.name && root.rgbPowerState
                                        
                                        color: isActive ? Qt.alpha(root.themePrimary, 0.25) : (presetMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.08) : root.themeSurface)
                                        border.width: root.themeBorderSize
                                        border.color: isActive ? root.themePrimary : (presetMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.4) : Qt.alpha(root.themeBorder, 0.08))
                                        
                                        scale: presetMouse.containsMouse ? 1.03 : 1.0

                                        Behavior on scale { NumberAnimation { duration: animStyle.animDuration; easing.type: animStyle.bounceEasing } }
                                        Behavior on color { ColorAnimation { duration: animStyle.fadeDuration } }
                                        Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }

                                        MouseArea {
                                            id: presetMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.executeAuraCommand(model.name, model.type, model.colors, false)
                                        }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4 
                                            
                                            Text { 
                                                Layout.alignment: Qt.AlignHCenter; text: model.icon; font.pixelSize: 26
                                                color: cardRect.isActive || presetMouse.containsMouse ? root.themePrimary : Qt.alpha(root.themePrimary, 0.8) 
                                                visible: !model.isCustom 
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                            
                                            Text { 
                                                Layout.alignment: Qt.AlignHCenter; text: model.name; font.pixelSize: 13
                                                font.weight: cardRect.isActive ? Font.Bold : Font.DemiBold
                                                color: cardRect.isActive ? root.themeText : root.themeTextMuted
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        Rectangle {
                                            width: 24; height: 24; radius: 12
                                            anchors { top: parent.top; right: parent.right; margins: 6 }
                                            color: delHover.containsMouse ? "#ff4b6e" : Qt.alpha(root.themeText, 0.15)
                                            
                                            opacity: model.isCustom && (presetMouse.containsMouse || delHover.containsMouse) ? 1.0 : 0.0
                                            visible: opacity > 0
                                            
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 12; color: "#ffffff" }

                                            MouseArea {
                                                id: delHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                preventStealing: true
                                                propagateComposedEvents: false
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true
                                                    root.deleteCustomPreset(presetDelegate.itemIndex)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.6)
                        radius: parent.radius
                        opacity: root.isEditingCustom ? 1.0 : 0.0
                        visible: opacity > 0
                        z: 10
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        
                        MouseArea { anchors.fill: parent; onClicked: root.isEditingCustom = false } 

                        ListModel {
                            id: customZoneModel
                            ListElement { name: "Zone 1"; colorHex: "ff0000" }
                            ListElement { name: "Zone 2"; colorHex: "00ff00" }
                            ListElement { name: "Zone 3"; colorHex: "0000ff" }
                            ListElement { name: "Zone 4"; colorHex: "ffff00" }
                        }

                        Rectangle {
                            id: customPresetEditor
                            width: 600; height: 460 
                            anchors.centerIn: parent
                            radius: root.themeRounding
                            color: Qt.alpha(root.themeBackground, 0.95)
                            border.width: root.themeBorderSize; border.color: Qt.alpha(root.themeBorder, 0.4)
                            
                            MouseArea { anchors.fill: parent } 
                            
                            property string customEffectType: "static"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 36
                                spacing: 24

                                Text { text: "Create Custom 4-Zone Preset"; font.pixelSize: 20; font.weight: Font.Bold; color: root.themeText }

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 46
                                    color: Qt.alpha(root.themeText, 0.05); radius: Math.max(8, root.themeRounding - 4)
                                    border.width: 1; border.color: customNameInput.activeFocus ? root.themePrimary : Qt.alpha(root.themeText, 0.15)
                                    TextInput {
                                        id: customNameInput
                                        anchors.fill: parent; anchors.margins: 14
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: root.themeText; font.pixelSize: 15; font.family: "sans-serif"
                                        text: "My Custom Preset"
                                        selectByMouse: true
                                    }
                                }

                                RowLayout {
                                    spacing: 16
                                    Text { text: "Animation:"; color: root.themeTextMuted; font.pixelSize: 15 }
                                    Repeater {
                                        model: ["static", "breath"]
                                        Rectangle {
                                            width: 100; height: 38; radius: Math.max(8, root.themeRounding - 4)
                                            color: customPresetEditor.customEffectType === modelData ? root.themePrimary : Qt.alpha(root.themeText, 0.05)
                                            border.width: 1; border.color: customPresetEditor.customEffectType === modelData ? root.themePrimary : Qt.alpha(root.themeText, 0.15)
                                            Text { anchors.centerIn: parent; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); font.weight: Font.Bold; color: customPresetEditor.customEffectType === modelData ? "#000" : root.themeText }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: customPresetEditor.customEffectType = modelData }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 24
                                    
                                    Repeater {
                                        model: customZoneModel
                                        ColumnLayout {
                                            spacing: 12
                                            Text { text: model.name; color: root.themeTextMuted; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter }
                                            
                                            Rectangle {
                                                width: 90; height: 50; radius: 6
                                                color: "#" + model.colorHex
                                                border.width: 1; border.color: Qt.alpha(root.themeText, 0.2)
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.activeZoneIndex = index
                                                        let rgb = root.hexToRgb(model.colorHex)
                                                        root.pickerR = rgb.r
                                                        root.pickerG = rgb.g
                                                        root.pickerB = rgb.b
                                                        root.isPickingColor = true
                                                    }
                                                }
                                            }
                                            Text { text: "#" + model.colorHex.toUpperCase(); color: root.themeText; font.pixelSize: 14; font.family: "monospace"; Layout.alignment: Qt.AlignHCenter }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true } 

                                RowLayout {
                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignRight
                                    spacing: 12
                                    Rectangle {
                                        width: 100; height: 42; radius: Math.max(8, root.themeRounding - 4)
                                        color: "transparent"; border.width: 1; border.color: Qt.alpha(root.themeText, 0.2)
                                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 15; color: root.themeText }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isEditingCustom = false }
                                    }
                                    Rectangle {
                                        width: 140; height: 42; radius: Math.max(8, root.themeRounding - 4)
                                        color: Qt.alpha(root.themePrimary, 0.2); border.width: 1; border.color: root.themePrimary
                                        Text { anchors.centerIn: parent; text: "Save Preset"; font.pixelSize: 15; font.weight: Font.Bold; color: root.themePrimary }
                                        MouseArea { 
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let c1 = customZoneModel.get(0).colorHex
                                                let c2 = customZoneModel.get(1).colorHex
                                                let c3 = customZoneModel.get(2).colorHex
                                                let c4 = customZoneModel.get(3).colorHex
                                                let finalColors = `${c1} ${c2} ${c3} ${c4}`
                                                
                                                root.saveNewCustomPreset(customNameInput.text, customPresetEditor.customEffectType, finalColors)
                                                
                                                presetGrid.positionViewAtEnd()
                                                
                                                customNameInput.text = "My Custom Preset"
                                                customPresetEditor.customEffectType = "static"
                                                customZoneModel.setProperty(0, "colorHex", "ff0000")
                                                customZoneModel.setProperty(1, "colorHex", "00ff00")
                                                customZoneModel.setProperty(2, "colorHex", "0000ff")
                                                customZoneModel.setProperty(3, "colorHex", "ffff00")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.7)
                        radius: parent.radius
                        opacity: root.isPickingColor ? 1.0 : 0.0
                        visible: opacity > 0
                        z: 20
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        
                        MouseArea { anchors.fill: parent; onClicked: root.isPickingColor = false } 

                        Rectangle {
                            width: 440; height: 380
                            anchors.centerIn: parent
                            radius: root.themeRounding
                            color: Qt.alpha(root.themeBackground, 0.98)
                            border.width: root.themeBorderSize; border.color: Qt.alpha(root.themeBorder, 0.4)
                            
                            MouseArea { anchors.fill: parent } 
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 32
                                spacing: 20

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20
                                    Rectangle {
                                        width: 60; height: 60; radius: 10
                                        color: root.pickerHex
                                        border.width: 1; border.color: Qt.alpha(root.themeText, 0.2)
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 4
                                        Text { text: "Select Zone Color"; color: root.themeText; font.pixelSize: 18; font.weight: Font.Bold }
                                        Text { text: root.pickerHex.toUpperCase(); color: root.themeTextMuted; font.pixelSize: 14; font.family: "monospace" }
                                    }
                                }

                                Item { Layout.preferredHeight: 8 }

                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 32
                                    RowLayout {
                                        anchors.fill: parent; spacing: 12
                                        Text { text: "R"; color: root.themeTextMuted; font.weight: Font.Bold; font.pixelSize: 15; Layout.preferredWidth: 16 }
                                        Item {
                                            Layout.fillWidth: true; Layout.fillHeight: true
                                            Rectangle { 
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width; height: 10; radius: 5; color: "#ff0000"
                                                Rectangle { 
                                                    anchors.fill: parent; radius: 5
                                                    gradient: Gradient { 
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: "#FF000000" }
                                                        GradientStop { position: 1.0; color: "#00000000" } 
                                                    } 
                                                }
                                            }
                                            Rectangle { 
                                                width: 22; height: 22; radius: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Math.max(0, Math.min(parent.width - 22, (root.pickerR / 255) * (parent.width - 22)))
                                                color: "#ffffff"; border.width: 2; border.color: "#333333" 
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                preventStealing: true
                                                function updateVal(mx) { root.pickerR = Math.round((Math.max(0, Math.min(mx - 11, width - 22)) / Math.max(1, width - 22)) * 255) }
                                                onPressed: updateVal(mouseX)
                                                onPositionChanged: if (pressed) updateVal(mouseX)
                                            }
                                        }
                                        Text { text: root.pickerR.toString().padStart(3, '0'); color: root.themeText; font.pixelSize: 14; font.family: "monospace"; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight }
                                    }
                                }
                                
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 32
                                    RowLayout {
                                        anchors.fill: parent; spacing: 12
                                        Text { text: "G"; color: root.themeTextMuted; font.weight: Font.Bold; font.pixelSize: 15; Layout.preferredWidth: 16 }
                                        Item {
                                            Layout.fillWidth: true; Layout.fillHeight: true
                                            Rectangle { 
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width; height: 10; radius: 5; color: "#00ff00"
                                                Rectangle { 
                                                    anchors.fill: parent; radius: 5
                                                    gradient: Gradient { 
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: "#FF000000" }
                                                        GradientStop { position: 1.0; color: "#00000000" } 
                                                    } 
                                                }
                                            }
                                            Rectangle { 
                                                width: 22; height: 22; radius: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Math.max(0, Math.min(parent.width - 22, (root.pickerG / 255) * (parent.width - 22)))
                                                color: "#ffffff"; border.width: 2; border.color: "#333333" 
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                preventStealing: true
                                                function updateVal(mx) { root.pickerG = Math.round((Math.max(0, Math.min(mx - 11, width - 22)) / Math.max(1, width - 22)) * 255) }
                                                onPressed: updateVal(mouseX)
                                                onPositionChanged: if (pressed) updateVal(mouseX)
                                            }
                                        }
                                        Text { text: root.pickerG.toString().padStart(3, '0'); color: root.themeText; font.pixelSize: 14; font.family: "monospace"; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight }
                                    }
                                }
                                
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 32
                                    RowLayout {
                                        anchors.fill: parent; spacing: 12
                                        Text { text: "B"; color: root.themeTextMuted; font.weight: Font.Bold; font.pixelSize: 15; Layout.preferredWidth: 16 }
                                        Item {
                                            Layout.fillWidth: true; Layout.fillHeight: true
                                            Rectangle { 
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width; height: 10; radius: 5; color: "#0000ff"
                                                Rectangle { 
                                                    anchors.fill: parent; radius: 5
                                                    gradient: Gradient { 
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: "#FF000000" }
                                                        GradientStop { position: 1.0; color: "#00000000" } 
                                                    } 
                                                }
                                            }
                                            Rectangle { 
                                                width: 22; height: 22; radius: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Math.max(0, Math.min(parent.width - 22, (root.pickerB / 255) * (parent.width - 22)))
                                                color: "#ffffff"; border.width: 2; border.color: "#333333" 
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                preventStealing: true
                                                function updateVal(mx) { root.pickerB = Math.round((Math.max(0, Math.min(mx - 11, width - 22)) / Math.max(1, width - 22)) * 255) }
                                                onPressed: updateVal(mouseX)
                                                onPositionChanged: if (pressed) updateVal(mouseX)
                                            }
                                        }
                                        Text { text: root.pickerB.toString().padStart(3, '0'); color: root.themeText; font.pixelSize: 14; font.family: "monospace"; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight }
                                    }
                                }

                                Item { Layout.fillHeight: true } 

                                // Actions
                                RowLayout {
                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignRight
                                    spacing: 12
                                    Rectangle {
                                        width: 100; height: 42; radius: Math.max(8, root.themeRounding - 4)
                                        color: "transparent"; border.width: 1; border.color: Qt.alpha(root.themeText, 0.2)
                                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 15; color: root.themeText }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isPickingColor = false }
                                    }
                                    Rectangle {
                                        width: 120; height: 42; radius: Math.max(8, root.themeRounding - 4)
                                        color: Qt.alpha(root.themePrimary, 0.2); border.width: 1; border.color: root.themePrimary
                                        Text { anchors.centerIn: parent; text: "Apply"; font.pixelSize: 15; font.weight: Font.Bold; color: root.themePrimary }
                                        MouseArea { 
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.activeZoneIndex >= 0) {
                                                    customZoneModel.setProperty(root.activeZoneIndex, "colorHex", root.rgbToHex(root.pickerR, root.pickerG, root.pickerB))
                                                }
                                                root.isPickingColor = false
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