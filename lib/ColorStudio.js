// Complete Color Studio Library for ReClip Omarchy
// 100% parity with ReClip original ColorPageUtils.ts

function hexToRgb(hex) {
  var clean = String(hex || "").trim().replace("#", "")
  if (clean.length === 3) clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2]
  if (clean.length < 6) return null
  var r = parseInt(clean.substring(0, 2), 16)
  var g = parseInt(clean.substring(2, 4), 16)
  var b = parseInt(clean.substring(4, 6), 16)
  if (isNaN(r) || isNaN(g) || isNaN(b)) return null
  return { r: r, g: g, b: b }
}

function rgbToHex(r, g, b) {
  var clamp = function(v) { return Math.max(0, Math.min(255, Math.round(v))) }
  var cr = clamp(r).toString(16).padStart(2, "0")
  var cg = clamp(g).toString(16).padStart(2, "0")
  var cb = clamp(b).toString(16).padStart(2, "0")
  return ("#" + cr + cg + cb).toUpperCase()
}

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b)
  var h = 0, s = 0, l = (max + min) / 2
  if (max !== min) {
    var d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break
      case g: h = ((b - r) / d + 2) / 6; break
      case b: h = ((r - g) / d + 4) / 6; break
    }
  }
  return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) }
}

function hslToRgb(h, s, l) {
  h = (h % 360 + 360) % 360 / 360
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

function rgbToHsv(r, g, b) {
  r /= 255; g /= 255; b /= 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b)
  var h = 0, v = max, d = max - min
  var s = max === 0 ? 0 : d / max
  if (max !== min) {
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break
      case g: h = ((b - r) / d + 2) / 6; break
      case b: h = ((r - g) / d + 4) / 6; break
    }
  }
  return { h: Math.round(h * 360), s: Math.round(s * 100), v: Math.round(v * 100) }
}

function rgbToCmyk(r, g, b) {
  r /= 255; g /= 255; b /= 255
  var k = 1 - Math.max(r, g, b)
  if (k === 1) return { c: 0, m: 0, y: 0, k: 100 }
  return {
    c: Math.round((1 - r - k) / (1 - k) * 100),
    m: Math.round((1 - g - k) / (1 - k) * 100),
    y: Math.round((1 - b - k) / (1 - k) * 100),
    k: Math.round(k * 100)
  }
}

// HWB (Hue, Whiteness, Blackness)
function rgbToHwb(r, g, b) {
  r /= 255; g /= 255; b /= 255
  var max = Math.max(r, g, b)
  var min = Math.min(r, g, b)
  var hsl = rgbToHsl(Math.round(r * 255), Math.round(g * 255), Math.round(b * 255))
  return {
    h: hsl.h,
    w: Math.round(min * 100),
    b: Math.round((1 - max) * 100)
  }
}

// XYZ (sRGB D65)
function rgbToXyz(r, g, b) {
  var rLinear = r / 255, gLinear = g / 255, bLinear = b / 255
  rLinear = rLinear > 0.04045 ? Math.pow((rLinear + 0.055) / 1.055, 2.4) : rLinear / 12.92
  gLinear = gLinear > 0.04045 ? Math.pow((gLinear + 0.055) / 1.055, 2.4) : gLinear / 12.92
  bLinear = bLinear > 0.04045 ? Math.pow((bLinear + 0.055) / 1.055, 2.4) : bLinear / 12.92
  return {
    x: rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375,
    y: rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750,
    z: rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041
  }
}

function xyzToRgb(x, y, z) {
  var r = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
  var g = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
  var b = x * 0.0556434 + y * -0.2040259 + z * 1.0572252
  r = r > 0.0031308 ? 1.055 * Math.pow(r, 1 / 2.4) - 0.055 : 12.92 * r
  g = g > 0.0031308 ? 1.055 * Math.pow(g, 1 / 2.4) - 0.055 : 12.92 * g
  b = b > 0.0031308 ? 1.055 * Math.pow(b, 1 / 2.4) - 0.055 : 12.92 * b
  return {
    r: Math.round(Math.max(0, Math.min(255, r * 255))),
    g: Math.round(Math.max(0, Math.min(255, g * 255))),
    b: Math.round(Math.max(0, Math.min(255, b * 255)))
  }
}

// CIE LAB
function rgbToLab(r, g, b) {
  var xyz = rgbToXyz(r, g, b)
  var refX = 0.95047, refY = 1.0, refZ = 1.08883
  var x = xyz.x / refX, y = xyz.y / refY, z = xyz.z / refZ
  var epsilon = 0.008856, kappa = 903.3
  x = x > epsilon ? Math.pow(x, 1 / 3) : (kappa * x + 16) / 116
  y = y > epsilon ? Math.pow(y, 1 / 3) : (kappa * y + 16) / 116
  z = z > epsilon ? Math.pow(z, 1 / 3) : (kappa * z + 16) / 116
  return {
    l: 116 * y - 16,
    a: 500 * (x - y),
    b: 200 * (y - z)
  }
}

function labToRgb(l, a, labB) {
  var refX = 0.95047, refY = 1.0, refZ = 1.08883
  var y = (l + 16) / 116
  var x = a / 500 + y
  var z = y - labB / 200
  var epsilon = 0.008856, kappa = 903.3
  var x3 = Math.pow(x, 3), y3 = Math.pow(y, 3), z3 = Math.pow(z, 3)
  x = x3 > epsilon ? x3 : (116 * x - 16) / kappa
  y = l > kappa * epsilon ? y3 : l / kappa
  z = z3 > epsilon ? z3 : (116 * z - 16) / kappa
  return xyzToRgb(x * refX, y * refY, z * refZ)
}

