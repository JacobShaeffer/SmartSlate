// Run with qmltestrunner -input tests -platform offscreen.
import QtQuick
import QtTest
import QtQuick.VirtualKeyboard
import ".." as Slate

Item {
    width: 960
    height: 640

    Component {
        id: slateComponent
        Slate.Main {}
    }

    TestCase {
        name: "SlateFontFit"
        when: windowShown
        property var slateWindow

        function init() {
            failOnWarning(/Binding loop|TypeError|ReferenceError/)
            slateWindow = createTemporaryObject(slateComponent, null)
            verify(slateWindow !== null)
            slateWindow.requestActivate()
            wait(40)
        }

        function cleanup() {
            InputContext.clear()
            InputMethod.hide()
            slateWindow.close()
        }

        function slateField(name) {
            const item = findChild(slateWindow, name)
            verify(item !== null, "Missing field: " + name)
            return item
        }

        function focusInput(name) {
            const input = slateField(name).input
            input.forceActiveFocus(Qt.MouseFocusReason)
            InputMethod.show()
            tryCompare(input, "activeFocus", true)
            tryCompare(findChild(slateWindow, "virtualKeyboard"), "active", true)
            wait(20)
            return input
        }

        function verifyTextFits(input) {
            verify(input.contentWidth <= input.width - input.leftPadding - input.rightPadding,
                   "Text exceeds the input width: " + input.contentWidth + "/" + input.width)
        }

        function verifyCursorVisible(input) {
            const viewport = findChild(slateWindow, "slateViewport")
            const position = input.mapToItem(viewport, input.cursorRectangle.x, input.cursorRectangle.y)
            verify(position.y >= 0, "Cursor is above the slate viewport")
            verify(position.y + input.cursorRectangle.height <= viewport.height,
                   "Cursor is below the slate viewport")
            verify(input.cursorRectangle.x >= 0 && input.cursorRectangle.x <= input.width,
                   "Cursor is outside the input horizontally: " + input.cursorRectangle.x + "/" + input.width
                   + " at " + input.cursorPosition)
        }

        function test_shrinkAndRestore_data() {
            return [
                { tag: "production", name: "production", text: "PRODUCTION WITH AN EXTENDED SUBTITLE ".repeat(3) },
                { tag: "director", name: "director", text: "DIRECTOR WITH A LONG NAME AND ADDITIONAL CREDITS ".repeat(3) },
                { tag: "camera", name: "camera", text: "CAMERA OPERATOR WITH A LONG NAME AND ADDITIONAL CREDITS ".repeat(3) },
                { tag: "roll", name: "roll", text: "W".repeat(10) },
                { tag: "scene", name: "scene", text: "W".repeat(20) },
                { tag: "take", name: "take", text: "W".repeat(20) }
            ]
        }

        function test_shrinkAndRestore(data) {
            const item = slateField(data.name)
            const input = item.input
            const originalSize = input.font.pixelSize
            const originalWidth = item.width
            const originalHeight = item.height
            const otherSize = slateField(data.name === "scene" ? "take" : "scene").input.font.pixelSize
            input.text = data.text
            input.cursorPosition = 3
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verify(input.font.pixelSize >= 12)
            verifyTextFits(input)
            compare(input.text, data.text)
            compare(input.cursorPosition, 3)
            compare(item.width, originalWidth)
            compare(item.height, originalHeight)
            compare(slateField(data.name === "scene" ? "take" : "scene").input.font.pixelSize, otherSize)

            input.text = "A1"
            tryCompare(input.font, "pixelSize", originalSize)
            input.clear()
            tryCompare(input.font, "pixelSize", originalSize)
        }

        function test_minimumAndScrolling_data() {
            return test_shrinkAndRestore_data()
        }

        function test_minimumAndScrolling(data) {
            const input = slateField(data.name).input
            const longText = "W".repeat(500)
            input.text = longText
            tryCompare(input.font, "pixelSize", 12)
            compare(input.text, longText)
            verify(input.contentWidth > input.width)
            verify(input.autoScroll)
            verify(input.cursorRectangle.x >= 0 && input.cursorRectangle.x <= input.width,
                   "Overflow is scrolled outside an unfocused input")
            focusInput(data.name)
            input.cursorPosition = input.length
            wait(20)
            verifyCursorVisible(input)
            input.cursorPosition = 0
            wait(20)
            verifyCursorVisible(input)
        }

        function test_virtualKeyboardTypingAndDeletion() {
            const input = focusInput("roll")
            const originalSize = input.font.pixelSize
            for (let i = 0; i < 10; ++i)
                verify(InputContext.inputEngine.virtualKeyClick(Qt.Key_W, "W", Qt.NoModifier))
            tryCompare(input, "text", "W".repeat(10))
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verifyTextFits(input)
            verifyCursorVisible(input)
            const fittedSize = input.font.pixelSize
            verify(InputContext.inputEngine.virtualKeyClick(Qt.Key_Backspace, "", Qt.NoModifier))
            tryCompare(input, "text", "W".repeat(9))
            tryVerify(function() { return input.font.pixelSize >= fittedSize })
            input.selectAll()
            verify(InputContext.inputEngine.virtualKeyClick(Qt.Key_Backspace, "", Qt.NoModifier))
            tryCompare(input, "text", "")
            tryCompare(input.font, "pixelSize", originalSize)
            verifyCursorVisible(input)
        }

        function test_pasteAndSelection() {
            const source = slateField("camera").input
            const input = focusInput("director")
            const originalSize = input.font.pixelSize
            const pastedText = "A LONG DIRECTOR NAME WITH ADDITIONAL CREDITS ".repeat(3)
            source.text = pastedText
            source.selectAll()
            source.copy()
            input.paste()
            tryCompare(input, "text", pastedText)
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verifyTextFits(input)
            const fittedSize = input.font.pixelSize
            input.select(2, 8)
            wait(20)
            compare(input.selectedText, pastedText.substring(2, 8))
            compare(input.font.pixelSize, fittedSize)
        }

        function test_preeditAndCommit() {
            const input = focusInput("scene")
            input.text = "A"
            wait(20)
            const originalSize = input.font.pixelSize
            const composition = "W".repeat(20)
            InputContext.preeditText = composition
            tryCompare(input, "preeditText", composition)
            compare(input.text, "A")
            compare(input.displayText, "A" + composition)
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verifyTextFits(input)
            verifyCursorVisible(input)
            InputContext.commit()
            tryCompare(input, "text", "A" + composition)
            compare(input.preeditText, "")
            verifyTextFits(input)
            input.clear()
            tryCompare(input.font, "pixelSize", originalSize)
        }

        function test_preeditOverflow() {
            const input = focusInput("scene")
            input.text = "A"
            const composition = "W".repeat(500)
            InputContext.preeditText = composition
            tryCompare(input, "preeditText", composition)
            tryCompare(input.font, "pixelSize", 12)
            wait(20)
            verifyCursorVisible(input)
            compare(input.text, "A")
            InputContext.commit()
            tryCompare(input, "text", "A" + composition)
            wait(20)
            verifyCursorVisible(input)
        }

        function test_resizeWhileEditing() {
            const input = focusInput("scene")
            const text = "W".repeat(10)
            input.text = text
            wait(20)
            const originalSize = input.font.pixelSize
            slateWindow.width = 480
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verifyTextFits(input)
            verifyCursorVisible(input)
            const narrowSize = input.font.pixelSize
            slateWindow.width = 1280
            tryVerify(function() { return input.font.pixelSize > narrowSize })
            verifyTextFits(input)
            verifyCursorVisible(input)
            compare(input.text, text)
        }

        function test_fontAndPaddingChanges() {
            const input = slateField("scene").input
            input.text = "A".repeat(20)
            wait(20)
            const originalSize = input.font.pixelSize
            input.font.letterSpacing = 5
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verifyTextFits(input)
            input.font.letterSpacing = 0
            tryCompare(input.font, "pixelSize", originalSize)
            input.leftPadding = 60
            input.rightPadding = 60
            tryVerify(function() { return input.font.pixelSize < originalSize })
            verifyTextFits(input)
            input.font.family = "Arial"
            input.font.weight = Font.Black
            input.renderType = TextInput.NativeRendering
            wait(20)
            verifyTextFits(input)
        }
    }
}
