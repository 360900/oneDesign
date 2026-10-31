import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    readonly property var audio: root.audio

    PageHeader { title: i18n("Sound Output") }

    Repeater {
        model: audio.outputs
        ListRow {
            required property var model
            icon: "audio-speakers-symbolic"
            label: model.Description
            checked: !!model.PulseObject && model.PulseObject.default
            onClicked: model.PulseObject.default = true
        }
    }

    ListRow {
        icon: "emblem-system-symbolic"
        label: i18n("Sound Settings")
        onClicked: root.openKcm("kcm_pulseaudio")
    }
}
