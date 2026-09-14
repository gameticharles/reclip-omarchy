import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
  id: footerContainer
  required property var modal
  readonly property var root: modal
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(59)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------------------
        // Row 1: Action Controls & Feedback Toast (Height: 34px)
        // -------------------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(34)
          Layout.leftMargin: Style.space(10)
          Layout.rightMargin: Style.space(10)
          spacing: Style.space(8)

          // Left: Secondary Actions (Copy Original, Save File)
          Row {
            spacing: Style.space(6)
            Layout.alignment: Qt.AlignVCenter

            // Copy Clean Original
            Rectangle {
              height: Style.space(24)
              width: copyOrigTxt.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: origMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1; border.color: Util.alpha(Color.popups.text || Color.text, 0.15)
              Row {
                id: copyOrigTxt
                anchors.centerIn: parent; spacing: Style.space(4)
                Text { text: "󰆏"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Original"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
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
              height: Style.space(24)
              width: saveFileTxt.implicitWidth + Style.space(12)
              radius: Style.space(4)
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
                  font.pixelSize: Style.space(8)
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
          }

          // Center: Flexible Feedback Toast / Status Pill (never overflows!)
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
              id: fbPill
              visible: root.actionFeedback !== ""
              anchors.centerIn: parent
              height: Style.space(22)
              width: Math.min(parent.width - Style.space(10), fbRow.implicitWidth + Style.space(16))
              radius: Style.space(3)
              color: Util.alpha(Color.accent, 0.2)
              border.width: 1
              border.color: Color.accent

              Row {
                id: fbRow
                anchors.centerIn: parent
                spacing: Style.space(4)
                width: Math.min(parent.width - Style.space(8), implicitWidth)

                Text {
                  text: "✓"
                  color: Color.accent
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: fbTxt
                  text: root.actionFeedback
                  color: Color.accent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, fbPill.width - Style.space(24))
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }

          // Right: Action Buttons: Cancel and Copy & Save
          Row {
            spacing: Style.space(6)
            Layout.alignment: Qt.AlignVCenter

            // Cancel
            Rectangle {
              width: Style.space(58)
              height: Style.space(24)
              radius: Style.space(4)
              color: cancelMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.06)
              border.width: 1
              border.color: Util.alpha(Color.popups.text || Color.text, 0.12)

              Text {
                text: "Cancel"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
                anchors.centerIn: parent
              }

              MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
              }
              PanelToolTip { visible: cancelMouse.containsMouse; text: "Discard edits and close (Esc)" }
            }

            // Copy & Save
            Rectangle {
              width: copyClipTxt.implicitWidth + Style.space(16)
              height: Style.space(24)
              radius: Style.space(4)
              color: copyClipMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

              Row {
                id: copyClipTxt
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "󰆏"; color: "#FFFFFF"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
                Text {
                  text: "Copy & Save"
                  color: "#FFFFFF"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: copyClipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.exportImage("clipboard")
              }
              PanelToolTip { visible: copyClipMouse.containsMouse; text: "Copy annotated image & save to feed" }
            }
          }
        }

        // -------------------------------------------------------------
        // Hairline Divider
        // -------------------------------------------------------------
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.3)
        }

        // -------------------------------------------------------------
        // Row 2: Dedicated Status & Image Statistics Strip (Height: 24px)
        // -------------------------------------------------------------
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(24)
          color: Util.alpha("#000000", 0.18)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            // Statistics (Resolution, Zoom, Edits Status)
            Row {
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignVCenter

              readonly property int editCount: root.actions.length + (root.imageHistory ? root.imageHistory.length : 0)

              // Resolution
              Text {
                text: "🖼 " + Math.round(baseImage.implicitWidth > 0 ? baseImage.implicitWidth : compositeContainer.baseW) + "×" + Math.round(baseImage.implicitHeight > 0 ? baseImage.implicitHeight : compositeContainer.baseH) + " px"
                color: Util.alpha(Color.popups.text || Color.text, 0.65)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: Util.alpha(Color.popups.text || Color.text, 0.35)
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              // Zoom Scale
              Text {
                text: "🔍 " + Math.round(root.zoomScale * 100) + "%"
                color: Util.alpha(Color.popups.text || Color.text, 0.65)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: Util.alpha(Color.popups.text || Color.text, 0.35)
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              // Edit count indicator dot & label
              Row {
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  width: Style.space(6); height: Style.space(6); radius: Style.space(3)
                  color: parent.parent.editCount > 0 ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.25)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: parent.parent.editCount > 0 ? (parent.parent.editCount + (parent.parent.editCount === 1 ? " edit" : " edits")) : "Clean"
                  color: parent.parent.editCount > 0 ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.55)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Selection indicator if an element is selected
              Text {
                visible: root.selectedActionIndex >= 0
                text: "· (Item #" + (root.selectedActionIndex + 1) + " selected)"
                color: Color.accent
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Item { Layout.fillWidth: true }

            // RIGHT: Active Tool & Universal Keyboard Shortcut Chips (Matching Home Page Style)
            Row {
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignVCenter

              // Active Tool
              Text {
                text: "Tool: " + root.currentTool.toUpperCase()
                color: Color.accent
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: Util.alpha(Color.popups.text || Color.text, 0.35)
                font.pixelSize: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              // Ctrl+Z Undo Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlZTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlZTxt
                    text: "Ctrl+Z"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Undo"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Ctrl+S Save Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlSTxtImg.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlSTxtImg
                    text: "Ctrl+S"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Save"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Ctrl+C Copy Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlCTxtImg.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlCTxtImg
                    text: "Ctrl+C"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Copy"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Esc Close Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), imgEscTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: imgEscTxt
                    text: "Esc"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Close"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }
        }
      }
    }
