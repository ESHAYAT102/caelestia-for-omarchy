pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property int pending

    implicitWidth: pending > 0 ? icon.implicitHeight + Tokens.padding.small : 0
    implicitHeight: icon.implicitHeight
    visible: pending > 0

    Component.onCompleted: refreshTimer.triggered()

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
    }

    MaterialIcon {
        id: icon
        anchors.centerIn: parent
        text: "deployed_code"
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }

    Timer {
        id: refreshTimer
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateProcess.running = true
    }

    Process {
        id: updateProcess
        command: ["bash", "-lc", "qs -p /usr/share/omarchy/shell ipc call gennaro.updater query 2>/dev/null || printf '{\"pending\":0}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.pending = JSON.parse(text).pending ?? 0; }
                catch (error) { root.pending = 0; }
            }
        }
    }
}
