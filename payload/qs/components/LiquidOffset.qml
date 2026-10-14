import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A drawer offset: 0 = open, 1 = hidden. Keep Caelestia's original animation
// when motion is off, and use a velocity-preserving spring when it is on.
Item {
    id: root

    property real target: 1
    property string drawerName: "preview"
    readonly property bool liquid: Motion.forDrawer(drawerName)
    readonly property real value: liquid ? position : stock
    property real stock: target
    property real position: 1
    property real velocity: 0
    property bool moving: false

    visible: false
    width: 0
    height: 0

    Behavior on stock { Anim {} }

    Component.onCompleted: {
        position = target;
        moving = false;
    }

    onTargetChanged: if (liquid) moving = true
    onLiquidChanged: {
        if (liquid) {
            position = stock;
        } else {
            stock = position;
            stock = Qt.binding(() => target);
        }
        velocity = 0;
        moving = liquid && Math.abs(position - target) > 0.001;
    }

    function step(dt: real): void {
        const count = Math.max(1, Math.ceil(Math.min(0.05, dt) * 240));
        const h = Math.min(0.05, dt) / count;
        const stiffness = Motion.stiffness;
        const damping = Motion.damping;
        let x = position;
        let v = velocity;
        for (let i = 0; i < count; ++i) {
            v += (-stiffness * (x - target) - damping * v) * h;
            x += v * h;
        }
        // Absorb closing overshoot: an invisible drawer must not reappear.
        if (target === 1 && x >= 1) {
            x = 1;
            v = 0;
        }
        if (Math.abs(x - target) < 0.001 && Math.abs(v) < 0.02) {
            x = target;
            v = 0;
            moving = false;
        }
        position = x;
        velocity = v;
    }

    FrameAnimation {
        running: root.liquid && root.moving
        onTriggered: root.step(frameTime)
    }
}
