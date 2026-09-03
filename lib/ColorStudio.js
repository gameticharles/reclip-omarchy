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

function generateTints(hex, count) {
  var rgb = hexToRgb(hex)
  if (!rgb) return []
  var n = count || 6
  var tints = []
  for (var i = 1; i <= n; i++) {
    var factor = i / (n + 1)
    tints.push(rgbToHex(
      rgb.r + (255 - rgb.r) * factor,
      rgb.g + (255 - rgb.g) * factor,
      rgb.b + (255 - rgb.b) * factor
    ))
  }
  return tints
}

function generateShades(hex, count) {
  var rgb = hexToRgb(hex)
  if (!rgb) return []
  var n = count || 6
  var shades = []
  for (var i = 1; i <= n; i++) {
    var factor = 1 - (i / (n + 1))
    shades.push(rgbToHex(rgb.r * factor, rgb.g * factor, rgb.b * factor))
  }
  return shades
}

function generateHarmonies(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return []
  var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)

  var makeHex = function(deg, s, l) {
    var c = hslToRgb((hsl.h + deg) % 360, s !== undefined ? s : hsl.s, l !== undefined ? l : hsl.l)
    return rgbToHex(c.r, c.g, c.b)
  }

  return [
    { name: "Complementary", colors: [hex, makeHex(180)] },
    { name: "Analogous", colors: [makeHex(330), hex, makeHex(30)] },
    { name: "Triadic", colors: [hex, makeHex(120), makeHex(240)] },
    { name: "Split-Comp", colors: [hex, makeHex(150), makeHex(210)] },
    { name: "Tetradic", colors: [hex, makeHex(90), makeHex(180), makeHex(270)] }
  ]
}

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
  return Math.round(((brightest + 0.05) / (darkest + 0.05)) * 10) / 10
}

function analyzeColor(hex) {
  var rgb = hexToRgb(hex)
  if (!rgb) return null
  var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)
  var hsv = rgbToHsv(rgb.r, rgb.g, rgb.b)
  var cmyk = rgbToCmyk(rgb.r, rgb.g, rgb.b)
  var cleanHex = rgbToHex(rgb.r, rgb.g, rgb.b)
  var contrastWhite = getContrastRatio(cleanHex, "#FFFFFF")
  var contrastBlack = getContrastRatio(cleanHex, "#000000")

  return {
    hex: cleanHex,
    rgbStr: "rgb(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ")",
    hslStr: "hsl(" + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%)",
    hsvStr: "hsv(" + hsv.h + ", " + hsv.s + "%, " + hsv.v + "%)",
    cmykStr: "cmyk(" + cmyk.c + "%, " + cmyk.m + "%, " + cmyk.y + "%, " + cmyk.k + "%)",
    tints: generateTints(cleanHex, 6),
    shades: generateShades(cleanHex, 6),
    harmonies: generateHarmonies(cleanHex),
    contrastWhite: contrastWhite,
    contrastBlack: contrastBlack,
    passAAWhite: contrastWhite >= 4.5,
    passAABlack: contrastBlack >= 4.5
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    hexToRgb: hexToRgb, rgbToHex: rgbToHex, rgbToHsl: rgbToHsl, hslToRgb: hslToRgb,
    rgbToHsv: rgbToHsv, rgbToCmyk: rgbToCmyk, generateTints: generateTints,
    generateShades: generateShades, generateHarmonies: generateHarmonies,
    getContrastRatio: getContrastRatio, analyzeColor: analyzeColor
  }
}