// CIE LCH
function rgbToLch(r, g, b) {
  var lab = rgbToLab(r, g, b)
  var c = Math.sqrt(lab.a * lab.a + lab.b * lab.b)
  var h = Math.atan2(lab.b, lab.a) * 180 / Math.PI
  if (h < 0) h += 360
  return { l: lab.l, c: c, h: h }
}

// OKLAB & OKLCH
function rgbToOklab(r, g, b) {
  var lr = r / 255, lg = g / 255, lb = b / 255
  lr = lr <= 0.04045 ? lr / 12.92 : Math.pow((lr + 0.055) / 1.055, 2.4)
  lg = lg <= 0.04045 ? lg / 12.92 : Math.pow((lg + 0.055) / 1.055, 2.4)
  lb = lb <= 0.04045 ? lb / 12.92 : Math.pow((lb + 0.055) / 1.055, 2.4)

  var l_ = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
  var m_ = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
  var s_ = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)

  return {
    l: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    a: 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
  }
}

function oklabToRgb(l, a, b) {
  var l_ = l + 0.3963377774 * a + 0.2158037573 * b
  var m_ = l - 0.1055613458 * a - 0.0638541728 * b
  var s_ = l - 0.0894841775 * a - 1.2914855480 * b

  var lr = Math.pow(l_, 3), mr = Math.pow(m_, 3), sr = Math.pow(s_, 3)
  var r = 4.0767416621 * lr - 3.3077115913 * mr + 0.2309699292 * sr
  var g = -1.2684380046 * lr + 2.6097574011 * mr - 0.3413193965 * sr
  var bVal = -0.0041960863 * lr - 0.7034186147 * mr + 1.7076147010 * sr

  r = r <= 0.0031308 ? 12.92 * r : 1.055 * Math.pow(r, 1 / 2.4) - 0.055
  g = g <= 0.0031308 ? 12.92 * g : 1.055 * Math.pow(g, 1 / 2.4) - 0.055
  bVal = bVal <= 0.0031308 ? 12.92 * bVal : 1.055 * Math.pow(bVal, 1 / 2.4) - 0.055

  return {
    r: Math.round(Math.max(0, Math.min(255, r * 255))),
    g: Math.round(Math.max(0, Math.min(255, g * 255))),
    b: Math.round(Math.max(0, Math.min(255, bVal * 255)))
  }
}

function rgbToOklch(r, g, b) {
  var oklab = rgbToOklab(r, g, b)
  var c = Math.sqrt(oklab.a * oklab.a + oklab.b * oklab.b)
  var h = Math.atan2(oklab.b, oklab.a) * 180 / Math.PI
  if (h < 0) h += 360
  return { l: oklab.l, c: c, h: h }
}

function oklchToRgb(l, c, h) {
  var hRad = h * Math.PI / 180
  var a = c * Math.cos(hRad)
  var b = c * Math.sin(hRad)
  return oklabToRgb(l, a, b)
}

// Tints & Shades
function generateTints(hex, count) {
  var rgb = hexToRgb(hex)
  if (!rgb) return []
  var n = count || 10
  var tints = []
  for (var i = 1; i <= n; i++) {
    var factor = i / (n + 1)
    tints.push(rgbToHex(
      Math.round(rgb.r + (255 - rgb.r) * factor),
      Math.round(rgb.g + (255 - rgb.g) * factor),
      Math.round(rgb.b + (255 - rgb.b) * factor)
    ))
  }
  return tints
}

function generateShades(hex, count) {
  var rgb = hexToRgb(hex)
  if (!rgb) return []
  var n = count || 10
  var shades = []
  for (var i = 1; i <= n; i++) {
    var factor = 1 - (i / (n + 1))
    shades.push(rgbToHex(
      Math.round(rgb.r * factor),
      Math.round(rgb.g * factor),
      Math.round(rgb.b * factor)
    ))
  }
  return shades
}

// Mixing & Blending
function mixColors(color1, color2, ratio) {
  var rgb1 = hexToRgb(color1)
  var rgb2 = hexToRgb(color2)
  if (!rgb1 || !rgb2) return color1
  var r = Math.round(rgb1.r * (1 - ratio) + rgb2.r * ratio)
  var g = Math.round(rgb1.g * (1 - ratio) + rgb2.g * ratio)
  var b = Math.round(rgb1.b * (1 - ratio) + rgb2.b * ratio)
  return rgbToHex(r, g, b)
}

function mixColorsLab(color1, color2, ratio) {
  var rgb1 = hexToRgb(color1), rgb2 = hexToRgb(color2)
  if (!rgb1 || !rgb2) return color1
  var lab1 = rgbToLab(rgb1.r, rgb1.g, rgb1.b)
  var lab2 = rgbToLab(rgb2.r, rgb2.g, rgb2.b)
  var l = lab1.l * (1 - ratio) + lab2.l * ratio
  var a = lab1.a * (1 - ratio) + lab2.a * ratio
  var b = lab1.b * (1 - ratio) + lab2.b * ratio
  var res = labToRgb(l, a, b)
  return rgbToHex(res.r, res.g, res.b)
}

function mixColorsOklch(color1, color2, ratio) {
  var rgb1 = hexToRgb(color1), rgb2 = hexToRgb(color2)
  if (!rgb1 || !rgb2) return color1
  var oklch1 = rgbToOklch(rgb1.r, rgb1.g, rgb1.b)
  var oklch2 = rgbToOklch(rgb2.r, rgb2.g, rgb2.b)
  var h1 = oklch1.h, h2 = oklch2.h
  if (Math.abs(h2 - h1) > 180) {
    if (h2 > h1) h1 += 360
    else h2 += 360
  }
  var l = oklch1.l * (1 - ratio) + oklch2.l * ratio
  var c = oklch1.c * (1 - ratio) + oklch2.c * ratio
  var h = h1 * (1 - ratio) + h2 * ratio
  if (h >= 360) h -= 360
  var res = oklchToRgb(l, c, h)
  return rgbToHex(res.r, res.g, res.b)
}

