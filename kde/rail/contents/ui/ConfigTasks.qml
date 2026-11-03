import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// The options of KDE's icons-only task manager (Behavior and Appearance pages), in its words
KCM.SimpleKCM {
    property alias cfg_showPinned: pinned.checked
    property alias cfg_separateLaunchers: separate.checked
    property alias cfg_showOnlyCurrentDesktop: desk.checked
    property alias cfg_showOnlyCurrentScreen: screen.checked
    property alias cfg_showOnlyCurrentActivity: activity.checked
    property alias cfg_showOnlyMinimized: minimized.checked
    property alias cfg_unhideOnAttention: unhide.checked
    property int cfg_groupingStrategy
    property int cfg_groupedTaskVisualization
    property var cfg_groupingAppIdBlacklist
    property var cfg_groupingLauncherUrlBlacklist
    property int cfg_sortingStrategy
    property alias cfg_minimizeActiveTaskOnClick: minimizeActive.checked
    property int cfg_middleClickAction
    property int cfg_wheelEnabled
    property alias cfg_wheelSkipMinimized: wheelSkip.checked
    property bool cfg_reverseMode
    property alias cfg_showToolTips: tips.checked
    property alias cfg_highlightWindows: highlight.checked
    property alias cfg_indicateAudioStreams: audio.checked
    property alias cfg_interactiveMute: mute.checked
    property alias cfg_tooltipControls: controls.checked
    property alias cfg_showRunningIndicator: indicator.checked
    property alias cfg_highlightAttention: attention.checked
    property bool cfg_showPinnedDefault
    property bool cfg_separateLaunchersDefault
    property bool cfg_showOnlyCurrentDesktopDefault
    property bool cfg_showOnlyCurrentScreenDefault
    property bool cfg_showOnlyCurrentActivityDefault
    property bool cfg_showOnlyMinimizedDefault
    property bool cfg_unhideOnAttentionDefault
    property int cfg_groupingStrategyDefault
    property int cfg_groupedTaskVisualizationDefault
    property var cfg_groupingAppIdBlacklistDefault
    property var cfg_groupingLauncherUrlBlacklistDefault
    property int cfg_sortingStrategyDefault
    property bool cfg_minimizeActiveTaskOnClickDefault
    property int cfg_middleClickActionDefault
    property int cfg_wheelEnabledDefault
    property bool cfg_wheelSkipMinimizedDefault
    property bool cfg_reverseModeDefault
    property bool cfg_showToolTipsDefault
    property bool cfg_highlightWindowsDefault
    property bool cfg_indicateAudioStreamsDefault
    property bool cfg_interactiveMuteDefault
    property bool cfg_tooltipControlsDefault
    property bool cfg_showRunningIndicatorDefault
    property bool cfg_highlightAttentionDefault

    Kirigami.FormLayout {
        QQC.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox how to group tasks", "Group:")
            model: [i18nc("@item:inlistbox how to group tasks", "Do not group"), i18nc("@item:inlistbox how to group tasks", "By program name")]
            currentIndex: cfg_groupingStrategy
            onActivated: index => cfg_groupingStrategy = index
        }
        QQC.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox completes sentence like: … cycles through tasks", "Clicking grouped task:")
            enabled: cfg_groupingStrategy !== 0
            model: [i18nc("@item:inlistbox", "Cycles through tasks"), i18nc("@item:inlistbox", "Shows small window previews"),
                    i18nc("@item:inlistbox", "Shows large window previews"), i18nc("@item:inlistbox", "Shows textual list")]
            currentIndex: cfg_groupedTaskVisualization
            onActivated: index => cfg_groupedTaskVisualization = index
        }

        Item { Kirigami.FormData.isSection: true }
        QQC.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox sort tasks in grouped task", "Sort:")
            model: [i18nc("@item:inlistbox", "Do not sort"), i18nc("@item:inlistbox", "Manually"), i18nc("@item:inlistbox", "Alphabetically"),
                    i18nc("@item:inlistbox", "By desktop"), i18nc("@item:inlistbox", "By activity"), i18nc("@item:inlistbox", "By horizontal window position")]
            currentIndex: cfg_sortingStrategy
            onActivated: index => cfg_sortingStrategy = index
        }
        QQC.CheckBox { id: separate; text: i18nc("@option:check configure task sorting", "Keep launchers separate"); enabled: cfg_sortingStrategy === 1 }
        QQC.CheckBox { id: pinned; text: i18n("Show pinned apps that are not running") }

        Item { Kirigami.FormData.isSection: true }
        QQC.CheckBox {
            id: minimizeActive
            Kirigami.FormData.label: i18nc("@label for checkbox Part of a sentence: 'Clicking active task minimizes the task'", "Clicking active task:")
            text: i18nc("@option:check Part of a sentence: 'Clicking active task minimizes the task'", "Minimizes the task")
        }
        QQC.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox completes sentence like: … does nothing", "Middle-clicking any task:")
            model: [i18nc("@item:inlistbox", "Does nothing"), i18nc("@item:inlistbox", "Closes window or group"), i18nc("@item:inlistbox", "Opens a new window"),
                    i18nc("@item:inlistbox", "Minimizes/Restores window or group"), i18nc("@item:inlistbox", "Toggles grouping"),
                    i18nc("@item:inlistbox", "Brings it to the current virtual desktop")]
            currentIndex: cfg_middleClickAction
            onActivated: index => cfg_middleClickAction = index
        }
        QQC.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Scrolling behavior:")
            model: [i18nc("@item:inlistbox", "Does nothing"), i18nc("@item:inlistbox", "Cycles through all tasks"),
                    i18nc("@item:inlistbox", "Cycles through the hovered task’s windows"), i18nc("@item:inlistbox", "Adjusts the hovered task’s volume")]
            currentIndex: cfg_wheelEnabled
            onActivated: index => cfg_wheelEnabled = index
        }
        QQC.CheckBox { id: wheelSkip; text: i18nc("@option:check mouse wheel task cycling", "Skip minimized tasks"); enabled: cfg_wheelEnabled === 1 || cfg_wheelEnabled === 2 }

        Item { Kirigami.FormData.isSection: true }
        QQC.CheckBox { id: desk; Kirigami.FormData.label: i18nc("@label for checkbox group", "Show only tasks:"); text: i18nc("@option:check", "From the current desktop") }
        QQC.CheckBox { id: activity; text: i18nc("@option:check", "From the current activity") }
        QQC.CheckBox { id: screen; text: i18nc("@option:check", "From the current screen") }
        QQC.CheckBox { id: minimized; text: i18nc("@option:check", "That are minimized") }

        Item { Kirigami.FormData.isSection: true }
        QQC.CheckBox {
            id: unhide
            Kirigami.FormData.label: i18nc("@label for checkbox", "When panel is hidden:")
            text: i18nc("@option:check", "Unhide when a window wants attention")
        }
        QQC.RadioButton {
            Kirigami.FormData.label: i18nc("@label for radiobutton group", "New tasks appear:")
            text: i18nc("@option:check completes sentence: New tasks appear", "On the bottom")
            checked: !cfg_reverseMode
            onToggled: if (checked) cfg_reverseMode = false
        }
        QQC.RadioButton {
            text: i18nc("@option:check completes sentence: New tasks appear", "On the top")
            checked: cfg_reverseMode
            onToggled: if (checked) cfg_reverseMode = true
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Appearance") }
        QQC.CheckBox { id: tips; Kirigami.FormData.label: i18nc("@label for several checkboxes", "General:"); text: i18nc("@option:check", "Show small window previews when hovering over tasks") }
        QQC.CheckBox { id: highlight; text: tips.checked ? i18nc("@option:check", "Hide other windows when hovering over previews") : i18nc("@option:check", "Hide other windows when hovering over tooltips") }
        QQC.CheckBox { id: audio; text: i18nc("@option:check", "Show an indicator when a task is playing audio") }
        QQC.CheckBox { id: mute; text: i18nc("@option:check", "Mute task when clicking indicator"); enabled: audio.checked; Layout.leftMargin: Kirigami.Units.gridUnit }
        QQC.CheckBox { id: controls; text: i18nc("@option:check", "Show media and volume controls in tooltip") }
        QQC.CheckBox { id: indicator; text: i18n("Mark running apps on the screen edge, one mark per window") }
        QQC.CheckBox { id: attention; text: i18n("Highlight apps that ask for attention") }
    }
}
