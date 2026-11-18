import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property string fontFamily: "Adwaita Sans"
    property string iconFontFamily: "Symbols Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font, sans-serif"

    property color themeBorder: "#ffb3af"
    property color themePrimary: "#ffb3af"
    property color themeText: "#FFFFFF"
    property color themeTextMuted: "#D4D4D8"
    property color themeBackground: "#0d0e11"
    property color themeSurface: Qt.rgba(0, 0, 0, 0.42)

    property int themeRounding: 22
    property int themeBorderSize: 2
    property bool animEnabled: true
    property int animDuration: 220

    property real posXRatio: 0.50
    property real posYRatio: 0.14
    property int clockFontSize: 312
    property bool depthEnabled: true
    property string depthMode: "auto"
    property real depthThreshold: 0.48
    property bool primaryMonitorOnly: true
    property bool controlsVisible: false

    property string pythonBin: Quickshell.env("HOME") + "/.local/share/quickshell/depth-venv/bin/python3"
    property string engineScript: Quickshell.env("HOME") + "/.config/hypr/scripts/depth_engine.py"

    property string currentWallpaper: ""
    property string depthMaskSource: ""
    property string resolvedDepthMode: "depth"
    property string depthEngineStatus: "checking"

    property string currentHour: "00"
    property string currentMinute: "00"
    property string currentPeriod: "AM"
    property string currentDateLine: "Wednesday, Nov 18"
    property string weatherIcon: ""
    property string weatherTemp: ""
    property string weatherLat: "23.3441"
    property string weatherLon: "85.3096"

    function getTargetOutputName() {
        if (!root.primaryMonitorOnly) return ""
        if (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0]) {
            return Quickshell.screens[0].name || ""
        }
        return ""
    }

    function mixColor(c1, c2, ratio, alphaVal) {
        let col1 = Qt.color(c1)
        let col2 = Qt.color(c2)
        let r = col1.r * (1 - ratio) + col2.r * ratio
        let g = col1.g * (1 - ratio) + col2.g * ratio
        let b = col1.b * (1 - ratio) + col2.b * ratio
        return Qt.rgba(r, g, b, alphaVal)
    }

    property color clockDigitColor: mixColor("#FFFFFF", themePrimary, 0.38, 1.0)
    property color clockAccentColor: Qt.lighter(themePrimary, 1.08)
    property color clockOutlineColor: Qt.rgba(0.03, 0.035, 0.05, 0.88)
    property color clockShadowColor: Qt.rgba(0.02, 0.025, 0.04, 0.62)

    QtObject {
        id: animStyle
        property int base: root.animDuration > 0 ? Math.min(root.animDuration, 260) : 220
        property int enterDuration: Math.round(base * 1.35)
        property int exitDuration: Math.round(base * 1.05)
        property int morphDuration: Math.round(base * 1.25)
        property int fadeDuration: Math.round(base * 0.85)
        property int microDuration: Math.round(base * 0.65)
        property int scaleDuration: Math.round(base * 1.1)
        property var smoothEasing: Easing.OutQuint
        property var expoEasing: Easing.OutExpo
    }

    FileView {
        id: clockConfigFile
        path: Quickshell.env("HOME") + "/.config/quickshell/json/depth_clock.json"
        watchChanges: false
        onLoaded: {
            try {
                let raw = text().trim()
                if (!raw) return
                let d = JSON.parse(raw)
                if (d.posXRatio !== undefined && !isNaN(d.posXRatio))
                    root.posXRatio = Math.max(0.0, Math.min(1.0, parseFloat(d.posXRatio)))
                if (d.posYRatio !== undefined && !isNaN(d.posYRatio))
                    root.posYRatio = Math.max(0.0, Math.min(1.0, parseFloat(d.posYRatio)))
                let savedSize = d.clockFontSize !== undefined ? d.clockFontSize : d.clockFontSizeLarge
                if (savedSize !== undefined && !isNaN(savedSize))
                    root.clockFontSize = Math.max(120, Math.min(520, parseInt(savedSize)))
                if (d.depthEnabled !== undefined)
                    root.depthEnabled = Boolean(d.depthEnabled)
                if (d.depthMode === "auto" || d.depthMode === "depth" || d.depthMode === "subject")
                    root.depthMode = d.depthMode
                if (d.depthThreshold !== undefined && !isNaN(d.depthThreshold))
                    root.depthThreshold = Math.max(0.08, Math.min(0.92, parseFloat(d.depthThreshold)))
            } catch (e) {}
        }
    }

    Process {
        id: saveConfigProcess
        property bool pendingSave: false
        onExited: {
            if (pendingSave) {
                pendingSave = false
                root.saveClockConfig()
            }
        }
    }

    function saveClockConfig() {
        if (saveConfigProcess.running) {
            saveConfigProcess.pendingSave = true
            return
        }
        let jsonDir = Quickshell.env("HOME") + "/.config/quickshell/json"
        let jsonFile = jsonDir + "/depth_clock.json"
        let jsonTmp = jsonFile + ".tmp"
        let payload = JSON.stringify({
            posXRatio: Number(root.posXRatio.toFixed(4)),
            posYRatio: Number(root.posYRatio.toFixed(4)),
            clockFontSize: root.clockFontSize,
            depthEnabled: root.depthEnabled,
            depthMode: root.depthMode,
            depthThreshold: Number(root.depthThreshold.toFixed(2))
        })

        let cmd = "mkdir -p '" + jsonDir + "' && printf '%s' '" + payload + "' > '" + jsonTmp + "' && mv '" + jsonTmp + "' '" + jsonFile + "'"
        saveConfigProcess.command = ["bash", "-c", cmd]
        saveConfigProcess.running = true
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let content = text()
                let match = content.match(/active_border\s*=\s*"rgba?\(([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}\)"/) ||
                            content.match(/active_border\s*=\s*"#([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}"/) ||
                            content.match(/(?:primary|accent)\s*=\s*"rgba?\(([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}\)"/) ||
                            content.match(/(?:primary|accent)\s*=\s*"#([a-fA-F0-9]{6})[a-fA-F0-9]{0,2}"/)
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
                if (rMatch && rMatch[1]) root.themeRounding = Math.max(14, parseInt(rMatch[1]))
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
                let enabledMatch = content.match(/animations\s*=\s*\{[\s\S]*?enabled\s*=\s*(true|false)/) ||
                                   content.match(/enabled\s*=\s*(true|false)/)
                if (enabledMatch && enabledMatch[1]) root.animEnabled = (enabledMatch[1] === "true")
                let speedMatch = content.match(/speed\s*=\s*([\d.]+)/)
                if (speedMatch && speedMatch[1]) root.animDuration = Math.round(parseFloat(speedMatch[1]) * 100)
            } catch (e) {}
        }
    }

    Process {
        id: wallpaperPollProcess
        command: ["sh", "-c", "awww query 2>/dev/null || swww query 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n")
                let targetOut = root.getTargetOutputName()
                let fallbackWp = ""
                let matchedWp = ""
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].replace(/^:\s*/, "").trim()
                    let idx = line.indexOf("image:")
                    if (idx === -1) continue
                    let colonIdx = line.indexOf(":")
                    let outName = colonIdx !== -1 ? line.slice(0, colonIdx).trim() : ""
                    let wpPath = line.slice(idx + 6).trim()
                    if (wpPath !== "") {
                        if (targetOut !== "" && outName === targetOut) {
                            matchedWp = wpPath
                            break
                        }
                        if (fallbackWp === "") fallbackWp = wpPath
                    }
                }
                let activeWp = matchedWp !== "" ? matchedWp : fallbackWp
                if (activeWp !== "" && activeWp !== root.currentWallpaper) {
                    root.currentWallpaper = activeWp
                    root.depthMaskSource = ""
                    root.syncWallpaperDepth(false)
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            if (!wallpaperPollProcess.running) {
                wallpaperPollProcess.running = true
            }
        }
    }

    Process {
        id: wallpaperDepthProcess
        property bool pendingRun: false
        property bool pendingForce: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text.trim())
                    if (res.wp && res.wp !== "") {
                        root.currentWallpaper = res.wp
                    }
                    root.depthEngineStatus = res.status || "none"
                    if (res.resolved_mode) {
                        root.resolvedDepthMode = res.resolved_mode
                    }
                    if (res.status === "ready" && res.cutout && res.cutout !== "") {
                        root.depthMaskSource = "file://" + res.cutout + "?t=" + Date.now()
                    } else if (res.status !== "ready") {
                        root.depthMaskSource = ""
                    }
                } catch (e) {}
            }
        }

        onExited: {
            if (pendingRun) {
                let f = pendingForce
                pendingRun = false
                pendingForce = false
                root.syncWallpaperDepth(f)
            }
        }
    }

    function syncWallpaperDepth(force) {
        let isForce = Boolean(force)
        if (wallpaperDepthProcess.running) {
            wallpaperDepthProcess.pendingRun = true
            if (isForce) wallpaperDepthProcess.pendingForce = true
            return
        }
        let targetOut = root.getTargetOutputName()
        let args = [
            root.pythonBin,
            root.engineScript,
            "--mode", root.depthMode,
            "--threshold", root.depthThreshold.toFixed(2)
        ]
        if (targetOut !== "") {
            args.push("--output", targetOut)
        }
        if (isForce) {
            args.push("--force")
        }
        root.depthEngineStatus = "processing"
        wallpaperDepthProcess.command = args
        wallpaperDepthProcess.running = true
    }

    function cycleDepthMode() {
        if (root.depthMode === "auto") root.depthMode = "depth"
        else if (root.depthMode === "depth") root.depthMode = "subject"
        else root.depthMode = "auto"
        root.syncWallpaperDepth(false)
        root.saveClockConfig()
    }

    Timer {
        id: depthSliceDebounce
        interval: 85
        repeat: false
        onTriggered: {
            root.syncWallpaperDepth(false)
            root.saveClockConfig()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date()
            let rawHours = now.getHours()
            root.currentPeriod = rawHours >= 12 ? "PM" : "AM"
            let hours12 = rawHours % 12 || 12

            root.currentHour = hours12.toString().padStart(2, '0')
            root.currentMinute = now.getMinutes().toString().padStart(2, '0')

            let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            root.currentDateLine = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()
        }
    }

    function fetchWeather() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", `https://api.open-meteo.com/v1/forecast?latitude=${root.weatherLat}&longitude=${root.weatherLon}&current=temperature_2m,weather_code&timezone=auto`)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText).current
                    var temp = Math.round(d.temperature_2m)
                    var code = d.weather_code
                    var icon = "󰖙"
                    if (code === 1 || code === 2) icon = "󰖕"
                    else if (code === 3) icon = "󰖐"
                    else if (code >= 45 && code <= 48) icon = "󰖑"
                    else if (code >= 51 && code <= 67) icon = "󰖗"
                    else if (code >= 71 && code <= 77) icon = "󰖘"
                    else if (code >= 95 && code <= 99) icon = "󰙾"
                    root.weatherIcon = icon
                    root.weatherTemp = temp + "°"
                } catch (e) {}
            }
        }
        xhr.send()
    }

    Component.onCompleted: {
        clockConfigFile.reload()
        colorFile.reload()
        generalConfigFile.reload()
        animConfigFile.reload()
        root.fetchWeather()
        wallpaperPollProcess.running = true
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: clockWindow
            required property var modelData
            screen: modelData

            visible: modelData !== null && (!root.primaryMonitorOnly || modelData === Quickshell.screens[0])

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-depth-clock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            mask: (resizeArea.isHoldingLeft || resizeArea.isResizing) ? fullScreenRegion : interactiveRegion
            color: "transparent"

            Region {
                id: fullScreenRegion
                x: 0
                y: 0
                width: clockWindow.width
                height: clockWindow.height
            }

            Region {
                id: interactiveRegion
                item: clockContainer
                Region {
                    item: root.controlsVisible ? depthHoverToggle : null
                }
            }

            Item {
                id: clockContainer
                z: 1
                width: clockColumn.implicitWidth + 32
                height: clockColumn.implicitHeight + 48

                property bool shown: false
                property bool settled: false

                layer.enabled: root.animEnabled && !settled
                layer.smooth: true

                Binding {
                    target: clockContainer
                    property: "x"
                    value: Math.max(0, Math.min(clockWindow.width - clockContainer.width,
                           (clockWindow.width - clockContainer.width) * root.posXRatio))
                    when: !dragArea.drag.active && !resizeArea.isResizing && !resizeArea.committing && clockWindow.width > 0
                }

                Binding {
                    target: clockContainer
                    property: "y"
                    value: Math.max(0, Math.min(clockWindow.height - clockContainer.height,
                           (clockWindow.height - clockContainer.height) * root.posYRatio))
                    when: !dragArea.drag.active && !resizeArea.isResizing && !resizeArea.committing && clockWindow.height > 0
                }

                Component.onCompleted: {
                    shown = true
                    settleTimer.start()
                }

                Timer {
                    id: settleTimer
                    interval: animStyle.enterDuration + 40
                    repeat: false
                    onTriggered: clockContainer.settled = true
                }

                opacity: shown ? 1.0 : 0.0
                scale: shown ? 1.0 : 0.94

                transform: Translate {
                    y: clockContainer.shown ? 0 : 12
                    Behavior on y {
                        NumberAnimation {
                            duration: root.animEnabled ? animStyle.enterDuration : 0
                            easing.type: animStyle.expoEasing
                        }
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.enterDuration : 0
                        easing.type: animStyle.expoEasing
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    drag.target: clockContainer
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, clockWindow.width - clockContainer.width)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, clockWindow.height - clockContainer.height)
                    drag.threshold: 3

                    onDoubleClicked: {
                        root.controlsVisible = !root.controlsVisible
                    }

                    onReleased: mouse => {
                        if (mouse.button !== Qt.LeftButton) return
                        let maxX = Math.max(1, clockWindow.width - clockContainer.width)
                        let maxY = Math.max(1, clockWindow.height - clockContainer.height)
                        root.posXRatio = Math.max(0.0, Math.min(1.0, clockContainer.x / maxX))
                        root.posYRatio = Math.max(0.0, Math.min(1.0, clockContainer.y / maxY))
                        root.saveClockConfig()
                    }

                    onWheel: wheel => {
                        let step = wheel.angleDelta.y > 0 ? 12 : -12
                        root.clockFontSize = Math.max(120, Math.min(520, root.clockFontSize + step))
                        root.saveClockConfig()
                    }
                }

                MouseArea {
                    id: resizeArea
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 84
                    height: 84
                    z: 5
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    pressAndHoldInterval: 240
                    preventStealing: true
                    cursorShape: isResizing ? Qt.SizeFDiagCursor : (containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor)

                    property bool isHoldingLeft: false
                    property bool isResizing: false
                    property bool committing: false
                    property real pressGlobalX: 0
                    property real pressGlobalY: 0
                    property real startX: 0
                    property real startY: 0
                    property real startWidth: 400
                    property real startHeight: 300
                    property int startFontSize: 312
                    property real smoothScale: 1.0

                    onDoubleClicked: {
                        root.controlsVisible = !root.controlsVisible
                    }

                    onPressed: mouse => {
                        if (mouse.button !== Qt.LeftButton) return
                        isHoldingLeft = true
                        let pt = mapToItem(clockWindow.contentItem, mouse.x, mouse.y)
                        pressGlobalX = pt.x
                        pressGlobalY = pt.y
                        startX = clockContainer.x
                        startY = clockContainer.y
                        startWidth = Math.max(1, clockContainer.width)
                        startHeight = Math.max(1, clockContainer.height)
                        startFontSize = root.clockFontSize
                        smoothScale = 1.0
                        isResizing = false
                    }

                    onPressAndHold: {
                        if (isHoldingLeft) {
                            isResizing = true
                        }
                    }

                    onPositionChanged: mouse => {
                        if (!isResizing) return
                        let pt = mapToItem(clockWindow.contentItem, mouse.x, mouse.y)
                        let dx = pt.x - pressGlobalX
                        let dy = pt.y - pressGlobalY
                        let scaleX = (startWidth + dx) / startWidth
                        let scaleY = (startHeight + dy) / startHeight
                        let rawScale = (scaleX + scaleY) * 0.5
                        let minScale = 120 / startFontSize
                        let maxScaleByFont = 520 / startFontSize
                        let maxScaleByW = (clockWindow.width - startX) / startWidth
                        let maxScaleByH = (clockWindow.height - startY) / startHeight
                        let maxScale = Math.max(minScale, Math.min(maxScaleByFont, maxScaleByW, maxScaleByH))
                        smoothScale = Math.max(minScale, Math.min(maxScale, rawScale))
                    }

                    function finishResize() {
                        isHoldingLeft = false
                        if (!isResizing) return
                        let finalFontSize = Math.max(120, Math.min(520, Math.round(startFontSize * smoothScale)))
                        committing = true
                        isResizing = false
                        smoothScale = 1.0
                        root.clockFontSize = finalFontSize
                        Qt.callLater(function() {
                            let maxX = Math.max(1, clockWindow.width - clockContainer.width)
                            let maxY = Math.max(1, clockWindow.height - clockContainer.height)
                            root.posXRatio = Math.max(0.0, Math.min(1.0, startX / maxX))
                            root.posYRatio = Math.max(0.0, Math.min(1.0, startY / maxY))
                            committing = false
                            root.saveClockConfig()
                        })
                    }

                    onReleased: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            finishResize()
                        }
                    }

                    onCanceled: finishResize()

                    Canvas {
                        id: cornerArc
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 26
                        height: 26
                        opacity: (resizeArea.containsMouse || resizeArea.isHoldingLeft || resizeArea.isResizing) ? 1.0 : 0.0
                        scale: resizeArea.isResizing ? 1.2 : (resizeArea.isHoldingLeft ? 1.08 : 1.0)
                        antialiasing: true

                        property color arcColor: resizeArea.isResizing ? root.themePrimary : (resizeArea.isHoldingLeft ? Qt.lighter(root.themePrimary, 1.15) : Qt.alpha(root.themePrimary, 0.78))
                        onArcColorChanged: requestPaint()
                        onVisibleChanged: if (visible) requestPaint()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.fadeDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.animEnabled ? animStyle.scaleDuration : 0
                                easing.type: animStyle.smoothEasing
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = arcColor
                            ctx.lineWidth = 3.2
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.arc(width - 13, height - 13, 11, 0, Math.PI * 0.5)
                            ctx.stroke()
                        }
                    }
                }

                ColumnLayout {
                    id: clockColumn
                    x: 16
                    y: 0
                    transformOrigin: Item.TopLeft
                    scale: resizeArea.smoothScale
                    spacing: -Math.round(root.clockFontSize * 0.11)

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Text {
                            text: root.currentDateLine
                            color: "#FFFFFF"
                            font.family: root.fontFamily
                            font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.11))
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                            style: Text.Outline
                            styleColor: root.clockOutlineColor
                        }

                        Text {
                            visible: root.weatherTemp !== ""
                            text: "•"
                            color: root.clockAccentColor
                            font.family: root.fontFamily
                            font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.11))
                            font.weight: Font.Black
                            style: Text.Outline
                            styleColor: root.clockOutlineColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: root.animEnabled ? animStyle.fadeDuration : 0
                                    easing.type: animStyle.smoothEasing
                                }
                            }
                        }

                        RowLayout {
                            visible: root.weatherTemp !== ""
                            spacing: 6

                            Text {
                                text: root.weatherIcon
                                color: root.clockAccentColor
                                font.family: root.iconFontFamily
                                font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.105))
                                style: Text.Outline
                                styleColor: root.clockOutlineColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }

                            Text {
                                text: root.weatherTemp
                                color: "#FFFFFF"
                                font.family: root.fontFamily
                                font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.11))
                                font.weight: Font.Bold
                                style: Text.Outline
                                styleColor: root.clockOutlineColor
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Item {
                            implicitWidth: hourText.implicitWidth
                            implicitHeight: hourText.implicitHeight

                            Text {
                                x: 0
                                y: 7
                                text: root.currentHour
                                color: root.clockShadowColor
                                font.family: root.fontFamily
                                font.pixelSize: root.clockFontSize
                                font.weight: Font.Bold
                                font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                            }

                            Text {
                                id: hourText
                                text: root.currentHour
                                color: root.clockDigitColor
                                font.family: root.fontFamily
                                font.pixelSize: root.clockFontSize
                                font.weight: Font.Bold
                                font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                                style: Text.Outline
                                styleColor: root.clockOutlineColor

                                Behavior on font.pixelSize {
                                    enabled: root.animEnabled && !resizeArea.isResizing && !resizeArea.committing
                                    NumberAnimation {
                                        duration: animStyle.morphDuration
                                        easing.type: animStyle.expoEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }
                        }

                        Item {
                            implicitWidth: colonText.implicitWidth
                            implicitHeight: colonText.implicitHeight
                            Layout.alignment: Qt.AlignVCenter
                            Layout.bottomMargin: Math.round(root.clockFontSize * 0.08)

                            Text {
                                x: 0
                                y: 7
                                text: ":"
                                color: root.clockShadowColor
                                opacity: colonText.opacity
                                font.family: root.fontFamily
                                font.pixelSize: Math.round(root.clockFontSize * 0.90)
                                font.weight: Font.Bold
                            }

                            Text {
                                id: colonText
                                text: ":"
                                color: root.clockAccentColor
                                font.family: root.fontFamily
                                font.pixelSize: Math.round(root.clockFontSize * 0.90)
                                font.weight: Font.Bold
                                style: Text.Outline
                                styleColor: root.clockOutlineColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }

                                SequentialAnimation on opacity {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.65; duration: 1000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                                }
                            }
                        }

                        Item {
                            implicitWidth: minuteText.implicitWidth
                            implicitHeight: minuteText.implicitHeight

                            Text {
                                x: 0
                                y: 7
                                text: root.currentMinute
                                color: root.clockShadowColor
                                font.family: root.fontFamily
                                font.pixelSize: root.clockFontSize
                                font.weight: Font.Bold
                                font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                            }

                            Text {
                                id: minuteText
                                text: root.currentMinute
                                color: root.clockDigitColor
                                font.family: root.fontFamily
                                font.pixelSize: root.clockFontSize
                                font.weight: Font.Bold
                                font.letterSpacing: -Math.round(root.clockFontSize * 0.025)
                                style: Text.Outline
                                styleColor: root.clockOutlineColor

                                Behavior on font.pixelSize {
                                    enabled: root.animEnabled && !resizeArea.isResizing && !resizeArea.committing
                                    NumberAnimation {
                                        duration: animStyle.morphDuration
                                        easing.type: animStyle.expoEasing
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }
                        }

                        Item {
                            implicitWidth: periodText.implicitWidth
                            implicitHeight: periodText.implicitHeight
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: Math.round(root.clockFontSize * 0.19)
                            Layout.leftMargin: 6

                            Text {
                                x: 0
                                y: 3
                                text: root.currentPeriod
                                color: root.clockShadowColor
                                font.family: root.fontFamily
                                font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.12))
                                font.weight: Font.Black
                                font.letterSpacing: 1.4
                            }

                            Text {
                                id: periodText
                                text: root.currentPeriod
                                color: root.clockAccentColor
                                font.family: root.fontFamily
                                font.pixelSize: Math.max(20, Math.round(root.clockFontSize * 0.12))
                                font.weight: Font.Black
                                font.letterSpacing: 1.4
                                style: Text.Outline
                                styleColor: root.clockOutlineColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: depthMaskLayer
                z: 2
                anchors.fill: parent

                property int activeBuffer: 0
                property bool hasAnyMask: false

                function loadNewSource(src) {
                    if (!src || src === "") {
                        hasAnyMask = false
                        maskImgA.source = ""
                        maskImgB.source = ""
                        return
                    }
                    if (activeBuffer === 0) {
                        maskImgB.source = src
                    } else {
                        maskImgA.source = src
                    }
                }

                Connections {
                    target: root
                    function onDepthMaskSourceChanged() {
                        depthMaskLayer.loadNewSource(root.depthMaskSource)
                    }
                }

                Component.onCompleted: {
                    if (root.depthMaskSource !== "") {
                        loadNewSource(root.depthMaskSource)
                    }
                }

                opacity: (root.depthEnabled && hasAnyMask) ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                Image {
                    id: maskImgA
                    anchors.fill: parent
                    sourceSize.width: clockWindow.width
                    sourceSize.height: clockWindow.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    cache: false
                    visible: depthMaskLayer.activeBuffer === 0 && status === Image.Ready

                    onStatusChanged: {
                        if (status === Image.Ready && source.toString() !== "") {
                            depthMaskLayer.activeBuffer = 0
                            depthMaskLayer.hasAnyMask = true
                            maskImgB.source = ""
                        }
                    }
                }

                Image {
                    id: maskImgB
                    anchors.fill: parent
                    sourceSize.width: clockWindow.width
                    sourceSize.height: clockWindow.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    cache: false
                    visible: depthMaskLayer.activeBuffer === 1 && status === Image.Ready

                    onStatusChanged: {
                        if (status === Image.Ready && source.toString() !== "") {
                            depthMaskLayer.activeBuffer = 1
                            depthMaskLayer.hasAnyMask = true
                            maskImgA.source = ""
                        }
                    }
                }
            }

            Rectangle {
                id: resizeBadge
                z: 3
                x: Math.min(clockWindow.width - width - 12, clockContainer.x + clockContainer.width * resizeArea.smoothScale - width - 12)
                y: Math.min(clockWindow.height - height - 12, clockContainer.y + clockContainer.height * resizeArea.smoothScale - height - 34)
                height: 26
                width: resizeBadgeRow.implicitWidth + 18
                radius: 13
                color: Qt.rgba(0.05, 0.055, 0.07, 0.88)
                border.width: 1
                border.color: root.themePrimary
                opacity: resizeArea.isResizing ? 1.0 : 0.0
                visible: opacity > 0.01
                antialiasing: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.microDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                RowLayout {
                    id: resizeBadgeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "󰩨"
                        color: root.themePrimary
                        font.family: root.iconFontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: Math.round(resizeArea.startFontSize * resizeArea.smoothScale) + "px"
                        color: root.themeText
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
            }

            Rectangle {
                id: depthHoverToggle
                z: 3
                anchors.horizontalCenter: clockContainer.horizontalCenter
                anchors.bottom: clockContainer.bottom
                anchors.bottomMargin: 6
                height: 32
                width: depthToggleRow.implicitWidth + 24
                radius: 16
                color: Qt.rgba(0.05, 0.055, 0.07, 0.88)
                border.width: 1
                border.color: (depthToggleMouse.containsMouse || modeBtnMouse.containsMouse || depthSliderMouse.containsMouse || depthSliderMouse.pressed)
                              ? root.themePrimary
                              : Qt.alpha(root.themePrimary, 0.45)
                opacity: (root.controlsVisible && !dragArea.drag.active && !resizeArea.isResizing && !resizeArea.isHoldingLeft) ? 1.0 : 0.0
                visible: opacity > 0.01
                antialiasing: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: root.animEnabled ? animStyle.fadeDuration : 0
                        easing.type: animStyle.smoothEasing
                    }
                }

                RowLayout {
                    id: depthToggleRow
                    anchors.centerIn: parent
                    spacing: 10

                    RowLayout {
                        spacing: 6

                        Text {
                            text: root.depthEngineStatus === "processing" ? "󰑐" : (root.depthEnabled ? "󰌨" : "󰌩")
                            color: root.depthEnabled ? root.themePrimary : root.themeTextMuted
                            font.family: root.iconFontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            text: root.depthEnabled ? "Depth: On" : "Depth: Off"
                            color: root.depthEnabled ? root.themeText : root.themeTextMuted
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: depthToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.depthEnabled = !root.depthEnabled
                                root.saveClockConfig()
                            }
                        }
                    }

                    Rectangle {
                        visible: root.depthEnabled
                        width: 1
                        height: 14
                        color: Qt.rgba(255, 255, 255, 0.16)
                    }

                    RowLayout {
                        visible: root.depthEnabled
                        spacing: 5

                        Text {
                            text: root.depthMode === "auto" ? "󰁨" : (root.depthMode === "depth" ? "󰋫" : "󰆞")
                            color: root.themePrimary
                            font.family: root.iconFontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            text: root.depthMode === "auto"
                                  ? ("Auto · " + (root.resolvedDepthMode === "subject" ? "Subj" : "3D"))
                                  : (root.depthMode === "depth" ? "3D Depth" : "Subject")
                            color: root.themeText
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: modeBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleDepthMode()
                        }
                    }

                    Rectangle {
                        visible: root.depthEnabled
                        width: 1
                        height: 14
                        color: Qt.rgba(255, 255, 255, 0.16)
                    }

                    RowLayout {
                        visible: root.depthEnabled
                        spacing: 7

                        Item {
                            id: depthSliderTrack
                            width: 82
                            height: 18

                            property real ratio: Math.max(0.0, Math.min(1.0, (root.depthThreshold - 0.08) / 0.84))

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 5
                                radius: 2.5
                                color: Qt.rgba(255, 255, 255, 0.16)
                                antialiasing: true

                                Rectangle {
                                    width: parent.width * depthSliderTrack.ratio
                                    height: parent.height
                                    radius: 2.5
                                    color: root.themePrimary
                                    antialiasing: true
                                }
                            }

                            Rectangle {
                                x: Math.max(0, Math.min(parent.width - width, parent.width * depthSliderTrack.ratio - width * 0.5))
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                radius: 6
                                color: "#FFFFFF"
                                border.width: 2
                                border.color: root.themePrimary
                                scale: depthSliderMouse.pressed ? 1.2 : (depthSliderMouse.containsMouse ? 1.1 : 1.0)
                                antialiasing: true

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: root.animEnabled ? animStyle.scaleDuration : 0
                                        easing.type: animStyle.smoothEasing
                                    }
                                }
                            }

                            MouseArea {
                                id: depthSliderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor

                                function updateFromMouse(mx) {
                                    let r = Math.max(0.0, Math.min(1.0, mx / width))
                                    root.depthThreshold = Number((0.08 + r * 0.84).toFixed(2))
                                    if (root.depthMode !== "depth") {
                                        root.depthMode = "depth"
                                    }
                                    depthSliceDebounce.restart()
                                }

                                onPressed: mouse => updateFromMouse(mouse.x)
                                onPositionChanged: mouse => {
                                    if (pressed) updateFromMouse(mouse.x)
                                }
                                onReleased: {
                                    depthSliceDebounce.stop()
                                    root.syncWallpaperDepth(false)
                                    root.saveClockConfig()
                                }
                            }
                        }

                        Text {
                            text: Math.round(root.depthThreshold * 100) + "%"
                            color: root.themeTextMuted
                            font.family: root.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            Layout.preferredWidth: 28
                        }
                    }
                }
            }
        }
    }
}