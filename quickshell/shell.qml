import QtQuick
import Quickshell

ShellRoot {
    Loader {
        source: "topbar/shell.qml"
    }

    Loader {
        source: "dock/shell.qml"
    }

    Loader {
        source: "desktop/shell.qml"
    }

    Loader {
        source: "player/shell.qml"
    }

    Loader {
        source: "brightness/shell.qml"
    }

    Loader {
        source: "volume/shell.qml"
    }

    Loader {
        source: "notification/shell.qml"
    }
}