var BLEND_NEUTRAL = {
  normal: "#000000",
  multiply: "#ffffff",
  screen: "#000000",
  overlay: "#808080",
  "soft-light": "#808080",
  "hard-light": "#808080",
  difference: "#000000",
  exclusion: "#000000"
}

function blendColors(base, blend, mode) {
  var baseRgb = hexToRgb(base), blendRgb = hexToRgb(blend)
  if (!baseRgb || !blendRgb) return base
  var blendChannel = function(a, b, m) {
    a /= 255; b /= 255
    var result
    switch (m) {
      case "multiply": result = a * b; break
      case "screen": result = 1 - (1 - a) * (1 - b); break
      case "overlay": result = a < 0.5 ? 2 * a * b : 1 - 2 * (1 - a) * (1 - b); break
      case "soft-light":
        result = b < 0.5 ? a - (1 - 2 * b) * a * (1 - a) : a + (2 * b - 1) * (a < 0.25 ? ((16 * a - 12) * a + 4) * a : Math.sqrt(a) - a); break
      case "hard-light": result = b < 0.5 ? 2 * a * b : 1 - 2 * (1 - a) * (1 - b); break
      case "difference": result = Math.abs(a - b); break
      case "exclusion": result = a + b - 2 * a * b; break
      default: result = b
    }
    return Math.round(result * 255)
  }
  return rgbToHex(
    blendChannel(baseRgb.r, blendRgb.r, mode),
    blendChannel(baseRgb.g, blendRgb.g, mode),
    blendChannel(baseRgb.b, blendRgb.b, mode)
  )
}

function blendWithStrength(base, blend, mode, strength) {
  if (mode === "normal") return mixColors(base, blend, strength)
  var neutral = BLEND_NEUTRAL[mode] || "#808080"
  var adjustedBlend = mixColors(neutral, blend, strength)
  return blendColors(base, adjustedBlend, mode)
}

function generateScale(color1, color2, steps) {
  var n = Math.max(2, steps || 5)
  var scale = []
  for (var i = 0; i < n; i++) {
    scale.push(mixColors(color1, color2, i / (n - 1)))
  }
  return scale
}

function generateScaleLab(color1, color2, steps) {
  var n = Math.max(2, steps || 5)
  var scale = []
  for (var i = 0; i < n; i++) {
    scale.push(mixColorsLab(color1, color2, i / (n - 1)))
  }
  return scale
}

function generateScaleOklch(color1, color2, steps) {
  var n = Math.max(2, steps || 5)
  var scale = []
  for (var i = 0; i < n; i++) {
    scale.push(mixColorsOklch(color1, color2, i / (n - 1)))
  }
  return scale
}

// Luminance & Contrast
function getLuminance(r, g, b) {
  var a = [r, g, b].map(function(v) {
    v /= 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  })
  return a[0] * 0.2126 + a[1] * 0.7152 + a[2] * 0.0722
}

function getContrastRatio(hex1, hex2) {
  var rgb1 = hexToRgb(hex1), rgb2 = hexToRgb(hex2)
  if (!rgb1 || !rgb2) return 1
  var l1 = getLuminance(rgb1.r, rgb1.g, rgb1.b)
  var l2 = getLuminance(rgb2.r, rgb2.g, rgb2.b)
  var brightest = Math.max(l1, l2), darkest = Math.min(l1, l2)
  return Math.round(((brightest + 0.05) / (darkest + 0.05)) * 100) / 100
}

// APCA Contrast Calculation
function getApcaContrast(textHex, bgHex) {
  var text = hexToRgb(textHex), bg = hexToRgb(bgHex)
  if (!text || !bg) return 0

  var sRGBtoY = function(rgb) {
    var mainTRC = 2.4
    var Rco = 0.2126729, Gco = 0.7151522, Bco = 0.0721750
    var simpleExp = function(c) { return Math.pow(c / 255, mainTRC) }
    return Rco * simpleExp(rgb.r) + Gco * simpleExp(rgb.g) + Bco * simpleExp(rgb.b)
  }

  var Ytext = sRGBtoY(text), Ybg = sRGBtoY(bg)
  var normBG = 0.56, normTXT = 0.57
  var revTXT = 0.62, revBG = 0.65
  var blkThrs = 0.022, blkClmp = 1.414
  var scaleBoW = 1.14, scaleWoB = 1.14
  var loClip = 0.1, deltaYmin = 0.0005

  var Ytxt = Ytext > blkThrs ? Ytext : Ytext + Math.pow(blkThrs - Ytext, blkClmp)
  var Ybgc = Ybg > blkThrs ? Ybg : Ybg + Math.pow(blkThrs - Ybg, blkClmp)

  if (Math.abs(Ybgc - Ytxt) < deltaYmin) return 0

  var SAPC = 0, outputContrast = 0
  if (Ybgc > Ytxt) {
    SAPC = (Math.pow(Ybgc, normBG) - Math.pow(Ytxt, normTXT)) * scaleBoW
    outputContrast = SAPC < loClip ? 0 : SAPC * 100
  } else {
    SAPC = (Math.pow(Ybgc, revBG) - Math.pow(Ytxt, revTXT)) * scaleWoB
    outputContrast = SAPC > -loClip ? 0 : SAPC * 100
  }
  return Math.round(outputContrast * 10) / 10
}

function calculateMinFontSize(contrast, isLarge) {
  if (contrast >= 7) return 12
  if (contrast >= 4.5) return isLarge ? 14 : 18
  if (contrast >= 3) return 24
  return 36
}

