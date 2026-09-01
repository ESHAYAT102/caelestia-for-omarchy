import QtQuick
import qs.Commons

// The null bar: Omarchy's bar has no off switch -- a bar plugin is replaced,
// never disabled -- so "off" has to be spelled as a bar that renders nothing.
//
// It deliberately has no PanelWindow. No PanelWindow means no Wayland layer
// surface, which means no exclusive zone, which means Hyprland reserves
// nothing for Omarchy and Caelestia's bar gets the whole screen edge to
// itself. Windows then tile to the real edges instead of around a phantom
// reserved strip.
//
// Three properties below are the entire reason this file is not empty. The
// host assigns this object to `shell.bar`, and exactly three things are read
// off it anywhere in Omarchy's shell -- all three in the notification service,
// which is the crash-diagnosis toast and therefore must not regress:
//
//   plugins/notifications/Service.qml:51
//     liveBarSize: shell.bar && !shell.bar.barHidden ? max(0, shell.bar.barSize)
//                                                    : defaultBarSize
//   plugins/notifications/Service.qml:1052
//     fontFamily: shell.bar ? shell.bar.fontFamily : ""
//
// Leaving barSize/barHidden undefined would make liveBarSize read
// Math.max(0, undefined) -> NaN, and leaving fontFamily undefined would drop
// the toast's themed font. So they are stated, not inherited:
//
//   barSize 0 + barHidden false  ->  liveBarSize 0, so the toast clears only
//                                    Style.gapsOut and sits where it always has
//   fontFamily                   ->  the same value omarchy.bar publishes, so
//                                    the toast is byte-for-byte as themed as before
//
// Everything else the host offers (omarchyPath, shell, manifest, barConfig,
// barWidgetRegistry, pluginRegistry) is assigned only `if (name in target)`
// -- see shell.qml configureBar() -- so not declaring them is not an error,
// it is the point.
Item {
    id: root

    readonly property int barSize: 0
    readonly property bool barHidden: false
    readonly property string fontFamily: Style.font.family
}
