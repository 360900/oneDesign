"""FreeCAD preference packs (3D view, sketcher, editor colors) and theme parameters."""
from onetokens import Color


def name(th):
    return "One Dark" if th.dark else "One Light"


def _uint(col):
    r, g, b = col.rgb255
    return (r << 24) | (g << 16) | (b << 8) | 0xFF


def _palette(th):
    c, a = th.c, th.ansi()
    flat = lambda k, base="canvas": th.flat(k, base)
    white = Color(1, 1, 1)
    return {
        "bg": c["canvas"], "surface": c["surface"], "alt": c["surfaceAlt"], "float": c["float"],
        "text": c["text"], "text2": c["text2"], "text3": c["text3"],
        "stroke": flat("stroke"), "strokeStrong": flat("strokeStrong"),
        "accent": c["accent"], "accentText": c["accentText"],
        "preselect": c["accent"].mix(white, 0.35 if th.dark else 0.45),
        "container": c["container"], "currentLine": c["accentSoft"].over(c["surface"]),
        "danger": c["danger"], "warning": c["warning"], "success": c["success"],
        "shape": th.ok(0.62 if th.dark else 0.80, 0.01), "edge": th.ok(0.20, 0.01),
        "navi": c["surfaceAlt"] if th.dark else c["float"],
        "pageBg": c["desktop"] if th.dark else c["sidebar"],
        "orange": Color.oklch(0.72 if th.dark else 0.62, 0.16, 55),
        **{k: a[k] for k in ("red", "green", "yellow", "blue", "magenta", "cyan", "brightBlue")},
    }


def _prefs(th):
    p = _palette(th)
    return {
        "Editor": {
            "Text": p["text"], "Comment": p["text3"], "Block comment": p["text3"],
            "Keyword": p["blue"], "String": p["green"], "Number": p["yellow"], "Character": p["red"],
            "Class name": p["magenta"], "Define name": p["magenta"], "Operator": p["text2"],
            "Bookmark": p["cyan"], "Breakpoint": p["danger"], "Current line highlight": p["currentLine"],
            "Python output": p["text2"], "Python error": p["danger"],
        },
        "MainWindow": {
            "QtStyle": "System", "StyleSheet": f"{name(th)}.qss", "Theme": name(th),
            "OverlayActiveStyleSheet": "Freecad Overlay.qss",
        },
        "Mod/CAM": {
            "DefaultNormalPathColor": p["green"], "DefaultRapidPathColor": p["red"],
            "DefaultHighlightPathColor": p["orange"], "DefaultProbePathColor": p["yellow"],
            "DefaultPathMarkerColor": p["green"], "DefaultBBoxNormalColor": p["text2"],
            "DefaultBBoxSelectionColor": p["cyan"],
        },
        "Mod/Draft": {
            "constructioncolor": p["blue"], "gridColor": p["text3"], "snapcolor": p["warning"],
            "DefaultAnnoLineColor": p["text"],
        },
        "Mod/Measure/Appearance": {
            "DefaultLineColor": p["text"], "DefaultTextColor": p["text"], "DefaultTextBackgroundColor": p["float"],
        },
        "Mod/Sketcher/General": {"GridLineColor": p["stroke"], "GridDivLineColor": p["strokeStrong"]},
        "Mod/Spreadsheet": {
            "TextColor": p["text"].hexs, "PositiveNumberColor": p["text"].hexs,
            "NegativeNumberColor": p["danger"].hexs, "AliasedCellBackgroundColor": p["container"].hexs,
        },
        "Mod/TechDraw/Colors": {
            "Background": p["pageBg"], "PageColor": p["surface"], "FaceColor": p["surface"],
            "CutSurfaceColor": p["alt"], "NormalColor": p["text"], "HiddenColor": p["text2"],
            "LightTextColor": p["text2"], "Hatch": p["text2"], "GeomHatch": p["text2"],
            "SelectColor": p["accent"], "PreSelectColor": p["preselect"], "gridColor": p["stroke"],
            "TemplateUnderlineColor": p["accent"],
        },
        "Mod/TechDraw/Decorations": {
            "CenterColor": p["text2"], "SectionColor": p["text2"], "VertexColor": p["text"],
            "HighlightColor": p["text2"],
        },
        "Mod/TechDraw/Dimensions": {"Color": p["text"]},
        "Mod/TechDraw/Markups": {"Color": p["text"]},
        "NaviCube": {"BaseColor": p["navi"], "Color": p["navi"]},
        "OutputWindow": {
            "colorText": p["text"], "colorLogging": p["accentText"], "colorWarning": p["warning"],
            "colorError": p["danger"],
        },
        "Themes": {
            "ThemeAccentColor1": p["accent"], "ThemeAccentColor2": p["magenta"],
            "ThemeAccentColor3": p["accent"].mix(p["text3"], 0.5),
        },
        "TreeView": {"TreeActiveColor": p["success"], "TreeEditColor": p["accent"]},
        "View": {
            "Simple": True, "Gradient": False, "RadialGradient": False, "UseBackgroundColorMid": False,
            "BackgroundColor": p["bg"], "DefaultShapeColor": p["shape"],
            "DefaultShapeLineColor": p["edge"], "DefaultShapeVertexColor": p["edge"],
            "SelectionColor": p["accent"], "HighlightColor": p["preselect"],
            "BoundingBoxColor": p["text2"], "AnnotationTextColor": p["text2"], "AxisLetterColor": p["text"],
            "CbLabelColor": p["text"], "CursorTextColor": p["text"], "CursorCrosshairColor": p["text"],
            "CreateLineColor": p["text"], "EditedEdgeColor": p["text"], "EditedVertexColor": p["text"],
            "SketchEdgeColor": p["text"], "SketchVertexColor": p["text"],
            "ConstructionColor": p["blue"], "ExternalColor": p["magenta"],
            "InternalAlignedGeoColor": p["cyan"], "InvalidSketchColor": p["orange"],
            "FullyConstrainedColor": p["success"], "FullyConstraintElementColor": p["success"],
            "FullyConstraintConstructionElementColor": p["brightBlue"],
            "FullyConstraintConstructionPointColor": p["success"],
            "FullyConstraintInternalAlignmentColor": p["brightBlue"],
            "ConstrainedDimColor": p["danger"], "ConstrainedIcoColor": p["danger"],
            "ExprBasedConstrDimColor": p["orange"], "NonDrivingConstrDimColor": p["text3"],
            "DeactivatedConstrDimColor": p["text3"],
        },
    }


