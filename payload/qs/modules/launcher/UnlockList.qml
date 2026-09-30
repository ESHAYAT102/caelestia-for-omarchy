pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.services

PathView {
    id: root

    required property SearchBar search
    required property var screenState

    readonly property int itemWidth: Tokens.sizes.launcher.wallpaperWidth * 0.8 + Tokens.padding.medium * 2
    readonly property string previewDir: `${Quickshell.env("HOME")}/.cache/omarchy/unlock-selector/previews`
    property var unlocks: []
    property string currentTheme: "default"

    function loadThemes(): void {
        themeProcess.running = true;
    }

    model: ScriptModel {
        values: {
            const query = root.search.text.split(" ").slice(1).join(" ").toLowerCase();
            return root.unlocks.filter(item => !query || item.name.toLowerCase().includes(query));
        }
    }

    Component.onCompleted: {
        currentIndex = 0;
        root.loadThemes();
    }

    implicitWidth: Math.min(count, 7) * itemWidth
    pathItemCount: Math.min(count, 7)
    cacheItemCount: 4
    snapMode: PathView.SnapToItem
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    delegate: Item {
        id: card

        required property var modelData
        required property int index
        function activate(): void { root.selectUnlock(modelData.name); }
        readonly property real imageWidth: Tokens.sizes.launcher.wallpaperWidth

        implicitWidth: imageWidth + Tokens.padding.medium * 2
        implicitHeight: image.height + label.implicitHeight + Tokens.spacing.extraSmall + Tokens.padding.large + Tokens.padding.medium
        scale: PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0
        opacity: PathView.onPath ? 1 : 0
        z: PathView.z ?? 0

        StateLayer {
            radius: Tokens.rounding.large
            onClicked: root.selectUnlock(card.modelData.name)
        }

        StyledClippingRect {
            id: image
            anchors.horizontalCenter: parent.horizontalCenter
            y: Tokens.padding.large
            radius: Tokens.rounding.large
            implicitWidth: card.imageWidth
            implicitHeight: implicitWidth / 16 * 9

            CachingImage {
                anchors.fill: parent
                path: `${root.previewDir}/${card.modelData.name}.png`
            }
        }

        StyledText {
            id: label
            anchors.top: image.bottom
            anchors.topMargin: Tokens.spacing.extraSmall
            anchors.horizontalCenter: parent.horizontalCenter
            width: image.width - Tokens.padding.medium * 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: card.modelData.name
            font: Tokens.font.label.medium
        }
    }

    path: Path {
        startY: root.height / 2
        PathLine { x: root.width / 2; relativeY: 0 }
        PathLine { x: root.width; relativeY: 0 }
    }

    Process {
        id: themeProcess
        command: ["bash", "-lc", "set -e; dir=\"${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/unlock-selector/previews\"; mkdir -p \"$dir\"; ln -sfn \"$OMARCHY_PATH/default/plymouth/preview-unlock.png\" \"$dir/default.png\"; omarchy-plymouth-list | while read -r theme; do ln -sfn \"$(omarchy-theme-dir \"$theme\")/preview-unlock.png\" \"$dir/$theme.png\"; done; printf '%s\\n' default; omarchy-plymouth-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n").filter(name => name.length > 0);
                root.unlocks = names.map(name => ({ name }));
                currentThemeProcess.running = true;
            }
        }
    }

    Process {
        id: currentThemeProcess
        command: ["omarchy-plymouth-current"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentTheme = text.trim() || "default";
                root.currentIndex = Math.max(0, root.unlocks.findIndex(item => item.name === root.currentTheme));
            }
        }
    }

    function activate(): void {
        const theme = currentItem?.modelData?.name;
        if (theme)
            selectUnlock(theme);
    }

    function selectUnlock(theme: string): void {
        Quickshell.execDetached(["caelestia-unlock-set", theme]);
        screenState.launcher = false;
    }
}
