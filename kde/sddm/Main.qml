// One login screen for SDDM (Qt 6). Colors and sizes come from theme.conf.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects

Item {
    id: root
    width: 1600
    height: 1000

    readonly property bool dark: cfg("Mode", "light") === "dark"
    readonly property string mode: dark ? "dark" : "light"
    readonly property string fontFamily: inter.status === FontLoader.Ready ? inter.font.family : "sans-serif"
    readonly property real s: Math.max(0.5, Math.min(3, Number(cfg("Scale", "1")) || 1))

    function cfg(key, fallback) {
        const v = config.stringValue(key)
        return v === undefined || v === "" ? fallback : v
    }
    function col(key) { return cfg(mode + "_" + key, "#ff00ff") }
    function icon(name, onAccent) { return "icons/" + mode + "/" + name + (onAccent ? "-on" : "") + ".svg" }

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool manualUser: userModel.count === 0
    property string userName: manualUser ? manualName.text : (root.currentUser ? root.currentUser.uName : "")
    property bool busy: false
    property string message: ""

    function login() {
        if (userName === "" || busy)
            return
        busy = true
        message = ""
        sddm.login(userName, password.text, sessionIndex)
    }

    FontLoader { id: inter; source: "fonts/InterVariable.ttf" }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy = false
            password.text = ""
            message = cfg("TextFailed", "Wrong password, try again")
            shake.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { busy = false }
    }

    // Users list model (hidden view, used for selection and the avatar strip)
    readonly property Item currentUser: userCount > 0 ? userList.itemAt(Math.min(userIndex, userCount - 1)) : null
    readonly property Item currentSession: sessionCount > 0 ? sessionList.itemAt(Math.min(sessionIndex, sessionCount - 1)) : null
    property int userCount: 0
    property int sessionCount: 0

    Repeater {
        id: userList
        model: userModel
        onCountChanged: root.userCount = count
        delegate: Item {
            required property string name
            required property string realName
            required property string icon
            readonly property string uName: name
            readonly property string uLabel: realName !== "" ? realName : name
            readonly property string uIcon: icon
        }
    }

    Repeater {
        id: sessionList
        model: sessionModel
        onCountChanged: root.sessionCount = count
        delegate: Item {
            required property string name
            readonly property string sName: name
        }
    }

    // Background: wallpaper, softly blurred, with a light veil
    Image {
        id: wallpaper
        anchors.fill: parent
        source: cfg(mode + "_Background", "background-" + mode + ".jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: false
    }
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 0.55
        saturation: 0.1
    }
    Rectangle { anchors.fill: parent; color: col("Veil") }

    // Clock
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.085
        spacing: -10 * s
        property date now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.now, cfg("DateFormat", "dddd, d MMMM"))
            color: col("OnWallpaper")
            opacity: 0.92
            font { family: root.fontFamily; pixelSize: 22 * s; weight: Font.Medium }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.now, cfg("TimeFormat", "HH:mm"))
            color: col("OnWallpaper")
            font { family: root.fontFamily; pixelSize: 128 * s; weight: Font.Bold; letterSpacing: -7 * s }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#40000000"; shadowBlur: 0.6; shadowVerticalOffset: 2 }
        }
    }

    // Login card
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 22 * s
        blur: 60 * s
        spread: -12 * s
        color: col("Shadow")
    }
    Rectangle {
        id: card
        width: 400 * s
        height: cardCol.implicitHeight + 60 * s
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: shakeX
        y: parent.height * 0.42
        radius: Number(cfg("Radius", 22)) * s
        color: col("Card")
        border.width: 1
        border.color: col("Stroke")
        property real shakeX: 0

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: card; property: "shakeX"; to: -10 * s; duration: 50 }
            NumberAnimation { target: card; property: "shakeX"; to: 10 * s; duration: 80 }
            NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 50 }
        }

        Column {
            id: cardCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30 * s
            width: parent.width - 60 * s
            spacing: 0

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 96 * s
                source: root.manualUser ? "" : (root.currentUser ? root.currentUser.uIcon : "")
            }
            Item { width: 1; height: 14 * s }
            Text {
                visible: !root.manualUser
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.currentUser ? root.currentUser.uLabel : ""
                color: col("Text")
                font { family: root.fontFamily; pixelSize: 21 * s; weight: 750 }
            }
            Field {
                id: manualName
                visible: root.manualUser
                width: parent.width
                placeholderText: cfg("TextUsername", "Username")
                onAccepted: password.forceActiveFocus()
            }
            Item { width: 1; height: 16 * s }
            Field {
                id: password
                width: parent.width
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                placeholderText: cfg("TextPassword", "Password")
                rightPadding: 52 * s
                enabled: !root.busy
                onAccepted: root.login()
                onTextEdited: root.message = ""
                focus: true

                RoundBtn {
                    anchors.right: parent.right
                    anchors.rightMargin: 5 * s
                    anchors.verticalCenter: parent.verticalCenter
                    size: 34 * s
                    accent: true
                    iconName: "go-next"
                    onClicked: root.login()
                }
            }
            Item { width: 1; height: 12 * s }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.message !== "" ? root.message
                     : keyboard.capsLock ? cfg("TextCapsLock", "Caps Lock is on")
                     : cfg("TextHint", "Enter your password")
                color: root.message !== "" ? col("Danger") : col("Text2")
                font { family: root.fontFamily; pixelSize: 12.5 * s; weight: keyboard.capsLock || root.message !== "" ? Font.DemiBold : Font.Normal }
            }
        }
    }

    // Other users
    Pill {
        id: usersPill
        visible: userModel.count > 1 || root.manualUser
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.835
        padding: 6 * s
        contentItem: Row {
            spacing: 10 * s
            Repeater {
                model: userModel
                delegate: Item {
                    id: u
                    required property int index
                    required property string icon
                    required property string name
                    width: 36 * s
                    height: 36 * s
                    visible: root.manualUser || index !== root.userIndex
                    Avatar { anchors.centerIn: parent; size: 36 * s; source: u.icon; seed: u.name }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.manualUser = false; root.userIndex = u.index; password.text = ""; password.forceActiveFocus() }
                    }
                }
            }
            RoundBtn {
                size: 36 * s
                flat: true
                iconName: "list-add"
                visible: !root.manualUser
                onClicked: { root.manualUser = true; manualName.text = ""; manualName.forceActiveFocus() }
            }
        }
    }

    // Bottom bar: session (left), keyboard layout and power (right)
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24 * s
        spacing: 10 * s
        Pill {
            id: sessionBtn
            visible: sessionModel.count > 1
            hoverable: true
            onClicked: sessionMenu.open()
            contentItem: Row {
                spacing: 8 * s
                leftPadding: 6 * s
                rightPadding: 4 * s
                Image { anchors.verticalCenter: parent.verticalCenter; source: root.icon("computer"); sourceSize: Qt.size(16 * s, 16 * s) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentSession ? root.currentSession.sName : ""
                    color: col("Text")
                    font { family: root.fontFamily; pixelSize: 14 * s; weight: Font.DemiBold }
                }
                Image { anchors.verticalCenter: parent.verticalCenter; source: root.icon("pan-down"); sourceSize: Qt.size(16 * s, 16 * s) }
            }
            PopMenu {
                id: sessionMenu
                y: -height - 8 * s
                Instantiator {
                    model: sessionModel
                    delegate: MenuEntry {
                        required property int index
                        required property string name
                        text: name
                        current: index === root.sessionIndex
                        onTriggered: root.sessionIndex = index
                    }
                    onObjectAdded: (i, o) => sessionMenu.insertItem(i, o)
                    onObjectRemoved: (i, o) => sessionMenu.removeItem(o)
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24 * s
        spacing: 10 * s
        Pill {
            visible: keyboard.layouts.length > 1
            hoverable: true
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            contentItem: Text {
                leftPadding: 6 * s
                rightPadding: 6 * s
                text: keyboard.layouts.length ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
                color: col("Text")
                font { family: root.fontFamily; pixelSize: 13 * s; weight: Font.DemiBold }
            }
        }
        RoundBtn {
            id: powerBtn
            size: 40 * s
            glass: true
            iconName: "system-shutdown"
            onClicked: powerMenu.open()
            PopMenu {
                id: powerMenu
                x: parent.width - width
                y: -height - 8 * s
                MenuEntry { text: cfg("TextSuspend", "Suspend"); visible: sddm.canSuspend; height: visible ? implicitHeight : 0; onTriggered: sddm.suspend() }
                MenuEntry { text: cfg("TextReboot", "Restart"); visible: sddm.canReboot; height: visible ? implicitHeight : 0; onTriggered: sddm.reboot() }
                MenuEntry { text: cfg("TextPowerOff", "Shut Down"); visible: sddm.canPowerOff; height: visible ? implicitHeight : 0; onTriggered: sddm.powerOff() }
            }
        }
    }

    Component.onCompleted: (manualUser ? manualName : password).forceActiveFocus()

    // ---- components ----

    component Avatar: Item {
        id: av
        property real size: 96
        property string source: ""
        property string seed: ""
        width: size
        height: size
        readonly property bool hasImage: img.status === Image.Ready
        readonly property int hue: { let h = 0; for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 360; return h }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: !av.hasImage
            gradient: Gradient {
                GradientStop { position: 0; color: av.seed === "" ? col("AvatarA") : Qt.hsla(av.hue / 360, 0.55, 0.62, 1) }
                GradientStop { position: 1; color: av.seed === "" ? col("AvatarB") : Qt.hsla(((av.hue + 50) % 360) / 360, 0.55, 0.5, 1) }
            }
        }
        // Generic person, drawn only on the large avatar
        Item {
            anchors.fill: parent
            visible: !av.hasImage && av.seed === ""
            Rectangle {
                width: parent.width * 0.6; height: parent.height * 0.7
                radius: width / 2
                x: (parent.width - width) / 2; y: parent.height * 0.52
                color: col("AvatarBody")
            }
            Rectangle {
                width: parent.width * 0.3; height: width; radius: width / 2
                x: (parent.width - width) / 2; y: parent.height * 0.22
                color: col("AvatarHead")
            }
        }
        Image {
            id: img
            anchors.fill: parent
            // SDDM hands out its stock outline face when the user has none; draw ours instead
            source: av.source.endsWith("/.face.icon") ? "" : av.source
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
        // Clip the generic body to the circle
        layer.enabled: !av.hasImage && av.seed === ""
        layer.effect: MultiEffect { maskEnabled: true; maskSource: avMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
    }

    component Field: TextField {
        height: 46 * s
        leftPadding: 18 * s
        rightPadding: 18 * s
        color: col("Text")
        placeholderTextColor: col("Text3")
        selectionColor: col("Accent")
        selectedTextColor: col("OnAccent")
        font { family: root.fontFamily; pixelSize: 15 * s; letterSpacing: echoMode === TextInput.Password && text.length ? 2 : 0 }
        verticalAlignment: TextInput.AlignVCenter
        background: Rectangle {
            radius: height / 2
            color: col("Field")
            border.width: parent.activeFocus ? 2 : 1
            border.color: parent.activeFocus ? col("Accent") : col("StrokeStrong")
        }
    }

    component RoundBtn: AbstractButton {
        id: rb
        property real size: 36
        property bool accent: false
        property bool glass: false
        property bool flat: false
        property string iconName: ""
        width: size
        height: size
        hoverEnabled: true
        background: Rectangle {
            radius: width / 2
            color: rb.accent ? (rb.down ? col("AccentPressed") : rb.hovered ? col("AccentHover") : col("Accent"))
                 : rb.glass ? col("Glass")
                 : rb.down ? col("Active") : rb.hovered ? col("Hover") : "transparent"
            border.width: rb.glass ? 1 : 0
            border.color: col("Stroke")
            Rectangle { anchors.fill: parent; radius: width / 2; visible: rb.glass; color: rb.down ? col("Active") : rb.hovered ? col("Hover") : "transparent" }
        }
        contentItem: Item {
            Image {
                anchors.centerIn: parent
                source: root.icon(rb.iconName, rb.accent)
                sourceSize: Qt.size(16 * s, 16 * s)
            }
        }
    }

    component Pill: AbstractButton {
        id: pill
        property bool hoverable: false
        hoverEnabled: hoverable
        padding: 8 * s
        height: 40 * s
        background: Rectangle {
            radius: height / 2
            color: col("Glass")
            border.width: 1
            border.color: col("Stroke")
            Rectangle { anchors.fill: parent; radius: height / 2; color: pill.down ? col("Active") : pill.hovered ? col("Hover") : "transparent" }
        }
    }

    component PopMenu: Menu {
        padding: 6 * s
        background: Rectangle {
            implicitWidth: 220 * s
            radius: 14 * s
            color: col("Card")
            border.width: 1
            border.color: col("Stroke")
        }
    }

    component MenuEntry: MenuItem {
        id: me
        checkable: false
        property bool current: false
        implicitHeight: 36 * s
        implicitWidth: 220 * s
        contentItem: Row {
            spacing: 10 * s
            leftPadding: 4 * s
            Text {
                width: 16 * s
                anchors.verticalCenter: parent.verticalCenter
                text: me.current ? "\u2713" : ""
                color: col("Accent")
                font { family: root.fontFamily; pixelSize: 14 * s; weight: Font.Bold }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: me.text
                color: col("Text")
                font { family: root.fontFamily; pixelSize: 14 * s; weight: Font.Medium }
            }
        }
        background: Rectangle {
            radius: 8 * s
            color: me.highlighted ? col("Hover") : "transparent"
        }
    }
}
