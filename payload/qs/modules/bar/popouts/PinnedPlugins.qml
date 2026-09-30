pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    property var plugins: []

    implicitWidth: Tokens.sizes.bar.networkWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    Component.onCompleted: loadProcess.running = true

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Pinned plugins")
            font: Tokens.font.body.medium
        }

        Repeater {
            model: root.plugins

            IconTextButton {
                required property var modelData
                Layout.fillWidth: true
                icon: "extension"
                text: modelData.name
                inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "toggle", modelData.id])
            }
        }

        StyledText {
            visible: root.plugins.length === 0
            text: qsTr("Pin enabled bar plugins from Settings → Plugins")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
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
