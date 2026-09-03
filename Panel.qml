import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "lib/ClipboardHistory.js" as ClipboardHistory
import "lib/SnippetLibrary.js" as SnippetLib
import "lib/SyntaxHighlight.js" as Syntax

Panel {
  id: root
  moduleName: "reclip"
  ipcTarget: "reclip"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property string home: Quickshell.env("HOME")
  property string stateDir: home + "/.local/state/reclip"
  property string historyPath: stateDir + "/clipboard-history.json"
  property string snippetsPath: stateDir + "/snippets.json"
  property string incognitoPath: stateDir + "/incognito"
  property string pluginDir: home + "/.config/omarchy/plugins/reclip"
  property string captureScript: pluginDir + "/capture.sh"

  property bool incognito: false
  property int activeTab: 0 // 0: History, 1: Snippets, 2: Queue
  property string categoryFilter: "all"
  property string filterText: ""
  property int selectedIndex: 0
  property int historyLimit: 500

  property var history: []
  property var snippets: []
  property var folders: []
  property var pasteQueue: []
  readonly property int historyCount: history.length

  property bool clearConfirmOpen: false
  property bool snippetEditOpen: false
  property int snippetEditIndex: -1
  property string snippetEditTitle: ""
  property string snippetEditContent: ""
  property string snippetEditLang: "text"
  property string snippetEditFolder: ""
  property bool qrOpen: false
  property string qrImgPath: "/tmp/reclip-qr.png"

  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color bg: Color.menu.background
  readonly property color fg: Color.menu.text
  readonly property color borderCol: Color.menu.border
  readonly property color selBg: Color.menu.selectedBackground
  readonly property color selFg: Color.menu.selectedText
  readonly property color scrimCol: Color.menu.scrim

  function open(payload) {
    controller.show()
    root.filterText = ""
    root.selectedIndex = 0
    root.clearConfirmOpen = false
    root.snippetEditOpen = false
    root.qrOpen = false
    root.rebuildDisplay()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    root.clearConfirmOpen = false
    root.snippetEditOpen = false
    root.qrOpen = false
    controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function toggleIncognito() {
    root.incognito = !root.incognito
    if (root.incognito) {
      Quickshell.execDetached(["touch", root.incognitoPath])
    } else {
      Quickshell.execDetached(["rm", "-f", root.incognitoPath])
    }
  }

  function checkIncognitoFile() {
    incognitoCheckProc.running = true
  }

  function loadHistory(raw) {
    root.history = ClipboardHistory.parseHistory(raw)
    if (root.opened && root.activeTab === 0) root.rebuildDisplay()
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(root.history.slice(0, root.historyLimit), null, 2) + "\n")
  }

  function addClipboardEntry(entry) {
    if (root.incognito) return
    var normalized = ClipboardHistory.normalizeEntry(entry)
    if (!normalized) return
    root.history = ClipboardHistory.addEntry(root.history, normalized, root.historyLimit)
    root.saveHistory()
    if (root.opened && root.activeTab === 0) root.rebuildDisplay()
  }

  function addClipboardJson(line) {
    root.addClipboardEntry(ClipboardHistory.parseEntryJson(line))
  }

  function loadSnippets(raw) {
    var parsed = SnippetLib.parseStore(raw)
    root.snippets = parsed.snippets
    root.folders = parsed.folders
    if (root.opened && root.activeTab === 1) root.rebuildDisplay()
  }

  function saveSnippets() {
    snippetFile.setText(JSON.stringify({
      snippets: root.snippets,
      folders: root.folders
    }, null, 2) + "\n")
  }

  function rebuildDisplay() {
    displayModel.clear()
    if (root.activeTab === 0) {
      var rows = ClipboardHistory.displayRows(root.history, root.filterText, root.categoryFilter, 100)
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i]
        displayModel.append({
          itemType: "history",
          entryType: r.entryType,
          kind: r.kind || "text",
          colorValue: r.colorValue || "",
          fullText: r.fullText,
          previewText: r.previewText,
          previewImage: r.previewImage ? Util.fileUrl(r.previewImage) : "",
          path: r.path,
          mime: r.mime,
          historyIndex: r.index,
          snippetIndex: -1,
          title: "",
          language: "",
          tags: "",
          isFavorite: false
        })
      }
    } else if (root.activeTab === 1) {
      var sRows = SnippetLib.displayRows(root.snippets, root.filterText, 100)
      for (var j = 0; j < sRows.length; j++) {
        var s = sRows[j]
        displayModel.append({
          itemType: "snippet",
          entryType: "text",
          kind: "code",
          colorValue: "",
          fullText: s.content,
          previewText: s.preview,
          previewImage: "",
          path: "",
          mime: "text/plain",
          historyIndex: -1,
          snippetIndex: s.index,
          title: s.title,
          language: s.language,
          tags: s.tags,
          isFavorite: s.favorite
        })
      }
    } else if (root.activeTab === 2) {
      for (var q = 0; q < root.pasteQueue.length; q++) {
        var qIdx = root.pasteQueue[q]
        if (qIdx >= 0 && qIdx < root.history.length) {
          var qEntry = root.history[qIdx]
          var qTxt = ClipboardHistory.fullText(qEntry)
          displayModel.append({
            itemType: "queue",
            entryType: qEntry.type,
            kind: ClipboardHistory.detectKind(qEntry),
            colorValue: ClipboardHistory.isHexColor(qTxt) ? qTxt.trim() : "",
            fullText: qTxt,
            previewText: (q + 1) + ". " + ClipboardHistory.previewText(qEntry),
            previewImage: qEntry.type === "image" ? Util.fileUrl(qEntry.path) : "",
            path: qEntry.path || "",
            mime: qEntry.mime || "text/plain",
            historyIndex: qIdx,
            snippetIndex: -1,
            title: "Step " + (q + 1),
            language: "",
            tags: "",
            isFavorite: false
          })
        }
      }
    }

    if (displayModel.count === 0) root.selectedIndex = 0
    else if (root.selectedIndex >= displayModel.count) root.selectedIndex = displayModel.count - 1
    else if (root.selectedIndex < 0) root.selectedIndex = 0
  }

  function pasteRow(row) {
    root.close()
    if (!row) return
    if (row.entryType === "image" && row.path) {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-file", row.mime || "image/png", row.path])
    } else if (row.fullText) {
      Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(row.fullText) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
    }
  }

  function copyRow(row) {
    if (!row) return
    if (row.entryType === "image" && row.path) {
      Quickshell.execDetached(["wl-copy", "--type", row.mime || "image/png"], null, function(proc) {
        Quickshell.execDetached(["cat", row.path])
      })
    } else if (row.fullText) {
      Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(row.fullText) + " | wl-copy"])
    }
  }

  function deleteRow(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (row.itemType === "history") {
      root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
      root.saveHistory()
    } else if (row.itemType === "snippet") {
      root.snippets = SnippetLib.removeSnippet(root.snippets, row.snippetIndex)
      root.saveSnippets()
    } else if (row.itemType === "queue") {
      root.pasteQueue.splice(index, 1)
    }
    root.rebuildDisplay()
  }

  function toggleQueue(row) {
    if (!row || row.itemType !== "history") return
    var idx = row.historyIndex
    var p = root.pasteQueue.indexOf(idx)
    if (p >= 0) root.pasteQueue.splice(p, 1)
    else root.pasteQueue.push(idx)
    root.pasteQueueChanged()
    root.rebuildDisplay()
  }

  function flushQueue() {
    if (root.pasteQueue.length === 0) return
    root.close()
    var indices = root.pasteQueue.slice()
    root.pasteQueue = []
    root.pasteQueueChanged()
    queueProc.indices = indices
    queueProc.pending = indices.length
    queueProc.position = 0
    queueProc.step()
  }

  function saveAsSnippet(row) {
    if (!row || !row.fullText) return
    var title = row.previewText.slice(0, 30)
    var lang = row.kind === "code" ? "javascript" : "text"
    root.snippets = SnippetLib.addSnippet(root.snippets, {
      title: title,
      content: row.fullText,
      language: lang,
      folder: "Saved",
      favorite: false
    })
    root.saveSnippets()
    root.activeTab = 1
    root.rebuildDisplay()
  }

  function showQrModal(text) {
    if (!text) return
    qrCodeProc.textToEncode = text
    qrCodeProc.running = true
  }

  ListModel { id: displayModel }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  FileView {
    id: snippetFile
    path: root.snippetsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSnippets(text())
    onLoadFailed: root.loadSnippets("{\"snippets\":[],\"folders\":[]}")
    onFileChanged: reload()
  }

  Process {
    id: incognitoCheckProc
    command: ["test", "-f", root.incognitoPath]
    onExited: function(code) { root.incognito = (code === 0) }
  }

  Process {
    id: initProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: {
      root.checkIncognitoFile()
      wlInit.running = true
      currentProc.running = true
    }
  }

  Process {
    id: wlInit
    command: ["pkill", "-f", "wl-paste .*--watch .*/reclip/capture\\.sh"]
    onExited: {
      textWatch.running = true
      imageWatch.running = true
    }
  }

  Process {
    id: currentProc
    command: [root.captureScript]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: function(t) { root.addClipboardJson(t) } }
  }

  Process {
    id: textWatch
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
    stdout: SplitParser { onRead: function(data) { root.addClipboardJson(data) } }
  }

  Process {
    id: imageWatch
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
    stdout: SplitParser { onRead: function(data) { root.addClipboardJson(data) } }
  }

  Process {
    id: qrCodeProc
    property string textToEncode: ""
    command: ["qrencode", "-o", root.qrImgPath, "-s", "8", textToEncode]
    onExited: {
      qrImg.source = ""
      qrImg.source = "file://" + root.qrImgPath + "?t=" + Date.now()
      root.qrOpen = true
    }
  }

  Process {
    id: queueProc
    property var indices: []
    property int pending: 0
    property int position: 0

    function step() {
      if (position >= pending) { position = 0; return }
      var idx = indices[position]
      exec(["bash", "-c",
        "jq -j --argjson i " + idx + " 'if .[$i].type==\"text\" then .[$i].text else empty end' " +
        root.historyPath + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
    }

    onExited: {
      position += 1
      if (position < pending) Qt.callLater(step)
    }
  }

  Component.onCompleted: initProc.running = true

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: searchInput
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        root.activeTab = (root.activeTab + direction + 3) % 3
        root.selectedIndex = 0
        root.rebuildDisplay()
      }
    }

    Column {
      id: mainColumn
      width: parent.width
      spacing: Style.space(8)

      // 1. App Header (Title + Tabs + Incognito + Close)
      Row {
        width: parent.width
        height: Style.space(32)
        spacing: Style.space(8)

        Row {
          spacing: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "󰅍"
            color: root.incognito ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "ReClip"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Item { Layout.fillWidth: true; width: Style.space(16) }

        // Tab Pill Switcher
        Row {
          spacing: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            width: Style.space(70); height: Style.space(26)
            radius: Style.space(13)
            color: root.activeTab === 0 ? Color.accent : Util.alpha(root.fg, 0.08)
            Text {
              text: "History (" + root.historyCount + ")"
              color: root.activeTab === 0 ? "#fff" : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: root.activeTab === 0
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.activeTab = 0; root.rebuildDisplay() }
            }
          }

          Rectangle {
            width: Style.space(70); height: Style.space(26)
            radius: Style.space(13)
            color: root.activeTab === 1 ? Color.accent : Util.alpha(root.fg, 0.08)
            Text {
              text: "Snippets"
              color: root.activeTab === 1 ? "#fff" : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: root.activeTab === 1
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.activeTab = 1; root.rebuildDisplay() }
            }
          }

          Rectangle {
            width: Style.space(60); height: Style.space(26)
            radius: Style.space(13)
            color: root.activeTab === 2 ? Color.accent : (root.pasteQueue.length > 0 ? Color.urgent : Util.alpha(root.fg, 0.08))
            Text {
              text: "Queue " + (root.pasteQueue.length > 0 ? "(" + root.pasteQueue.length + ")" : "")
              color: (root.activeTab === 2 || root.pasteQueue.length > 0) ? "#fff" : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: root.activeTab === 2
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.activeTab = 2; root.rebuildDisplay() }
            }
          }
        }

        Item { Layout.fillWidth: true; width: Style.space(8) }

        // Incognito Button
        Rectangle {
          width: Style.space(26); height: Style.space(26)
          radius: Style.space(13)
          color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.08)
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: root.incognito ? "󰈈" : "󰈉"
            color: root.incognito ? "#fff" : root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleIncognito()
          }
        }

        // Close Button
        Rectangle {
          width: Style.space(26); height: Style.space(26)
          radius: Style.space(13)
          color: Util.alpha(root.fg, 0.08)
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "✕"
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            anchors.centerIn: parent
          }
          MouseArea { anchors.fill: parent; onClicked: root.close(); cursorShape: Qt.PointingHandCursor }
        }
      }

      // 2. Search Box
      Rectangle {
        width: parent.width
        height: Style.space(36)
        radius: Style.cornerRadius
        color: Util.alpha(root.fg, 0.06)
        border.width: 1
        border.color: searchInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "󰍉"
            color: Util.alpha(root.fg, 0.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: searchInput
            width: parent.width - Style.space(48)
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            text: root.filterText
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true

            onTextChanged: {
              root.filterText = text
              root.selectedIndex = 0
              root.rebuildDisplay()
            }

            Keys.onUpPressed: {
              if (displayModel.count > 0) {
                root.selectedIndex = (root.selectedIndex - 1 + displayModel.count) % displayModel.count
                list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
              }
            }
            Keys.onDownPressed: {
              if (displayModel.count > 0) {
                root.selectedIndex = (root.selectedIndex + 1) % displayModel.count
                list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
              }
            }
            Keys.onReturnPressed: function(event) {
              if (displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count) {
                var row = displayModel.get(root.selectedIndex)
                if (event.modifiers & Qt.ShiftModifier) {
                  root.toggleQueue(row)
                } else {
                  root.pasteRow(row)
                }
              }
            }
            Keys.onEscapePressed: {
              if (root.filterText !== "") root.filterText = ""
              else root.close()
            }
            Keys.onTabPressed: function(e) {
              root.activeTab = (root.activeTab + 1) % 3
              root.rebuildDisplay()
              e.accepted = true
            }

            Text {
              visible: searchInput.text === "" && !searchInput.activeFocus
              text: root.activeTab === 0 ? "Type to filter clipboard clips..." : (root.activeTab === 1 ? "Search saved snippets..." : "Search queued items...")
              color: Util.alpha(root.fg, 0.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            visible: searchInput.text !== ""
            text: "✕"
            color: Util.alpha(root.fg, 0.6)
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; onClicked: searchInput.text = ""; cursorShape: Qt.PointingHandCursor }
          }
        }
      }

      // 3. Category Filter Chips (History tab only)
      Row {
        visible: root.activeTab === 0
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: [
            { id: "all", label: "All" },
            { id: "text", label: "Text" },
            { id: "code", label: "Code" },
            { id: "color", label: "Colors" },
            { id: "link", label: "Links" },
            { id: "image", label: "Images" },
            { id: "file", label: "Files" }
          ]

          Rectangle {
            required property var modelData
            width: chipText.implicitWidth + Style.space(16)
            height: Style.space(22)
            radius: Style.space(11)
            color: root.categoryFilter === modelData.id ? Color.accent : Util.alpha(root.fg, 0.06)
            border.width: 1
            border.color: root.categoryFilter === modelData.id ? Color.accent : Util.alpha(root.fg, 0.1)

            Text {
              id: chipText
              text: parent.modelData.label
              color: root.categoryFilter === parent.modelData.id ? "#fff" : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              font.bold: root.categoryFilter === parent.modelData.id
              anchors.centerIn: parent
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.categoryFilter = parent.modelData.id
                root.selectedIndex = 0
                root.rebuildDisplay()
              }
            }
          }
        }
      }

      // Action Row for Snippets tab
      Row {
        visible: root.activeTab === 1
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(110); height: Style.space(26)
          radius: Style.space(6)
          color: Color.accent
          Row {
            anchors.centerIn: parent; spacing: Style.space(4)
            Text { text: "+"; color: "#fff"; font.pixelSize: Style.font.body; font.bold: true }
            Text { text: "New Snippet"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.snippetEditIndex = -1
              root.snippetEditTitle = ""
              root.snippetEditContent = ""
              root.snippetEditLang = "javascript"
              root.snippetEditFolder = ""
              root.snippetEditOpen = true
            }
          }
        }

        Item { Layout.fillWidth: true }
      }

      // Action Row for Queue tab
      Row {
        visible: root.activeTab === 2
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(120); height: Style.space(26)
          radius: Style.space(6)
          color: root.pasteQueue.length > 0 ? Color.accent : Util.alpha(root.fg, 0.1)
          Row {
            anchors.centerIn: parent; spacing: Style.space(4)
            Text { text: "󰆒"; color: "#fff"; font.pixelSize: Style.font.body }
            Text { text: "Paste Queue (" + root.pasteQueue.length + ")"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.flushQueue()
          }
        }

        Rectangle {
          width: Style.space(80); height: Style.space(26)
          radius: Style.space(6)
          color: Util.alpha(root.fg, 0.08)
          Text { text: "Clear Queue"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { root.pasteQueue = []; root.rebuildDisplay() }
          }
        }
      }

      // 4. Content List
      Rectangle {
        width: parent.width
        height: root.activeTab === 0 ? Style.space(410) : Style.space(435)
        color: "transparent"

        ListView {
          id: list
          anchors.fill: parent
          model: displayModel
          clip: true
          spacing: Style.space(6)

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: cardItem
            required property int index
            required property string itemType
            required property string entryType
            required property string kind
            required property string colorValue
            required property string fullText
            required property string previewText
            required property string previewImage
            required property string path
            required property string mime
            required property string title
            required property string language
            required property string tags
            required property bool isFavorite

            width: list.width - Style.space(6)
            height: kind === "code" ? Style.space(68) : (entryType === "image" ? Style.space(74) : Style.space(52))
            radius: Style.space(6)
            color: root.selectedIndex === index ? root.selBg : Util.alpha(root.fg, 0.04)
            border.width: 1
            border.color: root.selectedIndex === index ? Color.accent : Util.alpha(root.fg, 0.08)

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.selectedIndex = parent.index
                root.pasteRow(displayModel.get(parent.index))
              }
            }

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              // Type Visual Badge
              Rectangle {
                width: Style.space(36)
                height: Style.space(36)
                radius: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                color: cardItem.kind === "color" && cardItem.colorValue !== ""
                  ? cardItem.colorValue
                  : Util.alpha(root.fg, 0.08)
                border.width: cardItem.kind === "color" ? 1 : 0
                border.color: Util.alpha(root.fg, 0.3)

                Text {
                  visible: cardItem.kind !== "color" && cardItem.entryType !== "image"
                  text: cardItem.kind === "code" ? "󰅩" : (cardItem.kind === "link" ? "󰌹" : (cardItem.entryType === "file" ? "󰈔" : "󰅍"))
                  color: root.selectedIndex === cardItem.index ? root.selFg : root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.centerIn: parent
                }

                Image {
                  visible: cardItem.entryType === "image" && cardItem.previewImage !== ""
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  source: cardItem.previewImage
                  fillMode: Image.PreserveAspectCrop
                  clip: true
                }
              }

              // Text info
              Column {
                width: parent.width - Style.space(160)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Row {
                  spacing: Style.space(6)
                  Text {
                    visible: cardItem.title !== ""
                    text: cardItem.title
                    color: root.selectedIndex === cardItem.index ? root.selFg : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                  }
                  Rectangle {
                    visible: cardItem.kind === "code"
                    width: langTag.implicitWidth + Style.space(8); height: Style.space(14)
                    radius: Style.space(3); color: Util.alpha(Color.accent, 0.2)
                    Text { id: langTag; text: cardItem.language || "code"; color: Color.accent; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
                  }
                  Rectangle {
                    visible: cardItem.kind === "color"
                    width: colTag.implicitWidth + Style.space(8); height: Style.space(14)
                    radius: Style.space(3); color: Util.alpha(root.fg, 0.1)
                    Text { id: colTag; text: cardItem.colorValue; color: root.fg; font.pixelSize: Style.space(9); font.family: "monospace"; anchors.centerIn: parent }
                  }
                }

                Text {
                  width: parent.width
                  text: cardItem.previewText
                  color: root.selectedIndex === cardItem.index ? root.selFg : Util.alpha(root.fg, 0.85)
                  font.family: cardItem.kind === "code" ? "monospace" : root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  maximumLineCount: cardItem.kind === "code" ? 2 : 1
                  wrapMode: Text.WrapAnywhere
                }
              }

              // Action Buttons
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                // Quick Copy
                Rectangle {
                  width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "󰆏"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRow(displayModel.get(cardItem.index))
                  }
                }

                // Add to Queue
                Rectangle {
                  visible: cardItem.itemType === "history"
                  width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                  color: root.pasteQueue.indexOf(cardItem.index) >= 0 ? Color.accent : Util.alpha(root.fg, 0.08)
                  Text { text: "+"; color: root.pasteQueue.indexOf(cardItem.index) >= 0 ? "#fff" : root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleQueue(displayModel.get(cardItem.index))
                  }
                }

                // Save as Snippet
                Rectangle {
                  visible: cardItem.itemType === "history" && cardItem.entryType === "text"
                  width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "⭐"; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveAsSnippet(displayModel.get(cardItem.index))
                  }
                }

                // QR Code
                Rectangle {
                  visible: cardItem.entryType === "text" && cardItem.fullText !== ""
                  width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "󰐳"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.showQrModal(cardItem.fullText)
                  }
                }

                // Delete
                Rectangle {
                  width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "󰆴"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteRow(cardItem.index)
                  }
                }
              }
            }
          }
        }

        // Empty state
        Column {
          visible: displayModel.count === 0
          anchors.centerIn: parent
          spacing: Style.space(8)
          Text { text: "󰅍"; color: Util.alpha(root.fg, 0.3); font.family: root.fontFamily; font.pixelSize: Style.space(36); anchors.horizontalCenter: parent.horizontalCenter }
          Text {
            text: root.filterText !== "" ? "No matching clips found" : (root.activeTab === 0 ? "Clipboard is empty" : (root.activeTab === 1 ? "No snippets saved" : "Paste queue is empty"))
            color: Util.alpha(root.fg, 0.5)
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            anchors.horizontalCenter: parent.horizontalCenter
          }
        }
      }

      // 5. Footer (Hints + Clear History)
      Row {
        width: parent.width
        height: Style.space(24)
        spacing: Style.space(8)

        Text {
          text: "↵ Paste • Shift+↵ Queue • Tab Switch • Esc Close"
          color: Util.alpha(root.fg, 0.45)
          font.family: root.fontFamily
          font.pixelSize: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
        }

        Item { Layout.fillWidth: true; width: Style.space(16) }

        Rectangle {
          visible: root.activeTab === 0 && root.history.length > 0
          width: clearText.implicitWidth + Style.space(12); height: Style.space(20)
          radius: Style.space(4)
          color: Util.alpha(Color.urgent, 0.1)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: clearText
            text: "Clear All"
            color: Color.urgent
            font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
            anchors.centerIn: parent
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.clearConfirmOpen = true
          }
        }
      }
    }

    // Modal: Snippet Editor
    Rectangle {
      visible: root.snippetEditOpen
      anchors.fill: parent
      color: Util.alpha(root.scrimCol, 0.85)
      radius: Style.cornerRadius
      z: 30

      Rectangle {
        width: parent.width * 0.9
        height: parent.height * 0.85
        radius: Style.cornerRadius
        color: root.bg
        border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Text {
            text: root.snippetEditIndex >= 0 ? "Edit Snippet" : "New Snippet"
            color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
          }

          Row {
            width: parent.width; spacing: Style.space(8)
            Text { text: "Title:"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              width: parent.width - Style.space(50); height: Style.space(28); radius: Style.space(4)
              color: Util.alpha(root.fg, 0.08); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
              TextInput {
                id: edTitle
                anchors.fill: parent; anchors.margins: Style.space(4)
                color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
                text: root.snippetEditTitle; onTextChanged: root.snippetEditTitle = text
              }
            }
          }

          Row {
            width: parent.width; spacing: Style.space(8)
            Text { text: "Language:"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              width: Style.space(100); height: Style.space(28); radius: Style.space(4)
              color: Util.alpha(root.fg, 0.08); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
              TextInput {
                id: edLang
                anchors.fill: parent; anchors.margins: Style.space(4)
                color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
                text: root.snippetEditLang; onTextChanged: root.snippetEditLang = text
              }
            }
            Text { text: "Folder:"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              width: Style.space(100); height: Style.space(28); radius: Style.space(4)
              color: Util.alpha(root.fg, 0.08); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
              TextInput {
                id: edFolder
                anchors.fill: parent; anchors.margins: Style.space(4)
                color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
                text: root.snippetEditFolder; onTextChanged: root.snippetEditFolder = text
              }
            }
          }

          Rectangle {
            width: parent.width
            height: parent.height - Style.space(130)
            radius: Style.space(4)
            color: Util.alpha(root.fg, 0.05); border.width: 1; border.color: Util.alpha(root.fg, 0.12)
            Flickable {
              anchors.fill: parent; anchors.margins: Style.space(6)
              contentWidth: width; clip: true
              TextEdit {
                id: edBody
                width: parent.width
                color: root.fg; font.family: "monospace"; font.pixelSize: Style.font.caption
                wrapMode: TextEdit.Wrap
                text: root.snippetEditContent; onTextChanged: root.snippetEditContent = text
              }
            }
          }

          Row {
            anchors.right: parent.right; spacing: Style.space(8)
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4)
              color: Util.alpha(root.fg, 0.1)
              Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.snippetEditOpen = false; cursorShape: Qt.PointingHandCursor }
            }
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4)
              color: Color.accent
              Text { text: "Save"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.saveSnippet(root.snippetEditTitle, root.snippetEditContent, root.snippetEditLang, root.snippetEditFolder)
                  root.snippetEditOpen = false
                }
              }
            }
          }
        }
      }
    }

    // Modal: QR Code Sharing
    Rectangle {
      visible: root.qrOpen
      anchors.fill: parent
      color: Util.alpha(root.scrimCol, 0.85)
      radius: Style.cornerRadius
      z: 35

      Rectangle {
        width: Style.space(300); height: Style.space(340)
        radius: Style.cornerRadius
        color: root.bg; border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent; anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Text {
            text: "Scan with Phone"
            color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Image {
            id: qrImg
            width: Style.space(220); height: Style.space(220)
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
          }

          Rectangle {
            width: Style.space(100); height: Style.space(28); radius: Style.space(4)
            color: Color.accent
            anchors.horizontalCenter: parent.horizontalCenter
            Text { text: "Done"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; onClicked: root.qrOpen = false; cursorShape: Qt.PointingHandCursor }
          }
        }
      }
    }

    // Modal: Clear Confirmation
    Rectangle {
      visible: root.clearConfirmOpen
      anchors.fill: parent
      color: Util.alpha(root.scrimCol, 0.85)
      radius: Style.cornerRadius
      z: 40

      Rectangle {
        width: Style.space(280); height: Style.space(140)
        radius: Style.cornerRadius
        color: root.bg; border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent; anchors.margins: Style.space(16)
          spacing: Style.space(12)

          Text {
            text: "Clear History?"
            color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            text: "This will remove all stored clipboard clips."
            color: Util.alpha(root.fg, 0.7); font.family: root.fontFamily; font.pixelSize: Style.font.caption
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(12)

            Rectangle {
              width: Style.space(80); height: Style.space(28); radius: Style.space(4)
              color: Util.alpha(root.fg, 0.1)
              Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.clearConfirmOpen = false; cursorShape: Qt.PointingHandCursor }
            }

            Rectangle {
              width: Style.space(80); height: Style.space(28); radius: Style.space(4)
              color: Color.urgent
              Text { text: "Clear All"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.clearHistory()
                  root.clearConfirmOpen = false
                }
              }
            }
          }
        }
      }
    }
  }
}
