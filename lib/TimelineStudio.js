function parseClipDate(dateVal) {
  if (!dateVal) return new Date()
  var d = new Date(dateVal)
  if (!isNaN(d.getTime())) return d
  // If date was stored as e.g. "Thursday 21:42", fallback to today
  return new Date()
}

function formatLocalDate(d) {
  var date = d instanceof Date ? d : parseClipDate(d)
  var year = date.getFullYear()
  var month = String(date.getMonth() + 1).padStart(2, "0")
  var day = String(date.getDate()).padStart(2, "0")
  return year + "-" + month + "-" + day
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

function buildCalendarGrid(year, month, history, activeFilter) {
  var dateCounts = getClipDateCounts(history)
  var firstDay = new Date(year, month, 1).getDay()
  var lastDay = new Date(year, month + 1, 0).getDate()
  var now = new Date()
  var todayStr = formatLocalDate(now)
  var cells = []

  // Leading padding
  for (var p = 0; p < firstDay; p++) {
    cells.push({ day: 0, dateStr: "", count: 0, isToday: false, isSelected: false, isPad: true })
  }

  // Days in month
  for (var d = 1; d <= lastDay; d++) {
    var dStr = year + "-" + String(month + 1).padStart(2, "0") + "-" + String(d).padStart(2, "0")
    var count = dateCounts[dStr] || 0
    cells.push({
      day: d,
      dateStr: dStr,
      count: count,
      isToday: (dStr === todayStr),
      isSelected: (activeFilter === dStr),
      isPad: false
    })
  }

  // Trailing padding to complete full row of 7
  while (cells.length % 7 !== 0) {
    cells.push({ day: 0, dateStr: "", count: 0, isToday: false, isSelected: false, isPad: true })
  }

  return cells
}

function computeTimelineMarkers(clips, zoomLevel) {
  var values = Array.isArray(clips) ? clips : []
  if (values.length === 0) {
    return { markers: [], oldestStr: "", newestStr: "", total: 0 }
  }

  var now = new Date()
  var timestamps = []
  for (var i = 0; i < values.length; i++) {
    var d = parseClipDate(values[i].capturedAt)
    timestamps.push({ date: d, clip: values[i] })
  }

  timestamps.sort(function(a, b) { return a.date.getTime() - b.date.getTime() })
  var oldest = timestamps[0].date
  var newest = timestamps[timestamps.length - 1].date
  var rangeMs = Math.max(1000 * 60, newest.getTime() - oldest.getTime())

  var zoom = zoomLevel || "day"
  var buckets = {}

  for (var j = 0; j < timestamps.length; j++) {
    var item = timestamps[j]
    var dt = item.date
    var key = ""
    var label = ""

    if (zoom === "hour") {
      key = formatLocalDate(dt) + "-" + dt.getHours()
      var hrsAgo = Math.floor((now.getTime() - dt.getTime()) / 3600000)
      label = hrsAgo <= 0 ? "Now" : (hrsAgo < 24 ? hrsAgo + "h ago" : formatLocalDate(dt))
    } else if (zoom === "day") {
      key = formatLocalDate(dt)
      var daysAgo = Math.floor((now.getTime() - dt.getTime()) / 86400000)
      label = daysAgo <= 0 ? "Today" : (daysAgo === 1 ? "Yesterday" : formatLocalDate(dt))
    } else if (zoom === "week") {
      var wStart = new Date(dt)
      wStart.setDate(dt.getDate() - dt.getDay())
      key = formatLocalDate(wStart)
      label = "Week of " + formatLocalDate(wStart)
    } else {
      key = dt.getFullYear() + "-" + dt.getMonth()
      label = dt.toLocaleDateString("en-US", { month: "short", year: "numeric" })
    }

    if (!buckets[key]) {
      buckets[key] = { date: dt, count: 0, label: label }
    }
    buckets[key].count++
  }

  var maxCount = 1
  for (var k in buckets) {
    if (buckets[k].count > maxCount) maxCount = buckets[k].count
  }

  var markers = []
  for (var bk in buckets) {
    var b = buckets[bk]
    var pos = rangeMs === 0 ? 50 : ((b.date.getTime() - oldest.getTime()) / rangeMs) * 100
    markers.push({
      position: Math.max(0, Math.min(100, pos)),
      intensity: b.count / maxCount,
      count: b.count,
      label: b.label,
      dateStr: formatLocalDate(b.date)
    })
  }

  markers.sort(function(a, b) { return a.position - b.position })

  return {
    markers: markers,
    oldestStr: formatLocalDate(oldest),
    newestStr: formatLocalDate(newest),
    total: values.length
  }
}

function matchFilter(capturedAt, filter) {
  if (!filter || filter === "" || filter === "all") return true
  var d = parseClipDate(capturedAt)
  var now = new Date()
  var clipDateStr = formatLocalDate(d)
  var todayStr = formatLocalDate(now)

  if (filter === "today") return clipDateStr === todayStr
  if (filter === "yesterday") {
    var yest = new Date(now.getTime() - 86400000)
    return clipDateStr === formatLocalDate(yest)
  }
  if (filter === "7d") return (now.getTime() - d.getTime()) <= 7 * 86400000 && (now.getTime() - d.getTime()) >= 0
  if (filter === "30d") return (now.getTime() - d.getTime()) <= 30 * 86400000 && (now.getTime() - d.getTime()) >= 0
  if (filter === "mtd") return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()

  // Exact date match (YYYY-MM-DD)
  return clipDateStr === filter
}

if (typeof module !== "undefined") {
  module.exports = {
    parseClipDate: parseClipDate,
    formatLocalDate: formatLocalDate,
    getClipDateCounts: getClipDateCounts,
    buildCalendarGrid: buildCalendarGrid,
    computeTimelineMarkers: computeTimelineMarkers,
    matchFilter: matchFilter
  }
}
