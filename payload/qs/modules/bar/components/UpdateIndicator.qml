pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var bar

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight
    visible: true

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            const popouts = root.bar.popouts;
            if (popouts.hasCurrent && popouts.currentName === "updates")
                popouts.close();
            else {
                popouts.currentName = "updates";
                popouts.currentCenter = Qt.binding(() => root.mapToItem(root.bar, 0, root.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        }
    }

    StyledText {
        id: icon
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -2.5
        anchors.verticalCenterOffset: 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: ""
        color: UpdateChecker.count > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.family: "CaskaydiaCove Nerd Font"
        font.pixelSize: Tokens.font.icon.small.pointSize
        font.weight: Font.Bold
    }
}
