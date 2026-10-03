pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property var omarchyUpdates: []
    property var repoUpdates: []
    property var aurUpdates: []
    property bool loading
    readonly property var updates: omarchyUpdates.concat(repoUpdates, aurUpdates)

    width: Math.round(Tokens.sizes.bar.networkWidth * 1.35)
    spacing: Tokens.spacing.medium

    function refresh(): void {
        loading = true;
        Quickshell.execDetached(["qs", "-p", "/usr/share/omarchy/shell", "ipc", "call", "gennaro.updater", "refresh"]);
        delay.restart();
    }

    Component.onCompleted: refresh()

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            text: ""
            color: root.updates.length > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font.family: "CaskaydiaCove Nerd Font"
            font.pixelSize: Tokens.font.icon.medium.pointSize
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: root.loading ? qsTr("Checking updates…") : root.updates.length > 0 ? qsTr("%1 updates available").arg(root.updates.length) : qsTr("System is up to date")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

        }
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Tokens.sizes.bar.networkWidth * 1.5)
        contentWidth: width
        contentHeight: updatesColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: updatesColumn
            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: root.updates

                StyledRect {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainer

                    RowLayout {
                        id: row
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "deployed_code_update"
                            color: Colours.palette.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: modelData.name
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: `${modelData.old} → ${modelData.new}`
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        icon: "refresh"
        text: qsTr("Update")
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
    }

    Timer {
        id: delay
        interval: 1200
        onTriggered: queryProcess.running = true
    }

    Process {
        id: queryProcess
        command: ["bash", "-lc", "qs -p /usr/share/omarchy/shell ipc call gennaro.updater query 2>/dev/null || printf '{\"omarchy\":[],\"repo\":[],\"aur\":[]}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.omarchyUpdates = data.omarchy ?? [];
                    root.repoUpdates = data.repo ?? [];
                    root.aurUpdates = data.aur ?? [];
                } catch (error) {
                    root.omarchyUpdates = [];
                    root.repoUpdates = [];
                    root.aurUpdates = [];
                }
                root.loading = false;
            }
        }
    }
}
