import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property int themeRounding: 14
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.75
    property bool internalChange: false
    property string searchQuery: ""
    
    property string currentAnimPreset: "Default"
    property string currentCursorTheme: "WhiteSur-cursors"
    property var installedCursors: ["WhiteSur-cursors", "Adwaita", "breeze_cursors", "Bibata-Modern-Classic"]

    property color themeBackground: "#141416"
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#ffb3af"

    property var presetList: [
        { name: "Default", desc: "Balanced speed & smooth spring physics", tag: "Balanced" },
        { name: "Snappy", desc: "Ultra fast transitions with minimal delay", tag: "Fast" },
        { name: "Bouncy", desc: "Playful overshoot curve with dynamic bounce", tag: "Playful" },
        { name: "Smooth", desc: "Gentle bezier curve with soft ease-in-out", tag: "Elegant" },
        { name: "Fast Slide", desc: "High performance linear slide animation", tag: "Performance" },
        { name: "Overshoot", desc: "Pop-in scaling with pronounced mechanical pop", tag: "Expressive" }
    ]

    property var settingsSchema: [
        // General & Decoration
        { id: "gaps_in", name: "Inner Gaps", cat: "General", type: "slider", min: 0, max: 30, step: 1, val: 5, file: "general.lua", match: /gaps_in\s*=\s*([0-9.]+)/, replaceCmd: "s/(gaps_in\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "gaps_out", name: "Outer Gaps", cat: "General", type: "slider", min: 0, max: 40, step: 1, val: 5, file: "general.lua", match: /gaps_out\s*=\s*([0-9.]+)/, replaceCmd: "s/(gaps_out\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "border_size", name: "Border Size", cat: "General", type: "slider", min: 0, max: 10, step: 1, val: 2, file: "general.lua", match: /border_size\s*=\s*([0-9.]+)/, replaceCmd: "s/(border_size\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "rounding", name: "Corner Rounding", cat: "Decoration", type: "slider", min: 0, max: 30, step: 1, val: 15, file: "general.lua", match: /rounding\s*=\s*([0-9.]+)/, replaceCmd: "s/(rounding\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "active_opacity", name: "Active Opacity", cat: "Decoration", type: "slider", min: 0.1, max: 1.0, step: 0.05, val: 0.85, file: "general.lua", match: /active_opacity\s*=\s*([0-9.]+)/, replaceCmd: "s/(active_opacity\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "inactive_opacity", name: "Inactive Opacity", cat: "Decoration", type: "slider", min: 0.1, max: 1.0, step: 0.05, val: 0.85, file: "general.lua", match: /inactive_opacity\s*=\s*([0-9.]+)/, replaceCmd: "s/(inactive_opacity\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "blur_enabled", name: "Enable Blur", cat: "Decoration", type: "switch", valBool: true, file: "general.lua", match: /blur\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/, replaceCmd: "/blur\\s*=\\s*\\{/,/\\}/ s/(enabled\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "shadow_enabled", name: "Enable Shadow", cat: "Decoration", type: "switch", valBool: true, file: "general.lua", match: /shadow\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/, replaceCmd: "/shadow\\s*=\\s*\\{/,/\\}/ s/(enabled\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "layout", name: "Layout Mode", cat: "General", type: "toggle", options: ["scrolling", "dwindle", "master"], valStr: "scrolling", file: "general.lua", match: /layout\s*=\s*["']?([a-zA-Z0-9_-]+)["']?/, replaceCmd: "s/(layout\\s*=\\s*)[\"']?[^\"'\\s,]+[\"']?/\\1\"{VAL}\"/" },

        // Animations
        { id: "anim_enabled", name: "Global Animations", cat: "Animations", type: "switch", valBool: true, file: "animations.lua", match: /animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/, replaceCmd: "/animations\\s*=\\s*\\{/,/\\}/ s/(enabled\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "anim_preset", name: "Animation Preset", cat: "Animations", type: "preset", options: ["Default", "Snappy", "Bouncy", "Smooth", "Fast Slide", "Overshoot"], valStr: "Default", file: "animations.lua", match: /--\s*preset:\s*([^\r\n]+)/ },

        // Input & Keyboard
        { id: "numlock", name: "Numlock Default", cat: "Input", type: "switch", valBool: false, file: "input.lua", match: /numlock_by_default\s*=\s*(true|false)/, replaceCmd: "s/(numlock_by_default\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "repeat_rate", name: "Repeat Rate", cat: "Input", type: "slider", min: 10, max: 100, step: 5, val: 50, file: "input.lua", match: /repeat_rate\s*=\s*([0-9.]+)/, replaceCmd: "s/(repeat_rate\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "repeat_delay", name: "Repeat Delay", cat: "Input", type: "slider", min: 100, max: 1000, step: 25, val: 200, file: "input.lua", match: /repeat_delay\s*=\s*([0-9.]+)/, replaceCmd: "s/(repeat_delay\\s*=\\s*)[0-9.]+/\\1{VAL}/" },
        { id: "sensitivity", name: "Mouse Sensitivity", cat: "Input", type: "slider", min: -1.0, max: 1.0, step: 0.1, val: 0.0, file: "input.lua", match: /sensitivity\s*=\s*(-?[0-9.]+)/, replaceCmd: "s/(sensitivity\\s*=\\s*)-?[0-9.]+/\\1{VAL}/" },
        { id: "accel_profile", name: "Accel Profile", cat: "Input", type: "toggle", options: ["flat", "adaptive"], valStr: "flat", file: "input.lua", match: /accel_profile\s*=\s*["']?([a-zA-Z0-9_-]+)["']?/, replaceCmd: "s/(accel_profile\\s*=\\s*)[\"']?[^\"'\\s,]+[\"']?/\\1\"{VAL}\"/" },

        // Touchpad
        { id: "tap_to_click", name: "Tap to Click", cat: "Touchpad", type: "switch", valBool: true, file: "input.lua", match: /tap_to_click\s*=\s*(true|false)/, replaceCmd: "s/(tap_to_click\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "natural_scroll", name: "Natural Scroll", cat: "Touchpad", type: "switch", valBool: true, file: "input.lua", match: /natural_scroll\s*=\s*(true|false)/, replaceCmd: "s/(natural_scroll\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "disable_while_typing", name: "Disable While Typing", cat: "Touchpad", type: "switch", valBool: true, file: "input.lua", match: /disable_while_typing\s*=\s*(true|false)/, replaceCmd: "s/(disable_while_typing\\s*=\\s*)(true|false)/\\1{VAL}/" },
        { id: "scroll_factor", name: "Scroll Factor", cat: "Touchpad", type: "slider", min: 0.1, max: 2.0, step: 0.1, val: 0.5, file: "input.lua", match: /scroll_factor\s*=\s*([0-9.]+)/, replaceCmd: "s/(scroll_factor\\s*=\\s*)[0-9.]+/\\1{VAL}/" },

        // Cursor Theme
        { id: "cursor_theme", name: "Cursor Theme", cat: "Cursor", type: "cursor", valStr: "WhiteSur-cursors", file: "cursor.lua", match: /XCURSOR_THEME",\s*"([^"]+)"/ },
        { id: "cursor_size", name: "Cursor Size", cat: "Cursor", type: "slider", min: 16, max: 48, step: 4, val: 24, file: "cursor.lua", match: /XCURSOR_SIZE",\s*"([0-9]+)"/, replaceCmd: "s/(HYPRCURSOR_SIZE\",\\s*)\"[0-9]+\"/\\1\"{VAL}\"/g; s/(XCURSOR_SIZE\",\\s*)\"[0-9]+\"/\\1\"{VAL}\"/g" }
    ]

    Process { id: bashRunner }

    Process {
        id: cursorScanner
        command: ["bash", "-c", "find /usr/share/icons ~/.icons ~/.local/share/icons -maxdepth 2 -name cursors 2>/dev/null | xargs -n1 dirname | xargs -n1 basename | sort -u"]
        stdout: SplitParser {
            onRead: (data) => {
                let themes = data.trim().split("\n").filter(t => t.length > 0)
                if (themes.length > 0) root.installedCursors = themes
            }
        }
    }

    Timer {
        id: debounceWriteTimer
        interval: 100
        repeat: false
        property string pendingId: ""
        property var pendingVal: null
        onTriggered: root.executeCommit(pendingId, pendingVal)
    }

    Timer {
        id: internalLockTimer
        interval: 400
        repeat: false
        onTriggered: root.internalChange = false
    }

    function commitChange(id, val) {
        debounceWriteTimer.pendingId = id
        debounceWriteTimer.pendingVal = val
        debounceWriteTimer.restart()
    }

    function executeCommit(id, val) {
        let setting = root.settingsSchema.find(s => s.id === id)
        if (!setting) return

        root.internalChange = true
        internalLockTimer.restart()

        if (setting.type === "slider") setting.val = val
        if (setting.type === "switch") setting.valBool = val
        if (setting.type === "toggle" || setting.type === "preset" || setting.type === "cursor") {
            setting.valStr = val
            if (setting.id === "anim_preset") root.currentAnimPreset = val
            if (setting.id === "cursor_theme") root.currentCursorTheme = val
        }

        let path = Quickshell.env("HOME") + "/.config/hypr/configs/" + setting.file

        if (setting.type === "preset") {
            root.applyAnimationPreset(val, path)
        } else if (setting.type === "cursor") {
            root.applyCursorTheme(val, path)
        } else {
            let valStr = (typeof val === "boolean") ? (val ? "true" : "false") : (typeof val === "number" ? (val % 1 === 0 ? val.toString() : val.toFixed(2)) : val.toString())
            let cmd = `sed -i -E '${setting.replaceCmd.replace("{VAL}", valStr)}' '${path}'`

            if (setting.id === "layout") {
                cmd += ` && hyprctl keyword general:layout '${valStr}'`
            }

            if (bashRunner.running) bashRunner.terminate()
            bashRunner.command = ["bash", "-c", cmd]
            bashRunner.running = true
        }

        for (let i = 0; i < filteredModel.count; i++) {
            if (filteredModel.get(i).itemId === id) {
                if (setting.type === "slider") filteredModel.setProperty(i, "itemVal", val)
                if (setting.type === "switch") filteredModel.setProperty(i, "itemValBool", val)
                if (setting.type === "toggle" || setting.type === "preset" || setting.type === "cursor") filteredModel.setProperty(i, "itemValStr", val)
                break
            }
        }
    }

    function applyAnimationPreset(preset, path) {
        let content = `-- preset: ${preset}\n`
        if (preset === "Snappy") {
            content += `hl.config({ animations = { enabled = true } })\n` +
                `hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "default", style = "popin 80%" })\n` +
                `hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "default", style = "popin 80%" })\n` +
                `hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "default" })\n` +
                `hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })\n` +
                `hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "default" })`
        } else if (preset === "Bouncy") {
            content += `hl.config({ animations = { enabled = true } })\n` +
                `hl.animation({ leaf = "windowsIn", enabled = true, speed = 6, bezier = "default", style = "popin 70%" })\n` +
                `hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 70%" })\n` +
                `hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "default" })\n` +
                `hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })\n` +
                `hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })`
        } else if (preset === "Smooth") {
            content += `hl.config({ animations = { enabled = true } })\n` +
                `hl.animation({ leaf = "windowsIn", enabled = true, speed = 7, bezier = "default", style = "fade" })\n` +
                `hl.animation({ leaf = "windowsOut", enabled = true, speed = 6, bezier = "default", style = "fade" })\n` +
                `hl.animation({ leaf = "windowsMove", enabled = true, speed = 7, bezier = "default" })\n` +
                `hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })\n` +
                `hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "default", style = "slidefade" })\n` +
                `hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })`
        } else if (preset === "Fast Slide") {
            content += `hl.config({ animations = { enabled = true } })\n` +
                `hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.5, bezier = "default" })\n` +
                `hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })\n` +
                `hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })`
        } else if (preset === "Overshoot") {
            content += `hl.config({ animations = { enabled = true } })\n` +
                `hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })\n` +
                `hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "popin 80%" })\n` +
                `hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "default" })\n` +
                `hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })\n` +
                `hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "default" })`
        } else {
            content += `hl.config({ animations = { enabled = true } })\n` +
                `hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "default" })\n` +
                `hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })\n` +
                `hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slide" })\n` +
                `hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })`
        }

        let cmd = `cat << 'EOF' > '${path}'\n${content}\nEOF`
        if (bashRunner.running) bashRunner.terminate()
        bashRunner.command = ["bash", "-c", cmd]
        bashRunner.running = true
    }

    function applyCursorTheme(themeName, path) {
        let size = root.settingsSchema.find(s => s.id === "cursor_size").val || 24
        let content = `hl.env("HYPRCURSOR_THEME", "${themeName}")\n` +
            `hl.env("XCURSOR_THEME", "${themeName}")\n` +
            `hl.env("HYPRCURSOR_SIZE", "${size}")\n` +
            `hl.env("XCURSOR_SIZE", "${size}")`

        let cmd = `cat << 'EOF' > '${path}'\n${content}\nEOF`
        if (bashRunner.running) bashRunner.terminate()
        bashRunner.command = ["bash", "-c", `${cmd} && hyprctl setcursor '${themeName}' ${size}`]
        bashRunner.running = true
    }

    function parseConfigFile(content, filename) {
        if (!content) return
        let hasChanges = false

        for (let i = 0; i < root.settingsSchema.length; i++) {
            let s = root.settingsSchema[i]
            if (s.file === filename && s.match) {
                let match = content.match(s.match)
                if (match && match[1]) {
                    let parsedVal = match[1].trim()
                    if (s.type === "slider") s.val = parseFloat(parsedVal)
                    if (s.type === "switch") s.valBool = (parsedVal === "true")
                    if (s.type === "toggle" || s.type === "preset" || s.type === "cursor") {
                        s.valStr = parsedVal
                        if (s.id === "anim_preset") root.currentAnimPreset = parsedVal
                        if (s.id === "cursor_theme") root.currentCursorTheme = parsedVal
                    }
                    hasChanges = true
                }
            }
        }

        if (hasChanges && !root.internalChange) {
            root.filterSettings(root.searchQuery)
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
                    let hex = "#" + match[1]
                    root.themeBorder = hex
                    root.themePrimary = hex
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
                parseConfigFile(content, "general.lua")
                let rMatch = content.match(/rounding\s*=\s*([0-9.]+)/)
                if (rMatch && rMatch[1]) root.themeRounding = parseInt(rMatch[1])
                let bMatch = content.match(/border_size\s*=\s*([0-9.]+)/)
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
            try { parseConfigFile(text(), "animations.lua") } catch (e) {}
        }
    }

    FileView {
        id: inputConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/input.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { parseConfigFile(text(), "input.lua") } catch (e) {}
        }
    }

    FileView {
        id: cursorConfigFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/cursor.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { parseConfigFile(text(), "cursor.lua") } catch (e) {}
        }
    }

    Component.onCompleted: {
        cursorScanner.running = true
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        inputConfigFile.reload()
        cursorConfigFile.reload()
        root.filterSettings(root.searchQuery)
    }

    ListModel { id: filteredModel }

    function filterSettings(query) {
        filteredModel.clear()
        let q = query ? query.trim().toLowerCase() : ""

        for (let i = 0; i < root.settingsSchema.length; i++) {
            let item = root.settingsSchema[i]
            let itemDesc = String(item.name || "")
            let itemCat = String(item.cat || "General")

            if (q === "" || itemDesc.toLowerCase().indexOf(q) !== -1 || itemCat.toLowerCase().indexOf(q) !== -1) {
                filteredModel.append({
                    itemId: item.id,
                    itemName: itemDesc,
                    itemCategory: itemCat,
                    itemType: item.type,
                    itemMin: item.min || 0,
                    itemMax: item.max || 10,
                    itemStep: item.step || 1,
                    itemVal: item.val !== undefined ? item.val : 0,
                    itemValBool: item.valBool !== undefined ? item.valBool : false,
                    itemValStr: item.valStr !== undefined ? item.valStr : ""
                })
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: controlWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: Quickshell.screens.length > 0 && modelData.name === Quickshell.screens[0].name
            visible: isTargetMonitor

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-config"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1

            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            Rectangle {
                id: mainCard
                width: Math.min(680, parent.width - 40)
                height: Math.min(640, parent.height - 80)
                anchors.centerIn: parent

                focus: isTargetMonitor
                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.40)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text { text: ""; font.pixelSize: 24; color: root.themePrimary }
                        Text { text: "Hyprland Control Center"; font.pixelSize: 18; font.weight: Font.Bold; color: root.themeText }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 220
                            Layout.preferredHeight: 36
                            radius: Math.max(4, root.themeRounding - 4)
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: searchInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.1)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text { text: ""; font.pixelSize: 13; color: root.themeTextMuted }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    font.pixelSize: 13
                                    color: root.themeText
                                    placeholderText: "Search settings..."
                                    placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.5)
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}

                                    Component.onCompleted: { if (controlWindow.isTargetMonitor) forceActiveFocus() }
                                    onTextChanged: {
                                        root.searchQuery = text
                                        root.filterSettings(text)
                                    }
                                    Keys.onDownPressed: settingsList.incrementCurrentIndex()
                                    Keys.onUpPressed: settingsList.decrementCurrentIndex()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 1; color: Qt.alpha(root.themeBorder, 0.20)
                    }

                    ListView {
                        id: settingsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: filteredModel
                        clip: true
                        spacing: 6
                        highlightFollowsCurrentItem: true

                        ScrollBar.vertical: ScrollBar {
                            active: settingsList.moving || settingsList.flicking
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            id: delegateItem
                            width: settingsList.width
                            height: 52
                            radius: Math.max(4, root.themeRounding - 6)
                            color: ListView.isCurrentItem ? Qt.alpha(root.themePrimary, 0.15) : Qt.rgba(1, 1, 1, 0.04)

                            // Left Column: Setting Label
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 180
                                text: model.itemName
                                color: root.themeText
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            // Middle Column: Category Badge
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                implicitWidth: catText.implicitWidth + 14
                                radius: 6
                                color: Qt.alpha(root.themeText, 0.08)

                                Text {
                                    id: catText
                                    anchors.centerIn: parent
                                    text: model.itemCategory
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.themeTextMuted
                                }
                            }

                            // Right Column: Controls Container
                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 140
                                height: 36

                                // Slider Control
                                RowLayout {
                                    anchors.centerIn: parent
                                    visible: model.itemType === "slider"
                                    spacing: 6

                                    Rectangle {
                                        width: 28; height: 28
                                        radius: 6
                                        color: minusMouse.containsPress ? Qt.alpha(root.themePrimary, 0.4) : (minusMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.alpha(root.themePrimary, 0.15))
                                        border.color: Qt.alpha(root.themePrimary, 0.4)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "-"
                                            color: root.themeText
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: minusMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let step = model.itemStep || 1
                                                let minVal = model.itemMin
                                                let curVal = model.itemVal
                                                let newVal = Math.max(minVal, curVal - step)
                                                let precision = step < 1 ? 2 : 0
                                                newVal = parseFloat(newVal.toFixed(precision))
                                                root.commitChange(model.itemId, newVal)
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 42
                                        horizontalAlignment: Text.AlignHCenter
                                        text: Number(model.itemVal).toFixed(model.itemStep < 1 ? 2 : 0)
                                        color: root.themePrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }

                                    Rectangle {
                                        width: 28; height: 28
                                        radius: 6
                                        color: plusMouse.containsPress ? Qt.alpha(root.themePrimary, 0.4) : (plusMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.alpha(root.themePrimary, 0.15))
                                        border.color: Qt.alpha(root.themePrimary, 0.4)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "+"
                                            color: root.themeText
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: plusMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let step = model.itemStep || 1
                                                let maxVal = model.itemMax
                                                let curVal = model.itemVal
                                                let newVal = Math.min(maxVal, curVal + step)
                                                let precision = step < 1 ? 2 : 0
                                                newVal = parseFloat(newVal.toFixed(precision))
                                                root.commitChange(model.itemId, newVal)
                                            }
                                        }
                                    }
                                }

                                // Toggle Switch
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: model.itemType === "switch"
                                    width: 42; height: 22
                                    radius: 11
                                    color: model.itemValBool ? root.themePrimary : Qt.rgba(1, 1, 1, 0.1)
                                    border.color: model.itemValBool ? root.themePrimary : Qt.rgba(1, 1, 1, 0.2)
                                    border.width: 1

                                    Rectangle {
                                        x: model.itemValBool ? parent.width - width - 3 : 3
                                        y: 3; width: 16; height: 16; radius: 8
                                        color: model.itemValBool ? root.themeBackground : "#FFFFFF"
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.commitChange(model.itemId, !model.itemValBool)
                                    }
                                }

                                // Mode / Accel Toggle Button
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: model.itemType === "toggle"
                                    width: 110; height: 28
                                    radius: 6
                                    color: toggleMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.alpha(root.themePrimary, 0.15)
                                    border.color: Qt.alpha(root.themePrimary, 0.4)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.itemValStr.toUpperCase()
                                        color: root.themePrimary
                                        font.pixelSize: 11; font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: toggleMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let setting = root.settingsSchema.find(s => s.id === model.itemId)
                                            if (setting && setting.options && setting.options.length > 0) {
                                                let opts = setting.options
                                                let idx = opts.indexOf(model.itemValStr)
                                                let nextIdx = (idx >= 0) ? (idx + 1) % opts.length : 0
                                                root.commitChange(model.itemId, opts[nextIdx])
                                            }
                                        }
                                    }
                                }

                                // Animation Preset Button
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: model.itemType === "preset"
                                    width: 130; height: 28
                                    radius: 6
                                    color: presetTriggerMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.alpha(root.themePrimary, 0.15)
                                    border.color: Qt.alpha(root.themePrimary, 0.4)
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: root.currentAnimPreset
                                            color: root.themePrimary
                                            font.pixelSize: 11; font.weight: Font.Bold
                                        }
                                        Text { text: "▾"; color: root.themePrimary; font.pixelSize: 10 }
                                    }

                                    MouseArea {
                                        id: presetTriggerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: presetDialog.visible = true
                                    }
                                }

                                // Cursor Theme Selection Button
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: model.itemType === "cursor"
                                    width: 130; height: 28
                                    radius: 6
                                    color: cursorTriggerMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.28) : Qt.alpha(root.themePrimary, 0.15)
                                    border.color: Qt.alpha(root.themePrimary, 0.4)
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: root.currentCursorTheme
                                            color: root.themePrimary
                                            font.pixelSize: 11; font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 95
                                        }
                                        Text { text: "▾"; color: root.themePrimary; font.pixelSize: 10 }
                                    }

                                    MouseArea {
                                        id: cursorTriggerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cursorDialog.visible = true
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        color: Qt.rgba(0, 0, 0, 0.18)
                        radius: Math.max(4, root.themeRounding - 6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text { text: filteredModel.count + " settings loaded"; font.pixelSize: 11; color: root.themeTextMuted }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 28; height: 18; radius: 4
                                    color: Qt.alpha(root.themeText, 0.1)
                                    Text { anchors.centerIn: parent; text: "ESC"; font.pixelSize: 9; color: root.themeTextMuted; font.weight: Font.Bold }
                                }
                                Text { text: "Close"; font.pixelSize: 11; color: root.themeTextMuted }
                            }
                        }
                    }
                }

                // Animation Preset Selection Dialog
                Rectangle {
                    id: presetDialog
                    anchors.fill: parent
                    visible: false
                    radius: root.themeRounding
                    color: Qt.rgba(0, 0, 0, 0.75)
                    z: 100

                    MouseArea {
                        anchors.fill: parent
                        onClicked: presetDialog.visible = false
                    }

                    Rectangle {
                        width: parent.width - 60
                        height: parent.height - 70
                        anchors.centerIn: parent
                        radius: root.themeRounding
                        color: root.themeBackground
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.themeBorder, 0.5)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "🪄"; font.pixelSize: 20; color: root.themePrimary }
                                Text { text: "Select Animation Preset"; font.pixelSize: 16; font.weight: Font.Bold; color: root.themeText }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 26; height: 26; radius: 13
                                    color: dialogCloseMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                                    Text { anchors.centerIn: parent; text: "✕"; color: root.themeText; font.pixelSize: 11 }
                                    MouseArea {
                                        id: dialogCloseMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: presetDialog.visible = false
                                    }
                                }
                            }

                            Text {
                                text: "Choose a pre-configured physics curve for window popups, transitions, and workspaces."
                                color: root.themeTextMuted
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.themeBorder, 0.2) }

                            ListView {
                                id: presetListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: root.presetList
                                spacing: 8
                                clip: true

                                delegate: Rectangle {
                                    width: presetListView.width
                                    height: 58
                                    radius: 8
                                    property bool isActive: modelData.name === root.currentAnimPreset
                                    color: isActive ? Qt.alpha(root.themePrimary, 0.20) : (presetCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                                    border.color: isActive ? root.themePrimary : Qt.rgba(1, 1, 1, 0.1)
                                    border.width: isActive ? 2 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        ColumnLayout {
                                            spacing: 2
                                            Layout.fillWidth: true
                                            Text { text: modelData.name; color: root.themeText; font.pixelSize: 13; font.weight: Font.Bold }
                                            Text { text: modelData.desc; color: root.themeTextMuted; font.pixelSize: 11; elide: Text.ElideRight }
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 20
                                            Layout.preferredWidth: tagText.implicitWidth + 10
                                            radius: 4
                                            color: isActive ? root.themePrimary : Qt.rgba(1, 1, 1, 0.08)

                                            Text {
                                                id: tagText
                                                anchors.centerIn: parent
                                                text: modelData.tag
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: isActive ? root.themeBackground : root.themeTextMuted
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: presetCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.commitChange("anim_preset", modelData.name)
                                            presetDialog.visible = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Cursor Theme Selector Dialog
                Rectangle {
                    id: cursorDialog
                    anchors.fill: parent
                    visible: false
                    radius: root.themeRounding
                    color: Qt.rgba(0, 0, 0, 0.75)
                    z: 100

                    MouseArea {
                        anchors.fill: parent
                        onClicked: cursorDialog.visible = false
                    }

                    Rectangle {
                        width: parent.width - 60
                        height: parent.height - 70
                        anchors.centerIn: parent
                        radius: root.themeRounding
                        color: root.themeBackground
                        border.width: root.themeBorderSize
                        border.color: Qt.alpha(root.themeBorder, 0.5)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "🖱️"; font.pixelSize: 20; color: root.themePrimary }
                                Text { text: "Installed Cursor Themes"; font.pixelSize: 16; font.weight: Font.Bold; color: root.themeText }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 26; height: 26; radius: 13
                                    color: cursorCloseMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                                    Text { anchors.centerIn: parent; text: "✕"; color: root.themeText; font.pixelSize: 11 }
                                    MouseArea {
                                        id: cursorCloseMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cursorDialog.visible = false
                                    }
                                }
                            }

                            Text {
                                text: "System detected " + root.installedCursors.length + " installed cursor pack(s). Click to apply dynamically."
                                color: root.themeTextMuted
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.themeBorder, 0.2) }

                            ListView {
                                id: cursorListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: root.installedCursors
                                spacing: 6
                                clip: true

                                delegate: Rectangle {
                                    width: cursorListView.width
                                    height: 48
                                    radius: 8
                                    property bool isActive: modelData === root.currentCursorTheme
                                    color: isActive ? Qt.alpha(root.themePrimary, 0.20) : (cursorCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                                    border.color: isActive ? root.themePrimary : Qt.rgba(1, 1, 1, 0.1)
                                    border.width: isActive ? 2 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        spacing: 12

                                        Text { text: "👆"; font.pixelSize: 16 }
                                        Text { text: modelData; color: root.themeText; font.pixelSize: 13; font.weight: Font.Bold; Layout.fillWidth: true }

                                        Rectangle {
                                            visible: isActive
                                            width: 20; height: 20; radius: 10
                                            color: root.themePrimary
                                            Text { anchors.centerIn: parent; text: "✓"; color: root.themeBackground; font.pixelSize: 11; font.weight: Font.Bold }
                                        }
                                    }

                                    MouseArea {
                                        id: cursorCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.commitChange("cursor_theme", modelData)
                                            cursorDialog.visible = false
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