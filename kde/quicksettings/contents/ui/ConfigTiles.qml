import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes
import "../code/tiles.js" as Tiles

ConfigBase {
    id: page

    readonly property var customs: Tiles.parseCustom(cfg_customTiles)
    readonly property var ids: Tiles.order(cfg_tileOrder, customs)

    function move(i, d) {
        const list = ids.slice();
        const [it] = list.splice(i, 1);
        list.splice(i + d, 0, it);
        cfg_tileOrder = list;
    }
    function setShown(id, shown) {
        const hidden = (cfg_hiddenTiles || []).filter(h => h !== id);
        if (!shown) hidden.push(id);
        cfg_hiddenTiles = hidden;
    }
    function saveCustom(def) {
        const list = customs.slice();
        const i = list.findIndex(t => t.id === def.id);
        if (i >= 0) list[i] = def; else list.push(def);
        cfg_customTiles = JSON.stringify(list);
        if (i < 0) cfg_tileOrder = ids.concat([def.id]);
    }
    function removeCustom(id) {
        cfg_customTiles = JSON.stringify(customs.filter(t => t.id !== id));
        cfg_tileOrder = ids.filter(x => x !== id);
        cfg_hiddenTiles = (cfg_hiddenTiles || []).filter(x => x !== id);
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Choose which tiles appear and in what order. Tiles for hardware you don't have stay hidden automatically.")
        }

        Repeater {
            model: page.ids
            delegate: RowLayout {
                id: row
                required property string modelData
                required property int index
                readonly property var info: Tiles.info(modelData, page.customs)
                readonly property bool custom: !!info && info.custom === true
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                QQC.CheckBox {
                    checked: (page.cfg_hiddenTiles || []).indexOf(row.modelData) < 0
                    onToggled: page.setShown(row.modelData, checked)
                }
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: row.info ? row.info.icon : ""
                }
                QQC.Label {
                    Layout.fillWidth: true
                    text: row.info ? (row.custom ? row.info.name : i18n(row.info.name)) : row.modelData
                    elide: Text.ElideRight
                }
                QQC.Label {
                    visible: row.custom
                    text: i18n("Custom")
                    opacity: 0.6
                }
                QQC.ToolButton {
                    visible: row.custom
                    icon.name: "document-edit-symbolic"
                    display: QQC.AbstractButton.IconOnly
                    text: i18n("Edit")
                    onClicked: editor.openFor(page.customs.find(t => t.id === row.modelData))
                }
                QQC.ToolButton {
                    visible: row.custom
                    icon.name: "edit-delete-symbolic"
                    display: QQC.AbstractButton.IconOnly
                    text: i18n("Remove")
                    onClicked: page.removeCustom(row.modelData)
                }
                QQC.ToolButton {
                    icon.name: "go-up-symbolic"
                    display: QQC.AbstractButton.IconOnly
                    text: i18n("Move up")
                    enabled: row.index > 0
                    onClicked: page.move(row.index, -1)
                }
                QQC.ToolButton {
                    icon.name: "go-down-symbolic"
                    display: QQC.AbstractButton.IconOnly
                    text: i18n("Move down")
                    enabled: row.index < page.ids.length - 1
                    onClicked: page.move(row.index, 1)
                }
            }
        }

        QQC.Button {
            icon.name: "list-add-symbolic"
            text: i18n("Add Custom Tile…")
            onClicked: editor.openFor(null)
        }
    }

    Kirigami.Dialog {
        id: editor
        property string tileId: ""
        title: tileId && page.customs.some(t => t.id === tileId) ? i18n("Edit Tile") : i18n("Add Custom Tile")
        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 28

        function openFor(def) {
            tileId = def ? def.id : "c-" + Date.now().toString(36);
            nameField.text = def ? def.label || "" : "";
            iconButton.iconName = def ? def.icon || "" : "system-run-symbolic";
            cmdField.text = def ? def.command || "" : "";
            offField.text = def ? def.offCommand || "" : "";
            statusField.text = def ? def.statusCommand || "" : "";
            open();
            nameField.forceActiveFocus();
        }

        onAccepted: {
            if (!nameField.text.trim() || !cmdField.text.trim()) return;
            page.saveCustom({
                id: tileId,
                label: nameField.text.trim(),
                icon: iconButton.iconName,
                command: cmdField.text.trim(),
                offCommand: offField.text.trim(),
                statusCommand: statusField.text.trim(),
            });
        }

        Kirigami.FormLayout {
            QQC.TextField {
                id: nameField
                Kirigami.FormData.label: i18n("Name:")
                placeholderText: i18n("VPN")
            }
            QQC.Button {
                id: iconButton
                property string iconName: "system-run-symbolic"
                Kirigami.FormData.label: i18n("Icon:")
                icon.name: iconName
                text: iconName
                onClicked: iconDialog.open()
                KIconThemes.IconDialog {
                    id: iconDialog
                    onIconNameChanged: if (iconName) iconButton.iconName = iconName
                }
            }
            QQC.TextField {
                id: cmdField
                Kirigami.FormData.label: i18n("Command:")
                Layout.fillWidth: true
                placeholderText: "nmcli connection up work-vpn"
            }
            QQC.TextField {
                id: offField
                Kirigami.FormData.label: i18n("Off command:")
                Layout.fillWidth: true
                placeholderText: i18n("Optional, makes the tile a toggle")
            }
            QQC.TextField {
                id: statusField
                Kirigami.FormData.label: i18n("Status command:")
                Layout.fillWidth: true
                placeholderText: i18n("Optional, exit code 0 means on")
            }
            QQC.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                wrapMode: Text.Wrap
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: i18n("Commands run through the shell. Without an off command the tile runs its command on every click. The status command is checked every few seconds while the menu is open.")
            }
        }
    }
}
