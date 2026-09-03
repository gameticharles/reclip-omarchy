function normalizeEntry(value) {
  if (typeof value === "string") {
    var trimmed = value.trim()
    return trimmed.length > 0 ? {
      type: "text",
      text: value,
      pinned: false,
      favorite: false,
      capturedAt: new Date().toISOString()
    } : null
  }

  if (!value || typeof value !== "object") return null

  var type = String(value.type || value.kind || "")
  if (type === "text") {
    var text = String(value.text || "")
    if (!text.trim()) return null
    return {
      type: "text",
      text: text,
      pinned: !!value.pinned,
      favorite: !!value.favorite,
      capturedAt: String(value.capturedAt || new Date().toISOString()),
      tags: Array.isArray(value.tags) ? value.tags : []
    }
  }

  if (type === "image") {
    var path = String(value.path || "")
    if (!path) return null
    return {
      type: "image",
      path: path,
      mime: String(value.mime || "image/png"),
      pinned: !!value.pinned,
      favorite: !!value.favorite,
      capturedAt: String(value.capturedAt || new Date().toISOString()),
      tags: Array.isArray(value.tags) ? value.tags : []
    }
  }

  return null
}

function entryKey(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image:" + String(entry.path || "")
  return "text:" + String(entry.text || "")
}

function parseHistory(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    var next = []
    if (!Array.isArray(parsed)) return next
    for (var i = 0; i < parsed.length; i++) {
      var entry = normalizeEntry(parsed[i])
      if (entry) next.push(entry)
    }
    return next
  } catch (e) { return [] }
}

function addEntry(history, entry, limit) {
  var normalized = normalizeEntry(entry)
  var max = limit === undefined ? 500 : Number(limit)
  if (isNaN(max)) max = 500
  max = Math.max(0, max)
  if (!normalized) return Array.isArray(history) ? history.slice(0, max) : []
  if (max === 0) return []

  var key = entryKey(normalized)
  var next = [normalized]
  var values = Array.isArray(history) ? history : []
  for (var i = 0; i < values.length && next.length < max; i++) {
    var existing = normalizeEntry(values[i])
    if (!existing || entryKey(existing) === key) continue
    next.push(existing)
  }
  return next
}

function removeEntryAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  next.splice(target, 1)
  return next
}

function togglePin(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  var item = Object.assign({}, next[target])
  item.pinned = !item.pinned
  next[target] = item
  return next
}

function toggleFavorite(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  var item = Object.assign({}, next[target])
  item.favorite = !item.favorite
  next[target] = item
  return next
}

function updateEntryText(history, index, newText) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  var item = Object.assign({}, next[target])
  item.text = String(newText || "")
  next[target] = item
  return next
}

function transformText(text, mode) {
  var s = String(text || "")
  switch (mode) {
    case "upper": return s.toUpperCase()
    case "lower": return s.toLowerCase()
    case "title": return s.replace(/\w\S*/g, function(w) { return w.charAt(0).toUpperCase() + w.substr(1).toLowerCase() })
    case "trim": return s.trim()
    case "kebab": return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    case "snake": return s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
    case "json_pretty":
      try { return JSON.stringify(JSON.parse(s), null, 2) } catch(e) { return s }
    case "json_minify":
      try { return JSON.stringify(JSON.parse(s)) } catch(e) { return s }
    default: return s
  }
}

function mergeEntries(history, indices, separator) {
  var sep = separator !== undefined ? separator : "\n"
  var texts = []
  for (var i = 0; i < indices.length; i++) {
    var idx = indices[i]
    if (idx >= 0 && idx < history.length && history[idx].type === "text") {
      texts.push(history[idx].text)
    }
  }
  if (texts.length === 0) return history
  var mergedText = texts.join(sep)
  return addEntry(history, { type: "text", text: mergedText })
}

function clearHistory() { return [] }

function parseEntryJson(line) {
  var raw = String(line || "").trim()
  if (!raw) return null
  try { return normalizeEntry(JSON.parse(raw)) } catch (e) { return null }
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""
  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""
  try { return decodeURIComponent(path) } catch (e) { return path }
}

