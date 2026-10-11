pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "com.gaugedb.search"
  readonly property Panel loadedPanel: panelLoader.item as Panel
  // Host grouped roles are exposed as QtObject; keep their dynamic contract explicit.
  readonly property var barMetrics: Style.bar
  readonly property bool opened: root.loadedPanel ? root.loadedPanel.opened : false
  readonly property bool popoutSwitchClosing: root.loadedPanel ? root.loadedPanel.popoutSwitchClosing : false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { if (root.loadedPanel) root.loadedPanel.open() }
  function close() { if (root.loadedPanel) root.loadedPanel.close() }
  function toggle() { if (root.loadedPanel) root.loadedPanel.toggle() }
  function closeForPopoutSwitch() { if (root.loadedPanel) root.loadedPanel.closeForPopoutSwitch() }
  function injectPanel() {
    if (!root.loadedPanel) return
    root.loadedPanel.bar = root.bar
    root.loadedPanel.settings = root.settings
    root.loadedPanel.anchorItem = button
    root.loadedPanel.hostWidget = root
  }
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }
  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      BrandMark {
        width: parent.width
        height: parent.height
        foreground: button.active ? button.activeColor : button.foreground
      }
    }
    active: root.opened
    slotSize: root.barMetrics.statusSlot
    tooltipText: "GaugeDB — games and regional deals"
    onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
  }
}
