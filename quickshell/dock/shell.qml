import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property color themeBorder: "#ffffff"
    property color themePrimary: "#ffffff"
    property color themeText: "#ffffff"
    property color themeTextMuted: "#D4D4D8"

    property int themeRounding: 22
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.25
    property bool animEnabled: true
    property int animDuration: 220

    property color themeBackground: "#141416"
    property color themeSurface: Qt.rgba(1.0, 1.0, 1.0, 0.08)

    QtObject {
        id: style
        property int animDuration: root.animDuration > 0 ? Math.min(root.animDuration, 240) : 200
        property int fadeDuration: 180
        property var smoothEasing: Easing.OutCubic
        property var fadeEasing: Easing.OutCubic
        property var bounceEasing: Easing.OutBack
        property real overshoot: 1.25
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    function escapeShell(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    Process { id: rootExecProcess }
    function exec(cmd) {
        rootExecProcess.running = false
        rootExecProcess.command = ["bash", "-c", "(" + cmd + ") >/dev/null 2>&1 & disown"]
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
                if (content !== "") {
                    let apps = JSON.parse(content)
                    if (apps && Array.isArray(apps) && apps.length > 0) {
                        pinnedAppsModel.clear()
                        for (let i = 0; i < apps.length; i++) {
                            pinnedAppsModel.append(apps[i])
                        }
                        return
                    }
                }
            } catch (e) {}

            if (pinnedAppsModel.count === 0) root.loadDefaultApps()
        }
        onLoadFailed: {
            if (pinnedAppsModel.count === 0) root.loadDefaultApps()
        }
    }

    Process { id: saveProcess }

    function loadDefaultApps() {
        pinnedAppsModel.clear()
        pinnedAppsModel.append({ name: "Terminal", iconName: "kitty", cmd: "kitty", wmClass: "kitty", process: "kitty", filePath: "" })
        pinnedAppsModel.append({ name: "Files", iconName: "org.gnome.Nautilus", cmd: "nautilus", wmClass: "org.gnome.nautilus", process: "nautilus", filePath: "" })
        pinnedAppsModel.append({ name: "Calculator", iconName: "org.gnome.Calculator", cmd: "gnome-calculator", wmClass: "org.gnome.calculator", process: "gnome-calculator", filePath: "" })
        pinnedAppsModel.append({ name: "Disks", iconName: "org.gnome.DiskUtility", cmd: "gnome-disks", wmClass: "org.gnome.diskutility", process: "gnome-disks", filePath: "" })
        root.savePinnedApps()
    }

    function savePinnedApps() {
        let apps = []
        for (let i = 0; i < pinnedAppsModel.count; i++) {
            let item = pinnedAppsModel.get(i)
            apps.push({
                name: item.name,
                iconName: item.iconName,
                cmd: item.cmd,
                wmClass: item.wmClass,
                process: item.process,
                filePath: item.filePath || ""
            })
        }
        let jsonStr = JSON.stringify(apps)

        saveProcess.running = false
        saveProcess.command = [
            "python3", "-c",
            "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])",
            root.savedAppsFilePath,
            jsonStr
        ]
        saveProcess.running = true
    }

    function isAppPinned(app) {
        if (!app) return false
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
        if (!app) return
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
        id: generalFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/general.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let rMatch = content.match(/rounding\s*=\s*(\d+)/)
                if (rMatch && rMatch[1]) root.themeRounding = Math.min(Math.max(parseInt(rMatch[1]) + 4, 18), 28)
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

    Timer {
        id: bootTimer
        interval: 80
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

            implicitWidth: Math.max(dockContainer.width + 96, 320)

            property int currentHitboxHeight: 165
            implicitHeight: currentHitboxHeight
            color: "transparent"

            mask: Region {
                item: dockWindow.dockShouldBeVisible ? activeHoverMask : bottomRevealArea
            }

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
                interval: 650
                repeat: false
                onTriggered: {
                    if (!dockWindow.anyHovered) {
                        dockWindow.dockLatchedOpen = false
                    }
                }
            }

            property bool dockShouldBeVisible: dockPinnedOpen || dockLatchedOpen || !isOverlapped
            property var runningClients: []
            property string focusedClass: ""
            property var unpinnedApps: []

            property bool isDraggingAny: false
            property real lastHoveredX: -1

            readonly property int totalSlotCount: 1 + pinnedAppsModel.count + dockWindow.unpinnedApps.length
            readonly property real baseSlotWidth: 56
            readonly property real maxSlotZoomWidth: 74
            readonly property real baseDockHeight: 74
            readonly property real maxDockZoomHeight: 84

            property real targetZoomIntensity: (dockWindow.dockHovered && !dockWindow.isDraggingAny) ? 1.0 : 0.0
            property real activeZoomIntensity: targetZoomIntensity

            Behavior on activeZoomIntensity {
                NumberAnimation {
                    duration: root.animEnabled ? 150 : 0
                    easing.type: style.smoothEasing
                }
            }

            function getStableItemCenterX(type, index) {
                let baseW = dockWindow.baseSlotWidth
                let pCount = pinnedAppsModel.count
                let uCount = dockWindow.unpinnedApps.length

                let layoutW = baseW
                if (pCount > 0 || uCount > 0) layoutW += 13.5
                if (pCount > 0) layoutW += 8 + pCount * baseW + Math.max(0, pCount - 1) * 6
                if (pCount > 0 && uCount > 0) layoutW += 13.5
                if (uCount > 0) layoutW += 8 + uCount * baseW + Math.max(0, uCount - 1) * 6

                let dockW = layoutW + 26
                let startX = (rootContainer.width - dockW) / 2 + 13

                let cx = startX
                if (type === "launcher") return cx + baseW / 2

                cx += baseW + 8
                if (pCount > 0 || uCount > 0) {
                    cx += 5.5
                    if (type === "pinned") return cx + 8 + index * (baseW + 6) + baseW / 2
                    if (pCount > 0) cx += 8 + pCount * baseW + Math.max(0, pCount - 1) * 6
                }

                if (pCount > 0 && uCount > 0) cx += 13.5

                if (type === "unpinned") return cx + 8 + index * (baseW + 6) + baseW / 2

                return 0
            }

            function getZoomFactorForCenter(itemCenterX) {
                if (!root.animEnabled || dockWindow.isDraggingAny || dockWindow.activeZoomIntensity === 0) return 0.0
                let dist = Math.abs(itemCenterX - dockWindow.lastHoveredX)
                let radius = 148.0
                if (dist >= radius) return 0.0
                let norm = dist / radius
                return 0.5 * (1.0 + Math.cos(Math.PI * norm)) * dockWindow.activeZoomIntensity
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

                    if [ -n "$fp" ] && [ -f "$fp" ]; then
                        gio launch "$fp" >/dev/null 2>&1 & disown
                        exit 0
                    fi

                    for target in "$w" "$c" "$(basename "$fp" 2>/dev/null)"; do
                        if [ -n "$target" ]; then
                            clean="\${target%.desktop}"
                            if gtk-launch "$clean" >/dev/null 2>&1; then
                                exit 0
                            fi
                        fi
                    done

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

                    if [ -n "$c" ] && command -v "$c" >/dev/null 2>&1; then
                        "$c" >/dev/null 2>&1 & disown
                        exit 0
                    fi

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
                            dockWindow.focusedClass = (data.focused || "").toLowerCase()
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

                            if (data.pinned_resolved && Array.isArray(data.pinned_resolved)) {
                                for (let i = 0; i < data.pinned_resolved.length; i++) {
                                    let pRes = data.pinned_resolved[i]
                                    if (i < pinnedAppsModel.count) {
                                        let item = pinnedAppsModel.get(i)
                                        if (pRes.iconName && pRes.iconName.startsWith("/") && item.iconName !== pRes.iconName) {
                                            pinnedAppsModel.setProperty(i, "iconName", pRes.iconName)
                                        }
                                    }
                                }
                            }
                        } catch (e) {}
                    }
                }
            }

            Timer {
                id: clientTimer
                interval: 400
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (clientProcess.running) return
                    let pyScript = `
import json, subprocess, sys, os, re

CACHE_PATH = "/tmp/qs_dock_meta_cache.json"

def load_cache():
    if os.path.exists(CACHE_PATH):
        try:
            with open(CACHE_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"icons": {}, "desktop": {}, "entries": None}

def save_cache(c):
    try:
        data = {"icons": c.get("icons", {}), "desktop": c.get("desktop", {})}
        with open(CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except Exception:
        pass

CACHE = load_cache()

def get_desktop_entries():
    if CACHE.get("entries") is not None:
        return CACHE["entries"]
    dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications",
        "/usr/local/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
    ]
    entries = []
    for d in dirs:
        if not os.path.isdir(d): continue
        try:
            for f in os.listdir(d):
                if f.endswith(".desktop"):
                    p = os.path.join(d, f)
                    try:
                        with open(p, "r", encoding="utf-8", errors="ignore") as file_obj:
                            lines = file_obj.read().splitlines()
                            exec_l = next((l.split("=", 1)[1].strip() for l in lines if l.startswith("Exec=")), "")
                            name_l = next((l.split("=", 1)[1].strip() for l in lines if l.startswith("Name=")), "")
                            icon_l = next((l.split("=", 1)[1].strip() for l in lines if l.startswith("Icon=")), "")
                            wm_l = next((l.split("=", 1)[1].strip() for l in lines if l.startswith("StartupWMClass=")), "")
                            clean_cmd = re.sub(r'%[fFuUikKc]', '', exec_l).strip()
                            entries.append({
                                "stem": f[:-8].lower(),
                                "path": p,
                                "cmd": clean_cmd,
                                "name": name_l,
                                "icon": icon_l,
                                "wm": wm_l
                            })
                    except Exception:
                        pass
        except Exception:
            pass
    CACHE["entries"] = entries
    return entries

def resolve_desktop_meta(cls):
    if not cls: return "", cls, cls.capitalize(), cls
    cls_clean = cls.strip().lower()
    if cls_clean in CACHE["desktop"]:
        d = CACHE["desktop"][cls_clean]
        return d[0], d[1], d[2], d[3]

    entries = get_desktop_entries()
    stem = cls_clean.split(".")[-1]
    res = ("", cls, stem.capitalize(), cls)

    for e in entries:
        if e["wm"] and e["wm"].lower() == cls_clean:
            res = (e["path"], e["cmd"] or cls, e["name"] or cls, e["icon"] or cls)
            break
    else:
        for e in entries:
            if e["stem"] == cls_clean or e["stem"] == stem:
                res = (e["path"], e["cmd"] or cls, e["name"] or cls, e["icon"] or cls)
                break
        else:
            for e in entries:
                cmd_base = os.path.basename(e["cmd"].split()[0]).lower() if e["cmd"] else ""
                if cmd_base and (cmd_base == cls_clean or cmd_base == stem):
                    res = (e["path"], e["cmd"] or cls, e["name"] or cls, e["icon"] or cls)
                    break
            else:
                for e in entries:
                    if cls_clean in e["stem"] or stem in e["stem"] or e["stem"] in cls_clean:
                        res = (e["path"], e["cmd"] or cls, e["name"] or cls, e["icon"] or cls)
                        break

    CACHE["desktop"][cls_clean] = list(res)
    return res

def find_icon(icon_name, wm_class="", file_path=""):
    if not icon_name and not wm_class: return ""
    if icon_name and os.path.isabs(icon_name) and os.path.exists(icon_name): return icon_name

    cache_key = f"{icon_name}|{wm_class}"
    if cache_key in CACHE["icons"]:
        cached_val = CACHE["icons"][cache_key]
        if not cached_val.startswith("/") or os.path.exists(cached_val):
            return cached_val

    search_keys = []
    for item in [icon_name, wm_class]:
        if not item: continue
        search_keys.append(item)
        search_keys.append(item.lower())
        if "." in item:
            stem = item.split(".")[-1]
            search_keys.extend([stem, stem.lower(), "gnome-" + stem.lower(), "org.gnome." + stem])

    unique_keys = []
    seen_keys = set()
    for k in search_keys:
        if k and k not in seen_keys:
            seen_keys.add(k)
            unique_keys.append(k)

    home = os.path.expanduser("~")
    icon_roots = [
        os.path.join(home, ".local/share/icons"),
        os.path.join(home, ".icons"),
        "/usr/share/icons",
        "/var/lib/flatpak/exports/share/icons",
        os.path.expanduser("~/.local/share/flatpak/exports/share/icons")
    ]

    theme_dirs = []
    for r in icon_roots:
        if os.path.exists(r):
            try:
                for d in os.listdir(r):
                    full = os.path.join(r, d)
                    if os.path.isdir(full):
                        if "whitesur" in d.lower():
                            theme_dirs.insert(0, full)
                        else:
                            theme_dirs.append(full)
            except Exception:
                pass

    subdirs = [
        "apps/scalable", "apps/48", "apps/128", "apps/64", "apps/256", "apps/512",
        "scalable/apps", "48x48/apps", "64x64/apps", "128x128/apps", "256x256/apps",
        "apps/symbolic", "symbolic/apps", "categories/scalable", "places/scalable"
    ]
    extensions = [".svg", ".png", ".xpm"]

    for td in theme_dirs:
        for sub in subdirs:
            target_dir = os.path.join(td, sub)
            if os.path.exists(target_dir):
                for key in unique_keys:
                    for ext in extensions:
                        p = os.path.join(target_dir, key + ext)
                        if os.path.exists(p):
                            CACHE["icons"][cache_key] = p
                            return p

    pixmap_dirs = ["/usr/share/pixmaps", os.path.join(home, ".local/share/pixmaps")]
    for pd in pixmap_dirs:
        if os.path.exists(pd):
            for key in unique_keys:
                for ext in extensions:
                    p = os.path.join(pd, key + ext)
                    if os.path.exists(p):
                        CACHE["icons"][cache_key] = p
                        return p

    for r in icon_roots:
        if os.path.exists(r):
            for key in unique_keys:
                for ext in extensions:
                    for fallback_sub in ["hicolor/scalable/apps", "hicolor/48x48/apps", "hicolor/128x128/apps", "hicolor/256x256/apps", "pixmaps", "hicolor/apps/scalable"]:
                        p = os.path.join(r, fallback_sub, key + ext)
                        if os.path.exists(p):
                            CACHE["icons"][cache_key] = p
                            return p

    fallback = icon_name or wm_class
    CACHE["icons"][cache_key] = fallback
    return fallback

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
    focused_cls = ""
    seen = set()

    for c in clients:
        if not c.get("mapped") or c.get("hidden"): continue
        cls = str(c.get("class", ""))
        initial_cls = str(c.get("initialClass", ""))
        lookup_target = initial_cls if initial_cls else cls

        if c.get("focusHistoryID") == 0 and cls:
            focused_cls = cls.lower()

        if cls:
            classes.append(cls.lower())
            if cls.lower() not in seen:
                seen.add(cls.lower())
                fpath, cmd_clean, disp_name, raw_icon = resolve_desktop_meta(lookup_target)
                resolved_icon = find_icon(raw_icon, cls, fpath)
                running_info.append({
                    "name": disp_name,
                    "wmClass": cls,
                    "process": cls,
                    "cmd": cmd_clean,
                    "iconName": resolved_icon,
                    "filePath": fpath
                })

        if c.get("workspace", {}).get("id") == my_ws_id:
            if c.get("fullscreen"):
                overlap = True
            else:
                y = c.get("at", [0,0])[1]
                h = c.get("size", [0,0])[1]
                if y + h > logical_height - 110:
                    overlap = True

    pinned_file = os.path.expanduser("~/.config/quickshell/json/dock_pinned.json")
    resolved_pinned = []
    if os.path.exists(pinned_file):
        try:
            with open(pinned_file, "r", encoding="utf-8") as pf:
                p_data = json.load(pf)
                for item in p_data:
                    icon_orig = item.get("iconName", "")
                    wm_cls = item.get("wmClass", "")
                    fp = item.get("filePath", "")
                    resolved_icon = find_icon(icon_orig, wm_cls, fp)
                    item_copy = dict(item)
                    item_copy["iconName"] = resolved_icon
                    resolved_pinned.append(item_copy)
        except Exception:
            pass

    save_cache(CACHE)
    print(json.dumps({"clients": classes, "focused": focused_cls, "overlap": overlap, "running_info": running_info, "pinned_resolved": resolved_pinned}))
except Exception:
    print(json.dumps({"clients": [], "focused": "", "overlap": False, "running_info": [], "pinned_resolved": []}))
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

                Item {
                    id: activeHoverMask
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: dockContainer.width + 24
                    height: dockContainer.height + 34
                }

                Rectangle {
                    id: sharedTooltip
                    height: 28
                    width: tooltipLabel.implicitWidth + 22
                    radius: 9
                    color: Qt.alpha(root.themeBackground, 0.42)
                    border.width: 1
                    border.color: Qt.alpha(root.themePrimary, 0.45)
                    antialiasing: true
                    z: 30

                    anchors.bottom: dockContainer.top
                    anchors.bottomMargin: 16

                    property real targetX: dockWindow.activeTooltipX - (width / 2)
                    x: Math.max(8, Math.min(targetX, rootContainer.width - width - 8))
                    Behavior on x { NumberAnimation { duration: 130; easing.type: style.fadeEasing } }

                    visible: dockWindow.activeTooltipText !== "" && dockWindow.dockShouldBeVisible
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 130; easing.type: style.fadeEasing } }

                    Text {
                        id: tooltipLabel
                        anchors.centerIn: parent
                        text: dockWindow.activeTooltipText
                        color: root.themeText
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }
                }

                Rectangle {
                    id: dockContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    transformOrigin: Item.Bottom

                    anchors.bottomMargin: dockWindow.dockShouldBeVisible ? 10 : -(dockContainer.height + 28)
                    Behavior on anchors.bottomMargin {
                        NumberAnimation {
                            duration: root.animEnabled ? style.animDuration : 0
                            easing.type: style.smoothEasing
                        }
                    }

                    width: masterDockLayout.implicitWidth + 26 + (dockWindow.activeZoomIntensity * 8)
                    height: dockWindow.baseDockHeight + (dockWindow.maxDockZoomHeight - dockWindow.baseDockHeight) * dockWindow.activeZoomIntensity
                    radius: root.themeRounding + (dockWindow.activeZoomIntensity * 3)
                    color: Qt.alpha(root.themeBackground, root.themeBgAlpha)
                    border.width: root.themeBorderSize
                    border.color: dockWindow.dockPinnedOpen ? root.themePrimary : (dockWindow.activeZoomIntensity > 0.01 ? Qt.alpha(root.themePrimary, 0.62) : Qt.alpha(root.themePrimary, 0.40))
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: style.fadeDuration
                            easing.type: style.fadeEasing
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: style.fadeDuration
                            easing.type: style.fadeEasing
                        }
                    }

                    opacity: dockWindow.dockShouldBeVisible ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animEnabled ? style.fadeDuration : 0
                            easing.type: style.fadeEasing
                        }
                    }

                    HoverHandler {
                        id: dockHoverHandler
                        onPointChanged: {
                            if (hovered && !dockWindow.isDraggingAny) {
                                let pos = dockContainer.mapToItem(rootContainer, point.position.x, point.position.y)
                                dockWindow.lastHoveredX = pos.x
                            }
                        }
                    }

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
                        spacing: 8
                        z: 10

                        Item {
                            id: launcherSlot
                            
                            property real stableCenterX: dockWindow.getStableItemCenterX("launcher", 0)

                            Layout.preferredWidth: dockWindow.baseSlotWidth
                            Layout.preferredHeight: 66
                            z: launcherMouse.containsMouse ? 10 : 1

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                width: 48
                                height: 48
                                scale: launcherMouse.pressed ? 0.92 : (launcherMouse.containsMouse ? 1.05 : 1.0)
                                transformOrigin: Item.Bottom

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: style.smoothEasing
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: launcherMouse.containsMouse
                                           ? Qt.rgba(1.0, 1.0, 1.0, 0.16)
                                           : root.themeSurface
                                    border.width: 1
                                    border.color: launcherMouse.containsMouse
                                                  ? root.themePrimary
                                                  : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: style.fadeDuration
                                            easing.type: style.fadeEasing
                                        }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: style.fadeDuration
                                            easing.type: style.fadeEasing
                                        }
                                    }

                                    Grid {
                                        anchors.centerIn: parent
                                        columns: 3
                                        rows: 3
                                        spacing: 4
                                        Repeater {
                                            model: 9
                                            delegate: Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: root.themePrimary
                                                antialiasing: true
                                            }
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
                                        dockWindow.activeTooltipX = launcherSlot.stableCenterX
                                        dockWindow.activeTooltipText = "App Drawer"
                                    } else if (dockWindow.activeTooltipText === "App Drawer") {
                                        dockWindow.activeTooltipText = ""
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1.5
                            Layout.preferredHeight: 36 + (dockWindow.activeZoomIntensity * 6)
                            radius: 1
                            color: Qt.alpha(root.themePrimary, 0.28)
                            visible: pinnedAppsModel.count > 0 || dockWindow.unpinnedApps.length > 0
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                            antialiasing: true
                        }

                        Row {
                            id: pinnedRowContainer
                            spacing: 6
                            visible: pinnedAppsModel.count > 0

                            Repeater {
                                id: visualModel
                                model: pinnedAppsModel

                                delegate: DropArea {
                                    id: delegateRoot
                                    keys: ["app"]
                                    property int visualIndex: index

                                    property real stableCenterX: dockWindow.getStableItemCenterX("pinned", visualIndex)
                                    property real zoomFactor: dockWindow.getZoomFactorForCenter(stableCenterX)
                                    property real targetWidth: dockWindow.baseSlotWidth + (dockWindow.maxSlotZoomWidth - dockWindow.baseSlotWidth) * zoomFactor

                                    width: targetWidth
                                    height: 66
                                    z: itemMouse.dragActive ? 50 : (zoomFactor > 0.1 ? Math.round(10 + zoomFactor * 20) : 1)

                                    onEntered: (drag) => {
                                        let from = drag.source.visualIndex
                                        let to = delegateRoot.visualIndex
                                        if (from !== to) {
                                            pinnedAppsModel.move(from, to, 1)
                                        }
                                    }

                                    Item {
                                        id: iconContainer
                                        width: delegateRoot.width
                                        height: 66

                                        Drag.active: itemMouse.dragActive
                                        Drag.source: delegateRoot
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2
                                        Drag.keys: ["app"]

                                        property int instanceCount: {
                                            let count = 0
                                            let target = (model.wmClass || "").toLowerCase()
                                            if (!target) return 0
                                            for (let i = 0; i < dockWindow.runningClients.length; i++) {
                                                let c = dockWindow.runningClients[i]
                                                if (c === target || c.includes(target) || target.includes(c)) count++
                                            }
                                            return count
                                        }

                                        property bool isAppFocused: {
                                            let target = (model.wmClass || "").toLowerCase()
                                            let foc = dockWindow.focusedClass
                                            if (!target || !foc) return false
                                            return foc === target || foc.includes(target) || target.includes(foc)
                                        }

                                        states: [
                                            State {
                                                when: iconContainer.Drag.active
                                                ParentChange { target: iconContainer; parent: dockContainer }
                                                PropertyChanges { target: iconContainer; opacity: 0.90 }
                                            }
                                        ]

                                        Item {
                                            id: glyphBox
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: iconContainer.Drag.active ? 10 : (9 + delegateRoot.zoomFactor * 12)
                                            width: 48
                                            height: 48
                                            scale: itemMouse.pressed && !iconContainer.Drag.active
                                                   ? 0.92
                                                   : (iconContainer.Drag.active ? 1.12 : (1.0 + delegateRoot.zoomFactor * 0.34))
                                            transformOrigin: Item.Bottom

                                            ToolButton {
                                                anchors.centerIn: parent
                                                visible: !model.iconName.startsWith("/")
                                                icon.name: !model.iconName.startsWith("/") ? model.iconName : ""
                                                icon.width: 48
                                                icon.height: 48
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
                                                sourceSize: Qt.size(68, 68)
                                                width: 48
                                                height: 48
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                antialiasing: true
                                                asynchronous: true
                                            }
                                        }

                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 2
                                            spacing: 3
                                            visible: iconContainer.instanceCount > 0

                                            Repeater {
                                                model: iconContainer.isAppFocused ? 1 : Math.min(iconContainer.instanceCount, 3)
                                                Rectangle {
                                                    property real focusAnimState: iconContainer.isAppFocused ? 1.0 : 0.0
                                                    Behavior on focusAnimState { NumberAnimation { duration: 150 } }
                                                    width: 5 + (focusAnimState * (9 + delegateRoot.zoomFactor * 4))
                                                    height: 4
                                                    radius: 2
                                                    color: root.themePrimary
                                                    antialiasing: true
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
                                                dockWindow.isDraggingAny = true
                                            }
                                        }

                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton && !itemMouse.dragActive) {
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
                                                root.savePinnedApps()
                                                itemMouse.dragActive = false
                                                dockWindow.isDraggingAny = false
                                            }
                                        }

                                        onContainsMouseChanged: {
                                            if (containsMouse && !dragActive) {
                                                dockWindow.activeTooltipX = delegateRoot.stableCenterX
                                                dockWindow.activeTooltipText = model.name
                                            } else if (dockWindow.activeTooltipText === model.name) {
                                                dockWindow.activeTooltipText = ""
                                            }
                                        }

                                        onDragActiveChanged: {
                                            if (dragActive && dockWindow.activeTooltipText === model.name) {
                                                dockWindow.activeTooltipText = ""
                                            } else if (!dragActive && containsMouse) {
                                                dockWindow.activeTooltipX = delegateRoot.stableCenterX
                                                dockWindow.activeTooltipText = model.name
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1.5
                            Layout.preferredHeight: 36 + (dockWindow.activeZoomIntensity * 6)
                            radius: 1
                            color: Qt.alpha(root.themePrimary, 0.28)
                            visible: dockWindow.unpinnedApps.length > 0 && pinnedAppsModel.count > 0
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                            antialiasing: true
                        }

                        Row {
                            id: unpinnedRowContainer
                            spacing: 6
                            visible: dockWindow.unpinnedApps.length > 0

                            Repeater {
                                model: dockWindow.unpinnedApps

                                delegate: Item {
                                    id: unpinnedDelegate
                                    property real stableCenterX: dockWindow.getStableItemCenterX("unpinned", index)
                                    property real zoomFactor: dockWindow.getZoomFactorForCenter(stableCenterX)
                                    property real targetWidth: dockWindow.baseSlotWidth + (dockWindow.maxSlotZoomWidth - dockWindow.baseSlotWidth) * zoomFactor

                                    width: targetWidth
                                    height: 66
                                    z: zoomFactor > 0.1 ? Math.round(10 + zoomFactor * 20) : 1

                                    property bool isAppFocused: {
                                        let target = (modelData.wmClass || "").toLowerCase()
                                        let foc = dockWindow.focusedClass
                                        if (!target || !foc) return false
                                        return foc === target || foc.includes(target) || target.includes(foc)
                                    }

                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 9 + (unpinnedDelegate.zoomFactor * 12)
                                        width: 48
                                        height: 48
                                        scale: unpinnedMouse.pressed ? 0.92 : (1.0 + unpinnedDelegate.zoomFactor * 0.34)
                                        transformOrigin: Item.Bottom

                                        ToolButton {
                                            anchors.centerIn: parent
                                            visible: !modelData.iconName.startsWith("/")
                                            icon.name: !modelData.iconName.startsWith("/") ? modelData.iconName : ""
                                            icon.width: 48
                                            icon.height: 48
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
                                            sourceSize: Qt.size(68, 68)
                                            width: 48
                                            height: 48
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            antialiasing: true
                                            asynchronous: true
                                        }
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2
                                        property real focusAnimState: unpinnedDelegate.isAppFocused ? 1.0 : 0.0
                                        Behavior on focusAnimState { NumberAnimation { duration: 150 } }
                                        width: 5 + (focusAnimState * (9 + unpinnedDelegate.zoomFactor * 4))
                                        height: 4
                                        radius: 2
                                        color: root.themePrimary
                                        antialiasing: true
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
                                                dockWindow.activeTooltipX = unpinnedDelegate.stableCenterX
                                                dockWindow.activeTooltipText = modelData.name
                                            } else if (dockWindow.activeTooltipText === modelData.name) {
                                                dockWindow.activeTooltipText = ""
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