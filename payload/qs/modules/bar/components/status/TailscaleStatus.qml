pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

MaterialIcon {
    id: root

    property bool connected
    property color colour: Colours.palette.m3secondary

    text: "device_hub"
    color: connected ? colour : Colours.palette.m3outline
    fontStyle: Tokens.font.icon.medium
    fill: connected ? 1 : 0

    Component.onCompleted: statusProcess.running = true

    Process {
        id: statusProcess
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.connected = JSON.parse(text).BackendState === "Running"; }
                catch (error) { root.connected = false; }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }
}
