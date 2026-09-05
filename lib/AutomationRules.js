.pragma library

// =============================================================================
// ReClip Omarchy - Automations & Regex Rules Engine
// =============================================================================

var DEFAULT_RULES = [
  {
    id: "rule_email",
    name: "Auto-tag Email Addresses",
    pattern: "\\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\b",
    action: "tag",
    payload: "email",
    enabled: true
  },
  {
    id: "rule_jwt",
    name: "Auto-tag JWT & Bearer Tokens",
    pattern: "eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}",
    action: "tag",
    payload: "jwt",
    enabled: true
  },
  {
    id: "rule_ip",
    name: "Auto-tag IPv4 Addresses",
    pattern: "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b",
    action: "tag",
    payload: "ip",
    enabled: true
  },
  {
    id: "rule_hexcolor",
    name: "Auto-tag Hex Color Codes",
    pattern: "^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$",
    action: "tag",
    payload: "hexcolor",
    enabled: true
  },
  {
    id: "rule_url",
    name: "Auto-tag Web URLs",
    pattern: "https?:\\/\\/[^\\s$.?#].[^\\s]*",
    action: "tag",
    payload: "url",
    enabled: true
  },
  {
    id: "rule_pwd_ignore",
    name: "Privacy: Ignore Passwords",
    pattern: "^(?:password|secret|passwd|api[_-]?key)\\s*[:=]\\s*.+",
    action: "ignore",
    payload: "",
    enabled: false
  },
  {
    id: "rule_cc_ignore",
    name: "Privacy: Ignore Credit Cards",
    pattern: "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b",
    action: "ignore",
    payload: "",
    enabled: false
  },
  {
    id: "rule_gh_issue",
    name: "GitHub Issue Notification",
    pattern: "(?:GH-|gh-|#)(\\d{1,6})",
    action: "notify",
    payload: "Detected issue reference #$1",
    enabled: false
  },
  {
    id: "rule_utm_clean",
    name: "Privacy: Clean URL Tracking Params",
    pattern: "[?&]utm_[a-zA-Z0-9_]+=[^&#]*",
    action: "replace",
    payload: "",
    enabled: false
  },
  {
    id: "rule_strip_ws",
    name: "Text: Trim Trailing Spaces",
    pattern: "[ \\t]+$",
    action: "replace",
    payload: "",
    enabled: false
  }
];

function parseRules(raw) {
  try {
    if (!raw || !raw.trim()) return DEFAULT_RULES.slice();
    var parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      return parsed.length > 0 ? parsed : DEFAULT_RULES.slice();
    }
    if (parsed && Array.isArray(parsed.rules)) {
      return parsed.rules.length > 0 ? parsed.rules : DEFAULT_RULES.slice();
    }
  } catch(e) {}
  return DEFAULT_RULES.slice();
}

function addRule(rules, rule) {
  var list = Array.isArray(rules) ? rules.slice() : [];
  var newRule = {
    id: "rule_" + Date.now(),
    name: (rule.name || "Untitled Rule").trim(),
    pattern: (rule.pattern || "").trim(),
    action: rule.action || "tag",
    payload: String(rule.payload || "").trim(),
    enabled: rule.enabled !== undefined ? !!rule.enabled : true
  };
  list.unshift(newRule);
  return list;
}

function updateRule(rules, id, updated) {
  var list = Array.isArray(rules) ? rules.slice() : [];
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      list[i] = Object.assign({}, list[i], {
        name: updated.name !== undefined ? updated.name.trim() : list[i].name,
        pattern: updated.pattern !== undefined ? updated.pattern.trim() : list[i].pattern,
        action: updated.action !== undefined ? updated.action : list[i].action,
        payload: updated.payload !== undefined ? String(updated.payload).trim() : list[i].payload,
        enabled: updated.enabled !== undefined ? !!updated.enabled : list[i].enabled
      });
      break;
    }
  }
  return list;
}

function toggleRule(rules, id) {
  var list = Array.isArray(rules) ? rules.slice() : [];
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      var item = Object.assign({}, list[i]);
      item.enabled = !item.enabled;
      list[i] = item;
      break;
    }
  }
  return list;
}

function deleteRule(rules, id) {
  var list = Array.isArray(rules) ? rules.slice() : [];
  return list.filter(function(r) { return r.id !== id; });
}

