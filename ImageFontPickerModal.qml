import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: fontPickerOverlay
  required property var modal
  readonly property var root: modal
  property alias fontSearchInput: fontSearchInput
    visible: root.fontPickerOpen
    anchors.fill: parent
    z: 150

    // Backdrop to dismiss dropdown popup when clicking anywhere outside
    MouseArea {
      anchors.fill: parent
      onClicked: function(mouse) {
        var cardPt = mapToItem(fontPickerCard, mouse.x, mouse.y)
        if (cardPt.x >= 0 && cardPt.x <= fontPickerCard.width && cardPt.y >= 0 && cardPt.y <= fontPickerCard.height) {
          return
        }
        if (typeof fontPickerTriggerBtn !== "undefined" && fontPickerTriggerBtn) {
          var btnPt = mapToItem(fontPickerTriggerBtn, mouse.x, mouse.y)
          if (btnPt.x >= 0 && btnPt.x <= fontPickerTriggerBtn.width && btnPt.y >= 0 && btnPt.y <= fontPickerTriggerBtn.height) {
            root.fontPickerOpen = false
            return
          }
        }
        root.fontPickerOpen = false
      }
    }

    // Dropdown popover card anchored directly to fontPickerTriggerBtn
    Rectangle {
      id: fontPickerCard
      width: Style.space(250)
      height: Style.space(310)
      radius: Style.space(6)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

      // Dynamic position anchoring under fontPickerTriggerBtn in root coordinates
      x: {
        if (!root.fontPickerOpen || typeof fontPickerTriggerBtn === "undefined" || !fontPickerTriggerBtn) {
          return root.width / 2 - width / 2
        }
        var pt = fontPickerTriggerBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.fontPickerOpen || typeof fontPickerTriggerBtn === "undefined" || !fontPickerTriggerBtn) {
          return root.height / 2 - height / 2
        }
        var pt = fontPickerTriggerBtn.mapToItem(root, 0, 0)
        var btnH = fontPickerTriggerBtn.height
        if (pt.y + btnH + height + Style.space(8) <= root.height) {
          return pt.y + btnH + Style.space(4)
        } else {
          return Math.max(Style.space(8), pt.y - height - Style.space(4))
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // Header
        Item {
          width: parent.width
          height: Style.space(20)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Text {
              text: "System Fonts"
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8.5)
              font.bold: true
              color: Color.popups.text || Color.text
              anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
              height: Style.space(14)
              width: fCountTxt.implicitWidth + Style.space(6)
              radius: Style.space(3)
              color: Util.alpha(Color.accent, 0.15)
              anchors.verticalCenter: parent.verticalCenter
              Text {
                id: fCountTxt
                anchors.centerIn: parent
                text: String(fontListView.filteredFonts ? fontListView.filteredFonts.length : 0)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7)
                font.bold: true
                color: Color.accent
              }
            }
          }

          // Close button
          Rectangle {
            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: cfbMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.16) : "transparent"
            Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
            MouseArea {
              id: cfbMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.fontPickerOpen = false
            }
          }
        }

        // Search Box
        Rectangle {
          width: parent.width
          height: Style.space(24)
          radius: Style.space(4)
          color: Util.alpha(Color.popups.text || Color.text, 0.06)
          border.width: 1
          border.color: fontSearchInput.activeFocus ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: fontSearchInput.forceActiveFocus()
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(4)

            Text {
              text: "🔍"
              font.pixelSize: Style.space(7.5)
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: fontSearchInput
              width: parent.width - Style.space(34)
              anchors.verticalCenter: parent.verticalCenter
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              color: Color.popups.text || Color.text
              selectionColor: Color.accent
              selectedTextColor: "#FFFFFF"
              text: root.fontSearchQuery
              onTextChanged: root.fontSearchQuery = text

              Text {
                visible: !fontSearchInput.text && !fontSearchInput.activeFocus
                text: "Search " + root.systemFontFamilies.length + " fonts..."
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                color: Util.alpha(Color.popups.text || Color.text, 0.4)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            // Clear search button
            Rectangle {
              visible: fontSearchInput.text.length > 0
              width: Style.space(14); height: Style.space(14); radius: Style.space(7)
              color: clearSearchMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.2) : "transparent"
              anchors.verticalCenter: parent.verticalCenter
              Text { text: "✕"; font.pixelSize: Style.space(6.5); color: Color.popups.text || Color.text; anchors.centerIn: parent }
              MouseArea {
                id: clearSearchMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  fontSearchInput.text = ""
                  root.fontSearchQuery = ""
                  fontSearchInput.forceActiveFocus()
                }
              }
            }
          }
        }

        // Quick Category Filter Chips
        Row {
          spacing: Style.space(4)
          Repeater {
            model: [
              { id: "", label: "All", filter: "" },
              { id: "sans", label: "Sans", filter: "sans" },
              { id: "mono", label: "Mono", filter: "mono" },
              { id: "serif", label: "Serif", filter: "serif" }
            ]
            Rectangle {
              id: chipRect
              required property var modelData
              property bool isCurrent: {
                if (!chipRect.modelData.id) return !root.fontSearchQuery
                return (root.fontSearchQuery || "").toLowerCase() === chipRect.modelData.filter
              }
              width: chipTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
              color: isCurrent ? Color.accent : (chipMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.popups.text || Color.text, 0.06))
              border.width: 1
              border.color: isCurrent ? Color.accent : Util.alpha(Color.accent, 0.2)
              Text {
                id: chipTxt
                text: chipRect.modelData.label
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                color: chipRect.isCurrent ? "#FFFFFF" : Color.accent
                anchors.centerIn: parent
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.fontSearchQuery = chipRect.modelData.filter
                  fontSearchInput.text = chipRect.modelData.filter
                }
              }
            }
          }
        }

        // Live Font List
        ListView {
          id: fontListView
          width: parent.width
          height: fontPickerCard.height - Style.space(88)
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: Style.space(4)
          }

          readonly property var filteredFonts: {
            var q = (root.fontSearchQuery || "").trim().toLowerCase()
            var list = root.systemFontFamilies || []
            if (!q) return list
            return list.filter(function(f) {
              return f.toLowerCase().indexOf(q) !== -1
            })
          }

          model: filteredFonts

          delegate: Rectangle {
            id: fItemDelegate
            required property string modelData
            property bool isSelected: {
              if (selectionOverlay.curAct && selectionOverlay.curAct.fontFamily) {
                return selectionOverlay.curAct.fontFamily === modelData
              }
              return (root.defaultFontFamily || "sans") === modelData
            }
            width: fontListView.width
            height: Style.space(24)
            radius: Style.space(3)
            color: isSelected ? Util.alpha(Color.accent, 0.25) : (fItemMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              Text {
                text: fItemDelegate.modelData
                font.family: fItemDelegate.modelData
                font.pixelSize: Style.space(8.5)
                color: fItemDelegate.isSelected ? Color.accent : (Color.popups.text || Color.text)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: parent.width - (fItemDelegate.isSelected ? Style.space(20) : 0)
              }

              Text {
                visible: fItemDelegate.isSelected
                text: "✓"
                color: Color.accent
                font.bold: true
                font.pixelSize: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: fItemMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.setSelectedFontFamily(fItemDelegate.modelData)
                root.fontPickerOpen = false
              }
            }
          }

          // Empty State if no fonts match
          Item {
            visible: fontListView.count === 0
            width: parent.width
            height: Style.space(80)
            Text {
              anchors.centerIn: parent
              text: "No fonts matching \"" + root.fontSearchQuery + "\""
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(8)
              color: Util.alpha(Color.popups.text || Color.text, 0.5)
            }
          }
        }
      }
    }
  }
