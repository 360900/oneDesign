# oneDesign: the lock screen lives in the Plasma shell package, so a copy of the
# system package with the one LockScreenUi.qml on top is kept in the user data dir.
# Sourced by startplasma before plasmashell; refreshes the copy after Plasma updates.
onedesign_lockscreen_sync() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}"
    local sys=/usr/share/plasma/shells/org.kde.plasma.desktop
    local dst="$data/plasma/shells/org.kde.plasma.desktop"
    local ui="$data/onedesign/lockscreen/LockScreenUi.qml"
    [ -f "$ui" ] && [ -d "$sys" ] || return 0
    # never replace a shell package the user put there
    [ -e "$dst" ] && [ ! -f "$dst/.onedesign" ] && return 0
    local stamp
    stamp=$( (find "$sys" -type f -printf '%P %T@\n' | sort; md5sum "$ui") | md5sum | cut -d' ' -f1)
    [ -f "$dst/.onedesign" ] && [ "$(cat "$dst/.onedesign")" = "$stamp" ] && return 0
    rm -rf "$dst"
    mkdir -p "${dst%/*}"
    cp -r "$sys" "$dst" && cp "$ui" "$dst/contents/lockscreen/LockScreenUi.qml" && echo "$stamp" > "$dst/.onedesign"
}
onedesign_lockscreen_sync
unset -f onedesign_lockscreen_sync
