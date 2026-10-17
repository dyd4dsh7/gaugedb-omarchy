pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../" as Plugin
QtObject {
  id: root
  property int ticks: 0
  property int phase: 0
  property Plugin.WatchService service: Plugin.WatchService {
    enabled: true
    watches: [{id:"steam:620",name:"PRIVATE WATCH NAME",country:"NZ",currency:"NZD",baseline:999,last:999,observedAt:Date.now()-60000}]
    onUpdated: function(values) { watches = values }
  }
  property Plugin.PublicRequest wishlist: Plugin.PublicRequest {
    onFinished: function(value, success) {
      root.check(success && JSON.parse(value).ids.length === 2, "wishlist stdin transport")
      root.phase = 1
    }
  }
  function check(value, label) { if (!value) { console.error("PRIVACY_FAIL: " + label); Qt.quit(); throw new Error(label) } }
  property Timer test: Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      root.ticks++
      root.check(root.ticks < 200, "deadline")
      if (root.phase === 0 && !root.wishlist.busy) {
        root.wishlist.requestArguments = ["wishlist", "76561197960265729"]
        root.check(root.wishlist.process.command.length === 6 && root.wishlist.process.command.join(" ").indexOf("76561197960265729") < 0, "account absent from command")
        root.wishlist.process.command = ["python3", Quickshell.env("GAUGEDB_PUBLIC_PROVIDER")]
        root.wishlist.request(["wishlist", "76561197960265729"])
      } else if (root.phase === 1) {
        root.service.request.requestArguments = ["watch", "620", "NZ"]
        root.check(root.service.request.process.command.length === 6 && root.service.request.process.command.indexOf("620") < 0, "watch absent from command")
        root.service.request.process.command = ["python3", Quickshell.env("GAUGEDB_PUBLIC_PROVIDER")]
        root.service.check()
        root.phase = 2
      } else if (root.phase === 2 && !root.service.request.busy && root.service.watches[0].last === 499 && root.service.notifyExitSeen && !root.service.notifications.length) {
        root.check(root.service.status === "Checked 1 watches.", "notification delivered")
        root.service.enabled = false
        root.check(!root.service.poll.running && !root.service.notify.running, "opt-out cancels")
        console.log("PRIVACY_PASS: native stdin transport, automatic generic notification and cancellation")
        Qt.quit()
      }
    }
  }
}