function suggestAccessibleColor(bg, fg, preference, targetRatio) {
  var pref = preference || "lighter"
  var target = targetRatio || 4.5
  var fgRgb = hexToRgb(fg)
  if (!fgRgb) return fg
  var hsl = rgbToHsl(fgRgb.r, fgRgb.g, fgRgb.b)

  var check = function(l) {
    var testRgb = hslToRgb(hsl.h, hsl.s, l)
    var testHex = rgbToHex(testRgb.r, testRgb.g, testRgb.b)
    return getContrastRatio(bg, testHex) >= target ? testHex : null
  }

  if (check(hsl.l)) return fg

  for (var i = 1; i <= 100; i++) {
    if (pref === "any" || pref === "lighter") {
      var lUp = Math.min(100, Math.floor(hsl.l + i))
      var resUp = check(lUp)
      if (resUp) return resUp
    }
    if (pref === "any" || pref === "darker") {
      var lDown = Math.max(0, Math.ceil(hsl.l - i))
      var resDown = check(lDown)
      if (resDown) return resDown
    }
  }
  if (pref === "lighter") return "#FFFFFF"
  if (pref === "darker") return "#000000"
  var wc = getContrastRatio(bg, "#FFFFFF"), bc = getContrastRatio(bg, "#000000")
  return wc >= bc ? "#FFFFFF" : "#000000"
}

// Color Blindness Simulation
function simulateColorBlindness(r, g, b, type) {
  var matrices = {
    protanopia: [0.567, 0.433, 0, 0.558, 0.442, 0, 0, 0.242, 0.758],
    deuteranopia: [0.625, 0.375, 0, 0.7, 0.3, 0, 0, 0.3, 0.7],
    tritanopia: [0.95, 0.05, 0, 0, 0.433, 0.567, 0, 0.475, 0.525],
    achromatopsia: [0.299, 0.587, 0.114, 0.299, 0.587, 0.114, 0.299, 0.587, 0.114]
  }
  var m = matrices[type] || matrices.achromatopsia
  var R = r * m[0] + g * m[1] + b * m[2]
  var G = r * m[3] + g * m[4] + b * m[5]
  var B = r * m[6] + g * m[7] + b * m[8]
  return {
    r: Math.round(Math.min(255, Math.max(0, R))),
    g: Math.round(Math.min(255, Math.max(0, G))),
    b: Math.round(Math.min(255, Math.max(0, B)))
  }
}

// Naming & Industry Palettes
var COLOR_NAMES = {
  "#000000": "Black", "#FFFFFF": "White", "#FF0000": "Red", "#00FF00": "Lime", "#0000FF": "Blue",
  "#FFFF00": "Yellow", "#00FFFF": "Cyan", "#FF00FF": "Magenta", "#C0C0C0": "Silver",
  "#808080": "Gray", "#800000": "Maroon", "#808000": "Olive", "#008000": "Green",
  "#800080": "Purple", "#008080": "Teal", "#000080": "Navy", "#6366F1": "Indigo",
  "#EF4444": "Tailwind Red", "#3B82F6": "Tailwind Blue", "#10B981": "Emerald",
  "#F59E0B": "Amber", "#EC4899": "Pink", "#8B5CF6": "Violet"
}

function findNearestColorName(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return "Unknown"
  var minDist = Infinity, name = "Unknown"
  for (var cHex in COLOR_NAMES) {
    var cRgb = hexToRgb(cHex)
    if (cRgb) {
      var dist = Math.sqrt(Math.pow(rgb.r - cRgb.r, 2) + Math.pow(rgb.g - cRgb.g, 2) + Math.pow(rgb.b - cRgb.b, 2))
      if (dist < minDist) { minDist = dist; name = COLOR_NAMES[cHex] }
    }
  }
  return name
}

var TAILWIND_COLORS = {
  "slate-50": "#F8FAFC", "slate-500": "#64748B", "slate-900": "#0F172A",
  "red-500": "#EF4444", "orange-500": "#F97316", "amber-500": "#F59E0B",
  "yellow-500": "#EAB308", "lime-500": "#84CC16", "green-500": "#22C55E",
  "emerald-500": "#10B981", "teal-500": "#14B8A6", "cyan-500": "#06B6D4",
  "sky-500": "#0EA5E9", "blue-500": "#3B82F6", "indigo-500": "#6366F1",
  "violet-500": "#8B5CF6", "purple-500": "#A855F7", "fuchsia-500": "#D946EF",
  "pink-500": "#EC4899", "rose-500": "#F43F5E"
}

function findNearestTailwind(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return null
  var minDist = Infinity, match = ""
  for (var tName in TAILWIND_COLORS) {
    var cRgb = hexToRgb(TAILWIND_COLORS[tName])
    if (cRgb) {
      var dist = Math.sqrt(Math.pow(rgb.r - cRgb.r, 2) + Math.pow(rgb.g - cRgb.g, 2) + Math.pow(rgb.b - cRgb.b, 2))
      if (dist < minDist) { minDist = dist; match = tName }
    }
  }
  return match
}

