pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.images
import qs.services

StyledListView {
    id: root

    required property SearchBar search
    required property var screenState

    property var entries: []
    property int selected: 0
    property int historyRevision: 0

    function loadHistory(): void {
        historyProcess.running = true;
    }

    function activate(): void {
        copyEntry(currentItem?.modelData ?? null);
    }

    function copyEntry(entry: var): void {
        if (!entry)
            return;
        if (entry.type === "image")
            Quickshell.execDetached(["omarchy-clipboard-paste-file", "--copy-only", entry.mime, entry.path]);
        else
            Quickshell.execDetached(["omarchy-clipboard-paste-text", "--copy-only", "--history-index", String(entry.index)]);
        screenState.launcher = false;
    }

    function deleteEntry(entry: var): void {
        if (!entry)
            return;
        const file = Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json";
        deleteProcess.command = ["python", "-c", "import json,sys; p=sys.argv[1]; i=int(sys.argv[2]); d=json.load(open(p)); d.pop(i,None); open(p,'w').write(json.dumps(d,ensure_ascii=False)+'\\n')", file, String(entry.index)];
        deleteProcess.running = true;
    }

    function clearHistory(): void {
        const file = Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json";
        deleteProcess.command = ["python", "-c", "import sys; open(sys.argv[1],'w').write('[]\\n')", file];
        deleteProcess.running = true;
        Quickshell.execDetached(["bash", "-lc", "rm -f \"$HOME/.local/state/omarchy/clipboard-images\"/*"]);
    }

    model: ScriptModel {
        values: {
            root.historyRevision;
            const query = root.search.text.replace(/^>clipboard\s*/, "").trim().toLowerCase();
            return root.entries.map(entry => ({
                index: entry.index,
                type: entry.type,
                title: entry.title,
                mime: entry.mime,
                path: entry.path
            })).filter(entry => !query || entry.title.toLowerCase().includes(query));
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

        Behavior on y {
            Anim {}
        }
    }

    onCurrentIndexChanged: selected = currentIndex

    delegate: Item {
        id: row
        required property var modelData
        required property int index
        implicitHeight: row.modelData.type === "image" ? Tokens.sizes.launcher.itemHeight * 2 : Tokens.sizes.launcher.itemHeight
        anchors.left: parent?.left
        anchors.right: parent?.right

        StateLayer {
            radius: Tokens.rounding.large
            onClicked: root.copyEntry(row.modelData)
        }

        CachingImage {
            id: imagePreview
            visible: row.modelData.type === "image"
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - Tokens.padding.medium * 2
            height: width
            path: row.modelData.path
        }

        MaterialIcon {
            id: icon
            visible: row.modelData.type !== "image"
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: "content_paste"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            anchors.left: row.modelData.type === "image" ? imagePreview.right : icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: deleteIcon.left
            anchors.rightMargin: Tokens.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.type === "image" ? qsTr("Image") : row.modelData.title
            font: Tokens.font.body.medium
            elide: Text.ElideRight
        }

        MaterialIcon {
            id: deleteIcon
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: "delete"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                anchors.fill: parent
                onClicked: root.deleteEntry(row.modelData)
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
            root.clearHistory();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete) {
            root.deleteEntry(currentItem?.modelData ?? null);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.copyEntry(currentItem?.modelData ?? null);
            event.accepted = true;
        }
    }

    Component.onCompleted: loadHistory()

    Process {
        id: historyProcess
        command: ["python", "-c", "import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps([{'index':i,'type':x.get('type','text'),'title':(' '.join((x.get('text','') if x.get('type')=='text' else '[Image]').split())[:120]),'mime':x.get('mime','image/png'),'path':x.get('path','')} for i,x in enumerate(d) if x.get('type')=='image' or (x.get('type')=='text' and isinstance(x.get('text'),str))]))", Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.entries = parsed.map((entry, position) => ({
                        index: entry.index,
                        position,
                        type: entry.type,
                        title: entry.title,
                        mime: entry.mime,
                        path: entry.path
                    }));
                    root.historyRevision++;
                } catch (error) {
                    root.entries = [];
                }
            }
        }
    }

    Process {
        id: deleteProcess
        onExited: root.loadHistory()
    }
}
