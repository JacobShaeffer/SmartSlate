import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

ApplicationWindow {
    id: window

    // main.cpp supplies the native DDC/CI helper. It remains null in QML-only
    // tests and previews, where brightness control is deliberately disabled.
    property var brightnessController: null
    property bool darkMode: true
    property int currentScreen: 0

    readonly property color pageColor: darkMode ? "#0d0f10" : "#e8e7e2"
    readonly property color surfaceColor: darkMode ? "#191c1f" : "#f8f7f2"
    readonly property color raisedSurfaceColor: darkMode ? "#24282c" : "#ffffff"
    readonly property color primaryTextColor: darkMode ? "#f5f4ef" : "#161819"
    readonly property color secondaryTextColor: darkMode ? "#a9b0b5" : "#60676c"
    readonly property color outlineColor: darkMode ? "#343a3f" : "#c9c8c2"
    readonly property color accentColor: "#e8b44d"

    width: 1280
    height: 800
    minimumWidth: 480
    minimumHeight: 480
    visible: true
    title: qsTr("SmartSlate")
    color: pageColor

    function dismissKeyboard() {
        const focusedItem = activeFocusItem
        if (focusedItem)
            focusedItem.focus = false
        InputMethod.hide()
    }

    function openSettings() {
        dismissKeyboard()
        if (brightnessController)
            brightnessController.refresh()
        currentScreen = 1
    }

    function closeSettings() {
        currentScreen = 0
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: window.currentScreen

        Item {
            id: mainScreen
            objectName: "mainScreen"

            Flickable {
                id: slateViewport
                objectName: "slateViewport"

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: inputPanel.active ? inputPanel.height : 0
                clip: true
                contentWidth: width
                contentHeight: slate.height
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                // Keep the editing line above the keyboard, including at small
                // window sizes and while an IME composition is in progress.
                function revealInput(input) {
                    const cursorRectangle = input ? input.cursorRectangle : undefined
                    if (!cursorRectangle)
                        return

                    const position = input.mapToItem(slate, 0, cursorRectangle.y)
                    const top = Math.max(0, position.y - 32)
                    const bottom = position.y + cursorRectangle.height + 24
                    let scrollPosition = contentY

                    if (bottom > scrollPosition + height)
                        scrollPosition = bottom - height
                    if (top < scrollPosition)
                        scrollPosition = top

                    contentY = Math.max(0, Math.min(contentHeight - height, scrollPosition))
                }

                onHeightChanged: Qt.callLater(function() {
                    slateViewport.revealInput(window.activeFocusItem)
                })

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Rectangle {
                    id: slate
                    objectName: "slate"

                    width: slateViewport.width
                    height: Math.max(560, slateViewport.height)
                    color: window.pageColor

                    ColumnLayout {
                        id: mainLayout
                        objectName: "mainLayout"
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 4

                        RowLayout {
                            objectName: "productionRow"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 1
                            Layout.verticalStretchFactor: 1
                            spacing: 4

                            SlateField {
                                id: productionField
                                objectName: "production"
                                label: qsTr("Production")
                                darkMode: window.darkMode
                                nextInput: sceneField.input
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 3
                                Layout.horizontalStretchFactor: 3
                            }

                            Button {
                                id: settingsButton
                                objectName: "settingsButton"

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.horizontalStretchFactor: 1
                                hoverEnabled: true
                                Accessible.name: qsTr("Settings")

                                contentItem: ColumnLayout {
                                    spacing: 9

                                    Item { Layout.fillHeight: true }

                                    GearIcon {
                                        color: window.primaryTextColor
                                        holeColor: settingsButton.down ? window.accentColor
                                                                       : settingsButton.hovered
                                                                         ? window.raisedSurfaceColor
                                                                         : window.surfaceColor
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                    }

                                    Label {
                                        text: qsTr("SETTINGS")
                                        color: window.primaryTextColor
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1.8
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                background: Rectangle {
                                    color: settingsButton.down ? window.accentColor
                                                                  : settingsButton.hovered
                                                                    ? window.raisedSurfaceColor
                                                                    : window.surfaceColor
                                    border.width: 1
                                    border.color: settingsButton.activeFocus ? window.accentColor
                                                                              : window.outlineColor
                                    radius: 3
                                }

                                onClicked: window.openSettings()
                            }
                        }

                        RowLayout {
                            objectName: "sceneTakeRow"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 2
                            Layout.verticalStretchFactor: 2
                            spacing: 4

                            SlateField {
                                id: sceneField
                                objectName: "scene"
                                label: qsTr("Scene")
                                darkMode: window.darkMode
                                centeredValue: true
                                valueFontSize: 108
                                nextInput: takeField.input
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 2
                                Layout.horizontalStretchFactor: 2
                            }

                            SlateField {
                                id: takeField
                                objectName: "take"
                                label: qsTr("Take")
                                darkMode: window.darkMode
                                centeredValue: true
                                valueFontSize: 108
                                nextInput: rollField.input
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.horizontalStretchFactor: 1
                            }
                        }

                        RowLayout {
                            objectName: "rollDateRow"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 1
                            Layout.verticalStretchFactor: 1
                            spacing: 4

                            SlateField {
                                id: rollField
                                objectName: "roll"
                                label: qsTr("Roll")
                                darkMode: window.darkMode
                                centeredValue: true
                                valueFontSize: 80
                                nextInput: dateField.input
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.horizontalStretchFactor: 1
                            }

                            SlateField {
                                id: dateField
                                objectName: "date"
                                label: qsTr("Date")
                                darkMode: window.darkMode
                                centeredValue: true
                                valueFontSize: 64
                                nextInput: notesField.input
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 2
                                Layout.horizontalStretchFactor: 2
                            }
                        }

                        RowLayout {
                            objectName: "notesRow"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 1
                            Layout.verticalStretchFactor: 1
                            spacing: 4

                            SlateNotesField {
                                id: notesField
                                objectName: "notes"
                                label: qsTr("Notes")
                                darkMode: window.darkMode
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 3
                                Layout.horizontalStretchFactor: 3
                            }

                            Button {
                                id: syncToggle
                                objectName: "syncToggle"

                                checkable: true
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.horizontalStretchFactor: 1
                                hoverEnabled: true
                                Accessible.name: qsTr("Toggle MOS or sync")

                                contentItem: Label {
                                    text: syncToggle.checked ? qsTr("SYNC") : qsTr("MOS")
                                    color: syncToggle.checked || syncToggle.down
                                           ? "#171819" : window.primaryTextColor
                                    font.pixelSize: 42
                                    font.weight: Font.Black
                                    font.letterSpacing: 2
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    color: syncToggle.checked || syncToggle.down
                                           ? window.accentColor : window.surfaceColor
                                    border.width: 1
                                    border.color: syncToggle.checked || syncToggle.activeFocus
                                                  ? window.accentColor : window.outlineColor
                                    radius: 3
                                }

                                onClicked: window.dismissKeyboard()
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: settingsScreen
            objectName: "settingsScreen"
            color: window.pageColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Math.max(20, Math.min(52, width * 0.04))
                spacing: 28

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Button {
                        id: backButton
                        objectName: "backButton"
                        text: qsTr("‹  BACK")
                        hoverEnabled: true
                        Accessible.name: qsTr("Back to slate")

                        contentItem: Label {
                            text: backButton.text
                            color: window.primaryTextColor
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            implicitWidth: 148
                            implicitHeight: 58
                            color: backButton.down ? window.accentColor : window.surfaceColor
                            border.width: 1
                            border.color: backButton.activeFocus ? window.accentColor
                                                                  : window.outlineColor
                            radius: 3
                        }

                        onClicked: window.closeSettings()
                    }

                    Label {
                        text: qsTr("SETTINGS")
                        color: window.primaryTextColor
                        font.pixelSize: 30
                        font.weight: Font.Black
                        font.letterSpacing: 3
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    color: window.surfaceColor
                    border.width: 1
                    border.color: window.outlineColor
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("BRIGHTNESS")
                                color: window.primaryTextColor
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                font.letterSpacing: 2
                                Layout.fillWidth: true
                            }

                            Label {
                                text: brightnessSlider.enabled
                                      ? Math.round(brightnessSlider.value) + "%" : "--"
                                color: brightnessSlider.enabled ? window.accentColor
                                                                : window.secondaryTextColor
                                font.pixelSize: 24
                                font.weight: Font.Bold
                            }
                        }

                        Slider {
                            id: brightnessSlider
                            objectName: "brightnessSlider"
                            from: 0
                            to: 100
                            stepSize: 1
                            value: window.brightnessController
                                   ? window.brightnessController.brightness : 100
                            enabled: Boolean(window.brightnessController
                                             && window.brightnessController.available)
                            opacity: enabled ? 1 : 0.45
                            Layout.fillWidth: true
                            Accessible.name: qsTr("Display brightness")

                            background: Rectangle {
                                x: brightnessSlider.leftPadding
                                y: brightnessSlider.topPadding
                                   + brightnessSlider.availableHeight / 2 - height / 2
                                width: brightnessSlider.availableWidth
                                height: 10
                                radius: 5
                                color: window.outlineColor

                                Rectangle {
                                    width: brightnessSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: window.accentColor
                                }
                            }

                            handle: Rectangle {
                                x: brightnessSlider.leftPadding
                                   + brightnessSlider.visualPosition
                                     * (brightnessSlider.availableWidth - width)
                                y: brightnessSlider.topPadding
                                   + brightnessSlider.availableHeight / 2 - height / 2
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: 17
                                color: brightnessSlider.pressed ? window.accentColor
                                                                 : window.raisedSurfaceColor
                                border.width: 4
                                border.color: window.accentColor
                            }

                            onMoved: brightnessDebounce.restart()
                        }

                        Label {
                            text: window.brightnessController
                                  ? window.brightnessController.status
                                  : qsTr("Brightness control unavailable: native DDC/CI backend not loaded.")
                            color: window.secondaryTextColor
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 128
                    color: window.surfaceColor
                    border.width: 1
                    border.color: window.outlineColor
                    radius: 5

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 24

                        ColumnLayout {
                            spacing: 5
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("APPEARANCE")
                                color: window.primaryTextColor
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                font.letterSpacing: 2
                            }

                            Label {
                                text: window.darkMode ? qsTr("Dark mode") : qsTr("Light mode")
                                color: window.secondaryTextColor
                                font.pixelSize: 16
                            }
                        }

                        Switch {
                            id: themeToggle
                            objectName: "themeToggle"
                            checked: window.darkMode
                            text: checked ? qsTr("DARK") : qsTr("LIGHT")
                            Accessible.name: qsTr("Dark or light mode")

                            indicator: Rectangle {
                                implicitWidth: 78
                                implicitHeight: 42
                                x: themeToggle.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 21
                                color: themeToggle.checked ? window.accentColor
                                                           : window.outlineColor

                                Rectangle {
                                    x: themeToggle.checked ? parent.width - width - 5 : 5
                                    y: 5
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: themeToggle.checked ? "#171819" : "#ffffff"

                                    Behavior on x {
                                        NumberAnimation { duration: 120 }
                                    }
                                }
                            }

                            contentItem: Label {
                                leftPadding: themeToggle.indicator.width + themeToggle.spacing
                                text: themeToggle.text
                                color: window.primaryTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                                verticalAlignment: Text.AlignVCenter
                            }

                            onToggled: window.darkMode = checked
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Timer {
        id: brightnessDebounce
        interval: 160
        repeat: false
        onTriggered: {
            if (window.brightnessController && window.brightnessController.available)
                window.brightnessController.setBrightness(Math.round(brightnessSlider.value))
        }
    }

    Connections {
        target: window

        function onActiveFocusItemChanged() {
            Qt.callLater(function() {
                slateViewport.revealInput(window.activeFocusItem)
            })
        }
    }

    Connections {
        target: window.activeFocusItem
        ignoreUnknownSignals: true

        function onCursorRectangleChanged() {
            Qt.callLater(function() {
                slateViewport.revealInput(window.activeFocusItem)
            })
        }
    }

    InputPanel {
        id: inputPanel
        objectName: "virtualKeyboard"

        z: 10
        width: Math.min(window.width, 960)
        x: (window.width - width) / 2
        y: active ? window.height - height : window.height
        visible: active
    }

    Button {
        id: keyboardDismissButton
        objectName: "keyboardDismissButton"

        z: 11
        visible: inputPanel.active
        width: 68
        height: 50
        anchors.right: inputPanel.right
        anchors.rightMargin: 12
        anchors.bottom: inputPanel.top
        anchors.bottomMargin: 10
        hoverEnabled: true
        Accessible.name: qsTr("Dismiss keyboard")

        contentItem: Label {
            text: "⌨  ↓"
            color: window.primaryTextColor
            font.pixelSize: 19
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: keyboardDismissButton.down ? window.accentColor
                                               : window.raisedSurfaceColor
            border.width: 1
            border.color: window.accentColor
            radius: 5
        }

        onClicked: window.dismissKeyboard()
    }
}