def _entry(key, val):
    if isinstance(val, bool):
        return f'<FCBool Name="{key}" Value="{int(val)}"/>'
    if isinstance(val, Color):
        return f'<FCUInt Name="{key}" Value="{_uint(val)}"/>'
    return f'<FCText Name="{key}">{val}</FCText>' if val else f'<FCText Name="{key}"/>'


def cfg(th):
    tree = {}
    for path, entries in _prefs(th).items():
        node = tree
        for part in path.split("/"):
            node = node.setdefault(part, {})
        node[""] = entries

    def emit(node, depth):
        pad = "  " * depth
        out = [pad + _entry(k, v) for k, v in node.get("", {}).items()]
        for k, sub in node.items():
            if k:
                out += [f'{pad}<FCParamGroup Name="{k}">', *emit(sub, depth + 1), f"{pad}</FCParamGroup>"]
        return out

    body = emit({"Root": {"BaseApp": {"Preferences": tree}}}, 1)
    return '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>\n<FCParameters>\n' + \
        "\n".join(body) + "\n</FCParameters>\n"


def package(themes):
    packs = "".join(f"""
    <preferencepack>
      <name>{name(th)}</name>
      <type>Theme</type>
      <description>One {'dark' if th.dark else 'light'} colors. Uses the system Qt style.</description>
      <version>1.0.0</version>
      <tag>{'dark' if th.dark else 'light'}</tag>
    </preferencepack>""" for th in themes)
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<package format="1">
  <name>OneDesign</name>
  <description>One theme preference packs</description>
  <version>1.0.0</version>
  <maintainer>oneDesign</maintainer>
  <license>GPL-3.0-or-later</license>
  <content>{packs}
  </content>
