import QtQuick
import QtTest
import ".." as Slate

Item {
    width: 960
    height: 640

    Component {
        id: slateComponent
        Slate.Main {}
    }

    Component {
        id: monitorComponent
        QtObject {
            property bool available: true
            property int percentage: 78
            property int remainingMinutes: 200
            property bool charging: false
            property string status: "Based on recent usage."
            property int refreshCount: 0
            function refresh() { ++refreshCount }
        }
    }

    TestCase {
        name: "BatterySettings"
        when: windowShown
        property var slateWindow
        property var monitor

        function init() {
            failOnWarning(/Binding loop|recursive rearrange|TypeError|ReferenceError/)
            monitor = createTemporaryObject(monitorComponent, null)
            slateWindow = createTemporaryObject(slateComponent, null)
            verify(slateWindow !== null)
            slateWindow.batteryMonitor = monitor
            slateWindow.openSettings()
            tryCompare(slateWindow, "currentScreen", 1)
            wait(40)
        }

        function cleanup() {
            slateWindow.close()
        }

        function label(name) {
            const item = findChild(slateWindow, name)
            verify(item !== null)
            return item
        }

        function test_liveReadings() {
            compare(monitor.refreshCount, 1)
            compare(label("batteryPercentage").text, "78%")
            compare(label("batteryRuntime").text, "~3h 20m")
            compare(label("batteryStatus").text, monitor.status)
            monitor.percentage = 42
            monitor.remainingMinutes = 59
            tryCompare(label("batteryPercentage"), "text", "42%")
            tryCompare(label("batteryRuntime"), "text", "~59m")
            monitor.remainingMinutes = 60
            tryCompare(label("batteryRuntime"), "text", "~1h 0m")
            monitor.remainingMinutes = 0
            monitor.percentage = 0
            tryCompare(label("batteryRuntime"), "text", "<1m")
            tryCompare(label("batteryPercentage"), "text", "0%")
        }

        function test_chargingAndEstimating() {
            monitor.remainingMinutes = -1
            tryCompare(label("batteryRuntime"), "text", "Estimating…")
            monitor.charging = true
            tryCompare(label("batteryRuntime"), "text", "Charging")
            monitor.charging = false
            tryCompare(label("batteryRuntime"), "text", "Estimating…")
            monitor.remainingMinutes = 200
            tryCompare(label("batteryRuntime"), "text", "~3h 20m")
        }

        function test_unavailableAndRecovery() {
            monitor.available = false
            tryCompare(label("batteryPercentage"), "text", "--")
            tryCompare(label("batteryRuntime"), "text", "Unavailable")
            monitor.available = true
            tryCompare(label("batteryPercentage"), "text", "78%")
            tryCompare(label("batteryRuntime"), "text", "~3h 20m")
            slateWindow.batteryMonitor = null
            tryCompare(label("batteryPercentage"), "text", "--")
            tryCompare(label("batteryRuntime"), "text", "Unavailable")
            tryCompare(label("batteryStatus"), "text", "Battery monitor unavailable.")
        }

        function test_themesAndSmallWindow_data() {
            return [{tag: "dark", dark: true}, {tag: "light", dark: false}]
        }

        function test_themesAndSmallWindow(data) {
            slateWindow.darkMode = data.dark
            slateWindow.width = 480
            slateWindow.height = 480
            const viewport = label("settingsViewport")
            tryVerify(function() { return viewport.contentHeight > viewport.height })
            compare(label("batteryCard").color, slateWindow.surfaceColor)
            verify(label("batteryPercentage").width >= label("batteryPercentage").contentWidth)
            verify(label("batteryRuntime").width >= label("batteryRuntime").contentWidth)
            const toggle = label("themeToggle")
            viewport.contentY = viewport.contentHeight - viewport.height
            wait(40)
            const position = toggle.mapToItem(viewport, 0, 0)
            verify(position.y >= 0)
            verify(position.y + toggle.height <= viewport.height)
            verify(toggle.width > 0)
        }
    }
}
