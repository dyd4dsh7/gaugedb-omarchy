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
      if (test.phase >= 50) {
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