var PANTONE_COLORS = {
  "PMS 186 C": "#C8102E", "PMS 185 C": "#E4002B", "PMS 199 C": "#D50032",
  "PMS 032 C": "#F4364C", "PMS 021 C": "#FE5000", "PMS 151 C": "#FF8200",
  "PMS 123 C": "#FFC72C", "PMS 116 C": "#FFCD00", "PMS 109 C": "#FFD100",
  "PMS 382 C": "#C4D600", "PMS 375 C": "#97D700", "PMS 361 C": "#43B02A",
  "PMS 347 C": "#009A44", "PMS 3268 C": "#00AB84", "PMS 320 C": "#009CA6",
  "PMS 3005 C": "#0077C8", "PMS 300 C": "#005EB8", "PMS 286 C": "#0032A0",
  "PMS 2728 C": "#001489", "PMS 2685 C": "#56368A", "PMS 2607 C": "#500778",
  "PMS 254 C": "#84329B", "PMS 232 C": "#F74D8B", "PMS 219 C": "#E31C79",
  "PMS 485 C": "#DA291C", "PMS 711 C": "#AA8066", "PMS 476 C": "#4E3524",
  "PMS Black C": "#2D2926", "PMS Cool Gray 11 C": "#53565A", "PMS Cool Gray 5 C": "#B1B3B3",
  "PMS White": "#FFFFFF", "PMS 7421 C": "#612141", "PMS 7462 C": "#00558C",
  "PMS 7741 C": "#44883E", "PMS 7548 C": "#FFC600", "PMS 7579 C": "#DC4405"
}

var RAL_COLORS = {
  "RAL 1000": "#BEBD7F", "RAL 1001": "#C2B078", "RAL 1002": "#C6A664",
  "RAL 1003": "#E5BE01", "RAL 1004": "#CDA434", "RAL 1005": "#A98307",
  "RAL 2000": "#ED760E", "RAL 2001": "#C93C20", "RAL 2002": "#CB2821",
  "RAL 3000": "#AF2B1E", "RAL 3001": "#A52019", "RAL 3002": "#A2231D",
  "RAL 3003": "#9B111E", "RAL 4001": "#6D3F5B", "RAL 4002": "#922B3E",
  "RAL 5000": "#354D73", "RAL 5002": "#20214F", "RAL 5003": "#1D1E33",
  "RAL 5005": "#1E2460", "RAL 5010": "#0E294B", "RAL 5015": "#2271B3",
  "RAL 6000": "#316650", "RAL 6001": "#287233", "RAL 6002": "#2D572C",
  "RAL 7000": "#78858B", "RAL 7001": "#8A9597", "RAL 7035": "#D7D7D7",
  "RAL 8000": "#826C34", "RAL 8001": "#955F20", "RAL 9001": "#FDF4E3",
  "RAL 9002": "#E7EBDA", "RAL 9003": "#F4F4F4", "RAL 9005": "#0A0A0A",
  "RAL 9010": "#FFFFFF", "RAL 9016": "#F6F6F6", "RAL 9017": "#1E1E1E"
}

var NCS_COLORS = {
  "S 0500-N": "#F5F2E7", "S 0502-Y": "#F4F1E0", "S 0505-Y10R": "#F7EFE0",
  "S 1000-N": "#E8E4D8", "S 1002-Y": "#E5E1D0", "S 1005-Y20R": "#E8DFD0",
  "S 1500-N": "#D8D4C8", "S 2000-N": "#C8C4B8", "S 2002-Y": "#CAC6B5",
  "S 2005-Y30R": "#D4C8B5", "S 2010-Y30R": "#D8C4A8", "S 2020-Y30R": "#D8BC98",
  "S 3000-N": "#ACA8A0", "S 4000-N": "#908C85", "S 4502-B": "#7E8890",
  "S 5000-N": "#787470", "S 6000-N": "#605C58", "S 7000-N": "#4A4644",
  "S 8000-N": "#353230", "S 9000-N": "#201F1E", "S 0520-Y10R": "#F7E8C8",
  "S 0540-Y10R": "#F7DCA8", "S 0560-Y10R": "#F7D088", "S 1070-Y10R": "#E8B450",
  "S 2060-Y10R": "#D4A040", "S 3060-Y10R": "#B88C30", "S 2060-B": "#0078C8"
}

function findNearestFromPalette(hex, palette) {
  var rgb = hexToRgb(hex)
  if (!rgb) return null
  var minDist = Infinity, match = ""
  for (var name in palette) {
    var cRgb = hexToRgb(palette[name])
    if (cRgb) {
      var dist = Math.sqrt(Math.pow(rgb.r - cRgb.r, 2) + Math.pow(rgb.g - cRgb.g, 2) + Math.pow(rgb.b - cRgb.b, 2))
      if (dist < minDist) { minDist = dist; match = name }
    }
  }
  return minDist < 100 ? match : null
}

function findNearestPantone(hex) { return findNearestFromPalette(hex, PANTONE_COLORS) }
function findNearestRal(hex) { return findNearestFromPalette(hex, RAL_COLORS) }
function findNearestNcs(hex) { return findNearestFromPalette(hex, NCS_COLORS) }

// Temperature & Web-safe
function getColorTemperature(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return { type: "neutral", kelvin: 6500 }
  var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)
  var h = hsl.h, type = "neutral", kelvin = 6500
  if ((h >= 0 && h <= 60) || (h >= 300 && h <= 360)) {
    type = "warm"
    kelvin = 2700 + ((60 - Math.min(h, 60)) / 60) * 2000
  } else if (h >= 180 && h <= 270) {
    type = "cool"
    kelvin = 8000 + ((h - 180) / 90) * 4000
  } else if (h > 60 && h < 180) {
    type = hsl.s < 30 ? "neutral" : (h < 120 ? "warm" : "cool")
    kelvin = 5500 + ((h - 60) / 120) * 2000
  }
  if (hsl.s < 10) { type = "neutral"; kelvin = 6500 }
  return { type: type, kelvin: Math.round(kelvin) }
}

function getWebsafeColor(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return hex
  var ws = function(c) { return Math.round(c / 51) * 51 }
  return rgbToHex(ws(rgb.r), ws(rgb.g), ws(rgb.b))
}

