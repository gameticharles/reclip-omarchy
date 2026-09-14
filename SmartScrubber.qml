import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: scrubRoot
              property string label: ""
              property real value: 0
              property real from: 0
              property real to: 100
              property real step: 1
              property string unit: ""
              property real sensitivity: 0.5
              property string tip: ""
              property bool integerOnly: true
              signal valueScrubbed(real val)
              signal valueCommitted(real val)

              property real dragStartX: 0
              property real dragStartVal: 0
              property bool isScrubbing: false
              property bool editMode: false

              height: Style.space(18)
              width: scrubRow.implicitWidth + Style.space(4)
              radius: Style.space(3)
              color: Util.alpha(Color.popups.text || Color.text, 0.06)
              border.width: 1
              border.color: isScrubbing ? Color.accent : (scrubMidMouse.containsMouse ? Util.alpha(Color.accent, 0.4) : Util.alpha(Color.popups.text || Color.text, 0.12))

              Row {
                id: scrubRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                // Step Down [-]
                Rectangle {
                  width: Style.space(14); height: Style.space(18); radius: Style.space(3)
                  color: decM.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                  Text { text: "−"; font.pixelSize: Style.space(7.5); font.bold: true; color: Color.popups.text || Color.text; anchors.centerIn: parent }
                  MouseArea {
                    id: decM
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var nVal = Math.max(scrubRoot.from, scrubRoot.value - scrubRoot.step)
                      if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                      scrubRoot.value = nVal
                      scrubRoot.valueScrubbed(nVal)
                      scrubRoot.valueCommitted(nVal)
                    }
                  }
                }

                // Middle Badge (Drag to scrub, double click to type)
                Rectangle {
                  id: midBadge
                  height: Style.space(18)
                  width: Math.max(Style.space(36), valLabel.implicitWidth + Style.space(8))
                  color: scrubRoot.isScrubbing ? Util.alpha(Color.accent, 0.18) : (scrubMidMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")

                  Text {
                    id: valLabel
                    visible: !scrubRoot.editMode
                    anchors.centerIn: parent
                    text: (scrubRoot.label ? (scrubRoot.label + ": ") : "") + (scrubRoot.integerOnly ? Math.round(scrubRoot.value) : scrubRoot.value.toFixed(1)) + scrubRoot.unit
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(6.8)
                    font.bold: true
                    color: scrubRoot.isScrubbing ? Color.accent : (Color.popups.text || Color.text)
                  }

                  TextInput {
                    id: inlineInput
                    visible: scrubRoot.editMode
                    anchors.fill: parent
                    anchors.margins: 1
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(6.8)
                    font.bold: true
                    color: Color.accent
                    selectByMouse: true
                    onAccepted: {
                      var num = parseFloat(text)
                      if (!isNaN(num)) {
                        var clamped = Math.max(scrubRoot.from, Math.min(scrubRoot.to, num))
                        if (scrubRoot.integerOnly) clamped = Math.round(clamped)
                        scrubRoot.value = clamped
                        scrubRoot.valueScrubbed(clamped)
                        scrubRoot.valueCommitted(clamped)
                      }
                      scrubRoot.editMode = false
                    }
                    onActiveFocusChanged: {
                      if (!activeFocus && scrubRoot.editMode) {
                        scrubRoot.editMode = false
                      }
                    }
                  }

                  MouseArea {
                    id: scrubMidMouse
                    anchors.fill: parent
                    enabled: !scrubRoot.editMode
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor

                    onPressed: function(mouse) {
                      scrubRoot.dragStartX = mouse.x
                      scrubRoot.dragStartVal = scrubRoot.value
                      scrubRoot.isScrubbing = true
                    }
                    onPositionChanged: function(mouse) {
                      if (pressed) {
                        var dx = mouse.x - scrubRoot.dragStartX
                        var delta = dx * scrubRoot.step * scrubRoot.sensitivity * 0.25
                        var nVal = Math.max(scrubRoot.from, Math.min(scrubRoot.to, scrubRoot.dragStartVal + delta))
                        if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                        scrubRoot.value = nVal
                        scrubRoot.valueScrubbed(nVal)
                      }
                    }
                    onReleased: function() {
                      if (scrubRoot.isScrubbing) {
                        scrubRoot.isScrubbing = false
                        scrubRoot.valueCommitted(scrubRoot.value)
                      }
                    }
                    onDoubleClicked: {
                      scrubRoot.editMode = true
                      inlineInput.text = String(scrubRoot.integerOnly ? Math.round(scrubRoot.value) : scrubRoot.value.toFixed(1))
                      inlineInput.forceActiveFocus()
                      inlineInput.selectAll()
                    }
                  }
                }

                // Step Up [+]
                Rectangle {
                  width: Style.space(14); height: Style.space(18); radius: Style.space(3)
                  color: incM.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
                  Text { text: "+"; font.pixelSize: Style.space(7.5); font.bold: true; color: Color.popups.text || Color.text; anchors.centerIn: parent }
                  MouseArea {
                    id: incM
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var nVal = Math.max(scrubRoot.from, Math.min(scrubRoot.to, scrubRoot.value + scrubRoot.step))
                      if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                      scrubRoot.value = nVal
                      scrubRoot.valueScrubbed(nVal)
                      scrubRoot.valueCommitted(nVal)
                    }
                  }
                }
              }

              PanelToolTip {
                visible: (scrubMidMouse.containsMouse || isScrubbing) && !scrubRoot.editMode
                text: scrubRoot.tip ? scrubRoot.tip : (scrubRoot.label + ": drag horizontally to adjust, double-click to type")
              }
            }
