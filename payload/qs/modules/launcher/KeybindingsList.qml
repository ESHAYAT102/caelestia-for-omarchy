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
    property var bindings: []

    function activate(): void {}

    model: ScriptModel {
        values: {
            const query = root.search.text.replace(/^>keybindings\s*/, "").trim().toLowerCase();
            return root.bindings.filter(binding => !query || binding.key.toLowerCase().includes(query) || binding.action.toLowerCase().includes(query));
        }
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

        MaterialIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: "keyboard"
            color: Colours.palette.m3primary
        }

        StyledText {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.key
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
        }

        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.52
            horizontalAlignment: Text.AlignRight
            text: row.modelData.action
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    Component.onCompleted: loadProcess.running = true

    Process {
        id: loadProcess
        command: ["bash", "-lc", "omarchy menu keybindings --print | sed -E 's/[[:space:]]+→[[:space:]]+/\\t/' | jq -Rsc 'split(\"\\n\") | map(select(length>0) | split(\"\\t\") | {key:.[0],action:.[1]})'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.bindings = JSON.parse(text); }
                catch (error) { root.bindings = []; }
            }
        }
    }
}
