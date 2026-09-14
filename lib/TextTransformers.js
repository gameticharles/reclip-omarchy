// TextTransformers.js - Comprehensive Transformation Library for ReClip
.pragma library

var TRANSFORMERS = [
  // Case Group
  { id: "uppercase", name: "UPPERCASE", category: "Case", icon: "󰬁", desc: "Convert all letters to UPPERCASE" },
  { id: "lowercase", name: "lowercase", category: "Case", icon: "󰬁", desc: "Convert all letters to lowercase" },
  { id: "titlecase", name: "Title Case", category: "Case", icon: "󰬁", desc: "Capitalize The First Letter Of Each Word" },
  { id: "camelcase", name: "camelCase", category: "Case", icon: "󰬁", desc: "Convert to camelCase identifier" },
  { id: "pascalcase", name: "PascalCase", category: "Case", icon: "󰬁", desc: "Convert to PascalCase identifier" },
  { id: "snakecase", name: "snake_case", category: "Case", icon: "󰬁", desc: "Convert to snake_case identifier" },
  { id: "kebabcase", name: "kebab-case", category: "Case", icon: "󰬁", desc: "Convert to kebab-case slug" },
  { id: "constantcase", name: "CONSTANT_CASE", category: "Case", icon: "󰬁", desc: "Convert to UPPERCASE_SNAKE identifier" },

  // Developer Group
  { id: "json_pretty", name: "JSON Pretty Print", category: "Developer", icon: "󰅩", desc: "Format JSON with 2-space indentation" },
  { id: "json_minify", name: "JSON Minify", category: "Developer", icon: "󰅩", desc: "Compress JSON into a single dense line" },
  { id: "base64_encode", name: "Base64 Encode", category: "Developer", icon: "󰌹", desc: "Encode string into Base64 format" },
  { id: "base64_decode", name: "Base64 Decode", category: "Developer", icon: "󰌹", desc: "Decode Base64 string back to text" },
  { id: "url_encode", name: "URL Encode", category: "Developer", icon: "󰌹", desc: "Percent-encode URL parameters" },
  { id: "url_decode", name: "URL Decode", category: "Developer", icon: "󰌹", desc: "Decode percent-encoded URL characters" },
  { id: "html_encode", name: "HTML Entities Encode", category: "Developer", icon: "󰅩", desc: "Convert HTML characters to safe entities" },
  { id: "html_decode", name: "HTML Entities Decode", category: "Developer", icon: "󰅩", desc: "Decode HTML entities back to characters" },
  { id: "escape_string", name: "Escape String", category: "Developer", icon: "󰅩", desc: "Escape quotes and newlines (\\n, \\\")" },
  { id: "unescape_string", name: "Unescape String", category: "Developer", icon: "󰅩", desc: "Convert escaped sequences back to text" },

  // Clean & Format Group
  { id: "trim_all", name: "Trim Lines", category: "Format", icon: "󰁨", desc: "Remove leading and trailing spaces on every line" },
  { id: "remove_blank_lines", name: "Remove Blank Lines", category: "Format", icon: "󰁨", desc: "Strip all empty and whitespace-only lines" },
  { id: "deduplicate_lines", name: "Deduplicate Lines", category: "Format", icon: "󰁨", desc: "Remove repeated duplicate lines" },
  { id: "sort_lines_asc", name: "Sort Lines (A → Z)", category: "Format", icon: "󰒺", desc: "Alphabetize lines in ascending order" },
  { id: "sort_lines_desc", name: "Sort Lines (Z → A)", category: "Format", icon: "󰒺", desc: "Alphabetize lines in descending order" },
  { id: "add_line_numbers", name: "Number Lines", category: "Format", icon: "󰒺", desc: "Prefix each line with 1., 2., 3." },
  { id: "bullet_list", name: "Bullet List", category: "Format", icon: "󰁨", desc: "Prefix each line with Markdown bullet (- )" },
  { id: "markdown_table", name: "Markdown Table", category: "Format", icon: "󰅩", desc: "Convert CSV or TSV data into a Markdown table" }
];
var registry = TRANSFORMERS;

