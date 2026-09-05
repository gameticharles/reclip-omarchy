import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "lib/ClipboardHistory.js" as ClipboardHistory
import "lib/ColorStudio.js" as ColorStudio

Rectangle {
  id: root
  visible: false
  anchors.fill: parent
  color: Util.alpha(Color.background || "#000000", 0.75)
  radius: Style.cornerRadius
  z: 100

  signal colorSelected(string hex)
  signal requestScreenPick()
  signal closed()

  property string originalHex: "#3B82F6"
  property string currentHex: "#3B82F6"
  property int currentHue: 217
  property int currentSaturation: 91
  property int currentLightness: 60
  property var recentColors: []
  property string detectedFormat: "HEX"
  property string copyStatusText: ""

  readonly property color bgCol: Color.popups.background || Color.background || "#1e1e2e"
  readonly property color fgCol: Color.popups.text || Color.text || "#cdd6f4"
  readonly property color borderCol: Color.popups.border || Color.border || "#313244"
  readonly property string fontFamily: Style.font.family

  readonly property var vibrantPalette: [
    "#EF4444", "#F97316", "#F59E0B", "#10B981", "#06B6D4",
    "#3B82F6", "#6366F1", "#8B5CF6", "#EC4899", "#F43F5E"
  ]

  readonly property var neutralPalette: [
    "#FFFFFF", "#F1F5F9", "#CBD5E1", "#94A3B8", "#64748B",
    "#475569", "#334155", "#1E293B", "#0F172A", "#000000"
  ]

  Timer {
    id: copyStatusTimer
    interval: 1800
    repeat: false
    onTriggered: root.copyStatusText = ""
  }

  function open(initialHex, historyList) {
    var raw = String(initialHex || "").trim()
    var parsed = ClipboardHistory.extractColorHex(raw) || ColorStudio.parseColor(raw) || "#3B82F6"
    root.originalHex = parsed.toUpperCase()
    root.setColor(parsed)
    root.populateRecents(historyList)
    root.copyStatusText = ""
    root.visible = true
  }

  function close() {
    root.visible = false
    root.closed()
  }

  function setColor(hex) {
    var clean = String(hex || "").trim().toUpperCase()
    if (!clean.startsWith("#") && /^[0-9A-F]{6}$/i.test(clean)) clean = "#" + clean
    var rgb = ColorStudio.hexToRgb(clean)
    if (rgb) {
      var hsl = ColorStudio.rgbToHsl(rgb.r, rgb.g, rgb.b)
      root.currentHue = hsl.h
      root.currentSaturation = hsl.s
      root.currentLightness = hsl.l
      root.currentHex = ColorStudio.rgbToHex(rgb.r, rgb.g, rgb.b)
      if (!inputField.activeFocus) {
        inputField.text = root.currentHex
      }
      root.updateDetectedFormat(root.currentHex)
    }
  }

  function updateFromHsl() {
    var rgb = ColorStudio.hslToRgb(root.currentHue, root.currentSaturation, root.currentLightness)
    root.currentHex = ColorStudio.rgbToHex(rgb.r, rgb.g, rgb.b)
    if (!inputField.activeFocus) {
      inputField.text = root.currentHex
    }
    root.updateDetectedFormat(root.currentHex)
  }

  function resetColor() {
    root.setColor(root.originalHex)
  }

  function applyColor() {
    root.colorSelected(root.currentHex)
    root.close()
  }

  function updateDetectedFormat(str) {
    var s = String(str || "").trim()
    if (/^#?[0-9a-fA-F]{3,8}$/.test(s)) {
      root.detectedFormat = "HEX"
    } else if (/^rgba?\(/i.test(s)) {
      root.detectedFormat = "RGB"
    } else if (/^hsla?\(/i.test(s)) {
      root.detectedFormat = "HSL"
    } else if (/Color\(0x/i.test(s)) {
      root.detectedFormat = "FLUTTER"
    } else if (/UIColor\(/i.test(s)) {
      root.detectedFormat = "SWIFT"
    } else if (/-([5-9]00|50|[1-4]00)/i.test(s)) {
      root.detectedFormat = "TAILWIND"
    } else {
      root.detectedFormat = "COLOR"
    }
  }

  function populateRecents(historyList) {
    var arr = []
    if (Array.isArray(historyList)) {
      for (var i = 0; i < historyList.length && arr.length < 10; i++) {
        var item = historyList[i]
        if (item && item.type === "text" && item.text) {
          var extracted = ClipboardHistory.extractColorHex(item.text)
          if (extracted && arr.indexOf(extracted.toUpperCase()) === -1) {
            arr.push(extracted.toUpperCase())
          }
        }
      }
    }
    root.recentColors = arr
  }

  function copyValue(str, label) {
    if (!str) return
    Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(str) + " | wl-copy"])
    root.copyStatusText = "Copied " + label + "!"
    copyStatusTimer.restart()
  }

  function getRgbString(hex) {
    var rgb = ColorStudio.hexToRgb(hex) || { r: 0, g: 0, b: 0 }
    return "rgb(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ")"
  }

  // Scrim click closes modal
  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  // Main Dialog Container
  Rectangle {
    id: dialogCard
    width: Math.min(parent.width - Style.space(24), Style.space(480))
    height: Math.min(parent.height - Style.space(32), Style.space(660))
    radius: Style.cornerRadius
    color: root.bgCol
    border.width: 1
    border.color: root.borderCol
    anchors.centerIn: parent

    // Absorb clicks so clicking modal card doesn't close dialog
    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      // ==========================================
      // 1. TITLE BAR (With Right-Aligned Close '✕')
      // ==========================================
      Item {
        width: parent.width
        height: Style.space(30)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(26); height: Style.space(26); radius: Style.space(6)
            color: Util.alpha(Color.accent, 0.15)
            border.width: 1; border.color: Util.alpha(Color.accent, 0.4)
            Text {
              text: "󰏘"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.space(14)
              anchors.centerIn: parent
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
              text: "Color Picker"
              color: root.fgCol
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: "HSL Sliders, Universal Code Input & Eyedropper"
              color: Util.alpha(root.fgCol, 0.5)
              font.family: root.fontFamily
              font.pixelSize: Style.space(8)
            }
          }
        }

        // Close '✕' Button (Right Aligned)
        Rectangle {
          id: closeBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(26); height: Style.space(26); radius: Style.space(6)
          color: closeMouse.containsMouse ? Util.alpha(Color.urgent, 0.2) : Util.alpha(root.fgCol, 0.08)
          border.width: 1
          border.color: closeMouse.containsMouse ? Color.urgent : Util.alpha(root.fgCol, 0.12)
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            text: "✕"
            color: closeMouse.containsMouse ? Color.urgent : root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.space(11)
            anchors.centerIn: parent
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }

          PanelToolTip {
            visible: closeMouse.containsMouse
            text: "Close (Esc)"
          }
        }
      }

      // ==========================================
      // 2. SCROLLABLE BODY
      // ==========================================
      Flickable {
        width: parent.width
        height: dialogCard.height - Style.space(16 * 2 + 30 + 12 + 42 + 12)
        contentWidth: width
        contentHeight: bodyCol.implicitHeight
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: bodyCol
          width: parent.width
          spacing: Style.space(12)

          // ----------------------------------------------------
          // A. PREVIEW & EYEDROPPER SUMMARY CARD
          // ----------------------------------------------------
          Rectangle {
            width: parent.width
            height: Style.space(78)
            radius: Style.space(8)
            color: Util.alpha(root.fgCol, 0.04)
            border.width: 1
            border.color: Util.alpha(root.fgCol, 0.1)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(12)

              // Split Color Box: Left = Original (Old), Right = Current (New)
              Rectangle {
                width: Style.space(58); height: Style.space(58)
                radius: Style.space(8)
                clip: true
                border.width: 1; border.color: Util.alpha(root.fgCol, 0.2)

                // Left Half: Original
                Rectangle {
                  width: parent.width / 2
                  height: parent.height
                  anchors.left: parent.left
                  color: root.originalHex

                  Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: Style.space(14)
                    color: Util.alpha("#000000", 0.5)
                    Text {
                      text: "OLD"
                      color: "#FFFFFF"
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(7)
                      font.bold: true
                      anchors.centerIn: parent
                    }
                  }

                  MouseArea {
                    id: revertMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetColor()
                  }

                  PanelToolTip {
                    visible: revertMouse.containsMouse
                    text: "Revert to Original (" + root.originalHex + ")"
                  }
                }

                // Right Half: New (Live)
                Rectangle {
                  width: parent.width / 2
                  height: parent.height
                  anchors.right: parent.right
                  color: root.currentHex

                  Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: Style.space(14)
                    color: Util.alpha("#000000", 0.5)
                    Text {
                      text: "NEW"
                      color: "#FFFFFF"
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(7)
                      font.bold: true
                      anchors.centerIn: parent
                    }
                  }
                }
              }

              // Color Details Column
              Column {
                width: parent.width - Style.space(58 + 110 + 24)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Row {
                  spacing: Style.space(6)
                  Text {
                    text: root.currentHex
                    color: root.fgCol
                    font.family: "monospace"
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }
                  // Copy hex button
                  Rectangle {
                    width: Style.space(18); height: Style.space(18); radius: Style.space(4)
                    color: copyHexMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                      text: "󰅍"
                      color: copyHexMouse.containsMouse ? Color.accent : Util.alpha(root.fgCol, 0.5)
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(10)
                      anchors.centerIn: parent
                    }
                    MouseArea {
                      id: copyHexMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.copyValue(root.currentHex, "HEX")
                    }
                    PanelToolTip { visible: copyHexMouse.containsMouse; text: "Copy Hex Code" }
                  }
                }

                Text {
                  text: ColorStudio.findNearestColorName(root.currentHex)
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: {
                    var rgb = ColorStudio.hexToRgb(root.currentHex) || { r: 0, g: 0, b: 0 }
                    return "rgb(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ") • hsl(" + root.currentHue + "°, " + root.currentSaturation + "%, " + root.currentLightness + "%)"
                  }
                  color: Util.alpha(root.fgCol, 0.55)
                  font.family: "monospace"
                  font.pixelSize: Style.space(8)
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              // Eyedropper Button (Omarchy Hyprpicker)
              Rectangle {
                id: dropperBtn
                width: Style.space(110)
                height: Style.space(38)
                radius: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                color: dropperMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(root.fgCol, 0.08)
                border.width: 1
                border.color: dropperMouse.containsMouse ? Color.accent : Util.alpha(root.fgCol, 0.18)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(5)
                  Text {
                    text: "󰃉"
                    color: dropperMouse.containsMouse ? Color.accent : root.fgCol
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(13)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: "Pick Screen"
                    color: dropperMouse.containsMouse ? Color.accent : root.fgCol
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: dropperMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.requestScreenPick()
                }

                PanelToolTip {
                  visible: dropperMouse.containsMouse
                  text: "Use eyedropper to pick any pixel from your screen"
                }
              }
            }
          }

          // ----------------------------------------------------
          // B. HSL SLIDERS SECTION
          // ----------------------------------------------------
          Rectangle {
            width: parent.width
            height: Style.space(166)
            radius: Style.space(8)
            color: Util.alpha(root.fgCol, 0.03)
            border.width: 1
            border.color: Util.alpha(root.fgCol, 0.08)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              // 1. HUE SLIDER (0 - 360)
              Column {
                width: parent.width
                spacing: Style.space(4)

                Item {
                  width: parent.width
                  height: Style.space(14)
                  Text {
                    anchors.left: parent.left
                    text: "HUE"
                    color: Util.alpha(root.fgCol, 0.6)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                  }
                  Text {
                    anchors.right: parent.right
                    text: root.currentHue + "°"
                    color: root.fgCol
                    font.family: "monospace"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                  }
                }

                Rectangle {
                  id: hueTrack
                  width: parent.width
                  height: Style.space(18)
                  radius: Style.space(9)
                  border.width: 1; border.color: Util.alpha(root.fgCol, 0.15)

                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "#FF0000" }
                    GradientStop { position: 0.17; color: "#FFFF00" }
                    GradientStop { position: 0.33; color: "#00FF00" }
                    GradientStop { position: 0.50; color: "#00FFFF" }
                    GradientStop { position: 0.67; color: "#0000FF" }
                    GradientStop { position: 0.83; color: "#FF00FF" }
                    GradientStop { position: 1.00; color: "#FF0000" }
                  }

                  // Thumb
                  Rectangle {
                    width: Style.space(18); height: Style.space(18)
                    radius: Style.space(9)
                    x: Math.max(0, Math.min(parent.width - width, (root.currentHue / 360) * (parent.width - width)))
                    color: {
                      var rgb = ColorStudio.hslToRgb(root.currentHue, 100, 50)
                      return ColorStudio.rgbToHex(rgb.r, rgb.g, rgb.b)
                    }
                    border.width: 2; border.color: "#FFFFFF"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function handle(mx) {
                      var trackW = parent.width - Style.space(18)
                      if (trackW <= 0) return
                      var clamped = Math.max(0, Math.min(trackW, mx - Style.space(9)))
                      root.currentHue = Math.round((clamped / trackW) * 360)
                      root.updateFromHsl()
                    }
                    onPressed: function(mouse) { handle(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) handle(mouse.x) }
                  }
                }
              }

              // 2. SATURATION SLIDER (0 - 100%)
              Column {
                width: parent.width
                spacing: Style.space(4)

                Item {
                  width: parent.width
                  height: Style.space(14)
                  Text {
                    anchors.left: parent.left
                    text: "SATURATION"
                    color: Util.alpha(root.fgCol, 0.6)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                  }
                  Text {
                    anchors.right: parent.right
                    text: root.currentSaturation + "%"
                    color: root.fgCol
                    font.family: "monospace"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                  }
                }

                Rectangle {
                  id: satTrack
                  width: parent.width
                  height: Style.space(18)
                  radius: Style.space(9)
                  border.width: 1; border.color: Util.alpha(root.fgCol, 0.15)

                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                      position: 0.0
                      color: {
                        var c0 = ColorStudio.hslToRgb(root.currentHue, 0, root.currentLightness)
                        return ColorStudio.rgbToHex(c0.r, c0.g, c0.b)
                      }
                    }
                    GradientStop {
                      position: 1.0
                      color: {
                        var c1 = ColorStudio.hslToRgb(root.currentHue, 100, root.currentLightness)
                        return ColorStudio.rgbToHex(c1.r, c1.g, c1.b)
                      }
                    }
                  }

                  // Thumb
                  Rectangle {
                    width: Style.space(18); height: Style.space(18)
                    radius: Style.space(9)
                    x: Math.max(0, Math.min(parent.width - width, (root.currentSaturation / 100) * (parent.width - width)))
                    color: root.currentHex
                    border.width: 2; border.color: "#FFFFFF"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function handle(mx) {
                      var trackW = parent.width - Style.space(18)
                      if (trackW <= 0) return
                      var clamped = Math.max(0, Math.min(trackW, mx - Style.space(9)))
                      root.currentSaturation = Math.round((clamped / trackW) * 100)
                      root.updateFromHsl()
                    }
                    onPressed: function(mouse) { handle(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) handle(mouse.x) }
                  }
                }
              }

              // 3. LIGHTNESS SLIDER (0 - 100%)
              Column {
                width: parent.width
                spacing: Style.space(4)

                Item {
                  width: parent.width
                  height: Style.space(14)
                  Text {
                    anchors.left: parent.left
                    text: "LIGHTNESS"
                    color: Util.alpha(root.fgCol, 0.6)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                  }
                  Text {
                    anchors.right: parent.right
                    text: root.currentLightness + "%"
                    color: root.fgCol
                    font.family: "monospace"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                  }
                }

                Rectangle {
                  id: lightTrack
                  width: parent.width
                  height: Style.space(18)
                  radius: Style.space(9)
                  border.width: 1; border.color: Util.alpha(root.fgCol, 0.15)

                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#000000" }
                    GradientStop {
                      position: 0.5
                      color: {
                        var cm = ColorStudio.hslToRgb(root.currentHue, root.currentSaturation, 50)
                        return ColorStudio.rgbToHex(cm.r, cm.g, cm.b)
                      }
                    }
                    GradientStop { position: 1.0; color: "#FFFFFF" }
                  }

                  // Thumb
                  Rectangle {
                    width: Style.space(18); height: Style.space(18)
                    radius: Style.space(9)
                    x: Math.max(0, Math.min(parent.width - width, (root.currentLightness / 100) * (parent.width - width)))
                    color: root.currentHex
                    border.width: 2; border.color: root.currentLightness > 70 ? "#222222" : "#FFFFFF"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function handle(mx) {
                      var trackW = parent.width - Style.space(18)
                      if (trackW <= 0) return
                      var clamped = Math.max(0, Math.min(trackW, mx - Style.space(9)))
                      root.currentLightness = Math.round((clamped / trackW) * 100)
                      root.updateFromHsl()
                    }
                    onPressed: function(mouse) { handle(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) handle(mouse.x) }
                  }
                }
              }
            }
          }

          // ----------------------------------------------------
          // C. UNIVERSAL COLOR INPUT & DEV FORMATS
          // ----------------------------------------------------
          Rectangle {
            width: parent.width
            height: Style.space(100)
            radius: Style.space(8)
            color: Util.alpha(root.fgCol, 0.03)
            border.width: 1
            border.color: Util.alpha(root.fgCol, 0.08)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              Item {
                width: parent.width
                height: Style.space(14)
                Text {
                  anchors.left: parent.left
                  text: "UNIVERSAL INPUT & AUTO-DETECTION"
                  color: Util.alpha(root.fgCol, 0.6)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                }
                Rectangle {
                  anchors.right: parent.right
                  width: Style.space(68); height: Style.space(14); radius: Style.space(3)
                  color: Util.alpha(Color.accent, 0.18)
                  border.width: 1; border.color: Util.alpha(Color.accent, 0.35)
                  Text {
                    text: root.detectedFormat
                    color: Color.accent
                    font.family: "monospace"
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
              }

              // Text Input
              Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.space(6)
                color: Util.alpha(root.fgCol, 0.06)
                border.width: 1
                border.color: inputField.activeFocus ? Color.accent : Util.alpha(root.fgCol, 0.15)

                TextInput {
                  id: inputField
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  color: root.fgCol
                  font.family: "monospace"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  text: root.currentHex
                  selectByMouse: true
                  onTextChanged: {
                    if (activeFocus) {
                      var raw = text.trim()
                      var hex = ClipboardHistory.extractColorHex(raw) || ColorStudio.parseColor(raw)
                      if (hex) {
                        root.setColor(hex)
                      }
                      root.updateDetectedFormat(raw)
                    }
                  }
                  onAccepted: {
                    var raw = text.trim()
                    var hex = ClipboardHistory.extractColorHex(raw) || ColorStudio.parseColor(raw)
                    if (hex) {
                      root.setColor(hex)
                    }
                  }
                }

                Text {
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  visible: !inputField.text && !inputField.activeFocus
                  text: "Type/paste #HEX, rgb(), hsl(), Color(0x...), blue-500..."
                  color: Util.alpha(root.fgCol, 0.3)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              // Format Chips Row (Click to copy)
              Row {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: [
                    { label: "HEX", code: root.currentHex },
                    { label: "RGB", code: root.getRgbString(root.currentHex) },
                    { label: "HSL", code: "hsl(" + root.currentHue + ", " + root.currentSaturation + "%, " + root.currentLightness + "%)" },
                    { label: "Flutter", code: ColorStudio.formatCode(root.currentHex, "flutter") },
                    { label: "Swift", code: ColorStudio.formatCode(root.currentHex, "swift") }
                  ]

                  Rectangle {
                    width: (parent.width - Style.space(24)) / 5
                    height: Style.space(22)
                    radius: Style.space(4)
                    color: chipMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fgCol, 0.05)
                    border.width: 1
                    border.color: chipMouse.containsMouse ? Color.accent : Util.alpha(root.fgCol, 0.12)

                    Text {
                      text: modelData.label
                      color: chipMouse.containsMouse ? Color.accent : Util.alpha(root.fgCol, 0.8)
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      anchors.centerIn: parent
                    }

                    MouseArea {
                      id: chipMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.copyValue(modelData.code, modelData.label)
                    }

                    PanelToolTip {
                      visible: chipMouse.containsMouse
                      text: "Copy " + modelData.label + ": " + modelData.code
                    }
                  }
                }
              }
            }
          }

          // ----------------------------------------------------
          // D. PRESET PALETTES & RECENT COLORS
          // ----------------------------------------------------
          Rectangle {
            width: parent.width
            height: Style.space(root.recentColors.length > 0 ? 116 : 84)
            radius: Style.space(8)
            color: Util.alpha(root.fgCol, 0.03)
            border.width: 1
            border.color: Util.alpha(root.fgCol, 0.08)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                text: "PRESET PALETTES & RECENTS"
                color: Util.alpha(root.fgCol, 0.6)
                font.family: root.fontFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }

              // Row 1: Vibrant
              Row {
                width: parent.width
                spacing: Style.space(6)
                Repeater {
                  model: root.vibrantPalette
                  Rectangle {
                    width: (parent.width - Style.space(54)) / 10
                    height: Style.space(20)
                    radius: Style.space(4)
                    color: modelData
                    border.width: root.currentHex.toUpperCase() === modelData.toUpperCase() ? 2 : 1
                    border.color: root.currentHex.toUpperCase() === modelData.toUpperCase() ? "#FFFFFF" : Util.alpha(root.fgCol, 0.2)

                    MouseArea {
                      id: vibMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setColor(modelData)
                    }
                    PanelToolTip { visible: vibMouse.containsMouse; text: modelData }
                  }
                }
              }

              // Row 2: Neutrals & Monochrome
              Row {
                width: parent.width
                spacing: Style.space(6)
                Repeater {
                  model: root.neutralPalette
                  Rectangle {
                    width: (parent.width - Style.space(54)) / 10
                    height: Style.space(20)
                    radius: Style.space(4)
                    color: modelData
                    border.width: root.currentHex.toUpperCase() === modelData.toUpperCase() ? 2 : 1
                    border.color: root.currentHex.toUpperCase() === modelData.toUpperCase() ? Color.accent : Util.alpha(root.fgCol, 0.25)

                    MouseArea {
                      id: neutMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setColor(modelData)
                    }
                    PanelToolTip { visible: neutMouse.containsMouse; text: modelData }
                  }
                }
              }

              // Row 3: Recents from Clipboard (if any)
              Row {
                width: parent.width
                spacing: Style.space(6)
                visible: root.recentColors.length > 0
                Repeater {
                  model: root.recentColors
                  Rectangle {
                    width: (parent.width - Style.space(54)) / 10
                    height: Style.space(20)
                    radius: Style.space(4)
                    color: modelData
                    border.width: root.currentHex.toUpperCase() === modelData.toUpperCase() ? 2 : 1
                    border.color: root.currentHex.toUpperCase() === modelData.toUpperCase() ? "#FFFFFF" : Util.alpha(root.fgCol, 0.25)

                    MouseArea {
                      id: recMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setColor(modelData)
                    }
                    PanelToolTip { visible: recMouse.containsMouse; text: "Recent: " + modelData }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // 3. FOOTER ACTIONS (Reset, Cancel, Apply)
      // ==========================================
      Item {
        width: parent.width
        height: Style.space(32)

        // Left: Reset Button & Status feedback
        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(80); height: Style.space(30); radius: Style.space(6)
            color: resetMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.08)
            border.width: 1; border.color: Util.alpha(root.fgCol, 0.12)
            Row {
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: "󰁯"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(11); anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Reset"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: resetMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.resetColor()
            }
            PanelToolTip { visible: resetMouse.containsMouse; text: "Revert to original color" }
          }

          Text {
            visible: root.copyStatusText !== ""
            text: root.copyStatusText
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.space(9)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Right: Cancel & Apply
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(70); height: Style.space(30); radius: Style.space(6)
            color: cancelMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.08)
            border.width: 1; border.color: Util.alpha(root.fgCol, 0.12)
            Text { text: "Cancel"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
            MouseArea {
              id: cancelMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }

          Rectangle {
            width: Style.space(100); height: Style.space(30); radius: Style.space(6)
            color: applyMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text { text: "✓"; color: "#FFFFFF"; font.pixelSize: Style.space(11); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Apply Color"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: applyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.applyColor()
            }
          }
        }
      }
    }
  }
}
