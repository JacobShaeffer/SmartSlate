import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

Rectangle {
    id: field

    required property string label
    property alias text: editor.text
    property alias input: editor
    property bool centeredValue: false
    property int valueFontSize: 36
    property int minimumValueFontSize: 12
    property Item nextInput: null

    color: editor.activeFocus ? "#eef1f4" : "#faf9f6"
    implicitHeight: 88
    implicitWidth: 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 2

        Label {
            text: field.label.toUpperCase()
            color: "#111111"
            font.pixelSize: 16
            font.weight: Font.Bold
            font.letterSpacing: 2
            Layout.fillWidth: true
        }

        TextField {
            id: editor
            objectName: field.objectName + "Input"

            readonly property int minimumFontSize: Math.max(1, field.minimumValueFontSize)
            readonly property int maximumFontSize: Math.max(minimumFontSize,
                Math.round(Math.min(field.valueFontSize, Math.max(24, height * 0.8))))
            readonly property real availableTextWidth: Math.max(0, width - leftPadding - rightPadding - 2)
            property int fittedFontSize: maximumFontSize

            function fitText() {
                if (displayText.length === 0 || availableTextWidth <= 0) {
                    fittedFontSize = maximumFontSize
                    return
                }

                // Copy the input's font before measuring; trial sizes must not
                // change the input or feed back into the search bounds.
                textMetrics.font = font
                textMetrics.renderType = renderType
                textMetrics.text = displayText

                let lower = minimumFontSize
                let upper = maximumFontSize
                let best = minimumFontSize

                while (lower <= upper) {
                    const candidate = Math.floor((lower + upper) / 2)
                    textMetrics.font.pixelSize = candidate
                    const bounds = textMetrics.boundingRect
                    const measuredWidth = Math.max(textMetrics.advanceWidth, bounds.x + bounds.width)
                        - Math.min(0, bounds.x)

                    if (measuredWidth <= availableTextWidth) {
                        best = candidate
                        lower = candidate + 1
                    } else {
                        upper = candidate - 1
                    }
                }

                fittedFontSize = best
                // Refresh Qt's scroll offset for the resized font and the
                // actual cursor, including a cursor inside IME composition.
                autoScroll = false
                autoScroll = true
            }

            Component.onCompleted: Qt.callLater(fitText)
            onDisplayTextChanged: Qt.callLater(fitText)
            onAvailableTextWidthChanged: Qt.callLater(fitText)
            onMinimumFontSizeChanged: Qt.callLater(fitText)
            onMaximumFontSizeChanged: Qt.callLater(fitText)
            onFontChanged: Qt.callLater(fitText)
            onRenderTypeChanged: Qt.callLater(fitText)

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            padding: 0
            color: "#111111"
            selectionColor: "#111111"
            selectedTextColor: "#faf9f6"
            font.pixelSize: fittedFontSize
            font.weight: field.centeredValue ? Font.DemiBold : Font.Medium
            horizontalAlignment: field.centeredValue ? TextInput.AlignHCenter : TextInput.AlignLeft
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            autoScroll: true
            inputMethodHints: Qt.ImhNoPredictiveText
            background: null
            Accessible.name: field.label
            EnterKeyAction.actionId: field.nextInput ? EnterKeyAction.Next : EnterKeyAction.Done
            EnterKeyAction.enabled: true

            onAccepted: {
                if (field.nextInput) {
                    field.nextInput.forceActiveFocus(Qt.TabFocusReason)
                    InputMethod.show()
                } else {
                    focus = false
                    InputMethod.hide()
                }
            }

            Keys.onEscapePressed: event => {
                focus = false
                InputMethod.hide()
                event.accepted = true
            }
        }
    }

    TextMetrics {
        id: textMetrics
    }

    // The label and empty cell area are touch targets too. Tapping a focused
    // input also reopens the keyboard after its hide key has been used.
    TapHandler {
        onTapped: {
            editor.forceActiveFocus(Qt.MouseFocusReason)
            InputMethod.show()
        }
    }
}
