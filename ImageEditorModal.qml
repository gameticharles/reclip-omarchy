import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  visible: false
  anchors.fill: parent
  color: Util.alpha(Color.popups.background || Color.background, 0.98)
  radius: Style.cornerRadius
  z: 105

  // Root MouseArea: Absorbs all clicks on modal background so nothing ever reaches underlying views
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    onClicked: function(mouse) { mouse.accepted = true }
    onPressed: function(mouse) { mouse.accepted = true }
    onReleased: function(mouse) { mouse.accepted = true }
    onWheel: function(wheel) { wheel.accepted = true }
  }

  // Signals
  signal savedToClipboard(string path)
  signal savedToHistory(string path)
  signal runOcr(string path)
  signal requestScreenPick()
  signal requestColorPicker()
  signal closed()

  // Properties
  property string imagePath: ""
  property string originalImagePath: ""
  property string currentTool: "select" // "select", "pan", "pen", "highlighter", "arrow", "rect", "circle", "line", "blur", "text", "stamp", "eraser", "crop", "block_highlight", "pixelate"
  property int selectedActionIndex: -1
  property bool isExporting: false
  property color currentColor: "#EF4444"
  property int strokeWidth: 4
  property bool fillShape: false
  property bool textBox: false
  property string currentStamp: "number" // "number", "check", "cross", "star", "warn", "bug", "fire"
  property int stampCounter: 1
  property string actionFeedback: ""
  property var imageHistory: []
  property var imageRedoStack: []
  property var cropRect: null
  property var cropStartPt: null
  property string cropRatio: "free" // "free", "1:1", "16:9", "4:3", "9:16"

  readonly property var cropRatios: [
    { id: "free", label: "Free", ratio: 0 },
    { id: "1:1", label: "1:1", ratio: 1.0 },
    { id: "16:9", label: "16:9", ratio: 16.0 / 9.0 },
    { id: "4:3", label: "4:3", ratio: 4.0 / 3.0 },
    { id: "9:16", label: "9:16", ratio: 9.0 / 16.0 }
  ]

  function setCropRatio(ratioId) {
    root.cropRatio = ratioId
    if (!root.cropRect) root.initCropRect()
    if (ratioId === "free") return

    var targetRatio = 1.0
    for (var i = 0; i < root.cropRatios.length; i++) {
      if (root.cropRatios[i].id === ratioId) {
        targetRatio = root.cropRatios[i].ratio
        break
      }
    }

    var imgW = (baseImage.implicitWidth > 0 ? baseImage.implicitWidth : 800)
    var imgH = (baseImage.implicitHeight > 0 ? baseImage.implicitHeight : 600)
    var curW = root.cropRect.width
    var curH = root.cropRect.height
    var curCX = root.cropRect.x + curW / 2
    var curCY = root.cropRect.y + curH / 2

    var newW = curW
    var newH = Math.round(newW / targetRatio)
    if (newH > imgH) {
      newH = imgH
      newW = Math.round(newH * targetRatio)
    }
    if (newW > imgW) {
      newW = imgW
      newH = Math.round(newW / targetRatio)
    }
    var newX = Math.max(0, Math.min(imgW - newW, Math.round(curCX - newW / 2)))
    var newY = Math.max(0, Math.min(imgH - newH, Math.round(curCY - newH / 2)))

    root.cropRect = { x: newX, y: newY, width: newW, height: newH }
    root.showFeedback("✂ Ratio: " + ratioId)
  }

  Timer {
    id: feedbackTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionFeedback = ""
  }

  Process {
    id: transformProc
    property string targetPath: ""
    property string feedbackLabel: ""
    command: []
    onExited: function(code) {
      if (code === 0 && targetPath !== "") {
        root.actions = []
        root.redoStack = []
        root.imagePath = targetPath
        baseImage.source = ""
        baseImage.source = "file://" + targetPath + "?t=" + Date.now()
        root.showFeedback(feedbackLabel)
      } else {
        root.showFeedback("⚠ Transform failed")
      }
    }
  }

  function showFeedback(msg) {
    root.actionFeedback = msg
    feedbackTimer.restart()
  }

  // Zoom & Pan state
  property real zoomScale: 1.0

  // Annotation stacks
  property var actions: []
  property var undoStack: []
  property var redoStack: []
  property var currentAction: null
  property bool isDrawing: false

  onCurrentColorChanged: {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && String(act.color) !== String(root.currentColor)) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.color = String(root.currentColor)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
  }

  onStrokeWidthChanged: {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        var newSz = act.tool === "text" ? Math.max(14, root.strokeWidth * 4) : root.strokeWidth
        var curSz = act.tool === "text" ? act.size : act.width
        if (newSz !== curSz) {
          root.pushUndoState()
          var next = root.actions.slice()
          var cloned = JSON.parse(JSON.stringify(act))
          if (act.tool === "text") cloned.size = newSz
          else cloned.width = newSz
          next[root.selectedActionIndex] = cloned
          root.actions = next
          annotationCanvas.requestPaint()
        }
      }
    }
  }

  onTextBoxChanged: {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text" && Boolean(act.box) !== Boolean(root.textBox)) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.box = Boolean(root.textBox)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
  }

  // Text input state
  property bool textInputActive: false
  property point textInputPos: Qt.point(0, 0)
  property string textInputDraft: ""

  // Color presets
  readonly property var colorPalette: [
    "#EF4444", "#F97316", "#EAB308", "#22C55E",
    "#06B6D4", "#3B82F6", "#8B5CF6", "#EC4899",
    "#FFFFFF", "#111827"
  ]

  // Stroke width presets
  readonly property var strokeSizes: [
    { label: "2px", val: 2 },
    { label: "4px", val: 4 },
    { label: "8px", val: 8 },
    { label: "14px", val: 14 }
  ]

  // Stamp presets
  readonly property var stampOptions: [
    { id: "number", label: "①", name: "Counter (1, 2, 3...)" },
    { id: "check", label: "✓", name: "Checkmark" },
    { id: "cross", label: "✕", name: "Cross" },
    { id: "star", label: "★", name: "Star" },
    { id: "warn", label: "⚠", name: "Warning" },
    { id: "bug", label: "🪲", name: "Bug" },
    { id: "fire", label: "🔥", name: "Fire" }
  ]

  // Lifecycle
  function open(path) {
    root.imagePath = path || ""
    root.originalImagePath = path || ""
    root.actions = []
    root.undoStack = []
    root.redoStack = []
    root.imageHistory = []
    root.imageRedoStack = []
    root.cropRect = null
    root.cropStartPt = null
    root.currentAction = null
    root.isDrawing = false
    root.textInputActive = false
    root.stampCounter = 1
    root.cropRatio = "free"
    root.textBox = false
    root.selectedActionIndex = -1
    root.currentTool = "select"
    root.zoomScale = 1.0
    root.actionFeedback = ""
    root.visible = true
    root.forceActiveFocus()
    Qt.callLater(function() {
      root.fitZoom()
    })
  }

  function close() {
    root.visible = false
    root.closed()
  }

  // Zoom Helpers
  function zoomIn() {
    root.zoomScale = Math.min(6.0, root.zoomScale * 1.25)
    annotationCanvas.requestPaint()
  }

  function zoomOut() {
    root.zoomScale = Math.max(0.15, root.zoomScale / 1.25)
    annotationCanvas.requestPaint()
  }

  function resetZoom() {
    root.zoomScale = 1.0
    annotationCanvas.requestPaint()
  }

  function fitZoom() {
    if (baseImage.implicitWidth > 0 && baseImage.implicitHeight > 0 && canvasFlickable.width > 0 && canvasFlickable.height > 0) {
      var wRatio = (canvasFlickable.width - 24) / baseImage.implicitWidth
      var hRatio = (canvasFlickable.height - 24) / baseImage.implicitHeight
      root.zoomScale = Math.max(0.15, Math.min(1.0, Math.min(wRatio, hRatio)))
    } else {
      root.zoomScale = 1.0
    }
    annotationCanvas.requestPaint()
  }

  // History operations
  function pushUndoState() {
    var hist = root.undoStack.slice()
    hist.push(JSON.parse(JSON.stringify(root.actions)))
    if (hist.length > 50) hist.shift()
    root.undoStack = hist
    root.redoStack = []
  }

  function pushSpecificUndoState(preActionSnapshot, index) {
    var preActions = root.actions.slice()
    if (index >= 0 && index < preActions.length) {
      preActions[index] = preActionSnapshot
    }
    var hist = root.undoStack.slice()
    hist.push(JSON.parse(JSON.stringify(preActions)))
    if (hist.length > 50) hist.shift()
    root.undoStack = hist
    root.redoStack = []
  }

  function undo() {
    if (root.undoStack.length > 0) {
      var nextRedo = root.redoStack.slice()
      nextRedo.push(JSON.parse(JSON.stringify(root.actions)))
      root.redoStack = nextRedo

      var hist = root.undoStack.slice()
      var prevState = hist.pop()
      root.undoStack = hist
      root.actions = prevState
      root.selectedActionIndex = -1
      annotationCanvas.requestPaint()
      root.showFeedback("↺ Undo")
    } else if (root.actions.length > 0) {
      var nextActions = root.actions.slice()
      var popped = nextActions.pop()
      if (popped && popped.tool === "stamp" && popped.stampType === "number" && root.stampCounter > 1) {
        root.stampCounter--
      }
      var nextR = root.redoStack.slice()
      nextR.push([popped])
      root.actions = nextActions
      root.redoStack = nextR
      root.selectedActionIndex = -1
      annotationCanvas.requestPaint()
      root.showFeedback("↺ Undo")
    } else if (root.imageHistory && root.imageHistory.length > 0) {
      var hist = root.imageHistory.slice()
      var prev = hist.pop()
      var rHist = root.imageRedoStack ? root.imageRedoStack.slice() : []
      rHist.push({
        imagePath: root.imagePath,
        actions: root.actions.slice()
      })
      root.imageRedoStack = rHist
      root.imageHistory = hist
      root.imagePath = prev.imagePath
      baseImage.source = ""
      baseImage.source = "file://" + prev.imagePath + "?t=" + Date.now()
      root.actions = prev.actions ? prev.actions.slice() : []
      root.undoStack = []
      root.redoStack = []
      root.selectedActionIndex = -1
      root.cropRect = null
      root.fitZoom()
      root.showFeedback("↺ Undo transform")
    }
  }

  function redo() {
    if (root.redoStack.length > 0) {
      var nextRedo = root.redoStack.slice()
      var nxtState = nextRedo.pop()
      root.redoStack = nextRedo

      var hist = root.undoStack.slice()
      hist.push(JSON.parse(JSON.stringify(root.actions)))
      root.undoStack = hist

      if (Array.isArray(nxtState)) {
        root.actions = nxtState
      } else {
        var nextActions = root.actions.slice()
        nextActions.push(nxtState)
        root.actions = nextActions
      }
      root.selectedActionIndex = -1
      annotationCanvas.requestPaint()
      root.showFeedback("↷ Redo")
    } else if (root.imageRedoStack && root.imageRedoStack.length > 0) {
      var rHist = root.imageRedoStack.slice()
      var nxt = rHist.pop()
      var hist = root.imageHistory.slice()
      hist.push({
        imagePath: root.imagePath,
        actions: root.actions.slice()
      })
      root.imageHistory = hist
      root.imageRedoStack = rHist
      root.imagePath = nxt.imagePath
      baseImage.source = ""
      baseImage.source = "file://" + nxt.imagePath + "?t=" + Date.now()
      root.actions = nxt.actions ? nxt.actions.slice() : []
      root.undoStack = []
      root.redoStack = []
      root.selectedActionIndex = -1
      root.cropRect = null
      root.fitZoom()
      root.showFeedback("↷ Redo transform")
    }
  }

  function clearAll() {
    if (root.actions.length === 0) return
    root.pushUndoState()
    root.selectedActionIndex = -1
    root.actions = []
    annotationCanvas.requestPaint()
  }

  function revertToOriginal() {
    if (root.originalImagePath) {
      root.imagePath = root.originalImagePath
      baseImage.source = ""
      baseImage.source = "file://" + root.originalImagePath + "?t=" + Date.now()
    }
    root.actions = []
    root.undoStack = []
    root.redoStack = []
    root.imageHistory = []
    root.imageRedoStack = []
    root.selectedActionIndex = -1
    root.cropRect = null
    annotationCanvas.requestPaint()
    root.fitZoom()
    root.showFeedback("↺ Reverted to original")
  }

  // ==========================================
  // SELECTION & TRANSFORM HELPERS
  // ==========================================
  function getActionLabel(act) {
    if (!act) return ""
    var map = {
      "pen": "✏ Pen",
      "highlighter": "🖍 Highlighter",
      "arrow": "↗ Arrow",
      "rect": "□ Rectangle",
      "circle": "○ Circle",
      "line": "— Line",
      "blur": "▒ Blur",
      "block_highlight": "█ Highlight",
      "pixelate": "░ Pixelate",
      "text": "🔤 Text",
      "stamp": "① Stamp"
    }
    return map[act.tool] || act.tool
  }

  function getActionBounds(act) {
    if (!act) return { x: 0, y: 0, width: 0, height: 0 }
    if (act.start && act.end) {
      var minX = Math.min(act.start.x, act.end.x)
      var minY = Math.min(act.start.y, act.end.y)
      var maxX = Math.max(act.start.x, act.end.x)
      var maxY = Math.max(act.start.y, act.end.y)
      if (act.tool === "line" || act.tool === "arrow") {
        var pad = Math.max(8, (act.width || 4) * 2)
        return {
          x: minX - pad,
          y: minY - pad,
          width: Math.max(16, maxX - minX + pad * 2),
          height: Math.max(16, maxY - minY + pad * 2)
        }
      }
      return {
        x: minX,
        y: minY,
        width: Math.max(10, maxX - minX),
        height: Math.max(10, maxY - minY)
      }
    } else if (act.tool === "text" && act.pos) {
      var fs = act.size || 18
      var padX = act.box ? Math.round(fs * 0.45) : 4
      var padY = act.box ? Math.round(fs * 0.25) : 2
      var txtLen = act.text ? act.text.length : 1
      var estWidth = Math.max(30, txtLen * (fs * 0.65) + padX * 2)
      var estHeight = fs * 1.35 + padY * 2
      return {
        x: act.pos.x - padX,
        y: act.pos.y - padY,
        width: estWidth,
        height: estHeight
      }
    } else if (act.tool === "stamp" && act.pos) {
      var sr = Math.max(14, (act.width || 4) * 3)
      return {
        x: act.pos.x - sr,
        y: act.pos.y - sr,
        width: sr * 2,
        height: sr * 2
      }
    } else if (act.points && act.points.length > 0) {
      var pMinX = act.points[0].x
      var pMaxX = act.points[0].x
      var pMinY = act.points[0].y
      var pMaxY = act.points[0].y
      for (var i = 1; i < act.points.length; i++) {
        pMinX = Math.min(pMinX, act.points[i].x)
        pMaxX = Math.max(pMaxX, act.points[i].x)
        pMinY = Math.min(pMinY, act.points[i].y)
        pMaxY = Math.max(pMaxY, act.points[i].y)
      }
      var sw = (act.width || 4) * (act.tool === "highlighter" ? 3 : 1)
      return {
        x: pMinX - sw / 2,
        y: pMinY - sw / 2,
        width: Math.max(12, pMaxX - pMinX + sw),
        height: Math.max(12, pMaxY - pMinY + sw)
      }
    }
    return { x: 0, y: 0, width: 0, height: 0 }
  }

  function findActionAt(pt) {
    if (!root.actions || root.actions.length === 0) return -1
    for (var i = root.actions.length - 1; i >= 0; i--) {
      var act = root.actions[i]
      if (!act) continue

      if (act.tool === "text" && act.pos) {
        var tb = root.getActionBounds(act)
        if (pt.x >= tb.x - 4 && pt.x <= tb.x + tb.width + 4 && pt.y >= tb.y - 4 && pt.y <= tb.y + tb.height + 4) {
          return i
        }
      } else if (act.tool === "stamp" && act.pos) {
        var sr = Math.max(14, (act.width || 4) * 3) + 6
        if (Math.hypot(act.pos.x - pt.x, act.pos.y - pt.y) <= sr) {
          return i
        }
      } else if ((act.tool === "line" || act.tool === "arrow") && act.start && act.end) {
        var l2 = Math.pow(act.end.x - act.start.x, 2) + Math.pow(act.end.y - act.start.y, 2)
        if (l2 === 0) {
          if (Math.hypot(act.start.x - pt.x, act.start.y - pt.y) <= 16) return i
        } else {
          var t = Math.max(0, Math.min(1, ((pt.x - act.start.x) * (act.end.x - act.start.x) + (pt.y - act.start.y) * (act.end.y - act.start.y)) / l2))
          var projX = act.start.x + t * (act.end.x - act.start.x)
          var projY = act.start.y + t * (act.end.y - act.start.y)
          if (Math.hypot(pt.x - projX, pt.y - projY) <= Math.max(12, (act.width || 4) + 6)) return i
        }
      } else if (act.start && act.end) {
        var bb = root.getActionBounds(act)
        var isSolid = act.filled || act.tool === "blur" || act.tool === "pixelate" || act.tool === "block_highlight"
        if (isSolid) {
          if (pt.x >= bb.x - 4 && pt.x <= bb.x + bb.width + 4 && pt.y >= bb.y - 4 && pt.y <= bb.y + bb.height + 4) {
            return i
          }
        } else {
          if (pt.x >= bb.x - 10 && pt.x <= bb.x + bb.width + 10 && pt.y >= bb.y - 10 && pt.y <= bb.y + bb.height + 10) {
            if (bb.width <= 30 || bb.height <= 30) return i
            var dL = Math.abs(pt.x - bb.x)
            var dR = Math.abs(pt.x - (bb.x + bb.width))
            var dT = Math.abs(pt.y - bb.y)
            var dB = Math.abs(pt.y - (bb.y + bb.height))
            var minD = Math.min(Math.min(dL, dR), Math.min(dT, dB))
            if (minD <= 12) return i
          }
        }
      } else if (act.points && act.points.length > 0) {
        var thresh = Math.max(12, (act.width || 4) * (act.tool === "highlighter" ? 2 : 1) + 4)
        for (var p = 0; p < act.points.length; p++) {
          if (Math.hypot(act.points[p].x - pt.x, act.points[p].y - pt.y) <= thresh) {
            return i
          }
        }
      }
    }
    return -1
  }

  function selectAction(index) {
    if (index >= 0 && index < root.actions.length) {
      root.selectedActionIndex = index
      var act = root.actions[index]
      if (act.color) root.currentColor = act.color
      if (act.width) root.strokeWidth = act.width
      if (act.size && act.tool === "text") {
        if (act.size <= 16) root.strokeWidth = 2
        else if (act.size <= 22) root.strokeWidth = 4
        else if (act.size <= 32) root.strokeWidth = 8
        else root.strokeWidth = 14
      }
      if (typeof act.box !== "undefined") root.textBox = Boolean(act.box)
    } else {
      root.selectedActionIndex = -1
    }
    annotationCanvas.requestPaint()
  }

  function deleteSelectedAction() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    root.pushUndoState()
    var next = root.actions.slice()
    next.splice(root.selectedActionIndex, 1)
    root.selectedActionIndex = -1
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("🗑 Deleted element")
  }

  function duplicateSelectedAction() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    root.pushUndoState()
    var act = root.actions[root.selectedActionIndex]
    var cloned = root.moveAction(act, 20, 20)
    var next = root.actions.slice()
    next.push(cloned)
    root.actions = next
    root.selectedActionIndex = next.length - 1
    annotationCanvas.requestPaint()
    root.showFeedback("⧉ Duplicated element")
  }

  function bringSelectedToFront() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length - 1) return
    root.pushUndoState()
    var next = root.actions.slice()
    var act = next.splice(root.selectedActionIndex, 1)[0]
    next.push(act)
    root.actions = next
    root.selectedActionIndex = next.length - 1
    annotationCanvas.requestPaint()
    root.showFeedback("▲ Brought to front")
  }

  function sendSelectedToBack() {
    if (root.selectedActionIndex <= 0 || root.selectedActionIndex >= root.actions.length) return
    root.pushUndoState()
    var next = root.actions.slice()
    var act = next.splice(root.selectedActionIndex, 1)[0]
    next.unshift(act)
    root.actions = next
    root.selectedActionIndex = 0
    annotationCanvas.requestPaint()
    root.showFeedback("▼ Sent to back")
  }

  function nudgeSelected(dx, dy) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    root.pushUndoState()
    var act = root.actions[root.selectedActionIndex]
    var next = root.actions.slice()
    next[root.selectedActionIndex] = root.moveAction(act, dx, dy)
    root.actions = next
    annotationCanvas.requestPaint()
  }

  function moveAction(act, dx, dy) {
    var res = JSON.parse(JSON.stringify(act))
    if (res.start && res.end) {
      res.start.x += dx
      res.start.y += dy
      res.end.x += dx
      res.end.y += dy
    }
    if (res.pos) {
      res.pos.x += dx
      res.pos.y += dy
    }
    if (res.points && res.points.length > 0) {
      for (var i = 0; i < res.points.length; i++) {
        res.points[i].x += dx
        res.points[i].y += dy
      }
    }
    return res
  }

  function computeNewBounds(startBounds, handle, dx, dy) {
    var minW = 10, minH = 10
    var nx = startBounds.x
    var ny = startBounds.y
    var nw = startBounds.width
    var nh = startBounds.height

    if (handle === "r" || handle === "tr" || handle === "br") {
      nw = Math.max(minW, startBounds.width + dx)
    }
    if (handle === "b" || handle === "bl" || handle === "br") {
      nh = Math.max(minH, startBounds.height + dy)
    }
    if (handle === "l" || handle === "tl" || handle === "bl") {
      var proposedW = Math.max(minW, startBounds.width - dx)
      nx = startBounds.x + (startBounds.width - proposedW)
      nw = proposedW
    }
    if (handle === "t" || handle === "tl" || handle === "tr") {
      var proposedH = Math.max(minH, startBounds.height - dy)
      ny = startBounds.y + (startBounds.height - proposedH)
      nh = proposedH
    }

    return { x: nx, y: ny, width: nw, height: nh }
  }

  function scaleAction(origAct, startBounds, newBounds) {
    var res = JSON.parse(JSON.stringify(origAct))
    var scaleX = startBounds.width > 0 ? (newBounds.width / startBounds.width) : 1
    var scaleY = startBounds.height > 0 ? (newBounds.height / startBounds.height) : 1

    if (res.start && res.end) {
      if (res.tool === "line" || res.tool === "arrow") {
        res.start.x = newBounds.x + (origAct.start.x - startBounds.x) * scaleX
        res.start.y = newBounds.y + (origAct.start.y - startBounds.y) * scaleY
        res.end.x = newBounds.x + (origAct.end.x - startBounds.x) * scaleX
        res.end.y = newBounds.y + (origAct.end.y - startBounds.y) * scaleY
      } else {
        var flipX = origAct.start.x > origAct.end.x
        var flipY = origAct.start.y > origAct.end.y
        var sx = flipX ? (newBounds.x + newBounds.width) : newBounds.x
        var ex = flipX ? newBounds.x : (newBounds.x + newBounds.width)
        var sy = flipY ? (newBounds.y + newBounds.height) : newBounds.y
        var ey = flipY ? newBounds.y : (newBounds.y + newBounds.height)
        res.start = { x: sx, y: sy }
        res.end = { x: ex, y: ey }
      }
    }

    if (res.tool === "text" && res.pos) {
      var avgScale = (scaleX + scaleY) / 2
      var origSize = origAct.size || 18
      res.size = Math.max(10, Math.min(120, Math.round(origSize * avgScale)))
      var padX = res.box ? Math.round(res.size * 0.45) : 4
      var padY = res.box ? Math.round(res.size * 0.25) : 2
      res.pos = { x: newBounds.x + padX, y: newBounds.y + padY }
    }

    if (res.tool === "stamp" && res.pos) {
      var avgScaleS = (scaleX + scaleY) / 2
      var origW = origAct.width || 4
      res.width = Math.max(1, Math.min(30, Math.round(origW * avgScaleS)))
      res.pos = { x: newBounds.x + newBounds.width / 2, y: newBounds.y + newBounds.height / 2 }
    }

    if (res.points && res.points.length > 0) {
      for (var p = 0; p < res.points.length; p++) {
        res.points[p].x = newBounds.x + (origAct.points[p].x - startBounds.x) * scaleX
        res.points[p].y = newBounds.y + (origAct.points[p].y - startBounds.y) * scaleY
      }
    }

    return res
  }

  function initCropRect() {
    var imgW = (baseImage.implicitWidth > 0 ? baseImage.implicitWidth : 800)
    var imgH = (baseImage.implicitHeight > 0 ? baseImage.implicitHeight : 600)
    var cw = Math.round(imgW * 0.8)
    var ch = Math.round(imgH * 0.8)
    if (root.cropRatio !== "free") {
      var targetRatio = 1.0
      for (var i = 0; i < root.cropRatios.length; i++) {
        if (root.cropRatios[i].id === root.cropRatio) {
          targetRatio = root.cropRatios[i].ratio
          break
        }
      }
      if (targetRatio > 0) {
        ch = Math.round(cw / targetRatio)
        if (ch > imgH) {
          ch = imgH
          cw = Math.round(ch * targetRatio)
        }
      }
    }
    var cx = Math.round((imgW - cw) / 2)
    var cy = Math.round((imgH - ch) / 2)
    root.cropRect = { x: cx, y: cy, width: cw, height: ch }
  }

  function applyCrop() {
    if (!root.cropRect || root.cropRect.width < 10 || root.cropRect.height < 10) return
    var cx = Math.max(0, Math.round(root.cropRect.x))
    var cy = Math.max(0, Math.round(root.cropRect.y))
    var cw = Math.min(baseImage.implicitWidth - cx, Math.round(root.cropRect.width))
    var ch = Math.min(baseImage.implicitHeight - cy, Math.round(root.cropRect.height))
    root.cropRect = null
    root.currentTool = "pan"
    if (cw > 10 && ch > 10) {
      root.applyImageTransform("-crop " + cw + "x" + ch + "+" + cx + "+" + cy + " +repage", "✂ Cropped to " + cw + "×" + ch + "px")
    }
  }

  function applyImageTransform(magickArgs, label) {
    if (!root.imagePath) return
    if (transformProc.running) return
    var homeDir = Quickshell.env("HOME")
    var stateDir = homeDir + "/.local/state/reclip"
    var timeStr = Date.now()
    var targetFile = stateDir + "/transform_" + timeStr + ".png"

    var hist = root.imageHistory.slice()
    hist.push({
      imagePath: root.imagePath,
      actions: root.actions.slice()
    })
    root.imageHistory = hist
    root.imageRedoStack = []

    var runTransformOn = function(inputFile) {
      transformProc.targetPath = targetFile
      transformProc.feedbackLabel = label
      var cmd = "magick " + Util.shellQuote(inputFile) + " " + magickArgs + " " + Util.shellQuote(targetFile)
      transformProc.command = ["sh", "-c", cmd]
      transformProc.running = true
    }

    if (root.actions.length > 0) {
      root.isExporting = true
      var prevZoom = root.zoomScale
      root.zoomScale = 1.0
      annotationCanvas.requestPaint()
      Qt.callLater(function() {
        compositeContainer.grabToImage(function(result) {
          root.isExporting = false
          root.zoomScale = prevZoom
          annotationCanvas.requestPaint()
          if (!result) return
          var bakeFile = stateDir + "/bake_" + timeStr + ".png"
          result.saveToFile(bakeFile)
          runTransformOn(bakeFile)
        })
      })
    } else {
      runTransformOn(root.imagePath)
    }
  }

  function commitText() {
    if (!root.textInputActive) return
    var str = root.textInputDraft.trim()
    if (str.length > 0) {
      root.pushUndoState()
      var act = {
        tool: "text",
        text: str,
        color: String(root.currentColor),
        size: Math.max(14, root.strokeWidth * 4),
        box: Boolean(root.textBox),
        pos: { x: root.textInputPos.x, y: root.textInputPos.y }
      }
      var next = root.actions.slice()
      next.push(act)
      root.actions = next
      root.selectedActionIndex = next.length - 1
      annotationCanvas.requestPaint()
    }
    root.textInputActive = false
    root.textInputDraft = ""
  }

  function exportImage(saveMode) {
    // saveMode: "clipboard", "file", "history"
    var homeDir = Quickshell.env("HOME")
    var outDir = homeDir + "/.local/state/reclip"
    var timeStr = new Date().toISOString().replace(/[:.]/g, "-")
    var targetFile = outDir + "/annotated_" + timeStr + ".png"

    if (saveMode === "file") {
      targetFile = homeDir + "/Pictures/Screenshots/reclip_annotated_" + timeStr + ".png"
    }

    root.isExporting = true
    var prevZoom = root.zoomScale
    root.zoomScale = 1.0
    annotationCanvas.requestPaint()

    Qt.callLater(function() {
      compositeContainer.grabToImage(function(result) {
        root.isExporting = false
        root.zoomScale = prevZoom
        annotationCanvas.requestPaint()

        if (!result) return
        result.saveToFile(targetFile)

        if (saveMode === "clipboard" || saveMode === "history") {
          Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < " + Util.shellQuote(targetFile) + " && notify-send -a \"ReClip\" \"Annotated Image Copied\" \"Loaded to clipboard\""])
          root.savedToClipboard(targetFile)
          root.showFeedback("✓ Copied & saved to clips!")
        } else if (saveMode === "file") {
          Quickshell.execDetached(["notify-send", "-a", "ReClip", "Annotated Image Saved", "Saved to " + targetFile])
          root.showFeedback("✓ Saved to Screenshots!")
        }
      })
    })
  }

  // Keyboard Shortcuts
  focus: root.visible
  Keys.onPressed: function(event) {
    if (root.textInputActive) {
      if (event.key === Qt.Key_Escape) {
        root.textInputActive = false
        event.accepted = true
      }
      return
    }

    if (root.currentTool === "crop") {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.applyCrop()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Escape) {
        root.cropRect = null
        root.currentTool = "pan"
        event.accepted = true
        return
      }
    }

    // Selection-specific shortcuts
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      if (event.key === Qt.Key_Escape) {
        root.selectedActionIndex = -1
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
        root.deleteSelectedAction()
        event.accepted = true
        return
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
        root.duplicateSelectedAction()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_BracketRight) {
        root.bringSelectedToFront()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_BracketLeft) {
        root.sendSelectedToBack()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Left) {
        root.nudgeSelected((event.modifiers & Qt.ShiftModifier) ? -10 : -1, 0)
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Right) {
        root.nudgeSelected((event.modifiers & Qt.ShiftModifier) ? 10 : 1, 0)
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Up) {
        root.nudgeSelected(0, (event.modifiers & Qt.ShiftModifier) ? -10 : -1)
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Down) {
        root.nudgeSelected(0, (event.modifiers & Qt.ShiftModifier) ? 10 : 1)
        event.accepted = true
        return
      }
    }

    if (event.key === Qt.Key_Escape) {
      root.close()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
      root.undo()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Y || ((event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Z))) {
      root.redo()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
      root.exportImage("file")
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_C || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      root.exportImage("clipboard")
      event.accepted = true
    } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
      root.zoomIn()
      event.accepted = true
    } else if (event.key === Qt.Key_Minus) {
      root.zoomOut()
      event.accepted = true
    } else if (event.key === Qt.Key_0) {
      root.fitZoom()
      event.accepted = true
    } else if (event.key === Qt.Key_1) {
      root.resetZoom()
      event.accepted = true
    } else if (event.key === Qt.Key_V) {
      root.currentTool = "select"
      event.accepted = true
    } else if (event.key === Qt.Key_Space) {
      root.currentTool = "pan"
      event.accepted = true
    } else if (event.key === Qt.Key_P) {
      root.currentTool = "pen"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_H) {
      root.currentTool = "highlighter"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_A) {
      root.currentTool = "arrow"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_R) {
      root.currentTool = "rect"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_C) {
      root.currentTool = "circle"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_L) {
      root.currentTool = "line"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_B) {
      root.currentTool = "blur"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_T) {
      root.currentTool = "text"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_S) {
      root.currentTool = "stamp"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_E) {
      root.currentTool = "eraser"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_X) {
      if (root.currentTool === "crop") {
        root.currentTool = "select"
        root.cropRect = null
      } else {
        root.currentTool = "crop"
        root.selectedActionIndex = -1
        if (!root.cropRect) root.initCropRect()
      }
      event.accepted = true
    } else if (event.key === Qt.Key_M) {
      root.currentTool = "pixelate"
      root.selectedActionIndex = -1
      event.accepted = true
    } else if (event.key === Qt.Key_K) {
      root.currentTool = "block_highlight"
      root.selectedActionIndex = -1
      event.accepted = true
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ==========================================
    // TOP HEADER: TITLE, ZOOM CONTROLS, ACTIONS
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(42)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(6)

        // Title icon + label
        Row {
          spacing: Style.space(6)
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            width: Style.space(26); height: Style.space(26); radius: Style.space(5)
            color: Util.alpha(Color.accent, 0.2)
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: "󰏫"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              anchors.centerIn: parent
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
              text: root.imagePath ? root.imagePath.split("/").pop() : "Image Studio"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9)
              font.bold: true
              elide: Text.ElideMiddle
              width: Math.min(implicitWidth, Style.space(90))
            }
            Text {
              text: baseImage.implicitWidth > 0 ? (baseImage.implicitWidth + "×" + baseImage.implicitHeight) : "Studio"
              color: Util.alpha(Color.popups.text || Color.text, 0.5)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(7.5)
            }
          }
        }

        // Separator
        Rectangle { width: 1; height: Style.space(18); color: Util.alpha(Color.popups.text || Color.text, 0.12) }

        // Zoom Controls
        Row {
          spacing: Style.space(2)
          Layout.alignment: Qt.AlignVCenter

          // Zoom Out (-)
          Rectangle {
            width: Style.space(22); height: Style.space(22); radius: Style.space(4)
            color: zoomOutMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.08)
            Text { text: "−"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: zoomOutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.zoomOut() }
            PanelToolTip { visible: zoomOutMouse.containsMouse; text: "Zoom out (-)" }
          }

          // Zoom Level Indicator / Reset
          Rectangle {
            height: Style.space(22); width: Style.space(38); radius: Style.space(4)
            color: zoomResetMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
            Text {
              text: Math.round(root.zoomScale * 100) + "%"
              color: Color.popups.text || Color.text
              font.family: "monospace"
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.centerIn: parent
            }
            MouseArea { id: zoomResetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetZoom() }
            PanelToolTip { visible: zoomResetMouse.containsMouse; text: "Reset zoom (1)" }
          }

          // Zoom In (+)
          Rectangle {
            width: Style.space(22); height: Style.space(22); radius: Style.space(4)
            color: zoomInMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.08)
            Text { text: "+"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: zoomInMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.zoomIn() }
            PanelToolTip { visible: zoomInMouse.containsMouse; text: "Zoom in (+)" }
          }

          // Fit to Window
          Rectangle {
            height: Style.space(22); width: Style.space(26); radius: Style.space(4)
            color: fitMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.08)
            Text {
              text: "Fit"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.centerIn: parent
            }
            MouseArea { id: fitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.fitZoom() }
            PanelToolTip { visible: fitMouse.containsMouse; text: "Fit image to window (0)" }
          }
        }

        Item { Layout.fillWidth: true }

        // External System Editor (Tensaku)
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: tensakuMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
          border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
          Text { text: "󰏫"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(10); anchors.centerIn: parent }
          MouseArea {
            id: tensakuMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.imagePath) {
                Quickshell.execDetached(["tensaku-edit", root.imagePath])
                root.showFeedback("󰏫 Opened in Tensaku!")
              }
            }
          }
          PanelToolTip { visible: tensakuMouse.containsMouse; text: "Open in Tensaku editor" }
        }

        // OCR Action Button
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: ocrMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
          border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
          Text { text: "󰐳"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(10); anchors.centerIn: parent }
          MouseArea {
            id: ocrMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.imagePath) {
                root.runOcr(root.imagePath)
                root.showFeedback("󰐳 Text extracted to clipboard!")
              }
            }
          }
          PanelToolTip { visible: ocrMouse.containsMouse; text: "Extract text (OCR)" }
        }

        // Separator
        Rectangle { width: 1; height: Style.space(18); color: Util.alpha(Color.popups.text || Color.text, 0.12) }

        // Undo
        Rectangle {
          id: undoBtn
          readonly property bool canUndo: root.actions.length > 0 || root.undoStack.length > 0 || (root.imageHistory && root.imageHistory.length > 0)
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: canUndo ? (undoMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: canUndo ? 1.0 : 0.4
          Text { text: "󰕌"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); anchors.centerIn: parent }
          MouseArea {
            id: undoMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: undoBtn.canUndo ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (undoBtn.canUndo) root.undo()
            }
          }
          PanelToolTip { visible: undoMouse.containsMouse; text: "Undo (Ctrl+Z)" }
        }

        // Redo
        Rectangle {
          id: redoBtn
          readonly property bool canRedo: root.redoStack.length > 0 || (root.imageRedoStack && root.imageRedoStack.length > 0)
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: canRedo ? (redoMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: canRedo ? 1.0 : 0.4
          Text { text: "󰑎"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); anchors.centerIn: parent }
          MouseArea {
            id: redoMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: redoBtn.canRedo ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (redoBtn.canRedo) root.redo()
            }
          }
          PanelToolTip { visible: redoMouse.containsMouse; text: "Redo (Ctrl+Y)" }
        }

        // Clear Canvas
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: clearMouse.containsMouse ? Util.alpha(Color.urgent, 0.22) : Util.alpha(Color.urgent, 0.12)
          Text { text: "󰃢"; color: Color.urgent; font.pixelSize: Style.space(10); anchors.centerIn: parent }
          MouseArea {
            id: clearMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
          }
          PanelToolTip { visible: clearMouse.containsMouse; text: "Clear all annotations" }
        }

        // Revert to Original
        Rectangle {
          id: revertBtn
          readonly property bool hasChanges: root.actions.length > 0 || (root.imageHistory && root.imageHistory.length > 0) || (root.originalImagePath !== "" && root.imagePath !== root.originalImagePath)
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: hasChanges ? (revertMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: hasChanges ? 1.0 : 0.4
          Text { text: "↺"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); font.bold: true; anchors.centerIn: parent }
          MouseArea {
            id: revertMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: revertBtn.hasChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (revertBtn.hasChanges) root.revertToOriginal()
            }
          }
          PanelToolTip { visible: revertMouse.containsMouse; text: "Revert all changes to original file" }
        }

        // Separator
        Rectangle { width: 1; height: Style.space(18); color: Util.alpha(Color.popups.text || Color.text, 0.12) }

        // Header Close Button
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: closeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)
          Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
          MouseArea {
            id: closeMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
          PanelToolTip { visible: closeMouse.containsMouse; text: "Close (Esc)" }
        }
      }
    }

    // ==========================================
    // TOOLBAR ROW 2: DRAWING TOOLS & OPTIONS
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(34)
      color: Util.alpha(Color.popups.background || Color.background, 0.94)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

      Flickable {
        anchors.fill: parent
        contentWidth: Math.max(width, toolsRowContent.width + Style.space(20))
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Row {
          id: toolsRowContent
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          spacing: Style.space(3)

          // 1. Tool Buttons
          Repeater {
            model: [
              { id: "select", label: "↖", name: "Select / Transform (V)" },
              { id: "pan", label: "✋", name: "Pan / Hand (Space)" },
              { id: "pen", label: "✏", name: "Pen (P)" },
              { id: "highlighter", label: "🖍", name: "Highlighter (H)" },
              { id: "arrow", label: "↗", name: "Arrow (A)" },
              { id: "rect", label: "□", name: "Rectangle (R)" },
              { id: "circle", label: "○", name: "Circle (C)" },
              { id: "line", label: "—", name: "Line (L)" },
              { id: "blur", label: "▒", name: "Blur / Redact (B)" },
              { id: "text", label: "🔤", name: "Text (T)" },
              { id: "stamp", label: "①", name: "Stamp (S)" },
              { id: "eraser", label: "⌫", name: "Eraser (E)" }
            ]

            Rectangle {
              required property var modelData
              width: Style.space(24); height: Style.space(24); radius: Style.space(4)
              color: root.currentTool === modelData.id ? Color.accent : (tMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
              border.width: 1
              border.color: root.currentTool === modelData.id ? Color.accent : "transparent"

              Text {
                text: parent.modelData.label
                color: root.currentTool === parent.modelData.id ? "#FFFFFF" : (Color.popups.text || Color.text)
                font.pixelSize: Style.space(9.5)
                font.bold: true
                anchors.centerIn: parent
              }

              MouseArea {
                id: tMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentTool = parent.modelData.id
                  if (root.textInputActive) root.commitText()
                  if (parent.modelData.id !== "select" && parent.modelData.id !== "pan") {
                    root.selectedActionIndex = -1
                  }
                }
              }
              PanelToolTip { visible: tMouse.containsMouse; text: parent.modelData.name }
            }
          }

          // Separator when contextual options are active
          Rectangle {
            visible: root.currentTool === "rect" || root.currentTool === "circle" || root.currentTool === "stamp"
            width: 1; height: Style.space(16); color: Util.alpha(Color.popups.text || Color.text, 0.15)
            anchors.verticalCenter: parent.verticalCenter
          }

          // Fill toggle (for rect / circle)
          Rectangle {
            visible: root.currentTool === "rect" || root.currentTool === "circle"
            width: fillBtnTxt.implicitWidth + Style.space(10); height: Style.space(24); radius: Style.space(4)
            color: root.fillShape ? Color.accent : (fillMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.06))
            border.width: 1; border.color: root.fillShape ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: fillBtnTxt
              anchors.centerIn: parent; spacing: Style.space(3)
              Text { text: "⬛"; font.pixelSize: Style.space(7); color: root.fillShape ? "#fff" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
              Text { text: root.fillShape ? "Fill" : "Outline"; color: root.fillShape ? "#fff" : (Color.popups.text || Color.text); font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: fillMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.fillShape = !root.fillShape
            }
            PanelToolTip { visible: fillMouse.containsMouse; text: root.fillShape ? "Filled shape (click for outline)" : "Outline only (click for fill)" }
          }

          // Stamp options (when stamp tool active)
          Row {
            visible: root.currentTool === "stamp"
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              model: root.stampOptions
              Rectangle {
                required property var modelData
                width: Style.space(22); height: Style.space(22); radius: Style.space(4)
                color: root.currentStamp === modelData.id ? Color.accent : (sMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.06))
                border.width: 1
                border.color: root.currentStamp === modelData.id ? Color.accent : "transparent"

                Text {
                  text: parent.modelData.label
                  color: root.currentStamp === parent.modelData.id ? "#FFFFFF" : (Color.popups.text || Color.text)
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  anchors.centerIn: parent
                }
                MouseArea {
                  id: sMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentStamp = parent.modelData.id
                }
                PanelToolTip { visible: sMouse.containsMouse; text: parent.modelData.name }
              }
            }

            // Counter indicator & reset button when number stamp is active
            Rectangle {
              visible: root.currentStamp === "number"
              width: counterResetRow.implicitWidth + Style.space(8)
              height: Style.space(22)
              radius: Style.space(4)
              color: crMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
              border.width: 1
              border.color: Util.alpha(Color.popups.text || Color.text, 0.12)

              Row {
                id: counterResetRow
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text {
                  text: "#" + root.stampCounter
                  color: Color.accent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "↺"
                  color: Color.popups.text || Color.text
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: crMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.stampCounter = 1
                  root.showFeedback("Counter reset to 1")
                }
              }
              PanelToolTip { visible: crMouse.containsMouse; text: "Reset counter to 1" }
            }
          }
        }
      }
    }

    // ==========================================
    // TOOLBAR ROW 3: STYLING (STROKE & COLOR)
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(30)
      color: Util.alpha(Color.popups.background || Color.background, 0.90)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.2)

      Flickable {
        anchors.fill: parent
        contentWidth: Math.max(width, stylingRowContent.width + Style.space(20))
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Row {
          id: stylingRowContent
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          spacing: Style.space(6)

          // Stroke / Font Size Label
          Text {
            text: root.currentTool === "text" ? "Font Size:" : "Size:"
            color: Util.alpha(Color.popups.text || Color.text, 0.6)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          // Stroke / Font size selector
          Row {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              model: root.strokeSizes
              Rectangle {
                required property var modelData
                required property int index
                width: Style.space(24); height: Style.space(20); radius: Style.space(3)
                color: root.strokeWidth === modelData.val ? Util.alpha(Color.accent, 0.3) : (szMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.05))
                border.width: 1
                border.color: root.strokeWidth === modelData.val ? Color.accent : "transparent"

                Text {
                  text: root.currentTool === "text" ? ["S", "M", "L", "XL"][parent.index] : parent.modelData.label
                  color: root.strokeWidth === parent.modelData.val ? Color.accent : (Color.popups.text || Color.text)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: szMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.strokeWidth = parent.modelData.val
                }
                PanelToolTip {
                  visible: szMouse.containsMouse
                  text: root.currentTool === "text" ? ("Text: " + ["Small (14px)", "Medium (20px)", "Large (28px)", "Extra Large (40px)"][parent.index]) : ("Stroke: " + parent.modelData.val + "px")
                }
              }
            }
          }

          // Card Box Toggle (for Text Tool)
          Rectangle {
            visible: root.currentTool === "text"
            width: badgeBtnRow.implicitWidth + Style.space(8)
            height: Style.space(20)
            radius: Style.space(3)
            color: root.textBox ? Util.alpha(Color.accent, 0.3) : (cardBoxMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.05))
            border.width: 1
            border.color: root.textBox ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: badgeBtnRow
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text { text: "■"; color: root.textBox ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.6); font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Card Box"; color: root.textBox ? Color.accent : (Color.popups.text || Color.text); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: cardBoxMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.textBox = !root.textBox
            }
            PanelToolTip { visible: cardBoxMouse.containsMouse; text: root.textBox ? "Text card background active" : "Toggle solid high-contrast card box behind text" }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(14); color: Util.alpha(Color.popups.text || Color.text, 0.12); anchors.verticalCenter: parent.verticalCenter }

          // Color Label
          Text {
            text: "Color:"
            color: Util.alpha(Color.popups.text || Color.text, 0.6)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          // Color Palette Swatches
          Row {
            spacing: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              model: root.colorPalette
              Rectangle {
                required property string modelData
                width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                color: modelData
                border.width: String(root.currentColor).toLowerCase() === String(modelData).toLowerCase() ? 2 : 1
                border.color: String(root.currentColor).toLowerCase() === String(modelData).toLowerCase() ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.2)
                scale: String(root.currentColor).toLowerCase() === String(modelData).toLowerCase() ? 1.2 : 1.0

                MouseArea {
                  id: palMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentColor = parent.modelData
                }
                PanelToolTip { visible: palMouse.containsMouse; text: modelData }
              }
            }
          }

          // Eyedropper Button (pick from screen/image)
          Rectangle {
            width: Style.space(20); height: Style.space(20); radius: Style.space(10)
            color: eyedropMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
            border.width: 1
            border.color: Util.alpha(Color.popups.text || Color.text, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "󰈊"
              color: Color.popups.text || Color.text
              font.pixelSize: Style.space(9.5)
              anchors.centerIn: parent
            }
            MouseArea {
              id: eyedropMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.requestScreenPick()
            }
            PanelToolTip { visible: eyedropMouse.containsMouse; text: "Eyedropper: pick any color from screen or image" }
          }

          // Color Studio Picker Button (opens full Color Studio modal)
          Rectangle {
            width: Style.space(20); height: Style.space(20); radius: Style.space(10)
            color: studioColorMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.06)
            border.width: 1
            border.color: Util.alpha(Color.popups.text || Color.text, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "󰏘"
              color: studioColorMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text)
              font.pixelSize: Style.space(9.5)
              anchors.centerIn: parent
            }
            MouseArea {
              id: studioColorMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.requestColorPicker()
            }
            PanelToolTip { visible: studioColorMouse.containsMouse; text: "Open Color Studio: custom palette, harmonies & shades" }
          }

          // Current Color Swatch + Interactive Hex Input
          Rectangle {
            height: Style.space(20)
            width: hexEditRow.implicitWidth + Style.space(10)
            radius: Style.space(10)
            color: Util.alpha(Color.popups.text || Color.text, 0.06)
            border.width: 1
            border.color: Util.alpha(Color.popups.text || Color.text, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: hexEditRow
              anchors.centerIn: parent
              spacing: Style.space(4)

              Rectangle {
                width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                color: root.currentColor
                border.width: 1; border.color: Util.alpha("#000000", 0.3)
                anchors.verticalCenter: parent.verticalCenter
              }

              TextInput {
                id: hexInput
                text: String(root.currentColor).toUpperCase()
                color: Color.popups.text || Color.text
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                font.bold: true
                maximumLength: 7
                selectByMouse: true
                anchors.verticalCenter: parent.verticalCenter
                onAccepted: {
                  var val = text.trim()
                  if (val.indexOf("#") !== 0) val = "#" + val
                  if (/^#[0-9A-Fa-f]{6}$/.test(val)) {
                    root.currentColor = val
                    root.showFeedback("Color set: " + val)
                  } else {
                    text = String(root.currentColor).toUpperCase()
                  }
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // TOOLBAR ROW 4: TENSAKU TOOLS & TRANSFORMS
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(32)
      color: Util.alpha(Color.popups.background || Color.background, 0.92)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

      Flickable {
        anchors.fill: parent
        contentWidth: Math.max(width, tensakuRowContent.width + Style.space(20))
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Row {
          id: tensakuRowContent
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          spacing: Style.space(6)

          // Tensaku Branding Badge
          Row {
            spacing: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: "󰏫"
              color: Color.accent
              font.pixelSize: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "Tensaku"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(14); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

          // Crop Tool Button
          Rectangle {
            width: cropBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
            color: root.currentTool === "crop" ? Color.accent : (cropMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
            border.width: 1
            border.color: root.currentTool === "crop" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: cropBtnTxt
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text { text: "✂"; font.pixelSize: Style.space(8.5); color: root.currentTool === "crop" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Crop"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: root.currentTool === "crop" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: cropMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.currentTool === "crop") {
                  root.currentTool = "pan"
                  root.cropRect = null
                } else {
                  root.currentTool = "crop"
                  if (!root.cropRect) root.initCropRect()
                }
              }
            }
            PanelToolTip { visible: cropMouse.containsMouse; text: root.currentTool === "crop" ? "Exit Crop mode" : "Select region to crop (X)" }
          }

          // Contextual Crop Actions: Apply & Cancel (shown when crop tool active)
          Row {
            visible: root.currentTool === "crop"
            spacing: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter

            // Apply Crop
            Rectangle {
              enabled: Boolean(root.cropRect && root.cropRect.width > 10 && root.cropRect.height > 10)
              opacity: enabled ? 1.0 : 0.4
              width: applyCropTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: Color.accent
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: applyCropTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "✓"; color: "#FFFFFF"; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Apply"; color: "#FFFFFF"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: applyCropMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyCrop()
              }
              PanelToolTip { visible: applyCropMouse.containsMouse; text: "Apply crop to selection (Enter)" }
            }

            // Cancel Crop
            Rectangle {
              width: cancelCropTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: cancelCropMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1
              border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: cancelCropTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Cancel"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: cancelCropMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.cropRect = null
                  root.currentTool = "pan"
                }
              }
              PanelToolTip { visible: cancelCropMouse.containsMouse; text: "Cancel crop (Esc)" }
            }
          }

          // Aspect Ratio Presets (shown when crop tool active)
          Row {
            visible: root.currentTool === "crop"
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: root.cropRatios
              Rectangle {
                required property var modelData
                width: ratioTxt.implicitWidth + Style.space(8); height: Style.space(22); radius: Style.space(4)
                color: root.cropRatio === modelData.id ? Color.accent : (ratioMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
                border.width: 1
                border.color: root.cropRatio === modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  id: ratioTxt
                  anchors.centerIn: parent
                  text: parent.modelData.label
                  color: root.cropRatio === parent.modelData.id ? "#FFFFFF" : (Color.popups.text || Color.text)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                }
                MouseArea {
                  id: ratioMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.setCropRatio(parent.modelData.id)
                }
                PanelToolTip { visible: ratioMouse.containsMouse; text: "Lock aspect ratio: " + parent.modelData.label }
              }
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(14); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

          // Transform Tools (Rotate & Flip)
          Row {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            // Rotate CCW (90° Left)
            Rectangle {
              width: Style.space(24); height: Style.space(22); radius: Style.space(4)
              color: rotLMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              Text { text: "↶"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(10); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: rotLMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyImageTransform("-rotate 270", "↶ Rotated 90° Left")
              }
              PanelToolTip { visible: rotLMouse.containsMouse; text: "Rotate 90° counter-clockwise" }
            }

            // Rotate CW (90° Right)
            Rectangle {
              width: Style.space(24); height: Style.space(22); radius: Style.space(4)
              color: rotRMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              Text { text: "↷"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(10); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: rotRMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyImageTransform("-rotate 90", "↷ Rotated 90° Right")
              }
              PanelToolTip { visible: rotRMouse.containsMouse; text: "Rotate 90° clockwise" }
            }

            // Flip Horizontal
            Rectangle {
              width: Style.space(24); height: Style.space(22); radius: Style.space(4)
              color: flipHMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              Text { text: "⇄"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(10); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: flipHMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyImageTransform("-flop", "⇄ Flipped horizontally")
              }
              PanelToolTip { visible: flipHMouse.containsMouse; text: "Flip horizontally (mirror left-right)" }
            }

            // Flip Vertical
            Rectangle {
              width: Style.space(24); height: Style.space(22); radius: Style.space(4)
              color: flipVMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              Text { text: "⇅"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(10); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: flipVMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyImageTransform("-flip", "⇅ Flipped vertically")
              }
              PanelToolTip { visible: flipVMouse.containsMouse; text: "Flip vertically (mirror top-bottom)" }
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(14); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

          // Tensaku Annotation Modes: Block Highlight & Pixelate
          Row {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            // Block Highlight
            Rectangle {
              width: bhlBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: root.currentTool === "block_highlight" ? Color.accent : (bhlMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
              border.width: 1; border.color: root.currentTool === "block_highlight" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: bhlBtnTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "█"; font.pixelSize: Style.space(7.5); color: root.currentTool === "block_highlight" ? "#FFFFFF" : Color.accent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Block Highlight"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: root.currentTool === "block_highlight" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: bhlMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentTool = "block_highlight"
                  if (root.textInputActive) root.commitText()
                }
              }
              PanelToolTip { visible: bhlMouse.containsMouse; text: "Tensaku block highlight: rectangular text highlight" }
            }

            // Pixelate / Mosaic
            Rectangle {
              width: pixBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: root.currentTool === "pixelate" ? Color.accent : (pixMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
              border.width: 1; border.color: root.currentTool === "pixelate" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: pixBtnTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "▒"; font.pixelSize: Style.space(8.5); color: root.currentTool === "pixelate" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Pixelate"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: root.currentTool === "pixelate" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: pixMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentTool = "pixelate"
                  if (root.textInputActive) root.commitText()
                }
              }
              PanelToolTip { visible: pixMouse.containsMouse; text: "Tensaku mosaic pixelation privacy redact" }
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(14); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

          // Filters / Image adjustments
          Row {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            // Invert
            Rectangle {
              width: invBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: invMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: invBtnTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "◐"; font.pixelSize: Style.space(8.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Invert"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: invMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyImageTransform("-negate", "◐ Colors inverted")
              }
              PanelToolTip { visible: invMouse.containsMouse; text: "Invert colors (diagram dark/light switch)" }
            }

            // Grayscale
            Rectangle {
              width: grayBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: grayMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: grayBtnTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "◑"; font.pixelSize: Style.space(8.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "B&W"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: grayMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyImageTransform("-colorspace Gray", "◑ Converted to Black & White")
              }
              PanelToolTip { visible: grayMouse.containsMouse; text: "Convert to monochrome / grayscale" }
            }
          }
        }
      }
    }

    // ==========================================
    // CENTER CANVAS VIEWPORT
    // ==========================================
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      Flickable {
        id: canvasFlickable
        anchors.fill: parent
        contentWidth: Math.max(width, compositeContainer.width)
        contentHeight: Math.max(height, compositeContainer.height)
        clip: true
        interactive: false

        // Mouse Wheel to Zoom
        WheelHandler {
          id: wheelHandler
          onWheel: function(event) {
            if (event.angleDelta.y > 0) root.zoomIn()
            else if (event.angleDelta.y < 0) root.zoomOut()
          }
        }

        // Viewport Background MouseArea: Handles panning in space beyond image and absorbs unhandled clicks
        MouseArea {
          id: viewportBgMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.currentTool === "pan" ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
          property real lastX: 0
          property real lastY: 0
          onPressed: function(mouse) {
            lastX = mouse.x
            lastY = mouse.y
            mouse.accepted = true
          }
          onPositionChanged: function(mouse) {
            if ((root.currentTool === "pan" || (mouse.buttons & Qt.MiddleButton)) && pressed) {
              var dx = mouse.x - lastX
              var dy = mouse.y - lastY
              var maxX = Math.max(0, canvasFlickable.contentWidth - canvasFlickable.width)
              var maxY = Math.max(0, canvasFlickable.contentHeight - canvasFlickable.height)
              canvasFlickable.contentX = Math.max(0, Math.min(maxX, canvasFlickable.contentX - dx))
              canvasFlickable.contentY = Math.max(0, Math.min(maxY, canvasFlickable.contentY - dy))
              lastX = mouse.x
              lastY = mouse.y
            }
          }
          onClicked: function(mouse) { mouse.accepted = true }
          onDoubleClicked: function(mouse) { mouse.accepted = true }
        }

        // COMPOSITE CONTAINER (Source image + Canvas overlay)
        Item {
          id: compositeContainer
          readonly property real baseW: baseImage.implicitWidth > 0 ? baseImage.implicitWidth : canvasFlickable.width
          readonly property real baseH: baseImage.implicitHeight > 0 ? baseImage.implicitHeight : canvasFlickable.height
          width: baseW * root.zoomScale
          height: baseH * root.zoomScale
          x: Math.max(0, (canvasFlickable.width - width) / 2)
          y: Math.max(0, (canvasFlickable.height - height) / 2)

          // 1. Base Image
          Image {
            id: baseImage
            source: root.imagePath ? ("file://" + root.imagePath) : ""
            fillMode: Image.Stretch
            anchors.fill: parent
            smooth: true
            onStatusChanged: {
              if (status === Image.Ready) {
                root.fitZoom()
              }
            }
          }

          // 2. Annotation Canvas
          Canvas {
            id: annotationCanvas
            anchors.fill: parent

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              ctx.save()
              ctx.scale(root.zoomScale, root.zoomScale)

              // Render finished actions
              for (var i = 0; i < root.actions.length; i++) {
                root.renderAction(ctx, root.actions[i])
              }

              // Render live current action during drag
              if (root.currentAction) {
                root.renderAction(ctx, root.currentAction)
              }
              ctx.restore()
            }
          }

          // 3. Interactive Drawing & Pan MouseArea
          MouseArea {
            id: drawMouseArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: root.currentTool !== "pan" && root.currentTool !== "select"
            cursorShape: root.currentTool === "pan" ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : (root.currentTool === "select" ? (hoverActionIdx >= 0 ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor)) : (root.currentTool === "crop" ? Qt.CrossCursor : (root.currentTool === "eraser" ? Qt.ForbiddenCursor : (root.currentTool === "text" ? Qt.IBeamCursor : Qt.CrossCursor))))

            property real lastPanX: 0
            property real lastPanY: 0
            property int hoverActionIdx: -1
            property bool isBgPanning: false

            onPressed: function(mouse) {
              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var pt = { x: mouse.x / z, y: mouse.y / z }
              var actColor = String(root.currentColor)

              if (mouse.button === Qt.MiddleButton) {
                isBgPanning = true
                lastPanX = mouse.x
                lastPanY = mouse.y
                mouse.accepted = true
                return
              }

              if (root.textInputActive) {
                root.commitText()
                return
              }

              // Crop tool is handled entirely by cropOverlay
              if (root.currentTool === "crop") {
                mouse.accepted = true
                return
              }

              // Select tool
              if (root.currentTool === "select") {
                var hitIdx = root.findActionAt(pt)
                if (hitIdx >= 0) {
                  root.selectAction(hitIdx)
                  selectionOverlay.startDrag("move", drawMouseArea, mouse.x, mouse.y)
                } else {
                  root.selectedActionIndex = -1
                  isBgPanning = true
                  lastPanX = mouse.x
                  lastPanY = mouse.y
                }
                mouse.accepted = true
                return
              }

              // Pan tool: if an element is clicked, select it and switch to select tool! Otherwise pan.
              if (root.currentTool === "pan") {
                var panHit = root.findActionAt(pt)
                if (panHit >= 0) {
                  root.currentTool = "select"
                  root.selectAction(panHit)
                  selectionOverlay.startDrag("move", drawMouseArea, mouse.x, mouse.y)
                  mouse.accepted = true
                  return
                }
                isBgPanning = true
                lastPanX = mouse.x
                lastPanY = mouse.y
                mouse.accepted = true
                return
              }

              // Text tool
              if (root.currentTool === "text") {
                root.textInputPos = Qt.point(mouse.x, mouse.y)
                root.textInputDraft = ""
                root.textInputActive = true
                return
              }

              // Stamp tool
              if (root.currentTool === "stamp") {
                root.pushUndoState()
                var stampAct = {
                  tool: "stamp",
                  stampType: root.currentStamp,
                  num: root.stampCounter,
                  color: actColor,
                  width: Number(root.strokeWidth),
                  pos: pt
                }
                if (root.currentStamp === "number") {
                  root.stampCounter++
                }
                var nextActs = root.actions.slice()
                nextActs.push(stampAct)
                root.actions = nextActs
                root.selectedActionIndex = nextActs.length - 1
                annotationCanvas.requestPaint()
                return
              }

              // Eraser tool
              if (root.currentTool === "eraser") {
                root.eraseNearPoint(pt)
                return
              }

              // Freehand / shape tools
              root.isDrawing = true

              if (root.currentTool === "pen" || root.currentTool === "highlighter") {
                root.currentAction = {
                  tool: root.currentTool,
                  color: actColor,
                  width: Number(root.strokeWidth),
                  points: [pt]
                }
              } else {
                root.currentAction = {
                  tool: root.currentTool,
                  color: actColor,
                  width: Number(root.strokeWidth),
                  filled: Boolean(root.fillShape),
                  start: pt,
                  end: pt
                }
              }
              annotationCanvas.requestPaint()
            }

            onPositionChanged: function(mouse) {
              if (root.currentTool === "crop") return

              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var pt = { x: mouse.x / z, y: mouse.y / z }

              if (root.currentTool === "select" && !pressed) {
                hoverActionIdx = root.findActionAt(pt)
              }

              if (isBgPanning && pressed) {
                var dx = mouse.x - lastPanX
                var dy = mouse.y - lastPanY
                var maxX = Math.max(0, canvasFlickable.contentWidth - canvasFlickable.width)
                var maxY = Math.max(0, canvasFlickable.contentHeight - canvasFlickable.height)
                canvasFlickable.contentX = Math.max(0, Math.min(maxX, canvasFlickable.contentX - dx))
                canvasFlickable.contentY = Math.max(0, Math.min(maxY, canvasFlickable.contentY - dy))
                lastPanX = mouse.x
                lastPanY = mouse.y
                return
              }

              if (selectionOverlay.activeHandle !== "") {
                selectionOverlay.updateDrag(drawMouseArea, mouse.x, mouse.y)
                return
              }

              if (root.currentTool === "eraser" && pressed) {
                root.eraseNearPoint(pt)
                return
              }

              if (!root.isDrawing || !root.currentAction) return

              if (root.currentTool === "pen" || root.currentTool === "highlighter") {
                root.currentAction.points.push(pt)
              } else {
                root.currentAction.end = pt
              }
              annotationCanvas.requestPaint()
            }

            onReleased: function(mouse) {
              if (isBgPanning) {
                isBgPanning = false
              }

              if (selectionOverlay.activeHandle !== "") {
                selectionOverlay.endDrag()
              }

              if (root.isDrawing && root.currentAction) {
                var act = root.currentAction
                var valid = true
                if (act.tool === "block_highlight" && act.start && act.end) {
                  if (Math.abs(act.end.x - act.start.x) <= 2 || Math.abs(act.end.y - act.start.y) <= 2) valid = false
                } else if (act.tool === "pixelate" && act.start && act.end) {
                  if (Math.abs(act.end.x - act.start.x) <= 4 || Math.abs(act.end.y - act.start.y) <= 4) valid = false
                }
                if (valid) {
                  root.pushUndoState()
                  var finalActs = root.actions.slice()
                  finalActs.push(act)
                  root.actions = finalActs
                  root.selectedActionIndex = finalActs.length - 1
                }
                root.currentAction = null
                root.isDrawing = false
                annotationCanvas.requestPaint()
              }
              mouse.accepted = true
            }

            onClicked: function(mouse) {
              mouse.accepted = true
            }

            onCanceled: function() {
              isBgPanning = false
              if (selectionOverlay.activeHandle !== "") {
                selectionOverlay.endDrag()
              }
              if (root.isDrawing && root.currentAction) {
                var act = root.currentAction
                var valid = true
                if (act.tool === "block_highlight" && act.start && act.end) {
                  if (Math.abs(act.end.x - act.start.x) <= 2 || Math.abs(act.end.y - act.start.y) <= 2) valid = false
                } else if (act.tool === "pixelate" && act.start && act.end) {
                  if (Math.abs(act.end.x - act.start.x) <= 4 || Math.abs(act.end.y - act.start.y) <= 4) valid = false
                }
                if (valid) {
                  root.pushUndoState()
                  var finalActs = root.actions.slice()
                  finalActs.push(act)
                  root.actions = finalActs
                  root.selectedActionIndex = finalActs.length - 1
                }
                root.currentAction = null
                root.isDrawing = false
                annotationCanvas.requestPaint()
              }
            }
          }

          // Inline Text Input Overlay
          Rectangle {
            id: textInputOverlay
            visible: root.textInputActive
            x: root.textInputPos.x
            y: root.textInputPos.y
            width: Math.max(Style.space(160), textEditorInput.implicitWidth + Style.space(24))
            height: Style.space(34)
            radius: Style.space(4)
            color: root.textBox ? Util.alpha("#0F172A", 0.90) : Util.alpha(Color.popups.background || Color.background, 0.95)
            border.width: root.textBox ? 1.5 : 1
            border.color: root.textBox ? root.currentColor : Color.accent
            z: 20

            TextInput {
              id: textEditorInput
              anchors.fill: parent
              anchors.margins: Style.space(6)
              color: root.currentColor
              font.family: Style.font.menuFamily
              font.pixelSize: Math.max(14, root.strokeWidth * 4)
              font.bold: true
              focus: root.textInputActive
              text: root.textInputDraft
              onTextEdited: root.textInputDraft = text
              onAccepted: root.commitText()

              Text {
                visible: textEditorInput.text === ""
                text: "Type text & Enter…"
                color: Util.alpha(Color.popups.text || Color.text, 0.4)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // Crop Overlay
          Item {
            id: cropOverlay
            visible: root.currentTool === "crop"
            anchors.fill: parent
            z: 25

            property var startCrop: null
            property real startGlobalX: 0
            property real startGlobalY: 0
            property string activeHandle: ""

            function startDrag(handle, mouseItem, mouseX, mouseY) {
              if (!root.cropRect) return
              var pt = mouseItem.mapToItem(cropOverlay, mouseX, mouseY)
              activeHandle = handle
              startGlobalX = pt.x
              startGlobalY = pt.y
              startCrop = {
                x: root.cropRect.x,
                y: root.cropRect.y,
                width: root.cropRect.width,
                height: root.cropRect.height
              }
            }

            function updateDrag(mouseItem, mouseX, mouseY) {
              if (!startCrop || !activeHandle) return
              var pt = mouseItem.mapToItem(cropOverlay, mouseX, mouseY)
              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var dx = (pt.x - startGlobalX) / z
              var dy = (pt.y - startGlobalY) / z

              var imgW = (baseImage.implicitWidth > 0 ? baseImage.implicitWidth : compositeContainer.width)
              var imgH = (baseImage.implicitHeight > 0 ? baseImage.implicitHeight : compositeContainer.height)
              var minSize = 20

              var nx = startCrop.x
              var ny = startCrop.y
              var nw = startCrop.width
              var nh = startCrop.height

              if (activeHandle === "move") {
                nx = Math.max(0, Math.min(imgW - nw, startCrop.x + dx))
                ny = Math.max(0, Math.min(imgH - nh, startCrop.y + dy))
              } else {
                if (activeHandle === "tl" || activeHandle === "l" || activeHandle === "bl") {
                  var proposedX = Math.max(0, Math.min(startCrop.x + startCrop.width - minSize, startCrop.x + dx))
                  nw = startCrop.width - (proposedX - startCrop.x)
                  nx = proposedX
                }
                if (activeHandle === "tr" || activeHandle === "r" || activeHandle === "br") {
                  nw = Math.max(minSize, Math.min(imgW - startCrop.x, startCrop.width + dx))
                }
                if (activeHandle === "tl" || activeHandle === "t" || activeHandle === "tr") {
                  var proposedY = Math.max(0, Math.min(startCrop.y + startCrop.height - minSize, startCrop.y + dy))
                  nh = startCrop.height - (proposedY - startCrop.y)
                  ny = proposedY
                }
                if (activeHandle === "bl" || activeHandle === "b" || activeHandle === "br") {
                  nh = Math.max(minSize, Math.min(imgH - startCrop.y, startCrop.height + dy))
                }

                if (root.cropRatio !== "free") {
                  var targetRatio = 1.0
                  for (var r = 0; r < root.cropRatios.length; r++) {
                    if (root.cropRatios[r].id === root.cropRatio) {
                      targetRatio = root.cropRatios[r].ratio
                      break
                    }
                  }
                  if (targetRatio > 0) {
                    if (activeHandle === "t" || activeHandle === "b") {
                      nw = Math.max(minSize, Math.round(nh * targetRatio))
                      if (nx + nw > imgW) {
                        nw = imgW - nx
                        nh = Math.round(nw / targetRatio)
                      }
                    } else {
                      nh = Math.max(minSize, Math.round(nw / targetRatio))
                      if (ny + nh > imgH) {
                        nh = imgH - ny
                        nw = Math.round(nh * targetRatio)
                      }
                    }
                  }
                }
              }

              root.cropRect = {
                x: Math.round(nx),
                y: Math.round(ny),
                width: Math.round(nw),
                height: Math.round(nh)
              }
            }

            function endDrag() {
              activeHandle = ""
              startCrop = null
            }

            // Background MouseArea: drag to draw new crop box or middle-click pan
            MouseArea {
              id: cropBgMouseArea
              anchors.fill: parent
              cursorShape: Qt.CrossCursor
              z: 1

              property real dragStartX: 0
              property real dragStartY: 0
              property var previousValidCrop: null
              property real lastPanX: 0
              property real lastPanY: 0
              property bool isPanning: false

              onPressed: function(mouse) {
                if (mouse.button === Qt.MiddleButton) {
                  isPanning = true
                  lastPanX = mouse.x
                  lastPanY = mouse.y
                  mouse.accepted = true
                  return
                }
                isPanning = false
                previousValidCrop = (root.cropRect && root.cropRect.width > 20 && root.cropRect.height > 20) ? root.cropRect : null
                var z = root.zoomScale > 0 ? root.zoomScale : 1.0
                dragStartX = mouse.x / z
                dragStartY = mouse.y / z
                root.cropRect = { x: dragStartX, y: dragStartY, width: 0, height: 0 }
              }

              onPositionChanged: function(mouse) {
                if (isPanning) {
                  var pdx = mouse.x - lastPanX
                  var pdy = mouse.y - lastPanY
                  var maxX = Math.max(0, canvasFlickable.contentWidth - canvasFlickable.width)
                  var maxY = Math.max(0, canvasFlickable.contentHeight - canvasFlickable.height)
                  canvasFlickable.contentX = Math.max(0, Math.min(maxX, canvasFlickable.contentX - pdx))
                  canvasFlickable.contentY = Math.max(0, Math.min(maxY, canvasFlickable.contentY - pdy))
                  lastPanX = mouse.x
                  lastPanY = mouse.y
                  return
                }
                if (!pressed) return
                var z = root.zoomScale > 0 ? root.zoomScale : 1.0
                var curX = mouse.x / z
                var curY = mouse.y / z
                var imgW = (baseImage.implicitWidth > 0 ? baseImage.implicitWidth : compositeContainer.width)
                var imgH = (baseImage.implicitHeight > 0 ? baseImage.implicitHeight : compositeContainer.height)
                var x1 = Math.max(0, Math.min(imgW, Math.min(dragStartX, curX)))
                var y1 = Math.max(0, Math.min(imgH, Math.min(dragStartY, curY)))
                var x2 = Math.max(0, Math.min(imgW, Math.max(dragStartX, curX)))
                var y2 = Math.max(0, Math.min(imgH, Math.max(dragStartY, curY)))
                root.cropRect = { x: x1, y: y1, width: x2 - x1, height: y2 - y1 }
              }

              onReleased: function() {
                isPanning = false
                if (!root.cropRect || root.cropRect.width < 20 || root.cropRect.height < 20) {
                  if (previousValidCrop) {
                    root.cropRect = previousValidCrop
                  } else {
                    root.initCropRect()
                  }
                }
              }
            }

            // Dark scrims outside crop rect (z: 5)
            Rectangle {
              // Top scrim
              z: 5
              x: 0; y: 0
              width: parent.width
              height: root.cropRect ? Math.max(0, root.cropRect.y * root.zoomScale) : parent.height
              color: Qt.rgba(0, 0, 0, 0.55)
            }
            Rectangle {
              // Bottom scrim
              z: 5
              visible: Boolean(root.cropRect)
              x: 0
              y: root.cropRect ? (root.cropRect.y + root.cropRect.height) * root.zoomScale : parent.height
              width: parent.width
              height: root.cropRect ? Math.max(0, parent.height - y) : 0
              color: Qt.rgba(0, 0, 0, 0.55)
            }
            Rectangle {
              // Left scrim
              z: 5
              visible: Boolean(root.cropRect)
              x: 0
              y: root.cropRect ? root.cropRect.y * root.zoomScale : 0
              width: root.cropRect ? Math.max(0, root.cropRect.x * root.zoomScale) : 0
              height: root.cropRect ? root.cropRect.height * root.zoomScale : 0
              color: Qt.rgba(0, 0, 0, 0.55)
            }
            Rectangle {
              // Right scrim
              z: 5
              visible: Boolean(root.cropRect)
              x: root.cropRect ? (root.cropRect.x + root.cropRect.width) * root.zoomScale : parent.width
              y: root.cropRect ? root.cropRect.y * root.zoomScale : 0
              width: root.cropRect ? Math.max(0, parent.width - x) : 0
              height: root.cropRect ? root.cropRect.height * root.zoomScale : 0
              color: Qt.rgba(0, 0, 0, 0.55)
            }

            // Crop boundary box (z: 10)
            Rectangle {
              id: cropBoundaryBox
              visible: Boolean(root.cropRect && root.cropRect.width > 2 && root.cropRect.height > 2)
              x: root.cropRect ? root.cropRect.x * root.zoomScale : 0
              y: root.cropRect ? root.cropRect.y * root.zoomScale : 0
              width: root.cropRect ? root.cropRect.width * root.zoomScale : 0
              height: root.cropRect ? root.cropRect.height * root.zoomScale : 0
              color: "transparent"
              border.width: 1.5
              border.color: Color.accent
              z: 10

              // Rule-of-Thirds Grid
              Rectangle { x: parent.width / 3; y: 0; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.25) }
              Rectangle { x: parent.width * 2 / 3; y: 0; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.25) }
              Rectangle { x: 0; y: parent.height / 3; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }
              Rectangle { x: 0; y: parent.height * 2 / 3; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }

              // Interior Move MouseArea
              MouseArea {
                id: cropMoveArea
                anchors.fill: parent
                anchors.margins: Style.space(8)
                cursorShape: Qt.SizeAllCursor
                hoverEnabled: true

                onPressed: function(mouse) {
                  cropOverlay.startDrag("move", cropMoveArea, mouse.x, mouse.y)
                }
                onPositionChanged: function(mouse) {
                  if (pressed) cropOverlay.updateDrag(cropMoveArea, mouse.x, mouse.y)
                }
                onReleased: function() {
                  cropOverlay.endDrag()
                }
              }

              // Dimension badge in top-left
              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Style.space(4)
                width: cropDimText.implicitWidth + Style.space(8)
                height: Style.space(18)
                radius: Style.space(3)
                color: Util.alpha("#000000", 0.75)
                border.width: 1
                border.color: Color.accent
                z: 20

                Text {
                  id: cropDimText
                  anchors.centerIn: parent
                  text: root.cropRect ? (Math.round(root.cropRect.width) + " × " + Math.round(root.cropRect.height) + " px" + (root.cropRatio !== "free" ? (" (" + root.cropRatio + ")") : "")) : ""
                  color: "#FFFFFF"
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                }
              }

              // Floating Action Badge: Apply & Cancel
              Rectangle {
                id: cropFloatingActions
                z: 25
                x: Math.max(-cropBoundaryBox.x, Math.min(cropOverlay.width - cropBoundaryBox.x - width, parent.width / 2 - width / 2))
                y: (cropBoundaryBox.y + cropBoundaryBox.height + height + 8 < cropOverlay.height) ? (parent.height + Style.space(6)) : ((cropBoundaryBox.y - height - 8 > 0) ? (-height - Style.space(6)) : (parent.height - height - Style.space(6)))
                width: cropFloatRow.implicitWidth + Style.space(12)
                height: Style.space(26)
                radius: Style.space(13)
                color: Util.alpha(Color.popups.background || Color.background, 0.95)
                border.width: 1
                border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

                Row {
                  id: cropFloatRow
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  // Apply Button
                  Rectangle {
                    width: fltApplyRow.implicitWidth + Style.space(10)
                    height: Style.space(20)
                    radius: Style.space(10)
                    color: fltApplyMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                      id: fltApplyRow
                      anchors.centerIn: parent
                      spacing: Style.space(3)
                      Text { text: "✓"; color: "#FFFFFF"; font.pixelSize: Style.space(8.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                      Text { text: "Apply"; color: "#FFFFFF"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                      id: fltApplyMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.applyCrop()
                    }
                  }

                  // Cancel Button
                  Rectangle {
                    width: fltCancelRow.implicitWidth + Style.space(10)
                    height: Style.space(20)
                    radius: Style.space(10)
                    color: fltCancelMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.06)
                    border.width: 1
                    border.color: Util.alpha(Color.popups.text || Color.text, 0.15)
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                      id: fltCancelRow
                      anchors.centerIn: parent
                      spacing: Style.space(3)
                      Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                      Text { text: "Cancel"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                      id: fltCancelMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.cropRect = null
                        root.currentTool = "pan"
                      }
                    }
                  }
                }
              }

              // Reusable Handle Component
              component CropHandle: Rectangle {
                id: handleRoot
                property string handleName: ""
                property int cursor: Qt.ArrowCursor
                width: Style.space(10)
                height: Style.space(10)
                radius: Style.space(2)
                color: (hMouse.containsMouse || (cropOverlay.activeHandle === handleRoot.handleName)) ? Color.accent : "#FFFFFF"
                border.width: 1.5
                border.color: (hMouse.containsMouse || (cropOverlay.activeHandle === handleRoot.handleName)) ? "#FFFFFF" : "#1E293B"
                z: 15

                MouseArea {
                  id: hMouse
                  anchors.fill: parent
                  anchors.margins: -Style.space(5)
                  hoverEnabled: true
                  cursorShape: handleRoot.cursor

                  onPressed: function(mouse) {
                    cropOverlay.startDrag(handleRoot.handleName, hMouse, mouse.x, mouse.y)
                  }
                  onPositionChanged: function(mouse) {
                    if (pressed) cropOverlay.updateDrag(hMouse, mouse.x, mouse.y)
                  }
                  onReleased: function() {
                    cropOverlay.endDrag()
                  }
                }
              }

              // 8 Resizing Handles
              CropHandle { handleName: "tl"; cursor: Qt.SizeFDiagCursor; anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.top }
              CropHandle { handleName: "t"; cursor: Qt.SizeVerCursor; width: Style.space(16); height: Style.space(7); anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.top }
              CropHandle { handleName: "tr"; cursor: Qt.SizeBDiagCursor; anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.top }
              CropHandle { handleName: "r"; cursor: Qt.SizeHorCursor; width: Style.space(7); height: Style.space(16); anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.verticalCenter }
              CropHandle { handleName: "br"; cursor: Qt.SizeFDiagCursor; anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.bottom }
              CropHandle { handleName: "b"; cursor: Qt.SizeVerCursor; width: Style.space(16); height: Style.space(7); anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.bottom }
              CropHandle { handleName: "bl"; cursor: Qt.SizeBDiagCursor; anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.bottom }
              CropHandle { handleName: "l"; cursor: Qt.SizeHorCursor; width: Style.space(7); height: Style.space(16); anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.verticalCenter }
            }
          }

          // Selection & Transform Overlay
          Item {
            id: selectionOverlay
            anchors.fill: parent
            z: 30
            visible: root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length && !root.isExporting && root.currentTool !== "crop"

            property var curAct: (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) ? root.actions[root.selectedActionIndex] : null
            property var selBounds: curAct ? root.getActionBounds(curAct) : null

            readonly property real boxX: selBounds ? selBounds.x * root.zoomScale : 0
            readonly property real boxY: selBounds ? selBounds.y * root.zoomScale : 0
            readonly property real boxW: selBounds ? selBounds.width * root.zoomScale : 0
            readonly property real boxH: selBounds ? selBounds.height * root.zoomScale : 0

            property string activeHandle: ""
            property real startMouseX: 0
            property real startMouseY: 0
            property var dragStartAct: null
            property var dragStartB: null

            function startDrag(handle, mouseItem, mouseX, mouseY) {
              if (!curAct || !selBounds) return
              var pt = mouseItem.mapToItem(selectionOverlay, mouseX, mouseY)
              activeHandle = handle
              startMouseX = pt.x
              startMouseY = pt.y
              dragStartAct = JSON.parse(JSON.stringify(curAct))
              dragStartB = {
                x: selBounds.x,
                y: selBounds.y,
                width: selBounds.width,
                height: selBounds.height
              }
            }

            function updateDrag(mouseItem, mouseX, mouseY) {
              if (!dragStartAct || !dragStartB || !activeHandle) return
              var pt = mouseItem.mapToItem(selectionOverlay, mouseX, mouseY)
              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var dx = (pt.x - startMouseX) / z
              var dy = (pt.y - startMouseY) / z

              var updated = null
              if (activeHandle === "move") {
                updated = root.moveAction(dragStartAct, dx, dy)
              } else if (activeHandle === "start_pt") {
                updated = JSON.parse(JSON.stringify(dragStartAct))
                updated.start = { x: dragStartAct.start.x + dx, y: dragStartAct.start.y + dy }
              } else if (activeHandle === "end_pt") {
                updated = JSON.parse(JSON.stringify(dragStartAct))
                updated.end = { x: dragStartAct.end.x + dx, y: dragStartAct.end.y + dy }
              } else {
                var nb = root.computeNewBounds(dragStartB, activeHandle, dx, dy)
                updated = root.scaleAction(dragStartAct, dragStartB, nb)
              }

              if (updated) {
                var next = root.actions.slice()
                next[root.selectedActionIndex] = updated
                root.actions = next
                annotationCanvas.requestPaint()
              }
            }

            function endDrag() {
              if (dragStartAct && activeHandle) {
                var cur = (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) ? root.actions[root.selectedActionIndex] : null
                if (cur && JSON.stringify(cur) !== JSON.stringify(dragStartAct)) {
                  root.pushSpecificUndoState(dragStartAct, root.selectedActionIndex)
                  root.showFeedback(activeHandle === "move" ? "Moved element" : "Resized element")
                }
              }
              activeHandle = ""
              dragStartAct = null
              dragStartB = null
            }

            // Selection Bounding Box
            Rectangle {
              id: selectionBoundingBox
              visible: Boolean(selectionOverlay.selBounds && selectionOverlay.boxW > 0 && selectionOverlay.boxH > 0)
              x: selectionOverlay.boxX
              y: selectionOverlay.boxY
              width: selectionOverlay.boxW
              height: selectionOverlay.boxH
              color: Util.alpha(Color.accent, 0.08)
              border.width: 1.5
              border.color: Color.accent
              z: 10

              // Move MouseArea inside box
              MouseArea {
                id: selMoveArea
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                hoverEnabled: true

                onPressed: function(mouse) {
                  selectionOverlay.startDrag("move", selMoveArea, mouse.x, mouse.y)
                }
                onPositionChanged: function(mouse) {
                  if (pressed) selectionOverlay.updateDrag(selMoveArea, mouse.x, mouse.y)
                }
                onReleased: function() {
                  selectionOverlay.endDrag()
                }
              }

              // Floating Actions Bar
              Rectangle {
                id: selFloatingActions
                z: 35
                x: Math.max(-selectionBoundingBox.x, Math.min(selectionOverlay.width - selectionBoundingBox.x - width, parent.width / 2 - width / 2))
                y: (selectionBoundingBox.y - height - Style.space(8) >= 0) ? (-height - Style.space(8)) : (parent.height + Style.space(8))
                width: selFloatRow.implicitWidth + Style.space(12)
                height: Style.space(26)
                radius: Style.space(13)
                color: Util.alpha(Color.popups.background || Color.background, 0.96)
                border.width: 1
                border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

                Row {
                  id: selFloatRow
                  anchors.centerIn: parent
                  spacing: Style.space(5)

                  // Tool Type Badge
                  Text {
                    text: root.getActionLabel(selectionOverlay.curAct)
                    color: Color.accent
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Separator
                  Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.2); anchors.verticalCenter: parent.verticalCenter }

                  // Duplicate Button
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(4)
                    color: dupMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "⧉"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                    MouseArea {
                      id: dupMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.duplicateSelectedAction()
                    }
                    PanelToolTip { visible: dupMouse.containsMouse; text: "Duplicate element (Ctrl+D)" }
                  }

                  // Bring to Front Button
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(4)
                    color: frontMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "▲"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                    MouseArea {
                      id: frontMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.bringSelectedToFront()
                    }
                    PanelToolTip { visible: frontMouse.containsMouse; text: "Bring to Front (])" }
                  }

                  // Send to Back Button
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(4)
                    color: backMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "▼"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                    MouseArea {
                      id: backMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.sendSelectedToBack()
                    }
                    PanelToolTip { visible: backMouse.containsMouse; text: "Send to Back ([)" }
                  }

                  // Separator
                  Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.2); anchors.verticalCenter: parent.verticalCenter }

                  // Delete Button
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(4)
                    color: delMouse.containsMouse ? Util.alpha("#EF4444", 0.3) : Util.alpha("#EF4444", 0.12)
                    border.width: 1; border.color: Util.alpha("#EF4444", 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🗑"; color: "#EF4444"; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                    MouseArea {
                      id: delMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.deleteSelectedAction()
                    }
                    PanelToolTip { visible: delMouse.containsMouse; text: "Delete element (Del)" }
                  }

                  // Close / Deselect Button
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(4)
                    color: deselMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                    MouseArea {
                      id: deselMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.selectedActionIndex = -1
                    }
                    PanelToolTip { visible: deselMouse.containsMouse; text: "Deselect (Esc)" }
                  }
                }
              }

              // Reusable Handle Component
              component SelHandle: Rectangle {
                id: sHandleRoot
                property string handleName: ""
                property int cursor: Qt.ArrowCursor
                width: Style.space(9)
                height: Style.space(9)
                radius: Style.space(2)
                color: (shMouse.containsMouse || (selectionOverlay.activeHandle === sHandleRoot.handleName)) ? Color.accent : "#FFFFFF"
                border.width: 1.5
                border.color: Color.accent
                z: 20

                MouseArea {
                  id: shMouse
                  anchors.fill: parent
                  anchors.margins: -Style.space(6)
                  hoverEnabled: true
                  cursorShape: sHandleRoot.cursor

                  onPressed: function(mouse) {
                    selectionOverlay.startDrag(sHandleRoot.handleName, shMouse, mouse.x, mouse.y)
                  }
                  onPositionChanged: function(mouse) {
                    if (pressed) selectionOverlay.updateDrag(shMouse, mouse.x, mouse.y)
                  }
                  onReleased: function() {
                    selectionOverlay.endDrag()
                  }
                }
              }

              // 8 Resizing Handles
              SelHandle { handleName: "tl"; cursor: Qt.SizeFDiagCursor; anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.top }
              SelHandle { handleName: "t"; cursor: Qt.SizeVerCursor; width: Style.space(14); height: Style.space(6); anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.top }
              SelHandle { handleName: "tr"; cursor: Qt.SizeBDiagCursor; anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.top }
              SelHandle { handleName: "r"; cursor: Qt.SizeHorCursor; width: Style.space(6); height: Style.space(14); anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.verticalCenter }
              SelHandle { handleName: "br"; cursor: Qt.SizeFDiagCursor; anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.bottom }
              SelHandle { handleName: "b"; cursor: Qt.SizeVerCursor; width: Style.space(14); height: Style.space(6); anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.bottom }
              SelHandle { handleName: "bl"; cursor: Qt.SizeBDiagCursor; anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.bottom }
              SelHandle { handleName: "l"; cursor: Qt.SizeHorCursor; width: Style.space(6); height: Style.space(14); anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.verticalCenter }
            }

            // Direct Endpoint Handles for Line and Arrow
            Item {
              visible: Boolean(selectionOverlay.curAct && (selectionOverlay.curAct.tool === "line" || selectionOverlay.curAct.tool === "arrow") && selectionOverlay.curAct.start && selectionOverlay.curAct.end)
              anchors.fill: parent
              z: 25

              // Start Point Handle
              Rectangle {
                x: selectionOverlay.curAct ? (selectionOverlay.curAct.start.x * root.zoomScale - width / 2) : 0
                y: selectionOverlay.curAct ? (selectionOverlay.curAct.start.y * root.zoomScale - height / 2) : 0
                width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                color: (ptStartMouse.containsMouse || (selectionOverlay.activeHandle === "start_pt")) ? Color.accent : "#FFFFFF"
                border.width: 1.5; border.color: Color.accent

                MouseArea {
                  id: ptStartMouse
                  anchors.fill: parent; anchors.margins: -Style.space(6); hoverEnabled: true; cursorShape: Qt.CrossCursor
                  onPressed: function(mouse) { selectionOverlay.startDrag("start_pt", ptStartMouse, mouse.x, mouse.y) }
                  onPositionChanged: function(mouse) { if (pressed) selectionOverlay.updateDrag(ptStartMouse, mouse.x, mouse.y) }
                  onReleased: function() { selectionOverlay.endDrag() }
                }
                PanelToolTip { visible: ptStartMouse.containsMouse; text: "Tail / Start Point" }
              }

              // End Point Handle
              Rectangle {
                x: selectionOverlay.curAct ? (selectionOverlay.curAct.end.x * root.zoomScale - width / 2) : 0
                y: selectionOverlay.curAct ? (selectionOverlay.curAct.end.y * root.zoomScale - height / 2) : 0
                width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                color: (ptEndMouse.containsMouse || (selectionOverlay.activeHandle === "end_pt")) ? Color.accent : "#FFFFFF"
                border.width: 1.5; border.color: Color.accent

                MouseArea {
                  id: ptEndMouse
                  anchors.fill: parent; anchors.margins: -Style.space(6); hoverEnabled: true; cursorShape: Qt.CrossCursor
                  onPressed: function(mouse) { selectionOverlay.startDrag("end_pt", ptEndMouse, mouse.x, mouse.y) }
                  onPositionChanged: function(mouse) { if (pressed) selectionOverlay.updateDrag(ptEndMouse, mouse.x, mouse.y) }
                  onReleased: function() { selectionOverlay.endDrag() }
                }
                PanelToolTip { visible: ptEndMouse.containsMouse; text: "Head / End Point" }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // BOTTOM ACTION BAR: VIEWER & EXPORT CONTROLS
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(42)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(8)

        // Annotations count info & Feedback Badge
        Row {
          spacing: Style.space(5)
          Layout.alignment: Qt.AlignVCenter

          readonly property int editCount: root.actions.length + (root.imageHistory ? root.imageHistory.length : 0)

          Rectangle {
            width: Style.space(7); height: Style.space(7); radius: Style.space(3.5)
            color: parent.editCount > 0 ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.25)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: parent.editCount > 0 ? (parent.editCount + (parent.editCount === 1 ? " edit" : " edits")) : "Clean"
            color: Util.alpha(Color.popups.text || Color.text, 0.6)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(8.5)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            Layout.maximumWidth: Style.space(80)
            elide: Text.ElideRight
          }

          // In-modal Toast Feedback Badge
          Rectangle {
            visible: root.actionFeedback !== ""
            height: Style.space(20)
            width: fbText.implicitWidth + Style.space(12)
            radius: Style.space(4)
            color: Util.alpha(Color.accent, 0.2)
            border.width: 1
            border.color: Color.accent
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: fbText
              text: root.actionFeedback
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              font.bold: true
              anchors.centerIn: parent
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Action buttons
        Row {
          spacing: Style.space(5)
          Layout.alignment: Qt.AlignVCenter

          // Cancel / Dismiss
          Rectangle {
            height: Style.space(26); width: Style.space(54); radius: Style.space(4)
            color: cancelMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.06)
            border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
            Text {
              text: "Cancel"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8.5)
              font.bold: true
              anchors.centerIn: parent
            }
            MouseArea {
              id: cancelMouse
              anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
            PanelToolTip { visible: cancelMouse.containsMouse; text: "Discard edits and close (Esc)" }
          }

          // Copy Clean Original
          Rectangle {
            height: Style.space(26); width: copyOrigTxt.implicitWidth + Style.space(12); radius: Style.space(4)
            color: origMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.08)
            border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.15)
            Row {
              id: copyOrigTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰆏"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Original"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: origMouse
              anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.imagePath) {
                  Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < " + Util.shellQuote(root.imagePath) + " && notify-send -a \"ReClip\" \"Original Image Copied\" \"Loaded to clipboard\""])
                  root.showFeedback("✓ Original copied to clipboard!")
                }
              }
            }
            PanelToolTip { visible: origMouse.containsMouse; text: "Copy clean original to clipboard" }
          }

          // Save to File (Pictures/Screenshots)
          Rectangle {
            height: Style.space(26); width: saveFileTxt.implicitWidth + Style.space(12); radius: Style.space(4)
            color: saveMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)
            border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.2)

            Row {
              id: saveFileTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "💾"; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
              Text {
                text: "Save File"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8.5)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: saveMouse
              anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.exportImage("file")
            }
            PanelToolTip { visible: saveMouse.containsMouse; text: "Save to ~/Pictures/Screenshots/" }
          }

          // Copy to Clipboard (wl-copy)
          Rectangle {
            height: Style.space(26); width: copyClipTxt.implicitWidth + Style.space(14); radius: Style.space(4)
            color: copyClipMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

            Row {
              id: copyClipTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰆏"; color: "#FFFFFF"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
              Text {
                text: "Copy & Save"
                color: "#FFFFFF"
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8.5)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: copyClipMouse
              anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.exportImage("clipboard")
            }
            PanelToolTip { visible: copyClipMouse.containsMouse; text: "Copy annotated image & save to feed" }
          }
        }
      }
    }
  }

  // Helper drawing functions
  function renderAction(ctx, act) {
    if (!act) return
    ctx.save()

    var actColor = String(act.color || "#EF4444")
    var actWidth = Number(act.width || 4)

    try {
      if (act.tool === "pen") {
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.lineWidth = actWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        var pts = act.points || []
        if (pts.length === 1) {
          ctx.arc(pts[0].x, pts[0].y, actWidth / 2, 0, Math.PI * 2)
          ctx.fillStyle = actColor
          ctx.fill()
        } else if (pts.length >= 2) {
          ctx.moveTo(pts[0].x, pts[0].y)
          for (var j = 1; j < pts.length; j++) {
            ctx.lineTo(pts[j].x, pts[j].y)
          }
          ctx.stroke()
        }
      } else if (act.tool === "highlighter") {
        ctx.globalAlpha = 0.35
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.lineWidth = actWidth * 3
        ctx.lineCap = "square"
        var hpts = act.points || []
        if (hpts.length >= 2) {
          ctx.moveTo(hpts[0].x, hpts[0].y)
          for (var k = 1; k < hpts.length; k++) {
            ctx.lineTo(hpts[k].x, hpts[k].y)
          }
          ctx.stroke()
        }
      } else if (act.tool === "rect" && act.start && act.end) {
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.lineWidth = actWidth
        var rx = Math.min(act.start.x, act.end.x)
        var ry = Math.min(act.start.y, act.end.y)
        var rw = Math.abs(act.end.x - act.start.x)
        var rh = Math.abs(act.end.y - act.start.y)
        if (act.filled) {
          ctx.fillStyle = actColor
          ctx.globalAlpha = 0.25
          ctx.fillRect(rx, ry, rw, rh)
          ctx.globalAlpha = 1.0
        }
        ctx.strokeRect(rx, ry, rw, rh)
      } else if (act.tool === "circle" && act.start && act.end) {
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.lineWidth = actWidth
        var crx = (act.end.x - act.start.x) / 2
        var cry = (act.end.y - act.start.y) / 2
        var ccx = act.start.x + crx
        var ccy = act.start.y + cry
        if (typeof ctx.ellipse === "function") {
          ctx.ellipse(ccx, ccy, Math.abs(crx), Math.abs(cry), 0, 0, Math.PI * 2)
        } else {
          var r = Math.max(Math.abs(crx), Math.abs(cry))
          ctx.arc(ccx, ccy, r, 0, Math.PI * 2)
        }
        if (act.filled) {
          ctx.fillStyle = actColor
          ctx.globalAlpha = 0.25
          ctx.fill()
          ctx.globalAlpha = 1.0
        }
        ctx.stroke()
      } else if (act.tool === "line" && act.start && act.end) {
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.lineWidth = actWidth
        ctx.lineCap = "round"
        ctx.moveTo(act.start.x, act.start.y)
        ctx.lineTo(act.end.x, act.end.y)
        ctx.stroke()
      } else if (act.tool === "arrow" && act.start && act.end) {
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.fillStyle = actColor
        ctx.lineWidth = actWidth
        ctx.lineCap = "round"
        ctx.moveTo(act.start.x, act.start.y)
        ctx.lineTo(act.end.x, act.end.y)
        ctx.stroke()

        var angle = Math.atan2(act.end.y - act.start.y, act.end.x - act.start.x)
        var headLen = Math.max(12, actWidth * 3.5)
        ctx.beginPath()
        ctx.moveTo(act.end.x, act.end.y)
        ctx.lineTo(act.end.x - headLen * Math.cos(angle - Math.PI / 6), act.end.y - headLen * Math.sin(angle - Math.PI / 6))
        ctx.lineTo(act.end.x - headLen * Math.cos(angle + Math.PI / 6), act.end.y - headLen * Math.sin(angle + Math.PI / 6))
        ctx.closePath()
        ctx.fill()
      } else if (act.tool === "blur" && act.start && act.end) {
        var bx = Math.min(act.start.x, act.end.x)
        var by = Math.min(act.start.y, act.end.y)
        var bw = Math.abs(act.end.x - act.start.x)
        var bh = Math.abs(act.end.y - act.start.y)
        ctx.fillStyle = "#0A0A0A"
        ctx.fillRect(bx, by, bw, bh)
        ctx.strokeStyle = "rgba(255,255,255,0.25)"
        ctx.lineWidth = 1
        ctx.strokeRect(bx, by, bw, bh)
      } else if (act.tool === "block_highlight" && act.start && act.end) {
        var hx = Math.min(act.start.x, act.end.x)
        var hy = Math.min(act.start.y, act.end.y)
        var hw = Math.abs(act.end.x - act.start.x)
        var hh = Math.abs(act.end.y - act.start.y)
        ctx.save()
        ctx.fillStyle = actColor
        ctx.globalAlpha = 0.35
        ctx.fillRect(hx, hy, hw, hh)
        ctx.restore()
      } else if (act.tool === "pixelate" && act.start && act.end) {
        var px = Math.min(act.start.x, act.end.x)
        var py = Math.min(act.start.y, act.end.y)
        var pw = Math.abs(act.end.x - act.start.x)
        var ph = Math.abs(act.end.y - act.start.y)
        var blockSize = Math.max(8, Math.min(24, Math.round(Math.min(pw, ph) / 8)))

        ctx.save()
        ctx.fillStyle = "#1E293B"
        ctx.fillRect(px, py, pw, ph)

        var mosaicPalette = ["#0F172A", "#1E293B", "#334155", "#475569", "#64748B", "#1E293B"]
        for (var mx = px; mx < px + pw; mx += blockSize) {
          for (var my = py; my < py + ph; my += blockSize) {
            var bww = Math.min(blockSize, px + pw - mx)
            var bhh = Math.min(blockSize, py + ph - my)
            var seed = Math.sin(mx * 12.9898 + my * 78.233) * 43758.5453
            var idx = Math.abs(Math.floor(seed)) % mosaicPalette.length
            ctx.fillStyle = mosaicPalette[idx]
            ctx.fillRect(mx, my, bww, bhh)
          }
        }
        ctx.strokeStyle = "rgba(255,255,255,0.2)"
        ctx.lineWidth = 1
        ctx.strokeRect(px, py, pw, ph)
        ctx.restore()
      } else if (act.tool === "text" && act.pos && act.text) {
        var fs = act.size || 18
        ctx.font = "bold " + fs + "px sans-serif"
        ctx.textBaseline = "top"
        if (act.box) {
          var padX = Math.round(fs * 0.45)
          var padY = Math.round(fs * 0.25)
          var tw = ctx.measureText(act.text).width
          ctx.save()
          ctx.fillStyle = "rgba(15, 23, 42, 0.88)"
          ctx.fillRect(act.pos.x - padX, act.pos.y - padY, tw + padX * 2, fs + padY * 2)
          ctx.strokeStyle = actColor
          ctx.lineWidth = 1.5
          ctx.strokeRect(act.pos.x - padX, act.pos.y - padY, tw + padX * 2, fs + padY * 2)
          ctx.restore()
        } else {
          ctx.strokeStyle = "rgba(0,0,0,0.7)"
          ctx.lineWidth = 3
          ctx.strokeText(act.text, act.pos.x, act.pos.y)
        }
        ctx.fillStyle = actColor
        ctx.fillText(act.text, act.pos.x, act.pos.y)
      } else if (act.tool === "stamp" && act.pos) {
        var sx = act.pos.x
        var sy = act.pos.y
        var sr = Math.max(14, actWidth * 3)

        ctx.save()
        // Circular badge background (shared across all stamps for visual consistency)
        ctx.fillStyle = actColor
        ctx.beginPath()
        ctx.arc(sx, sy, sr, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = "#FFFFFF"
        ctx.lineWidth = Math.max(1.5, Math.round(sr * 0.12))
        ctx.stroke()

        if (act.stampType === "number") {
          ctx.fillStyle = "#FFFFFF"
          ctx.font = "bold " + Math.round(sr * 1.1) + "px sans-serif"
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText(String(act.num || 1), sx, sy)
        } else if (act.stampType === "check") {
          // Checkmark ✓
          ctx.strokeStyle = "#FFFFFF"
          ctx.lineWidth = Math.max(2, Math.round(sr * 0.22))
          ctx.lineCap = "round"
          ctx.lineJoin = "round"
          ctx.beginPath()
          ctx.moveTo(sx - sr * 0.44, sy + sr * 0.02)
          ctx.lineTo(sx - sr * 0.10, sy + sr * 0.38)
          ctx.lineTo(sx + sr * 0.44, sy - sr * 0.36)
          ctx.stroke()
        } else if (act.stampType === "cross") {
          // Cross ✕
          ctx.strokeStyle = "#FFFFFF"
          ctx.lineWidth = Math.max(2, Math.round(sr * 0.22))
          ctx.lineCap = "round"
          var cd = sr * 0.38
          ctx.beginPath()
          ctx.moveTo(sx - cd, sy - cd)
          ctx.lineTo(sx + cd, sy + cd)
          ctx.moveTo(sx + cd, sy - cd)
          ctx.lineTo(sx - cd, sy + cd)
          ctx.stroke()
        } else if (act.stampType === "star") {
          // 5-point star ★
          ctx.fillStyle = "#FFFFFF"
          ctx.beginPath()
          var starPts = 5
          var outerR = sr * 0.62
          var innerR = outerR * 0.45
          for (var sp = 0; sp < starPts * 2; sp++) {
            var srad = (sp % 2 === 0) ? outerR : innerR
            var sang = (sp * Math.PI / starPts) - (Math.PI / 2)
            var spx = sx + Math.cos(sang) * srad
            var spy = sy + Math.sin(sang) * srad
            if (sp === 0) ctx.moveTo(spx, spy)
            else ctx.lineTo(spx, spy)
          }
          ctx.closePath()
          ctx.fill()
        } else if (act.stampType === "warn") {
          // Warning ! (exclamation mark)
          ctx.strokeStyle = "#FFFFFF"
          ctx.fillStyle = "#FFFFFF"
          ctx.lineWidth = Math.max(2.5, Math.round(sr * 0.22))
          ctx.lineCap = "round"
          ctx.beginPath()
          ctx.moveTo(sx, sy - sr * 0.48)
          ctx.lineTo(sx, sy + sr * 0.10)
          ctx.stroke()
          ctx.beginPath()
          ctx.arc(sx, sy + sr * 0.38, Math.max(1.5, sr * 0.12), 0, Math.PI * 2)
          ctx.fill()
        } else if (act.stampType === "bug") {
          // Bug icon
          ctx.fillStyle = "#FFFFFF"
          ctx.strokeStyle = "#FFFFFF"
          ctx.lineWidth = Math.max(1.5, Math.round(sr * 0.12))
          ctx.lineCap = "round"
          // Body
          ctx.beginPath()
          ctx.arc(sx, sy + sr * 0.08, sr * 0.32, 0, Math.PI * 2)
          ctx.fill()
          // Head
          ctx.beginPath()
          ctx.arc(sx, sy - sr * 0.32, sr * 0.18, 0, Math.PI * 2)
          ctx.fill()
          // Antennae
          ctx.beginPath()
          ctx.moveTo(sx - sr * 0.08, sy - sr * 0.42)
          ctx.lineTo(sx - sr * 0.28, sy - sr * 0.62)
          ctx.moveTo(sx + sr * 0.08, sy - sr * 0.42)
          ctx.lineTo(sx + sr * 0.28, sy - sr * 0.62)
          // Legs
          ctx.moveTo(sx - sr * 0.20, sy - sr * 0.08)
          ctx.lineTo(sx - sr * 0.52, sy - sr * 0.22)
          ctx.moveTo(sx - sr * 0.25, sy + sr * 0.08)
          ctx.lineTo(sx - sr * 0.55, sy + sr * 0.08)
          ctx.moveTo(sx - sr * 0.20, sy + sr * 0.24)
          ctx.lineTo(sx - sr * 0.52, sy + sr * 0.38)
          ctx.moveTo(sx + sr * 0.20, sy - sr * 0.08)
          ctx.lineTo(sx + sr * 0.52, sy - sr * 0.22)
          ctx.moveTo(sx + sr * 0.25, sy + sr * 0.08)
          ctx.lineTo(sx + sr * 0.55, sy + sr * 0.08)
          ctx.moveTo(sx + sr * 0.20, sy + sr * 0.24)
          ctx.lineTo(sx + sr * 0.52, sy + sr * 0.38)
          ctx.stroke()
        } else if (act.stampType === "fire") {
          // Flame icon
          ctx.fillStyle = "#FFFFFF"
          ctx.beginPath()
          ctx.moveTo(sx, sy - sr * 0.58)
          ctx.bezierCurveTo(sx + sr * 0.48, sy - sr * 0.15, sx + sr * 0.48, sy + sr * 0.38, sx, sy + sr * 0.52)
          ctx.bezierCurveTo(sx - sr * 0.48, sy + sr * 0.38, sx - sr * 0.48, sy - sr * 0.15, sx, sy - sr * 0.58)
          ctx.closePath()
          ctx.fill()
          // Inner flame cut-out
          ctx.fillStyle = actColor
          ctx.beginPath()
          ctx.moveTo(sx, sy - sr * 0.15)
          ctx.bezierCurveTo(sx + sr * 0.22, sy + sr * 0.05, sx + sr * 0.22, sy + sr * 0.32, sx, sy + sr * 0.38)
          ctx.bezierCurveTo(sx - sr * 0.22, sy + sr * 0.32, sx - sr * 0.22, sy + sr * 0.05, sx, sy - sr * 0.15)
          ctx.closePath()
          ctx.fill()
        } else {
          ctx.fillStyle = "#FFFFFF"
          ctx.beginPath()
          ctx.arc(sx, sy, sr * 0.4, 0, Math.PI * 2)
          ctx.fill()
        }
        ctx.restore()
      }
    } catch (e) {
      console.warn("Error rendering action:", e)
    }

    ctx.restore()
  }

  function eraseNearPoint(pt) {
    var radius = 24
    var filtered = []
    var changed = false
    for (var i = 0; i < root.actions.length; i++) {
      var a = root.actions[i]
      var hit = false
      if (a.pos) {
        hit = Math.hypot(a.pos.x - pt.x, a.pos.y - pt.y) < radius
      } else if (a.start && a.end) {
        var minX = Math.min(a.start.x, a.end.x) - radius
        var maxX = Math.max(a.start.x, a.end.x) + radius
        var minY = Math.min(a.start.y, a.end.y) - radius
        var maxY = Math.max(a.start.y, a.end.y) + radius
        hit = pt.x >= minX && pt.x <= maxX && pt.y >= minY && pt.y <= maxY
      } else if (a.points && a.points.length > 0) {
        for (var p = 0; p < a.points.length; p++) {
          if (Math.hypot(a.points[p].x - pt.x, a.points[p].y - pt.y) < radius) {
            hit = true
            break
          }
        }
      }
      if (hit) changed = true
      else filtered.push(a)
    }

    if (changed) {
      root.actions = filtered
      annotationCanvas.requestPaint()
    }
  }
}
