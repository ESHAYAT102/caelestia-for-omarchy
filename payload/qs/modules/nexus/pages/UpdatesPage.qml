pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.modules.nexus.common

PageBase {
    id: root

    property var updates: []
    property bool omarchyUpdateAvailable
    property bool loading
    readonly property Process updateProcess: Process {
        command: ["bash", "-lc", "set +e; omarchy_available=false; omarchy update available >/dev/null 2>&1 && omarchy_available=true; { checkupdates 2>/dev/null | awk '{print $1 \"\\t\" $2 \"\\t\" $4 \"\\trepo\"}'; yay -Qua 2>/dev/null | awk '{print $1 \"\\t\" $2 \"\\t\" $4 \"\\tAUR\"}'; } | sort -u; printf '__OMARCHY__\\t%s\\n' \"$omarchy_available\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                let available = false;
                for (const line of text.trim().split("\n")) {
                    if (!line)
                        continue;
                    const parts = line.split("\t");
                    if (parts[0] === "__OMARCHY__") {
                        available = parts[1] === "true";
                        continue;
                    }
                    if (parts.length >= 3)
                        rows.push({ name: parts[0], current: parts[1], next: parts[2], source: parts[3] ?? "" });
                }
                root.updates = rows;
                root.omarchyUpdateAvailable = available;
                root.loading = false;
            }
        }
    }

    title: qsTr("Updates")

    function refresh(): void {
        loading = true;
        updateProcess.running = true;
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
            icon: root.omarchyUpdateAvailable ? "system_update" : "check_circle"
            iconLabel.color: Colours.palette.m3onPrimaryContainer
            label.color: Colours.palette.m3onPrimaryContainer
            text: root.omarchyUpdateAvailable ? qsTr("Omarchy update available") : qsTr("Omarchy is up to date")
            subtext: qsTr("Update Omarchy and all system packages")
            trailingIcon: "open_in_new"
            onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
        }

        SectionHeader {
            text: qsTr("Packages (%1)").arg(root.updates.length)
        }

        Repeater {
            model: root.updates

            RowButton {
                required property var modelData
                required property int index
                first: index === 0
                last: index === root.updates.length - 1
                color: index % 2 === 0 ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
                icon: "deployed_code_update"
                iconLabel.color: Colours.palette.m3primary
                label.color: Colours.palette.m3onSurface
                subLabel.color: Colours.palette.m3onSurfaceVariant
                text: modelData.name
                subtext: `${modelData.current} → ${modelData.next}${modelData.source ? ` • ${modelData.source}` : ""}`
            }
        }

        RowButton {
            visible: !root.loading && root.updates.length === 0
            first: true
            last: true
            icon: "check_circle"
            text: qsTr("All packages are up to date")
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
