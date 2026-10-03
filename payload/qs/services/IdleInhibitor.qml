pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property bool mediaPlaying: Players.list.some(player => player.isPlaying)
    // Manual "off" that also suspends the media-driven keep-awake, so the
    // hotkey/card can force normal power management even while media plays.
    // Transient, and cleared when playback stops: a restart or a later
    // playback session returns to the default media behaviour.
    property bool mediaOverrideOff: false
    readonly property bool effectiveEnabled: enabled || (mediaPlaying && !mediaOverrideOff)
    readonly property alias enabledSince: props.enabledSince

    onEffectiveEnabledChanged: {
        if (effectiveEnabled)
            props.enabledSince = new Date();
    }

    onMediaPlayingChanged: {
        if (!mediaPlaying)
            mediaOverrideOff = false;
    }

    function turnOn(): void {
        mediaOverrideOff = false;
        props.enabled = true;
        inhibitor.enabled = true;
        Toaster.toast("Keep Awake", "Preventing sleep mode", "coffee", Toast.Info);
    }

    function turnOff(): void {
        props.enabled = false;
        // Only suppress an active media session; with nothing playing there
        // is nothing to override and no latent state should linger.
        mediaOverrideOff = mediaPlaying;
        inhibitor.enabled = false;
        Toaster.toast("Keep Awake", "Normal power management", "coffee", Toast.Info);
    }

    function toggle(): void {
        if (effectiveEnabled)
            turnOff();
        else
            turnOn();
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
            return root.effectiveEnabled;
        }

        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            root.turnOn();
        }

        function disable(): void {
            root.turnOff();
        }

        target: "idleInhibitor"
    }
}
