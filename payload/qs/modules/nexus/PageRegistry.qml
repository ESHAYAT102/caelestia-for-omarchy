pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int pluginCount
    readonly property Process pluginListProcess: Process {
        running: true
        command: ["omarchy", "plugin", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.pluginCount = JSON.parse(text).length;
                } catch (error) {
                    root.pluginCount = 0;
                }
            }
        }
    }

    readonly property list<var> pages: [
        {
            label: qsTr("Wallpaper & style"),
            icon: "palette",
            description: qsTr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            label: qsTr("Connected devices"),
            icon: "devices_other",
            description: qsTr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            label: qsTr("Audio"),
            icon: "volume_up",
            description: qsTr("App volumes, sound devices"),
            category: "connectivity"
        },
        {
            label: qsTr("Updates"),
            icon: "update",
            description: qsTr("System updates"),
            category: "system"
        },
        {
            label: qsTr("Plugins"),
            icon: "extension",
            description: root.pluginCount > 0 ? qsTr("%1 Omarchy plugins").arg(root.pluginCount) : qsTr("Manage plugins"),
            category: "system"
        },
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: qsTr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            label: qsTr("Services"),
            icon: "build",
            description: qsTr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("UI language, weather location, display units"),
            category: "shell"
        },
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "about"
        },
    ]
}
