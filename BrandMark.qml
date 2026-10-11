pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

// Same six-square geometry as GaugeDB's approved shared logo, recolored by the shell.
Item {
  id: root
  property color foreground: Color.foreground
  implicitWidth: 29
  implicitHeight: 29
  Repeater {
    model: [{x: 0, y: 20, secondary: true}, {x: 10, y: 10, secondary: true}, {x: 10, y: 20, secondary: true}, {x: 20, y: 0}, {x: 20, y: 10}, {x: 20, y: 20}]
    delegate: Rectangle {
      required property var modelData
      x: modelData.x / 29 * root.width
      y: modelData.y / 29 * root.height
      width: 9 / 29 * root.width
      height: 9 / 29 * root.height
      color: root.foreground
      opacity: modelData.secondary ? 0.55 : 1
    }
  }
}
