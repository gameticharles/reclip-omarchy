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
  property string ocrScript: pluginDir + "/ocr-capture.sh"
  property string settingsPath: stateDir + "/settings.json"

  property bool incognito: false
  // Tabs: 0: History, 1: Pinned/Favs, 2: Snippets, 3: Color Studio, 4: Queue
  property int activeTab: 0
  property string categoryFilter: "all"
  property string filterText: ""
  property int selectedIndex: 0
  property int historyLimit: 500

  // Settings & Privacy State
  property bool settingsOpen: false
  property int settingsMaxClips: 500
  property int settingsRetainDays: 30
  property bool settingsIgnoreSensitive: true

  // Image Zoom Modal State
  property bool imageZoomOpen: false
  property string imageZoomPath: ""
  property real imageZoomScale: 1.0
  property real imageZoomPanX: 0.0
  property real imageZoomPanY: 0.0

  // Bulk Selection Mode State
  property bool bulkMode: false
  property var bulkSelectedIndices: []

  // Tag / Collection Editor State
  property bool tagModalOpen: false
  property int tagModalClipIndex: -1
  property var tagModalCurrentTags: []
  property string tagModalInputText: ""

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
  property int colorStudioSubTab: 0 // 0: Analyze, 1: Mixer, 2: Harmonies, 3: A11y, 4: Gradient, 5: Library
  property bool showDevFormats: false

  // Color Studio Mixer State
  property string mixColor1: "#FF0000"
  property string mixColor2: "#0000FF"
  property real mixRatio: 0.5
  property int mixSteps: 5
  property string mixMode: "rgb" // "rgb", "lab", "oklch"
  property string blendMode: "normal" // "normal", "multiply", "screen", "overlay", "soft-light", "hard-light", "difference", "exclusion"

  // Color Studio Harmonies State
  property int harmonyAngleOffset: 0
  property bool lockHarmonyColor: false

  // Color Studio Accessibility State
  property string contrastColor: "#FFFFFF"

  // Color Studio Gradient State
  property string gradientType: "linear" // "linear", "radial", "conic"
  property int gradientAngle: 90
  property var gradientStops: [
    { color: "#3B82F6", position: 0 },
    { color: "#6366F1", position: 100 }
  ]

  // Color Studio Library State
  property string savedPalettesPath: stateDir + "/saved-palettes.json"
  property var savedPalettes: []
  property string colorImportText: ""
  property string editingPaletteId: ""

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
  readonly property var allTags: ClipboardHistory.getAllTags(history)
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

  property int activeMenuClipIndex: -1
  property point activeMenuPos: Qt.point(0, 0)

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
    root.imageZoomOpen = false
    root.settingsOpen = false
    root.tagModalOpen = false
    root.bulkMode = false
    root.bulkSelectedIndices = []
    root.activeMenuClipIndex = -1
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
    root.imageZoomOpen = false
    root.settingsOpen = false
    root.tagModalOpen = false
    root.bulkMode = false
    root.bulkSelectedIndices = []
    root.activeMenuClipIndex = -1
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
    var parsed = ColorStudio.parseColor(hex) || hex
    var clean = ColorStudio.analyzeColor(parsed)
    if (clean) {
      root.activeColorHex = clean.hex
      root.activeColorAnalysis = clean
    }
  }

  function randomColor() {
    var r = Math.floor(Math.random() * 256)
    var g = Math.floor(Math.random() * 256)
    var b = Math.floor(Math.random() * 256)
    root.selectColor(ColorStudio.rgbToHex(r, g, b))
  }

  function loadSavedPalettes(raw) {
    try {
      var arr = JSON.parse(raw)
      if (Array.isArray(arr)) root.savedPalettes = arr
    } catch(e) {
      root.savedPalettes = []
    }
  }

  function saveSavedPalettes() {
    savedPalettesFile.setText(JSON.stringify(root.savedPalettes, null, 2) + "\n")
  }

  function saveCurrentPalette() {
    var colors = [root.activeColorHex]
    if (root.activeColorAnalysis && root.activeColorAnalysis.harmonies && root.activeColorAnalysis.harmonies.length > 0) {
      var comp = root.activeColorAnalysis.harmonies[0].colors
      if (comp && comp.length > 1) colors.push(comp[1])
    }
    if (root.activeColorAnalysis && root.activeColorAnalysis.tints && root.activeColorAnalysis.tints.length > 2) {
      colors.push(root.activeColorAnalysis.tints[2])
    }
    if (root.activeColorAnalysis && root.activeColorAnalysis.shades && root.activeColorAnalysis.shades.length > 2) {
      colors.push(root.activeColorAnalysis.shades[2])
    }
    var newPal = {
      id: "pal-" + Date.now(),
      name: "Palette " + (root.savedPalettes.length + 1),
      colors: colors,
      createdAt: Date.now(),
      tags: []
    }
    var updated = [newPal].concat(root.savedPalettes)
    root.savedPalettes = updated
    root.saveSavedPalettes()
    Quickshell.execDetached(["notify-send", "-a", "ReClip", "Palette Saved", "Added " + newPal.name + " to Library"])
  }

  function deleteSavedPalette(id) {
    var updated = []
    for (var i = 0; i < root.savedPalettes.length; i++) {
      if (root.savedPalettes[i].id !== id) updated.push(root.savedPalettes[i])
    }
    root.savedPalettes = updated
    root.saveSavedPalettes()
  }

  function renameSavedPalette(id, newName) {
    var updated = []
    for (var i = 0; i < root.savedPalettes.length; i++) {
      var p = root.savedPalettes[i]
      if (p.id === id) p.name = newName
      updated.push(p)
    }
    root.savedPalettes = updated
    root.saveSavedPalettes()
  }

  function addSavedPaletteTag(id, tag) {
    var t = String(tag || "").trim().replace("#", "")
    if (!t) return
    var updated = []
    for (var i = 0; i < root.savedPalettes.length; i++) {
      var p = root.savedPalettes[i]
      if (p.id === id) {
        var tags = p.tags || []
        if (tags.indexOf(t) === -1) tags.push(t)
        p.tags = tags
      }
      updated.push(p)
    }
    root.savedPalettes = updated
    root.saveSavedPalettes()
  }

  function removeSavedPaletteTag(id, tag) {
    var updated = []
    for (var i = 0; i < root.savedPalettes.length; i++) {
      var p = root.savedPalettes[i]
      if (p.id === id) {
        var tags = p.tags || []
        p.tags = tags.filter(function(x) { return x !== tag })
      }
      updated.push(p)
    }
    root.savedPalettes = updated
    root.saveSavedPalettes()
  }

  function importPaletteFromText(txt) {
    var text = String(txt || "").trim()
    if (!text) return
    var colors = []
    if (text.startsWith("[")) {
      try {
        var parsed = JSON.parse(text)
        if (Array.isArray(parsed)) {
          colors = parsed.filter(function(c) {
            return typeof c === "string" && (c.startsWith("#") || c.startsWith("rgb"))
          })
        }
      } catch(e) {}
    }
    if (colors.length === 0) {
      var matches = text.match(/#[0-9A-Fa-f]{6}/g)
      if (matches) colors = matches
    }
    if (colors.length > 0) {
      var newPal = {
        id: "pal-" + Date.now(),
        name: "Imported Palette",
        colors: colors,
        createdAt: Date.now(),
        tags: ["imported"]
      }
      root.savedPalettes = [newPal].concat(root.savedPalettes)
      root.saveSavedPalettes()
      root.colorImportText = ""
      Quickshell.execDetached(["notify-send", "-a", "ReClip", "Palette Imported", "Added " + colors.length + " colors to Library"])
    } else {
      Quickshell.execDetached(["notify-send", "-a", "ReClip", "Import Failed", "No valid HEX or JSON colors found"])
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

  // --- OCR Text Recognition Helpers ---
  function captureOcrScreen() {
    root.close()
    Quickshell.execDetached([root.ocrScript])
  }

  function runOcrOnImage(imgUriOrPath) {
    if (!imgUriOrPath) return
    var cleanPath = String(imgUriOrPath).replace(/^file:\/\//, "")
    Quickshell.execDetached([root.ocrScript, cleanPath])
  }

  // --- URL Open in Browser Helper ---
  function openUrlInBrowser(urlStr) {
    if (!urlStr) return
    Quickshell.execDetached(["xdg-open", urlStr])
  }

  // --- Image Zoom Helpers ---
  function openImageZoom(imgUriOrPath) {
    if (!imgUriOrPath) return
    root.imageZoomPath = String(imgUriOrPath).replace(/^file:\/\//, "")
    root.imageZoomScale = 1.0
    root.imageZoomPanX = 0.0
    root.imageZoomPanY = 0.0
    root.imageZoomOpen = true
  }

  function closeImageZoom() {
    root.imageZoomOpen = false
  }

  function resetImageZoom() {
    root.imageZoomScale = 1.0
    root.imageZoomPanX = 0.0
    root.imageZoomPanY = 0.0
  }

  // --- Settings & Retention Helpers ---
  function loadSettings(raw) {
    try {
      var s = JSON.parse(raw)
      if (s.maxClips !== undefined) root.settingsMaxClips = s.maxClips
      if (s.retainDays !== undefined) root.settingsRetainDays = s.retainDays
      if (s.ignoreSensitive !== undefined) root.settingsIgnoreSensitive = s.ignoreSensitive
    } catch(e) {}
  }

  function saveSettings() {
    var obj = {
      maxClips: root.settingsMaxClips,
      retainDays: root.settingsRetainDays,
      ignoreSensitive: root.settingsIgnoreSensitive
    }
    settingsFile.setText(JSON.stringify(obj, null, 2) + "\n")
  }

  function applyRetentionClean() {
    root.history = ClipboardHistory.applyRetentionLimits(root.history, root.settingsMaxClips, root.settingsRetainDays)
    root.saveHistory()
    root.rebuildDisplay()
    Quickshell.execDetached(["notify-send", "-a", "ReClip", "Retention Policy Applied", "Cleaned older clips based on your retention limits."])
  }

  function exportBackupJson() {
    var d = new Date()
    var dateStr = d.toISOString().substring(0, 10)
    var exportPath = root.home + "/reclip-backup-" + dateStr + ".json"
    Quickshell.execDetached(["bash", "-c", "cp " + Util.shellQuote(root.historyPath) + " " + Util.shellQuote(exportPath) + " && notify-send -a 'ReClip' 'Backup Exported' 'Saved history to " + exportPath + "'"])
  }

  // --- Bulk Selection Helpers ---
  function toggleBulkMode() {
    root.bulkMode = !root.bulkMode
    root.bulkSelectedIndices = []
  }

  function isBulkSelected(hIdx) {
    return root.bulkSelectedIndices.indexOf(hIdx) >= 0
  }

  function toggleBulkSelect(hIdx) {
    var arr = root.bulkSelectedIndices.slice()
    var p = arr.indexOf(hIdx)
    if (p >= 0) arr.splice(p, 1)
    else arr.push(hIdx)
    root.bulkSelectedIndices = arr
  }

  function bulkSelectAll() {
    var arr = []
    for (var i = 0; i < displayModel.count; i++) {
      var item = displayModel.get(i)
      if (item.itemType === "history" && item.historyIndex >= 0) {
        arr.push(item.historyIndex)
      }
    }
    root.bulkSelectedIndices = arr
  }

  function bulkClearSelection() {
    root.bulkSelectedIndices = []
  }

  function executeBulkPin(pinState) {
    if (root.bulkSelectedIndices.length === 0) return
    root.history = ClipboardHistory.bulkPin(root.history, root.bulkSelectedIndices, pinState)
    root.saveHistory()
    root.rebuildDisplay()
  }

  function executeBulkDelete() {
    if (root.bulkSelectedIndices.length === 0) return
    root.history = ClipboardHistory.bulkDelete(root.history, root.bulkSelectedIndices)
    root.saveHistory()
    root.bulkSelectedIndices = []
    root.rebuildDisplay()
  }

  function executeBulkPaste() {
    if (root.bulkSelectedIndices.length === 0) return
    root.close()
    var parts = []
    for (var i = 0; i < root.bulkSelectedIndices.length; i++) {
      var idx = root.bulkSelectedIndices[i]
      if (idx >= 0 && idx < root.history.length) {
        var entry = root.history[idx]
        parts.push(ClipboardHistory.fullText(entry))
      }
    }
    var merged = parts.join("\n")
    Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(merged) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
    root.bulkSelectedIndices = []
  }

  function executeBulkTransform(mode) {
    if (root.bulkSelectedIndices.length === 0) return
    var next = root.history.slice()
    for (var i = 0; i < root.bulkSelectedIndices.length; i++) {
      var idx = root.bulkSelectedIndices[i]
      if (idx >= 0 && idx < next.length) {
        var item = Object.assign({}, next[idx])
        if (item.type === "text" && item.text) {
          item.text = ClipboardHistory.transformText(item.text, mode)
          next[idx] = item
        }
      }
    }
    root.history = next
    root.saveHistory()
    root.rebuildDisplay()
  }

  // --- Tag / Collection Helpers ---
  function openTagModal(hIdx) {
    if (hIdx < 0 || hIdx >= root.history.length) return
    root.tagModalClipIndex = hIdx
    var item = root.history[hIdx]
    root.tagModalCurrentTags = (item && Array.isArray(item.tags)) ? item.tags.slice() : []
    root.tagModalInputText = ""
    root.tagModalOpen = true
  }

  function addTagToClipModal(tagStr) {
    var clean = String(tagStr || "").trim().replace(/^#/, "")
    if (!clean) return
    var arr = root.tagModalCurrentTags.slice()
    if (arr.indexOf(clean) < 0) {
      arr.push(clean)
      root.tagModalCurrentTags = arr
    }
    root.tagModalInputText = ""
  }

  function removeTagFromClipModal(tagStr) {
    var arr = root.tagModalCurrentTags.slice()
    var p = arr.indexOf(tagStr)
    if (p >= 0) {
      arr.splice(p, 1)
      root.tagModalCurrentTags = arr
    }
  }

  function saveTagModal() {
    if (root.tagModalClipIndex >= 0) {
      root.history = ClipboardHistory.setClipTags(root.history, root.tagModalClipIndex, root.tagModalCurrentTags)
      root.saveHistory()
      root.tagModalOpen = false
      root.rebuildDisplay()
    }
  }

  function openClipMenu(idx, item) {
    if (root.activeMenuClipIndex === idx) {
      root.activeMenuClipIndex = -1
      return
    }
    var pt = item.mapToItem(contentArea, 0, item.height + Style.space(4))
    var menuW = Style.space(210)
    var menuH = Style.space(260)
    var targetX = pt.x - menuW + item.width
    var targetY = pt.y
    if (targetX < Style.space(10)) targetX = Style.space(10)
    if (targetX + menuW > contentArea.width - Style.space(10)) targetX = contentArea.width - menuW - Style.space(10)
    if (targetY + menuH > contentArea.height - Style.space(10)) {
      targetY = pt.y - item.height - menuH - Style.space(8)
    }
    if (targetY < Style.space(10)) targetY = Style.space(10)
    root.activeMenuPos = Qt.point(Math.round(targetX), Math.round(targetY))
    root.activeMenuClipIndex = idx
  }

  function rebuildDisplay() {
    root.activeMenuClipIndex = -1
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
          urlDomain: r.urlDomain || "",
          tags: Array.isArray(r.tags) ? r.tags.join(",") : (r.tags || ""),
          historyIndex: r.index,
          snippetIndex: -1,
          title: "",
          language: ""
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
          urlDomain: "",
          tags: s.tags || "",
          historyIndex: -1,
          snippetIndex: s.index,
          title: s.title,
          language: s.language
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
            urlDomain: ClipboardHistory.extractDomain(qTxt),
            tags: Array.isArray(qEntry.tags) ? qEntry.tags.join(",") : (qEntry.tags || ""),
            historyIndex: qIdx,
            snippetIndex: -1,
            title: "Step " + (q + 1),
            language: ""
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

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("{}")
    onFileChanged: reload()
  }

  FileView {
    id: savedPalettesFile
    path: root.savedPalettesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSavedPalettes(text())
    onLoadFailed: root.loadSavedPalettes("[]")
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
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.cappedContentHeight(panel.screenH > 0 ? Math.round(panel.screenH * 0.94) : Style.space(920))

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

    Item {
      id: mainContainer
      anchors.fill: parent

      Column {
        id: topSection
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)

      // ==========================================
      // 1. HERO HEADER (Omarchy PanelHero Style)
      // ==========================================
      Item {
        id: heroHeader
        width: parent.width
        height: Style.space(38)

        // Logo & Title (Aligned Left)
        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

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

        // Trailing Controls (Aligned strictly to the Right: Calendar, Capture, Incognito, Close)
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

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

          // Multi-Select Mode Toggle
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.bulkMode ? Color.accent : Util.alpha(root.fg, 0.08)
            border.width: 1
            border.color: root.bulkMode ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "󰒆"
              color: root.bulkMode ? "#fff" : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleBulkMode()
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

          // OCR Screen Capture Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.12)
            Text {
              text: "󰐳"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.captureOcrScreen()
            }
          }

          // Settings & Preferences Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.settingsOpen ? Color.accent : Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: root.settingsOpen ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "󰒓"
              color: root.settingsOpen ? "#fff" : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.settingsOpen = !root.settingsOpen
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
                if (root.activeMenuClipIndex >= 0) root.activeMenuClipIndex = -1
                else if (root.showCalendar) root.showCalendar = false
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

      // Active Tag Filter Banner
      Row {
        visible: root.categoryFilter.indexOf("tag:") === 0 && root.activeTab === 0
        spacing: Style.space(6)

        Rectangle {
          height: Style.space(22)
          radius: Style.space(11)
          color: Util.alpha(Color.accent, 0.15)
          border.width: 1; border.color: Color.accent
          width: filterTagContent.implicitWidth + Style.space(20)

          Row {
            id: filterTagContent
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              text: "󰋚 Collection: #" + root.categoryFilter.substring(4)
              color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
            }
            Text { text: "✕"; color: Color.accent; font.pixelSize: Style.space(10); font.bold: true }
          }

          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.categoryFilter = "all"
              root.rebuildDisplay()
            }
          }
        }
      }

      // Category & Collection Tag Chips (History tab only)
      Flickable {
        visible: root.activeTab === 0
        width: parent.width
        height: Style.space(26)
        contentWidth: chipsInnerRow.implicitWidth
        clip: true
        flickableDirection: Flickable.HorizontalFlick

        Row {
          id: chipsInnerRow
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

          // Custom Tag / Collection Chips
          Repeater {
            model: root.allTags
            Rectangle {
              required property string modelData
              readonly property string tagCat: "tag:" + modelData.toLowerCase()
              readonly property bool isSelected: root.categoryFilter === tagCat
              width: tagChipContent.implicitWidth + Style.space(14)
              height: Style.space(24)
              radius: Style.space(12)
              color: isSelected ? Color.accent : Util.alpha(root.fg, 0.05)
              border.width: 1
              border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.12)

              Row {
                id: tagChipContent
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text {
                  text: "#"
                  color: parent.parent.isSelected ? "#fff" : Color.accent
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                }
                Text {
                  text: parent.parent.modelData
                  color: parent.parent.isSelected ? "#fff" : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  font.bold: parent.parent.isSelected
                }
              }

              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.categoryFilter = parent.isSelected ? "all" : parent.tagCat
                  root.selectedIndex = 0
                  root.rebuildDisplay()
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // REDESIGNED UNIFIED FOOTER (Consistent on ALL tabs)
    // ==========================================
    Rectangle {
      id: footerBar
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(40)
      radius: Style.space(8)
      color: Util.alpha(root.fg, 0.04)
      border.width: 1
      border.color: Util.alpha(root.fg, 0.08)

      // LEFT: Tab Status & Live Stats Pill
      Row {
        id: footerLeft
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Rectangle {
          height: Style.space(24)
          radius: Style.space(6)
          color: Util.alpha(Color.accent, 0.12)
          border.width: 1
          border.color: Util.alpha(Color.accent, 0.25)
          width: tabStatusRow.implicitWidth + Style.space(14)
          anchors.verticalCenter: parent.verticalCenter

          Row {
            id: tabStatusRow
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text {
              text: root.activeTab === 0 ? "󰅍" : (root.activeTab === 1 ? "󰐃" : (root.activeTab === 2 ? "󰅩" : (root.activeTab === 3 ? "󰏘" : "󰆒")))
              color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: {
                if (root.activeTab === 0) {
                  return root.activeDateFilter !== "" ? (displayModel.count + " clips (" + root.formatDateFilterLabel(root.activeDateFilter) + ")") : (root.historyCount + " clips")
                }
                if (root.activeTab === 1) return root.pinnedCount + " pinned"
                if (root.activeTab === 2) return root.snippets.length + " snippets"
                if (root.activeTab === 3) return root.activeColorHex + " active"
                if (root.activeTab === 4) return root.pasteQueue.length + " in queue"
                return ""
              }
              color: root.fg
              font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // CENTER: Universal Keyboard Shortcut Chips
      Row {
        id: footerCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)
        visible: footerBar.width > Style.space(480)

        // 1-9 Chip (Only on History / Pinned)
        Row {
          visible: root.activeTab === 0 || root.activeTab === 1
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            height: Style.space(18); width: Style.space(24); radius: Style.space(4)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.15)
            Text { text: "1-9"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
          }
          Text { text: "Paste"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
        }

        // Enter Chip
        Row {
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            height: Style.space(18); width: Style.space(18); radius: Style.space(4)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.15)
            Text { text: "↵"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.centerIn: parent }
          }
          Text { text: root.activeTab === 3 ? "Inspect" : "Copy/Paste"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
        }

        // Tab Key Chip
        Row {
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            height: Style.space(18); width: Style.space(26); radius: Style.space(4)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.15)
            Text { text: "Tab"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
          }
          Text { text: "Switch"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
        }

        // Esc Chip
        Row {
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            height: Style.space(18); width: Style.space(24); radius: Style.space(4)
            color: Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: Util.alpha(root.fg, 0.15)
            Text { text: "Esc"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
          }
          Text { text: "Close"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // RIGHT: Dedicated Action Buttons Per Page
      Row {
        id: footerRight
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

          // TAB 0: Clear History Button
          Rectangle {
            visible: root.activeTab === 0 && root.history.length > 0
            height: Style.space(26)
            width: clearBtnContent.implicitWidth + Style.space(16)
            radius: Style.space(5)
            color: Util.alpha(Color.urgent, 0.1)
            border.width: 1; border.color: Util.alpha(Color.urgent, 0.25)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: clearBtnContent
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: "󰆴"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Clear History"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.clearConfirmOpen = true
            }
          }

          // TAB 1: Pinned Filter Info
          Rectangle {
            visible: root.activeTab === 1
            height: Style.space(26)
            width: pinnedInfoContent.implicitWidth + Style.space(16)
            radius: Style.space(5)
            color: Util.alpha(Color.accent, 0.1)
            border.width: 1; border.color: Util.alpha(Color.accent, 0.25)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: pinnedInfoContent
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: "󰐃"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Pinned & Starred"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
          }

          // TAB 2: New Snippet Button
          Rectangle {
            visible: root.activeTab === 2
            height: Style.space(26)
            width: newSnipContent.implicitWidth + Style.space(16)
            radius: Style.space(5)
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: newSnipContent
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: "+"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "New Snippet"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
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

          // TAB 3: Copy Current HEX Button
          Rectangle {
            visible: root.activeTab === 3
            height: Style.space(26)
            width: copyHexContent.implicitWidth + Style.space(16)
            radius: Style.space(5)
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: copyHexContent
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: "󰆏"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Copy " + root.activeColorHex; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.copyText(root.activeColorHex)
            }
          }

          // TAB 4: Queue Actions (Merge & Paste All & Clear)
          Row {
            visible: root.activeTab === 4
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            // Merge Queued clips
            Rectangle {
              visible: root.pasteQueue.length >= 2
              height: Style.space(26)
              width: mergeContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Util.alpha(Color.accent, 0.15)
              border.width: 1; border.color: Color.accent

              Row {
                id: mergeContent
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "󰅪"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Merge (" + root.pasteQueue.length + ")"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.mergeDialogOpen = true
              }
            }

            // Paste All in Queue
            Rectangle {
              visible: root.pasteQueue.length > 0
              height: Style.space(26)
              width: pasteQueueContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Color.accent

              Row {
                id: pasteQueueContent
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "󰆒"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Paste Queue"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.flushQueue()
              }
            }

            // Clear Queue
            Rectangle {
              visible: root.pasteQueue.length > 0
              height: Style.space(26)
              width: clearQueueContent.implicitWidth + Style.space(12)
              radius: Style.space(5)
              color: Util.alpha(Color.urgent, 0.1)
              border.width: 1; border.color: Util.alpha(Color.urgent, 0.25)

              Row {
                id: clearQueueContent
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "✕"; color: Color.urgent; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Clear"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.pasteQueue = []
                  root.rebuildDisplay()
                }
              }
            }
          }
        }
      }

    // ==========================================
    // DYNAMIC MAIN CONTENT AREA (Fills space between topSection and footerBar)
    // ==========================================
    Item {
      id: contentArea
      anchors.top: topSection.bottom
      anchors.topMargin: Style.space(8)
      anchors.bottom: footerBar.top
      anchors.bottomMargin: Style.space(8)
      anchors.left: parent.left
      anchors.right: parent.right
      clip: true

      // =========================================================================
      // TAB 3: COLOR STUDIO (Dedicated Advanced Color Studio)
      // =========================================================================
      Flickable {
        id: colorStudioFlick
        visible: root.activeTab === 3
        anchors.fill: parent
        contentWidth: width
        contentHeight: colorStudioCol.implicitHeight + Style.space(24)
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: colorStudioCol
          width: parent.width
          spacing: Style.space(10)

          // 1. TOOLBAR HEADER (Title, Color Name, Quick Export, Random)
          Rectangle {
            width: parent.width
            height: Style.space(34)
            radius: Style.space(6)
            color: Util.alpha(root.fg, 0.04)
            border.width: 1; border.color: Util.alpha(root.fg, 0.08)

            Row {
              anchors.fill: parent; anchors.margins: Style.space(6)
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(16); height: Style.space(16); radius: Style.space(4)
                color: root.activeColorHex
                border.width: 1; border.color: Util.alpha(root.fg, 0.25)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Color Tool"
                color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.activeColorAnalysis ? root.activeColorAnalysis.colorName : ""
                color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
              }

              Item { Layout.fillWidth: true; width: parent.width - Style.space(340) }

              // Quick Copy Formats
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Rectangle {
                  height: Style.space(22); radius: Style.space(3); width: Style.space(66)
                  color: Util.alpha(root.fg, 0.06)
                  Text { text: "󰆏 Tailwind"; color: root.fg; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(ColorStudio.formatCode(root.activeColorHex, "tailwind"))
                  }
                }

                Rectangle {
                  height: Style.space(22); radius: Style.space(3); width: Style.space(50)
                  color: Util.alpha(root.fg, 0.06)
                  Text { text: "󰆏 Swift"; color: root.fg; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(ColorStudio.formatCode(root.activeColorHex, "swift"))
                  }
                }

                Rectangle {
                  height: Style.space(22); radius: Style.space(3); width: Style.space(55)
                  color: Util.alpha(root.fg, 0.06)
                  Text { text: "󰆏 Flutter"; color: root.fg; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(ColorStudio.formatCode(root.activeColorHex, "flutter"))
                  }
                }

                // Random Color button
                Rectangle {
                  height: Style.space(22); radius: Style.space(3); width: Style.space(66)
                  color: Util.alpha(Color.accent, 0.15); border.width: 1; border.color: Color.accent
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(3)
                    Text { text: "󰑐"; color: Color.accent; font.pixelSize: Style.space(8) }
                    Text { text: "Random"; color: Color.accent; font.pixelSize: Style.space(8); font.bold: true }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.randomColor()
                  }
                }
              }
            }
          }

          // 2. CURRENT COLOR INPUT ROW
          Rectangle {
            width: parent.width
            height: Style.space(72)
            radius: Style.space(8)
            color: Util.alpha(root.fg, 0.04)
            border.width: 1; border.color: Util.alpha(root.fg, 0.08)

            Row {
              anchors.fill: parent; anchors.margins: Style.space(8)
              spacing: Style.space(12)

              Rectangle {
                width: Style.space(56); height: Style.space(56)
                radius: Style.space(8)
                color: root.activeColorHex
                border.width: 1; border.color: Util.alpha(root.fg, 0.25)
              }

              Column {
                width: parent.width - Style.space(80)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Text {
                  text: "CURRENT COLOR"
                  color: Util.alpha(root.fg, 0.45); font.pixelSize: Style.space(8); font.bold: true
                }

                Row {
                  width: parent.width; spacing: Style.space(6)
                  Rectangle {
                    width: parent.width - Style.space(76); height: Style.space(30); radius: Style.space(4)
                    color: Util.alpha(root.fg, 0.06); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                    TextInput {
                      id: colorTextInput
                      anchors.fill: parent; anchors.margins: Style.space(4)
                      color: root.fg; font.family: "monospace"; font.pixelSize: Style.font.body; font.bold: true
                      text: root.activeColorHex
                      onAccepted: root.selectColor(text)
                    }
                  }
                  Rectangle {
                    width: Style.space(70); height: Style.space(30); radius: Style.space(4)
                    color: Color.accent
                    Text { text: "Inspect"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: root.selectColor(colorTextInput.text); cursorShape: Qt.PointingHandCursor }
                  }
                }
              }
            }
          }

          // 3. COLOR TOOL SUB-NAVIGATION TABS (Analyze, Mixer, Harmonies, A11y, Gradient, Library)
          Row {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: [
                { id: 0, label: "Analyze", icon: "󰏘" },
                { id: 1, label: "Mixer", icon: "󰈲" },
                { id: 2, label: "Harmonies", icon: "󰄳" },
                { id: 3, label: "A11y", icon: "󰈈" },
                { id: 4, label: "Gradient", icon: "󰉼" },
                { id: 5, label: "Library", icon: "󰆓" }
              ]
              Rectangle {
                required property var modelData
                width: (parent.width - Style.space(20)) / 6
                height: Style.space(30)
                radius: Style.space(5)
                color: root.colorStudioSubTab === modelData.id ? Util.alpha(Color.accent, 0.18) : Util.alpha(root.fg, 0.04)
                border.width: 1; border.color: root.colorStudioSubTab === modelData.id ? Color.accent : Util.alpha(root.fg, 0.08)

                Row {
                  anchors.centerIn: parent; spacing: Style.space(3)
                  Text {
                    text: parent.parent.modelData.icon
                    color: root.colorStudioSubTab === parent.parent.modelData.id ? Color.accent : Util.alpha(root.fg, 0.6)
                    font.family: root.fontFamily; font.pixelSize: Style.space(10)
                  }
                  Text {
                    text: parent.parent.modelData.label
                    color: root.colorStudioSubTab === parent.parent.modelData.id ? Color.accent : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.space(8)
                    font.bold: root.colorStudioSubTab === parent.parent.modelData.id
                  }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.colorStudioSubTab = parent.modelData.id
                }
              }
            }
          }

          // =========================================================================
          // SUB-TAB 0: ANALYZE
          // =========================================================================
          Column {
            visible: root.colorStudioSubTab === 0
            width: parent.width
            spacing: Style.space(10)

            // Matches Tailwind Pill
            Rectangle {
              visible: root.activeColorAnalysis && !!root.activeColorAnalysis.tailwindMatch
              width: parent.width; height: Style.space(30); radius: Style.space(6)
              color: Util.alpha(Color.accent, 0.12); border.width: 1; border.color: Util.alpha(Color.accent, 0.25)
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                Rectangle { width: 8; height: 8; radius: 4; color: Color.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                  text: "Matches Tailwind: " + (root.activeColorAnalysis ? root.activeColorAnalysis.tailwindMatch : "")
                  color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(9); font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
                Item { Layout.fillWidth: true; width: parent.width - Style.space(250) }
                Text { text: "󰆏"; color: Color.accent; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (root.activeColorAnalysis) root.copyText(root.activeColorAnalysis.tailwindMatch)
              }
            }

            // 14 Format Cards Grid
            Grid {
              columns: 2
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.activeColorAnalysis ? [
                  { label: "CSS Hex", val: root.activeColorAnalysis.hex },
                  { label: "Hex Short", val: root.activeColorAnalysis.hexShort || "N/A" },
                  { label: "CSS RGB", val: root.activeColorAnalysis.rgbStr },
                  { label: "CSS RGBA", val: root.activeColorAnalysis.rgbaStr },
                  { label: "CSS HSL", val: root.activeColorAnalysis.hslStr },
                  { label: "CSS HSLA", val: root.activeColorAnalysis.hslaStr },
                  { label: "CSS HWB", val: root.activeColorAnalysis.hwbStr },
                  { label: "LAB", val: root.activeColorAnalysis.labStr },
                  { label: "LCH", val: root.activeColorAnalysis.lchStr },
                  { label: "OKLCH", val: root.activeColorAnalysis.oklchStr },
                  { label: "HSV", val: root.activeColorAnalysis.hsvStr },
                  { label: "CMYK", val: root.activeColorAnalysis.cmykStr },
                  { label: "ARGB Hex", val: root.activeColorAnalysis.argbStr },
                  { label: "Integer", val: root.activeColorAnalysis.integerStr },
                  { label: "Hex Int", val: root.activeColorAnalysis.hexIntStr }
                ] : []
                Rectangle {
                  required property var modelData
                  width: (parent.width - Style.space(6)) / 2
                  height: Style.space(40)
                  radius: Style.space(6)
                  color: Util.alpha(root.fg, 0.04)
                  border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                  Row {
                    anchors.fill: parent; anchors.margins: Style.space(6)
                    spacing: Style.space(6)

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(26)
                      Text { text: parent.parent.parent.modelData.label; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8); font.bold: true }
                      Text { text: parent.parent.parent.modelData.val; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(9); font.bold: true; elide: Text.ElideRight; width: parent.width }
                    }

                    Text { text: "󰆏"; color: Util.alpha(root.fg, 0.35); font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
                  }

                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(parent.modelData.val)
                  }
                }
              }
            }

            // Color Properties (Temperature, Luminance, Web-safe)
            Row {
              width: parent.width
              spacing: Style.space(6)

              // Temperature
              Rectangle {
                width: (parent.width - Style.space(12)) / 3; height: Style.space(44); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                Row {
                  anchors.centerIn: parent; spacing: Style.space(6)
                  Text {
                    text: "󰔏"; color: (root.activeColorAnalysis && root.activeColorAnalysis.temperatureType === "warm") ? "#F59E0B" : ((root.activeColorAnalysis && root.activeColorAnalysis.temperatureType === "cool") ? "#3B82F6" : "#6B7280")
                    font.pixelSize: Style.space(14)
                  }
                  Column {
                    Text { text: "Temperature"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7) }
                    Text { text: root.activeColorAnalysis ? (root.activeColorAnalysis.temperatureType + " (~" + root.activeColorAnalysis.temperatureKelvin + "K)") : ""; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                  }
                }
              }

              // Luminance
              Rectangle {
                width: (parent.width - Style.space(12)) / 3; height: Style.space(44); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                Row {
                  anchors.centerIn: parent; spacing: Style.space(6)
                  Rectangle {
                    width: Style.space(16); height: Style.space(16); radius: Style.space(3)
                    color: root.activeColorAnalysis && root.activeColorAnalysis.luminance > 0.5 ? "#000" : "#fff"
                  }
                  Column {
                    Text { text: "Luminance"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7) }
                    Text { text: root.activeColorAnalysis ? root.activeColorAnalysis.luminancePercent : ""; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                  }
                }
              }

              // Web-safe
              Rectangle {
                width: (parent.width - Style.space(12)) / 3; height: Style.space(44); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                Row {
                  anchors.centerIn: parent; spacing: Style.space(6)
                  Rectangle {
                    width: Style.space(16); height: Style.space(16); radius: Style.space(3)
                    color: root.activeColorAnalysis ? root.activeColorAnalysis.websafeColor : "#fff"
                    border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                  }
                  Column {
                    Text { text: "Web-safe (Click)"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7) }
                    Text { text: root.activeColorAnalysis ? root.activeColorAnalysis.websafeColor : ""; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true }
                  }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.activeColorAnalysis) root.selectColor(root.activeColorAnalysis.websafeColor)
                }
              }
            }

            // Industry Color Matches (Pantone, RAL, NCS)
            Column {
              width: parent.width; spacing: Style.space(4)
              Text { text: "Industry Color Matches"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Row {
                width: parent.width; spacing: Style.space(6)
                // Pantone
                Rectangle {
                  visible: root.activeColorAnalysis && !!root.activeColorAnalysis.pantoneMatch
                  height: Style.space(28); radius: Style.space(5); width: (parent.width - Style.space(12)) / 3
                  color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(4)
                    Rectangle { width: 8; height: 8; radius: 2; color: root.activeColorHex }
                    Text { text: root.activeColorAnalysis ? root.activeColorAnalysis.pantoneMatch : ""; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                    Text { text: "󰆏"; color: Util.alpha(root.fg, 0.4); font.pixelSize: Style.space(8) }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activeColorAnalysis) root.copyText(root.activeColorAnalysis.pantoneMatch)
                  }
                }
                // RAL
                Rectangle {
                  visible: root.activeColorAnalysis && !!root.activeColorAnalysis.ralMatch
                  height: Style.space(28); radius: Style.space(5); width: (parent.width - Style.space(12)) / 3
                  color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(4)
                    Rectangle { width: 8; height: 8; radius: 2; color: root.activeColorHex }
                    Text { text: root.activeColorAnalysis ? root.activeColorAnalysis.ralMatch : ""; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                    Text { text: "󰆏"; color: Util.alpha(root.fg, 0.4); font.pixelSize: Style.space(8) }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activeColorAnalysis) root.copyText(root.activeColorAnalysis.ralMatch)
                  }
                }
                // NCS
                Rectangle {
                  visible: root.activeColorAnalysis && !!root.activeColorAnalysis.ncsMatch
                  height: Style.space(28); radius: Style.space(5); width: (parent.width - Style.space(12)) / 3
                  color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(4)
                    Rectangle { width: 8; height: 8; radius: 2; color: root.activeColorHex }
                    Text { text: root.activeColorAnalysis ? root.activeColorAnalysis.ncsMatch : ""; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                    Text { text: "󰆏"; color: Util.alpha(root.fg, 0.4); font.pixelSize: Style.space(8) }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activeColorAnalysis) root.copyText(root.activeColorAnalysis.ncsMatch)
                  }
                }
              }
            }

            // Developer Formats (Collapsible)
            Column {
              width: parent.width; spacing: Style.space(6)
              Rectangle {
                width: parent.width; height: Style.space(26); radius: Style.space(4)
                color: Util.alpha(Color.accent, 0.08)
                Row {
                  anchors.centerIn: parent; spacing: Style.space(6)
                  Text { text: root.showDevFormats ? "󰅃" : "󰅀"; color: Color.accent; font.pixelSize: Style.space(10) }
                  Text { text: (root.showDevFormats ? "Hide" : "Show") + " Developer Formats (Swift, Flutter, Kotlin, C#, XML)"; color: Color.accent; font.pixelSize: Style.space(8); font.bold: true }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.showDevFormats = !root.showDevFormats
                }
              }

              Grid {
                visible: root.showDevFormats
                columns: 2
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.activeColorAnalysis ? root.activeColorAnalysis.devFormats : []
                  Rectangle {
                    required property var modelData
                    width: (parent.width - Style.space(6)) / 2
                    height: Style.space(44); radius: Style.space(5)
                    color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.07)
                    Column {
                      anchors.fill: parent; anchors.margins: Style.space(6)
                      spacing: Style.space(2)
                      Text { text: parent.parent.modelData.label; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7); font.bold: true }
                      Text { text: parent.parent.modelData.val; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); elide: Text.ElideRight; width: parent.width }
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.copyText(parent.modelData.val)
                    }
                  }
                }
              }
            }

            // Tints & Shades Strips
            Column {
              width: parent.width; spacing: Style.space(4)
              Text { text: "Tints (10 Lighter Steps)"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Row {
                width: parent.width; spacing: Style.space(2)
                Repeater {
                  model: root.activeColorAnalysis ? root.activeColorAnalysis.tints : []
                  Rectangle {
                    required property string modelData
                    width: (parent.width - Style.space(18)) / 10
                    height: Style.space(24); radius: Style.space(3)
                    color: modelData
                    border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.selectColor(parent.modelData); root.copyText(parent.modelData) }
                    }
                  }
                }
              }
            }

            Column {
              width: parent.width; spacing: Style.space(4)
              Text { text: "Shades (10 Darker Steps)"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Row {
                width: parent.width; spacing: Style.space(2)
                Repeater {
                  model: root.activeColorAnalysis ? root.activeColorAnalysis.shades : []
                  Rectangle {
                    required property string modelData
                    width: (parent.width - Style.space(18)) / 10
                    height: Style.space(24); radius: Style.space(3)
                    color: modelData
                    border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.selectColor(parent.modelData); root.copyText(parent.modelData) }
                    }
                  }
                }
              }
            }

            // Clipboard Palettes
            Column {
              width: parent.width; spacing: Style.space(6)
              Text {
                text: "Extracted Clipboard Palettes (" + root.colorPalette.length + " colors)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
              }
              Grid {
                columns: 5; width: parent.width; spacing: Style.space(6)
                Repeater {
                  model: root.colorPalette
                  Rectangle {
                    required property var modelData
                    width: (parent.width - Style.space(24)) / 5
                    height: Style.space(36); radius: Style.space(4)
                    color: modelData.hex; border.width: 1; border.color: Util.alpha(root.fg, 0.25)
                    Text {
                      text: parent.modelData.hex
                      color: ColorStudio.getContrastRatio(parent.modelData.hex, "#000000") > 4.5 ? "#000" : "#fff"
                      font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true
                      anchors.centerIn: parent
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.selectColor(parent.modelData.hex); root.copyText(parent.modelData.hex) }
                    }
                  }
                }
              }
            }
          }

          // =========================================================================
          // SUB-TAB 1: MIXER
          // =========================================================================
          Column {
            visible: root.colorStudioSubTab === 1
            width: parent.width
            spacing: Style.space(12)

            // Mixing Mode Selector
            Row {
              width: parent.width; spacing: Style.space(6)
              Repeater {
                model: [
                  { mode: "rgb", label: "RGB (Standard)" },
                  { mode: "lab", label: "LAB (Perceptual)" },
                  { mode: "oklch", label: "OKLCH (Modern)" }
                ]
                Rectangle {
                  required property var modelData
                  width: (parent.width - Style.space(12)) / 3; height: Style.space(28); radius: Style.space(5)
                  color: root.mixMode === modelData.mode ? Color.accent : Util.alpha(root.fg, 0.05)
                  border.width: 1; border.color: root.mixMode === modelData.mode ? Color.accent : Util.alpha(root.fg, 0.1)
                  Text {
                    text: parent.modelData.label
                    color: root.mixMode === parent.modelData.mode ? "#fff" : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.mixMode = parent.modelData.mode
                  }
                }
              }
            }

            // Blend Mode Chips Row
            Column {
              width: parent.width; spacing: Style.space(4)
              Text { text: "Blend Mode"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(8); font.bold: true }
              Row {
                width: parent.width; spacing: Style.space(4)
                Repeater {
                  model: ["normal", "multiply", "screen", "overlay", "soft-light", "hard-light", "difference", "exclusion"]
                  Rectangle {
                    required property string modelData
                    width: (parent.width - Style.space(28)) / 8; height: Style.space(22); radius: Style.space(4)
                    color: root.blendMode === modelData ? Util.alpha(Color.accent, 0.25) : Util.alpha(root.fg, 0.04)
                    border.width: 1; border.color: root.blendMode === modelData ? Color.accent : Util.alpha(root.fg, 0.08)
                    Text {
                      text: parent.modelData.replace("-", " ")
                      color: root.blendMode === parent.modelData ? Color.accent : root.fg
                      font.pixelSize: Style.space(7); font.bold: root.blendMode === parent.modelData
                      anchors.centerIn: parent; elide: Text.ElideRight
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.blendMode = parent.modelData
                    }
                  }
                }
              }
            }

            // Inputs Card (Color 1 + Slider + Color 2)
            Rectangle {
              width: parent.width; height: Style.space(90); radius: Style.space(8)
              color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)

              Row {
                anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(12)

                // Color 1
                Column {
                  width: Style.space(70); spacing: Style.space(4); anchors.verticalCenter: parent.verticalCenter
                  Rectangle {
                    width: Style.space(44); height: Style.space(44); radius: Style.space(6)
                    color: root.mixColor1; border.width: 1; border.color: Util.alpha(root.fg, 0.25)
                    anchors.horizontalCenter: parent.horizontalCenter
                  }
                  Rectangle {
                    width: Style.space(70); height: Style.space(20); radius: Style.space(3)
                    color: Util.alpha(Color.accent, 0.15)
                    Text { text: "Use Current"; color: Color.accent; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.mixColor1 = root.activeColorHex
                    }
                  }
                }

                // Mix Ratio Slider
                Column {
                  width: parent.width - Style.space(164); spacing: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                  Row {
                    width: parent.width
                    Text { text: Math.round((1 - root.mixRatio) * 100) + "%"; color: root.mixColor1; font.pixelSize: Style.space(8); font.bold: true }
                    Item { Layout.fillWidth: true; width: parent.width - Style.space(60) }
                    Text { text: Math.round(root.mixRatio * 100) + "%"; color: root.mixColor2; font.pixelSize: Style.space(8); font.bold: true }
                  }

                  // Slider Bar
                  Rectangle {
                    width: parent.width; height: Style.space(12); radius: Style.space(6)
                    color: Util.alpha(root.fg, 0.1)
                    Rectangle {
                      x: 0; width: parent.width * root.mixRatio; height: parent.height; radius: parent.radius
                      color: Color.accent
                    }
                    Rectangle {
                      x: Math.max(0, Math.min(parent.width - Style.space(16), parent.width * root.mixRatio - Style.space(8)))
                      y: -Style.space(2); width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                      color: "#fff"; border.width: 2; border.color: Color.accent
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onPositionChanged: function(mouse) {
                        var ratio = Math.max(0, Math.min(1, mouse.x / width))
                        root.mixRatio = Math.round(ratio * 100) / 100
                      }
                      onClicked: function(mouse) {
                        var ratio = Math.max(0, Math.min(1, mouse.x / width))
                        root.mixRatio = Math.round(ratio * 100) / 100
                      }
                    }
                  }
                }

                // Color 2
                Column {
                  width: Style.space(70); spacing: Style.space(4); anchors.verticalCenter: parent.verticalCenter
                  Rectangle {
                    width: Style.space(44); height: Style.space(44); radius: Style.space(6)
                    color: root.mixColor2; border.width: 1; border.color: Util.alpha(root.fg, 0.25)
                    anchors.horizontalCenter: parent.horizontalCenter
                  }
                  Rectangle {
                    width: Style.space(70); height: Style.space(20); radius: Style.space(3)
                    color: Util.alpha(Color.accent, 0.15)
                    Text { text: "Use Current"; color: Color.accent; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.mixColor2 = root.activeColorHex
                    }
                  }
                }
              }
            }

            // Mixed Result Section
            Column {
              width: parent.width; spacing: Style.space(6)
              property string mixedHex: {
                if (root.blendMode !== "normal") return ColorStudio.blendWithStrength(root.mixColor1, root.mixColor2, root.blendMode, root.mixRatio)
                if (root.mixMode === "lab") return ColorStudio.mixColorsLab(root.mixColor1, root.mixColor2, root.mixRatio)
                if (root.mixMode === "oklch") return ColorStudio.mixColorsOklch(root.mixColor1, root.mixColor2, root.mixRatio)
                return ColorStudio.mixColors(root.mixColor1, root.mixColor2, root.mixRatio)
              }

              Rectangle {
                width: parent.width; height: Style.space(60); radius: Style.space(8)
                color: parent.mixedHex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                Text {
                  text: parent.parent.mixedHex
                  color: ColorStudio.getContrastRatio(parent.parent.mixedHex, "#000000") > 4.5 ? "#000" : "#fff"
                  font.family: "monospace"; font.pixelSize: Style.space(14); font.bold: true
                  anchors.centerIn: parent
                }
              }

              Rectangle {
                width: Style.space(160); height: Style.space(28); radius: Style.space(5)
                color: Color.accent; anchors.horizontalCenter: parent.horizontalCenter
                Text { text: "Set as Current Color"; color: "#fff"; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectColor(parent.parent.mixedHex)
                }
              }
            }

            // Step Scale Generator
            Column {
              width: parent.width; spacing: Style.space(6)
              Row {
                width: parent.width
                Text { text: "Step Scale (" + root.mixSteps + " Steps)"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
                Item { Layout.fillWidth: true; width: parent.width - Style.space(250) }
                Row {
                  spacing: Style.space(4)
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(3); color: Util.alpha(root.fg, 0.08)
                    Text { text: "-"; color: root.fg; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: root.mixSteps = Math.max(3, root.mixSteps - 1) }
                  }
                  Rectangle {
                    width: Style.space(20); height: Style.space(20); radius: Style.space(3); color: Util.alpha(root.fg, 0.08)
                    Text { text: "+"; color: root.fg; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: root.mixSteps = Math.min(30, root.mixSteps + 1) }
                  }
                }
              }

              // Scale Swatch Strip
              property var currentScale: {
                if (root.mixMode === "lab") return ColorStudio.generateScaleLab(root.mixColor1, root.mixColor2, root.mixSteps)
                if (root.mixMode === "oklch") return ColorStudio.generateScaleOklch(root.mixColor1, root.mixColor2, root.mixSteps)
                return ColorStudio.generateScale(root.mixColor1, root.mixColor2, root.mixSteps)
              }

              Row {
                width: parent.width; height: Style.space(36); spacing: 1
                Repeater {
                  model: parent.currentScale
                  Rectangle {
                    required property string modelData
                    width: (parent.width - (parent.parent.currentScale.length - 1)) / parent.parent.currentScale.length
                    height: parent.height; color: modelData
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.selectColor(parent.modelData); root.copyText(parent.modelData) }
                    }
                  }
                }
              }

              Row {
                spacing: Style.space(6)
                Rectangle {
                  height: Style.space(24); radius: Style.space(4); width: Style.space(110)
                  color: Util.alpha(root.fg, 0.06)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(4)
                    Text { text: "󰆏"; color: root.fg; font.pixelSize: Style.space(8) }
                    Text { text: "CSS Variables"; color: root.fg; font.pixelSize: Style.space(8) }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(ColorStudio.exportPaletteAsCSS(parent.parent.parent.currentScale))
                  }
                }

                Rectangle {
                  height: Style.space(24); radius: Style.space(4); width: Style.space(90)
                  color: Util.alpha(root.fg, 0.06)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(4)
                    Text { text: "󰆏"; color: root.fg; font.pixelSize: Style.space(8) }
                    Text { text: "JSON Array"; color: root.fg; font.pixelSize: Style.space(8) }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(ColorStudio.exportPaletteAsJSON(parent.parent.parent.currentScale))
                  }
                }
              }
            }

            // Gradient Presets for Quick Mixing
            Column {
              width: parent.width; spacing: Style.space(6)
              Text { text: "Presets"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Grid {
                columns: 4; width: parent.width; spacing: Style.space(6)
                Repeater {
                  model: ColorStudio.GRADIENT_PRESETS.slice(0, 12)
                  Rectangle {
                    required property var modelData
                    width: (parent.width - Style.space(18)) / 4; height: Style.space(26); radius: Style.space(4)
                    color: modelData.colors[0]
                    border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                    Text {
                      text: parent.modelData.name
                      color: "#fff"; font.pixelSize: Style.space(7); font.bold: true
                      anchors.centerIn: parent
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.mixColor1 = parent.modelData.colors[0]
                        root.mixColor2 = parent.modelData.colors[parent.modelData.colors.length - 1]
                      }
                    }
                  }
                }
              }
            }
          }

          // =========================================================================
          // SUB-TAB 2: HARMONIES
          // =========================================================================
          Column {
            visible: root.colorStudioSubTab === 2
            width: parent.width
            spacing: Style.space(12)

            // Controls (Angle Offset + Lock Primary)
            Rectangle {
              width: parent.width; height: Style.space(44); radius: Style.space(6)
              color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)

              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(12)

                Text { text: "Angle Offset:"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }

                // Angle buttons
                Row {
                  spacing: Style.space(4); anchors.verticalCenter: parent.verticalCenter
                  Rectangle {
                    width: Style.space(24); height: Style.space(24); radius: Style.space(3); color: Util.alpha(root.fg, 0.08)
                    Text { text: "-5°"; color: root.fg; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: root.harmonyAngleOffset = Math.max(-30, root.harmonyAngleOffset - 5) }
                  }
                  Rectangle {
                    width: Style.space(36); height: Style.space(24); radius: Style.space(3); color: Util.alpha(Color.accent, 0.15)
                    Text { text: (root.harmonyAngleOffset > 0 ? "+" : "") + root.harmonyAngleOffset + "°"; color: Color.accent; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                  }
                  Rectangle {
                    width: Style.space(24); height: Style.space(24); radius: Style.space(3); color: Util.alpha(root.fg, 0.08)
                    Text { text: "+5°"; color: root.fg; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: root.harmonyAngleOffset = Math.min(30, root.harmonyAngleOffset + 5) }
                  }
                }

                Item { Layout.fillWidth: true; width: parent.width - Style.space(240) }

                Rectangle {
                  height: Style.space(26); radius: Style.space(4); width: Style.space(100)
                  color: root.lockHarmonyColor ? Color.accent : Util.alpha(root.fg, 0.08)
                  anchors.verticalCenter: parent.verticalCenter
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(4)
                    Text { text: root.lockHarmonyColor ? "󰌾" : "󰌿"; color: root.lockHarmonyColor ? "#fff" : root.fg; font.pixelSize: Style.space(9) }
                    Text { text: root.lockHarmonyColor ? "Locked" : "Lock Primary"; color: root.lockHarmonyColor ? "#fff" : root.fg; font.pixelSize: Style.space(8); font.bold: true }
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.lockHarmonyColor = !root.lockHarmonyColor
                  }
                }
              }
            }

            // 7 Harmonies Rows
            property var advancedHarmoniesMap: ColorStudio.generateHarmoniesAdvanced(root.activeColorHex, root.harmonyAngleOffset)

            Repeater {
              model: [
                { name: "Complementary", key: "complementary" },
                { name: "Analogous", key: "analogous" },
                { name: "Triadic", key: "triadic" },
                { name: "Split-Comp", key: "split" },
                { name: "Tetradic", key: "tetradic" },
                { name: "Monochromatic", key: "monochromatic" },
                { name: "Double-Split", key: "doubleSplit" }
              ]

              Rectangle {
                required property var modelData
                property var colorsList: parent.advancedHarmoniesMap[modelData.key] || []
                width: parent.width; height: Style.space(56); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.03); border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                Column {
                  anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(4)

                  Row {
                    width: parent.width
                    Text { text: parent.parent.modelData.name; color: Util.alpha(root.fg, 0.75); font.pixelSize: Style.space(8); font.bold: true }
                    Item { Layout.fillWidth: true; width: parent.width - Style.space(200) }
                    Row {
                      spacing: Style.space(4)
                      Rectangle {
                        height: Style.space(16); radius: Style.space(3); width: Style.space(40); color: Util.alpha(root.fg, 0.06)
                        Text { text: "󰆏 CSS"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(6); anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.copyText(ColorStudio.exportPaletteAsCSS(parent.parent.parent.parent.parent.colorsList))
                        }
                      }
                      Rectangle {
                        height: Style.space(16); radius: Style.space(3); width: Style.space(42); color: Util.alpha(root.fg, 0.06)
                        Text { text: "󰆏 JSON"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(6); anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.copyText(ColorStudio.exportPaletteAsJSON(parent.parent.parent.parent.parent.colorsList))
                        }
                      }
                    }
                  }

                  // Swatches Row
                  Row {
                    width: parent.width; height: Style.space(24); spacing: Style.space(4)
                    Repeater {
                      model: parent.parent.colorsList
                      Rectangle {
                        required property string modelData
                        width: (parent.width - (parent.parent.parent.colorsList.length - 1) * Style.space(4)) / parent.parent.parent.colorsList.length
                        height: parent.height; radius: Style.space(4); color: modelData
                        border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                        Text {
                          text: parent.modelData
                          color: ColorStudio.getContrastRatio(parent.modelData, "#000000") > 4.5 ? "#000" : "#fff"
                          font.family: "monospace"; font.pixelSize: Style.space(7); font.bold: true
                          anchors.centerIn: parent
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (!root.lockHarmonyColor) root.selectColor(parent.modelData)
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

          // =========================================================================
          // SUB-TAB 3: ACCESSIBILITY (A11y)
          // =========================================================================
          Column {
            visible: root.colorStudioSubTab === 3
            width: parent.width
            spacing: Style.space(12)

            // Contrast Checker Card
            Rectangle {
              width: parent.width; height: Style.space(170); radius: Style.space(8)
              color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)

              Column {
                anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(8)

                Row {
                  width: parent.width; spacing: Style.space(12)

                  // Background (Current Color)
                  Column {
                    width: (parent.width - Style.space(12)) / 2; spacing: Style.space(3)
                    Text { text: "Background Color"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7); font.bold: true }
                    Row {
                      spacing: Style.space(6)
                      Rectangle { width: Style.space(24); height: Style.space(24); radius: Style.space(4); color: root.activeColorHex; border.width: 1; border.color: Util.alpha(root.fg, 0.2) }
                      Text { text: root.activeColorHex; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                  }

                  // Foreground / Text Color Input
                  Column {
                    width: (parent.width - Style.space(12)) / 2; spacing: Style.space(3)
                    Text { text: "Foreground / Text Color"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7); font.bold: true }
                    Row {
                      spacing: Style.space(6)
                      Rectangle { width: Style.space(24); height: Style.space(24); radius: Style.space(4); color: root.contrastColor; border.width: 1; border.color: Util.alpha(root.fg, 0.2) }
                      Rectangle {
                        width: Style.space(90); height: Style.space(24); radius: Style.space(3); color: Util.alpha(root.fg, 0.06); border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                        TextInput {
                          anchors.fill: parent; anchors.margins: 3; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true
                          text: root.contrastColor
                          onAccepted: root.contrastColor = ColorStudio.parseColor(text) || text
                        }
                      }
                    }
                  }
                }

                // Auto-suggest Accessible Alternatives if contrast < 4.5
                property real currentRatio: ColorStudio.getContrastRatio(root.activeColorHex, root.contrastColor)
                property real currentApca: ColorStudio.getApcaContrast(root.contrastColor, root.activeColorHex)

                Rectangle {
                  visible: parent.currentRatio < 4.5
                  width: parent.width; height: Style.space(36); radius: Style.space(5)
                  color: Util.alpha("#EF4444", 0.12); border.width: 1; border.color: Util.alpha("#EF4444", 0.3)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(8)
                    Text { text: "󰅙 Contrast Issue (" + parent.parent.currentRatio.toFixed(2) + ":1 < 4.5:1)"; color: "#EF4444"; font.pixelSize: Style.space(8); font.bold: true }
                    Rectangle {
                      height: Style.space(20); radius: Style.space(3); width: Style.space(80); color: "#fff"
                      Text { text: "Suggest Light"; color: "#000"; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.contrastColor = ColorStudio.suggestAccessibleColor(root.activeColorHex, root.contrastColor, "lighter")
                      }
                    }
                    Rectangle {
                      height: Style.space(20); radius: Style.space(3); width: Style.space(80); color: "#000"
                      Text { text: "Suggest Dark"; color: "#fff"; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.contrastColor = ColorStudio.suggestAccessibleColor(root.activeColorHex, root.contrastColor, "darker")
                      }
                    }
                  }
                }

                // Real UI Previews Box
                Row {
                  width: parent.width; spacing: Style.space(6)

                  // Button Example
                  Rectangle {
                    width: (parent.width - Style.space(12)) / 3; height: Style.space(32); radius: Style.space(5)
                    color: root.activeColorHex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Text { text: "Button Example"; color: root.contrastColor; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                  }

                  // Card Preview
                  Rectangle {
                    width: (parent.width - Style.space(12)) / 3; height: Style.space(32); radius: Style.space(5)
                    color: root.activeColorHex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Column {
                      anchors.centerIn: parent; spacing: 1
                      Text { text: "Card Title"; color: root.contrastColor; font.pixelSize: Style.space(7); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: "Body text sample"; color: root.contrastColor; font.pixelSize: Style.space(6); anchors.horizontalCenter: parent.horizontalCenter }
                    }
                  }

                  // Input Preview
                  Rectangle {
                    width: (parent.width - Style.space(12)) / 3; height: Style.space(32); radius: Style.space(5)
                    color: root.activeColorHex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Text { text: "Placeholder..."; color: Util.alpha(root.contrastColor, 0.7); font.pixelSize: Style.space(7); anchors.centerIn: parent }
                  }
                }

                // Scores Row
                Row {
                  width: parent.width; spacing: Style.space(8)
                  Rectangle {
                    width: (parent.width - Style.space(8)) / 2; height: Style.space(32); radius: Style.space(5)
                    color: Util.alpha(root.fg, 0.05)
                    Row {
                      anchors.centerIn: parent; spacing: Style.space(6)
                      Text { text: "WCAG: " + parent.parent.parent.currentRatio.toFixed(2) + ":1"; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                      Rectangle {
                        height: Style.space(16); radius: Style.space(3); width: Style.space(44)
                        color: parent.parent.parent.parent.currentRatio >= 4.5 ? "#10B981" : "#EF4444"
                        Text { text: parent.parent.parent.parent.parent.currentRatio >= 4.5 ? "AA Pass" : "AA Fail"; color: "#fff"; font.pixelSize: Style.space(6); font.bold: true; anchors.centerIn: parent }
                      }
                    }
                  }

                  Rectangle {
                    width: (parent.width - Style.space(8)) / 2; height: Style.space(32); radius: Style.space(5)
                    color: Util.alpha(root.fg, 0.05)
                    Row {
                      anchors.centerIn: parent; spacing: Style.space(6)
                      Text { text: "APCA: " + Math.abs(parent.parent.parent.currentApca).toFixed(1); color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                      Text { text: "Min: " + ColorStudio.calculateMinFontSize(parent.parent.parent.currentRatio, false) + "px"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(7) }
                    }
                  }
                }
              }
            }

            // Check Against 12 Standard Backgrounds Grid
            Column {
              width: parent.width; spacing: Style.space(4)
              Text { text: "Check Against Standard Backgrounds"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Grid {
                columns: 4; width: parent.width; spacing: Style.space(6)
                Repeater {
                  model: root.activeColorAnalysis ? root.activeColorAnalysis.standardBgResults : []
                  Rectangle {
                    required property var modelData
                    width: (parent.width - Style.space(18)) / 4; height: Style.space(42); radius: Style.space(5)
                    color: modelData.hex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Column {
                      anchors.centerIn: parent; spacing: 1
                      Text { text: parent.parent.modelData.name; color: root.activeColorHex; font.pixelSize: Style.space(7); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: parent.parent.modelData.ratio.toFixed(2) + ":1"; color: root.activeColorHex; font.pixelSize: Style.space(8); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: parent.parent.modelData.passAA ? "✓ AA" : "✕ Fail"; color: parent.parent.modelData.passAA ? "#10B981" : "#EF4444"; font.pixelSize: Style.space(6); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                  }
                }
              }
            }

            // Color Blindness Simulation Grid
            Column {
              width: parent.width; spacing: Style.space(4)
              Text { text: "Color Blindness Simulation"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Grid {
                columns: 2; width: parent.width; spacing: Style.space(6)
                Repeater {
                  model: root.activeColorAnalysis ? root.activeColorAnalysis.blindnessSim : []
                  Rectangle {
                    required property var modelData
                    width: (parent.width - Style.space(6)) / 2; height: Style.space(38); radius: Style.space(5)
                    color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                    Row {
                      anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                      Rectangle { width: Style.space(26); height: Style.space(26); radius: Style.space(4); color: parent.parent.modelData.hex; border.width: 1; border.color: Util.alpha(root.fg, 0.2) }
                      Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: parent.parent.parent.modelData.label; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                        Text { text: parent.parent.parent.modelData.hex; color: Util.alpha(root.fg, 0.5); font.family: "monospace"; font.pixelSize: Style.space(7) }
                      }
                    }
                  }
                }
              }
            }
          }

          // =========================================================================
          // SUB-TAB 4: GRADIENT
          // =========================================================================
          Column {
            visible: root.colorStudioSubTab === 4
            width: parent.width
            spacing: Style.space(12)

            // Gradient Canvas Preview
            Rectangle {
              width: parent.width; height: Style.space(130); radius: Style.space(8)
              clip: true; border.width: 1; border.color: Util.alpha(root.fg, 0.15)

              Canvas {
                id: gradCanvas
                anchors.fill: parent
                onPaint: {
                  var ctx = getContext("2d")
                  var w = width, h = height
                  ctx.clearRect(0, 0, w, h)
                  var grad
                  if (root.gradientType === "radial") {
                    grad = ctx.createRadialGradient(w/2, h/2, 0, w/2, h/2, Math.max(w, h)/2)
                  } else {
                    var rad = (root.gradientAngle * Math.PI) / 180
                    var x1 = w/2 - (Math.cos(rad) * w)/2
                    var y1 = h/2 - (Math.sin(rad) * h)/2
                    var x2 = w/2 + (Math.cos(rad) * w)/2
                    var y2 = h/2 + (Math.sin(rad) * h)/2
                    grad = ctx.createLinearGradient(x1, y1, x2, y2)
                  }
                  for (var i = 0; i < root.gradientStops.length; i++) {
                    var s = root.gradientStops[i]
                    grad.addColorStop(Math.max(0, Math.min(1, s.position / 100)), s.color)
                  }
                  ctx.fillStyle = grad
                  ctx.fillRect(0, 0, w, h)
                }
              }

              Connections {
                target: root
                function onGradientAngleChanged() { gradCanvas.requestPaint() }
                function onGradientTypeChanged() { gradCanvas.requestPaint() }
                function onGradientStopsChanged() { gradCanvas.requestPaint() }
              }
            }

            // Controls (Type + Angle)
            Row {
              width: parent.width; spacing: Style.space(8)

              // Type Selector
              Row {
                spacing: Style.space(4)
                Repeater {
                  model: ["linear", "radial", "conic"]
                  Rectangle {
                    required property string modelData
                    width: Style.space(55); height: Style.space(26); radius: Style.space(4)
                    color: root.gradientType === modelData ? Color.accent : Util.alpha(root.fg, 0.05)
                    Text {
                      text: parent.modelData
                      color: root.gradientType === parent.modelData ? "#fff" : root.fg
                      font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.gradientType = parent.modelData; gradCanvas.requestPaint() }
                    }
                  }
                }
              }

              Item { Layout.fillWidth: true; width: parent.width - Style.space(300) }

              // Angle Controls (Linear)
              Row {
                visible: root.gradientType === "linear"
                spacing: Style.space(4); anchors.verticalCenter: parent.verticalCenter
                Text { text: "Angle: " + root.gradientAngle + "°"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                  width: Style.space(22); height: Style.space(22); radius: Style.space(3); color: Util.alpha(root.fg, 0.08)
                  Text { text: "-"; color: root.fg; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                  MouseArea { anchors.fill: parent; onClicked: { root.gradientAngle = (root.gradientAngle - 15 + 360) % 360; gradCanvas.requestPaint() } }
                }
                Rectangle {
                  width: Style.space(22); height: Style.space(22); radius: Style.space(3); color: Util.alpha(root.fg, 0.08)
                  Text { text: "+"; color: root.fg; font.pixelSize: Style.space(10); anchors.centerIn: parent }
                  MouseArea { anchors.fill: parent; onClicked: { root.gradientAngle = (root.gradientAngle + 15) % 360; gradCanvas.requestPaint() } }
                }
              }
            }

            // Stops Editor
            Column {
              width: parent.width; spacing: Style.space(6)
              Row {
                width: parent.width
                Text { text: "Gradient Stops"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
                Item { Layout.fillWidth: true; width: parent.width - Style.space(150) }
                Rectangle {
                  height: Style.space(20); radius: Style.space(3); width: Style.space(65); color: Util.alpha(Color.accent, 0.15)
                  Text { text: "+ Add Stop"; color: Color.accent; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var stops = root.gradientStops.slice()
                      stops.push({ color: root.activeColorHex, position: 50 })
                      stops.sort(function(a, b) { return a.position - b.position })
                      root.gradientStops = stops
                      gradCanvas.requestPaint()
                    }
                  }
                }
              }

              Repeater {
                model: root.gradientStops
                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width; height: Style.space(32); radius: Style.space(5)
                  color: Util.alpha(root.fg, 0.03); border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                  Row {
                    anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                    Rectangle {
                      width: Style.space(20); height: Style.space(20); radius: Style.space(3)
                      color: parent.parent.modelData.color; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    }
                    Text { text: parent.parent.modelData.color; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: parent.parent.modelData.position + "%"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }

                    Item { Layout.fillWidth: true; width: parent.width - Style.space(200) }

                    // Position adjust buttons
                    Rectangle {
                      width: Style.space(18); height: Style.space(18); radius: Style.space(2); color: Util.alpha(root.fg, 0.08)
                      Text { text: "◀"; color: root.fg; font.pixelSize: Style.space(6); anchors.centerIn: parent }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var stops = root.gradientStops.slice()
                          stops[parent.parent.parent.index].position = Math.max(0, stops[parent.parent.parent.index].position - 5)
                          stops.sort(function(a, b) { return a.position - b.position })
                          root.gradientStops = stops
                          gradCanvas.requestPaint()
                        }
                      }
                    }
                    Rectangle {
                      width: Style.space(18); height: Style.space(18); radius: Style.space(2); color: Util.alpha(root.fg, 0.08)
                      Text { text: "▶"; color: root.fg; font.pixelSize: Style.space(6); anchors.centerIn: parent }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var stops = root.gradientStops.slice()
                          stops[parent.parent.parent.index].position = Math.min(100, stops[parent.parent.parent.index].position + 5)
                          stops.sort(function(a, b) { return a.position - b.position })
                          root.gradientStops = stops
                          gradCanvas.requestPaint()
                        }
                      }
                    }

                    // Remove Stop
                    Rectangle {
                      visible: root.gradientStops.length > 2
                      width: Style.space(18); height: Style.space(18); radius: Style.space(2); color: Util.alpha("#EF4444", 0.15)
                      Text { text: "✕"; color: "#EF4444"; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var stops = root.gradientStops.slice()
                          stops.splice(parent.parent.parent.index, 1)
                          root.gradientStops = stops
                          gradCanvas.requestPaint()
                        }
                      }
                    }
                  }
                }
              }
            }

            // 18 Gradient Presets Grid
            Column {
              width: parent.width; spacing: Style.space(6)
              Text { text: "18 Gradient Presets (Click to Load)"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true }
              Grid {
                columns: 3; width: parent.width; spacing: Style.space(6)
                Repeater {
                  model: ColorStudio.GRADIENT_PRESETS
                  Rectangle {
                    required property var modelData
                    width: (parent.width - Style.space(12)) / 3; height: Style.space(30); radius: Style.space(4)
                    color: modelData.colors[0]
                    border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Text {
                      text: parent.modelData.name
                      color: "#fff"; font.pixelSize: Style.space(8); font.bold: true
                      anchors.centerIn: parent
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var p = parent.modelData
                        var stops = []
                        for (var i = 0; i < p.colors.length; i++) {
                          stops.push({ color: p.colors[i], position: Math.round((i / (p.colors.length - 1)) * 100) })
                        }
                        root.gradientStops = stops
                        root.gradientAngle = p.angle
                        root.gradientType = "linear"
                        gradCanvas.requestPaint()
                      }
                    }
                  }
                }
              }
            }

            // CSS Output Card
            Rectangle {
              width: parent.width; height: Style.space(42); radius: Style.space(6)
              color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                Column {
                  width: parent.width - Style.space(60); anchors.verticalCenter: parent.verticalCenter
                  Text { text: "CSS Code"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7); font.bold: true }
                  Text {
                    text: "background: " + ColorStudio.generateGradient(root.gradientType, root.gradientAngle, root.gradientStops) + ";"
                    color: Color.accent; font.family: "monospace"; font.pixelSize: Style.space(8); elide: Text.ElideRight; width: parent.width
                  }
                }
                Rectangle {
                  height: Style.space(24); radius: Style.space(4); width: Style.space(50); color: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                  Text { text: "Copy"; color: "#fff"; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText("background: " + ColorStudio.generateGradient(root.gradientType, root.gradientAngle, root.gradientStops) + ";")
                  }
                }
              }
            }
          }

          // =========================================================================
          // SUB-TAB 5: LIBRARY / SAVED PALETTES
          // =========================================================================
          Column {
            visible: root.colorStudioSubTab === 5
            width: parent.width
            spacing: Style.space(12)

            // Import Palette Card
            Rectangle {
              width: parent.width; height: Style.space(46); radius: Style.space(6)
              color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)

              Row {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(6)
                Rectangle {
                  width: parent.width - Style.space(80); height: Style.space(32); radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.06); border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                  TextInput {
                    anchors.fill: parent; anchors.margins: Style.space(4)
                    color: root.fg; font.pixelSize: Style.space(8)
                    text: root.colorImportText
                    onTextChanged: root.colorImportText = text
                    onAccepted: root.importPaletteFromText(text)
                    Text {
                      visible: !parent.text
                      text: "Paste JSON array or Hex codes (#FF0000 #00FF00...)"
                      color: Util.alpha(root.fg, 0.35); font.pixelSize: Style.space(7)
                      anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                    }
                  }
                }
                Rectangle {
                  width: Style.space(70); height: Style.space(32); radius: Style.space(4); color: Color.accent
                  Text { text: "Import"; color: "#fff"; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.importPaletteFromText(root.colorImportText)
                  }
                }
              }
            }

            // Save Current Palette Button
            Rectangle {
              width: parent.width; height: Style.space(34); radius: Style.space(6)
              color: Color.accent
              Row {
                anchors.centerIn: parent; spacing: Style.space(6)
                Text { text: "󰆓"; color: "#fff"; font.pixelSize: Style.space(11) }
                Text { text: "Save Current Palette to Library"; color: "#fff"; font.pixelSize: Style.space(9); font.bold: true }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.saveCurrentPalette()
              }
            }

            // Saved Palettes List
            Text {
              text: "Saved Palettes (" + root.savedPalettes.length + ")"; color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); font.bold: true
            }

            Text {
              visible: root.savedPalettes.length === 0
              text: "No saved palettes yet. Click 'Save Current Palette' to store palettes in your library."
              color: Util.alpha(root.fg, 0.4); font.pixelSize: Style.space(8); font.italic: true
            }

            Repeater {
              model: root.savedPalettes
              Rectangle {
                required property var modelData
                width: parent.width; height: Style.space(82); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.03); border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                Column {
                  anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)

                  Row {
                    width: parent.width
                    Column {
                      Text { text: parent.parent.parent.modelData.name; color: root.fg; font.pixelSize: Style.space(9); font.bold: true }
                      Text {
                        text: (parent.parent.parent.modelData.colors ? parent.parent.parent.modelData.colors.length : 0) + " colors • " + new Date(parent.parent.parent.modelData.createdAt).toLocaleDateString()
                        color: Util.alpha(root.fg, 0.4); font.pixelSize: Style.space(7)
                      }
                    }

                    Item { Layout.fillWidth: true; width: parent.width - Style.space(200) }

                    Row {
                      spacing: Style.space(4)
                      Rectangle {
                        width: Style.space(22); height: Style.space(22); radius: Style.space(3); color: Util.alpha(root.fg, 0.06)
                        Text { text: "󰆏"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(8); anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.copyText(ColorStudio.exportPaletteAsJSON(parent.parent.parent.parent.modelData.colors))
                        }
                      }
                      Rectangle {
                        width: Style.space(22); height: Style.space(22); radius: Style.space(3); color: Util.alpha("#EF4444", 0.12)
                        Text { text: "✕"; color: "#EF4444"; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.deleteSavedPalette(parent.parent.parent.parent.modelData.id)
                        }
                      }
                    }
                  }

                  // Swatches Row
                  Row {
                    width: parent.width; height: Style.space(24); spacing: Style.space(3)
                    Repeater {
                      model: parent.parent.modelData.colors || []
                      Rectangle {
                        required property string modelData
                        width: (parent.width - (parent.parent.parent.modelData.colors.length - 1) * Style.space(3)) / parent.parent.parent.modelData.colors.length
                        height: parent.height; radius: Style.space(3); color: modelData
                        border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: { root.selectColor(parent.modelData); root.copyText(parent.modelData) }
                        }
                      }
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
        id: listContainer
        visible: root.activeTab !== 3
        anchors.fill: parent
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
            required property string urlDomain
            required property string tags
            required property int historyIndex
            required property int snippetIndex
            required property string title

            readonly property bool isSelected: root.selectedIndex === index
            readonly property bool isBulkChecked: root.isBulkSelected(cardItem.historyIndex)
            readonly property bool isHovered: cardMouse.containsMouse

            width: list.width - Style.space(6)
            height: kind === "code" ? Style.space(78) : (entryType === "image" ? Style.space(80) : Style.space(62))
            radius: Style.space(8)
            color: isBulkChecked ? Util.alpha(Color.accent, 0.18) : (isSelected ? root.selBg : (isHovered ? Util.alpha(root.fg, 0.06) : Util.alpha(root.fg, 0.03)))
            border.width: 1
            border.color: isBulkChecked ? Color.accent : (isSelected ? Color.accent : (cardItem.isPinned ? Util.alpha(Color.accent, 0.4) : Util.alpha(root.fg, 0.08)))

            // Glowing Left Accent Line for selected item
            Rectangle {
              visible: cardItem.isSelected || cardItem.isBulkChecked
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
                if (root.bulkMode && cardItem.itemType === "history") {
                  root.toggleBulkSelect(cardItem.historyIndex)
                } else {
                  root.pasteRow(displayModel.get(parent.index))
                }
              }
            }

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              anchors.leftMargin: (cardItem.isSelected || cardItem.isBulkChecked) ? Style.space(12) : Style.space(8)
              spacing: Style.space(10)

              // Bulk Selection Checkbox (Visible in bulk mode)
              Rectangle {
                visible: root.bulkMode && cardItem.itemType === "history"
                width: Style.space(22); height: Style.space(22)
                radius: Style.space(5)
                anchors.verticalCenter: parent.verticalCenter
                color: cardItem.isBulkChecked ? Color.accent : Util.alpha(root.fg, 0.08)
                border.width: 1
                border.color: cardItem.isBulkChecked ? Color.accent : Util.alpha(root.fg, 0.25)
                Text {
                  visible: cardItem.isBulkChecked
                  text: "✓"
                  color: "#fff"
                  font.family: root.fontFamily; font.pixelSize: Style.space(12); font.bold: true
                  anchors.centerIn: parent
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleBulkSelect(cardItem.historyIndex)
                }
              }

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

                // Click image to zoom / inspect
                MouseArea {
                  anchors.fill: parent
                  enabled: cardItem.entryType === "image"
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openImageZoom(cardItem.path)
                }
              }

              // Metadata & Content Details
              Column {
                width: parent.width - Style.space(130) - (root.bulkMode ? Style.space(26) : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                // Meta Row (Index badge, Pin, Tag, Time Ago)
                Row {
                  spacing: Style.space(6)

                  // 1-9 Quick paste badge
                  Rectangle {
                    visible: cardItem.index < 9 && root.activeTab === 0 && !root.bulkMode
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

                  // URL Domain Badge (e.g. github.com)
                  Rectangle {
                    visible: cardItem.urlDomain !== ""
                    height: Style.space(14)
                    width: domainBadgeContent.implicitWidth + Style.space(8)
                    radius: Style.space(3)
                    color: Util.alpha(Color.accent, 0.15)
                    Row {
                      id: domainBadgeContent
                      anchors.centerIn: parent
                      spacing: Style.space(3)
                      Text { text: "󰌹"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      Text { text: cardItem.urlDomain; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true }
                    }
                  }

                  // Collection / Custom Tags Badges
                  Repeater {
                    model: cardItem.tags ? cardItem.tags.split(",").filter(function(t) { return t.trim() !== "" }) : []
                    Rectangle {
                      required property string modelData
                      height: Style.space(14)
                      width: tagBadgeTxt.implicitWidth + Style.space(8)
                      radius: Style.space(3)
                      color: Util.alpha(root.fg, 0.1)
                      Text {
                        id: tagBadgeTxt
                        text: "#" + parent.modelData
                        color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true
                        anchors.centerIn: parent
                      }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.categoryFilter = "tag:" + parent.modelData.toLowerCase()
                          root.rebuildDisplay()
                        }
                      }
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
              // COMPACT TRAILING CONTROLS (Quick Actions + Dropdown)
              // ==========================================
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                // Quick Open in Browser (for links)
                Rectangle {
                  visible: cardItem.kind === "link" || cardItem.urlDomain !== ""
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: urlMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08)
                  border.width: 1; border.color: urlMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)
                  Text {
                    text: "󰌹"
                    color: urlMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: urlMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openUrlInBrowser(cardItem.fullText)
                  }
                }

                // Quick OCR Extract (for image clips)
                Rectangle {
                  visible: cardItem.entryType === "image"
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: ocrMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08)
                  border.width: 1; border.color: ocrMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)
                  Text {
                    text: "󰐳"
                    color: ocrMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: ocrMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.runOcrOnImage(cardItem.path)
                  }
                }

                // Quick Copy
                Rectangle {
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: copyMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08)
                  border.width: 1
                  border.color: copyMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)

                  Text {
                    text: "󰆏"
                    color: copyMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: copyMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRow(displayModel.get(cardItem.index))
                  }
                }

                // Dropdown Menu Button (Three Dots)
                Rectangle {
                  id: menuBtn
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: (root.activeMenuClipIndex === cardItem.index || menuMouse.containsMouse) ? Color.accent : Util.alpha(root.fg, 0.08)
                  border.width: 1
                  border.color: (root.activeMenuClipIndex === cardItem.index || menuMouse.containsMouse) ? Color.accent : Util.alpha(root.fg, 0.1)

                  Text {
                    text: "󰇙"
                    color: (root.activeMenuClipIndex === cardItem.index || menuMouse.containsMouse) ? "#fff" : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: menuMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openClipMenu(cardItem.index, menuBtn)
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

      // ==========================================
      // FLOATING DROPDOWN CONTEXT MENU FOR CLIPS
      // ==========================================
      Item {
        id: menuOverlay
        visible: root.activeMenuClipIndex >= 0 && root.activeMenuClipIndex < displayModel.count
        anchors.fill: parent
        z: 99

        // Dismiss click catcher outside menu
        MouseArea {
          anchors.fill: parent
          onClicked: root.activeMenuClipIndex = -1
        }

        // Dropdown Card
        Rectangle {
          id: menuDropdownCard
          readonly property var clipRow: root.activeMenuClipIndex >= 0 && root.activeMenuClipIndex < displayModel.count ? displayModel.get(root.activeMenuClipIndex) : null
          readonly property bool isClipPinned: clipRow ? (clipRow.isPinned === true) : false
          readonly property bool isClipFav: clipRow ? (clipRow.isFavorite === true) : false
          readonly property bool isClipQueued: clipRow ? (root.pasteQueue.indexOf(clipRow.historyIndex) >= 0) : false
          readonly property bool isTextClip: clipRow ? (clipRow.entryType === "text") : false
          readonly property bool isHistoryClip: clipRow ? (clipRow.itemType === "history") : false

          x: root.activeMenuPos.x
          y: root.activeMenuPos.y
          width: Style.space(210)
          height: menuCol.implicitHeight + Style.space(12)
          radius: Style.space(8)
          color: root.bg
          border.width: 1
          border.color: Util.alpha(root.fg, 0.16)

          Column {
            id: menuCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.space(6)
            spacing: Style.space(2)

            // 1. Copy
            Rectangle {
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: copyItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰆏"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Copy to Clipboard"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: copyItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (menuDropdownCard.clipRow) root.copyRow(menuDropdownCard.clipRow)
                  root.activeMenuClipIndex = -1
                }
              }
            }

            // 2. Pin / Unpin
            Rectangle {
              visible: menuDropdownCard.isHistoryClip
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: pinItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text {
                  text: "󰐃"
                  color: menuDropdownCard.isClipPinned ? Color.accent : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: menuDropdownCard.isClipPinned ? "Unpin Item" : "Pin to Top"
                  color: root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: pinItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (menuDropdownCard.clipRow) root.togglePinRow(menuDropdownCard.clipRow)
                  root.activeMenuClipIndex = -1
                }
              }
            }

            // 3. Favorite Star
            Rectangle {
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: favItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text {
                  text: "⭐"
                  font.pixelSize: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: menuDropdownCard.isClipFav ? "Remove Favorite" : "Add to Favorites"
                  color: root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: favItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (menuDropdownCard.clipRow) root.toggleFavRow(menuDropdownCard.clipRow)
                  root.activeMenuClipIndex = -1
                }
              }
            }

            // 4. Edit Clip Content
            Rectangle {
              visible: menuDropdownCard.isTextClip
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: editItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "✏"; color: root.fg; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Edit Content"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: editItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var row = menuDropdownCard.clipRow
                  root.activeMenuClipIndex = -1
                  if (row) root.openEditRow(row)
                }
              }
            }

            // 5. Transform Text Case
            Rectangle {
              visible: menuDropdownCard.isTextClip && menuDropdownCard.isHistoryClip
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: tfItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "🔤"; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Transform Text Case…"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: tfItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var row = menuDropdownCard.clipRow
                  root.activeMenuClipIndex = -1
                  if (row) root.openTransformRow(row)
                }
              }
            }

            // 6. QR Code
            Rectangle {
              visible: menuDropdownCard.isTextClip && menuDropdownCard.clipRow && menuDropdownCard.clipRow.fullText !== ""
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: qrItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰐳"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Generate QR Code"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: qrItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var text = menuDropdownCard.clipRow ? menuDropdownCard.clipRow.fullText : ""
                  root.activeMenuClipIndex = -1
                  if (text !== "") root.showQrModal(text)
                }
              }
            }

            // 7. Queue Toggle
            Rectangle {
              visible: menuDropdownCard.isHistoryClip
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: queueItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text {
                  text: "󰆒"
                  color: menuDropdownCard.isClipQueued ? Color.accent : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: menuDropdownCard.isClipQueued ? "Remove from Queue" : "Add to Paste Queue"
                  color: root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: queueItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (menuDropdownCard.clipRow) root.toggleQueue(menuDropdownCard.clipRow)
                  root.activeMenuClipIndex = -1
                }
              }
            }

            // URL: Open in Browser
            Rectangle {
              visible: menuDropdownCard.clipRow && (menuDropdownCard.clipRow.kind === "link" || menuDropdownCard.clipRow.urlDomain !== "")
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: urlItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰌹"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Open in Browser"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: urlItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var url = menuDropdownCard.clipRow ? menuDropdownCard.clipRow.fullText : ""
                  root.activeMenuClipIndex = -1
                  if (url) root.openUrlInBrowser(url)
                }
              }
            }

            // Image: View & Zoom
            Rectangle {
              visible: menuDropdownCard.clipRow && menuDropdownCard.clipRow.entryType === "image"
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: zoomItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰍉"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "View & Zoom Image"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: zoomItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var p = menuDropdownCard.clipRow ? menuDropdownCard.clipRow.path : ""
                  root.activeMenuClipIndex = -1
                  if (p) root.openImageZoom(p)
                }
              }
            }

            // Image: OCR Text Extraction
            Rectangle {
              visible: menuDropdownCard.clipRow && menuDropdownCard.clipRow.entryType === "image"
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: ocrItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰐳"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Extract Text (OCR)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: ocrItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var p = menuDropdownCard.clipRow ? menuDropdownCard.clipRow.path : ""
                  root.activeMenuClipIndex = -1
                  if (p) root.runOcrOnImage(p)
                }
              }
            }

            // Tags: Manage Tags / Collections
            Rectangle {
              visible: menuDropdownCard.isHistoryClip
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: tagItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰋚"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Manage Tags…"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: tagItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var hIdx = menuDropdownCard.clipRow ? menuDropdownCard.clipRow.historyIndex : -1
                  root.activeMenuClipIndex = -1
                  if (hIdx >= 0) root.openTagModal(hIdx)
                }
              }
            }

            // Separator
            Rectangle {
              width: parent.width; height: 1
              color: Util.alpha(root.fg, 0.08)
            }

            // 8. Delete
            Rectangle {
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: delItemMouse.containsMouse ? Util.alpha(Color.urgent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰆴"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text {
                  text: menuDropdownCard.clipRow && menuDropdownCard.clipRow.itemType === "snippet" ? "Delete Snippet" : "Delete from History"
                  color: Color.urgent
                  font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: delItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var idx = root.activeMenuClipIndex
                  root.activeMenuClipIndex = -1
                  root.deleteRow(idx)
                }
              }
            }
          }
        }
      }

      // ==========================================
      // BULK ACTIONS BAR (Floating dock when bulk mode active)
      // ==========================================
      Rectangle {
        id: bulkActionsDock
        visible: root.bulkMode && (root.activeTab === 0 || root.activeTab === 1)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Style.space(16), bulkDockRow.implicitWidth + Style.space(20))
        height: Style.space(40)
        radius: Style.space(8)
        color: root.bg
        border.width: 1
        border.color: Color.accent
        z: 90

        Row {
          id: bulkDockRow
          anchors.centerIn: parent
          spacing: Style.space(6)

          // Selected Count Info
          Rectangle {
            height: Style.space(26)
            width: countTxt.implicitWidth + Style.space(14)
            radius: Style.space(5)
            color: Util.alpha(Color.accent, 0.15)
            Text {
              id: countTxt
              text: root.bulkSelectedIndices.length + " selected"
              color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
              anchors.centerIn: parent
            }
          }

          // Select All
          Rectangle {
            height: Style.space(26)
            width: selAllTxt.implicitWidth + Style.space(12)
            radius: Style.space(5)
            color: Util.alpha(root.fg, 0.08)
            Text {
              id: selAllTxt
              text: "Select All"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10)
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.bulkSelectAll()
            }
          }

          // Bulk Pin (if any selected)
          Rectangle {
            visible: root.bulkSelectedIndices.length > 0
            height: Style.space(26)
            width: bulkPinTxt.implicitWidth + Style.space(12)
            radius: Style.space(5)
            color: Util.alpha(Color.accent, 0.15)
            border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
            Row {
              id: bulkPinTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰐃"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Pin"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.executeBulkPin(true)
            }
          }

          // Bulk Merge & Paste (if 2+ selected)
          Rectangle {
            visible: root.bulkSelectedIndices.length >= 2
            height: Style.space(26)
            width: bulkMergeTxt.implicitWidth + Style.space(12)
            radius: Style.space(5)
            color: Color.accent
            Row {
              id: bulkMergeTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰅪"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Merge & Paste"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.executeBulkPaste()
            }
          }

          // Bulk UPPER (if selected)
          Rectangle {
            visible: root.bulkSelectedIndices.length > 0
            height: Style.space(26)
            width: Style.space(32)
            radius: Style.space(5)
            color: Util.alpha(root.fg, 0.08)
            Text {
              text: "TT"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.executeBulkTransform("upper")
            }
          }

          // Bulk lower (if selected)
          Rectangle {
            visible: root.bulkSelectedIndices.length > 0
            height: Style.space(26)
            width: Style.space(32)
            radius: Style.space(5)
            color: Util.alpha(root.fg, 0.08)
            Text {
              text: "tt"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.executeBulkTransform("lower")
            }
          }

          // Bulk Delete (if selected)
          Rectangle {
            visible: root.bulkSelectedIndices.length > 0
            height: Style.space(26)
            width: bulkDelTxt.implicitWidth + Style.space(12)
            radius: Style.space(5)
            color: Util.alpha(Color.urgent, 0.15)
            border.width: 1; border.color: Util.alpha(Color.urgent, 0.3)
            Row {
              id: bulkDelTxt
              anchors.centerIn: parent; spacing: Style.space(3)
              Text { text: "󰆴"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Delete"; color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.executeBulkDelete()
            }
          }

          // Cancel / Done
          Rectangle {
            height: Style.space(26)
            width: cancelTxt.implicitWidth + Style.space(12)
            radius: Style.space(5)
            color: Util.alpha(root.fg, 0.1)
            Text {
              id: cancelTxt
              text: "Done"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
              anchors.centerIn: parent
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.bulkMode = false
                root.bulkSelectedIndices = []
              }
            }
          }
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

    // ==========================================
    // MODAL: IMAGE ZOOM / FULL PREVIEW MODAL
    // ==========================================
    Rectangle {
      id: imageZoomModal
      visible: root.imageZoomOpen
      anchors.fill: parent
      color: Util.alpha(Color.background, 0.95)
      radius: Style.cornerRadius
      z: 100

      focus: root.imageZoomOpen
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.closeImageZoom()
          event.accepted = true
        } else if (event.key === Qt.Key_0) {
          root.resetImageZoom()
          event.accepted = true
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
          root.imageZoomScale = Math.min(8.0, root.imageZoomScale * 1.3)
          event.accepted = true
        } else if (event.key === Qt.Key_Minus) {
          root.imageZoomScale = Math.max(0.15, root.imageZoomScale / 1.3)
          event.accepted = true
        }
      }

      // Top Header Bar
      Item {
        id: zoomTopBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(46)
        anchors.margins: Style.space(10)
        z: 10

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(28); height: Style.space(28); radius: Style.space(6)
            color: Util.alpha(Color.accent, 0.2)
            Text { text: "󰍉"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.centerIn: parent }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
              text: root.imageZoomPath ? root.imageZoomPath.split("/").pop() : "Image Preview"
              color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
              elide: Text.ElideMiddle
              width: Style.space(220)
            }
            Text {
              text: "Wheel to zoom • Drag to pan • Esc to close"
              color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8)
            }
          }
        }

        // Close Button
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(30); height: Style.space(30); radius: Style.space(6)
          color: Util.alpha(root.fg, 0.1)
          Text { text: "✕"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.closeImageZoom()
          }
        }
      }

      // Interactive Pan & Zoom Canvas
      Item {
        id: zoomCanvas
        anchors.top: zoomTopBar.bottom
        anchors.bottom: zoomBottomBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true

        MouseArea {
          id: zoomMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: pressed ? Qt.ClosedHandCursor : (root.imageZoomScale > 1.0 ? Qt.OpenHandCursor : Qt.ArrowCursor)

          property real lastX: 0
          property real lastY: 0

          onPressed: function(mouse) {
            lastX = mouse.x
            lastY = mouse.y
          }

          onPositionChanged: function(mouse) {
            if (pressed) {
              root.imageZoomPanX += (mouse.x - lastX)
              root.imageZoomPanY += (mouse.y - lastY)
              lastX = mouse.x
              lastY = mouse.y
            }
          }

          onWheel: function(wheel) {
            var factor = wheel.angleDelta.y > 0 ? 1.25 : 0.8
            root.imageZoomScale = Math.max(0.15, Math.min(8.0, root.imageZoomScale * factor))
          }
        }

        Image {
          id: fullZoomImg
          source: root.imageZoomPath ? ("file://" + root.imageZoomPath) : ""
          fillMode: Image.PreserveAspectFit
          anchors.centerIn: parent
          width: parent.width * 0.9
          height: parent.height * 0.9
          scale: root.imageZoomScale
          transformOrigin: Item.Center
          x: (parent.width - width) / 2 + root.imageZoomPanX
          y: (parent.height - height) / 2 + root.imageZoomPanY
          smooth: true
        }
      }

      // Floating Bottom Controls Bar
      Rectangle {
        id: zoomBottomBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(16)
        anchors.horizontalCenter: parent.horizontalCenter
        height: Style.space(42)
        width: zoomBtnRow.implicitWidth + Style.space(24)
        radius: Style.space(21)
        color: root.bg
        border.width: 1
        border.color: Util.alpha(root.fg, 0.16)
        z: 10

        Row {
          id: zoomBtnRow
          anchors.centerIn: parent
          spacing: Style.space(8)

          // Zoom Out
          Rectangle {
            width: Style.space(28); height: Style.space(28); radius: Style.space(14)
            color: Util.alpha(root.fg, 0.08)
            Text { text: "−"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.imageZoomScale = Math.max(0.15, root.imageZoomScale / 1.3) }
          }

          // Percentage & Reset
          Rectangle {
            height: Style.space(28); width: Style.space(52); radius: Style.space(14)
            color: Util.alpha(Color.accent, 0.15)
            Text {
              text: Math.round(root.imageZoomScale * 100) + "%"
              color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true
              anchors.centerIn: parent
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resetImageZoom() }
          }

          // Zoom In
          Rectangle {
            width: Style.space(28); height: Style.space(28); radius: Style.space(14)
            color: Util.alpha(root.fg, 0.08)
            Text { text: "+"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.imageZoomScale = Math.min(8.0, root.imageZoomScale * 1.3) }
          }

          // Divider
          Rectangle { width: 1; height: Style.space(20); color: Util.alpha(root.fg, 0.15); anchors.verticalCenter: parent.verticalCenter }

          // Copy Image
          Rectangle {
            height: Style.space(28); width: copyImgTxt.implicitWidth + Style.space(16); radius: Style.space(14)
            color: Util.alpha(root.fg, 0.08)
            Row {
              id: copyImgTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰆏"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Copy Image"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.imageZoomPath) {
                  Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < " + Util.shellQuote(root.imageZoomPath) + " && notify-send -a 'ReClip' 'Image Copied' 'Image loaded to clipboard'"])
                }
              }
            }
          }

          // Extract Text (OCR)
          Rectangle {
            height: Style.space(28); width: ocrImgTxt.implicitWidth + Style.space(16); radius: Style.space(14)
            color: Util.alpha(Color.accent, 0.2)
            border.width: 1; border.color: Color.accent
            Row {
              id: ocrImgTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰐳"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Extract Text (OCR)"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.imageZoomPath) root.runOcrOnImage(root.imageZoomPath)
              }
            }
          }

          // Open in Viewer
          Rectangle {
            height: Style.space(28); width: openExtTxt.implicitWidth + Style.space(14); radius: Style.space(14)
            color: Util.alpha(root.fg, 0.08)
            Row {
              id: openExtTxt
              anchors.centerIn: parent; spacing: Style.space(4)
              Text { text: "󰅍"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Viewer"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.imageZoomPath) root.openUrlInBrowser(root.imageZoomPath)
              }
            }
          }
        }
      }
    }

    // ==========================================
    // MODAL: SETTINGS & PRIVACY PREFERENCES
    // ==========================================
    Rectangle {
      id: settingsModal
      visible: root.settingsOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 95

      Rectangle {
        width: parent.width * 0.92
        height: parent.height * 0.86
        radius: Style.cornerRadius
        color: root.bg
        border.width: 1
        border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(18)
          spacing: Style.space(14)

          // Header
          Row {
            width: parent.width
            height: Style.space(32)

            Row {
              spacing: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              Rectangle {
                width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                color: Util.alpha(Color.accent, 0.15)
                Text { text: "󰒓"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.centerIn: parent }
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text { text: "Settings & Privacy"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: "Retention limits, privacy controls, and backup tools"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: Style.space(28); height: Style.space(28); radius: Style.space(6)
              color: Util.alpha(root.fg, 0.08)
              Text { text: "✕"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsOpen = false }
            }
          }

          // Scrollable Settings Body
          Flickable {
            width: parent.width
            height: parent.height - Style.space(90)
            contentWidth: width
            contentHeight: settingsBodyCol.implicitHeight + Style.space(20)
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
              id: settingsBodyCol
              width: parent.width
              spacing: Style.space(14)

              // SECTION 1: CLIPBOARD HISTORY & RETENTION LIMITS
              Rectangle {
                width: parent.width
                height: sec1Col.implicitHeight + Style.space(20)
                radius: Style.space(8)
                color: Util.alpha(root.fg, 0.03)
                border.width: 1; border.color: Util.alpha(root.fg, 0.08)

                Column {
                  id: sec1Col
                  anchors.fill: parent; anchors.margins: Style.space(12)
                  spacing: Style.space(10)

                  Text { text: "📋 History & Retention Limits"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }

                  // Max Clips Option
                  Column {
                    width: parent.width; spacing: Style.space(4)
                    Text { text: "Maximum clips stored in history:"; color: Util.alpha(root.fg, 0.7); font.family: root.fontFamily; font.pixelSize: Style.space(10) }
                    Row {
                      spacing: Style.space(6)
                      Repeater {
                        model: [
                          { val: 100, label: "100" },
                          { val: 250, label: "250" },
                          { val: 500, label: "500" },
                          { val: 1000, label: "1,000" },
                          { val: 10000, label: "Unlimited" }
                        ]
                        Rectangle {
                          required property var modelData
                          width: Style.space(64); height: Style.space(26); radius: Style.space(4)
                          color: root.settingsMaxClips === modelData.val ? Color.accent : Util.alpha(root.fg, 0.06)
                          border.width: 1; border.color: root.settingsMaxClips === modelData.val ? Color.accent : Util.alpha(root.fg, 0.1)
                          Text {
                            text: parent.modelData.label
                            color: root.settingsMaxClips === parent.modelData.val ? "#fff" : root.fg
                            font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                            anchors.centerIn: parent
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsMaxClips = parent.modelData.val
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }
                  }

                  // Auto Cleanup Age Option
                  Column {
                    width: parent.width; spacing: Style.space(4)
                    Text { text: "Auto-cleanup clips older than:"; color: Util.alpha(root.fg, 0.7); font.family: root.fontFamily; font.pixelSize: Style.space(10) }
                    Row {
                      spacing: Style.space(6)
                      Repeater {
                        model: [
                          { days: 7, label: "7 Days" },
                          { days: 30, label: "30 Days" },
                          { days: 90, label: "90 Days" },
                          { days: 0, label: "Keep All" }
                        ]
                        Rectangle {
                          required property var modelData
                          width: Style.space(70); height: Style.space(26); radius: Style.space(4)
                          color: root.settingsRetainDays === modelData.days ? Color.accent : Util.alpha(root.fg, 0.06)
                          border.width: 1; border.color: root.settingsRetainDays === modelData.days ? Color.accent : Util.alpha(root.fg, 0.1)
                          Text {
                            text: parent.modelData.label
                            color: root.settingsRetainDays === parent.modelData.days ? "#fff" : root.fg
                            font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                            anchors.centerIn: parent
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsRetainDays = parent.modelData.days
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }
                  }

                  // Apply Clean Button
                  Rectangle {
                    height: Style.space(28); width: cleanBtnTxt.implicitWidth + Style.space(16); radius: Style.space(4)
                    color: Util.alpha(Color.accent, 0.15); border.width: 1; border.color: Color.accent
                    Row {
                      id: cleanBtnTxt
                      anchors.centerIn: parent; spacing: Style.space(4)
                      Text { text: "󰃢"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                      Text { text: "Apply Retention Clean Now"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.applyRetentionClean()
                    }
                  }
                }
              }

              // SECTION 2: PRIVACY & SECURITY
              Rectangle {
                width: parent.width
                height: sec2Col.implicitHeight + Style.space(20)
                radius: Style.space(8)
                color: Util.alpha(root.fg, 0.03)
                border.width: 1; border.color: Util.alpha(root.fg, 0.08)

                Column {
                  id: sec2Col
                  anchors.fill: parent; anchors.margins: Style.space(12)
                  spacing: Style.space(10)

                  Text { text: "🛡 Privacy & Security Preferences"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }

                  // Password Manager Protection
                  Row {
                    width: parent.width
                    Rectangle {
                      width: parent.width; height: Style.space(38); radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.05)
                      Row {
                        anchors.fill: parent; anchors.margins: Style.space(8)
                        spacing: Style.space(8)
                        Text { text: "󰌋"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                          anchors.verticalCenter: parent.verticalCenter; spacing: 0
                          Text { text: "Password Manager Protection"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true }
                          Text { text: "Filter sensitive entries from KeePassXC, 1Password, Bitwarden"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8) }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                          width: Style.space(64); height: Style.space(22); radius: Style.space(11)
                          color: root.settingsIgnoreSensitive ? Color.accent : Util.alpha(root.fg, 0.15)
                          anchors.verticalCenter: parent.verticalCenter
                          Text {
                            text: root.settingsIgnoreSensitive ? "Active" : "Off"
                            color: root.settingsIgnoreSensitive ? "#fff" : root.fg
                            font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                            anchors.centerIn: parent
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsIgnoreSensitive = !root.settingsIgnoreSensitive
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }
                  }

                  // Incognito Explanation
                  Row {
                    width: parent.width
                    Rectangle {
                      width: parent.width; height: Style.space(38); radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.05)
                      Row {
                        anchors.fill: parent; anchors.margins: Style.space(8)
                        spacing: Style.space(8)
                        Text { text: "󰈈"; color: root.incognito ? Color.urgent : root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                          anchors.verticalCenter: parent.verticalCenter; spacing: 0
                          Text { text: "Incognito Mode"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true }
                          Text { text: "Pauses clipboard history recording immediately"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8) }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                          width: Style.space(64); height: Style.space(22); radius: Style.space(11)
                          color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.15)
                          anchors.verticalCenter: parent.verticalCenter
                          Text {
                            text: root.incognito ? "Active" : "Normal"
                            color: root.incognito ? "#fff" : root.fg
                            font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                            anchors.centerIn: parent
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleIncognito()
                          }
                        }
                      }
                    }
                  }
                }
              }

              // SECTION 3: BACKUP & EXPORT
              Rectangle {
                width: parent.width
                height: sec3Col.implicitHeight + Style.space(20)
                radius: Style.space(8)
                color: Util.alpha(root.fg, 0.03)
                border.width: 1; border.color: Util.alpha(root.fg, 0.08)

                Column {
                  id: sec3Col
                  anchors.fill: parent; anchors.margins: Style.space(12)
                  spacing: Style.space(10)

                  Text { text: "💾 Backup & Data Export"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }

                  Row {
                    spacing: Style.space(8)
                    Rectangle {
                      height: Style.space(28); width: exportTxt.implicitWidth + Style.space(16); radius: Style.space(4)
                      color: Color.accent
                      Row {
                        id: exportTxt
                        anchors.centerIn: parent; spacing: Style.space(4)
                        Text { text: "󰍉"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Export Backup (JSON)"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                      }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.exportBackupJson()
                      }
                    }
                  }
                }
              }

              // SECTION 4: ABOUT & PARITY
              Rectangle {
                width: parent.width
                height: Style.space(48)
                radius: Style.space(8)
                color: Util.alpha(root.fg, 0.03)
                border.width: 1; border.color: Util.alpha(root.fg, 0.08)

                Row {
                  anchors.fill: parent; anchors.margins: Style.space(10)
                  spacing: Style.space(8)
                  Text { text: "󰅍"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.heading; anchors.verticalCenter: parent.verticalCenter }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { text: "ReClip Omarchy Edition • v1.0"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true }
                    Text { text: "Native Quickshell integration with 100% ReClip feature parity"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8) }
                  }
                }
              }
            }
          }

          // Close Button
          Row {
            anchors.right: parent.right; spacing: Style.space(8)
            Rectangle {
              width: Style.space(80); height: Style.space(30); radius: Style.space(4)
              color: Color.accent
              Text { text: "Close"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsOpen = false }
            }
          }
        }
      }
    }

    // ==========================================
    // MODAL: CUSTOM COLLECTIONS & TAGS EDITOR
    // ==========================================
    Rectangle {
      id: tagModal
      visible: root.tagModalOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 95

      Rectangle {
        width: Style.space(340)
        height: Style.space(300)
        radius: Style.cornerRadius
        color: root.bg
        border.width: 1
        border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            width: parent.width
            Text { text: "󰋚 Manage Tags"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Item { Layout.fillWidth: true }
            Rectangle {
              width: Style.space(24); height: Style.space(24); radius: Style.space(4); color: Util.alpha(root.fg, 0.08)
              Text { text: "✕"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tagModalOpen = false }
            }
          }

          Text { text: "Add tags to categorize this clip into collections:"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.font.caption }

          // Active Tags on this Clip
          Rectangle {
            width: parent.width; height: Style.space(60); radius: Style.space(6)
            color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.1)

            Flickable {
              anchors.fill: parent; anchors.margins: Style.space(6); clip: true
              contentWidth: width; contentHeight: tagFlow.implicitHeight

              Flow {
                id: tagFlow
                width: parent.width; spacing: Style.space(6)

                Repeater {
                  model: root.tagModalCurrentTags
                  Rectangle {
                    required property string modelData
                    height: Style.space(22)
                    width: tagChipText.implicitWidth + Style.space(20)
                    radius: Style.space(11)
                    color: Util.alpha(Color.accent, 0.15)
                    border.width: 1; border.color: Color.accent

                    Row {
                      anchors.centerIn: parent; spacing: Style.space(4)
                      Text {
                        id: tagChipText
                        text: "#" + parent.parent.modelData
                        color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                      }
                      Text { text: "✕"; color: Color.accent; font.pixelSize: Style.space(8); font.bold: true }
                    }

                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.removeTagFromClipModal(parent.modelData)
                    }
                  }
                }

                Text {
                  visible: root.tagModalCurrentTags.length === 0
                  text: "No tags assigned yet."
                  color: Util.alpha(root.fg, 0.4); font.family: root.fontFamily; font.pixelSize: Style.space(9)
                }
              }
            }
          }

          // Add New Tag Input Field
          Row {
            width: parent.width; spacing: Style.space(6)
            Rectangle {
              width: parent.width - Style.space(70); height: Style.space(32); radius: Style.space(5)
              color: Util.alpha(root.fg, 0.06); border.width: 1; border.color: newTagInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.15)

              TextInput {
                id: newTagInput
                anchors.fill: parent; anchors.margins: Style.space(6)
                color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
                text: root.tagModalInputText
                onTextChanged: root.tagModalInputText = text
                onAccepted: {
                  root.addTagToClipModal(text)
                  text = ""
                }

                Text {
                  visible: newTagInput.text === "" && !newTagInput.activeFocus
                  text: "Enter tag (e.g. work, dev)..."
                  color: Util.alpha(root.fg, 0.4); font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            Rectangle {
              width: Style.space(64); height: Style.space(32); radius: Style.space(5)
              color: Color.accent
              Text { text: "+ Add"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.addTagToClipModal(newTagInput.text)
                  newTagInput.text = ""
                }
              }
            }
          }

          // Existing Suggestions
          Column {
            width: parent.width; spacing: Style.space(4)
            Text { text: "Existing tags:"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8) }
            Flow {
              width: parent.width; spacing: Style.space(4)
              Repeater {
                model: root.allTags.filter(function(t) { return root.tagModalCurrentTags.indexOf(t) < 0 })
                Rectangle {
                  required property string modelData
                  height: Style.space(18); width: sugTxt.implicitWidth + Style.space(10); radius: Style.space(9)
                  color: Util.alpha(root.fg, 0.08)
                  Text {
                    id: sugTxt
                    text: "+" + parent.modelData
                    color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8)
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.addTagToClipModal(parent.modelData)
                  }
                }
              }
            }
          }

          Item { Layout.fillHeight: true }

          // Footer
          Row {
            anchors.right: parent.right; spacing: Style.space(8)
            Rectangle {
              width: Style.space(70); height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.fg, 0.1)
              Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.tagModalOpen = false; cursorShape: Qt.PointingHandCursor }
            }
            Rectangle {
              width: Style.space(80); height: Style.space(28); radius: Style.space(4); color: Color.accent
              Text { text: "Save Tags"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; onClicked: root.saveTagModal(); cursorShape: Qt.PointingHandCursor }
            }
          }
        }
      }
    }
  }
}
}
