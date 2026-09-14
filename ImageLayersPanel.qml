import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
  id: layerPanelRoot
  required property var modal
  readonly property var root: modal
  property alias layerListView: layerListView
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Style.space(8)
        width: Style.space(280)
        radius: Style.space(8)
        color: Util.alpha(Color.popups.background || Color.background, 0.96)
        border.width: 1
        border.color: Util.alpha(Color.popups.border || Color.border, 0.6)
        visible: root.layerPanelOpen
        z: 45
        clip: true

        // Absorb clicks so they don't bleed into canvas
        MouseArea {
          anchors.fill: parent
          onClicked: function(mouse) { mouse.accepted = true }
          onPressed: function(mouse) { mouse.accepted = true }
          onReleased: function(mouse) { mouse.accepted = true }
          onDoubleClicked: function(mouse) { mouse.accepted = true }
          onWheel: function(wheel) { wheel.accepted = true }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // ----------------------------------------
          // 1. PANEL HEADER
          // ----------------------------------------
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(36)
            color: Util.alpha(Color.popups.text || Color.text, 0.04)

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: Util.alpha(Color.popups.border || Color.border, 0.4)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: "󰘚"
                color: Color.accent
                font.pixelSize: Style.space(13)
                Layout.alignment: Qt.AlignVCenter
              }

              Text {
                text: "Layers"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(9)
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
              }

              // Count Pill
              Rectangle {
                height: Style.space(16)
                width: layerCountTxt.implicitWidth + Style.space(8)
                radius: Style.space(8)
                color: Util.alpha(Color.accent, 0.16)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.3)
                Layout.alignment: Qt.AlignVCenter

                Text {
                  id: layerCountTxt
                  anchors.centerIn: parent
                  text: root.layerSearchQuery.trim() !== ""
                    ? (root.visibleLayerIndices.length + "/" + root.actions.length)
                    : String(root.actions.length)
                  color: Color.accent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7)
                  font.bold: true
                }
              }

              Item { Layout.fillWidth: true }

              // Select All Button
              Rectangle {
                width: Style.space(20); height: Style.space(20); radius: Style.space(3)
                color: selAllMouse.containsMouse ? Util.alpha(Color.accent, 0.18) : "transparent"
                visible: root.actions.length > 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                  text: "󰒅"
                  color: selAllMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.6)
                  font.pixelSize: Style.space(10)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: selAllMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectAllLayers()
                }
                PanelToolTip { visible: selAllMouse.containsMouse; text: "Select All (Ctrl+A)" }
              }

              // Close Panel Button
              Rectangle {
                width: Style.space(20); height: Style.space(20); radius: Style.space(3)
                color: closeLayerMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Text {
                  text: "✕"
                  color: closeLayerMouse.containsMouse ? Color.urgent : Util.alpha(Color.popups.text || Color.text, 0.6)
                  font.pixelSize: Style.space(9)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: closeLayerMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.layerPanelOpen = false
                }
                PanelToolTip { visible: closeLayerMouse.containsMouse; text: "Close Layers (Ctrl+L)" }
              }
            }
          }

          // ----------------------------------------
          // 2. SEARCH & FILTER BAR
          // ----------------------------------------
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(32)
            color: "transparent"
            visible: root.actions.length > 0

            Rectangle {
              anchors.fill: parent
              anchors.margins: Style.space(4)
              radius: Style.space(4)
              color: Util.alpha(Color.popups.text || Color.text, 0.05)
              border.width: 1
              border.color: searchInput.activeFocus ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.35)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(4)

                Text {
                  text: "󰍉"
                  color: Util.alpha(Color.popups.text || Color.text, 0.45)
                  font.pixelSize: Style.space(9)
                  Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                  id: searchInput
                  Layout.fillWidth: true
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  color: Color.popups.text || Color.text
                  selectByMouse: true
                  text: root.layerSearchQuery
                  onTextChanged: root.layerSearchQuery = text

                  Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Filter layers..."
                    color: Util.alpha(Color.popups.text || Color.text, 0.3)
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(7.5)
                    visible: !searchInput.text && !searchInput.activeFocus
                  }
                }

                // Clear Search Button
                Rectangle {
                  width: Style.space(14); height: Style.space(14); radius: Style.space(7)
                  visible: root.layerSearchQuery.length > 0
                  color: lpClearSearchMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.2) : "transparent"
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    text: "✕"
                    color: Util.alpha(Color.popups.text || Color.text, 0.6)
                    font.pixelSize: Style.space(7)
                    anchors.centerIn: parent
                  }

                  MouseArea {
                    id: lpClearSearchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.layerSearchQuery = ""
                      searchInput.text = ""
                    }
                  }
                }
              }
            }
          }

          // ----------------------------------------
          // 3. MULTI-SELECTION BANNER
          // ----------------------------------------
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(26)
            color: Util.alpha(Color.accent, 0.14)
            visible: root.selectedActionIndices && root.selectedActionIndices.length > 1

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: Util.alpha(Color.accent, 0.3)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: (root.selectedActionIndices ? root.selectedActionIndices.length : 0) + " selected"
                color: Color.accent
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
              }

              Item { Layout.fillWidth: true }

              // Quick Group
              Rectangle {
                height: Style.space(18)
                width: grpTxt.implicitWidth + Style.space(12)
                radius: Style.space(3)
                color: qkGrpMouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.accent, 0.2)
                border.width: 1
                border.color: Color.accent
                Layout.alignment: Qt.AlignVCenter

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Text { text: "󰉋"; font.pixelSize: Style.space(8); color: Color.accent; anchors.verticalCenter: parent.verticalCenter }
                  Text { id: grpTxt; text: "Group"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.accent; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  id: qkGrpMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.groupSelectedActions()
                }
                PanelToolTip { visible: qkGrpMouse.containsMouse; text: "Group Selected (Ctrl+G)" }
              }

              // Quick Delete
              Rectangle {
                width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                color: qkDelMouse.containsMouse ? Util.alpha(Color.urgent, 0.25) : Util.alpha(Color.urgent, 0.12)
                border.width: 1
                border.color: Color.urgent
                Layout.alignment: Qt.AlignVCenter

                Text {
                  text: "🗑"
                  color: Color.urgent
                  font.pixelSize: Style.space(8)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: qkDelMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.deleteSelectedAction()
                }
                PanelToolTip { visible: qkDelMouse.containsMouse; text: "Delete Selected" }
              }

              // Deselect
              Rectangle {
                width: Style.space(18); height: Style.space(18); radius: Style.space(3)
                color: lpDeselMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Text {
                  text: "✕"
                  color: Util.alpha(Color.popups.text || Color.text, 0.6)
                  font.pixelSize: Style.space(7.5)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: lpDeselMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedActionIndices = []
                    root.selectedActionIndex = -1
                  }
                }
                PanelToolTip { visible: lpDeselMouse.containsMouse; text: "Deselect" }
              }
            }
          }

          // ----------------------------------------
          // 4. LAYER LIST VIEW / EMPTY STATE
          // ----------------------------------------
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Empty state placeholder
            Column {
              anchors.centerIn: parent
              spacing: Style.space(6)
              visible: root.actions.length === 0

              Text {
                text: "󰘚"
                color: Util.alpha(Color.popups.text || Color.text, 0.2)
                font.pixelSize: Style.space(28)
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                text: "No layers yet"
                color: Util.alpha(Color.popups.text || Color.text, 0.45)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8.5)
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                text: "Draw annotations to create layers"
                color: Util.alpha(Color.popups.text || Color.text, 0.3)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7)
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }

            // No filter results placeholder
            Column {
              anchors.centerIn: parent
              spacing: Style.space(6)
              visible: root.actions.length > 0 && root.visibleLayerIndices.length === 0

              Text {
                text: "󰍉"
                color: Util.alpha(Color.popups.text || Color.text, 0.2)
                font.pixelSize: Style.space(24)
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                text: "No matching layers"
                color: Util.alpha(Color.popups.text || Color.text, 0.45)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }

            // Layer list
            ListView {
              id: layerListView
              anchors.fill: parent
              anchors.margins: Style.space(6)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              spacing: Style.space(4)
              model: root.visibleLayerIndices
              visible: root.visibleLayerIndices.length > 0

              delegate: Rectangle {
                id: layerDelegateRoot
                width: layerListView.width
                height: contentCol.implicitHeight
                radius: Style.space(4)

                readonly property int actionIndex: modelData
                readonly property var curAct: {
                  var _rev = root.layerRevision
                  return (actionIndex >= 0 && actionIndex < root.actions.length) ? root.actions[actionIndex] : null
                }
                readonly property bool isSelected: (root.selectedActionIndices && root.selectedActionIndices.indexOf(actionIndex) !== -1) || root.selectedActionIndex === actionIndex
                readonly property bool isHidden: Boolean(curAct && curAct.hidden)
                readonly property bool isLocked: Boolean(curAct && curAct.locked)
                readonly property bool isGroup: Boolean(curAct && curAct.tool === "group")
                readonly property bool isExpanded: Boolean(curAct && curAct.expanded !== false)
                readonly property bool isEditing: root.editingLayerIndex === actionIndex
                readonly property bool isDragSource: root.dragLayerSourceIndex === actionIndex
                readonly property bool isDragTarget: root.dragLayerTargetIndex === actionIndex && root.dragLayerSourceIndex >= 0 && root.dragLayerSourceIndex !== actionIndex

                color: isSelected ? Util.alpha(Color.accent, 0.18) : (rowMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.02))
                border.width: 1
                border.color: isDragTarget ? Color.accent : (isSelected ? Color.accent : (rowMouse.containsMouse ? Util.alpha(Color.accent, 0.35) : Util.alpha(Color.popups.border || Color.border, 0.25)))
                opacity: isDragSource ? 0.45 : (isHidden ? 0.48 : 1.0)

                // Drag Target Indicator Line
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  height: Style.space(2)
                  radius: Style.space(1)
                  color: Color.accent
                  visible: layerDelegateRoot.isDragTarget
                  z: 10
                }

                // Left selection highlight bar
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(3)
                  width: Style.space(3)
                  radius: Style.space(1.5)
                  color: Color.accent
                  visible: layerDelegateRoot.isSelected
                }

                Column {
                  id: contentCol
                  width: parent.width

                  // Main Row Container
                  Rectangle {
                    width: parent.width
                    height: Style.space(32)
                    color: "transparent"

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(5)
                      spacing: Style.space(4)

                      // Drag Handle
                      Rectangle {
                        width: Style.space(14)
                        height: Style.space(22)
                        radius: Style.space(2)
                        color: dragHandleMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: "⠿"
                          color: dragHandleMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.35)
                          font.pixelSize: Style.space(9)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: dragHandleMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.OpenHandCursor
                          onPressed: function(mouse) {
                            cursorShape = Qt.ClosedHandCursor
                            root.dragLayerSourceIndex = layerDelegateRoot.actionIndex
                            root.dragLayerTargetIndex = layerDelegateRoot.actionIndex
                          }
                          onPositionChanged: function(mouse) {
                            if (pressed && root.dragLayerSourceIndex >= 0) {
                              var pt = dragHandleMouse.mapToItem(layerListView.contentItem, mouse.x, mouse.y)
                              if (pt.y <= 0 && root.visibleLayerIndices.length > 0) {
                                root.dragLayerTargetIndex = root.visibleLayerIndices[0]
                              } else if (pt.y >= layerListView.contentItem.height && root.visibleLayerIndices.length > 0) {
                                root.dragLayerTargetIndex = root.visibleLayerIndices[root.visibleLayerIndices.length - 1]
                              } else {
                                var targetUiIdx = layerListView.indexAt(layerListView.width / 2, pt.y)
                                if (targetUiIdx >= 0 && targetUiIdx < root.visibleLayerIndices.length) {
                                  root.dragLayerTargetIndex = root.visibleLayerIndices[targetUiIdx]
                                }
                              }
                            }
                          }
                          onReleased: {
                            cursorShape = Qt.OpenHandCursor
                            if (root.dragLayerSourceIndex >= 0 && root.dragLayerTargetIndex >= 0 && root.dragLayerSourceIndex !== root.dragLayerTargetIndex) {
                              root.moveLayer(root.dragLayerSourceIndex, root.dragLayerTargetIndex)
                            }
                            root.dragLayerSourceIndex = -1
                            root.dragLayerTargetIndex = -1
                          }
                        }
                        PanelToolTip { visible: dragHandleMouse.containsMouse; text: "Drag to reorder" }
                      }

                      // Group Chevron Expand/Collapse
                      Rectangle {
                        width: Style.space(14)
                        height: Style.space(16)
                        radius: Style.space(2)
                        visible: layerDelegateRoot.isGroup
                        color: chevMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: layerDelegateRoot.isExpanded ? "▼" : "▶"
                          color: Util.alpha(Color.popups.text || Color.text, 0.7)
                          font.pixelSize: Style.space(7)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: chevMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleGroupExpanded(layerDelegateRoot.actionIndex)
                        }
                        PanelToolTip { visible: chevMouse.containsMouse; text: layerDelegateRoot.isExpanded ? "Collapse group" : "Expand group" }
                      }

                      // Color pip (only for non-group actions)
                      Rectangle {
                        width: Style.space(7)
                        height: Style.space(7)
                        radius: Style.space(3.5)
                        visible: !layerDelegateRoot.isGroup
                        color: root.getLayerColor(layerDelegateRoot.curAct)
                        border.width: 1
                        border.color: Util.alpha("#FFFFFF", 0.3)
                        Layout.alignment: Qt.AlignVCenter
                      }

                      // Tool icon
                      Text {
                        text: root.getLayerIcon(layerDelegateRoot.curAct)
                        color: layerDelegateRoot.isSelected ? Color.accent : (Color.popups.text || Color.text)
                        font.pixelSize: Style.space(10)
                        Layout.alignment: Qt.AlignVCenter
                      }

                      // Layer Title / Inline Rename TextInput
                      Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Regular Text Title
                        Text {
                          visible: !layerDelegateRoot.isEditing
                          anchors.fill: parent
                          verticalAlignment: Text.AlignVCenter
                          text: root.getLayerTitle(layerDelegateRoot.curAct, layerDelegateRoot.actionIndex)
                          color: layerDelegateRoot.isSelected ? Color.accent : (Color.popups.text || Color.text)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: layerDelegateRoot.isSelected
                          font.strikeout: layerDelegateRoot.isHidden
                          elide: Text.ElideRight
                        }

                        // Inline Rename Input
                        Rectangle {
                          visible: layerDelegateRoot.isEditing
                          anchors.fill: parent
                          anchors.margins: 1
                          radius: Style.space(2)
                          color: Util.alpha(Color.popups.text || Color.text, 0.08)
                          border.width: 1
                          border.color: Color.accent

                          TextInput {
                            id: renameInput
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(3)
                            anchors.rightMargin: Style.space(3)
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            color: Color.popups.text || Color.text
                            selectByMouse: true
                            text: (layerDelegateRoot.curAct && layerDelegateRoot.curAct.name)
                              ? layerDelegateRoot.curAct.name
                              : root.getLayerTitle(layerDelegateRoot.curAct, layerDelegateRoot.actionIndex)

                            Component.onCompleted: {
                              if (layerDelegateRoot.isEditing) {
                                forceActiveFocus()
                                selectAll()
                              }
                            }
                            onActiveFocusChanged: {
                              if (!activeFocus && layerDelegateRoot.isEditing) {
                                root.setLayerName(layerDelegateRoot.actionIndex, text)
                                root.editingLayerIndex = -1
                              }
                            }
                            onAccepted: {
                              root.setLayerName(layerDelegateRoot.actionIndex, text)
                              root.editingLayerIndex = -1
                            }
                            Keys.onEscapePressed: {
                              root.editingLayerIndex = -1
                            }
                          }
                        }
                      }

                      // Rename button ✏ (on hover or selected, when not already editing)
                      Rectangle {
                        width: Style.space(16); height: Style.space(16); radius: Style.space(2)
                        visible: (rowMouse.containsMouse || layerDelegateRoot.isSelected) && !layerDelegateRoot.isEditing && !layerDelegateRoot.isLocked
                        color: renRowMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: "✏"
                          color: renRowMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.45)
                          font.pixelSize: Style.space(8)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: renRowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.editingLayerIndex = layerDelegateRoot.actionIndex
                        }
                        PanelToolTip { visible: renRowMouse.containsMouse; text: "Rename layer" }
                      }

                      // Move Up ▲ (Nudge button)
                      Rectangle {
                        width: Style.space(14); height: Style.space(16); radius: Style.space(2)
                        visible: (rowMouse.containsMouse || layerDelegateRoot.isSelected) && (layerDelegateRoot.actionIndex < root.actions.length - 1)
                        color: nudgeUpMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: "▲"
                          color: nudgeUpMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.45)
                          font.pixelSize: Style.space(7)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: nudgeUpMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.moveLayerStep(layerDelegateRoot.actionIndex, 1)
                        }
                        PanelToolTip { visible: nudgeUpMouse.containsMouse; text: "Move up (])" }
                      }

                      // Move Down ▼ (Nudge button)
                      Rectangle {
                        width: Style.space(14); height: Style.space(16); radius: Style.space(2)
                        visible: (rowMouse.containsMouse || layerDelegateRoot.isSelected) && (layerDelegateRoot.actionIndex > 0)
                        color: nudgeDownMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: "▼"
                          color: nudgeDownMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.45)
                          font.pixelSize: Style.space(7)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: nudgeDownMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.moveLayerStep(layerDelegateRoot.actionIndex, -1)
                        }
                        PanelToolTip { visible: nudgeDownMouse.containsMouse; text: "Move down ([)" }
                      }

                      // Visibility Toggle Button (Eye)
                      Rectangle {
                        width: Style.space(16); height: Style.space(16); radius: Style.space(2)
                        color: eyeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: layerDelegateRoot.isHidden ? "󰈉" : "󰈈"
                          color: layerDelegateRoot.isHidden ? Util.alpha(Color.popups.text || Color.text, 0.4) : (layerDelegateRoot.isSelected ? Color.accent : (Color.popups.text || Color.text))
                          font.pixelSize: Style.space(9)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: eyeMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleLayerVisibility(layerDelegateRoot.actionIndex)
                        }
                        PanelToolTip { visible: eyeMouse.containsMouse; text: layerDelegateRoot.isHidden ? "Show layer" : "Hide layer" }
                      }

                      // Lock Toggle Button
                      Rectangle {
                        width: Style.space(16); height: Style.space(16); radius: Style.space(2)
                        color: lockRowMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: layerDelegateRoot.isLocked ? "🔒" : "🔓"
                          color: layerDelegateRoot.isLocked ? "#F59E0B" : Util.alpha(Color.popups.text || Color.text, 0.35)
                          font.pixelSize: Style.space(8)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: lockRowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleLayerLock(layerDelegateRoot.actionIndex)
                        }
                        PanelToolTip { visible: lockRowMouse.containsMouse; text: layerDelegateRoot.isLocked ? "Unlock layer" : "Lock layer" }
                      }

                      // Delete row button (visible when hovered or selected)
                      Rectangle {
                        width: Style.space(16); height: Style.space(16); radius: Style.space(2)
                        visible: (rowMouse.containsMouse || layerDelegateRoot.isSelected) && !layerDelegateRoot.isLocked
                        color: delRowMouse.containsMouse ? Util.alpha(Color.urgent, 0.2) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          text: "🗑"
                          color: delRowMouse.containsMouse ? Color.urgent : Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.pixelSize: Style.space(8)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: delRowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.deleteLayerByIndex(layerDelegateRoot.actionIndex)
                        }
                        PanelToolTip { visible: delRowMouse.containsMouse; text: "Delete layer" }
                      }
                    }

                    // Row click handler (placed under action buttons)
                    MouseArea {
                      id: rowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      z: -1
                      onClicked: function(mouse) {
                        root.currentTool = "select"
                        var isMulti = Boolean(mouse.modifiers & Qt.ControlModifier)
                        var isRange = Boolean(mouse.modifiers & Qt.ShiftModifier)
                        root.toggleSelectAction(layerDelegateRoot.actionIndex, isMulti, isRange)
                      }
                      onDoubleClicked: function(mouse) {
                        root.currentTool = "select"
                        root.selectAction(layerDelegateRoot.actionIndex)
                        if (layerDelegateRoot.curAct && layerDelegateRoot.curAct.tool === "text") {
                          root.editSelectedText()
                        } else {
                          root.editingLayerIndex = layerDelegateRoot.actionIndex
                        }
                      }
                    }
                  }

                  // Group Children Column (Tree View when group is expanded)
                  Column {
                    width: parent.width
                    visible: layerDelegateRoot.isGroup && layerDelegateRoot.isExpanded
                    spacing: Style.space(2)

                    Repeater {
                      model: (layerDelegateRoot.curAct && layerDelegateRoot.curAct.children) ? layerDelegateRoot.curAct.children.length : 0
                      delegate: Rectangle {
                        width: layerListView.width - Style.space(4)
                        height: Style.space(22)
                        radius: Style.space(3)
                        color: childRowMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.05) : "transparent"
                        anchors.right: parent ? parent.right : undefined

                        readonly property var childAct: (layerDelegateRoot.curAct && layerDelegateRoot.curAct.children) ? layerDelegateRoot.curAct.children[index] : null
                        readonly property bool childHidden: Boolean(childAct && childAct.hidden)

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(24)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(4)

                          Text {
                            text: "└"
                            color: Util.alpha(Color.popups.text || Color.text, 0.3)
                            font.pixelSize: Style.space(8)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Rectangle {
                            width: Style.space(6)
                            height: Style.space(6)
                            radius: Style.space(3)
                            color: root.getLayerColor(childAct)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Text {
                            text: root.getLayerIcon(childAct)
                            color: Util.alpha(Color.popups.text || Color.text, 0.7)
                            font.pixelSize: Style.space(8.5)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Text {
                            text: root.getLayerTitle(childAct, index)
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            font.strikeout: childHidden
                          }

                          // Child Eye Toggle
                          Rectangle {
                            width: Style.space(16); height: Style.space(16); radius: Style.space(2)
                            color: childEyeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                              text: childHidden ? "󰈉" : "󰈈"
                              color: childHidden ? Util.alpha(Color.popups.text || Color.text, 0.35) : Util.alpha(Color.popups.text || Color.text, 0.7)
                              font.pixelSize: Style.space(8)
                              anchors.centerIn: parent
                            }

                            MouseArea {
                              id: childEyeMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: root.toggleGroupChildVisibility(layerDelegateRoot.actionIndex, index)
                            }
                            PanelToolTip { visible: childEyeMouse.containsMouse; text: childHidden ? "Show element" : "Hide element" }
                          }
                        }

                        MouseArea {
                          id: childRowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          z: -1
                          onClicked: {
                            root.selectAction(layerDelegateRoot.actionIndex)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // ----------------------------------------
          // 5. FOOTER TOOLBAR (REORDER & ACTIONS)
          // ----------------------------------------
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(62)
            color: Util.alpha(Color.popups.text || Color.text, 0.03)

            Rectangle {
              anchors.top: parent.top
              width: parent.width
              height: 1
              color: Util.alpha(Color.popups.border || Color.border, 0.4)
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(4)

              readonly property bool hasSel: root.selectedActionIndex >= 0 && root.selectedActionIndex < root.actions.length
              readonly property bool canMoveUp: hasSel && root.selectedActionIndex < root.actions.length - 1
              readonly property bool canMoveDown: hasSel && root.selectedActionIndex > 0
              readonly property bool isCurGroup: hasSel && root.actions[root.selectedActionIndex] && root.actions[root.selectedActionIndex].tool === "group"
              readonly property bool canGroup: root.selectedActionIndices && root.selectedActionIndices.length > 1

              // Row 1: Reorder buttons
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(3)

                // Bring to Front
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  color: parent.parent.canMoveUp ? (lpFrontMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  opacity: parent.parent.canMoveUp ? 1.0 : 0.35
                  border.width: 1
                  border.color: parent.parent.canMoveUp ? Util.alpha(Color.accent, 0.3) : "transparent"

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    Text { text: "󰞁"; font.pixelSize: Style.space(9); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Front"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpFrontMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: parent.parent.parent.canMoveUp ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                      if (parent.parent.parent.canMoveUp) root.bringLayerToFront(root.selectedActionIndex)
                    }
                  }
                  PanelToolTip { visible: lpFrontMouse.containsMouse; text: "Bring to Front (])" }
                }

                // Move Up
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  color: parent.parent.canMoveUp ? (lpUpMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  opacity: parent.parent.canMoveUp ? 1.0 : 0.35
                  border.width: 1
                  border.color: parent.parent.canMoveUp ? Util.alpha(Color.accent, 0.3) : "transparent"

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    Text { text: "▲"; font.pixelSize: Style.space(8); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Up"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpUpMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: parent.parent.parent.canMoveUp ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                      if (parent.parent.parent.canMoveUp) root.moveLayerStep(root.selectedActionIndex, 1)
                    }
                  }
                  PanelToolTip { visible: lpUpMouse.containsMouse; text: "Move Layer Up" }
                }

                // Move Down
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  color: parent.parent.canMoveDown ? (lpDownMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  opacity: parent.parent.canMoveDown ? 1.0 : 0.35
                  border.width: 1
                  border.color: parent.parent.canMoveDown ? Util.alpha(Color.accent, 0.3) : "transparent"

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    Text { text: "▼"; font.pixelSize: Style.space(8); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Down"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpDownMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: parent.parent.parent.canMoveDown ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                      if (parent.parent.parent.canMoveDown) root.moveLayerStep(root.selectedActionIndex, -1)
                    }
                  }
                  PanelToolTip { visible: lpDownMouse.containsMouse; text: "Move Layer Down" }
                }

                // Send to Back
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  color: parent.parent.canMoveDown ? (lpBackMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.popups.text || Color.text, 0.08)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  opacity: parent.parent.canMoveDown ? 1.0 : 0.35
                  border.width: 1
                  border.color: parent.parent.canMoveDown ? Util.alpha(Color.accent, 0.3) : "transparent"

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    Text { text: "󰞂"; font.pixelSize: Style.space(9); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Back"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpBackMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: parent.parent.parent.canMoveDown ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                      if (parent.parent.parent.canMoveDown) root.sendLayerToBack(root.selectedActionIndex)
                    }
                  }
                  PanelToolTip { visible: lpBackMouse.containsMouse; text: "Send to Back ([)" }
                }
              }

              // Row 2: Action buttons (Group/Ungroup, Duplicate, Delete)
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(3)

                // Group / Ungroup Button
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  visible: parent.parent.canGroup || parent.parent.isCurGroup
                  color: (parent.parent.canGroup || parent.parent.isCurGroup) ? (lpGrpBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.14)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  border.width: 1
                  border.color: Util.alpha(Color.accent, 0.4)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: parent.parent.parent.isCurGroup ? "󰘚" : "󰉋"; font.pixelSize: Style.space(8.5); color: Color.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: parent.parent.parent.isCurGroup ? "Ungroup" : "Group"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.accent; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpGrpBtnMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (parent.parent.parent.isCurGroup) {
                        root.ungroupSelectedAction()
                      } else if (parent.parent.parent.canGroup) {
                        root.groupSelectedActions()
                      }
                    }
                  }
                  PanelToolTip { visible: lpGrpBtnMouse.containsMouse; text: parent.parent.isCurGroup ? "Ungroup selected (Ctrl+Shift+G)" : "Group selected (Ctrl+G)" }
                }

                // Duplicate Button
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  color: parent.parent.hasSel ? (lpDupMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.07)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  opacity: parent.parent.hasSel ? 1.0 : 0.35
                  border.width: 1
                  border.color: parent.parent.hasSel ? Util.alpha(Color.popups.text || Color.text, 0.15) : "transparent"

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: "⧉"; font.pixelSize: Style.space(8.5); color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Duplicate"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.popups.text || Color.text; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpDupMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: parent.parent.parent.hasSel ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                      if (parent.parent.parent.hasSel) root.duplicateSelectedAction()
                    }
                  }
                  PanelToolTip { visible: lpDupMouse.containsMouse; text: "Duplicate Selected (Ctrl+D)" }
                }

                // Delete Button
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(22); radius: Style.space(3)
                  color: parent.parent.hasSel ? (lpDelBtnMouse.containsMouse ? Util.alpha(Color.urgent, 0.22) : Util.alpha(Color.urgent, 0.1)) : Util.alpha(Color.popups.text || Color.text, 0.02)
                  opacity: parent.parent.hasSel ? 1.0 : 0.35
                  border.width: 1
                  border.color: parent.parent.hasSel ? Util.alpha(Color.urgent, 0.3) : "transparent"

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: "🗑"; font.pixelSize: Style.space(8); color: Color.urgent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Delete"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; color: Color.urgent; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: lpDelBtnMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: parent.parent.parent.hasSel ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                      if (parent.parent.parent.hasSel) root.deleteSelectedAction()
                    }
                  }
                  PanelToolTip { visible: lpDelBtnMouse.containsMouse; text: "Delete Selected (Del)" }
                }
              }
            }
          }
        }
      }
