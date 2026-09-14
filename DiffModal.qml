import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "lib/ClipboardHistory.js" as ClipboardHistory

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
  signal restored(int clipIndex, int revIndex)
  signal copied(string text)
  signal revisionDeleted(int clipIndex, int revIndex)

  // Properties
  property int clipIndex: -1
  property string currentText: ""
  property var revisions: []
  property int selectedRevIndex: 0
  property var diffLines: []
  property int addedCount: 0
  property int deletedCount: 0
  property string feedbackMsg: ""

  function open(index, current, revList) {
    root.clipIndex = (index !== undefined) ? index : -1
    root.currentText = String(current || "")
    root.revisions = Array.isArray(revList) ? revList : []
    root.selectedRevIndex = 0
    root.updateDiff()
    root.visible = true
  }

  function close() {
    root.visible = false
    root.closed()
  }

  function showFeedback(msg) {
    root.feedbackMsg = msg
    feedbackTimer.restart()
  }

  Timer {
    id: feedbackTimer
    interval: 2500
    repeat: false
    onTriggered: root.feedbackMsg = ""
  }

  function updateDiff() {
    if (!root.revisions || root.revisions.length === 0 || root.selectedRevIndex < 0 || root.selectedRevIndex >= root.revisions.length) {
      root.diffLines = []
      root.addedCount = 0
      root.deletedCount = 0
      return
    }

    var rev = root.revisions[root.selectedRevIndex]
    var revText = rev ? String(rev.text || "") : ""
    var lines = ClipboardHistory.computeLineDiff(revText, root.currentText)
    root.diffLines = lines

    var adds = 0
    var dels = 0
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].type === "add") adds++
      else if (lines[i].type === "delete") dels++
    }
    root.addedCount = adds
    root.deletedCount = dels
  }

  onSelectedRevIndexChanged: updateDiff()
  onCurrentTextChanged: updateDiff()
  onRevisionsChanged: updateDiff()

  // Shield background clicks & Esc key
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
    Keys.onEscapePressed: root.close()
    Keys.onPressed: function(event) {
      if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R)) {
        if (root.revisions.length > 0) {
          root.restored(root.clipIndex, root.selectedRevIndex)
          root.close()
          event.accepted = true
        }
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
        if (root.revisions.length > 0 && root.selectedRevIndex >= 0 && root.selectedRevIndex < root.revisions.length) {
          var rev = root.revisions[root.selectedRevIndex]
          var rText = (rev && typeof rev === "object") ? (rev.text || "") : String(rev || "")
          root.copied(rText)
          root.showFeedback("✓ Revision copied!")
          event.accepted = true
        }
      } else if (event.key === Qt.Key_Left) {
        if (root.selectedRevIndex > 0) {
          root.selectedRevIndex--
          event.accepted = true
        }
      } else if (event.key === Qt.Key_Right) {
        if (root.selectedRevIndex < root.revisions.length - 1) {
          root.selectedRevIndex++
          event.accepted = true
        }
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
      color: Util.alpha(Color.popups.text || Color.text, 0.04)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.2)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(8)

        // Title icon + text
        Row {
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(26); height: Style.space(26); radius: Style.space(6)
            color: Util.alpha(Color.accent, 0.15)
            border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
            Text {
              text: "󰦪"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              anchors.centerIn: parent
            }
          }

          Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Text {
              text: "Revision History & Diff Viewer"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              text: root.revisions.length > 0 ? ("Comparing current clip with revision " + (root.selectedRevIndex + 1) + " of " + root.revisions.length) : "No revisions recorded"
              color: Util.alpha(Color.popups.text || Color.text, 0.55)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
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
    // 2. BODY CONTENT (Docked Edge-to-Edge)
    // ==========================================
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Revision pills horizontally scrollable + diff stats (Docked edge-to-edge)
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(36)
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
            spacing: Style.space(8)

            // Revision pills horizontally scrollable
            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              ScrollBar.vertical.policy: ScrollBar.AlwaysOff
              ScrollBar.horizontal.policy: ScrollBar.AsNeeded

              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Repeater {
                  model: root.revisions

                  Rectangle {
                    required property int index
                    required property var modelData
                    width: Style.space(120); height: Style.space(26)
                    radius: Style.space(4)
                    color: root.selectedRevIndex === index ? Color.accent : (revMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03))
                    border.width: 1
                    border.color: root.selectedRevIndex === index ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: Style.space(4)
                      spacing: Style.space(4)

                      Text {
                        text: "Rev " + (parent.parent.index + 1)
                        color: root.selectedRevIndex === parent.parent.index ? "#ffffff" : (Color.popups.text || Color.text)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(8)
                        font.bold: root.selectedRevIndex === parent.parent.index
                      }

                      Text {
                        text: String(parent.parent.modelData.diffSummary || "")
                        color: root.selectedRevIndex === parent.parent.index ? Util.alpha("#ffffff", 0.85) : Util.alpha(Color.popups.text || Color.text, 0.5)
                        font.family: Style.font.fixedFamily || "monospace"
                        font.pixelSize: Style.space(7.5)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }
                    }

                    MouseArea {
                      id: revMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.selectedRevIndex = parent.index
                    }
                  }
                }
              }
            }

            // Diff summary stats pills
            Row {
              spacing: Style.space(4)
              Layout.alignment: Qt.AlignVCenter

              Rectangle {
                height: Style.space(22); width: Style.space(56); radius: Style.space(4)
                color: Util.alpha("#22C55E", 0.15)
                border.width: 1; border.color: Util.alpha("#22C55E", 0.3)
                Text {
                  anchors.centerIn: parent
                  text: "+" + root.addedCount + " add"
                  color: "#22C55E"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                }
              }

              Rectangle {
                height: Style.space(22); width: Style.space(56); radius: Style.space(4)
                color: Util.alpha("#EF4444", 0.15)
                border.width: 1; border.color: Util.alpha("#EF4444", 0.3)
                Text {
                  anchors.centerIn: parent
                  text: "-" + root.deletedCount + " del"
                  color: "#EF4444"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                }
              }
            }
          }
        }

        // Diff Line-by-Line Viewer (Docked edge-to-edge)
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 0
          color: "transparent"
          border.width: 1
          border.color: Util.alpha(Color.popups.border || Color.border, 0.25)
          clip: true

          ListView {
            id: diffList
            anchors.fill: parent
            clip: true
            model: root.diffLines
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property var modelData
              required property int index
              width: diffList.width
              height: Math.max(Style.space(20), diffText.contentHeight + Style.space(4))
              color: modelData.type === "add" ? Util.alpha("#22C55E", 0.12) : (modelData.type === "delete" ? Util.alpha("#EF4444", 0.12) : "transparent")

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(6)

                // Line type symbol (+ or -)
                Text {
                  Layout.preferredWidth: Style.space(16)
                  text: parent.parent.modelData.type === "add" ? "+" : (parent.parent.modelData.type === "delete" ? "-" : " ")
                  color: parent.parent.modelData.type === "add" ? "#22C55E" : (parent.parent.modelData.type === "delete" ? "#EF4444" : Util.alpha(Color.popups.text || Color.text, 0.3))
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                }

                // Old Line Number
                Text {
                  Layout.preferredWidth: Style.space(24)
                  horizontalAlignment: Text.AlignRight
                  text: parent.parent.modelData.lineNumOld ? String(parent.parent.modelData.lineNumOld) : ""
                  color: Util.alpha(Color.popups.text || Color.text, 0.3)
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(7.5)
                }

                // New Line Number
                Text {
                  Layout.preferredWidth: Style.space(24)
                  horizontalAlignment: Text.AlignRight
                  text: parent.parent.modelData.lineNumNew ? String(parent.parent.modelData.lineNumNew) : ""
                  color: Util.alpha(Color.popups.text || Color.text, 0.3)
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(7.5)
                }

                // Line text content
                Text {
                  id: diffText
                  Layout.fillWidth: true
                  text: parent.parent.modelData.line || ""
                  color: parent.parent.modelData.type === "add" ? "#4ADE80" : (parent.parent.modelData.type === "delete" ? "#F87171" : (Color.popups.text || Color.text))
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(8.5)
                  font.strikeout: parent.parent.modelData.type === "delete"
                  wrapMode: Text.WrapAnywhere
                }
              }
            }

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
            }
          }

          // Empty State
          Column {
            anchors.centerIn: parent
            spacing: Style.space(6)
            visible: !root.diffLines || root.diffLines.length === 0

            Text {
              text: "󰁯"
              color: Util.alpha(Color.popups.text || Color.text, 0.25)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(28)
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
              text: "No differences between current clip and selected revision"
              color: Util.alpha(Color.popups.text || Color.text, 0.45)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8.5)
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }
    }

    // ==========================================
    // 3. STANDARDIZED TWO-TIER FOOTER (Height: 58px)
    // ==========================================
    Rectangle {
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
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(34)
          Layout.fillHeight: false
          color: "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            // Left: Restore, Copy, Delete Revision Buttons
            Row {
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignVCenter

              // Restore Version (Primary Button)
              Rectangle {
                width: restoreTxt.implicitWidth + Style.space(16)
                height: Style.space(24)
                radius: Style.space(4)
                color: restoreMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                Row {
                  id: restoreTxt
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    text: "󰁯"
                    color: "#ffffff"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8.5)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: "Restore Version"
                    color: "#ffffff"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: restoreMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.restored(root.clipIndex, root.selectedRevIndex)
                    root.close()
                  }
                }
              }

              // Copy Revision
              Rectangle {
                width: copyTxt.implicitWidth + Style.space(16)
                height: Style.space(24)
                radius: Style.space(4)
                color: copyMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.06)
                border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

                Row {
                  id: copyTxt
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    text: "📋"
                    font.pixelSize: Style.space(7.5)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: "Copy Revision"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: copyMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.revisions && root.revisions[root.selectedRevIndex]) {
                      root.copied(String(root.revisions[root.selectedRevIndex].text || ""))
                      root.showFeedback("✓ Revision copied to clipboard")
                    }
                  }
                }
              }

              // Delete Revision
              Rectangle {
                width: delTxt.implicitWidth + Style.space(14)
                height: Style.space(24)
                radius: Style.space(4)
                color: delMouse.containsMouse ? Util.alpha("#EF4444", 0.18) : "transparent"
                border.width: 1
                border.color: delMouse.containsMouse ? "#EF4444" : Util.alpha(Color.popups.text || Color.text, 0.15)

                Row {
                  id: delTxt
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    text: "🗑"
                    font.pixelSize: Style.space(7.5)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: "Delete Revision"
                    color: delMouse.containsMouse ? "#EF4444" : Util.alpha(Color.popups.text || Color.text, 0.7)
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: delMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.revisionDeleted(root.clipIndex, root.selectedRevIndex)
                    if (root.revisions.length <= 1) {
                      root.close()
                    } else {
                      root.selectedRevIndex = Math.max(0, root.selectedRevIndex - 1)
                      root.showFeedback("🗑 Revision removed")
                    }
                  }
                }
              }
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

            // Right: Close / Done
            Row {
              spacing: Style.space(8)
              Layout.alignment: Qt.AlignVCenter

              Rectangle {
                width: Style.space(68)
                height: Style.space(24)
                radius: Style.space(4)
                color: doneMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
                border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

                Text {
                  text: "Done"
                  color: Color.popups.text || Color.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8.5)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: doneMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.close()
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
        // Row 2: Status & Revision Statistics Strip (Height: 24px)
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
                text: root.revisions.length > 0 ? ("Rev " + (root.selectedRevIndex + 1) + " of " + root.revisions.length) : "No revisions"
                color: Util.alpha(Color.popups.text || Color.text, 0.65)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
              }

              Text {
                text: "•  +" + root.addedCount + " / -" + root.deletedCount
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

              // Arrow Keys Switch Revision Chip (when > 1 rev)
              Row {
                visible: root.revisions.length > 1
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), arrowTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: arrowTxt
                    text: "←/→"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Switch"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Ctrl+Enter Restore Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), restoreKeyTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: restoreKeyTxt
                    text: "Ctrl+↵"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Restore"
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
                  width: Math.max(Style.space(16), copyKeyTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: copyKeyTxt
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
                  width: Math.max(Style.space(16), diffEscTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: diffEscTxt
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
