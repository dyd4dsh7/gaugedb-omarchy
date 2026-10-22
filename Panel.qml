pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "Model.js" as Model
import "Store.js" as Store
import "Countries.js" as Countries
import "Watch.js" as Watch
import "History.js" as History

Ui.Panel {
  id: root
  moduleName: "com.gaugedb.search"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var games: []
  property string message: "Find a game by title."
  property string coverage: ""
  property bool busy: false
  property int serial: 0
  property var pending: null
  property string mode: "search"
  property string selectedId: ""
  property bool canRetry: false
  property var listGames: []
  property string listCoverage: ""
  property string listMode: "search"
  property string listMessage: "Find a game by title."
  property var presentation: ({})
  property var artworkQueue: []
  property var artworkPending: null
  property bool showProvenance: false
  property var localData: Store.empty()
  property bool storageReady: false
  property bool storageWritable: true
  property bool storageWriting: false
  property bool storageDirty: false
  property string storageMessage: ""
  property string countryCode: Countries.supported(String(root.setting("country", "NZ")).trim().toUpperCase()) ? String(root.setting("country", "NZ")).trim().toUpperCase() : "NZ"
  property bool choosingCountry: false
  property string savedSection: "favourites"
  property var comparisonIds: []
  property string requestBody: ""
  property bool offline: false
  property bool listOffline: false
  property bool showMoreActions: false
  property bool showPriceHistory: false
  property var priceHistoryData: ({points:[],currency:"",actualStoreCountry:"",coverage:""})
  property string historyMessage: ""
  property bool showHelp: false
  property bool showSettings: false
  property bool startApplied: false
  readonly property bool showingDetails: mode === "details" || mode === "compare"
  readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME").charAt(0) === "/" ? Quickshell.env("XDG_STATE_HOME") : Quickshell.env("HOME") + "/.local/state") + "/gaugedb-omarchy"
  readonly property string fontFamily: root.hostBar ? root.hostBar.fontFamily : root.fontRoles.family
  // Omarchy's grouped roles are QtObject-typed; their members are dynamic host contracts.
  readonly property var hostBar: root.bar
  readonly property var fontRoles: Style.font
  readonly property var popupRoles: Commons.Color.popups
  readonly property color foreground: root.popupRoles.text

  function loadPriceHistory(id) {
    if (historyRequest.busy || !Model.gameId(id)) return
    showPriceHistory = true
    historyMessage = "Loading saved price observations…"
    historyRequest.request(["history", id.slice(6), countryCode])
  }
  function toggleWatch(game) {
    if (!storageReady) return
    let watches = localData.watches || []
    let old = watches.find(function(item) { return item.id === game.id && item.country === root.countryCode })
    if (old) watches = watches.filter(function(item) { return item !== old })
    else {
      let quote = Watch.quote(game, countryCode, Date.now())
      if (!quote) { message = "A fresh price from this exact country is needed to start a watch."; return }
      if (quote.amount === 0) { message = "This saved price is already free; there is no lower price to watch."; return }
      if (watches.length >= 10) { message = "Remove a watch before adding another (10 maximum)."; return }
      watches = watches.concat([{id: game.id, name: game.name, country: countryCode, currency: quote.currency, baseline: quote.amount, last: quote.amount, observedAt: quote.at}])
    }
    localData = Object.assign({}, localData, {watches: watches})
    persist()
  }
  function removeWatch(id, country) {
    localData = Object.assign({}, localData, {watches:(localData.watches || []).filter(function(item) { return item.id !== id || item.country !== country })})
    persist()
  }
  function openWatch(id, country) {
    setCountry(country)
    details(id)
  }
  function importWishlist() {
    if (!storageReady || wishlistRequest.busy) return
    let id = steamId.text.trim()
    if (!/^[0-9]{17}$/.test(id)) { message = "Enter a 17-digit individual SteamID64."; return }
    message = "Reading public Steam wishlist…"
    wishlistRequest.request(["wishlist", id])
  }
  function dismiss() {
    if (showHelp) showHelp = false
    else if (showSettings) showSettings = false
    else root.close()
  }
  function setStartView(view) {
    if (["search", "saved", "deals"].indexOf(view) === -1) return
    localData = Object.assign({}, localData, { startView: view })
    persist()
  }
  function applyStartView() {
    if (startApplied || !storageReady || !opened) return
    startApplied = true
    let view = localData.startView || "search"
    if (view === "saved") root.saved()
    else if (view === "deals") root.deals()
  }
  function cancel() {
    if (busy) { message = "Request cancelled."; canRetry = true }
    clipboardPaste.cancel()
    wishlistRequest.cancel()
    wishlistNames.cancel()
    historyRequest.cancel()
    showPriceHistory = false
    priceHistoryData = ({points:[],currency:"",actualStoreCountry:"",coverage:""})
    serial += 1
    deadline.stop()
    artworkDeadline.stop()
    artworkRetry.stop()
    artworkQueue = []
    artworkPending = null
    artworkRequest.cancel()
    mcpRetry.stop()
    pending = null
    mcpRequest.cancel()
    busy = false
  }
  function close() { countryPopup.close(); cancel(); root.controller.hide() }
  function switchPanel(direction) {
    if (root.hostBar && typeof root.hostBar.switchPanelFrom === "function")
      return root.hostBar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }
  function call(name, args) {
    cancel()
    games = []
    coverage = ""
    canRetry = false
    showProvenance = false
    showMoreActions = false
    offline = false
    let id = serial
    let body
    try { body = Model.request(name, args, id) }
    catch (error) { message = error.message; return }
    requestBody = body
    busy = true
    message = name === "find_deals" ? "Loading regional deals…" : name === "get_game" ? "Loading game…" : "Searching games…"
    pending = { id: id, body: body, name: name, started: false }
    deadline.restart()
    startMcp()
  }
  function startMcp() {
    if (!pending || pending.started) return
    if (mcpRequest.busy || mcpRequest.process.running) { mcpRetry.restart(); return }
    pending.started = true
    if (!mcpRequest.request(["mcp", pending.body])) finishMcp("", false, false)
  }
  function finishMcp(value, success, rateLimited) {
    let request = pending
    if (!request || !request.started || request.id !== serial) return
    deadline.stop()
    pending = null
    busy = false
    if (!success) {
      canRetry = true
      recover(rateLimited ? "Too many requests. Wait a minute and retry."
        : "GaugeDB is unavailable. Check your connection and retry.")
      return
    }
    try {
      let requestArgs = JSON.parse(request.body).params.arguments
      let result = Model.decode(value, request.id, { gameId: requestArgs.id, ids: requestArgs.ids, country: requestArgs.country })
      games = result.games
      coverage = result.coverage
      message = result.games.length ? (result.missingIds && result.missingIds.length ? "Some selected games have no saved data." : "") : "No saved results for this request."
      localData = Store.put(localData, request.body, result, Date.now())
      if (request.name === "get_game" && result.games.length) {
        localData = Store.remember(localData, result.games[0])
        localData = Store.wishlistName(localData, result.games[0].id, result.games[0].name)
      }
      persist()
      enrich(result.games)
    } catch (error) { canRetry = true; recover("GaugeDB returned an unexpected response. Try again.") }
  }
  function enrich(items) {
    artworkQueue = items.slice(0, 5).filter(function(game) { return !root.presentation[game.id] }).map(function(game) { return game.id })
    fetchPresentation()
  }
  function fetchPresentation() {
    if (!root.opened || artworkPending || !artworkQueue.length) return
    if (artworkRequest.busy || artworkRequest.process.running) { artworkRetry.restart(); return }
    let gameId = artworkQueue[0]
    artworkQueue = artworkQueue.slice(1)
    artworkPending = { gameId: gameId, generation: serial }
    artworkDeadline.restart()
    if (!artworkRequest.request(["presentation", gameId.slice(6)])) {
      artworkDeadline.stop()
      artworkPending = null
      Qt.callLater(function() { root.fetchPresentation() })
    }
  }
  function finishPresentation(value, success, rateLimited) {
    let request = artworkPending
    if (!request || request.generation !== serial || !root.opened) return
    artworkDeadline.stop()
    artworkPending = null
    if (rateLimited) { artworkQueue = []; return }
    if (success) {
      try {
        let item = Model.decodePresentation(value, request.gameId)
        let next = Object.assign({}, presentation)
        next[request.gameId] = item
        let keys = Object.keys(next)
        while (keys.length > 30) delete next[keys.shift()]
        presentation = next
      } catch (error) { /* Optional artwork never blocks saved game data. */ }
    }
    Qt.callLater(function() { root.fetchPresentation() })
  }
  function artworkTimedOut() {
    artworkPending = null
    artworkRequest.cancel()
    Qt.callLater(function() { root.fetchPresentation() })
  }
  function search() { startApplied = true; mode = "search"; selectedId = ""; call("search_games", { query: query.text }) }
  function deals() { startApplied = true; mode = "deals"; selectedId = ""; call("find_deals", { country: countryCode }) }
  function details(id) {
    startApplied = true
    if (mode !== "details" && mode !== "compare") {
      listGames = games
      listCoverage = coverage
      listMode = mode
      listMessage = message
      listOffline = offline
    }
    mode = "details"
    selectedId = id
    call("get_game", { id: id, country: countryCode })
    scroll.contentY = 0
  }
  function back() {
    let previousId = selectedId
    cancel()
    mode = listMode
    games = listGames
    coverage = listCoverage
    message = listMessage
    offline = listOffline
    if (mode === "saved") {
      games = savedSection === "watches" ? [] : Store.savedGames(localData, savedSection)
      offline = false
      message = savedSection === "watches" ? "" : games.length ? "" : savedSection === "recent" ? "Games you open will appear here." : "Save a game from its details."
    }
    selectedId = ""
    canRetry = false
    scroll.contentY = 0
    if (!offline) enrich(games)
    Qt.callLater(function() {
      for (let i = 0; i < results.count; i++) {
        let item = results.itemAt(i) as GameResult
        if (item && item.modelData.id === previousId) { item.focusResult(); return }
      }
      if (root.mode === "search") query.forceActiveFocus(); else if (root.mode === "saved") savedTab.forceActiveFocus(); else dealsTab.forceActiveFocus()
    })
  }
  function retry() {
    if (mode === "deals") deals()
    else if (mode === "details") details(selectedId)
    else if (mode === "compare") compare()
    else search()
  }
  function countryChanged() {
    cancel()
    games = []
    coverage = ""
    listGames = []
    listCoverage = ""
    listMode = "search"
    listMessage = "Find a game by title."
    mode = "search"
    selectedId = ""
    canRetry = false
    offline = false
    message = "Search or browse deals for this country."
  }
  function queryChanged() {
    cancel()
    games = []
    coverage = ""
    canRetry = false
    message = "Press Enter or Search."
  }
  function persist() {
    storageDirty = true
    if (storageReady && storageWritable) writeDelay.restart()
  }
  function writeState() {
    if (!storageReady || !storageWritable || storageWriting || !storageDirty) return
    storageDirty = false
    storageWriting = true
    try { stateFile.setText(Store.encode(localData)) }
    catch (error) { storageWriting = false; storageMessage = "Local changes could not be saved; kept for this session." }
  }
  function loadState(text) {
    try {
      let loaded = Store.read(text, Model, Countries)
      // Preserve changes made while the asynchronous disk read was finishing.
      localData = storageDirty ? Store.mergeLoaded(loaded, localData) : loaded
      if (localData.country && Countries.supported(localData.country) && countryCode !== localData.country) { countryCode = localData.country; countryChanged() }
      storageReady = true
      root.applyStartView()
      if (storageDirty) persist()
      if (mode === "saved") saved()
    } catch (error) {
      storageReady = true
      storageWritable = false
      storageMessage = "Saved data could not be read. Existing file preserved; changes stay in this session."
    }
  }
  function setCountry(code) {
    if (!Countries.supported(code)) return
    if (countryCode !== code) { countryCode = code; countryChanged() }
    choosingCountry = false
    countryPopup.close()
    localData = Object.assign({}, localData, { country: code })
    persist()
  }
  function favourite(game) {
    try { localData = Store.toggle(localData, game); persist(); if (mode === "saved") saved() }
    catch (error) { storageMessage = error.message }
  }
  function isFavourite(id) { return localData.favourites.some(function(game) { return game.id === id }) }
  function saved() {
    startApplied = true
    cancel()
    mode = "saved"
    offline = false
    games = savedSection === "watches" ? [] : Store.savedGames(localData, savedSection)
    coverage = ""
    canRetry = false
    selectedId = ""
    message = savedSection === "watches" ? "" : games.length ? "" : savedSection === "recent" ? "Games you open will appear here." : "Save a game from its details."
    enrich(games)
  }
  function selectComparison(id) {
    if (!Model.gameId(id)) return
    if (comparisonIds.indexOf(id) !== -1) comparisonIds = comparisonIds.filter(function(value) { return value !== id })
    else if (comparisonIds.length < 2) comparisonIds = comparisonIds.concat([id])
    else message = "Remove a selected game before adding another."
  }
  function compare() {
    if (comparisonIds.length !== 2) return
    if (mode !== "compare" && mode !== "details") {
      listGames = games; listCoverage = coverage; listMode = mode; listMessage = message; listOffline = offline
    }
    mode = "compare"
    selectedId = ""
    call("compare_games", { ids: comparisonIds, country: countryCode })
    scroll.contentY = 0
  }
  function recover(reason) {
    let cached = requestBody ? Store.get(localData, requestBody, Date.now()) : null
    if (!cached) { message = reason; return }
    games = cached.result.games
    coverage = cached.result.coverage
    offline = true
    message = reason + "\nOffline summary · cached " + Model.compactObservation({at: new Date(cached.savedAt).toISOString(), freshness: "stale"})
    if (mode === "details" && games.length) { localData = Store.remember(localData, games[0]); persist() }
    // Cache recovery never starts additional network requests.
  }
  function reveal(item) {
    let top = item.mapToItem(content, 0, 0).y
    if (top < scroll.contentY) scroll.contentY = top
    else if (top + item.height > scroll.contentY + scroll.height)
      scroll.contentY = Math.max(0, top + item.height - scroll.height)
  }
  onOpenedChanged: { if (!opened) cancel(); else { root.applyStartView(); if (games.length && !offline) enrich(games) } }
  onSettingsChanged: {
    let code = String(root.setting("country", "NZ")).trim().toUpperCase()
    if (storageReady && Countries.supported(code) && code !== countryCode) root.setCountry(code)
  }
  Component.onDestruction: cancel()

  Timer { id: mcpRetry; interval: 50; onTriggered: root.startMcp() }
  PublicRequest {
    id: mcpRequest
    objectName: "gaugedb-mcp-request"
    onFinished: function(value, success) { root.finishMcp(value, success, mcpRequest.rateLimited) }
  }
  PublicRequest {
    id: historyRequest
    objectName: "gaugedb-history-request"
    onFinished: function(value, success) {
      if (!success) { root.historyMessage = "Price history is unavailable."; return }
      try { root.priceHistoryData = History.decode(value, root.selectedId, root.countryCode); root.historyMessage = "" }
      catch(error) { root.historyMessage = "Unexpected price history; no chart shown." }
    }
  }
  WatchService {
    id: watchService
    objectName: "gaugedb-watch-service"
    enabled: root.storageReady && root.localData.backgroundWatches === true
    watches: root.localData.watches || []
    onUpdated: function(values) { root.localData = Object.assign({}, root.localData, {watches: values}); root.persist() }
  }
  WishlistService {
    id: wishlistNames
    objectName: "gaugedb-wishlist-names"
    onResolved: function(id, name) {
      root.localData = Store.wishlistName(root.localData, id, name)
      root.persist()
      if (root.mode === "saved" && root.savedSection === "wishlist") root.games = Store.savedGames(root.localData, "wishlist")
    }
  }
  PublicRequest {
    id: wishlistRequest
    objectName: "gaugedb-wishlist-request"
    onFinished: function(value, success) {
      if (!success) { root.message = "Steam wishlist is private, empty without public data, or unavailable. Existing saved games kept."; return }
      try {
        let result = JSON.parse(value)
        if (!Array.isArray(result.ids) || result.ids.length > 40 || !Number.isInteger(result.total) || result.total < result.ids.length || result.ids.some(function(id) { return !Model.gameId(id) })) throw new Error("Invalid wishlist")
        root.localData = Store.importWishlist(root.localData, result.ids)
        let games = root.localData.wishlist
        root.persist()
        root.savedSection = "wishlist"
        root.saved()
        wishlistNames.start(root.localData.wishlist, root.countryCode)
        root.message = result.total > games.length ? "Showing the first 40 of " + result.total + " public wishlist games." : "Imported " + games.length + " public wishlist games."
      } catch(error) { root.message = "Steam returned an unexpected wishlist; existing saved games kept." }
    }
  }
  Timer {
    id: deadline
    interval: 12000
    onTriggered: { root.cancel(); root.canRetry = true; root.recover("Request timed out. Check your connection and retry.") }
  }
  Timer { id: writeDelay; interval: 200; onTriggered: root.writeState() }
  Process {
    // Fixed shell program; paths and initial JSON are separate positional arguments.
    // Establish confidentiality before FileView reads or performs its atomic writes.
    command: ["sh", "-c", "set -eu; umask 077; d=$1; f=$d/state.json; [ ! -L \"$d\" ]; mkdir -p -- \"$d\"; chmod 700 -- \"$d\"; if [ ! -e \"$f\" ]; then (set -C; printf \"%s\" \"$2\" > \"$f\"); fi; [ -f \"$f\" ] && [ ! -L \"$f\" ]; chmod 600 -- \"$f\"", "gaugedb-state", root.stateDirectory, Store.encode(Store.empty())]
    running: true
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) stateFile.path = root.stateDirectory + "/state.json"
      else { root.storageReady = true; root.storageWritable = false; root.storageMessage = "Private local storage is unavailable; changes stay in this session." }
    }
  }
  FileView {
    id: stateFile
    path: ""
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: function(error) {
      root.storageReady = true
      if (error === FileViewError.FileNotFound) { if (root.storageDirty) root.persist() }
      else { root.storageWritable = false; root.storageMessage = "Local storage could not be read; changes stay in this session." }
    }
    onSaved: { root.storageWriting = false; root.storageMessage = ""; if (root.storageDirty) root.persist() }
    onSaveFailed: { root.storageWriting = false; root.storageMessage = "Local changes could not be saved; kept for this session." }
  }
  Timer {
    id: artworkDeadline
    interval: 8000
    onTriggered: root.artworkTimedOut()
  }
  Timer { id: artworkRetry; interval: 50; onTriggered: root.fetchPresentation() }
  PublicRequest {
    id: artworkRequest
    objectName: "gaugedb-artwork-request"
    onFinished: function(value, success) { root.finishPresentation(value, success, artworkRequest.rateLimited) }
  }

  component Artwork: Item {
    id: artwork
    property string imageUrl: ""
    property string title: ""
    Rectangle {
      anchors.fill: parent
      radius: Style.space(4)
      color: Commons.Color.background
    }
    Label {
      anchors.fill: parent
      text: picture.status === Image.Loading ? "Loading artwork…" : "Artwork unavailable"
      font.pixelSize: Math.max(12, root.fontRoles.caption)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      visible: picture.status !== Image.Ready
    }
    Image {
      id: picture
      objectName: "gaugedb-capsule"
      anchors.fill: parent
      source: root.opened && !root.offline ? artwork.imageUrl : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      sourceSize.width: Math.round(artwork.width * 2)
      sourceSize.height: Math.round(artwork.height * 2)
      Accessible.name: artwork.title + " Steam artwork"
    }
  }

  component GameResult: Item {
    required property var modelData
    required property int index
    required property Item focusTarget
    function focusResult() { focusTarget.forceActiveFocus() }
  }

  component Label: Text {
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Math.max(13, root.fontRoles.body)
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
  }
  component Action: Controls.Button {
    id: action
    property bool quiet: false
    property bool emphasized: false
    palette.button: Commons.Color.background
    palette.buttonText: root.popupRoles.text
    palette.highlight: Commons.Color.accent
    palette.highlightedText: Commons.Color.background
    font.family: root.fontFamily
    font.pixelSize: Math.max(13, root.fontRoles.body)
    font.bold: checked || emphasized
    implicitHeight: Math.max(44, contentItem.implicitHeight + Style.space(16))
    leftPadding: Style.space(12)
    rightPadding: Style.space(12)
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5
    background: Rectangle {
      radius: Style.cornerRadius
      color: action.down ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
        : action.checked || action.emphasized ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        : action.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07) : "transparent"
      border.width: action.activeFocus ? 2 : action.quiet ? 0 : 1
      border.color: action.activeFocus ? Commons.Color.accent : root.popupRoles.border
    }
    contentItem: Label {
      text: action.text
      font: action.font
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
    Accessible.name: text
    onActiveFocusChanged: if (activeFocus) root.reveal(this)
    Keys.onEscapePressed: root.dismiss()
  }
  ClipboardPaste { id: clipboardPaste; objectName: "gaugedb-clipboard-paste" }

  component Field: ClipboardField {
    id: field
    onPasteRequested: clipboardPaste.request(field)
    onPasteCancelled: clipboardPaste.cancel(field)
    property bool scrollIntoView: true
    property real surfaceRadius: Style.cornerRadius
    property var escapeAction: function() { root.dismiss() }
    palette.base: Commons.Color.background
    palette.text: root.popupRoles.text
    palette.highlight: Commons.Color.accent
    palette.highlightedText: Commons.Color.background
    palette.placeholderText: root.popupRoles.text
    font.family: root.fontFamily
    font.pixelSize: Math.max(14, root.fontRoles.subtitle)
    implicitHeight: 44
    selectByMouse: true
    contentInset: Style.space(12)
    rightPadding: Style.space(12)
    background: Rectangle {
      radius: field.surfaceRadius
      color: Commons.Color.background
      border.width: field.activeFocus ? 2 : 1
      border.color: field.activeFocus ? Commons.Color.accent : root.popupRoles.border
    }
    onActiveFocusChanged: if (activeFocus && scrollIntoView) root.reveal(this)
    Keys.onEscapePressed: field.escapeAction()
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: root.showingDetails ? backButton : root.mode === "search" ? query : root.mode === "saved" ? savedTab : dealsTab
    contentWidth: panel.fittedContentWidth(Style.space(root.mode === "compare" ? 760 : 480))
    contentHeight: panel.fittedContentHeight(Math.max(content.implicitHeight, root.choosingCountry ? Style.space(360) : 0), Style.space(640))

    // Let native controls own Tab and text editing; catch Escape after them.
    Item {
      id: viewport
      anchors.fill: parent
      Keys.onEscapePressed: root.dismiss()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F1 || (!query.activeFocus && !countrySearch.activeFocus && event.text === "?")) {
          root.showHelp = !root.showHelp
          event.accepted = true
        } else if (!query.activeFocus && !countrySearch.activeFocus && event.key === Qt.Key_Slash && root.mode === "search") {
          query.forceActiveFocus()
          event.accepted = true
        }
      }
      Controls.Popup {
        id: countryPopup
        objectName: "gaugedb-country-popup"
        parent: viewport
        width: Math.min(Style.space(360), viewport.width)
        x: Math.max(0, Math.min(viewport.width - width, storeTrigger.mapToItem(viewport, storeTrigger.width, 0).x - width))
        y: Math.max(0, Math.min(viewport.height - height, storeTrigger.mapToItem(viewport, 0, storeTrigger.height).y + Style.space(8)))
        padding: Style.space(8)
        focus: true
        modal: true
        dim: false
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onOpened: {
          root.choosingCountry = true
          countrySearch.text = ""
          countryChoices.currentIndex = Math.max(0, countryChoices.model.findIndex(function(item) { return item.code === root.countryCode }))
          Qt.callLater(function() { countryChoices.positionViewAtIndex(countryChoices.currentIndex, ListView.Contain); countrySearch.forceActiveFocus() })
        }
        onClosed: { clipboardPaste.cancel(countrySearch); root.choosingCountry = false; if (root.opened) storeTrigger.forceActiveFocus() }
        background: Rectangle {
          color: root.popupRoles.background
          radius: Style.cornerRadius
          border.width: 1
          border.color: root.popupRoles.border
        }
        contentItem: Column {
          id: countryPickerContent
          spacing: Style.space(8)
          Field {
            id: countrySearch
            objectName: "gaugedb-country-search"
            width: parent.width
            placeholderText: "Search countries or codes"
            maximumLength: 80
            scrollIntoView: false
            surfaceRadius: Math.max(0, Style.cornerRadius - countryPopup.padding)
            escapeAction: function() { countryPopup.close() }
            Accessible.name: "Search store countries"
            onTextEdited: { countryChoices.currentIndex = countryChoices.count ? 0 : -1; countryChoices.positionViewAtBeginning() }
            onAccepted: if (countryChoices.currentIndex >= 0) root.setCountry(countryChoices.model[countryChoices.currentIndex].code)
            Keys.onDownPressed: { if (countryChoices.count) { countryChoices.currentIndex = Math.max(0, countryChoices.currentIndex); countryChoices.forceActiveFocus() } }
          }
          ListView {
            id: countryChoices
            objectName: "gaugedb-country-list"
            width: parent.width
            height: Math.min(Math.max(1, count) * 44, Math.max(44, Math.min(Style.space(264), viewport.height - countrySearch.height - countryPickerContent.spacing - countryPopup.padding * 2 - Style.space(16))))
            model: Countries.filter(countrySearch.text)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            Keys.onReturnPressed: if (currentIndex >= 0) root.setCountry(model[currentIndex].code)
            Keys.onEnterPressed: if (currentIndex >= 0) root.setCountry(model[currentIndex].code)
            Keys.onEscapePressed: countryPopup.close()
            Keys.onUpPressed: function(event) { if (currentIndex <= 0) countrySearch.forceActiveFocus(); else event.accepted = false }
            delegate: Controls.ItemDelegate {
              id: countryChoice
              required property var modelData
              required property int index
              width: countryChoices.width
              height: Math.max(44, contentItem.implicitHeight + Style.space(12))
              Accessible.name: modelData.name + ", " + modelData.code
              Accessible.selected: modelData.code === root.countryCode
              hoverEnabled: true
              onClicked: root.setCountry(modelData.code)
              onActiveFocusChanged: if (activeFocus) countryChoices.currentIndex = index
              background: Rectangle {
                radius: Math.max(0, Style.cornerRadius - countryPopup.padding)
                color: countryChoice.down ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                  : countryChoice.modelData.code === root.countryCode || countryChoice.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
                border.width: countryChoice.activeFocus || (countryChoices.activeFocus && countryChoices.currentIndex === countryChoice.index) ? 2 : 0
                border.color: Commons.Color.accent
              }
              contentItem: RowLayout {
                spacing: Style.space(12)
                Label { Layout.fillWidth: true; text: countryChoice.modelData.name }
                Label { text: countryChoice.modelData.code; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                Label { text: countryChoice.modelData.code === root.countryCode ? "✓" : ""; Layout.preferredWidth: Style.space(16) }
              }
            }
            Label { anchors.fill: parent; text: "No matching countries"; visible: countryChoices.count === 0; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
          }
        }
      }
      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)
          RowLayout {
            width: parent.width
            spacing: Style.space(16)
            Item {
              Layout.fillWidth: true
              implicitHeight: Style.space(36)
              Image {
                width: Math.min(Style.space(144), parent.width)
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                source: Qt.resolvedUrl((root.popupRoles.background.r * 0.299 + root.popupRoles.background.g * 0.587 + root.popupRoles.background.b * 0.114) > 0.5 ? "assets/logo-light.svg" : "assets/logo.svg")
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                Accessible.name: "GaugeDB"
              }
            }
            Action {
              id: storeTrigger
              text: "Store · " + root.countryCode + "  ▾"
              Accessible.name: "Choose store country, " + Countries.label(root.countryCode)
              checked: root.choosingCountry
              onClicked: countryPopup.opened ? countryPopup.close() : countryPopup.open()
            }
          }
          RowLayout {
            width: parent.width
            Action { text: "Options"; quiet: true; checked: root.showSettings; onClicked: root.showSettings = !root.showSettings }
            Item { Layout.fillWidth: true }
            Action { text: "?"; quiet: true; checked: root.showHelp; Accessible.name: "Keyboard help"; onClicked: root.showHelp = !root.showHelp }
          }
          Column {
            width: parent.width
            visible: root.showSettings
            spacing: Style.space(8)
            Field { id: steamId; objectName: "gaugedb-steam-id"; width: parent.width; maximumLength: 17; placeholderText: "SteamID64 (public wishlist)"; Accessible.name: "SteamID64 for public wishlist import" }
            Action { text: wishlistRequest.busy ? "Importing…" : "Import public wishlist"; enabled: root.storageReady && !wishlistRequest.busy; onClicked: root.importWishlist() }
            Label { width: parent.width; text: "Reads only public wishlist IDs from Steam; your Steam ID is not saved."; font.pixelSize: Math.max(12, root.fontRoles.caption) }
            Action {
              width: parent.width
              text: root.localData.backgroundWatches === true ? "Background watches · on" : "Background watches · off"
              checked: root.localData.backgroundWatches === true
              enabled: root.storageReady
              onClicked: { root.localData = Object.assign({}, root.localData, {backgroundWatches: root.localData.backgroundWatches !== true}); root.persist() }
            }
            Label { width: parent.width; text: "Opt-in checks every 30 minutes for up to 10 watched games. Notifications use saved price observations, not live Steam quotes."; font.pixelSize: Math.max(12, root.fontRoles.caption) }
            Action { text: watchService.busy ? "Checking watches…" : "Check watches now"; enabled: root.storageReady && !watchService.busy && (root.localData.watches || []).length > 0; onClicked: watchService.check() }
            Label { width: parent.width; visible: watchService.status !== ""; text: watchService.status }
            Label { text: "Open in" }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Repeater {
                model: [{ value: "search", label: "Games" }, { value: "saved", label: "Saved" }, { value: "deals", label: "Deals" }]
                Action {
                  required property var modelData
                  width: (parent.width - Style.space(16)) / 3
                  text: modelData.label
                  checked: (root.localData.startView || "search") === modelData.value
                  onClicked: root.setStartView(modelData.value)
                }
              }
            }
          }
          Label {
            width: parent.width
            visible: root.showHelp
            text: "Enter · search or open the focused game\nDown / Up · navigate results\n/ · focus game search\nF1 or ? · toggle this help\nTab / Shift+Tab · move between controls\nEscape · dismiss help, options or panel\nCtrl+V / Shift+Insert · paste\nStore · search countries by name or code"
            Accessible.name: "Keyboard shortcuts"
          }
          Label { width: parent.width; text: root.storageMessage; visible: text !== ""; font.pixelSize: Math.max(12, root.fontRoles.caption) }
          Ui.PanelSeparator { foreground: root.foreground }
          Row {
            width: parent.width
            visible: !root.showingDetails
            spacing: Style.space(8)
            Action {
              id: savedTab
              text: "Saved"; width: (parent.width - parent.spacing * 2) / 3
              checked: root.mode === "saved"
              Accessible.role: Accessible.PageTab
              Accessible.selected: checked
              onClicked: root.saved()
            }
            Action {
              id: gamesTab
              text: "Games"; width: (parent.width - parent.spacing * 2) / 3
              checked: root.mode === "search"
              Accessible.role: Accessible.PageTab
              Accessible.selected: checked
              onClicked: {
                if (root.mode === "search") { query.forceActiveFocus(); return }
                root.cancel(); root.mode = "search"; root.games = []; root.coverage = ""; root.canRetry = false
                root.message = "Find a game by title."
                query.forceActiveFocus()
              }
            }
            Action {
              id: dealsTab
              text: "Deals"; width: (parent.width - parent.spacing * 2) / 3
              checked: root.mode === "deals"
              Accessible.role: Accessible.PageTab
              Accessible.selected: checked
              onClicked: root.deals()
            }
          }
          Flow {
            width: parent.width
            visible: root.mode === "saved"
            spacing: Style.space(8)
            Action { width: parent.width < 420 ? (parent.width - parent.spacing) / 2 : (parent.width - parent.spacing * 3) / 4; text: "Favourites"; checked: root.savedSection === "favourites"; onClicked: { root.savedSection = "favourites"; root.saved() } }
            Action { width: parent.width < 420 ? (parent.width - parent.spacing) / 2 : (parent.width - parent.spacing * 3) / 4; text: "Recent"; checked: root.savedSection === "recent"; onClicked: { root.savedSection = "recent"; root.saved() } }
            Action { width: parent.width < 420 ? (parent.width - parent.spacing) / 2 : (parent.width - parent.spacing * 3) / 4; text: "Wishlist"; checked: root.savedSection === "wishlist"; onClicked: { root.savedSection = "wishlist"; root.saved() } }
            Action { width: parent.width < 420 ? (parent.width - parent.spacing) / 2 : (parent.width - parent.spacing * 3) / 4; text: "Watches"; checked: root.savedSection === "watches"; onClicked: { root.savedSection = "watches"; root.saved() } }
          }
          RowLayout {
            width: parent.width
            visible: root.comparisonIds.length > 0 && root.mode !== "compare"
            spacing: Style.space(8)
            Label { Layout.fillWidth: true; text: root.comparisonIds.length + " / 2 selected" }
            Action { text: "Clear"; quiet: true; onClicked: root.comparisonIds = [] }
            Action { text: "Compare"; emphasized: true; enabled: root.comparisonIds.length === 2; onClicked: root.compare() }
          }
          RowLayout {
            width: parent.width
            visible: root.mode === "search"
            spacing: Style.space(8)
            Field {
              id: query
              Layout.fillWidth: true
              placeholderText: "Search games"
              maximumLength: 100
              Accessible.name: "Game title"
              onAccepted: root.search()
              onTextEdited: root.queryChanged()
              Keys.onDownPressed: { let first = results.itemAt(0) as GameResult; if (first) first.focusResult() }
            }
            Action {
              text: "Search"
              emphasized: true
              enabled: query.text.trim().length > 0
              onClicked: root.search()
            }
          }
          Action {
            id: backButton
            visible: root.showingDetails
            text: "‹  Results"
            quiet: true
            onClicked: root.back()
          }
          RowLayout {
            width: parent.width
            visible: root.games.length > 0 && !root.showingDetails
            Label {
              Layout.fillWidth: true
              text: root.mode === "deals" ? "Regional deals" : root.mode === "saved" ? (root.savedSection === "watches" ? "Price watches" : root.savedSection === "wishlist" ? "Public wishlist" : root.savedSection === "recent" ? "Recent games" : "Favourites") : "Search results"
              font.pixelSize: Math.max(12, root.fontRoles.caption)
            }
            Label { text: String(root.games.length); font.pixelSize: Math.max(12, root.fontRoles.caption) }
          }
          Label { width: parent.width; text: root.message; visible: text !== ""; Accessible.role: Accessible.StaticText }
          Action { text: "Retry"; visible: !root.busy && root.canRetry; onClicked: root.retry() }
          Column {
            width: parent.width
            visible: root.mode === "saved" && root.savedSection === "watches"
            spacing: Style.space(12)
            Label { text: "Price watches · " + root.localData.watches.length }
            Action { text: watchService.busy ? "Checking…" : "Check watches now"; enabled: root.storageReady && !watchService.busy && root.localData.watches.length > 0; onClicked: watchService.check() }
            Label { width: parent.width; visible: watchService.status !== ""; text: watchService.status }
            Label { width: parent.width; visible: !root.localData.watches.length; text: "Start a watch from a game's fresh regional price." }
            Repeater {
              model: root.localData.watches || []
              Column {
                required property var modelData
                width: parent.width
                spacing: Style.space(4)
                Label { width: parent.width; text: modelData.name + " · " + modelData.country }
                Label { width: parent.width; text: "Latest " + History.amount(modelData.last, modelData.currency) + " · Started " + History.amount(modelData.baseline, modelData.currency) + (modelData.previous !== undefined && modelData.previous !== modelData.last ? "\nPrevious " + History.amount(modelData.previous, modelData.currency) + (modelData.last < modelData.previous ? " · Price fell" : " · Price rose") : "") }
                Label { width: parent.width; text: "Observed " + new Date(modelData.observedAt).toISOString() + (modelData.checkedAt ? "\nLast checked " + new Date(modelData.checkedAt).toISOString() : "\nNot checked yet"); font.pixelSize: Math.max(12, root.fontRoles.caption) }
                Row {
                  width: parent.width; spacing: Style.space(8)
                  Action { text: "Open game"; onClicked: root.openWatch(modelData.id, modelData.country) }
                  Action { text: "Remove"; Accessible.name: "Remove watch for " + modelData.name + " in " + modelData.country; onClicked: root.removeWatch(modelData.id, modelData.country) }
                }
              }
            }
          }
          Column {
            width: parent.width
            visible: root.mode === "saved" && root.savedSection === "wishlist"
            Label { width: parent.width; visible: wishlistNames.status !== ""; text: wishlistNames.status }
            Action { text: "Load missing names"; visible: !wishlistNames.busy && root.localData.wishlist.some(function(item) { return item.name === "Steam app " + item.id.slice(6) }); onClicked: wishlistNames.start(root.localData.wishlist, root.countryCode) }
          }
          GridLayout {
            id: gameGrid
            width: parent.width
            columns: root.mode === "compare" && width >= Style.space(600) ? 2 : 1
            columnSpacing: Style.space(24)
            rowSpacing: Style.space(20)
          Repeater {
            id: results
            objectName: "gaugedb-results"
            model: root.games
            delegate: GameResult {
              id: result
              focusTarget: resultButton
              readonly property var priceData: Model.priceView(modelData)
              readonly property var presentationData: root.presentation[modelData.id] || ({image: "", detail: ""})
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: gameGrid.columns === 2 ? (content.width - gameGrid.columnSpacing) / 2 : content.width
              implicitHeight: root.showingDetails ? detail.implicitHeight : Math.max(resultButton.implicitHeight, selectButton.implicitHeight)
              Action {
                id: resultButton
                width: parent.width - Style.space(52)
                visible: !root.showingDetails
                quiet: true
                Accessible.name: result.modelData.name + ", view details"
                onClicked: root.details(result.modelData.id)
                Keys.onDownPressed: {
                  let next = results.itemAt(result.index + 1) as GameResult
                  if (next) next.focusResult()
                }
                Keys.onUpPressed: {
                  let previous = results.itemAt(result.index - 1) as GameResult
                  if (previous) previous.focusResult()
                  else if (root.mode === "search") query.forceActiveFocus()
                  else if (root.mode === "saved") savedTab.forceActiveFocus()
                  else dealsTab.forceActiveFocus()
                }
                contentItem: RowLayout {
                  spacing: Style.space(12)
                  Artwork {
                    Layout.preferredWidth: content.width < Style.space(380) ? Style.space(104) : Style.space(136)
                    Layout.preferredHeight: width * 87 / 231
                    imageUrl: result.presentationData.image
                    title: result.modelData.name
                  }
                  Column {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Label { width: parent.width; text: result.modelData.name; font.pixelSize: Math.max(15, root.fontRoles.title); font.bold: true }
                    Label {
                      width: parent.width
                      text: root.mode === "deals" ? result.priceData.amount + " · " + result.priceData.region
                        + (result.priceData.discount ? " · " + result.priceData.discount : "") : result.presentationData.detail || result.modelData.id
                    }
                    Label {
                      width: parent.width; visible: root.mode === "deals"
                      text: result.priceData.note; font.pixelSize: Math.max(12, root.fontRoles.caption)
                    }
                  }
                  Label { text: "›"; font.pixelSize: Math.max(18, root.fontRoles.heading) }
                }
              }
              Action {
                id: selectButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(44)
                visible: !root.showingDetails
                text: checked ? "✓" : "+"
                checked: root.comparisonIds.indexOf(result.modelData.id) !== -1
                Accessible.name: (checked ? "Remove " : "Compare ") + result.modelData.name
                onClicked: root.selectComparison(result.modelData.id)
              }
              Column {
                id: detail
                width: parent.width
                visible: root.showingDetails
                spacing: Style.space(16)
                GridLayout {
                  width: parent.width
                  columns: width >= Style.space(320) ? 2 : 1
                  columnSpacing: Style.space(16)
                  rowSpacing: Style.space(12)
                  Artwork {
                    Layout.preferredWidth: detail.width >= Style.space(380) ? Style.space(168) : Style.space(128)
                    Layout.preferredHeight: width * 87 / 231
                    imageUrl: result.presentationData.image
                    title: result.modelData.name
                  }
                  Column {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Label { width: parent.width; text: result.modelData.name; font.pixelSize: Math.max(20, root.fontRoles.heading); font.bold: true }
                    Label { width: parent.width; text: result.presentationData.detail; visible: text !== "" }
                    Label { text: result.modelData.id; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                  }
                }
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Action { width: (parent.width - parent.spacing) / 2; text: root.isFavourite(result.modelData.id) ? "★ Saved" : "☆ Save"; checked: root.isFavourite(result.modelData.id); enabled: root.storageReady; onClicked: root.favourite(result.modelData) }
                  Action { width: (parent.width - parent.spacing) / 2; text: root.comparisonIds.indexOf(result.modelData.id) !== -1 ? "✓ Selected" : "Compare"; checked: root.comparisonIds.indexOf(result.modelData.id) !== -1; onClicked: root.selectComparison(result.modelData.id) }
                }
                Ui.PanelSeparator { foreground: root.foreground }
                Column {
                  width: parent.width
                  spacing: Style.space(4)
                  Label { text: "Saved price · " + result.priceData.region; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                  Label { width: parent.width; text: result.priceData.amount; font.pixelSize: Math.max(24, root.fontRoles.display); font.bold: true }
                  Label { text: result.priceData.discount; visible: text !== ""; font.bold: true }
                  Label { text: "Original price · " + Model.initialPrice(result.modelData); visible: Model.initialPrice(result.modelData) !== "" }
                  Label { width: parent.width; text: result.priceData.note.replace(/^Saved /, ""); font.pixelSize: Math.max(12, root.fontRoles.caption) }
                }
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Action { width: (parent.width - parent.spacing) / 2; text: "Open GaugeDB"; emphasized: true; onClicked: Quickshell.execDetached(["xdg-open", Model.links(result.modelData.id).gauge]) }
                  Action { width: (parent.width - parent.spacing) / 2; text: "Open Steam"; onClicked: Quickshell.execDetached(["xdg-open", Model.links(result.modelData.id).steam]) }
                }
                Action {
                  width: parent.width
                  text: root.showMoreActions ? "Hide more actions  −" : "More actions  +"
                  quiet: true
                  onClicked: root.showMoreActions = !root.showMoreActions
                }
                Column {
                  width: parent.width
                  visible: root.showMoreActions
                  spacing: Style.space(8)
                  Action { width: parent.width; text: "Linux compatibility · ProtonDB"; onClicked: Quickshell.execDetached(["xdg-open", Model.links(result.modelData.id).proton]) }
                  Action { width: parent.width; text: "Price history · GaugeDB"; onClicked: Quickshell.execDetached(["xdg-open", Model.links(result.modelData.id).history]) }
                  Action { width: parent.width; text: "Set price alert · GaugeDB"; onClicked: Quickshell.execDetached(["xdg-open", Model.links(result.modelData.id).alerts]) }
                  Action { width: parent.width; text: "Steam wishlist · GaugeDB"; onClicked: Quickshell.execDetached(["xdg-open", Model.wishlistLink()]) }
                  Label { width: parent.width; text: "Account actions open in your browser and may require sign-in. The website uses its own store preference."; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                }
                Ui.PanelSeparator { foreground: root.foreground }
                GridLayout {
                  width: parent.width
                  columns: width >= Style.space(300) ? 2 : 1
                  columnSpacing: Style.space(24)
                  rowSpacing: Style.space(16)
                  Column {
                    id: activity
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.space(8)
                    readonly property var activityData: Model.activityView(result.modelData)
                    Label { text: "Global activity"; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                    RowLayout {
                      width: parent.width
                      Label { Layout.fillWidth: true; text: "Players" }
                      Label { text: activity.activityData.players; font.bold: true }
                    }
                    RowLayout {
                      width: parent.width
                      Label { Layout.fillWidth: true; text: "24h peak" }
                      Label { text: activity.activityData.peak; font.bold: true }
                    }
                    Label { width: parent.width; text: activity.activityData.note; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                  }
                  Column {
                    id: reviews
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.space(8)
                    readonly property var reviewData: Model.reviewsView(result.modelData)
                    Label { text: "Reviews"; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                    RowLayout {
                      width: parent.width
                      Label { Layout.fillWidth: true; text: "Count" }
                      Label { text: reviews.reviewData.count; font.bold: true }
                    }
                    RowLayout {
                      width: parent.width
                      Label { Layout.fillWidth: true; text: "Positive" }
                      Label { text: reviews.reviewData.score; font.bold: true }
                    }
                    Label { width: parent.width; text: reviews.reviewData.note; font.pixelSize: Math.max(12, root.fontRoles.caption) }
                  }
                }
                Action {
                  width: parent.width
                  visible: root.mode === "details"
                  text: historyRequest.busy ? "Loading history…" : root.showPriceHistory ? "Hide price history" : "Price history"
                  enabled: !historyRequest.busy
                  onClicked: root.showPriceHistory ? root.showPriceHistory = false : root.loadPriceHistory(result.modelData.id)
                }
                Label { width: parent.width; visible: root.mode === "details" && root.showPriceHistory && root.historyMessage !== ""; text: root.historyMessage }
                Action {
                  width: parent.width
                  visible: root.mode === "details" && root.showPriceHistory && root.historyMessage !== ""
                  text: "Open web price history"
                  onClicked: Quickshell.execDetached(["xdg-open", Model.links(result.modelData.id).history])
                }
                PriceHistory { width: parent.width; visible: root.mode === "details" && root.showPriceHistory && root.historyMessage === ""; dataset: root.priceHistoryData; foreground: root.foreground; fontFamily: root.fontFamily; onRevealRequested: function(item) { root.reveal(item) } }
                Action {
                  width: parent.width
                  text: (root.localData.watches || []).some(function(item) { return item.id === result.modelData.id && item.country === root.countryCode }) ? "Remove local price watch" : "Watch for a lower saved price"
                  enabled: root.storageReady
                  onClicked: root.toggleWatch(result.modelData)
                }
                Action {
                  width: parent.width
                  text: root.showProvenance ? "Hide observation details  −" : "Observation details  +"
                  quiet: true
                  Accessible.description: root.showProvenance ? "Expanded" : "Collapsed"
                  onClicked: root.showProvenance = !root.showProvenance
                }
                Label {
                  width: parent.width
                  visible: root.showProvenance
                  text: "Catalogue observed · " + Model.compactObservation(result.modelData.metadata) + "\n" + root.coverage
                  font.pixelSize: Math.max(12, root.fontRoles.caption)
                }
              }
            }
          }
          }
          Label {
            width: parent.width
            visible: root.games.length > 0
            text: root.mode === "saved" ? "Stored on this device. Open a game to load its summary." : (root.mode === "deals" ? "Partial coverage · latest 512 saved price observations.\n" : "")
              + "Saved observations · check Steam before buying."
            font.pixelSize: Math.max(12, root.fontRoles.caption)
          }
        }
      }
    }
  }
}
