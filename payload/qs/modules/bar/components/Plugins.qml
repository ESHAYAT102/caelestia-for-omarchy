pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var bar
    property var plugins: []

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    Component.onCompleted: loadProcess.running = true

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            const popouts = root.bar.popouts;
            if (popouts.hasCurrent && popouts.currentName === "pinnedplugins")
                popouts.close();
            else {
                popouts.currentName = "pinnedplugins";
                popouts.currentCenter = Qt.binding(() => root.mapToItem(root.bar, 0, root.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        }
    }

    MaterialIcon {
        id: icon
        anchors.centerIn: parent
        text: "extension"
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }

    Process {
        id: loadProcess
        command: ["bash", "-lc", "file=\"$HOME/.config/caelestia/pinned-plugins.json\"; test -r \"$file\" && cat \"$file\" || printf '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.plugins = JSON.parse(text); }
                catch (error) { root.plugins = []; }
            }
        }
    }
}
