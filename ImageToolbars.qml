import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

ColumnLayout {
  id: toolbarsRoot
  required property var modal
  readonly property var root: modal
  spacing: 0
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

        // QR Decode Action Button (QR Scan / Decode)
        Rectangle {
          width: Style.space(24); height: Style.space(24); radius: Style.space(4)
          color: qrDecMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.popups.text || Color.text, 0.06)
          border.width: 1; border.color: qrDecMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
          Text {
            text: "QR"
            color: qrDecMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text)
            font.family: Style.font.fixedFamily || "monospace"
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.centerIn: parent
          }
          MouseArea {
            id: qrDecMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.imagePath) {
                root.requestQrDecode(root.imagePath)
              }
            }
          }
          PanelToolTip { visible: qrDecMouse.containsMouse; text: "Decode QR code from image" }
        }

        // Layer Panel Toggle Button
        Rectangle {
          id: layerToggleBtn
          height: Style.space(24)
          width: Math.max(Style.space(24), layerBtnRow.implicitWidth + Style.space(10))
          radius: Style.space(4)
          color: root.layerPanelOpen ? Color.accent : (layerMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
          border.width: 1
          border.color: root.layerPanelOpen ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

          Row {
            id: layerBtnRow
            anchors.centerIn: parent
            spacing: Style.space(3)

            Text {
              text: "󰘚"
              color: root.layerPanelOpen ? (Color.popups.background || "#FFFFFF") : (Color.popups.text || Color.text)
              font.pixelSize: Style.space(11)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              visible: root.actions.length > 0
              text: String(root.actions.length)
              color: root.layerPanelOpen ? (Color.popups.background || "#FFFFFF") : (Color.popups.text || Color.text)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            id: layerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.layerPanelOpen = !root.layerPanelOpen
            }
          }
          PanelToolTip { visible: layerMouse.containsMouse; text: "Toggle Layer Panel (Ctrl+L)" }
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

}
