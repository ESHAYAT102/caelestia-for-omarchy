pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property bool mediaPlaying: Players.list.some(player => player.isPlaying)
    readonly property bool effectiveEnabled: enabled || mediaPlaying
    readonly property alias enabledSince: props.enabledSince

    onEffectiveEnabledChanged: {
        if (effectiveEnabled)
            props.enabledSince = new Date();
    }

    PersistentProperties {
        id: props

        property bool enabled
        property date enabledSince

        reloadableId: "idleInhibitor"
    }

    IdleInhibitor {
        enabled: root.enabled
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
            if (props.enabled)
                Toaster.toast("Keep Awake", "Preventing sleep mode", "coffee", Toast.Info);
            else
                Toaster.toast("Keep Awake", "Normal power management", "coffee", Toast.Info);
        }

        function enable(): void {
            props.enabled = true;
            Toaster.toast("Keep Awake", "Preventing sleep mode", "coffee", Toast.Info);
        }

        function disable(): void {
            props.enabled = false;
            Toaster.toast("Keep Awake", "Normal power management", "coffee", Toast.Info);
        }

        target: "idleInhibitor"
    }
}
