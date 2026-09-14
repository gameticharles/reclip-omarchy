import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "lib/ClipboardHistory.js" as ClipboardHistory
import "lib/SnippetLibrary.js" as SnippetLib
import "lib/SyntaxHighlight.js" as Syntax

Rectangle {
  id: root
  visible: false
  anchors.fill: parent
  color: Util.alpha(Color.popups.background || Color.background || "#1e1e2e", 0.98)
  radius: Style.cornerRadius
  z: 110

  // Root MouseArea: Absorbs all clicks on modal background so nothing ever reaches underlying views
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    onClicked: function(mouse) { mouse.accepted = true }
    onPressed: function(mouse) { mouse.accepted = true }
    onReleased: function(mouse) { mouse.accepted = true }
    onWheel: function(wheel) { wheel.accepted = true }
  }

  // Signals
  signal savedClip(int index, string content)
  signal savedSnippet(int index, string title, string content, string language, string folder, string tags)
  signal saveAsSnippetRequested(string title, string content, string language)
  signal copiedToClipboard(string content)
  signal requestScreenPick()
  signal requestColorPicker()
  signal closed()

  // Properties
  property string targetType: "clip" // "clip" or "snippet"
  property int clipIndex: -1
  property int snippetIndex: -1
  property string itemTitle: ""
  property string editorContent: ""
  property string originalContent: ""
  property string snippetTitle: ""
  property string snippetLanguage: "markdown"
  property string snippetFolder: ""
  property string snippetTags: ""
  property bool isSaveAsSnippetMode: false
  property string newSnippetTitle: ""
  property bool wrapEditorText: true

  // Typography, Font & Editor Inspector Properties
  property var systemFontFamilies: {
    var fams = (typeof Qt !== "undefined" && Qt.fontFamilies) ? Qt.fontFamilies() : []
    if (fams && fams.length > 0) {
      return fams.slice().sort(function(a, b) {
        return a.localeCompare(b)
      })
    }
    return ["monospace", "sans-serif", "serif"]
  }
  property string editorFontFamily: "monospace"
  property real editorFontSize: 10
  property bool fontPickerOpen: false
  property string fontSearchQuery: ""
  property string editorContentMode: "markdown" // "markdown", "text", "code", "rich"
  property int tabSize: 2 // 2 or 4
  property bool showLineNumbers: true
  property string currentColor: "#EF4444"
  readonly property var presetColors: ["#FFFFFF", "#94A3B8", "#EF4444", "#F97316", "#EAB308", "#22C55E", "#3B82F6", "#A855F7"]

  // View Mode: "split" (Top Source + Bottom Preview), "edit" (Source only), "preview" (Preview only)
  property string viewMode: "split"

  // Search & Replace State
  property bool searchOpen: false
  property string searchQuery: ""
  property string replaceQuery: ""
  property bool searchMatchCase: false
  property var searchMatches: []
  property int searchCurrentMatchIdx: -1

  // Preview Rendering & Code Language State
  property string codeLanguage: "javascript"
  property string renderedPreviewHtml: ""
  property int cursorLine: 1
  property int cursorCol: 1

  // Row 6: Boilerplate and Save As File State
  property bool boilerplateMenuOpen: false
  property bool saveDrawerOpen: false
  property string saveFilePath: "~/Documents/reclip_note.md"
  property var boilerplateTemplates: [
    {
      id: "bash",
      name: "Bash Script",
      icon: "🐚",
      mode: "code",
      content: "#!/usr/bin/env bash\nset -euo pipefail\n\nmain() {\n    echo \"Running $(basename \"$0\")...\"\n}\n\nmain \"$@\"\n"
    },
    {
      id: "html",
      name: "HTML5 Skeleton",
      icon: "🌐",
      mode: "code",
      content: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>Document</title>\n</head>\n<body>\n  <h1>Hello, World!</h1>\n</body>\n</html>\n"
    },
    {
      id: "python",
      name: "Python Main",
      icon: "🐍",
      mode: "code",
      content: "#!/usr/bin/env python3\n\"\"\"Module docstring.\"\"\"\n\ndef main():\n    print(\"Hello from Python!\")\n\nif __name__ == \"__main__\":\n    main()\n"
    },
    {
      id: "readme",
      name: "README Template",
      icon: "📖",
      mode: "markdown",
      content: "# Project Title\n\nA short description of the project.\n\n## Installation\n\n```bash\ngit clone https://github.com/user/project.git\ncd project\n```\n\n## Usage\n\n```bash\n./run.sh\n```\n\n## Features\n- [ ] Feature 1\n- [ ] Feature 2\n\n## License\nMIT\n"
    },
    {
      id: "changelog",
      name: "Changelog Template",
      icon: "📜",
      mode: "markdown",
      content: "# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n## [Unreleased]\n### Added\n- New feature\n\n### Fixed\n- Bug fix\n\n## [1.0.0] - 2026-09-08\n### Added\n- Initial release\n"
    },
    {
      id: "curl",
      name: "REST API cURL",
      icon: "🚀",
      mode: "code",
      content: "curl -X POST \"https://api.example.com/v1/endpoint\" \\\n  -H \"Content-Type: application/json\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -d '{\n    \"key\": \"value\"\n  }'\n"
    }
  ]

  // Feedback banner
  property string feedbackText: ""

  onEditorContentChanged: {
    if (editorInput && editorInput.text !== root.editorContent) {
      editorInput.text = root.editorContent
    }
    root.schedulePreviewUpdate()
  }
  onEditorContentModeChanged: root.schedulePreviewUpdate()
  onEditorFontSizeChanged: root.schedulePreviewUpdate()
  onEditorFontFamilyChanged: root.schedulePreviewUpdate()
  onWrapEditorTextChanged: root.schedulePreviewUpdate()

  readonly property bool isModified: editorContent !== originalContent
  readonly property color bgCol: Color.popups.background || Color.background || "#1e1e2e"
  readonly property color fgCol: Color.popups.text || Color.text || "#cdd6f4"
  readonly property color borderCol: Color.popups.border || Color.border || "#313244"
  readonly property string fontFamily: Style.font.family

  Timer {
    id: feedbackTimer
    interval: 2200
    repeat: false
    onTriggered: function() {
      root.feedbackText = ""
    }
  }

  function showFeedback(msg) {
    root.feedbackText = msg
    feedbackTimer.restart()
  }

  function openClip(index, text, title) {
    root.targetType = "clip"
    root.clipIndex = index
    root.snippetIndex = -1
    root.itemTitle = title || ("Clip #" + (index + 1))
    root.editorContent = String(text || "")
    root.originalContent = String(text || "")
    root.snippetTitle = ""
    root.snippetLanguage = "markdown"
    root.snippetFolder = ""
    root.snippetTags = ""
    root.isSaveAsSnippetMode = false
    root.newSnippetTitle = ""
    root.viewMode = "split"
    root.searchOpen = false
    root.fontPickerOpen = false
    root.feedbackText = ""
    root.cursorLine = 1
    root.cursorCol = 1

    // Auto-detect mode from content
    var trimmed = String(text || "").trim()
    if (trimmed.indexOf("<html") === 0 || trimmed.indexOf("<!DOCTYPE") === 0 || trimmed.indexOf("<div") === 0) {
      root.editorContentMode = "rich"
    } else if (trimmed.indexOf("{") === 0 || trimmed.indexOf("[") === 0 || trimmed.indexOf("function") === 0 || trimmed.indexOf("import ") === 0 || trimmed.indexOf("#!/") === 0) {
      root.editorContentMode = "code"
    } else {
      root.editorContentMode = "markdown"
    }

    root.visible = true
    if (editorInput.text !== root.editorContent) {
      editorInput.text = root.editorContent
    }
    root.updatePreviewRendering()
    editorInput.forceActiveFocus()
  }

  function openSnippet(index, title, content, language, folder, tags) {
    root.targetType = "snippet"
    root.clipIndex = -1
    root.snippetIndex = index
    root.itemTitle = title || (index >= 0 ? "Edit Snippet" : "New Snippet")
    root.snippetTitle = String(title || (index >= 0 ? "" : "New Snippet"))
    root.editorContent = String(content || "")
    root.originalContent = String(content || "")
    root.snippetLanguage = String(language || "markdown")
    root.codeLanguage = String(language || "javascript")
    root.snippetFolder = String(folder || "")
    root.snippetTags = String(tags || "")
    root.isSaveAsSnippetMode = false
    root.newSnippetTitle = ""
    root.viewMode = "split"
    root.searchOpen = false
    root.fontPickerOpen = false
    root.feedbackText = ""
    root.cursorLine = 1
    root.cursorCol = 1

    var lang = String(language || "markdown").toLowerCase()
    if (lang === "html") root.editorContentMode = "rich"
    else if (lang === "markdown") root.editorContentMode = "markdown"
    else if (lang === "text") root.editorContentMode = "text"
    else root.editorContentMode = "code"

    root.visible = true
    if (editorInput.text !== root.editorContent) {
      editorInput.text = root.editorContent
    }
    root.updatePreviewRendering()
    editorInput.forceActiveFocus()
  }

  function close() {
    root.visible = false
    root.searchOpen = false
    root.fontPickerOpen = false
    root.isSaveAsSnippetMode = false
    root.closed()
  }

  function save() {
    if (root.targetType === "snippet") {
      root.savedSnippet(
        root.snippetIndex,
        root.snippetTitle || "Untitled Snippet",
        root.editorContent,
        root.snippetLanguage || "markdown",
        root.snippetFolder || "",
        root.snippetTags || ""
      )
      root.close()
    } else {
      root.savedClip(root.clipIndex, root.editorContent)
      root.close()
    }
  }

  function copyContent() {
    root.copiedToClipboard(root.editorContent)
    root.showFeedback("Copied to clipboard!")
  }

  function clearEditor() {
    editorInput.text = ""
    root.editorContent = ""
    root.showFeedback("Editor cleared")
    editorInput.forceActiveFocus()
  }

  function confirmSaveAsSnippet() {
    var title = root.newSnippetTitle.trim()
    if (!title) {
      var firstLine = root.editorContent.split("\n")[0].trim()
      title = firstLine ? firstLine.substring(0, 40) : "Snippet from Clip"
    }
    root.saveAsSnippetRequested(title, root.editorContent, "markdown")
    root.isSaveAsSnippetMode = false
    root.newSnippetTitle = ""
    root.showFeedback("Saved as new snippet!")
  }

  // --- Formatting Helpers ---
  function surroundSelection(before, after, placeholder) {
    var start = editorInput.selectionStart
    var end = editorInput.selectionEnd
    var text = editorInput.text
    if (start !== end) {
      var selected = text.substring(start, end)
      var replacement = before + selected + after
      editorInput.remove(start, end)
      editorInput.insert(start, replacement)
      editorInput.select(start + before.length, start + before.length + selected.length)
    } else {
      var ph = placeholder || "text"
      var insertStr = before + ph + after
      editorInput.insert(start, insertStr)
      editorInput.select(start + before.length, start + before.length + ph.length)
    }
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function applyFormatting(type) {
    if (type === "bold") {
      if (root.editorContentMode === "rich") root.surroundSelection("<b>", "</b>", "bold text")
      else root.surroundSelection("**", "**", "bold text")
    } else if (type === "italic") {
      if (root.editorContentMode === "rich") root.surroundSelection("<i>", "</i>", "italic text")
      else root.surroundSelection("*", "*", "italic text")
    } else if (type === "underline") {
      root.surroundSelection("<u>", "</u>", "underlined text")
    } else if (type === "strike") {
      if (root.editorContentMode === "rich") root.surroundSelection("<s>", "</s>", "strikethrough")
      else root.surroundSelection("~~", "~~", "strikethrough")
    } else if (type === "code") {
      if (root.editorContentMode === "rich") root.surroundSelection("<code>", "</code>", "code")
      else root.surroundSelection("`", "`", "code")
    } else if (type === "sup") {
      root.surroundSelection("<sup>", "</sup>", "superscript")
    } else if (type === "sub") {
      root.surroundSelection("<sub>", "</sub>", "subscript")
    } else if (type === "kbd") {
      root.surroundSelection("<kbd>", "</kbd>", "key")
    }
  }

  function applyColorSpan(colorHex) {
    if (!colorHex) return
    root.currentColor = colorHex
    root.surroundSelection('<span style="color:' + colorHex + '">', '</span>', "colored text")
  }

  function applyPickedColor(hex) {
    if (!hex) return
    var col = String(hex).trim()
    root.currentColor = col
    root.applyColorSpan(col)
    root.showFeedback("Color applied: " + col)
  }

  function increaseFontSize() {
    if (root.editorFontSize < 24) root.editorFontSize += 1
  }

  function decreaseFontSize() {
    if (root.editorFontSize > 8) root.editorFontSize -= 1
  }

  function resetFontSize() {
    root.editorFontSize = 10
  }

  function indentSelection() {
    var sel = editorInput.selectedText
    var sp = root.tabSize === 4 ? "    " : "  "
    if (sel && sel.indexOf("\n") !== -1) {
      var lines = sel.split("\n")
      var out = lines.map(function(l) { return sp + l }).join("\n")
      editorInput.remove(editorInput.selectionStart, editorInput.selectionEnd)
      editorInput.insert(editorInput.cursorPosition, out)
    } else {
      editorInput.insert(editorInput.cursorPosition, sp)
    }
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function outdentSelection() {
    var sel = editorInput.selectedText
    if (sel && sel.indexOf("\n") !== -1) {
      var lines = sel.split("\n")
      var out = lines.map(function(l) {
        if (l.indexOf("    ") === 0 && root.tabSize === 4) return l.substring(4)
        if (l.indexOf("  ") === 0) return l.substring(2)
        if (l.indexOf("\t") === 0) return l.substring(1)
        return l
      }).join("\n")
      editorInput.remove(editorInput.selectionStart, editorInput.selectionEnd)
      editorInput.insert(editorInput.cursorPosition, out)
    }
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function prefixCurrentLines(prefix) {
    var start = editorInput.selectionStart
    var end = editorInput.selectionEnd
    var text = editorInput.text
    var lineStart = text.lastIndexOf("\n", Math.max(0, start - 1))
    lineStart = (lineStart === -1) ? 0 : lineStart + 1
    var lineEnd = text.indexOf("\n", end)
    if (lineEnd === -1) lineEnd = text.length

    var block = text.substring(lineStart, lineEnd)
    var lines = block.split("\n")
    var modifiedLines = []
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i]
      if (l.indexOf(prefix) === 0) {
        modifiedLines.push(l.substring(prefix.length))
      } else {
        modifiedLines.push(prefix + l)
      }
    }
    var replacement = modifiedLines.join("\n")
    editorInput.remove(lineStart, lineEnd)
    editorInput.insert(lineStart, replacement)
    editorInput.select(lineStart, lineStart + replacement.length)
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function numberCurrentLines() {
    var start = editorInput.selectionStart
    var end = editorInput.selectionEnd
    var text = editorInput.text
    var lineStart = text.lastIndexOf("\n", Math.max(0, start - 1))
    lineStart = (lineStart === -1) ? 0 : lineStart + 1
    var lineEnd = text.indexOf("\n", end)
    if (lineEnd === -1) lineEnd = text.length

    var block = text.substring(lineStart, lineEnd)
    var lines = block.split("\n")
    var modifiedLines = []
    for (var i = 0; i < lines.length; i++) {
      var numPrefix = (i + 1) + ". "
      var cleaned = lines[i].replace(/^\d+\.\s*/, "")
      modifiedLines.push(numPrefix + cleaned)
    }
    var replacement = modifiedLines.join("\n")
    editorInput.remove(lineStart, lineEnd)
    editorInput.insert(lineStart, replacement)
    editorInput.select(lineStart, lineStart + replacement.length)
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function insertBlock(blockText) {
    var pos = editorInput.cursorPosition
    var text = editorInput.text
    var insertStr = blockText
    if (pos > 0 && text.charAt(pos - 1) !== "\n") {
      insertStr = "\n" + insertStr
    }
    if (pos < text.length && text.charAt(pos) !== "\n") {
      insertStr = insertStr + "\n"
    }
    editorInput.insert(pos, insertStr)
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function insertLink() {
    var sel = editorInput.selectedText
    if (sel && sel.length > 0) {
      editorInput.remove(editorInput.selectionStart, editorInput.selectionEnd)
      var linkStr = "[" + sel + "](https://)"
      editorInput.insert(editorInput.cursorPosition, linkStr)
    } else {
      insertBlock("[Link Title](https://example.com)")
    }
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function insertTimestamp() {
    var d = new Date()
    var stamp = d.getFullYear() + "-" +
      String(d.getMonth() + 1).padStart(2, "0") + "-" +
      String(d.getDate()).padStart(2, "0") + " " +
      String(d.getHours()).padStart(2, "0") + ":" +
      String(d.getMinutes()).padStart(2, "0")
    editorInput.insert(editorInput.cursorPosition, stamp)
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function clearFormatting() {
    var sel = editorInput.selectedText
    if (!sel || sel.length === 0) {
      root.showFeedback("Select text to clear formatting")
      return
    }
    var clean = sel
    clean = clean.replace(/(\*\*|__)(.*?)\1/g, "$2")
    clean = clean.replace(/(\*|_)(.*?)\1/g, "$2")
    clean = clean.replace(/~~(.*?)~~/g, "$1")
    clean = clean.replace(/`([^`]+)`/g, "$1")
    clean = clean.replace(/<(\/)?(u|mark|sup|sub|kbd)>/gi, "")
    clean = clean.replace(/<span[^>]*>(.*?)<\/span>/gi, "$1")
    clean = clean.replace(/\[([^\]]+)\]\([^\)]+\)/g, "$1")

    var start = editorInput.selectionStart
    var end = editorInput.selectionEnd
    editorInput.remove(start, end)
    editorInput.insert(start, clean)
    editorInput.select(start, start + clean.length)
    root.editorContent = editorInput.text
    root.showFeedback("Formatting cleared from selection")
  }

  function insertFootnote() {
    var text = root.editorContent || ""
    var matches = text.match(/\[\^(\d+)\]/g)
    var maxNum = 0
    if (matches) {
      for (var i = 0; i < matches.length; i++) {
        var num = parseInt(matches[i].replace(/[^\d]/g, ""), 10)
        if (!isNaN(num) && num > maxNum) maxNum = num
      }
    }
    var nextNum = maxNum + 1
    var noteRef = "[^" + nextNum + "]"
    var noteDef = "\n\n[^" + nextNum + "]: Footnote text here."

    var pos = editorInput.cursorPosition
    editorInput.insert(pos, noteRef)
    editorInput.insert(editorInput.text.length, noteDef)
    root.editorContent = editorInput.text
    editorInput.cursorPosition = pos + noteRef.length
    editorInput.forceActiveFocus()
    root.showFeedback("Footnote " + noteRef + " inserted")
  }

  // --- Process Objects for Async Operations ---
  Process {
    id: saveFileProc
    property string destPath: ""
    command: []
    onExited: function(code) {
      if (code === 0) {
        root.showFeedback("Saved to " + destPath)
        root.saveDrawerOpen = false
      } else {
        root.showFeedback("Error saving file")
      }
    }
  }

  Process {
    id: copyHtmlProc
    command: []
    onExited: function(code) {
      if (code === 0) {
        root.showFeedback("Copied as Rich HTML to clipboard")
      }
    }
  }

  // --- Live Preview Markdown Rendering Engine ---
  Timer {
    id: previewTimer
    interval: 35
    repeat: false
    running: false
    onTriggered: {
      root.updatePreviewRendering()
    }
  }

  function schedulePreviewUpdate() {
    previewTimer.restart()
  }

  function updatePreviewRendering() {
    var raw = root.editorContent || ""
    root.renderedPreviewHtml = root.renderMarkdownToHtml(raw)
  }

  function renderMarkdownToHtml(md) {
    if (!md || md.trim().length === 0) return "<div style=\"color:" + Util.alpha(root.fgCol, 0.4) + "; font-style: italic;\">*No content to preview*</div>"

    var text = md.replace(/\u00a0/g, " ").replace(/\r\n/g, "\n").replace(/\r/g, "\n")

    if (root.editorContentMode === "code") {
      var hlCode = Syntax.highlight(text, root.codeLanguage || "javascript")
      return "<div style=\"background-color: rgba(0,0,0,0.35); border: 1px solid " + Util.alpha(root.borderCol, 0.6) + "; border-radius: 6px; padding: 10px 12px; margin: 8px 0; font-family:" + root.editorFontFamily + "; font-size:" + Style.space(root.editorFontSize) + "px; white-space: pre-wrap;\"><div style=\"font-size:9px; font-weight:bold; color:" + Color.accent + "; text-transform:uppercase; margin-bottom:6px; letter-spacing:1px;\">" + (root.codeLanguage || "code") + "</div>" + hlCode + "</div>"
    }

    if (root.editorContentMode === "rich") {
      return text
    }

    if (root.editorContentMode === "text") {
      return "<div style=\"white-space: pre-wrap; font-family:" + root.editorFontFamily + "; font-size:" + Style.space(root.editorFontSize) + "px; color:" + root.fgCol + ";\">" + Syntax.escapeHtml(text) + "</div>"
    }

    var lines = text.split("\n")
    var html = []

    var inCodeBlock = false
    var codeLang = ""
    var codeBuffer = []
    var inList = false
    var listType = ""
    var tableBuffer = []

    function flushTable() {
      if (tableBuffer.length === 0) return
      var rows = []
      for (var r = 0; r < tableBuffer.length; r++) {
        var l = tableBuffer[r].trim()
        if (l.startsWith("|")) l = l.slice(1)
        if (l.endsWith("|")) l = l.slice(0, -1)
        var cells = l.split("|").map(function(c) { return c.trim() })
        if (cells.every(function(c) { return /^:?-+:?$/.test(c) })) continue
        rows.push(cells)
      }
      if (rows.length > 0) {
        var tblHtml = "<table style=\"border-collapse: collapse; margin: 10px 0; width: 100%; border: 1px solid " + Util.alpha(root.borderCol, 0.6) + ";\">"
        tblHtml += "<thead><tr>"
        for (var h = 0; h < rows[0].length; h++) {
          tblHtml += "<th style=\"border: 1px solid " + Util.alpha(root.borderCol, 0.6) + "; padding: 5px 10px; background: rgba(255,255,255,0.06); font-weight: bold; color: " + root.fgCol + "; text-align: left;\">" + formatInlinePreview(rows[0][h]) + "</th>"
        }
        tblHtml += "</tr></thead><tbody>"
        for (var rowIdx = 1; rowIdx < rows.length; rowIdx++) {
          var row = rows[rowIdx]
          var bg = (rowIdx % 2 === 0) ? "rgba(255,255,255,0.02)" : "transparent"
          tblHtml += "<tr style=\"background:" + bg + ";\">"
          for (var cIdx = 0; cIdx < rows[0].length; cIdx++) {
            var cellVal = (cIdx < row.length) ? row[cIdx] : ""
            tblHtml += "<td style=\"border: 1px solid " + Util.alpha(root.borderCol, 0.5) + "; padding: 4px 10px; color: " + root.fgCol + ";\">" + formatInlinePreview(cellVal) + "</td>"
          }
          tblHtml += "</tr>"
        }
        tblHtml += "</tbody></table>"
        html.push(tblHtml)
      }
      tableBuffer = []
    }

    function flushList() {
      if (inList) {
        html.push(listType === "ol" ? "</ol>" : "</ul>")
        inList = false
        listType = ""
      }
    }

    function formatInlinePreview(str) {
      if (!str) return ""
      var s = Syntax.escapeHtml(str)
      s = s.replace(/(`)([^`]+)(`)/g, "<code style=\"background-color: rgba(255,255,255,0.08); color: " + Color.accent + "; padding: 1px 4px; border-radius: 3px; font-family:" + root.editorFontFamily + ";\">$2</code>")
      s = s.replace(/(\*\*|__)(.+?)\1/g, "<b>$2</b>")
      s = s.replace(/(^|[^*_])(\*|_)(?!\2)(.+?)\2/g, "$1<i>$3</i>")
      s = s.replace(/~~([^~]+)~~/g, "<s>$1</s>")
      s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, "<a href=\"$2\" style=\"color:" + Color.accent + "; text-decoration: underline;\">$1</a>")
      return s
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var trimmed = line.trim()

      if (trimmed.startsWith("```")) {
        if (!inCodeBlock) {
          flushTable()
          flushList()
          inCodeBlock = true
          codeLang = trimmed.slice(3).trim()
          codeBuffer = []
        } else {
          inCodeBlock = false
          var rawCode = codeBuffer.join("\n")
          var highlighted = Syntax.highlight(rawCode, codeLang || "javascript")
          var badge = codeLang ? ("<div style=\"font-size:9px; font-weight:bold; color:" + Color.accent + "; text-transform:uppercase; letter-spacing:1px; border-bottom:1px solid " + Util.alpha(root.borderCol, 0.4) + "; padding-bottom:4px; margin-bottom:6px;\">" + codeLang + "</div>") : ""
          html.push("<div style=\"background-color: rgba(0,0,0,0.35); border: 1px solid " + Util.alpha(root.borderCol, 0.6) + "; border-radius: 6px; padding: 10px 12px; margin: 10px 0; font-family:" + root.editorFontFamily + "; font-size:" + Style.space(root.editorFontSize) + "px;\">" + badge + "<div style=\"white-space: pre-wrap;\">" + highlighted + "</div></div>")
          codeBuffer = []
          codeLang = ""
        }
        continue
      }

      if (inCodeBlock) {
        codeBuffer.push(line)
        continue
      }

      if (trimmed.startsWith("|") || (trimmed.indexOf("|") !== -1 && trimmed.endsWith("|"))) {
        flushList()
        tableBuffer.push(line)
        continue
      } else {
        flushTable()
      }

      if (/^(---|\*\*\*|___)$/.test(trimmed)) {
        flushList()
        html.push("<hr style=\"border: 0; border-top: 1px solid " + Util.alpha(root.borderCol, 0.6) + "; margin: 12px 0;\" />")
        continue
      }

      if (trimmed.startsWith("# ")) {
        flushList()
        html.push("<h1 style=\"color:" + root.fgCol + "; font-size: 16px; font-weight: bold; margin: 14px 0 6px 0; border-bottom: 1px solid " + Util.alpha(root.borderCol, 0.5) + "; padding-bottom: 4px;\">" + formatInlinePreview(trimmed.slice(2)) + "</h1>")
        continue
      }
      if (trimmed.startsWith("## ")) {
        flushList()
        html.push("<h2 style=\"color:" + root.fgCol + "; font-size: 14px; font-weight: bold; margin: 12px 0 5px 0; border-bottom: 1px solid " + Util.alpha(root.borderCol, 0.4) + "; padding-bottom: 3px;\">" + formatInlinePreview(trimmed.slice(3)) + "</h2>")
        continue
      }
      if (trimmed.startsWith("### ")) {
        flushList()
        html.push("<h3 style=\"color:" + Color.accent + "; font-size: 12px; font-weight: bold; margin: 10px 0 4px 0;\">" + formatInlinePreview(trimmed.slice(4)) + "</h3>")
        continue
      }
      if (trimmed.startsWith("#### ")) {
        flushList()
        html.push("<h4 style=\"color:" + root.fgCol + "; font-size: 11px; font-weight: bold; margin: 8px 0 3px 0;\">" + formatInlinePreview(trimmed.slice(5)) + "</h4>")
        continue
      }

      if (trimmed.startsWith("- [ ] ") || trimmed.startsWith("* [ ] ")) {
        flushList()
        html.push("<div style=\"margin: 3px 0; color:" + root.fgCol + ";\"><span style=\"font-family:" + root.editorFontFamily + "; color:" + Color.accent + "; font-size: 11px;\">☐</span> " + formatInlinePreview(trimmed.slice(6)) + "</div>")
        continue
      }
      if (trimmed.startsWith("- [x] ") || trimmed.startsWith("- [X] ") || trimmed.startsWith("* [x] ") || trimmed.startsWith("* [X] ")) {
        flushList()
        html.push("<div style=\"margin: 3px 0; color:" + Util.alpha(root.fgCol, 0.6) + ";\"><span style=\"font-family:" + root.editorFontFamily + "; color:" + Color.accent + "; font-size: 11px;\">☑</span> <span style=\"text-decoration: line-through;\">" + formatInlinePreview(trimmed.slice(6)) + "</span></div>")
        continue
      }

      if (trimmed.startsWith(">")) {
        flushList()
        var bqText = trimmed.replace(/^>\s*/, "")
        html.push("<div style=\"border-left: 3px solid " + Color.accent + "; padding-left: 10px; margin: 6px 0; color:" + Util.alpha(root.fgCol, 0.8) + "; font-style: italic;\">" + formatInlinePreview(bqText) + "</div>")
        continue
      }

      if (trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ")) {
        if (!inList || listType !== "ul") {
          flushList()
          html.push("<ul style=\"margin: 4px 0; padding-left: 18px;\">")
          inList = true
          listType = "ul"
        }
        html.push("<li style=\"margin: 2px 0; color:" + root.fgCol + ";\">" + formatInlinePreview(trimmed.slice(2)) + "</li>")
        continue
      }

      var olMatch = trimmed.match(/^(\d+)\.\s+(.*)$/)
      if (olMatch) {
        if (!inList || listType !== "ol") {
          flushList()
          html.push("<ol style=\"margin: 4px 0; padding-left: 18px;\">")
          inList = true
          listType = "ol"
        }
        html.push("<li style=\"margin: 2px 0; color:" + root.fgCol + ";\">" + formatInlinePreview(olMatch[2]) + "</li>")
        continue
      }

      flushList()

      if (trimmed.length > 0) {
        html.push("<p style=\"margin: 4px 0; line-height: 1.35; color:" + root.fgCol + ";\">" + formatInlinePreview(line) + "</p>")
      } else {
        html.push("<div style=\"height: 6px;\"></div>")
      }
    }

    flushTable()
    flushList()
    if (inCodeBlock && codeBuffer.length > 0) {
      var rawCode2 = codeBuffer.join("\n")
      var hl2 = Syntax.highlight(rawCode2, codeLang || "javascript")
      html.push("<div style=\"background-color: rgba(0,0,0,0.35); border: 1px solid " + Util.alpha(root.borderCol, 0.6) + "; border-radius: 6px; padding: 10px 12px; margin: 10px 0; font-family:" + root.editorFontFamily + "; font-size:" + Style.space(root.editorFontSize) + "px;\"><div style=\"white-space: pre-wrap;\">" + hl2 + "</div></div>")
    }

    return html.join("\n")
  }

  // --- Markdown Table & Data Operations ---
  function formatMarkdownTable() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var lines = targetText.split("\n")

    function formatBlock(blk) {
      if (blk.length === 0) return []
      var rows = blk.map(function(l) {
        var raw = l.trim()
        if (raw.startsWith("|")) raw = raw.slice(1)
        if (raw.endsWith("|")) raw = raw.slice(0, -1)
        return raw.split("|").map(function(c) { return c.trim() })
      })

      var maxCols = 0
      for (var r = 0; r < rows.length; r++) {
        if (rows[r].length > maxCols) maxCols = rows[r].length
      }

      var colWidths = []
      for (var c = 0; c < maxCols; c++) colWidths[c] = 3

      for (var r2 = 0; r2 < rows.length; r2++) {
        var isSep2 = (r2 === 1) || (rows[r2].every(function(cell) { return /^:?-+:?$/.test(cell) }))
        if (isSep2) continue
        for (var c2 = 0; c2 < rows[r2].length; c2++) {
          var len = rows[r2][c2].length
          if (len > colWidths[c2]) colWidths[c2] = len
        }
      }

      var out = []
      for (var r3 = 0; r3 < rows.length; r3++) {
        var isSep3 = (r3 === 1) || (rows[r3].every(function(cell) { return /^:?-+:?$/.test(cell) }))
        var rowCells = []
        for (var c3 = 0; c3 < maxCols; c3++) {
          var val = (c3 < rows[r3].length) ? rows[r3][c3] : ""
          var targetW = colWidths[c3]
          if (isSep3) {
            var alignLeft = val.startsWith(":")
            var alignRight = val.endsWith(":")
            var dashes = "-".repeat(Math.max(3, targetW - (alignLeft ? 1 : 0) - (alignRight ? 1 : 0)))
            rowCells.push((alignLeft ? ":" : "-") + dashes + (alignRight ? ":" : "-"))
          } else {
            rowCells.push(" " + val + " ".repeat(Math.max(0, targetW - val.length)) + " ")
          }
        }
        out.push("|" + rowCells.join("|") + "|")
      }
      return out
    }

    var outLines = []
    var tbl = []
    for (var i = 0; i < lines.length; i++) {
      var trimmed = lines[i].trim()
      if (trimmed.startsWith("|") || (trimmed.indexOf("|") !== -1 && trimmed.endsWith("|"))) {
        tbl.push(lines[i])
      } else {
        if (tbl.length > 0) {
          outLines = outLines.concat(formatBlock(tbl))
          tbl = []
        }
        outLines.push(lines[i])
      }
    }
    if (tbl.length > 0) {
      outLines = outLines.concat(formatBlock(tbl))
    }

    var result = outLines.join("\n")
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, result)
      editorInput.select(s, s + result.length)
    } else {
      root.editorContent = result
      editorInput.text = result
    }
    root.showFeedback("Table auto-aligned")
  }

  function convertCsvTable() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var lines = targetText.trim().split("\n")
    if (lines.length === 0) return

    var isMdTable = lines.some(function(l) { return l.trim().startsWith("|") })
    var result = ""

    if (isMdTable) {
      var csvRows = []
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line.startsWith("|") && line.indexOf("|") === -1) continue
        if (line.startsWith("|")) line = line.slice(1)
        if (line.endsWith("|")) line = line.slice(0, -1)
        var cells = line.split("|").map(function(c) { return c.trim() })
        if (cells.every(function(c) { return /^:?-+:?$/.test(c) })) continue

        var escapedCells = cells.map(function(c) {
          if (c.indexOf(",") !== -1 || c.indexOf("\"") !== -1 || c.indexOf("\n") !== -1) {
            return "\"" + c.replace(/"/g, "\"\"") + "\""
          }
          return c
        })
        csvRows.push(escapedCells.join(","))
      }
      result = csvRows.join("\n")
      root.showFeedback("Converted to CSV")
    } else {
      var delimiter = lines[0].indexOf("\t") !== -1 ? "\t" : ","
      var mdRows = []
      var headerCols = 0
      for (var i2 = 0; i2 < lines.length; i2++) {
        var line2 = lines[i2]
        if (!line2.trim()) continue
        var cells2 = []
        var inQuotes = false
        var curCell = ""
        for (var chIdx = 0; chIdx < line2.length; chIdx++) {
          var ch = line2[chIdx]
          if (ch === "\"") {
            inQuotes = !inQuotes
          } else if (ch === delimiter && !inQuotes) {
            cells2.push(curCell.trim())
            curCell = ""
          } else {
            curCell += ch
          }
        }
        cells2.push(curCell.trim())

        if (i2 === 0) {
          headerCols = cells2.length
          mdRows.push("| " + cells2.join(" | ") + " |")
          var sep = []
          for (var sc = 0; sc < headerCols; sc++) sep.push("---")
          mdRows.push("| " + sep.join(" | ") + " |")
        } else {
          while (cells2.length < headerCols) cells2.push("")
          mdRows.push("| " + cells2.slice(0, headerCols).join(" | ") + " |")
        }
      }
      result = mdRows.join("\n")
      root.showFeedback("Converted to Markdown Table")
    }

    if (sel && sel.length > 0) {
      var s2 = editorInput.selectionStart
      var e2 = editorInput.selectionEnd
      editorInput.remove(s2, e2)
      editorInput.insert(s2, result)
      editorInput.select(s2, s2 + result.length)
    } else {
      root.editorContent = result
      editorInput.text = result
    }
  }

  function convertTableToJson() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var lines = targetText.trim().split("\n")
    var tableLines = lines.filter(function(l) { return l.trim().startsWith("|") || l.indexOf("|") !== -1 })
    if (tableLines.length < 2) {
      root.showFeedback("No Markdown table found")
      return
    }
    var parseCells = function(line) {
      var raw = line.trim()
      if (raw.startsWith("|")) raw = raw.slice(1)
      if (raw.endsWith("|")) raw = raw.slice(0, -1)
      return raw.split("|").map(function(c) { return c.trim() })
    }
    var headers = parseCells(tableLines[0])
    var rows = []
    for (var i = 1; i < tableLines.length; i++) {
      var cells = parseCells(tableLines[i])
      if (cells.every(function(c) { return /^:?-+:?$/.test(c) })) continue
      var obj = {}
      for (var h = 0; h < headers.length; h++) {
        var key = headers[h] || ("col_" + (h + 1))
        var val = (h < cells.length) ? cells[h] : ""
        obj[key] = val
      }
      rows.push(obj)
    }
    var jsonStr = JSON.stringify(rows, null, 2)
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, jsonStr)
      editorInput.select(s, s + jsonStr.length)
    } else {
      root.editorContent = jsonStr
      editorInput.text = jsonStr
    }
    root.showFeedback("Table converted to JSON")
  }

  // --- Developer Encoders & Parsers ---
  function decodeJwtToken() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel.trim() : root.editorContent.trim()
    var match = targetText.match(/([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)/)
    if (!match) {
      root.showFeedback("No JWT token found")
      return
    }
    var parts = match[1].split(".")
    function b64UrlDecode(str) {
      var output = str.replace(/-/g, "+").replace(/_/g, "/")
      switch (output.length % 4) {
        case 0: break
        case 2: output += "=="; break
        case 3: output += "="; break
        default: break
      }
      try {
        return Qt.atob(output)
      } catch(e) {
        return "{}"
      }
    }
    try {
      var headerObj = JSON.parse(b64UrlDecode(parts[0]))
      var payloadObj = JSON.parse(b64UrlDecode(parts[1]))
      var result = "// --- JWT HEADER ---\n" +
        JSON.stringify(headerObj, null, 2) +
        "\n\n// --- JWT PAYLOAD ---\n" +
        JSON.stringify(payloadObj, null, 2)

      if (sel && sel.length > 0) {
        var s = editorInput.selectionStart
        var e = editorInput.selectionEnd
        editorInput.remove(s, e)
        editorInput.insert(s, result)
      } else {
        root.editorContent = result
        editorInput.text = result
      }
      root.showFeedback("JWT decoded")
    } catch(e) {
      root.showFeedback("Failed to decode JWT")
    }
  }

  function toggleEscapeStringLiterals() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var isEscaped = targetText.indexOf("\\\"") !== -1 || targetText.indexOf("\\n") !== -1 || targetText.indexOf("\\\\") !== -1
    var result = ""
    if (isEscaped) {
      result = targetText
        .replace(/\\"/g, "\"")
        .replace(/\\'/g, "'")
        .replace(/\\n/g, "\n")
        .replace(/\\r/g, "\r")
        .replace(/\\t/g, "\t")
        .replace(/\\\\/g, "\\")
      root.showFeedback("Unescaped string literals")
    } else {
      result = targetText
        .replace(/\\/g, "\\\\")
        .replace(/"/g, "\\\"")
        .replace(/\n/g, "\\n")
        .replace(/\r/g, "\\r")
        .replace(/\t/g, "\\t")
      root.showFeedback("Escaped string literals")
    }
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, result)
      editorInput.select(s, s + result.length)
    } else {
      root.editorContent = result
      editorInput.text = result
    }
  }

  function wrapLinesInQuotes() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var lines = targetText.split("\n")
    var out = lines.map(function(l) {
      var trimmed = l.trim()
      if (trimmed.length === 0) return l
      if ((trimmed.startsWith("\"") && trimmed.endsWith("\",")) ||
          (trimmed.startsWith("'") && trimmed.endsWith("',"))) {
        return trimmed.slice(1, -2)
      } else if ((trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
                 (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
        return trimmed.slice(1, -1)
      } else {
        return "\"" + trimmed.replace(/"/g, "\\\"") + "\","
      }
    })
    var result = out.join("\n")
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, result)
      editorInput.select(s, s + result.length)
    } else {
      root.editorContent = result
      editorInput.text = result
    }
    root.showFeedback("Lines wrapped in quotes & comma")
  }

  function convertHexText() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var trimmed = targetText.trim()
    var isHex = /^[0-9a-fA-F\s]+$/.test(trimmed) && trimmed.indexOf(" ") !== -1 && trimmed.length >= 2
    var result = ""
    if (isHex) {
      try {
        var hexArr = trimmed.split(/\s+/)
        var chars = []
        for (var i = 0; i < hexArr.length; i++) {
          if (hexArr[i].length > 0) {
            chars.push(String.fromCharCode(parseInt(hexArr[i], 16)))
          }
        }
        result = chars.join("")
        root.showFeedback("Hex decoded to text")
      } catch(e) {
        result = targetText
      }
    } else {
      var hexes = []
      for (var c = 0; c < targetText.length; c++) {
        var h = targetText.charCodeAt(c).toString(16)
        if (h.length === 1) h = "0" + h
        hexes.push(h)
      }
      result = hexes.join(" ")
      root.showFeedback("Text converted to Hex bytes")
    }
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, result)
      editorInput.select(s, s + result.length)
    } else {
      root.editorContent = result
      editorInput.text = result
    }
  }

  // --- Checklist & Task Automation ---
  function toggleCheckboxes() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var hasUnchecked = targetText.indexOf("- [ ] ") !== -1
    var result = ""
    if (hasUnchecked) {
      result = targetText.replace(/- \[ \] /g, "- [x] ")
      root.showFeedback("Checked all tasks")
    } else {
      result = targetText.replace(/- \[[xX]\] /g, "- [ ] ")
      root.showFeedback("Unchecked all tasks")
    }
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, result)
      editorInput.select(s, s + result.length)
    } else {
      root.editorContent = result
      editorInput.text = result
    }
  }

  function sortTasksByCompletion() {
    var sel = editorInput.selectedText
    var targetText = (sel && sel.length > 0) ? sel : root.editorContent
    var lines = targetText.split("\n")
    var result = []
    var currentTaskBlock = []

    function flushTaskBlock() {
      if (currentTaskBlock.length === 0) return
      var pending = []
      var done = []
      for (var i = 0; i < currentTaskBlock.length; i++) {
        var item = currentTaskBlock[i]
        if (item.trim().startsWith("- [ ] ")) {
          pending.push(item)
        } else {
          done.push(item)
        }
      }
      result = result.concat(pending).concat(done)
      currentTaskBlock = []
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var trimmed = line.trim()
      if (trimmed.startsWith("- [ ] ") || trimmed.startsWith("- [x] ") || trimmed.startsWith("- [X] ")) {
        currentTaskBlock.push(line)
      } else {
        flushTaskBlock()
        result.push(line)
      }
    }
    flushTaskBlock()
    var outText = result.join("\n")
    if (sel && sel.length > 0) {
      var s = editorInput.selectionStart
      var e = editorInput.selectionEnd
      editorInput.remove(s, e)
      editorInput.insert(s, outText)
      editorInput.select(s, s + outText.length)
    } else {
      root.editorContent = outText
      editorInput.text = outText
    }
    root.showFeedback("Tasks sorted: pending tasks first")
  }

  // --- Boilerplate & Export Helpers ---
  function insertBoilerplate(tpl) {
    if (!tpl) return
    if (!root.editorContent || root.editorContent.trim().length === 0) {
      root.editorContent = tpl.content
      editorInput.text = tpl.content
    } else {
      var pos = editorInput.cursorPosition
      editorInput.insert(pos, tpl.content)
      root.editorContent = editorInput.text
    }
    if (tpl.mode) root.editorContentMode = tpl.mode
    root.boilerplateMenuOpen = false
    root.showFeedback("Inserted " + tpl.name + " template")
    editorInput.forceActiveFocus()
  }

  function mdToHtml(md) {
    return root.renderMarkdownToHtml(md)
  }

  function copyAsRichHtml() {
    var html = (root.editorContentMode === "rich") ? root.editorContent : root.renderMarkdownToHtml(root.editorContent)
    if (copyHtmlProc) {
      copyHtmlProc.command = ["bash", "-c", "printf '%s' \"$1\" | wl-copy -t text/html 2>/dev/null || true", "_", html]
      copyHtmlProc.running = true
    }
    ClipboardHistory.writeText(root.editorContent)
    root.showFeedback("Copied as Rich Text / HTML")
  }

  function saveToFile(filePath) {
    if (!filePath || filePath.trim().length === 0) {
      root.showFeedback("Please specify a file path")
      return
    }
    var expanded = filePath.trim()
    if (saveFileProc) {
      saveFileProc.destPath = expanded
      saveFileProc.command = ["bash", "-c", "target=\"${1/#\\~/$HOME}\"; mkdir -p \"$(dirname \"$target\")\" && printf '%s' \"$2\" > \"$target\"", "_", expanded, root.editorContent]
      saveFileProc.running = true
    }
  }


  // --- Search & Replace Helpers ---
  function performSearch() {
    var query = root.searchQuery
    if (!query) {
      root.searchMatches = []
      root.searchCurrentMatchIdx = -1
      return
    }
    var text = root.editorContent
    var matches = []
    var flags = root.searchMatchCase ? "g" : "gi"
    try {
      var escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
      var regex = new RegExp(escaped, flags)
      var match
      while ((match = regex.exec(text)) !== null) {
        matches.push({ start: match.index, end: match.index + match[0].length })
        if (regex.lastIndex === match.index) regex.lastIndex++
      }
    } catch(e) {}

    root.searchMatches = matches
    if (matches.length > 0) {
      var pos = editorInput.cursorPosition
      var bestIdx = 0
      for (var i = 0; i < matches.length; i++) {
        if (matches[i].start >= pos) {
          bestIdx = i
          break
        }
      }
      root.searchCurrentMatchIdx = bestIdx
      highlightCurrentMatch()
    } else {
      root.searchCurrentMatchIdx = -1
    }
  }

  function findNext() {
    if (root.searchMatches.length === 0) return
    root.searchCurrentMatchIdx = (root.searchCurrentMatchIdx + 1) % root.searchMatches.length
    highlightCurrentMatch()
  }

  function findPrev() {
    if (root.searchMatches.length === 0) return
    root.searchCurrentMatchIdx = (root.searchCurrentMatchIdx - 1 + root.searchMatches.length) % root.searchMatches.length
    highlightCurrentMatch()
  }

  function highlightCurrentMatch() {
    if (root.searchCurrentMatchIdx >= 0 && root.searchCurrentMatchIdx < root.searchMatches.length) {
      var m = root.searchMatches[root.searchCurrentMatchIdx]
      editorInput.select(m.start, m.end)
      editorInput.cursorPosition = m.end
    }
  }

  function replaceCurrent() {
    if (root.searchMatches.length === 0 || root.searchCurrentMatchIdx < 0) return
    var m = root.searchMatches[root.searchCurrentMatchIdx]
    var rep = root.replaceQuery
    editorInput.remove(m.start, m.end)
    editorInput.insert(m.start, rep)
    root.editorContent = editorInput.text
    performSearch()
  }

  function replaceAll() {
    var query = root.searchQuery
    if (!query) return
    var flags = root.searchMatchCase ? "g" : "gi"
    try {
      var escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
      var regex = new RegExp(escaped, flags)
      var count = (root.editorContent.match(regex) || []).length
      if (count > 0) {
        root.editorContent = root.editorContent.replace(regex, root.replaceQuery)
        editorInput.text = root.editorContent
        root.showFeedback("Replaced " + count + " occurrences")
        performSearch()
      } else {
        root.showFeedback("No matches found")
      }
    } catch(e) {
      root.showFeedback("Regex error in search")
    }
  }

  // --- Transformations ---
  function applyTransform(mode) {
    var s = root.editorContent
    switch (mode) {
      case "upper":
        root.editorContent = s.toUpperCase()
        break
      case "lower":
        root.editorContent = s.toLowerCase()
        break
      case "title":
        root.editorContent = s.replace(/\w\S*/g, function(w) {
          return w.charAt(0).toUpperCase() + w.substr(1).toLowerCase()
        })
        break
      case "sentence":
        root.editorContent = s.toLowerCase().replace(/(^\s*|[.!?]\s+)([a-z])/g, function(m, p1, p2) {
          return p1 + p2.toUpperCase()
        })
        root.showFeedback("Sentence case applied")
        break
      case "camel":
        root.editorContent = s.toLowerCase().replace(/[^a-zA-Z0-9]+(.)/g, function(m, chr) {
          return chr.toUpperCase()
        }).replace(/^[A-Z]/, function(m) { return m.toLowerCase() })
        break
      case "kebab":
        root.editorContent = s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        break
      case "snake":
        root.editorContent = s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
        break
      case "trim":
        root.editorContent = s.split("\n").map(function(l) { return l.trim() }).join("\n").trim()
        break
      case "remove_empty_lines":
        root.editorContent = s.split("\n").filter(function(l) { return l.trim().length > 0 }).join("\n")
        root.showFeedback("Blank lines removed")
        break
      case "join_lines":
        root.editorContent = s.split("\n\n").map(function(para) {
          return para.split("\n").map(function(l) { return l.trim() }).join(" ")
        }).join("\n\n")
        root.showFeedback("Lines joined into paragraphs")
        break
      case "sort_asc":
        root.editorContent = s.split("\n").sort().join("\n")
        break
      case "sort_desc":
        root.editorContent = s.split("\n").sort().reverse().join("\n")
        break
      case "dedup":
        var lines = s.split("\n")
        var seen = {}
        var out = []
        for (var i = 0; i < lines.length; i++) {
          if (!seen[lines[i]]) {
            seen[lines[i]] = true
            out.push(lines[i])
          }
        }
        root.editorContent = out.join("\n")
        break
      case "json_pretty":
        try {
          root.editorContent = JSON.stringify(JSON.parse(s), null, 2)
          root.showFeedback("JSON formatted")
        } catch(e) {
          root.showFeedback("Invalid JSON")
          return
        }
        break
      case "json_minify":
        try {
          root.editorContent = JSON.stringify(JSON.parse(s))
          root.showFeedback("JSON minified")
        } catch(e) {
          root.showFeedback("Invalid JSON")
          return
        }
        break
      case "strip_md":
        var clean = s
        clean = clean.replace(/^#{1,6}\s+/gm, "")
        clean = clean.replace(/(\*\*|__)(.*?)\1/g, "$2")
        clean = clean.replace(/(\*|_)(.*?)\1/g, "$2")
        clean = clean.replace(/~~(.*?)~~/g, "$1")
        clean = clean.replace(/`([^`]+)`/g, "$1")
        clean = clean.replace(/```[\s\S]*?```/g, function(m) {
          return m.replace(/^```[a-z]*\n?/i, "").replace(/```$/, "")
        })
        clean = clean.replace(/\[([^\]]+)\]\([^\)]+\)/g, "$1")
        clean = clean.replace(/^>\s*/gm, "")
        clean = clean.replace(/^[-*+]\s+/gm, "")
        clean = clean.replace(/^\d+\.\s+/gm, "")
        root.editorContent = clean
        root.showFeedback("Markdown stripped")
        break
      case "url_encode":
        try {
          root.editorContent = encodeURIComponent(s)
          root.showFeedback("URL encoded")
        } catch(e) {}
        break
      case "url_decode":
        try {
          root.editorContent = decodeURIComponent(s)
          root.showFeedback("URL decoded")
        } catch(e) {}
        break
      case "html_escape":
        if (s.indexOf("&lt;") !== -1 || s.indexOf("&gt;") !== -1 || s.indexOf("&amp;") !== -1) {
          root.editorContent = s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&amp;/g, "&")
          root.showFeedback("HTML entities unescaped")
        } else {
          root.editorContent = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;")
          root.showFeedback("HTML entities escaped")
        }
        break
      case "reverse_lines":
        root.editorContent = s.split("\n").reverse().join("\n")
        root.showFeedback("Lines reversed")
        break
      case "shuffle_lines":
        var lns = s.split("\n")
        for (var si = lns.length - 1; si > 0; si--) {
          var sj = Math.floor(Math.random() * (si + 1))
          var stmp = lns[si]
          lns[si] = lns[sj]
          lns[sj] = stmp
        }
        root.editorContent = lns.join("\n")
        root.showFeedback("Lines shuffled")
        break
      case "slug":
        root.editorContent = s.toLowerCase().trim()
          .replace(/[^\w\s-]/g, "")
          .replace(/[\s_-]+/g, "-")
          .replace(/^-+|-+$/g, "")
        root.showFeedback("Slugified")
        break
      case "base64_encode":
        try {
          root.editorContent = Qt.btoa(s)
          root.showFeedback("Base64 encoded")
        } catch(e) {
          root.showFeedback("Encoding error")
        }
        break
      case "base64_decode":
        try {
          root.editorContent = Qt.atob(s)
          root.showFeedback("Base64 decoded")
        } catch(e) {
          root.showFeedback("Invalid Base64")
        }
        break
      default:
        break
    }
    editorInput.text = root.editorContent
  }

  function duplicateLineOrSelection() {
    var start = editorInput.selectionStart
    var end = editorInput.selectionEnd
    var text = editorInput.text
    if (start !== end) {
      var sel = text.substring(start, end)
      editorInput.insert(end, sel)
      editorInput.select(end, end + sel.length)
      root.showFeedback("Selection duplicated")
    } else {
      var lineStart = text.lastIndexOf("\n", Math.max(0, start - 1))
      lineStart = (lineStart === -1) ? 0 : lineStart + 1
      var lineEnd = text.indexOf("\n", start)
      if (lineEnd === -1) lineEnd = text.length
      var lineText = text.substring(lineStart, lineEnd)
      editorInput.insert(lineEnd, "\n" + lineText)
      editorInput.cursorPosition = lineEnd + 1 + lineText.length
      root.showFeedback("Line duplicated")
    }
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
  }

  function toggleComment() {
    var prefix = root.editorContentMode === "rich" ? "<!-- " : (root.editorContentMode === "code" ? "// " : "# ")
    var suffix = root.editorContentMode === "rich" ? " -->" : ""
    var start = editorInput.selectionStart
    var end = editorInput.selectionEnd
    var text = editorInput.text
    var lineStart = text.lastIndexOf("\n", Math.max(0, start - 1))
    lineStart = (lineStart === -1) ? 0 : lineStart + 1
    var lineEnd = text.indexOf("\n", end)
    if (lineEnd === -1) lineEnd = text.length

    var block = text.substring(lineStart, lineEnd)
    var lines = block.split("\n")
    var isAllCommented = true
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().length > 0 && lines[i].indexOf(prefix) !== 0) {
        isAllCommented = false
        break
      }
    }
    var modified = []
    for (var j = 0; j < lines.length; j++) {
      var l = lines[j]
      if (isAllCommented) {
        if (l.indexOf(prefix) === 0) {
          l = l.substring(prefix.length)
          if (suffix && l.indexOf(suffix) !== -1) l = l.substring(0, l.length - suffix.length)
        }
      } else {
        if (l.trim().length > 0) {
          l = prefix + l + suffix
        }
      }
      modified.push(l)
    }
    editorInput.remove(lineStart, lineEnd)
    editorInput.insert(lineStart, modified.join("\n"))
    root.editorContent = editorInput.text
    editorInput.forceActiveFocus()
    root.showFeedback(isAllCommented ? "Uncommented" : "Commented")
  }

  function generateLineNumbers(content) {
    var count = (content || "").split("\n").length
    var res = []
    for (var i = 1; i <= count; i++) {
      res.push(i)
    }
    return res.join("\n")
  }

  // Keyboard Shortcuts
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (root.searchOpen) {
        root.searchOpen = false
        event.accepted = true
        return
      }
      if (root.isSaveAsSnippetMode) {
        root.isSaveAsSnippetMode = false
        event.accepted = true
        return
      }
      root.close()
      event.accepted = true
    } else if (event.modifiers & Qt.ControlModifier) {
      if (event.key === Qt.Key_S) {
        root.save()
        event.accepted = true
      } else if (event.key === Qt.Key_F) {
        root.searchOpen = !root.searchOpen
        event.accepted = true
      } else if (event.key === Qt.Key_B) {
        root.surroundSelection("**", "**", "bold text")
        event.accepted = true
      } else if (event.key === Qt.Key_I) {
        root.surroundSelection("*", "*", "italic text")
        event.accepted = true
      }
    }
  }

  // Full-View Column Layout (0 margins, matching ImageEditorModal)
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ==========================================
    // 1. TOP HEADER BAR (Edge-to-Edge)
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(40)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        // Left Side: Icon, Eliding Title, Badges
        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.space(6)

          Text {
            text: "✏️"
            font.pixelSize: Style.space(13)
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: Style.space(60)
            text: root.targetType === "snippet" ? (root.snippetTitle || "Snippet Editor") : (root.itemTitle || "Edit Content")
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.alignment: Qt.AlignVCenter
          }

          // Badge
          Rectangle {
            height: Style.space(18)
            width: badgeText.implicitWidth + Style.space(8)
            radius: Style.space(3)
            color: root.targetType === "snippet" ? Util.alpha("#A855F7", 0.2) : Util.alpha(Color.accent, 0.2)
            border.width: 1
            border.color: root.targetType === "snippet" ? Util.alpha("#A855F7", 0.5) : Util.alpha(Color.accent, 0.5)
            Layout.alignment: Qt.AlignVCenter

            Text {
              id: badgeText
              text: root.targetType === "snippet" ? "SNIPPET" : "CLIP"
              color: root.targetType === "snippet" ? "#C084FC" : Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.space(8)
              font.bold: true
              anchors.centerIn: parent
            }
          }

          // Modified indicator
          Rectangle {
            visible: root.isModified
            height: Style.space(18)
            width: modText.implicitWidth + Style.space(8)
            radius: Style.space(3)
            color: Util.alpha("#EAB308", 0.15)
            border.width: 1
            border.color: Util.alpha("#EAB308", 0.4)
            Layout.alignment: Qt.AlignVCenter

            Text {
              id: modText
              text: "● Edited"
              color: "#FACC15"
              font.family: root.fontFamily
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.centerIn: parent
            }
          }
        }

        // Undo & Redo Actions (Elevated Buttons)
        Row {
          spacing: Style.space(3)
          Layout.alignment: Qt.AlignVCenter

          // Undo
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.space(5)
            color: undoHeaderMouse.containsMouse ? Util.alpha(root.fgCol, 0.16) : "transparent"
            border.width: 1
            border.color: undoHeaderMouse.containsMouse ? Util.alpha(root.borderCol, 0.8) : "transparent"
            opacity: (editorInput && editorInput.canUndo) ? 1.0 : 0.45

            Text {
              text: "↶"
              color: root.fgCol
              font.pixelSize: Style.space(12)
              font.bold: true
              anchors.centerIn: parent
            }

            MouseArea {
              id: undoHeaderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function() { editorInput.undo() }
            }

            PanelToolTip {
              visible: undoHeaderMouse.containsMouse
              text: "Undo (Ctrl+Z)"
            }
          }

          // Redo
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.space(5)
            color: redoHeaderMouse.containsMouse ? Util.alpha(root.fgCol, 0.16) : "transparent"
            border.width: 1
            border.color: redoHeaderMouse.containsMouse ? Util.alpha(root.borderCol, 0.8) : "transparent"
            opacity: (editorInput && editorInput.canRedo) ? 1.0 : 0.45

            Text {
              text: "↷"
              color: root.fgCol
              font.pixelSize: Style.space(12)
              font.bold: true
              anchors.centerIn: parent
            }

            MouseArea {
              id: redoHeaderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function() { editorInput.redo() }
            }

            PanelToolTip {
              visible: redoHeaderMouse.containsMouse
              text: "Redo (Ctrl+Y)"
            }
          }
        }

        // Left Separator |
        Rectangle {
          width: 1
          height: Style.space(18)
          color: Util.alpha(root.fgCol, 0.18)
          Layout.alignment: Qt.AlignVCenter
        }

        // View Mode Switcher Pill with Rounded Corners (Split, Source, Preview)
        Rectangle {
          Layout.alignment: Qt.AlignVCenter
          height: Style.space(30)
          width: viewButtonsRow.implicitWidth + Style.space(4)
          radius: Style.space(7)
          color: Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: Util.alpha(root.fgCol, 0.12)

          Row {
            id: viewButtonsRow
            anchors.centerIn: parent
            spacing: Style.space(2)

            // Split View (Top/Down)
            Rectangle {
              width: Style.space(28)
              height: Style.space(26)
              radius: Style.space(5)
              color: root.viewMode === "split" ? Color.accent : (splitMouse.containsMouse ? Util.alpha(root.fgCol, 0.12) : "transparent")

              Text {
                text: "↕️"
                font.pixelSize: Style.space(11)
                anchors.centerIn: parent
              }

              MouseArea {
                id: splitMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.viewMode = "split" }
              }

              PanelToolTip {
                visible: splitMouse.containsMouse
                text: "Split View (Top/Down)"
              }
            }

            // Source Only
            Rectangle {
              width: Style.space(28)
              height: Style.space(26)
              radius: Style.space(5)
              color: root.viewMode === "edit" ? Color.accent : (editMouse.containsMouse ? Util.alpha(root.fgCol, 0.12) : "transparent")

              Text {
                text: "📝"
                font.pixelSize: Style.space(11)
                anchors.centerIn: parent
              }

              MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.viewMode = "edit" }
              }

              PanelToolTip {
                visible: editMouse.containsMouse
                text: "Source Editor Only"
              }
            }

            // Preview Only
            Rectangle {
              width: Style.space(28)
              height: Style.space(26)
              radius: Style.space(5)
              color: root.viewMode === "preview" ? Color.accent : (previewMouse.containsMouse ? Util.alpha(root.fgCol, 0.12) : "transparent")

              Text {
                text: "👁️"
                font.pixelSize: Style.space(11)
                anchors.centerIn: parent
              }

              MouseArea {
                id: previewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.viewMode = "preview" }
              }

              PanelToolTip {
                visible: previewMouse.containsMouse
                text: "Rendered Preview Only"
              }
            }
          }
        }

        // Right Separator |
        Rectangle {
          width: 1
          height: Style.space(18)
          color: Util.alpha(root.fgCol, 0.18)
          Layout.alignment: Qt.AlignVCenter
        }

        // Elevated Copy & Close Icon Buttons
        Row {
          spacing: Style.space(4)
          Layout.alignment: Qt.AlignVCenter

          // Copy Icon Button
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.space(5)
            color: copyMouse.containsMouse ? Util.alpha(root.fgCol, 0.16) : "transparent"
            border.width: 1
            border.color: copyMouse.containsMouse ? Util.alpha(root.borderCol, 0.8) : "transparent"

            Text {
              text: "📋"
              font.pixelSize: Style.space(11)
              anchors.centerIn: parent
            }

            MouseArea {
              id: copyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function() { root.copyContent() }
            }

            PanelToolTip {
              visible: copyMouse.containsMouse
              text: "Copy Content to Clipboard"
            }
          }

          // Close Icon Button
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.space(5)
            color: closeMouse.containsMouse ? Util.alpha("#EF4444", 0.22) : "transparent"
            border.width: 1
            border.color: closeMouse.containsMouse ? Util.alpha("#EF4444", 0.7) : "transparent"

            Text {
              text: "✕"
              color: closeMouse.containsMouse ? "#EF4444" : root.fgCol
              font.pixelSize: Style.space(11)
              font.bold: true
              anchors.centerIn: parent
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function() { root.close() }
            }

            PanelToolTip {
              visible: closeMouse.containsMouse
              text: "Close (Esc)"
            }
          }
        }
      }
    }

    // ==========================================
    // 2. SNIPPET METADATA BAR (If editing snippet)
    // ==========================================
    Rectangle {
      visible: root.targetType === "snippet"
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(32)
      color: Util.alpha(root.fgCol, 0.03)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: "Title:"
          color: Util.alpha(root.fgCol, 0.7)
          font.family: root.fontFamily
          font.pixelSize: Style.space(8.5)
          font.bold: true
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(22)
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: titleField.activeFocus ? Color.accent : Util.alpha(root.borderCol, 0.4)

          TextInput {
            id: titleField
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            text: root.snippetTitle
            onTextEdited: function() { root.snippetTitle = text }
          }
        }

        Text {
          text: "Language:"
          color: Util.alpha(root.fgCol, 0.7)
          font.family: root.fontFamily
          font.pixelSize: Style.space(8.5)
          font.bold: true
        }

        Rectangle {
          Layout.preferredWidth: Style.space(90)
          Layout.preferredHeight: Style.space(22)
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: langField.activeFocus ? Color.accent : Util.alpha(root.borderCol, 0.4)

          TextInput {
            id: langField
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: "monospace"
            font.pixelSize: Style.font.caption
            text: root.snippetLanguage
            onTextEdited: function() { root.snippetLanguage = text }
          }
        }

        Text {
          text: "Folder:"
          color: Util.alpha(root.fgCol, 0.7)
          font.family: root.fontFamily
          font.pixelSize: Style.space(8.5)
          font.bold: true
        }

        Rectangle {
          Layout.preferredWidth: Style.space(90)
          Layout.preferredHeight: Style.space(22)
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: folderField.activeFocus ? Color.accent : Util.alpha(root.borderCol, 0.4)

          TextInput {
            id: folderField
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            text: root.snippetFolder
            onTextEdited: function() { root.snippetFolder = text }
          }
        }
      }
    }

    // ==========================================
    // 3. SEARCH & REPLACE DRAWER (Collapsible)
    // ==========================================
    Rectangle {
      id: searchDrawer
      visible: root.searchOpen
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(32)
      color: Util.alpha(Color.accent, 0.08)
      border.width: 1
      border.color: Util.alpha(Color.accent, 0.3)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(6)

        Text {
          text: "🔍"
          font.pixelSize: Style.space(10)
        }

        // Search Field
        Rectangle {
          Layout.preferredWidth: Style.space(150)
          Layout.fillHeight: true
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.08)
          border.width: 1
          border.color: searchInputField.activeFocus ? Color.accent : Util.alpha(root.borderCol, 0.5)

          TextInput {
            id: searchInputField
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.space(8.5)
            text: root.searchQuery
            onTextChanged: function() {
              root.searchQuery = text
              root.performSearch()
            }
            onAccepted: function() { root.findNext() }
          }
        }

        // Match Count Text
        Text {
          text: root.searchMatches.length > 0 ? ((root.searchCurrentMatchIdx + 1) + "/" + root.searchMatches.length) : (root.searchQuery ? "0 found" : "")
          color: root.searchMatches.length > 0 ? Color.accent : Util.alpha(root.fgCol, 0.5)
          font.family: "monospace"
          font.pixelSize: Style.space(8.5)
          font.bold: true
        }

        // Prev / Next Match
        Rectangle {
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.space(3)
          color: prevMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: prevMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
          Text { text: "▲"; color: root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.findPrev() }
          }
        }

        Rectangle {
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.space(3)
          color: nextMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: nextMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
          Text { text: "▼"; color: root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.findNext() }
          }
        }

        // Case Sensitive Toggle
        Rectangle {
          width: Style.space(24)
          height: Style.space(22)
          radius: Style.space(3)
          color: root.searchMatchCase ? Util.alpha(Color.accent, 0.3) : (caseMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.06))
          border.width: 1
          border.color: root.searchMatchCase ? Color.accent : (caseMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")
          Text {
            text: "Aa"
            color: root.searchMatchCase ? Color.accent : root.fgCol
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.centerIn: parent
          }
          MouseArea {
            id: caseMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() {
              root.searchMatchCase = !root.searchMatchCase
              root.performSearch()
            }
          }
        }

        // Divider
        Rectangle {
          width: 1
          height: Style.space(16)
          color: Util.alpha(root.borderCol, 0.6)
        }

        Text {
          text: "Replace:"
          color: Util.alpha(root.fgCol, 0.7)
          font.family: root.fontFamily
          font.pixelSize: Style.space(8.5)
        }

        // Replace Field
        Rectangle {
          Layout.preferredWidth: Style.space(130)
          Layout.fillHeight: true
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.08)
          border.width: 1
          border.color: replaceInputField.activeFocus ? Color.accent : Util.alpha(root.borderCol, 0.5)

          TextInput {
            id: replaceInputField
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.space(8.5)
            text: root.replaceQuery
            onTextEdited: function() { root.replaceQuery = text }
          }
        }

        // Replace Button
        Rectangle {
          height: Style.space(22)
          width: repTxt.implicitWidth + Style.space(10)
          radius: Style.space(3)
          color: repMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.08)
          border.width: 1
          border.color: repMouse.containsMouse ? Util.alpha(root.borderCol, 0.8) : "transparent"

          Text {
            id: repTxt
            text: "Replace"
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.space(8)
            anchors.centerIn: parent
          }

          MouseArea {
            id: repMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.replaceCurrent() }
          }
        }

        // Replace All Button
        Rectangle {
          height: Style.space(22)
          width: repAllTxt.implicitWidth + Style.space(10)
          radius: Style.space(3)
          color: repAllMouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.accent, 0.15)
          border.width: 1
          border.color: repAllMouse.containsMouse ? Color.accent : "transparent"

          Text {
            id: repAllTxt
            text: "Replace All"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.centerIn: parent
          }

          MouseArea {
            id: repAllMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.replaceAll() }
          }
        }

        Item { Layout.fillWidth: true }

        // Close Search
        Rectangle {
          width: Style.space(20)
          height: Style.space(20)
          radius: Style.space(3)
          color: closeSearchMouse.containsMouse ? Util.alpha(root.fgCol, 0.2) : "transparent"
          Text { text: "✕"; color: root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
          MouseArea {
            id: closeSearchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.searchOpen = false }
          }
        }
      }
    }

    // ==========================================
    // 3b. SAVE AS FILE DRAWER (Collapsible)
    // ==========================================
    Rectangle {
      id: saveFileDrawer
      visible: root.saveDrawerOpen
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(32)
      color: Util.alpha("#10B981", 0.08)
      border.width: 1
      border.color: Util.alpha("#10B981", 0.3)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(6)

        Text {
          text: "💾"
          font.pixelSize: Style.space(10)
        }

        Text {
          text: "Save Path:"
          color: Util.alpha(root.fgCol, 0.7)
          font.family: root.fontFamily
          font.pixelSize: Style.space(8.5)
        }

        // File Path Field
        Rectangle {
          Layout.preferredWidth: Style.space(260)
          Layout.fillHeight: true
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.08)
          border.width: 1
          border.color: savePathInput.activeFocus ? "#10B981" : Util.alpha(root.borderCol, 0.5)

          TextInput {
            id: savePathInput
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: "monospace"
            font.pixelSize: Style.space(8.5)
            text: root.saveFilePath
            onTextChanged: function() {
              root.saveFilePath = text
            }
            onAccepted: function() { root.saveToFile(root.saveFilePath) }
          }
        }

        // Save Button
        Rectangle {
          height: Style.space(22)
          width: saveBtnTxt.implicitWidth + Style.space(12)
          radius: Style.space(3)
          color: saveBtnMouse.containsMouse ? Util.alpha("#10B981", 0.35) : Util.alpha("#10B981", 0.2)
          border.width: 1
          border.color: saveBtnMouse.containsMouse ? "#10B981" : "transparent"

          Text {
            id: saveBtnTxt
            text: "Save to Disk"
            color: "#10B981"
            font.family: root.fontFamily
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.centerIn: parent
          }

          MouseArea {
            id: saveBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.saveToFile(root.saveFilePath) }
          }
        }

        Item { Layout.fillWidth: true }

        // Close Drawer Button
        Rectangle {
          width: Style.space(20)
          height: Style.space(20)
          radius: Style.space(3)
          color: closeSaveMouse.containsMouse ? Util.alpha(root.fgCol, 0.2) : "transparent"
          Text { text: "✕"; color: root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
          MouseArea {
            id: closeSaveMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.saveDrawerOpen = false }
          }
        }
      }
    }

    // =========================================================
    // 4. MULTI-ROW TOOLBAR SUITE (FORMATTING, TRANSFORMS, VARS)
    // Docked edge-to-edge, zero horizontal scrolling needed!
    // =========================================================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: toolbarLayout.implicitHeight + Style.space(10)
      color: Util.alpha(root.fgCol, 0.025)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

      // Reusable Smart Scrubber Component (Ported from Image Editor Inspector)
      component SmartScrubber: Rectangle {
        id: scrubRoot
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 100
        property real step: 1
        property string unit: ""
        property real sensitivity: 0.5
        property string tip: ""
        property bool integerOnly: true
        signal valueScrubbed(real val)
        signal valueCommitted(real val)

        property real dragStartX: 0
        property real dragStartVal: 0
        property bool isScrubbing: false
        property bool editMode: false

        height: parent ? parent.height : Style.space(25)
        width: scrubRow.implicitWidth + Style.space(4)
        radius: Style.space(3)
        color: Util.alpha(root.fgCol, 0.06)
        border.width: 1
        border.color: isScrubbing ? Color.accent : (scrubMidMouse.containsMouse ? Util.alpha(Color.accent, 0.4) : Util.alpha(root.fgCol, 0.12))

        Row {
          id: scrubRow
          anchors.verticalCenter: parent.verticalCenter
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 0

          // Step Down [-]
          Rectangle {
            width: Style.space(14); height: scrubRoot.height; radius: Style.space(3)
            color: decM.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
            Text { text: "−"; font.pixelSize: Style.space(7.5); font.bold: true; color: root.fgCol; anchors.centerIn: parent }
            MouseArea {
              id: decM
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                var nVal = Math.max(scrubRoot.from, scrubRoot.value - scrubRoot.step)
                if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                scrubRoot.value = nVal
                scrubRoot.valueScrubbed(nVal)
                scrubRoot.valueCommitted(nVal)
              }
            }
          }

          // Middle Badge (Drag to scrub, double click to type)
          Rectangle {
            id: midBadge
            height: scrubRoot.height
            width: Math.max(Style.space(40), valLabel.implicitWidth + Style.space(8))
            color: scrubRoot.isScrubbing ? Util.alpha(Color.accent, 0.18) : (scrubMidMouse.containsMouse ? Util.alpha(root.fgCol, 0.08) : "transparent")

            Text {
              id: valLabel
              visible: !scrubRoot.editMode
              anchors.centerIn: parent
              text: (scrubRoot.label ? (scrubRoot.label + ": ") : "") + (scrubRoot.integerOnly ? Math.round(scrubRoot.value) : scrubRoot.value.toFixed(1)) + scrubRoot.unit
              font.family: root.fontFamily
              font.pixelSize: Style.space(7)
              font.bold: true
              color: scrubRoot.isScrubbing ? Color.accent : root.fgCol
            }

            TextInput {
              id: inlineInput
              visible: scrubRoot.editMode
              anchors.fill: parent
              anchors.margins: 1
              horizontalAlignment: TextInput.AlignHCenter
              verticalAlignment: TextInput.AlignVCenter
              font.family: root.fontFamily
              font.pixelSize: Style.space(7)
              font.bold: true
              color: Color.accent
              selectByMouse: true
              onAccepted: {
                var num = parseFloat(text)
                if (!isNaN(num)) {
                  var clamped = Math.max(scrubRoot.from, Math.min(scrubRoot.to, num))
                  if (scrubRoot.integerOnly) clamped = Math.round(clamped)
                  scrubRoot.value = clamped
                  scrubRoot.valueScrubbed(clamped)
                  scrubRoot.valueCommitted(clamped)
                }
                scrubRoot.editMode = false
              }
              onActiveFocusChanged: {
                if (!activeFocus && scrubRoot.editMode) {
                  scrubRoot.editMode = false
                }
              }
            }

            MouseArea {
              id: scrubMidMouse
              anchors.fill: parent
              enabled: !scrubRoot.editMode
              hoverEnabled: true
              cursorShape: Qt.SizeHorCursor

              onPressed: function(mouse) {
                scrubRoot.dragStartX = mouse.x
                scrubRoot.dragStartVal = scrubRoot.value
                scrubRoot.isScrubbing = true
              }
              onPositionChanged: function(mouse) {
                if (pressed) {
                  var dx = mouse.x - scrubRoot.dragStartX
                  var delta = dx * scrubRoot.step * scrubRoot.sensitivity * 0.25
                  var nVal = Math.max(scrubRoot.from, Math.min(scrubRoot.to, scrubRoot.dragStartVal + delta))
                  if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                  scrubRoot.value = nVal
                  scrubRoot.valueScrubbed(nVal)
                }
              }
              onReleased: function() {
                if (scrubRoot.isScrubbing) {
                  scrubRoot.isScrubbing = false
                  scrubRoot.valueCommitted(scrubRoot.value)
                }
              }
              onDoubleClicked: {
                scrubRoot.editMode = true
                inlineInput.text = String(scrubRoot.integerOnly ? Math.round(scrubRoot.value) : scrubRoot.value.toFixed(1))
                inlineInput.forceActiveFocus()
                inlineInput.selectAll()
              }
            }
          }

          // Step Up [+]
          Rectangle {
            width: Style.space(14); height: scrubRoot.height; radius: Style.space(3)
            color: incM.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
            Text { text: "+"; font.pixelSize: Style.space(7.5); font.bold: true; color: root.fgCol; anchors.centerIn: parent }
            MouseArea {
              id: incM
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                var nVal = Math.max(scrubRoot.from, Math.min(scrubRoot.to, scrubRoot.value + scrubRoot.step))
                if (scrubRoot.integerOnly) nVal = Math.round(nVal)
                scrubRoot.value = nVal
                scrubRoot.valueScrubbed(nVal)
                scrubRoot.valueCommitted(nVal)
              }
            }
          }
        }

        PanelToolTip {
          visible: (scrubMidMouse.containsMouse || isScrubbing) && !scrubRoot.editMode
          text: scrubRoot.tip ? scrubRoot.tip : ((scrubRoot.label ? (scrubRoot.label + ": ") : "") + "drag horizontally to adjust, double-click to type")
        }
      }

      Column {
        id: toolbarLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        anchors.topMargin: Style.space(5)
        spacing: Style.space(4)

        // -----------------------------------------------------
        // TOOLBAR ROW 1: TEXT INSPECTOR (TYPOGRAPHY & MODE)
        // -----------------------------------------------------
        Item {
          width: parent.width
          height: Style.space(25)

          // 1. Content Mode Pill (Markdown, Plain Text, Code, Rich Text) - Left Anchored
          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: modePillRow.implicitWidth + Style.space(4)
            radius: Style.space(4)
            color: Util.alpha(root.fgCol, 0.05)
            border.width: 1
            border.color: Util.alpha(root.fgCol, 0.1)

            Row {
              id: modePillRow
              anchors.centerIn: parent
              spacing: Style.space(1)

              Repeater {
                model: [
                  { id: "markdown", label: "MD", tip: "Markdown Mode (CommonMark)" },
                  { id: "text", label: "Text", tip: "Plain Text Mode" },
                  { id: "code", label: "Code", tip: "Source Code Mode" },
                  { id: "rich", label: "Rich", tip: "HTML Rich Text Mode" }
                ]
                Rectangle {
                  required property var modelData
                  property bool isAct: root.editorContentMode === modelData.id
                  width: modeItemTxt.implicitWidth + Style.space(8)
                  height: Style.space(21)
                  radius: Style.space(3)
                  color: isAct ? Color.accent : (modeItemMouse.containsMouse ? Util.alpha(root.fgCol, 0.1) : "transparent")

                  Text {
                    id: modeItemTxt
                    text: parent.modelData.label
                    color: parent.isAct ? "#FFFFFF" : root.fgCol
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(7.5)
                    font.bold: parent.isAct
                    anchors.centerIn: parent
                  }

                  MouseArea {
                    id: modeItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.editorContentMode = parent.modelData.id
                      if (parent.modelData.id === "code" && root.editorFontFamily === "sans-serif") {
                        root.editorFontFamily = "monospace"
                      }
                      root.showFeedback("Mode: " + parent.modelData.tip)
                    }
                  }

                  PanelToolTip {
                    visible: modeItemMouse.containsMouse
                    text: parent.modelData.tip
                  }
                }
              }
            }
          }

          // Right-Anchored: Font Family, Font Size SmartScrubber & Indentation Tools
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // 2. System Font Family Selector Trigger Button
            Rectangle {
              id: fontPickerTriggerBtn
              height: parent.height
              width: Style.space(112)
              radius: Style.space(3)
              color: root.fontPickerOpen ? Color.accent : (fpTrigMouse.containsMouse ? Util.alpha(root.fgCol, 0.14) : Util.alpha(root.fgCol, 0.05))
              border.width: 1
              border.color: root.fontPickerOpen ? Color.accent : (fpTrigMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(5)
                anchors.rightMargin: Style.space(5)
                spacing: Style.space(3)

                Text {
                  text: "󰛄"
                  color: root.fontPickerOpen ? "#FFFFFF" : Color.accent
                  font.pixelSize: Style.space(8.5)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: root.editorFontFamily
                  font.family: root.editorFontFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                  color: root.fontPickerOpen ? "#FFFFFF" : root.fgCol
                  elide: Text.ElideRight
                  width: parent.width - Style.space(24)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: root.fontPickerOpen ? "▴" : "▾"
                  color: root.fontPickerOpen ? "#FFFFFF" : Util.alpha(root.fgCol, 0.5)
                  font.pixelSize: Style.space(7)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: fpTrigMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.fontPickerOpen = !root.fontPickerOpen
                  if (root.fontPickerOpen) {
                    root.fontSearchQuery = ""
                    Qt.callLater(function() {
                      if (typeof fontSearchInput !== "undefined" && fontSearchInput) {
                        fontSearchInput.forceActiveFocus()
                      }
                    })
                  }
                }
              }

              PanelToolTip {
                visible: fpTrigMouse.containsMouse && !root.fontPickerOpen
                text: "Font: " + root.editorFontFamily + " (" + root.systemFontFamilies.length + " system fonts loaded)"
              }
            }

            // Separator |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // 3. Font Size SmartScrubber (drag horizontally, step +/- or double-click to type)
            SmartScrubber {
              height: parent.height
              label: "Size"
              value: root.editorFontSize
              from: 8
              to: 32
              step: 1
              unit: "pt"
              tip: "Font size: drag horizontally to adjust, double-click to type"
              onValueScrubbed: function(val) { root.editorFontSize = Math.round(val) }
              onValueCommitted: function(val) { root.editorFontSize = Math.round(val) }
            }

            // Separator |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // 4. Indent / Outdent / Tab Size / Line Numbers
            Row {
              height: parent.height
              spacing: Style.space(2)

              // Outdent (⇤)
              Rectangle {
                width: Style.space(20); height: parent.height; radius: Style.space(3)
                color: outdentMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
                border.width: 1
                border.color: outdentMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
                Text { text: "⇤"; color: root.fgCol; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                MouseArea { id: outdentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.outdentSelection() }
                PanelToolTip { visible: outdentMouse.containsMouse; text: "Outdent / Unindent (Shift+Tab)" }
              }

              // Indent (⇥)
              Rectangle {
                width: Style.space(20); height: parent.height; radius: Style.space(3)
                color: indentMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
                border.width: 1
                border.color: indentMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
                Text { text: "⇥"; color: root.fgCol; font.pixelSize: Style.space(9); anchors.centerIn: parent }
                MouseArea { id: indentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.indentSelection() }
                PanelToolTip { visible: indentMouse.containsMouse; text: "Indent (Tab)" }
              }

              // Tab Size Toggle (2sp vs 4sp)
              Rectangle {
                height: parent.height; width: Style.space(26); radius: Style.space(3)
                color: tabSizeMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
                border.width: 1
                border.color: tabSizeMouse.containsMouse ? Util.alpha(Color.accent, 0.5) : "transparent"
                Text { text: root.tabSize + "sp"; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                MouseArea {
                  id: tabSizeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.tabSize = root.tabSize === 2 ? 4 : 2
                    root.showFeedback("Tab size: " + root.tabSize + " spaces")
                  }
                }
                PanelToolTip { visible: tabSizeMouse.containsMouse; text: "Tab indentation: " + root.tabSize + " spaces (click to toggle)" }
              }

              // Line Numbers Toggle (#)
              Rectangle {
                width: Style.space(20); height: parent.height; radius: Style.space(3)
                color: root.showLineNumbers ? Util.alpha(Color.accent, 0.25) : (lnMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05))
                border.width: 1
                border.color: root.showLineNumbers ? Color.accent : (lnMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")
                Text { text: "#"; color: root.showLineNumbers ? Color.accent : root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(8.5); font.bold: true; anchors.centerIn: parent }
                MouseArea {
                  id: lnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.showLineNumbers = !root.showLineNumbers
                    root.showFeedback(root.showLineNumbers ? "Line numbers visible" : "Line numbers hidden")
                  }
                }
                PanelToolTip { visible: lnMouse.containsMouse; text: root.showLineNumbers ? "Hide line numbers" : "Show line numbers" }
              }
            }
          }
        }

        // -----------------------------------------------------
        // TOOLBAR ROW 2: TEXT FORMATTING (LEFT) & HEADINGS/COLORS (RIGHT)
        // -----------------------------------------------------
        Item {
          width: parent.width
          height: Style.space(25)

          // Left-Anchored: Inline text formatting & quote
          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // Bold
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: bMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: bMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "B"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: bMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("bold") } }
              PanelToolTip { visible: bMouse.containsMouse; text: "Bold (Ctrl+B)" }
            }
            // Italic
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: iMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: iMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "I"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(9); font.italic: true; anchors.centerIn: parent }
              MouseArea { id: iMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("italic") } }
              PanelToolTip { visible: iMouse.containsMouse; text: "Italic (Ctrl+I)" }
            }
            // Strike
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: sMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: sMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "S̶"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
              MouseArea { id: sMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("strike") } }
              PanelToolTip { visible: sMouse.containsMouse; text: "Strikethrough (~~text~~)" }
            }
            // Underline
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: uMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: uMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "U̲"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
              MouseArea { id: uMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("underline") } }
              PanelToolTip { visible: uMouse.containsMouse; text: "Underline (<u>text</u>)" }
            }
            // Code Inline
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: cMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: cMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "</>"; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: cMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("code") } }
              PanelToolTip { visible: cMouse.containsMouse; text: "Inline Code (`text`)" }
            }
            // Highlight
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: hlMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: hlMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "🖍️"; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
              MouseArea { id: hlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.surroundSelection("<mark>", "</mark>", "highlighted") } }
              PanelToolTip { visible: hlMouse.containsMouse; text: "Highlight (<mark>text</mark>)" }
            }
            // Superscript
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: supMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: supMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "x²"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: supMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("sup") } }
              PanelToolTip { visible: supMouse.containsMouse; text: "Superscript (<sup>text</sup>)" }
            }
            // Subscript
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: subMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: subMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "x₂"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: subMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("sub") } }
              PanelToolTip { visible: subMouse.containsMouse; text: "Subscript (<sub>text</sub>)" }
            }
            // Keyboard Key
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: kbdMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: kbdMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "<k>"; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: kbdMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyFormatting("kbd") } }
              PanelToolTip { visible: kbdMouse.containsMouse; text: "Keyboard Key (<kbd>key</kbd>)" }
            }
            // Clear Formatting
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: txMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: txMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "Tx"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: txMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.clearFormatting() } }
              PanelToolTip { visible: txMouse.containsMouse; text: "Clear Formatting from Selection" }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // Quote
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: quoteMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: quoteMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "❝"; color: root.fgCol; font.pixelSize: Style.space(8.5); anchors.centerIn: parent }
              MouseArea { id: quoteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.prefixCurrentLines("> ") } }
              PanelToolTip { visible: quoteMouse.containsMouse; text: "Blockquote (> ...)" }
            }
          }

          // Right-Anchored: Headings and Colors
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // Headings H1, H2, H3
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: h1Mouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: h1Mouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "H1"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: h1Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.prefixCurrentLines("# ") } }
              PanelToolTip { visible: h1Mouse.containsMouse; text: "Heading 1 (# ...)" }
            }
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: h2Mouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: h2Mouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "H2"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: h2Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.prefixCurrentLines("## ") } }
              PanelToolTip { visible: h2Mouse.containsMouse; text: "Heading 2 (## ...)" }
            }
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: h3Mouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: h3Mouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "H3"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea { id: h3Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.prefixCurrentLines("### ") } }
              PanelToolTip { visible: h3Mouse.containsMouse; text: "Heading 3 (### ...)" }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // Color Swatches & Studio Tools
            Row {
              height: parent.height
              spacing: Style.space(2)
              anchors.verticalCenter: parent.verticalCenter

              Repeater {
                model: root.presetColors
                Rectangle {
                  required property string modelData
                  width: Style.space(11); height: Style.space(11); radius: Style.space(5.5)
                  color: modelData
                  border.width: (String(root.currentColor).toLowerCase() === String(modelData).toLowerCase()) ? 2 : 1
                  border.color: (String(root.currentColor).toLowerCase() === String(modelData).toLowerCase()) ? (Color.popups.text || Color.text) : Util.alpha("#000000", 0.4)
                  scale: (String(root.currentColor).toLowerCase() === String(modelData).toLowerCase()) ? 1.2 : 1.0
                  anchors.verticalCenter: parent.verticalCenter

                  MouseArea {
                    id: clrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.currentColor = parent.modelData
                      root.applyColorSpan(parent.modelData)
                    }
                  }
                  PanelToolTip { visible: clrMouse.containsMouse; text: "Color tag: " + parent.modelData }
                }
              }

              // Custom Color Swatch (if currentColor is not in presets)
              Rectangle {
                visible: root.presetColors.indexOf(root.currentColor.toUpperCase()) === -1 && root.presetColors.indexOf(root.currentColor.toLowerCase()) === -1
                width: Style.space(11); height: Style.space(11); radius: Style.space(5.5)
                color: root.currentColor
                border.width: 2
                border.color: Color.accent
                scale: 1.2
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                  id: custClrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.applyColorSpan(root.currentColor)
                }
                PanelToolTip { visible: custClrMouse.containsMouse; text: "Custom Color: " + root.currentColor }
              }

              // Screen Ink Picker (Eyedropper)
              Rectangle {
                width: Style.space(15); height: Style.space(15); radius: Style.space(7.5)
                color: tedMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(root.fgCol, 0.08)
                border.width: 1
                border.color: tedMouse.containsMouse ? Util.alpha(Color.accent, 0.6) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "󰈊"; color: tedMouse.containsMouse ? Color.accent : root.fgCol; font.pixelSize: Style.space(7.5); anchors.centerIn: parent }
                MouseArea {
                  id: tedMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.requestScreenPick()
                }
                PanelToolTip { visible: tedMouse.containsMouse; text: "Pick text color from screen" }
              }

              // Color Studio (Custom Palette & Shades)
              Rectangle {
                width: Style.space(15); height: Style.space(15); radius: Style.space(7.5)
                color: tcStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(root.fgCol, 0.08)
                border.width: 1
                border.color: tcStudioMouse.containsMouse ? Util.alpha(Color.accent, 0.6) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "󰏘"; color: tcStudioMouse.containsMouse ? Color.accent : root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
                MouseArea {
                  id: tcStudioMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.requestColorPicker()
                }
                PanelToolTip { visible: tcStudioMouse.containsMouse; text: "Open Color Studio (Custom Palette & Shades)" }
              }
            }
          }
        }

        // -----------------------------------------------------
        // TOOLBAR ROW 3: LISTS, INSERTS, BLOCKS & CALLOUTS
        // -----------------------------------------------------
        Row {
          width: parent.width
          height: Style.space(25)
          spacing: Style.space(3)

          // Lists
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: ulMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: ulMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "•—"; color: root.fgCol; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: ulMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.prefixCurrentLines("- ") } }
            PanelToolTip { visible: ulMouse.containsMouse; text: "Bullet List (- ...)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: olMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: olMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "1."; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: olMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.numberCurrentLines() } }
            PanelToolTip { visible: olMouse.containsMouse; text: "Numbered List (1. ...)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: taskMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: taskMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "☑"; color: root.fgCol; font.pixelSize: Style.space(9); anchors.centerIn: parent }
            MouseArea { id: taskMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.prefixCurrentLines("- [ ] ") } }
            PanelToolTip { visible: taskMouse.containsMouse; text: "Task Checklist (- [ ] ...)" }
          }

          // Divider |
          Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

          // Inserts: Code, Table, Link, Image, Line, Time, Footnote
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: cbMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: cbMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "💻"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: cbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("```javascript\n// code here\n```\n") } }
            PanelToolTip { visible: cbMouse.containsMouse; text: "Fenced Code Block (```)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: tableMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: tableMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "⊞"; color: root.fgCol; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: tableMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("| Column 1 | Column 2 | Column 3 |\n| :--- | :---: | ---: |\n| Item 1 | Value A | 100 |\n| Item 2 | Value B | 200 |\n") } }
            PanelToolTip { visible: tableMouse.containsMouse; text: "Markdown Table" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: linkMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: linkMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🔗"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: linkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertLink() } }
            PanelToolTip { visible: linkMouse.containsMouse; text: "Hyperlink ([text](url))" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: imgMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: imgMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🖼️"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: imgMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("![Image description](https://example.com/image.png)\n") } }
            PanelToolTip { visible: imgMouse.containsMouse; text: "Image (![alt](url))" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: hrMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: hrMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "―"; color: root.fgCol; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: hrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("---\n") } }
            PanelToolTip { visible: hrMouse.containsMouse; text: "Horizontal Divider (---)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: tsMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: tsMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🕒"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: tsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertTimestamp() } }
            PanelToolTip { visible: tsMouse.containsMouse; text: "Insert Current Date/Time" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: fnMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: fnMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🦶"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: fnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertFootnote() } }
            PanelToolTip { visible: fnMouse.containsMouse; text: "Insert Footnote ([^1])" }
          }

          // Divider |
          Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

          // Blocks: LaTeX Math, Details Accordion, Mermaid & Comment
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: mathMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: mathMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "📐"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: mathMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("$$\n\\frac{a}{b} = c\n$$\n") } }
            PanelToolTip { visible: mathMouse.containsMouse; text: "LaTeX Math Block ($$ ... $$)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: detailsMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: detailsMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🔽"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: detailsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("<details>\n<summary>Details Header</summary>\n\nHidden content here.\n</details>\n") } }
            PanelToolTip { visible: detailsMouse.containsMouse; text: "Collapsible Details (<details>)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: mermaidMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: mermaidMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "📊"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: mermaidMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("```mermaid\ngraph TD;\n    A[Start] --> B[Result];\n```\n") } }
            PanelToolTip { visible: mermaidMouse.containsMouse; text: "Mermaid Diagram Block (```mermaid)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: commentMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: commentMouse.containsMouse ? Util.alpha(Color.accent, 0.6) : "transparent"
            Text { text: "💬"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: commentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.toggleComment() } }
            PanelToolTip { visible: commentMouse.containsMouse; text: "Toggle Line Comment (//, <!-- -->, #)" }
          }

          // Divider |
          Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

          // Callouts (GitHub Alert Style)
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: noteMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: noteMouse.containsMouse ? Util.alpha(Color.accent, 0.6) : "transparent"
            Text { text: "💡"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: noteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("> [!NOTE]\n> Note details here.\n") } }
            PanelToolTip { visible: noteMouse.containsMouse; text: "Callout Note (> [!NOTE])" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: tipMouse.containsMouse ? Util.alpha("#10B981", 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: tipMouse.containsMouse ? Util.alpha("#10B981", 0.6) : "transparent"
            Text { text: "🚀"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: tipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("> [!TIP]\n> Tip details here.\n") } }
            PanelToolTip { visible: tipMouse.containsMouse; text: "Callout Tip (> [!TIP])" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: warnMouse.containsMouse ? Util.alpha("#EAB308", 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: warnMouse.containsMouse ? Util.alpha("#EAB308", 0.6) : "transparent"
            Text { text: "⚠️"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: warnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("> [!WARNING]\n> Warning details here.\n") } }
            PanelToolTip { visible: warnMouse.containsMouse; text: "Callout Warning (> [!WARNING])" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: infoMouse.containsMouse ? Util.alpha("#3B82F6", 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: infoMouse.containsMouse ? Util.alpha("#3B82F6", 0.6) : "transparent"
            Text { text: "ℹ️"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: infoMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("> [!IMPORTANT]\n> Important details here.\n") } }
            PanelToolTip { visible: infoMouse.containsMouse; text: "Callout Important (> [!IMPORTANT])" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: cautionMouse.containsMouse ? Util.alpha("#EF4444", 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: cautionMouse.containsMouse ? Util.alpha("#EF4444", 0.6) : "transparent"
            Text { text: "🔥"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: cautionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.insertBlock("> [!CAUTION]\n> Caution details here.\n") } }
            PanelToolTip { visible: cautionMouse.containsMouse; text: "Callout Caution (> [!CAUTION])" }
          }
        }

        // -----------------------------------------------------
        // TOOLBAR ROW 4: TEXT TRANSFORMATIONS & ENCODINGS
        // -----------------------------------------------------
        Row {
          width: parent.width
          height: Style.space(25)
          spacing: Style.space(3)

          // Case Conversions (Clean Typographic Glyphs)
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: upMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: upMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "AA"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: upMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("upper") } }
            PanelToolTip { visible: upMouse.containsMouse; text: "Convert to UPPERCASE" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: lowMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: lowMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "aa"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: lowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("lower") } }
            PanelToolTip { visible: lowMouse.containsMouse; text: "Convert to lowercase" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: tcMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: tcMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "Aa"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: tcMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("title") } }
            PanelToolTip { visible: tcMouse.containsMouse; text: "Convert to Title Case" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: sentMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: sentMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "s."; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: sentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("sentence") } }
            PanelToolTip { visible: sentMouse.containsMouse; text: "Convert to Sentence case" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: ccMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: ccMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "aB"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: ccMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("camel") } }
            PanelToolTip { visible: ccMouse.containsMouse; text: "Convert to camelCase" }
          }
          Rectangle {
            width: Style.space(24); height: parent.height; radius: Style.space(3)
            color: kcMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: kcMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "a-b"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: kcMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("kebab") } }
            PanelToolTip { visible: kcMouse.containsMouse; text: "Convert to kebab-case" }
          }
          Rectangle {
            width: Style.space(24); height: parent.height; radius: Style.space(3)
            color: scMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: scMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "a_b"; color: root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: scMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("snake") } }
            PanelToolTip { visible: scMouse.containsMouse; text: "Convert to snake_case" }
          }

          // Divider |
          Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

          // Clean & Format (Icons with Tooltips)
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: jpMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: jpMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "✨"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: jpMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("json_pretty") } }
            PanelToolTip { visible: jpMouse.containsMouse; text: "Beautify & Format JSON" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: jmMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: jmMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "📦"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: jmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("json_minify") } }
            PanelToolTip { visible: jmMouse.containsMouse; text: "Minify JSON Compactly" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: trMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: trMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "✂️"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: trMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("trim") } }
            PanelToolTip { visible: trMouse.containsMouse; text: "Trim Leading/Trailing Whitespace" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: rblMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: rblMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "⊘"; color: root.fgCol; font.pixelSize: Style.space(8.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: rblMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("remove_empty_lines") } }
            PanelToolTip { visible: rblMouse.containsMouse; text: "Remove Empty / Blank Lines" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: jlMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: jlMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "⇲"; color: root.fgCol; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: jlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("join_lines") } }
            PanelToolTip { visible: jlMouse.containsMouse; text: "Join Lines into Paragraphs" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: smMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: smMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "📝"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: smMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("strip_md") } }
            PanelToolTip { visible: smMouse.containsMouse; text: "Strip Markdown Tags to Plain Text" }
          }
          Rectangle {
            width: Style.space(28); height: parent.height; radius: Style.space(3)
            color: slugMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: slugMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "slug"; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: slugMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("slug") } }
            PanelToolTip { visible: slugMouse.containsMouse; text: "Convert to URL-friendly Slug (e.g. hello-world)" }
          }

          // Divider |
          Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

          // Encodings & Line Utilities
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: b64eMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: b64eMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🔐"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: b64eMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("base64_encode") } }
            PanelToolTip { visible: b64eMouse.containsMouse; text: "Base64 Encode" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: b64dMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: b64dMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🔓"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: b64dMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("base64_decode") } }
            PanelToolTip { visible: b64dMouse.containsMouse; text: "Base64 Decode" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: ueMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: ueMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "🌐"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea { id: ueMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("url_encode") } }
            PanelToolTip { visible: ueMouse.containsMouse; text: "URL Encode" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: udMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: udMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "%"; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(8.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: udMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("url_decode") } }
            PanelToolTip { visible: udMouse.containsMouse; text: "URL Decode (%20 to text)" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: htmlMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: htmlMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "&;"; color: root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: htmlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("html_escape") } }
            PanelToolTip { visible: htmlMouse.containsMouse; text: "HTML Entity Escape / Unescape (& < > \" ')" }
          }
          Rectangle {
            width: Style.space(22); height: parent.height; radius: Style.space(3)
            color: revMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
            border.width: 1; border.color: revMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
            Text { text: "⇄"; color: root.fgCol; font.pixelSize: Style.space(9); font.bold: true; anchors.centerIn: parent }
            MouseArea { id: revMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("reverse_lines") } }
            PanelToolTip { visible: revMouse.containsMouse; text: "Reverse Line Order (bottom to top)" }
          }
        }

        // -----------------------------------------------------
        // TOOLBAR ROW 5: ORGANIZE, VARIABLES & EDITOR UTILITIES
        // -----------------------------------------------------
        Item {
          width: parent.width
          height: Style.space(24)

          // Left-Anchored: Sort, Dedup, Shuffle, and Variables
          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // Sort Ascending (A-Z)
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: saMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: saMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "🔀"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea { id: saMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("sort_asc") } }
              PanelToolTip { visible: saMouse.containsMouse; text: "Sort Lines Alphabetically (A-Z)" }
            }
            // Sort Descending (Z-A)
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: sdMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: sdMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "🔃"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea { id: sdMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("sort_desc") } }
              PanelToolTip { visible: sdMouse.containsMouse; text: "Sort Lines Descending (Z-A)" }
            }
            // Dedup
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: ddMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: ddMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "🗑️"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea { id: ddMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("dedup") } }
              PanelToolTip { visible: ddMouse.containsMouse; text: "Remove Duplicate Lines (Dedup)" }
            }
            // Shuffle Lines
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: shufMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: shufMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "🎲"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea { id: shufMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.applyTransform("shuffle_lines") } }
              PanelToolTip { visible: shufMouse.containsMouse; text: "Shuffle / Randomize Line Order" }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // Template Variables Pills
            Repeater {
              model: ["{{date}}", "{{time}}", "{{clipboard}}", "{{uuid}}"]
              Rectangle {
                required property string modelData
                height: parent.height
                width: pillTxt.implicitWidth + Style.space(6)
                radius: Style.space(3)
                color: pillMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.accent, 0.09)
                border.width: 1
                border.color: pillMouse.containsMouse ? Color.accent : "transparent"

                Text {
                  id: pillTxt
                  text: parent.modelData
                  color: Color.accent
                  font.family: "monospace"
                  font.pixelSize: Style.space(7)
                  font.bold: true
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: pillMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function() {
                    editorInput.insert(editorInput.cursorPosition, parent.modelData)
                    root.editorContent = editorInput.text
                    editorInput.forceActiveFocus()
                  }
                }

                PanelToolTip {
                  visible: pillMouse.containsMouse
                  text: "Insert variable " + parent.modelData
                }
              }
            }
          }

          // Right-Anchored: Utilities (Duplicate, Find, Wrap, Clear)
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // Duplicate Line or Selection
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: dupMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: dupMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "📄"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea { id: dupMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function() { root.duplicateLineOrSelection() } }
              PanelToolTip { visible: dupMouse.containsMouse; text: "Duplicate Line or Selection (Ctrl+D)" }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // Quick Find Toggle
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: root.searchOpen ? Util.alpha(Color.accent, 0.3) : (fndMouse.containsMouse ? Util.alpha(root.fgCol, 0.12) : Util.alpha(root.fgCol, 0.05))
              border.width: 1
              border.color: root.searchOpen ? Color.accent : (fndMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")

              Text { text: "🔍"; font.pixelSize: Style.space(8); anchors.centerIn: parent }

              MouseArea {
                id: fndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() {
                  root.searchOpen = !root.searchOpen
                  if (root.searchOpen) searchInputField.forceActiveFocus()
                }
              }

              PanelToolTip {
                visible: fndMouse.containsMouse
                text: "Toggle Find & Replace (Ctrl+F)"
              }
            }

            // Soft Wrap Toggle
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: root.wrapEditorText ? Util.alpha(Color.accent, 0.3) : (wrapMouse.containsMouse ? Util.alpha(root.fgCol, 0.12) : Util.alpha(root.fgCol, 0.05))
              border.width: 1
              border.color: root.wrapEditorText ? Color.accent : (wrapMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")

              Text { text: "↩"; color: root.wrapEditorText ? Color.accent : root.fgCol; font.pixelSize: Style.space(8.5); font.bold: true; anchors.centerIn: parent }

              MouseArea {
                id: wrapMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.wrapEditorText = !root.wrapEditorText }
              }

              PanelToolTip {
                visible: wrapMouse.containsMouse
                text: root.wrapEditorText ? "Word Wrap: ON (click to disable)" : "Word Wrap: OFF (click to enable)"
              }
            }


            // Clear Editor Button
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: clrMouse.containsMouse ? Util.alpha("#EF4444", 0.25) : Util.alpha(root.fgCol, 0.05)
              border.width: 1
              border.color: clrMouse.containsMouse ? Util.alpha("#EF4444", 0.6) : "transparent"

              Text { text: "✕"; color: clrMouse.containsMouse ? "#EF4444" : root.fgCol; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }

              MouseArea {
                id: clrMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.clearEditor() }
              }

              PanelToolTip {
                visible: clrMouse.containsMouse
                text: "Clear all editor content"
              }
            }
          }
        }

        // -----------------------------------------------------
        // TOOLBAR ROW 6: DATA STUDIO, DEVELOPER & EXPORT SUITE
        // -----------------------------------------------------
        Item {
          width: parent.width
          height: Style.space(25)

          // Left-Anchored: Markdown Tables, Dev Encoders & Checklists
          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // --- Markdown Table Studio ---
            // 1. Table Auto-Align / Beautify
            Rectangle {
              width: Style.space(24); height: parent.height; radius: Style.space(3)
              color: tblFmtMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: tblFmtMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "⊞✨"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea {
                id: tblFmtMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.formatMarkdownTable() }
              }
              PanelToolTip { visible: tblFmtMouse.containsMouse; text: "Beautify / Auto-align Markdown Table columns" }
            }

            // 2. CSV ⇄ Markdown Table Converter
            Rectangle {
              width: Style.space(38); height: parent.height; radius: Style.space(3)
              color: csvTblMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: csvTblMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "CSV⇄⊞"; color: csvTblMouse.containsMouse ? Color.accent : root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: csvTblMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.convertCsvTable() }
              }
              PanelToolTip { visible: csvTblMouse.containsMouse; text: "Convert CSV/TSV ⇄ Markdown Table (bidirectional)" }
            }

            // 3. Markdown Table to JSON Array
            Rectangle {
              width: Style.space(28); height: parent.height; radius: Style.space(3)
              color: tblJsonMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: tblJsonMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "⊞→{}"; color: tblJsonMouse.containsMouse ? Color.accent : root.fgCol; font.family: root.fontFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: tblJsonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.convertTableToJson() }
              }
              PanelToolTip { visible: tblJsonMouse.containsMouse; text: "Convert Markdown Table into JSON Object Array" }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // --- Developer Encoders & Parsers ---
            // 4. JWT Token Decoder
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: jwtMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: jwtMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "🎫"; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea {
                id: jwtMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.decodeJwtToken() }
              }
              PanelToolTip { visible: jwtMouse.containsMouse; text: "Decode JWT Token (Header & Payload to JSON)" }
            }

            // 5. Escape / Unescape String Literals
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: escMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: escMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "\\\""; color: escMouse.containsMouse ? Color.accent : root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(8); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: escMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.toggleEscapeStringLiterals() }
              }
              PanelToolTip { visible: escMouse.containsMouse; text: "Escape / Unescape String Literals (\\n, \\t, \\\")" }
            }

            // 6. Wrap Lines in Quotes & Commas
            Rectangle {
              width: Style.space(24); height: parent.height; radius: Style.space(3)
              color: wrapQuotesMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: wrapQuotesMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "\"l\","; color: wrapQuotesMouse.containsMouse ? Color.accent : root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: wrapQuotesMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.wrapLinesInQuotes() }
              }
              PanelToolTip { visible: wrapQuotesMouse.containsMouse; text: "Wrap Lines in Quotes & Commas (SQL IN / Code arrays)" }
            }

            // 7. Hex ⇄ ASCII Plain Text
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: hexMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: hexMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "0x"; color: hexMouse.containsMouse ? Color.accent : root.fgCol; font.family: "monospace"; font.pixelSize: Style.space(7.5); font.bold: true; anchors.centerIn: parent }
              MouseArea {
                id: hexMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.convertHexText() }
              }
              PanelToolTip { visible: hexMouse.containsMouse; text: "Convert Hex ⇄ ASCII Plain Text" }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // --- Checklist & Task Automation ---
            // 8. Toggle All Checkboxes
            Rectangle {
              width: Style.space(28); height: parent.height; radius: Style.space(3)
              color: chkAllMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: chkAllMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "☑⇄☐"; color: chkAllMouse.containsMouse ? Color.accent : root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea {
                id: chkAllMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.toggleCheckboxes() }
              }
              PanelToolTip { visible: chkAllMouse.containsMouse; text: "Toggle all Markdown Checkboxes (- [ ] ⇄ - [x])" }
            }

            // 9. Sort Tasks by Completion Status
            Rectangle {
              width: Style.space(24); height: parent.height; radius: Style.space(3)
              color: chkSortMouse.containsMouse ? Util.alpha(Color.accent, 0.22) : Util.alpha(root.fgCol, 0.05)
              border.width: 1; border.color: chkSortMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent"
              Text { text: "☑↕"; color: chkSortMouse.containsMouse ? Color.accent : root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
              MouseArea {
                id: chkSortMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.sortTasksByCompletion() }
              }
              PanelToolTip { visible: chkSortMouse.containsMouse; text: "Sort Tasks (Incomplete pending tasks first, completed last)" }
            }
          }

          // Right-Anchored: Templates Dropdown & Export Controls
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Style.space(3)

            // Boilerplates Dropdown Trigger
            Rectangle {
              id: boilerplateTriggerBtn
              width: Style.space(72); height: parent.height; radius: Style.space(3)
              color: root.boilerplateMenuOpen ? Util.alpha(Color.accent, 0.3) : (tplTriggerMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fgCol, 0.05))
              border.width: 1
              border.color: root.boilerplateMenuOpen ? Color.accent : (tplTriggerMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")

              Row {
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "⚡"; font.pixelSize: Style.space(7.5) }
                Text {
                  text: "Templates ▾"
                  color: root.boilerplateMenuOpen ? Color.accent : root.fgCol
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                }
              }

              MouseArea {
                id: tplTriggerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.boilerplateMenuOpen = !root.boilerplateMenuOpen }
              }

              PanelToolTip {
                visible: tplTriggerMouse.containsMouse && !root.boilerplateMenuOpen
                text: "Insert Code & Document Templates (Bash, Python, HTML, README, etc.)"
              }
            }

            // Divider |
            Rectangle { width: 1; height: parent.height - Style.space(6); anchors.verticalCenter: parent.verticalCenter; color: Util.alpha(root.borderCol, 0.6) }

            // Copy as Rich HTML
            Rectangle {
              width: Style.space(34); height: parent.height; radius: Style.space(3)
              color: copyHtmlMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(root.fgCol, 0.05)
              border.width: 1
              border.color: copyHtmlMouse.containsMouse ? Util.alpha(Color.accent, 0.6) : "transparent"

              Text {
                text: "HTML"
                color: copyHtmlMouse.containsMouse ? Color.accent : root.fgCol
                font.family: root.fontFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                anchors.centerIn: parent
              }

              MouseArea {
                id: copyHtmlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.copyAsRichHtml() }
              }

              PanelToolTip {
                visible: copyHtmlMouse.containsMouse
                text: "Copy as Rich Text / HTML (for LibreOffice, Discord, Google Docs)"
              }
            }

            // Save As File Drawer Toggle
            Rectangle {
              width: Style.space(22); height: parent.height; radius: Style.space(3)
              color: root.saveDrawerOpen ? Util.alpha("#10B981", 0.3) : (saveDrawMouse.containsMouse ? Util.alpha(root.fgCol, 0.12) : Util.alpha(root.fgCol, 0.05))
              border.width: 1
              border.color: root.saveDrawerOpen ? "#10B981" : (saveDrawMouse.containsMouse ? Util.alpha(root.borderCol, 0.6) : "transparent")

              Text { text: "💾"; font.pixelSize: Style.space(8); anchors.centerIn: parent }

              MouseArea {
                id: saveDrawMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.saveDrawerOpen = !root.saveDrawerOpen }
              }

              PanelToolTip {
                visible: saveDrawMouse.containsMouse
                text: "Save Editor Content to File on Disk (Toggle Drawer)"
              }
            }
          }
        }
      }
    }

    // ==========================================
    // 5. SAVE AS SNIPPET INLINE BAR (When active)
    // ==========================================
    Rectangle {
      visible: root.isSaveAsSnippetMode
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(32)
      color: Util.alpha("#A855F7", 0.1)
      border.width: 1
      border.color: Util.alpha("#A855F7", 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: "Save as Snippet Title:"
          color: "#C084FC"
          font.family: root.fontFamily
          font.pixelSize: Style.space(8.5)
          font.bold: true
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(22)
          radius: Style.space(3)
          color: Util.alpha(root.fgCol, 0.08)
          border.width: 1
          border.color: newSnippetTitleInput.activeFocus ? "#A855F7" : Util.alpha(root.borderCol, 0.5)

          TextInput {
            id: newSnippetTitleInput
            anchors.fill: parent
            anchors.margins: Style.space(4)
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            text: root.newSnippetTitle
            onTextEdited: function() { root.newSnippetTitle = text }
            onAccepted: function() { root.confirmSaveAsSnippet() }
          }
        }

        Rectangle {
          Layout.preferredHeight: Style.space(22)
          Layout.preferredWidth: Style.space(70)
          radius: Style.space(4)
          color: "#A855F7"

          Text {
            text: "Save Snippet"
            color: "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: Style.space(8)
            font.bold: true
            anchors.centerIn: parent
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.confirmSaveAsSnippet() }
          }
        }

        Rectangle {
          Layout.preferredHeight: Style.space(22)
          Layout.preferredWidth: Style.space(50)
          radius: Style.space(4)
          color: Util.alpha(root.fgCol, 0.1)

          Text {
            text: "Cancel"
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.space(8)
            anchors.centerIn: parent
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: function() { root.isSaveAsSnippetMode = false }
          }
        }
      }
    }

    // =========================================================================
    // 6. MAIN WORKSPACE: VERTICAL SPLIT (TOP: SOURCE, BOTTOM: LIVE PREVIEW)
    // Docked edge-to-edge, clean 0 margin matching ImageEditorModal!
    // =========================================================================
    Item {
      id: workspaceItem
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      Column {
        anchors.fill: parent
        spacing: 0

        // -----------------------------------------------------
        // TOP PANE: SOURCE EDITOR
        // -----------------------------------------------------
        Rectangle {
          id: editorContainer
          visible: root.viewMode === "split" || root.viewMode === "edit"
          width: parent.width
          height: root.viewMode === "split" ? Math.floor(parent.height / 2) : parent.height
          color: "transparent"
          clip: true

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Pane Header Tab
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(22)
              color: Util.alpha(root.fgCol, 0.03)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  text: {
                    if (root.editorContentMode === "rich") return "📝 SOURCE (HTML RICH TEXT)"
                    if (root.editorContentMode === "code") return "💻 SOURCE (CODE)"
                    if (root.editorContentMode === "text") return "📄 SOURCE (PLAIN TEXT)"
                    return "📝 SOURCE (MARKDOWN)"
                  }
                  color: Util.alpha(root.fgCol, 0.65)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: editorInput.selectionStart !== editorInput.selectionEnd ? ((editorInput.selectionEnd - editorInput.selectionStart) + " chars selected") : ""
                  color: Color.accent
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                }

                Text {
                  text: (root.wrapEditorText ? "Wrap: ON" : "Wrap: OFF")
                  color: Util.alpha(root.fgCol, 0.4)
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Util.alpha(root.borderCol, 0.4)
              }
            }

            // Editor Scrollable Area with Line Numbers
            Flickable {
              id: editorFlickable
              Layout.fillWidth: true
              Layout.fillHeight: true
              contentWidth: root.wrapEditorText ? width : Math.max(width, editorInput.implicitWidth + gutterContainer.width + Style.space(32))
              contentHeight: Math.max(height, editorInput.implicitHeight + Style.space(32))
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              ScrollBar.horizontal: ScrollBar { policy: root.wrapEditorText ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded }

              Row {
                width: root.wrapEditorText ? parent.width : Math.max(parent.width, editorInput.implicitWidth + gutterContainer.width + Style.space(32))
                spacing: Style.space(8)
                anchors.top: parent.top
                anchors.topMargin: Style.space(4)
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)

                // Line Numbers Gutter
                Item {
                  id: gutterContainer
                  visible: root.showLineNumbers
                  width: root.showLineNumbers ? Math.max(Style.space(28), Style.space(10) + (String(root.editorContent.split("\n").length).length * Style.space(7))) : 0
                  height: Math.max(editorFlickable.height, editorInput.height)

                  Text {
                    id: gutterText
                    visible: root.showLineNumbers
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(6)
                    text: root.generateLineNumbers(root.editorContent)
                    color: Util.alpha(root.fgCol, 0.3)
                    font.family: root.editorFontFamily
                    font.pixelSize: Style.space(root.editorFontSize)
                    horizontalAlignment: Text.AlignRight
                  }

                  Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Util.alpha(root.borderCol, 0.35)
                  }
                }

                // Text Editor Area
                Item {
                  id: editorArea
                  width: root.wrapEditorText ? (editorFlickable.width - (root.showLineNumbers ? gutterContainer.width : 0) - Style.space(24)) : Math.max(editorFlickable.width - (root.showLineNumbers ? gutterContainer.width : 0) - Style.space(24), editorInput.implicitWidth)
                  height: Math.max(editorFlickable.height, editorInput.implicitHeight)

                  // Active Text Input
                  TextEdit {
                    id: editorInput
                    anchors.fill: parent
                    color: root.fgCol
                    selectionColor: Color.accent
                    selectedTextColor: "#ffffff"
                    font.family: root.editorFontFamily
                    font.pixelSize: Style.space(root.editorFontSize)
                    wrapMode: root.wrapEditorText ? TextEdit.Wrap : TextEdit.NoWrap
                    selectByMouse: true
                    cursorDelegate: Rectangle {
                      width: 2
                      color: Color.accent
                      visible: editorInput.cursorVisible && editorInput.activeFocus
                    }

                    Keys.onTabPressed: function(event) {
                      var sp = root.tabSize === 4 ? "    " : "  "
                      insert(cursorPosition, sp)
                      event.accepted = true
                    }

                    onTextChanged: function() {
                      if (root.editorContent !== text) {
                        root.editorContent = text
                      }
                      root.schedulePreviewUpdate()
                    }

                    onCursorPositionChanged: {
                      var pos = cursorPosition
                      var txt = text || ""
                      var sub = txt.substring(0, pos)
                      var lines = sub.split("\n")
                      root.cursorLine = lines.length
                      root.cursorCol = lines[lines.length - 1].length + 1
                    }
                  }
                }
              }
            }
          }
        }

        // Divider Line between Panes (Visible in Split Mode)
        Rectangle {
          visible: root.viewMode === "split"
          width: parent.width
          height: 1
          color: Util.alpha(root.borderCol, 0.5)
        }

        // -----------------------------------------------------
        // BOTTOM PANE: LIVE RENDERED PREVIEW
        // -----------------------------------------------------
        Rectangle {
          id: previewContainer
          visible: root.viewMode === "split" || root.viewMode === "preview"
          width: parent.width
          height: root.viewMode === "split" ? (parent.height - Math.floor(parent.height / 2) - 1) : parent.height
          color: Util.alpha(root.fgCol, 0.015)
          clip: true

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Bottom Pane Header Tab
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(22)
              color: Util.alpha(root.fgCol, 0.03)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)

                Text {
                  text: {
                    if (root.editorContentMode === "rich") return "👁️ LIVE PREVIEW (HTML RENDERED)"
                    if (root.editorContentMode === "code") return "👁️ PREVIEW (SOURCE CODE)"
                    if (root.editorContentMode === "text") return "👁️ PREVIEW (PLAIN TEXT)"
                    return "👁️ LIVE PREVIEW (COMMONMARK RENDERED)"
                  }
                  color: Util.alpha(root.fgCol, 0.65)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: "Click links to open externally"
                  color: Util.alpha(root.fgCol, 0.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(7.5)
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Util.alpha(root.borderCol, 0.4)
              }
            }

            // Preview Flickable
            Flickable {
              id: previewFlickable
              Layout.fillWidth: true
              Layout.fillHeight: true
              contentWidth: width
              contentHeight: Math.max(height, previewText.implicitHeight + Style.space(32))
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              Text {
                id: previewText
                width: parent.width - Style.space(24)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(8)
                text: root.renderedPreviewHtml.length > 0 ? root.renderedPreviewHtml : "<div style=\"color:" + Util.alpha(root.fgCol, 0.4) + "; font-style: italic;\">*No content to preview*</div>"
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: root.fgCol
                font.family: (root.editorContentMode === "code" || root.editorContentMode === "text") ? root.editorFontFamily : root.fontFamily
                font.pixelSize: (root.editorContentMode === "code") ? Style.space(root.editorFontSize) : Style.font.body
                lineHeight: 1.25

                onLinkActivated: function(link) {
                  Qt.openUrlExternally(link)
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // 7. TWO-TIER BOTTOM STATUS & ACTION BAR
    // ==========================================
    Rectangle {
      id: footerContainer
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(58)
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Row 1: Action Controls & Feedback Toast
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(34)
          Layout.leftMargin: Style.space(10)
          Layout.rightMargin: Style.space(10)
          spacing: Style.space(8)

          // Left: Save as Snippet button (for History clips)
          Rectangle {
            visible: root.targetType === "clip" && !root.isSaveAsSnippetMode
            height: Style.space(22)
            width: snipBtnRow.implicitWidth + Style.space(12)
            radius: Style.space(3)
            color: snipBtnMouse.containsMouse ? Util.alpha("#A855F7", 0.25) : Util.alpha("#A855F7", 0.12)
            border.width: 1
            border.color: Util.alpha("#A855F7", 0.4)

            Row {
              id: snipBtnRow
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text { text: "💾"; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
              Text {
                text: "Save as Snippet…"
                color: "#C084FC"
                font.family: root.fontFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: snipBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function() {
                root.isSaveAsSnippetMode = true
                var firstLine = root.editorContent.split("\n")[0].trim()
                root.newSnippetTitle = firstLine ? firstLine.substring(0, 35) : "New Snippet"
              }
            }

            PanelToolTip {
              visible: snipBtnMouse.containsMouse
              text: "Save clip as reusable snippet"
            }
          }

          // Center: Flexible Toast / Feedback Pill
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
              id: fbPill
              visible: root.feedbackText.length > 0
              anchors.centerIn: parent
              height: Style.space(22)
              width: Math.min(parent.width - Style.space(10), fbRow.implicitWidth + Style.space(16))
              radius: Style.space(3)
              color: Util.alpha(Color.accent, 0.2)
              border.width: 1
              border.color: Color.accent

              Row {
                id: fbRow
                anchors.centerIn: parent
                spacing: Style.space(4)
                width: Math.min(parent.width - Style.space(8), implicitWidth)

                Text {
                  text: "✓"
                  color: Color.accent
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: fbTxt
                  text: root.feedbackText
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, fbPill.width - Style.space(24))
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }

          // Right: Action Buttons: Cancel and Save
          Row {
            spacing: Style.space(8)
            Layout.alignment: Qt.AlignVCenter

            // Cancel
            Rectangle {
              width: Style.space(68)
              height: Style.space(24)
              radius: Style.space(4)
              color: cancelMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : Util.alpha(root.fgCol, 0.08)
              border.width: 1
              border.color: Util.alpha(root.borderCol, 0.6)

              Text {
                text: "Cancel"
                color: root.fgCol
                font.family: root.fontFamily
                font.pixelSize: Style.space(8.5)
                anchors.centerIn: parent
              }

              MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.close() }
              }
            }

            // Save
            Rectangle {
              width: saveTxt.implicitWidth + Style.space(18)
              height: Style.space(24)
              radius: Style.space(4)
              color: saveMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

              Row {
                id: saveTxt
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text {
                  text: "✓"
                  color: "#ffffff"
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: root.targetType === "snippet" ? "Save Snippet" : "Save Clip"
                  color: "#ffffff"
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: saveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function() { root.save() }
              }
            }
          }
        }

        // Hairline Divider
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Util.alpha(root.borderCol, 0.3)
        }

        // Row 2: Dedicated Status & Document Statistics Strip
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(22)
          color: Util.alpha("#000000", 0.18)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            // Statistics (Lines, Words, Chars, Selection)
            Row {
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignVCenter

              Text {
                text: "📄 " + (root.editorContent.split("\n").length) + " lines"
                color: Util.alpha(root.fgCol, 0.65)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: Util.alpha(root.fgCol, 0.35)
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "🔤 " + (root.editorContent.trim().length === 0 ? 0 : root.editorContent.trim().split(/\s+/).length) + " words"
                color: Util.alpha(root.fgCol, 0.65)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: Util.alpha(root.fgCol, 0.35)
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "🔠 " + root.editorContent.length + " chars"
                color: Util.alpha(root.fgCol, 0.65)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                visible: editorInput.selectedText.length > 0
                text: "(" + editorInput.selectedText.length + " sel)"
                color: Color.accent
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Item { Layout.fillWidth: true }

            // Editor Metadata & Cursor Position
            Row {
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignVCenter

              Text {
                text: "Ln " + root.cursorLine + ", Col " + root.cursorCol
                color: Util.alpha(root.fgCol, 0.55)
                font.family: "monospace"
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: Util.alpha(root.fgCol, 0.35)
                font.pixelSize: Style.space(7.5)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: (root.editorContentMode === "code" ? (root.codeLanguage || "code").toUpperCase() : root.editorContentMode.toUpperCase())
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                visible: root.isModified
                text: "● Edited"
                color: "#EAB308"
                font.family: root.fontFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }
  }

  // =========================================================================
  // 8. SEARCHABLE SYSTEM FONT PICKER POPOVER MODAL
  // Floats over workspace with z: 200, matching Image Studio Font Picker
  // =========================================================================
  Item {
    id: fontPickerOverlay
    visible: root.fontPickerOpen
    anchors.fill: parent
    z: 200

    // Dismiss backdrop
    MouseArea {
      anchors.fill: parent
      onClicked: function(mouse) {
        var cardPt = mapToItem(fontPickerCard, mouse.x, mouse.y)
        if (cardPt.x >= 0 && cardPt.x <= fontPickerCard.width && cardPt.y >= 0 && cardPt.y <= fontPickerCard.height) {
          return
        }
        if (typeof fontPickerTriggerBtn !== "undefined" && fontPickerTriggerBtn) {
          var btnPt = mapToItem(fontPickerTriggerBtn, mouse.x, mouse.y)
          if (btnPt.x >= 0 && btnPt.x <= fontPickerTriggerBtn.width && btnPt.y >= 0 && btnPt.y <= fontPickerTriggerBtn.height) {
            root.fontPickerOpen = false
            return
          }
        }
        root.fontPickerOpen = false
      }
    }

    // Popover Card anchored beneath fontPickerTriggerBtn
    Rectangle {
      id: fontPickerCard
      width: Style.space(240)
      height: Style.space(300)
      radius: Style.space(6)
      color: Util.alpha(Color.popups.background || Color.background || "#1e1e2e", 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border || "#313244", 0.7)

      x: {
        if (!root.fontPickerOpen || typeof fontPickerTriggerBtn === "undefined" || !fontPickerTriggerBtn) {
          return root.width / 2 - width / 2
        }
        var pt = fontPickerTriggerBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.fontPickerOpen || typeof fontPickerTriggerBtn === "undefined" || !fontPickerTriggerBtn) {
          return root.height / 2 - height / 2
        }
        var pt = fontPickerTriggerBtn.mapToItem(root, 0, 0)
        var btnH = fontPickerTriggerBtn.height
        if (pt.y + btnH + height + Style.space(8) <= root.height) {
          return pt.y + btnH + Style.space(4)
        } else {
          return Math.max(Style.space(8), pt.y - height - Style.space(4))
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // Header
        RowLayout {
          width: parent.width
          height: Style.space(20)

          Text {
            text: "System Fonts"
            color: root.fgCol
            font.family: root.fontFamily
            font.pixelSize: Style.space(9)
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Rectangle {
            height: Style.space(16)
            width: fCountTxt.implicitWidth + Style.space(8)
            radius: Style.space(3)
            color: Util.alpha(Color.accent, 0.15)
            Layout.alignment: Qt.AlignVCenter
            Text {
              id: fCountTxt
              text: String(root.systemFontFamilies.length)
              color: Color.accent
              font.pixelSize: Style.space(7.5)
              font.bold: true
              anchors.centerIn: parent
            }
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            width: Style.space(18); height: Style.space(18); radius: Style.space(3)
            color: closeFpMouse.containsMouse ? Util.alpha(root.fgCol, 0.15) : "transparent"
            Layout.alignment: Qt.AlignVCenter
            Text { text: "✕"; color: root.fgCol; font.pixelSize: Style.space(8); anchors.centerIn: parent }
            MouseArea {
              id: closeFpMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.fontPickerOpen = false
            }
          }
        }

        // Search Input
        Rectangle {
          width: parent.width
          height: Style.space(24)
          radius: Style.space(4)
          color: Util.alpha(root.fgCol, 0.06)
          border.width: 1
          border.color: fontSearchInput.activeFocus ? Color.accent : Util.alpha(root.borderCol, 0.6)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(4)

            Text { text: "🔍"; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }

            TextInput {
              id: fontSearchInput
              width: parent.width - Style.space(34)
              anchors.verticalCenter: parent.verticalCenter
              font.family: root.fontFamily
              font.pixelSize: Style.space(8.5)
              color: root.fgCol
              selectionColor: Color.accent
              selectedTextColor: "#FFFFFF"
              text: root.fontSearchQuery
              onTextChanged: root.fontSearchQuery = text

              Text {
                visible: !fontSearchInput.text && !fontSearchInput.activeFocus
                text: "Search " + root.systemFontFamilies.length + " fonts..."
                font.family: root.fontFamily
                font.pixelSize: Style.space(8.5)
                color: Util.alpha(root.fgCol, 0.4)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Rectangle {
              visible: fontSearchInput.text.length > 0
              width: Style.space(14); height: Style.space(14); radius: Style.space(7)
              color: clearFpSearchMouse.containsMouse ? Util.alpha(root.fgCol, 0.2) : "transparent"
              anchors.verticalCenter: parent.verticalCenter
              Text { text: "✕"; font.pixelSize: Style.space(7); color: root.fgCol; anchors.centerIn: parent }
              MouseArea {
                id: clearFpSearchMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  fontSearchInput.text = ""
                  root.fontSearchQuery = ""
                  fontSearchInput.forceActiveFocus()
                }
              }
            }
          }
        }

        // Category Filter Chips
        Row {
          spacing: Style.space(4)
          Repeater {
            model: [
              { id: "", label: "All", filter: "" },
              { id: "mono", label: "Mono", filter: "mono" },
              { id: "sans", label: "Sans", filter: "sans" },
              { id: "serif", label: "Serif", filter: "serif" }
            ]
            Rectangle {
              id: chipRect
              required property var modelData
              property bool isCurrent: {
                if (!chipRect.modelData.id) return !root.fontSearchQuery
                return (root.fontSearchQuery || "").toLowerCase() === chipRect.modelData.filter
              }
              width: chipTxt.implicitWidth + Style.space(8); height: Style.space(18); radius: Style.space(3)
              color: isCurrent ? Color.accent : (chipMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(root.fgCol, 0.06))
              border.width: 1
              border.color: isCurrent ? Color.accent : Util.alpha(Color.accent, 0.2)
              Text {
                id: chipTxt
                text: chipRect.modelData.label
                font.family: root.fontFamily
                font.pixelSize: Style.space(7.5)
                font.bold: true
                color: chipRect.isCurrent ? "#FFFFFF" : Color.accent
                anchors.centerIn: parent
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.fontSearchQuery = chipRect.modelData.filter
                  fontSearchInput.text = chipRect.modelData.filter
                }
              }
            }
          }
        }

        // Font List
        ListView {
          id: fontListView
          width: parent.width
          height: fontPickerCard.height - Style.space(88)
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: Style.space(4)
          }

          readonly property var filteredFonts: {
            var q = (root.fontSearchQuery || "").trim().toLowerCase()
            var list = root.systemFontFamilies || []
            if (!q) return list
            return list.filter(function(f) {
              return f.toLowerCase().indexOf(q) !== -1
            })
          }

          model: filteredFonts

          delegate: Rectangle {
            id: fItemDelegate
            required property string modelData
            property bool isSelected: root.editorFontFamily === modelData
            width: fontListView.width
            height: Style.space(24)
            radius: Style.space(3)
            color: isSelected ? Util.alpha(Color.accent, 0.25) : (fItemMouse.containsMouse ? Util.alpha(root.fgCol, 0.08) : "transparent")

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              Text {
                text: fItemDelegate.modelData
                font.family: fItemDelegate.modelData
                font.pixelSize: Style.space(8.5)
                color: fItemDelegate.isSelected ? Color.accent : root.fgCol
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: parent.width - (fItemDelegate.isSelected ? Style.space(20) : 0)
              }

              Text {
                visible: fItemDelegate.isSelected
                text: "✓"
                color: Color.accent
                font.bold: true
                font.pixelSize: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: fItemMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.editorFontFamily = fItemDelegate.modelData
                root.fontPickerOpen = false
                root.showFeedback("Font: " + fItemDelegate.modelData)
              }
            }
          }

          Item {
            visible: fontListView.count === 0
            width: parent.width
            height: Style.space(80)
            Text {
              anchors.centerIn: parent
              text: "No matching fonts found"
              color: Util.alpha(root.fgCol, 0.4)
              font.family: root.fontFamily
              font.pixelSize: Style.space(8)
            }
          }
        }
      }
    }

    // Dismiss overlay for Boilerplate Menu
    MouseArea {
      anchors.fill: parent
      visible: root.boilerplateMenuOpen
      z: 140
      hoverEnabled: true
      onClicked: function(mouse) {
        if (typeof boilerplateCard !== "undefined" && boilerplateCard) {
          var pt = mapToItem(boilerplateCard, mouse.x, mouse.y)
          if (pt.x >= 0 && pt.x <= boilerplateCard.width && pt.y >= 0 && pt.y <= boilerplateCard.height) {
            return
          }
        }
        if (typeof boilerplateTriggerBtn !== "undefined" && boilerplateTriggerBtn) {
          var btnPt = mapToItem(boilerplateTriggerBtn, mouse.x, mouse.y)
          if (btnPt.x >= 0 && btnPt.x <= boilerplateTriggerBtn.width && btnPt.y >= 0 && btnPt.y <= boilerplateTriggerBtn.height) {
            root.boilerplateMenuOpen = false
            return
          }
        }
        root.boilerplateMenuOpen = false
      }
    }

    // Popover Card anchored beneath boilerplateTriggerBtn
    Rectangle {
      id: boilerplateCard
      visible: root.boilerplateMenuOpen
      z: 150
      width: Style.space(170)
      height: boilerplateCol.implicitHeight + Style.space(12)
      radius: Style.space(6)
      color: Util.alpha(Color.popups.background || Color.background || "#1e1e2e", 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border || "#313244", 0.7)

      x: {
        if (!root.boilerplateMenuOpen || typeof boilerplateTriggerBtn === "undefined" || !boilerplateTriggerBtn) {
          return root.width / 2 - width / 2
        }
        var pt = boilerplateTriggerBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x + boilerplateTriggerBtn.width - width))
      }
      y: {
        if (!root.boilerplateMenuOpen || typeof boilerplateTriggerBtn === "undefined" || !boilerplateTriggerBtn) {
          return root.height / 2 - height / 2
        }
        var pt = boilerplateTriggerBtn.mapToItem(root, 0, 0)
        var btnH = boilerplateTriggerBtn.height
        if (pt.y + btnH + height + Style.space(8) <= root.height) {
          return pt.y + btnH + Style.space(4)
        } else {
          return Math.max(Style.space(8), pt.y - height - Style.space(4))
        }
      }

      Column {
        id: boilerplateCol
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(2)

        Text {
          text: "INSERT SKELETON"
          font.family: root.fontFamily
          font.pixelSize: Style.space(7)
          font.bold: true
          color: Util.alpha(root.fgCol, 0.5)
          leftPadding: Style.space(6)
          topPadding: Style.space(2)
          bottomPadding: Style.space(4)
        }

        Repeater {
          model: root.boilerplateTemplates
          delegate: Rectangle {
            id: tplItemDelegate
            required property var modelData
            width: parent.width
            height: Style.space(24)
            radius: Style.space(4)
            color: tplItemMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"
            border.width: 1
            border.color: tplItemMouse.containsMouse ? Util.alpha(Color.accent, 0.4) : "transparent"

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: tplItemDelegate.modelData.icon
                font.pixelSize: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: tplItemDelegate.modelData.name
                font.family: root.fontFamily
                font.pixelSize: Style.space(8.5)
                color: root.fgCol
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: tplItemMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.insertBoilerplate(tplItemDelegate.modelData)
                root.boilerplateMenuOpen = false
              }
            }
          }
        }
      }
    }
  }
}
