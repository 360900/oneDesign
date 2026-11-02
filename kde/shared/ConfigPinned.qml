import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.taskmanager as TaskManager

KCM.SimpleKCM {
    id: page
    property var cfg_launchers: []
    property var cfg_launchersDefault: []

    function set(list) { cfg_launchers = list; }
    function move(i, to) {
        const l = cfg_launchers.slice();
        l.splice(to, 0, l.splice(i, 1)[0]);
        set(l);
    }

    // Launchers only: no window matches the made-up desktop, so only the pinned entries remain
    TaskManager.TasksModel {
        id: pins
        filterByVirtualDesktop: true
        virtualDesktop: "none"
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: true
        launcherList: page.cfg_launchers
    }

    FileDialog {
        id: picker
        title: i18n("Choose an app")
        currentFolder: "file:///usr/share/applications"
        nameFilters: [i18n("Desktop entries (*.desktop)")]
        onAccepted: if (selectedFile) page.set(page.cfg_launchers.concat([selectedFile.toString()]))
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        Repeater {
            model: pins
            delegate: RowLayout {
                id: row
                required property int index
                required property var model
                Layout.fillWidth: true
                Kirigami.Icon { source: row.model.decoration; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                QQC.Label { Layout.fillWidth: true; text: row.model.AppName || row.model.display; elide: Text.ElideRight }
                QQC.ToolButton {
                    icon.name: "go-up-symbolic"; enabled: row.index > 0
                    onClicked: page.move(row.index, row.index - 1)
                }
                QQC.ToolButton {
                    icon.name: "go-down-symbolic"; enabled: row.index < pins.count - 1
                    onClicked: page.move(row.index, row.index + 1)
                }
                QQC.ToolButton {
                    icon.name: "edit-delete-symbolic"
                    onClicked: page.set(page.cfg_launchers.filter((u, i) => i !== row.index))
                }
            }
        }
        QQC.Button {
            text: i18n("Add app...")
            icon.name: "list-add-symbolic"
            onClicked: picker.open()
        }
        QQC.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("You can also pin from the rail itself: right-click an app, or use the + tile. Drag apps on the rail to reorder them.")
        }
    }
}
