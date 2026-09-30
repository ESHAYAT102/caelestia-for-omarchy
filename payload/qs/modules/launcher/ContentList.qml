pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    required property SearchBar search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `)
    readonly property bool showUnlocks: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}unlock `)
    readonly property bool showClipboard: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}clipboard`)
    readonly property bool showKeybindings: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}keybindings`)
    readonly property bool showEmojis: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}emoji`)
    readonly property bool showSpecialList: showWallpapers || showUnlocks
    readonly property var currentList: showSpecialList ? specialList.item : showClipboard ? clipboardList.item : showKeybindings ? keybindingsList.item : showEmojis ? emojiList.item : appList.item
    property string animState: showWallpapers ? "wallpapers" : showUnlocks ? "unlocks" : showClipboard ? "clipboard" : showKeybindings ? "keybindings" : showEmojis ? "emojis" : "apps"

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: animState

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
                appList.active: true
                clipboardList.active: false
                keybindingsList.active: false
                emojiList.active: false
                specialList.active: false
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, specialList.implicitWidth)
                root.implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight
                specialList.active: true
                clipboardList.active: false
                keybindingsList.active: false
                emojiList.active: false
                appList.active: false
            }
        },
        State {
            name: "unlocks"

            PropertyChanges {
                root.implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, specialList.implicitWidth)
                root.implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight
                specialList.active: true
                clipboardList.active: false
                keybindingsList.active: false
                emojiList.active: false
                appList.active: false
            }
        },
        State {
            name: "clipboard"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, clipboardList.implicitHeight)
                clipboardList.active: true
                keybindingsList.active: false
                emojiList.active: false
                appList.active: false
                specialList.active: false
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "keybindings"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, keybindingsList.implicitHeight)
                keybindingsList.active: true
                emojiList.active: false
                clipboardList.active: false
                appList.active: false
                specialList.active: false
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "emojis"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, emojiList.implicitHeight)
                emojiList.active: true
                keybindingsList.active: false
                clipboardList.active: false
                appList.active: false
                specialList.active: false
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        }
    ]

    Behavior on animState {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: appList

        active: false
        anchors.fill: parent

        sourceComponent: AppList {
            objectName: "launcherAppList"
            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: clipboardList

        active: false
        anchors.fill: parent
        sourceComponent: ClipboardList {
            objectName: "launcherClipboardList"
            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: keybindingsList

        active: false
        anchors.fill: parent
        sourceComponent: KeybindingsList {
            objectName: "launcherKeybindingsList"
            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: emojiList

        active: false
        anchors.fill: parent
        sourceComponent: EmojiList {
            objectName: "launcherEmojiList"
            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: specialList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: root.showWallpapers ? wallpaperComponent : unlockComponent
    }

    Component {
        id: wallpaperComponent

        WallpaperList {
            objectName: "launcherWallpaperList"

            search: root.search
            screenState: root.screenState
            panels: root.panels
            content: root.content
        }
    }

    Component {
        id: unlockComponent

        UnlockList {
            objectName: "launcherUnlockList"
            search: root.search
            screenState: root.screenState
        }
    }

    Row {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: root.showSpecialList ? "wallpaper_slideshow" : "manage_search"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.state === "wallpapers" ? qsTr("No wallpapers found") : root.state === "unlocks" ? qsTr("No unlock screens found") : qsTr("No results")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: root.state === "wallpapers" && Wallpapers.list.length === 0 ? qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : root.state === "unlocks" ? qsTr("No matching Omarchy unlock screen") : qsTr("Try searching for something else")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.screenState.launcher

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.screenState.launcher

        Anim {}
    }
}
