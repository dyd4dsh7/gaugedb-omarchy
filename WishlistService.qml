pragma ComponentBehavior: Bound
import QtQuick
import "Model.js" as Model
QtObject {
  id: root
  property var cooldown: null
  property var queue: []
  property string activeId: ""
  property string country: "NZ"
  property int unavailable: 0
  readonly property bool busy: request.busy || queue.length > 0 || next.running
  readonly property string status: cooldown && cooldown.remainingSeconds > 0 && busy ? "Wishlist names paused; retry in " + cooldown.remainingSeconds + "s." : busy ? "Loading wishlist names… " + (queue.length + (activeId ? 1 : 0)) + " remaining" : unavailable ? unavailable + " names unavailable. Retry when connected." : ""
  signal resolved(string gameId, string name)
  property Timer next: Timer { interval: 2000; onTriggered: root.fetchNext() }
  property PublicRequest request: PublicRequest {
    onFinished: function(value, success) {
      root.finish(value, success)
    }
  }
  function finish(value, success) {
    let id = activeId
    activeId = ""
    if (!id) return
    if (request.rateLimited) {
      queue = [id].concat(queue)
      if (cooldown) cooldown.block()
    } else {
      try {
        if (!success) throw new Error("Unavailable")
        let result = Model.decode(value, 1, {gameId:id,country:country})
        if (!result.games.length || !result.games[0].name.trim()) throw new Error("No name")
        resolved(id, result.games[0].name)
      } catch(error) { unavailable++ }
    }
    if (queue.length) { next.interval = cooldown && cooldown.remainingSeconds > 0 ? cooldown.remainingSeconds * 1000 : 2000; next.restart() }
  }
  function start(items, countryCode) {
    cancel()
    country = countryCode
    unavailable = 0
    queue = items.slice(0,40).filter(function(item) { return Model.gameId(item.id) && item.name === "Steam app " + item.id.slice(6) }).map(function(item) { return item.id })
    fetchNext()
  }
  function fetchNext() {
    if (!queue.length) return
    if ((cooldown && cooldown.remainingSeconds > 0) || request.busy || request.process.running) {
      next.interval = cooldown && cooldown.remainingSeconds > 0 ? cooldown.remainingSeconds * 1000 : 50
      next.restart()
      return
    }
    activeId = queue[0]
    if (request.request(["watch", activeId.slice(6), country])) queue = queue.slice(1)
    else { activeId = ""; next.interval = 50; next.restart() }
  }
  function cancel() { next.stop(); queue = []; activeId = ""; request.cancel() }
  Component.onDestruction: cancel()
}
