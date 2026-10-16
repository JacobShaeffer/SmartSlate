pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

Rectangle {
    id: keyboard

    property bool darkMode: true
    property bool numberMode: true
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

    function setNumberMode(enabled) {
        numberMode = enabled
        const requestedMode = enabled ? InputEngine.InputMode.Numeric
                                      : InputEngine.InputMode.Latin
        const engine = InputContext.inputEngine
        if (engine.inputModes.indexOf(requestedMode) !== -1)
            engine.inputMode = requestedMode
    }

    function sendKey(keyText) {
        if (keyText.length === 0)
            return
        InputContext.inputEngine.virtualKeyClick(keyText.charCodeAt(0),
                                                 keyText,
                                                 Qt.NoModifier)
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(function() { keyboard.setNumberMode(true) })
    }

    color: darkMode ? "#111416" : "#deddd8"
    border.width: 1
    border.color: darkMode ? "#343a3f" : "#c9c8c2"

    component KeyboardKey: Button {
        id: keyControl

        required property string keyText

        objectName: "sceneTakeKey" + keyText
        text: keyText
        focusPolicy: Qt.NoFocus
        hoverEnabled: true
        Layout.fillWidth: true
        Layout.fillHeight: true

        contentItem: Label {
            text: keyControl.text
            color: keyboard.darkMode ? "#f5f4ef" : "#161819"
            font.pixelSize: Math.max(18, Math.min(30, keyControl.height * 0.42))
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: keyControl.down
                   ? "#e8b44d"
                   : keyControl.hovered
                     ? (keyboard.darkMode ? "#2c3135" : "#ffffff")
                     : (keyboard.darkMode ? "#24282c" : "#f8f7f2")
            border.width: 1
            border.color: keyControl.down
                          ? "#e8b44d"
                          : (keyboard.darkMode ? "#454c52" : "#b8b7b1")
            radius: 5
        }

        onClicked: keyboard.sendKey(keyText)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Button {
            id: modeSwitch
            objectName: "sceneTakeModeSwitch"

            text: keyboard.numberMode ? qsTr("ABC") : qsTr("123")
            focusPolicy: Qt.NoFocus
            hoverEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(64, keyboard.width * 0.11)
            Accessible.name: keyboard.numberMode
                             ? qsTr("Show letter keyboard")
                             : qsTr("Show number pad")

            contentItem: Label {
                text: modeSwitch.text
                color: "#171819"
                font.pixelSize: 20
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: modeSwitch.down
                       ? (keyboard.darkMode ? "#f2c86e" : "#dca33c")
                       : "#e8b44d"
                border.width: 1
                border.color: keyboard.darkMode ? "#f2c86e" : "#ad7921"
                radius: 5
            }

            onClicked: keyboard.setNumberMode(!keyboard.numberMode)
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: keyboard.numberMode ? numberLayout : letterLayout
        }
    }

    Component {
        id: numberLayout

        GridLayout {
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            uniformCellWidths: true
            uniformCellHeights: true

            Repeater {
                model: keyboard.numberKeys

                delegate: Item {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    KeyboardKey {
                        anchors.fill: parent
                        keyText: parent.modelData
                        visible: keyText.length > 0
                    }
                }
            }
        }
    }

    Component {
        id: letterLayout

        ColumnLayout {
            spacing: 8

            Repeater {
                model: keyboard.letterRows

                delegate: RowLayout {
                    id: letterRow

                    required property var modelData
                    required property int index

                    readonly property real sideInset: index === 0 ? 0
                                                      : index === 1 ? width * 0.05
                                                                    : width * 0.15

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: sideInset
                    Layout.rightMargin: sideInset
                    spacing: 6

                    Repeater {
                        model: letterRow.modelData

                        delegate: KeyboardKey {
                            required property string modelData
                            keyText: modelData
                        }
                    }
                }
            }
        }
    }
}
