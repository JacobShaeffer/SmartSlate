import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

ApplicationWindow {
    id: window

    width: 960
    height: 640
    minimumWidth: 480
    minimumHeight: 480
    visible: true
    title: qsTr("SmartSlate")
    color: "#191919"

    Flickable {
        id: slateViewport
        objectName: "slateViewport"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: inputPanel.top
        clip: true
        contentWidth: width
        contentHeight: slate.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        // Keep the editing line above the keyboard, including at small window sizes.
        function revealInput() {
            const input = window.activeFocusItem as TextField
            if (!input)
                return

            const position = input.mapToItem(slate, 0, input.cursorRectangle.y)
            const top = Math.max(0, position.y - 32)
            const bottom = position.y + input.cursorRectangle.height + 24
            let scrollPosition = contentY

            if (bottom > scrollPosition + height)
                scrollPosition = bottom - height
            if (top < scrollPosition)
                scrollPosition = top

            contentY = Math.max(0, Math.min(contentHeight - height, scrollPosition))
        }

        onHeightChanged: Qt.callLater(revealInput)

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Rectangle {
            id: slate
            objectName: "slate"

            width: slateViewport.width
            height: Math.max(460, slateViewport.height)
            color: "#111111"

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                SlateField {
                    id: productionField
                    objectName: "production"
                    label: qsTr("Production")
                    nextInput: rollField.input
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 176
                    spacing: 4

                    SlateField {
                        id: rollField
                        objectName: "roll"
                        label: qsTr("Roll")
                        centeredValue: true
                        valueFontSize: 76
                        nextInput: sceneField.input
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.horizontalStretchFactor: 1
                        Layout.preferredWidth: 1
                    }

                    SlateField {
                        id: sceneField
                        objectName: "scene"
                        label: qsTr("Scene")
                        centeredValue: true
                        valueFontSize: 112
                        nextInput: takeField.input
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.horizontalStretchFactor: 2
                        Layout.preferredWidth: 2
                    }

                    SlateField {
                        id: takeField
                        objectName: "take"
                        label: qsTr("Take")
                        centeredValue: true
                        valueFontSize: 112
                        nextInput: directorField.input
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        Layout.fillHeight: true
                        Layout.horizontalStretchFactor: 2
                    }
                }

                SlateField {
                    id: directorField
                    objectName: "director"
                    label: qsTr("Director")
                    nextInput: cameraField.input
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                }

                SlateField {
                    id: cameraField
                    objectName: "camera"
                    label: qsTr("Camera")
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                }
            }
        }
    }

    Connections {
        target: window

        function onActiveFocusItemChanged() {
            Qt.callLater(slateViewport.revealInput)
        }
    }

    Connections {
        target: window.activeFocusItem as TextField

        function onCursorRectangleChanged() {
            Qt.callLater(slateViewport.revealInput)
        }
    }

    InputPanel {
        id: inputPanel
        objectName: "virtualKeyboard"

        z: 2
        width: Math.min(window.width, 960)
        x: (window.width - width) / 2
        y: active ? window.height - height : window.height
        visible: active
    }
}
