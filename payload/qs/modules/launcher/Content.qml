pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge
    readonly property string clipboardPreviewPath: list.currentList?.selectedImagePath ?? ""

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + search.anchors.bottomMargin

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: search.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight - search.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    Item {
        id: clipboardPreview

        readonly property real previewWidth: root.width * 0.9

        anchors.left: parent.right
        anchors.leftMargin: Tokens.spacing.large
        anchors.bottom: parent.bottom
        implicitWidth: root.clipboardPreviewPath.length > 0 ? previewWidth : 0
        implicitHeight: root.clipboardPreviewPath.length > 0 ? Math.round(previewWidth * 9 / 16) : 0
        opacity: root.clipboardPreviewPath.length > 0 ? 1 : 0
        scale: root.clipboardPreviewPath.length > 0 ? 1 : 0.96
        visible: opacity > 0

        Behavior on opacity {
            Anim { type: Anim.DefaultEffects }
        }
        Behavior on scale {
            Anim { type: Anim.DefaultEffects }
        }

        Elevation {
            anchors.fill: panel
            radius: panel.radius
            level: 3
        }

        StyledClippingRect {
            id: panel
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            CachingImage {
                anchors.fill: parent
                path: root.clipboardPreviewPath
            }
        }
    }

    SearchBar {
        id: search

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: qsTr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

        onAccepted: {
            if (list.showUnlocks) {
                list.currentList?.activate();
                return;
            }
            if (list.showEmojis) {
                list.currentList?.activate(false);
                return;
            }
            if (list.showClipboard || list.showKeybindings) {
                list.currentList?.activate();
                return;
            }
            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (currentItem.modelData?.commandMenu) {
                    search.text = GlobalConfig.launcher.actionPrefix;
                } else if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                    if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.screenState.launcher = false;
                }
            }
        }

        Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
        Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onPressed: event => {
            if (list.showClipboard) {
                if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
                    list.currentList?.clearHistory();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete && event.modifiers & Qt.ControlModifier) {
                    list.currentList?.deleteEntry(list.currentList?.currentItem?.modelData ?? null);
                    event.accepted = true;
                }
                return;
            }
            if (list.showEmojis) {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.modifiers & Qt.ShiftModifier) {
                    list.currentList?.activate(true);
                    event.accepted = true;
                }
                return;
            }
            if (list.showKeybindings)
                return;
            if (list.showUnlocks) {
                if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
                    event.accepted = true;
                }
                return;
            }
            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()

        Connections {
            function onLauncherChanged(): void {
                if (!root.screenState.launcher)
                    search.text = "";
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }
    }
}
