#!/usr/bin/env python3
"""Render an SDDM theme with mocked greeter objects (no SDDM needed).
  tools/sddm_preview.py THEME_DIR [--mode light|dark] [--grab out.png] [--users N] [--fail]
Without --grab it opens an interactive window."""
import argparse
import configparser
import sys
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot, Qt
from PySide6.QtGui import QGuiApplication, QStandardItem, QStandardItemModel
from PySide6.QtQuick import QQuickView


class Config(QObject):
    def __init__(self, path, mode):
        super().__init__()
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str
        cp.read(path)
        self.values = dict(cp["General"])
        if mode:
            self.values["Mode"] = mode

    @Slot(str, result=str)
    def stringValue(self, key):
        return self.values.get(key, "")


class Sddm(QObject):
    loginFailed = Signal()
    loginSucceeded = Signal()

    def __init__(self, fail):
        super().__init__()
        self.fail = fail

    @Slot(str, str, int)
    def login(self, user, password, session):
        print(f"login {user!r} session {session}")
        QTimer.singleShot(300, self.loginFailed.emit if self.fail else self.loginSucceeded.emit)

    for name in ("powerOff", "reboot", "suspend", "hibernate", "hybridSleep"):
        locals()[name] = Slot()(lambda self, n=name: print(n))

    hostName = Property(str, lambda self: "onedesign", constant=True)
    canPowerOff = Property(bool, lambda self: True, constant=True)
    canReboot = Property(bool, lambda self: True, constant=True)
    canSuspend = Property(bool, lambda self: True, constant=True)
    canHibernate = Property(bool, lambda self: False, constant=True)
    canHybridSleep = Property(bool, lambda self: False, constant=True)


class Keyboard(QObject):
    changed = Signal()

    def __init__(self):
        super().__init__()
        self._cur = 0

    capsLock = Property(bool, lambda self: False, constant=True)
    numLock = Property(bool, lambda self: True, constant=True)
    layouts = Property("QVariantList", lambda self: [], constant=True)

    def _set(self, v):
        self._cur = v
        self.changed.emit()

    currentLayout = Property(int, lambda self: self._cur, _set, notify=changed)


class Model(QStandardItemModel):
    def __init__(self, roles, rows, last=0):
        super().__init__()
        self.names = {Qt.UserRole + i + 1: r.encode() for i, r in enumerate(roles)}
        self.setItemRoleNames(self.names)
        for row in rows:
            it = QStandardItem()
            for i, r in enumerate(roles):
                it.setData(row.get(r, ""), Qt.UserRole + i + 1)
            self.appendRow(it)
        self._last = last

    lastIndex = Property(int, lambda self: self._last, constant=True)
    count = Property(int, lambda self: self.rowCount(), constant=True)
    lastUser = Property(str, lambda self: "", constant=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("theme")
    ap.add_argument("--mode")
    ap.add_argument("--grab")
    ap.add_argument("--users", type=int, default=3)
    ap.add_argument("--fail", action="store_true")
    ap.add_argument("--size", default="1600x1000")
    a = ap.parse_args()
    theme = Path(a.theme).resolve()
    w, h = map(int, a.size.split("x"))

    app = QGuiApplication(sys.argv)
    people = [("tarik", "Tarik"), ("mira", "Mira"), ("deniz", "Deniz"), ("sam", "Sam")][:a.users]
    users = Model(["name", "realName", "homeDir", "icon", "needsPassword"],
                  [{"name": n, "realName": r, "homeDir": f"/home/{n}", "icon": "", "needsPassword": True}
                   for n, r in people])
    sessions = Model(["file", "name", "exec", "comment"],
                     [{"name": "Plasma (Wayland)"}, {"name": "Plasma (X11)"}, {"name": "GNOME"}])
    objs = {"config": Config(theme / "theme.conf", a.mode), "sddm": Sddm(a.fail), "keyboard": Keyboard(),
            "userModel": users, "sessionModel": sessions}

    view = QQuickView()
    for k, v in objs.items():
        view.rootContext().setContextProperty(k, v)
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(w, h)
    view.setSource(QUrl.fromLocalFile(str(theme / "Main.qml")))
    if view.status() == QQuickView.Error:
        for e in view.errors():
            print(e.toString())
        sys.exit(1)
    view.show()
    if a.grab:
        def grab():
            view.grabWindow().save(a.grab)
            app.quit()
        QTimer.singleShot(1500, grab)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
