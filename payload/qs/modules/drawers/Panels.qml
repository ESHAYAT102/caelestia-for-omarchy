import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.images
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias clipboardPreview: clipboardPreview
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar

    anchors.fill: parent
    anchors.margins: borderThickness
    anchors.leftMargin: bar.implicitWidth

    Item {
        id: osdWrapper
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sessionWrapper.anchors.rightMargin + session.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible
        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd
            screen: root.screen
            screenState: root.screenState
            sidebarOrSessionVisible: sidebar.visible || session.visible
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications
        screenState: root.screenState
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities
        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sidebar.width * (1 - sidebar.offsetScale)
        clip: sidebar.visible
        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session
            screenState: root.screenState
            sidebarVisible: sidebar.visible
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher
        screen: root.screen
        screenState: root.screenState
        panels: root
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Item {
        id: clipboardPreview

        readonly property real cardPadding: Tokens.padding.large
        readonly property real imageWidth: launcher.width * 0.6
        readonly property real fullWidth: imageWidth + cardPadding * 2
        readonly property real fullHeight: Math.round(imageWidth * 9 / 16) + cardPadding
        readonly property bool shown: launcher.clipboardPreviewPath.length > 0
        readonly property bool settled: shown
            && width >= fullWidth - 0.5
            && height >= fullHeight - 0.5
            && opacity >= 0.999
            && scale >= 0.999

        x: launcher.x + launcher.width + Tokens.spacing.large * 4 + (fullWidth - width) / 2
        anchors.bottom: parent.bottom
        width: shown ? fullWidth : 0
        height: shown ? fullHeight : 0
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.92
        visible: opacity > 0
        transformOrigin: Item.Bottom

        Behavior on width { Anim { type: Anim.Standard } }
        Behavior on height { Anim { type: Anim.Standard } }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on scale { Anim { type: Anim.DefaultEffects } }

        StyledClippingRect {
            id: previewContent

            anchors.fill: parent
            anchors.leftMargin: clipboardPreview.cardPadding
            anchors.rightMargin: clipboardPreview.cardPadding
            anchors.topMargin: clipboardPreview.cardPadding
            anchors.bottomMargin: 0
            radius: Tokens.rounding.large
            opacity: clipboardPreview.settled ? 1 : 0

            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            CachingImage {
                anchors.fill: parent
                path: launcher.clipboardPreviewPath
                fillMode: Image.PreserveAspectCrop
            }
        }
    }

    Dashboard.Wrapper {
        id: dashboard
        screenState: root.screenState
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper
        screen: root.screen
        borderThickness: root.borderThickness
    }

    Utilities.Wrapper {
        id: utilities
        screenState: root.screenState
        sidebar: sidebar
        popouts: popoutsWrapper.content
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts
        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Tokens.padding.medium
    }

    Sidebar.Wrapper {
        id: sidebar
        screenState: root.screenState
        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.topMargin: -notifications.anchors.topMargin
    }
}