</package>
"""


def parameters(th):
    """Theme parameters (qss:parameters/<Theme>.yaml), used by the overlay panels and sketcher messages."""
    p = _palette(th)
    c = th.c
    accent = c["accent"]
    hover = th.flat("hover", "surface")
    v = {
        "AccentColor": accent, "AccentBackgroundColor": c["accentSoft"].over(c["surface"]),
        "AccentHoverColor": c["accentSoft"].over(hover),
        "PrimaryColor": c["surface"], "GeneralBackgroundColor": c["surface"],
        "GeneralAlternateBackgroundColor": c["surfaceAlt"], "GeneralBackgroundHoverColor": hover,
        "GeneralBorderColor": p["strokeStrong"], "GeneralBorderHoverColor": th.flat("strokeStrong", "surface"),
        "GeneralDisabledBackgroundColor": c["surfaceAlt"], "GeneralGridLinesColor": p["stroke"],
        "GeneralHeaderBackgroundColor": c["headerbar"], "GroupboxBackgroundColor": c["surface"],
        "GroupboxBorderColor": p["stroke"], "DialogBackgroundColor": c["float"],
        "MenuBackgroundColor": c["float"], "TabbarBackgroundColor": c["canvas"],
        "InActiveTabBackgroundColor": c["sidebar"], "ActiveTabBackgroundColor": c["canvas"],
        "3DViewBackgroundRefColor": c["canvas"],
        "ButtonTopBackgroundColor": th.flat("fill", "surface"), "ButtonBottomBackgroundColor": th.flat("fill", "surface"),
        "ButtonBackgroundHooverColor": th.flat("fillStrong", "surface"),
        "ButtonBorderColor": p["strokeStrong"], "ButtonBorderHooverColor": p["strokeStrong"],
        "CheckedButtonTopBackgroundColor": th.flat("active", "surface"),
        "CheckedButtonBottomBackgroundColor": th.flat("active", "surface"),
        "DefaultButtonTopBackgroundColor": accent, "DefaultButtonBottomBackgroundColor": accent,
        "DefaultButtonBorderColor": accent,
        "ToolButtonCheckedBorderColor": p["strokeStrong"], "ToolButtonCheckedBackground": th.flat("active", "surface"),
        "CheckBoxBackgroundColor": c["surface"], "CheckBoxBorderColor": p["strokeStrong"],
        "RadioButtonBackgroundColor": c["surface"], "RadioButtonBorderColor": p["strokeStrong"],
        "ScrollbarBackgroundColor": c["surfaceAlt"],
        "TextForegroundColor": c["text"], "TextDisabledColor": c["text3"],
        "TextEditFieldBackgroundColor": c["surface"], "TextSelectBackgroundColor": c["accentSoft"].over(c["surface"]),
        "TextUrlColor": c["accentText"],
        "SketcherFullyConstrainedColor": c["success"], "SketcherUnderConstrainedColor": c["text"],
        "SketcherEmptySketchColor": c["text"], "SketcherConflictingConstraintsColor": c["danger"],
        "SketcherMalformedConstraintsColor": c["danger"], "SketcherSolverFailedColor": c["danger"],
        "SketcherRedundantConstraintsColor": c["warning"], "SketcherPartiallyRedundantConstraintsColor": p["blue"],
    }
    lines = [f'{k}: "{col.hexs}"' for k, col in sorted(v.items())]
    for i in range(1, 7):
        t = i / 12
        lines += [f'PrimaryColorDarken{i}: "{c["surface"].mix(c["text"], t * 0.5).hexs}"' if not th.dark else
                  f'PrimaryColorDarken{i}: "{c["surface"].mix(Color(0, 0, 0), t).hexs}"',
                  f'PrimaryColorLighten{i}: "{c["surface"].mix(Color(1, 1, 1), t).hexs}"']
    lines += [
        f'IconsLocationFolderName: "images_classic"',
        f'StylesheetIconsColor: "{"white" if th.dark else "black"}"',
        'InputFieldBorderRadius: "3px"',
        'ToolbarButtonsPadding: "2px"',
    ]
    return "\n".join(lines) + "\n"


def _slug(th):
    return "one-dark" if th.dark else "one-light"


_ICONS = {
    "chevron-down": '<path d="M4 6l4 4 4-4" fill="none" stroke="{c}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "chevron-up": '<path d="M4 10l4-4 4 4" fill="none" stroke="{c}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "chevron-right": '<path d="M6 4l4 4-4 4" fill="none" stroke="{c}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "close": '<path d="M5 5l6 6M11 5l-6 6" fill="none" stroke="{c}" stroke-width="1.5" stroke-linecap="round"/>',
    "float": '<rect x="3.5" y="3.5" width="9" height="9" rx="2" fill="none" stroke="{c}" stroke-width="1.5"/>',
}


def icons(th):
    col = th.c["text2"].hexs
    return {f"{n}.svg": f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">{p.format(c=col)}</svg>\n'
            for n, p in _ICONS.items()}


def stylesheet(th):
    """Qt stylesheet layered over the system style (Kvantum): FreeCAD chrome only, controls stay native."""
    c = th.c
    flat = lambda k, base="canvas": th.flat(k, base).hexs
    icon = lambda n: f"url(qss:{_slug(th)}/{n}.svg)"
    v = {
        "canvas": c["canvas"].hexs, "sidebar": c["sidebar"].hexs, "surface": c["surface"].hexs,
        "alt": c["surfaceAlt"].hexs, "text": c["text"].hexs, "text2": c["text2"].hexs, "text3": c["text3"].hexs,
        "stroke": flat("stroke"), "strokeSide": flat("stroke", "sidebar"), "strokeSurf": flat("stroke", "surface"),
        "hover": c["hover"].css, "active": c["active"].css,
        "container": c["container"].hexs, "onContainer": c["onContainer"].hexs,
        "groupBg": flat("fill", "sidebar"),
    }
    rules = f"""
