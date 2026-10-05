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

    // After an update run, re-check every minute until the list clears so
    // the indicator drops back without reopening the popout.
    property bool watching: false
    property int watchPolls: 0

    function refresh(): void {
        if (checkProcess.running)
            return;
        loading = true;
        checkProcess.running = true;
    }

    function noteUpdateRun(): void {
        watching = true;
        watchPolls = 0;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: watchTimer
        interval: 60000
        running: root.watching && root.count > 0
        repeat: true
        onTriggered: {
            root.watchPolls += 1;
            if (root.watchPolls > 20)
                root.watching = false;
            else
                root.refresh();
        }
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
                if (root.updates.length === 0)
                    root.watching = false;
            }
        }
    }
}
