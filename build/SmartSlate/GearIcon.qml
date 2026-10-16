pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: gear

    property color color: "white"
    property color holeColor: "transparent"
    implicitWidth: 32
    implicitHeight: 32

    Repeater {
        model: 8

        delegate: Item {
            required property int index
            anchors.fill: parent
            rotation: index * 45

            Rectangle {
                width: gear.width * 0.24
                height: gear.height * 0.20
                x: (parent.width - width) / 2
                y: 0
                radius: Math.min(width, height) * 0.2
                color: gear.color
            }
        }
    }

    Rectangle {
        width: parent.width * 0.68
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: gear.color

        Rectangle {
            width: parent.width * 0.42
            height: width
            anchors.centerIn: parent
            radius: width / 2
            color: gear.holeColor
        }
    }
}
