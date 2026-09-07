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

    // ============================================================
    // STRICT FOCUSED MONITOR LOCK LOGIC
    // ============================================================
    property string targetMonitorName: ""
    property bool isPickingFolder: false

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
    // THEME PROPERTIES (Solid Black matching desktop widget)
    // ============================================================
    property int themeRounding: 15
    property int themeBorderSize: 2
    property real themeBgAlpha: 1.0
    
    property color themeBackground: "#111114" 
    property color themeCardBg: "#18181d"
    property color themeBorder: "#d6bbfb"
    property color themeText: "#FFFFFF"          
    property color themeTextMuted: "#A1A1AA"
    property color themePrimary: "#d6bbfb"        

    property string currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
    property string activeWallpaperPath: ""
    
    // Engine & Animation Options
    property var availableEngines: ["awww", "swww", "hyprpaper", "swaybg", "mpvpaper"]
    property string selectedEngine: "awww"

    property var availableAnimations: ["grow", "fade", "wipe", "wave", "outer", "random"]
    property string selectedAnimation: "grow"

    // ============================================================
    // READ-ONLY DYNAMIC THEME PARSING
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

    // Engine Autodetection
    Process {
        id: detectEngines
        command: ["sh", "-c", "for eng in awww swww hyprpaper swaybg mpvpaper; do command -v $eng >/dev/null 2>&1 && echo $eng; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim().split("\n");
                let engines = [];
                for (let i = 0; i < out.length; i++) {
                    let e = out[i].trim();
                    if (e !== "") engines.push(e);
                }
                if (engines.length > 0) {
                    root.availableEngines = engines;
                    if (engines.indexOf("awww") !== -1) {
                        root.selectedEngine = "awww";
                    } else {
                        root.selectedEngine = engines[0];
                    }
                }
            }
        }
    }

    // Auto-detect default wallpaper folder
    Process {
        id: initFolderCheck
        command: [
            "sh", "-c",
            "if [ -d \"$HOME/Pictures/Wallpapers\" ] && [ \"$(ls -A \"$HOME/Pictures/Wallpapers\" 2>/dev/null)\" ]; then echo \"$HOME/Pictures/Wallpapers\"; " +
            "elif [ -d \"$HOME/Pictures/wallpapers\" ] && [ \"$(ls -A \"$HOME/Pictures/wallpapers\" 2>/dev/null)\" ]; then echo \"$HOME/Pictures/wallpapers\"; " +
            "elif [ -d \"$HOME/wallpapers\" ] && [ \"$(ls -A \"$HOME/wallpapers\" 2>/dev/null)\" ]; then echo \"$HOME/wallpapers\"; " +
            "else echo \"$HOME/Pictures\"; fi"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let dir = this.text.trim();
                if (dir.length > 0) {
                    root.currentFolder = "file://" + dir;
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
    }

    // ============================================================
    // FOLDER PICKER PROCESS
    // ============================================================
    Process {
        id: folderPickerProcess
        running: false
        command: [
            "sh", "-c",
            "if command -v zenity >/dev/null 2>&1; then " +
            "    zenity --file-selection --directory --title='Select Wallpaper Folder' --filename=\"$HOME/Pictures/\" 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then " +
            "    kdialog --getexistingdirectory \"$HOME/Pictures\" 2>/dev/null; " +
            "else " +
            "    python3 -c 'import tkinter as tk, tkinter.filedialog as fd; r=tk.Tk(); r.withdraw(); d=fd.askdirectory(); print(d if d else \"\")' 2>/dev/null; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let selected = this.text.trim();
                if (selected.length > 0) {
                    root.currentFolder = "file://" + selected;
                    searchInput.text = "";
                }
                root.isPickingFolder = false;
            }
        }
        onExited: {
            root.isPickingFolder = false;
        }
    }

    // ============================================================
    // WALLPAPER APPLICATION & MATUGEN COLOR EXTRACTION
    // ============================================================
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
            "# 1. Apply wallpaper via chosen engine (Transition time decreased to 0.5s for speed)\n" +
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
            "elif [ \"$ENGINE\" = \"swww\" ]; then\n" +
            "    swww img \"$IMG\" --transition-type \"$ANIM\" --transition-pos 0.5,0.5 --transition-duration 0.5 --transition-fps 90\n" +
            "elif [ \"$ENGINE\" = \"hyprpaper\" ]; then\n" +
            "    hyprctl hyprpaper preload \"$IMG\"\n" +
            "    hyprctl hyprpaper wallpaper \",\"\"$IMG\"\n" +
            "elif [ \"$ENGINE\" = \"swaybg\" ]; then\n" +
            "    killall swaybg 2>/dev/null; swaybg -i \"$IMG\" -m fill &\n" +
            "elif [ \"$ENGINE\" = \"mpvpaper\" ]; then\n" +
            "    killall mpvpaper 2>/dev/null; mpvpaper -o \"loop no-audio\" '*' \"$IMG\" &\n" +
            "fi\n" +
            "# 2. Extract colors dynamically with Matugen\n" +
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
            root.selectedAnimation
        ]
        
        onExited: running = false
    }

    function updateFilters(query) {
        let q = query.trim()
        if (q === "") {
            folderModel.nameFilters = ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.GIF", "*.WEBP"]
        } else {
            folderModel.nameFilters = [
                "*" + q + "*.png", "*" + q + "*.jpg", "*" + q + "*.jpeg", "*" + q + "*.gif", "*" + q + "*.webp",
                "*" + q + "*.PNG", "*" + q + "*.JPG", "*" + q + "*.JPEG", "*" + q + "*.GIF", "*" + q + "*.WEBP"
            ]
        }
    }

    // ============================================================
    // WINDOW UI
    // ============================================================
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: selectorWindow
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName

            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.keyboardFocus: (!root.isPickingFolder && isTargetMonitor) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-wallselect"
            
            WlrLayershell.layer: root.isPickingFolder ? WlrLayer.Bottom : WlrLayer.Overlay
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

                visible: root.targetMonitorName !== "" && isTargetMonitor
                focus: isTargetMonitor

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.40)
                color: root.themeBackground

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true 
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // Header Area
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

                        // Styled Engine Dropdown
                        ComboBox {
                            id: engineCombo
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: 130
                            model: root.availableEngines
                            currentIndex: root.availableEngines.indexOf(root.selectedEngine)
                            onCurrentTextChanged: {
                                if (currentText !== "") {
                                    root.selectedEngine = currentText
                                }
                            }
                            
                            background: Rectangle {
                                color: engineCombo.down ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                radius: Math.max(4, root.themeRounding - 4)
                                border.width: 1
                                border.color: engineCombo.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.14)
                            }

                            contentItem: RowLayout {
                                spacing: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 24
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "⚙"
                                    font.pixelSize: 16
                                    color: root.themePrimary
                                }
                                Text {
                                    text: engineCombo.currentText
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            indicator: Text {
                                x: engineCombo.width - width - 10
                                y: (engineCombo.height - height) / 2
                                text: "▾"
                                font.pixelSize: 13
                                color: root.themeTextMuted
                            }

                            popup: Popup {
                                y: engineCombo.height + 6
                                width: engineCombo.width
                                padding: 4
                                background: Rectangle {
                                    color: root.themeCardBg
                                    radius: Math.max(4, root.themeRounding - 6)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.45)
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: engineCombo.popup.visible ? engineCombo.delegateModel : null
                                    currentIndex: engineCombo.highlightedIndex
                                }
                            }

                            delegate: ItemDelegate {
                                width: engineCombo.width - 8
                                height: 34
                                highlighted: engineCombo.highlightedIndex === index
                                background: Rectangle {
                                    color: highlighted ? Qt.alpha(root.themePrimary, 0.25) : (hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                    radius: 5
                                }
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? root.themePrimary : root.themeText
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Styled Animation Dropdown
                        ComboBox {
                            id: animCombo
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: 135
                            model: root.availableAnimations
                            currentIndex: root.availableAnimations.indexOf(root.selectedAnimation)
                            onCurrentTextChanged: {
                                if (currentText !== "") {
                                    root.selectedAnimation = currentText
                                }
                            }
                            
                            background: Rectangle {
                                color: animCombo.down ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                radius: Math.max(4, root.themeRounding - 4)
                                border.width: 1
                                border.color: animCombo.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.14)
                            }

                            contentItem: RowLayout {
                                spacing: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 24
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "✨"
                                    font.pixelSize: 15
                                    color: root.themePrimary
                                }
                                Text {
                                    text: animCombo.currentText
                                    color: root.themeText
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            indicator: Text {
                                x: animCombo.width - width - 10
                                y: (animCombo.height - height) / 2
                                text: "▾"
                                font.pixelSize: 13
                                color: root.themeTextMuted
                            }

                            popup: Popup {
                                y: animCombo.height + 6
                                width: animCombo.width
                                padding: 4
                                background: Rectangle {
                                    color: root.themeCardBg
                                    radius: Math.max(4, root.themeRounding - 6)
                                    border.width: 1
                                    border.color: Qt.alpha(root.themePrimary, 0.45)
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: animCombo.popup.visible ? animCombo.delegateModel : null
                                    currentIndex: animCombo.highlightedIndex
                                }
                            }

                            delegate: ItemDelegate {
                                width: animCombo.width - 8
                                height: 34
                                highlighted: animCombo.highlightedIndex === index
                                background: Rectangle {
                                    color: highlighted ? Qt.alpha(root.themePrimary, 0.25) : (hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                    radius: 5
                                }
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? root.themePrimary : root.themeText
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Browse Button
                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: 105
                            radius: Math.max(4, root.themeRounding - 4)
                            color: browseMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.14)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "📁"
                                    font.pixelSize: 15
                                }
                                Text {
                                    text: "Browse"
                                    font.pixelSize: 12
                                    color: root.themeText
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: browseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.isPickingFolder = true
                                    folderPickerProcess.running = true
                                }
                            }
                        }

                        // Search Box
                        Rectangle {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 38
                            radius: Math.max(4, root.themeRounding - 4)
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: searchInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.14)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: ""
                                    font.pixelSize: 14
                                    color: root.themeTextMuted
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    font.pixelSize: 12
                                    color: root.themeText
                                    placeholderText: "Search..."
                                    placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.5)
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}

                                    Component.onCompleted: {
                                        if (selectorWindow.isTargetMonitor) {
                                            forceActiveFocus()
                                        }
                                    }

                                    onTextChanged: root.updateFilters(text)
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(root.themeBorder, 0.20)
                    }

                    // Wallpaper Grid Container
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            visible: folderModel.count === 0
                            text: "No images found in this folder.\nClick 'Browse' to select your wallpaper directory."
                            horizontalAlignment: Text.AlignHCenter
                            color: root.themeTextMuted
                            font.pixelSize: 14
                            lineHeight: 1.4
                        }

                        GridView {
                            id: imageGrid
                            anchors.fill: parent
                            clip: true
                            
                            readonly property int columns: Math.max(1, Math.floor(width / 230))
                            cellWidth: width > 0 ? Math.floor(width / columns) : 230
                            cellHeight: Math.floor(cellWidth * 0.65)
                            
                            model: FolderListModel {
                                id: folderModel
                                folder: root.currentFolder
                                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.GIF", "*.WEBP"]
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
                                width: imageGrid.cellWidth
                                height: imageGrid.cellHeight

                                property string fullPath: filePath ? filePath : (model.fileUrl ? model.fileUrl.toString().replace("file://", "") : "")
                                property string displayName: fileName ? fileName : ""

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    radius: Math.max(4, root.themeRounding - 6)
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 2
                                    
                                    property bool isActive: root.activeWallpaperPath === fullPath
                                    border.color: isActive ? root.themePrimary : (itemMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.5) : "transparent")
                                    
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + fullPath
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 440
                                        sourceSize.height: 290
                                        smooth: true
                                        mipmap: true
                                        
                                        opacity: itemMouse.containsMouse ? 0.85 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 32
                                        color: Qt.rgba(0, 0, 0, 0.78)
                                        opacity: itemMouse.containsMouse ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        
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

                    // Footer Bar
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