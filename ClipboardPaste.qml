pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
  id: root
  property ClipboardField target: null
  property bool busy: false
  property bool exitSeen: false
  property Process process: Process {
    command: ["timeout", "--signal=TERM", "--kill-after=0.2s", "1s", "bash",
      decodeURIComponent(String(Qt.resolvedUrl("scripts/clipboard-paste.sh")).slice(7)), root.target && root.target.pastePrimary ? "primary" : "clipboard"]
    stdout: StdioCollector { id: output }
    onExited: function(exitCode, exitStatus) {
      root.exitSeen = true
      root.complete(output.text, exitCode, exitStatus)
    }
    onRunningChanged: if (!running && root.busy && !root.exitSeen) root.complete("", -1, 1)
  }
  function complete(value, exitCode, exitStatus) {
    let field = target
    target = null
    busy = false
    if (field) field.finishPaste(value, exitCode, exitStatus)
  }

  function request(field) {
    if (busy) { field.pasteBusy = false; field.pasteMessage = "Paste already running. Try again."; return }
    target = field
    busy = true
    exitSeen = false
    process.running = true
  }
  function cancel(field) {
    if (field && target !== field) return
    if (target) target.pasteBusy = false
    target = null
    process.running = false
    if (!process.running) busy = false
  }
  Component.onDestruction: cancel()
}
