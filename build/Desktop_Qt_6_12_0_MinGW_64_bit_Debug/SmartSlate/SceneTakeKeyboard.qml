pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

Rectangle {
    id: keyboard

    property bool darkMode: true
    property bool numberMode: true
    property bool uppercase: true
    property Item inputTarget: null
    property bool preferNumberMode: false

    readonly property real outerMargin: 8
    readonly property real keySpacing: 8
    readonly property real letterKeyWidth: Math.max(
        1, (width - outerMargin * 2 - keySpacing * 9) / 10)
    readonly property real numericKeyHeight: Math.max(
        1, Math.min((height - outerMargin * 2 - keySpacing * 3) / 4,
                    ((width - outerMargin * 2 - keySpacing * 4) / 5) * 3 / 4))
    readonly property real numericKeyWidth: numericKeyHeight * 4 / 3
    readonly property var numberKeys: [
        "7", "8", "9",
        "4", "5", "6",
        "1", "2", "3",
        "",  "0", ""
    ]
    readonly property var letterRows: [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    readonly property int textAction: 0
    readonly property int modeAction: 1
    readonly property int dismissAction: 2
    readonly property int caseAction: 3
    readonly property int backspaceAction: 4
    readonly property int spaceAction: 5
    readonly property int enterAction: 6

    signal dismissRequested()

    function setNumberMode(enabled) {
        numberMode = enabled
        const requestedMode = enabled ? InputEngine.InputMode.Numeric
                                      : InputEngine.InputMode.Latin
        const engine = InputContext.inputEngine
        if (engine.inputModes.indexOf(requestedMode) !== -1)
            engine.inputMode = requestedMode
    }

    function resetForInput() {
        uppercase = true
        setNumberMode(preferNumberMode)
    }

    function sendTextKey(baseText) {
        if (baseText.length === 0)
            return

        const isLetter = /^[A-Za-z]$/.test(baseText)
        const text = isLetter
                   ? (uppercase ? baseText.toUpperCase() : baseText.toLowerCase())
                   : baseText
        const keyCode = isLetter ? baseText.toUpperCase().charCodeAt(0)
                                 : baseText.charCodeAt(0)
        const modifiers = isLetter && uppercase ? Qt.ShiftModifier : Qt.NoModifier
        InputContext.inputEngine.virtualKeyClick(keyCode, text, modifiers)
    }

    function handleAction(action, keyText) {
        switch (action) {
        case textAction:
            sendTextKey(keyText)
            break
        case modeAction:
            setNumberMode(!numberMode)
            break
        case dismissAction:
            dismissRequested()
            break
        case caseAction:
            uppercase = !uppercase
            break
        case backspaceAction:
            InputContext.inputEngine.virtualKeyClick(Qt.Key_Backspace, "",
                                                     Qt.NoModifier)
            break
        case spaceAction:
            InputContext.inputEngine.virtualKeyClick(Qt.Key_Space, " ",
                                                     Qt.NoModifier)
            break
        case enterAction:
            InputContext.inputEngine.virtualKeyClick(Qt.Key_Return, "\n",
                                                     Qt.NoModifier)
            break
        }
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(resetForInput)
    }
    onInputTargetChanged: {
        if (visible)
            Qt.callLater(resetForInput)
    }

    color: darkMode ? "#111416" : "#deddd8"
    border.width: 1
    border.color: darkMode ? "#343a3f" : "#c9c8c2"

    component KeyboardKey: Button {
        id: keyControl

        required property string keyName
        required property string keyText
        property int keyAction: keyboard.textAction
        property bool emphasized: false
        property bool selected: false
        property string accessibleText: keyText
        property int labelPixelSize: Math.max(
            18, Math.min(30, keyControl.height * 0.42))
        property int labelWeight: Font.DemiBold

        objectName: "sceneTakeKey" + keyName
        text: keyText
        focusPolicy: Qt.NoFocus
        hoverEnabled: true
        Accessible.name: accessibleText

        contentItem: Label {
            text: keyControl.text
            color: keyControl.emphasized
                   ? "#171819"
                   : (keyboard.darkMode ? "#f5f4ef" : "#161819")
            font.pixelSize: keyControl.labelPixelSize
            font.weight: keyControl.labelWeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: keyControl.emphasized
                   ? (keyControl.down
                      ? (keyboard.darkMode ? "#f2c86e" : "#dca33c")
                      : "#e8b44d")
                   : keyControl.down
                     ? "#e8b44d"
                     : keyControl.selected
                       ? (keyboard.darkMode ? "#4b5053" : "#d2d1cb")
                       : keyControl.hovered
                         ? (keyboard.darkMode ? "#2c3135" : "#ffffff")
                         : (keyboard.darkMode ? "#24282c" : "#f8f7f2")
            border.width: 1
            border.color: keyControl.down || keyControl.emphasized
                          ? (keyboard.darkMode ? "#f2c86e" : "#ad7921")
                          : (keyboard.darkMode ? "#454c52" : "#b8b7b1")
            radius: 5
        }

        onClicked: keyboard.handleAction(keyAction, keyText)
    }

    component BottomRow: Row {
        spacing: keyboard.keySpacing
        width: keyboard.letterKeyWidth * 7.5 + spacing * 3
        // The controls are intentionally not centered as a group: offset the
        // group so the three-unit space bar itself is centered in the deck.
        x: parent ? parent.width / 2
                    - keyboard.letterKeyWidth * 4.5 - spacing * 2 : 0

        KeyboardKey {
            id: modeSwitch
            objectName: "sceneTakeModeSwitch"
            width: keyboard.letterKeyWidth * 1.5
            height: parent.height
            keyName: "ModeSwitch"
            keyText: keyboard.numberMode ? qsTr("ABC") : qsTr("123")
            keyAction: keyboard.modeAction
            emphasized: true
            accessibleText: keyboard.numberMode
                            ? qsTr("Show letter keyboard")
                            : qsTr("Show number pad")
        }

        KeyboardKey {
            width: keyboard.letterKeyWidth * 1.5
            height: parent.height
            keyName: "Dismiss"
            keyText: qsTr("\u2328  \u2193")
            keyAction: keyboard.dismissAction
            accessibleText: qsTr("Dismiss keyboard")
        }

        KeyboardKey {
            width: keyboard.letterKeyWidth * 3
            height: parent.height
            keyName: "Space"
            keyText: qsTr("space")
            keyAction: keyboard.spaceAction
            accessibleText: qsTr("Space")
        }

        KeyboardKey {
            width: keyboard.letterKeyWidth * 1.5
            height: parent.height
            keyName: "Enter"
            keyText: qsTr("\u21b5  enter")
            keyAction: keyboard.enterAction
            emphasized: true
            accessibleText: qsTr("Enter")
        }
    }

    Loader {
        anchors.fill: parent
        anchors.margins: keyboard.outerMargin
        sourceComponent: keyboard.numberMode ? numberLayout : letterLayout
    }

    Component {
        id: letterLayout

        Column {
            spacing: keyboard.keySpacing
            readonly property real rowHeight: (height - spacing * 3) / 4

            Item {
                width: parent.width
                height: parent.rowHeight

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    spacing: keyboard.keySpacing

                    Repeater {
                        model: keyboard.letterRows[0]

                        delegate: KeyboardKey {
                            required property string modelData
                            width: keyboard.letterKeyWidth
                            height: parent.height
                            keyName: modelData
                            keyText: keyboard.uppercase ? modelData
                                                        : modelData.toLowerCase()
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.rowHeight

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    spacing: keyboard.keySpacing

                    Repeater {
                        model: keyboard.letterRows[1]

                        delegate: KeyboardKey {
                            required property string modelData
                            width: keyboard.letterKeyWidth
                            height: parent.height
                            keyName: modelData
                            keyText: keyboard.uppercase ? modelData
                                                        : modelData.toLowerCase()
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.rowHeight

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    spacing: keyboard.keySpacing

                    KeyboardKey {
                        width: keyboard.letterKeyWidth * 1.5
                        height: parent.height
                        keyName: "Case"
                        keyText: keyboard.uppercase ? qsTr("\u21e7  Aa")
                                                    : qsTr("\u21e9  aa")
                        keyAction: keyboard.caseAction
                        selected: keyboard.uppercase
                        accessibleText: keyboard.uppercase
                                        ? qsTr("Use lowercase letters")
                                        : qsTr("Use uppercase letters")
                    }

                    Repeater {
                        model: keyboard.letterRows[2]

                        delegate: KeyboardKey {
                            required property string modelData
                            width: keyboard.letterKeyWidth
                            height: parent.height
                            keyName: modelData
                            keyText: keyboard.uppercase ? modelData
                                                        : modelData.toLowerCase()
                        }
                    }

                    KeyboardKey {
                        width: keyboard.letterKeyWidth * 1.5
                        height: parent.height
                        keyName: "Backspace"
                        keyText: qsTr("\u232b")
                        keyAction: keyboard.backspaceAction
                        accessibleText: qsTr("Backspace")
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.rowHeight

                BottomRow {
                    height: parent.height
                }
            }
        }
    }

    Component {
        id: numberLayout

        Item {
            readonly property real keyHeight: Math.max(
                1, Math.min((height - keyboard.keySpacing * 3) / 4,
                            ((width - keyboard.keySpacing * 4) / 5) * 3 / 4))
            readonly property real keyWidth: keyHeight * 4 / 3

            Column {
                anchors.centerIn: parent
                spacing: keyboard.keySpacing
                width: keyboard.numericKeyWidth * 5 + spacing * 4
                height: keyboard.numericKeyHeight * 4 + spacing * 3

                Row {
                    spacing: keyboard.keySpacing
                    height: keyboard.numericKeyHeight

                    KeyboardKey {
                        objectName: "sceneTakeModeSwitch"
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "ModeSwitch"
                        keyText: qsTr("ABC")
                        keyAction: keyboard.modeAction
                        emphasized: true
                        accessibleText: qsTr("Show letter keyboard")
                        labelPixelSize: Math.max(15, Math.min(20, height * 0.36))
                        labelWeight: Font.Bold
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "7"
                        keyText: "7"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "8"
                        keyText: "8"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "9"
                        keyText: "9"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "Backspace"
                        keyText: qsTr("\u232b")
                        keyAction: keyboard.backspaceAction
                        accessibleText: qsTr("Backspace")
                    }
                }

                Row {
                    spacing: keyboard.keySpacing
                    height: keyboard.numericKeyHeight

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "Dismiss"
                        keyText: qsTr("\u2328\n\u2193")
                        keyAction: keyboard.dismissAction
                        accessibleText: qsTr("Dismiss keyboard")
                        labelPixelSize: Math.max(14, Math.min(19, height * 0.32))
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "4"
                        keyText: "4"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "5"
                        keyText: "5"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "6"
                        keyText: "6"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "Enter"
                        keyText: qsTr("\u21b5 enter")
                        keyAction: keyboard.enterAction
                        emphasized: true
                        accessibleText: qsTr("Enter")
                        labelPixelSize: Math.max(12, Math.min(18, height * 0.3))
                    }
                }

                Row {
                    spacing: keyboard.keySpacing
                    height: keyboard.numericKeyHeight

                    Item {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "1"
                        keyText: "1"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "2"
                        keyText: "2"
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "3"
                        keyText: "3"
                    }

                    Item {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                    }
                }

                Row {
                    spacing: keyboard.keySpacing
                    height: keyboard.numericKeyHeight

                    Item {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                    }

                    Item {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                    }

                    KeyboardKey {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                        keyName: "0"
                        keyText: "0"
                    }

                    Item {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                    }

                    Item {
                        width: keyboard.numericKeyWidth
                        height: parent.height
                    }
                }
            }
        }
    }
}
