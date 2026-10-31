#!/bin/bash
# Render the One KDE theme in an isolated nested Plasma session and take a screenshot.
#   tools/kde_preview.sh MODE OUT.png [command ...]
# Extra commands run inside the session after plasmashell (e.g. "dolphin ~").
# PRE: shell code run after apply, before the session starts (config experiments).
# KVANTUM_PLUGIN_DIR: dir containing styles/libkvantum.so when Kvantum is not installed.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODE=${1:-light}; OUT=$(readlink -f "${2:-/tmp/opencode/one-$MODE.png}"); shift 2 || true
SANDBOX=$(mktemp -d /tmp/opencode/kdeprev.XXXX)
trap 'rm -rf "$SANDBOX"' EXIT

export HOME=$SANDBOX
export XDG_CONFIG_HOME=$HOME/.config XDG_DATA_HOME=$HOME/.local/share XDG_CACHE_HOME=$HOME/.cache XDG_STATE_HOME=$HOME/.local/state
export XDG_RUNTIME_DIR=$HOME/run XDG_DATA_DIRS=$HOME/.local/share:/usr/local/share:/usr/share
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME"; chmod 700 "$XDG_RUNTIME_DIR"
printf '[General]\nLastSeenVersion=%s\n' "$(plasmashell --version | awk '{print $2}')" >"$XDG_CONFIG_HOME/plasma-welcomerc"

"$ROOT/kde/one-theme" install >/dev/null
"$ROOT/kde/one-theme" apply --mode "$MODE" --layout >/dev/null
[ -n "$PRE" ] && eval "$PRE"

[ -n "$KVANTUM_PLUGIN_DIR" ] && export QT_PLUGIN_PATH=$KVANTUM_PLUGIN_DIR
unset WAYLAND_DISPLAY DISPLAY SESSION_MANAGER
export XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 QT_FORCE_STDERR_LOGGING=1
export OUT EXTRA="$*"
dbus-run-session -- bash -c '
kwin_wayland --virtual --width 1600 --height 1000 --socket wayland-one --no-lockscreen >$HOME/kwin.log 2>&1 &
sleep 2; export WAYLAND_DISPLAY=wayland-one QT_QPA_PLATFORM=wayland
dbus-update-activation-environment WAYLAND_DISPLAY QT_QPA_PLATFORM QT_PLUGIN_PATH XDG_CURRENT_DESKTOP KDE_FULL_SESSION KDE_SESSION_VERSION XDG_DATA_DIRS XDG_CONFIG_HOME XDG_DATA_HOME HOME
plasmashell >$HOME/ps.log 2>&1 &
sleep 6
[ -n "$EXTRA" ] && eval "$EXTRA" >$HOME/extra.log 2>&1 &
sleep ${WAIT:-8}
spectacle -b -f -n -o "$OUT" >/dev/null 2>&1
[ -n "$KEEPLOG" ] && cp $HOME/ps.log $HOME/kwin.log $HOME/extra.log "$KEEPLOG"/ 2>/dev/null
kill $(jobs -p) 2>/dev/null; sleep 1' 2>/dev/null
echo "$OUT"
