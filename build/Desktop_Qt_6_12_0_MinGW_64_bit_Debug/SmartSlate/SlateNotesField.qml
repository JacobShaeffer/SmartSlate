import QtQuick
import QtQuick.Controls.Basic
import QtQuick.VirtualKeyboard

Rectangle {
    id: field

    required property string label
    property alias text: editor.text
    property alias input: editor
    property alias viewport: editorViewport
    property bool darkMode: true
    property int valueFontSize: 4096
    property int minimumValueFontSize: 14
    property Item nextInput: null
    property int fitDebounceInterval: 220
    readonly property bool fitPending: fitDebounce.running

    property int fittedFontSize: Math.max(1, minimumValueFontSize)
    property int fitRevision: 0
    property int fitLow: minimumValueFontSize
    property int fitHigh: valueFontSize
    property int fitBest: minimumValueFontSize
    property int fitCandidate: valueFontSize
    property bool normalizingText: false

    function normalizedText(value) {
        return value.replace(/\r\n|\r|\n|\u2028|\u2029/g, " ")
    }

    function completeText() {
        if (editor.preeditText.length === 0)
            return editor.text

        const insertion = Math.max(0, Math.min(editor.cursorPosition,
                                                editor.text.length))
        return editor.text.slice(0, insertion) + editor.preeditText
                + editor.text.slice(insertion)
    }

    function requestFit() {
        const revision = ++fitRevision
        const minimumSize = Math.max(1, minimumValueFontSize)
        const maximumSize = Math.max(minimumSize,
                                     Math.floor(Math.min(valueFontSize,
                                                        editorViewport.height * 2)))
        fitLow = minimumSize
        fitHigh = maximumSize
        fitBest = minimumSize

        if (editorViewport.width <= 0 || editorViewport.height <= 0) {
            fittedFontSize = minimumSize
            Qt.callLater(editorViewport.revealCursor)
            return
        }

        fitNextCandidate(revision)
    }

    function queueFitAfterTyping() {
        // Invalidate any in-flight binary search immediately, but defer the
        // replacement search until input has been quiet for a moment.
        ++fitRevision
        fitDebounce.restart()
    }

    function fitNextCandidate(revision) {
        if (revision !== fitRevision)
            return

        if (fitLow > fitHigh) {
            fittedFontSize = fitBest
            Qt.callLater(editorViewport.revealCursor)
            return
        }

        fitCandidate = Math.floor((fitLow + fitHigh) / 2)
        Qt.callLater(function() {
            if (field)
                field.evaluateCandidate(revision)
        })
    }

    function evaluateCandidate(revision) {
        if (revision !== fitRevision)
            return

        const fits = fitProbe.contentHeight <= editorViewport.height + 0.5
        if (fits) {
            fitBest = fitCandidate
            fitLow = fitCandidate + 1
        } else {
            fitHigh = fitCandidate - 1
        }
        fitNextCandidate(revision)
    }

    function finishEditing() {
        fitDebounce.stop()
        requestFit()
        if (nextInput) {
            nextInput.forceActiveFocus(Qt.TabFocusReason)
            InputMethod.show()
        } else {
            editor.focus = false
            InputMethod.hide()
        }
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

    onValueFontSizeChanged: Qt.callLater(requestFit)
    onMinimumValueFontSizeChanged: Qt.callLater(requestFit)
    Component.onCompleted: Qt.callLater(requestFit)

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

        Flickable {
            id: editorViewport
            objectName: field.objectName + "Viewport"

            anchors.left: titleRail.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            function revealCursor() {
                if (!editor.activeFocus || height <= 0)
                    return

                const cursorTop = editor.cursorRectangle.y
                const cursorBottom = cursorTop + editor.cursorRectangle.height
                let destination = contentY
                if (cursorTop < contentY)
                    destination = cursorTop
                else if (cursorBottom > contentY + height)
                    destination = cursorBottom - height

                const maximumY = Math.max(0, contentHeight - height)
                contentY = Math.max(0, Math.min(maximumY, destination))
            }

            clip: true
            contentWidth: width
            contentHeight: Math.max(height, editor.height)
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            onWidthChanged: Qt.callLater(field.requestFit)
            onHeightChanged: Qt.callLater(field.requestFit)
            onContentHeightChanged: Qt.callLater(revealCursor)

            TextArea {
                id: editor
                objectName: field.objectName + "Input"

                width: editorViewport.width
                height: Math.max(editorViewport.height,
                                 contentHeight + topPadding + bottomPadding)
                padding: 0
                color: field.darkMode ? "#f5f4ef" : "#161819"
                selectionColor: "#e8b44d"
                selectedTextColor: "#171819"
                font.pixelSize: field.fittedFontSize
                font.weight: Font.Medium
                horizontalAlignment: TextEdit.AlignLeft
                verticalAlignment: contentHeight <= editorViewport.height
                                   ? TextEdit.AlignVCenter : TextEdit.AlignTop
                selectByMouse: true
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                inputMethodHints: Qt.ImhNoPredictiveText
                background: null
                Accessible.name: field.label
                EnterKeyAction.actionId: field.nextInput
                                         ? EnterKeyAction.Next
                                         : EnterKeyAction.Done
                EnterKeyAction.enabled: true

                onTextChanged: {
                    if (!field.normalizingText) {
                        const normalized = field.normalizedText(text)
                        if (normalized !== text) {
                            const normalizedCursor = field.normalizedText(
                                                       text.slice(0, cursorPosition)).length
                            field.normalizingText = true
                            text = normalized
                            cursorPosition = Math.min(normalizedCursor, text.length)
                            field.normalizingText = false
                        }
                    }
                    field.queueFitAfterTyping()
                }
                onPreeditTextChanged: field.queueFitAfterTyping()
                onCursorRectangleChanged: Qt.callLater(editorViewport.revealCursor)

                Keys.onReturnPressed: event => {
                    field.finishEditing()
                    event.accepted = true
                }
                Keys.onEnterPressed: event => {
                    field.finishEditing()
                    event.accepted = true
                }
                Keys.onEscapePressed: event => {
                    focus = false
                    InputMethod.hide()
                    event.accepted = true
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: editorViewport.contentHeight > editorViewport.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }
        }
    }

    Text {
        id: fitProbe
        width: editorViewport.width
        text: field.completeText().length > 0 ? field.completeText() : "Mg"
        textFormat: Text.PlainText
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        font.family: editor.font.family
        font.pixelSize: field.fitCandidate
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

    Timer {
        id: fitDebounce
        interval: field.fitDebounceInterval
        repeat: false
        onTriggered: field.requestFit()
    }

    TapHandler {
        onTapped: {
            editor.forceActiveFocus(Qt.MouseFocusReason)
            InputMethod.show()
        }
    }
}
