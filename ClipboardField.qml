pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

// TextArea checks clipboard formats without eagerly reading foreign text payloads.
Controls.TextArea {
  id: field
  property int maximumLength: 100
  property real contentInset: 12
  property real horizontalOffset: 0
  leftPadding: contentInset - horizontalOffset
  rightPadding: contentInset
  clip: true
  property string pasteMessage: ""
  property bool pasteBusy: false
  property bool pastePrimary: false
  property string pasteBase: ""
  property int pasteStart: 0
  property int pasteEnd: 0
  signal accepted()
  signal pasteRequested()
  textFormat: TextEdit.PlainText
  wrapMode: TextEdit.NoWrap
  verticalAlignment: TextEdit.AlignVCenter
  selectByMouse: true
  Controls.ContextMenu.menu: null
  Accessible.description: pasteMessage
  Controls.ToolTip.text: pasteMessage
  Controls.ToolTip.visible: pasteMessage !== "" && activeFocus
  Controls.ToolTip.timeout: 4000

  function singleLine(value) { return value.replace(/[\r\n\u2028\u2029]/g, " ") }
  property string lastValidText: ""
  signal pasteCancelled()
  function enforceLimit() {
    if (text.length <= maximumLength && text === singleLine(text)) return
    if (canUndo) undo()
    if (text.length > maximumLength || text !== singleLine(text)) text = lastValidText
    pasteMessage = "Enter one line of up to " + maximumLength + " characters."
  }
  onTextChanged: {
    if (text.length <= maximumLength && text === singleLine(text)) lastValidText = text
    else Qt.callLater(enforceLimit)
  }
  function revealCursor() {
    if (!activeFocus || width <= contentInset + rightPadding + 4) return
    let x = cursorRectangle.x
    if (x > width - rightPadding - 2) horizontalOffset += x - (width - rightPadding - 2)
    else if (x < contentInset) horizontalOffset = Math.max(0, horizontalOffset - (contentInset - x))
  }
  onCursorRectangleChanged: revealCursor()
  onWidthChanged: revealCursor()
  onActiveFocusChanged: {
    if (!activeFocus) { pasteBusy = false; pasteCancelled() }
    else Qt.callLater(revealCursor)
  }
  function paste() { startPaste(false) }
  function startPaste(primary) {
    if (pasteBusy) return
    pasteMessage = ""
    pasteBase = text
    pasteStart = selectionStart
    pasteEnd = selectionEnd
    pastePrimary = primary === true
    pasteBusy = true
    pasteRequested()
  }
  function finishPaste(output, exitCode, exitStatus) {
    if (!pasteBusy) return
    pasteBusy = false
    if (exitCode !== 0 || exitStatus !== 0) { pasteMessage = "Clipboard unavailable, too large or timed out."; return }
    let value = singleLine(output)
    if (text !== pasteBase || selectionStart !== pasteStart || selectionEnd !== pasteEnd) return
    if (!value.length) { pasteMessage = "Clipboard is empty."; return }
    if (value.indexOf("\u0000") !== -1 || text.length - (pasteEnd - pasteStart) + value.length > maximumLength) {
      pasteMessage = "Paste up to " + maximumLength + " characters."
      return
    }
    remove(pasteStart, pasteEnd)
    insert(pasteStart, value)
    cursorPosition = pasteStart + value.length
    textEdited()
  }
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.matches(StandardKey.Paste)) { field.paste(); event.accepted = true }
    else if (event.text.length && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
      && text.length - (selectionEnd - selectionStart) + event.text.length > maximumLength) { event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { field.accepted(); event.accepted = true }
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    preventStealing: true
    onPressed: function(event) { event.accepted = true; field.forceActiveFocus(); field.cursorPosition = field.positionAt(event.x, event.y); field.deselect(); field.startPaste(true) }
    onReleased: function(event) { event.accepted = true }
    onDoubleClicked: function(event) { event.accepted = true }
  }
}
