import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "lib/ClipboardHistory.js" as ClipboardHistory
import "lib/SnippetLibrary.js" as SnippetLib
import "lib/TemplateEngine.js" as TemplateEngine
import "lib/AutomationRules.js" as AutomationRules

Rectangle {
  id: root
  visible: false
  anchors.fill: parent
  color: Util.alpha(Color.popups.background || Color.background || "#1e1e2e", 0.98)
  radius: Style.cornerRadius
  z: 105
  clip: true

  // Parent connection
  property var rootPanel: null

  // Signals
  signal closed()
  signal requestSaveSettings()
  signal requestApplyRetentionClean()
  signal requestExportBackupJson()
  signal requestSyncKeybindingsWithNotify()
  signal requestToggleIncognito()
  signal requestSaveAutomations(var rules)
  signal requestSaveTemplates(var templates)
  signal requestSaveSnippets()
  signal requestRebuildDisplay()
  signal requestCopyText(string text)
  signal requestOpenVariablePrompt(string title, string tpl, bool autoPaste)

  // Appearance & Fonts
  property color fg: Color.popups.text || Color.text || "#cdd6f4"
  property string fontFamily: Style.fontFamily

  // State & Section
  property bool settingsOpen: visible
  property int settingsActiveSection: 0 // 0: Retention, 1: Privacy, 2: Automations, 3: Templates, 4: Shortcuts, 5: Backup
  property int settingsMaxClips: 500
  property int settingsRetainDays: 30
  property bool settingsIgnoreSensitive: true
  property int settingsImagePaletteLimit: 12
  property string settingsToggleShortcut: "SUPER + SHIFT + V"
  property string settingsPasteModifiers: "SUPER + CTRL + SHIFT"
  property bool settingsEnableQuickPaste: true
  property bool settingsClipActionsOnHover: true
  property bool settingsSmartBump: true
  property bool settingsRevisionStacking: true
  property var settingsAppBlacklist: []
  property string newBlacklistApp: ""
  property bool incognito: false

  // Automations & Regex Rules State
  property var automationRules: []
  property string ruleEditId: ""
  property string newRuleName: ""
  property string newRulePattern: ""
  property string newRuleAction: "tag"
  property string newRulePayload: ""
  property string testRuleSample: "https://example.com/checkout?utm_source=ad&utm_medium=cpc or #1234"
  property var testRuleResult: ({})

  // Dynamic Templates & Snippet Variables State
  property var templates: []
  property string tplEditId: ""
  property string tplEditName: ""
  property string tplEditLang: "markdown"
  property string tplEditContent: ""

  // Data lists
  property var history: []
  property var snippets: []

  // System Dependencies & Health State
  property string pluginDir: rootPanel ? rootPanel.pluginDir : (Quickshell.env("HOME") + "/.config/omarchy/plugins/reclip")
  property string installDepsScript: pluginDir + "/install-deps.sh"
  property var systemDependencies: []
  property bool isCheckingDeps: false
  property int installedDepsCount: 0
  property int totalDepsCount: 0
  property var missingPackagesList: []

  function checkDependencies() {
    isCheckingDeps = true
    depsCheckProc.running = true
  }

  function installMissingDependencies() {
    if (!missingPackagesList || missingPackagesList.length === 0) return
    var pkgs = missingPackagesList.join(" ")
    var cmd = "sudo pacman -S --needed " + pkgs
    var launcher = "omarchy-launch-floating-terminal-with-presentation"
    var fullCmd = launcher + " " + Util.shellQuote(cmd)
    Quickshell.execDetached(["sh", "-c", fullCmd])
    showFeedback("󰐥 Launched terminal to install " + missingPackagesList.length + " package(s)")
  }

  function copyInstallCommand() {
    var pkgs = missingPackagesList && missingPackagesList.length > 0 ? missingPackagesList.join(" ") : "wl-clipboard jq qrencode zbar imagemagick hyprpicker slurp grim wtype tesseract tesseract-data-eng libnotify python python-pillow perl util-linux"
    var cmd = "sudo pacman -S --needed " + pkgs
    root.requestCopyText(cmd)
    showFeedback("✓ Install command copied to clipboard")
  }

  Process {
    id: depsCheckProc
    command: ["bash", root.installDepsScript, "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isCheckingDeps = false
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var list = JSON.parse(raw)
          if (Array.isArray(list)) {
            root.systemDependencies = list
            var inst = 0
            var missing = []
            for (var i = 0; i < list.length; i++) {
              if (list[i].installed) {
                inst++
              } else {
                var p = String(list[i].package || "").split(" ")
                for (var j = 0; j < p.length; j++) {
                  if (p[j] && missing.indexOf(p[j]) === -1) {
                    missing.push(p[j])
                  }
                }
              }
            }
            root.installedDepsCount = inst
            root.totalDepsCount = list.length
            root.missingPackagesList = missing
          }
        } catch(e) {}
      }
    }
  }

  onSettingsOpenChanged: {
    if (!settingsOpen) closed()
    else checkDependencies()
  }

  // Delegated & Helper Functions
  function saveSettings() {
    if (rootPanel) {
      rootPanel.settingsMaxClips = root.settingsMaxClips
      rootPanel.settingsRetainDays = root.settingsRetainDays
      rootPanel.settingsIgnoreSensitive = root.settingsIgnoreSensitive
      rootPanel.settingsImagePaletteLimit = root.settingsImagePaletteLimit
      rootPanel.settingsToggleShortcut = root.settingsToggleShortcut
      rootPanel.settingsPasteModifiers = root.settingsPasteModifiers
      rootPanel.settingsEnableQuickPaste = root.settingsEnableQuickPaste
      rootPanel.settingsClipActionsOnHover = root.settingsClipActionsOnHover
      rootPanel.settingsSmartBump = root.settingsSmartBump
      rootPanel.settingsRevisionStacking = root.settingsRevisionStacking
      rootPanel.settingsAppBlacklist = root.settingsAppBlacklist
      if (rootPanel.saveSettings) rootPanel.saveSettings()
    } else {
      requestSaveSettings()
    }
  }

  function applyRetentionClean() {
    if (rootPanel && rootPanel.applyRetentionClean) rootPanel.applyRetentionClean()
    else requestApplyRetentionClean()
  }

  function exportBackupJson() {
    if (rootPanel && rootPanel.exportBackupJson) rootPanel.exportBackupJson()
    else requestExportBackupJson()
  }

  function syncKeybindingsWithNotify() {
    if (rootPanel && rootPanel.syncKeybindingsWithNotify) rootPanel.syncKeybindingsWithNotify()
    else requestSyncKeybindingsWithNotify()
  }

  function toggleIncognito() {
    if (rootPanel && rootPanel.toggleIncognito) rootPanel.toggleIncognito()
    else requestToggleIncognito()
  }

  function saveAutomations() {
    if (rootPanel) {
      rootPanel.automationRules = root.automationRules
      if (rootPanel.saveAutomations) rootPanel.saveAutomations()
    } else {
      requestSaveAutomations(root.automationRules)
    }
  }

  function saveTemplates() {
    if (rootPanel) {
      rootPanel.templates = root.templates
      if (rootPanel.saveTemplates) rootPanel.saveTemplates()
    } else {
      requestSaveTemplates(root.templates)
    }
  }

  function saveSnippets() {
    if (rootPanel && rootPanel.saveSnippets) rootPanel.saveSnippets()
    else requestSaveSnippets()
  }

  function rebuildDisplay() {
    if (rootPanel && rootPanel.rebuildDisplay) rootPanel.rebuildDisplay()
    else requestRebuildDisplay()
  }

  function copyText(text) {
    if (rootPanel && rootPanel.copyText) rootPanel.copyText(text)
    else requestCopyText(text)
  }

  function openVariablePrompt(title, tpl, autoPaste) {
    if (rootPanel && rootPanel.openVariablePrompt) rootPanel.openVariablePrompt(title, tpl, autoPaste)
    else requestOpenVariablePrompt(title, tpl, autoPaste)
  }

  function getLatestClipboardText() {
    if (rootPanel && rootPanel.getLatestClipboardText) return rootPanel.getLatestClipboardText()
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

  function close() {
    root.settingsOpen = false
    closed()
  }

      // Root MouseArea: Absorbs all clicks, drags, and wheel events so underlying views are 100% frozen
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: function(mouse) { mouse.accepted = true }
        onPressed: function(mouse) { mouse.accepted = true }
        onReleased: function(mouse) { mouse.accepted = true }
        onWheel: function(wheel) { wheel.accepted = true }
      }

      // -------------------------------------------------------------
      // TOP SECTION: Header & Segmented Pill Tabs
      // -------------------------------------------------------------
      Column {
        id: settingsHeaderCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)

        // Header Item (Hero header matching main page style)
        Item {
          width: parent.width
          height: Style.space(38)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(32); height: Style.space(32); radius: Style.space(8)
              color: Util.alpha(Color.accent, 0.15)
              border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
              Text { text: "󰒓"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.heading; anchors.centerIn: parent }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Text { text: "Settings & Preferences"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              Text { text: "Retention limits, privacy controls, shortcuts, and backup tools"; color: Util.alpha(root.fg, 0.55); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(30); height: Style.space(30); radius: Style.space(6)
            color: closeHdrMouse.containsMouse ? Util.alpha(root.fg, 0.15) : Util.alpha(root.fg, 0.08)
            border.width: 1; border.color: closeHdrMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.12)
            Text { text: "✕"; color: closeHdrMouse.containsMouse ? Color.accent : root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
            MouseArea {
              id: closeHdrMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.settingsOpen = false
            }
            PanelToolTip {
              visible: closeHdrMouse.containsMouse
              text: "Close Settings (Esc)"
            }
          }
        }

        // Segmented Pill Tab Bar (Exact pill style matching main page tabs)
        Rectangle {
          width: parent.width
          height: Style.space(32)
          radius: Style.space(8)
          color: Util.alpha(root.fg, 0.05)
          border.width: 1; border.color: Util.alpha(root.fg, 0.08)

          Row {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            spacing: Style.space(2)

            Repeater {
              model: [
                { id: 0, label: "Retention", icon: "📋" },
                { id: 1, label: "Privacy", icon: "🛡" },
                { id: 2, label: "Automations", icon: "⚡" },
                { id: 3, label: "Templates", icon: "📑" },
                { id: 4, label: "Shortcuts", icon: "⌨️" },
                { id: 5, label: "Backup", icon: "💾" },
                { id: 6, label: "System", icon: "󰚥" }
              ]

              Rectangle {
                required property var modelData
                width: (parent.width - Style.space(12)) / 7
                height: parent.height
                radius: Style.space(6)
                color: root.settingsActiveSection === modelData.id ? Color.accent : (tabMouse.containsMouse ? Util.alpha(root.fg, 0.06) : "transparent")

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: parent.parent.modelData.icon
                    color: root.settingsActiveSection === parent.parent.modelData.id ? "#fff" : root.fg
                    font.pixelSize: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: parent.parent.modelData.label
                    color: root.settingsActiveSection === parent.parent.modelData.id ? "#fff" : root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: root.settingsActiveSection === parent.parent.modelData.id
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.settingsActiveSection = parent.modelData.id
                    settingsFlickable.contentY = 0
                  }
                }
              }
            }
          }
        }
      }

      // -------------------------------------------------------------
      // SCROLLABLE SETTINGS CONTENT BODY
      // -------------------------------------------------------------
      Flickable {
        id: settingsFlickable
        anchors.top: settingsHeaderCol.bottom
        anchors.topMargin: Style.space(8)
        anchors.bottom: settingsFooterBar.top
        anchors.bottomMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        contentWidth: width
        contentHeight: settingsBodyCol.implicitHeight + Style.space(16)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: settingsBodyCol
          width: parent.width
          spacing: Style.space(14)

              // SECTION 1: CLIPBOARD HISTORY & RETENTION LIMITS (ACTIVE SECTION 0)
              Column {
                id: secRetentionCol
                visible: root.settingsActiveSection === 0
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                // Top Overview Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(42)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.035)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(26); height: Style.space(26); radius: Style.space(6)
                      color: Util.alpha(Color.accent, 0.15)
                      anchors.verticalCenter: parent.verticalCenter
                      Text { text: "📋"; font.pixelSize: Style.space(11); anchors.centerIn: parent }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(140)

                      Text {
                        text: "History Storage & Retention"
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: "Configure clipboard memory capacity and automatic cleanup rules"
                        color: Util.alpha(root.fg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // Stat Badge
                    Rectangle {
                      height: Style.space(22)
                      width: retStatTxt.implicitWidth + Style.space(12)
                      radius: Style.space(11)
                      color: Util.alpha(Color.accent, 0.12)
                      border.width: 1
                      border.color: Util.alpha(Color.accent, 0.3)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        id: retStatTxt
                        text: (root.history ? root.history.length : 0) + " Clips"
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        anchors.centerIn: parent
                      }
                    }
                  }
                }

                // CARD 1: MAXIMUM CLIPS LIMIT
                Rectangle {
                  width: parent.width
                  height: cardMaxClipsCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardMaxClipsCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰅍"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Maximum History Capacity"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Oldest non-pinned items are pruned when history exceeds this limit"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Presets
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { val: 100, label: "100 Clips" },
                          { val: 250, label: "250 Clips" },
                          { val: 500, label: "500 Clips (Default)" },
                          { val: 1000, label: "1,000 Clips" },
                          { val: 10000, label: "Unlimited" }
                        ]

                        Rectangle {
                          required property var modelData
                          height: Style.space(26)
                          width: maxClipTxt.implicitWidth + Style.space(14)
                          radius: Style.space(5)
                          property bool isSelected: root.settingsMaxClips === modelData.val
                          color: isSelected ? Color.accent : (mMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                          border.width: 1
                          border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                          Text {
                            id: maxClipTxt
                            text: parent.modelData.label
                            color: parent.isSelected ? "#FFFFFF" : root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            font.bold: parent.isSelected
                            anchors.centerIn: parent
                          }

                          MouseArea {
                            id: mMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsMaxClips = parent.modelData.val
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 2: AUTO-CLEANUP AGE & PRUNING
                Rectangle {
                  width: parent.width
                  height: cardPruneCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardPruneCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰔚"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Auto-Prune Expiration Age"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Automatically discard clips older than the specified duration"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Presets
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { days: 7, label: "7 Days" },
                          { days: 30, label: "30 Days (Default)" },
                          { days: 90, label: "90 Days" },
                          { days: 0, label: "Keep All" }
                        ]

                        Rectangle {
                          required property var modelData
                          height: Style.space(26)
                          width: pruneTxt.implicitWidth + Style.space(14)
                          radius: Style.space(5)
                          property bool isSelected: root.settingsRetainDays === modelData.days
                          color: isSelected ? Color.accent : (pMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                          border.width: 1
                          border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                          Text {
                            id: pruneTxt
                            text: parent.modelData.label
                            color: parent.isSelected ? "#FFFFFF" : root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            font.bold: parent.isSelected
                            anchors.centerIn: parent
                          }

                          MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsRetainDays = parent.modelData.days
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }

                    // Divider
                    Rectangle { width: parent.width; height: 1; color: Util.alpha(root.fg, 0.06) }

                    // Action row
                    Row {
                      spacing: Style.space(10)
                      Rectangle {
                        height: Style.space(30)
                        width: cleanBtnTxt.implicitWidth + Style.space(20)
                        radius: Style.space(5)
                        color: Util.alpha(Color.accent, 0.15)
                        border.width: 1
                        border.color: Color.accent

                        Row {
                          id: cleanBtnTxt
                          anchors.centerIn: parent; spacing: Style.space(5)
                          Text { text: "󰃢"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Apply Retention Clean Now"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.applyRetentionClean()
                        }
                      }

                      Text {
                        text: "Pinned clips are never deleted by retention cleanup"
                        color: Util.alpha(root.fg, 0.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }
                }

                // CARD 3: IMAGE COLOR EXTRACTION LIMIT
                Rectangle {
                  width: parent.width
                  height: cardPaletteCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardPaletteCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰏘"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Color Studio Palette Limit"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Maximum dominant swatches extracted automatically when copying images"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Presets
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { limit: 4, label: "4 Swatches" },
                          { limit: 6, label: "6 Swatches" },
                          { limit: 8, label: "8 Swatches" },
                          { limit: 12, label: "12 Swatches (Default)" },
                          { limit: 16, label: "16 Swatches" }
                        ]

                        Rectangle {
                          required property var modelData
                          height: Style.space(26)
                          width: palTxt.implicitWidth + Style.space(14)
                          radius: Style.space(5)
                          property bool isSelected: root.settingsImagePaletteLimit === modelData.limit
                          color: isSelected ? Color.accent : (palMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                          border.width: 1
                          border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                          Text {
                            id: palTxt
                            text: parent.modelData.label
                            color: parent.isSelected ? "#FFFFFF" : root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            font.bold: parent.isSelected
                            anchors.centerIn: parent
                          }

                          MouseArea {
                            id: palMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsImagePaletteLimit = parent.modelData.limit
                              root.saveSettings()
                              root.rebuildDisplay()
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 4: CLIP ACTION BUTTONS VISIBILITY
                Rectangle {
                  width: parent.width
                  height: cardActionsVisCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardActionsVisCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header Row with Sliding Capsule Toggle Switch
                    Item {
                      width: parent.width
                      height: Math.max(actionsVisHeaderLeft.implicitHeight, actionsVisToggle.implicitHeight)

                      Row {
                        id: actionsVisHeaderLeft
                        anchors.left: parent.left
                        anchors.right: actionsVisToggle.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                          color: Util.alpha(Color.accent, 0.12)
                          anchors.verticalCenter: parent.verticalCenter
                          Text { text: "󰇙"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                        }

                        Column {
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 1
                          width: parent.width - Style.space(36)

                          Text { text: "Clip Action Buttons Visibility"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                          Text { text: "Show trailing action controls (Copy, QR / OCR, Menu) only when hovering"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                        }
                      }

                      // Capsule sliding toggle switch
                      Rectangle {
                        id: actionsVisToggle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(42); height: Style.space(22); radius: Style.space(11)
                        color: root.settingsClipActionsOnHover ? Color.accent : Util.alpha(root.fg, 0.16)
                        border.width: 1
                        border.color: root.settingsClipActionsOnHover ? Color.accent : Util.alpha(root.fg, 0.12)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                          width: Style.space(16); height: Style.space(16); radius: Style.space(8)
                          color: "#FFFFFF"
                          anchors.verticalCenter: parent.verticalCenter
                          x: root.settingsClipActionsOnHover ? (parent.width - width - Style.space(3)) : Style.space(3)
                          Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.settingsClipActionsOnHover = !root.settingsClipActionsOnHover
                            root.saveSettings()
                          }
                        }
                      }
                    }

                    // Mode Selection Chips
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { hoverOnly: true, label: "Only on Hover (Default / Clean)", icon: "󰈈" },
                          { hoverOnly: false, label: "Always Visible", icon: "󰆒" }
                        ]

                        Rectangle {
                          required property var modelData
                          height: Style.space(26)
                          width: visChipRow.implicitWidth + Style.space(14)
                          radius: Style.space(5)
                          property bool isSelected: root.settingsClipActionsOnHover === modelData.hoverOnly
                          color: isSelected ? Color.accent : (visMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                          border.width: 1
                          border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                          Row {
                            id: visChipRow
                            anchors.centerIn: parent
                            spacing: Style.space(5)

                            Text {
                              text: parent.parent.modelData.icon
                              color: parent.parent.isSelected ? "#FFFFFF" : Color.accent
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(8.5)
                              anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                              text: parent.parent.modelData.label
                              color: parent.parent.isSelected ? "#FFFFFF" : root.fg
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(8.5)
                              font.bold: parent.parent.isSelected
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }

                          MouseArea {
                            id: visMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.settingsClipActionsOnHover = parent.modelData.hoverOnly
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }

                    Text {
                      text: root.settingsClipActionsOnHover
                        ? "Action buttons smoothly fade in when moving the mouse over any clip item."
                        : "Action buttons remain visible at all times on every history, pinned, and snippet clip."
                      color: Util.alpha(root.fg, 0.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(7.5)
                    }
                  }
                }

                // CARD 5: SMART BUMP & REVISION STACKING
                Rectangle {
                  width: parent.width
                  height: cardDedupCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardDedupCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(12)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰑖"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Intelligent Deduplication & Revision Stacking"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Keep history clean by bumping exact duplicates and stacking iterative edits"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Item 1: Smart Bump Deduplication
                    Item {
                      width: parent.width
                      height: Style.space(32)

                      Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(22); height: Style.space(22); radius: Style.space(4)
                          color: Util.alpha(Color.accent, 0.1)
                          Text { text: "󰑖"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                        }

                        Column {
                          spacing: 0
                          Text { text: "Smart Bump Counter"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true }
                          Text { text: "Bump duplicate copies to top and increment a copy counter (󰑖 ×N) instead of creating clutter"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(7.5) }
                        }
                      }

                      Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(40); height: Style.space(20); radius: Style.space(10)
                        color: root.settingsSmartBump ? Color.accent : Util.alpha(root.fg, 0.16)
                        border.width: 1; border.color: root.settingsSmartBump ? Color.accent : Util.alpha(root.fg, 0.12)

                        Rectangle {
                          width: Style.space(14); height: Style.space(14); radius: Style.space(7)
                          color: "#FFFFFF"
                          anchors.verticalCenter: parent.verticalCenter
                          x: root.settingsSmartBump ? (parent.width - width - Style.space(3)) : Style.space(3)
                          Behavior on x { NumberAnimation { duration: 160 } }
                        }

                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.settingsSmartBump = !root.settingsSmartBump
                            root.saveSettings()
                          }
                        }
                      }
                    }

                    // Item 2: Revision Stacking & Mini Diff
                    Item {
                      width: parent.width
                      height: Style.space(32)

                      Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(22); height: Style.space(22); radius: Style.space(4)
                          color: Util.alpha(Color.accent, 0.1)
                          Text { text: "󰦪"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                        }

                        Column {
                          spacing: 0
                          Text { text: "Stack Iterative Code / Text Revisions"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true }
                          Text { text: "Group sequential edits of the same paragraph or function with a mini diff viewer"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(7.5) }
                        }
                      }

                      Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(40); height: Style.space(20); radius: Style.space(10)
                        color: root.settingsRevisionStacking ? Color.accent : Util.alpha(root.fg, 0.16)
                        border.width: 1; border.color: root.settingsRevisionStacking ? Color.accent : Util.alpha(root.fg, 0.12)

                        Rectangle {
                          width: Style.space(14); height: Style.space(14); radius: Style.space(7)
                          color: "#FFFFFF"
                          anchors.verticalCenter: parent.verticalCenter
                          x: root.settingsRevisionStacking ? (parent.width - width - Style.space(3)) : Style.space(3)
                          Behavior on x { NumberAnimation { duration: 160 } }
                        }

                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.settingsRevisionStacking = !root.settingsRevisionStacking
                            root.saveSettings()
                          }
                        }
                      }
                    }
                  }
                }
              }

              // SECTION 2: PRIVACY & SECURITY (ACTIVE SECTION 1)
              Column {
                id: secPrivacyCol
                visible: root.settingsActiveSection === 1
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                // Top Overview Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(42)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.035)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(26); height: Style.space(26); radius: Style.space(6)
                      color: Util.alpha(Color.accent, 0.15)
                      anchors.verticalCenter: parent.verticalCenter
                      Text { text: "🛡"; font.pixelSize: Style.space(11); anchors.centerIn: parent }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(140)

                      Text {
                        text: "Privacy & Data Protection"
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: "Password manager shielding and on-demand incognito recording"
                        color: Util.alpha(root.fg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // Live Protected Badge
                    Rectangle {
                      height: Style.space(22)
                      width: privStatTxt.implicitWidth + Style.space(12)
                      radius: Style.space(11)
                      color: root.incognito ? Util.alpha(Color.urgent, 0.15) : Util.alpha("#22c55e", 0.12)
                      border.width: 1
                      border.color: root.incognito ? Util.alpha(Color.urgent, 0.3) : Util.alpha("#22c55e", 0.3)
                      anchors.verticalCenter: parent.verticalCenter

                      Row {
                        id: privStatTxt
                        anchors.centerIn: parent
                        spacing: Style.space(5)
                        Rectangle {
                          width: Style.space(6); height: Style.space(6); radius: Style.space(3)
                          color: root.incognito ? Color.urgent : "#22c55e"
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: root.incognito ? "Incognito" : "Protected"
                          color: root.incognito ? Color.urgent : "#22c55e"
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 1: PASSWORD MANAGER SHIELDING
                Rectangle {
                  width: parent.width
                  height: cardShieldCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardShieldCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header Row with Toggle Switch
                    Item {
                      width: parent.width
                      height: Math.max(shieldHeaderLeft.implicitHeight, shieldToggleSwitch.implicitHeight)

                      Row {
                        id: shieldHeaderLeft
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                          color: Util.alpha(Color.accent, 0.12)
                          Text { text: "󰌋"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                        }

                        Column {
                          spacing: 1
                          Text { text: "Password Manager Shielding"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                          Text { text: "Block sensitive credentials from KeePassXC, 1Password, and Bitwarden"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                        }
                      }

                      // Modern Toggle Switch
                      Rectangle {
                        id: shieldToggleSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(46); height: Style.space(24); radius: Style.space(12)
                        color: root.settingsIgnoreSensitive ? Color.accent : Util.alpha(root.fg, 0.16)
                        border.width: 1
                        border.color: root.settingsIgnoreSensitive ? Color.accent : Util.alpha(root.fg, 0.12)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                          width: Style.space(18); height: Style.space(18); radius: Style.space(9)
                          color: "#FFFFFF"
                          anchors.verticalCenter: parent.verticalCenter
                          x: root.settingsIgnoreSensitive ? (parent.width - width - Style.space(3)) : Style.space(3)
                          Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.settingsIgnoreSensitive = !root.settingsIgnoreSensitive
                            root.saveSettings()
                          }
                        }
                      }
                    }

                    // Explanatory Note
                    Rectangle {
                      width: parent.width
                      height: Style.space(30)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.025)
                      border.width: 1
                      border.color: Util.alpha(root.fg, 0.06)

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(6)
                        Text { text: "󰄬"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                          text: "Clips flagged with x-kde-passwordManagerHint MIME types are never written to disk"
                          color: Util.alpha(root.fg, 0.5)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 2: INCOGNITO RECORDING MODE
                Rectangle {
                  width: parent.width
                  height: cardIncogCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardIncogCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header Row with Toggle Switch
                    Item {
                      width: parent.width
                      height: Math.max(incogHeaderLeft.implicitHeight, incogToggleSwitch.implicitHeight)

                      Row {
                        id: incogHeaderLeft
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                          color: root.incognito ? Util.alpha(Color.urgent, 0.15) : Util.alpha(root.fg, 0.08)
                          Text { text: "󰈈"; color: root.incognito ? Color.urgent : root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                        }

                        Column {
                          spacing: 1
                          Text { text: "Incognito Recording Mode"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                          Text { text: "Temporarily pause recording all copied clips across the system"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                        }
                      }

                      // Modern Toggle Switch
                      Rectangle {
                        id: incogToggleSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(46); height: Style.space(24); radius: Style.space(12)
                        color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.16)
                        border.width: 1
                        border.color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.12)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                          width: Style.space(18); height: Style.space(18); radius: Style.space(9)
                          color: "#FFFFFF"
                          anchors.verticalCenter: parent.verticalCenter
                          x: root.incognito ? (parent.width - width - Style.space(3)) : Style.space(3)
                          Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleIncognito()
                        }
                      }
                    }

                    // Status Callout
                    Rectangle {
                      width: parent.width
                      height: Style.space(30)
                      radius: Style.space(6)
                      color: root.incognito ? Util.alpha(Color.urgent, 0.12) : Util.alpha(root.fg, 0.025)
                      border.width: 1
                      border.color: root.incognito ? Util.alpha(Color.urgent, 0.3) : Util.alpha(root.fg, 0.06)

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(6)
                        Text {
                          text: root.incognito ? "⏸" : "●"
                          color: root.incognito ? Color.urgent : "#22c55e"
                          font.pixelSize: Style.space(8.5)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: root.incognito ? "Clipboard capture is paused. No new items will be stored in history." : "Normal operation: Clipboard changes are captured to local storage."
                          color: root.incognito ? Color.urgent : Util.alpha(root.fg, 0.5)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 3: LOCAL DISK SECURITY & TELEMETRY
                Rectangle {
                  width: parent.width
                  height: cardSecurityCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardSecurityCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰌌"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Local Disk Storage & Zero Telemetry"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Your clipboard data never leaves your machine"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Security Badges Grid
                    Grid {
                      width: parent.width
                      columns: 2
                      spacing: Style.space(8)

                      Rectangle {
                        width: (parent.width - Style.space(8)) / 2
                        height: Style.space(38)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.03)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.07)

                        Row {
                          anchors.fill: parent; anchors.margins: Style.space(8)
                          spacing: Style.space(8)
                          Text { text: "󰄬"; color: "#22c55e"; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
                          Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Zero Network Access"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }
                            Text { text: "100% offline & client-side"; color: Util.alpha(root.fg, 0.45); font.family: root.fontFamily; font.pixelSize: Style.space(7.5) }
                          }
                        }
                      }

                      Rectangle {
                        width: (parent.width - Style.space(8)) / 2
                        height: Style.space(38)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.03)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.07)

                        Row {
                          anchors.fill: parent; anchors.margins: Style.space(8)
                          spacing: Style.space(8)
                          Text { text: "󰉋"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(10); anchors.verticalCenter: parent.verticalCenter }
                          Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Isolated User State"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }
                            Text { text: "~/.local/state/reclip"; color: Util.alpha(root.fg, 0.45); font.family: "monospace"; font.pixelSize: Style.space(7.5) }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 4: APP-AWARE EXCLUSIONS & BLACKLIST
                Rectangle {
                  width: parent.width
                  height: cardAppBlacklistCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardAppBlacklistCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰣆"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Application Exclusions & Blacklist"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Clips copied from blacklisted Hyprland window classes are automatically ignored"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Add Application Bar
                    RowLayout {
                      width: parent.width
                      spacing: Style.space(6)

                      Rectangle {
                        Layout.fillWidth: true
                        height: Style.space(28)
                        radius: Style.space(4)
                        color: Util.alpha(root.fg, 0.05)
                        border.width: 1
                        border.color: appInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6)
                          spacing: Style.space(4)
                          Text { text: "󰞷"; color: Util.alpha(root.fg, 0.4); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                          TextInput {
                            id: appInput
                            Layout.fillWidth: true
                            color: root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            text: root.newBlacklistApp
                            onTextChanged: root.newBlacklistApp = text
                            clip: true

                            Text {
                              visible: !parent.text && !parent.activeFocus
                              text: "Enter application class (e.g. KeePassXC, 1Password, Slack)..."
                              color: Util.alpha(root.fg, 0.35)
                              font.family: parent.font.family
                              font.pixelSize: parent.font.pixelSize
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }
                        }
                      }

                      Rectangle {
                        Layout.preferredWidth: Style.space(80)
                        Layout.preferredHeight: Style.space(28)
                        radius: Style.space(4)
                        color: addAppMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                        Text {
                          anchors.centerIn: parent
                          text: "+ Add App"
                          color: "#FFFFFF"
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8.5)
                          font.bold: true
                        }

                        MouseArea {
                          id: addAppMouse
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            var app = root.newBlacklistApp.trim()
                            if (!app) return
                            var list = Array.isArray(root.settingsAppBlacklist) ? root.settingsAppBlacklist.slice() : []
                            if (list.indexOf(app) < 0) {
                              list.push(app)
                              root.settingsAppBlacklist = list
                              root.saveSettings()
                            }
                            root.newBlacklistApp = ""
                          }
                        }
                      }
                    }

                    // Blacklist Chips
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: root.settingsAppBlacklist

                        Rectangle {
                          required property string modelData
                          required property int index
                          height: Style.space(24)
                          width: chipRow.implicitWidth + Style.space(12)
                          radius: Style.space(4)
                          color: Util.alpha(Color.accent, 0.15)
                          border.width: 1; border.color: Util.alpha(Color.accent, 0.3)

                          Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Style.space(4)
                            Text { text: "󰣆"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(7.5) }
                            Text { text: parent.parent.modelData; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true }
                            Text { text: "✕"; color: Util.alpha(root.fg, 0.5); font.pixelSize: Style.space(7.5) }
                          }

                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              var list = root.settingsAppBlacklist.slice()
                              list.splice(parent.index, 1)
                              root.settingsAppBlacklist = list
                              root.saveSettings()
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // SECTION 3: AUTOMATIONS & REGEX RULES (ACTIVE SECTION 2)
              Column {
                id: secAutoCol
                visible: root.settingsActiveSection === 2
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                // Top Overview Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(42)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.035)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(26); height: Style.space(26); radius: Style.space(6)
                      color: Util.alpha(Color.accent, 0.15)
                      anchors.verticalCenter: parent.verticalCenter
                      Text { text: "⚡"; font.pixelSize: Style.space(11); anchors.centerIn: parent }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(140)

                      Text {
                        text: "Clipboard Automations & Regex Rules"
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: "Trigger actions like auto-tagging, URL cleaning, or notifications when copying text"
                        color: Util.alpha(root.fg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // Stat Badge
                    Rectangle {
                      height: Style.space(22)
                      width: autoStatTxt.implicitWidth + Style.space(12)
                      radius: Style.space(11)
                      color: Util.alpha(Color.accent, 0.12)
                      border.width: 1
                      border.color: Util.alpha(Color.accent, 0.3)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        id: autoStatTxt
                        text: (root.automationRules ? root.automationRules.length : 0) + " Rules"
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        anchors.centerIn: parent
                      }
                    }
                  }
                }

                // CARD 1: PRESET RULE TEMPLATES
                Rectangle {
                  width: parent.width
                  height: cardPresetsCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardPresetsCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(8)

                    Text { text: "Quick Presets Gallery:"; color: Util.alpha(root.fg, 0.65); font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }

                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { label: "+ Clean URL UTM", pattern: "[?&]utm_[a-zA-Z0-9_]+=[^&#]*", act: "replace", payload: "", name: "Clean URL Tracking Params" },
                          { label: "+ Password Filter", pattern: "^(?:password|secret|passwd|api[_-]?key)\\s*[:=]\\s*.+", act: "ignore", payload: "", name: "Ignore Passwords" },
                          { label: "+ Credit Card Filter", pattern: "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b", act: "ignore", payload: "", name: "Ignore Credit Cards" },
                          { label: "+ Email Auto-tag", pattern: "\\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\b", act: "tag", payload: "email", name: "Auto-tag Email" },
                          { label: "+ JWT Token Auto-tag", pattern: "eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}", act: "tag", payload: "jwt", name: "Auto-tag JWT" },
                          { label: "+ IPv4 Auto-tag", pattern: "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", act: "tag", payload: "ip", name: "Auto-tag IP" },
                          { label: "+ GitHub Issue URL", pattern: "(?:GH-|gh-|#)(\\d{1,6})", act: "open_url", payload: "https://github.com/issues?q=$1", name: "Open GitHub Issue" }
                        ]

                        Rectangle {
                          required property var modelData
                          height: Style.space(24)
                          width: pChipTxt.implicitWidth + Style.space(12)
                          radius: Style.space(4)
                          color: pChipMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fg, 0.05)
                          border.width: 1
                          border.color: pChipMouse.containsMouse ? Color.accent : Util.alpha(root.fg, 0.1)

                          Text {
                            id: pChipTxt
                            text: parent.modelData.label
                            color: pChipMouse.containsMouse ? Color.accent : root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8)
                            font.bold: true
                            anchors.centerIn: parent
                          }

                          MouseArea {
                            id: pChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.newRuleName = parent.modelData.name
                              root.newRulePattern = parent.modelData.pattern
                              root.newRuleAction = parent.modelData.act
                              root.newRulePayload = parent.modelData.payload
                              root.runRuleTester()
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 2: AUTOMATION RULE BUILDER FORM
                Rectangle {
                  width: parent.width
                  height: cardRuleFormCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardRuleFormCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header
                    Item {
                      width: parent.width
                      height: Style.space(22)

                      Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(6)

                        Text {
                          text: root.ruleEditId !== "" ? "Edit Automation Rule" : "Create Automation Rule"
                          color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true
                        }

                        Rectangle {
                          visible: root.ruleEditId !== ""
                          height: Style.space(18); width: editBadgeTxt.implicitWidth + Style.space(8); radius: Style.space(3)
                          color: Util.alpha(Color.accent, 0.15)
                          anchors.verticalCenter: parent.verticalCenter
                          Text {
                            id: editBadgeTxt
                            text: "Editing: " + root.ruleEditId
                            color: Color.accent; font.family: "monospace"; font.pixelSize: Style.space(7.5); font.bold: true
                            anchors.centerIn: parent
                          }
                        }
                      }
                    }

                    // Rule Name Field
                    Rectangle {
                      width: parent.width
                      height: Style.space(32)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: ruleNameIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                      TextInput {
                        id: ruleNameIn
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(9)
                        selectByMouse: true
                        text: root.newRuleName
                        onTextEdited: root.newRuleName = text

                        Text {
                          visible: ruleNameIn.text === "" && !ruleNameIn.activeFocus
                          text: "Rule name (e.g. Clean URL Tracking Params)"
                          color: Util.alpha(root.fg, 0.35)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8.5)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }

                    // Regex Pattern Field
                    Rectangle {
                      width: parent.width
                      height: Style.space(32)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: rulePatternIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                      TextInput {
                        id: rulePatternIn
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        color: root.fg
                        font.family: "monospace"
                        font.pixelSize: Style.space(9)
                        selectByMouse: true
                        text: root.newRulePattern
                        onTextEdited: {
                          root.newRulePattern = text
                          root.runRuleTester()
                        }

                        Text {
                          visible: rulePatternIn.text === "" && !rulePatternIn.activeFocus
                          text: "Regex pattern (e.g. [?&]utm_[a-zA-Z0-9_]+=[^&#]*)"
                          color: Util.alpha(root.fg, 0.35)
                          font.family: "monospace"
                          font.pixelSize: Style.space(8.5)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }

                    // Action Selector
                    Column {
                      width: parent.width
                      spacing: Style.space(4)

                      Text { text: "Triggered Action:"; color: Util.alpha(root.fg, 0.65); font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }

                      Flow {
                        width: parent.width
                        spacing: Style.space(6)

                        Repeater {
                          model: [
                            { id: "tag", label: "🏷 Tag Clip" },
                            { id: "replace", label: "🧹 Clean / Replace" },
                            { id: "open_url", label: "↗ Open URL" },
                            { id: "notify", label: "󰂚 Notify" },
                            { id: "ignore", label: "⊘ Ignore / Filter" }
                          ]

                          Rectangle {
                            required property var modelData
                            height: Style.space(26)
                            width: actBtnTxt.implicitWidth + Style.space(14)
                            radius: Style.space(5)
                            property bool isSelected: root.newRuleAction === modelData.id
                            color: isSelected ? Color.accent : (actMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                            border.width: 1
                            border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                            Text {
                              id: actBtnTxt
                              text: parent.modelData.label
                              color: parent.isSelected ? "#FFFFFF" : root.fg
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(8.5)
                              font.bold: parent.isSelected
                              anchors.centerIn: parent
                            }

                            MouseArea {
                              id: actMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.newRuleAction = parent.modelData.id
                                root.runRuleTester()
                              }
                            }
                          }
                        }
                      }
                    }

                    // Action Payload Field (visible when action !== "ignore")
                    Rectangle {
                      visible: root.newRuleAction !== "ignore"
                      width: parent.width
                      height: Style.space(32)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: rulePayloadIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                      TextInput {
                        id: rulePayloadIn
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        color: root.fg
                        font.family: (root.newRuleAction === "open_url" || root.newRuleAction === "replace") ? "monospace" : root.fontFamily
                        font.pixelSize: Style.space(8.5)
                        selectByMouse: true
                        text: root.newRulePayload
                        onTextEdited: {
                          root.newRulePayload = text
                          root.runRuleTester()
                        }

                        Text {
                          visible: rulePayloadIn.text === "" && !rulePayloadIn.activeFocus
                          text: root.newRuleAction === "open_url" ? "Target URL (supports $1, $2 capture groups)" : (root.newRuleAction === "tag" ? "Tag name (e.g. email)" : (root.newRuleAction === "replace" ? "Replacement text (leave empty to strip)" : "Notification text template ($1)"))
                          color: Util.alpha(root.fg, 0.35)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8.5)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }

                    // Action Buttons Row
                    Row {
                      spacing: Style.space(8)

                      // Submit Button
                      Rectangle {
                        height: Style.space(30)
                        width: addRuleTxt.implicitWidth + Style.space(20)
                        radius: Style.space(5)
                        color: Color.accent

                        Row {
                          id: addRuleTxt
                          anchors.centerIn: parent; spacing: Style.space(4)
                          Text { text: root.ruleEditId !== "" ? "✓" : "+"; color: "#FFFFFF"; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: root.ruleEditId !== "" ? "Update Rule" : "Add Rule"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (!root.newRulePattern.trim()) return
                            if (root.ruleEditId !== "") {
                              root.automationRules = AutomationRules.updateRule(root.automationRules, root.ruleEditId, {
                                name: root.newRuleName || "Rule",
                                pattern: root.newRulePattern,
                                action: root.newRuleAction,
                                payload: root.newRulePayload
                              })
                              root.ruleEditId = ""
                            } else {
                              root.automationRules = AutomationRules.addRule(root.automationRules, {
                                name: root.newRuleName || "Rule #" + (root.automationRules.length + 1),
                                pattern: root.newRulePattern,
                                action: root.newRuleAction,
                                payload: root.newRulePayload,
                                enabled: true
                              })
                            }
                            root.saveAutomations()
                            root.newRuleName = ""
                            root.newRulePattern = ""
                            root.newRulePayload = ""
                            root.runRuleTester()
                          }
                        }
                      }

                      // Cancel Edit Button
                      Rectangle {
                        visible: root.ruleEditId !== ""
                        height: Style.space(30); width: Style.space(70); radius: Style.space(5)
                        color: Util.alpha(root.fg, 0.05); border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                        Text { text: "Cancel"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.ruleEditId = ""
                            root.newRuleName = ""
                            root.newRulePattern = ""
                            root.newRulePayload = ""
                            root.runRuleTester()
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 3: LIVE REGEX TESTER SANDBOX
                Rectangle {
                  width: parent.width
                  height: cardTesterCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardTesterCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(8)

                    Row {
                      spacing: Style.space(6)
                      Text { text: "🧪 Live Regex Tester Sandbox"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9.5); font.bold: true }
                      Text { text: "• Evaluates pattern in real-time"; color: Util.alpha(root.fg, 0.45); font.pixelSize: Style.space(8) }
                    }

                    // Sample Input Box
                    Rectangle {
                      width: parent.width
                      height: Style.space(30)
                      radius: Style.space(5)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: sampleIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.1)

                      TextInput {
                        id: sampleIn
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        color: root.fg
                        font.family: "monospace"
                        font.pixelSize: Style.space(8.5)
                        selectByMouse: true
                        text: root.testRuleSample
                        onTextEdited: {
                          root.testRuleSample = text
                          root.runRuleTester()
                        }

                        Text {
                          visible: sampleIn.text === "" && !sampleIn.activeFocus
                          text: "Type or paste test clipboard text here..."
                          color: Util.alpha(root.fg, 0.35)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8.5)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }

                    // Match Result Banner
                    Rectangle {
                      width: parent.width
                      height: Style.space(28)
                      radius: Style.space(5)
                      color: !root.newRulePattern ? Util.alpha(root.fg, 0.03) : (!root.testRuleResult.valid ? Util.alpha(Color.urgent, 0.12) : (root.testRuleResult.matches ? Util.alpha(Color.accent, 0.15) : Util.alpha(root.fg, 0.04)))
                      border.width: 1
                      border.color: !root.newRulePattern ? Util.alpha(root.fg, 0.06) : (!root.testRuleResult.valid ? Color.urgent : (root.testRuleResult.matches ? Color.accent : Util.alpha(root.fg, 0.08)))

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(8)

                        Text {
                          visible: !root.newRulePattern
                          text: "Type a regex pattern above to preview live matching against this sample."
                          color: Util.alpha(root.fg, 0.45); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          visible: !!root.newRulePattern && !root.testRuleResult.valid
                          text: "✕ " + (root.testRuleResult.error || "Regex compilation error")
                          color: Color.urgent; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter
                        }
                        Row {
                          visible: !!root.newRulePattern && !!root.testRuleResult.valid && root.testRuleResult.matches
                          spacing: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                          Text { text: "✓ MATCH"; color: Color.accent; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Matched: \"" + (root.testRuleResult.matchedText || "") + "\""; color: root.fg; font.family: "monospace"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "→ " + (root.testRuleResult.simulatedResult || ""); color: Util.alpha(root.fg, 0.7); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text {
                          visible: !!root.newRulePattern && !!root.testRuleResult.valid && !root.testRuleResult.matches
                          text: "✕ No match on sample text"
                          color: Util.alpha(root.fg, 0.45); font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 4: CONFIGURED RULES LIST
                Rectangle {
                  width: parent.width
                  height: cardRulesListCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardRulesListCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(8)

                    Text { text: "Configured Rules (" + root.automationRules.length + "):"; color: Util.alpha(root.fg, 0.65); font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }

                    Repeater {
                      model: root.automationRules

                      Rectangle {
                        id: ruleRowDelegate
                        required property var modelData
                        readonly property var ruleItem: modelData || {}
                        width: parent.width
                        height: Style.space(48)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.035)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.08)

                        Item {
                          anchors.fill: parent
                          anchors.margins: Style.space(8)

                          Row {
                            anchors.left: parent.left
                            anchors.right: ruleActionBtns.left
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(8)

                            // Action Badge
                            Rectangle {
                              height: Style.space(20); width: ruleBadgeTxt.implicitWidth + Style.space(10); radius: Style.space(3)
                              color: ruleRowDelegate.ruleItem.action === "ignore" ? Util.alpha(Color.urgent, 0.15) : (ruleRowDelegate.ruleItem.action === "replace" ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.accent, 0.12))
                              border.width: 1
                              border.color: ruleRowDelegate.ruleItem.action === "ignore" ? Util.alpha(Color.urgent, 0.4) : Util.alpha(Color.accent, 0.4)
                              anchors.verticalCenter: parent.verticalCenter
                              Text {
                                id: ruleBadgeTxt
                                text: (ruleRowDelegate.ruleItem.action || "").toUpperCase().replace("_", " ")
                                color: ruleRowDelegate.ruleItem.action === "ignore" ? Color.urgent : Color.accent
                                font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true
                                anchors.centerIn: parent
                              }
                            }

                            // Name & Pattern
                            Column {
                              anchors.verticalCenter: parent.verticalCenter; spacing: 2
                              width: parent.parent.width - Style.space(120)

                              Row {
                                spacing: Style.space(6)
                                Text {
                                  text: ruleRowDelegate.ruleItem.name || ""
                                  color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true
                                }
                                Text {
                                  visible: !!ruleRowDelegate.ruleItem.payload
                                  text: "→ " + (ruleRowDelegate.ruleItem.payload || "")
                                  color: Util.alpha(root.fg, 0.55); font.family: "monospace"; font.pixelSize: Style.space(8)
                                  elide: Text.ElideRight; width: Style.space(140)
                                }
                              }
                              Text {
                                text: ruleRowDelegate.ruleItem.pattern || ""
                                color: Color.accent; font.family: "monospace"; font.pixelSize: Style.space(8)
                                elide: Text.ElideRight; width: parent.width
                              }
                            }
                          }

                          // Action controls
                          Row {
                            id: ruleActionBtns
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(6)

                            // Edit Rule Button
                            Rectangle {
                              height: Style.space(24); width: Style.space(24); radius: Style.space(4)
                              color: Util.alpha(root.fg, 0.06)
                              Text { text: "✏"; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
                              MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  var r = ruleRowDelegate.ruleItem
                                  root.ruleEditId = r.id
                                  root.newRuleName = r.name || ""
                                  root.newRulePattern = r.pattern || ""
                                  root.newRuleAction = r.action || "tag"
                                  root.newRulePayload = r.payload || ""
                                  root.runRuleTester()
                                }
                              }
                            }

                            // Modern Sliding Toggle
                            Rectangle {
                              width: Style.space(38); height: Style.space(20); radius: Style.space(10)
                              color: ruleRowDelegate.ruleItem.enabled ? Color.accent : Util.alpha(root.fg, 0.16)
                              border.width: 1
                              border.color: ruleRowDelegate.ruleItem.enabled ? Color.accent : Util.alpha(root.fg, 0.12)
                              Behavior on color { ColorAnimation { duration: 160 } }

                              Rectangle {
                                width: Style.space(14); height: Style.space(14); radius: Style.space(7)
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                                x: ruleRowDelegate.ruleItem.enabled ? (parent.width - width - Style.space(2.5)) : Style.space(2.5)
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                              }

                              MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  root.automationRules = AutomationRules.toggleRule(root.automationRules, ruleRowDelegate.ruleItem.id)
                                  root.saveAutomations()
                                }
                              }
                            }

                            // Delete Rule Button
                            Rectangle {
                              height: Style.space(24); width: Style.space(24); radius: Style.space(4)
                              color: Util.alpha(Color.urgent, 0.12)
                              Text { text: "🗑"; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                              MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  root.automationRules = AutomationRules.deleteRule(root.automationRules, ruleRowDelegate.ruleItem.id)
                                  root.saveAutomations()
                                }
                              }
                            }
                          }
                        }
                      }
                    }

                    Text {
                      visible: root.automationRules.length === 0
                      text: "No automation rules defined yet. Use quick presets above or add a custom rule."
                      color: Util.alpha(root.fg, 0.4); font.family: root.fontFamily; font.pixelSize: Style.space(8.5)
                    }
                  }
                }
              }

              // SECTION 4: DYNAMIC TEMPLATES & SNIPPET VARIABLES (ACTIVE SECTION 3)
              Column {
                id: secTplCol
                visible: root.settingsActiveSection === 3
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                // Top Section Overview Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(52)
                  radius: Style.space(8)
                  color: Util.alpha(Color.accent, 0.08)
                  border.width: 1
                  border.color: Util.alpha(Color.accent, 0.25)

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(32)
                      height: Style.space(32)
                      radius: Style.space(8)
                      color: Util.alpha(Color.accent, 0.16)
                      anchors.verticalCenter: parent.verticalCenter
                      Text { text: "📑"; font.pixelSize: Style.space(12); anchors.centerIn: parent }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(140)

                      Text {
                        text: "Dynamic Templates & Variables"
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: "Dynamic placeholders with real-time variable evaluation"
                        color: Util.alpha(root.fg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // Stat Badge
                    Rectangle {
                      height: Style.space(22)
                      width: tplStatTxt.implicitWidth + Style.space(12)
                      radius: Style.space(11)
                      color: Util.alpha(Color.accent, 0.12)
                      border.width: 1
                      border.color: Util.alpha(Color.accent, 0.25)
                      anchors.verticalCenter: parent.verticalCenter

                      Row {
                        id: tplStatTxt
                        anchors.centerIn: parent
                        spacing: Style.space(5)
                        Rectangle {
                          width: Style.space(6); height: Style.space(6); radius: Style.space(3)
                          color: Color.accent
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: root.templates.length + " Templates"
                          color: Color.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 1: VARIABLE PLACEHOLDER TOKENS
                Rectangle {
                  width: parent.width
                  height: cardVarTokensCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardVarTokensCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰏫"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Variable Placeholders"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Click any token to insert at current cursor position in editor"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: ["{{date}}", "{{time}}", "{{datetime}}", "{{clipboard}}", "{{uuid}}", "{{timestamp}}", "{{year}}", "{{month}}"]

                        Rectangle {
                          required property string modelData
                          height: Style.space(24)
                          width: varChipContent.implicitWidth + Style.space(12)
                          radius: Style.space(4)
                          color: vChipMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.accent, 0.1)
                          border.width: 1
                          border.color: vChipMouse.containsMouse ? Color.accent : Util.alpha(Color.accent, 0.3)

                          Row {
                            id: varChipContent
                            anchors.centerIn: parent
                            spacing: Style.space(4)
                            Text {
                              text: parent.parent.modelData
                              color: Color.accent
                              font.family: "monospace"
                              font.pixelSize: Style.space(8)
                              font.bold: true
                            }
                          }

                          MouseArea {
                            id: vChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              tplContentIn.insert(tplContentIn.cursorPosition, parent.modelData)
                              root.tplEditContent = tplContentIn.text
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 2: TEMPLATE BUILDER & EDITOR
                Rectangle {
                  width: parent.width
                  height: cardTplFormCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardTplFormCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰏪"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text {
                          text: root.tplEditId !== "" ? "Edit Template: " + (root.tplEditName || "Untitled") : "Create New Template"
                          color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true
                        }
                        Text {
                          text: "Configure template name, language syntax, and content pattern"
                          color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8)
                        }
                      }
                    }

                    // Input fields row: Name & Language
                    Row {
                      width: parent.width
                      spacing: Style.space(8)

                      // Template Name Input
                      Rectangle {
                        width: parent.width - Style.space(138)
                        height: Style.space(32)
                        radius: Style.space(5)
                        color: Util.alpha(root.fg, 0.04)
                        border.width: 1
                        border.color: tplNameIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                        TextInput {
                          id: tplNameIn
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(8)
                          anchors.rightMargin: Style.space(8)
                          verticalAlignment: TextInput.AlignVCenter
                          color: root.fg
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(9)
                          text: root.tplEditName
                          onTextEdited: root.tplEditName = text

                          Text {
                            visible: tplNameIn.text === "" && !tplNameIn.activeFocus
                            text: "Template Name (e.g. Bug Report, Meeting Notes)"
                            color: Util.alpha(root.fg, 0.35)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                      }

                      // Language Input
                      Rectangle {
                        width: Style.space(130)
                        height: Style.space(32)
                        radius: Style.space(5)
                        color: Util.alpha(root.fg, 0.04)
                        border.width: 1
                        border.color: tplLangIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                        TextInput {
                          id: tplLangIn
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(8)
                          anchors.rightMargin: Style.space(8)
                          verticalAlignment: TextInput.AlignVCenter
                          color: root.fg
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(9)
                          text: root.tplEditLang
                          onTextEdited: root.tplEditLang = text

                          Text {
                            visible: tplLangIn.text === "" && !tplLangIn.activeFocus
                            text: "Language (markdown)"
                            color: Util.alpha(root.fg, 0.35)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                      }
                    }

                    // Content Editor Textarea
                    Rectangle {
                      width: parent.width
                      height: Style.space(86)
                      radius: Style.space(5)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: tplContentIn.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                      Flickable {
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        contentWidth: width
                        clip: true

                        TextEdit {
                          id: tplContentIn
                          width: parent.width
                          color: root.fg
                          font.family: "monospace"
                          font.pixelSize: Style.space(8.5)
                          wrapMode: TextEdit.Wrap
                          text: root.tplEditContent
                          onTextEdited: root.tplEditContent = text

                          Text {
                            visible: tplContentIn.text === "" && !tplContentIn.activeFocus
                            text: "Enter template text with placeholders e.g. 'Meeting with {{clipboard}} on {{date}}'..."
                            color: Util.alpha(root.fg, 0.35)
                            font.family: "monospace"
                            font.pixelSize: Style.space(8)
                            y: Style.space(1)
                          }
                        }
                      }
                    }

                    // Action buttons
                    Row {
                      spacing: Style.space(8)

                      Rectangle {
                        height: Style.space(30)
                        width: saveTplTxt.implicitWidth + Style.space(20)
                        radius: Style.space(5)
                        color: saveTplMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                        Row {
                          id: saveTplTxt
                          anchors.centerIn: parent
                          spacing: Style.space(5)
                          Text { text: root.tplEditId !== "" ? "󰑐" : "󰐕"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                          Text {
                            text: root.tplEditId !== "" ? "Update Template" : "Save Template"
                            color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter
                          }
                        }

                        MouseArea {
                          id: saveTplMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (!root.tplEditName.trim() || !root.tplEditContent.trim()) return
                            if (root.tplEditId !== "") {
                              root.templates = TemplateEngine.updateTemplate(root.templates, root.tplEditId, {
                                name: root.tplEditName,
                                language: root.tplEditLang || "markdown",
                                content: root.tplEditContent
                              })
                            } else {
                              root.templates = TemplateEngine.addTemplate(root.templates, {
                                name: root.tplEditName,
                                language: root.tplEditLang || "markdown",
                                content: root.tplEditContent
                              })
                            }
                            root.saveTemplates()
                            root.tplEditId = ""
                            root.tplEditName = ""
                            root.tplEditContent = ""
                            root.tplEditLang = "markdown"
                          }
                        }
                      }

                      Rectangle {
                        visible: root.tplEditId !== ""
                        height: Style.space(30)
                        width: cancelTplTxt.implicitWidth + Style.space(16)
                        radius: Style.space(5)
                        color: cancelTplMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.12)

                        Text {
                          id: cancelTplTxt
                          text: "Cancel"
                          color: root.fg
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8.5)
                          anchors.centerIn: parent
                        }

                        MouseArea {
                          id: cancelTplMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.tplEditId = ""
                            root.tplEditName = ""
                            root.tplEditContent = ""
                            root.tplEditLang = "markdown"
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 3: CONFIGURED TEMPLATES LIBRARY
                Rectangle {
                  width: parent.width
                  height: cardTplLibCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardTplLibCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰆒"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text {
                          text: "Configured Library (" + root.templates.length + ")"
                          color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true
                        }
                        Text {
                          text: "Evaluate placeholders on copy or instantiate directly into snippets"
                          color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8)
                        }
                      }
                    }

                    // Empty State
                    Rectangle {
                      visible: root.templates.length === 0
                      width: parent.width
                      height: Style.space(48)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.02)
                      border.width: 1
                      border.color: Util.alpha(root.fg, 0.06)

                      Text {
                        anchors.centerIn: parent
                        text: "No templates defined yet. Create your first template above."
                        color: Util.alpha(root.fg, 0.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8.5)
                      }
                    }

                    // Templates List
                    Repeater {
                      model: root.templates

                      Rectangle {
                        id: tplRowDelegate
                        required property var modelData
                        readonly property var tplItem: modelData || {}
                        width: parent.width
                        height: tplItemInnerCol.implicitHeight + Style.space(16)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.035)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.08)

                        Column {
                          id: tplItemInnerCol
                          anchors.fill: parent
                          anchors.margins: Style.space(8)
                          spacing: Style.space(6)

                          // Top row: Name, Language Badge, Edit/Delete
                          Item {
                            width: parent.width
                            height: Style.space(24)

                            Row {
                              anchors.left: parent.left
                              anchors.right: tplRowBtns.left
                              anchors.rightMargin: Style.space(8)
                              anchors.verticalCenter: parent.verticalCenter
                              spacing: Style.space(6)

                              Text {
                                text: tplRowDelegate.tplItem.name || ""
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(9)
                                font.bold: true
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                              }

                              Rectangle {
                                height: Style.space(16)
                                width: tplBadgeTxt.implicitWidth + Style.space(8)
                                radius: Style.space(3)
                                color: Util.alpha(Color.accent, 0.14)
                                border.width: 1
                                border.color: Util.alpha(Color.accent, 0.3)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                  id: tplBadgeTxt
                                  text: (tplRowDelegate.tplItem.language || "text").toUpperCase()
                                  color: Color.accent
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.space(7)
                                  font.bold: true
                                  anchors.centerIn: parent
                                }
                              }
                            }

                            Row {
                              id: tplRowBtns
                              anchors.right: parent.right
                              anchors.verticalCenter: parent.verticalCenter
                              spacing: Style.space(4)

                              // Edit Button
                              Rectangle {
                                height: Style.space(22); width: Style.space(22); radius: Style.space(4)
                                color: Util.alpha(root.fg, 0.06)
                                Text { text: "✏"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                                MouseArea {
                                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var t2 = tplRowDelegate.tplItem
                                    root.tplEditId = t2.id
                                    root.tplEditName = t2.name
                                    root.tplEditLang = t2.language || "markdown"
                                    root.tplEditContent = t2.content
                                  }
                                }
                              }

                              // Delete Button
                              Rectangle {
                                height: Style.space(22); width: Style.space(22); radius: Style.space(4)
                                color: Util.alpha(Color.urgent, 0.12)
                                Text { text: "🗑"; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                                MouseArea {
                                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    root.templates = TemplateEngine.deleteTemplate(root.templates, tplRowDelegate.tplItem.id)
                                    root.saveTemplates()
                                  }
                                }
                              }
                            }
                          }

                          // Content snippet preview box
                          Rectangle {
                            width: parent.width
                            height: Math.min(Style.space(38), tplPrevTxt.implicitHeight + Style.space(8))
                            radius: Style.space(4)
                            color: Util.alpha(root.fg, 0.03)
                            border.width: 1
                            border.color: Util.alpha(root.fg, 0.05)

                            Text {
                              id: tplPrevTxt
                              anchors.fill: parent
                              anchors.margins: Style.space(4)
                              text: (tplRowDelegate.tplItem.content || "").trim()
                              color: Util.alpha(root.fg, 0.6)
                              font.family: "monospace"
                              font.pixelSize: Style.space(7.5)
                              elide: Text.ElideRight
                              wrapMode: Text.Wrap
                            }
                          }

                          // Action Chips Row (Copy Expanded + Instantiate as Snippet)
                          Flow {
                            width: parent.width
                            spacing: Style.space(6)

                            // Copy Expanded Button
                            Rectangle {
                              height: Style.space(24)
                              width: copyTplTxt.implicitWidth + Style.space(12)
                              radius: Style.space(4)
                              color: copyTplMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.15)
                              border.width: 1
                              border.color: Color.accent

                              Row {
                                id: copyTplTxt
                                anchors.centerIn: parent
                                spacing: Style.space(4)
                                Text { text: "󰆒"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Copy Expanded"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                              }

                              MouseArea {
                                id: copyTplMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  var t = tplRowDelegate.tplItem
                                  if (TemplateEngine.hasCustomVariables(t.content)) {
                                    root.openVariablePrompt(t.name, t.content, false)
                                  } else {
                                    var expanded = TemplateEngine.expand(t.content || "", {}, root.getLatestClipboardText())
                                    root.copyText(expanded)
                                  }
                                }
                              }
                            }

                            // Instantiate as Snippet Button
                            Rectangle {
                              height: Style.space(24)
                              width: makeSnipTxt.implicitWidth + Style.space(12)
                              radius: Style.space(4)
                              color: makeSnipMouse.containsMouse ? Util.alpha(root.fg, 0.12) : Util.alpha(root.fg, 0.06)
                              border.width: 1
                              border.color: Util.alpha(root.fg, 0.1)

                              Row {
                                id: makeSnipTxt
                                anchors.centerIn: parent
                                spacing: Style.space(4)
                                Text { text: "󰅩"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "+ Add to Snippets"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                              }

                              MouseArea {
                                id: makeSnipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  var t = tplRowDelegate.tplItem
                                  root.snippets = SnippetLib.addSnippet(root.snippets, {
                                    title: t.name,
                                    language: t.language || "text",
                                    content: t.content,
                                    folder: "Templates"
                                  })
                                  root.saveSnippets()
                                  root.rebuildDisplay()
                                  Quickshell.execDetached(["notify-send", "-a", "ReClip", "Snippet Created", "Added '" + t.name + "' to Snippets"])
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

              // SECTION 5: KEYBINDINGS & SHORTCUTS (ACTIVE SECTION 4)
              Column {
                id: secShortcutsCol
                visible: root.settingsActiveSection === 4
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                function splitKeys(combo) {
                  if (!combo) return []
                  var raw = combo.split("+")
                  var res = []
                  for (var i = 0; i < raw.length; i++) {
                    var s = raw[i].trim()
                    if (s.length > 0) res.push(s)
                  }
                  return res
                }

                function formatKey(k) {
                  var u = k.trim().toUpperCase()
                  if (u === "SUPER") return "󰘳 Super"
                  if (u === "SHIFT") return "󰘶 Shift"
                  if (u === "CTRL" || u === "CONTROL") return "󰘵 Ctrl"
                  if (u === "ALT") return "󰘴 Alt"
                  if (u === "SPACE") return "Space"
                  return k.trim()
                }

                // Top Overview & Hyprland Status Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(42)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.035)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(26); height: Style.space(26); radius: Style.space(6)
                      color: Util.alpha(Color.accent, 0.15)
                      anchors.verticalCenter: parent.verticalCenter
                      Text { text: "󰌌"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(130)

                      Text {
                        text: "Hyprland Global Hotkeys"
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: "Configured in ~/.config/hypr/bindings.lua • Synced live via hyprctl"
                        color: Util.alpha(root.fg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // Live Synced Badge
                    Rectangle {
                      height: Style.space(22)
                      width: syncBadgeRow.implicitWidth + Style.space(12)
                      radius: Style.space(11)
                      color: Util.alpha("#22c55e", 0.12)
                      border.width: 1
                      border.color: Util.alpha("#22c55e", 0.3)
                      anchors.verticalCenter: parent.verticalCenter

                      Row {
                        id: syncBadgeRow
                        anchors.centerIn: parent
                        spacing: Style.space(5)
                        Rectangle {
                          width: Style.space(6); height: Style.space(6); radius: Style.space(3)
                          color: "#22c55e"
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: "Synced"
                          color: "#22c55e"
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 1: TOGGLE RECLIP PANEL SHORTCUT
                Rectangle {
                  width: parent.width
                  height: card1Col.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: card1Col
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header
                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰅍"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Toggle ReClip Window"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Global hotkey to summon or dismiss the clipboard manager"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Active Combination Keycaps Box
                    Rectangle {
                      width: parent.width
                      height: Style.space(36)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: Util.alpha(root.fg, 0.08)

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(8)

                        Text {
                          text: "Active Hotkey:"
                          color: Util.alpha(root.fg, 0.6)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8.5)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        // Keycaps list
                        Row {
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(4)

                          Repeater {
                            model: secShortcutsCol.splitKeys(root.settingsToggleShortcut)
                            Row {
                              spacing: Style.space(4)
                              Rectangle {
                                height: Style.space(22)
                                width: tglKeyTxt.implicitWidth + Style.space(10)
                                radius: Style.space(4)
                                color: Util.alpha(Color.accent, 0.15)
                                border.width: 1
                                border.color: Util.alpha(Color.accent, 0.4)
                                Text {
                                  id: tglKeyTxt
                                  text: secShortcutsCol.formatKey(modelData)
                                  color: Color.accent
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.space(8)
                                  font.bold: true
                                  anchors.centerIn: parent
                                }
                              }
                              Text {
                                visible: index < secShortcutsCol.splitKeys(root.settingsToggleShortcut).length - 1
                                text: "+"
                                color: Util.alpha(root.fg, 0.4)
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(8.5)
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                              }
                            }
                          }
                        }
                      }
                    }

                    // Presets
                    Column {
                      width: parent.width
                      spacing: Style.space(5)

                      Text { text: "Quick Presets:"; color: Util.alpha(root.fg, 0.6); font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }

                      Flow {
                        width: parent.width
                        spacing: Style.space(6)

                        Repeater {
                          model: [
                            { val: "SUPER + SHIFT + V", label: "SUPER + SHIFT + V (Default)" },
                            { val: "SUPER + V", label: "SUPER + V" },
                            { val: "SUPER + ALT + V", label: "SUPER + ALT + V" },
                            { val: "CTRL + ALT + V", label: "CTRL + ALT + V" },
                            { val: "SUPER + SPACE", label: "SUPER + SPACE" }
                          ]

                          Rectangle {
                            required property var modelData
                            height: Style.space(26)
                            width: tglScTxt.implicitWidth + Style.space(14)
                            radius: Style.space(5)
                            property bool isSelected: root.settingsToggleShortcut === modelData.val
                            color: isSelected ? Color.accent : (pMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                            border.width: 1
                            border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                            Text {
                              id: tglScTxt
                              text: parent.modelData.label
                              color: parent.isSelected ? "#FFFFFF" : root.fg
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(8.5)
                              font.bold: parent.isSelected
                              anchors.centerIn: parent
                            }

                            MouseArea {
                              id: pMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.settingsToggleShortcut = parent.modelData.val
                                root.saveSettings()
                              }
                            }
                          }
                        }
                      }
                    }

                    // Custom Hotkey Input Box
                    Rectangle {
                      width: parent.width
                      height: Style.space(34)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: toggleShortcutInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                      Binding {
                        target: toggleShortcutInput
                        property: "text"
                        value: root.settingsToggleShortcut
                        when: !toggleShortcutInput.activeFocus
                      }

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(6)
                        spacing: Style.space(8)

                        Text {
                          text: "󰌌"
                          color: toggleShortcutInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.4)
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        TextInput {
                          id: toggleShortcutInput
                          width: parent.width - Style.space(90)
                          anchors.verticalCenter: parent.verticalCenter
                          color: root.fg
                          font.family: "monospace"
                          font.pixelSize: Style.space(9)
                          selectByMouse: true
                          text: root.settingsToggleShortcut
                          onAccepted: {
                            if (text.trim()) {
                              root.settingsToggleShortcut = text.trim()
                              root.saveSettings()
                            }
                          }

                          Text {
                            visible: toggleShortcutInput.text.trim() === "" && !toggleShortcutInput.activeFocus
                            text: "Custom combo (press Enter to apply)..."
                            color: Util.alpha(root.fg, 0.35)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }

                        Rectangle {
                          width: Style.space(48)
                          height: Style.space(24)
                          radius: Style.space(4)
                          color: Util.alpha(Color.accent, 0.15)
                          border.width: 1
                          border.color: Util.alpha(Color.accent, 0.4)
                          anchors.verticalCenter: parent.verticalCenter

                          Text {
                            text: "Apply"
                            color: Color.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            font.bold: true
                            anchors.centerIn: parent
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              if (toggleShortcutInput.text.trim()) {
                                root.settingsToggleShortcut = toggleShortcutInput.text.trim()
                                root.saveSettings()
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 2: DIRECT QUICK-PASTE SLOTS (1 TO 9)
                Rectangle {
                  width: parent.width
                  height: card2Col.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: card2Col
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header Row with Toggle Switch
                    Item {
                      width: parent.width
                      height: Math.max(qpHeaderLeft.implicitHeight, qpToggleSwitch.implicitHeight)

                      Row {
                        id: qpHeaderLeft
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                          color: Util.alpha(Color.accent, 0.12)
                          Text { text: "󰆒"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                        }

                        Column {
                          spacing: 1
                          Text { text: "Direct Quick-Paste (Clips 1–9)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                          Text { text: "Paste clipboard items directly into apps without opening ReClip"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                        }
                      }

                      // Modern Toggle Switch
                      Rectangle {
                        id: qpToggleSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(46); height: Style.space(24); radius: Style.space(12)
                        color: root.settingsEnableQuickPaste ? Color.accent : Util.alpha(root.fg, 0.16)
                        border.width: 1
                        border.color: root.settingsEnableQuickPaste ? Color.accent : Util.alpha(root.fg, 0.12)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                          width: Style.space(18); height: Style.space(18); radius: Style.space(9)
                          color: "#FFFFFF"
                          anchors.verticalCenter: parent.verticalCenter
                          x: root.settingsEnableQuickPaste ? (parent.width - width - Style.space(3)) : Style.space(3)
                          Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.settingsEnableQuickPaste = !root.settingsEnableQuickPaste
                            root.saveSettings()
                          }
                        }
                      }
                    }

                    // Disabled Notice
                    Rectangle {
                      visible: !root.settingsEnableQuickPaste
                      width: parent.width
                      height: Style.space(32)
                      radius: Style.space(6)
                      color: Util.alpha(root.fg, 0.025)
                      border.width: 1
                      border.color: Util.alpha(root.fg, 0.06)

                      Text {
                        text: "Quick-paste is currently disabled. Toggle the switch above to activate."
                        color: Util.alpha(root.fg, 0.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8.5)
                        anchors.centerIn: parent
                      }
                    }

                    // Enabled Content Body
                    Column {
                      visible: root.settingsEnableQuickPaste
                      width: parent.width
                      height: visible ? implicitHeight : 0
                      spacing: Style.space(10)

                      // Active Modifiers Keycaps Box
                      Rectangle {
                        width: parent.width
                        height: Style.space(36)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.04)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.08)

                        Row {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(10)
                          anchors.rightMargin: Style.space(10)
                          spacing: Style.space(8)

                          Text {
                            text: "Active Modifiers:"
                            color: Util.alpha(root.fg, 0.6)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8.5)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                          }

                          Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)

                            Repeater {
                              model: secShortcutsCol.splitKeys(root.settingsPasteModifiers)
                              Row {
                                spacing: Style.space(4)
                                Rectangle {
                                  height: Style.space(22)
                                  width: modKeyTxt.implicitWidth + Style.space(10)
                                  radius: Style.space(4)
                                  color: Util.alpha(Color.accent, 0.15)
                                  border.width: 1
                                  border.color: Util.alpha(Color.accent, 0.4)
                                  Text {
                                    id: modKeyTxt
                                    text: secShortcutsCol.formatKey(modelData)
                                    color: Color.accent
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.space(8)
                                    font.bold: true
                                    anchors.centerIn: parent
                                  }
                                }
                                Text {
                                  visible: index < secShortcutsCol.splitKeys(root.settingsPasteModifiers).length - 1
                                  text: "+"
                                  color: Util.alpha(root.fg, 0.4)
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.space(8.5)
                                  font.bold: true
                                  anchors.verticalCenter: parent.verticalCenter
                                }
                              }
                            }
                          }
                        }
                      }

                      // Presets
                      Column {
                        width: parent.width
                        spacing: Style.space(5)

                        Text { text: "Modifier Presets:"; color: Util.alpha(root.fg, 0.6); font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true }

                        Flow {
                          width: parent.width
                          spacing: Style.space(6)

                          Repeater {
                            model: [
                              { val: "SUPER + CTRL + SHIFT", label: "SUPER + CTRL + SHIFT (Default)" },
                              { val: "SUPER + ALT", label: "SUPER + ALT" },
                              { val: "SUPER + CTRL", label: "SUPER + CTRL" },
                              { val: "CTRL + ALT", label: "CTRL + ALT" },
                              { val: "ALT + SHIFT", label: "ALT + SHIFT" }
                            ]

                            Rectangle {
                              required property var modelData
                              height: Style.space(26)
                              width: qpModTxt.implicitWidth + Style.space(14)
                              radius: Style.space(5)
                              property bool isSelected: root.settingsPasteModifiers === modelData.val
                              color: isSelected ? Color.accent : (qpMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04))
                              border.width: 1
                              border.color: isSelected ? Color.accent : Util.alpha(root.fg, 0.1)

                              Text {
                                id: qpModTxt
                                text: parent.modelData.label
                                color: parent.isSelected ? "#FFFFFF" : root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(8.5)
                                font.bold: parent.isSelected
                                anchors.centerIn: parent
                              }

                              MouseArea {
                                id: qpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  root.settingsPasteModifiers = parent.modelData.val
                                  root.saveSettings()
                                }
                              }
                            }
                          }
                        }
                      }

                      // Custom Modifiers Input Box
                      Rectangle {
                        width: parent.width
                        height: Style.space(34)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.04)
                        border.width: 1
                        border.color: pasteModifiersInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.12)

                        Binding {
                          target: pasteModifiersInput
                          property: "text"
                          value: root.settingsPasteModifiers
                          when: !pasteModifiersInput.activeFocus
                        }

                        Row {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(10)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(8)

                          Text {
                            text: "󰌌"
                            color: pasteModifiersInput.activeFocus ? Color.accent : Util.alpha(root.fg, 0.4)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            anchors.verticalCenter: parent.verticalCenter
                          }

                          TextInput {
                            id: pasteModifiersInput
                            width: parent.width - Style.space(90)
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.fg
                            font.family: "monospace"
                            font.pixelSize: Style.space(9)
                            selectByMouse: true
                            text: root.settingsPasteModifiers
                            onAccepted: {
                              if (text.trim()) {
                                root.settingsPasteModifiers = text.trim()
                                root.saveSettings()
                              }
                            }

                            Text {
                              visible: pasteModifiersInput.text.trim() === "" && !pasteModifiersInput.activeFocus
                              text: "Custom modifiers (e.g. SUPER + ALT)..."
                              color: Util.alpha(root.fg, 0.35)
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(8.5)
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }

                          Rectangle {
                            width: Style.space(48)
                            height: Style.space(24)
                            radius: Style.space(4)
                            color: Util.alpha(Color.accent, 0.15)
                            border.width: 1
                            border.color: Util.alpha(Color.accent, 0.4)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              text: "Apply"
                              color: Color.accent
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(8.5)
                              font.bold: true
                              anchors.centerIn: parent
                            }

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                if (pasteModifiersInput.text.trim()) {
                                  root.settingsPasteModifiers = pasteModifiersInput.text.trim()
                                  root.saveSettings()
                                }
                              }
                            }
                          }
                        }
                      }

                      // Visual Slots Matrix Header
                      Text {
                        text: "Direct Slots Mapping (Instant Paste):"
                        color: Util.alpha(root.fg, 0.6)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8.5)
                        font.bold: true
                      }

                      // 3x3 Slots Grid
                      Grid {
                        width: parent.width
                        columns: 3
                        spacing: Style.space(6)

                        Repeater {
                          model: 9
                          Rectangle {
                            width: (parent.width - Style.space(12)) / 3
                            height: Style.space(40)
                            radius: Style.space(6)
                            color: Util.alpha(root.fg, 0.035)
                            border.width: 1
                            border.color: Util.alpha(root.fg, 0.08)

                            Row {
                              anchors.fill: parent
                              anchors.margins: Style.space(6)
                              spacing: Style.space(6)

                              Rectangle {
                                height: Style.space(22)
                                width: Style.space(22)
                                radius: Style.space(4)
                                color: Util.alpha(Color.accent, 0.15)
                                border.width: 1
                                border.color: Util.alpha(Color.accent, 0.35)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                  text: "" + (index + 1)
                                  color: Color.accent
                                  font.family: "monospace"
                                  font.pixelSize: Style.space(9)
                                  font.bold: true
                                  anchors.centerIn: parent
                                }
                              }

                              Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                width: parent.width - Style.space(32)

                                Text {
                                  text: "Clip #" + (index + 1)
                                  color: root.fg
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.space(8.5)
                                  font.bold: true
                                }

                                Text {
                                  property var clipItem: (root.history && root.history.length > index) ? root.history[index] : null
                                  text: clipItem ? (clipItem.text ? clipItem.text.replace(/[\r\n\t]+/g, " ").trim() : "Image / Media") : "Empty slot"
                                  color: Util.alpha(root.fg, clipItem ? 0.55 : 0.28)
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.space(7.5)
                                  elide: Text.ElideRight
                                  width: parent.width
                                }
                              }
                            }
                          }
                        }
                      }

                      // Universal Hardware Keycode Note Banner
                      Rectangle {
                        width: parent.width
                        height: Style.space(30)
                        radius: Style.space(6)
                        color: Util.alpha(root.fg, 0.025)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.06)

                        Row {
                          anchors.centerIn: parent
                          spacing: Style.space(6)

                          Text {
                            text: "󰌌"
                            color: Color.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          Text {
                            text: "Universal hardware keycodes code:10..18 support all keyboard layouts"
                            color: Util.alpha(root.fg, 0.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 3: HYPRLAND ACTIONS & SYNC
                Rectangle {
                  width: parent.width
                  height: card3Col.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: card3Col
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    // Header Row
                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰑐"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Hyprland Configuration & Actions"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Apply hotkey changes immediately or restore factory defaults"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Action Buttons Row
                    Row {
                      spacing: Style.space(10)

                      // Primary Apply Button
                      Rectangle {
                        height: Style.space(32)
                        width: applyBindsTxt.implicitWidth + Style.space(22)
                        radius: Style.space(6)
                        color: applyMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                        Row {
                          id: applyBindsTxt
                          anchors.centerIn: parent
                          spacing: Style.space(6)
                          Text { text: "󰑐"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Apply & Reload Hyprland"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                          id: applyMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.syncKeybindingsWithNotify()
                        }
                      }

                      // Secondary Reset Button
                      Rectangle {
                        height: Style.space(32)
                        width: resetBindsTxt.implicitWidth + Style.space(20)
                        radius: Style.space(6)
                        color: resetMouse.containsMouse ? Util.alpha(root.fg, 0.08) : Util.alpha(root.fg, 0.04)
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.12)

                        Row {
                          id: resetBindsTxt
                          anchors.centerIn: parent
                          spacing: Style.space(6)
                          Text { text: "󰦛"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Reset Defaults"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                          id: resetMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.settingsToggleShortcut = "SUPER + SHIFT + V"
                            root.settingsPasteModifiers = "SUPER + CTRL + SHIFT"
                            root.settingsEnableQuickPaste = true
                            root.syncKeybindingsWithNotify()
                          }
                        }
                      }
                    }
                  }
                }
              }

              // SECTION 6: BACKUP & SYSTEM ARCHITECTURE (ACTIVE SECTION 5)
              Column {
                id: secBackupCol
                visible: root.settingsActiveSection === 5
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                // Top Section Overview Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(52)
                  radius: Style.space(8)
                  color: Util.alpha(Color.accent, 0.08)
                  border.width: 1
                  border.color: Util.alpha(Color.accent, 0.25)

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(32)
                      height: Style.space(32)
                      radius: Style.space(8)
                      color: Util.alpha(Color.accent, 0.16)
                      anchors.verticalCenter: parent.verticalCenter
                      Text { text: "💾"; font.pixelSize: Style.space(12); anchors.centerIn: parent }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(140)

                      Text {
                        text: "Backup & System Architecture"
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: "Export JSON archives, inspect persistent storage, and review architecture"
                        color: Util.alpha(root.fg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // System Active Badge
                    Rectangle {
                      height: Style.space(22)
                      width: sysStatTxt.implicitWidth + Style.space(12)
                      radius: Style.space(11)
                      color: Util.alpha("#22c55e", 0.12)
                      border.width: 1
                      border.color: Util.alpha("#22c55e", 0.3)
                      anchors.verticalCenter: parent.verticalCenter

                      Row {
                        id: sysStatTxt
                        anchors.centerIn: parent
                        spacing: Style.space(5)
                        Rectangle {
                          width: Style.space(6); height: Style.space(6); radius: Style.space(3)
                          color: "#22c55e"
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: "Active"
                          color: "#22c55e"
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(8)
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }

                // CARD 1: DATABASE EXPORT & ARCHIVE
                Rectangle {
                  width: parent.width
                  height: cardExportCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardExportCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰍉"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Export Database Snapshot"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Creates a complete portable JSON archive of your clipboard history and metadata"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Target Archive Location preview
                    Rectangle {
                      width: parent.width
                      height: Style.space(32)
                      radius: Style.space(5)
                      color: Util.alpha(root.fg, 0.04)
                      border.width: 1
                      border.color: Util.alpha(root.fg, 0.08)

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(8)

                        Text {
                          text: "󰈔"
                          color: Util.alpha(root.fg, 0.45)
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(9)
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                          text: "~/reclip-backup-" + new Date().toISOString().substring(0, 10) + ".json"
                          color: root.fg
                          font.family: "monospace"
                          font.pixelSize: Style.space(8)
                          elide: Text.ElideRight
                          width: parent.width - Style.space(40)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }

                    // Export Trigger Row
                    Row {
                      spacing: Style.space(10)

                      Rectangle {
                        height: Style.space(32)
                        width: exportBtnTxt.implicitWidth + Style.space(22)
                        radius: Style.space(6)
                        color: exportMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                        Row {
                          id: exportBtnTxt
                          anchors.centerIn: parent
                          spacing: Style.space(6)
                          Text { text: "󰍉"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Export JSON Backup"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                          id: exportMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.exportBackupJson()
                        }
                      }

                      Text {
                        text: "Clips, favorites, pinned status, and colors are preserved"
                        color: Util.alpha(root.fg, 0.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }
                }

                // CARD 2: STORAGE PATHS & CONFIGURATION
                Rectangle {
                  width: parent.width
                  height: cardStorageCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardStorageCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰉋"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "Persistent Storage Paths"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "Filesystem paths for database state, snippets, templates, and hotkeys"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Paths List
                    Column {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { name: "Clipboard History DB", path: "~/.local/state/reclip/clipboard-history.json", type: "JSON DB", icon: "󰆒" },
                          { name: "Custom Snippets & Folders", path: "~/.local/state/reclip/snippets.json", type: "JSON DB", icon: "󰅩" },
                          { name: "Dynamic Templates Library", path: "~/.local/state/reclip/templates.json", type: "JSON DB", icon: "📑" },
                          { name: "Hyprland Shortcut Bindings", path: "~/.config/hypr/bindings.lua", type: "LUA BIND", icon: "󰌌" }
                        ]

                        Rectangle {
                          required property var modelData
                          width: parent.width
                          height: Style.space(38)
                          radius: Style.space(5)
                          color: Util.alpha(root.fg, 0.035)
                          border.width: 1
                          border.color: Util.alpha(root.fg, 0.06)

                          Row {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            spacing: Style.space(8)

                            Text {
                              text: parent.parent.modelData.icon
                              color: Color.accent
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(9)
                              anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                              anchors.verticalCenter: parent.verticalCenter
                              spacing: 1
                              width: parent.width - Style.space(90)

                              Text {
                                text: parent.parent.parent.modelData.name
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(8.5)
                                font.bold: true
                              }
                              Text {
                                text: parent.parent.parent.modelData.path
                                color: Util.alpha(root.fg, 0.5)
                                font.family: "monospace"
                                font.pixelSize: Style.space(7.5)
                                elide: Text.ElideRight
                                width: parent.width
                              }
                            }

                            Rectangle {
                              height: Style.space(18)
                              width: typeTxt.implicitWidth + Style.space(8)
                              radius: Style.space(3)
                              color: Util.alpha(root.fg, 0.06)
                              border.width: 1
                              border.color: Util.alpha(root.fg, 0.1)
                              anchors.verticalCenter: parent.verticalCenter

                              Text {
                                id: typeTxt
                                text: parent.parent.parent.modelData.type
                                color: Util.alpha(root.fg, 0.7)
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(7)
                                font.bold: true
                                anchors.centerIn: parent
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // CARD 3: RUNTIME & SYSTEM ARCHITECTURE
                Rectangle {
                  width: parent.width
                  height: cardArchCol.implicitHeight + Style.space(24)
                  radius: Style.space(8)
                  color: Util.alpha(root.fg, 0.03)
                  border.width: 1
                  border.color: Util.alpha(root.fg, 0.08)

                  Column {
                    id: cardArchCol
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Row {
                      spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(28); height: Style.space(28); radius: Style.space(6)
                        color: Util.alpha(Color.accent, 0.12)
                        Text { text: "󰅍"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.centerIn: parent }
                      }
                      Column {
                        spacing: 1
                        Text { text: "ReClip Omarchy Edition • v1.1"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(10.5); font.bold: true }
                        Text { text: "High-performance Wayland native clipboard management suite"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(8) }
                      }
                    }

                    // Architecture Highlights Grid (2x2 Flow)
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: [
                          { title: "Wayland Native", desc: "Direct wl-paste & wl-copy daemon synchronization", icon: "󰍹" },
                          { title: "Quickshell Layer", desc: "Zero overhead Wayland layer-shell hardware rendering", icon: "⚡" },
                          { title: "Zero Telemetry", desc: "100% offline local operation without external network calls", icon: "🔒" },
                          { title: "Color Studio", desc: "Real-time automated palette extraction from clipboard media", icon: "🎨" }
                        ]

                        Rectangle {
                          required property var modelData
                          width: (parent.width - Style.space(6)) / 2
                          height: Style.space(48)
                          radius: Style.space(6)
                          color: Util.alpha(root.fg, 0.035)
                          border.width: 1
                          border.color: Util.alpha(root.fg, 0.06)

                          Row {
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            spacing: Style.space(6)

                            Text {
                              text: parent.parent.modelData.icon
                              color: Color.accent
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(11)
                              anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                              anchors.verticalCenter: parent.verticalCenter
                              spacing: 1
                              width: parent.width - Style.space(24)

                              Text {
                                text: parent.parent.parent.modelData.title
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(8.5)
                                font.bold: true
                              }
                              Text {
                                text: parent.parent.parent.modelData.desc
                                color: Util.alpha(root.fg, 0.5)
                                font.family: root.fontFamily
                                font.pixelSize: Style.space(7.5)
                                elide: Text.ElideRight
                                width: parent.width
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // SECTION 7: SYSTEM DEPENDENCIES & HEALTH CHECK (ACTIVE SECTION 6)
              Column {
                id: secDepsCol
                visible: root.settingsActiveSection === 6
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                // Top Health Status Banner
                Rectangle {
                  width: parent.width
                  height: Style.space(56)
                  radius: Style.space(8)
                  color: root.missingPackagesList.length === 0 ? Util.alpha("#22C55E", 0.09) : Util.alpha("#F59E0B", 0.12)
                  border.width: 1
                  border.color: root.missingPackagesList.length === 0 ? Util.alpha("#22C55E", 0.3) : Util.alpha("#F59E0B", 0.4)

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(10)

                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(34)
                      radius: Style.space(8)
                      color: root.missingPackagesList.length === 0 ? Util.alpha("#22C55E", 0.2) : Util.alpha("#F59E0B", 0.25)
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        text: root.missingPackagesList.length === 0 ? "✓" : "⚠"
                        color: root.missingPackagesList.length === 0 ? "#22C55E" : "#F59E0B"
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(13)
                        font.bold: true
                        anchors.centerIn: parent
                      }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1
                      width: parent.width - Style.space(220)

                      Text {
                        text: root.missingPackagesList.length === 0 ? ("All System Dependencies Active (" + root.installedDepsCount + "/" + root.totalDepsCount + ")") : (root.missingPackagesList.length + " Missing Packages Detected")
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(10)
                        font.bold: true
                      }
                      Text {
                        text: root.missingPackagesList.length === 0 ? "Every tool, library, and daemon required for ReClip is installed and working." : ("Missing: " + root.missingPackagesList.join(", "))
                        color: Util.alpha(root.fg, 0.6)
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8)
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    // Action Buttons in Banner
                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Rectangle {
                        visible: root.missingPackagesList.length > 0
                        height: Style.space(26)
                        width: bannerInstTxt.implicitWidth + Style.space(14)
                        radius: Style.space(5)
                        color: Color.accent

                        Row {
                          id: bannerInstTxt
                          anchors.centerIn: parent; spacing: Style.space(4)
                          Text { text: "󰐥"; color: "#FFFFFF"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Install All"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.installMissingDependencies()
                        }
                      }

                      Rectangle {
                        height: Style.space(26)
                        width: bannerCopyTxt.implicitWidth + Style.space(12)
                        radius: Style.space(5)
                        color: Util.alpha(root.fg, 0.08)
                        border.width: 1; border.color: Util.alpha(root.fg, 0.15)

                        Row {
                          id: bannerCopyTxt
                          anchors.centerIn: parent; spacing: Style.space(4)
                          Text { text: "󰆏"; color: root.fg; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                          Text { text: "Copy Command"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.copyInstallCommand()
                        }
                      }
                    }
                  }
                }

                // Dependency Cards List
                Column {
                  width: parent.width
                  spacing: Style.space(6)

                  Repeater {
                    model: root.systemDependencies

                    Rectangle {
                      required property var modelData
                      width: parent.width
                      height: Style.space(40)
                      radius: Style.space(6)
                      color: modelData.installed ? Util.alpha(root.fg, 0.02) : Util.alpha("#F59E0B", 0.08)
                      border.width: 1
                      border.color: modelData.installed ? Util.alpha(root.fg, 0.06) : Util.alpha("#F59E0B", 0.35)

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(8)

                        // Status Icon
                        Rectangle {
                          width: Style.space(24); height: Style.space(24); radius: Style.space(5)
                          color: parent.parent.modelData.installed ? Util.alpha("#22C55E", 0.15) : Util.alpha("#F59E0B", 0.2)
                          anchors.verticalCenter: parent.verticalCenter
                          Text {
                            text: parent.parent.parent.modelData.installed ? "✓" : "✕"
                            color: parent.parent.parent.modelData.installed ? "#22C55E" : "#F59E0B"
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(9)
                            font.bold: true
                            anchors.centerIn: parent
                          }
                        }

                        // Info Column
                        Column {
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 1
                          width: parent.width - Style.space(160)

                          Row {
                            spacing: Style.space(6)
                            Text {
                              text: parent.parent.parent.parent.modelData.name
                              color: root.fg
                              font.family: root.fontFamily
                              font.pixelSize: Style.space(9)
                              font.bold: true
                            }
                            Rectangle {
                              height: Style.space(14)
                              width: pkgChipTxt.implicitWidth + Style.space(8)
                              radius: Style.space(3)
                              color: Util.alpha(root.fg, 0.06)
                              anchors.verticalCenter: parent.verticalCenter
                              Text {
                                id: pkgChipTxt
                                text: parent.parent.parent.parent.parent.modelData.package
                                color: Util.alpha(root.fg, 0.7)
                                font.family: "monospace"
                                font.pixelSize: Style.space(7)
                                anchors.centerIn: parent
                              }
                            }
                          }

                          Text {
                            text: parent.parent.parent.modelData.desc
                            color: Util.alpha(root.fg, 0.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(7.5)
                            elide: Text.ElideRight
                            width: parent.width
                          }
                        }

                        // Status Chip / Action
                        Rectangle {
                          height: Style.space(20)
                          width: statChipTxt.implicitWidth + Style.space(12)
                          radius: Style.space(4)
                          color: parent.parent.modelData.installed ? Util.alpha("#22C55E", 0.15) : Color.accent
                          anchors.verticalCenter: parent.verticalCenter

                          Text {
                            id: statChipTxt
                            text: parent.parent.parent.modelData.installed ? "Installed" : "Install"
                            color: parent.parent.parent.modelData.installed ? "#22C55E" : "#FFFFFF"
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(7.5)
                            font.bold: true
                            anchors.centerIn: parent
                          }

                          MouseArea {
                            anchors.fill: parent
                            enabled: !parent.parent.parent.modelData.installed
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                              var pkg = parent.parent.parent.modelData.package
                              var cmd = "sudo pacman -S --needed " + pkg
                              var launcher = "omarchy-launch-floating-terminal-with-presentation"
                              Quickshell.execDetached(["sh", "-c", launcher + " " + Util.shellQuote(cmd)])
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
      // -------------------------------------------------------------
      // TWO-TIER UNIFIED SETTINGS FOOTER
      // -------------------------------------------------------------
      Rectangle {
        id: settingsFooterBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(56)
        radius: Style.space(8)
        color: Util.alpha(root.fg, 0.04)
        border.width: 1
        border.color: Util.alpha(root.fg, 0.08)
        clip: true

        Column {
          anchors.fill: parent
          spacing: 0

          // Row 1: Actions & Preferences Identity (Height: 32px)
          Item {
            width: parent.width
            height: Style.space(32)

            // Left: Settings badge
            Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(22)
              width: setBadgeContent.implicitWidth + Style.space(14)
              radius: Style.space(5)
              color: Util.alpha(Color.accent, 0.12)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.25)

              Row {
                id: setBadgeContent
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: "󰒓"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Preferences"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(9.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
              }
            }

            // Right: Primary Close / Done Action
            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              // Quick action if in Backup section
              Rectangle {
                visible: root.settingsActiveSection === 5
                height: Style.space(24)
                width: expBtnContent.implicitWidth + Style.space(12)
                radius: Style.space(5)
                color: Util.alpha(Color.accent, 0.15)
                border.width: 1
                border.color: Color.accent

                Row {
                  id: expBtnContent
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: "💾"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                  Text { text: "Export JSON"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.exportBackupJson()
                }
              }

              // Quick action if in System Dependencies section
              Rectangle {
                visible: root.settingsActiveSection === 6
                height: Style.space(24)
                width: instBtnContent.implicitWidth + Style.space(12)
                radius: Style.space(5)
                color: root.missingPackagesList.length > 0 ? Color.accent : Util.alpha(Color.accent, 0.15)
                border.width: 1
                border.color: Color.accent

                Row {
                  id: instBtnContent
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: root.missingPackagesList.length > 0 ? "󰐥" : "󰑮"; color: root.missingPackagesList.length > 0 ? "#FFFFFF" : Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                  Text { text: root.missingPackagesList.length > 0 ? ("Install Missing (" + root.missingPackagesList.length + ")") : "Refresh Status"; color: root.missingPackagesList.length > 0 ? "#FFFFFF" : Color.accent; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.missingPackagesList.length > 0) root.installMissingDependencies()
                    else root.checkDependencies()
                  }
                }
              }

              // Close / Done Button
              Rectangle {
                height: Style.space(24)
                width: closeSetTxt.implicitWidth + Style.space(16)
                radius: Style.space(5)
                color: closeSetMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                Row {
                  id: closeSetTxt
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: "󰅖"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                  Text { text: "Done"; color: "#FFFFFF"; font.family: root.fontFamily; font.pixelSize: Style.space(9.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  id: closeSetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.settingsOpen = false
                }
              }
            }
          }

          // Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(root.fg, 0.08)
          }

          // Row 2: Live Status & Shortcut Chips (Height: 23px)
          Rectangle {
            width: parent.width
            height: Style.space(23)
            color: Util.alpha(root.fg, 0.02)

            Item {
              anchors.fill: parent

              // Left: Section Name & Info
              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Text {
                  text: {
                    if (root.settingsActiveSection === 0) return "History Retention • Max " + root.settingsMaxClips + " clips (" + root.settingsRetainDays + " days)"
                    if (root.settingsActiveSection === 1) return "Privacy Filters • Ignore Sensitive: " + (root.settingsIgnoreSensitive ? "ON" : "OFF")
                    if (root.settingsActiveSection === 2) return "Regex Automations • " + (root.automationRules ? root.automationRules.length : 0) + " rules active"
                    if (root.settingsActiveSection === 3) return "Dynamic Templates • " + (root.templates ? root.templates.length : 0) + " templates"
                    if (root.settingsActiveSection === 4) return "Shortcut Bindings • " + root.settingsToggleShortcut
                    if (root.settingsActiveSection === 5) return "Database & Backup"
                    if (root.settingsActiveSection === 6) return "System Health • " + root.installedDepsCount + "/" + root.totalDepsCount + " dependencies active" + (root.missingPackagesList.length > 0 ? " (" + root.missingPackagesList.length + " missing)" : " (All OK)")
                    return ""
                  }
                  color: Util.alpha(root.fg, 0.55)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Right: Shortcuts
              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                // Esc Close Chip
                Row {
                  spacing: Style.space(3)
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    height: Style.space(14); width: Style.space(20); radius: Style.space(3)
                    color: Util.alpha(root.fg, 0.07)
                    border.width: 1; border.color: Util.alpha(root.fg, 0.12)
                    Text { text: "Esc"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
                  }
                  Text { text: "Close"; color: Util.alpha(root.fg, 0.5); font.family: root.fontFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                }
              }
            }
          }
        }
      }
}
