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
            width: parent.width * 0.42
            text: row.modelData.action
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
            elide: Text.ElideRight
        }

        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.47
            horizontalAlignment: Text.AlignRight
            text: row.modelData.key
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    Component.onCompleted: loadProcess.running = true

    Process {
        id: loadProcess
        // The Omarchy menu scans the Lua config to reconstruct binds, which can
        // hang on newer workspace modules. Hyprland already exposes live binds.
        command: ["hyprctl", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set();
                const entries = [];
                for (const block of text.split(/\n\s*\n/)) {
                    const key = block.match(/^\s*key: (.*)$/m)?.[1];
                    const action = block.match(/^\s*description: (.*)$/m)?.[1];
                    const modmask = Number(block.match(/^\s*modmask: (\d+)$/m)?.[1] ?? 0);
                    if (!key || !action)
                        continue;

                    // Hyprland spells digit-row binds as code:10 through code:19.
                    const displayKey = key.replace(/code:(1[0-9])\b/g, (_, code) =>
                        String((Number(code) - 9) % 10));
                    // Some Lua binds already contain their modifiers in `key`;
                    // the rest carry them only in `modmask`.
                    const modifiers = [
                        [64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]
                    ].filter(([mask]) => modmask & mask).map(([, name]) => name);
                    const chord = /^(?:SUPER|CTRL|ALT|SHIFT)\s*\+/.test(displayKey)
                        ? displayKey : [...modifiers, displayKey].join(" + ");
                    const id = `${chord}\t${action}`;
                    if (!seen.has(id)) {
                        seen.add(id);
                        entries.push({ key: chord, action });
                    }
                }
                root.bindings = entries.sort((a, b) => a.action.localeCompare(b.action));
            }
        }
    }
}
