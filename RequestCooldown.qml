pragma ComponentBehavior: Bound
import QtQuick
QtObject {
  id: root
  property double until: 0
  property int remainingSeconds: 0
  function block() { until = Date.now() + 60000; refresh() }
  function refresh() { remainingSeconds = Math.max(0, Math.ceil((until - Date.now()) / 1000)) }
  property Timer tick: Timer { interval: 1000; repeat: true; running: root.remainingSeconds > 0; onTriggered: root.refresh() }
}
