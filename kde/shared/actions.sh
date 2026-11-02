#!/bin/sh
# Prints "name<TAB>command" for each action in an app's desktop file. Usage: actions.sh <launcher url>
u=${1#applications:}
case "$u" in
  file://*) f=${u#file://} ;;
  *.desktop)
    f=
    for d in "$HOME/.local/share/applications" /usr/local/share/applications /usr/share/applications \
             /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do
      [ -f "$d/$u" ] && f=$d/$u && break
    done ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0
awk -F= '
/^\[/ { sect = $0; if (sect ~ /^\[Desktop Action /) order[++n] = sect; next }
sect ~ /^\[Desktop Action / && $1 == "Name" && !(sect in nm) { nm[sect] = substr($0, 6) }
sect ~ /^\[Desktop Action / && $1 == "Exec" && !(sect in ex) { ex[sect] = substr($0, 6) }
END {
  for (i = 1; i <= n; i++) {
    s = order[i]; c = ex[s]; gsub(/ ?%[a-zA-Z]/, "", c)
    if (nm[s] != "" && c != "") print nm[s] "\t" c
  }
}' "$f"
