import QtQuick

Text {
    id: title

    required property string label
    property bool darkMode: true

    width: 28
    text: label.toUpperCase().split("").join("\n")
    color: darkMode ? "#aeb8c4" : "#536170"
    font.pixelSize: 16
    minimumPixelSize: 8
    font.weight: Font.Bold
    font.letterSpacing: 1
    fontSizeMode: Text.VerticalFit
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    lineHeight: 0.88
    lineHeightMode: Text.ProportionalHeight
    wrapMode: Text.NoWrap
    elide: Text.ElideNone
}
