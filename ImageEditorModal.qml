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
  color: Util.alpha(Color.popups.background || Color.background, 0.96)
  radius: Style.cornerRadius
  z: 105

  // Signals
  signal savedToClipboard(string path)
  signal savedToHistory(string path)
  signal closed()

  // Properties
  property string imagePath: ""
  property string currentTool: "pen" // "pen", "highlighter", "arrow", "rect", "circle", "line", "blur", "text", "stamp", "eraser"
  property color currentColor: "#EF4444"
  property int strokeWidth: 4
  property bool fillShape: false
  property string currentStamp: "number" // "number", "check", "cross", "star", "warn", "bug", "fire"
  property int stampCounter: 1

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

  function open(path) {
    root.imagePath = path || ""
    root.actions = []
    root.redoStack = []
    root.currentAction = null
    root.isDrawing = false
    root.textInputActive = false
    root.stampCounter = 1
    root.visible = true
    root.forceActiveFocus()
    annotationCanvas.requestPaint()
  }

  function close() {
    root.visible = false
    root.closed()
  }

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
        color: root.currentColor,
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

    // Capture the composite item
    compositeContainer.grabToImage(function(result) {
      if (!result) return
      result.saveToFile(targetFile)

      if (saveMode === "clipboard" || saveMode === "history") {
        Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < " + Util.shellQuote(targetFile) + " && notify-send -a 'ReClip' 'Annotated Image Copied' 'Loaded to clipboard'"])
        root.savedToClipboard(targetFile)
        if (saveMode === "history") {
          root.savedToHistory(targetFile)
        }
      } else if (saveMode === "file") {
        Quickshell.execDetached(["notify-send", "-a", "ReClip", "Annotated Image Saved", "Saved to " + targetFile])
      }
      root.close()
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
    // TOP HEADER & CONTROLS TOOLBAR
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(48)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.5)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(14)
        anchors.rightMargin: Style.space(14)
        spacing: Style.space(10)

        // Title icon + label
        Row {
          spacing: Style.space(8)
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            width: Style.space(30); height: Style.space(30); radius: Style.space(6)
            color: Util.alpha(Color.accent, 0.2)
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: "󰏫"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
              text: "Screenshot & Annotation Studio"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Text {
              text: "Draw, highlight, redact sensitive data, and add numbered callouts"
              color: Util.alpha(Color.popups.text || Color.text, 0.5)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Undo Button
        Rectangle {
          width: Style.space(30); height: Style.space(30); radius: Style.space(6)
          color: root.actions.length > 0 ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: root.actions.length > 0 ? 1.0 : 0.4
          Text {
            text: "󰕌"
            color: Color.popups.text || Color.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: root.actions.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.undo()
          }
        }

        // Redo Button
        Rectangle {
          width: Style.space(30); height: Style.space(30); radius: Style.space(6)
          color: root.redoStack.length > 0 ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
          opacity: root.redoStack.length > 0 ? 1.0 : 0.4
          Text {
            text: "󰑎"
            color: Color.popups.text || Color.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: root.redoStack.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.redo()
          }
        }

        // Clear Canvas
        Rectangle {
          width: Style.space(30); height: Style.space(30); radius: Style.space(6)
          color: Util.alpha(Color.urgent, 0.12)
          Text {
            text: "󰃢"
            color: Color.urgent
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
          }
        }

        Rectangle { width: 1; height: Style.space(22); color: Util.alpha(Color.popups.text || Color.text, 0.15) }

        // Close Button
        Rectangle {
          width: Style.space(30); height: Style.space(30); radius: Style.space(6)
          color: Util.alpha(Color.popups.text || Color.text, 0.08)
          Text {
            text: "✕"
            color: Color.popups.text || Color.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }
    }

    // ==========================================
    // SECONDARY TOOLBAR: TOOL PALETTE & ATTRIBUTES
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(42)
      color: Util.alpha(Color.popups.background || Color.background, 0.94)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.35)

      Flickable {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        contentWidth: toolRowLayout.implicitWidth
        contentHeight: height
        clip: true

        Row {
          id: toolRowLayout
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          // 1. Tool Selection Buttons
          Row {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: [
                { id: "pen", icon: "󰏫", tip: "Pen (P)" },
                { id: "highlighter", icon: "󰏬", tip: "Highlight (H)" },
                { id: "arrow", icon: "󰁔", tip: "Arrow (A)" },
                { id: "rect", icon: "󰹢", tip: "Rectangle (R)" },
                { id: "circle", icon: "󰝦", tip: "Circle (C)" },
                { id: "line", icon: "󰘨", tip: "Line (L)" },
                { id: "blur", icon: "󰐳", tip: "Redact Blur (B)" },
                { id: "text", icon: "󰗊", tip: "Text (T)" },
                { id: "stamp", icon: "󰋚", tip: "Stamp (S)" },
                { id: "eraser", icon: "󰆴", tip: "Eraser (E)" }
              ]

              Rectangle {
                required property var modelData
                width: Style.space(30); height: Style.space(30); radius: Style.space(5)
                color: root.currentTool === modelData.id ? Color.accent : (toolMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")
                border.width: 1
                border.color: root.currentTool === modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)

                Text {
                  text: parent.modelData.icon
                  color: root.currentTool === parent.modelData.id ? "#FFFFFF" : (Color.popups.text || Color.text)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.caption
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: toolMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentTool = parent.modelData.id
                }
              }
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(22); color: Util.alpha(Color.popups.text || Color.text, 0.12); anchors.verticalCenter: parent.verticalCenter }

          // 2. Stroke Width Selector
          Row {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: root.strokeSizes
              Rectangle {
                required property var modelData
                width: Style.space(28); height: Style.space(26); radius: Style.space(4)
                color: root.strokeWidth === modelData.val ? Util.alpha(Color.accent, 0.25) : "transparent"
                border.width: 1
                border.color: root.strokeWidth === modelData.val ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)

                Text {
                  text: parent.modelData.label
                  color: root.strokeWidth === parent.modelData.val ? Color.accent : (Color.popups.text || Color.text)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: root.strokeWidth === parent.modelData.val
                  anchors.centerIn: parent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.strokeWidth = parent.modelData.val
                }
              }
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(22); color: Util.alpha(Color.popups.text || Color.text, 0.12); anchors.verticalCenter: parent.verticalCenter }

          // 3. Fill Shape Toggle (visible for rect & circle)
          Rectangle {
            visible: root.currentTool === "rect" || root.currentTool === "circle"
            height: Style.space(26); width: fillTxt.implicitWidth + Style.space(12); radius: Style.space(4)
            color: root.fillShape ? Util.alpha(Color.accent, 0.25) : "transparent"
            border.width: 1
            border.color: root.fillShape ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: fillTxt
              text: root.fillShape ? "Fill: On" : "Fill: Off"
              color: root.fillShape ? Color.accent : (Color.popups.text || Color.text)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              font.bold: root.fillShape
              anchors.centerIn: parent
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.fillShape = !root.fillShape
            }
          }

          // Stamp Selector (visible for stamp tool)
          Row {
            visible: root.currentTool === "stamp"
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: root.stampOptions
              Rectangle {
                required property var modelData
                width: Style.space(28); height: Style.space(26); radius: Style.space(4)
                color: root.currentStamp === modelData.id ? Util.alpha(Color.accent, 0.25) : "transparent"
                border.width: 1
                border.color: root.currentStamp === modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)

                Text {
                  text: parent.modelData.label
                  font.pixelSize: Style.space(11)
                  anchors.centerIn: parent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentStamp = parent.modelData.id
                }
              }
            }
          }

          // Separator
          Rectangle { width: 1; height: Style.space(22); color: Util.alpha(Color.popups.text || Color.text, 0.12); anchors.verticalCenter: parent.verticalCenter }

          // 4. Color Palette
          Row {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: root.colorPalette
              Rectangle {
                required property color modelData
                width: Style.space(18); height: Style.space(18); radius: Style.space(9)
                color: modelData
                border.width: root.currentColor === modelData ? 2 : 1
                border.color: root.currentColor === modelData ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.2)
                scale: root.currentColor === modelData ? 1.25 : 1.0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentColor = parent.modelData
                }
              }
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

        // COMPOSITE CONTAINER (Source image + Canvas overlay)
        Item {
          id: compositeContainer
          width: baseImage.implicitWidth > 0 ? baseImage.implicitWidth : canvasFlickable.width
          height: baseImage.implicitHeight > 0 ? baseImage.implicitHeight : canvasFlickable.height
          x: Math.max(0, (canvasFlickable.width - width) / 2)
          y: Math.max(0, (canvasFlickable.height - height) / 2)

          // 1. Base Image
          Image {
            id: baseImage
            source: root.imagePath ? ("file://" + root.imagePath) : ""
            fillMode: Image.PreserveAspectFit
            anchors.fill: parent
            smooth: true
            onStatusChanged: {
              if (status === Image.Ready) {
                annotationCanvas.requestPaint()
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

              // Render finished actions
              for (var i = 0; i < root.actions.length; i++) {
                root.renderAction(ctx, root.actions[i])
              }

              // Render live current action during drag
              if (root.currentAction) {
                root.renderAction(ctx, root.currentAction)
              }
            }
          }

          // 3. Interactive Drawing MouseArea
          MouseArea {
            id: drawMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.currentTool === "eraser" ? Qt.ForbiddenCursor : (root.currentTool === "text" ? Qt.IBeamCursor : Qt.CrossCursor)

            onPressed: function(mouse) {
              if (root.textInputActive) {
                root.commitText()
                return
              }

              var pt = { x: mouse.x, y: mouse.y }

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
                  color: root.currentColor,
                  width: root.strokeWidth,
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
                  color: root.currentColor,
                  width: root.strokeWidth,
                  points: [pt]
                }
              } else {
                root.currentAction = {
                  tool: root.currentTool,
                  color: root.currentColor,
                  width: root.strokeWidth,
                  filled: root.fillShape,
                  start: pt,
                  end: pt
                }
              }
              annotationCanvas.requestPaint()
            }

            onPositionChanged: function(mouse) {
              var pt = { x: mouse.x, y: mouse.y }
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
    // BOTTOM ACTION BAR: EXPORT & SAVE
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(48)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.5)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(16)
        anchors.rightMargin: Style.space(16)

        // Actions status info
        Text {
          text: root.actions.length + " annotations • Tool: " + root.currentTool.toUpperCase()
          color: Util.alpha(Color.popups.text || Color.text, 0.5)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.space(9)
          Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        // Cancel / Dismiss
        Rectangle {
          height: Style.space(30); width: Style.space(70); radius: Style.space(4)
          color: Util.alpha(Color.popups.text || Color.text, 0.08)
          Text {
            text: "Cancel"
            color: Color.popups.text || Color.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }

        // Save to File (Pictures/Screenshots)
        Rectangle {
          height: Style.space(30); width: saveFileTxt.implicitWidth + Style.space(18); radius: Style.space(4)
          color: Util.alpha(Color.popups.text || Color.text, 0.1)
          border.width: 1
          border.color: Util.alpha(Color.popups.text || Color.text, 0.2)

          Row {
            id: saveFileTxt
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "💾"; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: "Save to File"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.exportImage("file")
          }
        }

        // Copy to Clipboard (wl-copy)
        Rectangle {
          height: Style.space(30); width: copyClipTxt.implicitWidth + Style.space(20); radius: Style.space(4)
          color: Color.accent

          Row {
            id: copyClipTxt
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰆏"; color: "#FFFFFF"; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: "Copy & Save to Feed"
              color: "#FFFFFF"
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.exportImage("clipboard")
          }
        }
      }
    }
  }

  // Helper drawing functions
  function renderAction(ctx, act) {
    if (!act) return
    ctx.save()

    if (act.tool === "pen") {
      ctx.beginPath()
      ctx.strokeStyle = act.color
      ctx.lineWidth = act.width
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      var pts = act.points
      if (pts.length === 1) {
        ctx.arc(pts[0].x, pts[0].y, act.width / 2, 0, Math.PI * 2)
        ctx.fillStyle = act.color
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
      ctx.strokeStyle = act.color
      ctx.lineWidth = act.width * 3
      ctx.lineCap = "square"
      var hpts = act.points
      if (hpts.length >= 2) {
        ctx.moveTo(hpts[0].x, hpts[0].y)
        for (var k = 1; k < hpts.length; k++) {
          ctx.lineTo(hpts[k].x, hpts[k].y)
        }
        ctx.stroke()
      }
    } else if (act.tool === "rect" && act.start && act.end) {
      ctx.beginPath()
      ctx.strokeStyle = act.color
      ctx.lineWidth = act.width
      var rx = Math.min(act.start.x, act.end.x)
      var ry = Math.min(act.start.y, act.end.y)
      var rw = Math.abs(act.end.x - act.start.x)
      var rh = Math.abs(act.end.y - act.start.y)
      if (act.filled) {
        ctx.fillStyle = act.color
        ctx.globalAlpha = 0.25
        ctx.fillRect(rx, ry, rw, rh)
        ctx.globalAlpha = 1.0
      }
      ctx.strokeRect(rx, ry, rw, rh)
    } else if (act.tool === "circle" && act.start && act.end) {
      ctx.beginPath()
      ctx.strokeStyle = act.color
      ctx.lineWidth = act.width
      var crx = (act.end.x - act.start.x) / 2
      var cry = (act.end.y - act.start.y) / 2
      var ccx = act.start.x + crx
      var ccy = act.start.y + cry
      ctx.ellipse(ccx, ccy, Math.abs(crx), Math.abs(cry), 0, 0, Math.PI * 2)
      if (act.filled) {
        ctx.fillStyle = act.color
        ctx.globalAlpha = 0.25
        ctx.fill()
        ctx.globalAlpha = 1.0
      }
      ctx.stroke()
    } else if (act.tool === "line" && act.start && act.end) {
      ctx.beginPath()
      ctx.strokeStyle = act.color
      ctx.lineWidth = act.width
      ctx.lineCap = "round"
      ctx.moveTo(act.start.x, act.start.y)
      ctx.lineTo(act.end.x, act.end.y)
      ctx.stroke()
    } else if (act.tool === "arrow" && act.start && act.end) {
      ctx.beginPath()
      ctx.strokeStyle = act.color
      ctx.fillStyle = act.color
      ctx.lineWidth = act.width
      ctx.lineCap = "round"
      ctx.moveTo(act.start.x, act.start.y)
      ctx.lineTo(act.end.x, act.end.y)
      ctx.stroke()

      var angle = Math.atan2(act.end.y - act.start.y, act.end.x - act.start.x)
      var headLen = Math.max(12, act.width * 3.5)
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
      ctx.fillStyle = act.color || "#FFFFFF"
      ctx.fillText(act.text, act.pos.x, act.pos.y)
    } else if (act.tool === "stamp" && act.pos) {
      var sx = act.pos.x
      var sy = act.pos.y
      var sr = Math.max(14, (act.width || 4) * 3)
      if (act.stampType === "number") {
        ctx.fillStyle = act.color || "#3B82F6"
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
