/*
    one lock screen. Replaces LockScreenUi.qml of the stock Plasma shell package;
    the authentication logic follows the stock file (GPL-2.0-or-later, KDE).
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import QtQuick.Layouts

import org.kde.plasma.private.accessibility
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.ki18n
import org.kde.plasma.private.sessions
import org.kde.plasma.private.battery

Item {
    id: ui

    property bool expectingPrompt: false
    property bool showPrompt: false
    property bool passwordInputVisible: true
    property bool noPasswordUnlock: false
    property string pendingPassword

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Palette follows the active color scheme (one-light / one-dark)
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    readonly property color text: Kirigami.Theme.textColor
    readonly property color text2: ui.fade(text, 0.68)
    readonly property color text3: ui.fade(text, 0.5)
    readonly property color card: Kirigami.Theme.backgroundColor
    readonly property bool dark: ui.card.hslLightness < 0.5
    readonly property color glass: ui.fade(ui.card, dark ? 0.6 : 0.7)
    readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.045)
    readonly property color stroke: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)
    readonly property color strokeStrong: dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.2)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color active: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accentFg: Kirigami.Theme.highlightedTextColor
    readonly property color danger: Kirigami.Theme.negativeTextColor

    function i18nd(ctx, s) { return i18ndc("plasma_shell_org.kde.plasma.desktop", ctx, s) }

    function handleMessage(msg) {
        if (!msg)
            return
        if (!root.notification)
            root.notification = msg
        else if (root.notification.includes(msg))
            root.notificationRepeated()
        else
            root.notification += "\n" + msg
        lockScreenRoot.uiVisible = true
    }

    function submit() {
        if (!lockScreenRoot.uiVisible)
            return
        if (ui.noPasswordUnlock) {
            Qt.quit()
            return
        }
        const pw = password.text
        if (authenticator.pamTimeout) {
            ui.pendingPassword = pw
            password.enabled = false
        } else {
            authenticator.respond(pw)
        }
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0)
                return
            ui.handleMessage(ui.i18nd("@info:status", "Unlocking failed"))
            root.clearPassword()
            authenticator.startAuthenticating()
            notificationRemoveTimer.restart()
            shake.restart()
        }
        function onSucceeded() {
            authenticator.stopAuthenticating()
            if (!ui.expectingPrompt || authenticator.hadPrompt) {
                Qt.quit()
            } else {
                ui.noPasswordUnlock = true
                unlockButton.forceActiveFocus()
            }
        }
        function onInfoMessageChanged() { ui.handleMessage(authenticator.infoMessage) }
        function onErrorMessageChanged() { ui.handleMessage(authenticator.errorMessage) }
        function onPromptChanged() { ui.handleMessage(authenticator.prompt) }
        function onPromptForSecretChanged() {
            password.forceActiveFocus()
            if (ui.showPrompt)
                ui.handleMessage(authenticator.promptForSecret)
        }
        function onPamTimeoutChanged() {
            if (!authenticator.pamTimeout && ui.pendingPassword.length > 0) {
                authenticator.respond(ui.pendingPassword)
                ui.pendingPassword = ""
                password.enabled = true
            }
        }
    }

    Connections {
        target: root
        function onClearPassword() {
            password.forceActiveFocus()
            password.text = ""
            password.text = Qt.binding(() => PasswordSync.password)
        }
        function onNotificationRepeated() { shake.restart() }
    }

    SessionManagement { id: sessionManagement; onAboutToSuspend: root.clearPassword() }
    AccessibilityStatus { id: accessibilityStatus }
    KeyboardIndicator.KeyState { id: capsLockState; key: Qt.Key_CapsLock }
    BatteryControlModel { id: battery }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (password.text.length > 0 || ui.noPasswordUnlock || powerMenu.visible || Keyboards.KWinVirtualKeyboard.visible)

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true
        onPositionChanged: {
            uiVisible = seenPositionChange
            seenPositionChange = true
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate()
                password.forceActiveFocus()
            }
            if (blockUI)
                fadeoutTimer.running = false
            else if (uiVisible)
                fadeoutTimer.restart()
            authenticator.startAuthenticating()
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false
                uiVisible = true
            } else {
                fadeoutTimer.restart()
            }
        }
        Keys.onEscapePressed: {
            // kscreenlocker turns the screen off on Escape; keep the prompt hidden then
            if (uiVisible) {
                uiVisible = false
                if (Keyboards.KWinVirtualKeyboard.visible)
                    Keyboards.KWinVirtualKeyboard.active = false
                root.clearPassword()
            }
        }
        Keys.onPressed: event => {
            uiVisible = true
            event.accepted = false
        }

        Timer {
            // heartbeat keeping the backend active while the prompt is visible
            interval: 1000
            running: !authenticator.unlocked && lockScreenRoot.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }
        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI)
                    lockScreenRoot.uiVisible = false
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }
        ScreenLocker.ActiveScreenMonitor {
            lockscreenState: ScreenLocker.LockscreenState
            window: lockScreenRoot.Window.window
            onActiveChanged: if (!active) lockScreenRoot.uiVisible = false
        }

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        // 0 = idle (sharp wallpaper and clock), 1 = prompt (blurred, veiled, card)
        property real factor: uiVisible ? 1 : 0
        Behavior on factor { NumberAnimation { duration: 380; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

        ShaderEffectSource {
            id: wallpaperSource
            anchors.fill: parent
            sourceItem: wallpaper
            hideSource: true
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wallpaperSource
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 0.55 * lockScreenRoot.factor
            saturation: 0.1 * lockScreenRoot.factor
        }
        Rectangle {
            anchors.fill: parent
            color: ui.dark ? "#000000" : "#ffffff"
            opacity: (ui.dark ? 0.32 : 0.18) * lockScreenRoot.factor
        }

        // Clock
        Column {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.085
            spacing: -10
            visible: config.alwaysShowClock && (!config.hideClockWhenIdle || lockScreenRoot.uiVisible)
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.now, "dddd, d MMMM")
                color: "white"
                opacity: 0.92
                font { pixelSize: 22; weight: Font.Medium }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
                color: "white"
                font { pixelSize: 128; weight: Font.Bold; letterSpacing: -7 }
            }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#59000000"; shadowBlur: 0.6; shadowVerticalOffset: 2 }
        }

        // Card
        Item {
            id: prompt
            anchors.fill: parent
            opacity: lockScreenRoot.factor
            visible: opacity > 0

            RectangularShadow {
                anchors.fill: cardBox
                radius: cardBox.radius
                offset.y: 22
                blur: 60
                spread: -12
                color: Qt.rgba(0, 0, 0, ui.dark ? 0.55 : 0.28)
            }
            Rectangle {
                id: cardBox
                width: 400
                height: cardCol.implicitHeight + 60
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: shakeX
                y: parent.height * 0.42 + (1 - lockScreenRoot.factor) * 24
                radius: 22
                color: ui.card
                border.width: 1
                border.color: ui.stroke
                property real shakeX: 0

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: cardBox; property: "shakeX"; to: -10; duration: 50 }
                    NumberAnimation { target: cardBox; property: "shakeX"; to: 10; duration: 80 }
                    NumberAnimation { target: cardBox; property: "shakeX"; to: 0; duration: 50 }
                }

                Column {
                    id: cardCol
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 30
                    width: parent.width - 60

                    Avatar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 96
                        source: kscreenlocker_userImage !== ""
                                ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                    }
                    Item { width: 1; height: 14 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: kscreenlocker_userName
                        color: ui.text
                        font { pixelSize: 21; weight: 750 }
                    }
                    Item { width: 1; height: 16 }

                    QQC.TextField {
                        id: password
                        visible: ui.passwordInputVisible && !ui.noPasswordUnlock
                        width: parent.width
                        height: 46
                        leftPadding: 18
                        rightPadding: 52
                        text: PasswordSync.password
                        echoMode: TextInput.Password
                        passwordCharacter: "\u2022"
                        placeholderText: ui.i18nd("@info:placeholder in text field", "Password")
                        placeholderTextColor: ui.text3
                        color: ui.text
                        selectionColor: ui.accent
                        selectedTextColor: ui.accentFg
                        verticalAlignment: TextInput.AlignVCenter
                        font { pixelSize: 15; letterSpacing: text.length ? 2 : 0 }
                        focus: true
                        // stops cursor blinking renders while the prompt is hidden
                        cursorVisible: lockScreenRoot.uiVisible && activeFocus
                        onAccepted: ui.submit()
                        Keys.onPressed: event => { lockScreenRoot.uiVisible = true; event.accepted = false }
                        background: Rectangle {
                            radius: height / 2
                            color: ui.field
                            border.width: password.activeFocus ? 2 : 1
                            border.color: password.activeFocus ? ui.accent : ui.strokeStrong
                        }
                        RoundBtn {
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            size: 34
                            accent: true
                            iconName: "go-next-symbolic"
                            Accessible.name: ui.i18nd("@action:button accessible only", "Unlock")
                            onClicked: ui.submit()
                        }
                    }
                    Binding { target: PasswordSync; property: "password"; value: password.text }

                    QQC.AbstractButton {
                        id: unlockButton
                        visible: !password.visible
                        width: parent.width
                        height: 46
                        hoverEnabled: true
                        onClicked: ui.noPasswordUnlock ? Qt.quit() : authenticator.startAuthenticating()
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()
                        background: Rectangle {
                            radius: height / 2
                            color: unlockButton.down ? Qt.darker(ui.accent, 1.15) : unlockButton.hovered ? Qt.lighter(ui.accent, 1.08) : ui.accent
                        }
                        contentItem: Text {
                            text: ui.i18nd("@action:button", "Unlock")
                            color: ui.accentFg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font { pixelSize: 15; weight: Font.DemiBold }
                        }
                    }

                    Item { width: 1; height: 12 }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        readonly property string notice: {
                            const parts = []
                            if (capsLockState.locked)
                                parts.push(ui.i18nd("@info:status", "Caps Lock is on"))
                            if (accessibilityStatus.slowKeysEnabled)
                                parts.push(ui.i18nd("@info:status", "Slow Keys are enabled"))
                            if (root.notification)
                                parts.push(root.notification)
                            return parts.join(" \u2022 ")
                        }
                        text: notice !== "" ? notice : ui.i18nd("@info:placeholder in text field", "Password")
                        color: root.notification ? ui.danger : ui.text2
                        opacity: notice !== "" ? 1 : 0
                        font { pixelSize: 13; weight: notice !== "" ? Font.DemiBold : Font.Normal }
                    }

                    FailableLabel {
                        kind: ScreenLocker.Authenticator.Fingerprint
                        label: ui.i18nd("@info:usagetip", "(or scan your fingerprint on the reader)")
                    }
                    FailableLabel {
                        kind: ScreenLocker.Authenticator.Smartcard
                        label: ui.i18nd("@info:usagetip", "(or scan your smartcard)")
                    }

                    // Authenticator switcher (password, fingerprint, smartcard...)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        topPadding: 8
                        visible: authTypes.count > 1
                        Repeater {
                            id: authTypes
                            model: ScreenLocker.AuthenticatorModel
                            delegate: RoundBtn {
                                required property int type
                                required property string iconName
                                required property bool passwordField
                                required property bool expectingPrompt
                                required property string tooltip
                                required property bool showPrompt
                                required property bool functional

                                size: 36
                                checked: authenticator.authenticator === type
                                enabled: functional
                                iconSource: iconName
                                QQC.ToolTip.text: tooltip
                                QQC.ToolTip.visible: hovered
                                QQC.ToolTip.delay: Kirigami.Units.toolTipDelay
                                onFunctionalChanged: {
                                    if (functional)
                                        return
                                    root.notification = ""
                                    ui.passwordInputVisible = false
                                    ui.handleMessage(ui.i18nd("@info:status", "This authentication method is not functioning correctly. Please try another method, and check your system configuration."))
                                }
                                onClicked: {
                                    authenticator.authenticator = type
                                    root.notification = ""
                                    ui.passwordInputVisible = passwordField
                                    ui.expectingPrompt = expectingPrompt
                                    ui.showPrompt = showPrompt
                                }
                                Component.onCompleted: if (checked) clicked()
                            }
                        }
                    }
                }
            }

            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: cardBox.bottom
                anchors.topMargin: 16
                width: cardBox.width
                active: config.showMediaControls
                source: "MediaControls.qml"
                Kirigami.Theme.inherit: false
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
            }

            // Bottom bar: keyboard (left), battery and power (right)
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: 10
                RoundBtn {
                    size: 40
                    glass: true
                    iconName: Keyboards.KWinVirtualKeyboard.visible ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                    visible: Keyboards.KWinVirtualKeyboard.available
                    Accessible.name: ui.i18nd("Button to show/hide virtual keyboard", "Virtual Keyboard")
                    onClicked: {
                        if (Keyboards.KWinVirtualKeyboard.visible) {
                            Keyboards.KWinVirtualKeyboard.active = false
                        } else {
                            password.forceActiveFocus()
                            Keyboards.KWinVirtualKeyboard.forceActivate()
                        }
                    }
                }
                Pill {
                    id: layoutPill
                    visible: layoutSwitcher.hasMultipleKeyboardLayouts
                    Accessible.description: ui.i18nd("Button to change keyboard layout", "Switch layout")
                    onClicked: layoutSwitcher.keyboardLayout.switchToNextLayout()
                    PW.KeyboardLayoutSwitcher {
                        id: layoutSwitcher
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                    }
                    contentItem: Text {
                        leftPadding: 6
                        rightPadding: 6
                        text: layoutSwitcher.layoutNames.shortName.toUpperCase()
                        color: ui.text
                        font { pixelSize: 13; weight: Font.DemiBold }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: 10
                Pill {
                    visible: battery.hasInternalBatteries
                    hoverEnabled: false
                    contentItem: Row {
                        spacing: 6
                        leftPadding: 4
                        rightPadding: 6
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            isMask: true
                            color: ui.text
                            source: {
                                const level = Math.min(100, Math.round(battery.percent / 10) * 10)
                                const suffix = battery.state === BatteryControlModel.FullyCharged && level === 100 ? "-charged"
                                             : battery.state === BatteryControlModel.Charging ? "-charging"
                                             : battery.pluggedIn ? "-plugged-in" : ""
                                return "battery-level-" + level + suffix + "-symbolic"
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: battery.percent + "%"
                            color: ui.text
                            font { pixelSize: 13; weight: Font.DemiBold; features: { "tnum": 1 } }
                        }
                    }
                }
                RoundBtn {
                    id: powerBtn
                    size: 40
                    glass: true
                    iconName: "system-shutdown-symbolic"
                    visible: sessionManagement.canSuspend || sessionManagement.canHibernate || sessionManagement.canSwitchUser
                    onClicked: powerMenu.visible ? powerMenu.close() : powerMenu.open()
                    QQC.Menu {
                        id: powerMenu
                        x: parent.width - width
                        y: -height - 8
                        padding: 6
                        background: Rectangle {
                            implicitWidth: 220
                            radius: 14
                            color: ui.card
                            border.width: 1
                            border.color: ui.stroke
                        }
                        MenuEntry {
                            text: ui.i18nd("@action:button", "Slee&p").replace("&", "")
                            iconName: "media-playback-pause-symbolic"
                            shown: sessionManagement.canSuspend
                            onTriggered: sessionManagement.suspend()
                        }
                        MenuEntry {
                            text: ui.i18nd("@action:button", "&Hibernate").replace("&", "")
                            iconName: "document-save-symbolic"
                            shown: sessionManagement.canHibernate
                            onTriggered: sessionManagement.hibernate()
                        }
                        MenuEntry {
                            text: ui.i18nd("@action:button", "Switch &User").replace("&", "")
                            iconName: "system-users-symbolic"
                            shown: sessionManagement.canSwitchUser
                            onTriggered: sessionManagement.switchUser()
                        }
                    }
                }
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.gridUnit
        }
    }

    // ---- components ----

    component Avatar: Item {
        id: av
        property real size: 96
        property string source: ""
        width: size
        height: size
        readonly property bool hasImage: img.status === Image.Ready

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: !av.hasImage
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(ui.accent, 1.35) }
                GradientStop { position: 1; color: ui.accent }
            }
            clip: true
            Rectangle {
                width: parent.width * 0.6; height: parent.height * 0.7
                radius: width / 2
                x: (parent.width - width) / 2; y: parent.height * 0.52
                color: Qt.rgba(1, 1, 1, 0.85)
            }
            Rectangle {
                width: parent.width * 0.3; height: width; radius: width / 2
                x: (parent.width - width) / 2; y: parent.height * 0.22
                color: Qt.rgba(1, 1, 1, 0.95)
            }
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: avMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        }
        Image {
            id: img
            anchors.fill: parent
            source: av.source
            sourceSize: Qt.size(av.size * 2, av.size * 2)
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            visible: av.hasImage
            maskEnabled: true
            maskSource: avMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Rectangle {
            id: avMask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }
    }

    component RoundBtn: QQC.AbstractButton {
        id: rb
        property real size: 36
        property bool accent: false
        property bool glass: false
        property string iconName: ""
        property string iconSource: ""
        width: size
        height: size
        hoverEnabled: true
        focusPolicy: Qt.TabFocus
        opacity: enabled ? 1 : 0.5
        background: Rectangle {
            radius: width / 2
            color: rb.accent ? (rb.down ? Qt.darker(ui.accent, 1.15) : rb.hovered ? Qt.lighter(ui.accent, 1.08) : ui.accent)
                 : rb.glass ? ui.glass
                 : rb.checked ? ui.active
                 : rb.down ? ui.active : rb.hovered ? ui.hover : "transparent"
            border.width: rb.glass ? 1 : 0
            border.color: ui.stroke
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: rb.glass
                color: rb.down ? ui.active : rb.hovered ? ui.hover : "transparent"
            }
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: rb.iconSource !== "" ? rb.iconSource : rb.iconName
                isMask: rb.iconSource === ""
                color: rb.accent ? ui.accentFg : ui.text
            }
        }
    }

    component Pill: QQC.AbstractButton {
        id: pill
        hoverEnabled: true
        padding: 8
        height: 40
        background: Rectangle {
            radius: height / 2
            color: ui.glass
            border.width: 1
            border.color: ui.stroke
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: pill.down ? ui.active : pill.hovered ? ui.hover : "transparent"
            }
        }
    }

    component MenuEntry: QQC.MenuItem {
        id: me
        property string iconName: ""
        property bool shown: true
        visible: shown
        height: shown ? implicitHeight : 0
        implicitHeight: 36
        implicitWidth: 220
        contentItem: Row {
            spacing: 10
            leftPadding: 4
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                isMask: true
                color: ui.text
                source: me.iconName
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: me.text
                color: ui.text
                font { pixelSize: 14; weight: Font.Medium }
            }
        }
        background: Rectangle {
            radius: 8
            color: me.highlighted ? ui.hover : "transparent"
        }
    }

    component FailableLabel: Text {
        id: fl
        required property int kind
        required property string label
        visible: authenticator.authenticatorTypes & kind
        width: parent ? parent.width : 0
        topPadding: 6
        text: label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: ui.text2
        font.pixelSize: 13
        Connections {
            target: authenticator
            function onNoninteractiveError(kind, auth) {
                if (kind & fl.kind) {
                    fl.text = Qt.binding(() => auth.errorMessage)
                    fl.color = ui.danger
                    flTimer.restart()
                    shake.restart()
                }
            }
        }
        Timer {
            id: flTimer
            interval: Kirigami.Units.humanMoment
            onTriggered: { fl.text = Qt.binding(() => fl.label); fl.color = ui.text2 }
        }
    }
}