QMainWindow, QMainWindow > QWidget {{ background: {v['canvas']}; }}
QMainWindow::separator {{ background: {v['stroke']}; width: 1px; height: 1px; }}

QToolBar {{ background: {v['canvas']}; border: none; padding: 2px 6px; spacing: 2px; }}
QToolBar::handle {{ image: none; width: 6px; height: 6px; }}
QToolBar::separator {{ background: {v['stroke']}; width: 1px; height: 1px; margin: 7px 5px; }}
QToolBar QToolButton {{ background: transparent; border: none; border-radius: 8px; padding: 4px; margin: 0; color: {v['text']}; }}
QToolBar QToolButton:hover {{ background: {v['hover']}; }}
QToolBar QToolButton:pressed {{ background: {v['active']}; }}
QToolBar QToolButton:checked {{ background: {v['container']}; color: {v['onContainer']}; }}
QToolBar QToolButton[popupMode="1"] {{ padding-right: 18px; }}
QToolBar QToolButton::menu-button {{ border: none; background: transparent; width: 16px;
  border-top-right-radius: 8px; border-bottom-right-radius: 8px; }}
QToolBar QToolButton::menu-button:hover {{ background: {v['hover']}; }}
QToolBar QToolButton::menu-arrow {{ image: {icon('chevron-down')}; width: 12px; height: 12px; }}
QToolBar QToolButton::menu-indicator {{ image: {icon('chevron-down')}; width: 10px; height: 10px;
  subcontrol-origin: padding; subcontrol-position: bottom right; }}
QToolBar QToolButton#qt_toolbar_ext_button {{ qproperty-icon: {icon('chevron-right')}; }}

QDockWidget {{ color: {v['text2']}; titlebar-close-icon: {icon('close')}; titlebar-normal-icon: {icon('float')}; }}
QDockWidget::title {{ background: {v['sidebar']}; padding: 8px 12px; text-align: left; }}
QDockWidget::close-button, QDockWidget::float-button {{ border: none; border-radius: 6px; padding: 2px; background: transparent; }}
QDockWidget::close-button:hover, QDockWidget::float-button:hover {{ background: {v['hover']}; }}
QDockWidget > QWidget, Gui--OverlayTitleBar, Gui--TreePanel, Gui--DockWnd--ComboView,
Gui--PropertyView, Gui--TaskView--TaskView, Gui--TaskView--TaskView > QWidget > QWidget {{ background: {v['sidebar']}; border: none; }}
Gui--OverlayTitleBar {{ color: {v['text2']}; }}
Gui--OverlayToolButton {{ background: transparent; border: none; border-radius: 6px; padding: 2px; }}
Gui--OverlayToolButton:hover {{ background: {v['hover']}; }}
Gui--OverlayToolButton:checked, Gui--OverlayToolButton:pressed {{ background: {v['active']}; }}

QDockWidget QTreeView, QDockWidget QListView, QDockWidget QTableView, QDockWidget QTextEdit,
QDockWidget QPlainTextEdit {{ background: {v['sidebar']}; alternate-background-color: {v['groupBg']}; border: none; }}
QDockWidget QAbstractScrollArea {{ border: none; }}
QTreeView, QListView, QTableView {{ selection-background-color: {v['container']}; selection-color: {v['onContainer']}; outline: 0; }}
QHeaderView {{ background: transparent; border: none; }}
QHeaderView::section {{ background: {v['sidebar']}; color: {v['text2']}; border: none; border-bottom: 1px solid {v['strokeSide']};
  padding: 6px 10px; font-weight: 600; }}
QHeaderView::section:horizontal:!last {{ border-right: 1px solid {v['strokeSide']}; }}
Gui--PropertyEditor--PropertyEditor {{ gridline-color: {v['strokeSide']};
  qproperty-groupBackground: {v['groupBg']}; qproperty-groupTextColor: {v['text2']}; }}

