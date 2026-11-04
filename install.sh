#!/bin/sh
# Install oneDesign on KDE Plasma 6, or update an existing install.
#
#   curl -fsSL https://raw.githubusercontent.com/360900/oneDesign/main/install.sh | sh
#   ... | sh -s -- --accent NAME --wall NAME
#   ... | sh -s -- --rollback    back to the previously installed version
#   ... | sh -s -- --uninstall   remove oneDesign and restore the desktop from before it
#
# A first install replaces the panels with the rail. An update keeps the panels, wallpaper, accent
# and light/dark choice.
set -eu

REPO=https://github.com/360900/oneDesign.git
DIR=${XDG_DATA_HOME:-$HOME/.local/share}/oneDesign
VERSIONS=${XDG_STATE_HOME:-$HOME/.local/state}/onedesign/versions

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Sets PM and PKGS. Immutable systems can't install packages this way, so they get the manual check.
find_packages() {
    PM=
    [ -e /run/ostree-booted ] && return 0
    if have pacman; then
        PM=pacman
        PKGS="git python python-pillow python-numpy fontconfig qt6-tools kconfig kdbusaddons kde-cli-tools
              plasma-desktop plasma-workspace kscreenlocker milou plasma-nm plasma-pa bluedevil powerdevil
              kvantum aurorae papirus-icon-theme adwaita-icon-theme"
    elif have apt-get; then
        PM=apt-get
        PKGS="git python3 python3-pil python3-numpy fontconfig qdbus-qt6 libkf6config-bin libkf6dbusaddons-bin kde-cli-tools
              plasma-desktop plasma-workspace kde-config-screenlocker milou plasma-nm plasma-pa bluedevil powerdevil
              qt6-style-kvantum papirus-icon-theme adwaita-icon-theme"
        # Aurorae ships inside KWin's packages until a distro splits it out
        if apt-cache show aurorae >/dev/null 2>&1; then PKGS="$PKGS aurorae"; fi
    elif have dnf; then
        PM=dnf
        PKGS="git python3 python3-pillow python3-numpy fontconfig qt6-qttools kf6-kconfig kf6-kdbusaddons kde-cli-tools
              plasma-desktop plasma-workspace kscreenlocker plasma-milou plasma-nm plasma-pa bluedevil powerdevil
              kvantum aurorae papirus-icon-theme adwaita-icon-theme"
    elif have zypper; then
        PM=zypper
        PKGS="git python3 python3-Pillow python3-numpy fontconfig qt6-tools-qdbus kf6-kconfig kf6-kdbusaddons-tools kde-cli-tools6
              plasma6-desktop plasma6-workspace kscreenlocker6 milou6 plasma6-nm plasma6-pa bluedevil6 powerdevil6
              kvantum-qt6 aurorae6 papirus-icon-theme adwaita-icon-theme"
    fi
}

is_installed() {
    case $PM in
        pacman) pacman -T "$1" >/dev/null 2>&1 ;;
        apt-get) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
        *) rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;
    esac
}

install_packages() {
    find_packages
    [ -n "$PM" ] || return 0
    missing=
    for p in $PKGS; do
        is_installed "$p" || missing="$missing $p"
    done
    [ -n "$missing" ] || return 0

    say "Installing:$missing"
    # stdin is the script itself under `curl | sh`, so prompts have to read the terminal
    (: </dev/tty) 2>/dev/null || die "no terminal to confirm with. Install these first:$missing"
    if have sudo; then su=sudo; elif have doas; then su=doas; else die "needs sudo or doas. Install these first:$missing"; fi
    # shellcheck disable=SC2086
    case $PM in
        pacman) $su pacman -S --needed $missing </dev/tty ;;
        apt-get) $su apt-get update </dev/tty && $su apt-get install $missing </dev/tty ;;
        dnf) $su dnf install $missing </dev/tty ;;
        zypper) $su zypper install $missing </dev/tty ;;
    esac
}

# Everything the theme can't work without, on any distro
check_requirements() {
    gaps=
    for c in git python3 kwriteconfig6 kreadconfig6 plasmashell; do
        have "$c" || gaps="$gaps $c"
    done
    python3 -c 'import PIL, numpy' 2>/dev/null || gaps="$gaps python3-pillow python3-numpy"
    [ -d /usr/share/icons/Adwaita/symbolic ] || gaps="$gaps adwaita-icon-theme"
    [ -d /usr/share/icons/Papirus ] || gaps="$gaps papirus-icon-theme"
    [ -n "$(find /usr/lib /usr/lib64 -path '*qt6/plugins/styles/libkvantum*' 2>/dev/null | head -n 1)" ] || gaps="$gaps kvantum(qt6)"
    [ -z "$gaps" ] || die "missing:$gaps. Install them with your package manager and run this again."

    version=$(QT_QPA_PLATFORM=offscreen plasmashell --version 2>/dev/null | awk '{print $2}')
    # Some builds crash on --version without a display, so only a version it did print can rule it out
    case $version in
        6.*|'') ;;
        *) die "needs Plasma 6, found plasmashell $version" ;;
    esac
}

