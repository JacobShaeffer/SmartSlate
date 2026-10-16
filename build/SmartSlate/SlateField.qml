import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

Rectangle {
    id: field

    required property string label
    property alias text: editor.text
    property alias input: editor
    property bool darkMode: true
    property bool centeredValue: false
    property int valueFontSize: 36
    property int minimumValueFontSize: 14
    property Item nextInput: null

    color: editor.activeFocus
           ? (darkMode ? "#24292d" : "#ffffff")
           : (darkMode ? "#191c1f" : "#f8f7f2")
    border.width: 1
    border.color: editor.activeFocus ? "#e8b44d"
                                      : (darkMode ? "#343a3f" : "#c9c8c2")
    radius: 3
    implicitHeight: 88
    implicitWidth: 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        VerticalFieldLabel {
            objectName: field.objectName + "Title"
            label: field.label
            darkMode: field.darkMode
            Layout.preferredWidth: 28
            Layout.minimumWidth: 28
            Layout.maximumWidth: 28
            Layout.fillHeight: true
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

                // Measure at the size currently on screen, then converge on the
                // size that fills the available width. This remains reliable
                // when fonts, padding, window width, or IME pre-edit text change.
                const measuredWidth = textMetrics.advanceWidth
                const currentSize = Math.max(1, font.pixelSize)
                let targetSize = maximumFontSize
                if (measuredWidth > 0)
                    targetSize = Math.floor(currentSize * availableTextWidth / measuredWidth)
                targetSize = Math.max(minimumFontSize,
                                      Math.min(maximumFontSize, targetSize))
                if (measuredWidth > availableTextWidth && targetSize >= currentSize)
                    targetSize = Math.max(minimumFontSize, currentSize - 1)

                fittedFontSize = targetSize
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
            color: field.darkMode ? "#f5f4ef" : "#161819"
            selectionColor: "#e8b44d"
            selectedTextColor: "#171819"
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
        text: editor.displayText
        font.family: editor.font.family
        font.pixelSize: editor.font.pixelSize
        font.weight: editor.font.weight
        font.italic: editor.font.italic
        font.letterSpacing: editor.font.letterSpacing
        font.wordSpacing: editor.font.wordSpacing
        font.capitalization: editor.font.capitalization
        font.kerning: editor.font.kerning
        font.hintingPreference: editor.font.hintingPreference
        renderType: editor.renderType
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