function filePaths(entry) {
  if (!entry || entry.type !== "text") return []
  var lines = String(entry.text || "").split(/\r?\n/)
  var paths = []
  for (var i = 0; i < lines.length; i++) {
    var path = decodeFileUri(lines[i])
    if (path) paths.push(path)
  }
  return paths
}

function fileName(path) {
  var parts = String(path || "").split("/")
  return parts.length > 0 ? parts[parts.length - 1] : String(path || "")
}

function isImagePath(path) {
  return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || ""))
}

function fileEntryText(entry) {
  var paths = filePaths(entry)
  if (paths.length === 0) return ""
  if (paths.length === 1) return fileName(paths[0])
  return paths.length + " files"
}

function imagePreviewText(entry) {
  var timestamp = String(entry && entry.capturedAt || "")
  var label = String(entry && entry.mime || "") === "image/png" ? "Screenshot" : "Image"
  return label + (timestamp ? " • " + formatTimeAgo(timestamp) : "")
}

function previewText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return imagePreviewText(entry)
  var fileText = fileEntryText(entry)
  if (fileText) return fileText
  return String(entry.text || "").replace(/\s+/g, " ")
}

function fullText(entry) {
  if (!entry) return ""
  var paths = filePaths(entry)
  if (paths.length > 0) return paths.join("\n")
  return String(entry.text || "")
}

var displayTextLimit = 8192

function cappedEntry(entry) {
  if (!entry || entry.type !== "text" || entry.text.length <= displayTextLimit) return entry
  var cut = entry.text.lastIndexOf("\n", displayTextLimit)
  return { type: "text", text: entry.text.slice(0, cut > 0 ? cut : displayTextLimit), pinned: entry.pinned, favorite: entry.favorite, capturedAt: entry.capturedAt }
}

function searchableText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image screenshot " + String(entry.mime || "") + " " + String(entry.capturedAt || "")
  return String(entry.text || "") + " " + fileEntryText(entry)
}

function isHexColor(str) {
  var s = String(str || "").trim()
  return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s)
}

function hexToRgb(hex) {
  var h = String(hex || "").trim().replace("#", "")
  if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
  if (h.length < 6) return ""
  var num = parseInt(h.substring(0, 6), 16)
  return "rgb(" + (num >> 16) + ", " + ((num >> 8) & 255) + ", " + (num & 255) + ")"
}