# A saved accent or wallpaper from the last build, unless the command line set one
saved_setting() {
    python3 - "$DIR/build/kde/manifest.json" "$1" <<'EOF' 2>/dev/null || true
import json, sys
value = json.load(open(sys.argv[1]))[sys.argv[2]]
print(value.removeprefix("One-").lower() if sys.argv[2] == "wallpaper" else value)
EOF
}

# Builds and installs what's checked out in $DIR, then applies it with the given options
deploy() {
    one=$DIR/kde/one-theme
    say "Building"
    "$one" build --accent "${1:-blue}" --wall "${2:-wave}"
    "$one" install
    shift 2
    "$one" apply "$@" $LIVE
}

record_version() {
    head=$(git -C "$DIR" rev-parse HEAD)
    mkdir -p "$(dirname "$VERSIONS")"
    [ "$(tail -n 1 "$VERSIONS" 2>/dev/null)" = "$head" ] || echo "$head" >>"$VERSIONS"
}

rollback() {
    [ -d "$DIR/.git" ] || die "$DIR is not installed."
    head=$(git -C "$DIR" rev-parse HEAD)
    target=$(grep -vxF "$head" "$VERSIONS" 2>/dev/null | tail -n 1 || true)
    [ -n "$target" ] || die "no earlier version to go back to. --uninstall restores the desktop from before oneDesign."
    say "Rolling back to ${target%"${target#???????}"}"
    git -C "$DIR" reset --keep "$target" || die "can't reset $DIR. Commit or discard your changes there and run this again."
    deploy "$(saved_setting accent)" "$(saved_setting wallpaper)" --keep-wallpaper
    sed -i "/^$target\$/q" "$VERSIONS"
    say "Rolled back. Running the installer again updates to the latest version."
}

uninstall() {
    [ -x "$DIR/kde/one-theme" ] || die "$DIR is not installed."
    say "Restoring your desktop from before oneDesign"
    "$DIR/kde/one-theme" restore --original $LIVE
    "$DIR/kde/one-theme" uninstall
    rm -f "$VERSIONS"
    if [ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ]; then
        say "Kept $DIR, it has local changes."
    else
        rm -rf "$DIR"
    fi
    say "Removed. Config backups stay in ${XDG_STATE_HOME:-$HOME/.local/state}/onedesign/backup. Log out and back in to finish."
}

main() {
    accent= wall= action=install
    while [ $# -gt 0 ]; do
        case $1 in
            --accent|--wall)
                [ $# -ge 2 ] || die "$1 needs a value"
                if [ "$1" = --accent ]; then accent=$2; else wall=$2; fi
                shift 2 ;;
            --rollback) action=rollback; shift ;;
            --uninstall) action=uninstall; shift ;;
            *) die "unknown option: $1 (use --accent NAME, --wall NAME, --rollback, --uninstall)" ;;
        esac
    done
    [ "$(id -u)" -ne 0 ] || die "run this as your user, not root. The theme installs into your home."

    # Only a running Plasma session can take the changes live
    case ${XDG_CURRENT_DESKTOP:-} in
        *KDE*) LIVE=--live ;;
        *) LIVE= ;;
    esac

    case $action in
        rollback) check_requirements; rollback; return ;;
        uninstall) uninstall; return ;;
    esac

    install_packages
    check_requirements

    if [ -d "$DIR/.git" ]; then
        say "Updating $DIR"
        git -C "$DIR" pull --ff-only || die "can't fast-forward $DIR. Commit or discard your changes there and run this again."
    elif [ -e "$DIR" ]; then
        die "$DIR exists and is not a git clone. Move it away and run this again."
    else
        say "Cloning into $DIR"
        mkdir -p "$(dirname "$DIR")"
        git clone --depth 1 "$REPO" "$DIR"
    fi

    : "${accent:=$(saved_setting accent)}"
    : "${wall:=$(saved_setting wallpaper)}"
    case $(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage) in
        org.onedesign.*) say "Updating the theme"; set -- --keep-wallpaper ;;
        *) say "Applying, the current panels are replaced by the rail"; set -- --layout ;;
    esac
    deploy "$accent" "$wall" "$@"
    record_version

    [ -n "$LIVE" ] || say "Done. Log in to Plasma to see it."
    say "Undo with --rollback or --uninstall, see the README."
}

# Nothing but the prompts above reads stdin, which `curl | sh` is still feeding this script through
main "$@" </dev/null