QTabWidget::pane {{ border: none; background: {v['sidebar']}; }}
QTabWidget::tab-bar {{ alignment: center; }}
QTabBar {{ qproperty-drawBase: 0; background: transparent; }}
QTabBar::tab {{ background: transparent; color: {v['text2']}; border: none; border-radius: 8px; padding: 5px 12px; margin: 4px 2px; }}
QTabBar::tab:hover {{ background: {v['hover']}; color: {v['text']}; }}
QTabBar::tab:selected {{ background: {v['active']}; color: {v['text']}; }}
QTabBar::close-button {{ image: {icon('close')}; border-radius: 4px; margin: 2px; }}
QTabBar::close-button:hover {{ background: {v['hover']}; }}
QTabBar QToolButton {{ background: {v['canvas']}; border: none; border-radius: 6px; }}
QTabBar#mdiAreaTabBar {{ background: {v['canvas']}; }}
QTabBar#mdiAreaTabBar::tab {{ margin: 4px 2px 6px 2px; padding: 5px 10px 5px 12px; }}
QTabBar#mdiAreaTabBar::tab:selected {{ background: {v['surface']}; }}

QStatusBar {{ background: {v['canvas']}; color: {v['text2']}; }}
QStatusBar::item {{ border: none; }}
QStatusBar QToolButton, QStatusBar QPushButton {{ background: transparent; border: none; border-radius: 6px; padding: 2px 6px; }}
QStatusBar QToolButton:hover, QStatusBar QPushButton:hover {{ background: {v['hover']}; }}
QSplitter::handle {{ background: {v['stroke']}; }}
QSplitter::handle:horizontal {{ width: 1px; }}
QSplitter::handle:vertical {{ height: 1px; }}

QSint--ActionGroup {{ background: transparent; border: none; }}
QSint--ActionGroup QFrame[class="header"] {{ background: {v['surface']}; border: 1px solid {v['strokeSide']}; border-bottom: none;
  border-top-left-radius: 10px; border-top-right-radius: 10px; padding: 2px 6px; }}
QSint--ActionGroup QToolButton[class="header"] {{ background: transparent; border: none; text-align: left; font-weight: 600; color: {v['text']}; }}
QSint--ActionGroup QFrame[class="header"] QLabel[fold="false"] {{ image: {icon('chevron-up')}; padding: 2px; }}
QSint--ActionGroup QFrame[class="header"] QLabel[fold="true"] {{ image: {icon('chevron-down')}; padding: 2px; }}
QSint--ActionGroup QFrame[class="separator"] {{ min-height: 0; max-height: 0; border: none; }}
QSint--ActionGroup QFrame[class="content"] {{ background: {v['surface']}; border: 1px solid {v['strokeSide']}; border-top: none;
  border-bottom-left-radius: 10px; border-bottom-right-radius: 10px; }}
QSint--ActionGroup QFrame[class="content"] QTreeView, QSint--ActionGroup QFrame[class="content"] QListView,
QSint--ActionGroup QFrame[class="content"] QTableView {{ background: {v['surface']}; alternate-background-color: {v['alt']};
  border: 1px solid {v['strokeSurf']}; border-radius: 8px; }}
"""
    return rules.lstrip()


INIT_GUI = '''# Switches between the One Light and One Dark packs to follow the system color scheme.
def _one_follow_system():
    import os
    import FreeCAD
    from PySide import QtCore, QtGui

    theme = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/MainWindow").GetString("Theme")
    if theme not in ("One Light", "One Dark"):
        return
    app = QtGui.QApplication.instance()
    want = "One Dark" if app.palette().color(QtGui.QPalette.Window).lightness() < 128 else "One Light"
    if want == theme:
        return
    pack = os.path.join(FreeCAD.getUserAppDataDir(), "Mod", "OneDesign", want, want + ".cfg")
    FreeCAD.ParamGet("User parameter:BaseApp").Parent().Insert(pack)
    qss = QtCore.QFile("qss:" + want + ".qss")
    if qss.open(QtCore.QIODevice.ReadOnly | QtCore.QIODevice.Text):
        app.setStyleSheet(bytes(qss.readAll()).decode())


_one_follow_system()
'''


def build(themes):
    files = {"Mod/OneDesign/package.xml": package(themes), "Mod/OneDesignAuto/InitGui.py": INIT_GUI}
    for th in themes:
        files[f"Mod/OneDesign/{name(th)}/{name(th)}.cfg"] = cfg(th)
        files[f"Gui/Stylesheets/parameters/{name(th)}.yaml"] = parameters(th)
        files[f"Gui/Stylesheets/{name(th)}.qss"] = stylesheet(th)
        for f, svg in icons(th).items():
            files[f"Gui/Stylesheets/{_slug(th)}/{f}"] = svg
    return files
