import QtQuick
import org.kde.plasma.workspace.keyboardlayout as Keyboards

Item {
    readonly property var layouts: kbd.layoutsList
    readonly property bool multiple: layouts.length > 1
    readonly property int current: kbd.layout
    readonly property string shortName: multiple && layouts[current] ? layouts[current].shortName : ""
    readonly property string longName: multiple && layouts[current] ? layouts[current].longName : ""

    function next() { kbd.switchToNextLayout(); }
    function select(index) { kbd.layout = index; }

    Keyboards.KeyboardLayout { id: kbd }
}
