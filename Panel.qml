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
import "lib/ColorStudio.js" as ColorStudio
import "lib/TimelineStudio.js" as TimelineStudio

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
  // Tabs: 0: History, 1: Pinned/Favs, 2: Snippets, 3: Color Studio, 4: Queue
  property int activeTab: 0
  property string categoryFilter: "all"
  property string filterText: ""
  property int selectedIndex: 0
  property int historyLimit: 500

  // Timeline & Calendar State (Exact parity with ReClip TimelineView)
  property bool showTimeline: false
  property bool showCalendar: false
  property string timelineZoom: "hour" // "hour", "day", "week", "month"
  property int calendarYear: new Date().getFullYear()
  property int calendarMonth: new Date().getMonth()
  property string activeDateFilter: "" // "", "today", "yesterday", "7d", "30d", "mtd", or "YYYY-MM-DD"

  // Color Studio State
  property string activeColorHex: "#3B82F6"
  property var activeColorAnalysis: ColorStudio.analyzeColor(root.activeColorHex)

  property var history: []
  property var snippets: []
  property var folders: []
  property var pasteQueue: []
  property var colorPalette: []
  readonly property int historyCount: history.length
  readonly property int pinnedCount: {
    var count = 0
    for (var i = 0; i < history.length; i++) if (history[i].pinned) count++
    return count
  }
  readonly property var dateCounts: TimelineStudio.getClipDateCounts(history)
  readonly property var timelineData: TimelineStudio.computeTimelineMarkers(history, timelineZoom)
  readonly property var calendarDays: TimelineStudio.buildCalendarGrid(calendarYear, calendarMonth, history, activeDateFilter)

  // Modals & Popups
  property bool clearConfirmOpen: false
  property bool snippetEditOpen: false
  property int snippetEditIndex: -1
  property string snippetEditTitle: ""
  property string snippetEditContent: ""
  property string snippetEditLang: "javascript"
  property string snippetEditFolder: ""

  property bool clipEditOpen: false
  property int clipEditIndex: -1
  property string clipEditContent: ""

  property bool transformOpen: false
  property int transformClipIndex: -1

  property bool mergeDialogOpen: false
  property string mergeSeparator: "\n"

  property bool qrOpen: false
  property string qrImgPath: "/tmp/reclip-qr.png"

  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color bg: Color.popups.background
  readonly property color fg: Color.popups.text
  readonly property color borderCol: Color.popups.border
  readonly property color selBg: Style.selectedFillFor(Color.foreground, Color.accent)
  readonly property color selFg: Color.foreground
  readonly property color scrimCol: Util.alpha(Color.background, 0.75)

  function open(payload) {
    controller.show()
    root.filterText = ""
    root.selectedIndex = 0
    root.clearConfirmOpen = false
    root.snippetEditOpen = false
    root.clipEditOpen = false
    root.transformOpen = false
    root.mergeDialogOpen = false
    root.qrOpen = false
    root.showCalendar = false
    root.rebuildDisplay()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    root.clearConfirmOpen = false
    root.snippetEditOpen = false
    root.clipEditOpen = false
    root.transformOpen = false
    root.mergeDialogOpen = false
    root.qrOpen = false
    root.showCalendar = false
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

  function takeScreenshot() {
    root.close()
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-capture-screenshot"])
  }

  function checkIncognitoFile() {
    incognitoCheckProc.running = true
  }

  function loadHistory(raw) {
    root.history = ClipboardHistory.parseHistory(raw)
    root.colorPalette = ClipboardHistory.extractColors(root.history)
    if (root.colorPalette.length > 0 && root.activeColorHex === "#3B82F6") {
      root.selectColor(root.colorPalette[0].hex)
    }
    if (root.opened) root.rebuildDisplay()
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(root.history.slice(0, root.historyLimit), null, 2) + "\n")
    root.colorPalette = ClipboardHistory.extractColors(root.history)
  }

  function addClipboardEntry(entry) {
    if (root.incognito) return
    var normalized = ClipboardHistory.normalizeEntry(entry)
    if (!normalized) return
    root.history = ClipboardHistory.addEntry(root.history, normalized, root.historyLimit)
    root.saveHistory()
    if (normalized.type === "text" && ClipboardHistory.isHexColor(normalized.text)) {
      root.selectColor(normalized.text.trim())
    }
    if (root.opened && root.activeTab === 0) root.rebuildDisplay()
  }

  function addClipboardJson(line) {
    root.addClipboardEntry(ClipboardHistory.parseEntryJson(line))
  }

  function loadSnippets(raw) {
    var parsed = SnippetLib.parseStore(raw)
    root.snippets = parsed.snippets
    root.folders = parsed.folders
    if (root.opened && root.activeTab === 2) root.rebuildDisplay()
  }

  function saveSnippets() {
    snippetFile.setText(JSON.stringify({
      snippets: root.snippets,
      folders: root.folders
    }, null, 2) + "\n")
  }

  function selectColor(hex) {
    var clean = ColorStudio.analyzeColor(hex)
    if (clean) {
      root.activeColorHex = clean.hex
      root.activeColorAnalysis = clean
    }
  }

  function copyText(str) {
    if (!str) return
    Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(str) + " | wl-copy"])
  }

  function prevMonth() {
    if (root.calendarMonth === 0) {
      root.calendarMonth = 11
      root.calendarYear -= 1
    } else {
      root.calendarMonth -= 1
    }
  }

  function nextMonth() {
    if (root.calendarMonth === 11) {
      root.calendarMonth = 0
      root.calendarYear += 1
    } else {
      root.calendarMonth += 1
    }
  }

  function getMonthName(m) {
    var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    return months[m]
  }

  function formatDateFilterLabel(f) {
    if (f === "today") return "Today"
    if (f === "yesterday") return "Yesterday"
    if (f === "7d") return "Last 7 Days"
    if (f === "30d") return "Last 30 Days"
    if (f === "mtd") return "This Month"
    return f
  }

  function setDateFilter(f) {
    root.activeDateFilter = (root.activeDateFilter === f) ? "" : f
    root.showCalendar = false
    root.rebuildDisplay()
  }

  function rebuildDisplay() {
    displayModel.clear()

    if (root.activeTab === 0 || root.activeTab === 1) {
      var cat = root.activeTab === 1 ? "pinned" : root.categoryFilter
      var rows = ClipboardHistory.displayRows(root.history, root.filterText, cat, root.activeDateFilter, 100)
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i]
        displayModel.append({
          itemType: "history",
          entryType: r.entryType,
          kind: r.kind || "text",
          colorValue: r.colorValue || "",
          colorRgb: r.colorRgb || "",
          codeLang: r.codeLang || "",
          fullText: r.fullText,
          previewText: r.previewText,
          previewImage: r.previewImage ? Util.fileUrl(r.previewImage) : "",
          path: r.path,
          mime: r.mime,
          timeAgo: r.timeAgo || "",
          capturedDate: r.capturedDate || "",
          charCount: r.charCount || 0,
          lineCount: r.lineCount || 1,
          wordCount: r.wordCount || 0,
          isPinned: !!r.isPinned,
          isFavorite: !!r.isFavorite,
          historyIndex: r.index,
          snippetIndex: -1,
          title: "",
          language: "",
          tags: ""
        })
      }
    } else if (root.activeTab === 2) { // Snippets
      var sRows = SnippetLib.displayRows(root.snippets, root.filterText, 100)
      for (var j = 0; j < sRows.length; j++) {
        var s = sRows[j]
        displayModel.append({
          itemType: "snippet",
          entryType: "text",
          kind: "code",
          colorValue: "",
          colorRgb: "",
          codeLang: s.language || "text",
          fullText: s.content,
          previewText: s.preview,
          previewImage: "",
          path: "",
          mime: "text/plain",
          timeAgo: "",
          capturedDate: "",
          charCount: s.content.length,
          lineCount: s.content.split("\n").length,
          wordCount: s.content.split(/\s+/).length,
          isPinned: false,
          isFavorite: !!s.favorite,
          historyIndex: -1,
          snippetIndex: s.index,
          title: s.title,
          language: s.language,
          tags: s.tags
        })
      }
    } else if (root.activeTab === 4) { // Queue
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
            colorRgb: ClipboardHistory.isHexColor(qTxt) ? ClipboardHistory.hexToRgb(qTxt.trim()) : "",
            codeLang: ClipboardHistory.detectCodeLanguage(qTxt),
            fullText: qTxt,
            previewText: (q + 1) + ". " + ClipboardHistory.previewText(qEntry),
            previewImage: qEntry.type === "image" ? Util.fileUrl(qEntry.path) : "",
            path: qEntry.path || "",
            mime: qEntry.mime || "text/plain",
            timeAgo: ClipboardHistory.formatTimeAgo(qEntry.capturedAt),
            capturedDate: String(qEntry.capturedAt || "").substring(0, 10),
            charCount: qTxt.length,
            lineCount: qTxt.split("\n").length,
            wordCount: qTxt.split(/\s+/).length,
            isPinned: false,
            isFavorite: false,
            historyIndex: qIdx,
            snippetIndex: -1,
            title: "Step " + (q + 1),
            language: "",
            tags: ""
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
      Quickshell.execDetached(["bash", "-c", "wl-copy --type " + Util.shellQuote(row.mime || "image/png") + " < " + Util.shellQuote(row.path)])
    } else if (row.fullText) {
      root.copyText(row.fullText)
    }
  }

  function togglePinRow(row) {
    if (!row || row.historyIndex < 0) return
    root.history = ClipboardHistory.togglePin(root.history, row.historyIndex)
    root.saveHistory()
    root.rebuildDisplay()
  }

  function toggleFavRow(row) {
    if (!row) return
    if (row.itemType === "history" && row.historyIndex >= 0) {
      root.history = ClipboardHistory.toggleFavorite(root.history, row.historyIndex)
      root.saveHistory()
    } else if (row.itemType === "snippet" && row.snippetIndex >= 0) {
      root.snippets = SnippetLib.toggleFavorite(root.snippets, row.snippetIndex)
      root.saveSnippets()
    }
    root.rebuildDisplay()
  }

  function openEditRow(row) {
    if (!row) return
    if (row.itemType === "snippet") {
      root.snippetEditIndex = row.snippetIndex
      root.snippetEditTitle = row.title || ""
      root.snippetEditContent = row.fullText || ""
      root.snippetEditLang = row.language || "javascript"
      root.snippetEditFolder = ""
      root.snippetEditOpen = true
    } else if (row.itemType === "history" && row.entryType === "text") {
      root.clipEditIndex = row.historyIndex
      root.clipEditContent = row.fullText || ""
      root.clipEditOpen = true
    }
  }

  function saveClipEdit() {
    if (root.clipEditIndex >= 0 && root.clipEditContent) {
      root.history = ClipboardHistory.updateEntryText(root.history, root.clipEditIndex, root.clipEditContent)
      root.saveHistory()
      root.clipEditOpen = false
      root.rebuildDisplay()
    }
  }

  function openTransformRow(row) {
    if (!row || row.entryType !== "text") return
    root.transformClipIndex = row.historyIndex
    root.transformOpen = true
  }

  function applyTransform(mode) {
    if (root.transformClipIndex >= 0) {
      var item = root.history[root.transformClipIndex]
      if (item && item.type === "text") {
        var transformed = ClipboardHistory.transformText(item.text, mode)
        root.history = ClipboardHistory.updateEntryText(root.history, root.transformClipIndex, transformed)
        root.saveHistory()
        root.transformOpen = false
        root.rebuildDisplay()
      }
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

  function mergeQueueClips() {
    if (root.pasteQueue.length < 2) return
    root.history = ClipboardHistory.mergeEntries(root.history, root.pasteQueue, root.mergeSeparator)
    root.saveHistory()
    root.pasteQueue = []
    root.mergeDialogOpen = false
    root.activeTab = 0
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
    contentWidth: panel.fittedContentWidth(Style.space(540))
    contentHeight: panel.fittedContentHeight(Style.space(660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        root.activeTab = (root.activeTab + direction + 5) % 5
        root.selectedIndex = 0
        root.rebuildDisplay()
      }
    }

    Column {
      id: mainColumn
      width: parent.width
      spacing: Style.space(10)

      // ==========================================
      // 1. HERO HEADER (Omarchy PanelHero Style)
      // ==========================================
      Row {
        width: parent.width
        height: Style.space(38)
        spacing: Style.space(10)

        // Logo & Title
        Row {
          spacing: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            width: Style.space(32); height: Style.space(32)
            radius: Style.space(8)
            color: root.incognito ? Util.alpha(Color.urgent, 0.15) : Util.alpha(Color.accent, 0.15)
            border.width: 1
            border.color: root.incognito ? Color.urgent : Color.accent

            Text {
              text: "󰅍"
              color: root.incognito ? Color.urgent : Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.heading
              anchors.centerIn: parent
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
              text: "ReClip"
              color: root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
            }

            Text {
              text: root.historyCount + " clips • " + root.pinnedCount + " pinned" + (root.incognito ? " • Incognito" : "")
              color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.55)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
          }
        }

        Item { Layout.fillWidth: true; width: Style.space(12) }

        // Trailing Controls (Timeline, Screenshot, Incognito Switch, Close)
        Row {
          spacing: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter

          // Timeline / Calendar Toggle (ReClip title-btn style)
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.showTimeline ? Color.accent : (root.activeDateFilter !== "" ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08))
            border.width: 1
            border.color: root.showTimeline || root.activeDateFilter !== "" ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "󰸗"
              color: root.showTimeline ? "#fff" : (root.activeDateFilter !== "" ? Color.accent : root.fg)
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.showTimeline = !root.showTimeline
            }
          }

          // Screenshot Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.12)
            Text {
              text: "󰄀"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.takeScreenshot()
            }
          }

          // Incognito Toggle Pill
          Rectangle {
            width: incogRow.implicitWidth + Style.space(12); height: Style.space(30)
            radius: Style.space(6)
            color: root.incognito ? Util.alpha(Color.urgent, 0.2) : Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.12)

            Row {
              id: incogRow
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text {
                text: root.incognito ? "󰈈" : "󰈉"
                color: root.incognito ? Color.urgent : root.fg
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.incognito ? "Incognito" : "Normal"
                color: root.incognito ? Color.urgent : root.fg
                font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleIncognito()
            }
          }

          // Close Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.12)
            Text { text: "✕"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }
      }

      // ==========================================
      // 2. SEGMENTED TAB BAR
      // ==========================================
      Rectangle {
        width: parent.width
        height: Style.space(32)
        radius: Style.space(8)
        color: Util.alpha(root.fg, 0.05)
        border.width: 1; border.color: Util.alpha(root.fg, 0.08)

        Row {
          anchors.fill: parent; anchors.margins: Style.space(2)
          spacing: Style.space(2)

          Repeater {
            model: [
              { id: 0, label: "History", icon: "󰅍", count: root.historyCount },
              { id: 1, label: "Pinned", icon: "󰐃", count: root.pinnedCount },
              { id: 2, label: "Snippets", icon: "󰅩", count: root.snippets.length },
              { id: 3, label: "Color Studio", icon: "󰏘", count: root.colorPalette.length },
              { id: 4, label: "Queue", icon: "󰆒", count: root.pasteQueue.length }
            ]

            Rectangle {
              required property var modelData
              width: (parent.width - Style.space(8)) / 5
              height: parent.height
              radius: Style.space(6)
              color: root.activeTab === modelData.id ? Color.accent : "transparent"

              Row {
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  text: parent.parent.modelData.icon
                  color: root.activeTab === parent.parent.modelData.id ? "#fff" : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: parent.parent.modelData.label + (parent.parent.modelData.count > 0 ? " (" + parent.parent.modelData.count + ")" : "")
                  color: root.activeTab === parent.parent.modelData.id ? "#fff" : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  font.bold: root.activeTab === parent.parent.modelData.id
                  elide: Text.ElideRight
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.activeTab = parent.modelData.id
                  root.selectedIndex = 0
                  root.rebuildDisplay()
                }
              }
            }
          }
        }
      }

      // =========================================================================
      // 3. COMPLETE RECLIP TIMELINE & CALENDAR (Parity with TimelineView.tsx)
      // =========================================================================
      Rectangle {
        visible: root.showTimeline && (root.activeTab === 0 || root.activeTab === 1)
        width: parent.width
        height: timelineContentCol.implicitHeight + Style.space(16)
        radius: Style.space(10)
        color: Util.alpha(root.fg, 0.04)
        border.width: 1; border.color: Util.alpha(root.fg, 0.1)

        Column {
          id: timelineContentCol
          anchors.fill: parent; anchors.margins: Style.space(10)
          spacing: Style.space(8)

          // Row 1: Title, Count, and Quick Presets (7d, 30d, MTD, Clear)
          Row {
            width: parent.width
            height: Style.space(24)

            Row {
              spacing: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              Text { text: "📅 Timeline"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              Text { text: root.historyCount + " clips"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.font.caption }
            }

            Item { Layout.fillWidth: true; width: Style.space(8) }

            Row {
              spacing: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter

              Repeater {
                model: [
                  { id: "7d", label: "7d", tip: "Last 7 days" },
                  { id: "30d", label: "30d", tip: "Last 30 days" },
                  { id: "mtd", label: "MTD", tip: "Month to date" }
                ]
                Rectangle {
                  required property var modelData
                  width: Style.space(34); height: Style.space(22); radius: Style.space(4)
                  color: root.activeDateFilter === modelData.id ? Color.accent : Util.alpha(root.fg, 0.08)
                  Text {
                    text: parent.modelData.label
                    color: root.activeDateFilter === parent.modelData.id ? "#fff" : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.setDateFilter(parent.modelData.id)
                  }
                }
              }

              // Clear button (✕)
              Rectangle {
                visible: root.activeDateFilter !== ""
                width: Style.space(22); height: Style.space(22); radius: Style.space(4)
                color: Util.alpha(Color.urgent, 0.15)
                Text { text: "✕"; color: Color.urgent; font.pixelSize: Style.space(10); font.bold: true; anchors.centerIn: parent }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.setDateFilter("")
                }
              }
            }
          }

          // Row 2: Zoom Levels (Hour, Day, Week, Month) & Calendar Toggle / Today
          Row {
            width: parent.width
            height: Style.space(24)

            // Zoom Buttons
            Row {
              spacing: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              Repeater {
                model: [
                  { id: "hour", label: "Hour" },
                  { id: "day", label: "Day" },
                  { id: "week", label: "Week" },
                  { id: "month", label: "Month" }
                ]
                Rectangle {
                  required property var modelData
                  width: Style.space(42); height: Style.space(20); radius: Style.space(4)
                  color: root.timelineZoom === modelData.id ? Color.accent : Util.alpha(root.fg, 0.06)
                  Text {
                    text: parent.modelData.label
                    color: root.timelineZoom === parent.modelData.id ? "#fff" : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.space(9)
                    font.bold: root.timelineZoom === parent.modelData.id
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.timelineZoom = parent.modelData.id
                  }
                }
              }
            }

            Item { Layout.fillWidth: true; width: Style.space(8) }

            // Calendar Dropdown Toggle & Today Jump
            Row {
              spacing: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter

              // Calendar Toggle Button
              Rectangle {
                width: calBtnRow.implicitWidth + Style.space(10); height: Style.space(22); radius: Style.space(4)
                color: root.showCalendar ? Color.accent : Util.alpha(root.fg, 0.08)
                Row {
                  id: calBtnRow
                  anchors.centerIn: parent; spacing: Style.space(4)
                  Text { text: "📆"; font.pixelSize: Style.space(10) }
                  Text {
                    text: "Calendar"
                    color: root.showCalendar ? "#fff" : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                  }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.showCalendar = !root.showCalendar
                }
              }

              // Today Jump Button
              Rectangle {
                width: Style.space(44); height: Style.space(22); radius: Style.space(4)
                color: root.activeDateFilter === "today" ? Color.accent : Util.alpha(root.fg, 0.08)
                Text {
                  text: "Today"
                  color: root.activeDateFilter === "today" ? "#fff" : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                  anchors.centerIn: parent
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.setDateFilter("today")
                }
              }
            }
          }

          // Mini Month Calendar View (Opens when showCalendar is true)
          Rectangle {
            visible: root.showCalendar
            width: parent.width
            height: calInnerCol.implicitHeight + Style.space(12)
            radius: Style.space(8)
            color: Util.alpha(root.fg, 0.04)
            border.width: 1; border.color: Util.alpha(root.fg, 0.08)

            Column {
              id: calInnerCol
              anchors.fill: parent; anchors.margins: Style.space(8)
              spacing: Style.space(6)

              // Month Navigation Header
              Row {
                width: parent.width
                height: Style.space(22)

                Rectangle {
                  width: Style.space(22); height: Style.space(22); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "◀"; color: root.fg; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                  MouseArea { anchors.fill: parent; onClicked: root.prevMonth(); cursorShape: Qt.PointingHandCursor }
                }

                Item { Layout.fillWidth: true; width: Style.space(6) }

                Text {
                  text: root.getMonthName(root.calendarMonth) + " " + root.calendarYear
                  color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                Item { Layout.fillWidth: true; width: Style.space(6) }

                Rectangle {
                  width: Style.space(22); height: Style.space(22); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "▶"; color: root.fg; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                  MouseArea { anchors.fill: parent; onClicked: root.nextMonth(); cursorShape: Qt.PointingHandCursor }
                }
              }

              // Day of Week Labels (S M T W T F S)
              Row {
                width: parent.width
                Repeater {
                  model: ["S", "M", "T", "W", "T", "F", "S"]
                  Text {
                    required property string modelData
                    width: parent.width / 7
                    text: modelData
                    color: Util.alpha(root.fg, 0.5)
                    font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                  }
                }
              }

              // Days Grid
              Grid {
                columns: 7
                width: parent.width
                rowSpacing: Style.space(2)

                Repeater {
                  model: root.calendarDays
                  Rectangle {
                    required property var modelData
                    width: parent.width / 7
                    height: Style.space(24)
                    radius: Style.space(4)
                    color: modelData.isPad ? "transparent" : (modelData.isSelected ? Color.accent : (modelData.count > 0 ? Util.alpha(Color.accent, Math.min(0.25 + modelData.count * 0.08, 0.75)) : "transparent"))
                    border.width: modelData.isToday && !modelData.isSelected ? 1.5 : 0
                    border.color: Color.accent

                    Text {
                      visible: !parent.modelData.isPad
                      text: String(parent.modelData.day)
                      color: parent.modelData.isSelected ? "#fff" : (parent.modelData.count > 0 ? root.fg : Util.alpha(root.fg, 0.35))
                      font.family: root.fontFamily; font.pixelSize: Style.space(9)
                      font.bold: parent.modelData.count > 0 || parent.modelData.isToday
                      anchors.centerIn: parent
                    }

                    // Clip heat dot below number
                    Rectangle {
                      visible: !parent.modelData.isPad && parent.modelData.count > 0 && !parent.modelData.isSelected
                      width: Style.space(3); height: Style.space(3); radius: Style.space(1.5)
                      color: Color.accent
                      anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                      anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                      anchors.fill: parent
                      enabled: !parent.modelData.isPad && parent.modelData.count > 0
                      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: {
                        root.setDateFilter(parent.modelData.dateStr)
                        root.showCalendar = false
                      }
                    }
                  }
                }
              }
            }
          }

          // Interactive Timeline Track with Heatmap Markers
          Item {
            width: parent.width
            height: Style.space(26)

            Rectangle {
              anchors.fill: parent
              radius: Style.space(6)
              color: Util.alpha(root.fg, 0.06)
              clip: true

              Repeater {
                model: root.timelineData.markers
                Rectangle {
                  required property var modelData
                  x: Math.max(0, Math.min(parent.width - Style.space(12), (parent.width - Style.space(12)) * (modelData.position / 100)))
                  width: Math.max(Style.space(10), (parent.width / Math.max(root.timelineData.markers.length, 1)) * 0.8)
                  height: parent.height
                  radius: Style.space(3)
                  color: Util.alpha(Color.accent, Math.max(0.35, modelData.intensity))

                  MouseArea {
                    id: markerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setDateFilter(parent.modelData.dateStr)
                  }

                  // Tooltip
                  Rectangle {
                    visible: markerHover.containsMouse
                    z: 50
                    anchors.bottom: parent.top; anchors.bottomMargin: Style.space(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tipContent.implicitWidth + Style.space(10)
                    height: tipContent.implicitHeight + Style.space(6)
                    radius: Style.space(4)
                    color: root.bg; border.width: 1; border.color: root.borderCol

                    Column {
                      id: tipContent
                      anchors.centerIn: parent
                      Text { text: parent.parent.parent.modelData.label; color: root.fg; font.pixelSize: Style.space(9); font.bold: true }
                      Text { text: parent.parent.parent.modelData.count + " clips"; color: Color.accent; font.pixelSize: Style.space(8) }
                    }
                  }
                }
              }
            }
          }

          // Timeline Range Dates & Active Selection Info
          Row {
            width: parent.width
            height: Style.space(16)

            Text {
              text: root.timelineData.oldestStr
              color: Util.alpha(root.fg, 0.45); font.family: root.fontFamily; font.pixelSize: Style.space(9)
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.activeDateFilter !== "" ? ("Filtered: " + root.formatDateFilterLabel(root.activeDateFilter)) : "Click markers to filter"
              color: root.activeDateFilter !== "" ? Color.accent : Util.alpha(root.fg, 0.45)
              font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: root.activeDateFilter !== ""
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.timelineData.newestStr
              color: Util.alpha(root.fg, 0.45); font.family: root.fontFamily; font.pixelSize: Style.space(9)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // ==========================================
      // 4. SEARCH & QUICK FILTER ROW
      // ==========================================
      Row {
        visible: root.activeTab === 0 || root.activeTab === 1 || root.activeTab === 2
        width: parent.width
        spacing: Style.space(6)

        // Search Input
        Rectangle {
          width: parent.width
          height: Style.space(38)
          radius: Style.cornerRadius
          color: Util.alpha(root.fg, 0.05)
          border.width: 1
          border.color: searchInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10); anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              text: "󰍉"
              color: searchInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.5)
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchInput
              width: parent.width - Style.space(50)
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
              text: root.filterText
              anchors.verticalCenter: parent.verticalCenter
              clip: true; selectByMouse: true

              onTextChanged: {
                root.filterText = text
                root.selectedIndex = 0
                root.rebuildDisplay()
              }

              // Quick 1-9 paste shortcuts!
              Keys.onPressed: function(event) {
                if (!event.modifiers && event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && root.filterText === "") {
                  var numIdx = event.key - Qt.Key_1
                  if (numIdx < displayModel.count) {
                    root.pasteRow(displayModel.get(numIdx))
                    event.accepted = true
                    return
                  }
                }
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
                  if (event.modifiers & Qt.ShiftModifier) root.toggleQueue(row)
                  else root.pasteRow(row)
                }
              }
              Keys.onEscapePressed: {
                if (root.showCalendar) root.showCalendar = false
                else if (root.showTimeline) root.showTimeline = false
                else if (root.filterText !== "") root.filterText = ""
                else if (root.activeDateFilter !== "") root.setDateFilter("")
                else root.close()
              }

              Text {
                visible: searchInput.text === "" && !searchInput.activeFocus
                text: root.activeTab === 0 ? "Search history, code, colors… (Press 1-9 to paste)" : (root.activeTab === 2 ? "Search snippets…" : "Filter items…")
                color: Util.alpha(root.fg, 0.4)
                font.family: root.fontFamily; font.pixelSize: Style.font.body
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
      }

      // Active Date Filter Banner
      Row {
        visible: root.activeDateFilter !== "" && root.activeTab === 0
        spacing: Style.space(6)

        Rectangle {
          height: Style.space(22)
          radius: Style.space(11)
          color: Util.alpha(Color.accent, 0.15)
          border.width: 1; border.color: Color.accent
          width: filterDateContent.implicitWidth + Style.space(20)

          Row {
            id: filterDateContent
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              text: "󰸗 Filtered by: " + root.formatDateFilterLabel(root.activeDateFilter)
              color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
            }
            Text { text: "✕"; color: Color.accent; font.pixelSize: Style.space(10); font.bold: true }
          }

          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.setDateFilter("")
          }
        }
      }

      // Category Chips (History tab only)
      Row {
        visible: root.activeTab === 0
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: [
            { id: "all", label: "All", icon: "󰅍" },
            { id: "code", label: "Code", icon: "󰅩" },
            { id: "color", label: "Colors", icon: "󰏘" },
            { id: "link", label: "Links", icon: "󰌹" },
            { id: "image", label: "Images", icon: "" },
            { id: "file", label: "Files", icon: "󰈔" }
          ]

          Rectangle {
            required property var modelData
            width: chipContent.implicitWidth + Style.space(16)
            height: Style.space(24)
            radius: Style.space(12)
            color: root.categoryFilter === modelData.id ? Color.accent : Util.alpha(root.fg, 0.06)
            border.width: 1
            border.color: root.categoryFilter === modelData.id ? Color.accent : Util.alpha(root.fg, 0.1)

            Row {
              id: chipContent
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text {
                text: parent.parent.modelData.icon
                color: root.categoryFilter === parent.parent.modelData.id ? "#fff" : root.fg
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
              }
              Text {
                text: parent.parent.modelData.label
                color: root.categoryFilter === parent.parent.modelData.id ? "#fff" : root.fg
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                font.bold: root.categoryFilter === parent.parent.modelData.id
              }
            }

            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.categoryFilter = parent.modelData.id
                root.selectedIndex = 0
                root.rebuildDisplay()
              }
            }
          }
        }
      }

      // =========================================================================
      // TAB 3: COLOR STUDIO (Dedicated Advanced Color Studio)
      // =========================================================================
      Flickable {
        id: colorStudioFlick
        visible: root.activeTab === 3
        width: parent.width
        height: Style.space(510)
        contentWidth: width
        contentHeight: colorStudioCol.implicitHeight + Style.space(20)
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: colorStudioCol
          width: parent.width
          spacing: Style.space(12)

          // Top Inspector Hero
          Rectangle {
            width: parent.width
            height: Style.space(110)
            radius: Style.space(8)
            color: Util.alpha(root.fg, 0.04)
            border.width: 1; border.color: Util.alpha(root.fg, 0.08)

            Row {
              anchors.fill: parent; anchors.margins: Style.space(10)
              spacing: Style.space(12)

              // Large Color Swatch
              Rectangle {
                width: Style.space(90); height: Style.space(90)
                radius: Style.space(8)
                color: root.activeColorHex
                border.width: 1; border.color: Util.alpha(root.fg, 0.2)

                Text {
                  text: root.activeColorHex
                  color: root.activeColorAnalysis && root.activeColorAnalysis.contrastBlack > 4.5 ? "#000" : "#fff"
                  font.family: "monospace"; font.pixelSize: Style.space(10); font.bold: true
                  anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                  anchors.horizontalCenter: parent.horizontalCenter
                }
              }

              // Color Inputs & Quick Actions
              Column {
                width: parent.width - Style.space(115)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Row {
                  width: parent.width; spacing: Style.space(6)
                  Rectangle {
                    width: parent.width - Style.space(70); height: Style.space(30); radius: Style.space(4)
                    color: Util.alpha(root.fg, 0.06); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                    TextInput {
                      id: colorTextInput
                      anchors.fill: parent; anchors.margins: Style.space(4)
                      color: root.fg; font.family: "monospace"; font.pixelSize: Style.font.body
                      text: root.activeColorHex
                      onAccepted: root.selectColor(text)
                    }
                  }
                  Rectangle {
                    width: Style.space(64); height: Style.space(30); radius: Style.space(4)
                    color: Color.accent
                    Text { text: "Inspect"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: root.selectColor(colorTextInput.text); cursorShape: Qt.PointingHandCursor }
                  }
                }

                // WCAG Contrast Badges
                Row {
                  spacing: Style.space(8)
                  Rectangle {
                    height: Style.space(18); radius: Style.space(3); width: whiteA11y.implicitWidth + Style.space(8)
                    color: root.activeColorAnalysis && root.activeColorAnalysis.passAAWhite ? "#10B981" : "#EF4444"
                    Text {
                      id: whiteA11y
                      text: "White: " + (root.activeColorAnalysis ? root.activeColorAnalysis.contrastWhite + ":1" : "")
                      color: "#fff"; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent
                    }
                  }
                  Rectangle {
                    height: Style.space(18); radius: Style.space(3); width: blackA11y.implicitWidth + Style.space(8)
                    color: root.activeColorAnalysis && root.activeColorAnalysis.passAABlack ? "#10B981" : "#EF4444"
                    Text {
                      id: blackA11y
                      text: "Black: " + (root.activeColorAnalysis ? root.activeColorAnalysis.contrastBlack + ":1" : "")
                      color: "#fff"; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent
                    }
                  }
                }

                Text {
                  text: "Click any color code below to copy to clipboard"
                  color: Util.alpha(root.fg, 0.45); font.family: root.fontFamily; font.pixelSize: Style.space(9)
                }
              }
            }
          }

          // Format Cards Grid (HEX, RGB, HSL, CMYK)
          Grid {
            columns: 2
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: [
                { label: "HEX", val: root.activeColorAnalysis ? root.activeColorAnalysis.hex : "" },
                { label: "RGB", val: root.activeColorAnalysis ? root.activeColorAnalysis.rgbStr : "" },
                { label: "HSL", val: root.activeColorAnalysis ? root.activeColorAnalysis.hslStr : "" },
                { label: "CMYK", val: root.activeColorAnalysis ? root.activeColorAnalysis.cmykStr : "" }
              ]
              Rectangle {
                required property var modelData
                width: (parent.width - Style.space(6)) / 2
                height: Style.space(42)
                radius: Style.space(6)
                color: Util.alpha(root.fg, 0.05)
                border.width: 1; border.color: Util.alpha(root.fg, 0.08)

                Row {
                  anchors.fill: parent; anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: parent.parent.parent.modelData.label; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8); font.bold: true }
                    Text { text: parent.parent.parent.modelData.val; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(10); font.bold: true }
                  }

                  Item { Layout.fillWidth: true }
                  Text { text: "󰆏"; color: Util.alpha(root.fg, 0.4); font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.copyText(parent.modelData.val)
                }
              }
            }
          }

          // Harmonies Section
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "Color Harmonies"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
            }

            Repeater {
              model: root.activeColorAnalysis ? root.activeColorAnalysis.harmonies : []
              Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(46)
                radius: Style.space(6)
                color: Util.alpha(root.fg, 0.03)
                border.width: 1; border.color: Util.alpha(root.fg, 0.06)

                Row {
                  anchors.fill: parent; anchors.margins: Style.space(6)
                  spacing: Style.space(8)

                  Text {
                    width: Style.space(110)
                    text: parent.parent.modelData.name
                    color: Util.alpha(root.fg, 0.7)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Repeater {
                      model: parent.parent.parent.modelData.colors
                      Rectangle {
                        required property string modelData
                        width: Style.space(56); height: Style.space(32); radius: Style.space(4)
                        color: modelData
                        border.width: 1; border.color: Util.alpha(root.fg, 0.2)

                        Text {
                          text: parent.modelData
                          color: ColorStudio.getContrastRatio(parent.modelData, "#000000") > 4.5 ? "#000" : "#fff"
                          font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.selectColor(parent.modelData)
                            root.copyText(parent.modelData)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // Tints & Shades Strips
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text { text: "Tints (Lighter) & Shades (Darker)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }

            Row {
              width: parent.width; spacing: Style.space(2)
              Repeater {
                model: root.activeColorAnalysis ? root.activeColorAnalysis.tints.concat(root.activeColorAnalysis.shades) : []
                Rectangle {
                  required property string modelData
                  width: (parent.width - Style.space(22)) / 12
                  height: Style.space(28); radius: Style.space(3)
                  color: modelData
                  border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectColor(parent.modelData)
                      root.copyText(parent.modelData)
                    }
                  }
                }
              }
            }
          }

          // Clipboard Extracted Palettes
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "Extracted Clipboard Palettes (" + root.colorPalette.length + " colors)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
            }

            Grid {
              columns: 5
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.colorPalette
                Rectangle {
                  required property var modelData
                  width: (parent.width - Style.space(24)) / 5
                  height: Style.space(40); radius: Style.space(4)
                  color: modelData.hex
                  border.width: 1; border.color: Util.alpha(root.fg, 0.25)

                  Text {
                    text: parent.modelData.hex
                    color: ColorStudio.getContrastRatio(parent.modelData.hex, "#000000") > 4.5 ? "#000" : "#fff"
                    font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true
                    anchors.centerIn: parent
                  }

                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectColor(parent.modelData.hex)
                      root.copyText(parent.modelData.hex)
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // 4. MAIN SCROLLABLE LIST (Tabs 0, 1, 2, 4)
      // ==========================================
      Rectangle {
        visible: root.activeTab !== 3
        width: parent.width
        height: root.showCalendar ? Style.space(200) : (root.showTimeline ? Style.space(330) : (root.activeTab === 0 ? Style.space(450) : Style.space(475)))
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
            required property string colorRgb
            required property string codeLang
            required property string fullText
            required property string previewText
            required property string previewImage
            required property string path
            required property string mime
            required property string timeAgo
            required property string capturedDate
            required property int charCount
            required property int lineCount
            required property int wordCount
            required property bool isPinned
            required property bool isFavorite
            required property int historyIndex
            required property int snippetIndex
            required property string title

            readonly property bool isSelected: root.selectedIndex === index
            readonly property bool isHovered: cardMouse.containsMouse

            width: list.width - Style.space(6)
            height: kind === "code" ? Style.space(78) : (entryType === "image" ? Style.space(80) : Style.space(62))
            radius: Style.space(8)
            color: isSelected ? root.selBg : (isHovered ? Util.alpha(root.fg, 0.06) : Util.alpha(root.fg, 0.03))
            border.width: 1
            border.color: isSelected ? Color.accent : (cardItem.isPinned ? Util.alpha(Color.accent, 0.4) : Util.alpha(root.fg, 0.08))

            // Glowing Left Accent Line for selected item
            Rectangle {
              visible: cardItem.isSelected
              width: Style.space(3); height: parent.height - Style.space(12)
              radius: Style.space(2)
              color: Color.accent
              anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
              id: cardMouse
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
              anchors.leftMargin: cardItem.isSelected ? Style.space(12) : Style.space(8)
              spacing: Style.space(10)

              // Type Visual / Swatch / Thumbnail
              Rectangle {
                width: Style.space(42); height: Style.space(42)
                radius: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                color: cardItem.kind === "color" && cardItem.colorValue !== ""
                  ? cardItem.colorValue
                  : Util.alpha(root.fg, 0.08)
                border.width: cardItem.kind === "color" ? 1 : 0
                border.color: Util.alpha(root.fg, 0.25)

                Text {
                  visible: cardItem.kind !== "color" && cardItem.entryType !== "image"
                  text: cardItem.kind === "code" ? "󰅩" : (cardItem.kind === "link" ? "󰌹" : (cardItem.entryType === "file" ? "󰈔" : "󰅍"))
                  color: cardItem.isSelected ? root.selFg : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.heading
                  anchors.centerIn: parent
                }

                Image {
                  visible: cardItem.entryType === "image" && cardItem.previewImage !== ""
                  anchors.fill: parent; anchors.margins: 1
                  source: cardItem.previewImage
                  fillMode: Image.PreserveAspectCrop
                  clip: true
                }
              }

              // Metadata & Content Details
              Column {
                width: parent.width - Style.space(200)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                // Meta Row (Index badge, Pin, Tag, Time Ago)
                Row {
                  spacing: Style.space(6)

                  // 1-9 Quick paste badge
                  Rectangle {
                    visible: cardItem.index < 9 && root.activeTab === 0
                    width: Style.space(14); height: Style.space(14)
                    radius: Style.space(3)
                    color: Util.alpha(root.fg, 0.12)
                    Text {
                      text: String(cardItem.index + 1)
                      color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true
                      anchors.centerIn: parent
                    }
                  }

                  // Pinned indicator
                  Text {
                    visible: cardItem.isPinned
                    text: "󰐃"
                    color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Favorite indicator
                  Text {
                    visible: cardItem.isFavorite
                    text: "⭐"
                    font.pixelSize: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Type Tag / Language
                  Rectangle {
                    visible: cardItem.kind === "code" || cardItem.kind === "color"
                    width: tagTxt.implicitWidth + Style.space(8); height: Style.space(14)
                    radius: Style.space(3)
                    color: cardItem.kind === "color" ? Util.alpha(root.fg, 0.1) : Util.alpha(Color.accent, 0.2)
                    Text {
                      id: tagTxt
                      text: cardItem.kind === "color" ? cardItem.colorValue : (cardItem.codeLang || "CODE")
                      color: cardItem.kind === "color" ? root.fg : Color.accent
                      font.pixelSize: Style.space(9); font.bold: true
                      anchors.centerIn: parent
                    }
                  }

                  // Title (for Snippets)
                  Text {
                    visible: cardItem.title !== ""
                    text: cardItem.title
                    color: cardItem.isSelected ? root.selFg : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                  }

                  // Time ago
                  Text {
                    visible: cardItem.timeAgo !== ""
                    text: cardItem.timeAgo
                    color: Util.alpha(root.fg, 0.45)
                    font.family: root.fontFamily; font.pixelSize: Style.space(9)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Preview Content
                Text {
                  width: parent.width
                  text: cardItem.previewText
                  color: cardItem.isSelected ? root.selFg : Util.alpha(root.fg, 0.9)
                  font.family: cardItem.kind === "code" ? "monospace" : root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  maximumLineCount: cardItem.kind === "code" ? 2 : 1
                  wrapMode: Text.WrapAnywhere
                }

                // Stats (lines / characters)
                Text {
                  visible: cardItem.entryType === "text" && cardItem.fullText.length > 0
                  text: cardItem.lineCount + " lines • " + cardItem.charCount + " chars"
                  color: Util.alpha(root.fg, 0.4)
                  font.family: root.fontFamily; font.pixelSize: Style.space(9)
                }
              }

              // ==========================================
              // ACTION BUTTONS TOOLBAR
              // ==========================================
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                // Quick Copy
                Rectangle {
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "󰆏"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRow(displayModel.get(cardItem.index))
                  }
                }

                // Pin / Unpin
                Rectangle {
                  visible: cardItem.itemType === "history"
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: cardItem.isPinned ? Color.accent : Util.alpha(root.fg, 0.08)
                  Text {
                    text: "󰐃"
                    color: cardItem.isPinned ? "#fff" : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePinRow(displayModel.get(cardItem.index))
                  }
                }

                // Favorite Star
                Rectangle {
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: cardItem.isFavorite ? Color.accent : Util.alpha(root.fg, 0.08)
                  Text {
                    text: "⭐"
                    font.pixelSize: Style.space(10)
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleFavRow(displayModel.get(cardItem.index))
                  }
                }

                // Edit Clip inline
                Rectangle {
                  visible: cardItem.entryType === "text"
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "✏"; color: root.fg; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openEditRow(displayModel.get(cardItem.index))
                  }
                }

                // Transform Text Case
                Rectangle {
                  visible: cardItem.entryType === "text" && cardItem.itemType === "history"
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "🔤"; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTransformRow(displayModel.get(cardItem.index))
                  }
                }

                // QR Code
                Rectangle {
                  visible: cardItem.entryType === "text" && cardItem.fullText !== ""
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.08)
                  Text { text: "󰐳"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.showQrModal(cardItem.fullText)
                  }
                }

                // Add to Queue
                Rectangle {
                  visible: cardItem.itemType === "history"
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
                  color: root.pasteQueue.indexOf(cardItem.historyIndex) >= 0 ? Color.accent : Util.alpha(root.fg, 0.08)
                  Text {
                    text: "+"
                    color: root.pasteQueue.indexOf(cardItem.historyIndex) >= 0 ? "#fff" : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleQueue(displayModel.get(cardItem.index))
                  }
                }

                // Delete
                Rectangle {
                  width: Style.space(26); height: Style.space(26); radius: Style.space(4)
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
          visible: displayModel.count === 0 && root.activeTab !== 3
          anchors.centerIn: parent
          spacing: Style.space(10)
          Text { text: "󰅍"; color: Util.alpha(root.fg, 0.25); font.family: root.fontFamily; font.pixelSize: Style.space(42); anchors.horizontalCenter: parent.horizontalCenter }
          Text {
            text: root.filterText !== "" ? "No matching clips found" : (root.activeTab === 0 ? (root.activeDateFilter !== "" ? "No clips recorded for this date" : "Clipboard history is empty") : (root.activeTab === 1 ? "No pinned items yet • Click 󰐃 on any clip" : (root.activeTab === 2 ? "No snippets created yet" : "Paste queue is empty")))
            color: Util.alpha(root.fg, 0.5)
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            anchors.horizontalCenter: parent.horizontalCenter
          }
        }
      }

      // ==========================================
      // 5. FOOTER STATUS & CHEATSHEET
      // ==========================================
      Row {
        width: parent.width
        height: Style.space(24)
        spacing: Style.space(8)

        Text {
          text: "[1-9] Quick Paste • ↵ Paste • P Pin • F Star • 󰸗 Date Filter • 🔤 Transform • Del Remove"
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
            text: "Clear History"
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

    // ==========================================
    // MODAL: CLIP IN-PLACE EDITOR
    // ==========================================
    Rectangle {
      visible: root.clipEditOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 50

      Rectangle {
        width: parent.width * 0.92; height: parent.height * 0.82
        radius: Style.cornerRadius
        color: root.bg; border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent; anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Text { text: "Edit Clip"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }

          Rectangle {
            width: parent.width; height: parent.height - Style.space(80)
            radius: Style.space(6); color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.12)
            Flickable {
              anchors.fill: parent; anchors.margins: Style.space(8); contentWidth: width; clip: true
              TextEdit {
                id: clipBodyInput
                width: parent.width
                color: root.fg; font.family: "monospace"; font.pixelSize: Style.font.body
                wrapMode: TextEdit.Wrap
                text: root.clipEditContent
                onTextChanged: root.clipEditContent = text
              }
            }
          }

          Row {
            anchors.right: parent.right; spacing: Style.space(8)
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.fg, 0.1)
              Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.clipEditOpen = false; cursorShape: Qt.PointingHandCursor }
            }
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Color.accent
              Text { text: "Save"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.saveClipEdit(); cursorShape: Qt.PointingHandCursor }
            }
          }
        }
      }
    }

    // ==========================================
    // MODAL: TEXT TRANSFORMS
    // ==========================================
    Rectangle {
      visible: root.transformOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 50

      Rectangle {
        width: Style.space(280); height: Style.space(340)
        radius: Style.cornerRadius
        color: root.bg; border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent; anchors.margins: Style.space(16)
          spacing: Style.space(8)

          Text { text: "Transform Text"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }

          Repeater {
            model: [
              { id: "upper", label: "UPPERCASE" },
              { id: "lower", label: "lowercase" },
              { id: "title", label: "Title Case" },
              { id: "trim", label: "Trim Whitespace" },
              { id: "kebab", label: "kebab-case" },
              { id: "snake", label: "snake_case" },
              { id: "json_pretty", label: "Beautify JSON" },
              { id: "json_minify", label: "Minify JSON" }
            ]

            Rectangle {
              required property var modelData
              width: parent.width; height: Style.space(28); radius: Style.space(4)
              color: tfMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.05)

              Text {
                text: parent.modelData.label; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                anchors.centerIn: parent
              }

              MouseArea {
                id: tfMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.applyTransform(parent.modelData.id)
              }
            }
          }

          Rectangle {
            width: parent.width; height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.fg, 0.1)
            Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; onClicked: root.transformOpen = false; cursorShape: Qt.PointingHandCursor }
          }
        }
      }
    }

    // ==========================================
    // MODAL: MERGE DIALOG
    // ==========================================
    Rectangle {
      visible: root.mergeDialogOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 50

      Rectangle {
        width: Style.space(300); height: Style.space(220)
        radius: Style.cornerRadius
        color: root.bg; border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent; anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Text { text: "Merge Queued Clips"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
          Text { text: "Combine " + root.pasteQueue.length + " clips into a single new clip:"; color: Util.alpha(root.fg, 0.65); font.pixelSize: Style.font.caption }

          Row {
            spacing: Style.space(8)
            Repeater {
              model: [
                { id: "\n", label: "Newlines" },
                { id: " ", label: "Spaces" },
                { id: ", ", label: "Commas" }
              ]
              Rectangle {
                required property var modelData
                width: Style.space(80); height: Style.space(28); radius: Style.space(4)
                color: root.mergeSeparator === modelData.id ? Color.accent : Util.alpha(root.fg, 0.08)
                Text { text: parent.modelData.label; color: root.mergeSeparator === parent.modelData.id ? "#fff" : root.fg; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: root.mergeSeparator = parent.modelData.id; cursorShape: Qt.PointingHandCursor }
              }
            }
          }

          Row {
            anchors.right: parent.right; spacing: Style.space(8)
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.fg, 0.1)
              Text { text: "Cancel"; color: root.fg; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.mergeDialogOpen = false; cursorShape: Qt.PointingHandCursor }
            }
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Color.accent
              Text { text: "Merge"; color: "#fff"; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.mergeQueueClips(); cursorShape: Qt.PointingHandCursor }
            }
          }
        }
      }
    }

    // ==========================================
    // MODAL: SNIPPET EDITOR
    // ==========================================
    Rectangle {
      visible: root.snippetEditOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 50

      Rectangle {
        width: parent.width * 0.92; height: parent.height * 0.85
        radius: Style.cornerRadius
        color: root.bg; border.width: 1; border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent; anchors.margins: Style.space(16)
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
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.fg, 0.1)
              Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.snippetEditOpen = false; cursorShape: Qt.PointingHandCursor }
            }
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Color.accent
              Text { text: "Save"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.snippetEditIndex >= 0) {
                    root.snippets = SnippetLib.updateSnippet(root.snippets, root.snippetEditIndex, {
                      title: root.snippetEditTitle, content: root.snippetEditContent,
                      language: root.snippetEditLang, folder: root.snippetEditFolder
                    })
                  } else {
                    root.snippets = SnippetLib.addSnippet(root.snippets, {
                      title: root.snippetEditTitle || "Untitled", content: root.snippetEditContent,
                      language: root.snippetEditLang, folder: root.snippetEditFolder
                    })
                  }
                  root.saveSnippets()
                  root.snippetEditOpen = false
                  root.rebuildDisplay()
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // MODAL: QR CODE MODAL
    // ==========================================
    Rectangle {
      visible: root.qrOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 50

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

    // ==========================================
    // MODAL: CLEAR CONFIRMATION
    // ==========================================
    Rectangle {
      visible: root.clearConfirmOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 50

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
                  root.history = []
                  root.saveHistory()
                  root.clearConfirmOpen = false
                  root.rebuildDisplay()
                }
              }
            }
          }
        }
      }
    }
  }
}
