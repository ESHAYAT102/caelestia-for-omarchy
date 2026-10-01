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
        id: inhibitor
        enabled: false
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    onEnabledChanged: {
        inhibitor.enabled = root.enabled;
    }

    IpcHandler {
        function isEnabled(): bool {
            return inhibitor.enabled;
        }

        function toggle(): void {
            inhibitor.enabled = !inhibitor.enabled;
            props.enabled = inhibitor.enabled;
            if (inhibitor.enabled)
                Toaster.toast("Keep Awake", "Preventing sleep mode", "coffee", Toast.Info);
            else
                Toaster.toast("Keep Awake", "Normal power management", "coffee", Toast.Info);
        }

        function enable(): void {
            inhibitor.enabled = true;
            props.enabled = true;
            Toaster.toast("Keep Awake", "Preventing sleep mode", "coffee", Toast.Info);
        }

        function disable(): void {
            inhibitor.enabled = false;
            props.enabled = false;
            Toaster.toast("Keep Awake", "Normal power management", "coffee", Toast.Info);
        }

        target: "idleInhibitor"
    }
}
