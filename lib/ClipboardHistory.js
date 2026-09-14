function normalizeEntry(value) {
  if (typeof value === "string") {
    var trimmed = value.trim()
    return trimmed.length > 0 ? {
      type: "text",
      text: value,
      pinned: false,
      favorite: false,
      capturedAt: new Date().toISOString(),
      copyCount: 1,
      sourceApp: "",
      sourceTitle: "",
      revisions: []
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
      tags: Array.isArray(value.tags) ? value.tags : [],
      copyCount: Math.max(1, Number(value.copyCount || 1)),
      sourceApp: String(value.sourceApp || ""),
      sourceTitle: String(value.sourceTitle || ""),
      revisions: Array.isArray(value.revisions) ? value.revisions : []
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
      tags: Array.isArray(value.tags) ? value.tags : [],
      colors: Array.isArray(value.colors) ? value.colors : [],
      isQr: !!value.isQr,
      qrText: String(value.qrText || ""),
      copyCount: Math.max(1, Number(value.copyCount || 1)),
      sourceApp: String(value.sourceApp || ""),
      sourceTitle: String(value.sourceTitle || "")
    }
  }

  return null
}

function entryKey(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image:" + String(entry.path || "")
  return "text:" + String(entry.text || "")
}

function computeSimilarity(str1, str2) {
  if (str1 === str2) return 1.0
  if (!str1 || !str2) return 0.0
  var s1 = str1.trim(), s2 = str2.trim()
  if (Math.min(s1.length, s2.length) < 15) return 0.0

  var getTrigrams = function(s) {
    var grams = {}
    for (var i = 0; i <= s.length - 3; i++) {
      var g = s.substr(i, 3)
      grams[g] = (grams[g] || 0) + 1
    }
    return grams
  }
  var g1 = getTrigrams(s1), g2 = getTrigrams(s2)
  var intersection = 0, total1 = 0, total2 = 0
  for (var k in g1) {
    total1 += g1[k]
    if (g2[k]) intersection += Math.min(g1[k], g2[k])
  }
  for (var k2 in g2) total2 += g2[k2]
  if (total1 + total2 === 0) return 0.0
  return (2.0 * intersection) / (total1 + total2)
}

function computeLineDiff(oldText, newText) {
  var a = String(oldText || "").split(/\r?\n/)
  var b = String(newText || "").split(/\r?\n/)
  var n = Math.min(a.length, 1000), m = Math.min(b.length, 1000)
  var dp = []
  for (var i = 0; i <= n; i++) dp[i] = new Int32Array(m + 1)
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < m; j++) {
      if (a[i] === b[j]) dp[i + 1][j + 1] = dp[i][j] + 1
      else dp[i + 1][j + 1] = Math.max(dp[i + 1][j], dp[i][j + 1])
    }
  }
  var diff = []
  var curI = n, curJ = m
  while (curI > 0 || curJ > 0) {
    if (curI > 0 && curJ > 0 && a[curI - 1] === b[curJ - 1]) {
      diff.unshift({ type: "equal", line: a[curI - 1], lineNumOld: curI, lineNumNew: curJ })
      curI--; curJ--
    } else if (curJ > 0 && (curI === 0 || dp[curI][curJ - 1] >= dp[curI - 1][curJ])) {
      diff.unshift({ type: "add", line: b[curJ - 1], lineNumNew: curJ })
      curJ--
    } else if (curI > 0 && (curJ === 0 || dp[curI][curJ - 1] < dp[curI - 1][curJ])) {
      diff.unshift({ type: "delete", line: a[curI - 1], lineNumOld: curI })
      curI--
    }
  }
  return diff
}

function computeDiffStats(oldText, newText) {
  var diff = computeLineDiff(oldText, newText)
  var add = 0, del = 0
  for (var i = 0; i < diff.length; i++) {
    if (diff[i].type === "add") add++
    else if (diff[i].type === "delete") del++
  }
  return { added: add, deleted: del, summary: "+" + add + " -" + del }
}