// Live regex tester sandbox helper
function testRule(pattern, action, payload, sampleText) {
  if (!pattern || !pattern.trim()) {
    return { valid: false, error: "Empty pattern", matches: false, simulatedResult: "" };
  }
  try {
    var regex = new RegExp(pattern);
    var sample = sampleText !== undefined ? String(sampleText) : "";
    var match = regex.exec(sample);
    if (!match) {
      return {
        valid: true,
        error: "",
        matches: false,
        groups: [],
        matchedText: "",
        simulatedResult: "No match on sample text"
      };
    }

    var groups = [];
    for (var i = 0; i < match.length; i++) {
      groups.push({ index: i, value: match[i] !== undefined ? match[i] : "" });
    }

    var simulated = "";
    var act = action || "tag";
    if (act === "ignore") {
      simulated = "Clip dropped (ignored by privacy filter)";
    } else if (act === "tag") {
      simulated = "Clip tagged with: #" + (payload || "tag");
    } else if (act === "open_url") {
      var url = payload || "";
      for (var g = 0; g < match.length; g++) {
        url = url.replace(new RegExp("\\$" + g, "g"), match[g] || "");
      }
      simulated = "Browser opened: " + url;
    } else if (act === "notify") {
      var msg = payload || "";
      for (var g2 = 0; g2 < match.length; g2++) {
        msg = msg.replace(new RegExp("\\$" + g2, "g"), match[g2] || "");
      }
      simulated = "Notification sent: \"" + msg + "\"";
    } else if (act === "replace") {
      var rep = sample.replace(new RegExp(pattern, "gm"), payload !== undefined ? payload : "");
      simulated = "Transformed text: \"" + rep + "\"";
    }

    return {
      valid: true,
      error: "",
      matches: true,
      matchedText: match[0],
      groups: groups,
      simulatedResult: simulated
    };
  } catch(e) {
    return {
      valid: false,
      error: e.message || "Invalid regular expression",
      matches: false,
      groups: [],
      simulatedResult: "Regex compilation error"
    };
  }
}

// Evaluate clipboard text against all enabled automation & regex rules
function evaluateClip(rules, clipText, existingTags) {
  var result = {
    ignored: false,
    reason: "",
    tags: Array.isArray(existingTags) ? existingTags.slice() : [],
    actions: [],
    modifiedText: clipText || ""
  };

  if (!clipText || typeof clipText !== "string") {
    return result;
  }

  var list = Array.isArray(rules) ? rules : [];
  for (var i = 0; i < list.length; i++) {
    var rule = list[i];
    if (!rule.enabled || !rule.pattern) continue;

    try {
      var regex = new RegExp(rule.pattern);
      var match = regex.exec(result.modifiedText);
      if (match) {
        // 1. Ignore rule
        if (rule.action === "ignore") {
          result.ignored = true;
          result.reason = rule.name || "Regex Privacy Filter";
          return result; // Immediately abort and drop clip
        }

        // 2. Tag rule
        if (rule.action === "tag") {
          var tagVal = rule.payload.toLowerCase().trim();
          if (tagVal && result.tags.indexOf(tagVal) < 0) {
            result.tags.push(tagVal);
          }
        }

        // 3. Open URL rule
        if (rule.action === "open_url") {
          var targetUrl = rule.payload;
          for (var g = 0; g < match.length; g++) {
            targetUrl = targetUrl.replace(new RegExp("\\$" + g, "g"), match[g] || "");
          }
          result.actions.push({
            type: "open_url",
            url: targetUrl,
            ruleName: rule.name
          });
        }

        // 4. Notification rule
        if (rule.action === "notify") {
          var notifMsg = rule.payload || ("Matched " + rule.name);
          for (var g2 = 0; g2 < match.length; g2++) {
            notifMsg = notifMsg.replace(new RegExp("\\$" + g2, "g"), match[g2] || "");
          }
          result.actions.push({
            type: "notify",
            title: "ReClip Automation: " + (rule.name || "Rule Matched"),
            message: notifMsg
          });
        }

        // 5. Replace / Clean rule
        if (rule.action === "replace") {
          result.modifiedText = result.modifiedText.replace(new RegExp(rule.pattern, "gm"), rule.payload !== undefined ? rule.payload : "");
        }
      }
    } catch(e) {
      // Ignore invalid regex syntax gracefully
    }
  }

  return result;
}
