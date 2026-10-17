pragma ComponentBehavior: Bound
import QtQuick
import "Model.js" as Model
QtObject {
  id: root
  property var queue: []
  property string activeId: ""
  property string country: "NZ"
  property int unavailable: 0
  readonly property bool busy: request.busy || queue.length > 0 || next.running
  readonly property string status: busy ? "Loading wishlist names… " + (queue.length + (activeId ? 1 : 0)) + " remaining" : unavailable ? unavailable + " names unavailable. Retry when connected." : ""
  signal resolved(string gameId, string name)
  property Timer next: Timer { interval: 2000; onTriggered: root.fetchNext() }
  property PublicRequest request: PublicRequest {
    onFinished: function(value, success) {
      let id = root.activeId
      root.activeId = ""
      if (!id) return
      try {
        if (!success) throw new Error("Unavailable")
        let result = Model.decode(value, 1, {gameId:id,country:root.country})
        if (!result.games.length || !result.games[0].name.trim()) throw new Error("No name")
        root.resolved(id, result.games[0].name)
      } catch(error) { root.unavailable++ }
      if (root.queue.length) root.next.restart()
    }
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
    activeId = queue[0]
    queue = queue.slice(1)
    if (!request.request(["watch", activeId.slice(6), country])) { activeId = ""; queue = []; unavailable++ }
  }
  function cancel() { next.stop(); queue = []; activeId = ""; request.cancel() }
  Component.onDestruction: cancel()
}