function getHexShorthand(hex) {
  var clean = String(hex || "").trim().replace("#", "")
  if (clean.length !== 6) return null
  if (clean[0] === clean[1] && clean[2] === clean[3] && clean[4] === clean[5]) {
    return "#" + clean[0] + clean[2] + clean[4]
  }
  return null
}

// Developer Code Formatting
function formatCode(hex, format) {
  var rgb = hexToRgb(hex)
  if (!rgb) return hex
  var cleanHex = rgbToHex(rgb.r, rgb.g, rgb.b)
  var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)
  var hwb = rgbToHwb(rgb.r, rgb.g, rgb.b)
  var lab = rgbToLab(rgb.r, rgb.g, rgb.b)
  var lch = rgbToLch(rgb.r, rgb.g, rgb.b)
  var oklch = rgbToOklch(rgb.r, rgb.g, rgb.b)

  switch (format) {
    case "swift":
      return "UIColor(red: " + (rgb.r / 255).toFixed(3) + ", green: " + (rgb.g / 255).toFixed(3) + ", blue: " + (rgb.b / 255).toFixed(3) + ", alpha: 1.0)"
    case "swiftui":
      return "Color(red: " + (rgb.r / 255).toFixed(3) + ", green: " + (rgb.g / 255).toFixed(3) + ", blue: " + (rgb.b / 255).toFixed(3) + ")"
    case "flutter":
      return "Color(0xFF" + cleanHex.substring(1) + ")"
    case "kotlin":
      return "Color(0xFF" + cleanHex.substring(1) + ")"
    case "android-xml":
      return "<color name=\"color_" + cleanHex.substring(1).toLowerCase() + "\">#FF" + cleanHex.substring(1) + "</color>"
    case "csharp":
      return "Color.FromArgb(255, " + rgb.r + ", " + rgb.g + ", " + rgb.b + ")"
    case "java-awt":
      return "new Color(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ")"
    case "objective-c":
      return "[UIColor colorWithRed:" + (rgb.r / 255).toFixed(3) + " green:" + (rgb.g / 255).toFixed(3) + " blue:" + (rgb.b / 255).toFixed(3) + " alpha:1.0]"
    case "css-variable":
      return "--color-primary: " + cleanHex + ";"
    case "sass-variable":
      return "$color-primary: " + cleanHex + ";"
    case "tailwind":
      return findNearestTailwind(hex) || hex
    default:
      return cleanHex
  }
}

// Enhanced Harmonies
function generateHarmoniesAdvanced(hex, angleOffset) {
  var offset = angleOffset || 0
  var rgb = hexToRgb(hex)
  if (!rgb) return {}
  var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)

  var createColor = function(hueOffset) {
    var h = (hsl.h + hueOffset + offset + 360) % 360
    var newRgb = hslToRgb(h, hsl.s, hsl.l)
    return rgbToHex(newRgb.r, newRgb.g, newRgb.b)
  }

  var mono1 = hslToRgb(hsl.h, hsl.s, Math.max(0, hsl.l - 30))
  var mono2 = hslToRgb(hsl.h, hsl.s, Math.max(0, hsl.l - 15))
  var mono4 = hslToRgb(hsl.h, hsl.s, Math.min(100, hsl.l + 15))
  var mono5 = hslToRgb(hsl.h, hsl.s, Math.min(100, hsl.l + 30))

  return {
    complementary: [hex, createColor(180)],
    analogous: [createColor(-30), hex, createColor(30)],
    triadic: [hex, createColor(120), createColor(240)],
    split: [hex, createColor(150), createColor(210)],
    tetradic: [hex, createColor(90), createColor(180), createColor(270)],
    monochromatic: [
      rgbToHex(mono1.r, mono1.g, mono1.b),
      rgbToHex(mono2.r, mono2.g, mono2.b),
      hex,
      rgbToHex(mono4.r, mono4.g, mono4.b),
      rgbToHex(mono5.r, mono5.g, mono5.b)
    ],
    doubleSplit: [hex, createColor(60), createColor(180), createColor(240)]
  }
}

// Gradient Presets
var GRADIENT_PRESETS = [
  { name: "Sunset", colors: ["#FF6B6B", "#FFD93D", "#FF8E3C"], angle: 135 },
  { name: "Ocean", colors: ["#667EEA", "#764BA2", "#66A6FF"], angle: 135 },
  { name: "Forest", colors: ["#134E5E", "#71B280"], angle: 135 },
  { name: "Aurora", colors: ["#00D2FF", "#3A7BD5", "#00D2FF"], angle: 90 },
  { name: "Midnight", colors: ["#232526", "#414345"], angle: 180 },
  { name: "Candy", colors: ["#D53369", "#DAAE51"], angle: 135 },
  { name: "Peach", colors: ["#ED6EA0", "#EC8C69"], angle: 135 },
  { name: "Mojito", colors: ["#1D976C", "#93F9B9"], angle: 135 },
  { name: "Frost", colors: ["#000428", "#004E92"], angle: 180 },
  { name: "Stripe", colors: ["#1FA2FF", "#12D8FA", "#A6FFCB"], angle: 90 },
  { name: "Lavender", colors: ["#E0C3FC", "#8EC5FC"], angle: 135 },
  { name: "Fire", colors: ["#F12711", "#F5AF19"], angle: 135 },
  { name: "Emerald", colors: ["#348F50", "#56B4D3"], angle: 135 },
  { name: "Royal", colors: ["#141E30", "#243B55"], angle: 135 },
  { name: "Rose", colors: ["#FF0844", "#FFB199"], angle: 135 },
  { name: "Grape", colors: ["#5B247A", "#1BCEDF"], angle: 135 },
  { name: "Noir", colors: ["#000000", "#434343"], angle: 180 },
  { name: "Sky", colors: ["#56CCF2", "#2F80ED"], angle: 180 }
]

