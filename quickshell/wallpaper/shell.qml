import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel

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
    property real themeBgAlpha: 0.7
    property bool animEnabled: true
    property int animDuration: 380
    
    property color themeBackground: Qt.rgba(0.07, 0.07, 0.08, 0.7) 
    property color themeCardBg: Qt.rgba(0.09, 0.09, 0.12, 0.85)
    property color themeBorder: "#d6bbfb"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#d6bbfb"        

    QtObject {
        id: animStyle
        property int animDuration: root.animDuration > 0 ? root.animDuration : 380
        property int fadeDuration: 280
        property var bounceEasing: Easing.OutBack
        property var fadeEasing: Easing.OutCubic
        property real overshoot: 1.4
    }

    property string currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string activeWallpaperPath: ""
    property string selectedEngine: "awww"

    property int cacheEpoch: 0

    readonly property string cachePythonScript: `
import os, sys, hashlib, subprocess
from concurrent.futures import ThreadPoolExecutor

CACHE_DIR = os.path.expanduser("~/.cache/qs_wallpaper_thumbs")
os.makedirs(CACHE_DIR, exist_ok=True)

target_dir = sys.argv[1] if len(sys.argv) > 1 else ""
if not target_dir or not os.path.isdir(target_dir):
    sys.exit(0)

has_pil = False
try:
    from PIL import Image
    has_pil = True
except ImportError:
    pass

EXTS = ('.png', '.jpg', '.jpeg', '.webp', '.gif')

def make_thumb(filepath):
    try:
        if not os.path.isfile(filepath):
            return
        h = hashlib.md5(filepath.encode('utf-8')).hexdigest()
        out_file = os.path.join(CACHE_DIR, f"{h}.jpg")
        
        mtime = os.path.getmtime(filepath)
        if os.path.exists(out_file) and os.path.getmtime(out_file) >= mtime:
            return
            
        if has_pil:
            with Image.open(filepath) as img:
                img.thumbnail((360, 240))
                if img.mode != "RGB":
                    img = img.convert("RGB")
                img.save(out_file, "JPEG", quality=75)
        else:
            cmd = ["ffmpeg", "-y", "-loglevel", "quiet", "-i", filepath, "-vf", "scale=360:-1", "-vframes", "1", "-q:v", "5", out_file]
            r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if r.returncode != 0:
                subprocess.run(["magick", filepath, "-resize", "360x240^", "-gravity", "center", "-extent", "360x240", "-quality", "75", out_file], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

files = []
try:
    for entry in os.scandir(target_dir):
        if entry.is_file() and entry.name.lower().endswith(EXTS):
            files.append(entry.path)
except Exception:
    pass

if files:
    with ThreadPoolExecutor(max_workers=8) as executor:
        list(executor.map(make_thumb, files))
`

    Process {
        id: cacheGeneratorProcess
        property string folderPath: ""
        running: false
        command: ["python3", "-c", root.cachePythonScript, cacheGeneratorProcess.folderPath]
        onExited: {
            root.cacheEpoch++
        }
    }

    function triggerCacheGeneration() {
        let path = String(root.currentFolder).replace("file://", "")
        if (path.length > 0 && path !== "/") {
            if (cacheGeneratorProcess.running) {
                cacheGeneratorProcess.running = false
            }
            cacheGeneratorProcess.folderPath = path
            cacheGeneratorProcess.running = true
        }
    }

    onCurrentFolderChanged: {
        root.triggerCacheGeneration()
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
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    Process {
        id: initFolderCheck
        command: [
            "sh", "-c",
            "if [ -d \"$HOME/Pictures/Wallpapers\" ]; then echo \"$HOME/Pictures/Wallpapers\"; " +
            "elif [ -d \"$HOME/Pictures/wallpapers\" ]; then echo \"$HOME/Pictures/wallpapers\"; " +
            "elif [ -d \"$HOME/wallpapers\" ]; then echo \"$HOME/wallpapers\"; " +
            "else echo \"$HOME/Pictures\"; fi"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let dir = this.text.trim();
                if (dir.length > 0 && dir.startsWith("/")) {
                    root.currentFolder = "file://" + dir;
                    root.triggerCacheGeneration();
                }
            }
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
        root.triggerCacheGeneration()
    }

    Process {
        id: applyWallpaper
        property string imagePath: ""
        running: false
        
        command: [
            "sh",
            "-c",
            "ENGINE=\"$1\"\n" +
            "IMG=\"$2\"\n" +
            "ANIM=\"$3\"\n" +
            "if [ \"$ENGINE\" = \"awww\" ]; then\n" +
            "    if awww -h 2>&1 | grep -q -- '--transition-type'; then\n" +
            "        awww img \"$IMG\" --transition-type \"$ANIM\" --transition-pos 0.5,0.5 --transition-duration 0.5 2>/dev/null || " +
            "        awww -i \"$IMG\" --transition-type \"$ANIM\" 2>/dev/null || " +
            "        awww \"$IMG\" --transition-type \"$ANIM\"\n" +
            "    elif awww -h 2>&1 | grep -q -- '-i'; then\n" +
            "        awww -i \"$IMG\"\n" +
            "    elif awww -h 2>&1 | grep -q 'load'; then\n" +
            "        awww load \"$IMG\"\n" +
            "    else\n" +
            "        awww img \"$IMG\" --transition-type \"$ANIM\" 2>/dev/null || awww \"$IMG\" 2>/dev/null\n" +
            "    fi\n" +
            "fi\n" +
            "if command -v matugen >/dev/null 2>&1; then\n" +
            "    mkdir -p \"$HOME/.config/qt5ct/colors\"\n" +
            "    mkdir -p \"$HOME/.config/qt6ct/colors\"\n" +
            "    mkdir -p \"$HOME/.config/gtk-3.0\"\n" +
            "    mkdir -p \"$HOME/.config/gtk-4.0\"\n" +
            "    mkdir -p \"$HOME/.config/hypr/configs\"\n" +
            "    matugen image \"$IMG\" --source-color-index 0\n" +
            "    cp -a \"$HOME/.config/qt5ct/colors/.\" \"$HOME/.config/qt6ct/colors/\" 2>/dev/null || true\n" +
            "    hyprctl reload 2>/dev/null || true\n" +
            "fi\n",
            "sh",
            root.selectedEngine,
            applyWallpaper.imagePath,
            "fade"
        ]
        
        onExited: running = false
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
            WlrLayershell.namespace: "qs-wallselect"
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
                width: Math.min(1150, parent.width - 40)
                height: Math.min(760, parent.height - 80)
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.40)
                color: root.themeBackground

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
                        spacing: 10

                        Text {
                            text: "" 
                            font.pixelSize: 24
                            color: root.themePrimary
                        }

                        Text {
                            text: "Wallpaper Selector"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: root.themeText
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(root.themeBorder, 0.20)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            visible: folderModel.count === 0
                            text: "No images found in:\n" + String(root.currentFolder).replace("file://", "")
                            horizontalAlignment: Text.AlignHCenter
                            color: root.themeTextMuted
                            font.pixelSize: 14
                            lineHeight: 1.4
                        }

                        GridView {
                            id: imageGrid
                            anchors.fill: parent
                            clip: true
                            cacheBuffer: 600
                            
                            readonly property int columns: Math.max(1, Math.floor(width / 230))
                            cellWidth: width > 0 ? Math.floor(width / columns) : 230
                            cellHeight: Math.floor(cellWidth * 0.65)
                            
                            add: Transition {
                                ParallelAnimation {
                                    NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing }
                                    NumberAnimation { 
                                        properties: "scale"
                                        from: 0.88; to: 1.0
                                        duration: root.animEnabled ? animStyle.animDuration : 0
                                        easing.type: animStyle.bounceEasing
                                        easing.overshoot: animStyle.overshoot 
                                    }
                                }
                            }

                            displaced: Transition {
                                NumberAnimation { 
                                    properties: "x,y"
                                    duration: root.animEnabled ? animStyle.animDuration : 0
                                    easing.type: animStyle.bounceEasing
                                    easing.overshoot: animStyle.overshoot 
                                }
                            }

                            model: FolderListModel {
                                id: folderModel
                                folder: root.currentFolder
                                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp"]
                                showDirs: false
                                caseSensitive: false
                                sortField: FolderListModel.Time
                                sortReversed: true
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: imageGrid.moving || imageGrid.flicking
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Item {
                                id: cardDelegate
                                width: imageGrid.cellWidth
                                height: imageGrid.cellHeight

                                property string fullPath: model.filePath ? model.filePath : (model.fileUrl ? model.fileUrl.toString().replace("file://", "") : "")
                                property string displayName: model.fileName ? model.fileName : ""
                                property string thumbFile: Quickshell.env("HOME") + "/.cache/qs_wallpaper_thumbs/" + Qt.md5(fullPath) + ".jpg"

                                scale: itemMouse.containsMouse ? 1.04 : 1.0
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? animStyle.animDuration : 0
                                        easing.type: animStyle.bounceEasing
                                        easing.overshoot: animStyle.overshoot
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 2
                                    
                                    property bool isActive: root.activeWallpaperPath === fullPath
                                    border.color: isActive ? root.themePrimary : (itemMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.5) : "transparent")
                                    Behavior on border.color { ColorAnimation { duration: animStyle.fadeDuration } }
                                    
                                    clip: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰋩"
                                        font.pixelSize: 24
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        visible: imgItem.status !== Image.Ready
                                    }

                                    Image {
                                        id: imgItem
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize: Qt.size(280, 180)
                                        smooth: true

                                        property bool fallbackToOriginal: false

                                        source: fallbackToOriginal ? ("file://" + fullPath) : ("file://" + thumbFile)

                                        onStatusChanged: {
                                            if (status === Image.Error && !fallbackToOriginal) {
                                                fallbackToOriginal = true
                                            }
                                        }

                                        Connections {
                                            target: root
                                            function onCacheEpochChanged() {
                                                if (imgItem.fallbackToOriginal) {
                                                    imgItem.fallbackToOriginal = false
                                                }
                                            }
                                        }

                                        opacity: status === Image.Ready ? (itemMouse.containsMouse ? 0.85 : 1.0) : 0.0
                                        Behavior on opacity { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                    }
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 32
                                        color: Qt.rgba(0, 0, 0, 0.78)
                                        opacity: itemMouse.containsMouse ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: animStyle.fadeDuration; easing.type: animStyle.fadeEasing } }
                                        
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            text: displayName
                                            color: "#FFFFFF"
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: itemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeWallpaperPath = fullPath;
                                            applyWallpaper.imagePath = fullPath;
                                            applyWallpaper.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        color: Qt.rgba(0, 0, 0, 0.25)
                        radius: Math.max(4, root.themeRounding - 6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14

                            Text {
                                text: folderModel.count + " wallpapers in " + String(root.currentFolder).replace("file://", "")
                                font.pixelSize: 12
                                color: root.themeTextMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    width: 32; height: 20; radius: 4
                                    color: Qt.alpha(root.themeText, 0.12)
                                    Text { anchors.centerIn: parent; text: "ESC"; font.pixelSize: 10; color: root.themeTextMuted; font.weight: Font.Bold }
                                }
                                Text { text: "Close"; font.pixelSize: 12; color: root.themeTextMuted }
                            }
                        }
                    }
                }
            }
        }
    }
}