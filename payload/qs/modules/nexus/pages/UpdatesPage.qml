pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var omarchyUpdates: []
    property var repoUpdates: []
    property var aurUpdates: []
    property bool loading
    property string lastScan
    readonly property int totalPending: omarchyUpdates.length + repoUpdates.length + aurUpdates.length
    readonly property Timer refreshDelay: Timer {
        interval: 1200
        onTriggered: updateProcess.running = true
    }
    readonly property Process updateProcess: Process {
        command: ["bash", "-lc", "qs -p /usr/share/omarchy/shell ipc call gennaro.updater query 2>/dev/null || /home/$USER/.config/omarchy/plugins/gennaro.updater/collect-updates.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.omarchyUpdates = data.omarchy ?? [];
                    root.repoUpdates = data.repo ?? [];
                    root.aurUpdates = data.aur ?? [];
                    root.lastScan = data.lastScan ?? "";
                } catch (error) {
                    root.omarchyUpdates = [];
                    root.repoUpdates = [];
                    root.aurUpdates = [];
                }
                root.loading = false;
            }
        }
    }

    title: qsTr("Updates")

    function refresh(): void {
        loading = true;
        Quickshell.execDetached(["qs", "-p", "/usr/share/omarchy/shell", "ipc", "call", "gennaro.updater", "refresh"]);
        refreshDelay.restart();
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Omarchy")
        }

        RowButton {
            first: true
            last: true
            color: Colours.tPalette.m3primaryContainer
            icon: root.omarchyUpdates.length > 0 ? "system_update" : "check_circle"
            iconLabel.color: Colours.palette.m3onPrimaryContainer
            label.color: Colours.palette.m3onPrimaryContainer
            text: root.omarchyUpdates.length > 0 ? qsTr("Omarchy update available") : qsTr("Omarchy is up to date")
            subtext: qsTr("Update Omarchy and all system packages")
            trailingIcon: "open_in_new"
            onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
        }

        SectionHeader {
            text: qsTr("Repository packages (%1)").arg(root.repoUpdates.length)
        }

        Repeater {
            model: root.repoUpdates

            RowButton {
                required property var modelData
                required property int index
                first: index === 0
                last: index === root.repoUpdates.length - 1
                color: index % 2 === 0 ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
                icon: "deployed_code_update"
                iconLabel.color: Colours.palette.m3primary
                label.color: Colours.palette.m3onSurface
                subLabel.color: Colours.palette.m3onSurfaceVariant
                text: modelData.name
                subtext: `${modelData.old} → ${modelData.new}`
            }
        }

        RowButton {
            visible: !root.loading && root.totalPending === 0
            first: true
            last: true
            icon: "check_circle"
            text: qsTr("All packages are up to date")
        }

        SectionHeader {
            visible: root.aurUpdates.length > 0
            text: qsTr("AUR packages (%1)").arg(root.aurUpdates.length)
        }

        Repeater {
            model: root.aurUpdates

            RowButton {
                required property var modelData
                required property int index
                first: index === 0
                last: index === root.aurUpdates.length - 1
                color: index % 2 === 0 ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
                icon: "deployed_code_update"
                iconLabel.color: Colours.palette.m3tertiary
                label.color: Colours.palette.m3onSurface
                subLabel.color: Colours.palette.m3onSurfaceVariant
                text: modelData.name
                subtext: `${modelData.old} → ${modelData.new}`
            }
        }

        RowButton {
            first: true
            last: true
            icon: "refresh"
            text: root.loading ? qsTr("Checking for updates…") : qsTr("Check again")
            disabled: root.loading
            onClicked: root.refresh()
        }
    }

}
