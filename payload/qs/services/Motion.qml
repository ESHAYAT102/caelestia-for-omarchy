pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    readonly property bool enabled: GlobalConfig.appearance.deformScale > 0
    property string preset: "balanced"
    property bool neck: true
    property bool rounding: true
    property var drawers: ({ dashboard: true, launcher: true, popouts: true,
        sidebar: true, utilities: true, session: true, osd: true })

    readonly property real stiffness: preset === "subtle" ? 220 : preset === "bouncy" ? 260 : 190
    readonly property real damping: preset === "subtle" ? 26 : preset === "bouncy" ? 14 : 21

    function forDrawer(name: string): bool {
        return enabled && (drawers[name] ?? true);
    }

    function save(): void {
        storage.setText(JSON.stringify({ preset, neck, rounding, drawers }, null, 2));
    }

    function selectPreset(value: string): void {
        if (!["subtle", "balanced", "bouncy"].includes(value))
            return;
        preset = value;
        save();
    }

    function setDrawer(name: string, active: bool): void {
        if (!(name in drawers))
            return;
        drawers = Object.assign({}, drawers, { [name]: active });
        save();
    }

    FileView {
        id: storage

        path: `${Paths.config}/motion.json`
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (["subtle", "balanced", "bouncy"].includes(data.preset))
                    root.preset = data.preset;
                if (typeof data.neck === "boolean")
                    root.neck = data.neck;
                if (typeof data.rounding === "boolean")
                    root.rounding = data.rounding;
                if (data.drawers && typeof data.drawers === "object") {
                    const result = Object.assign({}, root.drawers);
                    for (const key of Object.keys(result))
                        if (typeof data.drawers[key] === "boolean")
                            result[key] = data.drawers[key];
                    root.drawers = result;
                }
            } catch (error) {
                console.warn("Invalid motion settings:", error);
            }
        }
    }
}
