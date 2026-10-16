import QtQuick
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

Rectangle {
    id: field

    required property string label
    property alias text: editor.text
    property alias input: editor
    property bool darkMode: true
    property bool centeredValue: false
    property bool forceUppercase: false
    property int inputMethodHints: Qt.ImhNoPredictiveText
    property string inputMask: ""
    property int valueFontSize: 4096
    property int minimumValueFontSize: 14
    property Item nextInput: null
    property bool normalizingText: false
    property int normalizationRevision: 0

    function uppercaseIndex(value, index) {
        const boundedIndex = Math.max(0, Math.min(index, value.length))
        return value.slice(0, boundedIndex).toUpperCase().length
    }

    function normalizeTextCase() {
        if (!forceUppercase || normalizingText)
            return

        const source = editor.text
        const normalized = source.toUpperCase()
        if (normalized === source)
            return

        const oldCursor = editor.cursorPosition
        const oldSelectionStart = editor.selectionStart
        const oldSelectionEnd = editor.selectionEnd
        const cursorWasAtSelectionStart = oldCursor === oldSelectionStart
        const mappedCursor = uppercaseIndex(source, oldCursor)
        const mappedSelectionStart = uppercaseIndex(source, oldSelectionStart)
        const mappedSelectionEnd = uppercaseIndex(source, oldSelectionEnd)

        normalizingText = true
        editor.text = normalized
        if (oldSelectionStart !== oldSelectionEnd) {
            if (cursorWasAtSelectionStart)
                editor.select(mappedSelectionEnd, mappedSelectionStart)
            else
                editor.select(mappedSelectionStart, mappedSelectionEnd)
        } else {
            editor.cursorPosition = Math.min(mappedCursor, normalized.length)
        }
        normalizingText = false
    }

    function scheduleTextNormalization() {
        if (!forceUppercase || normalizingText)
            return

        const revision = ++normalizationRevision
        Qt.callLater(function() {
            if (field && revision === field.normalizationRevision)
                field.normalizeTextCase()
        })
    }

    color: editor.activeFocus
           ? (darkMode ? "#24292d" : "#ffffff")
           : (darkMode ? "#191c1f" : "#f8f7f2")
    border.width: 1
    border.color: editor.activeFocus ? "#e8b44d"
                                      : (darkMode ? "#343a3f" : "#c9c8c2")
    radius: 3
    implicitHeight: 88
    implicitWidth: 0

    Item {
        objectName: field.objectName + "Content"
        anchors.fill: parent
        anchors.margins: 8

        VerticalFieldLabel {
            id: titleRail
            objectName: field.objectName + "Title"
            label: field.label
            darkMode: field.darkMode
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        TextField {
            id: editor
            objectName: field.objectName + "Input"

            anchors.left: titleRail.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            implicitWidth: 0
            implicitHeight: 0

            readonly property int minimumFontSize: Math.max(1, field.minimumValueFontSize)
            readonly property int maximumFontSize: Math.max(minimumFontSize,
                Math.floor(Math.min(field.valueFontSize,
                                    Math.max(minimumFontSize, height * 2))))
            readonly property real availableTextWidth: Math.max(0, width - leftPadding - rightPadding - 2)
            readonly property real availableTextHeight: Math.max(0, height - topPadding - bottomPadding)
            property int fittedFontSize: minimumFontSize
            property int fitRevision: 0
            property int fitLow: minimumFontSize
            property int fitHigh: maximumFontSize
            property int fitBest: minimumFontSize
            property int fitCandidate: maximumFontSize
            property bool applyingFitResult: false

            function fitText() {
                const revision = ++fitRevision
                if (availableTextWidth <= 0 || availableTextHeight <= 0) {
                    fittedFontSize = minimumFontSize
                    return
                }

                fitLow = minimumFontSize
                fitHigh = maximumFontSize
                fitBest = minimumFontSize
                fitNextCandidate(revision)
            }

            function fitNextCandidate(revision) {
                if (revision !== fitRevision)
                    return

                if (fitLow > fitHigh) {
                    applyingFitResult = true
                    fittedFontSize = fitBest
                    applyingFitResult = false
                    autoScroll = false
                    autoScroll = true
                    return
                }

                fitCandidate = Math.floor((fitLow + fitHigh) / 2)
                Qt.callLater(function() {
                    if (editor)
                        editor.evaluateCandidate(revision)
                })
            }

            function evaluateCandidate(revision) {
                if (revision !== fitRevision)
                    return

                const measuredWidth = fitProbe.contentWidth
                const measuredHeight = fitProbe.contentHeight
                if (measuredWidth <= availableTextWidth
                        && measuredHeight <= availableTextHeight) {
                    fitBest = fitCandidate
                    fitLow = fitCandidate + 1
                } else {
                    fitHigh = fitCandidate - 1
                }
                fitNextCandidate(revision)
            }

            Component.onCompleted: Qt.callLater(fitText)
            onDisplayTextChanged: Qt.callLater(fitText)
            onTextChanged: field.scheduleTextNormalization()
            onAvailableTextWidthChanged: Qt.callLater(fitText)
            onAvailableTextHeightChanged: Qt.callLater(fitText)
            onMinimumFontSizeChanged: Qt.callLater(fitText)
            onMaximumFontSizeChanged: Qt.callLater(fitText)
            onFontChanged: {
                if (!applyingFitResult)
                    Qt.callLater(fitText)
            }
            onRenderTypeChanged: Qt.callLater(fitText)

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
            inputMethodHints: field.inputMethodHints
            inputMask: field.inputMask
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

    Text {
        id: fitProbe
        text: editor.displayText.length > 0 ? editor.displayText : "Mg"
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        font.family: editor.font.family
        font.pixelSize: editor.fitCandidate
        font.weight: editor.font.weight
        font.italic: editor.font.italic
        font.letterSpacing: editor.font.letterSpacing
        font.wordSpacing: editor.font.wordSpacing
        font.capitalization: editor.font.capitalization
        font.kerning: editor.font.kerning
        font.hintingPreference: editor.font.hintingPreference
        renderType: editor.renderType
        visible: false
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
