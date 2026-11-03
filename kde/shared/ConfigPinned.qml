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

    // Resolves names and icons for the pinned urls. A running pinned app replaces its launcher row,
    // so rows are matched to the list by launcher position; apps that are only running have none.
    TaskManager.TasksModel {
        id: pins
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
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
                required property var model
                readonly property int pos: pins.launcherPosition(model.LauncherUrlWithoutIcon)
                visible: pos >= 0
                Layout.fillWidth: true
                Kirigami.Icon { source: row.model.decoration; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                QQC.Label { Layout.fillWidth: true; text: row.model.AppName || row.model.display; elide: Text.ElideRight }
                QQC.ToolButton {
                    icon.name: "go-up-symbolic"; enabled: row.pos > 0
                    onClicked: page.move(row.pos, row.pos - 1)
                }
                QQC.ToolButton {
                    icon.name: "go-down-symbolic"; enabled: row.pos < page.cfg_launchers.length - 1
                    onClicked: page.move(row.pos, row.pos + 1)
                }
                QQC.ToolButton {
                    icon.name: "edit-delete-symbolic"
                    onClicked: page.set(page.cfg_launchers.filter((u, i) => i !== row.pos))
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
            text: i18n("You can also right-click an app to pin or unpin it. The rail and the drawer keep separate lists. Drag apps on the rail to reorder them.")
        }
    }
}
