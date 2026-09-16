import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

RowLayout {
  id: secFiles
  required property var modal
  readonly property var root: modal
  spacing: 0

            // -------------------------------------------------------------
            // LEFT COLUMN: FILE SHARING CONTROLS & SERVER SIDEBAR
            // -------------------------------------------------------------
            Rectangle {
              id: fileSidebar
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
                spacing: Style.space(5)

                // Section Title
                Text {
                  text: "FILE SHARING"
                  color: Util.alpha(Color.popups.text || Color.text, 0.45)
                  font.family: Style.font.fixedFamily || "monospace"
                  font.pixelSize: Style.space(6.5)
                  font.bold: true
                  Layout.leftMargin: Style.space(4)
                  Layout.topMargin: Style.space(2)
                  Layout.bottomMargin: Style.space(1)
                }

                // Add File(s) Button
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(22)
                  radius: 0
                  color: addFileM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                  border.width: 1
                  border.color: Color.accent

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "󰐕"
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: (root.fileShareList && root.fileShareList.length > 0) ? "Add File(s)..." : "Browse Files..."
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: addFileM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.browseFiles()
                  }
                  PanelToolTip {
                    visible: addFileM.containsMouse
                    text: "Select one or multiple files to share over local Wi-Fi"
                  }
                }

                // Add Folder Button
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(22)
                  radius: 0
                  color: addFolderM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                  border.width: 1
                  border.color: Color.accent

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "󰉋"
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Add Folder..."
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: addFolderM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.browseFolder()
                  }
                  PanelToolTip {
                    visible: addFolderM.containsMouse
                    text: "Select a whole folder to share recursively over local Wi-Fi"
                  }
                }

                // Clear All Button (Visible when files are present)
                Rectangle {
                  visible: Boolean(root.fileShareList && root.fileShareList.length > 0)
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(22)
                  radius: 0
                  color: clearAllM.containsMouse ? Util.alpha("#EF4444", 0.2) : Util.alpha(Color.popups.text || Color.text, 0.05)
                  border.width: 1
                  border.color: clearAllM.containsMouse ? "#EF4444" : Util.alpha(Color.popups.border || Color.border, 0.3)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text {
                      text: "✕"
                      color: clearAllM.containsMouse ? "#EF4444" : (Color.popups.text || Color.text)
                      font.pixelSize: Style.space(6.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Clear All"
                      color: clearAllM.containsMouse ? "#EF4444" : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(6.5)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: clearAllM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearFileShare()
                  }
                  PanelToolTip {
                    visible: clearAllM.containsMouse
                    text: "Clear all selected files and reset Wi-Fi sharing"
                  }
                }

                // Divider Line
                Rectangle {
                  Layout.fillWidth: true
                  height: 1
                  color: Util.alpha(Color.popups.border || Color.border, 0.2)
                }

                // Protection Transfer Key Card (Visible when running and PIN exists)
                ColumnLayout {
                  visible: root.fileShareRunning && root.fileSharePin.length > 0
                  Layout.fillWidth: true
                  spacing: Style.space(3)

                  Text {
                    text: "SECURITY KEY"
                    color: Util.alpha(Color.popups.text || Color.text, 0.45)
                    font.family: Style.font.fixedFamily || "monospace"
                    font.pixelSize: Style.space(6)
                    font.bold: true
                    Layout.leftMargin: Style.space(4)
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(26)
                    radius: 0
                    color: Util.alpha(Color.accent, 0.12)
                    border.width: 1
                    border.color: Color.accent

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(6)
                      spacing: Style.space(4)

                      Text {
                        text: "🔒"
                        font.pixelSize: Style.space(7)
                        Layout.alignment: Qt.AlignVCenter
                      }

                      Text {
                        text: root.fileSharePin
                        color: Color.accent
                        font.family: "monospace"
                        font.pixelSize: Style.space(9)
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                      }

                      // Copy PIN mini button
                      Rectangle {
                        Layout.preferredWidth: Style.space(18)
                        Layout.preferredHeight: Style.space(18)
                        radius: 0
                        color: copyPinM.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.popups.text || Color.text, 0.06)
                        border.width: 1
                        border.color: Util.alpha(Color.accent, 0.4)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                          anchors.centerIn: parent
                          text: "󰆏"
                          color: Color.accent
                          font.pixelSize: Style.space(6.5)
                        }

                        MouseArea {
                          id: copyPinM
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            var pin = root.fileSharePin
                            if (pin && pin.length > 0) {
                              Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(pin) + " | wl-copy"])
                            }
                            root.copiedText(pin)
                            root.showFeedback("✓ PIN " + pin + " copied")
                          }
                        }
                        PanelToolTip {
                          visible: copyPinM.containsMouse
                          text: "Copy 4-digit protection key"
                        }
                      }
                    }
                  }
                }

                // Options: Single Download Toggle
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(22)
                  radius: 0
                  color: root.fileShareSingleShot
                         ? Util.alpha(Color.accent, 0.15)
                         : (singleShotM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")
                  border.width: 1
                  border.color: root.fileShareSingleShot ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: root.fileShareSingleShot ? "󰄲" : "󰄱"
                      color: root.fileShareSingleShot ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.6)
                      font.pixelSize: Style.space(7)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Single Download"
                      color: root.fileShareSingleShot ? (Color.popups.text || Color.text) : Util.alpha(Color.popups.text || Color.text, 0.7)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(6.5)
                      font.bold: root.fileShareSingleShot
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: singleShotM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.fileShareSingleShot = !root.fileShareSingleShot
                      if (root.fileShareList && root.fileShareList.length > 0 && root.fileShareRunning) {
                        root.startFileShareList(root.fileShareList)
                      }
                    }
                  }
                  PanelToolTip {
                    visible: singleShotM.containsMouse
                    text: "Automatically shut down local server after download completes"
                  }
                }

                // Copy Link Button (Visible when URL is available)
                Rectangle {
                  visible: root.fileShareUrl.length > 0
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(22)
                  radius: 0
                  color: copyUrlM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text {
                      text: "󰆏"
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(6.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Copy Link"
                      color: Color.popups.text || Color.text
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(6.5)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: copyUrlM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var targetUrl = root.fileShareUrl
                      if (targetUrl && targetUrl.length > 0) {
                        Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(targetUrl) + " | wl-copy"])
                      }
                      root.copiedText(targetUrl)
                      root.showFeedback("✓ Wi-Fi download link copied to clipboard")
                    }
                  }
                  PanelToolTip {
                    visible: copyUrlM.containsMouse
                    text: root.fileShareUrl
                  }
                }

                Item { Layout.fillHeight: true }

                // Server Daemon Status Indicator & Toggle
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(3)

                  // Status Pill
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(20)
                    radius: 0
                    color: root.fileShareStatus === "completed"
                           ? Util.alpha("#10B981", 0.15)
                           : (root.fileShareStatus === "downloading" ? Util.alpha("#F59E0B", 0.2) : (root.fileShareRunning ? Util.alpha(Color.accent, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.04)))
                    border.width: 1
                    border.color: root.fileShareStatus === "completed"
                                  ? "#10B981"
                                  : (root.fileShareStatus === "downloading" ? "#F59E0B" : (root.fileShareRunning ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)))

                    Row {
                      anchors.centerIn: parent
                      spacing: Style.space(3)
                      Text {
                        text: root.fileShareStatus === "completed" ? "✓" : (root.fileShareStatus === "downloading" ? "󰑮" : (root.fileShareRunning ? "●" : "○"))
                        color: root.fileShareStatus === "completed"
                               ? "#10B981"
                               : (root.fileShareStatus === "downloading" ? "#F59E0B" : (root.fileShareRunning ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.4)))
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: root.fileShareStatus === "completed"
                              ? "Transfer Done"
                              : (root.fileShareStatus === "downloading" ? "Downloading..." : (root.fileShareRunning ? "Live on LAN" : "Server Idle"))
                        color: root.fileShareStatus === "completed"
                               ? "#10B981"
                               : (root.fileShareStatus === "downloading" ? "#F59E0B" : (root.fileShareRunning ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.6)))
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }

                  // Start / Stop Micro-Server Button
                  Rectangle {
                    visible: Boolean(root.fileShareList && root.fileShareList.length > 0)
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(22)
                    radius: 0
                    color: root.fileShareRunning
                           ? (servToggleM.containsMouse ? Util.alpha("#EF4444", 0.25) : Util.alpha("#EF4444", 0.12))
                           : (servToggleM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12))
                    border.width: 1
                    border.color: root.fileShareRunning ? "#EF4444" : Color.accent

                    Row {
                      anchors.centerIn: parent
                      spacing: Style.space(3)
                      Text {
                        text: root.fileShareRunning ? "✕" : "▶"
                        color: root.fileShareRunning ? "#EF4444" : Color.accent
                        font.pixelSize: Style.space(6.5)
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: root.fileShareRunning ? "Stop Server" : "Start Server"
                        color: root.fileShareRunning ? "#EF4444" : Color.accent
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    MouseArea {
                      id: servToggleM
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.fileShareRunning) root.stopFileShare()
                        else root.startFileShareList(root.fileShareList)
                      }
                    }
                    PanelToolTip {
                      visible: servToggleM.containsMouse
                      text: root.fileShareRunning ? "Stop the local micro-server" : "Restart Wi-Fi file share server"
                    }
                  }
                }
              }
            }

            // -------------------------------------------------------------
            // RIGHT COLUMN: FILE WORKSPACE, QUEUE, & TRANSFER PROGRESS
            // -------------------------------------------------------------
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                // Main Content: Empty Drop Zone OR Scrollable Files List
                Rectangle {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: 0
                  color: fileDropArea.containsDrag
                         ? Util.alpha(Color.accent, 0.15)
                         : ((root.fileShareList && root.fileShareList.length > 0) ? Util.alpha(Color.popups.text || Color.text, 0.03) : Util.alpha(Color.popups.text || Color.text, 0.02))
                  border.width: fileDropArea.containsDrag ? 2 : 1
                  border.color: fileDropArea.containsDrag
                                ? Color.accent
                                : ((root.fileShareList && root.fileShareList.length > 0) ? Util.alpha(Color.accent, 0.35) : Util.alpha(Color.popups.border || Color.border, 0.3))

                  DropArea {
                    id: fileDropArea
                    anchors.fill: parent
                    onEntered: function(drag) {
                      if (drag.hasUrls) drag.acceptProposedAction()
                    }
                    onDropped: function(drop) {
                      if (drop.hasUrls && drop.urls.length > 0) {
                        var list = []
                        for (var i = 0; i < drop.urls.length; i++) {
                          var u = drop.urls[i].toString()
                          if (u.startsWith("file://")) u = decodeURIComponent(u.substring(7))
                          list.push(u)
                        }
                        root.addFileSharePaths(list)
                        drop.acceptProposedAction()
                      }
                    }
                  }

                  // State A: Empty Drop Placeholder
                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(6)
                    visible: !root.fileShareList || root.fileShareList.length === 0

                    Text {
                      text: "󰉋"
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(24)
                      anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                      text: "Drop file(s) or folder(s) here"
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                      text: "or select files to share over local Wi-Fi"
                      color: Util.alpha(Color.popups.text || Color.text, 0.5)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(6.5)
                      anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: Style.space(8)

                      Rectangle {
                        height: Style.space(22)
                        width: dropBrowseFileRow.implicitWidth + Style.space(16)
                        radius: 0
                        color: dropBrowseFileM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                        border.width: 1
                        border.color: Color.accent

                        Row {
                          id: dropBrowseFileRow
                          anchors.centerIn: parent
                          spacing: Style.space(4)
                          Text {
                            text: "󰐕"
                            color: Color.accent
                            font.pixelSize: Style.space(7)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          Text {
                            text: "Add File(s)..."
                            color: Color.accent
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(6.5)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }

                        MouseArea {
                          id: dropBrowseFileM
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.browseFiles()
                        }
                      }

                      Rectangle {
                        height: Style.space(22)
                        width: dropBrowseFolderRow.implicitWidth + Style.space(16)
                        radius: 0
                        color: dropBrowseFolderM.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                        border.width: 1
                        border.color: Color.accent

                        Row {
                          id: dropBrowseFolderRow
                          anchors.centerIn: parent
                          spacing: Style.space(4)
                          Text {
                            text: "󰉋"
                            color: Color.accent
                            font.pixelSize: Style.space(7)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          Text {
                            text: "Add Folder..."
                            color: Color.accent
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(6.5)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }

                        MouseArea {
                          id: dropBrowseFolderM
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.browseFolder()
                        }
                      }
                    }
                  }

                  // State B: Active Selected Files List
                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(4)
                    visible: Boolean(root.fileShareList && root.fileShareList.length > 0)

                    // Header
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        text: "Files to Share (" + (root.fileShareList ? root.fileShareList.length : 0) + "):"
                        color: Color.accent
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                        font.bold: true
                      }

                      Text {
                        text: (root.fileShareList && root.fileShareList.length === 1)
                              ? (root.fileShareSizeStr ? ("· " + root.fileShareSizeStr) : "")
                              : (root.fileShareTotalSizeStr ? ("· " + root.fileShareTotalSizeStr + " total") : "")
                        color: Util.alpha(Color.popups.text || Color.text, 0.6)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                      }

                      Item { Layout.fillWidth: true }

                      Text {
                        text: "Drag & drop more files anytime"
                        color: Util.alpha(Color.popups.text || Color.text, 0.4)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6)
                      }
                    }

                    // Scrollable List of Files
                    ScrollView {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      clip: true

                      ColumnLayout {
                        width: parent.width
                        spacing: Style.space(3)

                        Repeater {
                          model: root.fileShareList

                          Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(26)
                            radius: 0
                            color: fileItemM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : Util.alpha(Color.popups.text || Color.text, 0.03)
                            border.width: 1
                            border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

                            RowLayout {
                              anchors.fill: parent
                              anchors.leftMargin: Style.space(6)
                              anchors.rightMargin: Style.space(6)
                              spacing: Style.space(6)

                              Text {
                                property var itemMeta: root.getFileShareItemMeta(index, modelData)
                                text: (itemMeta && itemMeta.is_dir) ? "󰉋" : "󰈔"
                                color: (itemMeta && itemMeta.is_dir) ? Color.accent : (Color.popups.text || Color.text)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(9)
                                Layout.alignment: Qt.AlignVCenter
                              }

                              // Filename
                              Text {
                                property var itemMeta: root.getFileShareItemMeta(index, modelData)
                                text: itemMeta.name || (modelData ? modelData.split("/").pop() : "")
                                color: Color.popups.text || Color.text
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.space(7)
                                font.bold: true
                                elide: Text.ElideMiddle
                                Layout.preferredWidth: Style.space(130)
                                Layout.alignment: Qt.AlignVCenter
                              }

                              // Folder Items Count Badge
                              Rectangle {
                                property var itemMeta: root.getFileShareItemMeta(index, modelData)
                                visible: Boolean(itemMeta && itemMeta.is_dir && itemMeta.file_count > 0)
                                height: Style.space(14)
                                width: folderCountTxt.implicitWidth + Style.space(6)
                                radius: 0
                                color: Util.alpha(Color.accent, 0.2)
                                border.width: 1
                                border.color: Color.accent
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                  id: folderCountTxt
                                  anchors.centerIn: parent
                                  text: parent.itemMeta ? (parent.itemMeta.file_count + " items") : ""
                                  color: Color.accent
                                  font.family: "monospace"
                                  font.pixelSize: Style.space(5.5)
                                  font.bold: true
                                }
                              }

                              // File Size Badge
                              Rectangle {
                                property var itemMeta: root.getFileShareItemMeta(index, modelData)
                                visible: Boolean(itemMeta.size_str && itemMeta.size_str.length > 0)
                                height: Style.space(14)
                                width: itemSizeTxt.implicitWidth + Style.space(6)
                                radius: 0
                                color: Util.alpha(Color.accent, 0.12)
                                border.width: 1
                                border.color: Util.alpha(Color.accent, 0.3)
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                  id: itemSizeTxt
                                  anchors.centerIn: parent
                                  text: parent.itemMeta ? parent.itemMeta.size_str : ""
                                  color: Color.accent
                                  font.family: "monospace"
                                  font.pixelSize: Style.space(5.5)
                                  font.bold: true
                                }
                              }

                              // Path preview
                              Text {
                                text: modelData
                                color: Util.alpha(Color.popups.text || Color.text, 0.4)
                                font.family: Style.font.fixedFamily || "monospace"
                                font.pixelSize: Style.space(6)
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                              }

                              // Remove File Button
                              Rectangle {
                                Layout.preferredWidth: Style.space(16)
                                Layout.preferredHeight: Style.space(16)
                                radius: 0
                                color: removeBtnM.containsMouse ? Util.alpha("#EF4444", 0.25) : "transparent"
                                border.width: removeBtnM.containsMouse ? 1 : 0
                                border.color: "#EF4444"
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                  anchors.centerIn: parent
                                  text: "✕"
                                  color: removeBtnM.containsMouse ? "#EF4444" : Util.alpha(Color.popups.text || Color.text, 0.45)
                                  font.pixelSize: Style.space(6)
                                  font.bold: true
                                }

                                MouseArea {
                                  id: removeBtnM
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: root.removeFileSharePath(index)
                                }
                                PanelToolTip {
                                  visible: removeBtnM.containsMouse
                                  text: "Remove this file from share list"
                                }
                              }
                            }

                            MouseArea {
                              id: fileItemM
                              anchors.fill: parent
                              hoverEnabled: true
                              acceptedButtons: Qt.NoButton
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // Live Transfer Progress & Speedometer Widget
                Rectangle {
                  visible: root.fileShareTransferring || (root.fileShareProgress > 0 && (root.fileShareStatus === "downloading" || root.fileShareStatus === "uploading"))
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(30)
                  radius: 0
                  color: Util.alpha(Color.popups.text || Color.text, 0.04)
                  border.width: 1
                  border.color: root.fileShareTransferType === "upload" ? Util.alpha("#34D399", 0.4) : Util.alpha(Color.accent, 0.4)

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    anchors.topMargin: Style.space(4)
                    anchors.bottomMargin: Style.space(4)
                    spacing: Style.space(3)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(4)

                      Text {
                        text: root.fileShareTransferType === "upload" ? "󰐕 Uploading to PC" : "󰇚 Downloading from PC"
                        color: root.fileShareTransferType === "upload" ? "#34D399" : Color.accent
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                      }

                      Text {
                        text: root.fileShareTransferFile ? ("· " + root.fileShareTransferFile) : ""
                        color: Util.alpha(Color.popups.text || Color.text, 0.7)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                      }

                      Text {
                        text: root.fileShareSpeedStr ? (root.fileShareSpeedStr + (root.fileShareEtaStr ? (" · ETA " + root.fileShareEtaStr) : "")) : ""
                        color: Color.popups.text || Color.text
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                      }

                      Text {
                        text: Math.round(root.fileShareProgress * 100) + "%"
                        color: root.fileShareTransferType === "upload" ? "#34D399" : Color.accent
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                      }
                    }

                    // Progress Track & Fill
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(4)
                      radius: 0
                      color: Util.alpha(Color.popups.text || Color.text, 0.1)

                      Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0.0, Math.min(1.0, root.fileShareProgress))
                        radius: 0
                        color: root.fileShareTransferType === "upload" ? "#34D399" : Color.accent
                        Behavior on width {
                          NumberAnimation { duration: 150 }
                        }
                      }
                    }
                  }
                }

                // Live Transfer Notification Banner
                Rectangle {
                  visible: root.fileShareStatusMsg.length > 0
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(22)
                  radius: 0
                  color: root.fileShareStatus === "completed"
                         ? Util.alpha("#10B981", 0.12)
                         : (root.fileShareStatus === "downloading" ? Util.alpha("#F59E0B", 0.15) : Util.alpha(Color.accent, 0.08))
                  border.width: 1
                  border.color: root.fileShareStatus === "completed"
                                ? "#10B981"
                                : (root.fileShareStatus === "downloading" ? "#F59E0B" : Util.alpha(Color.accent, 0.3))

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(4)

                    Text {
                      text: root.fileShareStatus === "completed" ? "✓" : (root.fileShareStatus === "downloading" ? "󰑮" : "ℹ")
                      color: root.fileShareStatus === "completed"
                             ? "#10B981"
                             : (root.fileShareStatus === "downloading" ? "#F59E0B" : Color.accent)
                      font.pixelSize: Style.space(7.5)
                      font.bold: true
                      Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                      text: root.fileShareStatusMsg
                      color: Color.popups.text || Color.text
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7)
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                      visible: root.fileShareRunning
                      text: "Scan QR with Phone"
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(6.5)
                      font.bold: true
                      Layout.alignment: Qt.AlignVCenter
                    }
                  }
                }
              }
            }
          }
