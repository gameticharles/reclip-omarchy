.pragma library

// =============================================================================
// ReClip Omarchy - Dynamic Templates & Snippet Variables Engine
// =============================================================================

var DEFAULT_TEMPLATES = [
  {
    id: "tpl_meeting",
    name: "Meeting Notes",
    language: "markdown",
    content: "# Meeting Notes - {{date}}\n**Date**: {{date}} {{time}}\n**Attendees**: {{attendees}}\n\n## Agenda\n- [ ] \n\n## Discussion & Key Points\n- \n\n## Action Items\n- [ ] \n"
  },
  {
    id: "tpl_commit",
    name: "Conventional Commit",
    language: "text",
    content: "feat({{scope}}): {{summary}}\n\n- {{details}}\n\nRefs: {{issue}}"
  },
  {
    id: "tpl_md_link",
    name: "Markdown Link (Clipboard URL)",
    language: "markdown",
    content: "[{{title}}]({{clipboard}})"
  },
  {
    id: "tpl_bug_report",
    name: "Bug Report Template",
    language: "markdown",
    content: "### 🐛 Bug: {{title}}\n**Reported**: {{datetime}}\n**Tracking ID**: {{uuid}}\n\n#### Description\n{{description}}\n\n#### Steps to Reproduce\n1. \n2. \n\n#### Expected Behavior\n\n\n#### Actual Behavior\n"
  },
  {
    id: "tpl_log_note",
    name: "Timestamped Note",
    language: "markdown",
    content: "[{{date}} {{time}}] {{clipboard}}"
  },
  {
    id: "tpl_email_sig",
    name: "Email Signature",
    language: "text",
    content: "Best regards,\n{{name}}\nSent on {{date}} at {{time}}"
  }
];

// Generate RFC4122 v4 UUID
function generateUuid() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0;
    var v = c === "x" ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Zero-pad number
function pad2(n) {
  return n < 10 ? "0" + n : String(n);
}

// Format Date/Time helper
function formatDateTime(date, format) {
  var d = date instanceof Date ? date : new Date();
  var year = d.getFullYear();
  var month = pad2(d.getMonth() + 1);
  var day = pad2(d.getDate());
  var hours24 = d.getHours();
  var hours12 = hours24 % 12 || 12;
  var ampm = hours24 >= 12 ? "PM" : "AM";
  var minutes = pad2(d.getMinutes());
  var seconds = pad2(d.getSeconds());

  var daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  var daysOfWeekShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  var monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  if (!format || format === "YYYY-MM-DD") {
    return year + "-" + month + "-" + day;
  }
  if (format === "HH:mm:ss") {
    return pad2(hours24) + ":" + minutes + ":" + seconds;
  }
  if (format === "hh:mm A") {
    return pad2(hours12) + ":" + minutes + " " + ampm;
  }
  if (format === "ISO") {
    return d.toISOString();
  }

  return format
    .replace(/YYYY/g, String(year))
    .replace(/MM/g, month)
    .replace(/DD/g, day)
    .replace(/dddd/g, daysOfWeek[d.getDay()])
    .replace(/ddd/g, daysOfWeekShort[d.getDay()])
    .replace(/MMM/g, monthsShort[d.getMonth()])
    .replace(/HH/g, pad2(hours24))
    .replace(/hh/g, pad2(hours12))
    .replace(/mm/g, minutes)
    .replace(/ss/g, seconds)
    .replace(/A/g, ampm);
}

