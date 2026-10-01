pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property var peers: []
    property string backendState: "Unknown"
    property string selfName: ""
    property string selfIp: ""
    readonly property bool connected: backendState === "Running"

    width: Math.round(Tokens.sizes.bar.networkWidth * 1.35)
    spacing: Tokens.spacing.medium

    function refresh(): void {
        statusProcess.running = true;
    }

    function toggle(): void {
        actionProcess.command = connected ? ["tailscale", "down"] : ["tailscale", "up"];
        actionProcess.running = true;
    }

    Component.onCompleted: refresh()

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: "vpn_key"
            color: root.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: root.connected ? qsTr("Tailscale connected") : qsTr("Tailscale disconnected")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

            StyledText {
                text: root.selfIp ? `${root.selfName} • ${root.selfIp}` : root.backendState
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        StyledSwitch {
            checked: root.connected
            onToggled: root.toggle()
        }
    }

    StyledText {
        visible: root.peers.length > 0
        text: qsTr("Machines")
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.medium
    }

    Repeater {
        model: root.peers

        StyledRect {
            id: peerRow
            required property var modelData
            property bool copied
            Layout.fillWidth: true
            implicitHeight: peerLayout.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: peerLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: peerRow.modelData.os === "windows" ? "desktop_windows" : peerRow.modelData.os === "android" ? "smartphone" : "computer"
                    color: peerRow.modelData.online ? Colours.palette.m3primary : Colours.palette.m3outline
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: peerRow.modelData.name
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        text: peerRow.modelData.ip
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                StyledText {
                    text: peerRow.modelData.online ? qsTr("Online") : qsTr("Offline")
                    color: peerRow.modelData.online ? Colours.palette.m3primary : Colours.palette.m3outline
                    font: Tokens.font.label.small
                }

                IconButton {
                    icon: peerRow.copied ? "check" : "content_copy"
                    type: IconButton.Tonal
                    isRound: true
                    onClicked: {
                        Quickshell.clipboardText = peerRow.modelData.ip;
                        peerRow.copied = true;
                        copiedTimer.restart();
                    }
                }

                Timer {
                    id: copiedTimer
                    interval: 1400
                    onTriggered: peerRow.copied = false
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        icon: "refresh"
        text: qsTr("Refresh")
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        onClicked: root.refresh()
    }

    Process {
        id: statusProcess
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.backendState = data.BackendState ?? "Unknown";
                    root.selfName = data.Self?.HostName ?? "";
                    root.selfIp = data.Self?.TailscaleIPs?.find(ip => ip.startsWith("100.")) ?? "";
                    const peers = [];
                    for (const key in (data.Peer ?? {})) {
                        const peer = data.Peer[key];
                        peers.push({
                            name: peer.HostName || (peer.DNSName ?? "").split(".")[0] || "Unknown",
                            ip: peer.TailscaleIPs?.find(ip => ip.startsWith("100.")) ?? "",
                            online: peer.Online === true,
                            os: (peer.OS ?? "").toLowerCase()
                        });
                    }
                    root.peers = peers.sort((a, b) => Number(b.online) - Number(a.online) || a.name.localeCompare(b.name));
                } catch (error) {
                    root.backendState = "Unavailable";
                    root.peers = [];
                }
            }
        }
    }

    Process {
        id: actionProcess
        onExited: Qt.callLater(root.refresh)
    }
}