function getTransformers(category) {
  if (!category || category === "all" || category === "All") {
    return TRANSFORMERS;
  }
  return TRANSFORMERS.filter(function(t) {
    return t.category.toLowerCase() === category.toLowerCase();
  });
}

function wordsFromText(text) {
  var s = String(text || "");
  var words = s.match(/[A-Za-z0-9]+/g);
  return words || [];
}

var B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

function base64Encode(input) {
  var str = unescape(encodeURIComponent(String(input || "")));
  var output = "";
  var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
  var i = 0;
  while (i < str.length) {
    chr1 = str.charCodeAt(i++);
    chr2 = str.charCodeAt(i++);
    chr3 = str.charCodeAt(i++);
    enc1 = chr1 >> 2;
    enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
    enc3 = isNaN(chr2) ? 64 : (((chr2 & 15) << 2) | (chr3 >> 6));
    enc4 = isNaN(chr2) || isNaN(chr3) ? 64 : (chr3 & 63);
    output += B64_CHARS.charAt(enc1) + B64_CHARS.charAt(enc2) + B64_CHARS.charAt(enc3) + B64_CHARS.charAt(enc4);
  }
  return output;
}

function base64Decode(input) {
  var str = String(input || "").replace(/[^A-Za-z0-9\+\/\=]/g, "");
  var output = "";
  var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
  var i = 0;
  while (i < str.length) {
    enc1 = B64_CHARS.indexOf(str.charAt(i++));
    enc2 = B64_CHARS.indexOf(str.charAt(i++));
    enc3 = B64_CHARS.indexOf(str.charAt(i++));
    enc4 = B64_CHARS.indexOf(str.charAt(i++));
    chr1 = (enc1 << 2) | (enc2 >> 4);
    chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
    chr3 = ((enc3 & 3) << 6) | enc4;
    output += String.fromCharCode(chr1);
    if (enc3 !== 64 && enc3 !== -1) output += String.fromCharCode(chr2);
    if (enc4 !== 64 && enc4 !== -1) output += String.fromCharCode(chr3);
  }
  try {
    return decodeURIComponent(escape(output));
  } catch (e) {
    return output;
  }
}

