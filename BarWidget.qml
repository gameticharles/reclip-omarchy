import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "reclip"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property int historyCount: panelLoader.item ? panelLoader.item.historyCount : 0
  readonly property bool incognito: panelLoader.item ? panelLoader.item.incognito === true : false

  function open(payload) {
    if (panelLoader.item) panelLoader.item.open(payload)
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "reclip"

    function open(payloadJson: string) {
      var p = {}
      try { if (payloadJson) p = JSON.parse(payloadJson) } catch (e) {}
      root.open(p)
    }
    function close() { root.close() }
    function show(payloadJson: string) { open(payloadJson) }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function colorStudio(subTabStr: string) {
      var sTab = 0
      if (subTabStr) {
        var n = parseInt(subTabStr)
        if (!isNaN(n)) sTab = n
      }
      root.open({ tab: 3, subTab: sTab })
    }
    function incognito() {
      if (panelLoader.item) panelLoader.item.toggleIncognito()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅍"
    tooltipText: root.incognito ? "ReClip (Incognito: Paused)" : "ReClip Clipboard & Snippets"
    active: root.opened || root.incognito
    activeColor: root.incognito ? Color.urgent : Color.accent

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (panelLoader.item) panelLoader.item.toggleIncognito()
      } else {
        root.toggle()
      }
    }

    Rectangle {
      visible: root.incognito
      width: Style.space(6)
      height: Style.space(6)
      radius: Style.space(3)
      color: Color.urgent
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: Style.space(3)
    }
  }
}
