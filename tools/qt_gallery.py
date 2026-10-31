#!/usr/bin/env python3
"""Qt widget gallery for checking the Qt style.

  qt_gallery.py                     show with the platform style
  qt_gallery.py --style kvantum     force a style
  qt_gallery.py --grab out.png      render offscreen and exit
  qt_gallery.py --menu              also pop up a context menu (for screenshots)
"""
import argparse
import sys

from PySide6.QtCore import QPoint, Qt, QTimer
from PySide6.QtWidgets import (QApplication, QCheckBox, QComboBox, QGridLayout, QGroupBox, QLabel, QLineEdit,
                               QMainWindow, QMenu, QProgressBar, QPushButton, QRadioButton, QSlider, QSpinBox,
                               QStyleFactory, QTabWidget, QTextEdit, QToolButton, QTreeWidget, QTreeWidgetItem,
                               QVBoxLayout, QWidget)

ap = argparse.ArgumentParser()
ap.add_argument("--style")
ap.add_argument("--grab")
ap.add_argument("--menu", action="store_true")
a, rest = ap.parse_known_args()

app = QApplication([sys.argv[0]] + rest)
if a.style:
    app.setStyle(QStyleFactory.create(a.style))

w = QMainWindow()
w.setWindowTitle("Qt Gallery")
mb = w.menuBar()
for m in ("File", "Edit", "View", "Help"):
    mb.addMenu(m).addAction("Item")
tb = w.addToolBar("Main")
tb.addAction("New")
tb.addAction("Open")
tb.addSeparator()
tb.addAction("Save")

c = QWidget()
g = QGridLayout(c)
g.addWidget(QPushButton("Button"), 0, 0)
d = QPushButton("Default")
d.setDefault(True)
g.addWidget(d, 0, 1)
x = QPushButton("Disabled")
x.setEnabled(False)
g.addWidget(x, 0, 2)
t = QToolButton()
t.setText("Tool")
g.addWidget(t, 0, 3)
le = QLineEdit()
le.setPlaceholderText("Search…")
g.addWidget(le, 1, 0, 1, 2)
le2 = QLineEdit("Focused")
g.addWidget(le2, 1, 2, 1, 2)
cb = QComboBox()
cb.addItems(["Inter", "Geist"])
g.addWidget(cb, 2, 0)
sp = QSpinBox()
sp.setValue(42)
g.addWidget(sp, 2, 1)
c1 = QCheckBox("Check")
c1.setChecked(True)
g.addWidget(c1, 2, 2)
g.addWidget(QCheckBox("Uncheck"), 2, 3)
r1 = QRadioButton("Radio")
r1.setChecked(True)
g.addWidget(r1, 3, 0)
g.addWidget(QRadioButton("Other"), 3, 1)
sl = QSlider(Qt.Horizontal)
sl.setValue(60)
g.addWidget(sl, 3, 2, 1, 2)
pb = QProgressBar()
pb.setValue(45)
g.addWidget(pb, 4, 0, 1, 2)
tabs = QTabWidget()
tabs.addTab(QLabel("  Tab content"), "General")
tabs.addTab(QWidget(), "Advanced")
tabs.addTab(QWidget(), "About")
g.addWidget(tabs, 4, 2, 2, 2)
gb = QGroupBox("Group")
gl = QVBoxLayout(gb)
gl.addWidget(QCheckBox("Option A"))
gl.addWidget(QCheckBox("Option B"))
g.addWidget(gb, 5, 0, 1, 2)
tw = QTreeWidget()
tw.setHeaderLabels(["Name", "Size"])
for i, n in enumerate(("Documents", "Downloads", "Pictures", "Music", "Videos", "Projects")):
    tw.addTopLevelItem(QTreeWidgetItem([n, f"{i * 3 + 1} items"]))
tw.setCurrentItem(tw.topLevelItem(1))
g.addWidget(tw, 6, 0, 1, 2)
g.addWidget(QTextEdit("Lorem ipsum dolor sit amet\n" * 20), 6, 2, 1, 2)
w.setCentralWidget(c)
w.statusBar().showMessage("Ready")
w.resize(760, 640)
w.show()
le2.setFocus()


def menu():
    m = QMenu(w)
    m.addAction("Open")
    m.addAction("Save")
    m.addSeparator()
    act = m.addAction("Checked")
    act.setCheckable(True)
    act.setChecked(True)
    m.addMenu("Recent").addAction("notes.md")
    m.popup(w.mapToGlobal(QPoint(w.width() // 2, w.height() // 3)))
    return m


def done():
    if a.grab:
        w.grab().save(a.grab)
        app.quit()
    elif a.menu:
        menu()


QTimer.singleShot(800, done)
app.exec()
