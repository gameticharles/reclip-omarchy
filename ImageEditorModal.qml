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
  property string currentTool: "select" // "select", "pan", "pen", "highlighter", "arrow", "rect", "circle", "line", "blur", "text", "stamp", "eraser", "crop", "block_highlight", "pixelate", "magnifier", "spotlight"
  property int selectedActionIndex: -1
  property bool isExporting: false
  property color currentColor: "#EF4444"
  property int strokeWidth: 4
  property bool fillShape: false
  property string fillMode: "none" // "none", "semi", "solid"
  property color fillColor: "#EF4444"
  property string activeColorTarget: "stroke" // "stroke", "fill", "shadow", "halo", "box"
  property bool dropShadow: false
  property color dropShadowColor: "#000000"
  property int dropShadowBlur: 8
  property real dropShadowOpacity: 0.45
  property int dropShadowOffsetX: 0
  property int dropShadowOffsetY: 4
  property int rectCornerRadius: 0
  property string strokeDashStyle: "solid" // "solid", "dashed", "dotted"
  property bool textBox: false
  property string currentStamp: "number" // "number", "check", "cross", "star", "warn", "bug", "fire"
  property int stampCounter: 1
  property string actionFeedback: ""
  property var imageHistory: []
  property var imageRedoStack: []
  property var cropRect: null
  property var cropStartPt: null
  property string cropRatio: "free" // "free", "1:1", "16:9", "4:3", "9:16"
  property var systemFontFamilies: {
    var fams = (typeof Qt !== "undefined" && Qt.fontFamilies) ? Qt.fontFamilies() : []
    if (fams && fams.length > 0) {
      return fams.slice().sort(function(a, b) {
        return a.localeCompare(b)
      })
    }
    return ["Sans", "Serif", "Monospace"]
  }
  property string defaultFontFamily: "sans"
  property bool fontPickerOpen: false
  property string fontSearchQuery: ""
  property var recentColors: ["#EF4444", "#F97316", "#22C55E", "#3B82F6", "#8B5CF6", "#FFFFFF"]
  property bool textHalo: false
  property string textHaloColor: "#000000"
  property int textHaloWidth: 3
  property bool textItalic: false
  property bool textUnderline: false
  property bool textStrikeout: false
  property string textTransform: "none" // "none", "uppercase", "lowercase", "capitalize"
  property string defaultFontWeight: "bold"
  property string defaultTextAlign: "left"
  property string textBoxColor: "#0F172A"
  property real textBoxOpacity: 0.88
  property int textBoxRadius: 6
  property int textEditActionIndex: -1
  property real magnifierZoom: 2.0
  property int magnifierRadius: 50
  property string spotlightShape: "rect"
  property int spotlightRadius: 12
  property real spotlightZoom: 1.0
  property real spotlightDimOpacity: 0.65
  property string spotlightDimColor: "#000000"
  property int spotlightBorderWidth: 2
  property string spotlightBorderColor: "#FFFFFF"
  property bool aspectRatioLocked: false
  property var scrubStartAct: null

  onSelectedActionIndexChanged: {
    if (selectedActionIndex < 0 || !actions[selectedActionIndex] || actions[selectedActionIndex].tool !== "text") {
      fontPickerOpen = false
    }
  }

  readonly property var cropRatios: [
    { id: "free", label: "Free", ratio: 0 },
    { id: "1:1", label: "1:1", ratio: 1.0 },
    { id: "16:9", label: "16:9", ratio: 16.0 / 9.0 },
    { id: "4:3", label: "4:3", ratio: 4.0 / 3.0 },
    { id: "9:16", label: "9:16", ratio: 9.0 / 16.0 }
  ]

  Component.onCompleted: {
    if (!root.systemFontFamilies || root.systemFontFamilies.length <= 3) {
      var fams = (typeof Qt !== "undefined" && Qt.fontFamilies) ? Qt.fontFamilies() : []
      if (fams && fams.length > 0) {
        root.systemFontFamilies = fams.slice().sort(function(a, b) {
          return a.localeCompare(b)
        })
      }
    }
  }

  function isColorDark(col) {
    var c = String(col || "").trim()
    if (c.startsWith("#")) {
      var hex = c.substring(1)
      if (hex.length === 3) hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
      if (hex.length >= 6) {
        var r = parseInt(hex.substr(0, 2), 16) || 0
        var g = parseInt(hex.substr(2, 2), 16) || 0
        var b = parseInt(hex.substr(4, 2), 16) || 0
        var yiq = (r * 299 + g * 587 + b * 114) / 1000
        return yiq < 128
      }
    }
    return true
  }

  function hexToRgba(col, a) {
    var c = String(col || "#000000").trim()
    if (c.startsWith("#")) {
      var hex = c.substring(1)
      if (hex.length === 3) hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
      if (hex.length >= 6) {
        var r = parseInt(hex.substr(0, 2), 16) || 0
        var g = parseInt(hex.substr(2, 2), 16) || 0
        var b = parseInt(hex.substr(4, 2), 16) || 0
        return "rgba(" + r + "," + g + "," + b + "," + a + ")"
      }
    }
    return c
  }

  function addRecentColor(col) {
    if (!col) return
    var hex = String(col).toUpperCase()
    var list = (root.recentColors || []).slice()
    var idx = list.indexOf(hex)
    if (idx !== -1) list.splice(idx, 1)
    list.unshift(hex)
    if (list.length > 8) list = list.slice(0, 8)
    root.recentColors = list
  }

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

  function applyPickedColor(hex) {
    if (!hex) return
    var col = String(hex)
    root.currentColor = col
    root.addRecentColor(col)
    if (root.activeColorTarget === "fill") {
      root.setSelectedFillColor(col)
      root.activeColorTarget = "stroke"
      return
    }
    if (root.activeColorTarget === "shadow") {
      root.setSelectedShadowColor(col)
      root.activeColorTarget = "stroke"
      return
    }
    if (root.activeColorTarget === "halo") {
      root.setSelectedTextHaloColor(col)
      root.activeColorTarget = "stroke"
      return
    }
    if (root.activeColorTarget === "box") {
      root.setSelectedTextBoxColor(col)
      root.activeColorTarget = "stroke"
      return
    }
    if (root.activeColorTarget === "spotlightBorder") {
      root.setSelectedSpotlightBorderColor(col)
      root.activeColorTarget = "stroke"
      return
    }
    if (root.activeColorTarget === "spotlightDim") {
      root.setUnifiedSpotlightDimColor(col)
      root.activeColorTarget = "stroke"
      return
    }
    root.setSelectedStrokeColor(col)
  }

  onCurrentColorChanged: {
    root.applyPickedColor(root.currentColor)
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
          if (act.tool === "text") {
            cloned.size = newSz
          } else {
            cloned.width = newSz
            if (newSz === 0 && (cloned.tool === "rect" || cloned.tool === "circle")) {
              var fm = cloned.fillMode || (cloned.filled ? "semi" : "none")
              if (fm === "none") {
                cloned.fillMode = "semi"
                cloned.filled = true
                root.fillMode = "semi"
                root.fillShape = true
              }
            }
          }
          next[root.selectedActionIndex] = cloned
          root.actions = next
          annotationCanvas.requestPaint()
        }
      }
    }
  }

  onFillModeChanged: {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && (act.tool === "rect" || act.tool === "circle")) {
        var curFm = act.fillMode || (act.filled ? "semi" : "none")
        if (curFm !== root.fillMode) {
          root.pushUndoState()
          var next = root.actions.slice()
          var cloned = JSON.parse(JSON.stringify(act))
          cloned.fillMode = root.fillMode
          cloned.filled = (root.fillMode !== "none")
          if (root.fillMode === "none" && (cloned.width === 0 || typeof cloned.width === "undefined")) {
            cloned.width = 2
            root.strokeWidth = 2
          }
          next[root.selectedActionIndex] = cloned
          root.actions = next
          annotationCanvas.requestPaint()
        }
      }
    }
  }

  onFillColorChanged: {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && (act.tool === "rect" || act.tool === "circle")) {
        var curFc = act.fillColor || act.color
        if (String(curFc) !== String(root.fillColor)) {
          root.pushUndoState()
          var next = root.actions.slice()
          var cloned = JSON.parse(JSON.stringify(act))
          cloned.fillColor = String(root.fillColor)
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

  // Shape stroke presets (includes 0 for borderless filled shapes)
  readonly property var shapeStrokeSizes: [
    { label: "0", val: 0, tip: "No border (0px)" },
    { label: "2", val: 2, tip: "Thin border (2px)" },
    { label: "4", val: 4, tip: "Medium border (4px)" },
    { label: "8", val: 8, tip: "Thick border (8px)" },
    { label: "14", val: 14, tip: "Extra thick border (14px)" }
  ]

  // Shape fill mode presets
  readonly property var fillModes: [
    { id: "none", label: "None", icon: "□", tip: "No fill (outline only)" },
    { id: "semi", label: "Tint", icon: "▦", tip: "Tinted translucent fill (25%)" },
    { id: "solid", label: "Solid", icon: "⬛", tip: "Solid opaque fill (100%)" }
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

  // Drop shadow presets
  readonly property var shadowBlurPresets: [
    { label: "4", val: 4, tip: "Soft tight blur (4px)" },
    { label: "8", val: 8, tip: "Standard blur (8px)" },
    { label: "14", val: 14, tip: "Deep spread (14px)" },
    { label: "24", val: 24, tip: "Ambient glow (24px)" }
  ]

  readonly property var shadowOpacityPresets: [
    { label: "25%", val: 0.25, tip: "Subtle (25%)" },
    { label: "45%", val: 0.45, tip: "Natural (45%)" },
    { label: "70%", val: 0.70, tip: "Prominent (70%)" },
    { label: "90%", val: 0.90, tip: "Heavy (90%)" }
  ]

  readonly property var shadowOffsetPresets: [
    { label: "Down", ox: 0, oy: 4, tip: "Natural bottom drop (0, 4)" },
    { label: "Deep", ox: 3, oy: 6, tip: "Angled bottom-right (3, 6)" },
    { label: "Glow", ox: 0, oy: 0, tip: "Uniform ambient glow (0, 0)" }
  ]

  readonly property var shadowColorPresets: [
    "#000000", "#0F172A", "#3B82F6", "#EF4444", "#EAB308", "#FFFFFF"
  ]

  // Shape & stroke presets
  readonly property var cornerRadiusPresets: [
    { label: "0", val: 0, tip: "Sharp corners (0px)" },
    { label: "6", val: 6, tip: "Subtle rounded (6px)" },
    { label: "12", val: 12, tip: "Smooth rounded (12px)" },
    { label: "20", val: 20, tip: "Pill / soft rounded (20px)" }
  ]

  readonly property var dashStylePresets: [
    { id: "solid", label: "──", tip: "Solid continuous line" },
    { id: "dashed", label: "╌╌", tip: "Dashed line pattern" },
    { id: "dotted", label: "┈", tip: "Dotted line pattern" }
  ]

  readonly property var elementOpacityPresets: [
    { label: "100%", val: 1.0, tip: "Full opacity (100%)" },
    { label: "80%", val: 0.8, tip: "Slightly translucent (80%)" },
    { label: "60%", val: 0.6, tip: "Translucent (60%)" },
    { label: "35%", val: 0.35, tip: "Ghost / faint (35%)" }
  ]

  readonly property var arrowHeadPresets: [
    { id: "end", label: "▶", tip: "Arrow head at tip" },
    { id: "both", label: "◀▶", tip: "Arrow heads at both ends" },
    { id: "none", label: "──", tip: "Plain line without heads" }
  ]

  readonly property var fontFamilies: [
    { id: "sans", label: "Sans", tip: "Clean sans-serif font" },
    { id: "mono", label: "Mono", tip: "Code monospace font" },
    { id: "serif", label: "Serif", tip: "Editorial serif font" }
  ]

  readonly property var textAlignPresets: [
    { id: "left", label: "⇤", tip: "Left aligned" },
    { id: "center", label: "⇥⇤", tip: "Center aligned" },
    { id: "right", label: "⇥", tip: "Right aligned" }
  ]

  readonly property var stampSizePresets: [
    { id: "S", label: "S", r: 14, tip: "Small stamp (14px)" },
    { id: "M", label: "M", r: 18, tip: "Medium stamp (18px)" },
    { id: "L", label: "L", r: 24, tip: "Large stamp (24px)" },
    { id: "XL", label: "XL", r: 32, tip: "Extra-large stamp (32px)" }
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
    root.dropShadow = false
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
      "magnifier": "🔍 Magnifier",
      "spotlight": "🔦 Spotlight",
      "text": "🔤 Text",
      "stamp": "① Stamp"
    }
    return map[act.tool] || act.tool
  }

  function getActionBounds(act) {
    if (!act) return { x: 0, y: 0, width: 0, height: 0 }
    if (act.tool === "magnifier" && act.start) {
      var mr = (act.radius !== undefined) ? Number(act.radius) : 50
      return {
        x: act.start.x - mr,
        y: act.start.y - mr,
        width: mr * 2,
        height: mr * 2
      }
    }
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
    } else if (act.tool === "text" && act.pos && act.text) {
      var fs = act.size || 18
      var padX = act.box ? Math.round(fs * 0.45) : 4
      var padY = act.box ? Math.round(fs * 0.25) : 2
      var rawT = act.text || ""
      var estCharWidth = fs * (act.textTransform === "uppercase" ? 0.68 : 0.58)
      var estWidth = Math.max(24, Math.round(rawT.length * estCharWidth) + padX * 2)
      var estHeight = Math.round(fs * 1.3) + padY * 2
      var bx = act.pos.x - padX
      if (act.textAlign === "center") {
        bx = act.pos.x - estWidth / 2
      } else if (act.textAlign === "right") {
        bx = act.pos.x - estWidth + padX
      }
      return {
        x: bx,
        y: act.pos.y - padY,
        width: estWidth,
        height: estHeight
      }
    } else if (act.tool === "stamp" && act.pos) {
      var sr = (act.radius !== undefined) ? Number(act.radius) : 18
      if (act.radius !== undefined) sr = Number(act.radius)
      else if (act.stampSize === "S") sr = 14
      else if (act.stampSize === "M") sr = 18
      else if (act.stampSize === "L") sr = 24
      else if (act.stampSize === "XL") sr = 32
      else sr = Math.max(14, (act.width || 4) * 3)
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

      var testPt = { x: pt.x, y: pt.y }
      if (act.rotation) {
        var bRot = root.getActionBounds(act)
        var cRotX = bRot.x + bRot.width / 2
        var cRotY = bRot.y + bRot.height / 2
        var rad = -act.rotation * Math.PI / 180
        var cosA = Math.cos(rad)
        var sinA = Math.sin(rad)
        var dRotX = pt.x - cRotX
        var dRotY = pt.y - cRotY
        testPt.x = cRotX + dRotX * cosA - dRotY * sinA
        testPt.y = cRotY + dRotX * sinA + dRotY * cosA
      }

      if (act.tool === "text" && act.pos) {
        var tb = root.getActionBounds(act)
        if (testPt.x >= tb.x - 4 && testPt.x <= tb.x + tb.width + 4 && testPt.y >= tb.y - 4 && testPt.y <= tb.y + tb.height + 4) {
          return i
        }
      } else if (act.tool === "stamp" && act.pos) {
        var sr = Math.max(14, (act.width || 4) * 3) + 6
        if (Math.hypot(act.pos.x - testPt.x, act.pos.y - testPt.y) <= sr) {
          return i
        }
      } else if ((act.tool === "line" || act.tool === "arrow") && act.start && act.end) {
        var l2 = Math.pow(act.end.x - act.start.x, 2) + Math.pow(act.end.y - act.start.y, 2)
        if (l2 === 0) {
          if (Math.hypot(act.start.x - testPt.x, act.start.y - testPt.y) <= 16) return i
        } else {
          var t = Math.max(0, Math.min(1, ((testPt.x - act.start.x) * (act.end.x - act.start.x) + (testPt.y - act.start.y) * (act.end.y - act.start.y)) / l2))
          var projX = act.start.x + t * (act.end.x - act.start.x)
          var projY = act.start.y + t * (act.end.y - act.start.y)
          if (Math.hypot(testPt.x - projX, testPt.y - projY) <= Math.max(12, (act.width || 4) + 6)) return i
        }
      } else if ((act.tool === "circle" || (act.tool === "spotlight" && act.shape === "circle")) && act.start && act.end) {
        var ebb = root.getActionBounds(act)
        var ecx = ebb.x + ebb.width / 2
        var ecy = ebb.y + ebb.height / 2
        var erx = Math.max(1, ebb.width / 2)
        var ery = Math.max(1, ebb.height / 2)
        var enx = (testPt.x - ecx) / erx
        var eny = (testPt.y - ecy) / ery
        var eDist = Math.hypot(enx, eny)
        var eSolid = act.tool === "spotlight" || act.filled || (act.fillMode && act.fillMode !== "none")
        if (eSolid) {
          if (eDist <= 1.05) return i
        } else {
          var avgR = (erx + ery) / 2
          var pixDist = Math.abs(eDist - 1.0) * avgR
          if (pixDist <= Math.max(10, (act.width || 4) + 6)) return i
        }
      } else if (act.start && act.end) {
        var bb = root.getActionBounds(act)
        var isSolid = act.filled || act.tool === "blur" || act.tool === "pixelate" || act.tool === "block_highlight" || act.tool === "magnifier" || act.tool === "spotlight"
        if (isSolid) {
          if (testPt.x >= bb.x - 4 && testPt.x <= bb.x + bb.width + 4 && testPt.y >= bb.y - 4 && testPt.y <= bb.y + bb.height + 4) {
            return i
          }
        } else {
          if (testPt.x >= bb.x - 10 && testPt.x <= bb.x + bb.width + 10 && testPt.y >= bb.y - 10 && testPt.y <= bb.y + bb.height + 10) {
            if (bb.width <= 30 || bb.height <= 30) return i
            var dL = Math.abs(testPt.x - bb.x)
            var dR = Math.abs(testPt.x - (bb.x + bb.width))
            var dT = Math.abs(testPt.y - bb.y)
            var dB = Math.abs(testPt.y - (bb.y + bb.height))
            var minD = Math.min(Math.min(dL, dR), Math.min(dT, dB))
            if (minD <= 12) return i
          }
        }
      } else if (act.points && act.points.length > 0) {
        var thresh = Math.max(12, (act.width || 4) * (act.tool === "highlighter" ? 2 : 1) + 4)
        for (var p = 0; p < act.points.length; p++) {
          if (Math.hypot(act.points[p].x - testPt.x, act.points[p].y - testPt.y) <= thresh) {
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
      if (typeof act.width !== "undefined") root.strokeWidth = act.width
      if (act.size && act.tool === "text") {
        if (act.size <= 16) root.strokeWidth = 2
        else if (act.size <= 22) root.strokeWidth = 4
        else if (act.size <= 32) root.strokeWidth = 8
        else root.strokeWidth = 14
      }
      if (typeof act.box !== "undefined") root.textBox = Boolean(act.box)
      if (act.tool === "rect" || act.tool === "circle") {
        var fm = act.fillMode || (act.filled ? "semi" : "none")
        root.fillMode = fm
        root.fillShape = (fm !== "none")
        root.fillColor = act.fillColor || act.color || root.currentColor
      }
      if (typeof act.radius !== "undefined") root.rectCornerRadius = act.radius
      if (typeof act.dashStyle !== "undefined") root.strokeDashStyle = act.dashStyle
      if (typeof act.shadow !== "undefined") {
        root.dropShadow = Boolean(act.shadow)
        if (act.shadowColor) root.dropShadowColor = act.shadowColor
        if (typeof act.shadowBlur !== "undefined") root.dropShadowBlur = act.shadowBlur
        if (typeof act.shadowOpacity !== "undefined") root.dropShadowOpacity = act.shadowOpacity
        if (typeof act.shadowOffsetX !== "undefined") root.dropShadowOffsetX = act.shadowOffsetX
        if (typeof act.shadowOffsetY !== "undefined") root.dropShadowOffsetY = act.shadowOffsetY
      } else {
        root.dropShadow = false
      }
      if (act.tool === "spotlight") {
        if (act.shape) root.spotlightShape = act.shape
        if (typeof act.radius !== "undefined") root.spotlightRadius = act.radius
        if (typeof act.zoom !== "undefined") root.spotlightZoom = act.zoom
        if (typeof act.borderWidth !== "undefined") root.spotlightBorderWidth = act.borderWidth
        if (act.borderColor) root.spotlightBorderColor = act.borderColor
        if (typeof act.dimOpacity !== "undefined") root.spotlightDimOpacity = act.dimOpacity
        if (act.dimColor) root.spotlightDimColor = act.dimColor
      }
    } else {
      root.selectedActionIndex = -1
    }
    annotationCanvas.requestPaint()
  }

  function deleteSelectedAction() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (act && act.locked) {
      root.showFeedback("🔒 Element is locked. Unlock to delete.")
      return
    }
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
    cloned.locked = false
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

  function setSelectedStrokeColor(col) {
    root.currentColor = col
    root.addRecentColor(col)
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (!act) return
      root.pushUndoState()
      var next = root.actions.slice()
      var cloned = JSON.parse(JSON.stringify(act))
      cloned.color = String(col)
      if (!cloned.fillColor) cloned.fillColor = String(col)
      next[root.selectedActionIndex] = cloned
      root.actions = next
      annotationCanvas.requestPaint()
    }
    root.showFeedback("Color: " + col)
  }

  function setSelectedColor(col) {
    root.setSelectedStrokeColor(col)
  }

  function setSelectedStrokeWidth(w) {
    root.strokeWidth = w
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (!act) return
      root.pushUndoState()
      var next = root.actions.slice()
      var cloned = JSON.parse(JSON.stringify(act))
      if (cloned.tool === "text") {
        cloned.size = Math.max(14, w * 4)
      } else {
        cloned.width = w
        if (w === 0 && (cloned.tool === "rect" || cloned.tool === "circle")) {
          var fm = cloned.fillMode || (cloned.filled ? "semi" : "none")
          if (fm === "none") {
            cloned.fillMode = "semi"
            cloned.filled = true
            root.fillMode = "semi"
            root.fillShape = true
          }
        }
      }
      next[root.selectedActionIndex] = cloned
      root.actions = next
      annotationCanvas.requestPaint()
    }
    root.showFeedback(w === 0 ? "Stroke: None (borderless)" : ("Stroke: " + w + "px"))
  }

  function setSelectedWidth(w) {
    root.setSelectedStrokeWidth(w)
  }

  function setSelectedFillMode(mode) {
    root.fillMode = mode
    root.fillShape = (mode !== "none")
    if (mode === "none" && root.strokeWidth === 0) {
      root.strokeWidth = 2
    }
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && (act.tool === "rect" || act.tool === "circle")) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.fillMode = mode
        cloned.filled = (mode !== "none")
        if (mode === "none" && (cloned.width === 0 || typeof cloned.width === "undefined")) {
          cloned.width = 2
          root.strokeWidth = 2
        }
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    var label = mode === "none" ? "Outline only (no fill)" : (mode === "semi" ? "Tinted fill (25%)" : "Solid fill (100%)")
    root.showFeedback("Fill: " + label)
  }

  function toggleSelectedFill() {
    var curMode = "none"
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) curMode = act.fillMode || (act.filled ? "semi" : "none")
    } else {
      curMode = root.fillMode
    }
    var nextMode = curMode === "none" ? "semi" : (curMode === "semi" ? "solid" : "none")
    root.setSelectedFillMode(nextMode)
  }

  function setSelectedFillColor(col) {
    root.fillColor = col
    root.addRecentColor(col)
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && (act.tool === "rect" || act.tool === "circle")) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.fillColor = String(col)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Fill color: " + col)
  }

  function toggleSelectedTextBox() {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.box = !Boolean(cloned.box)
        if (cloned.box && !cloned.boxColor) cloned.boxColor = root.textBoxColor || "#0F172A"
        if (cloned.box && (cloned.boxOpacity === undefined)) cloned.boxOpacity = (root.textBoxOpacity !== undefined ? root.textBoxOpacity : 0.88)
        if (cloned.box && (cloned.boxRadius === undefined)) cloned.boxRadius = (root.textBoxRadius !== undefined ? root.textBoxRadius : 6)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        root.textBox = cloned.box
        annotationCanvas.requestPaint()
        root.showFeedback(cloned.box ? "■ Card Box enabled" : "Card Box disabled")
      }
    } else {
      root.textBox = !root.textBox
      root.showFeedback(root.textBox ? "■ Card Box enabled default" : "Card Box disabled default")
    }
  }

  function flipSelectedArrow() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (act && (act.tool === "arrow" || act.tool === "line") && act.start && act.end) {
      root.pushUndoState()
      var next = root.actions.slice()
      var cloned = JSON.parse(JSON.stringify(act))
      var tmp = cloned.start
      cloned.start = cloned.end
      cloned.end = tmp
      next[root.selectedActionIndex] = cloned
      root.actions = next
      annotationCanvas.requestPaint()
      root.showFeedback("⇄ Direction flipped")
    }
  }

  function setSelectedStampType(typeId) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (act && act.tool === "stamp") {
      root.pushUndoState()
      var next = root.actions.slice()
      var cloned = JSON.parse(JSON.stringify(act))
      cloned.stampType = typeId
      next[root.selectedActionIndex] = cloned
      root.actions = next
      root.currentStamp = typeId
      annotationCanvas.requestPaint()
      root.showFeedback("Stamp changed: " + typeId)
    }
  }

  function setSelectedPixelSize(pxSize) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (act && act.tool === "pixelate") {
      root.pushUndoState()
      var next = root.actions.slice()
      var cloned = JSON.parse(JSON.stringify(act))
      cloned.pixelSize = pxSize
      next[root.selectedActionIndex] = cloned
      root.actions = next
      annotationCanvas.requestPaint()
      root.showFeedback("Pixel block: " + pxSize + "px")
    }
  }

  function formatColorWithAlpha(hexColor, alpha) {
    var a = (typeof alpha === "number" && !isNaN(alpha)) ? Math.max(0, Math.min(1, alpha)) : 0.45
    var c = String(hexColor || "#000000").trim()
    if (c.indexOf("#") === 0) {
      var hex = c.slice(1)
      if (hex.length === 3) {
        hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
      }
      if (hex.length >= 6) {
        var r = parseInt(hex.substr(0, 2), 16) || 0
        var g = parseInt(hex.substr(2, 2), 16) || 0
        var b = parseInt(hex.substr(4, 2), 16) || 0
        return "rgba(" + r + "," + g + "," + b + "," + a + ")"
      }
    }
    return c
  }

  function toggleSelectedShadow() {
    var curState = false
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) curState = Boolean(act.shadow)
    } else {
      curState = root.dropShadow
    }
    var nextState = !curState
    root.dropShadow = nextState
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var sAct = root.actions[root.selectedActionIndex]
      if (sAct) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(sAct))
        cloned.shadow = nextState
        if (nextState) {
          cloned.shadowColor = cloned.shadowColor || String(root.dropShadowColor)
          cloned.shadowBlur = (cloned.shadowBlur !== undefined ? cloned.shadowBlur : root.dropShadowBlur)
          cloned.shadowOpacity = (cloned.shadowOpacity !== undefined ? cloned.shadowOpacity : root.dropShadowOpacity)
          cloned.shadowOffsetX = (cloned.shadowOffsetX !== undefined ? cloned.shadowOffsetX : root.dropShadowOffsetX)
          cloned.shadowOffsetY = (cloned.shadowOffsetY !== undefined ? cloned.shadowOffsetY : root.dropShadowOffsetY)
        }
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback(nextState ? "◩ Drop Shadow enabled" : "Drop Shadow disabled")
  }

  function setSelectedShadowBlur(blur) {
    root.dropShadowBlur = blur
    root.dropShadow = true
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.shadow = true
        cloned.shadowBlur = blur
        cloned.shadowColor = cloned.shadowColor || String(root.dropShadowColor)
        cloned.shadowOpacity = (cloned.shadowOpacity !== undefined ? cloned.shadowOpacity : root.dropShadowOpacity)
        cloned.shadowOffsetX = (cloned.shadowOffsetX !== undefined ? cloned.shadowOffsetX : root.dropShadowOffsetX)
        cloned.shadowOffsetY = (cloned.shadowOffsetY !== undefined ? cloned.shadowOffsetY : root.dropShadowOffsetY)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Shadow Blur: " + blur + "px")
  }

  function setSelectedShadowOpacity(op) {
    root.dropShadowOpacity = op
    root.dropShadow = true
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.shadow = true
        cloned.shadowOpacity = op
        cloned.shadowColor = cloned.shadowColor || String(root.dropShadowColor)
        cloned.shadowBlur = (cloned.shadowBlur !== undefined ? cloned.shadowBlur : root.dropShadowBlur)
        cloned.shadowOffsetX = (cloned.shadowOffsetX !== undefined ? cloned.shadowOffsetX : root.dropShadowOffsetX)
        cloned.shadowOffsetY = (cloned.shadowOffsetY !== undefined ? cloned.shadowOffsetY : root.dropShadowOffsetY)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Shadow Opacity: " + Math.round(op * 100) + "%")
  }

  function setSelectedShadowOffset(ox, oy) {
    root.dropShadowOffsetX = ox
    root.dropShadowOffsetY = oy
    root.dropShadow = true
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.shadow = true
        cloned.shadowOffsetX = ox
        cloned.shadowOffsetY = oy
        cloned.shadowColor = cloned.shadowColor || String(root.dropShadowColor)
        cloned.shadowBlur = (cloned.shadowBlur !== undefined ? cloned.shadowBlur : root.dropShadowBlur)
        cloned.shadowOpacity = (cloned.shadowOpacity !== undefined ? cloned.shadowOpacity : root.dropShadowOpacity)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Shadow Offset: (" + ox + ", " + oy + ")")
  }

  function setSelectedShadowColor(col) {
    root.dropShadowColor = col
    root.dropShadow = true
    root.addRecentColor(col)
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.shadow = true
        cloned.shadowColor = String(col)
        cloned.shadowBlur = (cloned.shadowBlur !== undefined ? cloned.shadowBlur : root.dropShadowBlur)
        cloned.shadowOpacity = (cloned.shadowOpacity !== undefined ? cloned.shadowOpacity : root.dropShadowOpacity)
        cloned.shadowOffsetX = (cloned.shadowOffsetX !== undefined ? cloned.shadowOffsetX : root.dropShadowOffsetX)
        cloned.shadowOffsetY = (cloned.shadowOffsetY !== undefined ? cloned.shadowOffsetY : root.dropShadowOffsetY)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Shadow color: " + col)
  }

  function setSelectedCornerRadius(val) {
    root.rectCornerRadius = val
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "rect") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.radius = val
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Corner radius: " + val + "px")
  }

  function setSelectedDashStyle(style) {
    root.strokeDashStyle = style
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.dashStyle = style
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    var lbl = style === "dashed" ? "Dashed" : (style === "dotted" ? "Dotted" : "Solid")
    root.showFeedback("Stroke: " + lbl)
  }

  function setSelectedOpacity(val) {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.opacity = val
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        root.showFeedback("Opacity: " + Math.round(val * 100) + "%")
      }
    }
  }

  function setSelectedArrowHeadStyle(val) {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && (act.tool === "arrow" || act.tool === "line")) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.headStyle = val
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        var lbl = val === "both" ? "Double Arrow (◀▶)" : (val === "none" ? "Plain Line (──)" : "Single Arrow (▶)")
        root.showFeedback("Heads: " + lbl)
      }
    }
  }

  function setSelectedFontFamily(fam) {
    root.defaultFontFamily = fam
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.fontFamily = fam
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        root.showFeedback("Font: " + fam)
      }
    } else {
      root.showFeedback("Font set: " + fam)
    }
  }

  function toggleSelectedFontWeight() {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.fontWeight = (cloned.fontWeight === "normal") ? "bold" : "normal"
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        root.showFeedback(cloned.fontWeight === "bold" ? "Bold font" : "Regular font")
      }
    }
  }

  function setSelectedTextAlign(align) {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.textAlign = align
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        root.showFeedback("Align: " + align)
      }
    }
  }

  function toggleSelectedItalic() {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.italic = !Boolean(cloned.italic)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        root.textItalic = cloned.italic
        annotationCanvas.requestPaint()
        root.showFeedback(cloned.italic ? "Italic font" : "Normal slant")
      }
    } else {
      root.textItalic = !root.textItalic
      root.showFeedback(root.textItalic ? "Italic font default" : "Normal slant default")
    }
  }

  function toggleSelectedUnderline() {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.underline = !Boolean(cloned.underline)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        root.textUnderline = cloned.underline
        annotationCanvas.requestPaint()
        root.showFeedback(cloned.underline ? "Underline enabled" : "Underline disabled")
      }
    } else {
      root.textUnderline = !root.textUnderline
      root.showFeedback(root.textUnderline ? "Underline enabled default" : "Underline disabled default")
    }
  }

  function toggleSelectedStrikeout() {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.strikeout = !Boolean(cloned.strikeout)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        root.textStrikeout = cloned.strikeout
        annotationCanvas.requestPaint()
        root.showFeedback(cloned.strikeout ? "Strikethrough enabled" : "Strikethrough disabled")
      }
    } else {
      root.textStrikeout = !root.textStrikeout
      root.showFeedback(root.textStrikeout ? "Strikethrough enabled default" : "Strikethrough disabled default")
    }
  }

  function setSelectedTextTransform(t) {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.textTransform = (cloned.textTransform === t) ? "none" : t
        next[root.selectedActionIndex] = cloned
        root.actions = next
        root.textTransform = cloned.textTransform
        annotationCanvas.requestPaint()
        root.showFeedback("Text case: " + (cloned.textTransform || "normal"))
      }
    } else {
      root.textTransform = (root.textTransform === t) ? "none" : t
      root.showFeedback("Text case default: " + (root.textTransform || "normal"))
    }
  }

  function setSelectedTextHaloColor(col) {
    root.textHaloColor = col
    root.textHalo = true
    root.addRecentColor(col)
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.halo = true
        cloned.haloColor = String(col)
        if (cloned.haloWidth === undefined) cloned.haloWidth = root.textHaloWidth || 3
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Outline color: " + col)
  }

  function setSelectedTextHaloWidth(w) {
    root.textHaloWidth = w
    root.textHalo = true
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.haloWidth = w
        cloned.halo = true
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
  }

  function setSelectedTextBoxColor(col) {
    root.textBoxColor = col
    root.textBox = true
    root.addRecentColor(col)
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.box = true
        cloned.boxColor = String(col)
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
      }
    }
    root.showFeedback("Card color: " + col)
  }

  function editSelectedText() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act || act.tool !== "text") return
    root.textEditActionIndex = root.selectedActionIndex
    root.textInputPos = Qt.point(act.pos.x, act.pos.y)
    root.textInputDraft = act.text || ""
    root.textInputActive = true
  }

  function setSelectedStampSize(sz) {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "stamp") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.stampSize = sz
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        root.showFeedback("Stamp size: " + sz)
      }
    }
  }

  function stepSelectedStampNum(delta) {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "stamp" && act.stampType === "number") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        var nextNum = Math.max(1, (cloned.num || 1) + delta)
        cloned.num = nextNum
        next[root.selectedActionIndex] = cloned
        root.actions = next
        annotationCanvas.requestPaint()
        root.showFeedback("Stamp number: " + nextNum)
      }
    }
  }

  function alignSelectedCenterH() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    var b = root.getActionBounds(act)
    var imgW = (baseImage.implicitWidth > 0 ? baseImage.implicitWidth : 800)
    var targetCenterX = imgW / 2
    var curCenterX = b.x + b.width / 2
    var dx = targetCenterX - curCenterX
    root.nudgeSelected(dx, 0)
    root.showFeedback("⯐ Centered horizontally")
  }

  function alignSelectedCenterV() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    var b = root.getActionBounds(act)
    var imgH = (baseImage.implicitHeight > 0 ? baseImage.implicitHeight : 600)
    var targetCenterY = imgH / 2
    var curCenterY = b.y + b.height / 2
    var dy = targetCenterY - curCenterY
    root.nudgeSelected(0, dy)
    root.showFeedback("⯐ Centered vertically")
  }

  function flipSelectedH() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    var b = root.getActionBounds(act)
    var cx = b.x + b.width / 2
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    if (cloned.start && cloned.end) {
      var sX = 2 * cx - cloned.start.x
      var eX = 2 * cx - cloned.end.x
      cloned.start.x = sX
      cloned.end.x = eX
    } else if (cloned.points && cloned.points.length > 0) {
      for (var i = 0; i < cloned.points.length; i++) {
        cloned.points[i].x = 2 * cx - cloned.points[i].x
      }
    }
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("⇄ Flipped horizontally")
  }

  function flipSelectedV() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    var b = root.getActionBounds(act)
    var cy = b.y + b.height / 2
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    if (cloned.start && cloned.end) {
      var sY = 2 * cy - cloned.start.y
      var eY = 2 * cy - cloned.end.y
      cloned.start.y = sY
      cloned.end.y = eY
    } else if (cloned.points && cloned.points.length > 0) {
      for (var j = 0; j < cloned.points.length; j++) {
        cloned.points[j].y = 2 * cy - cloned.points[j].y
      }
    }
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("⇅ Flipped vertically")
  }

  function toggleSelectedLock() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.locked = !Boolean(cloned.locked)
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback(cloned.locked ? "🔒 Element locked" : "🔓 Element unlocked")
  }

  function setSelectedRotation(deg) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.rotation = Math.round(deg) % 360
    if (cloned.rotation < 0) cloned.rotation += 360
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
  }

  function rotateSelected(degDelta) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    root.pushUndoState()
    var curRot = act.rotation || 0
    var newRot = (curRot + degDelta) % 360
    if (newRot < 0) newRot += 360
    root.setSelectedRotation(newRot)
    root.showFeedback("↻ Rotated " + newRot + "°")
  }

  function toggleSelectedLockRatio() {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.lockRatio = !Boolean(cloned.lockRatio)
    next[root.selectedActionIndex] = cloned
    root.actions = next
    root.showFeedback(cloned.lockRatio ? "🔗 Aspect ratio locked" : "🔓 Aspect ratio unlocked")
  }

  function toggleSelectedTextHalo() {
    if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length) {
      var act = root.actions[root.selectedActionIndex]
      if (act && act.tool === "text") {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(act))
        cloned.halo = !Boolean(cloned.halo)
        if (cloned.halo && !cloned.haloColor) cloned.haloColor = root.textHaloColor || "#000000"
        if (cloned.halo && (cloned.haloWidth === undefined)) cloned.haloWidth = root.textHaloWidth || 3
        next[root.selectedActionIndex] = cloned
        root.actions = next
        root.textHalo = cloned.halo
        annotationCanvas.requestPaint()
        root.showFeedback(cloned.halo ? "Text outline enabled" : "Text outline disabled")
      }
    } else {
      root.textHalo = !root.textHalo
      root.showFeedback(root.textHalo ? "Text outline enabled default" : "Text outline disabled default")
    }
  }

  function setSelectedMagnifierZoom(z) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act || act.tool !== "magnifier") return
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.zoom = z
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
  }

  function setSelectedSpotlightShape(shape) {
    root.spotlightShape = shape
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act || act.tool !== "spotlight") return
    if (act.shape === shape) return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.shape = shape
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("Spotlight Shape: " + (shape === "circle" ? "Circle / Oval" : "Rectangle"))
  }

  function setSelectedSpotlightBorderColor(col) {
    root.spotlightBorderColor = col
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act || act.tool !== "spotlight") return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.borderColor = col
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("Spotlight Border: " + col)
  }

  function setUnifiedSpotlightDimOpacity(val) {
    root.pushUndoState()
    root.spotlightDimOpacity = val
    var next = root.actions.slice()
    var changed = false
    for (var i = 0; i < next.length; i++) {
      if (next[i] && next[i].tool === "spotlight") {
        var cl = JSON.parse(JSON.stringify(next[i]))
        cl.dimOpacity = val
        next[i] = cl
        changed = true
      }
    }
    if (changed) root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("Dim Darkness: " + Math.round(val * 100) + "%")
  }

  function setUnifiedSpotlightDimColor(col) {
    root.pushUndoState()
    root.spotlightDimColor = col
    var next = root.actions.slice()
    var changed = false
    for (var i = 0; i < next.length; i++) {
      if (next[i] && next[i].tool === "spotlight") {
        var cl = JSON.parse(JSON.stringify(next[i]))
        cl.dimColor = col
        next[i] = cl
        changed = true
      }
    }
    if (changed) root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("Dim Tint: " + col)
  }

  function modifySelectedProperty(key, val) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act) return
    if (!root.scrubStartAct) {
      root.scrubStartAct = JSON.parse(JSON.stringify(act))
    }
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned[key] = val
    if (key === "width" && cloned.tool === "text") {
      cloned.size = Math.max(10, val * 4)
    }
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
  }

  function commitSelectedProperty(key, val, feedbackLabel) {
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) {
      root.scrubStartAct = null
      return
    }
    var act = root.actions[root.selectedActionIndex]
    if (root.scrubStartAct && act) {
      if (JSON.stringify(root.scrubStartAct) !== JSON.stringify(act)) {
        root.pushSpecificUndoState(root.scrubStartAct, root.selectedActionIndex)
      }
    } else if (act && act[key] !== val) {
      root.pushUndoState()
      var next = root.actions.slice()
      var cloned = JSON.parse(JSON.stringify(act))
      cloned[key] = val
      next[root.selectedActionIndex] = cloned
      root.actions = next
      annotationCanvas.requestPaint()
    }
    root.scrubStartAct = null
    if (feedbackLabel) {
      root.showFeedback(feedbackLabel + ": " + val)
    }
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

  function computeNewBounds(startBounds, handle, dx, dy, lockRatio) {
    var minW = 10, minH = 10
    var nx = startBounds.x
    var ny = startBounds.y
    var nw = startBounds.width
    var nh = startBounds.height

    if (lockRatio && (handle === "tl" || handle === "tr" || handle === "bl" || handle === "br")) {
      var aspect = (startBounds.width > 0 && startBounds.height > 0) ? (startBounds.width / startBounds.height) : 1.0
      var d = Math.abs(dx) > Math.abs(dy) ? dx : (dy * aspect)
      if (handle === "br") {
        nw = Math.max(minW, startBounds.width + d)
        nh = Math.max(minH, nw / aspect)
      } else if (handle === "tr") {
        nw = Math.max(minW, startBounds.width + d)
        nh = Math.max(minH, nw / aspect)
        ny = startBounds.y + (startBounds.height - nh)
      } else if (handle === "bl") {
        nw = Math.max(minW, startBounds.width - d)
        nh = Math.max(minH, nw / aspect)
        nx = startBounds.x + (startBounds.width - nw)
      } else if (handle === "tl") {
        nw = Math.max(minW, startBounds.width - d)
        nh = Math.max(minH, nw / aspect)
        nx = startBounds.x + (startBounds.width - nw)
        ny = startBounds.y + (startBounds.height - nh)
      }
      return { x: nx, y: ny, width: nw, height: nh }
    }

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

    if (res.tool === "magnifier" && res.start && res.end) {
      res.radius = Math.max(15, Math.round(Math.min(newBounds.width, newBounds.height) / 2))
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
      if (root.textEditActionIndex >= 0 && root.textEditActionIndex < root.actions.length) {
        root.pushUndoState()
        var next = root.actions.slice()
        var cloned = JSON.parse(JSON.stringify(next[root.textEditActionIndex]))
        cloned.text = str
        next[root.textEditActionIndex] = cloned
        root.actions = next
        root.selectedActionIndex = root.textEditActionIndex
        annotationCanvas.requestPaint()
        root.showFeedback("Text updated")
      } else {
        root.pushUndoState()
        var act = {
          tool: "text",
          text: str,
          color: String(root.currentColor),
          size: Math.max(14, root.strokeWidth * 4),
          fontFamily: root.defaultFontFamily || "sans",
          fontWeight: root.defaultFontWeight || "bold",
          italic: Boolean(root.textItalic),
          underline: Boolean(root.textUnderline),
          strikeout: Boolean(root.textStrikeout),
          textTransform: String(root.textTransform || "none"),
          textAlign: root.defaultTextAlign || "left",
          halo: Boolean(root.textHalo),
          haloColor: String(root.textHaloColor || "#000000"),
          haloWidth: Number(root.textHaloWidth || 3),
          box: Boolean(root.textBox),
          boxColor: String(root.textBoxColor || "#0F172A"),
          boxOpacity: Number(root.textBoxOpacity !== undefined ? root.textBoxOpacity : 0.88),
          boxRadius: Number(root.textBoxRadius !== undefined ? root.textBoxRadius : 6),
          shadow: Boolean(root.dropShadow),
          shadowColor: String(root.dropShadowColor),
          shadowBlur: Number(root.dropShadowBlur),
          shadowOpacity: Number(root.dropShadowOpacity),
          shadowOffsetX: Number(root.dropShadowOffsetX),
          shadowOffsetY: Number(root.dropShadowOffsetY),
          pos: { x: root.textInputPos.x, y: root.textInputPos.y }
        }
        var next = root.actions.slice()
        next.push(act)
        root.actions = next
        root.selectedActionIndex = next.length - 1
        annotationCanvas.requestPaint()
      }
    }
    root.textEditActionIndex = -1
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
      var selAct = root.actions[root.selectedActionIndex]
      if (selAct && selAct.tool === "text") {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_B) {
          root.toggleSelectedFontWeight()
          event.accepted = true
          return
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_I) {
          root.toggleSelectedItalic()
          event.accepted = true
          return
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U) {
          root.toggleSelectedUnderline()
          event.accepted = true
          return
        } else if (event.key === Qt.Key_F2) {
          root.editSelectedText()
          event.accepted = true
          return
        }
      }

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
    } else if (event.key === Qt.Key_F) {
      root.currentTool = "spotlight"
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
    } else if (event.key === Qt.Key_Z) {
      root.currentTool = "magnifier"
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

        // External System Editor
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
                root.showFeedback("󰏫 Opened in external editor!")
              }
            }
          }
          PanelToolTip { visible: tensakuMouse.containsMouse; text: "Open in external editor" }
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
              { id: "spotlight", label: "🔦", name: "Spotlight / Focus (F)" },
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

          // Separator when stamp options are active
          Rectangle {
            visible: root.currentTool === "stamp"
            width: 1; height: Style.space(16); color: Util.alpha(Color.popups.text || Color.text, 0.15)
            anchors.verticalCenter: parent.verticalCenter
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
    // TOOLBAR ROW 3: ADVANCED TOOLS & TRANSFORMS
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(32)
      color: Util.alpha(Color.popups.background || Color.background, 0.92)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

      Flickable {
        anchors.fill: parent
        contentWidth: Math.max(width, advRowContent.width + Style.space(20))
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Row {
          id: advRowContent
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          spacing: Style.space(6)

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

          // Annotation Modes: Block Highlight & Pixelate
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
              PanelToolTip { visible: bhlMouse.containsMouse; text: "Block highlight: rectangular text highlight" }
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
              PanelToolTip { visible: pixMouse.containsMouse; text: "Mosaic pixelation privacy redact" }
            }

            // Magnifier / Loupe
            Rectangle {
              width: magBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: root.currentTool === "magnifier" ? Color.accent : (magMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
              border.width: 1; border.color: root.currentTool === "magnifier" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: magBtnTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "🔍"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Magnifier"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: root.currentTool === "magnifier" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: magMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentTool = "magnifier"
                  if (root.textInputActive) root.commitText()
                }
              }
              PanelToolTip { visible: magMouse.containsMouse; text: "Magnifier / Loupe: zoom in on fine screenshot details (Z)" }
            }

            // Spotlight / Focus
            Rectangle {
              width: spotBtnTxt.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
              color: root.currentTool === "spotlight" ? Color.accent : (spotMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
              border.width: 1; border.color: root.currentTool === "spotlight" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Row {
                id: spotBtnTxt
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "🔦"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Spotlight"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; color: root.currentTool === "spotlight" ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: spotMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentTool = "spotlight"
                  if (root.textInputActive) root.commitText()
                }
              }
              PanelToolTip { visible: spotMouse.containsMouse; text: "Spotlight: focus viewer attention on key regions (F)" }
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

              // 1. Unified Spotlight Background Dimming pass
              var activeSpotlights = []
              for (var s = 0; s < root.actions.length; s++) {
                var sa = root.actions[s]
                if (sa && sa.tool === "spotlight" && sa.start && sa.end) {
                  activeSpotlights.push(sa)
                }
              }
              if (root.currentAction && root.currentAction.tool === "spotlight" && root.currentAction.start && root.currentAction.end) {
                activeSpotlights.push(root.currentAction)
              }
              if (activeSpotlights.length > 0) {
                root.renderUnifiedSpotlightDim(ctx, activeSpotlights)
              }

              // 2. Render finished actions
              for (var i = 0; i < root.actions.length; i++) {
                if (root.textInputActive && root.textEditActionIndex === i) continue
                root.renderAction(ctx, root.actions[i])
              }

              // 3. Render live current action during drag
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
                var z = root.zoomScale > 0 ? root.zoomScale : 1.0
                root.textInputPos = Qt.point(mouse.x / z, mouse.y / z)
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
                  stampSize: "M",
                  num: root.stampCounter,
                  color: actColor,
                  width: Number(root.strokeWidth),
                  shadow: Boolean(root.dropShadow),
                  shadowColor: String(root.dropShadowColor),
                  shadowBlur: Number(root.dropShadowBlur),
                  shadowOpacity: Number(root.dropShadowOpacity),
                  shadowOffsetX: Number(root.dropShadowOffsetX),
                  shadowOffsetY: Number(root.dropShadowOffsetY),
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

              if (root.currentTool === "spotlight") {
                root.currentAction = {
                  tool: "spotlight",
                  start: pt,
                  end: pt,
                  shape: root.spotlightShape || "rect",
                  radius: (root.spotlightRadius !== undefined) ? root.spotlightRadius : 12,
                  zoom: (root.spotlightZoom !== undefined) ? root.spotlightZoom : 1.0,
                  dimOpacity: (root.spotlightDimOpacity !== undefined) ? root.spotlightDimOpacity : 0.65,
                  dimColor: root.spotlightDimColor || "#000000",
                  borderWidth: (root.spotlightBorderWidth !== undefined) ? root.spotlightBorderWidth : 2,
                  borderColor: root.spotlightBorderColor || "#FFFFFF",
                  shadow: Boolean(root.dropShadow)
                }
              } else if (root.currentTool === "magnifier") {
                root.currentAction = {
                  tool: "magnifier",
                  start: pt,
                  end: pt,
                  zoom: Number(root.magnifierZoom || 2.0),
                  radius: Number(root.magnifierRadius || 50),
                  color: actColor,
                  borderWidth: 3,
                  shadow: true,
                  shadowColor: "#000000",
                  shadowBlur: 10,
                  shadowOpacity: 0.35,
                  shadowOffsetX: 0,
                  shadowOffsetY: 4
                }
              } else if (root.currentTool === "pen" || root.currentTool === "highlighter") {
                root.currentAction = {
                  tool: root.currentTool,
                  color: actColor,
                  width: Number(root.strokeWidth),
                  dashStyle: root.strokeDashStyle,
                  shadow: Boolean(root.dropShadow && root.currentTool === "pen"),
                  shadowColor: String(root.dropShadowColor),
                  shadowBlur: Number(root.dropShadowBlur),
                  shadowOpacity: Number(root.dropShadowOpacity),
                  shadowOffsetX: Number(root.dropShadowOffsetX),
                  shadowOffsetY: Number(root.dropShadowOffsetY),
                  points: [pt]
                }
              } else {
                root.currentAction = {
                  tool: root.currentTool,
                  color: actColor,
                  fillColor: String(root.fillColor || actColor),
                  width: Number(root.strokeWidth),
                  filled: root.fillMode !== "none",
                  fillMode: root.fillMode,
                  radius: (root.currentTool === "rect" ? root.rectCornerRadius : 0),
                  dashStyle: root.strokeDashStyle,
                  headStyle: (root.currentTool === "arrow" ? "end" : (root.currentTool === "line" ? "none" : undefined)),
                  shadow: Boolean(root.dropShadow && (root.currentTool === "rect" || root.currentTool === "circle" || root.currentTool === "line" || root.currentTool === "arrow")),
                  shadowColor: String(root.dropShadowColor),
                  shadowBlur: Number(root.dropShadowBlur),
                  shadowOpacity: Number(root.dropShadowOpacity),
                  shadowOffsetX: Number(root.dropShadowOffsetX),
                  shadowOffsetY: Number(root.dropShadowOffsetY),
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
              } else if (root.currentTool === "magnifier") {
                root.currentAction.end = pt
                var curDist = Math.hypot(pt.x - root.currentAction.start.x, pt.y - root.currentAction.start.y)
                if (curDist > 10) root.currentAction.radius = Math.max(25, Math.round(curDist))
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
                } else if (act.tool === "magnifier" && act.start) {
                  if (!act.radius || act.radius < 15) act.radius = Number(root.magnifierRadius || 50)
                } else if (act.tool === "spotlight" && act.start && act.end) {
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

            onDoubleClicked: function(mouse) {
              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var pt = { x: mouse.x / z, y: mouse.y / z }
              var hitIdx = root.findActionAt(pt)
              if (hitIdx >= 0 && root.actions[hitIdx] && root.actions[hitIdx].tool === "text") {
                root.selectedActionIndex = hitIdx
                root.editSelectedText()
                mouse.accepted = true
              }
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
                } else if (act.tool === "magnifier" && act.start) {
                  if (!act.radius || act.radius < 15) act.radius = Number(root.magnifierRadius || 50)
                } else if (act.tool === "spotlight" && act.start && act.end) {
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
            readonly property var curAct: (root.textEditActionIndex >= 0 && root.actions[root.textEditActionIndex]) ? root.actions[root.textEditActionIndex] : null
            readonly property real zScale: (root.zoomScale > 0) ? root.zoomScale : 1.0
            readonly property real curFs: (curAct && curAct.size ? curAct.size : Math.max(14, root.strokeWidth * 4)) * zScale
            readonly property string curAlign: curAct ? (curAct.textAlign || "left") : (root.defaultTextAlign || "left")
            readonly property bool hasBox: curAct ? Boolean(curAct.box) : Boolean(root.textBox)
            readonly property real padX: hasBox ? Math.round(curFs * 0.45) : Style.space(4)
            readonly property real padY: hasBox ? Math.round(curFs * 0.25) : Style.space(2)

            x: {
              var basePosX = root.textInputPos.x * zScale
              if (curAlign === "center") return basePosX - width / 2
              if (curAlign === "right") return basePosX - width + padX
              return basePosX - padX
            }
            y: root.textInputPos.y * zScale - padY
            width: Math.max(Style.space(120), textEditorInput.implicitWidth + padX * 2 + Style.space(16))
            height: Math.max(curFs + padY * 2 + Style.space(4), textEditorInput.implicitHeight + padY * 2)
            radius: hasBox ? ((curAct && curAct.boxRadius !== undefined ? curAct.boxRadius : root.textBoxRadius) * zScale) : Style.space(4)
            color: hasBox ? root.hexToRgba(curAct && curAct.boxColor ? curAct.boxColor : (root.textBoxColor || "#0F172A"), curAct && curAct.boxOpacity !== undefined ? curAct.boxOpacity : (root.textBoxOpacity || 0.88)) : Util.alpha(Color.popups.background || Color.background, 0.95)
            border.width: hasBox ? 1.5 : 1
            border.color: hasBox ? (curAct && curAct.color ? curAct.color : root.currentColor) : Color.accent
            z: 20

            TextInput {
              id: textEditorInput
              anchors.fill: parent
              anchors.leftMargin: textInputOverlay.padX
              anchors.rightMargin: textInputOverlay.padX
              anchors.topMargin: textInputOverlay.padY
              anchors.bottomMargin: textInputOverlay.padY
              horizontalAlignment: {
                if (textInputOverlay.curAlign === "center") return TextInput.AlignHCenter
                if (textInputOverlay.curAlign === "right") return TextInput.AlignRight
                return TextInput.AlignLeft
              }
              verticalAlignment: TextInput.AlignTop
              color: (textInputOverlay.curAct && textInputOverlay.curAct.color) ? textInputOverlay.curAct.color : root.currentColor
              font.family: {
                var f = (textInputOverlay.curAct && textInputOverlay.curAct.fontFamily) ? textInputOverlay.curAct.fontFamily : (root.defaultFontFamily || "sans")
                if (f === "mono") return "monospace"
                if (f === "serif") return "serif"
                if (f === "sans") return Style.font.menuFamily
                return f
              }
              font.pixelSize: textInputOverlay.curFs
              font.bold: textInputOverlay.curAct ? (textInputOverlay.curAct.fontWeight !== "normal") : (root.defaultFontWeight !== "normal")
              font.italic: textInputOverlay.curAct ? Boolean(textInputOverlay.curAct.italic) : root.textItalic
              font.underline: textInputOverlay.curAct ? Boolean(textInputOverlay.curAct.underline) : root.textUnderline
              font.strikeout: textInputOverlay.curAct ? Boolean(textInputOverlay.curAct.strikeout) : root.textStrikeout
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
              if (!curAct || !selBounds || curAct.locked) return
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
                var lock = Boolean(dragStartAct && dragStartAct.lockRatio)
                var nb = root.computeNewBounds(dragStartB, activeHandle, dx, dy, lock)
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
              rotation: (selectionOverlay.curAct && selectionOverlay.curAct.rotation) || 0
              transformOrigin: Item.Center
              color: (selectionOverlay.curAct && (selectionOverlay.curAct.tool === "spotlight" || selectionOverlay.curAct.tool === "circle")) ? "transparent" : ((selectionOverlay.curAct && selectionOverlay.curAct.locked) ? Util.alpha("#F59E0B", 0.08) : Util.alpha(Color.accent, 0.08))
              border.width: 1.5
              border.color: (selectionOverlay.curAct && selectionOverlay.curAct.locked) ? "#F59E0B" : Color.accent
              z: 10

              // Move MouseArea inside box
              MouseArea {
                id: selMoveArea
                anchors.fill: parent
                cursorShape: (selectionOverlay.curAct && selectionOverlay.curAct.locked) ? Qt.ForbiddenCursor : Qt.SizeAllCursor
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
                onDoubleClicked: function(mouse) {
                  if (selectionOverlay.curAct && selectionOverlay.curAct.tool === "text") {
                    root.editSelectedText()
                    mouse.accepted = true
                  }
                }
              }

              // Reusable Handle Component
              component SelHandle: Rectangle {
                id: sHandleRoot
                property string handleName: ""
                property int cursor: Qt.ArrowCursor
                visible: !Boolean(selectionOverlay.curAct && selectionOverlay.curAct.locked)
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

            // Reusable Smart Scrubber Component
            component SmartScrubber: Rectangle {
              id: scrubRoot
              property string label: ""
              property real value: 0
              property real from: 0
              property real to: 100
              property real step: 1
              property string unit: ""
              property real sensitivity: 0.5
              property string tip: ""
              property bool integerOnly: true
              signal valueScrubbed(real val)
              signal valueCommitted(real val)

              property real dragStartX: 0
              property real dragStartVal: 0
              property bool isScrubbing: false
              property bool editMode: false

              height: Style.space(18)
              width: scrubRow.implicitWidth + Style.space(4)
              radius: Style.space(3)
              color: Util.alpha(Color.popups.text || Color.text, 0.06)
              border.width: 1
              border.color: isScrubbing ? Color.accent : (scrubMidMouse.containsMouse ? Util.alpha(Color.accent, 0.4) : Util.alpha(Color.popups.text || Color.text, 0.12))

              Row {
                id: scrubRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                // Step Down [-]
                Rectangle {
                  width: Style.space(14); height: Style.space(18); radius: Style.space(3)
                  color: decM.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                  Text { text: "−"; font.pixelSize: Style.space(7.5); font.bold: true; color: Color.popups.text || Color.text; anchors.centerIn: parent }
                  MouseArea {
                    id: decM
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var nVal = Math.max(scrubRoot.from, scrubRoot.value - scrubRoot.step)
                      if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                      scrubRoot.value = nVal
                      scrubRoot.valueScrubbed(nVal)
                      scrubRoot.valueCommitted(nVal)
                    }
                  }
                }

                // Middle Badge (Drag to scrub, double click to type)
                Rectangle {
                  id: midBadge
                  height: Style.space(18)
                  width: Math.max(Style.space(36), valLabel.implicitWidth + Style.space(8))
                  color: scrubRoot.isScrubbing ? Util.alpha(Color.accent, 0.18) : (scrubMidMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")

                  Text {
                    id: valLabel
                    visible: !scrubRoot.editMode
                    anchors.centerIn: parent
                    text: (scrubRoot.label ? (scrubRoot.label + ": ") : "") + (scrubRoot.integerOnly ? Math.round(scrubRoot.value) : scrubRoot.value.toFixed(1)) + scrubRoot.unit
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(6.8)
                    font.bold: true
                    color: scrubRoot.isScrubbing ? Color.accent : (Color.popups.text || Color.text)
                  }

                  TextInput {
                    id: inlineInput
                    visible: scrubRoot.editMode
                    anchors.fill: parent
                    anchors.margins: 1
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(6.8)
                    font.bold: true
                    color: Color.accent
                    selectByMouse: true
                    onAccepted: {
                      var num = parseFloat(text)
                      if (!isNaN(num)) {
                        var clamped = Math.max(scrubRoot.from, Math.min(scrubRoot.to, num))
                        if (scrubRoot.integerOnly) clamped = Math.round(clamped)
                        scrubRoot.value = clamped
                        scrubRoot.valueScrubbed(clamped)
                        scrubRoot.valueCommitted(clamped)
                      }
                      scrubRoot.editMode = false
                    }
                    onActiveFocusChanged: {
                      if (!activeFocus && scrubRoot.editMode) {
                        scrubRoot.editMode = false
                      }
                    }
                  }

                  MouseArea {
                    id: scrubMidMouse
                    anchors.fill: parent
                    enabled: !scrubRoot.editMode
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor

                    onPressed: function(mouse) {
                      scrubRoot.dragStartX = mouse.x
                      scrubRoot.dragStartVal = scrubRoot.value
                      scrubRoot.isScrubbing = true
                    }
                    onPositionChanged: function(mouse) {
                      if (pressed) {
                        var dx = mouse.x - scrubRoot.dragStartX
                        var delta = dx * scrubRoot.step * scrubRoot.sensitivity * 0.25
                        var nVal = Math.max(scrubRoot.from, Math.min(scrubRoot.to, scrubRoot.dragStartVal + delta))
                        if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                        scrubRoot.value = nVal
                        scrubRoot.valueScrubbed(nVal)
                      }
                    }
                    onReleased: function() {
                      if (scrubRoot.isScrubbing) {
                        scrubRoot.isScrubbing = false
                        scrubRoot.valueCommitted(scrubRoot.value)
                      }
                    }
                    onDoubleClicked: {
                      scrubRoot.editMode = true
                      inlineInput.text = String(scrubRoot.integerOnly ? Math.round(scrubRoot.value) : scrubRoot.value.toFixed(1))
                      inlineInput.forceActiveFocus()
                      inlineInput.selectAll()
                    }
                  }
                }

                // Step Up [+]
                Rectangle {
                  width: Style.space(14); height: Style.space(18); radius: Style.space(3)
                  color: incM.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                  Text { text: "+"; font.pixelSize: Style.space(7.5); font.bold: true; color: Color.popups.text || Color.text; anchors.centerIn: parent }
                  MouseArea {
                    id: incM
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var nVal = Math.max(scrubRoot.from, Math.min(scrubRoot.to, scrubRoot.value + scrubRoot.step))
                      if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                      scrubRoot.value = nVal
                      scrubRoot.valueScrubbed(nVal)
                      scrubRoot.valueCommitted(nVal)
                    }
                  }
                }
              }

              PanelToolTip {
                visible: (scrubMidMouse.containsMouse || isScrubbing) && !scrubRoot.editMode
                text: scrubRoot.tip ? scrubRoot.tip : (scrubRoot.label + ": drag horizontally to adjust, double-click to type")
              }
            }

            // Floating Multi-Row Inspector Panel
            Rectangle {
              id: selFloatingActions
              visible: Boolean(selectionOverlay.selBounds && selectionOverlay.boxW > 0 && selectionOverlay.boxH > 0)
              z: 35
              readonly property real naturalWidth: {
                var w1 = leftInfoRow.implicitWidth + rightActionsRow.implicitWidth + Style.space(20)
                var w2 = selRowStrokeFlick.visible ? selRowStrokeContent.implicitWidth : 0
                var w3 = selRowShapeFlick.visible ? selRowShapeContent.implicitWidth : 0
                var w4 = selRowToolFlick.visible ? selRowToolContent.implicitWidth : 0
                var w4b = selRowTextEffectsFlick.visible ? selRowTextEffectsContent.implicitWidth : 0
                var w4s_border = selRowSpotlightBorderFlick.visible ? selRowSpotlightBorderContent.implicitWidth : 0
                var w4s_dim = selRowSpotlightDimFlick.visible ? selRowSpotlightDimContent.implicitWidth : 0
                var w5 = selRowLayoutFlick.visible ? selRowLayoutContent.implicitWidth : 0
                var w6 = selRowShadowFlick.visible ? selRowShadowContent.implicitWidth : 0
                return Math.max(Style.space(340), Math.max(w1, Math.max(w2, Math.max(w3, Math.max(w4, Math.max(w4b, Math.max(w4s_border, Math.max(w4s_dim, Math.max(w5, w6))))))))) + Style.space(20)
              }
              width: Math.min(selectionOverlay.width - Style.space(8), naturalWidth)
              height: selInspectorCol.implicitHeight + Style.space(10)
              x: Math.max(Style.space(4), Math.min(selectionOverlay.width - width - Style.space(4), selectionOverlay.boxX + selectionOverlay.boxW / 2 - width / 2))
              y: {
                var gap = Style.space(8)
                if (selectionOverlay.boxY - height - gap >= Style.space(4)) {
                  return selectionOverlay.boxY - height - gap
                }
                if (selectionOverlay.boxY + selectionOverlay.boxH + gap + height <= selectionOverlay.height - Style.space(4)) {
                  return selectionOverlay.boxY + selectionOverlay.boxH + gap
                }
                return Math.max(Style.space(4), Math.min(selectionOverlay.height - height - Style.space(4), selectionOverlay.boxY + Style.space(4)))
              }
              radius: Style.space(6)
              color: Util.alpha(Color.popups.background || Color.background, 0.96)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

                Column {
                  id: selInspectorCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(5)
                  spacing: Style.space(4)

                  // ==========================================
                  // ROW 1: HEADER / INFO / LOCK / LAYERING / ACTIONS
                  // ==========================================
                  Item {
                    id: selRow1
                    width: parent.width
                    height: Style.space(20)

                    // Left: Badge & Size & Lock Toggle
                    Row {
                      id: leftInfoRow
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(5)

                      // 1. Tool Type Badge
                      Rectangle {
                        height: Style.space(18)
                        width: tbTxt.implicitWidth + Style.space(8)
                        radius: Style.space(3)
                        color: Util.alpha(Color.accent, 0.16)
                        border.width: 1
                        border.color: Util.alpha(Color.accent, 0.35)
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                          id: tbTxt
                          text: root.getActionLabel(selectionOverlay.curAct)
                          color: Color.accent
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          anchors.centerIn: parent
                        }
                      }

                      // 2. Element Dimensions
                      Text {
                        text: Math.round(selectionBoundingBox.width) + " × " + Math.round(selectionBoundingBox.height) + " px"
                        color: Util.alpha(Color.popups.text || Color.text, 0.5)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // 3. Lock Toggle Button (Feature I)
                      Rectangle {
                        property bool isLocked: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.locked)
                        width: lockRow.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: isLocked ? Util.alpha("#F59E0B", 0.25) : (lockMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                        border.width: 1
                        border.color: isLocked ? "#F59E0B" : Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: lockRow
                          anchors.centerIn: parent
                          spacing: Style.space(2)
                          Text {
                            text: parent.parent.isLocked ? "🔒" : "🔓"
                            font.pixelSize: Style.space(7.5)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          Text {
                            text: parent.parent.isLocked ? "Locked" : "Lock"
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            font.bold: true
                            color: parent.parent.isLocked ? "#F59E0B" : (Color.popups.text || Color.text)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                        MouseArea {
                          id: lockMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleSelectedLock()
                        }
                        PanelToolTip {
                          visible: lockMouse.containsMouse
                          text: parent.isLocked ? "Locked: cannot drag, resize, or delete (Click to Unlock)" : "Lock element (protect from accidental drag/resize/delete)"
                        }
                      }

                      // 4. Aspect Ratio Lock Toggle
                      Rectangle {
                        property bool isRatioLocked: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.lockRatio)
                        width: ratioRow.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: isRatioLocked ? Util.alpha(Color.accent, 0.25) : (ratioMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                        border.width: 1
                        border.color: isRatioLocked ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: ratioRow
                          anchors.centerIn: parent
                          spacing: Style.space(2)
                          Text {
                            text: parent.parent.isRatioLocked ? "🔗" : "🔓"
                            font.pixelSize: Style.space(7.5)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          Text {
                            text: "Ratio"
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            font.bold: true
                            color: parent.parent.isRatioLocked ? Color.accent : (Color.popups.text || Color.text)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                        MouseArea {
                          id: ratioMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleSelectedLockRatio()
                        }
                        PanelToolTip {
                          visible: ratioMouse.containsMouse
                          text: parent.isRatioLocked ? "Aspect ratio locked: corner handles scale proportionally (Click to Unlock)" : "Lock aspect ratio for proportional corner scaling"
                        }
                      }
                    }

                    // Right: Layering & Actions
                    Row {
                      id: rightActionsRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(3)

                      // Bring to Front
                      Rectangle {
                        width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                        color: frontMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "▲"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                        MouseArea { id: frontMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.bringSelectedToFront() }
                        PanelToolTip { visible: frontMouse.containsMouse; text: "Bring to Front (])" }
                      }

                      // Send to Back
                      Rectangle {
                        width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                        color: backMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "▼"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                        MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sendSelectedToBack() }
                        PanelToolTip { visible: backMouse.containsMouse; text: "Send to Back ([)" }
                      }

                      // Separator
                      Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                      // Duplicate Button
                      Rectangle {
                        width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                        color: dupMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "⧉"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                        MouseArea { id: dupMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.duplicateSelectedAction() }
                        PanelToolTip { visible: dupMouse.containsMouse; text: "Duplicate element (Ctrl+D)" }
                      }

                      // Delete Button
                      Rectangle {
                        property bool isLocked: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.locked)
                        width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                        color: isLocked ? Util.alpha(Color.popups.text || Color.text, 0.05) : (delMouse.containsMouse ? Util.alpha("#EF4444", 0.3) : Util.alpha("#EF4444", 0.12))
                        border.width: 1; border.color: isLocked ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha("#EF4444", 0.3)
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "🗑"; color: parent.isLocked ? Util.alpha(Color.popups.text || Color.text, 0.3) : "#EF4444"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                        MouseArea { id: delMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: parent.isLocked ? Qt.ForbiddenCursor : Qt.PointingHandCursor; onClicked: root.deleteSelectedAction() }
                        PanelToolTip { visible: delMouse.containsMouse; text: parent.isLocked ? "Locked element cannot be deleted" : "Delete element (Del)" }
                      }

                      // Separator
                      Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                      // Close / Deselect Button
                      Rectangle {
                        width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                        color: deselMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                        MouseArea { id: deselMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedActionIndex = -1 }
                        PanelToolTip { visible: deselMouse.containsMouse; text: "Deselect (Esc)" }
                      }
                    }
                  }

                  // Separator Line between Row 1 and Row 2
                  Rectangle {
                    visible: selRowStrokeFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.25)
                  }

                  // ==========================================
                  // ROW 2: STROKE WIDTH, COLOR & DASH PATTERN
                  // ==========================================
                  Flickable {
                    id: selRowStrokeFlick
                    visible: Boolean(selectionOverlay.curAct && (
                      selectionOverlay.curAct.tool === "rect" ||
                      selectionOverlay.curAct.tool === "circle" ||
                      selectionOverlay.curAct.tool === "line" ||
                      selectionOverlay.curAct.tool === "arrow" ||
                      selectionOverlay.curAct.tool === "pen" ||
                      selectionOverlay.curAct.tool === "highlighter"
                    ))
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowStrokeContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowStrokeContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      Text {
                        text: "Stroke:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.6)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // SmartScrubber for Stroke Width
                      SmartScrubber {
                        label: "Width"
                        value: (selectionOverlay.curAct && selectionOverlay.curAct.width !== undefined) ? selectionOverlay.curAct.width : root.strokeWidth
                        from: (selectionOverlay.curAct && (selectionOverlay.curAct.tool === "rect" || selectionOverlay.curAct.tool === "circle")) ? 0 : 1
                        to: 40
                        step: 1
                        unit: "px"
                        tip: "Stroke width (drag or double-click to type)"
                        onValueScrubbed: function(val) { root.modifySelectedProperty("width", val); root.strokeWidth = val }
                        onValueCommitted: function(val) { root.commitSelectedProperty("width", val, "Stroke Width"); root.strokeWidth = val }
                      }

                      // Stroke Color Swatches (intelligently visible when stroke width > 0)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.width !== 0)
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                          model: root.colorPalette
                          Rectangle {
                            required property string modelData
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                            border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: scMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedStrokeColor(parent.modelData)
                            }
                            PanelToolTip { visible: scMouse.containsMouse; text: "Stroke: " + parent.modelData }
                          }
                        }

                        // Eyedropper for Stroke
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: sedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: sedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "stroke"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: sedMouse.containsMouse; text: "Pick stroke color from screen" }
                        }

                        // Color Studio for Stroke
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: scStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: scStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: scStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "stroke"
                              if (selectionOverlay.curAct && selectionOverlay.curAct.color) {
                                root.currentColor = selectionOverlay.curAct.color
                              }
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: scStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                        }
                      }

                      // Separator before Dash Pattern
                      Rectangle {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.width !== 0)
                        width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Feature B: Stroke Dash Pattern Pills
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.width !== 0)
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          text: "Dash:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.55)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                          model: root.dashStylePresets
                          Rectangle {
                            required property var modelData
                            property bool isAct: Boolean(selectionOverlay.curAct && (selectionOverlay.curAct.dashStyle || "solid") === modelData.id)
                            width: dashTxt.implicitWidth + Style.space(6); height: Style.space(18); radius: Style.space(3)
                            color: isAct ? Color.accent : (dashMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isAct ? Color.accent : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              id: dashTxt
                              text: parent.modelData.label
                              color: parent.isAct ? "#FFFFFF" : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              font.bold: true
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: dashMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedDashStyle(parent.modelData.id)
                            }
                            PanelToolTip { visible: dashMouse.containsMouse; text: parent.modelData.tip }
                          }
                        }
                      }
                    }
                  }

                  // Separator Line before Row 3
                  Rectangle {
                    visible: selRowShapeFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ROW 3: SHAPE SPECIFICS (RADIUS & FILL)
                  // ==========================================
                  Flickable {
                    id: selRowShapeFlick
                    visible: Boolean(selectionOverlay.curAct && (
                      selectionOverlay.curAct.tool === "rect" ||
                      selectionOverlay.curAct.tool === "circle"
                    ))
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowShapeContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowShapeContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      // Corner Radius SmartScrubber (for rect)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "rect")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        SmartScrubber {
                          label: "Radius"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.radius !== undefined) ? selectionOverlay.curAct.radius : root.rectCornerRadius
                          from: 0
                          to: 80
                          step: 2
                          unit: "px"
                          tip: "Corner radius (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("radius", val); root.rectCornerRadius = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("radius", val, "Corner Radius"); root.rectCornerRadius = val }
                        }

                        // Separator between Radius and Fill
                        Rectangle {
                          width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }

                      // Fill Section
                      Text {
                        text: "Fill:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.6)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Fill Mode pills
                      Repeater {
                        model: [
                          { id: "none", label: "None", icon: "□", tip: "No fill (outline only)" },
                          { id: "semi", label: "Tint", icon: "▦", tip: "Tinted translucent fill (25%)" },
                          { id: "solid", label: "Solid", icon: "⬛", tip: "Solid opaque fill (100%)" }
                        ]
                        Rectangle {
                          required property var modelData
                          property bool isAct: {
                            if (!selectionOverlay.curAct) return false
                            var fm = selectionOverlay.curAct.fillMode || (selectionOverlay.curAct.filled ? "semi" : "none")
                            return fm === modelData.id
                          }
                          width: fModeRow.implicitWidth + Style.space(6); height: Style.space(18); radius: Style.space(3)
                          color: isAct ? Color.accent : (fmMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                          border.width: 1
                          border.color: isAct ? Color.accent : "transparent"
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            id: fModeRow
                            anchors.centerIn: parent
                            spacing: Style.space(2)
                            Text {
                              text: parent.parent.modelData.icon
                              font.pixelSize: Style.space(6.5)
                              color: parent.parent.isAct ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                              text: parent.parent.modelData.label
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              font.bold: true
                              color: parent.parent.isAct ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }
                          MouseArea {
                            id: fmMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.setSelectedFillMode(parent.modelData.id)
                          }
                          PanelToolTip { visible: fmMouse.containsMouse; text: parent.modelData.tip }
                        }
                      }

                      // Fill Color Swatches (INTELLIGENTLY VISIBLE ONLY WHEN FILL MODE IS NOT "none")
                      Row {
                        visible: Boolean(selectionOverlay.curAct && (
                          (selectionOverlay.curAct.fillMode && selectionOverlay.curAct.fillMode !== "none") ||
                          (selectionOverlay.curAct.filled && (!selectionOverlay.curAct.fillMode || selectionOverlay.curAct.fillMode !== "none"))
                        ))
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                          width: 1
                          height: Style.space(12)
                          color: Util.alpha(Color.popups.text || Color.text, 0.15)
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                          model: root.colorPalette
                          Rectangle {
                            required property string modelData
                            property string curFillCol: (selectionOverlay.curAct && (selectionOverlay.curAct.fillColor || selectionOverlay.curAct.color)) || ""
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: String(curFillCol).toLowerCase() === String(modelData).toLowerCase() ? 2 : 1
                            border.color: String(curFillCol).toLowerCase() === String(modelData).toLowerCase() ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: String(curFillCol).toLowerCase() === String(modelData).toLowerCase() ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: fcMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedFillColor(parent.modelData)
                            }
                            PanelToolTip { visible: fcMouse.containsMouse; text: "Fill: " + parent.modelData }
                          }
                        }

                        // Fill Eyedropper
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: fedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: fedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "fill"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: fedMouse.containsMouse; text: "Pick fill color from screen" }
                        }

                        // Color Studio for Fill
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: fcStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: fcStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: fcStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "fill"
                              var cur = (selectionOverlay.curAct && (selectionOverlay.curAct.fillColor || selectionOverlay.curAct.color)) || root.fillColor
                              if (cur) root.currentColor = cur
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: fcStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                        }
                      }
                    }
                  }

                  // Separator Line before Row 4
                  Rectangle {
                    visible: selRowToolFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ==========================================
                  // ROW 4: TOOL SPECIFICS (TEXT, ARROW, STAMP, PIXEL, BLUR, MAGNIFIER)
                  // ==========================================
                  Flickable {
                    id: selRowToolFlick
                    visible: Boolean(selectionOverlay.curAct && (
                      selectionOverlay.curAct.tool === "text" ||
                      selectionOverlay.curAct.tool === "arrow" ||
                      selectionOverlay.curAct.tool === "line" ||
                      selectionOverlay.curAct.tool === "stamp" ||
                      selectionOverlay.curAct.tool === "pixelate" ||
                      selectionOverlay.curAct.tool === "blur" ||
                      selectionOverlay.curAct.tool === "magnifier" ||
                      selectionOverlay.curAct.tool === "block_highlight" ||
                      selectionOverlay.curAct.tool === "spotlight"
                    ))
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowToolContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowToolContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      // 1. ARROW / LINE CONTROLS (Feature D)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && (selectionOverlay.curAct.tool === "arrow" || selectionOverlay.curAct.tool === "line"))
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          text: "Heads:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.6)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        // Arrow Head Style Presets (Single, Double, Line)
                        Repeater {
                          model: root.arrowHeadPresets
                          Rectangle {
                            required property var modelData
                            property bool isAct: {
                              if (!selectionOverlay.curAct) return false
                              var cur = selectionOverlay.curAct.headStyle || (selectionOverlay.curAct.tool === "line" ? "none" : "end")
                              return cur === modelData.id
                            }
                            width: headTxt.implicitWidth + Style.space(6); height: Style.space(18); radius: Style.space(3)
                            color: isAct ? Color.accent : (headMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isAct ? Color.accent : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              id: headTxt
                              text: parent.modelData.label
                              color: parent.isAct ? "#FFFFFF" : (Color.popups.text || Color.text)
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: headMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedArrowHeadStyle(parent.modelData.id)
                            }
                            PanelToolTip { visible: headMouse.containsMouse; text: parent.modelData.tip }
                          }
                        }

                        // Flip Direction Button
                        Rectangle {
                          width: flipArrowTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                          color: flipArrowMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.06)
                          border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            id: flipArrowTxt
                            anchors.centerIn: parent; spacing: Style.space(2)
                            Text { text: "⇄"; font.pixelSize: Style.space(8); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Flip"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                          }
                          MouseArea {
                            id: flipArrowMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.flipSelectedArrow()
                          }
                          PanelToolTip { visible: flipArrowMouse.containsMouse; text: "Reverse direction (swap start and end points)" }
                        }
                      }

                      // 2. TEXT CONTROLS (Size SmartScrubber, Font Presets + System Font Dropdown, Quick Edit, B/I/U/S, Case Aa/TT/tt, Align, Fill Color)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "text")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        // SmartScrubber for Font Size
                        SmartScrubber {
                          label: "Size"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.size !== undefined) ? selectionOverlay.curAct.size : 20
                          from: 8
                          to: 128
                          step: 2
                          unit: "px"
                          tip: "Font size (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("size", val) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("size", val, "Font Size") }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Smart Built System Font Loader & Search Dropdown Selector
                        Rectangle {
                          id: fontPickerTriggerBtn
                          property string curFam: (selectionOverlay.curAct && selectionOverlay.curAct.fontFamily) ? selectionOverlay.curAct.fontFamily : (root.defaultFontFamily || "Sans")
                          width: Style.space(110)
                          height: Style.space(18)
                          radius: Style.space(3)
                          color: root.fontPickerOpen ? Color.accent : (fpTrigMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08))
                          border.width: 1
                          border.color: root.fontPickerOpen ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.18)
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(5)
                            anchors.rightMargin: Style.space(5)
                            spacing: Style.space(3)

                            // Typeface Icon
                            Text {
                              text: "󰛄"
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              color: root.fontPickerOpen ? "#FFFFFF" : Color.accent
                              anchors.verticalCenter: parent.verticalCenter
                            }

                            // Current Font Family Name (Previewed in its own typeface)
                            Text {
                              id: fpCurLabel
                              text: {
                                var f = fontPickerTriggerBtn.curFam
                                if (f === "sans") return "Sans"
                                if (f === "mono") return "Mono"
                                if (f === "serif") return "Serif"
                                return f
                              }
                              width: parent.width - Style.space(24)
                              font.family: {
                                var f = fontPickerTriggerBtn.curFam
                                if (f === "mono") return "monospace"
                                if (f === "serif") return "serif"
                                if (f === "sans") return Style.font.menuFamily
                                return f
                              }
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              elide: Text.ElideRight
                              color: root.fontPickerOpen ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.verticalCenter: parent.verticalCenter
                            }

                            // Dropdown Arrow
                            Text {
                              text: root.fontPickerOpen ? "▴" : "▾"
                              font.pixelSize: Style.space(6.5)
                              color: root.fontPickerOpen ? "#FFFFFF" : Util.alpha(Color.popups.text || Color.text, 0.6)
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }

                          MouseArea {
                            id: fpTrigMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.fontPickerOpen = !root.fontPickerOpen
                              if (root.fontPickerOpen) {
                                root.fontSearchQuery = ""
                                Qt.callLater(function() {
                                  if (typeof fontSearchInput !== "undefined" && fontSearchInput) {
                                    fontSearchInput.forceActiveFocus()
                                  }
                                })
                              }
                            }
                          }
                          PanelToolTip {
                            visible: fpTrigMouse.containsMouse && !root.fontPickerOpen
                            text: "Font: " + fontPickerTriggerBtn.curFam + " (" + root.systemFontFamilies.length + " system fonts loaded)"
                          }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Quick Edit Button
                        Rectangle {
                          id: editBtnBox
                          width: editBtnRow.implicitWidth + Style.space(8)
                          height: Style.space(18)
                          radius: Style.space(3)
                          color: editMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          border.width: 1
                          border.color: editMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            id: editBtnRow
                            anchors.centerIn: parent
                            spacing: Style.space(2)
                            Text {
                              text: "✎"
                              font.pixelSize: Style.space(8)
                              color: Color.accent
                              anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                              text: "Edit"
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              color: Color.popups.text || Color.text
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }

                          MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editSelectedText()
                          }
                          PanelToolTip {
                            visible: editMouse.containsMouse
                            text: "Edit text content (or press F2 / double-click text)"
                          }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Style Formatting Pills: Bold (B), Italic (I), Underline (U), Strikethrough (S)
                        Row {
                          spacing: Style.space(2)
                          anchors.verticalCenter: parent.verticalCenter

                          // Bold (B)
                          Rectangle {
                            property bool isBold: Boolean(selectionOverlay.curAct && (selectionOverlay.curAct.fontWeight || "bold") === "bold")
                            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                            color: isBold ? Color.accent : (boldMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isBold ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: "B"
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              color: parent.isBold ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: boldMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.toggleSelectedFontWeight()
                            }
                            PanelToolTip { visible: boldMouse.containsMouse; text: parent.isBold ? "Bold font enabled (Ctrl+B)" : "Toggle bold font weight (Ctrl+B)" }
                          }

                          // Italic (I)
                          Rectangle {
                            property bool isItalic: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.italic)
                            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                            color: isItalic ? Color.accent : (italicMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isItalic ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: "I"
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.italic: true
                              font.bold: true
                              color: parent.isItalic ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: italicMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.toggleSelectedItalic()
                            }
                            PanelToolTip { visible: italicMouse.containsMouse; text: parent.isItalic ? "Italic slant enabled (Ctrl+I)" : "Toggle italic font slant (Ctrl+I)" }
                          }

                          // Underline (U)
                          Rectangle {
                            property bool isUnderline: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.underline)
                            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                            color: isUnderline ? Color.accent : (underMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isUnderline ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: "U"
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.underline: true
                              font.bold: true
                              color: parent.isUnderline ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: underMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.toggleSelectedUnderline()
                            }
                            PanelToolTip { visible: underMouse.containsMouse; text: parent.isUnderline ? "Underline enabled (Ctrl+U)" : "Toggle text underline (Ctrl+U)" }
                          }

                          // Strikethrough (S)
                          Rectangle {
                            property bool isStrike: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.strikeout)
                            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                            color: isStrike ? Color.accent : (strikeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isStrike ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: "S"
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.strikeout: true
                              font.bold: true
                              color: parent.isStrike ? "#FFFFFF" : (Color.popups.text || Color.text)
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: strikeMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.toggleSelectedStrikeout()
                            }
                            PanelToolTip { visible: strikeMouse.containsMouse; text: parent.isStrike ? "Strikethrough enabled" : "Toggle text strikethrough" }
                          }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Text Case Transform Pills: Aa (normal), TT (uppercase), tt (lowercase)
                        Row {
                          spacing: Style.space(2)
                          anchors.verticalCenter: parent.verticalCenter

                          Repeater {
                            model: [
                              { id: "none", label: "Aa", tip: "Normal case" },
                              { id: "uppercase", label: "TT", tip: "ALL UPPERCASE" },
                              { id: "lowercase", label: "tt", tip: "all lowercase" }
                            ]
                            Rectangle {
                              required property var modelData
                              property bool isCaseAct: Boolean(selectionOverlay.curAct && (selectionOverlay.curAct.textTransform || "none") === modelData.id)
                              width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                              color: isCaseAct ? Color.accent : (caseMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                              border.width: 1; border.color: isCaseAct ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                              anchors.verticalCenter: parent.verticalCenter

                              Text {
                                text: parent.modelData.label
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                font.bold: true
                                color: parent.isCaseAct ? "#FFFFFF" : (Color.popups.text || Color.text)
                                anchors.centerIn: parent
                              }
                              MouseArea {
                                id: caseMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.setSelectedTextTransform(parent.modelData.id)
                              }
                              PanelToolTip { visible: caseMouse.containsMouse; text: parent.modelData.tip }
                            }
                          }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Text Alignment (Left, Center, Right)
                        Repeater {
                          model: root.textAlignPresets
                          Rectangle {
                            required property var modelData
                            property bool isAct: Boolean(selectionOverlay.curAct && (selectionOverlay.curAct.textAlign || "left") === modelData.id)
                            width: Style.space(16); height: Style.space(18); radius: Style.space(3)
                            color: isAct ? Color.accent : (alignMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1; border.color: isAct ? Color.accent : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: parent.modelData.label
                              color: parent.isAct ? "#FFFFFF" : (Color.popups.text || Color.text)
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: alignMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedTextAlign(parent.modelData.id)
                            }
                            PanelToolTip { visible: alignMouse.containsMouse; text: parent.modelData.tip }
                          }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        Text {
                          text: "Fill:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.6)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        // Text Color Swatches (Using colorPalette)
                        Row {
                          spacing: Style.space(2)
                          anchors.verticalCenter: parent.verticalCenter
                          Repeater {
                            model: root.colorPalette
                            Rectangle {
                              required property string modelData
                              width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                              color: modelData
                              border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                              border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                              scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                              anchors.verticalCenter: parent.verticalCenter

                              MouseArea {
                                id: tcMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.setSelectedColor(parent.modelData)
                              }
                              PanelToolTip { visible: tcMouse.containsMouse; text: "Text color: " + parent.modelData }
                            }
                          }

                          // Eyedropper for Text Fill
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                            color: tedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                            MouseArea {
                              id: tedMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.activeColorTarget = "stroke"
                                root.requestScreenPick()
                              }
                            }
                            PanelToolTip { visible: tedMouse.containsMouse; text: "Pick text color from screen" }
                          }

                          // Color Studio for Text Fill
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                            color: tcStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "󰏘"; color: tcStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                            MouseArea {
                              id: tcStudioMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.activeColorTarget = "stroke"
                                if (selectionOverlay.curAct && selectionOverlay.curAct.color) {
                                  root.currentColor = selectionOverlay.curAct.color
                                }
                                root.requestColorPicker()
                              }
                            }
                            PanelToolTip { visible: tcStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                          }
                        }
                      }

                      // 3. STAMP CONTROLS (Types, Stepper, Size SmartScrubber, Color)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "stamp")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        // Stamp Types
                        Repeater {
                          model: [
                            { id: "number", label: "①" },
                            { id: "check", label: "✓" },
                            { id: "cross", label: "✕" },
                            { id: "star", label: "★" },
                            { id: "warn", label: "⚠" },
                            { id: "bug", label: "🪲" },
                            { id: "fire", label: "🔥" }
                          ]
                          Rectangle {
                            required property var modelData
                            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                            color: (selectionOverlay.curAct && selectionOverlay.curAct.stampType === modelData.id) ? Color.accent : (stMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                            border.width: 1
                            border.color: (selectionOverlay.curAct && selectionOverlay.curAct.stampType === modelData.id) ? Color.accent : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: parent.modelData.label
                              color: (selectionOverlay.curAct && selectionOverlay.curAct.stampType === parent.modelData.id) ? "#FFFFFF" : (Color.popups.text || Color.text)
                              font.pixelSize: Style.space(8.5)
                              font.bold: true
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: stMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedStampType(parent.modelData.id)
                            }
                            PanelToolTip { visible: stMouse.containsMouse; text: "Change stamp to " + parent.modelData.label }
                          }
                        }

                        // Number Stepper (only visible if stampType === 'number')
                        Row {
                          visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.stampType === "number")
                          spacing: Style.space(2)
                          anchors.verticalCenter: parent.verticalCenter

                          // Separator
                          Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                          // Dec button [-]
                          Rectangle {
                            width: Style.space(16); height: Style.space(18); radius: Style.space(3)
                            color: decMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "−"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                            MouseArea { id: decMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stepSelectedStampNum(-1) }
                            PanelToolTip { visible: decMouse.containsMouse; text: "Decrease number (-1)" }
                          }

                          // Current Step Display
                          Rectangle {
                            height: Style.space(18); width: numBadgeTxt.implicitWidth + Style.space(8); radius: Style.space(3)
                            color: Util.alpha(Color.accent, 0.15); border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                              id: numBadgeTxt
                              text: "Step " + ((selectionOverlay.curAct && selectionOverlay.curAct.num) ? selectionOverlay.curAct.num : 1)
                              font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); font.bold: true; color: Color.accent
                              anchors.centerIn: parent
                            }
                          }

                          // Inc button [+]
                          Rectangle {
                            width: Style.space(16); height: Style.space(18); radius: Style.space(3)
                            color: incMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "+"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                            MouseArea { id: incMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stepSelectedStampNum(1) }
                            PanelToolTip { visible: incMouse.containsMouse; text: "Increase number (+1)" }
                          }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Stamp Radius SmartScrubber
                        SmartScrubber {
                          label: "Radius"
                          value: {
                            if (!selectionOverlay.curAct) return 18
                            if (selectionOverlay.curAct.radius !== undefined) return selectionOverlay.curAct.radius
                            if (selectionOverlay.curAct.stampSize === "S") return 14
                            if (selectionOverlay.curAct.stampSize === "M") return 18
                            if (selectionOverlay.curAct.stampSize === "L") return 24
                            if (selectionOverlay.curAct.stampSize === "XL") return 32
                            return 18
                          }
                          from: 10
                          to: 60
                          step: 2
                          unit: "px"
                          tip: "Stamp radius (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("radius", val) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("radius", val, "Stamp Radius") }
                        }

                        // Stamp Color Swatches (Using colorPalette)
                        Row {
                          spacing: Style.space(2)
                          anchors.verticalCenter: parent.verticalCenter
                          Repeater {
                            model: root.colorPalette
                            Rectangle {
                              required property string modelData
                              width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                              color: modelData
                              border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                              border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                              scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                              anchors.verticalCenter: parent.verticalCenter

                              MouseArea {
                                id: stcMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.setSelectedColor(parent.modelData)
                              }
                              PanelToolTip { visible: stcMouse.containsMouse; text: "Color: " + parent.modelData }
                            }
                          }

                          // Eyedropper for Stamp
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                            color: stedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                            MouseArea {
                              id: stedMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.activeColorTarget = "stroke"
                                root.requestScreenPick()
                              }
                            }
                            PanelToolTip { visible: stedMouse.containsMouse; text: "Pick stamp color from screen" }
                          }

                          // Color Studio for Stamp
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                            color: stStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "󰏘"; color: stStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                            MouseArea {
                              id: stStudioMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.activeColorTarget = "stroke"
                                if (selectionOverlay.curAct && selectionOverlay.curAct.color) {
                                  root.currentColor = selectionOverlay.curAct.color
                                }
                                root.requestColorPicker()
                              }
                            }
                            PanelToolTip { visible: stStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                          }
                        }
                      }

                      // 4. PIXELATE CONTROLS (SmartScrubber for Block Size)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "pixelate")
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        SmartScrubber {
                          label: "Block"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.pixelSize !== undefined) ? selectionOverlay.curAct.pixelSize : 14
                          from: 4
                          to: 64
                          step: 2
                          unit: "px"
                          tip: "Pixelation block size (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("pixelSize", val) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("pixelSize", val, "Pixel Size") }
                        }
                      }

                      // 5. BLUR CONTROLS (SmartScrubber for Optical Dispersion)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "blur")
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        SmartScrubber {
                          label: "Dispersion"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.dispersion !== undefined) ? selectionOverlay.curAct.dispersion : 4
                          from: 2
                          to: 32
                          step: 1
                          unit: "px"
                          tip: "Blur optical dispersion radius (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("dispersion", val) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("dispersion", val, "Blur Dispersion") }
                        }
                      }

                      // 6. MAGNIFIER CONTROLS (Zoom, Radius, Rim Color Swatches)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "magnifier")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        SmartScrubber {
                          label: "Zoom"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.zoom !== undefined) ? selectionOverlay.curAct.zoom : 2.0
                          from: 1.2
                          to: 5.0
                          step: 0.1
                          unit: "×"
                          tip: "Magnifier zoom factor (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("zoom", Math.round(val * 10) / 10) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("zoom", Math.round(val * 10) / 10, "Magnifier Zoom") }
                        }

                        SmartScrubber {
                          label: "Radius"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.radius !== undefined) ? selectionOverlay.curAct.radius : 50
                          from: 25
                          to: 200
                          step: 5
                          unit: "px"
                          tip: "Magnifier lens radius (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("radius", val) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("radius", val, "Magnifier Radius") }
                        }

                        // Rim Color Swatches
                        Row {
                          spacing: Style.space(2)
                          anchors.verticalCenter: parent.verticalCenter

                          Repeater {
                            model: root.colorPalette
                            Rectangle {
                              required property string modelData
                              width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                              color: modelData
                              border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                              border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                              scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                              anchors.verticalCenter: parent.verticalCenter

                              MouseArea {
                                id: mcMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.setSelectedColor(parent.modelData)
                              }
                              PanelToolTip { visible: mcMouse.containsMouse; text: "Rim color: " + parent.modelData }
                            }
                          }

                          // Eyedropper for Magnifier Rim
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                            color: medMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                            MouseArea {
                              id: medMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.activeColorTarget = "stroke"
                                root.requestScreenPick()
                              }
                            }
                            PanelToolTip { visible: medMouse.containsMouse; text: "Pick rim color from screen" }
                          }

                          // Color Studio for Magnifier Rim
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                            color: medStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "󰏘"; color: medStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                            MouseArea {
                              id: medStudioMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.activeColorTarget = "stroke"
                                if (selectionOverlay.curAct && selectionOverlay.curAct.color) {
                                  root.currentColor = selectionOverlay.curAct.color
                                }
                                root.requestColorPicker()
                              }
                            }
                            PanelToolTip { visible: medStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                          }
                        }
                      }

                      // 7. BLOCK HIGHLIGHT CONTROLS (Tint Color Swatches, Eyedropper, Color Studio)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "block_highlight")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          text: "Highlight Tint:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.6)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                          model: root.colorPalette
                          Rectangle {
                            required property string modelData
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                            border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.color).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: bhlcMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedColor(parent.modelData)
                            }
                            PanelToolTip { visible: bhlcMouse.containsMouse; text: "Tint: " + parent.modelData }
                          }
                        }

                        // Eyedropper for Block Highlight
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: bhledMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: bhledMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "stroke"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: bhledMouse.containsMouse; text: "Pick tint color from screen" }
                        }

                        // Color Studio for Block Highlight
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: bhlStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: bhlStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: bhlStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "stroke"
                              if (selectionOverlay.curAct && selectionOverlay.curAct.color) {
                                root.currentColor = selectionOverlay.curAct.color
                              }
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: bhlStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                        }
                      }

                      // 8. SPOTLIGHT CONTROLS (Shape, Radius & Magnification Zoom)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "spotlight")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        // Shape Toggle: Rect vs Circle
                        Row {
                          spacing: Style.space(1.5)
                          anchors.verticalCenter: parent.verticalCenter

                          Rectangle {
                            width: Style.space(18); height: Style.space(18); radius: Style.space(4)
                            property bool isSelected: !selectionOverlay.curAct || selectionOverlay.curAct.shape !== "circle"
                            color: isSelected ? Util.alpha(Color.accent, 0.25) : (srectMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
                            border.width: 1
                            border.color: isSelected ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "□"; color: parent.isSelected ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
                            MouseArea {
                              id: srectMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedSpotlightShape("rect")
                            }
                            PanelToolTip { visible: srectMouse.containsMouse; text: "Rectangle Spotlight" }
                          }

                          Rectangle {
                            width: Style.space(18); height: Style.space(18); radius: Style.space(4)
                            property bool isSelected: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.shape === "circle")
                            color: isSelected ? Util.alpha(Color.accent, 0.25) : (scircMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
                            border.width: 1
                            border.color: isSelected ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "○"; color: parent.isSelected ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
                            MouseArea {
                              id: scircMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedSpotlightShape("circle")
                            }
                            PanelToolTip { visible: scircMouse.containsMouse; text: "Circle / Ellipse Spotlight" }
                          }
                        }

                        // Corner Radius (Rectangle only)
                        SmartScrubber {
                          visible: !selectionOverlay.curAct || selectionOverlay.curAct.shape !== "circle"
                          label: "Radius"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.radius !== undefined) ? selectionOverlay.curAct.radius : root.spotlightRadius
                          from: 0
                          to: 60
                          step: 2
                          unit: "px"
                          tip: "Spotlight corner radius"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("radius", val); root.spotlightRadius = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("radius", val, "Spotlight Radius"); root.spotlightRadius = val }
                        }

                        // Magnification Zoom Scrubber
                        SmartScrubber {
                          label: "Zoom"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.zoom !== undefined) ? selectionOverlay.curAct.zoom : (root.spotlightZoom || 1.0)
                          from: 1.0
                          to: 4.0
                          step: 0.1
                          unit: "×"
                          tip: "Spotlight magnification zoom factor (1.0× = normal / off)"
                          onValueScrubbed: function(val) {
                            var rounded = Math.round(val * 10) / 10
                            root.modifySelectedProperty("zoom", rounded)
                            root.spotlightZoom = rounded
                          }
                          onValueCommitted: function(val) {
                            var rounded = Math.round(val * 10) / 10
                            root.commitSelectedProperty("zoom", rounded, "Magnification Zoom")
                            root.spotlightZoom = rounded
                          }
                        }
                      }
                    }
                  }

                  // Separator Line before Spotlight Border Row
                  Rectangle {
                    visible: selRowSpotlightBorderFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ROW 4S_BORDER: SPOTLIGHT BORDER & COLOR
                  // ==========================================
                  Flickable {
                    id: selRowSpotlightBorderFlick
                    visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "spotlight")
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowSpotlightBorderContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowSpotlightBorderContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(3)

                      // Border Width Scrubber
                      SmartScrubber {
                        label: "Border"
                        value: (selectionOverlay.curAct && selectionOverlay.curAct.borderWidth !== undefined) ? selectionOverlay.curAct.borderWidth : root.spotlightBorderWidth
                        from: 0
                        to: 12
                        step: 1
                        unit: "px"
                        tip: "Spotlight rim border width (0 to hide border)"
                        onValueScrubbed: function(val) { root.modifySelectedProperty("borderWidth", val); root.spotlightBorderWidth = val }
                        onValueCommitted: function(val) { root.commitSelectedProperty("borderWidth", val, "Border Width"); root.spotlightBorderWidth = val }
                      }

                      // Border Color Swatches
                      Row {
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          text: "Border:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.6)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                          model: ["#FFFFFF", "#000000", "#FF4444", "#FFAA00", "#00C853", "#00B0FF", "#A855F7"]
                          Rectangle {
                            required property string modelData
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.borderColor).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                            border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.borderColor).toLowerCase() === String(modelData).toLowerCase()) ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.borderColor).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: sbcMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedSpotlightBorderColor(parent.modelData)
                            }
                            PanelToolTip { visible: sbcMouse.containsMouse; text: "Border: " + parent.modelData }
                          }
                        }

                        // Eyedropper for Border
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: sbedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: sbedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "spotlightBorder"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: sbedMouse.containsMouse; text: "Pick border color from screen" }
                        }

                        // Color Studio for Border
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: sbStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: sbStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: sbStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "spotlightBorder"
                              if (selectionOverlay.curAct && selectionOverlay.curAct.borderColor) {
                                root.currentColor = selectionOverlay.curAct.borderColor
                              }
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: sbStudioMouse.containsMouse; text: "Open Color Studio for Border" }
                        }
                      }
                    }
                  }

                  // Separator Line before Spotlight Dim Row
                  Rectangle {
                    visible: selRowSpotlightDimFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ROW 4C_SPOTLIGHT: UNIFIED BACKGROUND DARKNESS & TINT
                  // ==========================================
                  Flickable {
                    id: selRowSpotlightDimFlick
                    visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "spotlight")
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowSpotlightDimContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowSpotlightDimContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(3)

                      // Unified Dim Darkness Scrubber
                      SmartScrubber {
                        label: "Darkness"
                        value: Math.round(root.spotlightDimOpacity * 100)
                        from: 10
                        to: 95
                        step: 5
                        unit: "%"
                        tip: "Unified background dimming darkness percentage"
                        onValueScrubbed: function(val) {
                          root.spotlightDimOpacity = val / 100.0
                          annotationCanvas.requestPaint()
                        }
                        onValueCommitted: function(val) {
                          root.setUnifiedSpotlightDimOpacity(val / 100.0)
                        }
                      }

                      // Unified Dim Tint Swatches & Tools
                      Row {
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          text: "Dim Tint:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.6)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                          model: ["#000000", "#0F172A", "#1E1E2E", "#2B2D42", "#111827"]
                          Rectangle {
                            required property string modelData
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: (String(root.spotlightDimColor).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                            border.color: (String(root.spotlightDimColor).toLowerCase() === String(modelData).toLowerCase()) ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: (String(root.spotlightDimColor).toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: sdcMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setUnifiedSpotlightDimColor(parent.modelData)
                            }
                            PanelToolTip { visible: sdcMouse.containsMouse; text: "Dim Tint: " + parent.modelData }
                          }
                        }

                        // Eyedropper for Dim Tint
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: sdimedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: sdimedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "spotlightDim"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: sdimedMouse.containsMouse; text: "Pick dim tint from screen" }
                        }

                        // Color Studio for Dim Tint
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: sdimStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰃚"; color: sdimStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: sdimStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "spotlightDim"
                              root.currentColor = root.spotlightDimColor
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: sdimStudioMouse.containsMouse; text: "Customize Unified Dim Tint Color" }
                        }
                      }
                    }
                  }

                  // Separator Line before Row 4B
                  Rectangle {
                    visible: selRowTextEffectsFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ROW 4B: TEXT STROKE / HALO OUTLINE & CARD BOX
                  // ==========================================
                  Flickable {
                    id: selRowTextEffectsFlick
                    visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "text")
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowTextEffectsContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowTextEffectsContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      // --- Section 1: Stroke / Halo Outline ---
                      Rectangle {
                        property bool hasHalo: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.halo)
                        width: haloRowBtn.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: hasHalo ? Color.accent : (haloBtnMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                        border.width: 1; border.color: hasHalo ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: haloRowBtn
                          anchors.centerIn: parent
                          spacing: Style.space(2)
                          Text { text: "◰"; font.pixelSize: Style.space(7); color: parent.parent.hasHalo ? "#FFFFFF" : Color.accent; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Outline"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; color: parent.parent.hasHalo ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          id: haloBtnMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleSelectedTextHalo()
                        }
                        PanelToolTip { visible: haloBtnMouse.containsMouse; text: parent.hasHalo ? "Outline halo enabled (click to disable)" : "Add outline halo for high contrast on busy backgrounds" }
                      }

                      // Outline Thickness Scrubber (SmartScrubber)
                      SmartScrubber {
                        label: "Thick"
                        value: (selectionOverlay.curAct && selectionOverlay.curAct.haloWidth !== undefined) ? selectionOverlay.curAct.haloWidth : 3
                        from: 1
                        to: 16
                        step: 1
                        unit: "px"
                        tip: "Outline / halo thickness (drag or double-click to type)"
                        onValueScrubbed: function(val) { root.modifySelectedProperty("haloWidth", val) }
                        onValueCommitted: function(val) { root.commitSelectedProperty("haloWidth", val, "Outline Thickness") }
                      }

                      // Outline Color Swatches
                      Row {
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                          model: root.colorPalette
                          Rectangle {
                            required property string modelData
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.haloColor || "#000000").toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                            border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.haloColor || "#000000").toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.haloColor || "#000000").toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: hcolMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedTextHaloColor(parent.modelData)
                            }
                            PanelToolTip { visible: hcolMouse.containsMouse; text: "Outline: " + parent.modelData }
                          }
                        }

                        // Eyedropper for Halo Outline
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: hedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: hedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "halo"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: hedMouse.containsMouse; text: "Pick outline color from screen" }
                        }

                        // Color Studio for Halo Outline
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: hStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: hStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: hStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "halo"
                              if (selectionOverlay.curAct && selectionOverlay.curAct.haloColor) {
                                root.currentColor = selectionOverlay.curAct.haloColor
                              } else {
                                root.currentColor = "#000000"
                              }
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: hStudioMouse.containsMouse; text: "Open Color Studio for outline / halo color" }
                        }
                      }

                      // Separator between Outline and Card Box
                      Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                      // --- Section 2: Card Box Background ---
                      Rectangle {
                        property bool hasBox: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.box)
                        width: boxRowBtn.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: hasBox ? Color.accent : (boxBtnMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                        border.width: 1; border.color: hasBox ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: boxRowBtn
                          anchors.centerIn: parent; spacing: Style.space(2)
                          Text { text: "■"; font.pixelSize: Style.space(7); color: parent.parent.hasBox ? "#FFFFFF" : Color.accent; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Card Box"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; color: parent.parent.hasBox ? "#FFFFFF" : (Color.popups.text || Color.text); anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          id: boxBtnMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleSelectedTextBox()
                        }
                        PanelToolTip { visible: boxBtnMouse.containsMouse; text: parent.hasBox ? "Remove background card" : "Add high-contrast card box" }
                      }

                      // Card Box Opacity Scrubber
                      SmartScrubber {
                        label: "Opacity"
                        value: (selectionOverlay.curAct && selectionOverlay.curAct.boxOpacity !== undefined) ? Math.round(selectionOverlay.curAct.boxOpacity * 100) : 85
                        from: 10
                        to: 100
                        step: 5
                        unit: "%"
                        tip: "Card box opacity (drag or double-click to type)"
                        onValueScrubbed: function(val) { root.modifySelectedProperty("boxOpacity", val / 100.0) }
                        onValueCommitted: function(val) { root.commitSelectedProperty("boxOpacity", val / 100.0, "Card Opacity") }
                      }

                      // Card Box Radius Scrubber
                      SmartScrubber {
                        label: "Radius"
                        value: (selectionOverlay.curAct && selectionOverlay.curAct.boxRadius !== undefined) ? selectionOverlay.curAct.boxRadius : 6
                        from: 0
                        to: 24
                        step: 1
                        unit: "px"
                        tip: "Card box corner radius (drag or double-click to type)"
                        onValueScrubbed: function(val) { root.modifySelectedProperty("boxRadius", val) }
                        onValueCommitted: function(val) { root.commitSelectedProperty("boxRadius", val, "Card Radius") }
                      }

                      // Card Box Color Swatches
                      Row {
                        spacing: Style.space(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                          model: root.colorPalette
                          Rectangle {
                            required property string modelData
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: (selectionOverlay.curAct && String(selectionOverlay.curAct.boxColor || "#0F172A").toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                            border.color: (selectionOverlay.curAct && String(selectionOverlay.curAct.boxColor || "#0F172A").toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: (selectionOverlay.curAct && String(selectionOverlay.curAct.boxColor || "#0F172A").toLowerCase() === String(modelData).toLowerCase()) ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                              id: bcolMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedTextBoxColor(parent.modelData)
                            }
                            PanelToolTip { visible: bcolMouse.containsMouse; text: "Card: " + parent.modelData }
                          }
                        }

                        // Eyedropper for Card Box
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: bedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: bedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "box"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: bedMouse.containsMouse; text: "Pick card box color from screen" }
                        }

                        // Color Studio for Card Box
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: bStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: bStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: bStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "box"
                              if (selectionOverlay.curAct && selectionOverlay.curAct.boxColor) {
                                root.currentColor = selectionOverlay.curAct.boxColor
                              } else {
                                root.currentColor = "#0F172A"
                              }
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: bStudioMouse.containsMouse; text: "Open Color Studio for card box color" }
                        }
                      }
                    }
                  }

                  // Separator Line before Row 5
                  Rectangle {
                    visible: selRowLayoutFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ROW 5: LAYOUT, ALIGNMENT, ROTATION & OPACITY
                  // ==========================================
                  Flickable {
                    id: selRowLayoutFlick
                    visible: Boolean(selectionOverlay.curAct)
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowLayoutContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowLayoutContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      // Feature G: Canvas Alignment (Center H, Center V)
                      Text {
                        text: "Align:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.6)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Center Horizontally
                      Rectangle {
                        width: alignHTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: alHMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                        border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: alignHTxt
                          anchors.centerIn: parent; spacing: Style.space(2)
                          Text { text: "⯐"; font.pixelSize: Style.space(7.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "H"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          id: alHMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.alignSelectedCenterH()
                        }
                        PanelToolTip { visible: alHMouse.containsMouse; text: "Center horizontally on canvas" }
                      }

                      // Center Vertically
                      Rectangle {
                        width: alignVTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: alVMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                        border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: alignVTxt
                          anchors.centerIn: parent; spacing: Style.space(2)
                          Text { text: "⯐"; font.pixelSize: Style.space(7.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "V"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          id: alVMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.alignSelectedCenterV()
                        }
                        PanelToolTip { visible: alVMouse.containsMouse; text: "Center vertically on canvas" }
                      }

                      // Separator before Flip
                      Rectangle {
                        visible: Boolean(selectionOverlay.curAct && (
                          selectionOverlay.curAct.tool === "rect" ||
                          selectionOverlay.curAct.tool === "circle" ||
                          selectionOverlay.curAct.tool === "line" ||
                          selectionOverlay.curAct.tool === "arrow" ||
                          selectionOverlay.curAct.tool === "pen"
                        ))
                        width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Feature H: Flip Transform (for shapes, lines, pen)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && (
                          selectionOverlay.curAct.tool === "rect" ||
                          selectionOverlay.curAct.tool === "circle" ||
                          selectionOverlay.curAct.tool === "line" ||
                          selectionOverlay.curAct.tool === "arrow" ||
                          selectionOverlay.curAct.tool === "pen"
                        ))
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          text: "Flip:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.55)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        // Flip Horizontal
                        Rectangle {
                          width: flipHTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                          color: fHMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                          border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            id: flipHTxt
                            anchors.centerIn: parent; spacing: Style.space(2)
                            Text { text: "⇄"; font.pixelSize: Style.space(7.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "H"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                          }
                          MouseArea {
                            id: fHMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.flipSelectedH()
                          }
                          PanelToolTip { visible: fHMouse.containsMouse; text: "Flip horizontally around element center" }
                        }

                        // Flip Vertical
                        Rectangle {
                          width: flipVTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                          color: fVMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                          border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            id: flipVTxt
                            anchors.centerIn: parent; spacing: Style.space(2)
                            Text { text: "⇅"; font.pixelSize: Style.space(7.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "V"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                          }
                          MouseArea {
                            id: fVMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.flipSelectedV()
                          }
                          PanelToolTip { visible: fVMouse.containsMouse; text: "Flip vertically around element center" }
                        }
                      }

                      // Separator before Rotate
                      Rectangle {
                        width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Rotation Controls (Rotate 90° button + Angle SmartScrubber)
                      Row {
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                          width: rot90Txt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                          color: rot90Mouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06)
                          border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                          anchors.verticalCenter: parent.verticalCenter

                          Row {
                            id: rot90Txt
                            anchors.centerIn: parent; spacing: Style.space(2)
                            Text { text: "↻"; font.pixelSize: Style.space(8); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "90°"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                          }
                          MouseArea {
                            id: rot90Mouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.rotateSelected(90)
                          }
                          PanelToolTip { visible: rot90Mouse.containsMouse; text: "Rotate 90° clockwise" }
                        }

                        SmartScrubber {
                          label: "Angle"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.rotation !== undefined) ? selectionOverlay.curAct.rotation : 0
                          from: 0
                          to: 359
                          step: 5
                          unit: "°"
                          tip: "Rotation angle (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("rotation", Math.round(val)) }
                          onValueCommitted: function(val) { root.commitSelectedProperty("rotation", Math.round(val), "Rotation") }
                        }
                      }

                      // Separator before Opacity
                      Rectangle {
                        width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Feature C: Universal Element Opacity SmartScrubber
                      SmartScrubber {
                        label: "Opacity"
                        value: Math.round(((selectionOverlay.curAct && selectionOverlay.curAct.opacity !== undefined) ? selectionOverlay.curAct.opacity : 1.0) * 100)
                        from: 5
                        to: 100
                        step: 5
                        unit: "%"
                        tip: "Element opacity (drag or double-click to type)"
                        onValueScrubbed: function(val) { root.modifySelectedProperty("opacity", val / 100.0) }
                        onValueCommitted: function(val) { root.commitSelectedProperty("opacity", val / 100.0, "Opacity") }
                      }
                    }
                  }

                  // Separator Line before Drop Shadow Row
                  Rectangle {
                    visible: selRowShadowFlick.visible
                    width: parent.width
                    height: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.18)
                  }

                  // ==========================================
                  // ROW 6: DROP SHADOW ENGINE
                  // ==========================================
                  Flickable {
                    id: selRowShadowFlick
                    visible: Boolean(selectionOverlay.curAct && (
                      selectionOverlay.curAct.tool === "rect" ||
                      selectionOverlay.curAct.tool === "circle" ||
                      selectionOverlay.curAct.tool === "line" ||
                      selectionOverlay.curAct.tool === "arrow" ||
                      selectionOverlay.curAct.tool === "pen" ||
                      selectionOverlay.curAct.tool === "text" ||
                      selectionOverlay.curAct.tool === "stamp"
                    ))
                    width: parent.width
                    height: visible ? Style.space(20) : 0
                    contentWidth: selRowShadowContent.implicitWidth + Style.space(8)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                      id: selRowShadowContent
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      // Shadow Header Label
                      Text {
                        text: "Shadow:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.6)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      // Shadow Toggle Button
                      Rectangle {
                        property bool isShOn: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.shadow)
                        width: shTogRow.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
                        color: isShOn ? Color.accent : (shTogMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
                        border.width: 1
                        border.color: isShOn ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                          id: shTogRow
                          anchors.centerIn: parent
                          spacing: Style.space(2)
                          Text {
                            text: "◩"
                            font.pixelSize: Style.space(7.5)
                            color: parent.parent.isShOn ? "#FFFFFF" : Color.accent
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          Text {
                            text: parent.parent.isShOn ? "ON" : "OFF"
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            font.bold: true
                            color: parent.parent.isShOn ? "#FFFFFF" : (Color.popups.text || Color.text)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                        MouseArea {
                          id: shTogMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleSelectedShadow()
                        }
                        PanelToolTip { visible: shTogMouse.containsMouse; text: parent.isShOn ? "Disable drop shadow" : "Enable drop shadow" }
                      }

                      // Detailed Shadow Controls (spread/blur, opacity, offsets, color, eyedropper)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.shadow)
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Blur SmartScrubber
                        SmartScrubber {
                          label: "Blur"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.shadowBlur !== undefined) ? selectionOverlay.curAct.shadowBlur : root.dropShadowBlur
                          from: 0
                          to: 50
                          step: 2
                          unit: "px"
                          tip: "Shadow blur radius (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("shadowBlur", val); root.dropShadowBlur = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("shadowBlur", val, "Shadow Blur"); root.dropShadowBlur = val }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Opacity SmartScrubber
                        SmartScrubber {
                          label: "Opacity"
                          value: Math.round(((selectionOverlay.curAct && selectionOverlay.curAct.shadowOpacity !== undefined) ? selectionOverlay.curAct.shadowOpacity : root.dropShadowOpacity) * 100)
                          from: 0
                          to: 100
                          step: 5
                          unit: "%"
                          tip: "Shadow opacity (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("shadowOpacity", val / 100.0); root.dropShadowOpacity = val / 100.0 }
                          onValueCommitted: function(val) { root.commitSelectedProperty("shadowOpacity", val / 100.0, "Shadow Opacity"); root.dropShadowOpacity = val / 100.0 }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Offset X SmartScrubber
                        SmartScrubber {
                          label: "Off X"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.shadowOffsetX !== undefined) ? selectionOverlay.curAct.shadowOffsetX : root.dropShadowOffsetX
                          from: -40
                          to: 40
                          step: 2
                          unit: "px"
                          tip: "Shadow horizontal offset (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("shadowOffsetX", val); root.dropShadowOffsetX = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("shadowOffsetX", val, "Shadow Offset X"); root.dropShadowOffsetX = val }
                        }

                        // Offset Y SmartScrubber
                        SmartScrubber {
                          label: "Off Y"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.shadowOffsetY !== undefined) ? selectionOverlay.curAct.shadowOffsetY : root.dropShadowOffsetY
                          from: -40
                          to: 40
                          step: 2
                          unit: "px"
                          tip: "Shadow vertical offset (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("shadowOffsetY", val); root.dropShadowOffsetY = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("shadowOffsetY", val, "Shadow Offset Y"); root.dropShadowOffsetY = val }
                        }

                        // Separator
                        Rectangle { width: 1; height: Style.space(12); color: Util.alpha(Color.popups.text || Color.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Shadow Color Swatches (Using colorPalette)
                        Text {
                          text: "Color:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.55)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                          model: root.colorPalette
                          Rectangle {
                            required property string modelData
                            property string curCol: (selectionOverlay.curAct && selectionOverlay.curAct.shadowColor) || String(root.dropShadowColor)
                            width: Style.space(12); height: Style.space(12); radius: Style.space(6)
                            color: modelData
                            border.width: String(curCol).toLowerCase() === String(modelData).toLowerCase() ? 2 : 1
                            border.color: String(curCol).toLowerCase() === String(modelData).toLowerCase() ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.25)
                            scale: String(curCol).toLowerCase() === String(modelData).toLowerCase() ? 1.25 : 1.0
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                              id: scolMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedShadowColor(parent.modelData)
                            }
                            PanelToolTip { visible: scolMouse.containsMouse; text: "Shadow color: " + parent.modelData }
                          }
                        }

                        // Shadow Color Eyedropper
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: shedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰈊"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: shedMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "shadow"
                              root.requestScreenPick()
                            }
                          }
                          PanelToolTip { visible: shedMouse.containsMouse; text: "Pick shadow color from screen" }
                        }

                        // Shadow Color Studio Picker
                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: shStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰏘"; color: shStudioMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                          MouseArea {
                            id: shStudioMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.activeColorTarget = "shadow"
                              var cur = (selectionOverlay.curAct && selectionOverlay.curAct.shadowColor) || String(root.dropShadowColor)
                              if (cur) root.currentColor = cur
                              root.requestColorPicker()
                            }
                          }
                          PanelToolTip { visible: shStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
                        }
                      }
                    }
                  }
                }
              }

            // Direct Endpoint Handles for Line and Arrow
            Item {
              visible: Boolean(selectionOverlay.curAct && !selectionOverlay.curAct.locked && (selectionOverlay.curAct.tool === "line" || selectionOverlay.curAct.tool === "arrow") && selectionOverlay.curAct.start && selectionOverlay.curAct.end)
              anchors.fill: parent
              z: 25

              // Start Point Handle
              Rectangle {
                x: (selectionOverlay.curAct && selectionOverlay.curAct.start) ? (selectionOverlay.curAct.start.x * root.zoomScale - width / 2) : 0
                y: (selectionOverlay.curAct && selectionOverlay.curAct.start) ? (selectionOverlay.curAct.start.y * root.zoomScale - height / 2) : 0
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
                x: (selectionOverlay.curAct && selectionOverlay.curAct.end) ? (selectionOverlay.curAct.end.x * root.zoomScale - width / 2) : 0
                y: (selectionOverlay.curAct && selectionOverlay.curAct.end) ? (selectionOverlay.curAct.end.y * root.zoomScale - height / 2) : 0
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

  // ==========================================
  // DEVICE SYSTEM FONT PICKER DROPDOWN OVERLAY
  // ==========================================
  Item {
    id: fontPickerOverlay
    visible: root.fontPickerOpen
    anchors.fill: parent
    z: 150

    // Backdrop to dismiss dropdown popup when clicking anywhere outside
    MouseArea {
      anchors.fill: parent
      onClicked: function(mouse) {
        var cardPt = mapToItem(fontPickerCard, mouse.x, mouse.y)
        if (cardPt.x >= 0 && cardPt.x <= fontPickerCard.width && cardPt.y >= 0 && cardPt.y <= fontPickerCard.height) {
          return
        }
        if (typeof fontPickerTriggerBtn !== "undefined" && fontPickerTriggerBtn) {
          var btnPt = mapToItem(fontPickerTriggerBtn, mouse.x, mouse.y)
          if (btnPt.x >= 0 && btnPt.x <= fontPickerTriggerBtn.width && btnPt.y >= 0 && btnPt.y <= fontPickerTriggerBtn.height) {
            root.fontPickerOpen = false
            return
          }
        }
        root.fontPickerOpen = false
      }
    }

    // Dropdown popover card anchored directly to fontPickerTriggerBtn
    Rectangle {
      id: fontPickerCard
      width: Style.space(250)
      height: Style.space(310)
      radius: Style.space(6)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

      // Dynamic position anchoring under fontPickerTriggerBtn in root coordinates
      x: {
        if (!root.fontPickerOpen || typeof fontPickerTriggerBtn === "undefined" || !fontPickerTriggerBtn) {
          return root.width / 2 - width / 2
        }
        var pt = fontPickerTriggerBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.fontPickerOpen || typeof fontPickerTriggerBtn === "undefined" || !fontPickerTriggerBtn) {
          return root.height / 2 - height / 2
        }
        var pt = fontPickerTriggerBtn.mapToItem(root, 0, 0)
        var btnH = fontPickerTriggerBtn.height
        if (pt.y + btnH + height + Style.space(8) <= root.height) {
          return pt.y + btnH + Style.space(4)
        } else {
          return Math.max(Style.space(8), pt.y - height - Style.space(4))
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // Header
        Item {
          width: parent.width
          height: Style.space(20)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Text {
              text: "System Fonts"
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8.5)
              font.bold: true
              color: Color.popups.text || Color.text
              anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
              height: Style.space(14)
              width: fCountTxt.implicitWidth + Style.space(6)
              radius: Style.space(3)
              color: Util.alpha(Color.accent, 0.15)
              anchors.verticalCenter: parent.verticalCenter
              Text {
                id: fCountTxt
                anchors.centerIn: parent
                text: String(fontListView.filteredFonts ? fontListView.filteredFonts.length : 0)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7)
                font.bold: true
                color: Color.accent
              }
            }
          }

          // Close button
          Rectangle {
            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: cfbMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : "transparent"
            Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
            MouseArea {
              id: cfbMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.fontPickerOpen = false
            }
          }
        }

        // Search Box
        Rectangle {
          width: parent.width
          height: Style.space(24)
          radius: Style.space(4)
          color: Util.alpha(Color.popups.text || Color.text, 0.06)
          border.width: 1
          border.color: fontSearchInput.activeFocus ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: fontSearchInput.forceActiveFocus()
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(4)

            Text {
              text: "🔍"
              font.pixelSize: Style.space(7.5)
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: fontSearchInput
              width: parent.width - Style.space(34)
              anchors.verticalCenter: parent.verticalCenter
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              color: Color.popups.text || Color.text
              selectionColor: Color.accent
              selectedTextColor: "#FFFFFF"
              text: root.fontSearchQuery
              onTextChanged: root.fontSearchQuery = text

              Text {
                visible: !fontSearchInput.text && !fontSearchInput.activeFocus
                text: "Search " + root.systemFontFamilies.length + " fonts..."
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                color: Util.alpha(Color.popups.text || Color.text, 0.4)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            // Clear search button
            Rectangle {
              visible: fontSearchInput.text.length > 0
              width: Style.space(14); height: Style.space(14); radius: Style.space(7)
              color: clearSearchMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.2) : "transparent"
              anchors.verticalCenter: parent.verticalCenter
              Text { text: "✕"; font.pixelSize: Style.space(6.5); color: Color.popups.text || Color.text; anchors.centerIn: parent }
              MouseArea {
                id: clearSearchMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  fontSearchInput.text = ""
                  root.fontSearchQuery = ""
                  fontSearchInput.forceActiveFocus()
                }
              }
            }
          }
        }

        // Quick Category Filter Chips
        Row {
          spacing: Style.space(4)
          Repeater {
            model: [
              { id: "", label: "All", filter: "" },
              { id: "sans", label: "Sans", filter: "sans" },
              { id: "mono", label: "Mono", filter: "mono" },
              { id: "serif", label: "Serif", filter: "serif" }
            ]
            Rectangle {
              id: chipRect
              required property var modelData
              property bool isCurrent: {
                if (!chipRect.modelData.id) return !root.fontSearchQuery
                return (root.fontSearchQuery || "").toLowerCase() === chipRect.modelData.filter
              }
              width: chipTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
              color: isCurrent ? Color.accent : (chipMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.popups.text || Color.text, 0.06))
              border.width: 1
              border.color: isCurrent ? Color.accent : Util.alpha(Color.accent, 0.2)
              Text {
                id: chipTxt
                text: chipRect.modelData.label
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                color: chipRect.isCurrent ? "#FFFFFF" : Color.accent
                anchors.centerIn: parent
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.fontSearchQuery = chipRect.modelData.filter
                  fontSearchInput.text = chipRect.modelData.filter
                }
              }
            }
          }
        }

        // Live Font List
        ListView {
          id: fontListView
          width: parent.width
          height: fontPickerCard.height - Style.space(88)
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: Style.space(4)
          }

          readonly property var filteredFonts: {
            var q = (root.fontSearchQuery || "").trim().toLowerCase()
            var list = root.systemFontFamilies || []
            if (!q) return list
            return list.filter(function(f) {
              return f.toLowerCase().indexOf(q) !== -1
            })
          }

          model: filteredFonts

          delegate: Rectangle {
            id: fItemDelegate
            required property string modelData
            property bool isSelected: {
              if (selectionOverlay.curAct && selectionOverlay.curAct.fontFamily) {
                return selectionOverlay.curAct.fontFamily === modelData
              }
              return (root.defaultFontFamily || "sans") === modelData
            }
            width: fontListView.width
            height: Style.space(24)
            radius: Style.space(3)
            color: isSelected ? Util.alpha(Color.accent, 0.25) : (fItemMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              Text {
                text: fItemDelegate.modelData
                font.family: fItemDelegate.modelData
                font.pixelSize: Style.space(8.5)
                color: fItemDelegate.isSelected ? Color.accent : (Color.popups.text || Color.text)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: parent.width - (fItemDelegate.isSelected ? Style.space(20) : 0)
              }

              Text {
                visible: fItemDelegate.isSelected
                text: "✓"
                color: Color.accent
                font.bold: true
                font.pixelSize: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: fItemMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.setSelectedFontFamily(fItemDelegate.modelData)
                root.fontPickerOpen = false
              }
            }
          }

          // Empty State if no fonts match
          Item {
            visible: fontListView.count === 0
            width: parent.width
            height: Style.space(80)
            Text {
              anchors.centerIn: parent
              text: "No fonts matching \"" + root.fontSearchQuery + "\""
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              color: Util.alpha(Color.popups.text || Color.text, 0.5)
            }
          }
        }
      }
    }
  }

  function drawRoundedRectPath(ctx, x, y, w, h, r) {
    var rad = Math.max(0, Math.min(r, Math.min(w / 2, h / 2)))
    if (rad <= 0) {
      ctx.rect(x, y, w, h)
      return
    }
    ctx.moveTo(x + rad, y)
    ctx.lineTo(x + w - rad, y)
    ctx.arcTo(x + w, y, x + w, y + rad, rad)
    ctx.lineTo(x + w, y + h - rad)
    ctx.arcTo(x + w, y + h, x + w - rad, y + h, rad)
    ctx.lineTo(x + rad, y + h)
    ctx.arcTo(x, y + h, x, y + h - rad, rad)
    ctx.lineTo(x, y + rad)
    ctx.arcTo(x, y, x + rad, y, rad)
    ctx.closePath()
  }

  function drawEllipsePath(ctx, x, y, w, h) {
    var ex = Math.min(x, x + w)
    var ey = Math.min(y, y + h)
    var ew = Math.max(1, Math.abs(w))
    var eh = Math.max(1, Math.abs(h))
    if (typeof ctx.ellipse === "function") {
      ctx.ellipse(ex, ey, ew, eh)
    } else {
      var cx = ex + ew / 2
      var cy = ey + eh / 2
      var rx = ew / 2
      var ry = eh / 2
      var kappa = 0.5522847498307936
      var ox = rx * kappa
      var oy = ry * kappa
      ctx.moveTo(cx - rx, cy)
      ctx.bezierCurveTo(cx - rx, cy - oy, cx - ox, cy - ry, cx, cy - ry)
      ctx.bezierCurveTo(cx + ox, cy - ry, cx + rx, cy - oy, cx + rx, cy)
      ctx.bezierCurveTo(cx + rx, cy + oy, cx + ox, cy + ry, cx, cy + ry)
      ctx.bezierCurveTo(cx - ox, cy + ry, cx - rx, cy + oy, cx - rx, cy)
      ctx.closePath()
    }
  }

  function drawCutoutRoundedRect(ctx, x, y, w, h, r) {
    var rad = Math.max(0, Math.min(r, Math.min(w / 2, h / 2)))
    if (rad <= 0) {
      ctx.moveTo(x, y)
      ctx.lineTo(x, y + h)
      ctx.lineTo(x + w, y + h)
      ctx.lineTo(x + w, y)
      ctx.closePath()
      return
    }
    ctx.moveTo(x, y + rad)
    ctx.lineTo(x, y + h - rad)
    ctx.arcTo(x, y + h, x + rad, y + h, rad)
    ctx.lineTo(x + w - rad, y + h)
    ctx.arcTo(x + w, y + h, x + w, y + h - rad, rad)
    ctx.lineTo(x + w, y + rad)
    ctx.arcTo(x + w, y, x + w - rad, y, rad)
    ctx.lineTo(x + rad, y)
    ctx.arcTo(x, y, x, y + rad, rad)
    ctx.closePath()
  }

  function drawCutoutEllipse(ctx, x, y, w, h) {
    var ex = Math.min(x, x + w)
    var ey = Math.min(y, y + h)
    var ew = Math.max(1, Math.abs(w))
    var eh = Math.max(1, Math.abs(h))
    var cx = ex + ew / 2
    var cy = ey + eh / 2
    var rx = ew / 2
    var ry = eh / 2
    var kappa = 0.5522847498307936
    var ox = rx * kappa
    var oy = ry * kappa
    ctx.moveTo(cx + rx, cy)
    ctx.bezierCurveTo(cx + rx, cy - oy, cx + ox, cy - ry, cx, cy - ry)
    ctx.bezierCurveTo(cx - ox, cy - ry, cx - rx, cy - oy, cx - rx, cy)
    ctx.bezierCurveTo(cx - rx, cy + oy, cx - ox, cy + ry, cx, cy + ry)
    ctx.bezierCurveTo(cx + ox, cy + ry, cx + rx, cy + oy, cx + rx, cy)
    ctx.closePath()
  }

  function renderUnifiedSpotlightDim(ctx, spotlights) {
    if (!spotlights || spotlights.length === 0) return

    ctx.save()
    ctx.beginPath()

    var outMargin = 10000
    var outX = -outMargin
    var outY = -outMargin
    var outW = (root.imageWidth || 4000) + outMargin * 2
    var outH = (root.imageHeight || 4000) + outMargin * 2

    // Outer rect boundary (clockwise)
    ctx.moveTo(outX, outY)
    ctx.lineTo(outX + outW, outY)
    ctx.lineTo(outX + outW, outY + outH)
    ctx.lineTo(outX, outY + outH)
    ctx.closePath()

    // Inner cutouts for all active spotlights (counter-clockwise)
    for (var i = 0; i < spotlights.length; i++) {
      var s = spotlights[i]
      if (!s || !s.start || !s.end) continue
      var sx = Math.min(s.start.x, s.end.x)
      var sy = Math.min(s.start.y, s.end.y)
      var sw = Math.max(1, Math.abs(s.end.x - s.start.x))
      var sh = Math.max(1, Math.abs(s.end.y - s.start.y))
      var shape = s.shape || "rect"

      if (shape === "circle") {
        root.drawCutoutEllipse(ctx, sx, sy, sw, sh)
      } else {
        var sRad = (s.radius !== undefined) ? s.radius : root.spotlightRadius
        root.drawCutoutRoundedRect(ctx, sx, sy, sw, sh, sRad)
      }
    }

    ctx.fillStyle = root.spotlightDimColor || "#000000"
    ctx.globalAlpha = (root.spotlightDimOpacity !== undefined ? root.spotlightDimOpacity : 0.65)
    ctx.fill()
    ctx.restore()
  }

  // Helper drawing functions
  function renderAction(ctx, act) {
    if (!act) return
    ctx.save()

    var elemOpacity = (act.opacity !== undefined) ? Number(act.opacity) : 1.0
    if (elemOpacity < 1.0) {
      ctx.globalAlpha = ctx.globalAlpha * elemOpacity
    }

    var actRotation = (act.rotation !== undefined) ? Number(act.rotation) : 0
    if (actRotation !== 0) {
      var bRot = root.getActionBounds(act)
      if (bRot && bRot.width > 0 && bRot.height > 0) {
        var cx = bRot.x + bRot.width / 2
        var cy = bRot.y + bRot.height / 2
        ctx.translate(cx, cy)
        ctx.rotate(actRotation * Math.PI / 180)
        ctx.translate(-cx, -cy)
      }
    }

    var actColor = String(act.color || "#EF4444")
    var actWidth = (typeof act.width !== "undefined") ? Number(act.width) : 4

    var hasShadow = Boolean(act.shadow)
    var shadowCol = hasShadow ? root.formatColorWithAlpha(act.shadowColor || "#000000", (act.shadowOpacity !== undefined ? act.shadowOpacity : 0.45)) : "transparent"
    var shadowBlur = hasShadow ? (act.shadowBlur !== undefined ? act.shadowBlur : 8) : 0
    var shadowOffX = hasShadow ? (act.shadowOffsetX !== undefined ? act.shadowOffsetX : 0) : 0
    var shadowOffY = hasShadow ? (act.shadowOffsetY !== undefined ? act.shadowOffsetY : 4) : 0

    function enableShadow() {
      if (hasShadow) {
        ctx.shadowColor = shadowCol
        ctx.shadowBlur = shadowBlur
        ctx.shadowOffsetX = shadowOffX
        ctx.shadowOffsetY = shadowOffY
      }
    }

    function disableShadow() {
      ctx.shadowColor = "transparent"
      ctx.shadowBlur = 0
      ctx.shadowOffsetX = 0
      ctx.shadowOffsetY = 0
    }

    function applyDash() {
      if (act.dashStyle === "dashed") {
        ctx.setLineDash([Math.max(6, actWidth * 2.5), Math.max(4, actWidth * 1.5)])
      } else if (act.dashStyle === "dotted") {
        ctx.setLineDash([Math.max(2, actWidth), Math.max(3, actWidth * 1.5)])
      } else {
        ctx.setLineDash([])
      }
    }

    function clearDash() {
      ctx.setLineDash([])
    }

    try {
      if (act.tool === "pen") {
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.lineWidth = actWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        var pts = act.points || []
        if (pts.length === 1) {
          enableShadow()
          ctx.arc(pts[0].x, pts[0].y, actWidth / 2, 0, Math.PI * 2)
          ctx.fillStyle = actColor
          ctx.fill()
          disableShadow()
        } else if (pts.length >= 2) {
          enableShadow()
          ctx.moveTo(pts[0].x, pts[0].y)
          for (var j = 1; j < pts.length; j++) {
            ctx.lineTo(pts[j].x, pts[j].y)
          }
          applyDash()
          ctx.stroke()
          clearDash()
          disableShadow()
        }
      } else if (act.tool === "highlighter") {
        ctx.globalAlpha = 0.35 * elemOpacity
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
        var rx = Math.min(act.start.x, act.end.x)
        var ry = Math.min(act.start.y, act.end.y)
        var rw = Math.abs(act.end.x - act.start.x)
        var rh = Math.abs(act.end.y - act.start.y)
        var fMode = act.fillMode || (act.filled ? "semi" : "none")
        var rad = (act.radius !== undefined) ? Number(act.radius) : 0
        rad = Math.max(0, Math.min(rad, Math.min(rw / 2, rh / 2)))

        function buildRectPath() {
          ctx.beginPath()
          if (rad > 0) {
            ctx.moveTo(rx + rad, ry)
            ctx.lineTo(rx + rw - rad, ry)
            ctx.arcTo(rx + rw, ry, rx + rw, ry + rad, rad)
            ctx.lineTo(rx + rw, ry + rh - rad)
            ctx.arcTo(rx + rw, ry + rh, rx + rw - rad, ry + rh, rad)
            ctx.lineTo(rx + rad, ry + rh)
            ctx.arcTo(rx, ry + rh, rx, ry + rh - rad, rad)
            ctx.lineTo(rx, ry + rad)
            ctx.arcTo(rx, ry, rx + rad, ry, rad)
            ctx.closePath()
          } else {
            ctx.rect(rx, ry, rw, rh)
          }
        }

        if (fMode !== "none") {
          enableShadow()
          ctx.fillStyle = String(act.fillColor || actColor)
          var baseAlpha = (fMode === "solid") ? 1.0 : (act.fillAlpha !== undefined ? act.fillAlpha : 0.25)
          ctx.globalAlpha = elemOpacity * baseAlpha
          buildRectPath()
          ctx.fill()
          ctx.globalAlpha = elemOpacity
          disableShadow()
        }
        if (actWidth > 0) {
          if (fMode === "none") {
            enableShadow()
          } else {
            disableShadow()
          }
          ctx.strokeStyle = actColor
          ctx.lineWidth = actWidth
          buildRectPath()
          applyDash()
          ctx.stroke()
          clearDash()
          disableShadow()
        }
      } else if (act.tool === "circle" && act.start && act.end) {
        var cx = Math.min(act.start.x, act.end.x)
        var cy = Math.min(act.start.y, act.end.y)
        var cw = Math.max(1, Math.abs(act.end.x - act.start.x))
        var ch = Math.max(1, Math.abs(act.end.y - act.start.y))
        var fMode = act.fillMode || (act.filled ? "semi" : "none")
        if (fMode !== "none") {
          ctx.beginPath()
          root.drawEllipsePath(ctx, cx, cy, cw, ch)
          enableShadow()
          ctx.fillStyle = String(act.fillColor || actColor)
          var baseCircAlpha = (fMode === "solid") ? 1.0 : (act.fillAlpha !== undefined ? act.fillAlpha : 0.25)
          ctx.globalAlpha = elemOpacity * baseCircAlpha
          ctx.fill()
          ctx.globalAlpha = elemOpacity
          disableShadow()
        }
        if (actWidth > 0) {
          ctx.beginPath()
          root.drawEllipsePath(ctx, cx, cy, cw, ch)
          if (fMode === "none") {
            enableShadow()
          } else {
            disableShadow()
          }
          ctx.strokeStyle = actColor
          ctx.lineWidth = actWidth
          applyDash()
          ctx.stroke()
          clearDash()
          disableShadow()
        }
      } else if ((act.tool === "line" || act.tool === "arrow") && act.start && act.end) {
        var hStyle = act.headStyle || (act.tool === "arrow" ? "end" : "none")
        enableShadow()
        ctx.beginPath()
        ctx.strokeStyle = actColor
        ctx.fillStyle = actColor
        ctx.lineWidth = actWidth
        ctx.lineCap = "round"
        ctx.moveTo(act.start.x, act.start.y)
        ctx.lineTo(act.end.x, act.end.y)
        applyDash()
        ctx.stroke()
        clearDash()

        var headLen = Math.max(12, actWidth * 3.5)
        if (hStyle === "end" || hStyle === "both") {
          var angleEnd = Math.atan2(act.end.y - act.start.y, act.end.x - act.start.x)
          ctx.beginPath()
          ctx.moveTo(act.end.x, act.end.y)
          ctx.lineTo(act.end.x - headLen * Math.cos(angleEnd - Math.PI / 6), act.end.y - headLen * Math.sin(angleEnd - Math.PI / 6))
          ctx.lineTo(act.end.x - headLen * Math.cos(angleEnd + Math.PI / 6), act.end.y - headLen * Math.sin(angleEnd + Math.PI / 6))
          ctx.closePath()
          ctx.fill()
        }
        if (hStyle === "both") {
          var angleStart = Math.atan2(act.start.y - act.end.y, act.start.x - act.end.x)
          ctx.beginPath()
          ctx.moveTo(act.start.x, act.start.y)
          ctx.lineTo(act.start.x - headLen * Math.cos(angleStart - Math.PI / 6), act.start.y - headLen * Math.sin(angleStart - Math.PI / 6))
          ctx.lineTo(act.start.x - headLen * Math.cos(angleStart + Math.PI / 6), act.start.y - headLen * Math.sin(angleStart + Math.PI / 6))
          ctx.closePath()
          ctx.fill()
        }
        disableShadow()
      } else if (act.tool === "blur" && act.start && act.end) {
        var bx = Math.min(act.start.x, act.end.x)
        var by = Math.min(act.start.y, act.end.y)
        var bw = Math.abs(act.end.x - act.start.x)
        var bh = Math.abs(act.end.y - act.start.y)
        ctx.save()
        // Frosted base
        ctx.fillStyle = "rgba(15, 23, 42, 0.78)"
        ctx.fillRect(bx, by, bw, bh)
        // Multi-sample optical dispersion
        if (baseImage && baseImage.status === Image.Ready) {
          ctx.globalAlpha = 0.16 * elemOpacity
          var blurDisp = (act.dispersion !== undefined) ? Number(act.dispersion) : 4
          var ds = Math.max(0.5, blurDisp / 4)
          var blurOffsets = [[-2*ds, -2*ds], [2*ds, -2*ds], [-2*ds, 2*ds], [2*ds, 2*ds], [-4*ds, 0], [4*ds, 0], [0, -4*ds], [0, 4*ds]]
          for (var bo = 0; bo < blurOffsets.length; bo++) {
            var ox = blurOffsets[bo][0]
            var oy = blurOffsets[bo][1]
            ctx.drawImage(baseImage, bx + ox, by + oy, bw, bh, bx, by, bw, bh)
          }
        }
        ctx.globalAlpha = elemOpacity
        // Glass specular tint and crisp border
        ctx.fillStyle = "rgba(255, 255, 255, 0.07)"
        ctx.fillRect(bx, by, bw, bh)
        ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
        ctx.lineWidth = 1
        ctx.strokeRect(bx, by, bw, bh)
        ctx.restore()
      } else if (act.tool === "block_highlight" && act.start && act.end) {
        var hx = Math.min(act.start.x, act.end.x)
        var hy = Math.min(act.start.y, act.end.y)
        var hw = Math.abs(act.end.x - act.start.x)
        var hh = Math.abs(act.end.y - act.start.y)
        ctx.save()
        ctx.fillStyle = actColor
        ctx.globalAlpha = 0.35 * elemOpacity
        ctx.fillRect(hx, hy, hw, hh)
        ctx.restore()
      } else if (act.tool === "pixelate" && act.start && act.end) {
        var px = Math.min(act.start.x, act.end.x)
        var py = Math.min(act.start.y, act.end.y)
        var pw = Math.abs(act.end.x - act.start.x)
        var ph = Math.abs(act.end.y - act.start.y)
        var blockSize = act.pixelSize || Math.max(8, Math.min(24, Math.round(Math.min(pw, ph) / 8)))

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
        var weightStr = (act.fontWeight === "normal") ? "normal" : "bold"
        var famStr = "sans-serif"
        if (act.fontFamily === "mono") famStr = "monospace"
        else if (act.fontFamily === "serif") famStr = "serif"
        else if (act.fontFamily) famStr = '"' + act.fontFamily + '", sans-serif'
        var styleStr = act.italic ? "italic " : ""
        ctx.font = styleStr + weightStr + " " + fs + "px " + famStr
        var tAlign = act.textAlign || "left"
        ctx.textAlign = tAlign
        ctx.textBaseline = "top"

        var rawText = act.text || ""
        var dispText = rawText
        if (act.textTransform === "uppercase") {
          dispText = rawText.toUpperCase()
        } else if (act.textTransform === "lowercase") {
          dispText = rawText.toLowerCase()
        } else if (act.textTransform === "capitalize") {
          dispText = rawText.replace(/\b\w/g, function(l) { return l.toUpperCase() })
        }

        var tw = ctx.measureText(dispText).width
        var padX = Math.round(fs * 0.45)
        var padY = Math.round(fs * 0.25)
        var bx = act.pos.x - padX
        if (tAlign === "center") {
          bx = act.pos.x - tw / 2 - padX
        } else if (tAlign === "right") {
          bx = act.pos.x - tw - padX
        }
        var by = act.pos.y - padY
        var bw = tw + padX * 2
        var bh = fs + padY * 2

        var lineX1 = act.pos.x
        var lineX2 = act.pos.x + tw
        if (tAlign === "center") {
          lineX1 = act.pos.x - tw / 2
          lineX2 = act.pos.x + tw / 2
        } else if (tAlign === "right") {
          lineX1 = act.pos.x - tw
          lineX2 = act.pos.x
        }
        var strikeY = Math.round(act.pos.y + fs * 0.52)
        var underY = Math.round(act.pos.y + fs * 1.02)
        var decoThick = Math.max(1.5, Math.round(fs / 14))

        var hasOutline = Boolean(act.halo || act.stroke)
        var outlineCol = act.haloColor || act.strokeColor || (root.isColorDark(actColor) ? "#FFFFFF" : "#000000")
        var outlineW = (act.haloWidth !== undefined ? act.haloWidth : (act.strokeWidth !== undefined ? act.strokeWidth : 3))

        if (act.box) {
          ctx.save()
          enableShadow()
          var boxCol = act.boxColor || "#0F172A"
          var boxOp = (act.boxOpacity !== undefined) ? Number(act.boxOpacity) : 0.88
          ctx.fillStyle = root.hexToRgba(boxCol, boxOp)
          var cr = (act.boxRadius !== undefined) ? Math.min(Number(act.boxRadius), Math.min(bw / 4, bh / 4)) : Math.min(6, Math.min(bw / 4, bh / 4))
          ctx.beginPath()
          ctx.moveTo(bx + cr, by)
          ctx.lineTo(bx + bw - cr, by)
          ctx.arcTo(bx + bw, by, bx + bw, by + cr, cr)
          ctx.lineTo(bx + bw, by + bh - cr)
          ctx.arcTo(bx + bw, by + bh, bx + bw - cr, by + bh, cr)
          ctx.lineTo(bx + cr, by + bh)
          ctx.arcTo(bx, by + bh, bx, by + bh - cr, cr)
          ctx.lineTo(bx, by + cr)
          ctx.arcTo(bx, by, bx + cr, by, cr)
          ctx.closePath()
          ctx.fill()
          disableShadow()
          ctx.strokeStyle = actColor
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.restore()

          if (hasOutline) {
            ctx.strokeStyle = outlineCol
            ctx.lineWidth = outlineW * 2
            ctx.lineJoin = "round"
            ctx.miterLimit = 2
            ctx.strokeText(dispText, act.pos.x, act.pos.y)
            if (act.underline) {
              ctx.beginPath()
              ctx.moveTo(lineX1, underY)
              ctx.lineTo(lineX2, underY)
              ctx.lineWidth = decoThick + outlineW * 2
              ctx.strokeStyle = outlineCol
              ctx.stroke()
            }
            if (act.strikeout) {
              ctx.beginPath()
              ctx.moveTo(lineX1, strikeY)
              ctx.lineTo(lineX2, strikeY)
              ctx.lineWidth = decoThick + outlineW * 2
              ctx.strokeStyle = outlineCol
              ctx.stroke()
            }
          }

          ctx.fillStyle = actColor
          ctx.fillText(dispText, act.pos.x, act.pos.y)
          if (act.underline) {
            ctx.beginPath()
            ctx.moveTo(lineX1, underY)
            ctx.lineTo(lineX2, underY)
            ctx.lineWidth = decoThick
            ctx.strokeStyle = actColor
            ctx.stroke()
          }
          if (act.strikeout) {
            ctx.beginPath()
            ctx.moveTo(lineX1, strikeY)
            ctx.lineTo(lineX2, strikeY)
            ctx.lineWidth = decoThick
            ctx.strokeStyle = actColor
            ctx.stroke()
          }
        } else {
          enableShadow()
          if (hasOutline) {
            ctx.strokeStyle = outlineCol
            ctx.lineWidth = outlineW * 2
            ctx.lineJoin = "round"
            ctx.miterLimit = 2
            ctx.strokeText(dispText, act.pos.x, act.pos.y)
            if (act.underline) {
              ctx.beginPath()
              ctx.moveTo(lineX1, underY)
              ctx.lineTo(lineX2, underY)
              ctx.lineWidth = decoThick + outlineW * 2
              ctx.strokeStyle = outlineCol
              ctx.stroke()
            }
            if (act.strikeout) {
              ctx.beginPath()
              ctx.moveTo(lineX1, strikeY)
              ctx.lineTo(lineX2, strikeY)
              ctx.lineWidth = decoThick + outlineW * 2
              ctx.strokeStyle = outlineCol
              ctx.stroke()
            }
          }
          disableShadow()
          ctx.fillStyle = actColor
          ctx.fillText(dispText, act.pos.x, act.pos.y)
          if (act.underline) {
            ctx.beginPath()
            ctx.moveTo(lineX1, underY)
            ctx.lineTo(lineX2, underY)
            ctx.lineWidth = decoThick
            ctx.strokeStyle = actColor
            ctx.stroke()
          }
          if (act.strikeout) {
            ctx.beginPath()
            ctx.moveTo(lineX1, strikeY)
            ctx.lineTo(lineX2, strikeY)
            ctx.lineWidth = decoThick
            ctx.strokeStyle = actColor
            ctx.stroke()
          }
        }
      } else if (act.tool === "magnifier" && act.start) {
        var magR = (act.radius !== undefined) ? Number(act.radius) : 50
        var magZoom = (act.zoom !== undefined) ? Number(act.zoom) : 2.0
        var magCenterX = act.start.x
        var magCenterY = act.start.y
        var magBorderW = (act.borderWidth !== undefined) ? act.borderWidth : 3
        var magColor = act.color || "#3B82F6"

        ctx.save()
        // Draw shadow under the lens
        enableShadow()
        ctx.beginPath()
        ctx.arc(magCenterX, magCenterY, magR, 0, Math.PI * 2)
        ctx.fillStyle = "#1E293B"
        ctx.fill()
        disableShadow()

        // Clip to circular lens
        ctx.save()
        ctx.beginPath()
        ctx.arc(magCenterX, magCenterY, magR, 0, Math.PI * 2)
        ctx.clip()

        // Draw magnified base image
        if (baseImage && baseImage.status === Image.Ready) {
          var srcW = (magR * 2) / magZoom
          var srcH = (magR * 2) / magZoom
          var srcX = magCenterX - srcW / 2
          var srcY = magCenterY - srcH / 2
          ctx.drawImage(baseImage, srcX, srcY, srcW, srcH, magCenterX - magR, magCenterY - magR, magR * 2, magR * 2)
        } else {
          ctx.fillStyle = "#0F172A"
          ctx.fill()
        }

        // Lens specular glare / reflection
        var grad = ctx.createLinearGradient(magCenterX - magR, magCenterY - magR, magCenterX + magR, magCenterY + magR)
        grad.addColorStop(0, "rgba(255, 255, 255, 0.25)")
        grad.addColorStop(0.4, "rgba(255, 255, 255, 0.03)")
        grad.addColorStop(1, "rgba(0, 0, 0, 0.15)")
        ctx.fillStyle = grad
        ctx.beginPath()
        ctx.arc(magCenterX, magCenterY, magR, 0, Math.PI * 2)
        ctx.fill()

        // Subtle crosshair
        ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(magCenterX - 8, magCenterY)
        ctx.lineTo(magCenterX + 8, magCenterY)
        ctx.moveTo(magCenterX, magCenterY - 8)
        ctx.lineTo(magCenterX, magCenterY + 8)
        ctx.stroke()

        ctx.restore() // unclip

        // Outer lens metallic rim
        ctx.strokeStyle = magColor
        ctx.lineWidth = magBorderW
        ctx.beginPath()
        ctx.arc(magCenterX, magCenterY, magR, 0, Math.PI * 2)
        ctx.stroke()

        // Inner rim accent
        ctx.strokeStyle = "rgba(255, 255, 255, 0.6)"
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.arc(magCenterX, magCenterY, magR - magBorderW / 2, 0, Math.PI * 2)
        ctx.stroke()

        // Zoom Badge at bottom of lens
        var badgeText = magZoom.toFixed(1) + "×"
        ctx.font = "bold 10px sans-serif"
        var badgeTw = ctx.measureText(badgeText).width
        var badgeW = badgeTw + 10
        var badgeH = 16
        var badgeX = magCenterX - badgeW / 2
        var badgeY = magCenterY + magR - badgeH / 2
        ctx.fillStyle = "rgba(15, 23, 42, 0.85)"
        ctx.beginPath()
        ctx.rect(badgeX, badgeY, badgeW, badgeH)
        ctx.fill()
        ctx.strokeStyle = magColor
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.fillStyle = "#FFFFFF"
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(badgeText, magCenterX, badgeY + badgeH / 2)

        ctx.restore()
      } else if (act.tool === "stamp" && act.pos) {
        var sx = act.pos.x
        var sy = act.pos.y
        var sr = (act.radius !== undefined) ? Number(act.radius) : 18
        if (act.radius !== undefined) sr = Number(act.radius)
        else if (act.stampSize === "S") sr = 14
        else if (act.stampSize === "M") sr = 18
        else if (act.stampSize === "L") sr = 24
        else if (act.stampSize === "XL") sr = 32
        else sr = Math.max(14, actWidth * 3)

        ctx.save()
        // Circular badge background (shared across all stamps for visual consistency)
        enableShadow()
        ctx.fillStyle = actColor
        ctx.beginPath()
        ctx.arc(sx, sy, sr, 0, Math.PI * 2)
        ctx.fill()
        disableShadow()
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
      } else if (act.tool === "spotlight" && act.start && act.end) {
        var spX = Math.min(act.start.x, act.end.x)
        var spY = Math.min(act.start.y, act.end.y)
        var spW = Math.max(1, Math.abs(act.end.x - act.start.x))
        var spH = Math.max(1, Math.abs(act.end.y - act.start.y))
        var spShape = act.shape || "rect"
        var spRad = (act.radius !== undefined) ? act.radius : root.spotlightRadius
        var spBorderW = (act.borderWidth !== undefined) ? act.borderWidth : 2
        var spBorderCol = act.borderColor || "#FFFFFF"
        var spZoom = (act.zoom !== undefined) ? act.zoom : 1.0

        // Optional Magnification Zoom inside spotlight cutout
        if (spZoom > 1.0 && baseImage && baseImage.status === Image.Ready) {
          ctx.save()
          ctx.beginPath()
          if (spShape === "circle") {
            root.drawEllipsePath(ctx, spX, spY, spW, spH)
          } else {
            root.drawRoundedRectPath(ctx, spX, spY, spW, spH, spRad)
          }
          ctx.clip()
          var spZoomSrcW = spW / spZoom
          var spZoomSrcH = spH / spZoom
          var spZoomSrcX = (spX + spW / 2) - spZoomSrcW / 2
          var spZoomSrcY = (spY + spH / 2) - spZoomSrcH / 2
          ctx.drawImage(baseImage, spZoomSrcX, spZoomSrcY, spZoomSrcW, spZoomSrcH, spX, spY, spW, spH)
          ctx.restore()
        }

        // Stroke individual spotlight rim border
        if (spBorderW > 0) {
          ctx.save()
          ctx.beginPath()
          if (spShape === "circle") {
            root.drawEllipsePath(ctx, spX, spY, spW, spH)
          } else {
            root.drawRoundedRectPath(ctx, spX, spY, spW, spH, spRad)
          }
          ctx.strokeStyle = spBorderCol
          ctx.lineWidth = spBorderW
          ctx.globalAlpha = elemOpacity
          ctx.stroke()
          ctx.restore()
        }
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
