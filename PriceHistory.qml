pragma ComponentBehavior: Bound
import QtQuick
import "History.js" as History
Item {
  id: root
  property var dataset: ({points:[],currency:"",actualStoreCountry:"",coverage:""})
  property color foreground: "white"
  property string fontFamily: "sans-serif"
  implicitHeight: labels.implicitHeight
  onDatasetChanged: Qt.callLater(plot.requestPaint)
  onForegroundChanged: plot.requestPaint()
  Column {
    id: labels
    width: parent.width
    spacing: 8
    Text { width: parent.width; text: root.dataset.points.length ? "Price history · " + root.dataset.actualStoreCountry + " · " + root.dataset.currency : "No saved price history"; color: root.foreground; font.family: root.fontFamily; textFormat: Text.PlainText; wrapMode: Text.WordWrap }
    Canvas {
      id: plot
      width: parent.width
      height: root.dataset.points.length ? 140 : 0
      visible: root.dataset.points.length > 0
      onWidthChanged: requestPaint()
      onAvailableChanged: if (available) requestPaint()
      onVisibleChanged: if (visible) requestPaint()
      Accessible.name: "Saved price observations in " + root.dataset.currency + ". " + root.dataset.points.length + " observations."
      onPaint: {
        let ctx = getContext("2d")
        ctx.reset()
        let points = root.dataset.points
        if (!points.length) return
        let amounts = points.map(function(p) { return p.finalMinor })
        let low = Math.min.apply(null, amounts)
        let high = Math.max.apply(null, amounts)
        let first = Date.parse(points[0].at)
        let last = Date.parse(points[points.length-1].at)
        ctx.fillStyle = root.foreground
        for (let point of points) {
          let x = last === first ? width / 2 : 8 + (Date.parse(point.at)-first) / (last-first) * Math.max(1,width-16)
          let y = high === low ? height / 2 : 8 + (high-point.finalMinor) / (high-low) * Math.max(1,height-16)
          ctx.beginPath(); ctx.arc(x,y,3,0,Math.PI*2); ctx.fill()
        }
      }
    }
    Text {
      width: parent.width
      text: root.dataset.points.length ? "Latest · " + History.amount(root.dataset.points[root.dataset.points.length-1].finalMinor, root.dataset.currency) + " · " + root.dataset.points[root.dataset.points.length-1].at + "\n" + root.dataset.coverage + (root.dataset.otherCurrencies ? " Earlier observations in other currencies are excluded." : "") + (root.dataset.hasLegacy ? " Some dates use legacy history rather than original observation timestamps." : "") : root.dataset.coverage
      color: root.foreground
      font.family: root.fontFamily
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
    }
  }
}
