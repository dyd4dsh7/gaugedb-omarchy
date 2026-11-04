pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Model.js" as Model
import "Watch.js" as Watch
QtObject {
  id: root
  property bool enabled: false
  property var cooldown: null
  property var watches: []
  property var queue: []
  property var active: null
  property string resultStatus: ""
  property string notificationError: ""
  readonly property string status: (cooldown && cooldown.remainingSeconds > 0 && busy ? "Price checks paused; retry in " + cooldown.remainingSeconds + "s." : resultStatus) + (notificationError ? (busy || resultStatus ? "\n" : "") + notificationError : "")
  property int completed: 0
  property var outcomes: ({updated:0, unchanged:0, unavailable:0, failed:0})
  readonly property bool busy: request.busy || queue.length > 0 || next.running
  property var notifications: []
  property bool notifyExitSeen: false
  signal updated(var values)
  property Timer poll: Timer { interval: 1800000; repeat: true; running: root.enabled && root.watches.length > 0; onTriggered: root.check() }
  property Timer next: Timer { interval: 2000; onTriggered: root.fetchNext() }
  property PublicRequest request: PublicRequest {
    onFinished: function(value, success) {
      root.finish(value, success)
    }
  }
  property Process notify: Process {
    command: ["notify-send", "--app-name=GaugeDB", "GaugeDB price watch", "A watched price fell. Open GaugeDB to review saved prices; check Steam before buying."]
    onExited: function(code, status) {
      root.notifyExitSeen = true
      root.notificationError = code !== 0 || status !== 0 ? "Desktop notification could not be sent." : ""
      root.notifications = root.notifications.slice(1)
      Qt.callLater(root.sendNotification)
    }
    onRunningChanged: if (!running && !root.notifyExitSeen && root.notifications.length) { root.notifications = []; root.notificationError = "Desktop notifications unavailable; install notify-send." }
  }
  function sendNotification() { if (enabled && notifications.length && !notify.running) { notifyExitSeen = false; notify.running = true } }
  function finish(value, success) {
    let old = active
    active = null
    if (!old) return
    if (request.rateLimited) {
      queue = [old].concat(queue)
      if (cooldown) cooldown.block()
    } else {
      let current = watches.find(function(item) { return item.id === old.id && item.country === old.country && item.baseline === old.baseline })
      if (current) {
        let result = {watch:Object.assign({}, current, {checkedAt:Date.now()}), notify:false, outcome:"failed"}
        if (success) {
          try {
            let response = Model.decode(value, 1, {gameId:old.id, country:old.country})
            result = Watch.update(current, response.games[0], Date.now())
          } catch(error) { /* Keep the last valid price on malformed replies. */ }
        }
        updated(watches.map(function(item) { return item === current ? result.watch : item }))
        let counts = Object.assign({}, outcomes)
        counts[result.outcome]++
        outcomes = counts
        if (result.notify && enabled) { notifications = notifications.concat([true]); sendNotification() }
        completed++
      }
      resultStatus = summary()
    }
    if (queue.length) { next.interval = cooldown && cooldown.remainingSeconds > 0 ? cooldown.remainingSeconds * 1000 : 2000; next.restart() }
  }
  function summary() { return outcomes.updated + " updated · " + outcomes.unchanged + " unchanged · " + outcomes.unavailable + " unavailable · " + outcomes.failed + " failed." }
  function check() {
    if (busy) return
    resultStatus = ""
    completed = 0
    outcomes = ({updated:0, unchanged:0, unavailable:0, failed:0})
    queue = watches.slice(0, 10)
    fetchNext()
  }
  function fetchNext() {
    queue = queue.filter(function(item) { return watches.some(function(current) { return current.id === item.id && current.country === item.country && current.baseline === item.baseline }) })
    if (!queue.length) { next.stop(); resultStatus = completed ? summary() : ""; return }
    if ((cooldown && cooldown.remainingSeconds > 0) || request.busy || request.process.running) {
      next.interval = cooldown && cooldown.remainingSeconds > 0 ? cooldown.remainingSeconds * 1000 : 50
      next.restart()
      return
    }
    active = queue[0]
    if (request.request(["watch", active.id.slice(6), active.country])) queue = queue.slice(1)
    else { active = null; next.interval = 50; next.restart() }
  }
  function cancel() { resultStatus = ""; next.stop(); queue = []; active = null; request.cancel(); notifications = []; notify.running = false }
  onEnabledChanged: if (!enabled) cancel()
  Component.onDestruction: cancel()
}