function restoreRevision(history, clipIndex, revIndex) {
  var values = Array.isArray(history) ? history : []
  var target = Number(clipIndex)
  var rIdx = Number(revIndex)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var item = values[target]
  if (!item || !Array.isArray(item.revisions) || isNaN(rIdx) || rIdx < 0 || rIdx >= item.revisions.length) {
    return values.slice()
  }
  var rev = item.revisions[rIdx]
  var currentText = item.text
  var diffStat = computeDiffStats(rev.text, currentText)
  var newRevs = item.revisions.slice()
  newRevs.splice(rIdx, 1, {
    text: currentText,
    capturedAt: new Date().toISOString(),
    sourceApp: item.sourceApp || "",
    sourceTitle: item.sourceTitle || "",
    diffSummary: diffStat.summary
  })
  var updated = Object.assign({}, item, {
    text: rev.text,
    capturedAt: new Date().toISOString(),
    revisions: newRevs
  })
  var next = values.slice()
  next.splice(target, 1)
  next.unshift(updated)
  return next
}

function deleteRevision(history, clipIndex, revIndex) {
  var values = Array.isArray(history) ? history : []
  var target = Number(clipIndex)
  var rIdx = Number(revIndex)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var item = values[target]
  if (!item || !Array.isArray(item.revisions) || isNaN(rIdx) || rIdx < 0 || rIdx >= item.revisions.length) {
    return values.slice()
  }
  var newRevs = item.revisions.slice()
  newRevs.splice(rIdx, 1)
  var updated = Object.assign({}, item, { revisions: newRevs })
  var next = values.slice()
  next[target] = updated
  return next
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

function addEntry(history, entry, limit, options) {
  var normalized = normalizeEntry(entry)
  var max = limit === undefined ? 500 : Number(limit)
  if (isNaN(max)) max = 500
  max = Math.max(0, max)
  if (!normalized) return Array.isArray(history) ? history.slice(0, max) : []
  if (max === 0) return []

  var opts = options || {}
  var enableSmartBump = opts.smartBump !== false
  var enableRevisionStacking = opts.revisionStacking !== false

  var values = Array.isArray(history) ? history : []
  var key = entryKey(normalized)

  // 1. SMART BUMP: Exact duplicate match -> bump existing item to top and increment copy counter
  if (enableSmartBump) {
    for (var i = 0; i < values.length; i++) {
      var existing = normalizeEntry(values[i])
      if (existing && entryKey(existing) === key) {
        var newCount = Math.max(1, Number(existing.copyCount || 1)) + 1
        var bumped = Object.assign({}, existing, {
          copyCount: newCount,
          capturedAt: normalized.capturedAt || new Date().toISOString(),
          sourceApp: normalized.sourceApp || existing.sourceApp,
          sourceTitle: normalized.sourceTitle || existing.sourceTitle
        })
        var nextBump = [bumped]
        for (var j = 0; j < values.length && nextBump.length < max; j++) {
          if (j === i) continue
          var itemJ = normalizeEntry(values[j])
          if (itemJ && entryKey(itemJ) !== key) nextBump.push(itemJ)
        }
        return nextBump
      }
    }
  }

  // 2. REVISION STACKING: Check for edited iterations of similar text
  if (enableRevisionStacking && normalized.type === "text" && normalized.text.trim().length >= 15) {
    var checkLimit = Math.min(values.length, 25)
    for (var r = 0; r < checkLimit; r++) {
      var cand = normalizeEntry(values[r])
      if (cand && !cand.pinned && cand.type === "text" && cand.text.trim().length >= 15) {
        var sameApp = (cand.sourceApp && normalized.sourceApp && cand.sourceApp.toLowerCase() === normalized.sourceApp.toLowerCase())
        var threshold = sameApp ? 0.52 : 0.60
        var sim = computeSimilarity(cand.text, normalized.text)
        if (sim >= threshold && sim < 1.0) {
          var diffStat = computeDiffStats(cand.text, normalized.text)
          var oldRevs = Array.isArray(cand.revisions) ? cand.revisions.slice(0, 19) : []
          var newRev = {
            text: cand.text,
            capturedAt: cand.capturedAt || new Date().toISOString(),
            sourceApp: cand.sourceApp || "",
            sourceTitle: cand.sourceTitle || "",
            diffSummary: diffStat.summary
          }
          var stacked = Object.assign({}, cand, {
            text: normalized.text,
            capturedAt: normalized.capturedAt || new Date().toISOString(),
            sourceApp: normalized.sourceApp || cand.sourceApp,
            sourceTitle: normalized.sourceTitle || cand.sourceTitle,
            copyCount: Math.max(1, Number(cand.copyCount || 1)) + 1,
            revisions: [newRev].concat(oldRevs)
          })
          var nextStack = [stacked]
          for (var k = 0; k < values.length && nextStack.length < max; k++) {
            if (k === r) continue
            var itemK = normalizeEntry(values[k])
            if (itemK) nextStack.push(itemK)
          }
          return nextStack
        }
      }
    }
  }

  // 3. Normal prepend
  var next = [normalized]
  for (var m = 0; m < values.length && next.length < max; m++) {
    var ex = normalizeEntry(values[m])
    if (!ex || entryKey(ex) === key) continue
    next.push(ex)
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
  if (entry.type === "image") {
    var qr = (entry.isQr || entry.qrText) ? (" qrcode qr " + String(entry.qrText || "") + " ") : ""
    return "image screenshot " + qr + String(entry.mime || "") + " " + String(entry.capturedAt || "") + " " + String(entry.sourceApp || "") + " " + String(entry.sourceTitle || "")
  }
  var extra = ""
  if (entry.type === "text") {
    var cHex = extractColorHex(entry.text)
    if (cHex) extra = " color " + cHex + " "
  }
  return String(entry.text || "") + extra + " " + fileEntryText(entry) + " " + String(entry.sourceApp || "") + " " + String(entry.sourceTitle || "")
}

// Common CSS and Tailwind color names mapping
var NAMED_COLORS = {
  "black": "#000000", "white": "#FFFFFF", "red": "#FF0000", "lime": "#00FF00", "blue": "#0000FF",
  "yellow": "#FFFF00", "cyan": "#00FFFF", "magenta": "#FF00FF", "silver": "#C0C0C0",
  "gray": "#808080", "grey": "#808080", "maroon": "#800000", "olive": "#808000", "green": "#008000",
  "purple": "#800080", "teal": "#008080", "navy": "#000080", "orange": "#FFA500", "pink": "#FFC0CB",
  "gold": "#FFD700", "coral": "#FF7F50", "crimson": "#DC143C", "indigo": "#4B0082", "violet": "#EE82EE",
  "turquoise": "#40E0D0", "salmon": "#FA8072", "tomato": "#FF6347", "khaki": "#F0E68C", "plum": "#DDA0DD",
  "azure": "#F0FFFF", "beige": "#F5F5DC", "bisque": "#FFE4C4", "brown": "#A52A2A", "chocolate": "#D2691E",
  "darkblue": "#00008B", "darkcyan": "#008B8B", "darkgray": "#A9A9A9", "darkgreen": "#006400", "darkkhaki": "#BDB76B",
  "darkmagenta": "#8B008B", "darkolivegreen": "#556B2F", "darkorange": "#FF8C00", "darkorchid": "#9932CC",
  "darkred": "#8B0000", "darksalmon": "#E9967A", "darkseagreen": "#8FBC8F", "darkslateblue": "#483D8B",
  "darkslategray": "#2F4F4F", "darkturquoise": "#00CED1", "darkviolet": "#9400D3", "deeppink": "#FF1493",
  "deepskyblue": "#00BFFF", "dimgray": "#696969", "dodgerblue": "#1E90FF", "firebrick": "#B22222",
  "floralwhite": "#FFFAF0", "forestgreen": "#228B22", "fuchsia": "#FF00FF", "gainsboro": "#DCDCDC",
  "ghostwhite": "#F8F8FF", "goldenrod": "#DAA520", "greenyellow": "#ADFF2F", "honeydew": "#F0FFF0",
  "hotpink": "#FF69B4", "indianred": "#CD5C5C", "ivory": "#FFFFF0", "lavender": "#E6E6FA", "lavenderblush": "#FFF0F5",
  "lawngreen": "#7CFC00", "lemonchiffon": "#FFFACD", "lightblue": "#ADD8E6", "lightcoral": "#F08080",
  "lightcyan": "#E0FFFF", "lightgoldenrodyellow": "#FAFAD2", "lightgray": "#D3D3D3", "lightgreen": "#90EE90",
  "lightpink": "#FFB6C1", "lightsalmon": "#FFA07A", "lightseagreen": "#20B2AA", "lightskyblue": "#87CEFA",
  "lightslategray": "#778899", "lightsteelblue": "#B0C4DE", "lightyellow": "#FFFFE0", "limegreen": "#32CD32",
  "linen": "#FAF0E6", "mediumaquamarine": "#66CDAA", "mediumblue": "#0000CD", "mediumorchid": "#BA55D3",
  "mediumpurple": "#9370DB", "mediumseagreen": "#3CB371", "mediumslateblue": "#7B68EE", "mediumspringgreen": "#00FA9A",
  "mediumturquoise": "#48D1CC", "mediumvioletred": "#C71585", "midnightblue": "#191970", "mintcream": "#F5FFFA",
  "mistyrose": "#FFE4E1", "moccasin": "#FFE4E5", "navajowhite": "#FFDEAD", "oldlace": "#FDF5E6", "olivedrab": "#6B8E23",
  "orangered": "#FF4500", "orchid": "#DA70D6", "palegoldenrod": "#EEE8AA", "palegreen": "#98FB98",
  "paleturquoise": "#AFEEEE", "palevioletred": "#DB7093", "papayawhip": "#FFEFD5", "peachpuff": "#FFDAB9",
  "peru": "#CD853F", "powderblue": "#B0E0E6", "rosybrown": "#BC8F8F", "royalblue": "#4169E1",
  "saddlebrown": "#8B4513", "sandybrown": "#F4A460", "seagreen": "#2E8B57", "seashell": "#FFF5EE",
  "sienna": "#A0522D", "skyblue": "#87CEEB", "slateblue": "#6A5ACD", "slategray": "#708090", "snow": "#FFFAFA",
  "springgreen": "#00FF7F", "steelblue": "#4682B4", "tan": "#D2B48C", "thistle": "#D8BFD8", "wheat": "#F5DEB3",
  "whitesmoke": "#F5F5F5", "yellowgreen": "#9ACD32",
  // Tailwind Standard Colors
  "slate-50": "#F8FAFC", "slate-100": "#F1F5F9", "slate-200": "#E2E8F0", "slate-300": "#CBD5E1",
  "slate-400": "#94A3B8", "slate-500": "#64748B", "slate-600": "#475569", "slate-700": "#334155",
  "slate-800": "#1E293B", "slate-900": "#0F172A", "slate-950": "#020617",
  "gray-50": "#F9FAFB", "gray-100": "#F3F4F6", "gray-200": "#E5E7EB", "gray-300": "#D1D5DB",
  "gray-400": "#9CA3AF", "gray-500": "#6B7280", "gray-600": "#4B5563", "gray-700": "#374151",
  "gray-800": "#1F2937", "gray-900": "#111827", "gray-950": "#030712",
  "zinc-50": "#FAFAFA", "zinc-500": "#71717A", "zinc-900": "#18181B",
  "red-50": "#FEF2F2", "red-100": "#FEE2E2", "red-200": "#FECACA", "red-300": "#FCA5A5",
  "red-400": "#F87171", "red-500": "#EF4444", "red-600": "#DC2626", "red-700": "#B91C1C",
  "red-800": "#991B1B", "red-900": "#7F1D1D", "red-950": "#450A0A",
  "orange-50": "#FFF7ED", "orange-500": "#F97316", "orange-600": "#EA580C",
  "amber-50": "#FFFBEB", "amber-500": "#F59E0B", "amber-600": "#D97706",
  "yellow-50": "#FEFCE8", "yellow-500": "#EAB308", "yellow-600": "#CA8A04",
  "lime-50": "#F7FEE7", "lime-500": "#84CC16", "lime-600": "#65A30D",
  "green-50": "#F0FDF4", "green-500": "#22C55E", "green-600": "#16A34A",
  "emerald-50": "#ECFDF5", "emerald-100": "#D1FAE5", "emerald-200": "#A7F3D0", "emerald-300": "#6EE7B7",
  "emerald-400": "#34D399", "emerald-500": "#10B981", "emerald-600": "#059669", "emerald-700": "#047857",
  "teal-50": "#F0FDFA", "teal-500": "#14B8A6", "teal-600": "#0D9488",
  "cyan-50": "#ECFEFF", "cyan-500": "#06B6D4", "cyan-600": "#0891B2",
  "sky-50": "#F0F9FF", "sky-500": "#0EA5E9", "sky-600": "#0284C7",
  "blue-50": "#EFF6FF", "blue-100": "#DBEAFE", "blue-200": "#BFDBFE", "blue-300": "#93C5FD",
  "blue-400": "#60A5FA", "blue-500": "#3B82F6", "blue-600": "#2563EB", "blue-700": "#1D4ED8",
  "blue-800": "#1E40AF", "blue-900": "#1E3A8A", "blue-950": "#172554",
  "indigo-50": "#EEF2FF", "indigo-500": "#6366F1", "indigo-600": "#4F46E5",
  "violet-50": "#F5F3FF", "violet-500": "#8B5CF6", "violet-600": "#7C3AED",
  "purple-50": "#FAF5FF", "purple-500": "#A855F7", "purple-600": "#9333EA",
  "fuchsia-50": "#FDF4FF", "fuchsia-500": "#D946EF", "fuchsia-600": "#C026D3",
  "pink-50": "#FDF2F8", "pink-500": "#EC4899", "pink-600": "#DB2777",
  "rose-50": "#FFF1F2", "rose-500": "#F43F5E", "rose-600": "#E11D48"
}

function rgbToHex(r, g, b) {
  var clamp = function(n) { return Math.max(0, Math.min(255, Math.round(n))) }
  var toHex = function(n) {
    var h = clamp(n).toString(16).toUpperCase()
    return h.length === 1 ? "0" + h : h
  }
  return "#" + toHex(r) + toHex(g) + toHex(b)
}

function hslToRgb(h, s, l) {
  h = (((h % 360) + 360) % 360) / 360
  s = Math.max(0, Math.min(100, s)) / 100
  l = Math.max(0, Math.min(100, l)) / 100
  var r, g, b
  if (s === 0) {
    r = g = b = l
  } else {
    var hue2rgb = function(p, q, t) {
      if (t < 0) t += 1
      if (t > 1) t -= 1
      if (t < 1/6) return p + (q - p) * 6 * t
      if (t < 1/2) return q
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
      return p
    }
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s
    var p = 2 * l - q
    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  }
  return { r: Math.round(r * 255), g: Math.round(g * 255), b: Math.round(b * 255) }
}

// Extract canonical #RRGGBB hex from any color format (Flutter, Swift, CSS, hex, Tailwind, etc.)
function extractColorHex(str) {
  if (!str) return null
  var s = String(str).trim()
  if (!s) return null

  // Collapse internal whitespace
  var normalized = s.replace(/\s+/g, " ")

  // 1. Flutter / Dart / Kotlin / Android: Color(0xFF3B82F6), Color(0x3B82F6), 0xFF3B82F6, 0x3B82F6
  var flutterMatch = normalized.match(/^(?:Color\s*\(\s*)?0x([0-9a-fA-F]{6,8})(?:\s*\))?$/i)
  if (flutterMatch) {
    var hexDigits = flutterMatch[1]
    if (hexDigits.length === 8) return "#" + hexDigits.substring(2).toUpperCase()
    return "#" + hexDigits.toUpperCase()
  }

  // 2. Standard Hex: #RGB, #RGBA, #RRGGBB, #RRGGBBAA
  if (/^#([0-9a-fA-F]{3})$/i.test(normalized)) {
    var h3 = normalized.substring(1)
    return ("#" + h3[0] + h3[0] + h3[1] + h3[1] + h3[2] + h3[2]).toUpperCase()
  }
  if (/^#([0-9a-fA-F]{4})$/i.test(normalized)) {
    var h4 = normalized.substring(1)
    return ("#" + h4[0] + h4[0] + h4[1] + h4[1] + h4[2] + h4[2]).toUpperCase()
  }
  if (/^#([0-9a-fA-F]{6})$/i.test(normalized)) return normalized.toUpperCase()
  if (/^#([0-9a-fA-F]{8})$/i.test(normalized)) return ("#" + normalized.substring(1, 7)).toUpperCase()

  // 3. CSS / SASS Variables: --color: #3b82f6; or $color: #3b82f6;
  var varMatch = normalized.match(/^[\-\$][\w\-]+\s*:\s*(.+?)\s*;?$/)
  if (varMatch) {
    var inner = extractColorHex(varMatch[1])
    if (inner) return inner
  }

  // 4. CSS property values: color: #3b82f6; background-color: rgb(59, 130, 246)
  var cssPropMatch = normalized.match(/^(?:color|background|background-color|border-color|fill|stroke)\s*:\s*(.+?)\s*;?$/i)
  if (cssPropMatch) {
    var propColor = extractColorHex(cssPropMatch[1])
    if (propColor) return propColor
  }

  // 5. Android XML: <color name="...">#FF3B82F6</color>
  var xmlMatch = normalized.match(/^<color[^>]*>\s*([#0-9a-fA-F]+)\s*<\/color>$/i)
  if (xmlMatch) {
    var xmlHex = xmlMatch[1]
    if (xmlHex.startsWith("#")) xmlHex = xmlHex.substring(1)
    if (xmlHex.length === 8) return "#" + xmlHex.substring(2).toUpperCase()
    if (xmlHex.length === 6) return "#" + xmlHex.toUpperCase()
  }

  // 6. Swift UIColor: UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1.0)
  // or SwiftUI Color: Color(red: 0.231, green: 0.510, blue: 0.965)
  var swiftMatch = normalized.match(/^(?:UI)?Color\s*\(\s*red:\s*([\d.]+)\s*,\s*green:\s*([\d.]+)\s*,\s*blue:\s*([\d.]+)(?:[,\s]+(?:alpha|opacity):\s*[\d.]+)?\s*\)$/i)
  if (swiftMatch) {
    var sr = Math.min(255, Math.max(0, Math.round(parseFloat(swiftMatch[1]) * 255)))
    var sg = Math.min(255, Math.max(0, Math.round(parseFloat(swiftMatch[2]) * 255)))
    var sb = Math.min(255, Math.max(0, Math.round(parseFloat(swiftMatch[3]) * 255)))
    return rgbToHex(sr, sg, sb)
  }

  // 7. Objective-C: [UIColor colorWithRed:0.231 green:0.510 blue:0.965 alpha:1.0]
  var objcMatch = normalized.match(/^\[UIColor\s+colorWithRed:\s*([\d.]+)\s+green:\s*([\d.]+)\s+blue:\s*([\d.]+)\s+alpha:\s*[\d.]+\s*\]$/i)
  if (objcMatch) {
    var or = Math.min(255, Math.max(0, Math.round(parseFloat(objcMatch[1]) * 255)))
    var og = Math.min(255, Math.max(0, Math.round(parseFloat(objcMatch[2]) * 255)))
    var ob = Math.min(255, Math.max(0, Math.round(parseFloat(objcMatch[3]) * 255)))
    return rgbToHex(or, og, ob)
  }

  // 8. C# / Java AWT / Flutter methods:
  // Color.FromArgb(255, 59, 130, 246) or Color.fromARGB(255, 59, 130, 246)
  var argbMatch = normalized.match(/^Color\.(?:fromARGB|FromArgb)\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$/i)
  if (argbMatch) {
    return rgbToHex(parseInt(argbMatch[2]), parseInt(argbMatch[3]), parseInt(argbMatch[4]))
  }

  // Color.fromRGBO(59, 130, 246, 1.0)
  var rgbaObjMatch = normalized.match(/^Color\.fromRGBO\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*[\d.]+\s*\)$/i)
  if (rgbaObjMatch) {
    return rgbToHex(parseInt(rgbaObjMatch[1]), parseInt(rgbaObjMatch[2]), parseInt(rgbaObjMatch[3]))
  }

  // new Color(59, 130, 246) or new Color(59, 130, 246, 255)
  var javaMatch = normalized.match(/^new\s+Color\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*\d+)?\s*\)$/i)
  if (javaMatch) {
    return rgbToHex(parseInt(javaMatch[1]), parseInt(javaMatch[2]), parseInt(javaMatch[3]))
  }

  // 9. CSS rgb(...) or rgba(...)
  var rgbMatch = normalized.match(/^rgba?\s*\(\s*([\d.]+%?)\s*[, ]\s*([\d.]+%?)\s*[, ]\s*([\d.]+%?)(?:\s*[,/]\s*[\d.]+%?)?\s*\)$/i)
  if (rgbMatch) {
    var parseVal = function(v) {
      if (v.endsWith("%")) return Math.round((parseFloat(v) / 100) * 255)
      return Math.round(parseFloat(v))
    }
    return rgbToHex(parseVal(rgbMatch[1]), parseVal(rgbMatch[2]), parseVal(rgbMatch[3]))
  }

  // 10. CSS hsl(...) or hsla(...)
  var hslMatch = normalized.match(/^hsla?\s*\(\s*([\d.]+)(?:deg)?\s*[, ]\s*([\d.]+)%?\s*[, ]\s*([\d.]+)%?(?:\s*[,/]\s*[\d.]+%?)?\s*\)$/i)
  if (hslMatch) {
    var hVal = parseFloat(hslMatch[1]), sVal = parseFloat(hslMatch[2]), lVal = parseFloat(hslMatch[3])
    var rgbHsl = hslToRgb(hVal, sVal, lVal)
    return rgbToHex(rgbHsl.r, rgbHsl.g, rgbHsl.b)
  }

  // 11. Named / Tailwind Colors
  var lower = normalized.toLowerCase()
  if (NAMED_COLORS[lower]) return NAMED_COLORS[lower]

  return null
}

function isColor(str) {
  return extractColorHex(str) !== null
}

function isHexColor(str) {
  return extractColorHex(str) !== null
}

function hexToRgb(hex) {
  var h = String(hex || "").trim().replace("#", "")
  if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
  if (h.length < 6) return ""
  var num = parseInt(h.substring(0, 6), 16)
  if (isNaN(num)) return ""
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
  if (isColor(raw)) return "color"
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
      var cHex = extractColorHex(raw)
      if (cHex && !seen[cHex.toLowerCase()]) {
        seen[cHex.toLowerCase()] = true
        colors.push({
          hex: cHex,
          rgb: hexToRgb(cHex),
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

  // Extract app: filter (e.g. app:code, app:kitty, app:firefox)
  var appFilter = ""
  var appMatch = needle.match(/(?:^|\s)app:(\S+)/i)
  if (appMatch) {
    appFilter = appMatch[1].toLowerCase()
    needle = needle.replace(appMatch[0], "").trim()
  }

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
    if (appFilter) {
      var itemApp = String(entry.sourceApp || "").toLowerCase()
      if (itemApp.indexOf(appFilter) < 0) continue
    }
    if (needle && searchableText(entry).toLowerCase().indexOf(needle) < 0) continue
    if (dFilter && !matchDateFilter(entry.capturedAt, dFilter)) continue

    var isPinned = !!entry.pinned
    var isFav = !!entry.favorite
    var kind = detectKind(entry)

    if (cat === "pinned" && !isPinned) continue
    if (cat === "favorites" && !isFav) continue
    if (cat !== "all" && cat !== "pinned" && cat !== "favorites") {
      if (cat.indexOf("tag:") === 0) {
        var tagNeedle = cat.substring(4).toLowerCase()
        var itemTags = Array.isArray(entry.tags) ? entry.tags.map(function(t) { return String(t).toLowerCase() }) : []
        if (itemTags.indexOf(tagNeedle) < 0) continue
      } else if (cat === "text" && kind !== "text" && kind !== "code" && kind !== "link") continue
      else if (cat === "image" && kind !== "image") continue
      else if (cat === "code" && kind !== "code") continue
      else if (cat === "color" && kind !== "color") continue
      else if (cat === "link" && kind !== "link") continue
      else if (cat === "file" && kind !== "file") continue
    }

    var paths = filePaths(entry)
    var isFile = paths.length > 0
    var isImage = entry.type === "image"
    var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    var rawText = isImage ? "" : fullText(entry)
    var hex = kind === "color" ? (extractColorHex(rawText) || rawText.trim()) : ""
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
      copyCount: Math.max(1, Number(entry.copyCount || 1)),
      sourceApp: String(entry.sourceApp || ""),
      sourceTitle: String(entry.sourceTitle || ""),
      revisionCount: Array.isArray(entry.revisions) ? entry.revisions.length : 0,
      revisions: Array.isArray(entry.revisions) ? entry.revisions : [],
      urlDomain: kind === "link" ? extractDomain(rawText) : "",
      tags: Array.isArray(entry.tags) ? entry.tags : [],
      colors: isImage && Array.isArray(entry.colors) ? entry.colors : [],
      isQr: isImage && (!!entry.isQr || (typeof entry.qrText === "string" && entry.qrText.length > 0)),
      qrText: isImage ? String(entry.qrText || "") : "",
      index: wrapped.index
    })
    if (rows.length >= max) break
  }
  return rows
}

function extractDomain(urlStr) {
  try {
    var match = String(urlStr || "").match(/^https?:\/\/([^\/\?\#]+)/i)
    if (match && match[1]) return match[1].replace(/^www\./i, "")
    return ""
  } catch (e) { return "" }
}

function setClipTags(history, index, tags) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  var item = Object.assign({}, next[target])
  item.tags = Array.isArray(tags) ? tags : []
  next[target] = item
  return next
}

function getAllTags(history) {
  var values = Array.isArray(history) ? history : []
  var seen = {}
  var tags = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (item && Array.isArray(item.tags)) {
      for (var t = 0; t < item.tags.length; t++) {
        var tag = String(item.tags[t]).trim()
        if (tag && !seen[tag]) {
          seen[tag] = true
          tags.push(tag)
        }
      }
    }
  }
  return tags
}

function bulkDelete(history, indices) {
  var values = Array.isArray(history) ? history : []
  var idxSet = {}
  if (Array.isArray(indices)) {
    for (var i = 0; i < indices.length; i++) idxSet[indices[i]] = true
  }
  var next = []
  for (var j = 0; j < values.length; j++) {
    if (!idxSet[j]) next.push(values[j])
  }
  return next
}

function bulkPin(history, indices, pinState) {
  var values = Array.isArray(history) ? history : []
  var idxSet = {}
  if (Array.isArray(indices)) {
    for (var i = 0; i < indices.length; i++) idxSet[indices[i]] = true
  }
  var next = []
  for (var j = 0; j < values.length; j++) {
    if (idxSet[j]) {
      var item = Object.assign({}, values[j])
      item.pinned = (pinState !== undefined) ? !!pinState : true
      next.push(item)
    } else {
      next.push(values[j])
    }
  }
  return next
}

function applyRetentionLimits(history, maxClips, maxDays) {
  var values = Array.isArray(history) ? history : []
  var now = Date.now()
  var maxAgeMs = (maxDays && maxDays > 0) ? (maxDays * 86400000) : 0
  var limit = (maxClips && maxClips > 0) ? maxClips : 10000

  var filtered = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item) continue
    if (item.pinned) {
      filtered.push(item)
      continue
    }
    if (maxAgeMs > 0 && item.capturedAt) {
      var age = now - parseClipDate(item.capturedAt).getTime()
      if (age > maxAgeMs) continue
    }
    filtered.push(item)
  }

  if (filtered.length > limit) {
    var pinned = []
    var unpinned = []
    for (var j = 0; j < filtered.length; j++) {
      if (filtered[j].pinned) pinned.push(filtered[j])
      else unpinned.push(filtered[j])
    }
    var remainingSlots = Math.max(0, limit - pinned.length)
    filtered = pinned.concat(unpinned.slice(0, remainingSlots))
  }

  return filtered
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeEntry: normalizeEntry, entryKey: entryKey, parseHistory: parseHistory,
    addEntry: addEntry, removeEntryAt: removeEntryAt, togglePin: togglePin,
    toggleFavorite: toggleFavorite, updateEntryText: updateEntryText,
    transformText: transformText, mergeEntries: mergeEntries, clearHistory: clearHistory,
    parseEntryJson: parseEntryJson, searchableText: searchableText, previewText: previewText,
    fullText: fullText, displayRows: displayRows, detectKind: detectKind, isHexColor: isHexColor,
    isColor: isColor, extractColorHex: extractColorHex,
    isUrl: isUrl, isCodeSnippet: isCodeSnippet, detectCodeLanguage: detectCodeLanguage,
    hexToRgb: hexToRgb, formatTimeAgo: formatTimeAgo, extractColors: extractColors,
    matchDateFilter: matchDateFilter, getClipDateCounts: getClipDateCounts,
    extractDomain: extractDomain, setClipTags: setClipTags, getAllTags: getAllTags,
    bulkDelete: bulkDelete, bulkPin: bulkPin, applyRetentionLimits: applyRetentionLimits,
    computeSimilarity: computeSimilarity, computeLineDiff: computeLineDiff,
    computeDiffStats: computeDiffStats, restoreRevision: restoreRevision,
    deleteRevision: deleteRevision
  }
}
