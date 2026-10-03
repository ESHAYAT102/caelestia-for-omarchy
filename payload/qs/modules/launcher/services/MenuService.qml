pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Omarchy menu, read with Omarchy's own engine.
//
// Typing ":" in the launcher walks this menu, drawn as launcher rows and
// backed by Omarchy's own menu engine (MenuService). Ported from omacale.
//
// The menu is the first-party `omarchy.menu` plugin. Its IPC only opens and
// closes it, so there is no way to ask Omarchy for the menu as data. What
// there is, is the engine itself: `$OMARCHY_PATH/shell/plugins/menu/MenuModel.js`
// is plain JS with no shell dependencies -- it parses the JSONC, merges the
// user extension over the defaults, builds the `when:`/`checked:`/`disabled:`
// guard script, scores the search and shapes the rows.
//
// So we load that file in place rather than copying it: a wrapper object is
// created with its URL inside Omarchy's menu plugin directory, which is what
// resolves its relative `import "MenuModel.js"`. Search order, guards and
// route resolution then stay whatever the installed Omarchy ships. If it ever
// can't be loaded, `available` goes false and the launcher says so -- the
// failure is caught here, never at QML load time.
QtObject {
    id: root

    readonly property string menuPrefix: ":"
    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    readonly property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
    readonly property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"

    // The engine wrapper, and whether it and the menu definition both loaded.
    property var engine: null
    readonly property bool available: !!engine
    readonly property bool ready: available && itemOrder.length > 1

    property var items: ({})        // id -> normalized item
    property var itemOrder: []      // ids, in declaration order
    property string defaultRaw: ""
    property string userRaw: ""

    // Guard answers, as Omarchy's Menu.qml keeps them: id -> true|false.
    property var whenResults: ({})
    property var checkedResults: ({})
    property var disabledResults: ({})

    property var providersLoaded: ({})
    property int providerRevision: 0

    // Where in the menu tree ":" is looking, and how it got there. Omarchy's
    // Menu.qml keeps the same pair (activeMenu / navStack): the stack is what
    // makes going back retrace the route taken rather than the tree.
    property string menuPath: "root"
    property var menuStack: []

    function go(id: string, push: bool): void {
        if (push && id !== menuPath)
            menuStack = menuStack.concat([menuPath]);
        menuPath = id;
        open(id);
    }

    function back(): void {
        if (menuStack.length > 0) {
            const previous = menuStack[menuStack.length - 1];
            menuStack = menuStack.slice(0, menuStack.length - 1);
            menuPath = previous;
            open(previous);
        } else if (menuPath !== "root") {
            menuPath = parentOf(menuPath);
            open(menuPath);
        }
    }

    function reset(): void {
        menuStack = [];
        menuPath = "root";
    }

    function run(action: var): void {
        if (action)
            // Own transient scope so the command outlives the shell service.
            Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--", "bash", "-lc", String(action)]);
    }

    // Screen-grabbing actions (screenshot, text extractor, color picker)
    // must not fire while the launcher still covers the screen. The caller
    // closes the launcher first; this fires the action once the drawer is
    // gone. It lives here (not in the list) because the list is destroyed
    // when the launcher closes and clears the search.
    property var pendingAction: null

    property Timer runDelay: Timer {
        interval: 300
        onTriggered: {
            if (root.pendingAction) {
                root.run(root.pendingAction);
                root.pendingAction = null;
            }
        }
    }

    function runAfterClose(action: var): void {
        if (!action)
            return;
        root.pendingAction = action;
        runDelay.restart();
    }

    function quote(value: string): string {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    // ------------------------------------------------------------- the engine

    function loadEngine(): void {
        // Only the calls this UI makes; every one of them is MenuModel's.
        //
        // Omarchy 4.0.x (stable) predates `disabled:` guards: it has no
        // isDisabled, and its displayRow takes no disabledResults, so called with
        // the newer arguments every row came back with no id and drew blank.
        // `hasDisabled` picks the signature the installed engine has; without it
        // nothing is ever disabled, as in that Omarchy's own menu.
        const src = 'import QtQuick\nimport "MenuModel.js" as M\nQtObject {\n'
            + '  readonly property bool hasDisabled: typeof M.isDisabled === "function"\n'
            + '  function parse(raw) { return M.parseMenuJsonc(raw) }\n'
            + '  function merge(a, b) { return M.mergeMenuSources(a, b) }\n'
            + '  function mergeApps(i, o, rows) { return M.mergeAppRows(i, o, rows) }\n'
            + '  function swapProvider(i, o, id, rows) { return M.swapProviderRows(i, o, id, rows) }\n'
            + '  function guardScript(i) { return M.guardScript(i) }\n'
            + '  function isVisible(i, o, w, e) { return M.isVisible(i, o, w, e) }\n'
            + '  function isDisabled(d, e) { return hasDisabled ? M.isDisabled(d, e) : false }\n'
            + '  function matchesQuery(e, q, v) { return M.matchesQuery(e, q, v) }\n'
            + '  function searchScore(i, e, q) { return M.searchScore(i, e, q) }\n'
            + '  function displayRow(i, o, c, d, e, det, s) { return hasDisabled ? M.displayRow(i, o, c, d, e, det, s) : M.displayRow(i, o, c, e, det, s) }\n'
            + '  function pathFor(i, id) { return M.pathFor(i, id) }\n'
            + '  function parentPathFor(i, id) { return M.parentPathFor(i, id) }\n'
            + '  function isDescendantOf(i, id, a) { return M.isDescendantOf(i, id, a) }\n'
            + '  function resolveRoute(i, o, q) { return M.resolveRoute(i, o, q) }\n'
            + '  function slugify(v) { return M.slugify(v) }\n'
            + '}';
        try {
            // The URL never has to exist: it is only the document URL the relative
            // import is resolved against.
            root.engine = Qt.createQmlObject(src, root, "file://" + root.omarchyPath + "/shell/plugins/menu/OmacaleMenuEngine.qml");
        } catch (e) {
            root.engine = null;
            console.warn("Caelestia: Omarchy's menu engine could not be loaded:", e);
            return;
        }
        // The sources may already have arrived while the engine was being built.
        root.rebuild();
    }

    Component.onCompleted: root.loadEngine()

    // ------------------------------------------------------------- the rows

    function rebuild(): void {
        if (!engine)
            return;
        const merged = engine.merge(engine.parse(root.defaultRaw), engine.parse(root.userRaw));
        root.providerRevision += 1;
        root.providersLoaded = ({});
        root.items = merged.items;
        root.itemOrder = merged.itemOrder;
        root.evaluateGuards();
    }

    function item(id: string): var {
        return root.items[id] || null;
    }

    function label(id: string): string {
        const e = item(id);
        return e ? (e.title || e.label) : "";
    }

    function pathLabel(id: string): string {
        return engine && id !== "root" ? engine.pathFor(root.items, id) : "";
    }

    function parentOf(id: string): string {
        const e = item(id);
        return e && e.parent ? e.parent : "root";
    }

    function resolve(route: string): string {
        return engine ? engine.resolveRoute(root.items, root.itemOrder, route) : "root";
    }

    function visible(entry: var): bool {
        return engine.isVisible(root.items, root.itemOrder, root.whenResults, entry);
    }

    function disabled(entry: var): bool {
        return engine.isDisabled(root.disabledResults, entry);
    }

    // Omarchy's Menu.qml rebuildDisplay(), as a function of the state it reads:
    // the children of `menuId`, or, with a query, everything under it scored by
    // the engine, its own matches first and the deeper ones after.
    function rows(menuId: string, query: string): var {
        if (!engine || !ready)
            return [];
        const active = item(menuId) ? menuId : "root";
        const q = String(query || "").trim();
        const out = [];

        if (q) {
            const here = [], deeper = [];
            for (let i = 0; i < itemOrder.length; i++) {
                const entry = item(itemOrder[i]);
                if (!entry || entry.id === "root")
                    continue;
                if (!engine.isDescendantOf(items, entry.id, active))
                    continue;
                if (!engine.matchesQuery(entry, q, visible(entry) && !disabled(entry)))
                    continue;
                const row = engine.displayRow(items, itemOrder, checkedResults, disabledResults, entry, engine.parentPathFor(items, entry.id), engine.searchScore(items, entry, q));
                if (entry.parent === active)
                    here.push(row);
                else
                    deeper.push(row);
            }
            const byScore = (a, b) => a.score - b.score || a.path.localeCompare(b.path);
            here.sort(byScore);
            deeper.sort(byScore);
            return here.concat(deeper);
        }

        for (let j = 0; j < itemOrder.length; j++) {
            const child = item(itemOrder[j]);
            if (!child || child.parent !== active)
                continue;
            if (!visible(child))
                continue;
            out.push(engine.displayRow(items, itemOrder, checkedResults, disabledResults, child, child.description, child.order));
        }
        // DesktopEntries reorders itself when an application starts; keep the
        // Apps submenu alphabetical regardless (Omarchy's Menu.qml does the same).
        if (active === "apps")
            out.sort((a, b) => String(a.label).toLowerCase().localeCompare(String(b.label).toLowerCase()));
        return out;
    }

    // Entering menu mode is the one moment worth re-reading the world: guards
    // answer questions like "is this already installed" and a provider list may
    // have been reshaped by the last pick from it.
    function open(menuId: string): void {
        if (!engine)
            return;
        root.evaluateGuards();
        root.loadProvider(menuId);
    }

    // ------------------------------------------------------------- providers
    //
    // A provider fills a submenu from a live list. Omarchy declares its own in
    // `providers` inside Menu.qml, which is a property of a plugin Item we
    // can't instantiate (it wants the shell's own context), and the JSONC can
    // only name them -- so these two are restated here. They must stay in step
    // with Omarchy's map; there is nothing else to read them from.
    readonly property var providers: ({
        "fonts": {
            script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
            icon: "",
            volatile: true,
            actionFor: value => "omarchy-font-set " + root.quote(value)
        },
        "power-profiles": {
            script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
            icon: "",
            volatile: true,
            actionFor: value => "omarchy-powerprofiles-set autodetect " + root.quote(value)
        }
    })

    // The apps provider is native in Omarchy too (its AppLibrary). Ours is the
    // shell's own desktop entry list, so the menu lists what the system lists.
    // The apps submenu is re-merged on every entry, so no watcher is needed.
    function mergeApps(): void {
        const rows = [];
        const entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const id = String(e.id || "");
            if (!id)
                continue;
            const subtext = e.comment || e.genericName || "";
            let aliases = subtext ? [subtext] : [];
            try {
                if (e.keywords && e.keywords.join)
                    aliases = aliases.concat(e.keywords);
            } catch (err) {}
            rows.push({
                id: "apps." + id, parent: "apps", kind: "app", icon: "", iconFont: "",
                appIcon: String(e.icon || ""), appId: id, label: e.name, title: "", target: "",
                description: subtext, action: "", provider: "", aliases: aliases,
                when: "", checked: "", disabled: "", order: 0
            });
        }
        const merged = engine.mergeApps(root.items, root.itemOrder, rows);
        root.items = merged.items;
        root.itemOrder = merged.itemOrder;
    }

    // A fresh map every time: MenuModel's own note about writes into a QML
    // `var` object being dropped applies here too.
    function markProviderLoaded(menuId: string): void {
        const next = ({});
        for (const key in root.providersLoaded)
            next[key] = root.providersLoaded[key];
        next[menuId] = true;
        root.providersLoaded = next;
    }

    function loadProvider(menuId: string): void {
        const entry = item(menuId);
        if (!engine || !entry || !entry.provider)
            return;
        const spec = root.providers[entry.provider];
        if (entry.provider === "apps") {
            if (root.providersLoaded[menuId])
                return;
            root.markProviderLoaded(menuId);
            root.mergeApps();
            return;
        }
        if (!spec)
            return;
        // A volatile list (the installed fonts) is re-enumerated every time its
        // submenu is entered; the rest are read once.
        if (root.providersLoaded[menuId] && !spec.volatile)
            return;
        if (providerProc.running)
            return;
        root.markProviderLoaded(menuId);
        providerProc.menuId = menuId;
        providerProc.providerKey = entry.provider;
        providerProc.revision = root.providerRevision;
        providerProc.collected = "";
        providerProc.command = ["bash", "-lc", spec.script];
        providerProc.running = true;
    }

    // Provider output is `label\tvalue\tcurrent` per line, as Omarchy reads it.
    function mergeProviderRows(text: string, menuId: string, providerKey: string): void {
        const spec = root.providers[providerKey];
        if (!spec || !engine)
            return;
        const taken = ({});
        const rows = [];
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line)
                continue;
            const parts = line.split("\t");
            const label = parts[0] || "";
            if (!label)
                continue;
            const value = parts[1] || parts[0] || "";
            const current = parts[2] || "";
            let rowId = menuId + "." + engine.slugify(value);
            while (taken[rowId])
                rowId += "-";
            taken[rowId] = true;
            rows.push({
                id: rowId, parent: menuId, kind: "action",
                icon: value === current ? "✓" : (spec.icon || ""), iconFont: "",
                label: label, title: "", target: "", description: "",
                action: spec.actionFor(value), provider: "", aliases: [],
                when: "", checked: "", disabled: "", order: 0
            });
        }
        const merged = engine.swapProvider(root.items, root.itemOrder, menuId, rows);
        root.items = merged.items;
        root.itemOrder = merged.itemOrder;
    }

    property Process providerProc: Process {
        property string menuId: ""
        property string providerKey: ""
        property string collected: ""
        property int revision: 0
        stdout: SplitParser {
            onRead: data => providerProc.collected += data + "\n"
        }
        onExited: {
            if (revision === root.providerRevision)
                root.mergeProviderRows(collected, menuId, providerKey);
        }
    }

    // ------------------------------------------------------------- guards
    //
    // One bash run answers every `when:`, `checked:` and `disabled:` in the
    // menu, exactly as Omarchy's does -- the script is the engine's. It costs
    // the better part of a second (it queries pacman), so the menu draws on the
    // last answers and redraws when these land.
    property bool guardsPending: false
    property double lastGuardRun: 0

    function evaluateGuards(): void {
        if (!engine)
            return;
        // A rerun while one is in flight would throw away the lines already read
        // (Process ignores a command change while running), so wait for it.
        if (guardProc.running) {
            root.guardsPending = true;
            return;
        }
        // Opening the launcher, typing ":" and deleting it is not a reason to
        // query pacman again.
        if (Date.now() - root.lastGuardRun < 5000)
            return;
        root.guardsPending = false;

        const script = engine.guardScript(root.items);
        if (!script) {
            root.whenResults = ({});
            root.checkedResults = ({});
            root.disabledResults = ({});
            return;
        }
        guardProc.collected = "";
        guardProc.command = ["bash", "-lc", script];
        guardProc.running = true;
    }

    property Process guardProc: Process {
        property string collected: ""
        stdout: SplitParser {
            onRead: data => guardProc.collected += data + "\n"
        }
        onExited: (exitCode, exitStatus) => {
            root.lastGuardRun = Date.now();
            // A batch that was killed only reached some of the rows, and a `when:`
            // that went unanswered shows. Keep the last complete set instead.
            if (exitCode !== 0 || exitStatus !== 0) {
                if (root.guardsPending)
                    Qt.callLater(() => root.evaluateGuards());
                return;
            }
            const nextWhen = ({}), nextChecked = ({}), nextDisabled = ({});
            const lines = guardProc.collected.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (!line)
                    continue;
                const colon = line.lastIndexOf(":");
                if (colon < 0)
                    continue;
                const value = line.substring(colon + 1) === "1";
                const rest = line.substring(0, colon);
                const tagAt = rest.lastIndexOf(":");
                if (tagAt < 0)
                    continue;
                const id = rest.substring(0, tagAt);
                const tag = rest.substring(tagAt + 1);
                if (tag === "w")
                    nextWhen[id] = value;
                else if (tag === "c")
                    nextChecked[id] = value;
                else if (tag === "d")
                    nextDisabled[id] = value;
            }
            root.whenResults = nextWhen;
            root.checkedResults = nextChecked;
            root.disabledResults = nextDisabled;
            if (root.guardsPending)
                Qt.callLater(() => root.evaluateGuards());
        }
    }

    // ------------------------------------------------------------- sources
    //
    // Watched, as Omarchy watches them: an edit to either file reshapes the
    // launcher's menu without a restart.
    property FileView defaultMenuFile: FileView {
        path: root.defaultMenuPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.defaultRaw = text();
            root.rebuild();
        }
        onFileChanged: reload()
    }

    property FileView userMenuFile: FileView {
        path: root.userMenuPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.userRaw = text();
            root.rebuild();
        }
        onLoadFailed: {
            root.userRaw = "";
            root.rebuild();
        }
        onFileChanged: reload()
    }
}
