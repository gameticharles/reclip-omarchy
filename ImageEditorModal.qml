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

  // Signals
  signal savedToClipboard(string path)
  signal savedToHistory(string path)
  signal runOcr(string path)
  signal closed()

  // Properties
  property string imagePath: ""
  property string currentTool: "pan" // "pan", "pen", "highlighter", "arrow", "rect", "circle", "line", "blur", "text", "stamp", "eraser"
  property color currentColor: "#EF4444"
  property int strokeWidth: 4
  property bool fillShape: false
  property string currentStamp: "number" // "number", "check", "cross", "star", "warn", "bug", "fire"
  property int stampCounter: 1

  // Zoom & Pan state
  property real zoomScale: 1.0

  // Annotation stacks
  property var actions: []
  property var redoStack: []
  property var currentAction: null
  property bool isDrawing: false

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
    { id: "number", label: "①", name: "Counter (1,2,3...)" },
    { id: "check", label: "✅", name: "Check" },
    { id: "cross", label: "❌", name: "Cross" },
    { id: "star", label: "⭐", name: "Star" },
    { id: "warn", label: "⚠️", name: "Warning" },
    { id: "bug", label: "🐛", name: "Bug" },
    { id: "fire", label: "🔥", name: "Fire" }
  ]

  // Lifecycle
  function open(path) {
    root.imagePath = path || ""
    root.actions = []
    root.redoStack = []
    root.currentAction = null
    root.isDrawing = false
    root.textInputActive = false
    root.stampCounter = 1
    root.currentTool = "pan"
    root.zoomScale = 1.0
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
  function undo() {
    if (root.actions.length === 0) return
    var nextActions = root.actions.slice()
    var popped = nextActions.pop()
    var nextRedo = root.redoStack.slice()
    nextRedo.push(popped)
    root.actions = nextActions
    root.redoStack = nextRedo
    annotationCanvas.requestPaint()
  }

  function redo() {
    if (root.redoStack.length === 0) return
    var nextRedo = root.redoStack.slice()
    var popped = nextRedo.pop()
    var nextActions = root.actions.slice()
    nextActions.push(popped)
    root.actions = nextActions
    root.redoStack = nextRedo
    annotationCanvas.requestPaint()
  }

  function clearAll() {
    if (root.actions.length === 0) return
    root.redoStack = root.actions.slice()
    root.actions = []
    annotationCanvas.requestPaint()
  }

  function commitText() {
    if (!root.textInputActive) return
    var str = root.textInputDraft.trim()
    if (str.length > 0) {
      var act = {
        tool: "text",
        text: str,
        color: String(root.currentColor),
        size: Math.max(14, root.strokeWidth * 4),
        pos: { x: root.textInputPos.x, y: root.textInputPos.y }
      }
      var next = root.actions.slice()
      next.push(act)
      root.actions = next
      root.redoStack = []
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

    var prevZoom = root.zoomScale
    root.zoomScale = 1.0
    annotationCanvas.requestPaint()

    Qt.callLater(function() {
      compositeContainer.grabToImage(function(result) {
        root.zoomScale = prevZoom
        annotationCanvas.requestPaint()

        if (!result) return
        result.saveToFile(targetFile)

        if (saveMode === "clipboard" || saveMode === "history") {
          Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < " + Util.shellQuote(targetFile) + " && notify-send -a \"ReClip\" \"Annotated Image Copied\" \"Loaded to clipboard\""])
          root.savedToClipboard(targetFile)
          if (saveMode === "history") {
            root.savedToHistory(targetFile)
          }
        } else if (saveMode === "file") {
          Quickshell.execDetached(["notify-send", "-a", "ReClip", "Annotated Image Saved", "Saved to " + targetFile])
        }
        root.close()
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

    if (event.key === Qt.Key_Escape) {
      root.close()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
      root.undo()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Y || ((event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Z))) {
      root.redo()
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
      root.currentTool = "pan"
      event.accepted = true
    } else if (event.key === Qt.Key_P) {
      root.currentTool = "pen"
      event.accepted = true
    } else if (event.key === Qt.Key_H) {
      root.currentTool = "highlighter"
      event.accepted = true
    } else if (event.key === Qt.Key_A) {
      root.currentTool = "arrow"
      event.accepted = true
    } else if (event.key === Qt.Key_R) {
      root.currentTool = "rect"
      event.accepted = true
    } else if (event.key === Qt.Key_C) {
      root.currentTool = "circle"
      event.accepted = true
    } else if (event.key === Qt.Key_L) {
      root.currentTool = "line"
      event.accepted = true
    } else if (event.key === Qt.Key_B) {
      root.currentTool = "blur"
      event.accepted = true
    } else if (event.key === Qt.Key_T) {
      root.currentTool = "text"
      event.accepted = true
    } else if (event.key === Qt.Key_S) {
      root.currentTool = "stamp"
      event.accepted = true
    } else if (event.key === Qt.Key_E) {
      root.currentTool = "eraser"
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
                root.close()
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
                root.close()
              }
            }
          }
          PanelToolTip { visible: ocrMouse.containsMouse; text: "Extract text (OCR)" }
        }

        // Separator
        Rectangle { width: 1; height: Style.space(18); color: Util.alpha(Color.popups.text || Color.text, 0.12) }

        // Undo
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: root.actions.length > 0 ? (undoMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: root.actions.length > 0 ? 1.0 : 0.4
          Text { text: "󰕌"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); anchors.centerIn: parent }
          MouseArea {
            id: undoMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: root.actions.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.undo()
          }
          PanelToolTip { visible: undoMouse.containsMouse; text: "Undo (Ctrl+Z)" }
        }

        // Redo
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: root.redoStack.length > 0 ? (redoMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: root.redoStack.length > 0 ? 1.0 : 0.4
          Text { text: "󰑎"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(11); anchors.centerIn: parent }
          MouseArea {
            id: redoMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: root.redoStack.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.redo()
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
              { id: "pan", label: "✋", name: "Pan / View (V)" },
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
                Text { text: parent.modelData.label; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                MouseArea {
                  id: sMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentStamp = parent.modelData.id
                }
                PanelToolTip { visible: sMouse.containsMouse; text: parent.modelData.name }
              }
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

          // Stroke Label
          Text {
            text: "Size:"
            color: Util.alpha(Color.popups.text || Color.text, 0.6)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          // Stroke width selector
          Row {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              model: root.strokeSizes
              Rectangle {
                required property var modelData
                width: Style.space(24); height: Style.space(20); radius: Style.space(3)
                color: root.strokeWidth === modelData.val ? Util.alpha(Color.accent, 0.3) : (szMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.05))
                border.width: 1
                border.color: root.strokeWidth === modelData.val ? Color.accent : "transparent"

                Text {
                  text: parent.modelData.label
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
                PanelToolTip { visible: szMouse.containsMouse; text: "Stroke: " + parent.modelData.val + "px" }
              }
            }
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

          // Current Color Preview dot + Hex
          Row {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              width: Style.space(14); height: Style.space(14); radius: Style.space(7)
              color: root.currentColor
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.3)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: String(root.currentColor).toUpperCase()
              color: Util.alpha(Color.popups.text || Color.text, 0.7)
              font.family: "monospace"
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
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
        interactive: root.currentTool === "pan"

        // Mouse Wheel to Zoom
        WheelHandler {
          id: wheelHandler
          onWheel: function(event) {
            if (event.angleDelta.y > 0) root.zoomIn()
            else if (event.angleDelta.y < 0) root.zoomOut()
          }
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
            preventStealing: root.currentTool !== "pan"
            cursorShape: root.currentTool === "pan" ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : (root.currentTool === "eraser" ? Qt.ForbiddenCursor : (root.currentTool === "text" ? Qt.IBeamCursor : Qt.CrossCursor))

            property real lastPanX: 0
            property real lastPanY: 0

            onPressed: function(mouse) {
              if (root.currentTool === "pan" || mouse.button === Qt.MiddleButton) {
                lastPanX = mouse.x
                lastPanY = mouse.y
                return
              }

              if (root.textInputActive) {
                root.commitText()
                return
              }

              // Store unscaled coordinates on base image
              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var pt = { x: mouse.x / z, y: mouse.y / z }
              var actColor = String(root.currentColor)

              // Text tool
              if (root.currentTool === "text") {
                root.textInputPos = Qt.point(mouse.x, mouse.y)
                root.textInputDraft = ""
                root.textInputActive = true
                return
              }

              // Stamp tool
              if (root.currentTool === "stamp") {
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
                root.redoStack = []
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
              root.redoStack = []

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
              if ((root.currentTool === "pan" || mouse.buttons & Qt.MiddleButton) && pressed) {
                var dx = mouse.x - lastPanX
                var dy = mouse.y - lastPanY
                canvasFlickable.contentX = Math.max(0, canvasFlickable.contentX - dx)
                canvasFlickable.contentY = Math.max(0, canvasFlickable.contentY - dy)
                lastPanX = mouse.x
                lastPanY = mouse.y
                return
              }

              var z = root.zoomScale > 0 ? root.zoomScale : 1.0
              var pt = { x: mouse.x / z, y: mouse.y / z }

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
              if (root.isDrawing && root.currentAction) {
                var finalActs = root.actions.slice()
                finalActs.push(root.currentAction)
                root.actions = finalActs
                root.currentAction = null
                root.isDrawing = false
                annotationCanvas.requestPaint()
              }
            }

            onCanceled: function() {
              if (root.isDrawing && root.currentAction) {
                var finalActs = root.actions.slice()
                finalActs.push(root.currentAction)
                root.actions = finalActs
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
            color: Util.alpha(Color.popups.background || Color.background, 0.95)
            border.width: 1
            border.color: Color.accent
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

        // Annotations count info
        Row {
          spacing: Style.space(5)
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            width: Style.space(7); height: Style.space(7); radius: Style.space(3.5)
            color: root.actions.length > 0 ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.25)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: root.actions.length > 0 ? (root.actions.length + (root.actions.length === 1 ? " edit" : " edits")) : "Clean"
            color: Util.alpha(Color.popups.text || Color.text, 0.6)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(8.5)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            Layout.maximumWidth: Style.space(80)
            elide: Text.ElideRight
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
                  root.close()
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
      } else if (act.tool === "text" && act.pos && act.text) {
        var fs = act.size || 18
        ctx.font = "bold " + fs + "px sans-serif"
        ctx.textBaseline = "top"
        ctx.strokeStyle = "rgba(0,0,0,0.7)"
        ctx.lineWidth = 3
        ctx.strokeText(act.text, act.pos.x, act.pos.y)
        ctx.fillStyle = actColor
        ctx.fillText(act.text, act.pos.x, act.pos.y)
      } else if (act.tool === "stamp" && act.pos) {
        var sx = act.pos.x
        var sy = act.pos.y
        var sr = Math.max(14, actWidth * 3)
        if (act.stampType === "number") {
          ctx.fillStyle = actColor
          ctx.beginPath()
          ctx.arc(sx, sy, sr, 0, Math.PI * 2)
          ctx.fill()
          ctx.strokeStyle = "#FFFFFF"
          ctx.lineWidth = 2
          ctx.stroke()
          ctx.fillStyle = "#FFFFFF"
          ctx.font = "bold " + Math.round(sr * 1.1) + "px sans-serif"
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText(String(act.num || 1), sx, sy)
        } else {
          var iconMap = { check: "✅", cross: "❌", star: "⭐", warn: "⚠️", bug: "🐛", fire: "🔥" }
          var emoji = iconMap[act.stampType] || "⭐"
          ctx.font = Math.round(sr * 1.6) + "px sans-serif"
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText(emoji, sx, sy)
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