function generateGradient(type, angle, stops) {
  var sorted = stops.slice().sort(function(a, b) { return a.position - b.position })
  var stopsStr = sorted.map(function(s) { return s.color + " " + s.position + "%" }).join(", ")
  if (type === "linear") return "linear-gradient(" + angle + "deg, " + stopsStr + ")"
  if (type === "conic") return "conic-gradient(from " + angle + "deg, " + stopsStr + ")"
  return "radial-gradient(circle, " + stopsStr + ")"
}

var STANDARD_BACKGROUNDS = [
  { name: "White", hex: "#FFFFFF" },
  { name: "Slate-50", hex: "#F8FAFC" },
  { name: "Slate-100", hex: "#F1F5F9" },
  { name: "Gray-200", hex: "#E5E7EB" },
  { name: "Gray-300", hex: "#D1D5DB" },
  { name: "Gray-400", hex: "#9CA3AF" },
  { name: "Gray-500", hex: "#6B7280" },
  { name: "Gray-600", hex: "#4B5563" },
  { name: "Gray-700", hex: "#374151" },
  { name: "Gray-800", hex: "#1F2937" },
  { name: "Slate-900", hex: "#0F172A" },
  { name: "Black", hex: "#000000" }
]

function exportPaletteAsCSS(colors, prefix) {
  var p = prefix || "color"
  return colors.map(function(c, i) { return "--" + p + "-" + (i + 1) + ": " + c + ";" }).join("\n")
}

function exportPaletteAsJSON(colors) {
  return JSON.stringify(colors, null, 2)
}

function parseColor(input) {
  var str = String(input || "").trim()
  if (/^#?[a-f0-9]{6}$/i.test(str)) {
    return str.startsWith("#") ? str.toUpperCase() : "#" + str.toUpperCase()
  }
  if (/^#?[a-f0-9]{3}$/i.test(str)) {
    var c = str.replace("#", "")
    return ("#" + c[0] + c[0] + c[1] + c[1] + c[2] + c[2]).toUpperCase()
  }
  var rgbMatch = str.match(/rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/i)
  if (rgbMatch) {
    return rgbToHex(parseInt(rgbMatch[1]), parseInt(rgbMatch[2]), parseInt(rgbMatch[3]))
  }
  var hslMatch = str.match(/hsl\s*\(\s*(\d+)\s*,\s*(\d+)%?\s*,\s*(\d+)%?\s*\)/i)
  if (hslMatch) {
    var rgb = hslToRgb(parseInt(hslMatch[1]), parseInt(hslMatch[2]), parseInt(hslMatch[3]))
    return rgbToHex(rgb.r, rgb.g, rgb.b)
  }
  return null
}