function transform(text, transformerId) {
  var s = String(text || "");
  if (!s) return "";

  switch (transformerId) {
    case "uppercase":
      return s.toUpperCase();

    case "lowercase":
      return s.toLowerCase();

    case "titlecase":
      return s.replace(/\w\S*/g, function(txt) {
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });

    case "camelcase": {
      var wCamel = wordsFromText(s);
      if (wCamel.length === 0) return s;
      return wCamel.map(function(word, idx) {
        var lower = word.toLowerCase();
        if (idx === 0) return lower;
        return lower.charAt(0).toUpperCase() + lower.slice(1);
      }).join("");
    }

    case "pascalcase": {
      var wPascal = wordsFromText(s);
      if (wPascal.length === 0) return s;
      return wPascal.map(function(word) {
        var lower = word.toLowerCase();
        return lower.charAt(0).toUpperCase() + lower.slice(1);
      }).join("");
    }

    case "snakecase": {
      var wSnake = wordsFromText(s);
      if (wSnake.length === 0) return s;
      return wSnake.map(function(w) { return w.toLowerCase(); }).join("_");
    }

    case "kebabcase": {
      var wKebab = wordsFromText(s);
      if (wKebab.length === 0) return s;
      return wKebab.map(function(w) { return w.toLowerCase(); }).join("-");
    }

    case "constantcase": {
      var wConst = wordsFromText(s);
      if (wConst.length === 0) return s;
      return wConst.map(function(w) { return w.toUpperCase(); }).join("_");
    }

    case "json_pretty": {
      try {
        var parsed = JSON.parse(s);
        return JSON.stringify(parsed, null, 2);
      } catch (e) {
        return "/* Error: Invalid JSON input (" + e.message + ") */\n" + s;
      }
    }

    case "json_minify": {
      try {
        var parsedMin = JSON.parse(s);
        return JSON.stringify(parsedMin);
      } catch (e) {
        return "/* Error: Invalid JSON input (" + e.message + ") */\n" + s;
      }
    }
    case "base64_encode": {
      return base64Encode(s);
    }

    case "base64_decode": {
      try {
        return base64Decode(s);
      } catch (e) {
        return "/* Error: Invalid Base64 input */\n" + s;
      }
    }

    case "url_encode":
      return encodeURIComponent(s);

    case "url_decode": {
      try { return decodeURIComponent(s); } catch (e) { return s; }
    }

    case "html_encode":
      return s.replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;")
              .replace(/'/g, "&#39;");

    case "html_decode":
      return s.replace(/&amp;/g, "&")
              .replace(/&lt;/g, "<")
              .replace(/&gt;/g, ">")
              .replace(/&quot;/g, "\"")
              .replace(/&#39;/g, "'")
              .replace(/&apos;/g, "'");

    case "escape_string":
      return JSON.stringify(s).slice(1, -1);

    case "unescape_string": {
      try {
        return JSON.parse('"' + s.replace(/"/g, '\\"') + '"');
      } catch (e) {
        return s.replace(/\\n/g, "\n")
                .replace(/\\t/g, "\t")
                .replace(/\\r/g, "\r")
                .replace(/\\"/g, '"')
                .replace(/\\\\/g, "\\");
      }
    }

    case "trim_all": {
      var linesTrim = s.split(/\r?\n/);
      return linesTrim.map(function(l) { return l.trim(); }).join("\n");
    }

    case "remove_blank_lines": {
      var linesBlank = s.split(/\r?\n/);
      return linesBlank.filter(function(l) { return l.trim() !== ""; }).join("\n");
    }

    case "deduplicate_lines": {
      var linesDedup = s.split(/\r?\n/);
      var seen = {};
      var out = [];
      for (var i = 0; i < linesDedup.length; i++) {
        var line = linesDedup[i];
        if (!seen[line]) {
          seen[line] = true;
          out.push(line);
        }
      }
      return out.join("\n");
    }

    case "sort_lines_asc": {
      var linesAsc = s.split(/\r?\n/);
      return linesAsc.sort(function(a, b) {
        return a.localeCompare(b);
      }).join("\n");
    }

    case "sort_lines_desc": {
      var linesDesc = s.split(/\r?\n/);
      return linesDesc.sort(function(a, b) {
        return b.localeCompare(a);
      }).join("\n");
    }

    case "add_line_numbers": {
      var linesNum = s.split(/\r?\n/);
      var padLen = String(linesNum.length).length;
      return linesNum.map(function(line, idx) {
        var n = String(idx + 1);
        while (n.length < padLen) n = " " + n;
        return n + ". " + line;
      }).join("\n");
    }

    case "bullet_list": {
      var linesBullet = s.split(/\r?\n/);
      return linesBullet.map(function(line) {
        if (!line.trim()) return "";
        return "- " + line.trim();
      }).join("\n");
    }

    case "markdown_table": {
      var rawLines = s.split(/\r?\n/).filter(function(l) { return l.trim() !== ""; });
      if (rawLines.length === 0) return s;

      var delimiter = "\t";
      if (rawLines[0].indexOf("\t") < 0 && rawLines[0].indexOf(",") >= 0) {
        delimiter = ",";
      }

      var rows = rawLines.map(function(l) {
        return l.split(delimiter).map(function(c) { return c.trim(); });
      });

      var colCount = 0;
      for (var r = 0; r < rows.length; r++) {
        colCount = Math.max(colCount, rows[r].length);
      }

      if (colCount === 0) return s;

      var header = "| " + rows[0].join(" | ") + " |";
      var divider = "| " + Array(colCount).fill("---").join(" | ") + " |";
      var body = rows.slice(1).map(function(row) {
        while (row.length < colCount) row.push("");
        return "| " + row.join(" | ") + " |";
      }).join("\n");

      return header + "\n" + divider + (body ? "\n" + body : "");
    }

    default:
      return s;
  }
}
