.pragma library

var BUILTIN = [
    { id: "network", icon: "network-wireless-signal-excellent-symbolic", name: "Network" },
    { id: "bluetooth", icon: "bluetooth-active-symbolic", name: "Bluetooth" },
    { id: "power", icon: "power-profile-balanced-symbolic", name: "Power Mode" },
    { id: "nightlight", icon: "night-light-symbolic", name: "Night Light" },
    { id: "darkmode", icon: "weather-clear-night-symbolic", name: "Dark Style" },
    { id: "dnd", icon: "notifications-disabled-symbolic", name: "Do Not Disturb" },
    { id: "keyboard", icon: "input-keyboard-symbolic", name: "Keyboard" },
];

function parseCustom(json) {
    try {
        var list = JSON.parse(json || "[]");
        return Array.isArray(list) ? list.filter(function (t) { return t && t.id; }) : [];
    } catch (e) {
        return [];
    }
}

// Saved order, minus unknown ids, plus tiles added since (new built-ins, new custom tiles).
function order(saved, custom) {
    var all = BUILTIN.map(function (t) { return t.id; })
        .concat(custom.map(function (t) { return t.id; }));
    var out = (saved || []).filter(function (id) { return all.indexOf(id) >= 0; });
    all.forEach(function (id) { if (out.indexOf(id) < 0) out.push(id); });
    return out;
}

function visible(saved, hidden, custom) {
    return order(saved, custom).filter(function (id) { return (hidden || []).indexOf(id) < 0; });
}

function info(id, custom) {
    for (var i = 0; i < BUILTIN.length; i++)
        if (BUILTIN[i].id === id) return BUILTIN[i];
    for (var j = 0; j < custom.length; j++)
        if (custom[j].id === id)
            return { id: id, icon: custom[j].icon || "system-run-symbolic", name: custom[j].label || "Custom", custom: true };
    return null;
}
