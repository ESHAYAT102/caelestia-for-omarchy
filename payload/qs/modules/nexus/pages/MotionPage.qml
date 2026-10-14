pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    property bool previewOpen: true

    readonly property list<MenuItem> presets: [
        MenuItem { text: qsTr("Subtle") },
        MenuItem { text: qsTr("Balanced") },
        MenuItem { text: qsTr("Bouncy") }
    ]

    title: qsTr("Motion")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledRect {
            id: preview

            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            implicitHeight: 185
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            clip: true

            LiquidOffset {
                id: previewMotion
                target: root.previewOpen ? 0 : 1
            }

            StyledRect {
                id: sample

                width: Math.min(210, preview.width * 0.5)
                height: 88
                x: (preview.width - width) / 2
                y: 15 - (height + 5) * previewMotion.value
                visible: previewMotion.value < 1
                opacity: Math.max(0, Math.min(1, 1 - previewMotion.value))
                radius: Tokens.rounding.large * (1 + (Motion.rounding && Motion.enabled ? 0.6 * Math.max(0, 4 * previewMotion.value * (1 - previewMotion.value)) : 0))
                color: Colours.palette.m3secondaryContainer
                border.width: 1
                border.color: Colours.palette.m3outlineVariant

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "water_drop"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3onSecondaryContainer
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.padding.large
                text: qsTr("Click to preview · %1").arg(Motion.enabled ? Motion.preset : qsTr("Off"))
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            TapHandler {
                onTapped: root.previewOpen = !root.previewOpen
            }
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Liquid motion")
            subtext: qsTr("Springs that follow a drawer when it reverses")
            checked: Motion.enabled
            onToggled: GlobalConfig.appearance.deformScale = checked ? 0.7 : 0
        }

        SectionHeader { text: qsTr("Motion") }

        SelectRow {
            first: true
            label: qsTr("Preset")
            subtext: qsTr("How lively the springs feel")
            menuItems: root.presets
            active: root.presets[["subtle", "balanced", "bouncy"].indexOf(Motion.preset)]
            enabled: Motion.enabled
            onSelected: item => Motion.selectPreset(["subtle", "balanced", "bouncy"][root.presets.indexOf(item)])
        }

        SliderRow {
            last: true
            icon: "motion_blur"
            label: qsTr("Drawer stretch")
            value: Math.min(1, Config.appearance.deformScale / 2)
            valueLabel: `${Math.round(Config.appearance.deformScale * 100)}%`
            enabled: Motion.enabled
            onMoved: v => GlobalConfig.appearance.deformScale = Math.max(0.1, Math.round(v * 20) / 10)
        }

        SectionHeader { text: qsTr("Shape") }

        ToggleRow {
            first: true
            text: qsTr("Liquid neck")
            subtext: qsTr("Blend the drawer into the frame halfway through")
            checked: Motion.neck
            enabled: Motion.enabled
            onToggled: { Motion.neck = checked; Motion.save(); }
        }

        ToggleRow {
            last: true
            text: qsTr("Soft rounding")
            subtext: qsTr("Round the drawer while it moves")
            checked: Motion.rounding
            enabled: Motion.enabled
            onToggled: { Motion.rounding = checked; Motion.save(); }
        }

        SectionHeader { text: qsTr("Drawers") }

        ToggleRow { first: true; text: qsTr("Dashboard"); checked: Motion.drawers.dashboard; enabled: Motion.enabled; onToggled: Motion.setDrawer("dashboard", checked) }
        ToggleRow { text: qsTr("Launcher"); checked: Motion.drawers.launcher; enabled: Motion.enabled; onToggled: Motion.setDrawer("launcher", checked) }
        ToggleRow { text: qsTr("Bar popouts"); checked: Motion.drawers.popouts; enabled: Motion.enabled; onToggled: Motion.setDrawer("popouts", checked) }
        ToggleRow { text: qsTr("Sidebar"); checked: Motion.drawers.sidebar; enabled: Motion.enabled; onToggled: Motion.setDrawer("sidebar", checked) }
        ToggleRow { text: qsTr("Utilities"); checked: Motion.drawers.utilities; enabled: Motion.enabled; onToggled: Motion.setDrawer("utilities", checked) }
        ToggleRow { text: qsTr("Session menu"); checked: Motion.drawers.session; enabled: Motion.enabled; onToggled: Motion.setDrawer("session", checked) }
        ToggleRow { last: true; text: qsTr("OSD"); checked: Motion.drawers.osd; enabled: Motion.enabled; onToggled: Motion.setDrawer("osd", checked) }
    }
}
