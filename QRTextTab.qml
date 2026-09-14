import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

RowLayout {
  id: sec3
  required property var modal
  readonly property var root: modal
  property alias qrTextInput: qrTextInput
  spacing: 0

                // -------------------------------------------------------------
                // LEFT COLUMN: PAYLOAD TYPE SIDEBAR
                // -------------------------------------------------------------
                Rectangle {
                  id: textSidebar
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
                    spacing: Style.space(3)

                    // Sidebar Section Title
                    Text {
                      text: "PAYLOAD TYPE"
                      color: Util.alpha(Color.popups.text || Color.text, 0.45)
                      font.family: Style.font.fixedFamily || "monospace"
                      font.pixelSize: Style.space(6.5)
                      font.bold: true
                      Layout.leftMargin: Style.space(4)
                      Layout.topMargin: Style.space(2)
                      Layout.bottomMargin: Style.space(1)
                    }

                    // Vertical Navigation Tabs
                    Repeater {
                      model: [
                        { id: "text", icon: "󰈙", label: "Plain Text" },
                        { id: "url", icon: "󰌹", label: "Web URL" },
                        { id: "wifi", icon: "󰖩", label: "Wi-Fi Network" },
                        { id: "event", icon: "󰸗", label: "Calendar Event" },
                        { id: "geo", icon: "󰍎", label: "Geo Location" },
                        { id: "vcard", icon: "󰋾", label: "Contact Card" },
                        { id: "email", icon: "󰇮", label: "Email Draft" },
                        { id: "sms", icon: "󰍡", label: "SMS Message" }
                      ]

                      Rectangle {
                        id: payChip
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(20)
                        radius: 0
                        color: root.payloadType === payChip.modelData.id
                               ? Util.alpha(Color.accent, 0.16)
                               : (payTypeM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.07) : "transparent")
                        border.width: 1
                        border.color: root.payloadType === payChip.modelData.id
                                      ? Util.alpha(Color.accent, 0.6)
                                      : (payTypeM.containsMouse ? Util.alpha(Color.popups.border || Color.border, 0.2) : "transparent")

                        // Active Indicator Bar on Left Edge
                        Rectangle {
                          width: Style.space(2.5)
                          height: parent.height
                          anchors.left: parent.left
                          color: Color.accent
                          visible: root.payloadType === payChip.modelData.id
                        }

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(7)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(4)

                          Text {
                            text: payChip.modelData.icon
                            color: root.payloadType === payChip.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7.5)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Text {
                            text: payChip.modelData.label
                            color: root.payloadType === payChip.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(6.8)
                            font.bold: root.payloadType === payChip.modelData.id
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                          }
                        }

                        MouseArea {
                          id: payTypeM
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.payloadType = payChip.modelData.id
                            root.updatePayloadText()
                          }
                        }
                      }
                    }

                    Item { Layout.fillHeight: true }

                    // Divider
                    Rectangle {
                      Layout.fillWidth: true
                      height: 1
                      color: Util.alpha(Color.popups.border || Color.border, 0.2)
                    }

                    // Bottom Action 1: Paste from Clipboard
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(22)
                      radius: 0
                      color: pasteBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.popups.text || Color.text, 0.05)
                      border.width: 1
                      border.color: pasteBtnMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(4)
                        Text {
                          text: "󰅌"
                          color: pasteBtnMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: "Paste Clipboard"
                          color: pasteBtnMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }

                      MouseArea {
                        id: pasteBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pasteProc.running = true
                      }
                      PanelToolTip { visible: pasteBtnMouse.containsMouse; text: "Paste clipboard text into generator" }
                    }

                    // Bottom Action 2: Clear Fields
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(22)
                      radius: 0
                      color: clearBtnMouse.containsMouse ? Util.alpha("#EF4444", 0.2) : Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1
                      border.color: clearBtnMouse.containsMouse ? "#EF4444" : Util.alpha(Color.popups.border || Color.border, 0.25)

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(3)
                        Text { text: "✕"; color: clearBtnMouse.containsMouse ? "#EF4444" : (Color.popups.text || Color.text); font.pixelSize: Style.space(6.5); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                          text: "Clear Fields"
                          color: clearBtnMouse.containsMouse ? "#EF4444" : (Color.popups.text || Color.text)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(6.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }

                      MouseArea {
                        id: clearBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.textToEncode = ""
                          if (qrTextInput) qrTextInput.text = ""
                          root.wifiSsid = ""
                          root.wifiPassword = ""
                          root.vcardFirstName = ""
                          root.vcardLastName = ""
                          root.vcardPhone = ""
                          root.vcardEmail = ""
                          root.vcardOrg = ""
                          root.vcardTitle = ""
                          root.vcardUrl = ""
                          root.urlHost = ""
                          root.urlUtmSource = ""
                          root.urlUtmMedium = ""
                          root.urlUtmCampaign = ""
                          root.emailTo = ""
                          root.emailSubject = ""
                          root.emailBody = ""
                          root.smsPhone = ""
                          root.smsMessage = ""
                          root.geoLat = ""
                          root.geoLon = ""
                          root.geoQuery = ""
                          root.eventTitle = ""
                          root.eventLocation = ""
                          root.eventDescription = ""
                          root.eventStart = ""
                          root.eventEnd = ""
                          root.clearFileShare()
                          qrImage.source = ""
                        }
                      }
                      PanelToolTip { visible: clearBtnMouse.containsMouse; text: "Clear input text and builder fields" }
                    }
                  }
                }

                // -------------------------------------------------------------
                // RIGHT COLUMN: ACTIVE PAYLOAD WORKSPACE / FORMS
                // -------------------------------------------------------------
                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  clip: true

                  ScrollView {
                    anchors.fill: parent
                    clip: true

                    Item {
                      width: parent.width
                      implicitHeight: root.payloadType === "text" ? Math.max(qrTextInput.implicitHeight, Style.space(180)) : (builderCol.implicitHeight + Style.space(20))

                      // Mode 0: Raw Text Editor
                      TextArea {
                        id: qrTextInput
                        visible: root.payloadType === "text"
                        anchors.fill: parent
                        text: root.textToEncode
                        placeholderText: "Type, paste, or edit any link, snippet, or text here to generate QR code live..."
                        placeholderTextColor: Util.alpha(Color.popups.text || Color.text, 0.35)
                        color: Color.popups.text || Color.text
                        font.family: Style.font.fixedFamily || "monospace"
                        font.pixelSize: Style.space(9)
                        wrapMode: Text.WrapAnywhere
                        selectByMouse: true
                        background: null
                        leftPadding: Style.space(12)
                        rightPadding: Style.space(12)
                        topPadding: Style.space(10)
                        bottomPadding: Style.space(10)

                        onTextChanged: {
                          if (root.payloadType === "text" && !root.isSyncingPayload && root.textToEncode !== text) {
                            root.textToEncode = text
                            qrDebounceTimer.restart()
                          }
                        }
                      }

                ColumnLayout {
                  id: builderCol
                  visible: root.payloadType !== "text"
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  // 1. Wi-Fi Form
                  ColumnLayout {
                    visible: root.payloadType === "wifi"
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        text: "Network SSID:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.75)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.5)
                        font.bold: true
                        Layout.preferredWidth: Style.space(85)
                      }

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(24)
                        radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.05)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

                        TextInput {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                          text: root.wifiSsid
                          color: Color.popups.text || Color.text
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: {
                            root.wifiSsid = text
                            root.updatePayloadText()
                          }
                        }
                      }

                      // Security Selection
                      Repeater {
                        model: [
                          { id: "WPA", label: "WPA2/3" },
                          { id: "WEP", label: "WEP" },
                          { id: "nopass", label: "Open" }
                        ]

                        Rectangle {
                          id: secPill
                          required property var modelData
                          Layout.preferredHeight: Style.space(24)
                          Layout.preferredWidth: wifiSecTxt.implicitWidth + Style.space(10)
                          radius: 0
                          color: root.wifiEnc === secPill.modelData.id ? Color.accent : (wSecM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                          border.width: 1; border.color: root.wifiEnc === secPill.modelData.id ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)

                          Text {
                            id: wifiSecTxt
                            anchors.centerIn: parent
                            text: secPill.modelData.label
                            color: root.wifiEnc === secPill.modelData.id ? "#ffffff" : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(7)
                            font.bold: root.wifiEnc === secPill.modelData.id
                          }
                          MouseArea {
                            id: wSecM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.wifiEnc = secPill.modelData.id
                              root.updatePayloadText()
                            }
                          }
                        }
                      }

                      // Hidden Network Pill
                      Rectangle {
                        Layout.preferredHeight: Style.space(24)
                        Layout.preferredWidth: wifiHidTxt.implicitWidth + Style.space(10)
                        radius: 0
                        color: root.wifiHidden ? Color.accent : (wHidM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : Util.alpha(Color.popups.text || Color.text, 0.04))
                        border.width: 1; border.color: root.wifiHidden ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)

                        Text {
                          id: wifiHidTxt
                          anchors.centerIn: parent
                          text: root.wifiHidden ? "󰘔 Hidden" : "󰘔 Broadcast"
                          color: root.wifiHidden ? "#ffffff" : (Color.popups.text || Color.text)
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7)
                          font.bold: root.wifiHidden
                        }
                        MouseArea {
                          id: wHidM
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.wifiHidden = !root.wifiHidden
                            root.updatePayloadText()
                          }
                        }
                      }
                    }

                    // Password Row
                    RowLayout {
                      visible: root.wifiEnc !== "nopass"
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        text: "Password:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.75)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7.5)
                        font.bold: true
                        Layout.preferredWidth: Style.space(85)
                      }

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(24)
                        radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.05)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

                        TextInput {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                          text: root.wifiPassword
                          echoMode: root.wifiShowPass ? TextInput.Normal : TextInput.Password
                          color: Color.popups.text || Color.text
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(7.5)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: {
                            root.wifiPassword = text
                            root.updatePayloadText()
                          }
                        }
                      }

                      Rectangle {
                        Layout.preferredHeight: Style.space(24)
                        Layout.preferredWidth: Style.space(28)
                        radius: 0
                        color: wEyeM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                        Text {
                          anchors.centerIn: parent
                          text: root.wifiShowPass ? "󰈈" : "󰈉"
                          color: Color.popups.text || Color.text
                          font.pixelSize: Style.space(8.5)
                        }
                        MouseArea {
                          id: wEyeM
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.wifiShowPass = !root.wifiShowPass
                        }
                        PanelToolTip { visible: wEyeM.containsMouse; text: root.wifiShowPass ? "Hide password" : "Show password" }
                      }
                    }
                  }

                  // 2. URL Form
                  ColumnLayout {
                    visible: root.payloadType === "url"
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.preferredHeight: Style.space(24)
                        Layout.preferredWidth: Style.space(60)
                        radius: 0
                        color: protoM.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.accent, 0.1)
                        border.width: 1; border.color: Color.accent

                        Text {
                          anchors.centerIn: parent
                          text: root.urlProtocol
                          color: Color.accent
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.space(7.5)
                          font.bold: true
                        }
                        MouseArea {
                          id: protoM
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.urlProtocol = (root.urlProtocol === "https://") ? "http://" : "https://"
                            root.updatePayloadText()
                          }
                        }
                        PanelToolTip { visible: protoM.containsMouse; text: "Toggle https:// or http://" }
                      }

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(24)
                        radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.05)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

                        TextInput {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                          text: root.urlHost
                          color: Color.popups.text || Color.text
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(7.5)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: {
                            root.urlHost = text
                            root.updatePayloadText()
                          }
                        }
                        Text {
                          visible: !root.urlHost
                          anchors.fill: parent; anchors.leftMargin: Style.space(6)
                          text: "example.com/landing-page"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35)
                          font.family: Style.font.fixedFamily || "monospace"
                          font.pixelSize: Style.space(7.5)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    // UTM Tags Row
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        text: "UTM Tags:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.65)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(7)
                        Layout.preferredWidth: Style.space(60)
                      }

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(22)
                        radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.urlUtmSource
                          color: Color.popups.text || Color.text
                          font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.urlUtmSource = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.urlUtmSource
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Source (e.g. qr)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.3)
                          font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(22)
                        radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.urlUtmMedium
                          color: Color.popups.text || Color.text
                          font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.urlUtmMedium = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.urlUtmMedium
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Medium (e.g. print)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.3)
                          font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(22)
                        radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.urlUtmCampaign
                          color: Color.popups.text || Color.text
                          font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.urlUtmCampaign = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.urlUtmCampaign
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Campaign (e.g. promo)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.3)
                          font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }
                  }

                  // 3. Contact (vCard) Form
                  ColumnLayout {
                    visible: root.payloadType === "vcard"
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardFirstName
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardFirstName = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardFirstName
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "First Name"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardLastName
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardLastName = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardLastName
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Last Name"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardPhone
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardPhone = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardPhone
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Phone Number"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardEmail
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardEmail = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardEmail
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Email"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardOrg
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardOrg = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardOrg
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Organization"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardTitle
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardTitle = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardTitle
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Job Title"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.vcardUrl
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.vcardUrl = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.vcardUrl
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Website URL (https://...)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }
                  }

                  // 4. Email Form
                  ColumnLayout {
                    visible: root.payloadType === "email"
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.emailTo
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.emailTo = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.emailTo
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "To: user@example.com"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.emailSubject
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.emailSubject = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.emailSubject
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Subject line"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    Rectangle {
                      Layout.fillWidth: true; Layout.preferredHeight: Style.space(38); radius: 0
                      color: Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                      TextArea {
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                        text: root.emailBody
                        color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                        wrapMode: Text.WrapAnywhere
                        background: null
                        onTextChanged: {
                          if (root.emailBody !== text) {
                            root.emailBody = text
                            root.updatePayloadText()
                          }
                        }
                      }
                      Text {
                        visible: !root.emailBody
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.topMargin: Style.space(4)
                        text: "Pre-filled Email Body message..."
                        color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                      }
                    }
                  }

                  // 5. SMS Form
                  ColumnLayout {
                    visible: root.payloadType === "sms"
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.smsPhone
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.smsPhone = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.smsPhone
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Phone Number (+1...)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    Rectangle {
                      Layout.fillWidth: true; Layout.preferredHeight: Style.space(38); radius: 0
                      color: Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                      TextArea {
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                        text: root.smsMessage
                        color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                        wrapMode: Text.WrapAnywhere
                        background: null
                        onTextChanged: {
                          if (root.smsMessage !== text) {
                            root.smsMessage = text
                            root.updatePayloadText()
                          }
                        }
                      }
                      Text {
                        visible: !root.smsMessage
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.topMargin: Style.space(4)
                        text: "Pre-filled SMS text message..."
                        color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                      }
                    }
                  }

                  // 6. Geo Location Coordinates Form
                  ColumnLayout {
                    visible: root.payloadType === "geo"
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.geoLat
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.geoLat = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.geoLat
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Latitude (e.g. 37.7749)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.geoLon
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.geoLon = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.geoLon
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Longitude (e.g. -122.4194)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    Rectangle {
                      Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                      color: Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                      TextInput {
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                        text: root.geoQuery
                        color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                        verticalAlignment: TextInput.AlignVCenter
                        onTextEdited: { root.geoQuery = text; root.updatePayloadText() }
                      }
                      Text {
                        visible: !root.geoQuery
                        anchors.fill: parent; anchors.leftMargin: Style.space(4)
                        text: "Location Query / Place Name (optional, e.g. San Francisco)"
                        color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                        verticalAlignment: Text.AlignVCenter
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(4)

                      Text {
                        text: "Quick:"
                        color: Util.alpha(Color.popups.text || Color.text, 0.5)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                      }

                      Repeater {
                        model: [
                          { name: "San Francisco", lat: "37.7749", lon: "-122.4194" },
                          { name: "London", lat: "51.5074", lon: "-0.1278" },
                          { name: "Tokyo", lat: "35.6762", lon: "139.6503" },
                          { name: "New York", lat: "40.7128", lon: "-74.0060" }
                        ]

                        Rectangle {
                          id: geoChip
                          required property var modelData
                          Layout.preferredHeight: Style.space(18)
                          Layout.preferredWidth: geoChipTxt.implicitWidth + Style.space(8)
                          radius: 0
                          color: geoChipM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04)
                          border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

                          Text {
                            id: geoChipTxt
                            anchors.centerIn: parent
                            text: geoChip.modelData.name
                            color: (root.geoLat === geoChip.modelData.lat && root.geoLon === geoChip.modelData.lon) ? Color.accent : (Color.popups.text || Color.text)
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.space(6.5)
                            font.bold: (root.geoLat === geoChip.modelData.lat && root.geoLon === geoChip.modelData.lon)
                          }

                          MouseArea {
                            id: geoChipM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.geoLat = geoChip.modelData.lat
                              root.geoLon = geoChip.modelData.lon
                              root.geoQuery = geoChip.modelData.name
                              root.updatePayloadText()
                            }
                          }
                        }
                      }
                      Item { Layout.fillWidth: true }
                    }
                  }

                  // 7. Calendar Event (VEVENT) Form
                  ColumnLayout {
                    visible: root.payloadType === "event"
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.eventTitle
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.eventTitle = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.eventTitle
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Event Title (e.g. Omarchy Meetup)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.eventLocation
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.eventLocation = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.eventLocation
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Location / Room (e.g. Discord / Room 404)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.eventStart
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.eventStart = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.eventStart
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "Start (YYYY-MM-DD HH:MM)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }

                      Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Style.space(22); radius: 0
                        color: Util.alpha(Color.popups.text || Color.text, 0.04)
                        border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                        TextInput {
                          anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                          text: root.eventEnd
                          color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: TextInput.AlignVCenter
                          onTextEdited: { root.eventEnd = text; root.updatePayloadText() }
                        }
                        Text {
                          visible: !root.eventEnd
                          anchors.fill: parent; anchors.leftMargin: Style.space(4)
                          text: "End (YYYY-MM-DD HH:MM)"
                          color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }

                    Rectangle {
                      Layout.fillWidth: true; Layout.preferredHeight: Style.space(38); radius: 0
                      color: Util.alpha(Color.popups.text || Color.text, 0.04)
                      border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
                      TextArea {
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.rightMargin: Style.space(4)
                        text: root.eventDescription
                        color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                        wrapMode: Text.WrapAnywhere
                        background: null
                        onTextChanged: {
                          if (root.eventDescription !== text) {
                            root.eventDescription = text
                            root.updatePayloadText()
                          }
                        }
                      }
                      Text {
                        visible: !root.eventDescription
                        anchors.fill: parent; anchors.leftMargin: Style.space(4); anchors.topMargin: Style.space(4)
                        text: "Event notes & agenda description..."
                        color: Util.alpha(Color.popups.text || Color.text, 0.35); font.family: Style.font.menuFamily; font.pixelSize: Style.space(7)
                      }
                    }
                  }

                }
                }
              }
            }
          }
