pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var plugins: []
    property var pinnedIds: []
    property bool loading
    readonly property Process listProcess: Process {
        command: ["omarchy", "plugin", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.plugins = JSON.parse(text).sort((a, b) => a.name.localeCompare(b.name));
                } catch (error) {
                    root.plugins = [];
                }
                root.loading = false;
            }
        }
    }
    readonly property Process actionProcess: Process {
        onExited: root.refresh()
    }
    readonly property Process pinProcess: Process {
        command: ["bash", "-lc", "file=\"$HOME/.config/caelestia/pinned-plugins.json\"; test -r \"$file\" && jq -c '[.[].id]' \"$file\" || printf '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.pinnedIds = JSON.parse(text); }
                catch (error) { root.pinnedIds = []; }
            }
        }
    }
    readonly property Process savePinsProcess: Process {}

    title: qsTr("Plugins")

    function refresh(): void {
        loading = true;
        pinProcess.running = true;
        listProcess.running = true;
    }

    function isPinnable(plugin: var): bool {
        return plugin.enabled && plugin.kinds.includes("bar-widget");
    }

    function togglePin(plugin: var): void {
        const next = pinnedIds.slice();
        const index = next.indexOf(plugin.id);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(plugin.id);
        pinnedIds = next;
        savePinsProcess.command = ["python", "-c", "import json,sys; plugins=json.loads(sys.argv[1]); ids=json.loads(sys.argv[2]); rows=[{'id':p['id'],'name':p['name']} for p in plugins if p['id'] in ids]; open(sys.argv[3],'w').write(json.dumps(rows,ensure_ascii=False)+'\\n')", JSON.stringify(plugins), JSON.stringify(next), `${Quickshell.env("HOME")}/.config/caelestia/pinned-plugins.json`];
        savePinsProcess.running = true;
    }

    function trigger(plugin: var): void {
        Quickshell.execDetached(["omarchy-shell", "shell", "toggle", plugin.id]);
    }

    function setEnabled(plugin: var, enabled: bool): void {
        actionProcess.command = ["omarchy", "plugin", enabled ? "enable" : "disable", plugin.id];
        actionProcess.running = true;
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Omarchy plugins (%1)").arg(root.plugins.length)
        }

        Repeater {
            model: root.plugins

            ConnectedRect {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2
                color: index % 2 === 0 ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
                first: index === 0
                last: index === root.plugins.length - 1

                StateLayer {
                    onClicked: root.trigger(row.modelData)
                }

                RowLayout {
                    id: layout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: row.modelData.firstParty ? "verified" : "extension"
                        color: Colours.palette.m3primary
                    }

                    Column {
                        Layout.fillWidth: true

                        StyledText {
                            width: parent.width
                            text: row.modelData.name
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: `${row.modelData.id} • ${row.modelData.kinds.join(", ")}`
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        visible: root.isPinnable(row.modelData)
                        icon: root.pinnedIds.includes(row.modelData.id) ? "keep_off" : "keep"
                        type: IconButton.Tonal
                        isRound: true
                        onClicked: root.togglePin(row.modelData)
                    }

                    StyledSwitch {
                        checked: row.modelData.enabled
                        enabled: row.modelData.canDisable || !row.modelData.enabled
                        onToggled: root.setEnabled(row.modelData, checked)
                    }
                }
            }
        }

        RowButton {
            first: true
            last: true
            icon: "refresh"
            text: root.loading ? qsTr("Loading plugins…") : qsTr("Refresh plugins")
            disabled: root.loading
            onClicked: root.refresh()
        }

        RowButton {
            first: true
            last: true
            icon: "update"
            text: qsTr("Update installed plugins")
            onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-plugin-update", "--yes"])
        }
    }

}
