function parseExecArgv(value) {
    if (typeof value !== "string") return null;
    let argv;
    try { argv = JSON.parse(value); } catch (e) { return null; }
    if (!Array.isArray(argv) || !argv.length || argv.some(arg => typeof arg !== "string" || arg.includes("\u0000"))) return null;
    if (!argv[0] || argv[0].startsWith("-")) return null;
    return argv;
}

function buildActions(nativeActions, execArgv, activate, label) {
    const actions = nativeActions.map(action => ({
        identifier: action.identifier,
        text: action.text,
        invoke: () => action.invoke()
    }));
    const argv = parseExecArgv(execArgv);
    if (argv && !actions.some(action => action.identifier === "default"))
        actions.push({ identifier: "default", text: label, invoke: () => activate(argv) });
    return actions;
}
