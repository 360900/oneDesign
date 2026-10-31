import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "../../code/tiles.js" as Tiles

// User-defined tiles. A tile has a command; with an off command it becomes a toggle.
// A status command (exit code 0 = on) keeps the state in sync with the system.
Item {
    id: custom

    property string json: "[]"
    property bool polling: false
    readonly property var tiles: Tiles.parseCustom(json)
    property var states: ({})
    property var pending: ({})

    function tile(id) {
        return tiles.find(t => t.id === id) || null;
    }
    function isToggle(t) {
        return !!(t && (t.offCommand || t.statusCommand));
    }
    function setState(id, on) {
        const s = Object.assign({}, states);
        s[id] = on;
        states = s;
    }
    function exec(cmd, done) {
        if (!cmd) return;
        const p = Object.assign({}, pending);
        (p[cmd] = p[cmd] || []).push(done || null);
        pending = p;
        exec_.connectSource(cmd);
    }
    function refresh() {
        tiles.forEach(t => {
            if (t.statusCommand)
                exec(t.statusCommand, data => custom.setState(t.id, data["exit code"] === 0));
        });
    }
    function activate(id) {
        const t = tile(id);
        if (!t) return;
        const on = !!states[id];
        const cmd = on && t.offCommand ? t.offCommand : t.command;
        if (!t.statusCommand && t.offCommand) setState(id, !on);
        exec(cmd, () => { if (t.statusCommand) custom.refresh(); });
    }

    onTilesChanged: refresh()

    Timer {
        interval: 5000
        repeat: true
        running: custom.polling
        triggeredOnStart: true
        onTriggered: custom.refresh()
    }

    P5Support.DataSource {
        id: exec_
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            const cbs = custom.pending[source] || [];
            const p = Object.assign({}, custom.pending);
            delete p[source];
            custom.pending = p;
            cbs.forEach(cb => { if (cb) cb(data); });
        }
    }
}
