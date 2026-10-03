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

    required property var bar

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight
    visible: true

    Component.onCompleted: refreshTimer.triggered()

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            const popouts = root.bar.popouts;
            if (popouts.hasCurrent && popouts.currentName === "updates")
                popouts.close();
            else {
                popouts.currentName = "updates";
                popouts.currentCenter = Qt.binding(() => root.mapToItem(root.bar, 0, root.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        }
    }

    StyledText {
        id: icon
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -2
        anchors.verticalCenterOffset: 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: ""
        color: Colours.palette.m3primary
        font.family: "CaskaydiaCove Nerd Font"
        font.pixelSize: Tokens.font.icon.small.pointSize
        font.weight: Font.Bold
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