function analyzeColor(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return null
  var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)
  var hsv = rgbToHsv(rgb.r, rgb.g, rgb.b)
  var cmyk = rgbToCmyk(rgb.r, rgb.g, rgb.b)
  var hwb = rgbToHwb(rgb.r, rgb.g, rgb.b)
  var lab = rgbToLab(rgb.r, rgb.g, rgb.b)
  var lch = rgbToLch(rgb.r, rgb.g, rgb.b)
  var oklch = rgbToOklch(rgb.r, rgb.g, rgb.b)
  var cleanHex = rgbToHex(rgb.r, rgb.g, rgb.b)

  var contrastWhite = getContrastRatio(cleanHex, "#FFFFFF")
  var contrastBlack = getContrastRatio(cleanHex, "#000000")
  var apcaWhite = getApcaContrast(cleanHex, "#FFFFFF")
  var apcaBlack = getApcaContrast(cleanHex, "#000000")

  var colorName = findNearestColorName(cleanHex)
  var tailwindMatch = findNearestTailwind(cleanHex)
  var pantoneMatch = findNearestPantone(cleanHex)
  var ralMatch = findNearestRal(cleanHex)
  var ncsMatch = findNearestNcs(cleanHex)
  var temp = getColorTemperature(cleanHex)
  var websafe = getWebsafeColor(cleanHex)
  var shorthand = getHexShorthand(cleanHex)
  var luminance = getLuminance(rgb.r, rgb.g, rgb.b)

  var advancedHarmonies = generateHarmoniesAdvanced(cleanHex, 0)
  var harmoniesArray = [
    { name: "Complementary", colors: advancedHarmonies.complementary },
    { name: "Analogous", colors: advancedHarmonies.analogous },
    { name: "Triadic", colors: advancedHarmonies.triadic },
    { name: "Split-Comp", colors: advancedHarmonies.split },
    { name: "Tetradic", colors: advancedHarmonies.tetradic },
    { name: "Monochromatic", colors: advancedHarmonies.monochromatic },
    { name: "Double-Split", colors: advancedHarmonies.doubleSplit }
  ]

  // Color Blindness Simulation
  var protanopia = simulateColorBlindness(rgb.r, rgb.g, rgb.b, "protanopia")
  var deuteranopia = simulateColorBlindness(rgb.r, rgb.g, rgb.b, "deuteranopia")
  var tritanopia = simulateColorBlindness(rgb.r, rgb.g, rgb.b, "tritanopia")
  var achromatopsia = simulateColorBlindness(rgb.r, rgb.g, rgb.b, "achromatopsia")

  var blindnessSim = [
    { type: "protanopia", label: "Protanopia (Red-Blind)", hex: rgbToHex(protanopia.r, protanopia.g, protanopia.b) },
    { type: "deuteranopia", label: "Deuteranopia (Green-Blind)", hex: rgbToHex(deuteranopia.r, deuteranopia.g, deuteranopia.b) },
    { type: "tritanopia", label: "Tritanopia (Blue-Blind)", hex: rgbToHex(tritanopia.r, tritanopia.g, tritanopia.b) },
    { type: "achromatopsia", label: "Achromatopsia (Monochrome)", hex: rgbToHex(achromatopsia.r, achromatopsia.g, achromatopsia.b) }
  ]

  // Standard Backgrounds tested against this color
  var standardBgResults = STANDARD_BACKGROUNDS.map(function(bg) {
    var ratio = getContrastRatio(cleanHex, bg.hex)
    return { name: bg.name, hex: bg.hex, ratio: ratio, passAA: ratio >= 4.5 }
  })

  // Developer Formats Map
  var devFormats = [
    { label: "Swift UIColor", val: formatCode(cleanHex, "swift") },
    { label: "SwiftUI Color", val: formatCode(cleanHex, "swiftui") },
    { label: "Flutter", val: formatCode(cleanHex, "flutter") },
    { label: "Kotlin", val: formatCode(cleanHex, "kotlin") },
    { label: "Android XML", val: formatCode(cleanHex, "android-xml") },
    { label: "C# .NET", val: formatCode(cleanHex, "csharp") },
    { label: "Java AWT", val: formatCode(cleanHex, "java-awt") },
    { label: "Objective-C", val: formatCode(cleanHex, "objective-c") },
    { label: "CSS Variable", val: formatCode(cleanHex, "css-variable") },
    { label: "SASS Variable", val: formatCode(cleanHex, "sass-variable") }
  ]

  return {
    hex: cleanHex,
    hexShort: shorthand,
    rgb: rgb,
    rgbStr: "rgb(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ")",
    rgbaStr: "rgba(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ", 1)",
    hslStr: "hsl(" + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%)",
    hslaStr: "hsla(" + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%, 1)",
    hsvStr: "hsv(" + hsv.h + ", " + hsv.s + "%, " + hsv.v + "%)",
    hwbStr: "hwb(" + hwb.h + " " + hwb.w + "% " + hwb.b + "%)",
    labStr: "lab(" + lab.l.toFixed(1) + "% " + lab.a.toFixed(1) + " " + lab.b.toFixed(1) + ")",
    lchStr: "lch(" + lch.l.toFixed(1) + "% " + lch.c.toFixed(1) + " " + lch.h.toFixed(1) + ")",
    oklchStr: "oklch(" + oklch.l.toFixed(3) + " " + oklch.c.toFixed(3) + " " + oklch.h.toFixed(1) + ")",
    cmykStr: "cmyk(" + cmyk.c + "%, " + cmyk.m + "%, " + cmyk.y + "%, " + cmyk.k + "%)",
    argbStr: "#FF" + cleanHex.substring(1),
    integerStr: parseInt(cleanHex.substring(1), 16).toString(),
    hexIntStr: "0x" + cleanHex.substring(1),
    colorName: colorName,
    tailwindMatch: tailwindMatch,
    pantoneMatch: pantoneMatch,
    ralMatch: ralMatch,
    ncsMatch: ncsMatch,
    temperatureType: temp.type,
    temperatureKelvin: temp.kelvin,
    websafeColor: websafe,
    luminance: luminance,
    luminancePercent: (luminance * 100).toFixed(1) + "%",
    tints: generateTints(cleanHex, 10),
    shades: generateShades(cleanHex, 10),
    harmonies: harmoniesArray,
    contrastWhite: contrastWhite,
    contrastBlack: contrastBlack,
    passAAWhite: contrastWhite >= 4.5,
    passAABlack: contrastBlack >= 4.5,
    passAAAWhite: contrastWhite >= 7.0,
    passAAABlack: contrastBlack >= 7.0,
    apcaWhite: apcaWhite,
    apcaBlack: apcaBlack,
    blindnessSim: blindnessSim,
    standardBgResults: standardBgResults,
    devFormats: devFormats
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    hexToRgb: hexToRgb, rgbToHex: rgbToHex, rgbToHsl: rgbToHsl, hslToRgb: hslToRgb,
    rgbToHsv: rgbToHsv, rgbToCmyk: rgbToCmyk, rgbToHwb: rgbToHwb, rgbToLab: rgbToLab,
    labToRgb: labToRgb, rgbToLch: rgbToLch, rgbToOklab: rgbToOklab, oklabToRgb: oklabToRgb,
    rgbToOklch: rgbToOklch, oklchToRgb: oklchToRgb, generateTints: generateTints,
    generateShades: generateShades, mixColors: mixColors, mixColorsLab: mixColorsLab,
    mixColorsOklch: mixColorsOklch, blendColors: blendColors, blendWithStrength: blendWithStrength,
    generateScale: generateScale, generateScaleLab: generateScaleLab, generateScaleOklch: generateScaleOklch,
    getLuminance: getLuminance, getContrastRatio: getContrastRatio, getApcaContrast: getApcaContrast,
    calculateMinFontSize: calculateMinFontSize, suggestAccessibleColor: suggestAccessibleColor,
    simulateColorBlindness: simulateColorBlindness, findNearestColorName: findNearestColorName,
    findNearestTailwind: findNearestTailwind, findNearestPantone: findNearestPantone,
    findNearestRal: findNearestRal, findNearestNcs: findNearestNcs, getColorTemperature: getColorTemperature,
    getWebsafeColor: getWebsafeColor, getHexShorthand: getHexShorthand, formatCode: formatCode,
    generateHarmoniesAdvanced: generateHarmoniesAdvanced, GRADIENT_PRESETS: GRADIENT_PRESETS,
    generateGradient: generateGradient, STANDARD_BACKGROUNDS: STANDARD_BACKGROUNDS,
    exportPaletteAsCSS: exportPaletteAsCSS, exportPaletteAsJSON: exportPaletteAsJSON,
    parseColor: parseColor, analyzeColor: analyzeColor
  }
}
