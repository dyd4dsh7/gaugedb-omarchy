pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Model.js" as Model
import "Watch.js" as Watch
QtObject {
  id: root
  property bool enabled: false
  property var watches: []
  property var queue: []
  property var active: null
  property string status: ""
  property var notifications: []
  property bool notifyExitSeen: false
  signal updated(var values)
  property Timer poll: Timer { interval: 1800000; repeat: true; running: root.enabled && root.watches.length > 0; onTriggered: root.check() }
  property Timer next: Timer { interval: 2000; onTriggered: root.fetchNext() }
  property PublicRequest request: PublicRequest {
    onFinished: function(value, success) {
      let old = root.active
      root.active = null
      if (old && success) {
        try {
          let response = Model.decode(value, 1, {gameId: old.id, country: old.country})
          let current = root.watches.find(function(item) { return item.id === old.id && item.country === old.country && item.baseline === old.baseline })
          if (current && response.games.length) {
            let update = Watch.update(current, response.games[0], Date.now())
            root.updated(root.watches.map(function(item) { return item === current ? update.watch : item }))
            if (update.notify && root.enabled) {
              root.notifications = root.notifications.concat([Watch.notificationText(current.name + " · " + Model.price(response.games[0]) + ". Check Steam before buying.")])
              root.sendNotification()
            }
          }
        } catch(error) { root.status = "A watch response was unavailable; saved prices retained." }
      } else if (old) root.status = "Price checks unavailable; saved prices retained."
      if (root.queue.length) root.next.restart()
    }
  }
  property Process notify: Process {
    command: ["notify-send", "--app-name=GaugeDB", "GaugeDB price watch", root.notifications.length ? root.notifications[0] : ""]
    onExited: function(code, status) {
      root.notifyExitSeen = true
      if (code !== 0 || status !== 0) root.status = "Desktop notification could not be sent."
      root.notifications = root.notifications.slice(1)
      Qt.callLater(root.sendNotification)
    }
    onRunningChanged: if (!running && !root.notifyExitSeen && root.notifications.length) { root.notifications = []; root.status = "Desktop notifications unavailable; install notify-send." }
  }
  function sendNotification() { if (enabled && notifications.length && !notify.running) { notifyExitSeen = false; notify.running = true } }
  function check() {
    if (request.busy || queue.length) return
    status = ""
    queue = watches.slice(0, 10)
    fetchNext()
  }
  function fetchNext() {
    if (!queue.length) return
    active = queue[0]
    queue = queue.slice(1)
    if (!request.request(["watch", active.id.slice(6), active.country])) { active = null; queue = []; status = "Price check already running." }
  }
  function cancel() { next.stop(); queue = []; active = null; request.cancel(); notifications = []; notify.running = false }
  onEnabledChanged: if (!enabled) cancel()
  Component.onDestruction: cancel()
}
