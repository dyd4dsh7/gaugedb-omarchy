pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
QtObject {
  id: root
  property bool busy: false
  property bool exitSeen: false
  property var requestArguments: []
  signal finished(string value, bool success)
  property Process process: Process {
    command: ["timeout", "--signal=TERM", "--kill-after=1s", "20s", "python3", decodeURIComponent(String(Qt.resolvedUrl("scripts/public-fetch.py")).slice(7))].concat(root.requestArguments)
    stdout: StdioCollector { id: output }
    onExited: function(code, status) { root.exitSeen = true; root.complete(output.text, code === 0 && status === 0) }
    onRunningChanged: if (!running && root.busy && !root.exitSeen) root.complete("", false)
  }
  function request(args) {
    if (busy || process.running) return false
    root.requestArguments = args
    exitSeen = false
    busy = true
    process.running = true
    return true
  }
  function complete(value, success) { if (!busy) return; busy = false; root.finished(value, success) }
  function cancel() { busy = false; process.running = false }
  Component.onDestruction: cancel()
}
