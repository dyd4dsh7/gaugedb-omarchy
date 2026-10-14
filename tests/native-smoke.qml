pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../" as Plugin

// Use only disposable state via scripts/native-smoke.sh.
Item {
  id: test
  property int ticks: 0
  property int phase: 0
  readonly property string mode: Quickshell.env("GAUGEDB_TEST_MODE")
  function check(value, message) {
    if (!value) { console.error("GAUGEDB_NATIVE_FAIL: " + message); Qt.quit(); throw new Error(message) }
  }
  function find(object, name, visited) {
    if (!object || visited.indexOf(object) !== -1) return null
    visited.push(object)
    if (object.objectName === name) return object
    for (let key of ["data", "children", "contentItem"]) {
      let list = object[key]
      if (!list) continue
      if (list.length === undefined) list = [list]
      for (let i = 0; i < list.length; i++) {
        let found = find(list[i], name, visited)
        if (found) return found
      }
    }
    return null
  }
  Plugin.BarWidget { id: widget }
  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      test.ticks++
      test.check(test.ticks < 240, "native smoke test timed out")
      test.check(Quickshell.env("GAUGEDB_NATIVE_TEST") === "1" && Quickshell.env("XDG_STATE_HOME").indexOf("/tmp/") === 0, "disposable test state required")
      let panel = widget.loadedPanel
      if (!panel || !panel.storageReady) return
      if (test.phase === 0) {
        test.check(panel.fontRoles.body > 0 && panel.fontRoles.caption > 0, "native font roles")
        test.check(widget.barMetrics.statusSlot > 0, "native bar roles")
        if (test.mode === "features") {
          let wishlist = test.find(panel, "gaugedb-wishlist-request", [])
          let input = test.find(panel, "gaugedb-steam-id", [])
          test.check(wishlist && input, "native wishlist controls")
          panel.favourite({id:"steam:620",name:"Portal 2"})
          input.text = "76561197960265729"
          wishlist.requestArguments = ["wishlist", input.text]
          test.check(wishlist.process.command.length === 6 && wishlist.process.command.join(" ").indexOf(input.text) < 0, "private request inputs absent from production argv")
          wishlist.process.command = ["python3", Quickshell.env("GAUGEDB_PUBLIC_PROVIDER")]
          panel.importWishlist()
          test.phase = 60; return
        }
        if (test.mode === "clipboard") {
          let reader = test.find(panel, "gaugedb-clipboard-paste", [])
          let input = test.find(panel, "gaugedb-country-search", [])
          test.check(reader && input, "clipboard controller and field")
          input.text = ""
          reader.process.command = ["/missing-gaugedb-clipboard-command"]
          input.paste()
          test.phase = 50; return
        }
        if (test.mode === "network") {
          panel.call("get_game", { id: "steam:620", country: "NZ" })
          test.phase = 4; return
        }
        if (test.mode === "read") {
          test.check(panel.countryCode === "US" && panel.isFavourite("steam:620"), "restart restored country and favourite")
          console.log("GAUGEDB_NATIVE_PASS: restart read")
          Qt.quit(); return
        }
        if (test.mode === "corrupt" || test.mode === "unsafe") {
          test.check(!panel.storageWritable, "unsafe or corrupt storage disables writes")
          panel.favourite({ id: "steam:620", name: "Portal 2" })
          test.phase = 3; return
        }
        test.check(panel.storageWritable, "new state writable")
        let country = panel.countryCode
        panel.setCountry("ZZ")
        test.check(panel.countryCode === country, "invalid country rejected")
        panel.setCountry("US")
        panel.favourite({ id: "steam:620", name: "Portal 2" })
        panel.selectComparison("steam:620")
        panel.selectComparison("steam:730")
        panel.selectComparison("invalid")
        test.check(panel.comparisonIds.length === 2, "comparison validation")
        panel.mode = "search"
        panel.offline = true
        panel.games = [{ id: "steam:620", name: "Portal 2" }, { id: "steam:730", name: "Counter-Strike 2" }]
        test.phase = 1; return
      }
      if (test.phase >= 60) {
        let wishlist = test.find(panel, "gaugedb-wishlist-request", [])
        let history = test.find(panel, "gaugedb-history-request", [])
        let watches = test.find(panel, "gaugedb-watch-service", [])
        test.check(wishlist && history && watches, "native feature services")
        if (test.phase === 60) {
          if (wishlist.busy || panel.localData.wishlist.length !== 2) return
          test.check(panel.isFavourite("steam:620"), "wishlist preserves favourites")
          panel.countryCode = "NZ"
          panel.selectedId = "steam:620"
          panel.mode = "details"
          panel.games = [{id:"steam:620",name:"Portal 2"}]
          history.process.command = ["printf", "%s", JSON.stringify({gameId:"steam:620",requestedCountry:"NZ",actualStoreCountry:"NZ",coverage:"Synthetic native test observations",points:[{at:new Date().toISOString(),finalMinor:499,currency:"NZD",timeBasis:"observed"}]})]
          panel.loadPriceHistory("steam:620")
          test.phase = 61; return
        }
        if (test.phase === 61) {
          if (history.busy || panel.priceHistoryData.points.length !== 1) return
          panel.localData = Object.assign({}, panel.localData, {watches:[{id:"steam:620",name:"Portal 2",country:"NZ",currency:"NZD",baseline:999,last:999,observedAt:Date.now()-60000}]})
          watches.request.process.command = ["printf", "%s", JSON.stringify({jsonrpc:"2.0",id:1,result:{structuredContent:{coverage:"Synthetic test quote",games:[{id:"steam:620",name:"Portal 2",price:{status:"priced",requestedCountry:"NZ",actualStoreCountry:"NZ",currency:"NZD",finalMinor:499,observation:{at:new Date().toISOString(),freshness:"fresh"}}}]}}})]
          panel.localData = Object.assign({}, panel.localData, {backgroundWatches:true})
          watches.check()
          test.phase = 62; return
        }
        if (test.phase === 62) {
          if (watches.request.busy || panel.localData.watches[0].last !== 499 || !watches.notifyExitSeen || watches.notifications.length) return
          test.check(watches.status === "", "automatic notification succeeds and drains queue")
          panel.localData = Object.assign({}, panel.localData, {backgroundWatches:true})
          watches.notify.command = ["/missing-gaugedb-notification-command"]
          watches.notifications = ["Native test notification"]
          watches.sendNotification()
          test.phase = 63; return
        }
        if (watches.notifications.length) return
        test.check(watches.status.indexOf("unavailable") >= 0, "failed notification startup recovers")
        panel.localData = Object.assign({}, panel.localData, {backgroundWatches:false})
        test.check(!watches.poll.running, "background opt-out stops polling")
        panel.setStartView("saved")
        panel.showHelp = true
        panel.dismiss()
        test.check(!panel.showHelp && panel.localData.startView === "saved", "native options and help")
        console.log("GAUGEDB_NATIVE_PASS: wishlist isolation, history, local watch, notification recovery and options")
        Qt.quit(); return
      }
      if (test.phase >= 50 && test.phase < 60) {
        let reader = test.find(panel, "gaugedb-clipboard-paste", [])
        let input = test.find(panel, "gaugedb-country-search", [])
        if (reader.busy || input.pasteBusy) return
        if (test.phase === 50) {
          test.check(input.text === "" && input.pasteMessage.length > 0, "failed startup recovers")
          reader.process.command = ["sh", "-c", "sleep 0.1; printf NZ"]
          input.paste()
          test.phase = 51; return
        }
        if (test.phase === 51) {
          test.check(input.text === "NZ", "paste retry receives complete output")
          input.text = ""
          reader.process.command = ["sh", "-c", "sleep 0.4; printf stale"]
          input.paste()
          let popup = test.find(panel, "gaugedb-country-popup", [])
          test.check(popup, "country popup")
          popup.closed()
          test.phase = 52; return
        }
        test.check(input.text === "", "picker close cancels late paste")
        console.log("GAUGEDB_NATIVE_PASS: clipboard startup recovery, retry and picker-close cancellation")
        Qt.quit(); return
      }
      if (test.phase >= 4) {
        if (panel.busy) return
        test.check(panel.games.length > 0 && !panel.offline, "Qt public catalogue phase " + test.phase + ": " + panel.message)
        if (test.phase === 4) {
          test.check(panel.games[0].id === "steam:620", "Qt detail exact game")
          panel.call("search_games", { query: "Portal" })
        } else if (test.phase === 5) {
          panel.call("find_deals", { country: "NZ" })
        } else if (test.phase === 6) {
          panel.call("compare_games", { ids: ["steam:620", "steam:730"], country: "NZ" })
        } else {
          test.check(panel.games.length === 2, "Qt comparison games")
          console.log("GAUGEDB_NATIVE_PASS: Qt HTTP details, search, deals and comparison")
          Qt.quit(); return
        }
        test.phase++; return
      }
      if (test.phase === 1) {
        let results = test.find(panel, "gaugedb-results", [])
        test.check(results && results.count === 2, "bound result delegates instantiated")
        test.check(results.itemAt(0).modelData.id === "steam:620", "delegate required modelData")
        test.check(results.itemAt(1).index === 1, "delegate required index")
        results.itemAt(1).focusResult()
        panel.listMode = "saved"
        panel.listGames = panel.games
        panel.selectedId = "steam:620"
        panel.back()
        test.check(panel.games.length === 1 && panel.games[0].id === "steam:620", "native Saved Back rebuild")
        let search = test.find(panel, "gaugedb-country-search", [])
        let choices = test.find(panel, "gaugedb-country-list", [])
        test.check(search && choices, "native country controls")
        search.text = "New Zealand"
        test.check(choices.model.length === 1 && choices.model[0].code === "NZ", "native country filter binding")
        test.check(panel.countryCode === "US", "filtering preserves country")
        choices.currentIndex = 0
        search.accepted()
        test.check(panel.countryCode === "NZ", "native country accepted handler")
        panel.setCountry("US")
        search.text = "no-country-matches"
        test.check(choices.model.length === 0, "native empty country filter")
        choices.currentIndex = -1
        search.accepted()
        test.check(panel.countryCode === "US", "empty acceptance preserves country")
        search.text = ""
        test.phase = 2; return
      }
      if (test.phase === 2 && !panel.storageDirty && !panel.storageWriting) {
        console.log("GAUGEDB_NATIVE_PASS: write, delegates, country bindings, focus and actions")
        Qt.quit(); return
      }
      if (test.phase === 3 && test.ticks > 15) {
        console.log("GAUGEDB_NATIVE_PASS: " + test.mode + " state preserved")
        Qt.quit()
      }
    }
  }
}
