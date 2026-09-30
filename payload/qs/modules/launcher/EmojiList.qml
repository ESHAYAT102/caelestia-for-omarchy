pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

StyledListView {
    id: root

    required property SearchBar search
    required property var screenState
    property var emojis: []

    function activate(copyOnly: bool): void {
        const emoji = currentItem?.modelData?.emoji;
        if (!emoji)
            return;
        screenState.launcher = false;
        Quickshell.execDetached(["caelestia-emoji", copyOnly ? "copy" : "insert", emoji]);
    }

    model: ScriptModel {
        values: {
            const query = root.search.text.replace(/^>emoji\s*/, "").trim().toLowerCase();
            const output = [];
            for (const item of root.emojis) {
                if (!query || item.keywords.includes(query)) {
                    output.push(item);
                    if (output.length >= 200)
                        break;
                }
            }
            return output;
        }
        onValuesChanged: root.currentIndex = 0
    }

    spacing: Tokens.spacing.small
    orientation: Qt.Vertical
    implicitHeight: count > 0 ? (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing : Tokens.sizes.launcher.itemHeight
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange
    highlightFollowsCurrentItem: false

    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08
        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0
        Behavior on y { Anim {} }
    }

    delegate: Item {
        id: row
        required property var modelData
        implicitHeight: Tokens.sizes.launcher.itemHeight
        anchors.left: parent?.left
        anchors.right: parent?.right

        StateLayer {
            radius: Tokens.rounding.large
            onClicked: {
                root.screenState.launcher = false;
                Quickshell.execDetached(["caelestia-emoji", "insert", row.modelData.emoji]);
            }
        }

        StyledText {
            id: emoji
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.emoji
            font: Tokens.font.body.large
        }

        StyledText {
            anchors.left: emoji.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.keywords
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    Component.onCompleted: loadProcess.running = true

    Process {
        id: loadProcess
        command: ["python", "-c", "import json; d=json.load(open('/usr/share/omarchy/shell/plugins/emojis/emojis.json')); print(json.dumps([{'emoji':x['e'],'keywords':x['k']} for x in d]))"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.emojis = JSON.parse(text); }
                catch (error) { root.emojis = []; }
            }
        }
    }
}