function isUrl(str) {
  var s = String(str || "").trim()
  return /^https?:\/\/[^\s/$.?#].[^\s]*$/i.test(s)
}

function isCodeSnippet(str) {
  var s = String(str || "")
  if (s.indexOf("\n") >= 0 && (s.indexOf("{") >= 0 || s.indexOf("}") >= 0 || s.indexOf("const ") >= 0 || s.indexOf("let ") >= 0 || s.indexOf("function ") >= 0 || s.indexOf("def ") >= 0 || s.indexOf("fn ") >= 0 || s.indexOf("import ") >= 0 || s.indexOf("class ") >= 0 || s.indexOf("return ") >= 0 || s.indexOf("echo ") >= 0)) return true
  return false
}

function detectCodeLanguage(text) {
  var s = String(text || "")
  if (/^\s*[{[]/.test(s) && /[}\]]\s*$/.test(s)) {
    try { JSON.parse(s); return "JSON" } catch(e) {}
  }
  if (/(const|let|var|function|=>|console\.log)/.test(s)) return "JS"
  if (/(def |import |from |class |elif |print\()/.test(s)) return "PY"
  if (/(fn |pub struct |impl |let mut |println!)/.test(s)) return "RS"
  if (/(package |func |fmt\.Print)/.test(s)) return "GO"
  if (/(SELECT |INSERT |UPDATE |DELETE |FROM |WHERE )/i.test(s)) return "SQL"
  if (/(<html|<div|<span|<!DOCTYPE)/i.test(s)) return "HTML"
  if (/(\{|\}|\.[\w-]+\s*\{|#[\w-]+\s*\{|margin:|padding:)/.test(s)) return "CSS"
  if (/(#!\/bin\/bash|#!\/bin\/sh|echo |grep |curl |sudo )/.test(s)) return "SH"
  return "CODE"
}

function detectKind(entry) {
  if (!entry) return "text"
  if (entry.type === "image") return "image"
  var paths = filePaths(entry)
  if (paths.length > 0) return "file"
  var raw = String(entry.text || "").trim()
  if (isHexColor(raw)) return "color"
  if (isUrl(raw)) return "link"
  if (isCodeSnippet(raw)) return "code"
  return "text"
}

function formatTimeAgo(isoString) {
  if (!isoString) return ""
  var date = new Date(isoString)
  if (isNaN(date.getTime())) return ""
  var diff = Math.floor((Date.now() - date.getTime()) / 1000)
  if (diff < 30) return "Just now"
  if (diff < 60) return diff + "s ago"
  if (diff < 3600) return Math.floor(diff / 60) + "m ago"
  if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
  if (diff < 172800) return "Yesterday"
  return Math.floor(diff / 86400) + "d ago"
}

function extractColors(history) {
  var values = Array.isArray(history) ? history : []
  var colors = []
  var seen = {}
  for (var i = 0; i < values.length; i++) {
    var e = values[i]
    if (e && e.type === "text") {
      var raw = String(e.text || "").trim()
      if (isHexColor(raw) && !seen[raw.toLowerCase()]) {
        seen[raw.toLowerCase()] = true
        colors.push({
          hex: raw,
          rgb: hexToRgb(raw),
          timeAgo: formatTimeAgo(e.capturedAt)
        })
      }
    }
  }
  return colors
}

function parseClipDate(dateVal) {
  if (!dateVal) return new Date()
  var d = new Date(dateVal)
  if (!isNaN(d.getTime())) return d
  return new Date()
}

function formatLocalDate(d) {
  var date = d instanceof Date ? d : parseClipDate(d)
  var year = date.getFullYear()
  var month = String(date.getMonth() + 1).padStart(2, "0")
  var day = String(date.getDate()).padStart(2, "0")
  return year + "-" + month + "-" + day
}

function matchDateFilter(capturedAt, dateFilter) {
  if (!dateFilter || dateFilter === "" || dateFilter === "all") return true
  var d = parseClipDate(capturedAt)
  var now = new Date()
  var clipDateStr = formatLocalDate(d)
  var todayStr = formatLocalDate(now)

  if (dateFilter === "today") return clipDateStr === todayStr
  if (dateFilter === "yesterday") {
    var yest = new Date(now.getTime() - 86400000)
    return clipDateStr === formatLocalDate(yest)
  }
  if (dateFilter === "7d") return (now.getTime() - d.getTime()) <= 7 * 86400000 && (now.getTime() - d.getTime()) >= 0
  if (dateFilter === "30d") return (now.getTime() - d.getTime()) <= 30 * 86400000 && (now.getTime() - d.getTime()) >= 0
  if (dateFilter === "mtd") return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()

  // Exact date match (YYYY-MM-DD)
  return clipDateStr === dateFilter
}

function getClipDateCounts(history) {
  var counts = {}
  var values = Array.isArray(history) ? history : []
  for (var i = 0; i < values.length; i++) {
    var e = values[i]
    if (e) {
      var d = parseClipDate(e.capturedAt)
      var dStr = formatLocalDate(d)
      counts[dStr] = (counts[dStr] || 0) + 1
    }
  }
  return counts
}

function displayRows(history, query, category, dateFilter, limit) {
  var values = Array.isArray(history) ? history : []
  var needle = String(query || "").trim().toLowerCase()
  var cat = "all"
  var dFilter = ""
  var max = 80

  if (typeof category === "number") {
    max = category
  } else if (typeof category === "string") {
    cat = category.toLowerCase()
  }

  if (typeof dateFilter === "number") {
    max = dateFilter
  } else if (typeof dateFilter === "string") {
    dFilter = dateFilter
  }

  if (typeof limit === "number") {
    max = limit
  }

  if (isNaN(max)) max = 80
  max = Math.max(0, max)
  if (max === 0) return []

  // Split into pinned and unpinned
  var pinnedList = []
  var normalList = []
  for (var v = 0; v < values.length; v++) {
    var rawItem = values[v]
    if (rawItem && rawItem.pinned) pinnedList.push({ item: rawItem, index: v })
    else if (rawItem) normalList.push({ item: rawItem, index: v })
  }

  // Combined order: pinned first, then normal
  var ordered = pinnedList.concat(normalList)

  var rows = []
  for (var i = 0; i < ordered.length; i++) {
    var wrapped = ordered[i]
    var entry = cappedEntry(normalizeEntry(wrapped.item))
    if (!entry) continue
    if (needle && searchableText(entry).toLowerCase().indexOf(needle) < 0) continue
    if (dFilter && !matchDateFilter(entry.capturedAt, dFilter)) continue

    var isPinned = !!entry.pinned
    var isFav = !!entry.favorite
    var kind = detectKind(entry)

    if (cat === "pinned" && !isPinned) continue
    if (cat === "favorites" && !isFav) continue
    if (cat !== "all" && cat !== "pinned" && cat !== "favorites") {
      if (cat === "text" && kind !== "text" && kind !== "code" && kind !== "link") continue
      if (cat === "image" && kind !== "image") continue
      if (cat === "code" && kind !== "code") continue
      if (cat === "color" && kind !== "color") continue
      if (cat === "link" && kind !== "link") continue
      if (cat === "file" && kind !== "file") continue
    }

    var paths = filePaths(entry)
    var isFile = paths.length > 0
    var isImage = entry.type === "image"
    var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    var rawText = isImage ? "" : fullText(entry)
    var hex = kind === "color" ? rawText.trim() : ""
    var lineCount = rawText ? rawText.split(/\r?\n/).length : 1
    var wordCount = rawText ? rawText.trim().split(/\s+/).length : 0

    rows.push({
      entryType: isFile ? "file" : entry.type,
      kind: kind,
      colorValue: hex,
      colorRgb: hex ? hexToRgb(hex) : "",
      codeLang: kind === "code" ? detectCodeLanguage(rawText) : "",
      fullText: rawText,
      previewText: previewText(entry),
      previewImage: previewPath,
      path: isImage ? String(entry.path || "") : (isFile && paths.length === 1 ? paths[0] : ""),
      mime: isImage ? String(entry.mime || "image/png") : "text/plain",
      timeAgo: formatTimeAgo(entry.capturedAt),
      capturedDate: String(entry.capturedAt || "").substring(0, 10),
      charCount: rawText.length,
      lineCount: lineCount,
      wordCount: wordCount,
      isPinned: isPinned,
      isFavorite: isFav,
      index: wrapped.index
    })
    if (rows.length >= max) break
  }
  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeEntry: normalizeEntry, entryKey: entryKey, parseHistory: parseHistory,
    addEntry: addEntry, removeEntryAt: removeEntryAt, togglePin: togglePin,
    toggleFavorite: toggleFavorite, updateEntryText: updateEntryText,
    transformText: transformText, mergeEntries: mergeEntries, clearHistory: clearHistory,
    parseEntryJson: parseEntryJson, searchableText: searchableText, previewText: previewText,
    fullText: fullText, displayRows: displayRows, detectKind: detectKind, isHexColor: isHexColor,
    isUrl: isUrl, isCodeSnippet: isCodeSnippet, detectCodeLanguage: detectCodeLanguage,
    hexToRgb: hexToRgb, formatTimeAgo: formatTimeAgo, extractColors: extractColors,
    matchDateFilter: matchDateFilter, getClipDateCounts: getClipDateCounts
  }
}
