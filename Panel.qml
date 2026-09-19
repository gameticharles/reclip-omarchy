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
import "lib/TemplateEngine.js" as TemplateEngine
import "lib/AutomationRules.js" as AutomationRules

Panel {
  id: root
  moduleName: "reclip"
  ipcTarget: "reclip"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

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
  property string templatesPath: stateDir + "/templates.json"
  property string automationsPath: stateDir + "/automations.json"

  property bool incognito: false
  // Tabs: 0: History, 1: Pinned/Favs, 2: Snippets, 3: Color Studio, 4: Queue
  property int activeTab: 0
  property string categoryFilter: "all"
  property string filterText: ""
  property int selectedIndex: 0
  property int historyLimit: 500

  // Settings & Privacy State
  property bool settingsOpen: false
  property int settingsActiveSection: 0 // 0: Retention, 1: Privacy, 2: Automations, 3: Templates, 4: Shortcuts, 5: Backup
  property int settingsMaxClips: 500
  property int settingsRetainDays: 30
  property bool settingsIgnoreSensitive: true
  property int settingsImagePaletteLimit: 12
  property string syncKeybindingsScript: pluginDir + "/sync-keybindings.sh"
  property string settingsToggleShortcut: "SUPER + SHIFT + V"
  property string settingsPasteModifiers: "SUPER + CTRL + SHIFT"
  property bool settingsEnableQuickPaste: true
  property bool settingsClipActionsOnHover: true
  property bool settingsQrAllowUpload: true
  property bool settingsQrAllowBeam: true
  property string paletteScript: pluginDir + "/extract-palette.sh"
  property var imagePalettes: ({})
  property var paletteQueue: []
  property string lastCopiedColorHex: ""

  Timer {
    id: copiedTimer
    interval: 1800
    repeat: false
    onTriggered: root.lastCopiedColorHex = ""
  }

  // Automations & Regex Rules State
  property var automationRules: []
  property bool automationsLoaded: false
  property string ruleEditId: ""
  property string newRuleName: ""
  property string newRulePattern: ""
  property string newRuleAction: "tag"
  property string newRulePayload: ""
  property string testRuleSample: "https://example.com/checkout?utm_source=ad&utm_medium=cpc or #1234"
  property var testRuleResult: ({})

  // Dynamic Templates & Snippet Variables State
  property var templates: []
  property bool templatesLoaded: false
  property string tplEditId: ""
  property string tplEditName: ""
  property string tplEditLang: "markdown"
  property string tplEditContent: ""
  property bool tplEditorVisible: false
  property bool snippetTemplatePickerOpen: false

  // Interactive Template Variable Prompt Modal State
  property bool varPromptOpen: false
  property string varPromptTitle: ""
  property string varPromptTemplate: ""
  property bool varPromptAutoPaste: false
  property var varPromptList: []
  property var varPromptValues: ({})
  property string varPromptPreview: ""

  // Image Annotation Studio State
  property bool imageEditorOpen: false

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

  // Power Features Settings
  property bool settingsSmartBump: true
  property bool settingsRevisionStacking: true
  property var settingsAppBlacklist: []

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

  property bool pinned: false
  property string lastActiveModal: ""
  property int lastActiveTab: 0

  readonly property bool isPickingFiles: qrCodeModal ? qrCodeModal.isPickingFiles : false
  readonly property bool isEyedropperActive: hyprPickerProc ? hyprPickerProc.running : false

  readonly property bool isEditorActive: (textEditorModal && textEditorModal.visible)
    || (imageEditorModal && imageEditorModal.visible)
    || (qrCodeModal && qrCodeModal.visible)
    || (colorPickerModal && colorPickerModal.visible)
    || (transformModal && transformModal.visible)
    || (diffModal && diffModal.visible)
    || root.activeTab === 3
    || root.settingsOpen
    || root.isPickingFiles
    || root.isEyedropperActive

  readonly property bool isKeepOpenActive: root.pinned || root.isEditorActive

  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color bg: Color.popups.background
  readonly property color fg: Color.popups.text
  readonly property color borderCol: Color.popups.border
  readonly property color selBg: Style.selectedFillFor(Color.foreground, Color.accent)
  readonly property color selFg: Color.foreground
  readonly property color scrimCol: Util.alpha(Color.background, 0.75)

  function open(payload) {
    root.controller.show()
    root.filterText = ""
    root.selectedIndex = 0
    root.clearConfirmOpen = false
    root.snippetEditOpen = false
    root.clipEditOpen = false
    root.transformOpen = false
    root.mergeDialogOpen = false
    root.showCalendar = false
    root.imageZoomOpen = false
    root.tagModalOpen = false
    root.snippetTemplatePickerOpen = false
    root.varPromptOpen = false
    root.bulkMode = false
    root.bulkSelectedIndices = []
    root.activeMenuClipIndex = -1

    var hasExplicitAction = payload && (
      payload.tab !== undefined ||
      payload.qrOpen ||
      payload.colorPickerOpen ||
      payload.editText !== undefined ||
      payload.editSnippet !== undefined ||
      payload.diffOpen ||
      payload.transformOpen ||
      payload.annotatePath ||
      payload.settingsOpen !== undefined
    )

    if (hasExplicitAction) {
      root.lastActiveModal = ""
      if (colorPickerModal) colorPickerModal.close()
      if (imageEditorModal) imageEditorModal.close()
      if (transformModal) transformModal.close()
      if (qrCodeModal) qrCodeModal.close()
      if (diffModal) diffModal.close()
      if (textEditorModal) textEditorModal.close()

      if (payload.tab !== undefined) root.activeTab = payload.tab
      if (payload.subTab !== undefined) root.colorStudioSubTab = payload.subTab
      if (payload.category !== undefined) root.categoryFilter = payload.category
      if (payload.filter !== undefined) root.filterText = payload.filter
      if (payload.settingsOpen !== undefined) root.settingsOpen = payload.settingsOpen
      if (payload.settingsSection !== undefined) {
        root.settingsActiveSection = payload.settingsSection
        if (settingsFlickable) settingsFlickable.contentY = 0
      }
      if (payload.templatePickerOpen !== undefined) root.snippetTemplatePickerOpen = payload.templatePickerOpen
      if (payload.varPromptTemplate) {
        root.openVariablePrompt(payload.varPromptTitle || "Template", payload.varPromptTemplate, !!payload.varPromptAutoPaste)
      }
      if (payload.annotatePath) root.openImageAnnotation(payload.annotatePath)
      if (payload.colorPickerOpen) {
        colorPickerModal.open(payload.colorHex || root.activeColorHex, root.history)
      }
      if (payload.editText !== undefined) {
        textEditorModal.openClip(payload.clipIndex !== undefined ? payload.clipIndex : 0, payload.editText, payload.title || "Markdown Editor")
        if (payload.feedback) textEditorModal.showFeedback(payload.feedback)
      }
      if (payload.editSnippet) {
        textEditorModal.openSnippet(-1, payload.title || "New Snippet", payload.content || "", payload.lang || "markdown", "", "")
        if (payload.feedback) textEditorModal.showFeedback(payload.feedback)
      }
      if (payload.pasteQueue !== undefined) {
        root.pasteQueue = payload.pasteQueue
      }
      if (payload.diffOpen) {
        var dIdx = payload.clipIndex !== undefined ? payload.clipIndex : 0
        var dItem = (root.history && dIdx >= 0 && dIdx < root.history.length) ? root.history[dIdx] : null
        var dText = payload.text !== undefined ? payload.text : (dItem ? dItem.text : "")
        var dRevs = payload.revisions !== undefined ? payload.revisions : (dItem ? (dItem.revisions || []) : [])
        diffModal.open(dIdx, dText, dRevs)
      }
      if (payload.transformOpen) {
        var tIdx = payload.clipIndex !== undefined ? payload.clipIndex : 0
        var tText = payload.text !== undefined ? payload.text : ((root.history && tIdx >= 0 && tIdx < root.history.length) ? (root.history[tIdx].text || "") : "")
        if (tText) transformModal.open(tText, tIdx)
        if (payload.transformerListOpen !== undefined) transformModal.transformerListOpen = payload.transformerListOpen
      }
      if (payload.qrOpen) {
        if (payload.fileShareOpen || payload.filePath) {
          qrCodeModal.openFileShare(payload.filePath || "")
        } else if (payload.decodeOpen || payload.imagePath) {
          qrCodeModal.openDecode(payload.imagePath || "", payload.text || "")
        } else {
          var qText = payload.text !== undefined ? payload.text : ((root.history && root.history.length > 0) ? (root.history[0].text || "") : "")
          qrCodeModal.open(qText)
        }
        if (payload.sectionTab !== undefined) qrCodeModal.activeSectionTab = payload.sectionTab
        if (payload.payloadType !== undefined) {
          qrCodeModal.payloadType = payload.payloadType
          qrCodeModal.updatePayloadText()
        }
        if (payload.qrTab !== undefined) {
          qrCodeModal.activeSectionTab = 2
          qrCodeModal.activeControlTab = payload.qrTab
        }
        if (payload.logoSubTab !== undefined) qrCodeModal.activeLogoSubTab = payload.logoSubTab
        if (payload.preset !== undefined) qrCodeModal.applyThemePresetByName(payload.preset)
        if (payload.copyDropdownOpen !== undefined) qrCodeModal.copyDropdownOpen = payload.copyDropdownOpen
        if (payload.saveDropdownOpen !== undefined) qrCodeModal.saveDropdownOpen = payload.saveDropdownOpen
        if (payload.themePresetsDropdownOpen !== undefined) qrCodeModal.themePresetsDropdownOpen = payload.themePresetsDropdownOpen
        if (payload.logoPresetsDropdownOpen !== undefined) qrCodeModal.logoPresetsDropdownOpen = payload.logoPresetsDropdownOpen
        if (payload.logoPreset !== undefined) qrCodeModal.logoPreset = payload.logoPreset
      }
    } else {
      // Reopening casually (e.g. from bar button or SUPER+SHIFT+V toggle):
      // Resume active workspace session if one was previously open!
      if (root.lastActiveModal === "qr" && qrCodeModal) {
        qrCodeModal.visible = true
      } else if (root.lastActiveModal === "text" && textEditorModal) {
        textEditorModal.visible = true
      } else if (root.lastActiveModal === "image" && imageEditorModal) {
        imageEditorModal.visible = true
      } else if (root.lastActiveModal === "transform" && transformModal) {
        transformModal.visible = true
      } else if (root.lastActiveModal === "diff" && diffModal) {
        diffModal.visible = true
      } else if (root.lastActiveModal === "settings") {
        root.settingsOpen = true
      } else if (root.lastActiveTab === 3) {
        root.activeTab = 3
      }
    }

    root.rebuildDisplay()
    if (payload && payload.menuClipIndex !== undefined) {
      Qt.callLater(function() {
        var idx = payload.menuClipIndex
        if (idx >= 0 && idx < displayModel.count) {
          root.activeMenuClipIndex = idx
          root.activeMenuPos = Qt.point(Style.space(160), Style.space(180))
        }
      })
    }
    if (root.activeTab !== 3 && !root.isEditorActive) {
      Qt.callLater(function() { searchInput.forceActiveFocus() })
    }
  }

  function handleCloseRequested() {
    if (textEditorModal && textEditorModal.visible) {
      textEditorModal.close()
      root.lastActiveModal = ""
      return
    }
    if (colorPickerModal && colorPickerModal.visible) {
      colorPickerModal.close()
      return
    }
    if (imageEditorModal && imageEditorModal.visible) {
      imageEditorModal.close()
      root.lastActiveModal = ""
      return
    }
    if (root.settingsOpen) {
      root.settingsOpen = false
      root.lastActiveModal = ""
      return
    }
    if (root.tagModalOpen) {
      root.tagModalOpen = false
      return
    }
    if (root.snippetTemplatePickerOpen) {
      root.snippetTemplatePickerOpen = false
      return
    }
    if (root.varPromptOpen) {
      root.varPromptOpen = false
      return
    }
    if (transformModal && transformModal.visible) {
      transformModal.close()
      root.lastActiveModal = ""
      return
    }
    if (qrCodeModal && qrCodeModal.visible) {
      qrCodeModal.close()
      root.lastActiveModal = ""
      return
    }
    if (diffModal && diffModal.visible) {
      diffModal.close()
      root.lastActiveModal = ""
      return
    }
    if (root.mergeDialogOpen) {
      root.mergeDialogOpen = false
      return
    }
    if (root.clipEditOpen) {
      root.clipEditOpen = false
      return
    }
    if (root.snippetEditOpen) {
      root.snippetEditOpen = false
      return
    }
    if (root.clearConfirmOpen) {
      root.clearConfirmOpen = false
      return
    }
    root.close(true)
  }

  function close(force) {
    if (!force && root.isKeepOpenActive) {
      // Inhibit outside-click dismissal when working in editors or pinned
      return
    }

    // Save active state before closing so reopening can resume right where the user left off
    if (qrCodeModal && qrCodeModal.visible) root.lastActiveModal = "qr"
    else if (textEditorModal && textEditorModal.visible) root.lastActiveModal = "text"
    else if (imageEditorModal && imageEditorModal.visible) root.lastActiveModal = "image"
    else if (transformModal && transformModal.visible) root.lastActiveModal = "transform"
    else if (diffModal && diffModal.visible) root.lastActiveModal = "diff"
    else if (root.settingsOpen) root.lastActiveModal = "settings"
    else root.lastActiveModal = ""

    root.lastActiveTab = root.activeTab

    // Hide modals without destroying their underlying session data
    if (transformModal) transformModal.visible = false
    if (qrCodeModal) qrCodeModal.visible = false
    if (diffModal) diffModal.visible = false
    if (textEditorModal) textEditorModal.visible = false
    if (colorPickerModal) colorPickerModal.visible = false
    if (imageEditorModal) imageEditorModal.visible = false

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
    root.snippetTemplatePickerOpen = false
    root.varPromptOpen = false
    root.bulkMode = false
    root.bulkSelectedIndices = []
    root.activeMenuClipIndex = -1
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close(true)
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
    var pMap = Object.assign({}, root.imagePalettes)
    for (var i = 0; i < root.history.length; i++) {
      var it = root.history[i]
      if (it && it.type === "image" && it.path && Array.isArray(it.colors) && it.colors.length > 0) {
        pMap[it.path] = it.colors
      }
    }
    root.imagePalettes = pMap
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

    if (normalized.type === "image" && normalized.path && Array.isArray(normalized.colors) && normalized.colors.length > 0) {
      var pMapEntry = Object.assign({}, root.imagePalettes)
      pMapEntry[normalized.path] = normalized.colors
      root.imagePalettes = pMapEntry
    }

    // Evaluate Automation & Regex Rules
    if (normalized.type === "text" && normalized.text) {
      var autoResult = AutomationRules.evaluateClip(root.automationRules, normalized.text, normalized.tags)
      if (autoResult.ignored) {
        console.log("ReClip: Clip dropped by privacy/ignore rule: " + autoResult.reason)
        return
      }
      if (autoResult.modifiedText !== undefined && autoResult.modifiedText !== normalized.text) {
        normalized.text = autoResult.modifiedText
        normalized.preview = normalized.text.slice(0, 300)
      }
      normalized.tags = autoResult.tags
      for (var a = 0; a < autoResult.actions.length; a++) {
        var act = autoResult.actions[a]
        if (act.type === "open_url" && act.url) {
          root.openUrlInBrowser(act.url)
        } else if (act.type === "notify" && act.message) {
          Quickshell.execDetached(["notify-send", "-a", "ReClip", act.title || "ReClip Automation", act.message])
        }
      }
    }

    root.history = ClipboardHistory.addEntry(root.history, normalized, root.historyLimit, {
      smartBump: root.settingsSmartBump,
      revisionStacking: root.settingsRevisionStacking
    })
    root.saveHistory()
    if (normalized.type === "text" && ClipboardHistory.isColor(normalized.text)) {
      root.selectColor(ClipboardHistory.extractColorHex(normalized.text) || normalized.text.trim())
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

  function loadTemplates(raw) {
    root.templates = TemplateEngine.parseTemplates(raw)
    root.templatesLoaded = true
  }

  function saveTemplates() {
    templatesFile.setText(JSON.stringify(root.templates, null, 2) + "\n")
  }

  function loadAutomations(raw) {
    root.automationRules = AutomationRules.parseRules(raw)
    root.automationsLoaded = true
  }

  function saveAutomations() {
    automationsFile.setText(JSON.stringify(root.automationRules, null, 2) + "\n")
  }

  function getLatestClipboardText() {
    if (root.history && root.history.length > 0) {
      for (var i = 0; i < root.history.length; i++) {
        if (root.history[i].type === "text" && root.history[i].text) {
          return root.history[i].text
        }
      }
    }
    return ""
  }

  function runRuleTester() {
    root.testRuleResult = AutomationRules.testRule(
      root.newRulePattern,
      root.newRuleAction,
      root.newRulePayload,
      root.testRuleSample
    )
  }

  function openVariablePrompt(title, tpl, autoPaste) {
    root.varPromptTitle = title || "Fill Template Variables"
    root.varPromptTemplate = tpl || ""
    root.varPromptAutoPaste = !!autoPaste
    var customVars = TemplateEngine.getCustomVariables(tpl)
    var list = []
    var initialValues = {}
    for (var i = 0; i < customVars.length; i++) {
      list.push(customVars[i].name)
      initialValues[customVars[i].name] = ""
    }
    root.varPromptList = list
    root.varPromptValues = initialValues
    root.updateVarPromptPreview()
    root.varPromptOpen = true
  }

  function setVarPromptValue(key, val) {
    var copy = Object.assign({}, root.varPromptValues)
    copy[key] = val
    root.varPromptValues = copy
    root.updateVarPromptPreview()
  }

  function updateVarPromptPreview() {
    root.varPromptPreview = TemplateEngine.expand(root.varPromptTemplate, root.varPromptValues, root.getLatestClipboardText())
  }

  function finishVariablePrompt(pasteAction) {
    var expanded = TemplateEngine.expand(root.varPromptTemplate, root.varPromptValues, root.getLatestClipboardText())
    root.varPromptOpen = false
    if (pasteAction) {
      root.close()
      Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(expanded) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
    } else {
      root.copyText(expanded)
    }
  }

  function openImageAnnotation(path) {
    if (!path) return
    imageEditorModal.open(path)
  }

  function selectColor(hex) {
    var parsed = ClipboardHistory.extractColorHex(hex) || ColorStudio.parseColor(hex) || hex
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
    if (str === undefined || str === null) return
    var s = String(str)
    if (s.length === 0) return
    Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(s) + " | wl-copy"])
  }

  function setSystemClipboard(str) {
    copyText(str)
  }

  function pasteClipboard(str) {
    if (str === undefined || str === null) return
    var s = String(str)
    if (s.length === 0) return
    Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(s) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
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

  // --- QR Code Decoder Helper ---
  function openQrDecoder(imagePath, precomputedText) {
    if (!imagePath) return
    var cleanPath = String(imagePath).replace(/^file:\/\//, "")
    qrCodeModal.openDecode(cleanPath, precomputedText || "")
  }

  // --- URL Open in Browser Helper ---
  function openUrlInBrowser(urlStr) {
    if (!urlStr) return
    Quickshell.execDetached(["xdg-open", urlStr])
  }

  // --- Unified Image Studio Helpers ---
  function openImageZoom(imgUriOrPath) {
    if (!imgUriOrPath) return
    var cleanPath = String(imgUriOrPath).replace(/^file:\/\//, "")
    imageEditorModal.open(cleanPath)
  }

  function closeImageZoom() {
    imageEditorModal.close()
  }

  function resetImageZoom() {
    imageEditorModal.resetZoom()
  }

  // --- App Attribution Helpers ---
  function getAppIcon(appClass) {
    var s = String(appClass || "").toLowerCase()
    if (!s) return "󰣆"
    if (s.indexOf("kitty") >= 0 || s.indexOf("alacritty") >= 0 || s.indexOf("foot") >= 0 || s.indexOf("ghostty") >= 0 || s.indexOf("term") >= 0) return "󰞷"
    if (s.indexOf("code") >= 0 || s.indexOf("vscodium") >= 0 || s.indexOf("cursor") >= 0 || s.indexOf("neovim") >= 0) return "󰨞"
    if (s.indexOf("firefox") >= 0 || s.indexOf("chrome") >= 0 || s.indexOf("brave") >= 0 || s.indexOf("zen") >= 0 || s.indexOf("browser") >= 0) return "󰖟"
    if (s.indexOf("thunar") >= 0 || s.indexOf("nautilus") >= 0 || s.indexOf("dolphin") >= 0 || s.indexOf("nemo") >= 0 || s.indexOf("files") >= 0) return "󰉋"
    if (s.indexOf("discord") >= 0 || s.indexOf("slack") >= 0 || s.indexOf("telegram") >= 0 || s.indexOf("signal") >= 0) return "󰭹"
    if (s.indexOf("obsidian") >= 0 || s.indexOf("notion") >= 0) return "󰠮"
    if (s.indexOf("spotify") >= 0 || s.indexOf("vlc") >= 0 || s.indexOf("mpv") >= 0) return "󰝚"
    if (s.indexOf("gimp") >= 0 || s.indexOf("inkscape") >= 0 || s.indexOf("krita") >= 0) return "󰏘"
    return "󰣆"
  }

  function formatAppName(appClass) {
    var s = String(appClass || "").trim()
    if (!s) return ""
    if (s.indexOf(".") >= 0) {
      var parts = s.split(".")
      s = parts[parts.length - 1]
    }
    return s.charAt(0).toUpperCase() + s.slice(1)
  }

  // --- Settings & Retention Helpers ---
  function loadSettings(raw) {
    try {
      var s = JSON.parse(raw)
      if (s.maxClips !== undefined) root.settingsMaxClips = s.maxClips
      if (s.retainDays !== undefined) root.settingsRetainDays = s.retainDays
      if (s.ignoreSensitive !== undefined) root.settingsIgnoreSensitive = s.ignoreSensitive
      if (s.imagePaletteLimit !== undefined) root.settingsImagePaletteLimit = s.imagePaletteLimit
      if (s.toggleShortcut !== undefined && String(s.toggleShortcut).trim() !== "") root.settingsToggleShortcut = String(s.toggleShortcut).trim()
      if (s.pasteModifiers !== undefined && String(s.pasteModifiers).trim() !== "") root.settingsPasteModifiers = String(s.pasteModifiers).trim()
      if (s.enableQuickPaste !== undefined) root.settingsEnableQuickPaste = Boolean(s.enableQuickPaste)
      if (s.clipActionsOnHover !== undefined) root.settingsClipActionsOnHover = Boolean(s.clipActionsOnHover)
      if (s.smartBump !== undefined) root.settingsSmartBump = Boolean(s.smartBump)
      if (s.revisionStacking !== undefined) root.settingsRevisionStacking = Boolean(s.revisionStacking)
      if (s.qrAllowUpload !== undefined) root.settingsQrAllowUpload = Boolean(s.qrAllowUpload)
      if (s.qrAllowBeam !== undefined) root.settingsQrAllowBeam = Boolean(s.qrAllowBeam)
      if (Array.isArray(s.appBlacklist)) root.settingsAppBlacklist = s.appBlacklist
    } catch(e) {}
  }

  function saveSettings() {
    var obj = {
      maxClips: root.settingsMaxClips,
      retainDays: root.settingsRetainDays,
      ignoreSensitive: root.settingsIgnoreSensitive,
      imagePaletteLimit: root.settingsImagePaletteLimit,
      toggleShortcut: root.settingsToggleShortcut,
      pasteModifiers: root.settingsPasteModifiers,
      enableQuickPaste: root.settingsEnableQuickPaste,
      clipActionsOnHover: root.settingsClipActionsOnHover,
      smartBump: root.settingsSmartBump,
      revisionStacking: root.settingsRevisionStacking,
      qrAllowUpload: root.settingsQrAllowUpload,
      qrAllowBeam: root.settingsQrAllowBeam,
      appBlacklist: root.settingsAppBlacklist
    }
    settingsFile.setText(JSON.stringify(obj, null, 2) + "\n")
    syncKeybindingsProc.running = true
  }

  function syncKeybindingsWithNotify() {
    root.saveSettings()
    Quickshell.execDetached(["bash", root.syncKeybindingsScript, "--notify"])
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
        var imgPalette = ""
        if (r.entryType === "image" && r.path) {
          if (r.colors && Array.isArray(r.colors) && r.colors.length > 0) {
            imgPalette = r.colors.slice(0, root.settingsImagePaletteLimit).join(",")
          } else if (root.imagePalettes[r.path] && Array.isArray(root.imagePalettes[r.path]) && root.imagePalettes[r.path].length > 0) {
            imgPalette = root.imagePalettes[r.path].slice(0, root.settingsImagePaletteLimit).join(",")
          } else {
            root.queueImagePaletteExtraction(r.path, r.index)
          }
        }
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
          imagePaletteStr: imgPalette,
          path: r.path,
          mime: r.mime,
          timeAgo: r.timeAgo || "",
          capturedDate: r.capturedDate || "",
          charCount: r.charCount || 0,
          lineCount: r.lineCount || 1,
          wordCount: r.wordCount || 0,
          isPinned: !!r.isPinned,
          isFavorite: !!r.isFavorite,
          copyCount: r.copyCount || 1,
          sourceApp: r.sourceApp || "",
          sourceTitle: r.sourceTitle || "",
          revisionCount: r.revisionCount || 0,
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
          imagePaletteStr: "",
          path: "",
          mime: "text/plain",
          timeAgo: "",
          capturedDate: "",
          charCount: s.content.length,
          lineCount: s.content.split("\n").length,
          wordCount: s.content.split(/\s+/).length,
          isPinned: false,
          isFavorite: !!s.favorite,
          copyCount: 1,
          sourceApp: "",
          sourceTitle: "",
          revisionCount: 0,
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
          var qImgPal = ""
          if (qEntry.type === "image") {
            if (qEntry.colors && Array.isArray(qEntry.colors) && qEntry.colors.length > 0) {
              qImgPal = qEntry.colors.slice(0, root.settingsImagePaletteLimit).join(",")
            } else if (root.imagePalettes[qEntry.path] && Array.isArray(root.imagePalettes[qEntry.path]) && root.imagePalettes[qEntry.path].length > 0) {
              qImgPal = root.imagePalettes[qEntry.path].slice(0, root.settingsImagePaletteLimit).join(",")
            }
          }
          displayModel.append({
            itemType: "queue",
            entryType: qEntry.type,
            kind: ClipboardHistory.detectKind(qEntry),
            colorValue: ClipboardHistory.extractColorHex(qTxt) || "",
            colorRgb: ClipboardHistory.extractColorHex(qTxt) ? ClipboardHistory.hexToRgb(ClipboardHistory.extractColorHex(qTxt)) : "",
            codeLang: ClipboardHistory.detectCodeLanguage(qTxt),
            fullText: qTxt,
            previewText: (q + 1) + ". " + ClipboardHistory.previewText(qEntry),
            previewImage: qEntry.type === "image" ? Util.fileUrl(qEntry.path) : "",
            imagePaletteStr: qImgPal,
            path: qEntry.path || "",
            mime: qEntry.mime || "text/plain",
            timeAgo: ClipboardHistory.formatTimeAgo(qEntry.capturedAt),
            capturedDate: String(qEntry.capturedAt || "").substring(0, 10),
            charCount: qTxt.length,
            lineCount: qTxt.split("\n").length,
            wordCount: qTxt.split(/\s+/).length,
            isPinned: false,
            isFavorite: false,
            copyCount: qEntry.copyCount || 1,
            sourceApp: qEntry.sourceApp || "",
            sourceTitle: qEntry.sourceTitle || "",
            revisionCount: Array.isArray(qEntry.revisions) ? qEntry.revisions.length : 0,
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
    if (!row) return
    if (row.entryType === "image" && row.path) {
      root.close()
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-file", row.mime || "image/png", row.path])
    } else if (row.fullText) {
      if (row.itemType === "snippet" && TemplateEngine.hasCustomVariables(row.fullText)) {
        root.openVariablePrompt(row.title || row.previewText || "Snippet", row.fullText, true)
      } else {
        root.close()
        var textToPaste = row.itemType === "snippet" ? TemplateEngine.expand(row.fullText, {}, root.getLatestClipboardText()) : row.fullText
        Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(textToPaste) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
      }
    }
  }

  function copyRow(row) {
    if (!row) return
    if (row.entryType === "image" && row.path) {
      Quickshell.execDetached(["bash", "-c", "wl-copy --type " + Util.shellQuote(row.mime || "image/png") + " < " + Util.shellQuote(row.path)])
    } else if (row.fullText) {
      if (row.itemType === "snippet" && TemplateEngine.hasCustomVariables(row.fullText)) {
        root.openVariablePrompt(row.title || row.previewText || "Snippet", row.fullText, false)
      } else {
        var textToCopy = row.itemType === "snippet" ? TemplateEngine.expand(row.fullText, {}, root.getLatestClipboardText()) : row.fullText
        root.copyText(textToCopy)
      }
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
      textEditorModal.openSnippet(row.snippetIndex, row.title || "", row.fullText || "", row.language || "markdown", row.folder || "", row.tags || "")
    } else if (row.itemType === "history" && row.entryType === "text") {
      var previewTitle = row.displayText || ("Clip #" + (row.historyIndex + 1))
      textEditorModal.openClip(row.historyIndex, row.fullText || "", previewTitle)
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
    transformModal.open(row.fullText || "", row.historyIndex)
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
    var pos = root.pasteQueue.indexOf(idx)
    if (pos >= 0) {
      root.pasteQueue.splice(pos, 1)
    } else {
      root.pasteQueue.push(idx)
    }
    root.pasteQueueChanged()
    root.rebuildDisplay()
  }

  function playPasteQueue() {
    if (root.pasteQueue.length === 0) return
    root.close()
    var indices = root.pasteQueue.slice()
    root.pasteQueue = []
    root.pasteQueueChanged()
    queueProc.indices = indices
    queueProc.pending = indices.length
    queueProc.position = 0
    queueProc.step()
    root.rebuildDisplay()
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
    qrCodeModal.open(text)
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

  FileView {
    id: templatesFile
    path: root.templatesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadTemplates(text())
    onLoadFailed: root.loadTemplates("[]")
    onFileChanged: reload()
  }

  FileView {
    id: automationsFile
    path: root.automationsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadAutomations(text())
    onLoadFailed: root.loadAutomations("[]")
    onFileChanged: reload()
  }

  Process {
    id: incognitoCheckProc
    command: ["test", "-f", root.incognitoPath]
    onExited: function(code) { root.incognito = (code === 0) }
  }

  Process {
    id: syncKeybindingsProc
    command: ["bash", root.syncKeybindingsScript]
  }

  Process {
    id: initProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: {
      root.checkIncognitoFile()
      wlInit.running = true
      currentProc.running = true
      syncKeybindingsProc.running = true
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
    id: hyprPickerProc
    command: ["sh", "-c", "pkill hyprpicker 2>/dev/null; hyprpicker -a"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var picked = String(text || "").trim()
        if (picked) {
          root.selectColor(picked)
          if (colorPickerModal && colorPickerModal.visible) {
            colorPickerModal.setColor(picked)
          }
          if (imageEditorModal && imageEditorModal.visible) {
            imageEditorModal.applyPickedColor(picked)
            imageEditorModal.showFeedback("󰈊 Picked " + picked)
          }
          if (textEditorModal && textEditorModal.visible) {
            textEditorModal.applyPickedColor(picked)
          }
          if (qrCodeModal && qrCodeModal.visible) {
            qrCodeModal.applyPickedColor(picked)
          }
        }
      }
    }
  }

  function pickScreenColor() {
    hyprPickerProc.running = true
  }

  Process {
    id: paletteExtractProc
    property string activePath: ""
    property int activeIdx: -1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        try {
          var arr = JSON.parse(raw)
          if (Array.isArray(arr) && arr.length > 0 && paletteExtractProc.activePath) {
            root.setImagePalette(paletteExtractProc.activePath, paletteExtractProc.activeIdx, arr)
          }
        } catch(e) {}
      }
    }
    onExited: function(code) {
      paletteExtractProc.activePath = ""
      paletteExtractProc.activeIdx = -1
      paletteQueueTimer.restart()
    }
  }

  Timer {
    id: paletteQueueTimer
    interval: 50
    repeat: false
    onTriggered: root.processPaletteQueue()
  }

  function queueImagePaletteExtraction(path, hIdx) {
    if (!path) return
    if (root.imagePalettes[path] && root.imagePalettes[path].length > 0) return
    for (var i = 0; i < root.paletteQueue.length; i++) {
      if (root.paletteQueue[i].path === path) return
    }
    root.paletteQueue.push({ path: path, hIdx: hIdx })
    if (!paletteExtractProc.running && !paletteQueueTimer.running) {
      paletteQueueTimer.restart()
    }
  }

  function processPaletteQueue() {
    if (paletteExtractProc.running) return
    if (root.paletteQueue.length === 0) return
    var next = root.paletteQueue.shift()
    paletteExtractProc.activePath = next.path
    paletteExtractProc.activeIdx = next.hIdx
    paletteExtractProc.command = ["bash", root.paletteScript, next.path, String(root.settingsImagePaletteLimit)]
    paletteExtractProc.running = true
  }

  function setImagePalette(path, hIdx, colors) {
    var pMap = Object.assign({}, root.imagePalettes)
    pMap[path] = colors
    root.imagePalettes = pMap

    for (var i = 0; i < root.history.length; i++) {
      var item = root.history[i]
      if (item && item.type === "image" && item.path === path) {
        item.colors = colors
        root.saveHistory()
        break
      }
    }
    root.rebuildDisplay()
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
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.cappedContentHeight(panel.screenH > 0 ? Math.round(panel.screenH * 0.94) : Style.space(920))

    mask: Region {
      x: root.isKeepOpenActive ? panel.cardOrigin.x : 0
      y: root.isKeepOpenActive ? panel.cardOrigin.y : 0
      width: root.isKeepOpenActive ? panel.contentWidth : panel.screenW
      height: root.isKeepOpenActive ? panel.contentHeight : panel.screenH
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.handleCloseRequested()
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

        // Trailing Controls (Aligned strictly to the Right: Calendar, Multi-Select, Screenshot, OCR, Settings, Incognito, Close)
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          // Timeline / Calendar Toggle
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.showTimeline ? Color.accent : (root.activeDateFilter !== "" ? Util.alpha(Color.accent, 0.2) : (tlMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08)))
            border.width: 1
            border.color: root.showTimeline || root.activeDateFilter !== "" ? Color.accent : (tlMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12))
            Text {
              text: "󰸗"
              color: root.showTimeline ? "#fff" : (root.activeDateFilter !== "" ? Color.accent : (tlMouse.containsMouse ? Color.accent : root.fg))
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              id: tlMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.showTimeline = !root.showTimeline
            }
            PanelToolTip {
              visible: tlMouse.containsMouse
              text: root.showTimeline ? "Hide Timeline" : "Show Timeline & Calendar"
            }
          }

          // Multi-Select Mode Toggle
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.bulkMode ? Color.accent : (bulkMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08))
            border.width: 1
            border.color: root.bulkMode ? Color.accent : (bulkMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12))
            Text {
              text: "󰒆"
              color: root.bulkMode ? "#fff" : (bulkMouse.containsMouse ? Color.accent : root.fg)
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              id: bulkMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleBulkMode()
            }
            PanelToolTip {
              visible: bulkMouse.containsMouse
              text: root.bulkMode ? "Exit Multi-Select" : "Multi-Select Mode"
            }
          }

          // Screenshot Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: shotMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08)
            border.width: 1
            border.color: shotMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "󰄀"
              color: shotMouse.containsMouse ? Color.accent : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              id: shotMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.takeScreenshot()
            }
            PanelToolTip {
              visible: shotMouse.containsMouse
              text: "Take Screenshot"
            }
          }

          // OCR Screen Capture Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: ocrCapMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08)
            border.width: 1
            border.color: ocrCapMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "󰐳"
              color: ocrCapMouse.containsMouse ? Color.accent : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              id: ocrCapMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.captureOcrScreen()
            }
            PanelToolTip {
              visible: ocrCapMouse.containsMouse
              text: "Extract Text from Screen (OCR)"
            }
          }

          // Share Data / QR Code Bridge Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: qrGenMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08)
            border.width: 1
            border.color: qrGenMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "󰒗"
              color: qrGenMouse.containsMouse ? Color.accent : root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              id: qrGenMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: qrCodeModal.open("")
            }
            PanelToolTip {
              visible: qrGenMouse.containsMouse
              text: "Share Data (QR Code)"
            }
          }

          // Settings & Preferences Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.settingsOpen ? Color.accent : (settingsBtnMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08))
            border.width: 1
            border.color: root.settingsOpen ? Color.accent : (settingsBtnMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12))
            Text {
              text: "󰒓"
              color: root.settingsOpen ? "#fff" : (settingsBtnMouse.containsMouse ? Color.accent : root.fg)
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }
            MouseArea {
              id: settingsBtnMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.settingsOpen = !root.settingsOpen
            }
            PanelToolTip {
              visible: settingsBtnMouse.containsMouse
              text: root.settingsOpen ? "Close Settings" : "Preferences & Settings"
            }
          }

          // Pin / Keep Open Toggle Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.pinned ? Util.alpha(Color.accent, 0.2) : (pinMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08))
            border.width: 1
            border.color: root.pinned ? Color.accent : (pinMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12))

            Text {
              text: root.pinned ? "󰐃" : "󰤱"
              color: root.pinned ? Color.accent : (pinMouse.containsMouse ? Color.accent : root.fg)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }

            MouseArea {
              id: pinMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.pinned = !root.pinned
            }
            PanelToolTip {
              visible: pinMouse.containsMouse
              text: root.pinned ? "Pinned (Window stays open on click outside)" : "Pin Window (Keep open when clicking outside)"
            }
          }

          // Incognito Toggle Icon Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: root.incognito ? Util.alpha(Color.urgent, 0.2) : (incogMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08))
            border.width: 1
            border.color: root.incognito ? Color.urgent : (incogMouse.containsMouse ? (root.incognito ? Color.urgent : Color.accent) : Util.alpha(root.fg, 0.12))

            Text {
              text: root.incognito ? "󰈈" : "󰈉"
              color: root.incognito ? Color.urgent : (incogMouse.containsMouse ? Color.accent : root.fg)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.centerIn: parent
            }

            MouseArea {
              id: incogMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleIncognito()
            }
            PanelToolTip {
              visible: incogMouse.containsMouse
              text: root.incognito ? "Incognito Active (Recording paused)" : "Toggle Incognito Mode"
            }
          }

          // Close Button
          Rectangle {
            width: Style.space(30); height: Style.space(30)
            radius: Style.space(6)
            color: closeMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08)
            border.width: 1
            border.color: closeMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12)
            Text {
              text: "✕"
              color: closeMouse.containsMouse ? Color.accent : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.centerIn: parent
            }
            MouseArea {
              id: closeMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.close(true)
            }
            PanelToolTip {
              visible: closeMouse.containsMouse
              text: "Close (Esc)"
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
              { id: 0, label: "Clips", icon: "󰅍" },
              { id: 1, label: "Pinned", icon: "󰐃" },
              { id: 2, label: "Snippets", icon: "󰅩" },
              { id: 3, label: "Colors", icon: "󰏘" },
              { id: 4, label: "Queue", icon: "󰆒" }
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
                  text: parent.parent.modelData.label
                  color: root.activeTab === parent.parent.modelData.id ? "#fff" : root.fg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  font.bold: root.activeTab === parent.parent.modelData.id
                  elide: Text.ElideRight
                  anchors.verticalCenter: parent.verticalCenter
                }

                // Subtle status dot when queue has staged items
                Rectangle {
                  visible: parent.parent.modelData.id === 4 && root.pasteQueue.length > 0
                  width: Style.space(5)
                  height: Style.space(5)
                  radius: Style.space(3)
                  color: root.activeTab === 4 ? "#ffffff" : Color.accent
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
                  id: timelineMarkerDelegate
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
                    onClicked: root.setDateFilter(timelineMarkerDelegate.modelData.dateStr)
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
                      Text { text: timelineMarkerDelegate.modelData.label; color: root.fg; font.pixelSize: Style.space(9); font.bold: true }
                      Text { text: timelineMarkerDelegate.modelData.count + " clips"; color: Color.accent; font.pixelSize: Style.space(8) }
                    }
                  }
                }
              }
            }
          }

          // Timeline Range Dates & Active Selection Info
          Item {
            width: parent.width
            height: Style.space(16)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.timelineData.oldestStr
              color: Util.alpha(root.fg, 0.45); font.family: root.fontFamily; font.pixelSize: Style.space(9)
            }

            Text {
              anchors.centerIn: parent
              text: root.activeDateFilter !== "" ? ("Filtered: " + root.formatDateFilterLabel(root.activeDateFilter)) : "Click markers to filter"
              color: root.activeDateFilter !== "" ? Color.accent : Util.alpha(root.fg, 0.45)
              font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: root.activeDateFilter !== ""
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.timelineData.newestStr
              color: Util.alpha(root.fg, 0.45); font.family: root.fontFamily; font.pixelSize: Style.space(9)
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
    // TWO-TIER UNIFIED FOOTER (Consistent on ALL tabs)
    // ==========================================
    Rectangle {
      id: footerBar
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(64)
      radius: Style.space(8)
      color: Util.alpha(root.fg, 0.04)
      border.width: 1
      border.color: Util.alpha(root.fg, 0.08)
      clip: true

      Column {
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------------------
        // ROW 1: Action Controls & Active Tab Identity (Height: 34px)
        // -------------------------------------------------------------
        Item {
          width: parent.width
          height: Style.space(34)

          // LEFT: Active Tab Identity Badge
          Rectangle {
            id: tabBadge
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            height: Style.space(24)
            width: tabBadgeContent.implicitWidth + Style.space(14)
            radius: Style.space(5)
            color: Util.alpha(Color.accent, 0.12)
            border.width: 1
            border.color: Util.alpha(Color.accent, 0.25)

            Row {
              id: tabBadgeContent
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                text: root.activeTab === 0 ? "󰆴" :
                      root.activeTab === 1 ? "󰐃" :
                      root.activeTab === 2 ? "󰩫" :
                      root.activeTab === 3 ? "󰏘" : "󰆒"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.activeTab === 0 ? "History" :
                      root.activeTab === 1 ? "Pinned" :
                      root.activeTab === 2 ? "Snippets" :
                      root.activeTab === 3 ? "Color Studio" : "Paste Queue"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.space(10)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // RIGHT: Dedicated Action Buttons Per Page
          Row {
            id: footerActionsRow
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            // TAB 0: Clear History Button
            Rectangle {
              visible: root.activeTab === 0 && root.history.length > 0
              height: Style.space(26)
              width: clearBtnContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Util.alpha(Color.urgent, 0.1)
              border.width: 1
              border.color: Util.alpha(Color.urgent, 0.25)

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

            // TAB 1: Pinned / Starred Filter Info Pill
            Rectangle {
              visible: root.activeTab === 1
              height: Style.space(26)
              width: pinnedInfoContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Util.alpha(Color.accent, 0.1)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.25)

              Row {
                id: pinnedInfoContent
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "󰐃"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Favorites Only"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
            }

            // TAB 2: Templates Picker Button
            Rectangle {
              visible: root.activeTab === 2
              height: Style.space(26)
              width: tplBtnContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Util.alpha(Color.accent, 0.15)
              border.width: 1
              border.color: Color.accent

              Row {
                id: tplBtnContent
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "󰏫"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Templates"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.snippetTemplatePickerOpen = true
              }
            }

            // TAB 2: New Snippet Button (opens textEditorModal for new snippet)
            Rectangle {
              visible: root.activeTab === 2
              height: Style.space(26)
              width: newSnipContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Color.accent

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
                  textEditorModal.openSnippet(-1, "", "", "markdown", "", "")
                }
              }
            }

            // TAB 3: Copy Current HEX Button
            Rectangle {
              visible: root.activeTab === 3
              height: Style.space(26)
              width: copyHexContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Color.accent

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
                width: mergeContent.implicitWidth + Style.space(12)
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
                width: pasteQueueContent.implicitWidth + Style.space(12)
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
                width: clearQueueContent.implicitWidth + Style.space(10)
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

        // -------------------------------------------------------------
        // ROW DIVIDER
        // -------------------------------------------------------------
        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(root.fg, 0.08)
        }

        // -------------------------------------------------------------
        // ROW 2: Live Info, Stats & Keyboard Shortcuts Strip (Height: 29px)
        // -------------------------------------------------------------
        Rectangle {
          width: parent.width
          height: Style.space(29)
          color: Util.alpha(root.fg, 0.02)

          Item {
            anchors.fill: parent

            // LEFT: Live Stats / Information
            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                text: {
                  if (root.activeTab === 0) {
                    return (root.filterText || root.categoryFilter !== "all")
                      ? displayModel.count + " / " + root.history.length + " clips"
                      : root.history.length + " clips"
                  } else if (root.activeTab === 1) {
                    var favsCount = 0
                    for (var fi = 0; fi < root.history.length; fi++) {
                      if (root.history[fi] && root.history[fi].pinned) favsCount++
                    }
                    return favsCount + " pinned"
                  } else if (root.activeTab === 2) {
                    return root.snippets.length + " snippets"
                  } else if (root.activeTab === 3) {
                    return root.activeColorAnalysis ? (root.activeColorAnalysis.colorName || root.activeColorHex) : root.activeColorHex
                  } else if (root.activeTab === 4) {
                    return root.pasteQueue.length + (root.pasteQueue.length === 1 ? " item in queue" : " items in queue")
                  }
                  return ""
                }
                color: Util.alpha(root.fg, 0.55)
                font.family: root.fontFamily
                font.pixelSize: Style.space(9)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            // RIGHT: Universal Keyboard Shortcut Chips
            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              // 1-9 Chip (Only on History / Pinned)
              Row {
                visible: root.activeTab === 0 || root.activeTab === 1
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16); width: Style.space(22); radius: Style.space(3)
                  color: Util.alpha(root.fg, 0.07)
                  border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                  Text { text: "1-9"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                }
                Text { text: "Paste"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
              }

              // Enter Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16); width: Style.space(16); radius: Style.space(3)
                  color: Util.alpha(root.fg, 0.07)
                  border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                  Text { text: "↵"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
                }
                Text { text: root.activeTab === 3 ? "Inspect" : "Paste"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
              }

              // Tab Key Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16); width: Style.space(24); radius: Style.space(3)
                  color: Util.alpha(root.fg, 0.07)
                  border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                  Text { text: "Tab"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                }
                Text { text: "Switch"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
              }

              // Esc Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16); width: Style.space(22); radius: Style.space(3)
                  color: Util.alpha(root.fg, 0.07)
                  border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                  Text { text: "Esc"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                }
                Text { text: "Close"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
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
                id: currentColorBox
                width: Style.space(56); height: Style.space(56)
                radius: Style.space(8)
                color: root.activeColorHex
                border.width: curBoxMouse.containsMouse ? 2 : 1
                border.color: curBoxMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.25)

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(8)
                  color: curBoxMouse.containsMouse ? Util.alpha("#000000", 0.4) : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(1)
                    visible: curBoxMouse.containsMouse
                    Text {
                      text: "󰏘"
                      color: "#ffffff"
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(16)
                      anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                      text: "PICK"
                      color: "#ffffff"
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(7)
                      font.bold: true
                      anchors.horizontalCenter: parent.horizontalCenter
                    }
                  }
                }

                MouseArea {
                  id: curBoxMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: colorPickerModal.open(root.activeColorHex, root.history)
                }

                PanelToolTip {
                  visible: curBoxMouse.containsMouse
                  text: "Click to open Color Picker"
                }
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
                    width: parent.width - Style.space(70 + 34 + 12); height: Style.space(30); radius: Style.space(4)
                    color: Util.alpha(root.fg, 0.06); border.width: 1; border.color: Util.alpha(root.fg, 0.15)
                    TextInput {
                      id: colorTextInput
                      anchors.fill: parent; anchors.margins: Style.space(4)
                      color: root.fg; font.family: "monospace"; font.pixelSize: Style.font.body; font.bold: true
                      text: root.activeColorHex
                      selectByMouse: true
                      onAccepted: root.selectColor(text)
                      Connections {
                        target: root
                        function onActiveColorHexChanged() {
                          if (colorTextInput.text !== root.activeColorHex) {
                            colorTextInput.text = root.activeColorHex
                          }
                        }
                      }
                    }
                  }
                  // Screen Eyedropper Button (Omarchy Hyprpicker)
                  Rectangle {
                    id: screenDropBtn
                    width: Style.space(34); height: Style.space(30); radius: Style.space(4)
                    color: dropBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(root.fg, 0.08)
                    border.width: 1; border.color: dropBtnMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.15)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                      text: "󰃉"
                      color: dropBtnMouse.containsMouse ? Color.accent : root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(13)
                      anchors.centerIn: parent
                    }
                    MouseArea {
                      id: dropBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.pickScreenColor()
                    }
                    PanelToolTip {
                      visible: dropBtnMouse.containsMouse
                      text: "Pick Color from Screen (Eyedropper)"
                    }
                  }
                  // Inspect Button
                  Rectangle {
                    id: inspectBtn
                    width: Style.space(70); height: Style.space(30); radius: Style.space(4)
                    color: inspectMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { text: "Inspect"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.centerIn: parent }
                    MouseArea {
                      id: inspectMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.selectColor(colorTextInput.text)
                      cursorShape: Qt.PointingHandCursor
                    }
                    PanelToolTip {
                      visible: inspectMouse.containsMouse
                      text: "Inspect & analyze color"
                    }
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
                id: subTabBtnDelegate
                required property var modelData
                width: (parent.width - Style.space(20)) / 6
                height: Style.space(30)
                radius: Style.space(5)
                color: root.colorStudioSubTab === subTabBtnDelegate.modelData.id ? Util.alpha(Color.accent, 0.18) : Util.alpha(root.fg, 0.04)
                border.width: 1; border.color: root.colorStudioSubTab === subTabBtnDelegate.modelData.id ? Color.accent : Util.alpha(root.fg, 0.08)

                Row {
                  anchors.centerIn: parent; spacing: Style.space(3)
                  Text {
                    text: subTabBtnDelegate.modelData.icon
                    color: root.colorStudioSubTab === subTabBtnDelegate.modelData.id ? Color.accent : Util.alpha(root.fg, 0.6)
                    font.family: root.fontFamily; font.pixelSize: Style.space(10)
                  }
                  Text {
                    text: subTabBtnDelegate.modelData.label
                    color: root.colorStudioSubTab === subTabBtnDelegate.modelData.id ? Color.accent : root.fg
                    font.family: root.fontFamily; font.pixelSize: Style.space(8)
                    font.bold: root.colorStudioSubTab === subTabBtnDelegate.modelData.id
                  }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.colorStudioSubTab = subTabBtnDelegate.modelData.id
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
                  id: fmtItemDelegate
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
                      Text { text: fmtItemDelegate.modelData.label; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8); font.bold: true }
                      Text { text: fmtItemDelegate.modelData.val; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(9); font.bold: true; elide: Text.ElideRight; width: parent.width }
                    }

                    Text { text: "󰆏"; color: Util.alpha(root.fg, 0.35); font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
                  }

                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(fmtItemDelegate.modelData.val)
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
              id: mixedResultCol
              width: parent.width; spacing: Style.space(6)
              property string mixedHex: {
                if (root.blendMode !== "normal") return ColorStudio.blendWithStrength(root.mixColor1, root.mixColor2, root.blendMode, root.mixRatio)
                if (root.mixMode === "lab") return ColorStudio.mixColorsLab(root.mixColor1, root.mixColor2, root.mixRatio)
                if (root.mixMode === "oklch") return ColorStudio.mixColorsOklch(root.mixColor1, root.mixColor2, root.mixRatio)
                return ColorStudio.mixColors(root.mixColor1, root.mixColor2, root.mixRatio)
              }

              Rectangle {
                width: parent.width; height: Style.space(60); radius: Style.space(8)
                color: mixedResultCol.mixedHex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                Text {
                  text: mixedResultCol.mixedHex
                  color: ColorStudio.getContrastRatio(mixedResultCol.mixedHex, "#000000") > 4.5 ? "#000" : "#fff"
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
                  onClicked: root.selectColor(mixedResultCol.mixedHex)
                }
              }
            }

            // Step Scale Generator
            Column {
              id: mixerScaleCol
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
                  model: mixerScaleCol.currentScale
                  Rectangle {
                    id: scaleRectDelegate
                    required property string modelData
                    width: (parent.width - (mixerScaleCol.currentScale.length - 1)) / Math.max(1, mixerScaleCol.currentScale.length)
                    height: parent.height; color: modelData
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.selectColor(scaleRectDelegate.modelData); root.copyText(scaleRectDelegate.modelData) }
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
                    onClicked: root.copyText(ColorStudio.exportPaletteAsCSS(mixerScaleCol.currentScale))
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
                    onClicked: root.copyText(ColorStudio.exportPaletteAsJSON(mixerScaleCol.currentScale))
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
            id: harmoniesSubTabCol
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

                // Interactive angle offset slider
                Rectangle {
                  width: Style.space(120); height: Style.space(12); radius: Style.space(6)
                  color: Util.alpha(root.fg, 0.08); anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    x: ((root.harmonyAngleOffset + 180) / 360) * (parent.width - Style.space(12))
                    width: Style.space(12); height: Style.space(12); radius: Style.space(6); color: Color.accent
                  }

                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                    onPositionChanged: function(mouse) {
                      var norm = Math.max(0, Math.min(1, mouse.x / width))
                      root.harmonyAngleOffset = Math.round(norm * 360 - 180)
                    }
                  }
                }

                Text { text: root.harmonyAngleOffset + "°"; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }

                Item { Layout.fillWidth: true; width: parent.width - Style.space(340) }

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
                id: harmonyDelegate
                required property var modelData
                property var colorsList: harmoniesSubTabCol.advancedHarmoniesMap[harmonyDelegate.modelData.key] || []
                width: parent.width; height: Style.space(56); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.03); border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                Column {
                  anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(4)

                  Row {
                    width: parent.width
                    Text { text: harmonyDelegate.modelData.name; color: Util.alpha(root.fg, 0.75); font.pixelSize: Style.space(8); font.bold: true }
                    Item { Layout.fillWidth: true; width: parent.width - Style.space(200) }
                    Row {
                      spacing: Style.space(4)
                      Rectangle {
                        height: Style.space(16); radius: Style.space(3); width: Style.space(40); color: Util.alpha(root.fg, 0.06)
                        Text { text: "󰆏 CSS"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(6); anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.copyText(ColorStudio.exportPaletteAsCSS(harmonyDelegate.colorsList))
                        }
                      }
                      Rectangle {
                        height: Style.space(16); radius: Style.space(3); width: Style.space(42); color: Util.alpha(root.fg, 0.06)
                        Text { text: "󰆏 JSON"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(6); anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.copyText(ColorStudio.exportPaletteAsJSON(harmonyDelegate.colorsList))
                        }
                      }
                    }
                  }

                  // Swatches Row
                  Row {
                    width: parent.width; height: Style.space(24); spacing: Style.space(4)
                    Repeater {
                      model: harmonyDelegate.colorsList
                      Rectangle {
                        id: harmonySwatchDelegate
                        required property string modelData
                        width: (parent.width - (harmonyDelegate.colorsList.length - 1) * Style.space(4)) / Math.max(1, harmonyDelegate.colorsList.length)
                        height: parent.height; radius: Style.space(4); color: harmonySwatchDelegate.modelData
                        border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                        Text {
                          text: harmonySwatchDelegate.modelData
                          color: ColorStudio.getContrastRatio(harmonySwatchDelegate.modelData, "#000000") > 4.5 ? "#000" : "#fff"
                          font.family: "monospace"; font.pixelSize: Style.space(7); font.bold: true
                          anchors.centerIn: parent
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (!root.lockHarmonyColor) root.selectColor(harmonySwatchDelegate.modelData)
                            root.copyText(harmonySwatchDelegate.modelData)
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
                id: a11yCardCol
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
                  visible: a11yCardCol.currentRatio < 4.5
                  width: parent.width; height: Style.space(36); radius: Style.space(5)
                  color: Util.alpha("#EF4444", 0.12); border.width: 1; border.color: Util.alpha("#EF4444", 0.3)
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(8)
                    Text { text: "󰅙 Contrast Issue (" + a11yCardCol.currentRatio.toFixed(2) + ":1 < 4.5:1)"; color: "#EF4444"; font.pixelSize: Style.space(8); font.bold: true }
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
                      Text { text: "WCAG: " + a11yCardCol.currentRatio.toFixed(2) + ":1"; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                      Rectangle {
                        height: Style.space(16); radius: Style.space(3); width: Style.space(44)
                        color: a11yCardCol.currentRatio >= 4.5 ? "#10B981" : "#EF4444"
                        Text { text: a11yCardCol.currentRatio >= 4.5 ? "AA Pass" : "AA Fail"; color: "#fff"; font.pixelSize: Style.space(6); font.bold: true; anchors.centerIn: parent }
                      }
                    }
                  }

                  Rectangle {
                    width: (parent.width - Style.space(8)) / 2; height: Style.space(32); radius: Style.space(5)
                    color: Util.alpha(root.fg, 0.05)
                    Row {
                      anchors.centerIn: parent; spacing: Style.space(6)
                      Text { text: "APCA: " + Math.abs(a11yCardCol.currentApca).toFixed(1); color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                      Text { text: "Min: " + ColorStudio.calculateMinFontSize(a11yCardCol.currentRatio, false) + "px"; color: Util.alpha(root.fg, 0.6); font.pixelSize: Style.space(7) }
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
                    id: stdBgDelegate
                    required property var modelData
                    width: (parent.width - Style.space(18)) / 4; height: Style.space(42); radius: Style.space(5)
                    color: stdBgDelegate.modelData.hex; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Column {
                      anchors.centerIn: parent; spacing: 1
                      Text { text: stdBgDelegate.modelData.name; color: root.activeColorHex; font.pixelSize: Style.space(7); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: stdBgDelegate.modelData.ratio.toFixed(2) + ":1"; color: root.activeColorHex; font.pixelSize: Style.space(8); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: stdBgDelegate.modelData.passAA ? "✓ AA" : "✕ Fail"; color: stdBgDelegate.modelData.passAA ? "#10B981" : "#EF4444"; font.pixelSize: Style.space(6); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
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
                    id: blindnessDelegate
                    required property var modelData
                    width: (parent.width - Style.space(6)) / 2; height: Style.space(38); radius: Style.space(5)
                    color: Util.alpha(root.fg, 0.04); border.width: 1; border.color: Util.alpha(root.fg, 0.08)
                    Row {
                      anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                      Rectangle { width: Style.space(26); height: Style.space(26); radius: Style.space(4); color: blindnessDelegate.modelData.hex; border.width: 1; border.color: Util.alpha(root.fg, 0.2) }
                      Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: blindnessDelegate.modelData.label; color: root.fg; font.pixelSize: Style.space(8); font.bold: true }
                        Text { text: blindnessDelegate.modelData.hex; color: Util.alpha(root.fg, 0.5); font.family: "monospace"; font.pixelSize: Style.space(7) }
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
                  id: gradStopDelegate
                  required property var modelData
                  required property int index
                  width: parent.width; height: Style.space(32); radius: Style.space(5)
                  color: Util.alpha(root.fg, 0.03); border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                  Row {
                    anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                    Rectangle {
                      width: Style.space(20); height: Style.space(20); radius: Style.space(3)
                      color: gradStopDelegate.modelData.color; border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    }
                    Text { text: gradStopDelegate.modelData.color; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: gradStopDelegate.modelData.position + "%"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }

                    Item { Layout.fillWidth: true; width: parent.width - Style.space(200) }

                    // Position adjust buttons
                    Rectangle {
                      width: Style.space(18); height: Style.space(18); radius: Style.space(2); color: Util.alpha(root.fg, 0.08)
                      Text { text: "◀"; color: root.fg; font.pixelSize: Style.space(6); anchors.centerIn: parent }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var stops = root.gradientStops.slice()
                          stops[gradStopDelegate.index].position = Math.max(0, stops[gradStopDelegate.index].position - 5)
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
                          stops[gradStopDelegate.index].position = Math.min(100, stops[gradStopDelegate.index].position + 5)
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
                          stops.splice(gradStopDelegate.index, 1)
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
                    id: gradPresetDelegate
                    required property var modelData
                    width: (parent.width - Style.space(12)) / 3; height: Style.space(30); radius: Style.space(4)
                    color: gradPresetDelegate.modelData.colors[0]
                    border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                    Text {
                      text: gradPresetDelegate.modelData.name
                      color: "#fff"; font.pixelSize: Style.space(8); font.bold: true
                      anchors.centerIn: parent
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var preset = gradPresetDelegate.modelData.colors
                        var newStops = []
                        for (var i = 0; i < preset.length; i++) {
                          newStops.push({ color: preset[i], position: Math.round(i * (100 / (preset.length - 1))) })
                        }
                        root.gradientStops = newStops
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
                    onTextEdited: root.colorImportText = text
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
                id: savedPalDelegate
                required property var modelData
                width: parent.width; height: Style.space(82); radius: Style.space(6)
                color: Util.alpha(root.fg, 0.03); border.width: 1; border.color: Util.alpha(root.fg, 0.07)

                Column {
                  anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)

                  Row {
                    width: parent.width
                    Column {
                      Text { text: savedPalDelegate.modelData.name; color: root.fg; font.pixelSize: Style.space(9); font.bold: true }
                      Text {
                        text: (savedPalDelegate.modelData.colors ? savedPalDelegate.modelData.colors.length : 0) + " colors • " + new Date(savedPalDelegate.modelData.createdAt).toLocaleDateString()
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
                          onClicked: root.copyText(ColorStudio.exportPaletteAsJSON(savedPalDelegate.modelData.colors))
                        }
                      }
                      Rectangle {
                        width: Style.space(22); height: Style.space(22); radius: Style.space(3); color: Util.alpha("#EF4444", 0.12)
                        Text { text: "✕"; color: "#EF4444"; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.deleteSavedPalette(savedPalDelegate.modelData.id)
                        }
                      }
                    }
                  }

                  // Swatches Row
                  Row {
                    width: parent.width; height: Style.space(24); spacing: Style.space(3)
                    Repeater {
                      model: savedPalDelegate.modelData.colors || []
                      Rectangle {
                        id: savedPalSwatchDelegate
                        required property string modelData
                        width: (parent.width - (savedPalDelegate.modelData.colors.length - 1) * Style.space(3)) / Math.max(1, savedPalDelegate.modelData.colors.length)
                        height: parent.height; radius: Style.space(3); color: savedPalSwatchDelegate.modelData
                        border.width: 1; border.color: Util.alpha(root.fg, 0.2)
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: { root.selectColor(savedPalSwatchDelegate.modelData); root.copyText(savedPalSwatchDelegate.modelData) }
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
            required property string imagePaletteStr
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
            required property int copyCount
            required property string sourceApp
            required property string sourceTitle
            required property int revisionCount

            readonly property bool isSelected: root.selectedIndex === index
            readonly property bool isBulkChecked: root.isBulkSelected(cardItem.historyIndex)
            readonly property bool isHovered: cardMouse.containsMouse || trailingControls.isControlsHovered || (root.activeMenuClipIndex === cardItem.index)
            readonly property bool showActions: !root.settingsClipActionsOnHover || isHovered

            width: list.width - Style.space(6)
            height: kind === "code" ? Style.space(78) : Style.space(62)
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
                if (imageEditorModal && imageEditorModal.visible) return
                if (colorPickerModal && colorPickerModal.visible) return
                if (root.settingsOpen) return
                root.selectedIndex = parent.index
                if (root.bulkMode && cardItem.itemType === "history") {
                  root.toggleBulkSelect(cardItem.historyIndex)
                } else {
                  root.pasteRow(displayModel.get(parent.index))
                }
              }
            }

            // 1. Left Group: Bulk Checkbox + Swatch / Thumbnail
            Row {
              id: leftGroup
              anchors.left: parent.left
              anchors.leftMargin: (cardItem.isSelected || cardItem.isBulkChecked) ? Style.space(12) : Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
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

                // QR Detected Badge on Image Preview
                Rectangle {
                  visible: cardItem.entryType === "image" && cardItem.isQr
                  anchors.left: parent.left; anchors.top: parent.top
                  anchors.margins: Style.space(3)
                  width: Style.space(16); height: Style.space(16)
                  radius: Style.space(3)
                  color: Util.alpha("#000000", 0.75)
                  border.width: 1; border.color: Util.alpha(Color.accent, 0.7)
                  Text {
                    text: "󰄲"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(8.5)
                    anchors.centerIn: parent
                  }
                }

                // Click image to zoom / inspect
                MouseArea {
                  anchors.fill: parent
                  enabled: cardItem.entryType === "image"
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openImageZoom(cardItem.path)
                }
              }
            }

            // 2. Compact Trailing Controls Container (Collapsible Width on Hover)
            Item {
              id: trailingControls
              anchors.right: parent.right
              anchors.rightMargin: cardItem.showActions ? Style.space(8) : 0
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              width: cardItem.showActions ? trailingControlsRow.implicitWidth : 0
              clip: true

              opacity: cardItem.showActions ? 1.0 : 0.0
              visible: cardItem.showActions || opacity > 0.001 || width > 0
              readonly property bool isControlsHovered: trailingControlsRow.isControlsHovered

              Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
              }
              Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
              }
              Behavior on anchors.rightMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
              }

              Row {
                id: trailingControlsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                readonly property bool isControlsHovered: urlMouse.containsMouse || ocrMouse.containsMouse || qrDecMouse.containsMouse || qrMouse.containsMouse || tfMouse.containsMouse || diffMouse.containsMouse || copyMouse.containsMouse || menuMouse.containsMouse

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

                // Quick QR Decode Tool (for image clips)
                Rectangle {
                  visible: cardItem.entryType === "image"
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: cardItem.isQr ? Util.alpha(Color.accent, 0.25) : (qrDecMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08))
                  border.width: 1; border.color: cardItem.isQr ? Color.accent : (qrDecMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1))
                  Text {
                    text: "󰄳"
                    color: cardItem.isQr ? Color.accent : (qrDecMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg))
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: qrDecMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openQrDecoder(cardItem.path, cardItem.qrText || "")
                  }
                  PanelToolTip {
                    visible: qrDecMouse.containsMouse
                    text: cardItem.isQr ? "Decode QR Code (Detected)" : "Scan / Decode QR Code"
                  }
                }

                // Quick Share Data / QR Code Generator (for text / link / file clips)
                Rectangle {
                  visible: (cardItem.entryType === "text" || cardItem.entryType === "file") && (cardItem.fullText !== "" || cardItem.filePath !== "")
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: qrMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08)
                  border.width: 1; border.color: qrMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)
                  Text {
                    text: "󰒗"
                    color: qrMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: qrMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var p = cardItem.filePath || cardItem.fullText
                      if (cardItem.entryType === "file" || (p.startsWith("/") && p.indexOf("\n") === -1)) {
                        qrCodeModal.openFileShare(p)
                      } else {
                        qrCodeModal.open(cardItem.fullText)
                      }
                    }
                  }
                  PanelToolTip {
                    visible: qrMouse.containsMouse
                    text: (cardItem.entryType === "file" || (cardItem.fullText.startsWith("/") && cardItem.fullText.indexOf("\n") === -1))
                          ? "Share file via QR Code"
                          : "Share via QR Code"
                  }
                }

                // Quick Text Transformers (for text clips)
                Rectangle {
                  visible: cardItem.entryType === "text" && cardItem.fullText !== ""
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: tfMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08)
                  border.width: 1; border.color: tfMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)
                  Text {
                    text: "󰏫"
                    color: tfMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: tfMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: transformModal.open(cardItem.fullText, cardItem.historyIndex)
                  }
                }

                // Quick Revision Diff (for clips with revisions)
                Rectangle {
                  visible: cardItem.revisionCount > 0
                  width: Style.space(28); height: Style.space(28); radius: Style.space(5)
                  color: diffMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.08)
                  border.width: 1; border.color: diffMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)
                  Text {
                    text: "󰦪"
                    color: diffMouse.containsMouse ? Color.accent : (cardItem.isSelected ? root.selFg : root.fg)
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    anchors.centerIn: parent
                  }
                  MouseArea {
                    id: diffMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (cardItem.historyIndex >= 0) {
                        var it = root.history[cardItem.historyIndex]
                        if (it && it.revisions && it.revisions.length > 0) {
                          diffModal.open(cardItem.historyIndex, it.text, it.revisions)
                        }
                      }
                    }
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

            // 3. Middle Column: Metadata & Content Details (Dynamically fills remaining space)
            Column {
              id: midContentCol
              anchors.left: leftGroup.right
              anchors.leftMargin: Style.space(10)
              anchors.right: trailingControls.left
              anchors.rightMargin: cardItem.showActions ? Style.space(10) : Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              clip: true

              Behavior on anchors.rightMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
              }

              // Meta Row (Index badge, Pin, Tag, Time Ago)
              Row {
                width: parent.width
                spacing: Style.space(6)
                clip: true

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

                // Smart Bump Copy Counter Badge (e.g. 󰑖 ×3)
                Rectangle {
                  visible: cardItem.copyCount > 1
                  height: Style.space(14)
                  width: copyBadgeRow.implicitWidth + Style.space(8)
                  radius: Style.space(3)
                  color: Util.alpha(Color.accent, 0.16)
                  border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
                  Row {
                    id: copyBadgeRow
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    Text { text: "󰑖"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(7.5) }
                    Text { text: "×" + cardItem.copyCount; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true }
                  }
                }

                // Revision Stacking Badge (e.g. 󰦪 2 revs)
                Rectangle {
                  visible: cardItem.revisionCount > 0
                  height: Style.space(14)
                  width: revBadgeRow.implicitWidth + Style.space(8)
                  radius: Style.space(3)
                  color: revBadgeMouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.accent, 0.15)
                  border.width: 1; border.color: Util.alpha(Color.accent, 0.4)
                  Row {
                    id: revBadgeRow
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    Text { text: "󰦪"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(7.5) }
                    Text { text: cardItem.revisionCount + (cardItem.revisionCount === 1 ? " rev" : " revs"); color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true }
                  }
                  MouseArea {
                    id: revBadgeMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (cardItem.historyIndex >= 0) {
                        var it = root.history[cardItem.historyIndex]
                        if (it && it.revisions && it.revisions.length > 0) {
                          diffModal.open(cardItem.historyIndex, it.text, it.revisions)
                        }
                      }
                    }
                  }
                }

                // App-Aware Attribution Badge (e.g. 󰨞 Code, 󰞷 Kitty)
                Rectangle {
                  visible: cardItem.sourceApp !== ""
                  height: Style.space(14)
                  width: appBadgeRow.implicitWidth + Style.space(8)
                  radius: Style.space(3)
                  color: appBadgeMouse.containsMouse ? Util.alpha(root.fg, 0.16) : Util.alpha(root.fg, 0.08)
                  border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                  Row {
                    id: appBadgeRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text {
                      text: root.getAppIcon(cardItem.sourceApp)
                      color: Util.alpha(root.fg, 0.8)
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(8)
                    }
                    Text {
                      text: root.formatAppName(cardItem.sourceApp)
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                    }
                  }
                  MouseArea {
                    id: appBadgeMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.filterText = "app:" + cardItem.sourceApp
                      root.rebuildDisplay()
                    }
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

              // Preview Content (for text clips)
              Text {
                visible: cardItem.entryType !== "image"
                width: parent.width
                text: cardItem.previewText
                color: cardItem.isSelected ? root.selFg : Util.alpha(root.fg, 0.9)
                font.family: cardItem.kind === "code" ? "monospace" : root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                maximumLineCount: cardItem.kind === "code" ? 2 : 1
                wrapMode: Text.WrapAnywhere
              }

              // Extracted Color Palette (for image / screenshot clips)
              Row {
                visible: cardItem.entryType === "image"
                spacing: Style.space(6)
                anchors.left: parent.left

                property var colorArray: {
                  var s = cardItem.imagePaletteStr || ""
                  if (s.length > 0) {
                    return s.split(",").filter(function(c) { return c.length > 0 })
                  }
                  if (cardItem.path) {
                    var cached = root.imagePalettes[cardItem.path]
                    if (cached && Array.isArray(cached) && cached.length > 0) return cached.slice(0, root.settingsImagePaletteLimit)
                  }
                  return []
                }

                Text {
                  visible: parent.colorArray.length === 0
                  text: "󰏘 Extracting colors..."
                  color: Util.alpha(root.fg, 0.35)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                  model: parent.colorArray

                  Rectangle {
                    id: paletteDot
                    required property string modelData
                    required property int index
                    width: Style.space(16)
                    height: Style.space(16)
                    radius: Style.space(8)
                    color: modelData
                    border.width: dotMouse.containsMouse ? 2 : 1
                    border.color: dotMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.3)
                    scale: dotMouse.containsMouse ? 1.25 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                      visible: root.lastCopiedColorHex === paletteDot.modelData
                      text: "✓"
                      color: ColorStudio.getContrastRatio(paletteDot.modelData, "#FFFFFF") > 3.0 ? "#FFFFFF" : "#000000"
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      anchors.centerIn: parent
                    }

                    MouseArea {
                      id: dotMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      acceptedButtons: Qt.LeftButton | Qt.RightButton
                      onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                          root.selectColor(paletteDot.modelData)
                          root.activeTab = 3
                        } else {
                          root.copyText(paletteDot.modelData)
                          root.lastCopiedColorHex = paletteDot.modelData
                          copiedTimer.restart()
                        }
                      }
                    }

                    PanelToolTip {
                      visible: dotMouse.containsMouse
                      text: paletteDot.modelData + " (Click: Copy • Right-click: Inspect)"
                    }
                  }
                }
              }

              // Stats (lines / characters)
              Text {
                visible: cardItem.entryType === "text" && cardItem.fullText.length > 0
                text: cardItem.lineCount + " lines • " + cardItem.charCount + " chars"
                color: Util.alpha(root.fg, 0.4)
                font.family: root.fontFamily; font.pixelSize: Style.space(9)
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

            // 5. Transform Text Case & Encoding
            Rectangle {
              visible: menuDropdownCard.isTextClip && menuDropdownCard.isHistoryClip
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: tfItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰏫"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Text Transformers…"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
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

            // 6. Share via QR Code
            Rectangle {
              visible: (menuDropdownCard.isTextClip || (menuDropdownCard.clipRow && menuDropdownCard.clipRow.entryType === "file")) && menuDropdownCard.clipRow && (menuDropdownCard.clipRow.fullText !== "" || menuDropdownCard.clipRow.filePath !== "")
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: qrItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰒗"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Share via QR Code…"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: qrItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var row = menuDropdownCard.clipRow
                  root.activeMenuClipIndex = -1
                  if (row) {
                    var p = row.filePath || row.fullText || ""
                    if (row.entryType === "file" || (p.startsWith("/") && p.indexOf("\n") === -1)) {
                      qrCodeModal.openFileShare(p)
                    } else if (row.fullText !== "") {
                      root.showQrModal(row.fullText)
                    }
                  }
                }
              }
            }

            // 6b. Revision History & Diff
            Rectangle {
              visible: menuDropdownCard.clipRow && menuDropdownCard.clipRow.revisionCount > 0
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: diffItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰦪"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Revision History & Diff…"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea {
                id: diffItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var row = menuDropdownCard.clipRow
                  root.activeMenuClipIndex = -1
                  if (row && row.historyIndex >= 0) {
                    var it = root.history[row.historyIndex]
                    if (it && it.revisions && it.revisions.length > 0) {
                      diffModal.open(row.historyIndex, it.text, it.revisions)
                    }
                  }
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

            // Image: View & Edit
            Rectangle {
              visible: menuDropdownCard.clipRow && menuDropdownCard.clipRow.entryType === "image"
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: zoomItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰏫"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "View & Edit Image"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
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

            // Image: Decode QR Code
            Rectangle {
              visible: menuDropdownCard.clipRow && menuDropdownCard.clipRow.entryType === "image"
              width: parent.width; height: Style.space(28); radius: Style.space(5)
              color: qrDecItemMouse.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"
              Row {
                anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text { text: "󰄳"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text {
                  text: (menuDropdownCard.clipRow && menuDropdownCard.clipRow.isQr) ? "Decode QR Code (Detected)" : "Decode QR Code"
                  color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: qrDecItemMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var p = menuDropdownCard.clipRow ? menuDropdownCard.clipRow.path : ""
                  var qt = menuDropdownCard.clipRow ? (menuDropdownCard.clipRow.qrText || "") : ""
                  root.activeMenuClipIndex = -1
                  if (p) root.openQrDecoder(p, qt)
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
                onTextEdited: root.clipEditContent = text
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
                text: root.snippetEditTitle; onTextEdited: root.snippetEditTitle = text
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
                text: root.snippetEditLang; onTextEdited: root.snippetEditLang = text
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
                text: root.snippetEditFolder; onTextEdited: root.snippetEditFolder = text
              }
            }
          }

          // Dynamic Variable Insert Helpers
          Row {
            spacing: Style.space(6)
            Text {
              text: "Insert Variable:"
              color: Util.alpha(root.fg, 0.6)
              font.family: root.fontFamily
              font.pixelSize: Style.space(9)
              anchors.verticalCenter: parent.verticalCenter
            }
            Repeater {
              model: ["{{date}}", "{{time}}", "{{datetime}}", "{{clipboard}}", "{{uuid}}"]
              Rectangle {
                required property string modelData
                height: Style.space(20)
                width: varPillTxt.implicitWidth + Style.space(12)
                radius: Style.space(4)
                color: Util.alpha(Color.accent, 0.15)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.4)

                Text {
                  id: varPillTxt
                  text: parent.modelData
                  color: Color.accent
                  font.family: "monospace"
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  anchors.centerIn: parent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    edBody.insert(edBody.cursorPosition, parent.modelData)
                    root.snippetEditContent = edBody.text
                  }
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: parent.height - Style.space(155)
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
                text: root.snippetEditContent; onTextEdited: root.snippetEditContent = text
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
    // NOTE: IMAGE VIEWING & ZOOMING UNIFIED INTO ImageEditorModal
    // ==========================================


    // ==========================================
    // MODAL: SETTINGS & PRIVACY PREFERENCES
    // ==========================================
    SettingsModal {
      id: settingsModal
      visible: root.settingsOpen
      rootPanel: root
      settingsOpen: root.settingsOpen
      settingsActiveSection: root.settingsActiveSection
      settingsMaxClips: root.settingsMaxClips
      settingsRetainDays: root.settingsRetainDays
      settingsIgnoreSensitive: root.settingsIgnoreSensitive
      settingsImagePaletteLimit: root.settingsImagePaletteLimit
      settingsToggleShortcut: root.settingsToggleShortcut
      settingsPasteModifiers: root.settingsPasteModifiers
      settingsEnableQuickPaste: root.settingsEnableQuickPaste
      settingsClipActionsOnHover: root.settingsClipActionsOnHover
      automationRules: root.automationRules
      templates: root.templates
      history: root.history
      snippets: root.snippets
      incognito: root.incognito
      fg: root.fg
      fontFamily: root.fontFamily

      settingsSmartBump: root.settingsSmartBump
      settingsRevisionStacking: root.settingsRevisionStacking
      settingsAppBlacklist: root.settingsAppBlacklist
      onSettingsOpenChanged: root.settingsOpen = settingsOpen
      onSettingsActiveSectionChanged: root.settingsActiveSection = settingsActiveSection
      onSettingsMaxClipsChanged: root.settingsMaxClips = settingsMaxClips
      onSettingsRetainDaysChanged: root.settingsRetainDays = settingsRetainDays
      onSettingsIgnoreSensitiveChanged: root.settingsIgnoreSensitive = settingsIgnoreSensitive
      onSettingsImagePaletteLimitChanged: root.settingsImagePaletteLimit = settingsImagePaletteLimit
      onSettingsToggleShortcutChanged: root.settingsToggleShortcut = settingsToggleShortcut
      onSettingsPasteModifiersChanged: root.settingsPasteModifiers = settingsPasteModifiers
      onSettingsEnableQuickPasteChanged: root.settingsEnableQuickPaste = settingsEnableQuickPaste
      onSettingsClipActionsOnHoverChanged: root.settingsClipActionsOnHover = settingsClipActionsOnHover
      onSettingsSmartBumpChanged: root.settingsSmartBump = settingsSmartBump
      onSettingsRevisionStackingChanged: root.settingsRevisionStacking = settingsRevisionStacking
      onSettingsAppBlacklistChanged: root.settingsAppBlacklist = settingsAppBlacklist
      onAutomationRulesChanged: root.automationRules = automationRules
      onTemplatesChanged: root.templates = templates
      onClosed: root.settingsOpen = false
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

          Item {
            width: parent.width
            height: Style.space(28)
            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "󰋚 Manage Tags"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(24); height: Style.space(24); radius: Style.space(4)
              color: Util.alpha(root.fg, 0.08)
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
                onTextEdited: root.tagModalInputText = text
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

    // ==========================================
    // MODAL: SNIPPET TEMPLATE PICKER
    // ==========================================
    Rectangle {
      id: snippetTemplatePickerModal
      visible: root.snippetTemplatePickerOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 95

      Rectangle {
        width: parent.width * 0.88
        height: parent.height * 0.80
        radius: Style.cornerRadius
        color: root.bg
        border.width: 1
        border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(12)

          // Header
          Item {
            width: parent.width
            height: Style.space(32)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)
              Rectangle {
                width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                color: Util.alpha(Color.accent, 0.2)
                Text { text: "📑"; font.pixelSize: Style.font.body; anchors.centerIn: parent }
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Text { text: "Templates Library"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: "Instantiate templates or copy directly with expanded variables"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.font.caption }
              }
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(28); height: Style.space(28); radius: Style.space(6)
              color: Util.alpha(root.fg, 0.08)
              Text { text: "✕"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.snippetTemplatePickerOpen = false }
            }
          }

          // Template Cards Scroll Area
          Flickable {
            width: parent.width
            height: parent.height - Style.space(80)
            contentWidth: width
            contentHeight: tplPickerListCol.implicitHeight + Style.space(20)
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
              id: tplPickerListCol
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: root.templates
                Rectangle {
                  id: tplPickerRowDelegate
                  required property var modelData
                  readonly property var tplPickerItem: modelData || {}
                  width: parent.width
                  height: Style.space(64)
                  radius: Style.space(6)
                  color: Util.alpha(root.fg, 0.04)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Item {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)

                    Column {
                      anchors.left: parent.left
                      anchors.right: tplPickerBtnRow.left
                      anchors.rightMargin: Style.space(12)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 3
                      Row {
                        spacing: Style.space(6)
                        Text {
                          text: tplPickerRowDelegate.tplPickerItem.name || ""
                          color: root.fg
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(10)
                          font.bold: true
                        }
                        Rectangle {
                          height: Style.space(14); width: tplBadgeTxt2.implicitWidth + Style.space(6); radius: Style.space(3)
                          color: Util.alpha(Color.accent, 0.15)
                          anchors.verticalCenter: parent.verticalCenter
                          Text {
                            id: tplBadgeTxt2
                            text: tplPickerRowDelegate.tplPickerItem.language || "text"
                            color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(7); font.bold: true
                            anchors.centerIn: parent
                          }
                        }
                      }
                      Text {
                        text: (tplPickerRowDelegate.tplPickerItem.content || "").replace(/\n/g, " ")
                        color: Util.alpha(root.fg, 0.5)
                        font.family: "monospace"
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    Row {
                      id: tplPickerBtnRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      // Paste Direct Button
                      Rectangle {
                        height: Style.space(26); width: pasteTplTxt.implicitWidth + Style.space(12); radius: Style.space(4)
                        color: Color.accent
                        Row {
                          id: pasteTplTxt
                          anchors.centerIn: parent; spacing: Style.space(3)
                          Text { text: "↵"; color: "#fff"; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Paste"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            var t = tplPickerRowDelegate.tplPickerItem
                            root.snippetTemplatePickerOpen = false
                            if (TemplateEngine.hasCustomVariables(t.content)) {
                              root.openVariablePrompt(t.name, t.content, true)
                            } else {
                              var exp = TemplateEngine.expand(t.content, {}, root.getLatestClipboardText())
                              root.close()
                              Quickshell.execDetached(["bash", "-c", "printf '%s' " + Util.shellQuote(exp) + " | wl-copy && sleep 0.15 && wtype -M shift -k Insert -m shift"])
                            }
                          }
                        }
                      }

                      // Copy Expanded Button
                      Rectangle {
                        height: Style.space(26); width: copyExpTxt.implicitWidth + Style.space(12); radius: Style.space(4)
                        color: Util.alpha(Color.accent, 0.15); border.width: 1; border.color: Color.accent
                        Row {
                          id: copyExpTxt
                          anchors.centerIn: parent; spacing: Style.space(3)
                          Text { text: "󰆏"; color: Color.accent; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Copy"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            var t = tplPickerRowDelegate.tplPickerItem
                            root.snippetTemplatePickerOpen = false
                            if (TemplateEngine.hasCustomVariables(t.content)) {
                              root.openVariablePrompt(t.name, t.content, false)
                            } else {
                              var exp2 = TemplateEngine.expand(t.content || "", {}, root.getLatestClipboardText())
                              root.copyText(exp2)
                            }
                          }
                        }
                      }

                      // Use as New Snippet
                      Rectangle {
                        height: Style.space(26); width: useTplTxt.implicitWidth + Style.space(10); radius: Style.space(4)
                        color: Util.alpha(root.fg, 0.08)
                        Row {
                          id: useTplTxt
                          anchors.centerIn: parent; spacing: Style.space(3)
                          Text { text: "+"; color: root.fg; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Snippet"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            var t = tplPickerRowDelegate.tplPickerItem
                            root.snippetTemplatePickerOpen = false
                            textEditorModal.openSnippet(-1, t.name || "", t.content || "", t.language || "markdown", "Templates", "")
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
      }
    }

    // ==========================================
    // MODAL: DYNAMIC TEMPLATE VARIABLE FILL
    // ==========================================
    Rectangle {
      id: variablePromptModal
      visible: root.varPromptOpen
      anchors.fill: parent
      color: root.scrimCol
      radius: Style.cornerRadius
      z: 65

      Rectangle {
        width: Math.min(parent.width * 0.94, Style.space(520))
        height: Math.min(parent.height * 0.88, Style.space(440))
        radius: Style.cornerRadius
        color: root.bg
        border.width: 1
        border.color: root.borderCol
        anchors.centerIn: parent

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          // Header
          Item {
            width: parent.width
            height: Style.space(30)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                text: "📑"
                font.pixelSize: Style.space(14)
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Row {
                  spacing: Style.space(6)
                  Text {
                    text: "Fill Template Variables"
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }
                  Text {
                    visible: root.varPromptTitle !== ""
                    text: "• " + root.varPromptTitle
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(10)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Text {
                  text: "Provide values for placeholders below to generate custom output"
                  color: Util.alpha(root.fg, 0.5)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                }
              }
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.space(5)
              color: Util.alpha(root.fg, 0.08)
              border.width: 1
              border.color: Util.alpha(root.fg, 0.12)

              Text {
                text: "✕"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.centerIn: parent
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.varPromptOpen = false
              }
            }
          }

          // Content area: split into left (variable inputs) and right (live preview)
          Row {
            width: parent.width
            height: parent.height - Style.space(85)
            spacing: Style.space(12)

            // Left Side: Variables list
            Rectangle {
              width: parent.width * 0.48
              height: parent.height
              radius: Style.space(6)
              color: Util.alpha(root.fg, 0.03)
              border.width: 1
              border.color: Util.alpha(root.fg, 0.08)

              Flickable {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                contentWidth: width
                contentHeight: varCol.implicitHeight
                clip: true

                Column {
                  id: varCol
                  width: parent.width
                  spacing: Style.space(8)

                  Repeater {
                    model: root.varPromptList
                    Column {
                      id: varFieldItem
                      required property string modelData
                      width: parent.width
                      spacing: Style.space(3)

                      Row {
                        spacing: Style.space(4)
                        Text {
                          text: "{{" + varFieldItem.modelData + "}}"
                          color: Color.accent
                          font.family: "monospace"
                          font.pixelSize: Style.space(9)
                          font.bold: true
                        }
                      }

                      Rectangle {
                        width: parent.width
                        height: Style.space(28)
                        radius: Style.space(4)
                        color: Util.alpha(root.fg, 0.06)
                        border.width: 1
                        border.color: varInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                        TextInput {
                          id: varInput
                          anchors.fill: parent
                          anchors.margins: Style.space(4)
                          color: root.fg
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(9)
                          text: root.varPromptValues[varFieldItem.modelData] || ""
                          onTextEdited: root.setVarPromptValue(varFieldItem.modelData, text)

                          Text {
                            visible: varInput.text === "" && !varInput.activeFocus
                            text: "Value for " + varFieldItem.modelData + "..."
                            color: Util.alpha(root.fg, 0.35)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Right Side: Live Output Preview
            Rectangle {
              width: parent.width - (parent.width * 0.48) - Style.space(12)
              height: parent.height
              radius: Style.space(6)
              color: Util.alpha(root.fg, 0.03)
              border.width: 1
              border.color: Util.alpha(root.fg, 0.08)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                Row {
                  spacing: Style.space(6)
                  Text {
                    text: "󰆏"
                    color: Color.accent
                    font.pixelSize: Style.space(9)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: "Live Preview"
                    color: Util.alpha(root.fg, 0.7)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Rectangle {
                  width: parent.width
                  height: parent.height - Style.space(22)
                  radius: Style.space(4)
                  color: Util.alpha(root.fg, 0.04)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Flickable {
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    contentWidth: width
                    contentHeight: previewText.implicitHeight
                    clip: true

                    Text {
                      id: previewText
                      width: parent.width
                      text: root.varPromptPreview
                      color: root.fg
                      font.family: "monospace"
                      font.pixelSize: Style.space(8)
                      wrapMode: Text.Wrap
                    }
                  }
                }
              }
            }
          }

          // Footer Actions
          Item {
            width: parent.width
            height: Style.space(32)

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              // Cancel
              Rectangle {
                width: Style.space(70)
                height: Style.space(28)
                radius: Style.space(4)
                color: Util.alpha(root.fg, 0.08)

                Text {
                  text: "Cancel"
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.centerIn: parent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.varPromptOpen = false
                }
              }

              // Copy Expanded
              Rectangle {
                height: Style.space(28)
                width: copyBtnTxt.implicitWidth + Style.space(16)
                radius: Style.space(4)
                color: Util.alpha(Color.accent, 0.15)
                border.width: 1
                border.color: Color.accent

                Row {
                  id: copyBtnTxt
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: "󰆏"; color: Color.accent; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                  Text { text: "Copy"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.finishVariablePrompt(false)
                }
              }

              // Paste Direct
              Rectangle {
                height: Style.space(28)
                width: pasteBtnTxt.implicitWidth + Style.space(18)
                radius: Style.space(4)
                color: Color.accent

                Row {
                  id: pasteBtnTxt
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: "↵"; color: "#fff"; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  Text { text: "Paste"; color: "#fff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.finishVariablePrompt(true)
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // MODAL: SCREENSHOT & IMAGE ANNOTATION STUDIO
    // ==========================================
    ImageEditorModal {
      id: imageEditorModal
      onClosed: { if (root.lastActiveModal === "image") root.lastActiveModal = "" }
      onSavedToClipboard: function(path) {
        root.addClipboardEntry({
          type: "image",
          path: path,
          mime: "image/png",
          pinned: false,
          favorite: false,
          capturedAt: new Date().toISOString(),
          tags: ["annotated"]
        })
      }
      onSavedToHistory: function(path) {
        root.addClipboardEntry({
          type: "image",
          path: path,
          mime: "image/png",
          pinned: false,
          favorite: false,
          capturedAt: new Date().toISOString(),
          tags: ["annotated"]
        })
      }
      onRunOcr: function(path) {
        root.runOcrOnImage(path)
      }
      onRequestQrDecode: function(path) {
        root.openQrDecoder(path)
      }
      onRequestScreenPick: function() {
        root.pickScreenColor()
      }
      onRequestColorPicker: function() {
        colorPickerModal.z = 120
        colorPickerModal.open(imageEditorModal.currentColor, root.clipboardItems)
      }
    }

    // ==========================================
    // MODAL: INTERACTIVE COLOR PICKER STUDIO
    // ==========================================
    ColorPickerModal {
      id: colorPickerModal
      onColorSelected: function(hex) {
        root.selectColor(hex)
        if (imageEditorModal && imageEditorModal.visible) {
          imageEditorModal.applyPickedColor(hex)
          imageEditorModal.showFeedback("Color set: " + hex)
        }
        if (textEditorModal && textEditorModal.visible) {
          textEditorModal.applyPickedColor(hex)
        }
        if (qrCodeModal && qrCodeModal.visible) {
          qrCodeModal.applyPickedColor(hex)
        }
      }
      onRequestScreenPick: function() {
        root.pickScreenColor()
      }
      onClosed: function() {
        colorPickerModal.z = 100
        if (imageEditorModal && imageEditorModal.visible) {
          imageEditorModal.activeColorTarget = "stroke"
        }
      }
    }

    // ==========================================
    // MODAL: MARKDOWN & RICH TEXT EDITOR STUDIO
    // ==========================================
    TextEditorModal {
      id: textEditorModal
      onClosed: { if (root.lastActiveModal === "text") root.lastActiveModal = "" }
      onRequestScreenPick: function() {
        root.pickScreenColor()
      }
      onRequestColorPicker: function() {
        colorPickerModal.z = 120
        colorPickerModal.open(textEditorModal.currentColor || "#EF4444", root.history)
      }
      onSavedClip: function(index, content) {
        if (index >= 0 && content !== undefined) {
          root.history = ClipboardHistory.updateEntryText(root.history, index, content)
          root.saveHistory()
          root.rebuildDisplay()
        }
      }
      onSavedSnippet: function(index, title, content, language, folder, tags) {
        if (index >= 0) {
          root.snippets = SnippetLib.updateSnippet(root.snippets, index, {
            title: title,
            content: content,
            language: language,
            folder: folder,
            tags: tags
          })
        } else {
          root.snippets = SnippetLib.addSnippet(root.snippets, {
            title: title || "Untitled",
            content: content,
            language: language,
            folder: folder,
            tags: tags
          })
        }
        root.saveSnippets()
        root.rebuildDisplay()
      }
      onSaveAsSnippetRequested: function(title, content, language) {
        root.snippets = SnippetLib.addSnippet(root.snippets, {
          title: title || "Untitled Snippet",
          content: content,
          language: language || "markdown"
        })
        root.saveSnippets()
        root.rebuildDisplay()
      }
      onCopiedToClipboard: function(content) {
        root.setSystemClipboard(content)
      }
    }

    // ==========================================
    // MODAL: QUICK TEXT TRANSFORMERS
    // ==========================================
    TransformModal {
      id: transformModal
      onClosed: { if (root.lastActiveModal === "transform") root.lastActiveModal = "" }
      onApplied: function(newText, clipIndex) {
        if (clipIndex >= 0) {
          root.history = ClipboardHistory.updateEntryText(root.history, clipIndex, newText)
          root.saveHistory()
          root.rebuildDisplay()
        }
      }
      onCopied: function(text) {
        root.setSystemClipboard(text)
      }
      onPasteRequested: function(text) {
        root.setSystemClipboard(text)
        root.pasteClipboard(text)
      }
    }

    // ==========================================
    // MODAL: QR CODE GENERATOR BRIDGE
    // ==========================================
    QRCodeModal {
      id: qrCodeModal
      fileShareAllowUpload: root.settingsQrAllowUpload
      fileShareAllowBeam: root.settingsQrAllowBeam
      onFileShareAllowUploadChanged: {
        root.settingsQrAllowUpload = qrCodeModal.fileShareAllowUpload
        root.saveSettings()
      }
      onFileShareAllowBeamChanged: {
        root.settingsQrAllowBeam = qrCodeModal.fileShareAllowBeam
        root.saveSettings()
      }
      onClosed: { if (root.lastActiveModal === "qr") root.lastActiveModal = "" }
      onCopiedText: function(text) {
        root.setSystemClipboard(text)
      }
      onRequestOcr: function(path) {
        root.runOcrOnImage(path)
      }
      onRequestScreenPick: function(target) {
        qrCodeModal.activeColorTarget = target
        root.pickScreenColor()
      }
      onRequestColorPicker: function(target, curCol) {
        qrCodeModal.activeColorTarget = target
        colorPickerModal.z = 130
        colorPickerModal.open(curCol || (target === "fg" ? qrCodeModal.qrFgColor : qrCodeModal.qrBgColor), root.history)
      }
    }

    // ==========================================
    // MODAL: REVISION DIFF VIEWER
    // ==========================================
    DiffModal {
      id: diffModal
      onClosed: { if (root.lastActiveModal === "diff") root.lastActiveModal = "" }
      onRestored: function(clipIndex, revIndex) {
        root.history = ClipboardHistory.restoreRevision(root.history, clipIndex, revIndex)
        root.saveHistory()
        root.rebuildDisplay()
      }
      onCopied: function(text) {
        root.setSystemClipboard(text)
      }
      onRevisionDeleted: function(clipIndex, revIndex) {
        root.history = ClipboardHistory.deleteRevision(root.history, clipIndex, revIndex)
        root.saveHistory()
        root.rebuildDisplay()
      }
    }
  }
}
}
