function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
}

function parseStore(raw) {
  try {
    var parsed = JSON.parse(String(raw || "{}"))
    var snippets = Array.isArray(parsed.snippets) ? parsed.snippets : []
    var folders = Array.isArray(parsed.folders) ? parsed.folders : []
    var cleanSnippets = []
    for (var i = 0; i < snippets.length; i++) {
      var s = snippets[i]
      if (s && typeof s === "object" && (s.title || s.content)) {
        cleanSnippets.push({
          id: s.id || uid(),
          title: String(s.title || "Untitled"),
          content: String(s.content || ""),
          language: String(s.language || "text"),
          folder: String(s.folder || ""),
          tags: String(s.tags || ""),
          favorite: !!s.favorite,
          createdAt: String(s.createdAt || new Date().toISOString()),
          updatedAt: String(s.updatedAt || new Date().toISOString())
        })
      }
    }
    var cleanFolders = []
    for (var j = 0; j < folders.length; j++) {
      var f = folders[j]
      if (f && typeof f === "object" && f.name) {
        cleanFolders.push({ id: f.id || uid(), name: String(f.name) })
      }
    }
    return { snippets: cleanSnippets, folders: cleanFolders }
  } catch (e) { return { snippets: [], folders: [] } }
}

function addSnippet(snippets, data) {
  var now = new Date().toISOString()
  var snippet = {
    id: uid(),
    title: String(data.title || "Untitled"),
    content: String(data.content || ""),
    language: String(data.language || "text"),
    folder: String(data.folder || ""),
    tags: String(data.tags || ""),
    favorite: !!data.favorite,
    createdAt: now,
    updatedAt: now
  }
  var next = snippets.slice()
  next.unshift(snippet)
  return next
}

function updateSnippet(snippets, index, data) {
  if (index < 0 || index >= snippets.length) return snippets
  var next = snippets.slice()
  var s = Object.assign({}, next[index])
  if (data.title !== undefined) s.title = String(data.title)
  if (data.content !== undefined) s.content = String(data.content)
  if (data.language !== undefined) s.language = String(data.language)
  if (data.folder !== undefined) s.folder = String(data.folder)
  if (data.tags !== undefined) s.tags = String(data.tags)
  if (data.favorite !== undefined) s.favorite = !!data.favorite
  s.updatedAt = new Date().toISOString()
  next[index] = s
  return next
}

function removeSnippet(snippets, index) {
  if (index < 0 || index >= snippets.length) return snippets
  var next = snippets.slice()
  next.splice(index, 1)
  return next
}

function toggleFavorite(snippets, index) {
  if (index < 0 || index >= snippets.length) return snippets
  return updateSnippet(snippets, index, { favorite: !snippets[index].favorite })
}

function searchableText(snippet) {
  return (snippet.title || "") + " " + (snippet.content || "") + " " + (snippet.tags || "") + " " + (snippet.language || "")
}

function displayRows(snippets, query, limit) {
  var values = Array.isArray(snippets) ? snippets : []
  var needle = String(query || "").trim().toLowerCase()
  var max = limit === undefined ? 80 : Number(limit)
  if (isNaN(max)) max = 80
  max = Math.max(0, max)
  if (max === 0) return []

  var rows = []
  for (var i = 0; i < values.length; i++) {
    var s = values[i]
    if (!s) continue
    if (needle && searchableText(s).toLowerCase().indexOf(needle) < 0) continue
    var preview = String(s.content || "").replace(/\s+/g, " ")
    if (preview.length > 120) preview = preview.slice(0, 120) + "…"
    rows.push({
      index: i,
      title: s.title || "Untitled",
      content: s.content || "",
      language: s.language || "text",
      tags: s.tags || "",
      folder: s.folder || "",
      favorite: !!s.favorite,
      preview: preview
    })
    if (rows.length >= max) break
  }

  rows.sort(function(a, b) {
    if (a.favorite && !b.favorite) return -1
    if (!a.favorite && b.favorite) return 1
    return 0
  })

  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStore: parseStore, addSnippet: addSnippet, updateSnippet: updateSnippet,
    removeSnippet: removeSnippet, toggleFavorite: toggleFavorite, displayRows: displayRows
  }
}
