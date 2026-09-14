import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  visible: false
  anchors.fill: parent
  color: Util.alpha(Color.popups.background || Color.background || "#1e1e2e", 0.98)
  radius: Style.cornerRadius
  z: 120
  clip: true

  // Signals
  signal closed()
  signal copiedText(string text)
  signal feedbackShown(string msg)
  signal requestScreenPick(string target)
  signal requestColorPicker(string target, string currentColor)
  signal requestOcr(string path)

  // Unified Studio Mode: 0 = Generator, 1 = Decoder
  // Modular Component Aliases
  property alias qrImage: previewPane.qrImage
  property alias qrTextInput: textTab.qrTextInput
  property alias themePresetsDropdownBtn: propertiesTab.themePresetsDropdownBtn
  property alias logoPresetsDropdownBtn: propertiesTab.logoPresetsDropdownBtn
  property alias logoPathInput: propertiesTab.logoPathInput

  property int activeMode: 0

  // Decoder Properties
  property string decodeImagePath: ""
  property string decodedText: ""
  property bool isDecoding: false
  property bool decodeSuccess: false
  property string decodedFormat: "text" // "url", "wifi", "text"
  property bool isConnectingWifi: false
  property string wifiConnectedSsid: ""

  // QR Settings & Customization Properties
  property string textToEncode: ""
  property string eccLevel: "M"
  property string qrFgColor: "#000000"
  property string qrBgColor: "#FFFFFF"
  property string qrOuterEyeColor: "#000000"
  property string qrInnerEyeColor: "#000000"
  property string qrTimingColor: "#000000"
  property string qrAlignmentColor: "#000000"

  // Gradient & Frame Properties
  property string gradientType: "none" // "none", "linear_horizontal", "linear_vertical", "linear_diagonal", "radial"
  property string gradientColor: "#00F0FF"
  property string frameStyle: "none"   // "none", "bottom_banner", "top_banner", "framed_card"
  property string frameText: "SCAN ME"
  property string frameColor: ""
  property string frameTextColor: "#FFFFFF"

  // Live Scannability & Contrast Properties
  property real contrastRatio: 21.0
  property string contrastRating: "AAA"
  property string contrastColor: "#10B981"
  property bool isVerifiedScannable: true

  // Smart Payload Builder Properties
  property string payloadType: "text" // "text", "url", "wifi", "vcard", "email", "sms"
  property bool isSyncingPayload: false

  // Wi-Fi
  property string wifiSsid: ""
  property string wifiPassword: ""
  property string wifiEnc: "WPA" // "WPA", "WEP", "nopass"
  property bool wifiHidden: false
  property bool wifiShowPass: false

  // vCard
  property string vcardFirstName: ""
  property string vcardLastName: ""
  property string vcardPhone: ""
  property string vcardEmail: ""
  property string vcardOrg: ""
  property string vcardTitle: ""
  property string vcardUrl: ""

  // URL
  property string urlProtocol: "https://"
  property string urlHost: ""
  property string urlUtmSource: ""
  property string urlUtmMedium: ""
  property string urlUtmCampaign: ""

  // Email
  property string emailTo: ""
  property string emailSubject: ""
  property string emailBody: ""

  // SMS
  property string smsPhone: ""
  property string smsMessage: ""

  // Geo Location Coordinates
  property string geoLat: ""
  property string geoLon: ""
  property string geoQuery: ""

  // Calendar Event (VEVENT)
  property string eventTitle: ""
  property string eventLocation: ""
  property string eventDescription: ""
  property string eventStart: ""
  property string eventEnd: ""

  // Export Resolution (600 = Screen, 2400 = Print 300 DPI)
  property int exportResolution: 600

  // Inverted Detection & Physical Compatibility Warning
  property bool isQrInverted: false

  // Dropdown States
  property bool copyDropdownOpen: false
  property bool saveDropdownOpen: false
  property bool themePresetsDropdownOpen: false
  property bool logoPresetsDropdownOpen: false
  property string activeThemePresetName: "Omarchy"

  readonly property string currentLogoIcon: {
    if (root.customLogoPath.length > 0) return "🖼"
    for (var i = 0; i < root.logoPresetList.length; i++) {
      if (root.logoPresetList[i].id === root.logoPreset) {
        return root.logoPresetList[i].icon
      }
    }
    return "✕"
  }

  readonly property string currentLogoLabel: {
    if (root.customLogoPath.length > 0) {
      var parts = root.customLogoPath.split("/")
      return parts[parts.length - 1] || "Custom Logo"
    }
    for (var i = 0; i < root.logoPresetList.length; i++) {
      if (root.logoPresetList[i].id === root.logoPreset) {
        return root.logoPresetList[i].label
      }
    }
    return "None"
  }

  // Multi-Part Series & Carousel States
  property int currentSeriesIndex: 1
  property int totalSeriesParts: 1
  property bool isSeriesMode: false
  property bool seriesAutoPlay: false
  property int seriesChunkSize: 600
  property bool seriesAutoSplit: true
  property var seriesParts: []
  readonly property string currentPartImgPath: (root.isSeriesMode && root.totalSeriesParts > 1) ? (root.stateDir + "/reclip-qr-part-" + root.currentSeriesIndex + ".png") : root.qrImgPath
  readonly property string currentPartSvgPath: (root.isSeriesMode && root.totalSeriesParts > 1) ? (root.stateDir + "/reclip-qr-part-" + root.currentSeriesIndex + ".svg") : root.qrSvgPath

  // Decoder Multi-Part Stream Buffering
  property bool isDecodedSeries: false
  property int decodedSeriesPart: 1
  property int decodedSeriesTotal: 1
  property var decodedSeriesBuffer: ({})
  property int decodedSeriesCount: 0
  property string assembledSeriesText: ""

  // Local Wi-Fi File Drop State
  property string fileShareScript: root.pluginDir + "/lib/qr_file_server.py"
  property string filePickerScript: root.pluginDir + "/lib/qr_file_picker.py"
  property var fileShareList: []
  property var fileShareMeta: []
  property string fileSharePath: ""
  property string fileShareName: ""
  property string fileShareSizeStr: ""
  property string fileShareUrl: ""
  property string fileShareIp: ""
  property int fileSharePort: 0
  property int fileShareCount: 0
  property string fileShareTotalSizeStr: ""
  property bool fileShareRunning: false
  property bool fileShareSingleShot: false
  property string fileShareStatus: "idle" // "idle", "starting", "serving", "downloading", "completed", "error"
  property string fileShareStatusMsg: ""
  property string fileShareClientIp: ""
  property real fileShareProgress: 0.0
  property string fileShareSpeedStr: ""
  property string fileShareEtaStr: ""
  property bool fileShareTransferring: false
  property string fileShareTransferType: ""
  property string fileShareTransferFile: ""
  property string fileSharePin: ""
  property string fileShareToken: ""
  property bool isPickingFiles: false

  property string moduleShape: "square" // "square", "rounded", "dot", "fluid"
  property string eyeShape: "square"    // "square", "rounded", "circle", "squircle"
  property int qrVersion: 0             // 0 = Auto, 1..40
  property int quietZone: 1             // 0, 1, 2, 4
  property string logoPreset: "none"    // "none", "omarchy", "arch", "github", "terminal", "code", "wifi", "link", "phone", "email", "lock", "cart", "crypto", "location", "star", "heart", "custom"
  property string customLogoPath: ""
  property string logoShape: "rounded"  // "rounded", "circle", "square", "floating"
  property real logoSize: 0.22          // 0.16, 0.22, 0.28, 0.32
  property string logoBgColor: "#FFFFFF"
  property string logoBorderColor: ""
  property int logoBorderWidth: 2       // 0, 1, 2, 4
  property real logoPadding: 0.70       // 0.80 (tight), 0.60 (spacious)
  property string logoTintColor: ""
  property string activeLogoCat: "all"  // "all", "dev", "comm", "life", "custom"
  property string frameSubtext: ""
  property int frameRadius: 0           // 0, 14
  property bool hasFavoriteStyle: false

  property string activeColorTarget: "fg"
  property int activeSectionTab: 0      // 0: Texts, 1: Files & Folders, 2: Properties
  property int activeControlTab: 0      // 0: Colors, 1: Shapes, 2: Version, 3: Logo
  property int activeLogoSubTab: 0      // 0: Logo & Presets, 1: Badge & Shape, 2: Colors & Tint
  property string stateDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  property string qrImgPath: root.stateDir + "/reclip-qr-display.png"
  property string qrSvgPath: root.stateDir + "/reclip-qr-display.svg"
  property string home: Quickshell.env("HOME") || ""
  property string pluginDir: root.home + "/.config/omarchy/plugins/reclip"
  property string stylerScript: root.pluginDir + "/lib/qr_styler.py"

  property string feedbackMsg: ""
  property string generationError: ""
  property bool isGenerating: false
  property bool isBatchUpdating: false
  property bool pendingGeneration: false
  property int detectedVersion: 1
  property int matrixSize: 21
  property int totalModules: 441

  readonly property var themePresets: [
    {
      name: "Omarchy",
      fg: Color.accent || "#38BDF8",
      bg: Util.alpha(Color.popups.background || "#181825", 1.0),
      outerEye: Color.accent || "#38BDF8",
      innerEye: "#FFFFFF",
      timing: Color.accent || "#38BDF8",
      alignment: Color.accent || "#38BDF8",
      gradient: "none",
      gradientColor: "#38BDF8",
      frameStyle: "none"
    },
    {
      name: "Classic",
      fg: "#000000",
      bg: "#FFFFFF",
      outerEye: "#000000",
      innerEye: "#000000",
      timing: "#000000",
      alignment: "#000000",
      gradient: "none",
      gradientColor: "#000000",
      frameStyle: "none"
    },
    {
      name: "Inverted",
      fg: "#FFFFFF",
      bg: "#11111B",
      outerEye: "#FFFFFF",
      innerEye: "#FFFFFF",
      timing: "#FFFFFF",
      alignment: "#FFFFFF",
      gradient: "none",
      gradientColor: "#FFFFFF",
      frameStyle: "none"
    },
    {
      name: "Catppuccin",
      fg: "#CBA6F7",
      bg: "#1E1E2E",
      outerEye: "#F38BA8",
      innerEye: "#89B4FA",
      timing: "#A6ADC8",
      alignment: "#F9E2AF",
      gradient: "linear_diagonal",
      gradientColor: "#89B4FA",
      frameStyle: "none"
    },
    {
      name: "Tokyo Night",
      fg: "#7AA2F7",
      bg: "#1A1B26",
      outerEye: "#BB9AF7",
      innerEye: "#7DCFFF",
      timing: "#565F89",
      alignment: "#9ECE6A",
      gradient: "linear_horizontal",
      gradientColor: "#BB9AF7",
      frameStyle: "none"
    },
    {
      name: "Nord Frost",
      fg: "#88C0D0",
      bg: "#2E3440",
      outerEye: "#81A1C1",
      innerEye: "#ECEFF4",
      timing: "#4C566A",
      alignment: "#8FBCBB",
      gradient: "linear_vertical",
      gradientColor: "#5E81AC",
      frameStyle: "none"
    },
    {
      name: "Cyberpunk",
      fg: "#00F0FF",
      bg: "#0D0221",
      outerEye: "#FF007F",
      innerEye: "#FFE600",
      timing: "#FF007F",
      alignment: "#00F0FF",
      gradient: "linear_diagonal",
      gradientColor: "#FF007F",
      frameStyle: "bottom_banner"
    },
    {
      name: "Emerald",
      fg: "#10B981",
      bg: "#022C22",
      outerEye: "#34D399",
      innerEye: "#A7F3D0",
      timing: "#059669",
      alignment: "#6EE7B7",
      gradient: "radial",
      gradientColor: "#34D399",
      frameStyle: "none"
    }
  ]

  function applyThemePreset(preset) {
    root.isBatchUpdating = true
    root.activeThemePresetName = preset.name
    root.qrFgColor = preset.fg
    root.qrBgColor = preset.bg
    root.qrOuterEyeColor = preset.outerEye
    root.qrInnerEyeColor = preset.innerEye
    root.qrTimingColor = preset.timing
    root.qrAlignmentColor = preset.alignment
    root.gradientType = preset.gradient
    if (preset.gradientColor) root.gradientColor = preset.gradientColor
    if (preset.frameStyle) root.frameStyle = preset.frameStyle
    root.isBatchUpdating = false
    root.showFeedback("Preset: " + preset.name)
    root.requestGenerateQr()
  }

  function applyThemePresetByName(name) {
    if (!name) return
    var target = String(name).toLowerCase()
    for (var i = 0; i < root.themePresets.length; i++) {
      if (root.themePresets[i].name.toLowerCase() === target) {
        applyThemePreset(root.themePresets[i])
        break
      }
    }
  }

  readonly property var logoPresetList: [
    { id: "none", icon: "✕", label: "None", cat: "system" },
    { id: "omarchy", icon: "󰣇", label: "Omarchy", cat: "dev" },
    { id: "arch", icon: "󰣇", label: "Arch", cat: "dev" },
    { id: "github", icon: "󰊤", label: "GitHub", cat: "dev" },
    { id: "terminal", icon: "󰞷", label: "Term", cat: "dev" },
    { id: "code", icon: "󰅩", label: "Code", cat: "dev" },
    { id: "wifi", icon: "󰖩", label: "Wi-Fi", cat: "comm" },
    { id: "link", icon: "󰌹", label: "Link", cat: "comm" },
    { id: "phone", icon: "󰏲", label: "Phone", cat: "comm" },
    { id: "email", icon: "󰇮", label: "Email", cat: "comm" },
    { id: "lock", icon: "󰌾", label: "Lock", cat: "comm" },
    { id: "cart", icon: "󰄳", label: "Cart", cat: "life" },
    { id: "crypto", icon: "󰠠", label: "Crypto", cat: "life" },
    { id: "location", icon: "󰍎", label: "Pin", cat: "life" },
    { id: "star", icon: "󰓎", label: "Star", cat: "life" },
    { id: "heart", icon: "󰋑", label: "Heart", cat: "life" },
    { id: "custom", icon: "🖼", label: "Custom", cat: "custom" }
  ]

  function saveUserStyle() {
    var styleObj = {
      fg: root.qrFgColor,
      bg: root.qrBgColor,
      outerEye: root.qrOuterEyeColor,
      innerEye: root.qrInnerEyeColor,
      timing: root.qrTimingColor,
      alignment: root.qrAlignmentColor,
      gradient: root.gradientType,
      gradientColor: root.gradientColor,
      moduleShape: root.moduleShape,
      eyeShape: root.eyeShape,
      frameStyle: root.frameStyle,
      frameText: root.frameText,
      frameSubtext: root.frameSubtext,
      frameRadius: root.frameRadius,
      frameColor: root.frameColor,
      logoPreset: root.logoPreset,
      logoShape: root.logoShape,
      logoSize: root.logoSize,
      logoBgColor: root.logoBgColor,
      logoBorderColor: root.logoBorderColor,
      logoBorderWidth: root.logoBorderWidth,
      logoPadding: root.logoPadding,
      customLogoPath: root.customLogoPath
    }
    var jsonStr = JSON.stringify(styleObj, null, 2)
    saveStyleProc.command = [
      "python3",
      "-c",
      "import sys, os; p = sys.argv[1]; os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='utf-8').write(sys.argv[2])",
      root.pluginDir + "/user-style.json",
      jsonStr
    ]
    saveStyleProc.running = true
  }

  function loadUserStyle() {
    loadStyleProc.command = ["cat", root.pluginDir + "/user-style.json"]
    loadStyleProc.running = true
  }

  function parseHexColor(hexStr) {
    var c = String(hexStr || "").trim().toLowerCase()
    if (c === "transparent" || c === "#00000000" || c === "") return [255, 255, 255]
    if (c.startsWith("#")) c = c.slice(1)
    if (c.length === 3) {
      return [
        parseInt(c[0] + c[0], 16),
        parseInt(c[1] + c[1], 16),
        parseInt(c[2] + c[2], 16)
      ]
    }
    if (c.length >= 6) {
      return [
        parseInt(c.slice(0, 2), 16),
        parseInt(c.slice(2, 4), 16),
        parseInt(c.slice(4, 6), 16)
      ]
    }
    return [0, 0, 0]
  }

  function sRgbLuminance(rgb) {
    var r = rgb[0] / 255.0
    var g = rgb[1] / 255.0
    var b = rgb[2] / 255.0
    var rLin = r <= 0.03928 ? r / 12.92 : Math.pow((r + 0.055) / 1.055, 2.4)
    var gLin = g <= 0.03928 ? g / 12.92 : Math.pow((g + 0.055) / 1.055, 2.4)
    var bLin = b <= 0.03928 ? b / 12.92 : Math.pow((b + 0.055) / 1.055, 2.4)
    return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
  }

  function updateContrastRatio() {
    var fgRgb = root.parseHexColor(root.qrFgColor)
    var bgRgb = root.parseHexColor(root.qrBgColor)
    var l1 = root.sRgbLuminance(fgRgb)
    var l2 = root.sRgbLuminance(bgRgb)
    var maxL = Math.max(l1, l2)
    var minL = Math.min(l1, l2)
    var ratio = (maxL + 0.05) / (minL + 0.05)
    root.contrastRatio = Math.round(ratio * 10) / 10.0
    root.isQrInverted = (l1 > l2)

    if (ratio >= 7.0) {
      root.contrastRating = "AAA"
      root.contrastColor = "#10B981"
    } else if (ratio >= 4.5) {
      root.contrastRating = "AA"
      root.contrastColor = "#3B82F6"
    } else if (ratio >= 3.0) {
      root.contrastRating = "AA Large"
      root.contrastColor = "#F59E0B"
    } else {
      root.contrastRating = "Low"
      root.contrastColor = "#EF4444"
    }
  }

  function parseAndPopulatePayload(raw) {
    var s = String(raw || "").trim()
    root.isSyncingPayload = true
    if (/^WIFI:/i.test(s)) {
      root.payloadType = "wifi"
      var tMatch = s.match(/T:([^;]*)/i)
      var sMatch = s.match(/S:([^;]*)/i)
      var pMatch = s.match(/P:([^;]*)/i)
      var hMatch = s.match(/H:([^;]*)/i)
      root.wifiEnc = tMatch ? tMatch[1] : "WPA"
      root.wifiSsid = sMatch ? sMatch[1].replace(/\\([\\;,":])/g, "$1") : ""
      root.wifiPassword = pMatch ? pMatch[1].replace(/\\([\\;,":])/g, "$1") : ""
      root.wifiHidden = hMatch ? (hMatch[1].toLowerCase() === "true") : false
    } else if (/^BEGIN:VCARD/i.test(s)) {
      root.payloadType = "vcard"
      var fnM = s.match(/FN:([^\r\n]+)/i)
      var orgM = s.match(/ORG:([^\r\n]+)/i)
      var titleM = s.match(/TITLE:([^\r\n]+)/i)
      var telM = s.match(/TEL[^:]*:([^\r\n]+)/i)
      var emailM = s.match(/EMAIL[^:]*:([^\r\n]+)/i)
      var urlM = s.match(/URL[^:]*:([^\r\n]+)/i)
      var name = fnM ? fnM[1].trim() : ""
      var parts = name.split(" ")
      root.vcardFirstName = parts[0] || ""
      root.vcardLastName = parts.slice(1).join(" ") || ""
      root.vcardPhone = telM ? telM[1].trim() : ""
      root.vcardEmail = emailM ? emailM[1].trim() : ""
      root.vcardOrg = orgM ? orgM[1].trim() : ""
      root.vcardTitle = titleM ? titleM[1].trim() : ""
      root.vcardUrl = urlM ? urlM[1].trim() : ""
    } else if (/^geo:/i.test(s)) {
      root.payloadType = "geo"
      var g = s.slice(4)
      var qIdx = g.indexOf("?q=")
      if (qIdx >= 0) {
        var coords = g.slice(0, qIdx).split(",")
        root.geoLat = coords[0] ? coords[0].trim() : ""
        root.geoLon = coords[1] ? coords[1].trim() : ""
        root.geoQuery = decodeURIComponent(g.slice(qIdx + 3).trim())
      } else {
        var coords = g.split(",")
        root.geoLat = coords[0] ? coords[0].trim() : ""
        root.geoLon = coords[1] ? coords[1].trim() : ""
        root.geoQuery = ""
      }
    } else if (/BEGIN:(VEVENT|VCALENDAR)/i.test(s)) {
      root.payloadType = "event"
      var sumM = s.match(/SUMMARY:([^\r\n]+)/i)
      var locM = s.match(/LOCATION:([^\r\n]+)/i)
      var descM = s.match(/DESCRIPTION:([^\r\n]+)/i)
      var dtstartM = s.match(/DTSTART:([^\r\n]+)/i)
      var dtendM = s.match(/DTEND:([^\r\n]+)/i)
      root.eventTitle = sumM ? sumM[1].trim() : ""
      root.eventLocation = locM ? locM[1].trim() : ""
      root.eventDescription = descM ? descM[1].trim() : ""
      root.eventStart = dtstartM ? dtstartM[1].trim() : ""
      root.eventEnd = dtendM ? dtendM[1].trim() : ""
    } else if (/^mailto:/i.test(s)) {
      root.payloadType = "email"
      var m = s.slice(7)
      var qIdx = m.indexOf("?")
      if (qIdx >= 0) {
        root.emailTo = m.slice(0, qIdx)
        var qs = m.slice(qIdx + 1)
        var subM = qs.match(/subject=([^&]*)/i)
        var bodyM = qs.match(/body=([^&]*)/i)
        root.emailSubject = subM ? decodeURIComponent(subM[1]) : ""
        root.emailBody = bodyM ? decodeURIComponent(bodyM[1]) : ""
      } else {
        root.emailTo = m
        root.emailSubject = ""
        root.emailBody = ""
      }
    } else if (/^(smsto|sms):/i.test(s)) {
      root.payloadType = "sms"
      var smsParts = s.split(":")
      if (smsParts.length >= 3) {
        root.smsPhone = smsParts[1]
        root.smsMessage = smsParts.slice(2).join(":")
      } else if (smsParts.length === 2) {
        root.smsPhone = smsParts[1]
        root.smsMessage = ""
      }
    } else if (/^https?:\/\//i.test(s)) {
      root.payloadType = "url"
      root.urlProtocol = s.startsWith("http://") ? "http://" : "https://"
      root.urlHost = s.replace(/^https?:\/\//i, "")
      root.urlUtmSource = ""
      root.urlUtmMedium = ""
      root.urlUtmCampaign = ""
    } else {
      root.payloadType = "text"
      if (qrTextInput) qrTextInput.text = s
    }
    root.isSyncingPayload = false
  }

  function updatePayloadText() {
    if (root.isSyncingPayload) return
    root.isSyncingPayload = true

    var result = ""
    if (root.payloadType === "text") {
      result = (qrTextInput ? qrTextInput.text : root.textToEncode)
    } else if (root.payloadType === "file") {
      result = root.fileShareUrl
    } else if (root.payloadType === "url") {
      var h = root.urlHost.trim()
      if (h.length > 0) {
        if (!h.startsWith("http://") && !h.startsWith("https://")) {
          result = root.urlProtocol + h
        } else {
          result = h
        }
        var utm = []
        if (root.urlUtmSource.trim()) utm.push("utm_source=" + encodeURIComponent(root.urlUtmSource.trim()))
        if (root.urlUtmMedium.trim()) utm.push("utm_medium=" + encodeURIComponent(root.urlUtmMedium.trim()))
        if (root.urlUtmCampaign.trim()) utm.push("utm_campaign=" + encodeURIComponent(root.urlUtmCampaign.trim()))
        if (utm.length > 0) {
          result += (result.indexOf("?") >= 0 ? "&" : "?") + utm.join("&")
        }
      }
    } else if (root.payloadType === "wifi") {
      var ssid = root.wifiSsid.trim()
      if (ssid.length > 0) {
        var escS = ssid.replace(/([\\;,":])/g, "\\$1")
        var escP = root.wifiPassword.replace(/([\\;,":])/g, "\\$1")
        result = "WIFI:T:" + root.wifiEnc + ";S:" + escS + ";P:" + escP + ";H:" + (root.wifiHidden ? "true" : "false") + ";;"
      }
    } else if (root.payloadType === "vcard") {
      var fn = (root.vcardFirstName.trim() + " " + root.vcardLastName.trim()).trim()
      if (fn.length > 0 || root.vcardOrg.trim().length > 0) {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        if (root.vcardLastName.trim() || root.vcardFirstName.trim()) {
          lines.push("N:" + root.vcardLastName.trim() + ";" + root.vcardFirstName.trim() + ";;;")
          lines.push("FN:" + fn)
        }
        if (root.vcardOrg.trim()) lines.push("ORG:" + root.vcardOrg.trim())
        if (root.vcardTitle.trim()) lines.push("TITLE:" + root.vcardTitle.trim())
        if (root.vcardPhone.trim()) lines.push("TEL;TYPE=CELL:" + root.vcardPhone.trim())
        if (root.vcardEmail.trim()) lines.push("EMAIL:" + root.vcardEmail.trim())
        if (root.vcardUrl.trim()) lines.push("URL:" + root.vcardUrl.trim())
        lines.push("END:VCARD")
        result = lines.join("\n")
      }
    } else if (root.payloadType === "email") {
      var to = root.emailTo.trim()
      if (to.length > 0) {
        result = "mailto:" + to
        var q = []
        if (root.emailSubject.trim()) q.push("subject=" + encodeURIComponent(root.emailSubject.trim()))
        if (root.emailBody.trim()) q.push("body=" + encodeURIComponent(root.emailBody.trim()))
        if (q.length > 0) result += "?" + q.join("&")
      }
    } else if (root.payloadType === "sms") {
      var ph = root.smsPhone.trim()
      if (ph.length > 0) {
        result = "smsto:" + ph + ":" + root.smsMessage
      }
    } else if (root.payloadType === "geo") {
      var lat = root.geoLat.trim()
      var lon = root.geoLon.trim()
      if (lat.length > 0 && lon.length > 0) {
        result = "geo:" + lat + "," + lon
        if (root.geoQuery.trim().length > 0) {
          result += "?q=" + encodeURIComponent(root.geoQuery.trim())
        }
      }
    } else if (root.payloadType === "event") {
      var evTitle = root.eventTitle.trim()
      if (evTitle.length > 0) {
        var evLines = [
          "BEGIN:VCALENDAR",
          "VERSION:2.0",
          "BEGIN:VEVENT",
          "SUMMARY:" + evTitle
        ]
        if (root.eventLocation.trim()) evLines.push("LOCATION:" + root.eventLocation.trim())
        if (root.eventDescription.trim()) evLines.push("DESCRIPTION:" + root.eventDescription.trim())
        if (root.eventStart.trim()) {
          var ds = root.eventStart.trim().replace(/[-: ]/g, "")
          if (ds.indexOf("T") === -1 && ds.length >= 8) ds += "T090000"
          evLines.push("DTSTART:" + ds)
        }
        if (root.eventEnd.trim()) {
          var de = root.eventEnd.trim().replace(/[-: ]/g, "")
          if (de.indexOf("T") === -1 && de.length >= 8) de += "T100000"
          evLines.push("DTEND:" + de)
        }
        evLines.push("END:VEVENT")
        evLines.push("END:VCALENDAR")
        result = evLines.join("\n")
      }
    }

    root.textToEncode = result
    if (root.payloadType === "text" && qrTextInput) {
      qrTextInput.text = result
    }
    root.isSyncingPayload = false
    qrDebounceTimer.restart()
  }

  function open(text) {
    root.activeMode = 0
    var raw = String(text || "")
    if (raw.trim().length > 0) {
      root.activeSectionTab = 0
      root.textToEncode = raw
      root.eccLevel = (root.logoPreset !== "none") ? "H" : "M"
      root.feedbackMsg = ""
      root.parseAndPopulatePayload(raw)
      root.generateQr()
    } else if (!root.textToEncode && root.fileShareList.length === 0) {
      root.activeSectionTab = 0
      qrImage.source = ""
    }
    root.visible = true
    Qt.callLater(function() {
      if (root.payloadType === "text" && qrTextInput) qrTextInput.forceActiveFocus()
    })
  }

  function openDecode(imagePath, precomputedText) {
    root.activeMode = 1
    root.clearFileShare()
    root.decodeImagePath = String(imagePath || "")
    var raw = String(precomputedText || "")
    if (raw.length > 0) {
      root.handleDecodedRaw(raw)
    } else {
      root.decodedText = ""
      root.decodeSuccess = false
    }
    root.feedbackMsg = ""
    root.visible = true
    if (!root.decodeSuccess && root.decodeImagePath) {
      root.runDecode()
    }
  }

  function openFileShare(pathsOrPath) {
    root.activeMode = 0
    root.activeSectionTab = 1
    root.payloadType = "file"
    root.feedbackMsg = ""
    root.visible = true
    if (pathsOrPath) {
      root.clearFileShare()
      root.addFileSharePaths(pathsOrPath)
    }
  }

  function browseFiles() {
    if (filePickProc.running) {
      filePickProc.running = false
    }
    root.isPickingFiles = true
    filePickProc.command = ["python3", root.filePickerScript]
    filePickProc.running = true
  }

  function browseFolder() {
    if (folderPickProc.running) {
      folderPickProc.running = false
    }
    root.isPickingFiles = true
    folderPickProc.command = ["python3", root.filePickerScript, "--directory"]
    folderPickProc.running = true
  }

  function addFileSharePaths(pathsInput) {
    if (!pathsInput) return
    var items = []
    if (Array.isArray(pathsInput)) {
      items = pathsInput
    } else if (typeof pathsInput === "string") {
      items = pathsInput.split("\n")
    }
    var current = root.fileShareList ? root.fileShareList.slice(0) : []
    var addedCount = 0
    for (var i = 0; i < items.length; i++) {
      var p = String(items[i] || "").trim()
      if (p.startsWith("file://")) {
        p = decodeURIComponent(p.substring(7))
      }
      if (p.length > 0 && current.indexOf(p) === -1) {
        current.push(p)
        addedCount++
      }
    }
    if (addedCount > 0 || !root.fileShareRunning) {
      root.fileShareList = current
      root.startFileShareList(current)
    }
  }

  function removeFileSharePath(index) {
    var current = root.fileShareList ? root.fileShareList.slice(0) : []
    if (index >= 0 && index < current.length) {
      var removed = current.splice(index, 1)[0]
      root.fileShareList = current
      if (current.length === 0) {
        root.clearFileShare()
      } else {
        root.startFileShareList(current)
      }
      var remName = removed.split("/").pop() || "file"
      root.showFeedback("Removed " + remName)
    }
  }

  function clearFileShare() {
    root.stopFileShare()
    root.fileShareList = []
    root.fileShareMeta = []
    root.fileSharePath = ""
    root.fileShareName = ""
    root.fileShareSizeStr = ""
    root.fileShareUrl = ""
    root.fileShareIp = ""
    root.fileSharePort = 0
    root.fileShareCount = 0
    root.fileShareTotalSizeStr = ""
    root.fileShareStatus = "idle"
    root.fileShareStatusMsg = ""
    root.fileShareClientIp = ""
    root.fileShareProgress = 0.0
    root.fileShareSpeedStr = ""
    root.fileShareEtaStr = ""
    root.fileShareTransferring = false
    root.fileShareTransferType = ""
    root.fileShareTransferFile = ""
    root.fileSharePin = ""
    root.fileShareToken = ""
    if (root.payloadType === "file") {
      root.textToEncode = ""
      qrImage.source = ""
    }
  }

  function startFileShareList(paths) {
    if (!paths || paths.length === 0) {
      root.stopFileShare()
      return
    }
    root.stopFileShare()
    root.fileSharePath = paths[0]
    root.fileShareName = paths[0].split("/").pop()
    root.fileShareCount = paths.length
    root.fileShareStatus = "starting"
    root.fileShareStatusMsg = "Starting local Wi-Fi micro-server for " + paths.length + " file" + (paths.length > 1 ? "s" : "") + "..."
    root.payloadType = "file"

    var args = ["python3", root.fileShareScript]
    if (!root.fileShareSingleShot) {
      args.push("--no-single-shot")
    }
    for (var i = 0; i < paths.length; i++) {
      args.push(paths[i])
    }
    fileServerProc.command = args
    fileServerProc.running = true
  }

  function startFileShare(filePath) {
    root.addFileSharePaths([filePath])
  }

  function stopFileShare() {
    if (fileServerProc.running) {
      fileServerProc.running = false
    }
    root.fileShareRunning = false
    root.fileShareStatus = "idle"
    root.fileShareStatusMsg = ""
    root.fileShareUrl = ""
    root.fileShareIp = ""
    root.fileSharePort = 0
    root.fileShareClientIp = ""
  }

  function getFileShareItemMeta(index, path) {
    if (root.fileShareMeta && index >= 0 && index < root.fileShareMeta.length && root.fileShareMeta[index]) {
      return root.fileShareMeta[index]
    }
    var name = path ? path.split("/").pop() : "File"
    return { name: name, size_str: "", path: path || "" }
  }

  function handleFileServerEvent(ev) {
    if (!ev || !ev.event) return
    if (ev.event === "started") {
      root.fileShareRunning = true
      root.fileShareStatus = "serving"
      root.fileShareUrl = ev.url
      root.fileShareIp = ev.ip
      root.fileSharePort = ev.port
      root.fileSharePin = ev.pin || ""
      root.fileShareToken = ev.token || ""
      root.fileShareCount = ev.count || (ev.files ? ev.files.length : 1)
      root.fileShareTotalSizeStr = ev.total_size_str || ev.size_str || ""
      root.fileShareMeta = ev.files || []
      if (ev.files && ev.files.length > 0) {
        root.fileShareName = ev.files[0].name
        root.fileShareSizeStr = ev.files[0].size_str
      } else {
        root.fileShareName = ev.name || ""
        root.fileShareSizeStr = ev.size_str || ""
      }
      root.fileShareStatusMsg = "Live on LAN: " + ev.ip + ":" + ev.port + (root.fileShareCount > 1 ? " (" + root.fileShareCount + " files)" : "") + (root.fileSharePin ? " · PIN: " + root.fileSharePin : "")
      root.textToEncode = ev.url
      root.generateQr()
      root.showFeedback("󰉋 Sharing " + (root.fileShareCount > 1 ? (root.fileShareCount + " files") : root.fileShareName) + " on Wi-Fi")
    } else if (ev.event === "client_visiting") {
      root.fileShareClientIp = ev.client
      root.fileShareStatusMsg = "📱 Phone connected (" + ev.client + ")"
      root.showFeedback("📱 Device connected to web portal: " + ev.client)
    } else if (ev.event === "connecting") {
      root.fileShareClientIp = ev.client
      if (ev.action === "preview") {
        root.fileShareStatusMsg = "Client viewing " + (ev.file_name ? ev.file_name : "preview") + " on " + ev.client
      } else {
        root.fileShareStatus = "downloading"
        root.fileShareTransferring = true
        root.fileShareTransferType = "download"
        root.fileShareTransferFile = ev.file_name || ""
        root.fileShareStatusMsg = "Client downloading: " + ev.client + (ev.file_name ? " (" + ev.file_name + ")" : "")
      }
    } else if (ev.event === "download_progress") {
      root.fileShareClientIp = ev.client || root.fileShareClientIp
      root.fileShareTransferring = true
      root.fileShareTransferType = "download"
      root.fileShareTransferFile = ev.file_name || root.fileShareTransferFile
      root.fileShareProgress = (ev.percent || 0) / 100
      root.fileShareSpeedStr = ev.speed || ""
      root.fileShareEtaStr = ev.eta || ""
      root.fileShareStatus = "downloading"
      root.fileShareStatusMsg = "Sending " + (ev.file_name || "file") + " (" + (ev.percent || 0) + "% · " + (ev.speed || "") + ")"
    } else if (ev.event === "upload_started") {
      root.fileShareClientIp = ev.client || root.fileShareClientIp
      root.fileShareTransferring = true
      root.fileShareTransferType = "upload"
      root.fileShareTransferFile = ev.file_name || "file"
      root.fileShareProgress = 0.0
      root.fileShareSpeedStr = ""
      root.fileShareEtaStr = ""
      root.fileShareStatus = "uploading"
      root.fileShareStatusMsg = "Receiving upload: " + root.fileShareTransferFile
      root.showFeedback("󰐕 Receiving file from phone: " + root.fileShareTransferFile)
    } else if (ev.event === "upload_progress") {
      root.fileShareClientIp = ev.client || root.fileShareClientIp
      root.fileShareTransferring = true
      root.fileShareTransferType = "upload"
      root.fileShareTransferFile = ev.file_name || root.fileShareTransferFile
      root.fileShareProgress = (ev.percent || 0) / 100
      root.fileShareSpeedStr = ev.speed || ""
      root.fileShareEtaStr = ev.eta || ""
      root.fileShareStatus = "uploading"
      root.fileShareStatusMsg = "Receiving " + (ev.file_name || "file") + " (" + (ev.percent || 0) + "% · " + (ev.speed || "") + ")"
    } else if (ev.event === "upload_completed") {
      root.fileShareTransferring = false
      root.fileShareProgress = 1.0
      root.fileShareStatus = "serving"
      root.fileShareStatusMsg = "✓ Received " + (ev.file_name || "file") + " (" + (ev.size_str || "") + ") in ReClip-Drop"
      root.showFeedback("✓ Upload received: " + (ev.file_name || "file") + " (" + (ev.size_str || "") + ")")
    } else if (ev.event === "text_beamed") {
      root.fileShareStatusMsg = "⚡ Phone beamed text snippet to clipboard"
      root.showFeedback("⚡ Beamed from phone: " + (ev.preview || "Text copied to clipboard"))
    } else if (ev.event === "pin_verified") {
      root.fileShareStatusMsg = "🔒 Phone authenticated via PIN (" + ev.client + ")"
      root.showFeedback("🔒 Phone unlocked file drop via PIN (" + ev.client + ")")
    } else if (ev.event === "completed") {
      root.fileShareTransferring = false
      root.fileShareProgress = 1.0
      if (ev.action !== "preview") {
        root.fileShareStatus = "completed"
        root.fileShareStatusMsg = "✓ Transferred " + (ev.file_name || "") + " to " + ev.client + (ev.size_str ? " (" + ev.size_str + ")" : "")
        root.showFeedback("✓ Transfer complete: " + (ev.file_name || "File") + " sent to " + ev.client)
      }
    } else if (ev.event === "stopped") {
      root.fileShareRunning = false
      root.fileShareTransferring = false
      if (root.fileShareStatus !== "completed") {
        root.fileShareStatus = "idle"
        root.fileShareStatusMsg = "Server stopped"
      }
    } else if (ev.event === "error") {
      root.fileShareTransferring = false
      root.fileShareStatus = "error"
      root.fileShareStatusMsg = "Error: " + (ev.message || "Failed to start server")
      root.showFeedback("⚠ File Share Error: " + (ev.message || ""))
    }
  }

  function runDecode() {
    if (!root.decodeImagePath) {
      root.decodeSuccess = false
      root.decodedText = ""
      return
    }
    root.isDecoding = true
    root.decodeSuccess = false
    root.decodedText = ""
    decodeProc.command = ["sh", "-c", "zbarimg -q --raw '" + root.decodeImagePath + "' 2>/dev/null || (magick '" + root.decodeImagePath + "' -negate png:- 2>/dev/null | zbarimg -q --raw - 2>/dev/null)"]
    decodeProc.running = true
  }

  function updateDecodedFormat() {
    var s = String(root.decodedText || "").trim()
    if (/^https?:\/\//i.test(s)) {
      root.decodedFormat = "url"
    } else if (/^WIFI:/i.test(s)) {
      root.decodedFormat = "wifi"
    } else if (/^geo:/i.test(s)) {
      root.decodedFormat = "geo"
    } else if (/BEGIN:(VEVENT|VCALENDAR)/i.test(s)) {
      root.decodedFormat = "event"
    } else if (/^mailto:/i.test(s)) {
      root.decodedFormat = "email"
    } else if (/^(smsto|sms):/i.test(s)) {
      root.decodedFormat = "sms"
    } else if (/^BEGIN:VCARD/i.test(s)) {
      root.decodedFormat = "vcard"
    } else {
      root.decodedFormat = "text"
    }
  }

  function openDecodedGeo() {
    var s = String(root.decodedText || "").trim()
    if (/^geo:/i.test(s)) {
      var g = s.slice(4)
      var qIdx = g.indexOf("?q=")
      var query = qIdx >= 0 ? g.slice(qIdx + 3) : g
      var mapUrl = "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(decodeURIComponent(query))
      Quickshell.execDetached(["xdg-open", mapUrl])
      root.showFeedback("󰍎 Opened in Maps")
    }
  }

  function copyDecodedText() {
    if (root.decodedText) {
      root.copiedText(root.decodedText)
      root.showFeedback("✓ Decoded text copied to clipboard!")
    }
  }

  function openDecodedUrl() {
    var s = String(root.decodedText || "").trim()
    if (/^https?:\/\//i.test(s)) {
      Quickshell.execDetached(["xdg-open", s])
      root.showFeedback("󰌹 Opened in default browser")
    }
  }

  function parseWifiFromText(raw) {
    var s = String(raw || "").trim()
    var sMatch = s.match(/S:([^;]*)/i)
    var pMatch = s.match(/P:([^;]*)/i)
    var tMatch = s.match(/T:([^;]*)/i)
    var hMatch = s.match(/H:([^;]*)/i)
    var ssid = sMatch ? sMatch[1].replace(/\\([\\;,":])/g, "$1") : ""
    var pass = pMatch ? pMatch[1].replace(/\\([\\;,":])/g, "$1") : ""
    var enc = tMatch ? tMatch[1].toUpperCase() : "WPA"
    var hidden = hMatch ? (hMatch[1].toLowerCase() === "true") : false
    return { ssid: ssid, pass: pass, enc: enc, hidden: hidden }
  }

  function connectToDecodedWifi() {
    var s = String(root.decodedText || "").trim()
    if (!s.startsWith("WIFI:")) return
    var info = root.parseWifiFromText(s)
    if (!info.ssid) {
      root.showFeedback("⚠ No SSID found in Wi-Fi QR")
      return
    }
    root.isConnectingWifi = true
    root.wifiConnectedSsid = info.ssid
    root.showFeedback("󰖩 Connecting to " + info.ssid + "...")

    var cmd = ["nmcli", "dev", "wifi", "connect", info.ssid]
    if (info.pass && info.pass.length > 0) {
      cmd.push("password")
      cmd.push(info.pass)
    }
    if (info.hidden) {
      cmd.push("hidden")
      cmd.push("yes")
    }
    wifiConnectProc.command = cmd
    wifiConnectProc.running = true
  }

  function nextSeriesPart() {
    if (!root.isSeriesMode || root.totalSeriesParts <= 1) return
    if (root.currentSeriesIndex < root.totalSeriesParts) {
      root.currentSeriesIndex++
    } else {
      root.currentSeriesIndex = 1
    }
  }

  function prevSeriesPart() {
    if (!root.isSeriesMode || root.totalSeriesParts <= 1) return
    if (root.currentSeriesIndex > 1) {
      root.currentSeriesIndex--
    } else {
      root.currentSeriesIndex = root.totalSeriesParts
    }
  }

  function handleDecodedRaw(raw) {
    root.decodedText = raw
    root.isDecoding = false
    if (raw.length > 0) {
      root.decodeSuccess = true

      // Multi-part envelope detection: [X/Y] or [Part X/Y]
      var m = raw.match(/^\[(?:Part\s*)?(\d+)\s*\/\s*(\d+)\](?:\r?\n|\s+)?([\s\S]*)/i)
      if (m) {
        var pNum = parseInt(m[1])
        var pTotal = parseInt(m[2])
        var body = m[3]

        root.isDecodedSeries = true
        root.decodedSeriesPart = pNum
        root.decodedSeriesTotal = pTotal

        var buf = (root.decodedSeriesTotal === pTotal) ? Object.assign({}, root.decodedSeriesBuffer) : {}
        buf[pNum] = body
        root.decodedSeriesBuffer = buf

        var count = 0
        for (var i = 1; i <= pTotal; i++) {
          if (buf[i] !== undefined) count++
        }
        root.decodedSeriesCount = count

        if (count === pTotal) {
          root.showFeedback("✓ All " + pTotal + " parts captured! Ready to concat.")
        } else {
          root.showFeedback("󰄳 Captured part " + pNum + " of " + pTotal + " (" + count + "/" + pTotal + " ready)")
        }
      } else {
        root.isDecodedSeries = false
        root.showFeedback("✓ QR Code successfully decoded!")
      }
      root.updateDecodedFormat()
    } else {
      root.decodeSuccess = false
      root.showFeedback("No QR code detected in image")
    }
  }

  function concatBufferedSeries() {
    if (!root.isDecodedSeries) return
    var full = ""
    for (var i = 1; i <= root.decodedSeriesTotal; i++) {
      if (root.decodedSeriesBuffer[i] !== undefined) {
        full += root.decodedSeriesBuffer[i]
      } else {
        full += "\n[MISSING PART " + i + " OF " + root.decodedSeriesTotal + "]\n"
      }
    }
    root.decodedText = full
    root.updateDecodedFormat()
    root.showFeedback("✓ Concat complete: " + full.length + " characters assembled")
  }

  function resetDecodedSeries() {
    root.isDecodedSeries = false
    root.decodedSeriesBuffer = {}
    root.decodedSeriesCount = 0
    root.assembledSeriesText = ""
    root.showFeedback("Series scan buffer cleared")
  }

  function transferToGenerator() {
    if (root.isDecodedSeries && root.decodedSeriesCount === root.decodedSeriesTotal) {
      root.concatBufferedSeries()
    }
    if (root.decodedText) {
      root.textToEncode = root.decodedText
      if (qrTextInput) qrTextInput.text = root.decodedText
      root.activeMode = 0
      root.generateQr()
      root.showFeedback("󰄲 Transferred to QR Generator")
    }
  }

  function close() {
    root.isPickingFiles = false
    root.seriesAutoPlay = false
    root.copyDropdownOpen = false
    root.saveDropdownOpen = false
    root.themePresetsDropdownOpen = false
    root.logoPresetsDropdownOpen = false
    root.visible = false
    root.closed()
  }

  function requestGenerateQr() {
    if (!root.visible || root.textToEncode.trim().length === 0 || root.isBatchUpdating) return
    qrDebounceTimer.restart()
  }

  function generateQr() {
    var raw = String(root.textToEncode || "").trim()
    if (!raw) {
      root.isGenerating = false
      root.generationError = ""
      qrImage.source = ""
      return
    }

    if (qrProc.running) {
      root.pendingGeneration = true
      return
    }

    root.isGenerating = true
    root.generationError = ""

    var cfg = {
      text: root.textToEncode,
      output: root.qrImgPath,
      svg_output: root.qrSvgPath,
      ecc: root.eccLevel,
      version: root.qrVersion,
      quiet_zone: root.quietZone,
      fg_color: root.qrFgColor,
      bg_color: root.qrBgColor,
      outer_eye_color: root.qrOuterEyeColor,
      inner_eye_color: root.qrInnerEyeColor,
      timing_color: root.qrTimingColor,
      alignment_color: root.qrAlignmentColor,
      module_shape: root.moduleShape,
      eye_shape: root.eyeShape,
      logo_preset: root.logoPreset,
      logo_path: root.logoPreset === "custom" ? root.customLogoPath : "",
      logo_shape: root.logoShape,
      logo_size: root.logoSize,
      logo_bg_color: root.logoBgColor,
      logo_border_color: root.logoBorderColor || root.qrOuterEyeColor || root.qrFgColor,
      logo_border_width: root.logoBorderWidth,
      logo_padding: root.logoPadding,
      logo_tint_color: root.logoTintColor || root.qrFgColor,
      gradient_type: root.gradientType,
      gradient_color: root.gradientColor,
      frame_style: root.frameStyle,
      frame_text: root.frameText,
      frame_subtext: root.frameSubtext,
      frame_radius: root.frameRadius,
      frame_color: root.frameColor || root.qrFgColor,
      frame_text_color: root.frameTextColor,
      resolution: root.exportResolution,
      auto_split: root.seriesAutoSplit,
      max_chunk_size: root.seriesChunkSize
    }

    qrProc.command = [
      "python3",
      root.stylerScript,
      JSON.stringify(cfg)
    ]
    qrProc.running = true
  }

  function showFeedback(msg) {
    root.feedbackMsg = msg
    feedbackTimer.restart()
    root.feedbackShown(msg)
  }

  function applyPickedColor(hex) {
    if (!hex) return
    var clean = String(hex).trim()
    if (!clean.startsWith("#") && clean !== "transparent") clean = "#" + clean

    if (root.activeColorTarget === "fg") {
      root.qrFgColor = clean
      root.showFeedback("Modules FG: " + clean)
    } else if (root.activeColorTarget === "bg") {
      root.qrBgColor = clean
      root.showFeedback("Canvas BG: " + clean)
    } else if (root.activeColorTarget === "gradient") {
      root.gradientColor = clean
      root.showFeedback("Gradient End: " + clean)
    } else if (root.activeColorTarget === "frame_bg") {
      root.frameColor = clean
      root.showFeedback("Frame Banner: " + clean)
    } else if (root.activeColorTarget === "frame_text") {
      root.frameTextColor = clean
      root.showFeedback("Frame Text: " + clean)
    } else if (root.activeColorTarget === "outer_eye") {
      root.qrOuterEyeColor = clean
      root.showFeedback("Outer Eye: " + clean)
    } else if (root.activeColorTarget === "inner_eye") {
      root.qrInnerEyeColor = clean
      root.showFeedback("Inner Eye: " + clean)
    } else if (root.activeColorTarget === "timing") {
      root.qrTimingColor = clean
      root.showFeedback("Timing Track: " + clean)
    } else if (root.activeColorTarget === "alignment") {
      root.qrAlignmentColor = clean
      root.showFeedback("Alignment: " + clean)
    } else if (root.activeColorTarget === "logo_bg") {
      root.logoBgColor = clean
      root.showFeedback("Badge BG: " + clean)
    } else if (root.activeColorTarget === "logo_border") {
      root.logoBorderColor = clean
      root.showFeedback("Badge Border: " + clean)
    } else if (root.activeColorTarget === "logo_tint") {
      root.logoTintColor = clean
      root.showFeedback("Logo Tint: " + clean)
    }

    root.requestGenerateQr()
  }

  function resetColors() {
    root.isBatchUpdating = true
    root.qrFgColor = "#000000"
    root.qrBgColor = "#FFFFFF"
    root.qrOuterEyeColor = "#000000"
    root.qrInnerEyeColor = "#000000"
    root.qrTimingColor = "#000000"
    root.qrAlignmentColor = "#000000"
    root.gradientType = "none"
    root.frameStyle = "none"
    root.frameColor = ""
    root.frameTextColor = "#FFFFFF"
    root.isBatchUpdating = false
    root.showFeedback("Colors reset to default")
    root.requestGenerateQr()
  }

  function swapColors() {
    root.isBatchUpdating = true
    var oldFg = root.qrFgColor
    var oldBg = root.qrBgColor
    root.qrFgColor = oldBg
    root.qrBgColor = oldFg
    if (root.qrOuterEyeColor === oldFg) root.qrOuterEyeColor = oldBg
    if (root.qrInnerEyeColor === oldFg) root.qrInnerEyeColor = oldBg
    if (root.qrTimingColor === oldFg) root.qrTimingColor = oldBg
    if (root.qrAlignmentColor === oldFg) root.qrAlignmentColor = oldBg
    root.isBatchUpdating = false
    root.showFeedback("Colors swapped")
    root.requestGenerateQr()
  }

  onQrFgColorChanged: root.requestGenerateQr()
  onQrBgColorChanged: root.requestGenerateQr()
  onQrOuterEyeColorChanged: root.requestGenerateQr()
  onQrInnerEyeColorChanged: root.requestGenerateQr()
  onQrTimingColorChanged: root.requestGenerateQr()
  onQrAlignmentColorChanged: root.requestGenerateQr()
  onGradientTypeChanged: root.requestGenerateQr()
  onGradientColorChanged: root.requestGenerateQr()
  onFrameStyleChanged: root.requestGenerateQr()
  onFrameTextChanged: root.requestGenerateQr()
  onFrameSubtextChanged: root.requestGenerateQr()
  onFrameColorChanged: root.requestGenerateQr()
  onFrameTextColorChanged: root.requestGenerateQr()
  onFrameRadiusChanged: root.requestGenerateQr()
  onEccLevelChanged: root.requestGenerateQr()
  onModuleShapeChanged: root.requestGenerateQr()
  onEyeShapeChanged: root.requestGenerateQr()
  onQrVersionChanged: root.requestGenerateQr()
  onQuietZoneChanged: root.requestGenerateQr()
  onLogoPresetChanged: root.requestGenerateQr()
  onLogoShapeChanged: root.requestGenerateQr()
  onLogoSizeChanged: root.requestGenerateQr()
  onLogoBgColorChanged: root.requestGenerateQr()
  onLogoBorderColorChanged: root.requestGenerateQr()
  onLogoBorderWidthChanged: root.requestGenerateQr()
  onLogoPaddingChanged: root.requestGenerateQr()
  onLogoTintColorChanged: root.requestGenerateQr()
  onActiveModeChanged: {
    root.seriesAutoPlay = false
    root.copyDropdownOpen = false
    root.saveDropdownOpen = false
    root.themePresetsDropdownOpen = false
    root.logoPresetsDropdownOpen = false
  }
  onVisibleChanged: {
    if (!root.visible) {
      root.clearFileShare()
      root.seriesAutoPlay = false
      root.copyDropdownOpen = false
      root.saveDropdownOpen = false
      root.themePresetsDropdownOpen = false
      root.logoPresetsDropdownOpen = false
    }
  }
  onIsGeneratingChanged: {
    if (root.isGenerating) {
      root.copyDropdownOpen = false
      root.saveDropdownOpen = false
      root.themePresetsDropdownOpen = false
      root.logoPresetsDropdownOpen = false
    }
  }
  onActiveSectionTabChanged: {
    root.copyDropdownOpen = false
    root.saveDropdownOpen = false
    root.themePresetsDropdownOpen = false
    root.logoPresetsDropdownOpen = false
    if (root.activeSectionTab === 1) {
      if (root.payloadType !== "file") {
        root.payloadType = "file"
        root.updatePayloadText()
      }
    } else if (root.activeSectionTab === 0) {
      if (root.payloadType === "file") {
        root.payloadType = "text"
        root.updatePayloadText()
      }
    }
  }
  onActiveControlTabChanged: {
    root.themePresetsDropdownOpen = false
    root.logoPresetsDropdownOpen = false
  }
  onCurrentSeriesIndexChanged: {
    if (root.isSeriesMode && root.totalSeriesParts > 1) {
      qrImage.source = ""
      qrImage.source = "file://" + root.currentPartImgPath + "?t=" + Date.now()
    }
  }

  Timer {
    id: seriesPlayTimer
    interval: 1600
    repeat: true
    running: root.seriesAutoPlay && root.isSeriesMode && root.totalSeriesParts > 1 && root.visible && root.activeMode === 0
    onTriggered: {
      if (root.currentSeriesIndex < root.totalSeriesParts) {
        root.currentSeriesIndex++
      } else {
        root.currentSeriesIndex = 1
      }
    }
  }

  Timer {
    id: qrDebounceTimer
    interval: 80
    repeat: false
    onTriggered: root.generateQr()
  }

  Timer {
    id: feedbackTimer
    interval: 3000
    repeat: false
    onTriggered: root.feedbackMsg = ""
  }

  Process {
    id: qrProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        try {
          var info = JSON.parse(raw)
          if (info && info.success) {
            root.generationError = ""
            root.detectedVersion = info.version || 1
            root.matrixSize = info.matrix_size || 21
            root.totalModules = info.modules || 441
            root.isSeriesMode = Boolean(info.is_series)
            root.totalSeriesParts = info.total_parts || 1
            if (root.currentSeriesIndex > root.totalSeriesParts || root.currentSeriesIndex < 1) {
              root.currentSeriesIndex = 1
            }
            root.seriesParts = info.parts || []
          } else if (info && info.error) {
            root.generationError = String(info.error)
          }
        } catch (e) {
          if (raw && raw.length > 0 && !root.generationError) {
            root.generationError = raw
          }
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var errStr = String(text || "").trim()
        if (errStr && errStr.length > 0) {
          root.generationError = errStr
        }
      }
    }
    onExited: function(code) {
      root.isGenerating = false
      if (code === 0 && !root.generationError) {
        root.generationError = ""
        qrImage.source = ""
        qrImage.source = "file://" + root.currentPartImgPath + "?t=" + Date.now()
        root.updateContrastRatio()
        if (root.textToEncode.trim().length > 0) {
          verifyProc.command = ["sh", "-c", "zbarimg -q --raw '" + root.currentPartImgPath + "' 2>/dev/null || (magick '" + root.currentPartImgPath + "' -negate png:- 2>/dev/null | zbarimg -q --raw - 2>/dev/null)"]
          verifyProc.running = true
        }
      } else {
        qrImage.source = ""
        root.isVerifiedScannable = false
        if (!root.generationError) {
          root.generationError = "QR generation failed (exit code " + code + ")"
        }
        var cleanErr = root.generationError.replace(/\n/g, " ").trim()
        if (cleanErr.length > 36) cleanErr = cleanErr.slice(0, 36) + "..."
        root.showFeedback("⚠ " + cleanErr)
      }

      if (root.pendingGeneration) {
        root.pendingGeneration = false
        root.requestGenerateQr()
      }
    }
  }

  Process {
    id: verifyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        root.isVerifiedScannable = (raw.length > 0)
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.isVerifiedScannable = false
      }
    }
  }

  Process {
    id: copyImageProc
    command: ["sh", "-c", "wl-copy -t image/png < '" + root.currentPartImgPath + "'"]
    onExited: {
      var label = (root.isSeriesMode && root.totalSeriesParts > 1) ? ("Part " + root.currentSeriesIndex + "/" + root.totalSeriesParts) : "QR image"
      root.showFeedback("󰄲 " + label + " copied to clipboard!")
    }
  }

  Process {
    id: saveImageProc
    command: ["sh", "-c", "mkdir -p \"$HOME/Pictures\" && cp '" + root.currentPartImgPath + "' \"$HOME/Pictures/qr-" + (root.isSeriesMode ? ("part" + root.currentSeriesIndex + "-") : "") + "$(date +%Y%m%d-%H%M%S).png\""]
    onExited: function(code) {
      if (code === 0) {
        var label = (root.isSeriesMode && root.totalSeriesParts > 1) ? ("Part " + root.currentSeriesIndex + "/" + root.totalSeriesParts) : "QR PNG"
        root.showFeedback("󰆓 Saved " + label + " to ~/Pictures/")
      } else {
        root.showFeedback("⚠ Failed to save PNG")
      }
    }
  }

  Process {
    id: saveSvgProc
    command: ["sh", "-c", "mkdir -p \"$HOME/Pictures\" && cp '" + root.currentPartSvgPath + "' \"$HOME/Pictures/qr-" + (root.isSeriesMode ? ("part" + root.currentSeriesIndex + "-") : "") + "$(date +%Y%m%d-%H%M%S).svg\""]
    onExited: function(code) {
      if (code === 0) {
        var label = (root.isSeriesMode && root.totalSeriesParts > 1) ? ("Part " + root.currentSeriesIndex + "/" + root.totalSeriesParts) : "QR SVG"
        root.showFeedback("󰆓 Saved " + label + " to ~/Pictures/")
      } else {
        root.showFeedback("⚠ Failed to save SVG")
      }
    }
  }

  Process {
    id: saveAllSeriesProc
    command: [
      "sh", "-c",
      "TS=$(date +%Y%m%d_%H%M%S) && " +
      "DEST=\"$HOME/Pictures/QR_Series_$TS\" && " +
      "mkdir -p \"$DEST\" && " +
      "cp '" + root.stateDir + "'/reclip-qr-part-*.png \"$DEST/\" 2>/dev/null || true && " +
      "cp '" + root.stateDir + "'/reclip-qr-part-*.svg \"$DEST/\" 2>/dev/null || true && " +
      "printf '%s' '" + root.textToEncode.replace(/'/g, "'\\''") + "' > \"$DEST/full_payload.txt\" 2>/dev/null || true && " +
      "echo \"$DEST\""
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var d = String(text || "").trim()
        if (d) {
          var folderName = d.split("/").pop()
          root.showFeedback("󰆓 Exported " + root.totalSeriesParts + " parts to ~/Pictures/" + folderName)
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.showFeedback("⚠ Failed to export series")
      }
    }
  }

  Process {
    id: decodeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        root.handleDecodedRaw(raw)
      }
    }
    onExited: function(code) {
      root.isDecoding = false
      if (code !== 0 && (!root.decodedText || root.decodedText.length === 0)) {
        root.decodeSuccess = false
      }
    }
  }

  Process {
    id: pasteClipboardImageProc
    command: ["sh", "-c", "TMP=\"${XDG_RUNTIME_DIR:-/tmp}/reclip-qr-paste-$$.png\" && wl-paste -t image/png > \"$TMP\" 2>/dev/null && echo \"$TMP\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var p = String(text || "").trim()
        if (p && p.length > 0) {
          root.decodeImagePath = p
          root.runDecode()
        } else {
          root.showFeedback("No image found in clipboard")
        }
      }
    }
  }

  Process {
    id: snipScreenProc
    command: [
      "sh", "-c",
      "TMP=\"${XDG_RUNTIME_DIR:-/tmp}/reclip-qr-snip-$$.png\" && " +
      "GEO=$(slurp 2>/dev/null || true) && " +
      "if [ -n \"$GEO\" ]; then grim -g \"$GEO\" \"$TMP\" 2>/dev/null && echo \"$TMP\"; fi"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var p = String(text || "").trim()
        if (p && p.length > 0) {
          root.decodeImagePath = p
          root.runDecode()
          root.showFeedback("󰄳 Screen snip captured & scanned")
        }
      }
    }
  }

  Process {
    id: wifiConnectProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(text || "").trim()
        if (out && out.length > 0) root.showFeedback("󰖩 " + out)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err && err.length > 0) root.showFeedback("⚠ " + err)
      }
    }
    onExited: function(code) {
      root.isConnectingWifi = false
      if (code === 0) {
        root.showFeedback("󰖩 Connected to " + root.wifiConnectedSsid + "!")
      }
    }
  }

  Process {
    id: copySvgProc
    command: ["sh", "-c", "wl-copy < '" + root.qrSvgPath + "'"]
    onExited: function(code) {
      if (code === 0) {
        root.showFeedback("󰆏 SVG code copied to clipboard!")
      } else {
        root.showFeedback("⚠ Failed to copy SVG code")
      }
    }
  }

  Process {
    id: fileServerProc
    stdout: SplitParser {
      onRead: function(data) {
        var line = String(data || "").trim()
        if (!line) return
        try {
          var ev = JSON.parse(line)
          root.handleFileServerEvent(ev)
        } catch(e) {}
      }
    }
    onExited: function(code) {
      root.fileShareRunning = false
      if (root.fileShareStatus === "serving" || root.fileShareStatus === "downloading") {
        root.fileShareStatus = "idle"
        root.fileShareStatusMsg = "Server stopped"
      }
    }
  }

  Process {
    id: filePickProc
    command: ["python3", root.filePickerScript]
    onRunningChanged: {
      if (!running) root.isPickingFiles = false
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isPickingFiles = false
        var raw = String(text || "").trim()
        if (raw) {
          var lines = raw.split("\n")
          var picked = []
          for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l.length > 0) picked.push(l)
          }
          if (picked.length > 0) {
            root.addFileSharePaths(picked)
          }
        }
      }
    }
  }

  Process {
    id: folderPickProc
    command: ["python3", root.filePickerScript, "--directory"]
    onRunningChanged: {
      if (!running) root.isPickingFiles = false
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isPickingFiles = false
        var raw = String(text || "").trim()
        if (raw) {
          var lines = raw.split("\n")
          var picked = []
          for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l.length > 0) picked.push(l)
          }
          if (picked.length > 0) {
            root.addFileSharePaths(picked)
          }
        }
      }
    }
  }

  // Mouse shield & Escape handling
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    onClicked: function(mouse) { mouse.accepted = true }
    onPressed: function(mouse) { mouse.accepted = true }
    onReleased: function(mouse) { mouse.accepted = true }
    onWheel: function(wheel) { wheel.accepted = true }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: {
      if (root.copyDropdownOpen || root.saveDropdownOpen || root.themePresetsDropdownOpen || root.logoPresetsDropdownOpen) {
        root.copyDropdownOpen = false
        root.saveDropdownOpen = false
        root.themePresetsDropdownOpen = false
        root.logoPresetsDropdownOpen = false
      } else {
        root.close()
      }
    }
    Keys.onPressed: function(event) {
      if (root.activeMode === 0) {
        if (root.isSeriesMode && root.totalSeriesParts > 1 && (!qrTextInput || !qrTextInput.activeFocus)) {
          if (event.key === Qt.Key_Right) {
            root.nextSeriesPart()
            event.accepted = true
            return
          } else if (event.key === Qt.Key_Left) {
            root.prevSeriesPart()
            event.accepted = true
            return
          } else if (event.key === Qt.Key_Space) {
            root.seriesAutoPlay = !root.seriesAutoPlay
            event.accepted = true
            return
          }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_C || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
          if (!root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0) {
            copyImageProc.running = true
            event.accepted = true
          }
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
          if (!root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0) {
            saveImageProc.running = true
            event.accepted = true
          }
        }
      } else {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
          if (root.decodedText) {
            root.copyDecodedText()
            event.accepted = true
          }
        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
          if (root.decodedFormat === "url") {
            root.openDecodedUrl()
            event.accepted = true
          } else if (root.decodedFormat === "geo") {
            root.openDecodedGeo()
            event.accepted = true
          } else if (root.decodedText) {
            root.transferToGenerator()
            event.accepted = true
          }
        }
      }
    }
  }

  // Full-View Column Layout (0 outer margins, matching Text & Image Editors)
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ==========================================
    // 1. TOP HEADER BAR (Edge-to-Edge)
    // ==========================================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(40)
      Layout.fillHeight: false
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        // Left Side: Icon & Title
        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(26); height: Style.space(26); radius: Style.space(6)
            color: Util.alpha(Color.accent, 0.15)
            border.width: 1; border.color: Util.alpha(Color.accent, 0.3)
            Text {
              text: root.activeMode === 0 ? "󰒗" : "󰄳"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              anchors.centerIn: parent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: root.activeMode === 0 ? "Share Data" : "QR Code Scanner & Decoder"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: root.activeMode === 0 ? "Share texts, files and folders using QR Code" : "Scan, inspect, and extract data from QR code images"
              color: Util.alpha(Color.popups.text || Color.text, 0.55)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Mode Switcher Tabs (Generate / Decode)
        Row {
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.space(4)

          Rectangle {
            height: Style.space(24)
            width: genTabRow.implicitWidth + Style.space(16)
            radius: Style.space(4)
            color: root.activeMode === 0 ? Color.accent : (genTabMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
            border.width: 1
            border.color: root.activeMode === 0 ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)
            Row {
              id: genTabRow
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text { text: "󰄲"; color: root.activeMode === 0 ? "#ffffff" : (Color.popups.text || Color.text); font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Generate"; color: root.activeMode === 0 ? "#ffffff" : (Color.popups.text || Color.text); font.family: Style.font.menuFamily; font.pixelSize: Style.space(8.5); font.bold: root.activeMode === 0; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: genTabMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.activeMode = 0
            }
          }

          Rectangle {
            height: Style.space(24)
            width: decTabRow.implicitWidth + Style.space(16)
            radius: Style.space(4)
            color: root.activeMode === 1 ? Color.accent : (decTabMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.05))
            border.width: 1
            border.color: root.activeMode === 1 ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.3)
            Row {
              id: decTabRow
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text { text: "󰄳"; color: root.activeMode === 1 ? "#ffffff" : (Color.popups.text || Color.text); font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Decode"; color: root.activeMode === 1 ? "#ffffff" : (Color.popups.text || Color.text); font.family: Style.font.menuFamily; font.pixelSize: Style.space(8.5); font.bold: root.activeMode === 1; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: decTabMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.activeMode = 1
                if (!root.decodedText && root.decodeImagePath) {
                  root.runDecode()
                }
              }
            }
          }
        }

        // Close Button
        Rectangle {
          width: Style.space(26); height: Style.space(26); radius: Style.space(5)
          color: closeMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
          border.width: 1
          border.color: closeMouse.containsMouse ? Color.accent : Util.alpha(Color.popups.text || Color.text, 0.12)
          Text {
            text: "✕"
            color: closeMouse.containsMouse ? Color.accent : (Color.popups.text || Color.text)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.centerIn: parent
          }
          MouseArea {
            id: closeMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }
    }

    // ==========================================
    // 2. BODY CONTENT: SPLIT VIEW (QR Preview Top, Tabs Studio Bottom)
    // ==========================================
    Item {
      id: bodyContainer
      Layout.fillWidth: true
      Layout.fillHeight: true

      readonly property real availableHeight: bodyContainer.height
      // QR Code preview section allocated to 65% of available height
      readonly property real section1Height: Math.floor(availableHeight * 0.65)
      readonly property real section2Height: Math.floor(availableHeight * 0.22)
      readonly property real section3Height: Math.max(Style.space(80), availableHeight - section1Height)

      ColumnLayout {
        id: generatorBodyLayout
        visible: root.activeMode === 0
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------------------
        // SECTION 1: QR CODE PREVIEW (Frameless, pure QR Code)
        // -------------------------------------------------------------
        // -------------------------------------------------------------
        // SECTION 1: QR CODE PREVIEW (Frameless, pure QR Code)
        // -------------------------------------------------------------
        QRPreviewPane {
          id: previewPane
          modal: root
          Layout.fillWidth: true
          Layout.preferredHeight: bodyContainer.section1Height
          Layout.fillHeight: false
        }

        // -------------------------------------------------------------
        // -------------------------------------------------------------
        // COMBINED SECTION (Input & Properties Tabs)
        // -------------------------------------------------------------
        Rectangle {
          id: secCombined
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 0
          color: Util.alpha(Color.popups.text || Color.text, 0.02)
          border.width: 1
          border.color: Util.alpha(Color.popups.border || Color.border, 0.3)
          clip: true

          // Reusable Smart Scrubber Component
          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Master Tab Bar Header: [ Texts ] [ Files & Folders ] [ Properties ]
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(26)
              Layout.fillHeight: false
              color: Util.alpha(Color.popups.text || Color.text, 0.035)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.25)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(4)

                // 1. Texts Tab Button (Tab 0)
                Rectangle {
                  Layout.preferredHeight: Style.space(20)
                  Layout.preferredWidth: textsMasterTabRow.implicitWidth + Style.space(16)
                  radius: 0
                  color: root.activeSectionTab === 0
                         ? Util.alpha(Color.accent, 0.22)
                         : (textsMasterTabM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")
                  border.width: 1
                  border.color: root.activeSectionTab === 0
                                ? Color.accent
                                : (textsMasterTabM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : "transparent")

                  Row {
                    id: textsMasterTabRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "󰏫"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      color: root.activeSectionTab === 0 ? Color.accent : (Color.popups.text || Color.text)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Texts"
                      color: root.activeSectionTab === 0 ? Color.accent : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: root.activeSectionTab === 0
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: textsMasterTabM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.activeSectionTab = 0
                      if (root.payloadType === "file") {
                        root.payloadType = "text"
                        root.updatePayloadText()
                      }
                    }
                  }
                  PanelToolTip {
                    visible: textsMasterTabM.containsMouse
                    text: "Create QR codes from text, URLs, Wi-Fi, contacts, and other payload types"
                  }
                }

                // 2. Files & Folders Tab Button (Tab 1)
                Rectangle {
                  Layout.preferredHeight: Style.space(20)
                  Layout.preferredWidth: filesMasterTabRow.implicitWidth + Style.space(16)
                  radius: 0
                  color: root.activeSectionTab === 1
                         ? Util.alpha(Color.accent, 0.22)
                         : (filesMasterTabM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")
                  border.width: 1
                  border.color: root.activeSectionTab === 1
                                ? Color.accent
                                : (filesMasterTabM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : "transparent")

                  Row {
                    id: filesMasterTabRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "󰉋"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      color: root.activeSectionTab === 1 ? Color.accent : (Color.popups.text || Color.text)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Files & Folders"
                      color: root.activeSectionTab === 1 ? Color.accent : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: root.activeSectionTab === 1
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: filesMasterTabM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.activeSectionTab = 1
                      root.payloadType = "file"
                      root.updatePayloadText()
                    }
                  }
                  PanelToolTip {
                    visible: filesMasterTabM.containsMouse
                    text: "Share files and directories over local Wi-Fi via built-in HTTP file drop server"
                  }
                }

                // 3. Properties Tab Button (Tab 2)
                Rectangle {
                  Layout.preferredHeight: Style.space(20)
                  Layout.preferredWidth: propMasterTabRow.implicitWidth + Style.space(16)
                  radius: 0
                  color: root.activeSectionTab === 2
                         ? Util.alpha(Color.accent, 0.22)
                         : (propMasterTabM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")
                  border.width: 1
                  border.color: root.activeSectionTab === 2
                                ? Color.accent
                                : (propMasterTabM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : "transparent")

                  Row {
                    id: propMasterTabRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "⚙️"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      color: root.activeSectionTab === 2 ? Color.accent : (Color.popups.text || Color.text)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Properties"
                      color: root.activeSectionTab === 2 ? Color.accent : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: root.activeSectionTab === 2
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: propMasterTabM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeSectionTab = 2
                  }
                  PanelToolTip {
                    visible: propMasterTabM.containsMouse
                    text: "Customize QR colors, module shapes, finder eyes, quiet zone, and center logo"
                  }
                }

                Item { Layout.fillWidth: true }
              }
            }

            // Tab Content Body
            StackLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              currentIndex: root.activeSectionTab

              // ==========================================
              // TAB 0: TEXTS (Two-Column Layout: Builders Left, Workspace Right)
              // ==========================================
              // ==========================================
              // TAB 0: TEXTS (Two-Column Layout: Builders Left, Workspace Right)
              // ==========================================
              QRTextTab {
                id: textTab
                modal: root
                Layout.fillWidth: true
                Layout.fillHeight: true
              }

              // ==========================================
              // TAB 1: FILES & FOLDERS (Two-Column Layout: Controls Left, Workspace Right)
              // ==========================================
              QRFilesTab {
                id: filesTab
                modal: root
                Layout.fillWidth: true
                Layout.fillHeight: true
              }

              // ==========================================
              // TAB 2: PROPERTIES (Two-Column Layout: Sidebar Left, Content Right)
              // ==========================================
              QRPropertiesTab {
                id: propertiesTab
                modal: root
                Layout.fillWidth: true
                Layout.fillHeight: true
              }
            }
          }
        }
      }

      // ==========================================
      // MODE 1: DECODER LAYOUT (Matching Generator Structure & Styling)
      // ==========================================
      ColumnLayout {
        id: decoderBodyLayout
        visible: root.activeMode === 1
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------------------
        // DECODER SECTION 1: SOURCE IMAGE VIEW (Frameless, matching sec1 height)
        // -------------------------------------------------------------
        Item {
          id: decSec1
          Layout.fillWidth: true
          Layout.preferredHeight: bodyContainer.section1Height
          Layout.fillHeight: false
          clip: true

          Item {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: Style.space(6)

            // Centered High-Contrast Image Card (Fills maximum space allocated, matching qrCardBox)
            Rectangle {
              id: decCardBox
              anchors.centerIn: parent
              height: Math.max(Style.space(60), Math.min(parent.width - Style.space(16), parent.height - Style.space(8)))
              width: height
              radius: 0
              color: root.decodeImagePath.length > 0 ? "#ffffff" : Util.alpha(Color.popups.text || Color.text, 0.04)
              border.width: 0
              clip: true

              Image {
                id: decImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: root.decodeImagePath ? ("file://" + root.decodeImagePath) : ""
                visible: root.decodeImagePath.length > 0
                smooth: false
              }

              BusyIndicator {
                anchors.centerIn: parent
                running: root.isDecoding
                visible: root.isDecoding
              }

              // Empty State Placeholder when no image is loaded
              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)
                visible: !root.decodeImagePath || root.decodeImagePath.length === 0

                Text {
                  text: "󰄳"
                  color: Util.alpha(Color.popups.text || Color.text, 0.3)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(36)
                  anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                  text: "No image loaded for decoding"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(9)
                  anchors.horizontalCenter: parent.horizontalCenter
                }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(8)

                  Rectangle {
                    width: snipBtnRow.implicitWidth + Style.space(16)
                    height: Style.space(26)
                    radius: 0
                    color: snipEmptyMouse.containsMouse ? Qt.lighter(Color.accent, 1.15) : Color.accent
                    Row {
                      id: snipBtnRow
                      anchors.centerIn: parent
                      spacing: Style.space(6)
                      Text { text: "󰆍"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(9); anchors.verticalCenter: parent.verticalCenter }
                      Text { text: "Snip Screen Area"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                      id: snipEmptyMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: snipScreenProc.running = true
                    }
                  }

                  Rectangle {
                    width: pasteBtnRow.implicitWidth + Style.space(16)
                    height: Style.space(26)
                    radius: 0
                    color: pasteClipMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                    border.width: 1; border.color: Color.accent
                    Row {
                      id: pasteBtnRow
                      anchors.centerIn: parent
                      spacing: Style.space(6)
                      Text { text: "󰅍"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
                      Text { text: "Paste Clipboard"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                      id: pasteClipMouse
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: pasteClipboardImageProc.running = true
                    }
                  }
                }
              }

              // Floating Status Pill (Top Right, radius: 0)
              Rectangle {
                visible: root.decodeImagePath.length > 0
                anchors.top: parent.top; anchors.right: parent.right
                anchors.margins: Style.space(6)
                height: Style.space(20)
                width: statusPillRow.implicitWidth + Style.space(12)
                radius: 0
                color: root.isDecoding ? Util.alpha(Color.accent, 0.9) : (root.decodeSuccess ? "#16A34A" : "#DC2626")
                Row {
                  id: statusPillRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    text: root.isDecoding ? "󰑮" : (root.decodeSuccess ? "✓" : "✕")
                    color: "#ffffff"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(7.5)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: root.isDecoding ? "Scanning..." : (root.decodeSuccess ? "QR Code Detected" : "No QR Code Found")
                    color: "#ffffff"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(7.5)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              // Floating Overlay Action Pills (Bottom Right when image exists, radius: 0)
              Row {
                visible: root.decodeImagePath.length > 0 && !root.isDecoding
                anchors.bottom: parent.bottom; anchors.right: parent.right
                anchors.margins: Style.space(6)
                spacing: Style.space(4)

                Rectangle {
                  height: Style.space(20)
                  width: snipPillRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: snipOtherMouse.containsMouse ? Util.alpha("#000000", 0.9) : Util.alpha("#000000", 0.75)
                  border.width: 1
                  border.color: Util.alpha("#ffffff", 0.25)
                  Row {
                    id: snipPillRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰆍"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Snip Screen"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: snipOtherMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: snipScreenProc.running = true
                  }
                }

                Rectangle {
                  height: Style.space(20)
                  width: pastePillRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: pasteOtherMouse.containsMouse ? Util.alpha("#000000", 0.9) : Util.alpha("#000000", 0.75)
                  border.width: 1
                  border.color: Util.alpha("#ffffff", 0.25)
                  Row {
                    id: pastePillRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰅍"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Paste Other"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: pasteOtherMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: pasteClipboardImageProc.running = true
                  }
                }
              }
            }
          }
        }

        // Hairline Divider
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          Layout.fillHeight: false
          color: Util.alpha(Color.popups.border || Color.border, 0.3)
        }

        // -------------------------------------------------------------
        // DECODER SECTION 2: DECODED CONTENT & ACTION STUDIO (Docked, radius: 0)
        // -------------------------------------------------------------
        Rectangle {
          id: decSec2
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
          border.width: 1
          border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
          radius: 0
          clip: true

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Toolbar Strip (Height: 26px, matching Generator Section 3 title strip)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(26)
              Layout.fillHeight: false
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.03)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.2)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(6)

                // Format Badge Pill (radius: 0)
                Rectangle {
                  visible: root.decodeSuccess
                  height: Style.space(18)
                  width: fmtRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: root.decodedFormat === "url" ? Util.alpha(Color.accent, 0.2)
                         : (root.decodedFormat === "wifi" ? Util.alpha("#A855F7", 0.2)
                         : (root.decodedFormat === "geo" ? Util.alpha("#10B981", 0.2)
                         : (root.decodedFormat === "event" ? Util.alpha("#EC4899", 0.2)
                         : Util.alpha(Color.popups.text || Color.text, 0.1))))
                  border.width: 1
                  border.color: root.decodedFormat === "url" ? Color.accent
                                : (root.decodedFormat === "wifi" ? "#A855F7"
                                : (root.decodedFormat === "geo" ? "#10B981"
                                : (root.decodedFormat === "event" ? "#EC4899"
                                : Util.alpha(Color.popups.text || Color.text, 0.25))))
                  Row {
                    id: fmtRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: root.decodedFormat === "url" ? "󰌹"
                            : (root.decodedFormat === "wifi" ? "󰤨"
                            : (root.decodedFormat === "geo" ? "󰍎"
                            : (root.decodedFormat === "event" ? "󰸗"
                            : (root.decodedFormat === "vcard" ? "📇"
                            : (root.decodedFormat === "email" ? "󰇮"
                            : (root.decodedFormat === "sms" ? "󰍡" : "󰦨"))))))
                      color: root.decodedFormat === "url" ? Color.accent
                             : (root.decodedFormat === "wifi" ? "#C084FC"
                             : (root.decodedFormat === "geo" ? "#34D399"
                             : (root.decodedFormat === "event" ? "#F472B6" : (Color.popups.text || Color.text))))
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: root.decodedFormat === "url" ? "Web URL"
                            : (root.decodedFormat === "wifi" ? "Wi-Fi Config"
                            : (root.decodedFormat === "geo" ? "Geo Location"
                            : (root.decodedFormat === "event" ? "Calendar Event"
                            : (root.decodedFormat === "vcard" ? "Contact vCard"
                            : (root.decodedFormat === "email" ? "Email"
                            : (root.decodedFormat === "sms" ? "SMS" : "Plain Text"))))))
                      color: root.decodedFormat === "url" ? Color.accent
                             : (root.decodedFormat === "wifi" ? "#C084FC"
                             : (root.decodedFormat === "geo" ? "#34D399"
                             : (root.decodedFormat === "event" ? "#F472B6" : (Color.popups.text || Color.text))))
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }

                Text {
                  visible: root.decodeSuccess
                  text: root.decodedText.length + " chars · " + (root.decodedText.length > 0 ? root.decodedText.split("\n").length : 0) + " lines"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                  Layout.alignment: Qt.AlignVCenter
                }

                Text {
                  visible: !root.decodeSuccess
                  text: "󰄳 Extracted QR Content"
                  color: Color.popups.text || Color.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Action: Transfer to Generator (radius: 0)
                Rectangle {
                  visible: root.decodeSuccess
                  height: Style.space(20)
                  width: transferBtnRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: transferMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                  border.width: 1
                  border.color: Util.alpha(Color.accent, 0.4)
                  Row {
                    id: transferBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: "󰄲"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Edit in Generator"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: transferMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.transferToGenerator()
                  }
                }

                // Action: Open URL in Browser (radius: 0)
                Rectangle {
                  visible: root.decodeSuccess && root.decodedFormat === "url"
                  height: Style.space(20)
                  width: openUrlBtnRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: openUrlMouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.accent, 0.15)
                  border.width: 1
                  border.color: Color.accent
                  Row {
                    id: openUrlBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: "󰌹"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Open URL"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: openUrlMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDecodedUrl()
                  }
                }

                // Action: Open Maps (radius: 0)
                Rectangle {
                  visible: root.decodeSuccess && root.decodedFormat === "geo"
                  height: Style.space(20)
                  width: openGeoBtnRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: openGeoMouse.containsMouse ? Util.alpha("#10B981", 0.35) : Util.alpha("#10B981", 0.2)
                  border.width: 1
                  border.color: "#10B981"
                  Row {
                    id: openGeoBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: "󰍎"; color: "#A7F3D0"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Open Maps"; color: "#A7F3D0"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: openGeoMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDecodedGeo()
                  }
                }

                // Action: Connect to Wi-Fi (radius: 0)
                Rectangle {
                  visible: root.decodeSuccess && root.decodedFormat === "wifi"
                  height: Style.space(20)
                  width: connectWifiBtnRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: connectWifiMouse.containsMouse ? Util.alpha("#A855F7", 0.35) : Util.alpha("#A855F7", 0.2)
                  border.width: 1
                  border.color: "#A855F7"
                  Row {
                    id: connectWifiBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text {
                      text: root.isConnectingWifi ? "󰑮" : "󰖩"
                      color: "#E9D5FF"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: root.isConnectingWifi ? "Connecting..." : "Connect Wi-Fi"
                      color: "#E9D5FF"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                  MouseArea {
                    id: connectWifiMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !root.isConnectingWifi
                    onClicked: root.connectToDecodedWifi()
                  }
                }

                // Action: Copy Text (radius: 0)
                Rectangle {
                  visible: root.decodeSuccess
                  height: Style.space(20)
                  width: copyDecBtnRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: copyDecMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.18) : Util.alpha(Color.popups.text || Color.text, 0.08)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                  Row {
                    id: copyDecBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { text: "󰆏"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Copy Text"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: copyDecMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyDecodedText()
                  }
                }
              }
            }

            // Multi-Part Series Buffer & Progress Bar (visible when decoding a multi-part envelope)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(32)
              radius: 0
              visible: root.isDecodedSeries
              color: Util.alpha(Color.accent, 0.1)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.4)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                // Series Status Label & Part Counter
                Row {
                  Layout.alignment: Qt.AlignVCenter
                  spacing: Style.space(5)

                  Text {
                    text: root.decodedSeriesCount === root.decodedSeriesTotal ? "✓" : "󰑮"
                    color: root.decodedSeriesCount === root.decodedSeriesTotal ? "#10B981" : Color.accent
                    font.pixelSize: Style.space(8.5)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "Multi-Part Stream: " + root.decodedSeriesCount + " of " + root.decodedSeriesTotal + " captured"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(7.5)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Visual Part Completion Slices
                Row {
                  Layout.alignment: Qt.AlignVCenter
                  spacing: Style.space(3)

                  Repeater {
                    model: root.decodedSeriesTotal

                    Rectangle {
                      width: Style.space(14)
                      height: Style.space(12)
                      radius: 0
                      color: (root.decodedSeriesBuffer && root.decodedSeriesBuffer[index + 1] !== undefined)
                             ? Color.accent
                             : Util.alpha(Color.popups.text || Color.text, 0.15)
                      border.width: 1
                      border.color: (root.decodedSeriesBuffer && root.decodedSeriesBuffer[index + 1] !== undefined)
                                    ? Color.accent
                                    : Util.alpha(Color.popups.border || Color.border, 0.3)

                      Text {
                        anchors.centerIn: parent
                        text: (index + 1).toString()
                        color: (root.decodedSeriesBuffer && root.decodedSeriesBuffer[index + 1] !== undefined)
                               ? (Color.buttonText || "#000000")
                               : Util.alpha(Color.popups.text || Color.text, 0.5)
                        font.family: "monospace"
                        font.pixelSize: Style.space(6)
                        font.bold: true
                      }
                    }
                  }
                }

                Item { Layout.fillWidth: true }

                // Concat & Assemble Button
                Rectangle {
                  Layout.preferredHeight: Style.space(20)
                  Layout.preferredWidth: concatBtnRow.implicitWidth + Style.space(12)
                  radius: 0
                  color: root.decodedSeriesCount === root.decodedSeriesTotal
                         ? Color.accent
                         : (concatMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12))
                  border.width: 1
                  border.color: Color.accent

                  Row {
                    id: concatBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text {
                      text: "󰄳"
                      color: root.decodedSeriesCount === root.decodedSeriesTotal ? (Color.buttonText || "#000000") : Color.accent
                      font.pixelSize: Style.space(7.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: root.decodedSeriesCount === root.decodedSeriesTotal ? "Concat & Assemble All" : "Assemble Captured"
                      color: root.decodedSeriesCount === root.decodedSeriesTotal ? (Color.buttonText || "#000000") : Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: concatMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.concatBufferedSeries()
                  }
                  PanelToolTip {
                    visible: concatMouse.containsMouse
                    text: "Join captured series parts in numerical order into the full assembled payload."
                  }
                }

                // Clear Buffer Button
                Rectangle {
                  Layout.preferredHeight: Style.space(20)
                  Layout.preferredWidth: clearBufRow.implicitWidth + Style.space(10)
                  radius: 0
                  color: clearBufMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : "transparent"
                  border.width: 1
                  border.color: Util.alpha(Color.popups.border || Color.border, 0.3)

                  Row {
                    id: clearBufRow
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text {
                      text: "✕"
                      color: Util.alpha(Color.popups.text || Color.text, 0.7)
                      font.pixelSize: Style.space(7)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Clear Buffer"
                      color: Util.alpha(Color.popups.text || Color.text, 0.7)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: clearBufMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetDecodedSeries()
                  }
                  PanelToolTip {
                    visible: clearBufMouse.containsMouse
                    text: "Discard all buffered parts and reset multi-part streaming."
                  }
                }
              }
            }

            // ScrollView with TextArea (radius: 0, matching Generator Section 3)
            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              visible: root.decodeSuccess

              TextArea {
                id: decodedTextEdit
                width: parent.width
                readOnly: true
                selectByMouse: true
                wrapMode: Text.WrapAnywhere
                color: Color.popups.text || Color.text
                font.family: root.decodedFormat === "url" ? (Style.font.fixedFamily || "monospace") : Style.font.menuFamily
                font.pixelSize: Style.space(9)
                text: root.decodedText
                selectionColor: Color.accent
                selectedTextColor: "#ffffff"
                background: null
                leftPadding: Style.space(10)
                rightPadding: Style.space(10)
                topPadding: Style.space(6)
                bottomPadding: Style.space(6)
              }
            }

            // Failed / No QR Code Fallback View
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              visible: !root.decodeSuccess && !root.isDecoding && root.decodeImagePath.length > 0

              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "No QR code or barcode detected in this image."
                  color: Util.alpha(Color.popups.text || Color.text, 0.6)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(9)
                  anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: ocrFallbackRow.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: 0
                  color: ocrFallbackMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                  border.width: 1
                  border.color: Color.accent
                  Row {
                    id: ocrFallbackRow
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    Text { text: "󰐳"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Extract Text with OCR Instead"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: ocrFallbackMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.requestOcr(root.decodeImagePath)
                      root.showFeedback("󰐳 Text extracted to clipboard with OCR")
                    }
                  }
                }
              }
            }

            // Busy Decoding Placeholder
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              visible: root.isDecoding

              Column {
                anchors.centerIn: parent
                spacing: Style.space(6)

                BusyIndicator {
                  running: true
                  anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                  text: "Scanning image with zbarimg..."
                  color: Util.alpha(Color.popups.text || Color.text, 0.6)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8.5)
                  anchors.horizontalCenter: parent.horizontalCenter
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // 3. TWO-TIER BOTTOM STATUS & ACTION BAR
    // ==========================================
    Rectangle {
      id: footerContainer
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(59)
      Layout.fillHeight: false
      color: Util.alpha(Color.popups.background || Color.background, 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border, 0.4)

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Row 1: Action Controls & Feedback Toast (Height: 34px)
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(34)
          Layout.fillHeight: false
          color: "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            // Left: Actions
            Row {
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignVCenter

              // Generator Mode Actions
              Row {
                visible: root.activeMode === 0
                spacing: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter

                // Unified Copy Dropdown Button
                Rectangle {
                  id: copyDropdownBtn
                  width: copyBtnRow.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: 0
                  color: root.copyDropdownOpen ? Qt.lighter(Color.accent, 1.18) : (copyBtnMouse.containsMouse ? Qt.lighter(Color.accent, 1.08) : Color.accent)
                  opacity: (!root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0) ? 1.0 : 0.45

                  Row {
                    id: copyBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    Text {
                      text: "󰄲"
                      color: "#ffffff"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Copy"
                      color: "#ffffff"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: root.copyDropdownOpen ? "▴" : "▾"
                      color: "#ffffff"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: copyBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0
                    onClicked: {
                      root.saveDropdownOpen = false
                      root.copyDropdownOpen = !root.copyDropdownOpen
                    }
                  }
                  PanelToolTip {
                    visible: copyBtnMouse.containsMouse && !root.copyDropdownOpen
                    text: "Copy QR Image (PNG), SVG Vector Code, or Raw Text"
                  }
                }

                // Unified Save Dropdown Button
                Rectangle {
                  id: saveDropdownBtn
                  width: saveBtnRow.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: 0
                  color: root.saveDropdownOpen ? Util.alpha(Color.accent, 0.25) : (saveBtnMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08))
                  border.width: 1
                  border.color: root.saveDropdownOpen ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.6)
                  opacity: (!root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0) ? 1.0 : 0.45

                  Row {
                    id: saveBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    Text {
                      text: "󰆓"
                      color: root.saveDropdownOpen ? Color.accent : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: "Save"
                      color: root.saveDropdownOpen ? Color.accent : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: root.saveDropdownOpen ? "▴" : "▾"
                      color: root.saveDropdownOpen ? Color.accent : (Color.popups.text || Color.text)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(7.5)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: saveBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.isGenerating && root.textToEncode.trim().length > 0 && root.generationError.length === 0
                    onClicked: {
                      root.copyDropdownOpen = false
                      root.saveDropdownOpen = !root.saveDropdownOpen
                    }
                  }
                  PanelToolTip {
                    visible: saveBtnMouse.containsMouse && !root.saveDropdownOpen
                    text: "Save QR Code to ~/Pictures/ as PNG or SVG"
                  }
                }
              }

              // Decoder Mode Actions
              Row {
                visible: root.activeMode === 1
                spacing: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter

                // Copy Decoded Text
                Rectangle {
                  visible: root.decodeSuccess
                  width: copyDecTextRow.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: 0
                  color: copyDecTextMouse.containsMouse ? Qt.lighter(Color.accent, 1.1) : Color.accent

                  Row {
                    id: copyDecTextRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰆏"; color: "#ffffff"; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Copy Text"; color: "#ffffff"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: copyDecTextMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyDecodedText()
                  }
                }

                // Open URL (if URL)
                Rectangle {
                  visible: root.decodeSuccess && root.decodedFormat === "url"
                  width: openUrlFootRow.implicitWidth + Style.space(14)
                  height: Style.space(24)
                  radius: 0
                  color: openUrlFootMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
                  border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)
                  Row {
                    id: openUrlFootRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰌹"; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Open URL"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: openUrlFootMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDecodedUrl()
                  }
                }

                // Open Maps (if Geo)
                Rectangle {
                  visible: root.decodeSuccess && root.decodedFormat === "geo"
                  width: openGeoFootRow.implicitWidth + Style.space(14)
                  height: Style.space(24)
                  radius: 0
                  color: openGeoFootMouse.containsMouse ? Util.alpha("#10B981", 0.35) : Util.alpha("#10B981", 0.2)
                  border.width: 1; border.color: "#10B981"
                  Row {
                    id: openGeoFootRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰍎"; color: "#A7F3D0"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Open Maps"; color: "#A7F3D0"; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: openGeoFootMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDecodedGeo()
                  }
                  PanelToolTip { visible: openGeoFootMouse.containsMouse; text: "Open coordinates in map viewer or browser" }
                }

                // Connect Wi-Fi (if Wi-Fi)
                Rectangle {
                  visible: root.decodeSuccess && root.decodedFormat === "wifi"
                  width: connectWifiFootRow.implicitWidth + Style.space(14)
                  height: Style.space(24)
                  radius: 0
                  color: connectWifiFootMouse.containsMouse ? Util.alpha("#A855F7", 0.35) : Util.alpha("#A855F7", 0.2)
                  border.width: 1; border.color: "#A855F7"
                  Row {
                    id: connectWifiFootRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: root.isConnectingWifi ? "󰑮" : "󰖩"
                      color: "#E9D5FF"
                      font.pixelSize: Style.space(7.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: root.isConnectingWifi ? "Connecting..." : "Connect Wi-Fi"
                      color: "#E9D5FF"
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                  MouseArea {
                    id: connectWifiFootMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !root.isConnectingWifi
                    onClicked: root.connectToDecodedWifi()
                  }
                }

                // Transfer to Generator
                Rectangle {
                  visible: root.decodeSuccess
                  width: xferFootRow.implicitWidth + Style.space(14)
                  height: Style.space(24)
                  radius: 0
                  color: xferFootMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
                  border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)
                  Row {
                    id: xferFootRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰄲"; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "To Generator"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: xferFootMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.transferToGenerator()
                  }
                }

                // Snip Screen Area
                Rectangle {
                  width: snipFootRow.implicitWidth + Style.space(14)
                  height: Style.space(24)
                  radius: 0
                  color: snipFootMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
                  border.width: 1; border.color: Color.accent
                  Row {
                    id: snipFootRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰆍"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Snip Screen"; color: Color.accent; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: snipFootMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: snipScreenProc.running = true
                  }
                }

                // Paste Image
                Rectangle {
                  width: pasteFootRow.implicitWidth + Style.space(14)
                  height: Style.space(24)
                  radius: 0
                  color: pasteFootMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
                  border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)
                  Row {
                    id: pasteFootRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { text: "󰅍"; font.pixelSize: Style.space(7.5); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Paste Image"; color: Color.popups.text || Color.text; font.family: Style.font.menuFamily; font.pixelSize: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: pasteFootMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: pasteClipboardImageProc.running = true
                  }
                }
              }
            }

            // Center: Feedback Toast Pill
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              Rectangle {
                visible: root.feedbackMsg.length > 0
                anchors.centerIn: parent
                height: Style.space(22)
                width: Math.min(parent.width - Style.space(8), Style.space(240))
                radius: 0
                clip: true
                color: root.feedbackMsg.startsWith("⚠") ? Util.alpha("#EF4444", 0.2) : Util.alpha(Color.accent, 0.2)
                border.width: 1
                border.color: root.feedbackMsg.startsWith("⚠") ? "#EF4444" : Color.accent

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)
                  spacing: Style.space(4)
                  Text {
                    text: root.feedbackMsg.startsWith("⚠") ? "⚠" : "✓"
                    color: root.feedbackMsg.startsWith("⚠") ? "#EF4444" : Color.accent
                    font.pixelSize: Style.space(8.5)
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                  }
                  Text {
                    text: root.feedbackMsg.replace(/^[✓⚠]\s*/, "")
                    color: root.feedbackMsg.startsWith("⚠") ? "#EF4444" : Color.accent
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                  }
                }
              }
            }

            // Right: Close / Done
            Row {
              spacing: Style.space(8)
              Layout.alignment: Qt.AlignVCenter

              Rectangle {
                width: Style.space(68)
                height: Style.space(24)
                radius: 0
                color: doneMouse.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.15) : Util.alpha(Color.popups.text || Color.text, 0.08)
                border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.6)

                Text {
                  text: "Done"
                  color: Color.popups.text || Color.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8.5)
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: doneMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.close()
                }
              }
            }
          }
        }

        // Hairline Divider
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          Layout.fillHeight: false
          color: Util.alpha(Color.popups.border || Color.border, 0.3)
        }

        // Row 2: Status & QR Statistics Strip (Height: 24px)
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(24)
          Layout.fillHeight: false
          color: Util.alpha("#000000", 0.18)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            Row {
              spacing: Style.space(8)
              Layout.alignment: Qt.AlignVCenter

              // Generator Mode Stats
              Row {
                visible: root.activeMode === 0
                spacing: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: "📄 " + root.textToEncode.length + " chars"
                  color: Util.alpha(Color.popups.text || Color.text, 0.65)
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                }

                Text {
                  text: "•  V" + root.detectedVersion + " (" + root.matrixSize + "×" + root.matrixSize + ")"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                }

                Text {
                  text: "•  ECC " + root.eccLevel
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                }
              }

              // Decoder Mode Stats
              Row {
                visible: root.activeMode === 1
                spacing: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: root.decodeSuccess ? ("󰄲 Decoded: " + (root.decodedFormat === "url" ? "Web URL" : (root.decodedFormat === "wifi" ? "Wi-Fi" : "Plain Text"))) : (root.isDecoding ? "󰑮 Decoding image..." : "󰅖 No QR code found")
                  color: root.decodeSuccess ? Color.accent : (root.isDecoding ? Util.alpha(Color.popups.text || Color.text, 0.65) : Util.alpha("#EF4444", 0.75))
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                  font.bold: root.decodeSuccess
                }

                Text {
                  visible: root.decodeSuccess
                  text: "•  " + root.decodedText.length + " chars"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: "monospace"
                  font.pixelSize: Style.space(7.5)
                }

                Text {
                  text: "•  zbar scanner"
                  color: Util.alpha(Color.popups.text || Color.text, 0.35)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(7.5)
                }
              }
            }

            Item { Layout.fillWidth: true }

            // RIGHT: Universal Keyboard Shortcut Chips (Matching Home Page Style)
            Row {
              Layout.alignment: Qt.AlignVCenter
              spacing: Style.space(6)

              // Ctrl+C Copy Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlCTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlCTxt
                    text: "Ctrl+C"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Copy"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Ctrl+S Save PNG Chip (Generator Mode)
              Row {
                visible: root.activeMode === 0
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlSTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlSTxt
                    text: "Ctrl+S"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Save"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Ctrl+Enter Open URL / Edit in Generator Chip (Decoder Mode)
              Row {
                visible: root.activeMode === 1 && root.decodeSuccess
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), ctrlRetTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: ctrlRetTxt
                    text: "Ctrl+↵"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: root.decodedFormat === "url" ? "Open" : (root.decodedFormat === "geo" ? "Maps" : "Edit")
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Esc Close Chip
              Row {
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  height: Style.space(16)
                  width: Math.max(Style.space(16), qrEscTxt.implicitWidth + Style.space(8))
                  radius: Style.space(3)
                  color: Util.alpha(Color.popups.text || Color.text, 0.07)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text || Color.text, 0.12)
                  Text {
                    id: qrEscTxt
                    text: "Esc"
                    color: Color.popups.text || Color.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    anchors.centerIn: parent
                  }
                }
                Text {
                  text: "Close"
                  color: Util.alpha(Color.popups.text || Color.text, 0.5)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }
        }
      }
    }
  }

  // ==========================================
  // DROPDOWN OVERLAYS (Copy, Save, Theme Presets, Logo Presets)
  // ==========================================
  Item {
    id: qrFooterDropdownOverlay
    visible: root.copyDropdownOpen || root.saveDropdownOpen || root.themePresetsDropdownOpen || root.logoPresetsDropdownOpen
    anchors.fill: parent
    z: 160

    // Click outside backdrop to dismiss menus
    MouseArea {
      anchors.fill: parent
      onWheel: function(wheel) { wheel.accepted = true }
      onClicked: function(mouse) {
        if (root.copyDropdownOpen && typeof copyMenuCard !== "undefined" && copyMenuCard) {
          var ptCopy = mapToItem(copyMenuCard, mouse.x, mouse.y)
          if (ptCopy.x >= 0 && ptCopy.x <= copyMenuCard.width && ptCopy.y >= 0 && ptCopy.y <= copyMenuCard.height) return
        }
        if (root.saveDropdownOpen && typeof saveMenuCard !== "undefined" && saveMenuCard) {
          var ptSave = mapToItem(saveMenuCard, mouse.x, mouse.y)
          if (ptSave.x >= 0 && ptSave.x <= saveMenuCard.width && ptSave.y >= 0 && ptSave.y <= saveMenuCard.height) return
        }
        if (root.themePresetsDropdownOpen && typeof themePresetsMenuCard !== "undefined" && themePresetsMenuCard) {
          var ptTheme = mapToItem(themePresetsMenuCard, mouse.x, mouse.y)
          if (ptTheme.x >= 0 && ptTheme.x <= themePresetsMenuCard.width && ptTheme.y >= 0 && ptTheme.y <= themePresetsMenuCard.height) return
        }
        if (root.logoPresetsDropdownOpen && typeof logoPresetsMenuCard !== "undefined" && logoPresetsMenuCard) {
          var ptLogo = mapToItem(logoPresetsMenuCard, mouse.x, mouse.y)
          if (ptLogo.x >= 0 && ptLogo.x <= logoPresetsMenuCard.width && ptLogo.y >= 0 && ptLogo.y <= logoPresetsMenuCard.height) return
        }

        if (typeof copyDropdownBtn !== "undefined" && copyDropdownBtn) {
          var ptBtnCopy = mapToItem(copyDropdownBtn, mouse.x, mouse.y)
          if (ptBtnCopy.x >= 0 && ptBtnCopy.x <= copyDropdownBtn.width && ptBtnCopy.y >= 0 && ptBtnCopy.y <= copyDropdownBtn.height) {
            root.copyDropdownOpen = false
            return
          }
        }
        if (typeof saveDropdownBtn !== "undefined" && saveDropdownBtn) {
          var ptBtnSave = mapToItem(saveDropdownBtn, mouse.x, mouse.y)
          if (ptBtnSave.x >= 0 && ptBtnSave.x <= saveDropdownBtn.width && ptBtnSave.y >= 0 && ptBtnSave.y <= saveDropdownBtn.height) {
            root.saveDropdownOpen = false
            return
          }
        }
        if (typeof themePresetsDropdownBtn !== "undefined" && themePresetsDropdownBtn) {
          var ptBtnTheme = mapToItem(themePresetsDropdownBtn, mouse.x, mouse.y)
          if (ptBtnTheme.x >= 0 && ptBtnTheme.x <= themePresetsDropdownBtn.width && ptBtnTheme.y >= 0 && ptBtnTheme.y <= themePresetsDropdownBtn.height) {
            root.themePresetsDropdownOpen = false
            return
          }
        }
        if (typeof logoPresetsDropdownBtn !== "undefined" && logoPresetsDropdownBtn) {
          var ptBtnLogo = mapToItem(logoPresetsDropdownBtn, mouse.x, mouse.y)
          if (ptBtnLogo.x >= 0 && ptBtnLogo.x <= logoPresetsDropdownBtn.width && ptBtnLogo.y >= 0 && ptBtnLogo.y <= logoPresetsDropdownBtn.height) {
            root.logoPresetsDropdownOpen = false
            return
          }
        }

        root.copyDropdownOpen = false
        root.saveDropdownOpen = false
        root.themePresetsDropdownOpen = false
        root.logoPresetsDropdownOpen = false
      }
    }

    // 1. Copy Menu Card
    Rectangle {
      id: copyMenuCard
      visible: root.copyDropdownOpen
      width: Style.space(168)
      height: copyItemsCol.implicitHeight + Style.space(8)
      radius: 0
      color: Util.alpha(Color.popups.background || Color.background || "#181825", 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border || "#313244", 0.8)

      x: {
        if (!root.copyDropdownOpen || typeof copyDropdownBtn === "undefined" || !copyDropdownBtn) {
          return Style.space(10)
        }
        var pt = copyDropdownBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.copyDropdownOpen || typeof copyDropdownBtn === "undefined" || !copyDropdownBtn) {
          return root.height - height - Style.space(60)
        }
        var pt = copyDropdownBtn.mapToItem(root, 0, 0)
        return pt.y - height - Style.space(4)
      }

      Column {
        id: copyItemsCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.space(4)
        spacing: 0

        // Section Title
        Rectangle {
          width: parent.width
          height: Style.space(18)
          color: "transparent"
          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            Text {
              text: "COPY TO CLIPBOARD"
              color: Util.alpha(Color.popups.text || Color.text, 0.45)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(6.5)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        // Item 1: Copy QR Image (PNG)
        Rectangle {
          width: parent.width
          height: Style.space(28)
          color: copyItemImgMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: "󰄲"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9.5)
              Layout.alignment: Qt.AlignVCenter
            }

            Column {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                text: "Copy QR Image"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
              Text {
                text: "PNG bitmap image"
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6.5)
              }
            }

            Rectangle {
              height: Style.space(14)
              width: copyImgBadgeTxt.implicitWidth + Style.space(6)
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
              Layout.alignment: Qt.AlignVCenter

              Text {
                id: copyImgBadgeTxt
                anchors.centerIn: parent
                text: "Ctrl+C"
                color: Util.alpha(Color.popups.text || Color.text, 0.6)
                font.family: "monospace"
                font.pixelSize: Style.space(6)
              }
            }
          }

          MouseArea {
            id: copyItemImgMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.copyDropdownOpen = false
              copyImageProc.running = true
            }
          }
        }

        // Divider
        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.25)
        }

        // Item 2: Copy SVG Code
        Rectangle {
          width: parent.width
          height: Style.space(28)
          color: copyItemSvgMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: "󰅍"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9.5)
              Layout.alignment: Qt.AlignVCenter
            }

            Column {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                text: "Copy SVG Code"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
              Text {
                text: "Scalable vector XML"
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6.5)
              }
            }

            Rectangle {
              height: Style.space(14)
              width: copySvgBadgeTxt.implicitWidth + Style.space(6)
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
              Layout.alignment: Qt.AlignVCenter

              Text {
                id: copySvgBadgeTxt
                anchors.centerIn: parent
                text: "SVG"
                color: Util.alpha(Color.popups.text || Color.text, 0.6)
                font.family: "monospace"
                font.pixelSize: Style.space(6)
              }
            }
          }

          MouseArea {
            id: copyItemSvgMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.copyDropdownOpen = false
              copySvgProc.running = true
            }
          }
        }

        // Divider
        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.25)
        }

        // Item 3: Copy Raw Text
        Rectangle {
          width: parent.width
          height: Style.space(28)
          color: copyItemTxtMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: "📋"
              font.pixelSize: Style.space(8.5)
              Layout.alignment: Qt.AlignVCenter
            }

            Column {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                text: "Copy Raw Text"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
              Text {
                text: "Encoded payload string"
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6.5)
              }
            }

            Rectangle {
              height: Style.space(14)
              width: copyTxtBadgeTxt.implicitWidth + Style.space(6)
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
              Layout.alignment: Qt.AlignVCenter

              Text {
                id: copyTxtBadgeTxt
                anchors.centerIn: parent
                text: "TXT"
                color: Util.alpha(Color.popups.text || Color.text, 0.6)
                font.family: "monospace"
                font.pixelSize: Style.space(6)
              }
            }
          }

          MouseArea {
            id: copyItemTxtMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.copyDropdownOpen = false
              root.copiedText(root.textToEncode)
              root.showFeedback("✓ Text copied to clipboard")
            }
          }
        }
      }
    }

    // 2. Save Menu Card
    Rectangle {
      id: saveMenuCard
      visible: root.saveDropdownOpen
      width: (root.isSeriesMode && root.totalSeriesParts > 1) ? Style.space(198) : Style.space(178)
      height: saveItemsCol.implicitHeight + Style.space(8)
      radius: 0
      color: Util.alpha(Color.popups.background || Color.background || "#181825", 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border || "#313244", 0.8)

      x: {
        if (!root.saveDropdownOpen || typeof saveDropdownBtn === "undefined" || !saveDropdownBtn) {
          return Style.space(90)
        }
        var pt = saveDropdownBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.saveDropdownOpen || typeof saveDropdownBtn === "undefined" || !saveDropdownBtn) {
          return root.height - height - Style.space(60)
        }
        var pt = saveDropdownBtn.mapToItem(root, 0, 0)
        return pt.y - height - Style.space(4)
      }

      Column {
        id: saveItemsCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.space(4)
        spacing: 0

        // Section Title
        Rectangle {
          width: parent.width
          height: Style.space(18)
          color: "transparent"
          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            Text {
              text: "EXPORT TO ~/Pictures/"
              color: Util.alpha(Color.popups.text || Color.text, 0.45)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(6.5)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        // Item 1: Save PNG Image
        Rectangle {
          width: parent.width
          height: Style.space(28)
          color: saveItemPngMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: "󰆓"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9.5)
              Layout.alignment: Qt.AlignVCenter
            }

            Column {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                text: "Save PNG Image"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
              Text {
                text: "Raster image (" + root.exportResolution + "px)"
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6.5)
              }
            }

            Rectangle {
              height: Style.space(14)
              width: savePngBadgeTxt.implicitWidth + Style.space(6)
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
              Layout.alignment: Qt.AlignVCenter

              Text {
                id: savePngBadgeTxt
                anchors.centerIn: parent
                text: "Ctrl+S"
                color: Util.alpha(Color.popups.text || Color.text, 0.6)
                font.family: "monospace"
                font.pixelSize: Style.space(6)
              }
            }
          }

          MouseArea {
            id: saveItemPngMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.saveDropdownOpen = false
              saveImageProc.running = true
            }
          }
        }

        // Divider
        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.25)
        }

        // Item 2: Save SVG File
        Rectangle {
          width: parent.width
          height: Style.space(28)
          color: saveItemSvgMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: "󰆏"
              color: Color.popups.text || Color.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9.5)
              Layout.alignment: Qt.AlignVCenter
            }

            Column {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                text: "Save SVG File"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
              Text {
                text: "Scalable vector file"
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6.5)
              }
            }

            Rectangle {
              height: Style.space(14)
              width: saveSvgBadgeTxt.implicitWidth + Style.space(6)
              radius: 0
              color: Util.alpha(Color.popups.text || Color.text, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
              Layout.alignment: Qt.AlignVCenter

              Text {
                id: saveSvgBadgeTxt
                anchors.centerIn: parent
                text: ".svg"
                color: Util.alpha(Color.popups.text || Color.text, 0.6)
                font.family: "monospace"
                font.pixelSize: Style.space(6)
              }
            }
          }

          MouseArea {
            id: saveItemSvgMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.saveDropdownOpen = false
              saveSvgProc.running = true
            }
          }
        }

        // Divider (visible when multi-part series)
        Rectangle {
          visible: root.isSeriesMode && root.totalSeriesParts > 1
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.25)
        }

        // Item 3: Save All Parts (Dedicated Series Folder)
        Rectangle {
          visible: root.isSeriesMode && root.totalSeriesParts > 1
          width: parent.width
          height: Style.space(28)
          color: saveItemAllMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: "󰉋"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(9.5)
              Layout.alignment: Qt.AlignVCenter
            }

            Column {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                text: "Save All Parts (Folder)"
                color: Color.popups.text || Color.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
              Text {
                text: "All " + root.totalSeriesParts + " parts + full text"
                color: Util.alpha(Color.popups.text || Color.text, 0.5)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6.5)
              }
            }

            Rectangle {
              height: Style.space(14)
              width: saveAllBadgeTxt.implicitWidth + Style.space(6)
              radius: 0
              color: Util.alpha(Color.accent, 0.15)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.4)
              Layout.alignment: Qt.AlignVCenter

              Text {
                id: saveAllBadgeTxt
                anchors.centerIn: parent
                text: root.totalSeriesParts + " parts"
                color: Color.accent
                font.family: "monospace"
                font.pixelSize: Style.space(6)
                font.bold: true
              }
            }
          }

          MouseArea {
            id: saveItemAllMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.saveDropdownOpen = false
              saveAllSeriesProc.running = true
            }
          }
        }
      }
    }

    // 3. Theme Presets Menu Card
    Rectangle {
      id: themePresetsMenuCard
      visible: root.themePresetsDropdownOpen
      width: (typeof themePresetsDropdownBtn !== "undefined" && themePresetsDropdownBtn) ? themePresetsDropdownBtn.width : Style.space(220)
      height: themePresetsCol.implicitHeight + Style.space(8)
      radius: 0
      color: Util.alpha(Color.popups.background || Color.background || "#181825", 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border || "#313244", 0.8)

      x: {
        if (!root.themePresetsDropdownOpen || typeof themePresetsDropdownBtn === "undefined" || !themePresetsDropdownBtn) {
          return Style.space(130)
        }
        var pt = themePresetsDropdownBtn.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.themePresetsDropdownOpen || typeof themePresetsDropdownBtn === "undefined" || !themePresetsDropdownBtn) {
          return Style.space(100)
        }
        var pt = themePresetsDropdownBtn.mapToItem(root, 0, 0)
        if (pt.y + themePresetsDropdownBtn.height + height + Style.space(8) <= root.height) {
          return pt.y + themePresetsDropdownBtn.height + Style.space(2)
        } else {
          return Math.max(Style.space(8), pt.y - height - Style.space(2))
        }
      }

      Column {
        id: themePresetsCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.space(4)
        spacing: 0

        // Section Title
        Rectangle {
          width: parent.width
          height: Style.space(18)
          color: "transparent"
          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            Text {
              text: "SELECT COLOR PRESET"
              color: Util.alpha(Color.popups.text || Color.text, 0.45)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(6.5)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        // List of presets
        Repeater {
          model: root.themePresets

          Rectangle {
            id: tPresetItem
            required property var modelData
            width: parent.width
            height: Style.space(24)
            color: root.activeThemePresetName === tPresetItem.modelData.name
                   ? Util.alpha(Color.accent, 0.2)
                   : (tItemM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.08) : "transparent")

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              // Dual color swatch (FG & BG)
              Row {
                spacing: Style.space(2)
                Layout.alignment: Qt.AlignVCenter
                Rectangle {
                  width: Style.space(10); height: Style.space(10); radius: 0
                  color: tPresetItem.modelData.fg
                  border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                }
                Rectangle {
                  width: Style.space(10); height: Style.space(10); radius: 0
                  color: tPresetItem.modelData.bg
                  border.width: 1; border.color: Util.alpha(Color.popups.border || Color.border, 0.4)
                }
              }

              Text {
                text: tPresetItem.modelData.name
                color: root.activeThemePresetName === tPresetItem.modelData.name ? Color.accent : (Color.popups.text || Color.text)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(7.5)
                font.bold: root.activeThemePresetName === tPresetItem.modelData.name
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
              }

              Text {
                visible: root.activeThemePresetName === tPresetItem.modelData.name
                text: "✓"
                color: Color.accent
                font.pixelSize: Style.space(7.5)
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
              }
            }

            MouseArea {
              id: tItemM
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.applyThemePreset(tPresetItem.modelData)
                root.themePresetsDropdownOpen = false
              }
            }
          }
        }

        // Bottom Divider
        Rectangle {
          visible: root.hasFavoriteStyle
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.25)
        }

        // My Style Quick Option (if saved)
        Rectangle {
          visible: root.hasFavoriteStyle
          width: parent.width
          height: Style.space(24)
          color: tMyStyleM.containsMouse ? Util.alpha(Color.accent, 0.15) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)
            Text { text: "★"; color: Color.accent; font.pixelSize: Style.space(8); Layout.alignment: Qt.AlignVCenter }
            Text {
              text: "Load My Style (Favorite)"
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.space(7.5)
              font.bold: true
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }
          }
          MouseArea {
            id: tMyStyleM
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.loadUserStyle()
              root.themePresetsDropdownOpen = false
            }
          }
        }
      }
    }

    // 4. Logo Presets Menu Card
    Rectangle {
      id: logoPresetsMenuCard
      visible: root.logoPresetsDropdownOpen
      width: (typeof logoPresetsDropdownBtn !== "undefined" && logoPresetsDropdownBtn) ? (logoPresetsDropdownBtn.parent ? logoPresetsDropdownBtn.parent.width : logoPresetsDropdownBtn.width) : Style.space(280)
      height: logoPresetsCol.implicitHeight + Style.space(12)
      radius: 0
      color: Util.alpha(Color.popups.background || Color.background || "#181825", 0.98)
      border.width: 1
      border.color: Util.alpha(Color.popups.border || Color.border || "#313244", 0.8)

      x: {
        if (!root.logoPresetsDropdownOpen || typeof logoPresetsDropdownBtn === "undefined" || !logoPresetsDropdownBtn) {
          return Style.space(130)
        }
        var targetObj = logoPresetsDropdownBtn.parent || logoPresetsDropdownBtn
        var pt = targetObj.mapToItem(root, 0, 0)
        return Math.max(Style.space(8), Math.min(root.width - width - Style.space(8), pt.x))
      }
      y: {
        if (!root.logoPresetsDropdownOpen || typeof logoPresetsDropdownBtn === "undefined" || !logoPresetsDropdownBtn) {
          return Style.space(100)
        }
        var pt = logoPresetsDropdownBtn.mapToItem(root, 0, 0)
        if (pt.y + logoPresetsDropdownBtn.height + height + Style.space(8) <= root.height) {
          return pt.y + logoPresetsDropdownBtn.height + Style.space(2)
        } else {
          return Math.max(Style.space(8), pt.y - height - Style.space(2))
        }
      }

      Column {
        id: logoPresetsCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.space(6)
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(6)
        spacing: Style.space(5)

        // Title Header
        RowLayout {
          width: parent.width
          Text {
            text: "SELECT EMBLEM / LOGO"
            color: Util.alpha(Color.popups.text || Color.text, 0.45)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(6.5)
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.logoPresetList.length + " presets"
            color: Util.alpha(Color.popups.text || Color.text, 0.4)
            font.family: "monospace"
            font.pixelSize: Style.space(6)
          }
        }

        // Category Filter Chips
        RowLayout {
          width: parent.width
          spacing: Style.space(3)

          Repeater {
            model: [
              { id: "all", label: "All" },
              { id: "dev", label: "Dev" },
              { id: "comm", label: "Connect" },
              { id: "life", label: "Life" },
              { id: "custom", label: "Custom" }
            ]

            Rectangle {
              id: dropCatChip
              required property var modelData
              height: Style.space(18)
              Layout.preferredWidth: dropCatTxt.implicitWidth + Style.space(8)
              radius: 0
              color: root.activeLogoCat === dropCatChip.modelData.id ? Util.alpha(Color.accent, 0.25) : (dropCatM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.1) : "transparent")
              border.width: 1
              border.color: root.activeLogoCat === dropCatChip.modelData.id ? Color.accent : Util.alpha(Color.popups.border || Color.border, 0.25)

              Text {
                id: dropCatTxt
                anchors.centerIn: parent
                text: dropCatChip.modelData.label
                color: root.activeLogoCat === dropCatChip.modelData.id ? Color.accent : (Color.popups.text || Color.text)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.space(6)
                font.bold: root.activeLogoCat === dropCatChip.modelData.id
              }
              MouseArea {
                id: dropCatM
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.activeLogoCat = dropCatChip.modelData.id
              }
            }
          }
        }

        // Divider
        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.border || Color.border, 0.2)
        }

        // Flow of Logo Preset Chips
        Flow {
          width: parent.width
          spacing: Style.space(3)

          Repeater {
            model: root.logoPresetList

            Rectangle {
              id: dropLogoChip
              required property var modelData
              visible: root.activeLogoCat === "all" || dropLogoChip.modelData.cat === root.activeLogoCat || (root.activeLogoCat === "custom" && dropLogoChip.modelData.id === "custom")
              height: Style.space(20)
              width: dropLogoRow.implicitWidth + Style.space(8)
              radius: 0
              color: (root.logoPreset === dropLogoChip.modelData.id && (root.logoPreset !== "none" || root.customLogoPath === ""))
                     ? Color.accent
                     : (dropLogoM.containsMouse ? Util.alpha(Color.popups.text || Color.text, 0.12) : Util.alpha(Color.popups.text || Color.text, 0.04))
              border.width: 1
              border.color: (root.logoPreset === dropLogoChip.modelData.id && (root.logoPreset !== "none" || root.customLogoPath === ""))
                            ? Color.accent
                            : Util.alpha(Color.popups.border || Color.border, 0.25)

              Row {
                id: dropLogoRow
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text {
                  text: dropLogoChip.modelData.icon
                  color: (root.logoPreset === dropLogoChip.modelData.id && (root.logoPreset !== "none" || root.customLogoPath === ""))
                         ? "#ffffff"
                         : (Color.popups.text || Color.text)
                  font.pixelSize: Style.space(7)
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: dropLogoChip.modelData.label
                  color: (root.logoPreset === dropLogoChip.modelData.id && (root.logoPreset !== "none" || root.customLogoPath === ""))
                         ? "#ffffff"
                         : (Color.popups.text || Color.text)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(6.5)
                  font.bold: root.logoPreset === dropLogoChip.modelData.id
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: dropLogoM
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (dropLogoChip.modelData.id === "none") {
                    root.logoPreset = "none"
                    root.customLogoPath = ""
                    if (typeof logoPathInput !== "undefined" && logoPathInput) logoPathInput.text = ""
                    if (root.eccLevel === "H") root.eccLevel = "M"
                    root.generateQr()
                    root.showFeedback("✓ Logo removed")
                  } else if (dropLogoChip.modelData.id === "custom") {
                    root.browseFiles()
                  } else {
                    root.logoPreset = dropLogoChip.modelData.id
                    root.customLogoPath = ""
                    if (typeof logoPathInput !== "undefined" && logoPathInput) logoPathInput.text = ""
                    if (root.eccLevel !== "H") root.eccLevel = "H"
                    root.generateQr()
                    root.showFeedback("✓ Logo: " + dropLogoChip.modelData.label)
                  }
                  root.logoPresetsDropdownOpen = false
                }
              }
              PanelToolTip {
                visible: dropLogoM.containsMouse
                text: dropLogoChip.modelData.id === "none" ? "Clear center logo" : "Set " + dropLogoChip.modelData.label + " as center emblem"
              }
            }
          }
        }
      }
    }
  }

  Process {
    id: pasteProc
    command: ["wl-paste", "--type", "text"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "")
        if (str) {
          root.textToEncode = str
          if (qrTextInput) qrTextInput.text = str
          root.generateQr()
          root.showFeedback("✓ Pasted from clipboard")
        }
      }
    }
  }

  Process {
    id: pasteLogoPathProc
    command: ["wl-paste", "--type", "text"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str) {
          root.customLogoPath = str
          if (logoPathInput) logoPathInput.text = str
          root.generateQr()
          root.showFeedback("✓ Logo path pasted")
        }
      }
    }
  }

  Process {
    id: pasteLogoImageProc
    command: ["sh", "-c", "TMP=\"${XDG_RUNTIME_DIR:-/tmp}/reclip-custom-logo.png\" && wl-paste -t image/png > \"$TMP\" 2>/dev/null && echo \"$TMP\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var p = String(text || "").trim()
        if (p && p.length > 0) {
          root.customLogoPath = p
          root.logoPreset = "custom"
          root.generateQr()
          root.showFeedback("✓ Clipboard image set as logo")
        } else {
          root.showFeedback("No image found in clipboard")
        }
      }
    }
  }

  Process {
    id: saveStyleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.hasFavoriteStyle = true
        root.showFeedback("★ My Style saved")
      }
    }
  }

  Process {
    id: loadStyleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str && str.length > 0) {
          try {
            root.isBatchUpdating = true
            var obj = JSON.parse(str)
            if (obj.fg !== undefined) root.qrFgColor = String(obj.fg)
            if (obj.bg !== undefined) root.qrBgColor = String(obj.bg)
            if (obj.outerEye !== undefined) root.qrOuterEyeColor = String(obj.outerEye)
            if (obj.innerEye !== undefined) root.qrInnerEyeColor = String(obj.innerEye)
            if (obj.timing !== undefined) root.qrTimingColor = String(obj.timing)
            if (obj.alignment !== undefined) root.qrAlignmentColor = String(obj.alignment)
            if (obj.gradient !== undefined) root.gradientType = String(obj.gradient)
            if (obj.gradientColor !== undefined) root.gradientColor = String(obj.gradientColor)
            if (obj.moduleShape !== undefined) root.moduleShape = String(obj.moduleShape)
            if (obj.eyeShape !== undefined) root.eyeShape = String(obj.eyeShape)
            if (obj.frameStyle !== undefined) root.frameStyle = String(obj.frameStyle)
            if (obj.frameText !== undefined) root.frameText = String(obj.frameText)
            if (obj.frameSubtext !== undefined) root.frameSubtext = String(obj.frameSubtext)
            if (obj.frameRadius !== undefined) root.frameRadius = parseInt(obj.frameRadius) || 0
            if (obj.frameColor !== undefined) root.frameColor = String(obj.frameColor)
            if (obj.logoPreset !== undefined) root.logoPreset = String(obj.logoPreset)
            if (obj.logoShape !== undefined) root.logoShape = String(obj.logoShape)
            if (obj.logoSize !== undefined) root.logoSize = parseFloat(obj.logoSize) || 0.22
            if (obj.logoBgColor !== undefined) root.logoBgColor = String(obj.logoBgColor)
            if (obj.logoBorderColor !== undefined) root.logoBorderColor = String(obj.logoBorderColor)
            if (obj.logoBorderWidth !== undefined) root.logoBorderWidth = parseInt(obj.logoBorderWidth) || 0
            if (obj.logoPadding !== undefined) root.logoPadding = parseFloat(obj.logoPadding) || 0.70
            if (obj.customLogoPath !== undefined) root.customLogoPath = String(obj.customLogoPath)
            root.activeThemePresetName = "My Style"
            root.isBatchUpdating = false
            root.requestGenerateQr()
            root.showFeedback("★ My Style loaded")
          } catch (e) {
            root.isBatchUpdating = false
            root.showFeedback("Failed to load saved style")
          }
        }
      }
    }
  }

  Process {
    id: checkStyleProc
    command: ["test", "-f", root.pluginDir + "/user-style.json"]
    onExited: function(exitCode) {
      root.hasFavoriteStyle = (exitCode === 0)
    }
  }

  Component.onCompleted: {
    checkStyleProc.running = true
  }
}
