import QtQuick
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.battery

Item {
    readonly property bool hasBattery: battery.hasInternalBatteries
    readonly property int percent: battery.percent
    readonly property bool pluggedIn: battery.pluggedIn
    readonly property bool charging: battery.state === BatteryControlModel.Charging
    readonly property bool full: battery.state === BatteryControlModel.FullyCharged
    readonly property bool profilesAvailable: profiles.isPowerProfileDaemonInstalled && profiles.profiles.length > 0
    readonly property var profileList: profiles.profiles
    readonly property string profile: profiles.activeProfile

    readonly property string batteryIcon: {
        const level = Math.min(100, Math.round(percent / 10) * 10);
        const suffix = full ? "-charged" : charging ? "-charging" : pluggedIn ? "-plugged-in" : "";
        return "battery-level-" + level + suffix + "-symbolic";
    }
    readonly property string profileIcon: profileIconFor(profile)
    readonly property string icon: hasBattery ? batteryIcon : profilesAvailable ? profileIcon : "ac-adapter-symbolic"

    readonly property string batteryText: {
        if (!hasBattery) return "";
        let t = percent + "%";
        const ms = battery.smoothedRemainingMsec;
        if (ms > 0 && !full) {
            const h = Math.floor(ms / 3600000), m = Math.round(ms % 3600000 / 60000);
            const left = h > 0 ? i18n("%1 h %2 min", h, m) : i18n("%1 min", m);
            t += " · " + (charging ? i18n("%1 until full", left) : i18n("%1 left", left));
        } else if (full) {
            t += " · " + i18n("Charged");
        }
        return t;
    }

    function profileIconFor(p) {
        return p === "performance" ? "power-profile-performance-symbolic"
            : p === "power-saver" ? "power-profile-power-saver-symbolic" : "power-profile-balanced-symbolic";
    }
    function profileName(p) {
        return p === "performance" ? i18n("Performance") : p === "power-saver" ? i18n("Power Saver") : i18n("Balanced");
    }
    function setProfile(p) {
        if (p !== profile) profiles.setProfile(p);
    }

    PowerProfilesControl { id: profiles }
    BatteryControlModel { id: battery }
}
