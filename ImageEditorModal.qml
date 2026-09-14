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
  // Modular Component Aliases
  property alias layerListView: layersPanel.layerListView
  property alias fontPickerTriggerBtn: propInspector.fontPickerTriggerBtn
  property alias fontSearchInput: fontPickerOverlay.fontSearchInput

  signal runOcr(string path)
  signal requestQrDecode(string path)
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
  property string blurShape: "rect"
  property int blurRadius: 0
  property int blurDispersion: 4
  property bool aspectRatioLocked: false
  property var scrubStartAct: null
  property bool layerPanelOpen: false
  property int layerRevision: 0
  property var selectedActionIndices: []
  property int groupCounter: 1
  property string layerSearchQuery: ""
  property int editingLayerIndex: -1
  property int dragLayerSourceIndex: -1
  property int dragLayerTargetIndex: -1

  readonly property var visibleLayerIndices: {
    var _rev = root.layerRevision
    var q = (root.layerSearchQuery || "").trim().toLowerCase()
    var list = []
    for (var i = root.actions.length - 1; i >= 0; i--) {
      if (!q) {
        list.push(i)
      } else {
        var act = root.actions[i]
        var title = root.getLayerTitle(act, i).toLowerCase()
        var tool = String((act && act.tool) || "").toLowerCase()
        if (title.indexOf(q) !== -1 || tool.indexOf(q) !== -1) {
          list.push(i)
        }
      }
    }
    return list
  }

  onActionsChanged: {
    layerRevision++
  }

  onSelectedActionIndexChanged: {
    if (selectedActionIndex < 0) {
      root.selectedActionIndices = []
    } else if (root.selectedActionIndices.indexOf(selectedActionIndex) === -1) {
      root.selectedActionIndices = [selectedActionIndex]
    }
    if (selectedActionIndex < 0 || !actions[selectedActionIndex] || actions[selectedActionIndex].tool !== "text") {
      fontPickerOpen = false
    }
    if (selectedActionIndex >= 0 && root.layerPanelOpen && typeof layerListView !== "undefined" && layerListView && layerListView.count > 0) {
      var uiIndex = root.visibleLayerIndices ? root.visibleLayerIndices.indexOf(selectedActionIndex) : (root.actions.length - 1 - selectedActionIndex)
      if (uiIndex >= 0 && uiIndex < layerListView.count) {
        layerListView.positionViewAtIndex(uiIndex, ListView.Contain)
      }
    }
  }

  onLayerPanelOpenChanged: {
    if (layerPanelOpen && selectedActionIndex >= 0 && typeof layerListView !== "undefined" && layerListView && layerListView.count > 0) {
      var uiIndex = root.visibleLayerIndices ? root.visibleLayerIndices.indexOf(selectedActionIndex) : (root.actions.length - 1 - selectedActionIndex)
      if (uiIndex >= 0 && uiIndex < layerListView.count) {
        layerListView.positionViewAtIndex(uiIndex, ListView.Contain)
      }
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
    var home = Quickshell.env("HOME") || ""
    if (home.length > 0) {
      Quickshell.execDetached(["mkdir", "-p", home + "/Pictures/Screenshots", home + "/.local/state/reclip"])
    }
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

  Process {
    id: ensureSaveDirProc
    property string pendingSaveMode: ""
    property string pendingTargetDir: ""
    property string pendingTargetFile: ""
    command: []
    onExited: function(code) {
      if (code === 0) {
        root.proceedGrabAndSave(pendingSaveMode, pendingTargetFile)
      } else {
        root.isExporting = false
        console.warn("ReClip ImageEditor: Failed to ensure directory: " + pendingTargetDir)
        root.showFeedback("⚠ Cannot create folder: " + pendingTargetDir)
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
      "group": "󰉋 Group",
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
    if (act.name && String(act.name).trim().length > 0) return String(act.name).trim()
    return map[act.tool] || act.tool
  }

  function getLayerTitle(act, idx) {
    if (!act) return "Layer " + (idx + 1)
    if (act.name && String(act.name).trim().length > 0) {
      return String(act.name).trim()
    }
    if (act.tool === "group") {
      var cCount = act.children ? act.children.length : 0
      return "Group (" + cCount + " " + (cCount === 1 ? "layer" : "layers") + ")"
    }
    if (act.tool === "text") {
      if (act.text && String(act.text).trim().length > 0) {
        var txt = String(act.text).trim().replace(/\s+/g, " ")
        return "Text: \"" + (txt.length > 14 ? (txt.substring(0, 14) + "…") : txt) + "\""
      }
      return "Text"
    }
    if (act.tool === "spotlight") {
      return act.shape === "circle" ? "Spotlight (Circle)" : "Spotlight (Rect)"
    }
    if (act.tool === "blur") {
      return act.shape === "circle" ? "Blur (Circle)" : "Blur (Rect)"
    }
    if (act.tool === "stamp") {
      return "Stamp (" + (act.stampType || "number") + (act.stampValue !== undefined ? (": " + act.stampValue) : "") + ")"
    }
    if (act.tool === "magnifier") {
      return "Magnifier (" + (act.zoom || 2.0).toFixed(1) + "x)"
    }
    if (act.tool === "rect") {
      return "Rectangle"
    }
    if (act.tool === "circle") {
      return "Circle / Oval"
    }
    if (act.tool === "arrow") {
      return "Arrow"
    }
    if (act.tool === "line") {
      return "Line"
    }
    if (act.tool === "pen") {
      return "Pen Stroke"
    }
    if (act.tool === "highlighter") {
      return "Highlighter"
    }
    if (act.tool === "block_highlight") {
      return "Highlight Box"
    }
    if (act.tool === "pixelate") {
      return "Pixelate"
    }
    return act.tool ? (act.tool.charAt(0).toUpperCase() + act.tool.slice(1)) : ("Layer " + (idx + 1))
  }

  function getLayerIcon(act) {
    if (!act) return "󰘚"
    var icons = {
      "group": "󰉋",
      "pen": "󰏬",
      "highlighter": "󰘎",
      "arrow": "󰁔",
      "rect": "󰹢",
      "circle": "󰝦",
      "line": "󰿄",
      "blur": "󰂵",
      "block_highlight": "󰅃",
      "pixelate": "󰹑",
      "magnifier": "󰍉",
      "spotlight": "󰛩",
      "text": "󰬴",
      "stamp": "󰈻"
    }
    return icons[act.tool] || "󰘚"
  }

  function getLayerColor(act) {
    if (!act) return Color.accent
    if (act.tool === "group") return Color.accent
    if (act.color && act.color !== "transparent") return act.color
    if (act.fillColor && act.fillColor !== "transparent") return act.fillColor
    if (act.borderColor && act.borderColor !== "transparent") return act.borderColor
    if (act.tool === "spotlight") return act.borderColor || "#FFFFFF"
    if (act.tool === "blur" || act.tool === "pixelate") return "#38BDF8"
    return Color.accent
  }

  function moveLayer(fromIndex, toIndex) {
    if (fromIndex < 0 || fromIndex >= root.actions.length) return
    if (toIndex < 0 || toIndex >= root.actions.length) return
    if (fromIndex === toIndex) return
    root.pushUndoState()
    var next = root.actions.slice()
    var item = next.splice(fromIndex, 1)[0]
    next.splice(toIndex, 0, item)
    root.actions = next
    root.selectedActionIndex = toIndex
    root.selectedActionIndices = [toIndex]
    annotationCanvas.requestPaint()
    root.showFeedback("↕ Moved layer")
  }

  function moveLayerStep(index, delta) {
    var target = index + delta
    if (target >= 0 && target < root.actions.length) {
      root.moveLayer(index, target)
    }
  }

  function bringLayerToFront(index) {
    if (index >= 0 && index < root.actions.length - 1) {
      root.moveLayer(index, root.actions.length - 1)
      root.showFeedback("▲ Brought to front")
    }
  }

  function sendLayerToBack(index) {
    if (index > 0 && index < root.actions.length) {
      root.moveLayer(index, 0)
      root.showFeedback("▼ Sent to back")
    }
  }

  function toggleLayerVisibility(index) {
    if (index < 0 || index >= root.actions.length) return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(next[index]))
    cloned.hidden = !Boolean(cloned.hidden)
    next[index] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback(cloned.hidden ? "󰈉 Layer hidden" : "󰈈 Layer visible")
  }

  function toggleLayerLock(index) {
    if (index < 0 || index >= root.actions.length) return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(next[index]))
    cloned.locked = !Boolean(cloned.locked)
    next[index] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback(cloned.locked ? "🔒 Layer locked" : "🔓 Layer unlocked")
  }

  function deleteLayerByIndex(index) {
    if (index < 0 || index >= root.actions.length) return
    var act = root.actions[index]
    if (act && act.locked) {
      root.showFeedback("🔒 Layer is locked. Unlock to delete.")
      return
    }
    root.pushUndoState()
    var next = root.actions.slice()
    next.splice(index, 1)
    if (root.selectedActionIndex === index) {
      root.selectedActionIndex = -1
      root.selectedActionIndices = []
    } else if (root.selectedActionIndex > index) {
      root.selectedActionIndex--
      root.selectedActionIndices = [root.selectedActionIndex]
    }
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("🗑 Deleted layer")
  }

  function duplicateLayerByIndex(index) {
    if (index < 0 || index >= root.actions.length) return
    root.pushUndoState()
    var act = root.actions[index]
    var cloned = root.moveAction(act, 20, 20)
    cloned.locked = false
    var next = root.actions.slice()
    next.splice(index + 1, 0, cloned)
    root.actions = next
    root.selectedActionIndex = index + 1
    root.selectedActionIndices = [index + 1]
    annotationCanvas.requestPaint()
    root.showFeedback("⧉ Duplicated layer")
  }

  function toggleSelectAction(index, isMulti, isRange) {
    if (index < 0 || index >= root.actions.length) return
    if (isRange && root.selectedActionIndex >= 0) {
      var start = Math.min(root.selectedActionIndex, index)
      var end = Math.max(root.selectedActionIndex, index)
      var list = []
      for (var i = start; i <= end; i++) list.push(i)
      root.selectedActionIndices = list
      root.selectedActionIndex = index
      return
    }
    if (!isMulti) {
      root.selectAction(index)
      return
    }
    var currentList = (root.selectedActionIndices || []).slice()
    var pos = currentList.indexOf(index)
    if (pos !== -1) {
      if (currentList.length > 1) {
        currentList.splice(pos, 1)
        root.selectedActionIndices = currentList
        root.selectedActionIndex = currentList[currentList.length - 1]
      }
    } else {
      currentList.push(index)
      root.selectedActionIndices = currentList
      root.selectedActionIndex = index
    }
  }

  function selectAllLayers() {
    var all = []
    for (var i = 0; i < root.actions.length; i++) all.push(i)
    root.selectedActionIndices = all
    if (all.length > 0) root.selectedActionIndex = all[all.length - 1]
    root.showFeedback("Selected all " + all.length + " layers")
  }

  function groupSelectedActions() {
    var indices = (root.selectedActionIndices && root.selectedActionIndices.length > 0)
      ? root.selectedActionIndices.slice()
      : (root.selectedActionIndex >= 0 ? [root.selectedActionIndex] : [])
    if (indices.length < 2) {
      root.showFeedback("Select 2 or more layers (Ctrl+Click) to group")
      return
    }
    indices.sort(function(a, b) { return a - b })
    for (var i = 0; i < indices.length; i++) {
      if (root.actions[indices[i]] && root.actions[indices[i]].locked) {
        root.showFeedback("🔒 Cannot group locked layers. Unlock first.")
        return
      }
    }
    root.pushUndoState()
    var items = []
    var next = root.actions.slice()
    for (var i = 0; i < indices.length; i++) {
      items.push(JSON.parse(JSON.stringify(root.actions[indices[i]])))
    }
    for (var i = indices.length - 1; i >= 0; i--) {
      next.splice(indices[i], 1)
    }
    var insertIndex = Math.min(indices[0], next.length)
    var groupName = "Group " + (root.groupCounter++)
    var groupAct = {
      tool: "group",
      name: groupName,
      children: items,
      locked: false,
      hidden: false,
      expanded: true
    }
    next.splice(insertIndex, 0, groupAct)
    root.actions = next
    root.selectedActionIndex = insertIndex
    root.selectedActionIndices = [insertIndex]
    annotationCanvas.requestPaint()
    root.showFeedback("󰘚 Created " + groupName + " (" + items.length + " layers)")
  }

  function ungroupSelectedAction() {
    var idx = root.selectedActionIndex
    if (idx < 0 || idx >= root.actions.length) return
    var act = root.actions[idx]
    if (!act || act.tool !== "group" || !act.children || act.children.length === 0) {
      root.showFeedback("Selected layer is not a group")
      return
    }
    if (act.locked) {
      root.showFeedback("🔒 Group is locked. Unlock first.")
      return
    }
    root.pushUndoState()
    var next = root.actions.slice()
    var children = act.children.map(function(c) {
      var cloned = JSON.parse(JSON.stringify(c))
      if (act.hidden) cloned.hidden = true
      return cloned
    })
    next.splice(idx, 1)
    for (var c = 0; c < children.length; c++) {
      next.splice(idx + c, 0, children[c])
    }
    root.actions = next
    var newIndices = []
    for (var c = 0; c < children.length; c++) {
      newIndices.push(idx + c)
    }
    root.selectedActionIndices = newIndices
    root.selectedActionIndex = idx + children.length - 1
    annotationCanvas.requestPaint()
    root.showFeedback("󰘚 Ungrouped " + children.length + " layers")
  }

  function setLayerName(index, newName) {
    if (index < 0 || index >= root.actions.length) return
    var nameStr = String(newName || "").trim()
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(next[index]))
    cloned.name = nameStr
    next[index] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("✏ Renamed layer")
  }

  function toggleGroupExpanded(index) {
    if (index < 0 || index >= root.actions.length) return
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(next[index]))
    cloned.expanded = !Boolean(cloned.expanded !== false)
    next[index] = cloned
    root.actions = next
  }

  function toggleGroupChildVisibility(groupIndex, childIndex) {
    if (groupIndex < 0 || groupIndex >= root.actions.length) return
    var g = root.actions[groupIndex]
    if (!g || g.tool !== "group" || !g.children || childIndex < 0 || childIndex >= g.children.length) return
    root.pushUndoState()
    var next = root.actions.slice()
    var clonedG = JSON.parse(JSON.stringify(g))
    var ch = clonedG.children[childIndex]
    ch.hidden = !Boolean(ch.hidden)
    clonedG.children[childIndex] = ch
    next[groupIndex] = clonedG
    root.actions = next
    annotationCanvas.requestPaint()
  }

  function getActionBounds(act) {
    if (!act) return { x: 0, y: 0, width: 0, height: 0 }
    if (act.tool === "group" && act.children && act.children.length > 0) {
      var gMinX = Infinity, gMinY = Infinity, gMaxX = -Infinity, gMaxY = -Infinity
      var found = false
      for (var gi = 0; gi < act.children.length; gi++) {
        var gb = root.getActionBounds(act.children[gi])
        if (gb && (gb.width > 0 || gb.height > 0)) {
          gMinX = Math.min(gMinX, gb.x)
          gMinY = Math.min(gMinY, gb.y)
          gMaxX = Math.max(gMaxX, gb.x + gb.width)
          gMaxY = Math.max(gMaxY, gb.y + gb.height)
          found = true
        }
      }
      if (found && isFinite(gMinX) && isFinite(gMinY)) {
        return {
          x: gMinX,
          y: gMinY,
          width: Math.max(10, gMaxX - gMinX),
          height: Math.max(10, gMaxY - gMinY)
        }
      }
      return { x: 0, y: 0, width: 0, height: 0 }
    }
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
      if (!act || act.hidden) continue

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

      if (act.tool === "group" && act.children && act.children.length > 0) {
        var gbb = root.getActionBounds(act)
        if (testPt.x >= gbb.x - 4 && testPt.x <= gbb.x + gbb.width + 4 && testPt.y >= gbb.y - 4 && testPt.y <= gbb.y + gbb.height + 4) {
          return i
        }
      } else if (act.tool === "text" && act.pos) {
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
      if (act.tool === "blur") {
        if (act.shape) root.blurShape = act.shape
        if (typeof act.radius !== "undefined") root.blurRadius = act.radius
        if (typeof act.dispersion !== "undefined") root.blurDispersion = act.dispersion
      }
    } else {
      root.selectedActionIndex = -1
    }
    annotationCanvas.requestPaint()
  }

  function deleteSelectedAction() {
    if (root.selectedActionIndices && root.selectedActionIndices.length > 1) {
      root.pushUndoState()
      var toDelete = root.selectedActionIndices.slice().sort(function(a, b) { return b - a })
      var next = root.actions.slice()
      var deletedCount = 0
      for (var i = 0; i < toDelete.length; i++) {
        var idx = toDelete[i]
        if (idx >= 0 && idx < next.length) {
          if (!next[idx].locked) {
            next.splice(idx, 1)
            deletedCount++
          }
        }
      }
      root.actions = next
      root.selectedActionIndices = []
      root.selectedActionIndex = -1
      annotationCanvas.requestPaint()
      root.showFeedback("🗑 Deleted " + deletedCount + " layers")
      return
    }
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
    root.selectedActionIndices = []
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("🗑 Deleted element")
  }

  function duplicateSelectedAction() {
    if (root.selectedActionIndices && root.selectedActionIndices.length > 1) {
      root.pushUndoState()
      var sorted = root.selectedActionIndices.slice().sort(function(a, b) { return a - b })
      var next = root.actions.slice()
      var newIndices = []
      for (var i = 0; i < sorted.length; i++) {
        var idx = sorted[i]
        if (idx >= 0 && idx < root.actions.length) {
          var act = root.actions[idx]
          var cloned = root.moveAction(act, 20, 20)
          cloned.locked = false
          next.push(cloned)
          newIndices.push(next.length - 1)
        }
      }
      root.actions = next
      root.selectedActionIndices = newIndices
      root.selectedActionIndex = newIndices.length > 0 ? newIndices[newIndices.length - 1] : -1
      annotationCanvas.requestPaint()
      root.showFeedback("⧉ Duplicated " + newIndices.length + " layers")
      return
    }
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    root.pushUndoState()
    var act = root.actions[root.selectedActionIndex]
    var cloned = root.moveAction(act, 20, 20)
    cloned.locked = false
    var next = root.actions.slice()
    next.push(cloned)
    root.actions = next
    root.selectedActionIndex = next.length - 1
    root.selectedActionIndices = [next.length - 1]
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

  function setSelectedBlurShape(shape) {
    root.blurShape = shape
    if (root.selectedActionIndex < 0 || root.selectedActionIndex >= root.actions.length) return
    var act = root.actions[root.selectedActionIndex]
    if (!act || act.tool !== "blur") return
    if (act.shape === shape) return
    root.pushUndoState()
    var next = root.actions.slice()
    var cloned = JSON.parse(JSON.stringify(act))
    cloned.shape = shape
    next[root.selectedActionIndex] = cloned
    root.actions = next
    annotationCanvas.requestPaint()
    root.showFeedback("Blur Shape: " + (shape === "circle" ? "Circle / Oval" : "Rectangle"))
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
    if (res.tool === "group" && res.children && res.children.length > 0) {
      for (var ci = 0; ci < res.children.length; ci++) {
        res.children[ci] = root.moveAction(res.children[ci], dx, dy)
      }
      return res
    }
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
    if (res.tool === "group" && res.children && res.children.length > 0) {
      for (var si = 0; si < res.children.length; si++) {
        res.children[si] = root.scaleAction(origAct.children[si], startBounds, newBounds)
      }
      return res
    }
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
    var homeDir = Quickshell.env("HOME") || "/home/" + (Quickshell.env("USER") || "user")
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
      var cmd = "mkdir -p " + Util.shellQuote(stateDir) + " && magick " + Util.shellQuote(inputFile) + " " + magickArgs + " " + Util.shellQuote(targetFile)
      transformProc.command = ["sh", "-c", cmd]
      transformProc.running = true
    }

    if (root.actions.length > 0) {
      root.isExporting = true
      var prevZoom = root.zoomScale
      root.zoomScale = 1.0
      annotationCanvas.requestPaint()
      Qt.callLater(function() {
        try {
          compositeContainer.grabToImage(function(result) {
            root.isExporting = false
            root.zoomScale = prevZoom
            annotationCanvas.requestPaint()
            if (!result) return
            var bakeFile = stateDir + "/bake_" + timeStr + ".png"
            try {
              result.saveToFile(bakeFile)
            } catch (bakeErr) {
              console.warn("ReClip ImageEditor: saveToFile bake error: " + bakeErr)
            }
            runTransformOn(bakeFile)
          })
        } catch (err) {
          root.isExporting = false
          root.zoomScale = prevZoom
          console.warn("ReClip ImageEditor: grabToImage error: " + err)
        }
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
    if (root.isExporting || ensureSaveDirProc.running) {
      root.showFeedback("Saving in progress...")
      return
    }

    var homeDir = Quickshell.env("HOME") || "/home/" + (Quickshell.env("USER") || "user")
    var targetDir = (saveMode === "file") ? (homeDir + "/Pictures/Screenshots") : (homeDir + "/.local/state/reclip")
    var timeStr = new Date().toISOString().replace(/[:.]/g, "-")
    var targetFile = targetDir + (saveMode === "file" ? "/reclip_annotated_" : "/annotated_") + timeStr + ".png"

    // Proactively verify and create directory to ensure write success and avoid any crash
    ensureSaveDirProc.pendingSaveMode = saveMode
    ensureSaveDirProc.pendingTargetDir = targetDir
    ensureSaveDirProc.pendingTargetFile = targetFile
    ensureSaveDirProc.command = ["mkdir", "-p", targetDir]
    ensureSaveDirProc.running = true
  }

  function proceedGrabAndSave(saveMode, targetFile) {
    if (!compositeContainer) {
      root.isExporting = false
      root.showFeedback("⚠ Canvas not available")
      return
    }

    root.isExporting = true
    var prevZoom = root.zoomScale
    root.zoomScale = 1.0
    annotationCanvas.requestPaint()

    Qt.callLater(function() {
      try {
        compositeContainer.grabToImage(function(result) {
          root.isExporting = false
          root.zoomScale = prevZoom
          annotationCanvas.requestPaint()

          if (!result) {
            console.warn("ReClip ImageEditor: grabToImage returned null result")
            root.showFeedback("⚠ Image grab failed")
            return
          }

          var saveOk = false
          try {
            saveOk = result.saveToFile(targetFile)
          } catch (err) {
            console.warn("ReClip ImageEditor: saveToFile exception: " + err)
            saveOk = false
          }

          if (!saveOk) {
            console.warn("ReClip ImageEditor: saveToFile returned false for " + targetFile)
            root.showFeedback("⚠ Failed to save image file")
            return
          }

          if (saveMode === "clipboard" || saveMode === "history") {
            Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < " + Util.shellQuote(targetFile) + " && notify-send -a \"ReClip\" \"Annotated Image Copied\" \"Loaded to clipboard\""])
            root.savedToClipboard(targetFile)
            root.showFeedback("✓ Copied & saved to clips!")
          } else if (saveMode === "file") {
            Quickshell.execDetached(["notify-send", "-a", "ReClip", "Annotated Image Saved", "Saved to " + targetFile])
            root.showFeedback("✓ Saved to Screenshots!")
          }
        })
      } catch (grabErr) {
        root.isExporting = false
        root.zoomScale = prevZoom
        console.warn("ReClip ImageEditor: grabToImage exception: " + grabErr)
        root.showFeedback("⚠ Export error")
      }
    })
  }

  // Keyboard Shortcuts
  focus: root.visible
  Keys.onPressed: function(event) {
    if (root.textInputActive || root.editingLayerIndex >= 0) {
      if (event.key === Qt.Key_Escape) {
        root.textInputActive = false
        root.editingLayerIndex = -1
        event.accepted = true
      }
      return
    }

    // Group / Ungroup / Select All shortcuts
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_G) {
      root.ungroupSelectedAction()
      event.accepted = true
      return
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_G) {
      root.groupSelectedActions()
      event.accepted = true
      return
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A && (root.layerPanelOpen || root.currentTool === "select")) {
      root.selectAllLayers()
      event.accepted = true
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
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_BracketRight) {
        root.moveLayerStep(root.selectedActionIndex, 1)
        event.accepted = true
        return
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_BracketLeft) {
        root.moveLayerStep(root.selectedActionIndex, -1)
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
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_L) {
      root.layerPanelOpen = !root.layerPanelOpen
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
    // ==========================================
    // TOOLBARS: HEADER, DRAWING TOOLS & TRANSFORMS
    // ==========================================
    ImageToolbars {
      id: toolbars
      modal: root
      Layout.fillWidth: true
    }
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
              try {
                ctx.scale(root.zoomScale, root.zoomScale)

                // 1. Unified Spotlight Background Dimming pass
                var activeSpotlights = []
                for (var s = 0; s < root.actions.length; s++) {
                  var sa = root.actions[s]
                  if (sa && !sa.hidden && sa.tool === "spotlight" && sa.start && sa.end) {
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
                  var actItem = root.actions[i]
                  if (actItem && actItem.hidden) continue
                  root.renderAction(ctx, actItem)
                }

                // 3. Render live current action during drag
                if (root.currentAction) {
                  root.renderAction(ctx, root.currentAction)
                }
              } catch (err) {
                console.warn("[annotationCanvas.onPaint] Render error:", err)
              } finally {
                ctx.restore()
              }
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
              } else if (root.currentTool === "blur") {
                root.currentAction = {
                  tool: "blur",
                  start: pt,
                  end: pt,
                  shape: root.blurShape || "rect",
                  radius: (root.blurRadius !== undefined) ? root.blurRadius : 0,
                  dispersion: (root.blurDispersion !== undefined) ? root.blurDispersion : 4
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
                } else if (act.tool === "blur" && act.start && act.end) {
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
            visible: root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length && !root.isExporting && root.currentTool !== "crop" && !(curAct && curAct.hidden)

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
              if (!curAct || !selBounds || curAct.locked || curAct.hidden) return
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
              color: (selectionOverlay.curAct && (selectionOverlay.curAct.tool === "spotlight" || selectionOverlay.curAct.tool === "circle" || (selectionOverlay.curAct.tool === "blur" && selectionOverlay.curAct.shape === "circle"))) ? "transparent" : ((selectionOverlay.curAct && selectionOverlay.curAct.locked) ? Util.alpha("#F59E0B", 0.08) : Util.alpha(Color.accent, 0.08))
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
            // Floating Multi-Row Inspector Panel
            ImagePropertyInspector {
              id: propInspector
              modal: root
              selectionOverlay: selectionOverlay
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

      // ==========================================
      // LAYER PANEL (DOCKED / FLOATING OVER VIEWPORT RIGHT)
      // ==========================================
      ImageLayersPanel {
        id: layersPanel
        modal: root
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
      }

      // ==========================================
      // FLOATING CANVAS ZOOM CONTROLS DOCK
      // Docked at bottom-right corner of canvas just before footer
      // ==========================================
      Rectangle {
        id: canvasZoomDock
        z: 40
        anchors.right: (layersPanel && layersPanel.visible) ? layersPanel.left : parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(10)
        height: Style.space(26)
        width: zoomDockRow.implicitWidth + Style.space(10)
        radius: Style.space(6)
        color: Util.alpha(Color.popups.background || Color.background, 0.94)
        border.width: 1
        border.color: Util.alpha(Color.popups.border || Color.border, 0.5)

        Row {
          id: zoomDockRow
          anchors.centerIn: parent
          spacing: Style.space(3)

          // Zoom Out (-)
          Rectangle {
            width: Style.space(20); height: Style.space(20); radius: Style.space(4)
            color: zoomOutDockM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)
            Text { text: "−"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: zoomOutDockM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.zoomOut() }
            PanelToolTip { visible: zoomOutDockM.containsMouse; text: "Zoom out (-)" }
          }

          // Zoom Level Indicator / Reset (Click to reset to 100%)
          Rectangle {
            height: Style.space(20); width: Style.space(38); radius: Style.space(4)
            color: zoomResetDockM.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.popups.text || Color.text, 0.06)
            Text {
              text: Math.round(root.zoomScale * 100) + "%"
              color: zoomResetDockM.containsMouse ? Color.accent : (Color.popups.text || Color.text)
              font.family: Style.font.fixedFamily || "monospace"
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.centerIn: parent
            }
            MouseArea { id: zoomResetDockM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetZoom() }
            PanelToolTip { visible: zoomResetDockM.containsMouse; text: "Reset zoom to 100% (1)" }
          }

          // Zoom In (+)
          Rectangle {
            width: Style.space(20); height: Style.space(20); radius: Style.space(4)
            color: zoomInDockM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)
            Text { text: "+"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: zoomInDockM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.zoomIn() }
            PanelToolTip { visible: zoomInDockM.containsMouse; text: "Zoom in (+)" }
          }

          // Separator
          Rectangle {
            width: 1; height: Style.space(12)
            color: Util.alpha(Color.popups.border || Color.border, 0.4)
            anchors.verticalCenter: parent.verticalCenter
          }

          // Fit to Window Button
          Rectangle {
            height: Style.space(20)
            width: fitDockRow.implicitWidth + Style.space(8)
            radius: Style.space(4)
            color: fitDockM.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.popups.text || Color.text, 0.08)
            Row {
              id: fitDockRow
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text {
                text: "󰊓"
                color: fitDockM.containsMouse ? Color.accent : (Color.popups.text || Color.text)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "Fit"
                color: fitDockM.containsMouse ? Color.accent : (Color.popups.text || Color.text)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
            MouseArea { id: fitDockM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.fitZoom() }
            PanelToolTip { visible: fitDockM.containsMouse; text: "Fit image to window (0)" }
          }
        }
      }
    }

    // ==========================================
    // TWO-TIER BOTTOM STATUS & ACTION BAR
    // ==========================================
    // ==========================================
    // TWO-TIER BOTTOM STATUS & ACTION BAR
    // ==========================================
    ImageBottomBar {
      id: bottomBar
      modal: root
      Layout.fillWidth: true
    }
  }

  // ==========================================
  // DEVICE SYSTEM FONT PICKER DROPDOWN OVERLAY
  // ==========================================
  // ==========================================
  // DEVICE SYSTEM FONT PICKER DROPDOWN OVERLAY
  // ==========================================
  ImageFontPickerModal {
    id: fontPickerOverlay
    modal: root
    anchors.fill: parent
    z: 150
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
      if (act.tool === "group" && act.children && act.children.length > 0) {
        for (var c = 0; c < act.children.length; c++) {
          var ch = act.children[c]
          if (ch && !ch.hidden) {
            root.renderAction(ctx, ch)
          }
        }
      } else if (act.tool === "pen") {
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
        var bw = Math.max(1, Math.abs(act.end.x - act.start.x))
        var bh = Math.max(1, Math.abs(act.end.y - act.start.y))
        var bShape = act.shape || "rect"
        var bRad = (act.radius !== undefined) ? act.radius : 0

        ctx.save()
        try {
          // 1. Set clip path to prevent blur dispersion bleed and support circle/rounded shapes
          ctx.beginPath()
          if (bShape === "circle") {
            root.drawEllipsePath(ctx, bx, by, bw, bh)
          } else if (bRad > 0) {
            root.drawRoundedRectPath(ctx, bx, by, bw, bh, bRad)
          } else {
            ctx.rect(bx, by, bw, bh)
          }
          ctx.clip()

          // 2. Frosted glass base
          ctx.fillStyle = "rgba(15, 23, 42, 0.78)"
          ctx.fillRect(bx, by, bw, bh)

          // 3. Multi-sample optical dispersion
          if (baseImage && baseImage.status === Image.Ready) {
            ctx.globalAlpha = 0.16 * elemOpacity
            var blurDisp = (act.dispersion !== undefined) ? Number(act.dispersion) : 4
            var ds = Math.max(0.5, blurDisp / 4)
            var blurOffsets = [[-2*ds, -2*ds], [2*ds, -2*ds], [-2*ds, 2*ds], [2*ds, 2*ds], [-4*ds, 0], [4*ds, 0], [0, -4*ds], [0, 4*ds]]
            var imgW = Math.floor(baseImage.implicitWidth > 0 ? baseImage.implicitWidth : (baseImage.width > 0 ? baseImage.width : compositeContainer.baseW))
            var imgH = Math.floor(baseImage.implicitHeight > 0 ? baseImage.implicitHeight : (baseImage.height > 0 ? baseImage.height : compositeContainer.baseH))

            if (imgW > 0 && imgH > 0) {
              for (var bo = 0; bo < blurOffsets.length; bo++) {
                var ox = blurOffsets[bo][0]
                var oy = blurOffsets[bo][1]
                var rawSx = bx + ox
                var rawSy = by + oy
                var rawSw = bw
                var rawSh = bh
                var rawDx = bx
                var rawDy = by
                var rawDw = bw
                var rawDh = bh

                var sx = Math.max(0, Math.min(imgW, rawSx))
                var sy = Math.max(0, Math.min(imgH, rawSy))
                var dx = rawDx + (sx - rawSx)
                var dy = rawDy + (sy - rawSy)

                var maxSw = imgW - sx
                var maxSh = imgH - sy
                var sw = Math.max(0, Math.min(maxSw, rawSw - (sx - rawSx)))
                var sh = Math.max(0, Math.min(maxSh, rawSh - (sy - rawSy)))

                var dw = rawDw * (rawSw > 0 ? (sw / rawSw) : 1)
                var dh = rawDh * (rawSh > 0 ? (sh / rawSh) : 1)

                sw = Math.floor(sw)
                sh = Math.floor(sh)
                sx = Math.floor(sx)
                sy = Math.floor(sy)

                if (sx + sw > imgW) sw = imgW - sx
                if (sy + sh > imgH) sh = imgH - sy

                if (sw > 0 && sh > 0 && dw > 0 && dh > 0 && sx >= 0 && sy >= 0 && (sx + sw) <= imgW && (sy + sh) <= imgH) {
                  try {
                    ctx.drawImage(baseImage, sx, sy, sw, sh, dx, dy, dw, dh)
                  } catch (e) {
                    // Ignore any edge sampling errors
                  }
                }
              }
            }
          }
          ctx.globalAlpha = elemOpacity

          // 4. Glass specular tint
          ctx.fillStyle = "rgba(255, 255, 255, 0.07)"
          ctx.fillRect(bx, by, bw, bh)
        } finally {
          ctx.restore()
        }

        // 5. Crisp glass border matching exact shape
        ctx.save()
        try {
          ctx.beginPath()
          if (bShape === "circle") {
            root.drawEllipsePath(ctx, bx, by, bw, bh)
          } else if (bRad > 0) {
            root.drawRoundedRectPath(ctx, bx, by, bw, bh, bRad)
          } else {
            ctx.rect(bx, by, bw, bh)
          }
          ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
          ctx.lineWidth = 1
          ctx.globalAlpha = elemOpacity
          ctx.stroke()
        } finally {
          ctx.restore()
        }
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
        try {
          ctx.beginPath()
          ctx.arc(magCenterX, magCenterY, magR, 0, Math.PI * 2)
          ctx.clip()

          // Draw magnified base image
          if (baseImage && baseImage.status === Image.Ready) {
            var magImgW = Math.floor(baseImage.implicitWidth > 0 ? baseImage.implicitWidth : (baseImage.width > 0 ? baseImage.width : compositeContainer.baseW))
            var magImgH = Math.floor(baseImage.implicitHeight > 0 ? baseImage.implicitHeight : (baseImage.height > 0 ? baseImage.height : compositeContainer.baseH))
            if (magImgW > 0 && magImgH > 0) {
              var rawSrcW = (magR * 2) / magZoom
              var rawSrcH = (magR * 2) / magZoom
              var rawSrcX = magCenterX - rawSrcW / 2
              var rawSrcY = magCenterY - rawSrcH / 2
              var rawDstX = magCenterX - magR
              var rawDstY = magCenterY - magR

              var srcX = Math.max(0, Math.min(magImgW, rawSrcX))
              var srcY = Math.max(0, Math.min(magImgH, rawSrcY))
              var dstX = rawDstX + (srcX - rawSrcX) * magZoom
              var dstY = rawDstY + (srcY - rawSrcY) * magZoom

              var maxSrcW = magImgW - srcX
              var maxSrcH = magImgH - srcY
              var srcW = Math.max(0, Math.min(maxSrcW, rawSrcW - (srcX - rawSrcX)))
              var srcH = Math.max(0, Math.min(maxSrcH, rawSrcH - (srcY - rawSrcY)))

              var dstW = srcW * magZoom
              var dstH = srcH * magZoom

              srcW = Math.floor(srcW)
              srcH = Math.floor(srcH)
              srcX = Math.floor(srcX)
              srcY = Math.floor(srcY)

              if (srcX + srcW > magImgW) srcW = magImgW - srcX
              if (srcY + srcH > magImgH) srcH = magImgH - srcY

              if (srcW > 0 && srcH > 0 && dstW > 0 && dstH > 0 && srcX >= 0 && srcY >= 0 && (srcX + srcW) <= magImgW && (srcY + srcH) <= magImgH) {
                try {
                  ctx.drawImage(baseImage, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH)
                } catch (e) {
                  // Ignore sampling error
                }
              }
            }
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
        } finally {
          ctx.restore() // unclip
        }

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
          try {
            ctx.beginPath()
            if (spShape === "circle") {
              root.drawEllipsePath(ctx, spX, spY, spW, spH)
            } else {
              root.drawRoundedRectPath(ctx, spX, spY, spW, spH, spRad)
            }
            ctx.clip()
            var spImgW = Math.floor(baseImage.implicitWidth > 0 ? baseImage.implicitWidth : (baseImage.width > 0 ? baseImage.width : compositeContainer.baseW))
            var spImgH = Math.floor(baseImage.implicitHeight > 0 ? baseImage.implicitHeight : (baseImage.height > 0 ? baseImage.height : compositeContainer.baseH))
            if (spImgW > 0 && spImgH > 0) {
              var rawSpW = spW / spZoom
              var rawSpH = spH / spZoom
              var rawSpX = (spX + spW / 2) - rawSpW / 2
              var rawSpY = (spY + spH / 2) - rawSpH / 2

              var spZoomSrcX = Math.max(0, Math.min(spImgW, rawSpX))
              var spZoomSrcY = Math.max(0, Math.min(spImgH, rawSpY))
              var spDstX = spX + (spZoomSrcX - rawSpX) * spZoom
              var spDstY = spY + (spZoomSrcY - rawSpY) * spZoom

              var maxSpW = spImgW - spZoomSrcX
              var maxSpH = spImgH - spZoomSrcY
              var spZoomSrcW = Math.max(0, Math.min(maxSpW, rawSpW - (spZoomSrcX - rawSpX)))
              var spZoomSrcH = Math.max(0, Math.min(maxSpH, rawSpH - (spZoomSrcY - rawSpY)))

              var spDstW = spZoomSrcW * spZoom
              var spDstH = spZoomSrcH * spZoom

              spZoomSrcW = Math.floor(spZoomSrcW)
              spZoomSrcH = Math.floor(spZoomSrcH)
              spZoomSrcX = Math.floor(spZoomSrcX)
              spZoomSrcY = Math.floor(spZoomSrcY)

              if (spZoomSrcX + spZoomSrcW > spImgW) spZoomSrcW = spImgW - spZoomSrcX
              if (spZoomSrcY + spZoomSrcH > spImgH) spZoomSrcH = spImgH - spZoomSrcY

              if (spZoomSrcW > 0 && spZoomSrcH > 0 && spDstW > 0 && spDstH > 0 && spZoomSrcX >= 0 && spZoomSrcY >= 0 && (spZoomSrcX + spZoomSrcW) <= spImgW && (spZoomSrcY + spZoomSrcH) <= spImgH) {
                try {
                  ctx.drawImage(baseImage, spZoomSrcX, spZoomSrcY, spZoomSrcW, spZoomSrcH, spDstX, spDstY, spDstW, spDstH)
                } catch (e) {
                  // Ignore sampling error
                }
              }
            }
          } finally {
            ctx.restore()
          }
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
      if (a.locked || a.hidden) {
        filtered.push(a)
        continue
      }
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
