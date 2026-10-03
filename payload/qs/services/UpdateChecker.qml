pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared pending-update state for the taskbar indicator and the updates
// popout. Queries the package managers directly (pacman, AUR, flatpak,
// mise) instead of Omarchy's updater plugin, which is unavailable in
// Caelestia mode.
Singleton {
    id: root

    property var updates: []
    property bool loading: false
    readonly property int count: updates.length

    function refresh(): void {
        if (checkProcess.running)
            return;
        loading = true;
        checkProcess.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: checkProcess
        command: ["caelestia-check-updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.updates = JSON.parse(text);
                } catch (error) {
                    root.updates = [];
                }
                root.loading = false;
            }
        }
    }
}
