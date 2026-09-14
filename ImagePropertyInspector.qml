import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
  id: selFloatingActions
  required property var modal
  readonly property var root: modal
  required property var selectionOverlay
  property alias fontPickerTriggerBtn: fontPickerTriggerBtn
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
                        color: isRatioLocked ? Util.alpha(Color.accent, 0.25) : (ratioLockMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.14) : Util.alpha(Color.popups.text || Color.text, 0.06))
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
                          id: ratioLockMouse
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleSelectedLockRatio()
                        }
                        PanelToolTip {
                          visible: ratioLockMouse.containsMouse
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

                      // 5. BLUR CONTROLS (Shape, Radius & Optical Dispersion)
                      Row {
                        visible: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.tool === "blur")
                        spacing: Style.space(3)
                        anchors.verticalCenter: parent.verticalCenter

                        // Shape Toggle: Rect vs Circle
                        Row {
                          spacing: Style.space(1.5)
                          anchors.verticalCenter: parent.verticalCenter

                          Rectangle {
                            width: Style.space(18); height: Style.space(18); radius: Style.space(4)
                            property bool isSelected: !selectionOverlay.curAct || selectionOverlay.curAct.shape !== "circle"
                            color: isSelected ? Util.alpha(Color.accent, 0.25) : (brectMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
                            border.width: 1
                            border.color: isSelected ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "□"; color: parent.isSelected ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
                            MouseArea {
                              id: brectMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedBlurShape("rect")
                            }
                            PanelToolTip { visible: brectMouse.containsMouse; text: "Rectangle Blur" }
                          }

                          Rectangle {
                            width: Style.space(18); height: Style.space(18); radius: Style.space(4)
                            property bool isSelected: Boolean(selectionOverlay.curAct && selectionOverlay.curAct.shape === "circle")
                            color: isSelected ? Util.alpha(Color.accent, 0.25) : (bcircMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
                            border.width: 1
                            border.color: isSelected ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "○"; color: parent.isSelected ? Color.accent : (Color.popups.text || Color.text); font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
                            MouseArea {
                              id: bcircMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.setSelectedBlurShape("circle")
                            }
                            PanelToolTip { visible: bcircMouse.containsMouse; text: "Circle / Ellipse Blur" }
                          }
                        }

                        // Corner Radius (Rectangle only)
                        SmartScrubber {
                          visible: !selectionOverlay.curAct || selectionOverlay.curAct.shape !== "circle"
                          label: "Radius"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.radius !== undefined) ? selectionOverlay.curAct.radius : root.blurRadius
                          from: 0
                          to: 60
                          step: 2
                          unit: "px"
                          tip: "Blur corner radius"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("radius", val); root.blurRadius = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("radius", val, "Blur Radius"); root.blurRadius = val }
                        }

                        // Optical Dispersion Scrubber
                        SmartScrubber {
                          label: "Dispersion"
                          value: (selectionOverlay.curAct && selectionOverlay.curAct.dispersion !== undefined) ? selectionOverlay.curAct.dispersion : (root.blurDispersion || 4)
                          from: 2
                          to: 32
                          step: 1
                          unit: "px"
                          tip: "Blur optical dispersion radius (drag or double-click to type)"
                          onValueScrubbed: function(val) { root.modifySelectedProperty("dispersion", val); root.blurDispersion = val }
                          onValueCommitted: function(val) { root.commitSelectedProperty("dispersion", val, "Blur Dispersion"); root.blurDispersion = val }
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
