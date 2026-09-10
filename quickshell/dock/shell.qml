import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects

Scope {
    id: root

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#a1a1aa"
    
    property int themeRounding: 20
    property int themeBorderSize: 1
    property real themeBgAlpha: 0.5
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: "#141416" 
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.12) 

    QtObject {
        id: style
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.5
        property color hoverColor: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.12)
    }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    Process { id: rootExecProcess }
    function exec(cmd) {
        rootExecProcess.running = false
        rootExecProcess.command = ["bash", "-c", cmd + " >/dev/null 2>&1 & disown"]
        rootExecProcess.running = true
    }

    property string savedAppsFilePath: Quickshell.env("HOME") + "/.config/quickshell/json/dock_pinned.json"

    ListModel { 
        id: pinnedAppsModel 
    }

    FileView {
        id: savedAppsFile
        path: root.savedAppsFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text().trim()
                if (content === "") return
                
                let apps = JSON.parse(content)
                if (apps && Array.isArray(apps)) {
                    pinnedAppsModel.clear()
                    for (let i = 0; i < apps.length; i++) {
                        pinnedAppsModel.append(apps[i])
                    }
                    return
                }
            } catch(e) {}
            
            if (pinnedAppsModel.count === 0) root.loadDefaultApps()
        }
        onLoadFailed: {
            if (pinnedAppsModel.count === 0) root.loadDefaultApps()
        }
    }

    Process { id: saveProcess }

    function loadDefaultApps() {
        pinnedAppsModel.clear()
        pinnedAppsModel.append({ name: "Zen Browser", iconName: "zen", cmd: "zen-browser", wmClass: "zen", process: "zen", filePath: "" })
        pinnedAppsModel.append({ name: "Terminal", iconName: "kitty", cmd: "kitty", wmClass: "kitty", process: "kitty", filePath: "" })
        pinnedAppsModel.append({ name: "Files", iconName: "org.gnome.Nautilus", cmd: "nautilus", wmClass: "org.gnome.nautilus", process: "nautilus", filePath: "" })
        pinnedAppsModel.append({ name: "VSCodium", iconName: "vscodium", cmd: "codium", wmClass: "codium", process: "codium", filePath: "" })
        pinnedAppsModel.append({ name: "VirtualBox", iconName: "virtualbox", cmd: "virtualbox", wmClass: "virtualbox", process: "virtualbox", filePath: "" })
        pinnedAppsModel.append({ name: "Calculator", iconName: "org.gnome.Calculator", cmd: "gnome-calculator", wmClass: "org.gnome.calculator", process: "gnome-calculator", filePath: "" })
        pinnedAppsModel.append({ name: "Disks", iconName: "org.gnome.DiskUtility", cmd: "gnome-disks", wmClass: "org.gnome.diskutility", process: "gnome-disks", filePath: "" })
        pinnedAppsModel.append({ name: "Document Viewer", iconName: "org.gnome.Evince", cmd: "evince", wmClass: "org.gnome.evince", process: "evince", filePath: "" })
        pinnedAppsModel.append({ name: "Easy Effects", iconName: "com.github.wwmm.easyeffects", cmd: "easyeffects", wmClass: "com.github.wwmm.easyeffects", process: "easyeffects", filePath: "" })
        root.savePinnedApps()
    }

    function savePinnedApps() {
        let apps = []
        for (let i = 0; i < pinnedAppsModel.count; i++) {
            let item = pinnedAppsModel.get(i)
            apps.push({ name: item.name, iconName: item.iconName, cmd: item.cmd, wmClass: item.wmClass, process: item.process, filePath: item.filePath || "" })
        }
        let jsonStr = JSON.stringify(apps)
        
        saveProcess.command = ["bash", "-c", "mkdir -p $(dirname '" + root.savedAppsFilePath + "') && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + root.savedAppsFilePath + "'"]
        saveProcess.running = true
    }

    function isAppPinned(app) {
        if (!app) return false;
        let targetPath = app.filePath || ""
        let targetClass = (app.wmClass || "").toLowerCase()
        let targetCmd = (app.cmd || "").toLowerCase()
        for (let i = 0; i < pinnedAppsModel.count; i++) {
            let item = pinnedAppsModel.get(i)
            let pPath = item.filePath || ""
            let pClass = (item.wmClass || "").toLowerCase()
            let pCmd = (item.cmd || "").toLowerCase()
            
            if (targetPath && pPath && targetPath === pPath) return true
            if (targetClass && pClass && (targetClass === pClass || targetClass.includes(pClass) || pClass.includes(targetClass))) return true
            if (targetCmd && pCmd && (targetCmd === pCmd || targetCmd.includes(pCmd) || pCmd.includes(targetCmd))) return true
        }
        return false
    }

    function togglePinApp(app) {
        if (!app) return;
        let targetPath = app.filePath || ""
        let targetClass = (app.wmClass || "").toLowerCase()
        let targetCmd = (app.cmd || "").toLowerCase()
        let newList = []
        let found = false
        
        for (let i = 0; i < pinnedAppsModel.count; i++) {
            let item = pinnedAppsModel.get(i)
            let pPath = item.filePath || ""
            let pClass = (item.wmClass || "").toLowerCase()
            let pCmd = (item.cmd || "").toLowerCase()
            
            let isMatch = false
            if (targetPath && pPath && targetPath === pPath) {
                isMatch = true
            } else if (targetClass && pClass && (targetClass === pClass || targetClass.includes(pClass) || pClass.includes(targetClass))) {
                isMatch = true
            } else if (targetCmd && pCmd && (targetCmd === pCmd || targetCmd.includes(pCmd) || pCmd.includes(targetCmd))) {
                isMatch = true
            }
            
            if (isMatch) {
                found = true
            } else {
                newList.push({
                    name: item.name,
                    iconName: item.iconName,
                    cmd: item.cmd,
                    wmClass: item.wmClass,
                    process: item.process,
                    filePath: item.filePath || ""
                })
            }
        }
        
        if (!found) {
            newList.push({
                name: app.name,
                iconName: app.iconName,
                cmd: app.cmd,
                wmClass: app.wmClass,
                process: app.process,
                filePath: app.filePath || ""
            })
        }
        
        pinnedAppsModel.clear()
        for (let i = 0; i < newList.length; i++) {
            pinnedAppsModel.append(newList[i])
        }
        root.savePinnedApps()
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
        id: generalFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(parseInt(rMatch[1]) + 4, 28)
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
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    Timer {
        id: bootTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: { 
            savedAppsFile.reload()
            colorFile.reload()
            generalFile.reload()
            animConfigFile.reload() 
        }
    }

    Variants {
        model: Quickshell.screens
        
        delegate: PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors { 
                bottom: true
            }
            
            implicitWidth: Math.max(masterDockLayout.implicitWidth + 48, 260)
            
            property int currentHitboxHeight: 8
            implicitHeight: currentHitboxHeight
            color: "transparent"

            property string outputName: dockWindow.screen ? dockWindow.screen.name : ""

            property string activeTooltipText: ""
            property real activeTooltipX: 0

            property bool isOverlapped: false
            property bool dockPinnedOpen: false 
            
            property bool dockHovered: dockHoverHandler.hovered
            property bool bottomHovered: bottomHoverHandler.hovered
            property bool anyHovered: dockHovered || bottomHovered
            
            property bool dockLatchedOpen: false

            onAnyHoveredChanged: {
                if (anyHovered) { 
                    dockHideTimer.stop()
                    dockLatchedOpen = true 
                } else { 
                    dockHideTimer.restart() 
                }
            }
            
            Timer {
                id: dockHideTimer
                interval: 800 
                repeat: false
                onTriggered: {
                    if (!dockWindow.anyHovered) {
                        dockWindow.dockLatchedOpen = false
                    }
                }
            }

            property bool dockShouldBeVisible: dockPinnedOpen || dockLatchedOpen || !isOverlapped
            property var runningClients: []
            property var unpinnedApps: []

            Timer {
                id: hitboxShrinkTimer
                interval: style.animDuration + 10 
                onTriggered: {
                    if (!dockWindow.dockShouldBeVisible) {
                        dockWindow.currentHitboxHeight = 8
                    }
                }
            }

            onDockShouldBeVisibleChanged: {
                if (dockShouldBeVisible) {
                    hitboxShrinkTimer.stop()
                    currentHitboxHeight = 140
                } else {
                    hitboxShrinkTimer.restart()
                }
            }

            Process { id: launchProcess }

            function launchApp(app) {
                if (!app) return
                
                let filePath = (app.filePath || "").trim()
                let cmd = (app.cmd || "").trim()
                let wmClass = (app.wmClass || "").trim()

                let bashScript = `
                    fp=${root.escapeShell(filePath)}
                    c=${root.escapeShell(cmd)}
                    w=${root.escapeShell(wmClass)}

                    # 1. Desktop file launch via GIO
                    if [ -n "$fp" ] && [ -f "$fp" ]; then
                        gio launch "$fp" 2>/dev/null && exit 0
                        gtk-launch "$(basename "$fp" .desktop)" 2>/dev/null && exit 0
                    fi

                    # 2. gtk-launch resolution across possible desktop IDs
                    for target in "$w" "$c" "$(basename "$fp" 2>/dev/null)"; do
                        if [ -n "$target" ]; then
                            clean="\${target%.desktop}"
                            gtk-launch "$clean" 2>/dev/null && exit 0
                        fi
                    done

                    # 3. Handle reverse-DNS IDs (e.g. org.gnome.Software -> gnome-software, org.gnome.baobab -> baobab)
                    for target in "$w" "$c"; do
                        if [[ "$target" == *.* ]]; then
                            base="\${target##*.}"
                            base_lower="\${base,,}"
                            if command -v "gnome-$base_lower" >/dev/null 2>&1; then
                                "gnome-$base_lower" >/dev/null 2>&1 & disown
                                exit 0
                            elif command -v "$base_lower" >/dev/null 2>&1; then
                                "$base_lower" >/dev/null 2>&1 & disown
                                exit 0
                            fi
                        fi
                    done

                    # 4. Standard executable in PATH
                    if [ -n "$c" ] && command -v "$c" >/dev/null 2>&1; then
                        "$c" >/dev/null 2>&1 & disown
                        exit 0
                    fi

                    # 5. Raw fallback
                    if [ -n "$c" ]; then
                        eval "$c" >/dev/null 2>&1 & disown
                        exit 0
                    fi
                `
                launchProcess.running = false
                launchProcess.command = ["bash", "-c", bashScript]
                launchProcess.running = true
            }

            function commitDragOrder(vModel) {
                let newOrder = []
                for (let i = 0; i < vModel.items.count; i++) {
                    let m = vModel.items.get(i).model
                    newOrder.push({ 
                        name: m.name, 
                        iconName: m.iconName, 
                        cmd: m.cmd, 
                        wmClass: m.wmClass, 
                        process: m.process,
                        filePath: m.filePath || ""
                    })
                }
                pinnedAppsModel.clear()
                for (let i = 0; i < newOrder.length; i++) {
                    pinnedAppsModel.append(newOrder[i])
                }
                root.savePinnedApps()
            }

            Timer {
                id: persistTimer
                interval: 50
                onTriggered: dockWindow.commitDragOrder(visualModel)
            }

            Process {
                id: clientProcess
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let output = text.trim()
                            if (!output) return
                            let data = JSON.parse(output)
                            
                            dockWindow.runningClients = data.clients || []
                            dockWindow.isOverlapped = data.overlap === true

                            let info = data.running_info || []
                            let unpinned = []
                            
                            for (let i = 0; i < info.length; i++) {
                                let app = info[i]
                                let isPinned = false
                                let rClass = (app.wmClass || "").toLowerCase()
                                let rCmd = (app.cmd || "").toLowerCase()
                                
                                for (let j = 0; j < pinnedAppsModel.count; j++) {
                                    let pItem = pinnedAppsModel.get(j)
                                    let pClass = (pItem.wmClass || "").toLowerCase()
                                    let pCmd = (pItem.cmd || "").toLowerCase()
                                    
                                    if (
                                        (rClass && pClass && (rClass === pClass || rClass.includes(pClass) || pClass.includes(rClass))) ||
                                        (rCmd && pCmd && (rCmd === pCmd || rCmd.includes(pCmd) || pCmd.includes(rCmd)))
                                    ) {
                                        isPinned = true
                                        break
                                    }
                                }
                                if (!isPinned) {
                                    let alreadyExists = unpinned.some(item => (item.wmClass || "").toLowerCase() === rClass)
                                    if (!alreadyExists) {
                                        unpinned.push(app)
                                    }
                                }
                            }
                            dockWindow.unpinnedApps = unpinned

                        } catch (e) {}
                    }
                }
            }

            Timer {
                id: clientTimer
                interval: 350
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    let pyScript = `
import json, subprocess, sys, os, glob, re

def resolve_desktop_meta(cls):
    if not cls: return "", cls, cls.capitalize(), cls
    search_ids = [cls, cls + ".desktop", cls.lower(), cls.lower() + ".desktop"]
    if "." in cls:
        stem = cls.split(".")[-1]
        search_ids.extend([stem, stem.lower(), "gnome-" + stem.lower(), "org.gnome." + stem])
    
    candidate_dirs = [
        "/usr/share/applications",
        os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
    ]
    
    for d in candidate_dirs:
        for s in search_ids:
            target_path = os.path.join(d, s if s.endswith(".desktop") else s + ".desktop")
            if os.path.exists(target_path):
                try:
                    with open(target_path, "r", encoding="utf-8") as f:
                        raw = f.read()
                        exec_l = next((l.split("=", 1)[1].strip() for l in raw.split("\\n") if l.startswith("Exec=")), "")
                        name_l = next((l.split("=", 1)[1].strip() for l in raw.split("\\n") if l.startswith("Name=")), "")
                        icon_l = next((l.split("=", 1)[1].strip() for l in raw.split("\\n") if l.startswith("Icon=")), "")
                        clean_cmd = re.sub(r'%[fFuUikKc]', '', exec_l).strip()
                        return target_path, clean_cmd if clean_cmd else cls, name_l if name_l else cls, icon_l if icon_l else cls
                except Exception:
                    pass
    return "", cls, cls.split(".")[-1].capitalize(), cls

try:
    target_mon_name = sys.argv[1] if len(sys.argv) > 1 else ""
    mon_data = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
    my_mon = next((m for m in mon_data if m.get("name") == target_mon_name), None)
    if not my_mon:
        my_mon = next((m for m in mon_data if m.get("focused")), mon_data[0] if mon_data else None)

    logical_height = my_mon.get("height", 1080) / my_mon.get("scale", 1.0)
    my_ws_id = my_mon.get("activeWorkspace", {}).get("id", 1)

    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
    classes = []
    running_info = []
    overlap = False
    seen = set()

    for c in clients:
        if not c.get("mapped") or c.get("hidden"): continue
        cls = str(c.get("class", ""))
        initial_cls = str(c.get("initialClass", ""))
        lookup_target = initial_cls if initial_cls else cls
        
        if cls:
            classes.append(cls.lower())
            if cls.lower() not in seen:
                seen.add(cls.lower())
                fpath, cmd_clean, disp_name, icon_name = resolve_desktop_meta(lookup_target)
                running_info.append({
                    "name": disp_name,
                    "wmClass": cls,
                    "process": cls,
                    "cmd": cmd_clean,
                    "iconName": icon_name,
                    "filePath": fpath
                })
        
        if c.get("workspace", {}).get("id") == my_ws_id:
            if c.get("fullscreen"):
                overlap = True
            else:
                y = c.get("at", [0,0])[1]
                h = c.get("size", [0,0])[1]
                if y + h > logical_height - 120:
                    overlap = True

    print(json.dumps({"clients": classes, "overlap": overlap, "running_info": running_info}))
except Exception:
    print(json.dumps({"clients": [], "overlap": False, "running_info": []}))
`
                    clientProcess.command = ["python3", "-c", pyScript, dockWindow.outputName]
                    clientProcess.running = true
                }
            }

            Item {
                id: rootContainer
                anchors.fill: parent

                Item {
                    id: bottomRevealArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 8
                    z: 1
                    
                    HoverHandler { id: bottomHoverHandler }
                }

                Rectangle {
                    id: sharedTooltip
                    height: 26
                    width: tooltipLabel.implicitWidth + 20
                    radius: 15
                    color: Qt.alpha(root.themeBackground, 0.95)
                    border.width: 1
                    border.color: Qt.alpha(root.themeBorder, 0.3)
                    z: 20
                    
                    anchors.bottom: dockContainer.top
                    anchors.bottomMargin: 6
                    
                    property real targetX: dockWindow.activeTooltipX - (width / 2)
                    x: Math.max(0, Math.min(targetX, rootContainer.width - width))
                    Behavior on x { NumberAnimation { duration: 180; easing.type: style.fadeEasing } }
                    
                    opacity: dockWindow.activeTooltipText !== "" ? 1.0 : 0.0
                    scale: dockWindow.activeTooltipText !== "" ? 1.0 : 1.0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250 
                            easing.type: Easing.OutQuart
                        }
                    }
                    Behavior on scale { 
                        NumberAnimation { 
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.bounceEasing
                            easing.overshoot: style.overshoot
                        } 
                    }
                    
                    Text {
                        id: tooltipLabel
                        anchors.centerIn: parent
                        text: dockWindow.activeTooltipText
                        color: root.themeText
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }

                Rectangle {
                    id: dockContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    transformOrigin: Item.Bottom
                    
                    anchors.bottomMargin: dockWindow.dockShouldBeVisible ? 8 : -(dockContainer.height + 20)
                    Behavior on anchors.bottomMargin { 
                        NumberAnimation { 
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.bounceEasing
                            easing.overshoot: style.overshoot
                        } 
                    }
                    
                    scale: dockWindow.dockShouldBeVisible ? 1.0 : 1.0
                    Behavior on scale { 
                        NumberAnimation { 
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.bounceEasing
                            easing.overshoot: style.overshoot
                        } 
                    }

                    width: masterDockLayout.implicitWidth + 28
                    height: 84
                    radius: root.themeRounding
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: Qt.alpha(root.themeBorder, 0.45)

                    opacity: dockWindow.dockShouldBeVisible ? 1.0 : 0.0
                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: root.animEnabled ? style.fadeDuration : 0
                            easing.type: style.fadeEasing 
                        } 
                    }

                    HoverHandler { id: dockHoverHandler }
                    
                    MouseArea {
                        id: dockBackgroundClickArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        z: 1 
                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                dockWindow.dockPinnedOpen = !dockWindow.dockPinnedOpen
                            }
                        }
                    }

                    RowLayout {
                        id: masterDockLayout
                        anchors.centerIn: parent
                        spacing: 12
                        z: 10

                        Item {
                            width: 52
                            height: 52

                            scale: launcherMouse.containsMouse ? 1.15 : 1.0
                            anchors.verticalCenterOffset: launcherMouse.containsMouse ? -4 : 0
                            
                            Behavior on scale { 
                                NumberAnimation { 
                                    duration: root.animEnabled ? style.animDuration : 0
                                    easing.type: style.bounceEasing
                                    easing.overshoot: style.overshoot
                                } 
                            }
                            Behavior on anchors.verticalCenterOffset { 
                                NumberAnimation { 
                                    duration: root.animEnabled ? style.animDuration : 0
                                    easing.type: style.bounceEasing
                                    easing.overshoot: style.overshoot
                                } 
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: "#27272a"
                                border.width: 1
                                border.color: Qt.alpha("#ffffff", 0.15)

                                Grid {
                                    anchors.centerIn: parent
                                    columns: 3
                                    rows: 3
                                    spacing: 5
                                    Repeater {
                                        model: 9
                                        delegate: Rectangle {
                                            width: 5; height: 5; radius: 2.5; color: root.themePrimary
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: launcherMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.exec("quickshell -c ~/.config/hypr/quickshell/drawer/")
                                }
                                onContainsMouseChanged: {
                                    if (containsMouse) {
                                        let pos = mapToItem(rootContainer, width/2, 0)
                                        dockWindow.activeTooltipX = pos.x
                                        dockWindow.activeTooltipText = "App Drawer"
                                    } else if (dockWindow.activeTooltipText === "App Drawer") {
                                        dockWindow.activeTooltipText = ""
                                    }
                                }
                                onPositionChanged: {
                                    if (containsMouse) {
                                        let pos = mapToItem(rootContainer, width/2, 0)
                                        dockWindow.activeTooltipX = pos.x
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 2
                            Layout.preferredHeight: 40
                            radius: 1
                            color: Qt.alpha(root.themeBorder, 0.25)
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                        }

                        ListView {
                            id: dockList
                            Layout.preferredWidth: pinnedAppsModel.count * 76 - 12
                            Layout.preferredHeight: 64
                            orientation: ListView.Horizontal
                            spacing: 12 
                            interactive: false 

                            add: Transition {
                                ParallelAnimation {
                                    NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: style.fadeDuration; easing.type: style.fadeEasing }
                                    NumberAnimation { 
                                        properties: "scale"
                                        from: 0; to: 1
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.bounceEasing
                                        easing.overshoot: style.overshoot 
                                    }
                                }
                            }
                            remove: Transition {
                                ParallelAnimation {
                                    NumberAnimation { properties: "opacity"; to: 0; duration: style.fadeDuration; easing.type: style.fadeEasing }
                                    NumberAnimation { properties: "scale"; to: 0; duration: style.fadeDuration; easing.type: style.fadeEasing }
                                }
                            }
                            displaced: Transition {
                                NumberAnimation { 
                                    properties: "x,y"
                                    duration: root.animEnabled ? style.animDuration : 0
                                    easing.type: style.bounceEasing
                                    easing.overshoot: style.overshoot 
                                }
                            }

                            model: DelegateModel {
                                id: visualModel
                                model: pinnedAppsModel
                                
                                delegate: DropArea {
                                    id: delegateRoot
                                    width: 64
                                    height: 64
                                    keys: ["app"]
                                    property int visualIndex: DelegateModel.itemsIndex

                                    onEntered: (drag) => {
                                        let from = drag.source.visualIndex
                                        let to = delegateRoot.visualIndex
                                        if (from !== to) visualModel.items.move(from, to)
                                    }

                                    Item {
                                        id: iconContainer
                                        width: 64
                                        height: 64
                                        
                                        Drag.active: itemMouse.dragActive
                                        Drag.source: delegateRoot
                                        Drag.hotSpot.x: 32
                                        Drag.hotSpot.y: 32
                                        Drag.keys: ["app"]

                                        property int instanceCount: {
                                            let count = 0
                                            let target = model.wmClass.toLowerCase()
                                            for (let i = 0; i < dockWindow.runningClients.length; i++) {
                                                if (dockWindow.runningClients[i].includes(target)) count++
                                            }
                                            return count
                                        }

                                        scale: itemMouse.containsMouse && !Drag.active ? 1.15 : (Drag.active ? 1.05 : 1.0)
                                        anchors.verticalCenterOffset: itemMouse.containsMouse && !Drag.active ? -4 : 0
                                        
                                        Behavior on scale { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.bounceEasing
                                                easing.overshoot: style.overshoot 
                                            } 
                                        }
                                        Behavior on anchors.verticalCenterOffset { 
                                            NumberAnimation { 
                                                duration: root.animEnabled ? style.animDuration : 0
                                                easing.type: style.bounceEasing
                                                easing.overshoot: style.overshoot 
                                            } 
                                        }

                                        states: [
                                            State {
                                                when: iconContainer.Drag.active
                                                ParentChange { target: iconContainer; parent: dockContainer }
                                                PropertyChanges { target: iconContainer; opacity: 0.85 }
                                            }
                                        ]

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 16
                                            color: "transparent"

                                            ToolButton {
                                                anchors.centerIn: parent
                                                visible: !model.iconName.startsWith("/")
                                                icon.name: !model.iconName.startsWith("/") ? model.iconName : ""
                                                icon.width: 52
                                                icon.height: 52
                                                icon.color: "transparent"
                                                background: Item {}
                                                hoverEnabled: false
                                                down: false
                                                padding: 0
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                visible: model.iconName.startsWith("/")
                                                source: model.iconName.startsWith("/") ? "file://" + model.iconName : ""
                                                sourceSize: Qt.size(52, 52)
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 4
                                                spacing: 4
                                                visible: iconContainer.instanceCount > 0
                                                Repeater {
                                                    model: Math.min(iconContainer.instanceCount, 3)
                                                    Rectangle { width: 5; height: 5; radius: 2.5; color: root.themePrimary }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: itemMouse
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        
                                        property bool dragActive: false

                                        drag.target: dragActive ? iconContainer : null
                                        drag.axis: Drag.XAxis
                                        
                                        onPressAndHold: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                itemMouse.dragActive = true
                                            }
                                        }

                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (!itemMouse.dragActive) {
                                                    dockWindow.launchApp({
                                                        name: model.name,
                                                        iconName: model.iconName,
                                                        cmd: model.cmd,
                                                        wmClass: model.wmClass,
                                                        process: model.process,
                                                        filePath: model.filePath || ""
                                                    })
                                                }
                                            }
                                        }

                                        onDoubleClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.togglePinApp({
                                                    name: model.name,
                                                    iconName: model.iconName,
                                                    cmd: model.cmd,
                                                    wmClass: model.wmClass,
                                                    process: model.process,
                                                    filePath: model.filePath || ""
                                                })
                                            }
                                        }
                                        
                                        onReleased: {
                                            if (itemMouse.dragActive) {
                                                iconContainer.Drag.drop()
                                                persistTimer.restart()
                                                itemMouse.dragActive = false
                                            }
                                        }
                                        
                                        onContainsMouseChanged: {
                                            if (containsMouse && !dragActive) {
                                                let pos = mapToItem(rootContainer, width/2, 0)
                                                dockWindow.activeTooltipX = pos.x
                                                dockWindow.activeTooltipText = model.name
                                            } else if (dockWindow.activeTooltipText === model.name) {
                                                dockWindow.activeTooltipText = ""
                                            }
                                        }
                                        
                                        onDragActiveChanged: {
                                            if (dragActive && dockWindow.activeTooltipText === model.name) {
                                                dockWindow.activeTooltipText = ""
                                            } else if (!dragActive && containsMouse) {
                                                let pos = mapToItem(rootContainer, width/2, 0)
                                                dockWindow.activeTooltipX = pos.x
                                                dockWindow.activeTooltipText = model.name
                                            }
                                        }

                                        onPositionChanged: {
                                            if (containsMouse && !dragActive) {
                                                let pos = mapToItem(rootContainer, width/2, 0)
                                                dockWindow.activeTooltipX = pos.x
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 2
                            Layout.preferredHeight: 40
                            radius: 1
                            color: Qt.alpha(root.themeBorder, 0.25)
                            visible: dockWindow.unpinnedApps.length > 0
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                        }

                        ListView {
                            id: unpinnedList
                            Layout.preferredWidth: Math.min(dockWindow.unpinnedApps.length * 76 - 12, 400)
                            Layout.preferredHeight: 64
                            orientation: ListView.Horizontal
                            spacing: 12
                            visible: dockWindow.unpinnedApps.length > 0
                            interactive: dockWindow.unpinnedApps.length > 5 
                            clip: true
                            
                            model: dockWindow.unpinnedApps
                            
                            delegate: Item {
                                width: 64
                                height: 64
                                
                                scale: unpinnedMouse.containsMouse ? 1.15 : 1.0
                                anchors.verticalCenterOffset: unpinnedMouse.containsMouse ? -4 : 0
                                
                                Behavior on scale { 
                                    NumberAnimation { 
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.bounceEasing
                                        easing.overshoot: style.overshoot 
                                    } 
                                }
                                Behavior on anchors.verticalCenterOffset { 
                                    NumberAnimation { 
                                        duration: root.animEnabled ? style.animDuration : 0
                                        easing.type: style.bounceEasing
                                        easing.overshoot: style.overshoot 
                                    } 
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 16
                                    color: "transparent"

                                    ToolButton {
                                        anchors.centerIn: parent
                                        visible: !modelData.iconName.startsWith("/")
                                        icon.name: !modelData.iconName.startsWith("/") ? modelData.iconName : ""
                                        icon.width: 52
                                        icon.height: 52
                                        icon.color: "transparent"
                                        background: Item {}
                                        hoverEnabled: false
                                        down: false
                                        padding: 0
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        visible: modelData.iconName.startsWith("/")
                                        source: modelData.iconName.startsWith("/") ? "file://" + modelData.iconName : ""
                                        sourceSize: Qt.size(52, 52)
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4 
                                        width: 5; height: 5; radius: 2.5
                                        color: root.themePrimary
                                    }
                                }

                                MouseArea {
                                    id: unpinnedMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            dockWindow.launchApp({
                                                name: modelData.name,
                                                iconName: modelData.iconName,
                                                cmd: modelData.cmd,
                                                wmClass: modelData.wmClass,
                                                process: modelData.process,
                                                filePath: modelData.filePath || ""
                                            })
                                        }
                                    }

                                    onDoubleClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            root.togglePinApp({
                                                name: modelData.name,
                                                iconName: modelData.iconName,
                                                cmd: modelData.cmd,
                                                wmClass: modelData.wmClass,
                                                process: modelData.process,
                                                filePath: modelData.filePath || ""
                                            })
                                        }
                                    }
                                    
                                    onContainsMouseChanged: {
                                        if (containsMouse) {
                                            let pos = mapToItem(rootContainer, width/2, 0)
                                            dockWindow.activeTooltipX = pos.x
                                            dockWindow.activeTooltipText = modelData.name
                                        } else if (dockWindow.activeTooltipText === modelData.name) {
                                            dockWindow.activeTooltipText = ""
                                        }
                                    }
                                    
                                    onPositionChanged: {
                                        if (containsMouse) {
                                            let pos = mapToItem(rootContainer, width/2, 0)
                                            dockWindow.activeTooltipX = pos.x
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