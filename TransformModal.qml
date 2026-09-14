import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "lib/TextTransformers.js" as TextTransformers

Rectangle {
  id: root
  visible: false
  anchors.fill: parent
  color: Util.alpha(Color.popups.background || Color.background || "#1e1e2e", 0.98)
  radius: Style.cornerRadius
  z: 120
  clip: true

  // Signals
  signal closed()
  signal applied(string newText, int clipIndex)
  signal copied(string text)
  signal pasteRequested(string text)

  // Properties
  property string sourceText: ""
  property int targetClipIndex: -1
  property string selectedTransformerId: "titlecase"
  property string activeCategory: "all"
  property string filterQuery: ""
  property string transformedPreview: ""
  property string feedbackMsg: ""
  property bool transformerListOpen: false

  onTransformerListOpenChanged: {
    if (root.transformerListOpen && typeof searchField !== "undefined" && searchField) {
      Qt.callLater(function() { searchField.forceActiveFocus() })
    }
  }

  // Open modal method (polymorphic argument order)
  function open(arg1, arg2) {
    if (typeof arg1 === "number") {
      root.targetClipIndex = arg1
      root.sourceText = String(arg2 || "")
    } else {
      root.sourceText = String(arg1 || "")
      root.targetClipIndex = (arg2 !== undefined && typeof arg2 === "number") ? arg2 : -1
    }
    if (typeof origTxt !== "undefined" && origTxt) {
      origTxt.text = root.sourceText
    }
    root.selectedTransformerId = "titlecase"
    root.activeCategory = "all"
    root.filterQuery = ""
    root.feedbackMsg = ""
    root.transformerListOpen = false
    root.updatePreview()
    root.visible = true
  }

  function close() {
    root.visible = false
    root.transformerListOpen = false
    root.closed()
  }

  function updatePreview() {
    root.transformedPreview = TextTransformers.transform(root.sourceText, root.selectedTransformerId)
  }

  function showFeedback(msg) {
    root.feedbackMsg = msg
    feedbackTimer.restart()
  }

  Timer {
    id: feedbackTimer
    interval: 3000
    repeat: false
    onTriggered: root.feedbackMsg = ""
  }

  onSelectedTransformerIdChanged: updatePreview()
  onSourceTextChanged: {
    if (typeof origTxt !== "undefined" && origTxt && origTxt.text !== root.sourceText) {
      origTxt.text = root.sourceText
    }
    updatePreview()
  }

  // Mouse shield & Escape
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    onClicked: function(mouse) { mouse.accepted = true }
    onPressed: function(mouse) { mouse.accepted = true }
    onReleased: function(mouse) { mouse.accepted = true }
    onWheel: function(wheel) { wheel.accepted = true }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: {
      if (root.transformerListOpen) {
        root.transformerListOpen = false
      } else {
        root.close()
      }
    }
    Keys.onPressed: function(event) {
      if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_T || event.key === Qt.Key_L)) {
        root.transformerListOpen = !root.transformerListOpen
        event.accepted = true
      } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
        root.copied(root.transformedPreview)
        root.showFeedback("✓ Transformed result copied!")
        event.accepted = true
      }
    }
  }

  // Full-View Column Layout (0 outer margins, matching Text & Image Editors)
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ==========================================
    // 1. TOP HEADER BAR (Edge-to-Edge)
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(40)
      Layout.fillHeight: false
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        // Left Side: Icon & Title
        RowLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(26); height: Style.space(26); radius: Style.space(6)
            color: Util.alpha(Color.accent, 0.15)
            border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
            Text {
              text: "⚡"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              anchors.centerIn: parent
            }
          }

          Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Text {
              text: "Quick Text Transformers"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }
            Text {
              text: "Instant case conversion, developer encoding & formatting"
              color: Util.alpha(Color.popups.text || Color.text, 0.55)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Close Button
        Rectangle {
          width: Style.space(26); height: Style.space(26); radius: Style.space(5)
          color: closeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
          border.width: 1
          border.color: closeMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
          Text {
            text: "✕"
            color: closeMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            id: closeMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }
    }

    // ==========================================
    // 2. BODY WORKSPACE (Full Width Content View + Togglable Transformer Overlay)
    // ==========================================
    Item {
      id: workspaceArea
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      // -------------------------------------------------------------
      // 2A. MAIN CONTENT VIEW (50/50 Split Panes Docked Edge-to-Edge)
      // -------------------------------------------------------------
      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =============================================================
        // Top Pane: Original Input (50% Height)
        // =============================================================
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: 1
          radius: 0
          color: "transparent"

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Subheader Bar: Original Input (Edge-to-edge dock)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(26)
              Layout.fillHeight: false
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.03)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.25)
              clip: true

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(6)

                Text {
                  text: "Original Input"
                  color: Util.alpha(Color.popups.text || Color.text, 0.7)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: root.sourceText.length + " chars · " + root.sourceText.split("\n").length + " lines"
                  color: Util.alpha(Color.popups.text || Color.text, 0.4)
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                }
              }
            }

            // Text Content Box: Original (Edge-to-edge dock, 10px content margin)
            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 0
              color: Util.alpha("#000000", 0.15)
              clip: true

              ScrollView {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                anchors.topMargin: Style.space(6)
                anchors.bottomMargin: Style.space(6)
                clip: true

                TextEdit {
                  id: origTxt
                  text: root.sourceText
                  color: Util.alpha(Color.popups.text || Color.text, 0.8)
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(8.5)
                  wrapMode: Text.WrapAnywhere
                  selectByMouse: true
                  readOnly: false
                  onTextChanged: {
                    if (root.sourceText !== text) {
                      root.sourceText = text
                    }
                  }
                }
              }
            }
          }
        }

        // Hairline Divider between Panes
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          Layout.fillHeight: false
          color: Util.alpha(Color.popups.border || Color.border, 0.3)
        }

        // =============================================================
        // Bottom Pane: Transformed Result (50% Height)
        // =============================================================
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: 1
          radius: 0
          color: "transparent"

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Subheader Bar: Transformed Result (Edge-to-edge dock)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(26)
              Layout.fillHeight: false
              radius: 0
              color: Util.alpha(Color.accent, 0.06)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.25)
              clip: true

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(6)

                Text {
                  text: "✨ Transformed Result (" + root.selectedTransformerId + ")"
                  color: Color.accent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: root.transformedPreview.length + " chars · " + root.transformedPreview.split("\n").length + " lines"
                  color: Util.alpha(Color.popups.text || Color.text, 0.4)
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                }
              }
            }

            // Text Content Box: Transformed (Edge-to-edge dock, 10px content margin)
            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 0
              color: Util.alpha("#000000", 0.2)
              clip: true

              ScrollView {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                anchors.topMargin: Style.space(6)
                anchors.bottomMargin: Style.space(6)
                clip: true

                TextEdit {
                  id: transTxt
                  readOnly: true
                  selectByMouse: true
                  text: root.transformedPreview
                  color: Color.popups.text || Color.text
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(8.5)
                  wrapMode: Text.WrapAnywhere
                }
              }
            }
          }
        }
      }

      // -------------------------------------------------------------
      // 2B. TRANSFORMER LIST OVERLAY PANEL (Togglable Floating Drawer)
      // Modeled after ImageEditorModal layerPanelRoot
      // -------------------------------------------------------------
      Rectangle {
        id: transformerPanelRoot
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Style.space(310)
        radius: 0
        color: Util.alpha(Color.popups.background || Color.background, 0.98)
        border.width: 1
        border.color: Util.alpha(Color.popups.border || Color.border, 0.55)
        visible: root.transformerListOpen
        z: 45
        clip: true

        // Absorb clicks so they don't bleed into underlying preview
        MouseArea {
          anchors.fill: parent
          onClicked: function(mouse) { mouse.accepted = true }
          onPressed: function(mouse) { mouse.accepted = true }
          onReleased: function(mouse) { mouse.accepted = true }
          onWheel: function(wheel) { wheel.accepted = true }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // Panel Header
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(34)
            Layout.fillHeight: false
            color: Util.alpha(Color.popups.text || Color.text, 0.04)

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: Util.alpha(Color.popups.border || Color.border, 0.3)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: "⚡"
                color: Color.accent
                font.pixelSize: Style.space(11)
                Layout.alignment: Qt.AlignVCenter
              }

              Text {
                text: "Transformers"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8.5)
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
              }

              // Count Pill
              Rectangle {
                height: Style.space(16)
                width: tfCountTxt.implicitWidth + Style.space(8)
                radius: Style.space(8)
                color: Util.alpha(Color.accent, 0.16)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.3)
                Layout.alignment: Qt.AlignVCenter

                Text {
                  id: tfCountTxt
                  anchors.centerIn: parent
                  text: transformerListView.count + " items"
                  color: Color.accent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7)
                  font.bold: true
                }
              }

              Item { Layout.fillWidth: true }

              // Close Panel Button
              Rectangle {
                width: Style.space(20); height: Style.space(20); radius: Style.space(3)
                color: closeTfMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Text {
                  text: "✕"
                  color: closeTfMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.6)
                  font.pixelSize: Style.space(8.5)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: closeTfMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.transformerListOpen = false
                }
                PanelToolTip { visible: closeTfMouse.containsMouse; text: "Close Panel (Ctrl+T)" }
              }
            }
          }

          // Category Filter Tabs
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(28)
            Layout.fillHeight: false
            color: Util.alpha(Color.popups.text || Color.text, 0.02)

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: Util.alpha(Color.popups.border || Color.border, 0.15)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              anchors.topMargin: Style.space(3)
              anchors.bottomMargin: Style.space(3)
              spacing: Style.space(3)

              Repeater {
                model: [
                  { id: "all", label: "All" },
                  { id: "case", label: "Case" },
                  { id: "dev", label: "Dev" },
                  { id: "format", label: "Format" }
                ]

                Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: Style.space(3)
                  color: root.activeCategory === modelData.id ? Color.accent : (catMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")

                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: root.activeCategory === parent.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(7.5)
                    font.bold: root.activeCategory === parent.modelData.id
                  }

                  MouseArea {
                    id: catMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeCategory = parent.modelData.id
                  }
                }
              }
            }
          }

          // Search Field
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(34)
            Layout.fillHeight: false
            color: "transparent"

            Rectangle {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              anchors.topMargin: Style.space(4)
              anchors.bottomMargin: Style.space(4)
              radius: Style.space(4)
              color: Util.alpha(Color.popups.text || Color.text, 0.04)
              border.width: 1
              border.color: searchField.activeFocus ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(4)

                Text {
                  text: "🔍"
                  color: Util.alpha(Color.popups.text || Color.text, 0.4)
                  font.pixelSize: Style.space(8)
                }

                TextField {
                  id: searchField
                  Layout.fillWidth: true
                  placeholderText: "Search transformers..."
                  placeholderTextColor: Util.alpha(Color.popups.text || Color.text, 0.35)
                  color: Color.popups.text || Color.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  background: null
                  padding: 0
                  text: root.filterQuery
                  onTextChanged: root.filterQuery = text
                }

                Text {
                  visible: root.filterQuery.length > 0
                  text: "✕"
                  color: Util.alpha(Color.popups.text || Color.text, 0.4)
                  font.pixelSize: Style.space(7)
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.filterQuery = ""; searchField.text = "" }
                  }
                }
              }
            }
          }

          // List of Transformers
          ScrollView {
            id: tfScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
              id: transformerListView
              width: tfScroll.availableWidth
              boundsBehavior: Flickable.StopAtBounds
              spacing: Style.space(3)
              model: {
                var list = (TextTransformers.TRANSFORMERS || TextTransformers.registry || [])
                var q = root.filterQuery.toLowerCase().trim()
                var cat = root.activeCategory.toLowerCase()
                return list.filter(function(item) {
                  var itemCat = String(item.category || "").toLowerCase()
                  var matchesCat = (cat === "all" || itemCat.indexOf(cat) >= 0)
                  var matchesQuery = (!q || item.name.toLowerCase().indexOf(q) >= 0 || item.desc.toLowerCase().indexOf(q) >= 0 || item.id.toLowerCase().indexOf(q) >= 0)
                  return matchesCat && matchesQuery
                })
              }

              delegate: Rectangle {
                id: delegateRoot
                required property var modelData
                required property int index
                readonly property bool isSelected: root.selectedTransformerId === modelData.id
                width: transformerListView.width
                height: Style.space(36)
                radius: Style.space(5)
                color: isSelected ? Color.accent : (itemMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.02))
                border.width: 1
                border.color: isSelected ? Color.accent : (itemMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : "transparent")

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(6)

                  Text {
                    text: delegateRoot.modelData.icon || "⚡"
                    color: delegateRoot.isSelected ? "#ffffff" : Color.accent
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(10)
                    Layout.alignment: Qt.AlignVCenter
                  }

                  Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                      text: delegateRoot.modelData.name || ""
                      color: delegateRoot.isSelected ? "#ffffff" : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8.5)
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: delegateRoot.modelData.desc || ""
                      color: delegateRoot.isSelected ? Util.alpha("#ffffff", 0.75) : Util.alpha(Color.popups.text || Color.text, 0.5)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7)
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedTransformerId = delegateRoot.modelData.id
                    root.showFeedback("⚡ Applied: " + delegateRoot.modelData.name)
                  }
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // 3. TWO-TIER BOTTOM STATUS & ACTION BAR
    // ==========================================
    Rectangle {
      id: footerContainer
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(59)
      Layout.fillHeight: false
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
          Layout.fillHeight: false
          Layout.leftMargin: Style.space(10)
          Layout.rightMargin: Style.space(10)
          spacing: Style.space(8)

          // Left: Current Transformer Badge Pill (Clickable to toggle panel)
          Rectangle {
            height: Style.space(22)
            width: tfBadgeRow.implicitWidth + Style.space(14)
            radius: Style.space(3)
            color: root.transformerListOpen ? Color.accent : (tfBadgeMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.15))
            border.width: 1; border.color: Util.alpha(Color.accent, 0.35)

            Row {
              id: tfBadgeRow
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text {
                text: "⚡"
                font.pixelSize: Style.space(8)
                color: root.transformerListOpen ? "#ffffff" : Color.accent
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.selectedTransformerId
                color: root.transformerListOpen ? "#ffffff" : Color.accent
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.transformerListOpen ? "▴" : "▾"
                color: root.transformerListOpen ? "#ffffff" : Color.accent
                font.pixelSize: Style.space(7)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: tfBadgeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.transformerListOpen = !root.transformerListOpen
            }
            PanelToolTip { visible: tfBadgeMouse.containsMouse; text: "Toggle Transformer Panel (Ctrl+T)" }
          }

          // Center: Feedback Toast Pill
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
              visible: root.feedbackMsg.length > 0
              anchors.centerIn: parent
              height: Style.space(22)
              width: Math.min(parent.width - Style.space(10), fbRow.implicitWidth + Style.space(16))
              radius: Style.space(3)
              color: Util.alpha(Color.accent, 0.2)
              border.width: 1; border.color: Color.accent

              Row {
                id: fbRow
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "✓"; color: Color.accent; font.pixelSize: Style.space(8.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text {
                  text: root.feedbackMsg
                  color: Color.accent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  elide: Text.ElideRight
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }

          // Right: Action Buttons (Cancel, Apply to Clip, Paste Now, Copy Result)
          Row {
            spacing: Style.space(6)
            Layout.alignment: Qt.AlignVCenter

            // Cancel
            Rectangle {
              width: Style.space(58); height: Style.space(24); radius: Style.space(4)
              color: cancelTMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)
              Text {
                text: "Cancel"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
                anchors.centerIn: parent
              }
              MouseArea {
                id: cancelTMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
              }
            }

            // Apply to Clip (if targetClipIndex >= 0)
            Rectangle {
              visible: root.targetClipIndex >= 0
              width: applyTxt.implicitWidth + Style.space(14)
              height: Style.space(24); radius: Style.space(4)
              color: applyMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
              border.width: 1; border.color: Color.accent
              Row {
                id: applyTxt
                anchors.centerIn: parent; spacing: Style.space(3)
                Text { text: "✓"; color: Color.accent; font.pixelSize: Style.space(8); font.bold: true }
                Text { text: "Apply to Clip"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true }
              }
              MouseArea {
                id: applyMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.applied(root.transformedPreview, root.targetClipIndex)
                  root.close()
                }
              }
            }

            // Paste Now
            Rectangle {
              width: pasteTxt.implicitWidth + Style.space(14)
              height: Style.space(24); radius: Style.space(4)
              color: pasteMouse.containsMouse ? Util.alpha("#3B82F6", 0.3) : Util.alpha("#3B82F6", 0.15)
              border.width: 1; border.color: "#3B82F6"
              Row {
                id: pasteTxt
                anchors.centerIn: parent; spacing: Style.space(3)
                Text { text: "󰆒"; color: "#60A5FA"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8) }
                Text { text: "Paste Now"; color: "#60A5FA"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true }
              }
              MouseArea {
                id: pasteMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.pasteRequested(root.transformedPreview)
                  root.close()
                }
              }
            }

            // Copy Result Button (Primary Action)
            Rectangle {
              width: copyRTxt.implicitWidth + Style.space(16)
              height: Style.space(24); radius: Style.space(4)
              color: copyRMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent
              Row {
                id: copyRTxt
                anchors.centerIn: parent; spacing: Style.space(4)
                Text { text: "📋"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Copy Result"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: copyRMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.copied(root.transformedPreview)
                  root.showFeedback("✓ Transformed result copied!")
                }
              }
            }
          }
        }

        // -------------------------------------------------------------
        // Hairline Divider
        // -------------------------------------------------------------
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          Layout.fillHeight: false
          color: Util.alpha(Color.popups.border || Color.border, 0.3)
        }

        // -------------------------------------------------------------
        // Row 2: Status & Document Statistics Strip (Height: 24px)
        // -------------------------------------------------------------
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(24)
          Layout.fillHeight: false
          color: Util.alpha("#000000", 0.18)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            Row {
              spacing: Style.space(8)
              Layout.alignment: Qt.AlignVCenter

              Text {
                text: "📄 " + root.sourceText.length + " chars"
                color: Util.alpha(Color.popups.text || Color.text, 0.65)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
              }

              Text {
                text: "•  " + root.activeCategory
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
              }
            }

            Item { Layout.fillWidth: true }

            // RIGHT: Universal Keyboard Shortcut Chips (Matching Home Page Style)
            Row {
              Layout.alignment: Qt.AlignVCenter
              spacing: Style.space(6)

              // Ctrl+T Toggle Transformers Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlTTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlTTxt
                    text: "Ctrl+T"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Transformers"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Ctrl+Enter Copy Result Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlEnterTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlEnterTxt
                    text: "Ctrl+↵"
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
                  width: Math.max(Style.space(16), escTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: escTxt
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
  }
}
