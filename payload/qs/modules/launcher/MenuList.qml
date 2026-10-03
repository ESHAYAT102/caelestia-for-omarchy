pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.services

// The Omarchy menu, typed with ":". Rows come from MenuService, which reads
// the menu with Omarchy's own engine, so search order, guards and routes stay
// whatever the installed Omarchy ships. Ported from omacale.
StyledListView {
    id: root

    required property SearchBar search
    required property var screenState

    // A submenu says where ":" is in the tree; picking one drops the query
    // and keeps the mode, so the prefix alone is the submenu's root.
    function activateRow(row: var): void {
        if (!row || row.disabled)
            return;
        if (row.kind === "menu" || row.kind === "link") {
            MenuService.go(row.target || row.itemId, true);
            search.text = MenuService.menuPrefix;
            currentIndex = 0;
            return;
        }
        if (row.kind === "app") {
            const entry = DesktopEntries.byId(row.appId);
            if (entry)
                Apps.launch(entry);
        } else {
            MenuService.run(row.action);
        }
        screenState.launcher = false;
    }

    function activate(): void {
        activateRow(currentItem?.modelData ?? null);
    }

    function goBack(): void {
        if (search.text !== MenuService.menuPrefix)
            search.text = MenuService.menuPrefix;
        else
            MenuService.back();
        currentIndex = 0;
    }

    model: ScriptModel {
        values: MenuService.rows(MenuService.menuPath, root.search.text.replace(/^:/, ""))
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

    header: Item {
        visible: MenuService.menuPath !== "root"
        width: root.width
        height: visible ? Tokens.sizes.launcher.itemHeight * 0.8 : 0

        StateLayer {
            radius: Tokens.rounding.large
            onClicked: root.goBack()
        }

        MaterialIcon {
            id: backIcon
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_left"
            color: Colours.palette.m3outline
        }

        StyledText {
            anchors.left: backIcon.right
            anchors.leftMargin: Tokens.spacing.small
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: MenuService.pathLabel(MenuService.menuPath)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    delegate: Item {
        id: row
        required property var modelData
        required property int index
        implicitHeight: Tokens.sizes.launcher.itemHeight
        anchors.left: parent?.left
        anchors.right: parent?.right

        // A row whose `disabled:` evaluated true (software already on the
        // machine) reads as listed-but-spent, as in Omarchy's menu.
        opacity: row.modelData?.disabled ? 0.45 : 1

        StateLayer {
            radius: Tokens.rounding.large
            onClicked: root.activateRow(row.modelData)
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            anchors.topMargin: Tokens.padding.small
            anchors.bottomMargin: Tokens.padding.small

            IconImage {
                id: icon
                visible: (row.modelData?.kind === "app" ? row.modelData?.appIcon : "") !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: parent.height * 0.8
                asynchronous: true
                source: {
                    const appIcon = row.modelData?.kind === "app" ? row.modelData?.appIcon : "";
                    return appIcon ? Quickshell.iconPath(appIcon, "image-missing") : "";
                }
            }

            // Menu glyphs are Nerd Font (or whatever `iconFont:` names), not
            // Material Symbols.
            StyledText {
                visible: (row.modelData?.icon ?? "") !== "" && !icon.visible
                anchors.centerIn: icon
                text: row.modelData?.icon ?? ""
                font.family: row.modelData?.iconFont || "monospace"
                color: Colours.palette.m3onSurfaceVariant
            }

            MaterialIcon {
                id: chevron
                visible: row.modelData?.kind === "menu" || row.modelData?.kind === "link"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "chevron_right"
                color: Colours.palette.m3outline
            }

            Column {
                anchors.left: icon.right
                anchors.leftMargin: Tokens.spacing.medium
                anchors.right: chevron.visible ? chevron.left : parent.right
                anchors.verticalCenter: icon.verticalCenter

                StyledText {
                    text: row.modelData?.label ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData?.detail ?? ""
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    Component.onCompleted: {
        MenuService.reset();
        MenuService.open("root");
    }
}