// Built-in variable resolver
function resolveBuiltin(varName, clipboardText) {
  var now = new Date();
  var lower = varName.toLowerCase().trim();

  if (lower === "date") {
    return formatDateTime(now, "YYYY-MM-DD");
  }
  if (lower.indexOf("date:") === 0) {
    var fmt = varName.substring(5).trim();
    return formatDateTime(now, fmt);
  }
  if (lower === "time") {
    return formatDateTime(now, "HH:mm:ss");
  }
  if (lower.indexOf("time:") === 0) {
    var tfmt = varName.substring(5).trim();
    return formatDateTime(now, tfmt);
  }
  if (lower === "datetime" || lower === "now") {
    return formatDateTime(now, "YYYY-MM-DD HH:mm:ss");
  }
  if (lower === "year") {
    return String(now.getFullYear());
  }
  if (lower === "month") {
    return pad2(now.getMonth() + 1);
  }
  if (lower === "day") {
    return pad2(now.getDate());
  }
  if (lower === "timestamp") {
    return String(Math.floor(now.getTime() / 1000));
  }
  if (lower === "timestamp_ms") {
    return String(now.getTime());
  }
  if (lower === "uuid" || lower === "guid") {
    return generateUuid();
  }
  if (lower === "clipboard") {
    return clipboardText !== undefined ? String(clipboardText) : "";
  }
  if (lower.indexOf("random:") === 0) {
    var digits = parseInt(varName.substring(7).trim()) || 6;
    var result = "";
    for (var i = 0; i < digits; i++) {
      result += Math.floor(Math.random() * 10);
    }
    return result;
  }

  return null;
}

// Check if string contains any {{variable}} tokens
function hasVariables(text) {
  if (!text || typeof text !== "string") return false;
  return /\{\{[^{}]+\}\}/.test(text);
}

// Extract list of all unique placeholder names in template text
function extractVariables(text) {
  if (!text || typeof text !== "string") return [];
  var regex = /\{\{([^{}]+)\}\}/g;
  var match;
  var vars = [];
  var seen = {};

  while ((match = regex.exec(text)) !== null) {
    var raw = match[1].trim();
    if (!seen[raw]) {
      seen[raw] = true;
      var isBuiltin = resolveBuiltin(raw, "") !== null;
      vars.push({
        token: "{{" + raw + "}}",
        name: raw,
        isBuiltin: isBuiltin
      });
    }
  }

  return vars;
}

// Expand template string with built-in variables and optional custom variable dictionary
function expand(templateText, customVars, clipboardText) {
  if (!templateText || typeof templateText !== "string") return "";
  var vars = customVars || {};

  return templateText.replace(/\{\{([^{}]+)\}\}/g, function(match, varExpr) {
    var trimmed = varExpr.trim();

    // Check custom variables dictionary first
    if (vars[trimmed] !== undefined) {
      return String(vars[trimmed]);
    }

    // Check built-in resolvers
    var builtinVal = resolveBuiltin(trimmed, clipboardText);
    if (builtinVal !== null) {
      return builtinVal;
    }

    // If undefined custom placeholder, leave as is or return default
    return match;
  });
}

// Parse templates store JSON (or initialize with defaults)
function parseTemplates(raw) {
  try {
    if (!raw || !raw.trim()) return DEFAULT_TEMPLATES.slice();
    var parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      return parsed.length > 0 ? parsed : DEFAULT_TEMPLATES.slice();
    }
    if (parsed && Array.isArray(parsed.templates)) {
      return parsed.templates.length > 0 ? parsed.templates : DEFAULT_TEMPLATES.slice();
    }
  } catch(e) {}
  return DEFAULT_TEMPLATES.slice();
}

// Add a template
function addTemplate(templates, tpl) {
  var list = Array.isArray(templates) ? templates.slice() : [];
  var newTpl = {
    id: "tpl_" + Date.now(),
    name: (tpl.name || "Untitled Template").trim(),
    language: (tpl.language || "text").trim(),
    content: String(tpl.content || "")
  };
  list.unshift(newTpl);
  return list;
}

// Update a template
function updateTemplate(templates, id, updated) {
  var list = Array.isArray(templates) ? templates.slice() : [];
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      list[i] = Object.assign({}, list[i], {
        name: (updated.name || list[i].name).trim(),
        language: (updated.language || list[i].language).trim(),
        content: updated.content !== undefined ? String(updated.content) : list[i].content
      });
      break;
    }
  }
  return list;
}

// Delete a template
function deleteTemplate(templates, id) {
  var list = Array.isArray(templates) ? templates.slice() : [];
  return list.filter(function(t) { return t.id !== id; });
}
