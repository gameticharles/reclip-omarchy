import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: sec1
  required property var modal
  readonly property var root: modal
  property alias qrImage: qrImage
  clip: true
          ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: Style.space(6)
            spacing: Style.space(6)

            // 1. Unobstructed QR Code Preview Canvas
            Item {
              id: qrCanvasWrapper
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              // Centered High-Contrast QR Card (Fills maximum space allocated)
              Rectangle {
                id: qrCardBox
                anchors.centerIn: parent
                height: Math.max(Style.space(60), Math.min(parent.width - Style.space(8), parent.height - Style.space(8)))
                width: height
                radius: 0
                color: (root.frameStyle !== "none" || root.qrBgColor === "transparent" || root.qrBgColor === "#00000000") ? "transparent" : root.qrBgColor
                border.width: 0

                Image {
                  id: qrImage
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectFit
                  smooth: false
                  visible: !root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0
                }

                BusyIndicator {
                  anchors.centerIn: parent
                  running: root.isGenerating
                  visible: root.isGenerating
                }

                // Empty State Placeholder when no text is entered
                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  visible: !root.isGenerating && root.textToEncode.trim().length === 0 && root.generationError.length === 0

                  Text {
                    text: "󰄲"
                    color: "#94a3b8"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(32)
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    text: "Type below to generate"
                    color: "#64748b"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8.5)
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    text: "Instant live multi-color rendering"
                    color: "#94a3b8"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(7.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                  }
                }

                // Generation Error State Banner
                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(6)
                  width: Math.min(parent.width - Style.space(16), Style.space(260))
                  visible: !root.isGenerating && root.generationError.length > 0

                  Rectangle {
                    width: Style.space(32); height: Style.space(32); radius: 0
                    color: Util.alpha("#EF4444", 0.15)
                    border.width: 1; border.color: Util.alpha("#EF4444", 0.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                      text: "⚠"
                      color: "#EF4444"
                      font.pixelSize: Style.space(16)
                      font.bold: true
                      anchors.centerIn: parent
                    }
                  }

                  Text {
                    text: "Generation Failed"
                    color: "#EF4444"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8.5)
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    text: root.generationError
                    color: Color.popups.text || Color.text
                    font.family: Style.font.fixedFamily || "monospace"
                    font.pixelSize: Style.space(7.5)
                    wrapMode: Text.WrapAnywhere
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                  }
                }
              }
            }

            // 2. Dedicated Status, Verification & Navigation Bar (Below QR Preview)
            Rectangle {
              id: qrSubPreviewBar
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(24)
              Layout.fillHeight: false
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.035)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.25)
              visible: !root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(6)

                // Left: Contrast, Inverted, and Scannable Badges
                Row {
                  Layout.alignment: Qt.AlignVCenter
                  spacing: Style.space(4)

                  // Live Contrast Badge
                  Rectangle {
                    height: Style.space(18)
                    width: contrastBadgeRow.implicitWidth + Style.space(10)
                    radius: 0
                    color: Util.alpha(root.contrastColor, 0.15)
                    border.width: 1
                    border.color: root.contrastColor
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                      id: contrastBadgeRow
                      anchors.centerIn: parent
                      spacing: Style.space(4)
                      Text {
                        text: root.contrastRating
                        color: root.contrastColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.2)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: root.contrastRatio + ":1"
                        color: Color.popups.text || Color.text
                        font.family: "monospace"
                        font.pixelSize: Style.space(7.2)
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                    MouseArea {
                      id: contrastMouse
                      anchors.fill: parent
                      hoverEnabled: true
                    }
                    PanelToolTip {
                      visible: contrastMouse.containsMouse
                      text: "WCAG Contrast Score (" + root.contrastRating + "). 4.5:1 (AA) or 7:1 (AAA) ensures reliable camera scans."
                    }
                  }

                  // Inverted QR Code Compatibility Warning Pill
                  Rectangle {
                    visible: root.isQrInverted
                    height: Style.space(18)
                    width: invertedBadgeRow.implicitWidth + Style.space(10)
                    radius: 0
                    color: Util.alpha("#F59E0B", 0.2)
                    border.width: 1
                    border.color: "#F59E0B"
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                      id: invertedBadgeRow
                      anchors.centerIn: parent
                      spacing: Style.space(3)
                      Text {
                        text: "⚠"
                        color: "#F59E0B"
                        font.pixelSize: Style.space(7.2)
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: "Inverted"
                        color: "#F59E0B"
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                    MouseArea {
                      id: invertedMouse
                      anchors.fill: parent
                      hoverEnabled: true
                    }
                    PanelToolTip {
                      visible: invertedMouse.containsMouse
                      text: "Warning: Inverted QR Code (Light modules on dark background). Hardware barcode scanners and older phone cameras often fail to read inverted QR codes. Standard dark-on-light is strongly recommended for physical prints."
                    }
                  }

                  // Machine Verification Badge (tested with zbar)
                  Rectangle {
                    height: Style.space(18)
                    width: verifyBadgeRow.implicitWidth + Style.space(10)
                    radius: 0
                    color: verifyProc.running
                           ? Util.alpha(Color.accent, 0.15)
                           : (root.isVerifiedScannable ? Util.alpha("#10B981", 0.15) : Util.alpha("#EF4444", 0.15))
                    border.width: 1
                    border.color: verifyProc.running
                                  ? Color.accent
                                  : (root.isVerifiedScannable ? "#10B981" : "#EF4444")
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                      id: verifyBadgeRow
                      anchors.centerIn: parent
                      spacing: Style.space(4)
                      Text {
                        text: verifyProc.running ? "󰑮" : (root.isVerifiedScannable ? "✓" : "⚠")
                        color: verifyProc.running ? Color.accent : (root.isVerifiedScannable ? "#10B981" : "#EF4444")
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.2)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: verifyProc.running ? "Verifying..." : (root.isVerifiedScannable ? "Scannable" : "Scan Warning")
                        color: verifyProc.running ? Color.accent : (root.isVerifiedScannable ? "#10B981" : "#EF4444")
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.2)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                    MouseArea {
                      id: verifyMouse
                      anchors.fill: parent
                      hoverEnabled: true
                    }
                    PanelToolTip {
                      visible: verifyMouse.containsMouse
                      text: verifyProc.running
                            ? "Testing QR code machine scannability..."
                            : (root.isVerifiedScannable
                               ? "Machine verified: Standard barcode cameras can decode this QR code."
                               : "Warning: Low contrast or style distortion detected. Consider increasing contrast.")
                    }
                  }
                }

                Item { Layout.fillWidth: true }

                // Right: Multi-Part QR Series Navigator OR Matrix Stats Pill
                Row {
                  Layout.alignment: Qt.AlignVCenter
                  spacing: Style.space(4)

                  // Multi-Part Series Navigator (Only when series mode active with multiple parts)
                  Row {
                    visible: root.isSeriesMode && root.totalSeriesParts > 1
                    spacing: Style.space(3)
                    anchors.verticalCenter: parent.verticalCenter

                    // Play / Pause Stream Button
                    Rectangle {
                      width: Style.space(20); height: Style.space(18); radius: 0
                      color: root.seriesAutoPlay ? Color.accent : (playM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
                      border.width: 1
                      border.color: root.seriesAutoPlay ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.4)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        anchors.centerIn: parent
                        text: root.seriesAutoPlay ? "󰏤" : "󰐊"
                        color: root.seriesAutoPlay ? (Color.buttonText || "#000000") : (Color.popups.text || Color.text)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(8)
                      }
                      MouseArea {
                        id: playM
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.seriesAutoPlay = !root.seriesAutoPlay
                      }
                      PanelToolTip {
                        visible: playM.containsMouse
                        text: root.seriesAutoPlay ? "Pause auto-streaming (Space)" : "Auto-advance parts for scanner streaming (Space)"
                      }
                    }

                    // Prev Button
                    Rectangle {
                      width: Style.space(18); height: Style.space(18); radius: 0
                      color: prevM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
                      border.width: 1
                      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        anchors.centerIn: parent
                        text: "◀"
                        color: Color.popups.text || Color.text
                        font.pixelSize: Style.space(7)
                      }
                      MouseArea {
                        id: prevM
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevSeriesPart()
                      }
                      PanelToolTip {
                        visible: prevM.containsMouse
                        text: "Previous part (Left Arrow)"
                      }
                    }

                    // Part Indicator Pill
                    Rectangle {
                      height: Style.space(18)
                      width: partText.implicitWidth + Style.space(10)
                      radius: 0
                      color: Util.alpha(Color.accent, 0.15)
                      border.width: 1
                      border.color: Util.alpha(Color.accent, 0.4)
                      anchors.verticalCenter: parent.verticalCenter

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(3)
                        Text {
                          text: "󰄲"
                          color: Color.accent
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          id: partText
                          text: "Part " + root.currentSeriesIndex + " / " + root.totalSeriesParts
                          color: Color.popups.text || Color.text
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }

                    // Next Button
                    Rectangle {
                      width: Style.space(18); height: Style.space(18); radius: 0
                      color: nextM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
                      border.width: 1
                      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: Color.popups.text || Color.text
                        font.pixelSize: Style.space(7)
                      }
                      MouseArea {
                        id: nextM
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextSeriesPart()
                      }
                      PanelToolTip {
                        visible: nextM.containsMouse
                        text: "Next part (Right Arrow)"
                      }
                    }
                  }

                  // Single QR Mode Matrix Specs (When not in multi-part series)
                  Rectangle {
                    visible: !root.isSeriesMode || root.totalSeriesParts <= 1
                    height: Style.space(18)
                    width: singleSpecRow.implicitWidth + Style.space(10)
                    radius: 0
                    color: Util.alpha(Color.popups.text || Color.text, 0.05)
                    border.width: 1
                    border.color: Util.alpha(Color.popups.border || Color.border, 0.25)
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                      id: singleSpecRow
                      anchors.centerIn: parent
                      spacing: Style.space(4)

                      Text {
                        text: "󰄲 V" + root.detectedVersion + " (" + root.matrixSize + "×" + root.matrixSize + ")"
                        color: Util.alpha(Color.popups.text || Color.text, 0.75)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: "• " + root.eccLevel
                        color: Color.accent
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }
                }
              }
            }
          }
        }
