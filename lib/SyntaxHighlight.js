var rules = {
  javascript: [
    { pattern: /(\/\/.*$)/gm, cls: "cmt" },
    { pattern: /(\/\*[\s\S]*?\*\/)/g, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)/g, cls: "str" },
    { pattern: /\b(const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|this|class|extends|import|export|from|default|async|await|try|catch|finally|throw|typeof|instanceof|void|delete|in|of|yield|null|undefined|true|false)\b/g, cls: "kw" },
    { pattern: /\b(\d+\.?\d*([eE][+-]?\d+)?)\b/g, cls: "num" },
    { pattern: /\b([A-Z][a-zA-Z0-9_]*)\b/g, cls: "typ" },
    { pattern: /\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*(?=\()/g, cls: "fn" }
  ],
  typescript: [
    { pattern: /(\/\/.*$)/gm, cls: "cmt" },
    { pattern: /(\/\*[\s\S]*?\*\/)/g, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)/g, cls: "str" },
    { pattern: /\b(const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|this|class|extends|import|export|from|default|async|await|try|catch|finally|throw|typeof|instanceof|void|in|of|yield|null|undefined|true|false|type|interface|enum|implements|abstract|readonly|private|protected|public|static|as|is|keyof|infer|never|unknown|any|string|number|boolean|symbol|bigint|object)\b/g, cls: "kw" },
    { pattern: /\b(\d+\.?\d*([eE][+-]?\d+)?)\b/g, cls: "num" },
    { pattern: /\b([A-Z][a-zA-Z0-9_]*)\b/g, cls: "typ" },
    { pattern: /\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*(?=\()/g, cls: "fn" }
  ],
  python: [
    { pattern: /(#.*$)/gm, cls: "cmt" },
    { pattern: /("""[\s\S]*?"""|'''[\s\S]*?'''|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|f"(?:[^"\\]|\\.)*"|f'(?:[^'\\]|\\.)*')/g, cls: "str" },
    { pattern: /\b(def|class|return|if|elif|else|for|while|break|continue|pass|import|from|as|with|try|except|finally|raise|yield|lambda|and|or|not|in|is|None|True|False|global|nonlocal|del|assert|async|await|self|cls)\b/g, cls: "kw" },
    { pattern: /\b(\d+\.?\d*([eE][+-]?\d+)?j?)\b/g, cls: "num" },
    { pattern: /\b([A-Z][a-zA-Z0-9_]*)\b/g, cls: "typ" },
    { pattern: /\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()/g, cls: "fn" }
  ],
  rust: [
    { pattern: /(\/\/.*$)/gm, cls: "cmt" },
    { pattern: /(\/\*[\s\S]*?\*\/)/g, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*")/g, cls: "str" },
    { pattern: /\b(fn|let|mut|const|static|struct|enum|impl|trait|type|use|pub|mod|crate|self|super|where|match|if|else|for|while|loop|break|continue|return|move|ref|async|await|dyn|as|in|ref|unsafe|extern)\b/g, cls: "kw" },
    { pattern: /\b(self|true|false|Some|None|Ok|Err)\b/g, cls: "val" },
    { pattern: /\b(i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Option|Result|Box|Rc|Arc|HashMap|HashSet|BTreeMap|BTreeSet)\b/g, cls: "typ" },
    { pattern: /\b(\d+\.?\d*([eE][+-]?\d+)?[fFuUiIuUsSz]*)\b/g, cls: "num" },
    { pattern: /\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()/g, cls: "fn" }
  ],
  go: [
    { pattern: /(\/\/.*$)/gm, cls: "cmt" },
    { pattern: /(\/\*[\s\S]*?\*\/)/g, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*"|`[^`]*`)/g, cls: "str" },
    { pattern: /\b(package|import|func|return|if|else|for|range|switch|case|default|break|continue|go|defer|select|chan|var|const|type|struct|interface|map|make|new|append|len|cap|error|nil|true|false|iota)\b/g, cls: "kw" },
    { pattern: /\b(\d+\.?\d*([eE][+-]?\d+)?)\b/g, cls: "num" },
    { pattern: /\b([A-Z][a-zA-Z0-9_]*)\b/g, cls: "typ" },
    { pattern: /\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()/g, cls: "fn" }
  ],
  sql: [
    { pattern: /(--.*$)/gm, cls: "cmt" },
    { pattern: /(\/\*[\s\S]*?\*\/)/g, cls: "cmt" },
    { pattern: /('(?:[^'\\]|\\.)*')/g, cls: "str" },
    { pattern: /\b(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|DROP|ALTER|TABLE|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|EXISTS|BETWEEN|LIKE|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|AS|DISTINCT|COUNT|SUM|AVG|MIN|MAX|UNION|ALL|ANY|NULL|IS|TRUE|FALSE|PRIMARY|KEY|FOREIGN|REFERENCES|CONSTRAINT|DEFAULT|CHECK|BEGIN|COMMIT|ROLLBACK|TRANSACTION|GRANT|REVOKE|IF|ELSE|THEN|END|CASE|WHEN|DECLARE|CURSOR|FETCH|OPEN|CLOSE|INT|VARCHAR|TEXT|BOOLEAN|DATE|TIMESTAMP|INTEGER|FLOAT|DOUBLE|DECIMAL|BIGINT|SMALLINT|SERIAL)\b/g, cls: "kw" },
    { pattern: /\b(\d+\.?\d*)\b/g, cls: "num" }
  ],
  html: [
    { pattern: /(<!--[\s\S]*?-->)/g, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/g, cls: "str" },
    { pattern: /(&lt;\/?)([\w-]+)/g, cls: "tag", group: 2 },
    { pattern: /\b([\w-]+)(?==)/g, cls: "attr" }
  ],
  css: [
    { pattern: /(\/\*[\s\S]*?\*\/)/g, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/g, cls: "str" },
    { pattern: /(#[0-9a-fA-F]{3,8})\b/g, cls: "num" },
    { pattern: /\b(\d+\.?\d*(px|em|rem|%|vh|vw|s|ms)?)\b/g, cls: "num" },
    { pattern: /([.#][a-zA-Z_][\w-]*)/g, cls: "fn" },
    { pattern: /\b(color|background|margin|padding|border|display|flex|grid|position|font|width|height|top|left|right|bottom|z-index|opacity|transition|transform|animation|overflow|cursor|content|align|justify|gap)\b/g, cls: "kw" }
  ],
  shell: [
    { pattern: /(#.*$)/gm, cls: "cmt" },
    { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/g, cls: "str" },
    { pattern: /\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|exit|local|export|source|echo|printf|read|cd|ls|grep|sed|awk|find|cat|mkdir|rm|cp|mv|chmod|chown|sudo|apt|pacman|yay|npm|cargo|git|docker|curl|wget)\b/g, cls: "kw" },
    { pattern: /(\$[\w{][\w}]*)/g, cls: "var" }
  ]
}

var colorMap = {
  cmt: "#6a9955",
  str: "#ce9178",
  kw:  "#569cd6",
  num: "#b5cea8",
  typ: "#4ec9b0",
  fn:  "#dcdcaa",
  val: "#569cd6",
  tag: "#569cd6",
  attr: "#9cdcfe",
  var: "#9cdcfe"
}

var langAliases = {
  js: "javascript", jsx: "javascript", mjs: "javascript",
  ts: "typescript", tsx: "typescript", mts: "typescript",
  py: "python", py3: "python",
  rs: "rust",
  go: "go",
  sh: "shell", bash: "shell", zsh: "shell",
  htm: "html", xml: "html",
  json: "javascript", jsonc: "javascript",
  yaml: "shell", yml: "shell", toml: "shell",
  c: "rust", cpp: "rust", h: "rust", hpp: "rust"
}

function resolveLang(lang) {
  var l = String(lang || "").toLowerCase().trim()
  if (langAliases[l]) return langAliases[l]
  if (rules[l]) return l
  return ""
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

// QML Text with RichText does not interpret raw "\n" as a break; it must be
// <br/>. Replace newlines in the plain segments and the highlighted spans.
function br(text) {
  return String(text).replace(/\n/g, "<br/>")
}

function highlight(code, lang) {
  var resolved = resolveLang(lang)
  if (!resolved) return escapeHtml(code)

  var langRules = rules[resolved]
  if (!langRules) return escapeHtml(code)

  var tokens = []
  var plainSpans = []

  for (var r = 0; r < langRules.length; r++) {
    var rule = langRules[r]
    var re = new RegExp(rule.pattern.source, rule.pattern.flags)
    var m
    while ((m = re.exec(code)) !== null) {
      var text = m[0]
      var start = m.index
      var color = colorMap[rule.cls] || "#d4d4d4"
      tokens.push({ start: start, len: text.length, color: color, text: text })
    }
  }

  tokens.sort(function(a, b) { return a.start - b.start })

  var merged = []
  for (var i = 0; i < tokens.length; i++) {
    var t = tokens[i]
    if (merged.length > 0) {
      var last = merged[merged.length - 1]
      if (t.start < last.start + last.len) continue
    }
    merged.push(t)
  }

  var result = ""
  var pos = 0
  for (var j = 0; j < merged.length; j++) {
    var tk = merged[j]
    if (tk.start > pos) result += br(escapeHtml(code.slice(pos, tk.start)))
    result += '<span style="color:' + tk.color + '">' + br(escapeHtml(tk.text)) + '</span>'
    pos = tk.start + tk.len
  }
  if (pos < code.length) result += br(escapeHtml(code.slice(pos)))

  return result
}

if (typeof module !== "undefined") {
  module.exports = { highlight: highlight, resolveLang: resolveLang }
}
