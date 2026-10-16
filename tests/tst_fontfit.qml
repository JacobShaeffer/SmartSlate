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

        function waitForNotesFit(field) {
            tryCompare(field, "fitPending", false, 3000)
            tryVerify(function() { return field.fitLow > field.fitHigh }, 2000)
            wait(20)
        }

        function test_shrinkAndRestore_data() {
            return [
                { tag: "production", name: "production", text: "PRODUCTION WITH AN EXTENDED SUBTITLE AND COMPANY NAME" },
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
            tryVerify(function() { return input.font.pixelSize < originalSize }, 5000,
                      "Font did not shrink from " + originalSize + " (actual "
                      + input.font.pixelSize + ", input " + input.width + "x"
                      + input.height + ", fit range " + input.fitLow + "-"
                      + input.fitHigh + ")")
            verify(input.font.pixelSize >= 14)
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
            tryCompare(input.font, "pixelSize", 14)
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

        function test_sceneAndTakeNumericFirst_data() {
            return [
                { tag: "scene", name: "scene" },
                { tag: "take", name: "take" }
            ]
        }

        function test_sceneAndTakeNumericFirst(data) {
            const field = slateField(data.name)
            const input = field.input
            verify(field.forceUppercase)
            verify((input.inputMethodHints & Qt.ImhPreferNumbers) !== 0)
            verify((input.inputMethodHints & Qt.ImhUppercaseOnly) !== 0)
            verify((input.inputMethodHints & Qt.ImhDigitsOnly) === 0)

            focusInput(data.name)
            tryCompare(InputContext.inputEngine, "inputMode",
                       InputEngine.InputMode.Numeric)
            verify(InputContext.inputEngine.inputModes.indexOf(
                       InputEngine.InputMode.Latin) !== -1)

            InputContext.inputEngine.inputMode = InputEngine.InputMode.Latin
            tryCompare(InputContext.inputEngine, "inputMode",
                       InputEngine.InputMode.Latin)
            verify(InputContext.inputEngine.virtualKeyClick(Qt.Key_A, "a",
                                                            Qt.NoModifier))
            tryCompare(input, "text", "A")
        }

        function test_dateMaskAndNumericOnlyInput() {
            const field = slateField("date")
            const input = focusInput("date")

            compare(field.inputMask, "00/00/00")
            verify(input.inputMask.indexOf("00/00/00") === 0)
            compare(input.text, "//")
            compare(input.displayText, "  /  /  ")
            verify((input.inputMethodHints & Qt.ImhDigitsOnly) !== 0)
            tryCompare(InputContext.inputEngine, "inputMode",
                       InputEngine.InputMode.Numeric)

            const digits = "101526"
            for (let i = 0; i < digits.length; ++i) {
                const digit = digits.charAt(i)
                verify(InputContext.inputEngine.virtualKeyClick(
                           Qt.Key_0 + Number(digit), digit, Qt.NoModifier))
            }
            tryCompare(input, "text", "10/15/26")
            compare(input.displayText, "10/15/26")

            verify(InputContext.inputEngine.virtualKeyClick(Qt.Key_A, "A",
                                                            Qt.NoModifier))
            compare(input.text, "10/15/26")
        }

        function test_sceneAndTakeUppercase_data() {
            return test_sceneAndTakeNumericFirst_data()
        }

        function test_sceneAndTakeUppercase(data) {
            const input = slateField(data.name).input
            input.text = "ab-12ß"
            tryCompare(input, "text", "AB-12SS")
            verify(input.text.indexOf("12") !== -1)
            verify(input.text.indexOf("-") !== -1)
        }

        function test_sceneUppercasePasteCursorAndIme() {
            const source = slateField("production").input
            const input = focusInput("scene")

            source.text = "ß"
            source.selectAll()
            source.copy()
            input.text = "ABCD"
            input.select(1, 3)
            input.paste()
            tryCompare(input, "text", "ASSD")
            compare(input.cursorPosition, 3)

            input.clear()
            input.cursorPosition = 0
            InputContext.preeditText = "abß"
            tryCompare(input, "preeditText", "abß")
            compare(input.text, "")
            InputContext.commit()
            tryCompare(input, "text", "ABSS")
            compare(input.cursorPosition, 4)
        }

        function test_otherFieldsKeepTextKeyboardAndCase() {
            const field = slateField("production")
            const input = focusInput("production")
            compare(field.forceUppercase, false)
            verify((input.inputMethodHints & Qt.ImhPreferNumbers) === 0)
            verify((input.inputMethodHints & Qt.ImhDigitsOnly) === 0)
            input.text = "Mixed case"
            compare(input.text, "Mixed case")
        }

        function test_pasteAndSelection() {
            const source = slateField("roll").input
            const input = focusInput("notes")
            const originalSize = input.font.pixelSize
            const pastedText = "A LONG NOTE WITH MORE DETAILS"
            source.text = pastedText
            source.selectAll()
            source.copy()
            input.paste()
            tryCompare(input, "text", pastedText)
            waitForNotesFit(slateField("notes"))
            verify(input.font.pixelSize < originalSize)
            verify(input.font.pixelSize >= 14)
            verify(input.lineCount >= 2)
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
            tryCompare(input.font, "pixelSize", 14)
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

        function test_compactLayoutAndVerticalTitles() {
            const layout = findChild(slateWindow, "mainLayout")
            verify(layout !== null)
            compare(layout.anchors.margins, 0)
            compare(layout.spacing, 4)

            const rows = ["productionRow", "sceneTakeRow", "rollDateRow", "notesRow"]
            for (let i = 0; i < rows.length; ++i)
                compare(findChild(slateWindow, rows[i]).spacing, 4)

            const fields = ["production", "scene", "take", "roll", "date", "notes"]
            for (let i = 0; i < fields.length; ++i) {
                const field = slateField(fields[i])
                const title = findChild(slateWindow, fields[i] + "Title")
                const content = findChild(slateWindow, fields[i] + "Content")
                verify(title !== null, "Missing vertical title for " + fields[i])
                verify(content !== null, "Missing inset content for " + fields[i])
                compare(title.text, field.label.toUpperCase().split("").join("\n"))
                compare(title.width, 28)
                compare(title.minimumPixelSize, 8)
                verify(title.paintedHeight <= title.height + 1,
                       fields[i] + " title is vertically clipped")
                compare(field.minimumValueFontSize, 14)
                compare(content.anchors.margins, 8)
                compare(content.x, 8)
                compare(content.y, 8)
                compare(field.width - content.x - content.width, 8)
                compare(field.height - content.y - content.height, 8)
            }

            const production = slateField("production")
            const settings = findChild(slateWindow, "settingsButton")
            compare(settings.x - production.x - production.width, 4)
            compare(production.x, 0)
            compare(findChild(slateWindow, "productionRow").y, 0)
        }

        function test_notesWrapsBeforeShrinking() {
            const notes = slateField("notes")
            const input = notes.input

            input.text = "SHORT NOTE"
            waitForNotesFit(notes)
            const shortSize = input.font.pixelSize
            verify(shortSize > 14)
            compare(input.lineCount, 1)

            input.text = "M".repeat(40)
            waitForNotesFit(notes)
            const twoLineSize = input.font.pixelSize
            verify(twoLineSize < shortSize)
            verify(input.lineCount >= 2)

            input.text = "M".repeat(70)
            waitForNotesFit(notes)
            const multiLineSize = input.font.pixelSize
            verify(multiLineSize < twoLineSize)
            verify(input.lineCount >= 3)

            input.text = "M".repeat(110)
            waitForNotesFit(notes)
            verify(input.font.pixelSize < multiLineSize)
            verify(input.font.pixelSize >= 14)
            verify(input.lineCount >= 3)
        }

        function test_notesWaitsForTypingToFinish() {
            const notes = slateField("notes")
            const input = notes.input

            input.text = "SHORT"
            waitForNotesFit(notes)
            const startingSize = input.font.pixelSize
            input.text = "M".repeat(110)
            compare(notes.fitPending, true)
            wait(Math.floor(notes.fitDebounceInterval / 2))
            compare(input.font.pixelSize, startingSize)
            waitForNotesFit(notes)
            verify(input.font.pixelSize < startingSize)
        }

        function test_notesMinimumSizeAndInternalScrolling() {
            const notes = slateField("notes")
            const input = notes.input
            const viewport = notes.viewport
            const fieldHeight = notes.height
            const longText = "WORD ".repeat(800)

            input.text = longText
            waitForNotesFit(notes)
            compare(input.font.pixelSize, 14)
            compare(notes.height, fieldHeight)
            verify(input.contentHeight > viewport.height)
            verify(viewport.contentHeight > viewport.height)

            focusInput("notes")
            input.cursorPosition = input.length
            tryVerify(function() { return viewport.contentY > 0 })
            const cursor = input.mapToItem(viewport, 0, input.cursorRectangle.y)
            verify(cursor.y >= -1)
            verify(cursor.y + input.cursorRectangle.height <= viewport.height + 1)
            verifyCursorVisible(input)

            input.cursorPosition = 0
            tryCompare(viewport, "contentY", 0)
            verifyCursorVisible(input)
        }

        function test_notesRefitsAfterRapidChangesAndResize() {
            const notes = slateField("notes")
            const input = notes.input

            input.text = "W".repeat(2000)
            input.text = "DONE"
            waitForNotesFit(notes)
            compare(input.text, "DONE")
            const doneSize = input.font.pixelSize
            verify(doneSize > 14)
            compare(input.lineCount, 1)

            input.text = "M".repeat(70)
            waitForNotesFit(notes)
            const roomySize = input.font.pixelSize
            verify(roomySize < doneSize)
            slateWindow.height = 480
            tryVerify(function() { return input.font.pixelSize < roomySize })
            verify(input.font.pixelSize >= 14)
            slateWindow.height = 800
            tryCompare(input.font, "pixelSize", roomySize)
            compare(input.text, "M".repeat(70))
        }

        function test_notesImeNewlinesAndDone() {
            const notes = slateField("notes")
            const input = focusInput("notes")

            input.text = "A"
            input.cursorPosition = input.length
            waitForNotesFit(notes)
            const singleCharacterSize = input.font.pixelSize
            InputContext.preeditText = "M".repeat(110)
            tryCompare(input, "preeditText", "M".repeat(110))
            tryVerify(function() { return input.font.pixelSize < singleCharacterSize })
            compare(input.text, "A")
            InputContext.commit()
            tryCompare(input, "text", "A" + "M".repeat(110))
            waitForNotesFit(notes)

            input.text = "ONE\nTWO\r\nTHREE\u2028FOUR"
            tryCompare(input, "text", "ONE TWO THREE FOUR")
            const beforeReturn = input.text
            keyClick(Qt.Key_Return)
            tryCompare(input, "activeFocus", false)
            compare(input.text, beforeReturn)
            verify(input.text.indexOf("\n") === -1)
        }

        function test_singleLineNextBehaviorUnchanged() {
            const production = focusInput("production")
            production.text = "PROJECT"
            keyClick(Qt.Key_Return)
            tryCompare(slateField("scene").input, "activeFocus", true)
            compare(production.text, "PROJECT")
        }

        function test_requiredMainControls() {
            const requiredFields = ["production", "scene", "take", "roll", "date", "notes"]
            for (let i = 0; i < requiredFields.length; ++i)
                verify(slateField(requiredFields[i]) !== null)

            verify(findChild(slateWindow, "settingsButton") !== null)
            verify(findChild(slateWindow, "syncToggle") !== null)
            compare(slateWindow.currentScreen, 0)

            const standardRowHeight = slateField("production").height
            verify(Math.abs(slateField("scene").height - standardRowHeight * 2) <= 2,
                   "Scene/Take row is not twice the standard row height")
        }

        function test_screenNavigationAndToggles() {
            const settingsButton = findChild(slateWindow, "settingsButton")
            mouseClick(settingsButton, settingsButton.width / 2, settingsButton.height / 2)
            tryCompare(slateWindow, "currentScreen", 1)

            const brightness = findChild(slateWindow, "brightnessSlider")
            verify(brightness !== null)
            compare(brightness.enabled, false)

            const themeToggle = findChild(slateWindow, "themeToggle")
            compare(slateWindow.darkMode, true)
            mouseClick(themeToggle, themeToggle.width / 2, themeToggle.height / 2)
            tryCompare(slateWindow, "darkMode", false)

            const backButton = findChild(slateWindow, "backButton")
            backButton.click()
            tryCompare(slateWindow, "currentScreen", 0)

            const syncToggle = findChild(slateWindow, "syncToggle")
            compare(syncToggle.checked, false)
            syncToggle.click()
            tryCompare(syncToggle, "checked", true)
        }

        function test_noKeyboardOverlayButtons() {
            focusInput("scene")
            compare(findChild(slateWindow, "keyboardModeButton"), null)
            compare(findChild(slateWindow, "keyboardDismissButton"), null)
        }
    }
}
