import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

RowLayout {
  id: sec2
  required property var modal
  readonly property var root: modal
  property alias themePresetsDropdownBtn: themePresetsDropdownBtn
  property alias logoPresetsDropdownBtn: logoPresetsDropdownBtn
  property alias logoPathInput: logoPathInput
  spacing: 0

                // -------------------------------------------------------------
                // LEFT COLUMN: PROPERTIES SIDEBAR NAVIGATION
                // -------------------------------------------------------------
                Rectangle {
                  id: propSidebar
                  Layout.preferredWidth: Style.space(122)
                  Layout.fillHeight: true
                  color: Util.alpha(Color.popups.text || Color.text, 0.02)
                  border.width: 0

                  // Vertical divider border line on the right
                  Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Util.alpha(Color.popups.border || Color.border, 0.25)
                  }

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(7)
                    spacing: Style.space(4)

                    // Sidebar Section Title
                    Text {
                      text: "PROPERTIES"
                      color: Util.alpha(Color.popups.text || Color.text, 0.45)
                      font.family: Style.font.fixedFamily || "monospace"
                      font.pixelSize: Style.space(6.5)
                      font.bold: true
                      Layout.leftMargin: Style.space(4)
                      Layout.topMargin: Style.space(2)
                      Layout.bottomMargin: Style.space(2)
                    }

                    // Vertical Navigation Tabs
                    Repeater {
                      model: [
                        { id: 0, icon: "🎨", title: "Colors & Parts" },
                        { id: 1, icon: "󰄲", title: "Shapes & Eyes" },
                        { id: 2, icon: "⚙️", title: "Version & Zone" },
                        { id: 3, icon: "󰣇", title: "Center Logo" }
                      ]

                      Rectangle {
                        id: propTabItem
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(28)
                        radius: 0
                        color: root.activeControlTab === modelData.id
                               ? Util.alpha(Color.accent, 0.16)
                               : (pTabMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.07) : "transparent")
                        border.width: 1
                        border.color: root.activeControlTab === modelData.id
                                      ? Util.alpha(Color.accent, 0.6)
                                      : (pTabMouse.containsMouse ? Util.alpha(Color.popups.border || Color.border, 0.2) : "transparent")

                        // Active Indicator Bar on Left Edge
                        Rectangle {
                          width: Style.space(2.5)
                          height: parent.height
                          anchors.left: parent.left
                          color: Color.accent
                          visible: root.activeControlTab === propTabItem.modelData.id
                        }

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(8)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(6)

                          Text {
                            text: propTabItem.modelData.icon
                            color: root.activeControlTab === propTabItem.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(8)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Text {
                            text: propTabItem.modelData.title
                            color: root.activeControlTab === propTabItem.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: root.activeControlTab === propTabItem.modelData.id
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                          }
                        }

                        MouseArea {
                          id: pTabMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.activeControlTab = propTabItem.modelData.id
                        }
                      }
                    }

                    Item { Layout.fillHeight: true }

                    // Quick Actions Section at Sidebar Bottom
                    Rectangle {
                      Layout.fillWidth: true
                      height: 1
                      color: Util.alpha(Color.popups.border || Color.border, 0.2)
                    }

                    Text {
                      text: "ACTIONS"
                      color: Util.alpha(Color.popups.text || Color.text, 0.45)
                      font.family: Style.font.fixedFamily || "monospace"
                      font.pixelSize: Style.space(6)
                      font.bold: true
                      Layout.leftMargin: Style.space(4)
                      Layout.topMargin: Style.space(2)
                    }

                    // Quick Color Swap
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(22)
                      radius: 0
                      color: swapTabMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1
                      border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: Style.space(4)
                        Text { text: "⇄"; font.pixelSize: Style.space(7.5); color: Color.popups.text || Color.text; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "Swap Colors"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); color: Color.popups.text || Color.text; Layout.alignment: Qt.AlignVCenter }
                      }
                      MouseArea {
                        id: swapTabMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.swapColors()
                      }
                      PanelToolTip { visible: swapTabMouse.containsMouse; text: "Swap FG and BG colors" }
                    }

                    // Quick Color Reset
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(22)
                      radius: 0
                      color: resetTabMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1
                      border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: Style.space(4)
                        Text { text: "󰑓"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); color: Color.popups.text || Color.text; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "Reset Colors"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7); color: Color.popups.text || Color.text; Layout.alignment: Qt.AlignVCenter }
                      }
                      MouseArea {
                        id: resetTabMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetColors()
                      }
                      PanelToolTip { visible: resetTabMouse.containsMouse; text: "Reset colors to default theme" }
                    }
                  }
                }

                // -------------------------------------------------------------
                // RIGHT COLUMN: ACTIVE TAB CONTENT VIEW
                // -------------------------------------------------------------
                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  clip: true

                  // =========================================================
                  // TAB 0: COLORS & PARTS
                  // =========================================================
                  ScrollView {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    visible: root.activeControlTab === 0
                    clip: true

                    ColumnLayout {
                      width: parent.width
                      spacing: Style.space(6)

                      // Inverted QR Compatibility Warning Banner (Light on Dark)
                      Rectangle {
                        visible: root.isQrInverted
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(22)
                        radius: 0
                        color: Util.alpha("#F59E0B", 0.12)
                        border.width: 1
                        border.color: Util.alpha("#F59E0B", 0.4)

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(4)

                          Text {
                            text: "⚠"
                            color: "#F59E0B"
                            font.pixelSize: Style.space(8)
                            Layout.alignment: Qt.AlignVCenter
                          }
                          Text {
                            text: "Inverted QR (Light on Dark): May not scan with older camera apps and physical barcode readers. Use dark-on-light for physical prints."
                            color: "#F59E0B"
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                          }
                        }
                      }

                      // Section: Theme Presets
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "THEME PRESETS"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }

                        // My Style / Favorite
                        Rectangle {
                          visible: root.hasFavoriteStyle
                          Layout.preferredHeight: Style.space(18)
                          Layout.preferredWidth: myStyleRow.implicitWidth + Style.space(8)
                          radius: 0
                          color: myStyleM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                          border.width: 1
                          border.color: Color.accent

                          Row {
                            id: myStyleRow
                            anchors.centerIn: parent
                            spacing: Style.space(3)
                            Text { text: "★"; color: Color.accent; font.pixelSize: Style.space(7); anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "My Style"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                          }
                          MouseArea {
                            id: myStyleM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadUserStyle()
                          }
                          PanelToolTip { visible: myStyleM.containsMouse; text: "Load your saved favorite style" }
                        }

                        // Save Style Button
                        Rectangle {
                          Layout.preferredHeight: Style.space(18)
                          Layout.preferredWidth: saveStyleRow.implicitWidth + Style.space(8)
                          radius: 0
                          color: saveStyleM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                          border.width: 1
                          border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                          Row {
                            id: saveStyleRow
                            anchors.centerIn: parent
                            spacing: Style.space(2)
                            Text { text: "󰆓"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7); anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Save Style"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                          }
                          MouseArea {
                            id: saveStyleM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveUserStyle()
                          }
                          PanelToolTip { visible: saveStyleM.containsMouse; text: "Save current style as Favorite (persists across sessions)" }
                        }
                      }

                      // Theme Presets Dropdown Selector
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Rectangle {
                          id: themePresetsDropdownBtn
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: root.themePresetsDropdownOpen
                                 ? Util.alpha(Color.accent, 0.18)
                                 : (themeDropM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                          border.width: 1
                          border.color: root.themePresetsDropdownOpen
                                        ? Color.accent
                                        : (themeDropM.containsMouse ? Util.alpha(Color.popups.border || Color.border, 0.5) : Util.alpha(Color.popups.border || Color.border, 0.25))

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            spacing: Style.space(6)

                            // Dual color swatch (FG & BG)
                            Row {
                              spacing: Style.space(2)
                              Layout.alignment: Qt.AlignVCenter
                              Rectangle {
                                width: Style.space(10); height: Style.space(10); radius: 0
                                color: root.qrFgColor
                                border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                              }
                              Rectangle {
                                width: Style.space(10); height: Style.space(10); radius: 0
                                color: root.qrBgColor
                                border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                              }
                            }

                            Text {
                              text: "Theme Preset:"
                              color: Util.alpha(Color.popups.text || Color.text, 0.55)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                              text: root.activeThemePresetName
                              color: Color.popups.text || Color.text
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                              text: root.themePresetsDropdownOpen ? "▴" : "▾"
                              color: root.themePresetsDropdownOpen ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.7)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              Layout.alignment: Qt.AlignVCenter
                            }
                          }

                          MouseArea {
                            id: themeDropM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.copyDropdownOpen = false
                              root.saveDropdownOpen = false
                              root.logoPresetsDropdownOpen = false
                              root.themePresetsDropdownOpen = !root.themePresetsDropdownOpen
                            }
                          }
                          PanelToolTip {
                            visible: themeDropM.containsMouse && !root.themePresetsDropdownOpen
                            text: "Select a pre-designed color theme preset"
                          }
                        }
                      }

                      // Section: Palette Assignments (2 Columns)
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "PALETTE ASSIGNMENTS"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Style.space(4)
                        columnSpacing: Style.space(6)

                        // 1. Data Modules
                        Rectangle {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: fgChipMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                          border.width: 1
                          border.color: root.activeColorTarget === "fg" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                          MouseArea {
                            id: fgChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "fg"; root.requestColorPicker("fg", root.qrFgColor) }
                          }

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            Rectangle {
                              Layout.preferredWidth: Style.space(12)
                              Layout.preferredHeight: Style.space(12)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrFgColor
                              border.width: 1
                              border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                            }

                            Text {
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                              text: "Modules " + root.qrFgColor
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            // Eyedropper
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: fgPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: fgPickM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰈊"; color: fgPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: fgPickM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "fg"; root.requestScreenPick("fg") }
                              }
                              PanelToolTip { visible: fgPickM.containsMouse; text: "Pick module color from screen (Eyedropper)" }
                            }

                            // Studio
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: fgStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: fgStudM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰏘"; color: fgStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: fgStudM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "fg"; root.requestColorPicker("fg", root.qrFgColor) }
                              }
                              PanelToolTip { visible: fgStudM.containsMouse; text: "Open Color Studio for modules" }
                            }
                          }
                        }

                        // 2. Canvas Background
                        Rectangle {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: bgChipMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                          border.width: 1
                          border.color: root.activeColorTarget === "bg" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                          MouseArea {
                            id: bgChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "bg"; root.requestColorPicker("bg", root.qrBgColor) }
                          }

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            Rectangle {
                              Layout.preferredWidth: Style.space(12)
                              Layout.preferredHeight: Style.space(12)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrBgColor === "transparent" ? "transparent" : root.qrBgColor
                              border.width: 1
                              border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                            }

                            Text {
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                              text: "Canvas " + (root.qrBgColor === "transparent" ? "Transp" : root.qrBgColor)
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            // Eyedropper
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: bgPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: bgPickM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰈊"; color: bgPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: bgPickM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "bg"; root.requestScreenPick("bg") }
                              }
                              PanelToolTip { visible: bgPickM.containsMouse; text: "Pick canvas background from screen (Eyedropper)" }
                            }

                            // Studio
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: bgStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: bgStudM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰏘"; color: bgStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: bgStudM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "bg"; root.requestColorPicker("bg", root.qrBgColor) }
                              }
                              PanelToolTip { visible: bgStudM.containsMouse; text: "Open Color Studio for canvas background" }
                            }

                            // Transparent Toggle
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrBgColor === "transparent" ? Color.accent : (bgTrM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08))
                              border.width: 1
                              border.color: root.qrBgColor === "transparent" ? Color.accent : "transparent"
                              Text { text: "󰙵"; color: root.qrBgColor === "transparent" ? "#ffffff" : (Color.popups.text || Color.text); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: bgTrM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  root.qrBgColor = (root.qrBgColor === "transparent") ? "#FFFFFF" : "transparent"
                                  root.showFeedback("Canvas: " + root.qrBgColor)
                                  if (root.visible && root.textToEncode.trim().length > 0) root.generateQr()
                                }
                              }
                              PanelToolTip { visible: bgTrM.containsMouse; text: "Toggle transparent background" }
                            }
                          }
                        }

                        // 3. Outer Eye Box
                        Rectangle {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: eyeOutChipMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                          border.width: 1
                          border.color: root.activeColorTarget === "outer_eye" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                          MouseArea {
                            id: eyeOutChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "outer_eye"; root.requestColorPicker("outer_eye", root.qrOuterEyeColor) }
                          }

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            Rectangle {
                              Layout.preferredWidth: Style.space(12)
                              Layout.preferredHeight: Style.space(12)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrOuterEyeColor
                              border.width: 1
                              border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                            }

                            Text {
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                              text: "Outer Eye " + root.qrOuterEyeColor
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            // Eyedropper
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: eyeOutPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: eyeOutPickM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰈊"; color: eyeOutPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: eyeOutPickM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "outer_eye"; root.requestScreenPick("outer_eye") }
                              }
                              PanelToolTip { visible: eyeOutPickM.containsMouse; text: "Pick outer eye color from screen (Eyedropper)" }
                            }

                            // Studio
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: eyeOutStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: eyeOutStudM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰏘"; color: eyeOutStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: eyeOutStudM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "outer_eye"; root.requestColorPicker("outer_eye", root.qrOuterEyeColor) }
                              }
                              PanelToolTip { visible: eyeOutStudM.containsMouse; text: "Open Color Studio for outer eye" }
                            }
                          }
                        }

                        // 4. Inner Eye Ball
                        Rectangle {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: eyeInChipMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                          border.width: 1
                          border.color: root.activeColorTarget === "inner_eye" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                          MouseArea {
                            id: eyeInChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "inner_eye"; root.requestColorPicker("inner_eye", root.qrInnerEyeColor) }
                          }

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            Rectangle {
                              Layout.preferredWidth: Style.space(12)
                              Layout.preferredHeight: Style.space(12)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrInnerEyeColor
                              border.width: 1
                              border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                            }

                            Text {
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                              text: "Inner Eye " + root.qrInnerEyeColor
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            // Eyedropper
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: eyeInPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: eyeInPickM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰈊"; color: eyeInPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: eyeInPickM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "inner_eye"; root.requestScreenPick("inner_eye") }
                              }
                              PanelToolTip { visible: eyeInPickM.containsMouse; text: "Pick inner eyeball color from screen (Eyedropper)" }
                            }

                            // Studio
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: eyeInStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: eyeInStudM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰏘"; color: eyeInStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: eyeInStudM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "inner_eye"; root.requestColorPicker("inner_eye", root.qrInnerEyeColor) }
                              }
                              PanelToolTip { visible: eyeInStudM.containsMouse; text: "Open Color Studio for inner eyeball" }
                            }
                          }
                        }

                        // 5. Timing Track
                        Rectangle {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: timingChipMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                          border.width: 1
                          border.color: root.activeColorTarget === "timing" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                          MouseArea {
                            id: timingChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "timing"; root.requestColorPicker("timing", root.qrTimingColor) }
                          }

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            Rectangle {
                              Layout.preferredWidth: Style.space(12)
                              Layout.preferredHeight: Style.space(12)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrTimingColor
                              border.width: 1
                              border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                            }

                            Text {
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                              text: "Timing " + root.qrTimingColor
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            // Eyedropper
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: timingPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: timingPickM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰈊"; color: timingPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: timingPickM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "timing"; root.requestScreenPick("timing") }
                              }
                              PanelToolTip { visible: timingPickM.containsMouse; text: "Pick timing track color from screen (Eyedropper)" }
                            }

                            // Studio
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: timingStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: timingStudM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰏘"; color: timingStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: timingStudM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "timing"; root.requestColorPicker("timing", root.qrTimingColor) }
                              }
                              PanelToolTip { visible: timingStudM.containsMouse; text: "Open Color Studio for timing track" }
                            }
                          }
                        }

                        // 6. Alignment Marker
                        Rectangle {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(24)
                          radius: 0
                          color: alignChipMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                          border.width: 1
                          border.color: root.activeColorTarget === "alignment" ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                          MouseArea {
                            id: alignChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "alignment"; root.requestColorPicker("alignment", root.qrAlignmentColor) }
                          }

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            Rectangle {
                              Layout.preferredWidth: Style.space(12)
                              Layout.preferredHeight: Style.space(12)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: root.qrAlignmentColor
                              border.width: 1
                              border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                            }

                            Text {
                              Layout.fillWidth: true
                              Layout.alignment: Qt.AlignVCenter
                              text: "Alignment " + root.qrAlignmentColor
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            // Eyedropper
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: alignPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: alignPickM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰈊"; color: alignPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: alignPickM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "alignment"; root.requestScreenPick("alignment") }
                              }
                              PanelToolTip { visible: alignPickM.containsMouse; text: "Pick alignment marker color from screen (Eyedropper)" }
                            }

                            // Studio
                            Rectangle {
                              Layout.preferredWidth: Style.space(16)
                              Layout.preferredHeight: Style.space(16)
                              Layout.alignment: Qt.AlignVCenter
                              radius: 0
                              color: alignStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                              border.width: 1
                              border.color: alignStudM.containsMouse ? Color.accent : "transparent"
                              Text { text: "󰏘"; color: alignStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                              MouseArea {
                                id: alignStudM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeColorTarget = "alignment"; root.requestColorPicker("alignment", root.qrAlignmentColor) }
                              }
                              PanelToolTip { visible: alignStudM.containsMouse; text: "Open Color Studio for alignment patterns" }
                            }
                          }
                        }
                      }

                      // Section: Gradient Engine
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "GRADIENT ENGINE"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Style:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(40)
                        }

                        Repeater {
                          model: [
                            { id: "none", label: "None" },
                            { id: "linear_diagonal", label: "Diagonal" },
                            { id: "linear_horizontal", label: "Horizontal" },
                            { id: "linear_vertical", label: "Vertical" },
                            { id: "radial", label: "Radial" }
                          ]

                          Rectangle {
                            id: gradChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: Style.space(58)
                            radius: 0
                            color: root.gradientType === gradChip.modelData.id ? Color.accent : (gradM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.gradientType === gradChip.modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                            Text {
                              text: gradChip.modelData.label
                              color: root.gradientType === gradChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              font.bold: root.gradientType === gradChip.modelData.id
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: gradM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.gradientType = gradChip.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // Gradient End Color Row (when active)
                      RowLayout {
                        visible: root.gradientType !== "none"
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "End Color:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(40)
                        }

                        Rectangle {
                          Layout.preferredWidth: Style.space(12); Layout.preferredHeight: Style.space(12); radius: 0
                          color: root.gradientColor
                          border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                        }

                        Text {
                          text: root.gradientColor
                          color: Color.popups.text || Color.text
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(7)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.preferredWidth: Style.space(16); Layout.preferredHeight: Style.space(16); radius: 0
                          color: gradColPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          border.width: 1; border.color: gradColPickM.containsMouse ? Color.accent : "transparent"
                          Text { text: "󰈊"; color: gradColPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: gradColPickM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "gradient"; root.requestScreenPick("gradient") }
                          }
                          PanelToolTip { visible: gradColPickM.containsMouse; text: "Pick gradient end color from screen" }
                        }

                        Rectangle {
                          Layout.preferredWidth: Style.space(16); Layout.preferredHeight: Style.space(16); radius: 0
                          color: gradColStudM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.08)
                          border.width: 1; border.color: gradColStudM.containsMouse ? Color.accent : "transparent"
                          Text { text: "󰏘"; color: gradColStudM.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.8); font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                          MouseArea {
                            id: gradColStudM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.activeColorTarget = "gradient"; root.requestColorPicker("gradient", root.gradientColor) }
                          }
                          PanelToolTip { visible: gradColStudM.containsMouse; text: "Open Color Studio for gradient end color" }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      Text {
                        Layout.fillWidth: true
                        text: "💡 Click 󰈊 for Hyprpicker or 󰏘 for Color Studio. Each QR section updates independently."
                        color: Util.alpha(Color.popups.text || Color.text, 0.45)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                      }
                    }
                  }

                  // =========================================================
                  // TAB 1: SHAPES & EYES & FRAMES
                  // =========================================================
                  ScrollView {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    visible: root.activeControlTab === 1
                    clip: true

                    ColumnLayout {
                      width: parent.width
                      spacing: Style.space(6)

                      // 1. Module Geometry Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "DATA MODULE GEOMETRY"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Modules:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(60)
                        }

                        Repeater {
                          model: [
                            { id: "square", icon: "■", label: "Square" },
                            { id: "rounded", icon: "▢", label: "Rounded" },
                            { id: "dot", icon: "●", label: "Dots" },
                            { id: "fluid", icon: "󰄲", label: "Fluid" }
                          ]

                          Rectangle {
                            id: modChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(22)
                            Layout.preferredWidth: Style.space(66)
                            radius: 0
                            color: root.moduleShape === modChip.modelData.id ? Color.accent : (modMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.moduleShape === modChip.modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                            Row {
                              anchors.centerIn: parent; spacing: Style.space(4)
                              Text { text: modChip.modelData.icon; color: root.moduleShape === modChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text); font.pixelSize: Style.space(7.5) }
                              Text {
                                text: modChip.modelData.label
                                color: root.moduleShape === modChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7.5)
                                font.bold: root.moduleShape === modChip.modelData.id
                              }
                            }
                            MouseArea {
                              id: modMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.moduleShape = modChip.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // 2. Corner Finder Eyes Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "CORNER FINDER EYES"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Finder Eyes:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(60)
                        }

                        Repeater {
                          model: [
                            { id: "square", icon: "■", label: "Square" },
                            { id: "rounded", icon: "▢", label: "Curved" },
                            { id: "circle", icon: "●", label: "Circle" },
                            { id: "squircle", icon: "󰄱", label: "Squircle" }
                          ]

                          Rectangle {
                            id: eyeChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(22)
                            Layout.preferredWidth: Style.space(66)
                            radius: 0
                            color: root.eyeShape === eyeChip.modelData.id ? Color.accent : (eyeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.eyeShape === eyeChip.modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                            Row {
                              anchors.centerIn: parent; spacing: Style.space(4)
                              Text { text: eyeChip.modelData.icon; color: root.eyeShape === eyeChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text); font.pixelSize: Style.space(7.5) }
                              Text {
                                text: eyeChip.modelData.label
                                color: root.eyeShape === eyeChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7.5)
                                font.bold: root.eyeShape === eyeChip.modelData.id
                              }
                            }
                            MouseArea {
                              id: eyeMouse
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.eyeShape = eyeChip.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // 3. Card Frame & Banner Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "CARD FRAME & BRAND BANNER"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Frame Style:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(60)
                        }

                        Repeater {
                          model: [
                            { id: "none", label: "None" },
                            { id: "bottom_banner", label: "Bottom Banner" },
                            { id: "top_banner", label: "Top Banner" },
                            { id: "framed_card", label: "Framed Card" }
                          ]

                          Rectangle {
                            id: frameChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(22)
                            Layout.preferredWidth: framePillRow.implicitWidth + Style.space(12)
                            radius: 0
                            color: root.frameStyle === frameChip.modelData.id ? Color.accent : (frameM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.frameStyle === frameChip.modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)

                            Row {
                              id: framePillRow
                              anchors.centerIn: parent
                              spacing: Style.space(3)
                              Text {
                                text: frameChip.modelData.label
                                color: root.frameStyle === frameChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                font.bold: root.frameStyle === frameChip.modelData.id
                                anchors.verticalCenter: parent.verticalCenter
                              }
                            }
                            MouseArea {
                              id: frameM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.frameStyle = frameChip.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // Frame Banner CTA Row
                      RowLayout {
                        visible: root.frameStyle !== "none"
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Banner CTA:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(60)
                        }

                        Rectangle {
                          Layout.preferredWidth: Style.space(100)
                          Layout.preferredHeight: Style.space(22)
                          radius: 0
                          color: Util.alpha(Color.popups.text || Color.text, 0.05)
                          border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

                          TextInput {
                            id: frameTextInput
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                            text: root.frameText
                            color: Color.popups.text || Color.text
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            verticalAlignment: TextInput.AlignVCenter
                            onTextEdited: {
                              root.frameText = text
                              qrDebounceTimer.restart()
                            }
                          }
                        }

                        Repeater {
                          model: ["SCAN ME", "JOIN WI-FI", "CONNECT", "VISIT SITE"]

                          Rectangle {
                            id: sugChip
                            required property string modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: sugTxt.implicitWidth + Style.space(8)
                            radius: 0
                            color: sugM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                            Text {
                              id: sugTxt
                              anchors.centerIn: parent
                              text: sugChip.modelData
                              color: root.frameText === sugChip.modelData ? Color.accent : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(6.5)
                              font.bold: root.frameText === sugChip.modelData
                            }
                            MouseArea {
                              id: sugM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.frameText = sugChip.modelData
                                if (frameTextInput) frameTextInput.text = sugChip.modelData
                                root.generateQr()
                              }
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // Frame Subtitle & Corners Row
                      RowLayout {
                        visible: root.frameStyle !== "none"
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Subtitle:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(60)
                        }

                        Rectangle {
                          Layout.preferredWidth: Style.space(100)
                          Layout.preferredHeight: Style.space(22)
                          radius: 0
                          color: Util.alpha(Color.popups.text || Color.text, 0.05)
                          border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

                          TextInput {
                            id: frameSubtextInput
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                            text: root.frameSubtext
                            color: Color.popups.text || Color.text
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            verticalAlignment: TextInput.AlignVCenter
                            onTextEdited: {
                              root.frameSubtext = text
                              qrDebounceTimer.restart()
                            }
                          }
                        }

                        Repeater {
                          model: ["Guest Wi-Fi", "omarchy.org", "Scan with camera"]

                          Rectangle {
                            id: subChip
                            required property string modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: subTxt.implicitWidth + Style.space(8)
                            radius: 0
                            color: subM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                            Text {
                              id: subTxt
                              anchors.centerIn: parent
                              text: subChip.modelData
                              color: root.frameSubtext === subChip.modelData ? Color.accent : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(6.5)
                              font.bold: root.frameSubtext === subChip.modelData
                            }
                            MouseArea {
                              id: subM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.frameSubtext = subChip.modelData
                                if (frameSubtextInput) frameSubtextInput.text = subChip.modelData
                                root.generateQr()
                              }
                            }
                          }
                        }

                        Text {
                          text: "Corners:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.leftMargin: Style.space(4)
                        }

                        Repeater {
                          model: [
                            { val: 0, label: "Sharp [0px]" },
                            { val: 14, label: "Rounded [14px]" }
                          ]

                          Rectangle {
                            id: radChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: radTxt.implicitWidth + Style.space(8)
                            radius: 0
                            color: root.frameRadius === radChip.modelData.val ? Color.accent : (radM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1; border.color: root.frameRadius === radChip.modelData.val ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)

                            Text {
                              id: radTxt
                              anchors.centerIn: parent
                              text: radChip.modelData.label
                              color: root.frameRadius === radChip.modelData.val ? "#ffffff" : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(6.5)
                              font.bold: root.frameRadius === radChip.modelData.val
                            }
                            MouseArea {
                              id: radM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.frameRadius = radChip.modelData.val
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      Text {
                        text: "All stylized shapes remain 100% compliant and readable by iOS & Android camera apps."
                        color: Util.alpha(Color.popups.text || Color.text, 0.45)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                      }
                    }
                  }

                  // =========================================================
                  // TAB 2: VERSION & QUIET ZONE & ECC
                  // =========================================================
                  ScrollView {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    visible: root.activeControlTab === 2
                    clip: true

                    ColumnLayout {
                      width: parent.width
                      spacing: Style.space(6)

                      // 1. Matrix Version Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "QR MATRIX & VERSION"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Grid Version:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(70)
                        }

                        // Version SmartScrubber Spinner
                        QrSmartScrubber {
                          id: qrVersionScrubber
                          value: root.qrVersion
                          from: 0
                          to: 40
                          step: 1
                          tip: "QR matrix version 1-40 (0 = Auto). Drag horizontally to adjust, double-click to type"
                          customDisplay: function(val) {
                            var v = Math.round(val)
                            if (v === 0) {
                              return "Auto (V" + root.detectedVersion + " · " + root.matrixSize + "x" + root.matrixSize + ")"
                            }
                            var sz = 17 + 4 * v
                            return "Version " + v + " (" + sz + "x" + sz + ")"
                          }
                          onValueScrubbed: function(val) { root.qrVersion = Math.round(val) }
                          onValueCommitted: function(val) { root.qrVersion = Math.round(val) }
                          Connections {
                            target: root
                            function onQrVersionChanged() {
                              qrVersionScrubber.value = root.qrVersion
                            }
                          }
                        }

                        // Auto Button
                        Rectangle {
                          Layout.preferredHeight: Style.space(20)
                          Layout.preferredWidth: Style.space(45)
                          radius: 0
                          color: root.qrVersion === 0 ? Color.accent : (autoVM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                          border.width: 1; border.color: root.qrVersion === 0 ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)
                          Text {
                            text: "Auto"
                            color: root.qrVersion === 0 ? "#ffffff" : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: root.qrVersion === 0
                            anchors.centerIn: parent
                          }
                          MouseArea {
                            id: autoVM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.qrVersion = 0
                              qrVersionScrubber.value = 0
                            }
                          }
                          PanelToolTip {
                            visible: autoVM.containsMouse
                            text: "Auto: Automatically detect smallest viable QR matrix version based on content length"
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // 2. Quiet Zone & ECC Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "MARGIN & ERROR RECOVERY"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      // Quiet Zone Margin Row
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Quiet Zone:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(70)
                        }

                        Repeater {
                          model: [
                            { id: 0, label: "0 None" },
                            { id: 1, label: "1 Compact" },
                            { id: 2, label: "2 Standard" },
                            { id: 4, label: "4 Spec (ISO)" }
                          ]

                          Rectangle {
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: qzTxt.implicitWidth + Style.space(12)
                            radius: 0
                            color: root.quietZone === modelData.id ? Color.accent : (qzM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.quietZone === modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
                            Text {
                              id: qzTxt
                              text: parent.modelData.label
                              color: root.quietZone === parent.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              font.bold: root.quietZone === parent.modelData.id
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: qzM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.quietZone = parent.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // Error Correction ECC Row
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "ECC Level:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(70)
                        }

                        Repeater {
                          model: [
                            { id: "L", label: "L (7%)" },
                            { id: "M", label: "M (15% Default)" },
                            { id: "Q", label: "Q (25%)" },
                            { id: "H", label: "H (30% Logo)" }
                          ]

                          Rectangle {
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: eccTxt.implicitWidth + Style.space(12)
                            radius: 0
                            color: root.eccLevel === modelData.id ? Color.accent : (eccM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.eccLevel === modelData.id ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.1)
                            Text {
                              id: eccTxt
                              text: parent.modelData.label
                              color: root.eccLevel === parent.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              font.bold: root.eccLevel === parent.modelData.id
                              anchors.centerIn: parent
                            }
                            MouseArea {
                              id: eccM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.eccLevel = parent.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // 3. Export Resolution Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "EXPORT RESOLUTION"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Raster Target:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(70)
                        }

                        Repeater {
                          model: [
                            { val: 600, label: "600px Screen (Digital / Web)", icon: "󰍹" },
                            { val: 2400, label: "2400px Print (300 DPI Ultra-HD)", icon: "󰐾" }
                          ]

                          Rectangle {
                            id: resChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: resRow.implicitWidth + Style.space(12)
                            radius: 0
                            color: root.exportResolution === resChip.modelData.val
                                   ? Color.accent
                                   : (resM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.exportResolution === resChip.modelData.val ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)

                            Row {
                              id: resRow
                              anchors.centerIn: parent
                              spacing: Style.space(4)
                              Text {
                                text: resChip.modelData.icon
                                color: root.exportResolution === resChip.modelData.val ? "#ffffff" : Color.accent
                                font.pixelSize: Style.space(7.5)
                                anchors.verticalCenter: parent.verticalCenter
                              }
                              Text {
                                text: resChip.modelData.label
                                color: root.exportResolution === resChip.modelData.val ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                font.bold: root.exportResolution === resChip.modelData.val
                                anchors.verticalCenter: parent.verticalCenter
                              }
                            }

                            MouseArea {
                              id: resM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.exportResolution = resChip.modelData.val
                                root.generateQr()
                              }
                            }
                            PanelToolTip {
                              visible: resM.containsMouse
                              text: resChip.modelData.val === 600
                                    ? "Standard 600px raster resolution, optimized for digital screens, quick clipboard pasting, and web sharing."
                                    : "High-resolution 2400px raster export (300 DPI), razor-sharp for professional print, posters, brochures, and packaging."
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // 4. Large Payload Multi-Part Section
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Layout.topMargin: Style.space(2)

                        Text {
                          text: "LARGE PAYLOAD MULTI-PART STREAMING"
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                        }

                        Rectangle {
                          Layout.fillWidth: true
                          height: 1
                          color: Util.alpha(Color.popups.border || Color.border, 0.15)
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Text {
                          text: "Auto-Split:"
                          color: Util.alpha(Color.popups.text || Color.text, 0.75)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                          Layout.preferredWidth: Style.space(70)
                        }

                        // Auto-Split Toggle Button
                        Rectangle {
                          Layout.preferredHeight: Style.space(20)
                          Layout.preferredWidth: autoSplitRow.implicitWidth + Style.space(12)
                          radius: 0
                          color: root.seriesAutoSplit
                                 ? Util.alpha(Color.accent, 0.25)
                                 : (autoSplitM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                          border.width: 1
                          border.color: root.seriesAutoSplit ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.15)

                          Row {
                            id: autoSplitRow
                            anchors.centerIn: parent
                            spacing: Style.space(4)
                            Text {
                              text: root.seriesAutoSplit ? "󰄲" : "󰄱"
                              color: root.seriesAutoSplit ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.6)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7.5)
                              font.bold: true
                              anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                              text: "Enable Multi-Part"
                              color: root.seriesAutoSplit ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.7)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              font.bold: root.seriesAutoSplit
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }

                          MouseArea {
                            id: autoSplitM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.seriesAutoSplit = !root.seriesAutoSplit
                              root.generateQr()
                            }
                          }
                          PanelToolTip {
                            visible: autoSplitM.containsMouse
                            text: "Intelligently split long text into a multi-part QR sequence at natural word/line boundaries."
                          }
                        }

                        // Chunk Size Selector Chips
                        Repeater {
                          model: [
                            { val: 300, label: "300 Chars (Fast Scan)", tip: "300 chars/part: Low density modules, fastest scannability for camera lenses." },
                            { val: 600, label: "600 Chars (Balanced)", tip: "600 chars/part: Optimal balance between scan speed and number of QR codes." },
                            { val: 1200, label: "1200 Chars (Dense)", tip: "1200 chars/part: Higher module density, minimizes the total count of parts." }
                          ]

                          Rectangle {
                            id: chunkChip
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: chunkRow.implicitWidth + Style.space(12)
                            radius: 0
                            opacity: root.seriesAutoSplit ? 1.0 : 0.4
                            color: (root.seriesAutoSplit && root.seriesChunkSize === chunkChip.modelData.val)
                                   ? Color.accent
                                   : (chunkM.containsMouse && root.seriesAutoSplit ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: (root.seriesAutoSplit && root.seriesChunkSize === chunkChip.modelData.val)
                                          ? Color.accent
                                          : Util.alpha(Color.popups.text || Color.text, 0.15)

                            Row {
                              id: chunkRow
                              anchors.centerIn: parent
                              spacing: Style.space(3)
                              Text {
                                text: chunkChip.modelData.label
                                color: (root.seriesAutoSplit && root.seriesChunkSize === chunkChip.modelData.val)
                                       ? "#ffffff"
                                       : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                font.bold: (root.seriesAutoSplit && root.seriesChunkSize === chunkChip.modelData.val)
                                anchors.verticalCenter: parent.verticalCenter
                              }
                            }

                            MouseArea {
                              id: chunkM
                              anchors.fill: parent
                              hoverEnabled: root.seriesAutoSplit
                              cursorShape: root.seriesAutoSplit ? Qt.PointingHandCursor : Qt.ArrowCursor
                              enabled: root.seriesAutoSplit
                              onClicked: {
                                root.seriesChunkSize = chunkChip.modelData.val
                                root.generateQr()
                              }
                            }
                            PanelToolTip {
                              visible: chunkM.containsMouse && root.seriesAutoSplit
                              text: chunkChip.modelData.tip
                            }
                          }
                        }

                        // Active Series Indicator Pill
                        Rectangle {
                          visible: root.isSeriesMode && root.totalSeriesParts > 1
                          Layout.preferredHeight: Style.space(20)
                          Layout.preferredWidth: seriesPillRow.implicitWidth + Style.space(10)
                          radius: 0
                          color: Util.alpha(Color.accent, 0.15)
                          border.width: 1
                          border.color: Util.alpha(Color.accent, 0.35)

                          Row {
                            id: seriesPillRow
                            anchors.centerIn: parent
                            spacing: Style.space(3)
                            Text {
                              text: "󰏗"
                              color: Color.accent
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(7)
                              anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                              text: root.totalSeriesParts + " Parts Active"
                              color: Color.accent
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }
                      }
                    }
                  }

                  // =========================================================
                  // TAB 3: CENTER LOGO & BRANDING STUDIO
                  // =========================================================
                  ScrollView {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(6)
                    anchors.bottomMargin: Style.space(6)
                    visible: root.activeControlTab === 3
                    clip: true

                    ColumnLayout {
                      width: parent.width
                      spacing: Style.space(5)

                      // Logo Sub-Tabs Navigation Bar
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(4)

                        Repeater {
                          model: [
                            { id: 0, icon: "󰊤", label: "Logo & Presets" },
                            { id: 1, icon: "󰆍", label: "Badge & Shape" },
                            { id: 2, icon: "󰏘", label: "Colors & Styling" }
                          ]

                          Rectangle {
                            id: lSubBtn
                            required property var modelData
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: lSubRow.implicitWidth + Style.space(12)
                            radius: 0
                            color: root.activeLogoSubTab === lSubBtn.modelData.id
                                   ? Util.alpha(Color.accent, 0.2)
                                   : (lSubM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")
                            border.width: 1
                            border.color: root.activeLogoSubTab === lSubBtn.modelData.id
                                          ? Color.accent
                                          : (lSubM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.2) : Util.alpha(Color.popups.border || Color.border, 0.25))

                            Row {
                              id: lSubRow
                              anchors.centerIn: parent
                              spacing: Style.space(4)

                              Text {
                                text: lSubBtn.modelData.icon
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7.5)
                                color: root.activeLogoSubTab === lSubBtn.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                                anchors.verticalCenter: parent.verticalCenter
                              }
                              Text {
                                text: lSubBtn.modelData.label
                                color: root.activeLogoSubTab === lSubBtn.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                font.bold: root.activeLogoSubTab === lSubBtn.modelData.id
                                anchors.verticalCenter: parent.verticalCenter
                              }
                            }

                            MouseArea {
                              id: lSubM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.activeLogoSubTab = lSubBtn.modelData.id
                            }
                          }
                        }

                        Item { Layout.fillWidth: true }

                        // Prominent Remove Logo Button (or Active Status Pill)
                        Rectangle {
                          Layout.preferredHeight: Style.space(20)
                          Layout.preferredWidth: rmLogoRow.implicitWidth + Style.space(10)
                          radius: 0
                          color: (root.logoPreset !== "none" || root.customLogoPath.length > 0)
                                 ? (rmLogoM.containsMouse ? Util.alpha("#EF4444", 0.3) : Util.alpha("#EF4444", 0.12))
                                 : Util.alpha(Color.popups.text || Color.text, 0.04)
                          border.width: 1
                          border.color: (root.logoPreset !== "none" || root.customLogoPath.length > 0)
                                        ? Util.alpha("#EF4444", 0.7)
                                        : Util.alpha(Color.popups.border || Color.border, 0.25)

                          Row {
                            id: rmLogoRow
                            anchors.centerIn: parent
                            spacing: Style.space(3)
                            Text {
                              text: (root.logoPreset !== "none" || root.customLogoPath.length > 0) ? "✕" : "✓"
                              color: (root.logoPreset !== "none" || root.customLogoPath.length > 0) ? "#EF4444" : Util.alpha(Color.popups.text || Color.text, 0.5)
                              font.pixelSize: Style.space(7)
                              font.bold: true
                              anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                              text: (root.logoPreset !== "none" || root.customLogoPath.length > 0) ? "Remove Logo" : "No Logo"
                              color: (root.logoPreset !== "none" || root.customLogoPath.length > 0) ? "#EF4444" : Util.alpha(Color.popups.text || Color.text, 0.5)
                              font.family: Style.font.menuFamily
                              font.pixelSize: Style.space(6.5)
                              font.bold: true
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }

                          MouseArea {
                            id: rmLogoM
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: (root.logoPreset !== "none" || root.customLogoPath.length > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                              if (root.logoPreset !== "none" || root.customLogoPath.length > 0) {
                                root.logoPreset = "none"
                                root.customLogoPath = ""
                                if (logoPathInput) logoPathInput.text = ""
                                if (root.eccLevel === "H") root.eccLevel = "M"
                                root.generateQr()
                                root.showFeedback("✓ Center logo removed")
                              }
                            }
                          }
                          PanelToolTip {
                            visible: rmLogoM.containsMouse
                            text: (root.logoPreset !== "none" || root.customLogoPath.length > 0)
                                  ? "Click to completely clear center logo and restore full QR modules"
                                  : "No logo currently active on QR code"
                          }
                        }
                      }

                      // Hairline Divider
                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 1
                        color: Util.alpha(Color.popups.border || Color.border, 0.25)
                      }

                      // Subtab 0: Logo & Presets
                      ColumnLayout {
                        visible: root.activeLogoSubTab === 0
                        Layout.fillWidth: true
                        spacing: Style.space(5)

                        // Preset Logos Dropdown Selector
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          // Dropdown Button
                          Rectangle {
                            id: logoPresetsDropdownBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(24)
                            radius: 0
                            color: root.logoPresetsDropdownOpen
                                   ? Util.alpha(Color.accent, 0.18)
                                   : (logoDropM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                            border.width: 1
                            border.color: root.logoPresetsDropdownOpen
                                          ? Color.accent
                                          : (logoDropM.containsMouse ? Util.alpha(Color.popups.border || Color.border, 0.5) : Util.alpha(Color.popups.border || Color.border, 0.25))

                            RowLayout {
                              anchors.fill: parent
                              anchors.leftMargin: Style.space(8)
                              anchors.rightMargin: Style.space(8)
                              spacing: Style.space(6)

                              Text {
                                text: root.currentLogoIcon
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(8.5)
                                color: (root.logoPreset !== "none" || root.customLogoPath.length > 0) ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.5)
                                Layout.alignment: Qt.AlignVCenter
                              }

                              Text {
                                text: "Emblem:"
                                color: Util.alpha(Color.popups.text || Color.text, 0.55)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                Layout.alignment: Qt.AlignVCenter
                              }

                              Text {
                                text: root.currentLogoLabel
                                color: Color.popups.text || Color.text
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7.5)
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                              }

                              Text {
                                text: root.logoPresetsDropdownOpen ? "▴" : "▾"
                                color: root.logoPresetsDropdownOpen ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.7)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7.5)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                              }
                            }

                            MouseArea {
                              id: logoDropM
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.copyDropdownOpen = false
                                root.saveDropdownOpen = false
                                root.themePresetsDropdownOpen = false
                                root.logoPresetsDropdownOpen = !root.logoPresetsDropdownOpen
                              }
                            }
                            PanelToolTip {
                              visible: logoDropM.containsMouse && !root.logoPresetsDropdownOpen
                              text: "Choose a center emblem or logo preset"
                            }
                          }

                          // Quick Clear Logo Button (Visible when logo active)
                          Rectangle {
                            visible: root.logoPreset !== "none" || root.customLogoPath.length > 0
                            Layout.preferredHeight: Style.space(24)
                            Layout.preferredWidth: clearLogoRow.implicitWidth + Style.space(10)
                            radius: 0
                            color: clearLogoM.containsMouse ? Util.alpha("#EF4444", 0.25) : Util.alpha("#EF4444", 0.1)
                            border.width: 1
                            border.color: Util.alpha("#EF4444", 0.6)

                            Row {
                              id: clearLogoRow
                              anchors.centerIn: parent
                              spacing: Style.space(3)
                              Text {
                                text: "✕"
                                color: "#EF4444"
                                font.pixelSize: Style.space(6.5)
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                              }
                              Text {
                                text: "Clear"
                                color: "#EF4444"
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                              }
                            }

                            MouseArea {
                              id: clearLogoM
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.logoPreset = "none"
                                root.customLogoPath = ""
                                if (typeof logoPathInput !== "undefined" && logoPathInput) logoPathInput.text = ""
                                if (root.eccLevel === "H") root.eccLevel = "M"
                                root.generateQr()
                                root.showFeedback("✓ Logo cleared")
                              }
                            }
                            PanelToolTip {
                              visible: clearLogoM.containsMouse
                              text: "Clear center emblem and restore standard ECC"
                            }
                          }
                        }

                        // Image Sources (Clipboard Paste & System Pixmaps)
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Image Source:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(55)
                          }

                          // Paste Clipboard Image Button
                          Rectangle {
                            Layout.preferredHeight: Style.space(20)
                            Layout.preferredWidth: clipImgRow.implicitWidth + Style.space(8)
                            radius: 0
                            color: clipImgM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.1)
                            border.width: 1; border.color: Color.accent

                            Row {
                              id: clipImgRow
                              anchors.centerIn: parent
                              spacing: Style.space(3)
                              Text { text: "󰅍"; color: Color.accent; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                              Text { text: "Paste Clipboard Image"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                              id: clipImgM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: pasteLogoImageProc.running = true
                            }
                            PanelToolTip { visible: clipImgM.containsMouse; text: "Paste raw image directly from Wayland clipboard" }
                          }

                          Text {
                            text: "System:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.55)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            Layout.leftMargin: Style.space(4)
                          }

                          // System Quick-Picks
                          Repeater {
                            model: [
                              { name: "Omarchy", path: "/usr/share/pixmaps/omarchy.png" },
                              { name: "Arch", path: "/usr/share/pixmaps/archlinux-logo.png" },
                              { name: "Neovim", path: "/usr/share/pixmaps/nvim.png" }
                            ]

                            Rectangle {
                              id: pixChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(20)
                              Layout.preferredWidth: pixTxt.implicitWidth + Style.space(8)
                              radius: 0
                              color: (root.logoPreset === "custom" && root.customLogoPath === pixChip.modelData.path) ? Color.accent : (pixM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: (root.logoPreset === "custom" && root.customLogoPath === pixChip.modelData.path) ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)

                              Text {
                                id: pixTxt
                                anchors.centerIn: parent
                                text: pixChip.modelData.name
                                color: (root.logoPreset === "custom" && root.customLogoPath === pixChip.modelData.path) ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: root.customLogoPath === pixChip.modelData.path
                              }
                              MouseArea {
                                id: pixM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  root.customLogoPath = pixChip.modelData.path
                                  root.logoPreset = "custom"
                                  if (logoPathInput) logoPathInput.text = pixChip.modelData.path
                                  if (root.eccLevel !== "H") root.eccLevel = "H"
                                  root.generateQr()
                                  root.showFeedback("✓ " + pixChip.modelData.name + " pixmap logo set")
                                }
                              }
                              PanelToolTip { visible: pixM.containsMouse; text: "Use " + pixChip.modelData.path }
                            }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // Custom File Path Input Row
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "File Path:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(55)
                          }

                          Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(22)
                            radius: 0
                            color: Util.alpha(Color.popups.text || Color.text, 0.05)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

                            TextInput {
                              id: logoPathInput
                              anchors.fill: parent
                              anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                              text: root.customLogoPath
                              color: Color.popups.text || Color.text
                              font.family: Style.font.fixedFamily || "monospace"
                              font.pixelSize: Style.space(7.5)
                              verticalAlignment: TextInput.AlignVCenter
                              onTextEdited: {
                                root.customLogoPath = text
                                if (text.trim().length > 0) root.logoPreset = "custom"
                                qrDebounceTimer.restart()
                              }
                            }
                          }

                          // Paste Path Button
                          Rectangle {
                            Layout.preferredHeight: Style.space(22)
                            Layout.preferredWidth: Style.space(65)
                            radius: 0
                            color: pastePathM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                            Text { text: "📋 Paste"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); anchors.centerIn: parent }
                            MouseArea {
                              id: pastePathM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: pasteLogoPathProc.running = true
                            }
                          }

                          // Clear Path Button
                          Rectangle {
                            visible: root.customLogoPath.length > 0
                            Layout.preferredHeight: Style.space(22)
                            Layout.preferredWidth: Style.space(22)
                            radius: 0
                            color: clearPathM.containsMouse ? Util.alpha(Color.urgent || "#EF4444", 0.2) : Util.alpha(Color.popups.text || Color.text, 0.05)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                            Text { text: "✕"; color: Color.popups.text || Color.text; font.pixelSize: Style.space(7); anchors.centerIn: parent }
                            MouseArea {
                              id: clearPathM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.customLogoPath = ""
                                if (logoPathInput) logoPathInput.text = ""
                                if (root.logoPreset === "custom") root.logoPreset = "none"
                                root.generateQr()
                              }
                            }
                            PanelToolTip { visible: clearPathM.containsMouse; text: "Clear file path" }
                          }
                        }
                      }

                      // Subtab 1: Badge & Shape
                      ColumnLayout {
                        visible: root.activeLogoSubTab === 1
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        // Badge Shape Selection
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Badge Shape:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          Repeater {
                            model: [
                              { id: "rounded", icon: "󰄳", label: "Squircle" },
                              { id: "circle", icon: "󰝤", label: "Circle" },
                              { id: "square", icon: "󰆍", label: "Square" },
                              { id: "floating", icon: "󰌷", label: "Floating" }
                            ]

                            Rectangle {
                              id: bShapeChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(20)
                              Layout.preferredWidth: bShapeTxt.implicitWidth + Style.space(10)
                              radius: 0
                              color: root.logoShape === bShapeChip.modelData.id ? Color.accent : (bShapeM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: root.logoShape === bShapeChip.modelData.id ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Row {
                                id: bShapeTxt
                                anchors.centerIn: parent; spacing: Style.space(3)
                                Text {
                                  text: bShapeChip.modelData.icon
                                  color: root.logoShape === bShapeChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                                  font.pixelSize: Style.space(7)
                                  anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                  text: bShapeChip.modelData.label
                                  color: root.logoShape === bShapeChip.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                                  font.family: Style.font.menuFamily
                                  font.pixelSize: Style.space(6.5)
                                  font.bold: root.logoShape === bShapeChip.modelData.id
                                  anchors.verticalCenter: parent.verticalCenter
                                }
                              }

                              MouseArea {
                                id: bShapeM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoShape = bShapeChip.modelData.id
                              }
                            }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // Badge Size / Scale
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Badge Size:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          Repeater {
                            model: [
                              { sz: 0.16, label: "16% Compact" },
                              { sz: 0.22, label: "22% Standard" },
                              { sz: 0.28, label: "28% Prominent" },
                              { sz: 0.32, label: "32% Max Safe" }
                            ]

                            Rectangle {
                              id: bScaleChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(20)
                              Layout.preferredWidth: bScaleTxt.implicitWidth + Style.space(8)
                              radius: 0
                              color: Math.abs(root.logoSize - bScaleChip.modelData.sz) < 0.01 ? Color.accent : (bScaleM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: Math.abs(root.logoSize - bScaleChip.modelData.sz) < 0.01 ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Text {
                                id: bScaleTxt
                                anchors.centerIn: parent
                                text: bScaleChip.modelData.label
                                color: Math.abs(root.logoSize - bScaleChip.modelData.sz) < 0.01 ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: Math.abs(root.logoSize - bScaleChip.modelData.sz) < 0.01
                              }
                              MouseArea {
                                id: bScaleM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoSize = bScaleChip.modelData.sz
                              }
                            }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // Icon Margin Row
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Icon Margin:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          Repeater {
                            model: [
                              { pad: 0.80, label: "Tight (80%)" },
                              { pad: 0.70, label: "Balanced (70%)" },
                              { pad: 0.60, label: "Spacious (60%)" }
                            ]

                            Rectangle {
                              id: bPadChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(20)
                              Layout.preferredWidth: bPadTxt.implicitWidth + Style.space(8)
                              radius: 0
                              color: Math.abs(root.logoPadding - bPadChip.modelData.pad) < 0.04 ? Color.accent : (bPadM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: Math.abs(root.logoPadding - bPadChip.modelData.pad) < 0.04 ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Text {
                                id: bPadTxt
                                anchors.centerIn: parent
                                text: bPadChip.modelData.label
                                color: Math.abs(root.logoPadding - bPadChip.modelData.pad) < 0.04 ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: Math.abs(root.logoPadding - bPadChip.modelData.pad) < 0.04
                              }
                              MouseArea {
                                id: bPadM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoPadding = bPadChip.modelData.pad
                              }
                            }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // Badge Border Row (Next Row with SmartScrubber spinner)
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Border Width:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          QrSmartScrubber {
                            id: logoBorderScrubber
                            value: root.logoBorderWidth
                            from: 0
                            to: 12
                            step: 1
                            unit: "px"
                            tip: "Logo badge border width in pixels (drag to adjust, double-click to type)"
                            customDisplay: function(val) {
                              var v = Math.round(val)
                              return v === 0 ? "0px (None)" : (v + "px")
                            }
                            onValueScrubbed: function(val) { root.logoBorderWidth = Math.round(val) }
                            onValueCommitted: function(val) { root.logoBorderWidth = Math.round(val) }
                            Connections {
                              target: root
                              function onLogoBorderWidthChanged() {
                                logoBorderScrubber.value = root.logoBorderWidth
                              }
                            }
                          }

                          // Quick chips for 0 (None), 1px, 2px, 4px
                          Repeater {
                            model: [
                              { w: 0, label: "None" },
                              { w: 1, label: "1px" },
                              { w: 2, label: "2px" },
                              { w: 4, label: "4px" }
                            ]

                            Rectangle {
                              id: bBrdWChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(20)
                              Layout.preferredWidth: bBrdWTxt.implicitWidth + Style.space(8)
                              radius: 0
                              color: root.logoBorderWidth === bBrdWChip.modelData.w ? Color.accent : (bBrdWM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: root.logoBorderWidth === bBrdWChip.modelData.w ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Text {
                                id: bBrdWTxt
                                anchors.centerIn: parent
                                text: bBrdWChip.modelData.label
                                color: root.logoBorderWidth === bBrdWChip.modelData.w ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: root.logoBorderWidth === bBrdWChip.modelData.w
                              }
                              MouseArea {
                                id: bBrdWM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoBorderWidth = bBrdWChip.modelData.w
                              }
                              PanelToolTip {
                                visible: bBrdWM.containsMouse
                                text: bBrdWChip.modelData.w === 0 ? "Remove badge border" : ("Set " + bBrdWChip.modelData.w + "px border")
                              }
                            }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // Safety note
                        Text {
                          text: "🛡️ Center logos automatically elevate Error Correction to Level H (30%) for camera scannability."
                          color: Util.alpha(Color.popups.text || Color.text, 0.5)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          Layout.topMargin: Style.space(2)
                        }
                      }

                      // Subtab 2: Colors & Styling
                      ColumnLayout {
                        visible: root.activeLogoSubTab === 2
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        // 1. Badge Background Fill
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Badge Fill:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          Rectangle {
                            width: Style.space(12); height: Style.space(12); radius: 0
                            color: root.logoBgColor === "transparent" ? "transparent" : root.logoBgColor
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                          }

                          Repeater {
                            model: [
                              { col: root.qrBgColor, label: "Canvas" },
                              { col: "#FFFFFF", label: "White" },
                              { col: "#181825", label: "Dark" },
                              { col: "transparent", label: "Clear" }
                            ]

                            Rectangle {
                              id: bgQuickChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(18)
                              Layout.preferredWidth: bgQuickTxt.implicitWidth + Style.space(6)
                              radius: 0
                              color: root.logoBgColor === bgQuickChip.modelData.col ? Color.accent : (bgQuickM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: root.logoBgColor === bgQuickChip.modelData.col ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Text {
                                id: bgQuickTxt
                                anchors.centerIn: parent
                                text: bgQuickChip.modelData.label
                                color: root.logoBgColor === bgQuickChip.modelData.col ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: root.logoBgColor === bgQuickChip.modelData.col
                              }
                              MouseArea {
                                id: bgQuickM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoBgColor = bgQuickChip.modelData.col
                              }
                            }
                          }

                          // Custom Color Picker Button
                          Rectangle {
                            Layout.preferredHeight: Style.space(18)
                            Layout.preferredWidth: pickBgTxt.implicitWidth + Style.space(8)
                            radius: 0
                            color: logoBgPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.06)
                            border.width: 1; border.color: logoBgPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)
                            Row {
                              id: pickBgTxt
                              anchors.centerIn: parent; spacing: Style.space(2)
                              Text { text: "🎨"; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                              Text { text: "Custom Fill"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                              id: logoBgPickM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: { root.activeColorTarget = "logo_bg"; root.requestColorPicker("logo_bg", root.logoBgColor) }
                            }
                            PanelToolTip { visible: logoBgPickM.containsMouse; text: "Pick custom badge background color" }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // 2. Badge Border Color
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Border Color:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          Rectangle {
                            width: Style.space(12); height: Style.space(12); radius: 0
                            color: (root.logoBorderColor || root.qrOuterEyeColor || root.qrFgColor)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                          }

                          Repeater {
                            model: [
                              { col: root.qrOuterEyeColor, label: "Eye Color" },
                              { col: Color.accent || "#38BDF8", label: "Accent" },
                              { col: "#FFFFFF", label: "White" },
                              { col: "#181825", label: "Dark" }
                            ]

                            Rectangle {
                              id: brdColChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(18)
                              Layout.preferredWidth: brdColTxt.implicitWidth + Style.space(6)
                              radius: 0
                              color: root.logoBorderColor === brdColChip.modelData.col ? Color.accent : (brdColM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1; border.color: root.logoBorderColor === brdColChip.modelData.col ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Text {
                                id: brdColTxt
                                anchors.centerIn: parent
                                text: brdColChip.modelData.label
                                color: root.logoBorderColor === brdColChip.modelData.col ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: root.logoBorderColor === brdColChip.modelData.col
                              }
                              MouseArea {
                                id: brdColM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoBorderColor = brdColChip.modelData.col
                              }
                            }
                          }

                          // Custom Border Color Picker Button
                          Rectangle {
                            Layout.preferredHeight: Style.space(18)
                            Layout.preferredWidth: pickBrdTxt.implicitWidth + Style.space(8)
                            radius: 0
                            color: logoBrdPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.06)
                            border.width: 1; border.color: logoBrdPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)
                            Row {
                              id: pickBrdTxt
                              anchors.centerIn: parent; spacing: Style.space(2)
                              Text { text: "🎨"; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                              Text { text: "Custom Border"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                              id: logoBrdPickM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: { root.activeColorTarget = "logo_border"; root.requestColorPicker("logo_border", root.logoBorderColor || root.qrOuterEyeColor) }
                            }
                            PanelToolTip { visible: logoBrdPickM.containsMouse; text: "Pick custom badge border color" }
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // 3. Emblem Tint Color
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Text {
                            text: "Icon Tint:"
                            color: Util.alpha(Color.popups.text || Color.text, 0.75)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            Layout.preferredWidth: Style.space(65)
                          }

                          Rectangle {
                            width: Style.space(12); height: Style.space(12); radius: 0
                            color: (root.logoTintColor || root.qrFgColor)
                            border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.5)
                          }

                          Repeater {
                            model: [
                              { col: root.qrFgColor, label: "Modules FG" },
                              { col: Color.accent || "#38BDF8", label: "Accent" },
                              { col: "#FFFFFF", label: "White" },
                              { col: "#181825", label: "Dark" }
                            ]

                            Rectangle {
                              id: tintChip
                              required property var modelData
                              Layout.preferredHeight: Style.space(18)
                              Layout.preferredWidth: tintTxt.implicitWidth + Style.space(6)
                              radius: 0
                              color: (root.logoTintColor === tintChip.modelData.col || (!root.logoTintColor && tintChip.modelData.label === "Modules FG"))
                                     ? Color.accent
                                     : (tintM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                              border.width: 1
                              border.color: (root.logoTintColor === tintChip.modelData.col || (!root.logoTintColor && tintChip.modelData.label === "Modules FG"))
                                            ? Color.accent
                                            : Util.alpha(Color.popups.border || Color.border, 0.25)

                              Text {
                                id: tintTxt
                                anchors.centerIn: parent
                                text: tintChip.modelData.label
                                color: (root.logoTintColor === tintChip.modelData.col || (!root.logoTintColor && tintChip.modelData.label === "Modules FG")) ? "#ffffff" : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(6.5)
                                font.bold: root.logoTintColor === tintChip.modelData.col
                              }
                              MouseArea {
                                id: tintM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.logoTintColor = tintChip.modelData.col
                              }
                            }
                          }

                          // Custom Tint Color Picker Button
                          Rectangle {
                            Layout.preferredHeight: Style.space(18)
                            Layout.preferredWidth: pickTintTxt.implicitWidth + Style.space(8)
                            radius: 0
                            color: logoTintPickM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text || Color.text, 0.06)
                            border.width: 1; border.color: logoTintPickM.containsMouse ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)
                            Row {
                              id: pickTintTxt
                              anchors.centerIn: parent; spacing: Style.space(2)
                              Text { text: "🎨"; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                              Text { text: "Custom Tint"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                              id: logoTintPickM
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: { root.activeColorTarget = "logo_tint"; root.requestColorPicker("logo_tint", root.logoTintColor || root.qrFgColor) }
                            }
                            PanelToolTip { visible: logoTintPickM.containsMouse; text: "Pick custom emblem tint color" }
                          }

                          Item { Layout.fillWidth: true }
                        }
                      }
                    }
                  }
                }
              }
