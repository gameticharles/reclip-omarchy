import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "lib/ClipboardHistory.js" as ClipboardHistory
import "lib/SnippetLibrary.js" as SnippetLib
import "lib/SyntaxHighlight.js" as Syntax

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property string home: Quickshell.env("HOME")
  property string stateDir: home + "/.local/state/reclip"
  property string historyPath: stateDir + "/clipboard-history.json"
  property string snippetsPath: stateDir + "/snippets.json"
  property string pluginDir: (manifest && manifest.id) ? (home + "/.config/omarchy/plugins/" + manifest.id) : (home + "/.config/omarchy/plugins/reclip")
  property string captureScript: root.pluginDir + "/capture.sh"

  property bool opened: false
  property int activeTab: 0
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool clearConfirmOpen: false

  property var history: []
  property var snippets: []
  property var folders: []
  property var pasteQueue: []
  property bool queueMode: false

  property string snippetEditTitle: ""
  property string snippetEditContent: ""
  property string snippetEditLang: "text"
  property string snippetEditFolder: ""
  property bool snippetEditOpen: false
  property int snippetEditIndex: -1
  property bool qrOpen: false

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(950), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(650), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int historyLimit: 500

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.cancelClearHistory()
    root.snippetEditOpen = false
    root.qrOpen = false
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "reclip")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open()
  }

  function ensureStateDir() {
    Quickshell.execDetached(["mkdir", "-p", root.stateDir])
  }

  function loadHistory(raw) {
    root.history = ClipboardHistory.parseHistory(raw)
    if (root.opened) root.rebuildDisplay()
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(root.history.slice(0, root.historyLimit), null, 2) + "\n")
  }

  function addClipboardEntry(entry) {
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
      var rows = ClipboardHistory.displayRows(root.history, root.filterText, 80)
      for (var i = 0; i < rows.length; i++) {
        var row = rows[i]
        displayModel.append({
          itemType: "history",
          entryType: row.entryType,
          fullText: row.fullText,
          previewText: row.previewText,
          previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
          path: row.path,
          mime: row.mime,
          historyIndex: row.index,
          snippetIndex: -1,
          title: "",
          language: "",
          tags: "",
          isFavorite: false
        })
      }
    } else {
      var rows = SnippetLib.displayRows(root.snippets, root.filterText, 80)
      for (var j = 0; j < rows.length; j++) {
        var sr = rows[j]
        displayModel.append({
          itemType: "snippet",
          entryType: "text",
          fullText: sr.content,
          previewText: sr.title + (sr.tags ? "  " + sr.tags : ""),
          previewImage: "",
          path: "",
          mime: "text/plain",
          historyIndex: -1,
          snippetIndex: sr.index,
          title: sr.title,
          language: sr.language,
          tags: sr.tags,
          isFavorite: sr.favorite
        })
      }
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function selectTab(tab) {
    root.activeTab = tab
    root.selectedIndex = 0
    root.filterText = ""
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function disarmPointer() { pointerGate.reset() }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (row.itemType === "history") {
      root.pasteHistoryRow(row)
    } else {
      root.pasteSnippetRow(row)
    }
  }

  function pasteHistoryRow(row) {
    root.opened = false
    if (row.entryType === "image") {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-file", row.mime, row.path])
    } else if (row.fullText) {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-text", "--shift-insert", "--history-index", String(row.historyIndex)])
    }
  }

  function pasteSnippetRow(row) {
    root.opened = false
    var text = row.fullText
    if (!text) return
    var cmd = "printf '%s' " + Util.shellQuote(text) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"
    Quickshell.execDetached(["sh", "-c", cmd])
  }

  function toggleQueueSelect(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (row.itemType !== "history") return

    var idx = row.historyIndex
    var pos = -1
    for (var i = 0; i < root.pasteQueue.length; i++) {
      if (root.pasteQueue[i] === idx) { pos = i; break }
    }
    if (pos >= 0) root.pasteQueue.splice(pos, 1)
    else root.pasteQueue.push(idx)
    root.pasteQueueChanged()
  }

  function isInQueue(index) {
    if (index < 0 || index >= displayModel.count) return false
    var row = displayModel.get(index)
    if (row.itemType !== "history") return false
    return root.pasteQueue.indexOf(row.historyIndex) >= 0
  }

  function flushPasteQueue() {
    if (root.pasteQueue.length === 0) return
    root.opened = false
    var indices = root.pasteQueue.slice()
    root.pasteQueue = []
    root.pasteQueueChanged()
    queueProc.indices = indices
    queueProc.pending = indices.length
    queueProc.step()
  }

  function openSnippetEditor(index) {
    if (index >= 0 && index < root.snippets.length) {
      var s = root.snippets[index]
      root.snippetEditTitle = s.title || ""
      root.snippetEditContent = s.content || ""
      root.snippetEditLang = s.language || "text"
      root.snippetEditFolder = s.folder || ""
      root.snippetEditIndex = index
    } else {
      root.snippetEditTitle = ""
      root.snippetEditContent = ""
      root.snippetEditLang = "text"
      root.snippetEditFolder = ""
      root.snippetEditIndex = -1
    }
    root.snippetEditOpen = true
    Qt.callLater(function() { snippetEditTitle.forceActiveFocus() })
  }

  function saveSnippetEdit() {
    var title = root.snippetEditTitle.trim()
    var content = root.snippetEditContent
    if (!title && !content) { root.snippetEditOpen = false; return }

    if (root.snippetEditIndex >= 0) {
      root.snippets = SnippetLib.updateSnippet(root.snippets, root.snippetEditIndex, {
        title: title, content: content,
        language: root.snippetEditLang, folder: root.snippetEditFolder
      })
    } else {
      root.snippets = SnippetLib.addSnippet(root.snippets, {
        title: title || "Untitled", content: content,
        language: root.snippetEditLang, folder: root.snippetEditFolder
      })
    }
    root.saveSnippets()
    root.snippetEditOpen = false
    root.rebuildDisplay()
  }

  function deleteSelectedSnippet() {
    if (selectedIndex < 0 || selectedIndex >= displayModel.count) return
    var row = displayModel.get(selectedIndex)
    if (row.itemType !== "snippet" || row.snippetIndex < 0) return
    root.snippets = SnippetLib.removeSnippet(root.snippets, row.snippetIndex)
    root.saveSnippets()
    root.rebuildDisplay()
  }

  function removeHistoryEntry(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (row.itemType !== "history") return
    root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
    root.saveHistory()
    if (displayModel.count <= 1) { selectedIndex = 0; cursorActive = false }
    else if (selectedIndex >= displayModel.count - 1) selectedIndex = displayModel.count - 2
    disarmPointer()
    root.rebuildDisplay()
  }

  function requestClearHistory() {
    if (root.history.length === 0) return
    clearConfirm.selectedIndex = 1
    root.clearConfirmOpen = true
  }

  function cancelClearHistory() { root.clearConfirmOpen = false; disarmPointer(); Qt.callLater(function() { keyCatcher.forceActiveFocus() }) }

  function confirmClearHistory() {
    root.history = ClipboardHistory.clearHistory()
    root.saveHistory()
    root.selectedIndex = 0
    root.cursorActive = false
    root.clearConfirmOpen = false
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function generateQr() {
    if (selectedIndex < 0 || selectedIndex >= displayModel.count) return
    var row = displayModel.get(selectedIndex)
    var text = row.fullText || ""
    if (!text) return
    root.ensureStateDir()
    qrInputFile.setText(text)
    qrProc.running = true
  }

  function showQr(file) {
    if (!file) return
    qrImage.source = Util.fileUrl(file)
    root.qrOpen = true
    Qt.callLater(function() { Qt.callLater(function() { qrClose.forceActiveFocus() }) })
  }

  function closeQr() {
    root.qrOpen = false
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  ListModel { id: displayModel }

  PointerMoveGate { id: pointerGate; referenceItem: card }

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
    id: initProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: {
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
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.addClipboardJson(text) }
  }

  Process {
    id: textWatch
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser { onRead: function(data) { root.addClipboardJson(data) } }
  }

  Process {
    id: imageWatch
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser { onRead: function(data) { root.addClipboardJson(data) } }
  }

  Timer { id: watchRestartTimer; interval: 1000; repeat: false; onTriggered: { if (!textWatch.running) textWatch.running = true; if (!imageWatch.running) imageWatch.running = true } }

  // Writes the text to generate a QR from. generateQr fills this, then qrProc
  // reads it back (avoiding shell-injection from arbitrary clipboard text).
  FileView {
    id: qrInputFile
    path: root.stateDir + "/qr-input.txt"
    atomicWrites: true
    printErrors: false
  }

  Process {
    id: qrProc
    command: ["sh", "-c", "qrencode -t PNG -m 2 -o " + root.stateDir + "/qr.png -l M < " + root.stateDir + "/qr-input.txt && echo OK"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text() === "OK") root.showQr(root.stateDir + "/qr.png")
      }
    }
  }

  // Sequential paste queue: copies each queued history entry to the clipboard
  // and types it with Shift+Insert, one after another. Reuses a single Process,
  // calling exec() per step with a freshly built argv (no shell interpolation —
  // content comes from our own history JSON by index).
  Process {
    id: queueProc
    property var indices: []
    property int pending: 0
    property int position: 0
    readonly property string historyFile: root.historyPath

    function step() {
      if (position >= pending) { position = 0; return }
      var idx = indices[position]
      exec(["bash", "-c",
        "jq -j --argjson i " + idx + " 'if .[$i].type==\"text\" then .[$i].text else empty end' " +
        root.historyPath + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
    }

    onExited: { position += 1; Qt.callLater(step) }
  }

  Component.onCompleted: initProc.running = true

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-reclip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: (root.clearConfirmOpen || root.snippetEditOpen) ? 20 : 0
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.clearConfirmOpen) { if (clearConfirm.handleKey(event)) event.accepted = true; return }
          if (root.snippetEditOpen) { event.accepted = true; return }

          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            root.activeTab = root.activeTab === 0 ? 1 : 0
            root.selectedIndex = 0
            root.filterText = ""
            root.rebuildDisplay()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            if (event.modifiers & Qt.ShiftModifier) {
              if (root.activeTab === 0) root.requestClearHistory()
              else root.deleteSelectedSnippet()
            } else if (root.activeTab === 0) root.removeHistoryEntry(root.selectedIndex)
            else root.deleteSelectedSnippet()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) { root.select(-1); event.accepted = true }
            else if (event.key === Qt.Key_Down) { root.select(1); event.accepted = true }
            else if (event.key === Qt.Key_PageUp) { root.select(-6); event.accepted = true }
            else if (event.key === Qt.Key_PageDown) { root.select(6); event.accepted = true }
            else if (event.key === Qt.Key_Home) { root.selectAbsolute(0); event.accepted = true }
            else if (event.key === Qt.Key_End) { root.selectAbsolute(displayModel.count - 1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.cursorActive && (event.modifiers & Qt.ControlModifier)) {
                if (root.activeTab === 1) root.openSnippetEditor(-1)
                else root.generateQr()
              } else if (root.cursorActive && (event.modifiers & Qt.ShiftModifier)) {
                root.toggleQueueSelect(root.selectedIndex)
              } else if (root.cursorActive) root.activateIndex(root.selectedIndex)
              else if (displayModel.count > 0) root.cursorActive = true
              event.accepted = true
            } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
              if (root.activeTab === 1) root.openSnippetEditor(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_E) {
              if (root.activeTab === 1 && root.selectedIndex >= 0) {
                var row = displayModel.get(root.selectedIndex)
                if (row && row.itemType === "snippet") root.openSnippetEditor(row.snippetIndex)
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Q && (event.modifiers & Qt.ControlModifier)) {
              root.flushPasteQueue()
              event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
              root.setFilter(root.filterText + event.text)
              event.accepted = true
            }
        }
      }

      ConfirmDialog {
        id: clearConfirm
        anchors.fill: parent
        opened: root.clearConfirmOpen
        z: 10
        message: root.activeTab === 0 ? "Delete entire clipboard history?" : "Delete selected snippet?"
        confirmText: "Delete"
        background: root.background
        foreground: root.foreground
        scrim: root.scrim
        selectedBackground: root.selectedBackground
        selectedText: root.selectedText
        fontFamily: root.fontFamily
        cornerRadius: root.cornerRadius
        onCanceled: root.cancelClearHistory()
        onConfirmed: root.confirmClearHistory()
      }

      Rectangle {
        id: snippetEditorOverlay
        anchors.fill: parent
        visible: root.snippetEditOpen
        z: 15
        color: Util.alpha(root.scrim, 0.92)

        Rectangle {
          width: parent.width * 0.7
          height: parent.height * 0.75
          radius: root.cornerRadius
          color: root.background
          border.width: 1
          border.color: root.border
          anchors.centerIn: parent

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(12)

            Text {
              text: root.snippetEditIndex >= 0 ? "Edit Snippet" : "New Snippet"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Text { text: "Title:"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Rectangle {
                width: parent.width - Style.space(60)
                height: Style.space(32)
                radius: Style.space(4)
                color: Util.alpha(root.foreground, 0.08)
                border.width: 1; border.color: Util.alpha(root.foreground, 0.15)
                TextInput {
                  id: snippetEditTitle
                  anchors.fill: parent; anchors.margins: Style.space(6)
                  color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body
                  text: root.snippetEditTitle
                  onTextChanged: root.snippetEditTitle = text
                  clip: true
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Text { text: "Language:"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Rectangle {
                width: Style.space(120); height: Style.space(32); radius: Style.space(4)
                color: Util.alpha(root.foreground, 0.08); border.width: 1; border.color: Util.alpha(root.foreground, 0.15)
                TextInput {
                  anchors.fill: parent; anchors.margins: Style.space(6)
                  color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body
                  text: root.snippetEditLang; onTextChanged: root.snippetEditLang = text; clip: true
                }
              }
              Text { text: "Folder:"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Rectangle {
                width: Style.space(120); height: Style.space(32); radius: Style.space(4)
                color: Util.alpha(root.foreground, 0.08); border.width: 1; border.color: Util.alpha(root.foreground, 0.15)
                TextInput {
                  anchors.fill: parent; anchors.margins: Style.space(6)
                  color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body
                  text: root.snippetEditFolder; onTextChanged: root.snippetEditFolder = text; clip: true
                }
              }
            }

            Rectangle {
              width: parent.width
              height: parent.height - Style.space(140)
              radius: Style.space(4)
              color: Util.alpha(root.foreground, 0.05)
              border.width: 1; border.color: Util.alpha(root.foreground, 0.12)
              Flickable {
                anchors.fill: parent; anchors.margins: Style.space(6)
                contentWidth: width; clip: true
                flickableDirection: Flickable.VerticalFlick
                TextEdit {
                  id: snippetEditBody
                  width: parent.width
                  color: root.foreground; font.family: "monospace"; font.pixelSize: Style.font.body
                  wrapMode: TextEdit.Wrap
                  text: root.snippetEditContent; onTextChanged: root.snippetEditContent = text
                }
              }
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(80); height: Style.space(32); radius: Style.space(4)
                color: Util.alpha(root.foreground, 0.1)
                Text { text: "Cancel"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: root.snippetEditOpen = false; cursorShape: Qt.PointingHandCursor }
              }

              Rectangle {
                width: Style.space(80); height: Style.space(32); radius: Style.space(4)
                color: Util.alpha(Color.accent, 0.85)
                Text { text: "Save"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: root.saveSnippetEdit(); cursorShape: Qt.PointingHandCursor }
              }
            }
          }
        }
      }

      Rectangle {
        id: qrOverlay
        anchors.fill: parent
        visible: root.qrOpen
        z: 16
        color: Util.alpha(root.scrim, 0.92)

        Item {
          id: qrClose
          anchors.fill: parent
          focus: true
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.qrOpen = false
              event.accepted = true
            }
          }
        }

        Rectangle {
          width: Style.space(360)
          height: Style.space(400)
          radius: root.cornerRadius
          color: root.background
          border.width: 1
          border.color: root.border
          anchors.centerIn: parent

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(20)
            spacing: Style.space(12)

            Text {
              text: "QR Code"
              color: root.foreground
              font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true
              horizontalAlignment: Text.AlignHCenter; width: parent.width
            }

            Image {
              id: qrImage
              width: Math.min(parent.width, Style.space(280))
              height: width
              anchors.horizontalCenter: parent.horizontalCenter
              source: ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true; smooth: true
            }

            Text {
              text: "Scan to transfer on your phone"
              color: Util.alpha(root.foreground, 0.6)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter; width: parent.width
            }

            Rectangle {
              width: parent.width; height: Style.space(32); radius: Style.space(4)
              color: Util.alpha(Color.accent, 0.85)
              anchors.horizontalCenter: parent.horizontalCenter
              Text { text: "Close (Esc)"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.closeQr(); cursorShape: Qt.PointingHandCursor }
            }
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Row {
          width: parent.width
          height: Style.space(36)
          spacing: Style.space(4)

          Rectangle {
            width: parent.width / 2 - Style.space(2); height: parent.height; radius: root.cornerRadius
            color: root.activeTab === 0 ? Util.alpha(root.foreground, 0.1) : "transparent"
            Text {
              text: "History" + (root.pasteQueue.length > 0 ? " [" + root.pasteQueue.length + "]" : "")
              color: root.activeTab === 0 ? root.selectedText : root.foreground; opacity: root.activeTab === 0 ? 1 : 0.6
              font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: root.activeTab === 0
              anchors.centerIn: parent
            }
            MouseArea { anchors.fill: parent; onClicked: root.selectTab(0); cursorShape: Qt.PointingHandCursor }
          }

          Rectangle {
            width: parent.width / 2 - Style.space(2); height: parent.height; radius: root.cornerRadius
            color: root.activeTab === 1 ? Util.alpha(root.foreground, 0.1) : "transparent"
            Text {
              text: "Snippets"
              color: root.activeTab === 1 ? root.selectedText : root.foreground; opacity: root.activeTab === 1 ? 1 : 0.6
              font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: root.activeTab === 1
              anchors.centerIn: parent
            }
            MouseArea { anchors.fill: parent; onClicked: root.selectTab(1); cursorShape: Qt.PointingHandCursor }
          }
        }

        Rectangle {
          width: parent.width; height: Style.space(32); radius: Style.space(4)
          color: Util.alpha(root.foreground, 0.06); border.width: 1; border.color: Util.alpha(root.foreground, 0.1)
          Text {
            anchors.left: parent.left; anchors.leftMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || (root.activeTab === 0 ? "Search clipboard…" : "Search snippets…")
            color: root.foreground; opacity: root.filterText ? 1 : 0.45
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
          TextInput {
            anchors.fill: parent; anchors.margins: Style.space(4)
            color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body
            clip: true; text: root.filterText; visible: false
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing - Style.space(76)

          Row {
            anchors.fill: parent
            spacing: 0

            Item {
              width: parent.width * 0.45
              height: parent.height
              clip: true

              ListView {
                id: resultList
                anchors.fill: parent
                anchors.rightMargin: root.contentMargin
                model: displayModel
                clip: true
                spacing: Style.space(4)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  id: row
                  required property int index
                  required property string itemType
                  required property string entryType
                  required property string previewText
                  required property string previewImage
                  required property string fullText
                  required property string title
                  required property string language
                  required property string tags
                  required property bool isFavorite

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                  readonly property bool inQueue: root.isInQueue(index)

                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: hasCursor ? root.selectedBackground : (inQueue ? Util.alpha(Color.accent, 0.2) : "transparent")

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(6)
                    anchors.bottomMargin: Style.space(6)
                    spacing: Style.space(8)

                    Text {
                      visible: row.itemType === "history"
                      text: row.inQueue ? "✓" : (row.entryType === "image" ? "🖼" : "📄")
                      font.pixelSize: Style.font.title
                      color: row.hasCursor ? root.selectedText : root.foreground
                      opacity: row.inQueue ? 1 : 0.7
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(20); horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                      visible: row.itemType === "snippet"
                      text: row.isFavorite ? "★" : "◇"
                      font.pixelSize: Style.font.title
                      color: row.isFavorite ? "#f0c040" : (row.hasCursor ? root.selectedText : root.foreground)
                      opacity: 0.8
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(20); horizontalAlignment: Text.AlignHCenter
                    }

                    Image {
                      visible: row.previewImage.length > 0
                      width: visible ? parent.height : 0
                      height: parent.height
                      source: row.previewImage
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true; smooth: true
                    }

                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - (row.previewImage.length > 0 ? parent.height + parent.spacing : Style.space(28))
                      height: parent.height
                      text: row.previewText
                      color: row.hasCursor ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      opacity: (row.entryType === "image" || row.entryType === "file") ? 0.72 : 1.0
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: function(mouse) { root.selectFromPointer(row.index, row, mouse) }
                    onClicked: {
                      root.cursorActive = true
                      root.selectedIndex = row.index
                      if (root.queueMode && row.itemType === "history") root.toggleQueueSelect(row.index)
                      else root.activateIndex(row.index)
                    }
                  }
                }
              }
            }

            Item {
              width: parent.width * 0.55
              height: parent.height
              clip: true

              property var activeRow: displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count ? displayModel.get(root.selectedIndex) : null

              Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: Style.normalBorderWidth; color: Util.alpha(root.border, 0.28)
              }

                  Flickable {
                    id: detailFlick
                    anchors.fill: parent
                    anchors.leftMargin: root.contentMargin
                    contentWidth: width; clip: true
                    contentHeight: detailCol.implicitHeight
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                      id: detailCol
                      width: parent.width
                      spacing: Style.space(6)

                      Text {
                        visible: parent.parent.parent.parent.activeRow && parent.parent.parent.parent.activeRow.itemType === "snippet"
                        text: parent.parent.parent.parent.activeRow ? (parent.parent.parent.parent.activeRow.language || "text") : ""
                        color: Util.alpha(root.foreground, 0.45)
                        font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      }

                      Text {
                        visible: parent.parent.parent.parent.activeRow && parent.parent.parent.parent.activeRow.itemType === "snippet" && parent.parent.parent.parent.activeRow.title
                        text: parent.parent.parent.parent.activeRow ? parent.parent.parent.parent.activeRow.title : ""
                        color: root.foreground
                        font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true
                        width: parent.width; elide: Text.ElideRight
                      }

                      // Syntax-highlighted snippet body (rich text). Falls back
                      // to plain text when the language is unknown.
                      Text {
                        visible: parent.parent.parent.parent.activeRow && parent.parent.parent.parent.activeRow.itemType === "snippet"
                        width: parent.width
                        textFormat: Text.RichText
                        text: parent.parent.parent.parent.activeRow
                          ? "<div style='font-family:monospace; color:" + root.foreground + "'>" +
                              Syntax.highlight(parent.parent.parent.parent.activeRow.fullText, parent.parent.parent.parent.activeRow.language) + "</div>"
                          : ""
                        color: root.foreground
                        font.family: "monospace"; font.pixelSize: Style.font.body
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                      }

                      Text {
                        visible: parent.parent.parent.parent.activeRow && !parent.parent.parent.parent.activeRow.previewImage && parent.parent.parent.parent.activeRow.itemType === "history"
                        textFormat: Text.PlainText
                        width: parent.width
                        text: parent.parent.parent.parent.activeRow ? parent.parent.parent.parent.activeRow.fullText : ""
                        color: root.foreground
                        font.family: root.fontFamily; font.pixelSize: Style.font.title
                        wrapMode: Text.WrapAnywhere; elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                      }

                      Image {
                        visible: parent.parent.parent.parent.activeRow && parent.parent.parent.parent.activeRow.previewImage
                        width: parent.width
                        source: parent.parent.parent.parent.activeRow ? parent.parent.parent.parent.activeRow.previewImage : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true; smooth: true
                      }
                    }
                  }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0

            Text {
              text: root.activeTab === 0 ? "󰅌" : "◇"
              color: root.selectedText; opacity: 0.8
              font.family: root.fontFamily; font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter; width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.activeTab === 0
                ? (root.history.length === 0 ? "Clipboard is empty" : "No matches for \"" + root.filterText + "\"")
                : (root.snippets.length === 0 ? "No snippets yet — press Ctrl+N" : "No matches for \"" + root.filterText + "\"")
              color: root.foreground; opacity: 0.7
              font.family: root.fontFamily; font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter; width: parent.width
            }
          }
        }

        Row {
          width: parent.width
          height: Style.space(32)
          spacing: Style.space(8)
          layoutDirection: Qt.RightToLeft

          Rectangle {
            width: queueLabel.width + Style.space(16); height: parent.height; radius: Style.space(4)
            color: root.pasteQueue.length > 0 ? Util.alpha(Color.accent, 0.85) : Util.alpha(root.foreground, 0.08)
            visible: root.activeTab === 0
            Text {
              id: queueLabel
              text: root.pasteQueue.length > 0 ? "Paste Queue (" + root.pasteQueue.length + ")" : "Queue (Shift+Click)"
              color: root.pasteQueue.length > 0 ? "#fff" : Util.alpha(root.foreground, 0.5)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent
            }
            MouseArea { anchors.fill: parent; onClicked: root.flushPasteQueue(); cursorShape: Qt.PointingHandCursor }
          }

          Rectangle {
            width: qrLabel.width + Style.space(16); height: parent.height; radius: Style.space(4)
            color: Util.alpha(root.foreground, 0.08)
            Text {
              id: qrLabel
              text: "QR Code (Ctrl+Enter)"
              color: Util.alpha(root.foreground, 0.5)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent
            }
            MouseArea { anchors.fill: parent; onClicked: root.generateQr(); cursorShape: Qt.PointingHandCursor }
          }

          Rectangle {
            width: newLabel.width + Style.space(16); height: parent.height; radius: Style.space(4)
            color: root.activeTab === 1 ? Util.alpha(Color.accent, 0.85) : Util.alpha(root.foreground, 0.08)
            visible: root.activeTab === 1
            Text {
              id: newLabel
              text: "New Snippet (Ctrl+N)"
              color: root.activeTab === 1 ? "#fff" : Util.alpha(root.foreground, 0.5)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent
            }
            MouseArea { anchors.fill: parent; onClicked: root.openSnippetEditor(-1); cursorShape: Qt.PointingHandCursor }
          }

          Item { width: parent.width - (root.activeTab === 0 ? qrLabel.width + queueLabel.width + Style.space(40) : qrLabel.width + newLabel.width + Style.space(32)); height: parent.height }
        }
      }
    }
  }
}
