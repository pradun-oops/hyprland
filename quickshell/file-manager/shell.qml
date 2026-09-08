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
    property string currentPath: Quickshell.env("HOME")
    property string searchQuery: ""
    property bool showHiddenFiles: false
    property bool isEditingPath: false

    property string clipboardPath: ""
    property string clipboardAction: "copy"

    property bool contextMenuVisible: false
    property real contextMenuX: 0
    property real contextMenuY: 0
    property string targetItemPath: ""
    property string targetItemName: ""
    property bool targetIsDir: false
    property bool isBackgroundContext: false

    property bool deleteDialogVisible: false
    property string deleteTargetPath: ""
    property string deleteTargetName: ""

    property bool createDialogVisible: false
    property string createType: "folder"
    property string createTargetPath: ""

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
        function onFocusedMonitorChanged() { root.updateTargetMonitor() }
    }

    property int themeRounding: 16
    property int themeBorderSize: 2
    property real themeBgAlpha: 0.88
    property color themeBackground: "#121318"
    property color themeBorder: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#9EA3B0"
    property color themePrimary: "#ffb3af"

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
                if (bMatch && bMatch[1]) root.themeBorderSize = parseInt(bMatch[1])
            } catch (e) {}
        }
    }

    ListModel { id: bookmarksModel }

    function isBookmarked(path) {
        if (!path) return false
        let cleanPath = path.replace(/\/$/, "")
        for (let i = 0; i < bookmarksModel.count; i++) {
            let bm = bookmarksModel.get(i)
            if (bm && bm.path && bm.path.replace(/\/$/, "") === cleanPath) return true
        }
        return false
    }

    function addBookmark(name, path) {
        if (isBookmarked(path)) return
        bookmarksModel.append({
            name: name && name !== "" ? name : path.split("/").pop(),
            path: path,
            icon: "📁"
        })
        saveBookmarks()
    }

    function removeBookmark(path) {
        let cleanPath = path.replace(/\/$/, "")
        for (let i = 0; i < bookmarksModel.count; i++) {
            let bm = bookmarksModel.get(i)
            if (bm && bm.path && bm.path.replace(/\/$/, "") === cleanPath) {
                bookmarksModel.remove(i)
                saveBookmarks()
                return
            }
        }
    }

    function initDefaultBookmarks() {
        bookmarksModel.clear()
        let defaultList = [
            { name: "Home", path: Quickshell.env("HOME"), icon: "🏠" },
            { name: "Downloads", path: Quickshell.env("HOME") + "/Downloads", icon: "📥" },
            { name: "Documents", path: Quickshell.env("HOME") + "/Documents", icon: "📄" },
            { name: "Pictures", path: Quickshell.env("HOME") + "/Pictures", icon: "🖼️" },
            { name: "Music", path: Quickshell.env("HOME") + "/Music", icon: "🎵" },
            { name: "Videos", path: Quickshell.env("HOME") + "/Videos", icon: "🎬" },
            { name: "Desktop", path: Quickshell.env("HOME") + "/Desktop", icon: "🖥️" }
        ]
        for (let i = 0; i < defaultList.length; i++) {
            bookmarksModel.append(defaultList[i])
        }
    }

    FileView {
        id: bookmarkConfigFile
        path: Quickshell.env("HOME") + "/.config/qs_bookmarks.json"
        watchChanges: false
        onLoaded: {
            try {
                let data = text()
                if (data && data.trim().length > 0) {
                    let parsed = JSON.parse(data)
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        bookmarksModel.clear()
                        for (let i = 0; i < parsed.length; i++) {
                            bookmarksModel.append(parsed[i])
                        }
                        return
                    }
                }
            } catch (e) {}
            root.initDefaultBookmarks()
        }
    }

    function saveBookmarks() {
        let list = []
        for (let i = 0; i < bookmarksModel.count; i++) {
            let item = bookmarksModel.get(i)
            list.push({ name: item.name, path: item.path, icon: item.icon })
        }
        let jsonStr = JSON.stringify(list)
        let saveCmd = "mkdir -p ~/.config && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > ~/.config/qs_bookmarks.json"
        sysProcess.runCmd(saveCmd)
    }

    ListModel { id: searchResultsModel }

    Timer {
        id: searchDebounceTimer
        interval: 120
        repeat: false
        onTriggered: root.performAggressiveSearch()
    }

    Process {
        id: searchProcess
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (line.length === 0) return
                let parts = line.split("|")
                if (parts.length >= 2) {
                    let isDir = (parts[0] === "d")
                    let fullPath = parts.slice(1).join("|")
                    let name = fullPath.split("/").pop()
                    if (name && name !== "." && name !== "..") {
                        searchResultsModel.append({
                            fileName: name,
                            filePath: fullPath,
                            fileIsDir: isDir
                        })
                    }
                }
            }
        }
    }

    function performAggressiveSearch() {
        searchProcess.running = false
        searchResultsModel.clear()
        let q = root.searchQuery.trim()
        if (q === "") return

        let escapedQ = q.replace(/'/g, "'\\''")
        let cmd = "find \"" + Quickshell.env("HOME") + "\" -maxdepth 5 -iname \"*" + escapedQ + "*\" -printf \"%y|%p\\n\" 2>/dev/null | head -n 120"
        searchProcess.command = ["sh", "-c", cmd]
        searchProcess.running = true
    }

    Component.onCompleted: {
        root.updateTargetMonitor()
        if (root.targetMonitorName === "") fallbackMonitorTimer.start()
        colorFile.reload()
        generalConfigFile.reload()
        bookmarkConfigFile.reload()
    }

    Process {
        id: sysProcess
        function runCmd(cmd) {
            command = ["sh", "-c", cmd]
            running = true
        }
    }

    function openItem(filePath, isFolder) {
        if (isFolder) {
            root.currentPath = filePath
            root.searchQuery = ""
            searchInput.text = ""
        } else {
            sysProcess.runCmd("nohup xdg-open \"" + filePath.replace(/"/g, "\\\"") + "\" >/dev/null 2>&1 &")
        }
    }

    function navigateUp() {
        let cleanPath = root.currentPath.replace(/\/$/, "")
        let parts = cleanPath.split("/")
        if (parts.length > 2) {
            parts.pop()
            root.currentPath = parts.join("/")
        } else if (parts.length === 2) {
            root.currentPath = "/"
        }
        root.searchQuery = ""
        searchInput.text = ""
    }

    function getPathSegments(path) {
        let clean = path.replace(/\/$/, "")
        if (clean === "") return [{ name: "root", path: "/" }]
        let parts = clean.split("/").filter(p => p.length > 0)
        let res = [{ name: "root", path: "/" }]
        let acc = ""
        for (let i = 0; i < parts.length; i++) {
            acc += "/" + parts[i]
            res.push({ name: parts[i], path: acc })
        }
        return res
    }

    function openContextMenu(x, y, path, name, isDir, isBg) {
        root.contextMenuX = x
        root.contextMenuY = y
        root.targetItemPath = path
        root.targetItemName = name
        root.targetIsDir = isDir
        root.isBackgroundContext = isBg
        root.contextMenuVisible = true
    }

    function isImageFile(fileName) {
        if (!fileName) return false
        let ext = fileName.split('.').pop().toLowerCase()
        return ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "ico"].indexOf(ext) !== -1
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window
            required property var modelData
            screen: modelData

            property bool isTargetMonitor: modelData.name === root.targetMonitorName
            visible: root.targetMonitorName !== "" && isTargetMonitor

            WlrLayershell.keyboardFocus: isTargetMonitor ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-filemanager"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusiveZone: -1
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (root.createDialogVisible) {
                        root.createDialogVisible = false
                    } else if (root.deleteDialogVisible) {
                        root.deleteDialogVisible = false
                    } else if (root.contextMenuVisible) {
                        root.contextMenuVisible = false
                    } else {
                        Qt.quit()
                    }
                }
            }
            Shortcut { sequence: "Ctrl+H"; onActivated: root.showHiddenFiles = !root.showHiddenFiles }
            Shortcut { sequence: "Alt+Up"; onActivated: root.navigateUp() }
            Shortcut { sequence: "Backspace"; onActivated: root.navigateUp() }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.createDialogVisible) {
                        root.createDialogVisible = false
                    } else if (root.deleteDialogVisible) {
                        root.deleteDialogVisible = false
                    } else if (root.contextMenuVisible) {
                        root.contextMenuVisible = false
                    } else {
                        Qt.quit()
                    }
                }
            }

            Rectangle {
                id: mainCard
                width: Math.min(1040, parent.width - 60)
                height: Math.min(720, parent.height - 80)
                anchors.centerIn: parent

                radius: root.themeRounding
                border.width: root.themeBorderSize
                border.color: Qt.alpha(root.themeBorder, 0.35)
                color: Qt.alpha(root.themeBackground, root.themeBgAlpha)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.contextMenuVisible) root.contextMenuVisible = false
                        mouse.accepted = true
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36
                            radius: Math.max(6, root.themeRounding - 6)
                            color: upMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "▲"
                                color: root.themeText
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: upMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.navigateUp()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Math.max(6, root.themeRounding - 6)
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: 1
                            border.color: pathInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                visible: !root.isEditingPath
                                spacing: 4

                                Repeater {
                                    model: root.getPathSegments(root.currentPath)

                                    delegate: RowLayout {
                                        spacing: 4

                                        Rectangle {
                                            height: 26
                                            width: segText.implicitWidth + 14
                                            radius: 6
                                            color: segMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.3) : Qt.rgba(1, 1, 1, 0.06)

                                            Text {
                                                id: segText
                                                anchors.centerIn: parent
                                                text: modelData.name
                                                color: root.themeText
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                id: segMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    root.currentPath = modelData.path
                                                    root.searchQuery = ""
                                                    searchInput.text = ""
                                                }
                                            }
                                        }

                                        Text {
                                            text: "›"
                                            color: root.themeTextMuted
                                            font.pixelSize: 14
                                            visible: index < root.getPathSegments(root.currentPath).length - 1
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.isEditingPath = true
                                            pathInput.selectAll()
                                            pathInput.forceActiveFocus()
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 26; height: 26
                                    radius: 5
                                    color: copyPathBtn.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                                    Text { anchors.centerIn: parent; text: "📋"; font.pixelSize: 12 }
                                    MouseArea {
                                        id: copyPathBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: sysProcess.runCmd("printf '%s' \"" + root.currentPath + "\" | wl-copy")
                                    }
                                }
                            }

                            TextField {
                                id: pathInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                visible: root.isEditingPath
                                font.pixelSize: 12
                                color: root.themeText
                                text: root.currentPath
                                background: Item {}

                                onAccepted: {
                                    root.currentPath = text
                                    root.isEditingPath = false
                                }

                                Keys.onEscapePressed: root.isEditingPath = false
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 230
                            Layout.preferredHeight: 36
                            radius: Math.max(6, root.themeRounding - 6)
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: 1
                            border.color: searchInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.1)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 6

                                Text { text: "🔍"; font.pixelSize: 11; opacity: 0.7 }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 12
                                    color: root.themeText
                                    placeholderText: "Search everywhere in ~..."
                                    placeholderTextColor: Qt.alpha(root.themeTextMuted, 0.5)
                                    background: Item {}

                                    onTextChanged: {
                                        root.searchQuery = text
                                        searchDebounceTimer.restart()
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Return) {
                                            fileGrid.forceActiveFocus()
                                            event.accepted = true
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 18; height: 18; radius: 9
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                    visible: searchInput.text !== ""
                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 9; color: root.themeText }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            searchInput.text = ""
                                            root.searchQuery = ""
                                            searchResultsModel.clear()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(root.themeBorder, 0.15)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 180
                            Layout.fillHeight: true
                            radius: Math.max(6, root.themeRounding - 6)
                            color: Qt.rgba(0, 0, 0, 0.22)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Text {
                                    text: "FAVORITES"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.themeTextMuted
                                    Layout.leftMargin: 6
                                    Layout.topMargin: 4
                                }

                                ListView {
                                    id: bookmarkList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4
                                    clip: true
                                    interactive: false
                                    model: bookmarksModel

                                    delegate: Item {
                                        width: bookmarkList.width
                                        height: 34

                                        property bool isActive: root.currentPath === path && root.searchQuery === ""

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: isActive ? Qt.alpha(root.themePrimary, 0.22) : (bmMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                            border.width: isActive ? 1 : 0
                                            border.color: root.themePrimary

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                                spacing: 8

                                                Text { text: icon; font.pixelSize: 13 }

                                                Text {
                                                    text: name
                                                    color: root.themeText
                                                    font.pixelSize: 11
                                                    font.weight: isActive ? Font.Bold : Font.Normal
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: bmMouse
                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: {
                                                root.currentPath = path
                                                root.searchQuery = ""
                                                searchInput.text = ""
                                                root.isEditingPath = false
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            GridView {
                                id: fileGrid
                                anchors.fill: parent
                                cellWidth: 145
                                cellHeight: 120
                                clip: true
                                focus: true

                                model: root.searchQuery.trim() !== "" ? searchResultsModel : folderModel

                                FolderListModel {
                                    id: folderModel
                                    folder: "file://" + root.currentPath
                                    showDirsFirst: true
                                    showHidden: root.showHiddenFiles
                                }

                                ScrollBar.vertical: ScrollBar {
                                    active: fileGrid.moving || fileGrid.flicking
                                    policy: ScrollBar.AsNeeded
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            let mappedPos = mainCard.mapFromItem(fileGrid, mouse.x, mouse.y)
                                            root.openContextMenu(mappedPos.x, mappedPos.y, root.currentPath, "", true, true)
                                        } else {
                                            root.contextMenuVisible = false
                                        }
                                    }
                                }

                                delegate: Item {
                                    width: fileGrid.cellWidth
                                    height: fileGrid.cellHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        radius: Math.max(6, root.themeRounding - 6)

                                        property bool isSelected: GridView.isCurrentItem
                                        color: isSelected ? Qt.alpha(root.themePrimary, 0.22) : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.025))
                                        border.width: 1
                                        border.color: isSelected ? root.themePrimary : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 6

                                            Item {
                                                Layout.alignment: Qt.AlignHCenter
                                                width: 48
                                                height: 42

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 6
                                                    color: "transparent"
                                                    clip: true
                                                    visible: !fileIsDir && root.isImageFile(fileName)

                                                    Image {
                                                        id: imgThumb
                                                        anchors.fill: parent
                                                        source: (!fileIsDir && root.isImageFile(fileName)) ? ("file://" + filePath) : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        cache: true
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 6
                                                        border.width: 1
                                                        border.color: Qt.rgba(1, 1, 1, 0.2)
                                                        color: "transparent"
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible: fileIsDir
                                                    color: "transparent"

                                                    Rectangle {
                                                        x: 0; y: 2; width: 18; height: 8
                                                        radius: 3
                                                        color: root.themePrimary
                                                    }
                                                    Rectangle {
                                                        x: 0; y: 6; width: 48; height: 36
                                                        radius: 5
                                                        color: root.themePrimary

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: 5
                                                            color: Qt.rgba(1, 1, 1, 0.15)
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible: !fileIsDir && !root.isImageFile(fileName)
                                                    color: "transparent"

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 32; height: 38
                                                        radius: 4
                                                        color: Qt.rgba(1, 1, 1, 0.12)
                                                        border.width: 1
                                                        border.color: Qt.rgba(1, 1, 1, 0.2)

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: root.getFileExtension(fileName)
                                                            color: root.themeText
                                                            font.pixelSize: 8
                                                            font.weight: Font.Bold
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: fileName
                                                color: root.themeText
                                                font.pixelSize: 11
                                                font.weight: fileIsDir ? Font.DemiBold : Font.Normal
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.WrapAnywhere
                                            }
                                        }

                                        MouseArea {
                                            id: itemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                                            onClicked: (mouse) => {
                                                fileGrid.currentIndex = index
                                                fileGrid.forceActiveFocus()

                                                if (mouse.button === Qt.RightButton) {
                                                    let mappedPos = mainCard.mapFromItem(itemMouse, mouse.x, mouse.y)
                                                    root.openContextMenu(mappedPos.x, mappedPos.y, filePath, fileName, fileIsDir, false)
                                                } else {
                                                    root.contextMenuVisible = false
                                                }
                                            }

                                            onDoubleClicked: (mouse) => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    root.openItem(filePath, fileIsDir)
                                                }
                                            }
                                        }
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return) {
                                            if (fileGrid.currentItem) {
                                                let itemModel = root.searchQuery.trim() !== "" ? searchResultsModel : folderModel
                                                let itemPath = itemModel.get(fileGrid.currentIndex, "filePath")
                                                let isDir = itemModel.get(fileGrid.currentIndex, "fileIsDir")
                                                root.openItem(itemPath, isDir)
                                            }
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Delete) {
                                            if (fileGrid.currentItem) {
                                                let itemModel = root.searchQuery.trim() !== "" ? searchResultsModel : folderModel
                                                root.deleteTargetPath = itemModel.get(fileGrid.currentIndex, "filePath")
                                                root.deleteTargetName = itemModel.get(fileGrid.currentIndex, "fileName")
                                                root.deleteDialogVisible = true
                                            }
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Backspace) {
                                            root.navigateUp()
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
                                            root.showHiddenFiles = !root.showHiddenFiles
                                            event.accepted = true
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
                        radius: Math.max(6, root.themeRounding - 6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12

                            Text {
                                text: (root.searchQuery.trim() !== "" ? searchResultsModel.count + " search matches in ~" : folderModel.count + " items") + (root.showHiddenFiles ? " • Hidden Shown" : "")
                                font.pixelSize: 11
                                color: root.themeTextMuted
                            }

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 10
                                KeyHint { keys: "Ctrl+H"; label: "Hidden" }
                                KeyHint { keys: "Enter"; label: "Open" }
                                KeyHint { keys: "Del"; label: "Delete" }
                                KeyHint { keys: "Backspace"; label: "Up" }
                                KeyHint { keys: "ESC"; label: "Close" }
                            }
                        }
                    }
                }

                Rectangle {
                    id: contextMenu
                    visible: root.contextMenuVisible
                    x: Math.min(Math.max(10, root.contextMenuX), mainCard.width - width - 10)
                    y: Math.min(Math.max(10, root.contextMenuY), mainCard.height - height - 10)
                    width: 185
                    height: menuColumn.implicitHeight + 12
                    radius: 10
                    color: Qt.alpha(root.themeBackground, 0.96)
                    border.width: 1
                    border.color: Qt.alpha(root.themeBorder, 0.4)
                    z: 999

                    ColumnLayout {
                        id: menuColumn
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        ContextMenuItem {
                            text: "New Folder"
                            icon: "📁"
                            onTriggered: {
                                root.contextMenuVisible = false
                                root.createType = "folder"
                                root.createTargetPath = (root.targetIsDir && !root.isBackgroundContext) ? root.targetItemPath : root.currentPath
                                createInput.text = "New Folder"
                                root.createDialogVisible = true
                                createInput.selectAll()
                                createInput.forceActiveFocus()
                            }
                        }

                        ContextMenuItem {
                            text: "New File"
                            icon: "📄"
                            onTriggered: {
                                root.contextMenuVisible = false
                                root.createType = "file"
                                root.createTargetPath = (root.targetIsDir && !root.isBackgroundContext) ? root.targetItemPath : root.currentPath
                                createInput.text = "New File.txt"
                                root.createDialogVisible = true
                                createInput.selectAll()
                                createInput.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.1)
                        }

                        ContextMenuItem {
                            text: "Open"
                            icon: "📂"
                            visible: !root.isBackgroundContext
                            onTriggered: {
                                root.contextMenuVisible = false
                                root.openItem(root.targetItemPath, root.targetIsDir)
                            }
                        }

                        ContextMenuItem {
                            text: "Add to Sidebar"
                            icon: "📌"
                            visible: !root.isBackgroundContext && root.targetIsDir && !root.isBookmarked(root.targetItemPath)
                            onTriggered: {
                                root.contextMenuVisible = false
                                root.addBookmark(root.targetItemName, root.targetItemPath)
                            }
                        }

                        ContextMenuItem {
                            text: "Remove from Sidebar"
                            icon: "❌"
                            visible: !root.isBackgroundContext && root.targetIsDir && root.isBookmarked(root.targetItemPath)
                            isDanger: true
                            onTriggered: {
                                root.contextMenuVisible = false
                                root.removeBookmark(root.targetItemPath)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.1)
                            visible: !root.isBackgroundContext
                        }

                        ContextMenuItem {
                            text: "Copy"
                            icon: "📋"
                            visible: !root.isBackgroundContext
                            onTriggered: {
                                root.clipboardPath = root.targetItemPath
                                root.clipboardAction = "copy"
                                root.contextMenuVisible = false
                            }
                        }

                        ContextMenuItem {
                            text: "Move (Cut)"
                            icon: "✂️"
                            visible: !root.isBackgroundContext
                            onTriggered: {
                                root.clipboardPath = root.targetItemPath
                                root.clipboardAction = "move"
                                root.contextMenuVisible = false
                            }
                        }

                        ContextMenuItem {
                            text: "Paste"
                            icon: "📥"
                            enabled: root.clipboardPath !== ""
                            onTriggered: {
                                root.contextMenuVisible = false
                                let cmd = root.clipboardAction === "move" 
                                    ? "mv \"" + root.clipboardPath + "\" \"" + root.currentPath + "/\""
                                    : "cp -r \"" + root.clipboardPath + "\" \"" + root.currentPath + "/\""
                                sysProcess.runCmd(cmd)
                                if (root.clipboardAction === "move") root.clipboardPath = ""
                            }
                        }

                        ContextMenuItem {
                            text: "Copy Path"
                            icon: "🔗"
                            visible: !root.isBackgroundContext
                            onTriggered: {
                                root.contextMenuVisible = false
                                sysProcess.runCmd("printf '%s' \"" + root.targetItemPath + "\" | wl-copy")
                            }
                        }

                        ContextMenuItem {
                            text: "Open Terminal"
                            icon: "💻"
                            onTriggered: {
                                root.contextMenuVisible = false
                                let targetDir = root.targetIsDir ? root.targetItemPath : root.currentPath
                                sysProcess.runCmd("kitty --detach --directory \"" + targetDir + "\"")
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.1)
                            visible: !root.isBackgroundContext
                        }

                        ContextMenuItem {
                            text: "Delete"
                            icon: "🗑️"
                            visible: !root.isBackgroundContext
                            isDanger: true
                            onTriggered: {
                                root.contextMenuVisible = false
                                root.deleteTargetPath = root.targetItemPath
                                root.deleteTargetName = root.targetItemName
                                root.deleteDialogVisible = true
                            }
                        }
                    }
                }

                Rectangle {
                    id: createModal
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: Qt.rgba(0, 0, 0, 0.65)
                    visible: root.createDialogVisible
                    z: 1000

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.createDialogVisible = false
                    }

                    Rectangle {
                        width: 380
                        height: 180
                        anchors.centerIn: parent
                        radius: Math.max(8, root.themeRounding - 4)
                        color: Qt.alpha(root.themeBackground, 0.98)
                        border.width: 1
                        border.color: Qt.alpha(root.themeBorder, 0.4)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse.accepted = true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            RowLayout {
                                spacing: 8
                                Text { text: root.createType === "folder" ? "📁" : "📄"; font.pixelSize: 18 }
                                Text {
                                    text: root.createType === "folder" ? "Create New Folder" : "Create New File"
                                    color: root.themeText
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 6
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: createInput.activeFocus ? root.themePrimary : Qt.rgba(1, 1, 1, 0.15)

                                TextField {
                                    id: createInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    font.pixelSize: 12
                                    color: root.themeText
                                    background: Item {}

                                    onAccepted: {
                                        if (text.trim().length > 0) {
                                            let name = text.trim().replace(/"/g, "\\\"")
                                            let fullPath = root.createTargetPath.replace(/\/$/, "") + "/" + name
                                            let cmd = root.createType === "folder"
                                                ? "mkdir -p \"" + fullPath + "\""
                                                : "touch \"" + fullPath + "\""
                                            sysProcess.runCmd(cmd)
                                        }
                                        root.createDialogVisible = false
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 80; height: 32
                                    radius: 6
                                    color: cancelCreateMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: root.themeText
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: cancelCreateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.createDialogVisible = false
                                    }
                                }

                                Rectangle {
                                    width: 80; height: 32
                                    radius: 6
                                    color: confirmCreateMouse.containsMouse ? Qt.alpha(root.themePrimary, 0.85) : Qt.alpha(root.themePrimary, 0.65)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Create"
                                        color: root.themeBackground
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: confirmCreateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (createInput.text.trim().length > 0) {
                                                let name = createInput.text.trim().replace(/"/g, "\\\"")
                                                let fullPath = root.createTargetPath.replace(/\/$/, "") + "/" + name
                                                let cmd = root.createType === "folder"
                                                    ? "mkdir -p \"" + fullPath + "\""
                                                    : "touch \"" + fullPath + "\""
                                                sysProcess.runCmd(cmd)
                                            }
                                            root.createDialogVisible = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: deleteModal
                    anchors.fill: parent
                    radius: root.themeRounding
                    color: Qt.rgba(0, 0, 0, 0.65)
                    visible: root.deleteDialogVisible
                    z: 1000

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.deleteDialogVisible = false
                    }

                    Rectangle {
                        width: 360
                        height: 170
                        anchors.centerIn: parent
                        radius: Math.max(8, root.themeRounding - 4)
                        color: Qt.alpha(root.themeBackground, 0.98)
                        border.width: 1
                        border.color: Qt.rgba(0.9, 0.2, 0.2, 0.5)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse.accepted = true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            RowLayout {
                                spacing: 8
                                Text { text: "⚠️"; font.pixelSize: 18 }
                                Text {
                                    text: "Confirm Delete"
                                    color: root.themeText
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: "Are you sure you want to delete '" + root.deleteTargetName + "'?"
                                color: root.themeTextMuted
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 75; height: 30
                                    radius: 6
                                    color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: root.themeText
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.deleteDialogVisible = false
                                    }
                                }

                                Rectangle {
                                    width: 75; height: 30
                                    radius: 6
                                    color: deleteMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.85) : Qt.rgba(0.9, 0.2, 0.2, 0.65)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Yes"
                                        color: "#FFFFFF"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: deleteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            sysProcess.runCmd("rm -rf \"" + root.deleteTargetPath.replace(/"/g, "\\\"") + "\"")
                                            root.deleteDialogVisible = false
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

    component ContextMenuItem: Rectangle {
        id: cItem
        property string text: ""
        property string icon: ""
        property bool isDanger: false
        property bool enabled: true
        signal triggered()

        Layout.fillWidth: true
        height: 26
        radius: 5
        opacity: enabled ? 1.0 : 0.4
        color: itemArea.containsMouse && enabled ? (isDanger ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : Qt.alpha(root.themePrimary, 0.25)) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 8

            Text { text: cItem.icon; font.pixelSize: 11 }
            Text {
                text: cItem.text
                color: cItem.isDanger ? "#FF6B6B" : root.themeText
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: itemArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (cItem.enabled) cItem.triggered()
            }
        }
    }

    component KeyHint: RowLayout {
        property string keys: ""
        property string label: ""
        spacing: 4
        Rectangle {
            height: 18
            width: hintText.implicitWidth + 8
            radius: 4
            color: Qt.alpha(root.themeText, 0.1)
            Text {
                id: hintText
                anchors.centerIn: parent
                text: keys
                font.pixelSize: 9
                color: root.themeTextMuted
                font.weight: Font.Bold
            }
        }
        Text { text: label; font.pixelSize: 10; color: root.themeTextMuted }
    }

    function getFileExtension(filename) {
        let ext = filename.split('.').pop().toUpperCase()
        return ext.length <= 4 ? ext : "FILE"
    }
}