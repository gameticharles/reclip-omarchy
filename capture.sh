#!/bin/bash

# ReClip clipboard capture. In watch mode wl-paste invokes this with the
# payload on stdin and the mime as $1. Without arguments it snapshots the
# current selection itself. Emits a JSON entry on stdout per capture.

set -o pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/reclip"
IMAGE_DIR="$STATE_DIR/clipboard-images"
mkdir -p "$IMAGE_DIR"

types=$(wl-paste --list-types 2>/dev/null || true)

if [[ -f "$STATE_DIR/incognito" ]] || [[ ${CLIPBOARD_STATE:-} == "sensitive" ]] || grep -qx 'x-kde-passwordManagerHint' <<<"$types"; then
  exit 0
fi

# Query active Hyprland window for App-Aware attribution & password manager protection
win_info=$(hyprctl activewindow -j 2>/dev/null || echo "{}")
app_class=$(jq -r '.class // empty' <<<"$win_info" 2>/dev/null || echo "")
app_title=$(jq -r '.title // empty' <<<"$win_info" 2>/dev/null || echo "")

# Auto-ignore password managers / blacklisted apps
app_lower=$(tr '[:upper:]' '[:lower:]' <<<"$app_class")
case "$app_lower" in
  *keepass*|*1password*|*bitwarden*|*authpass*|*enpass*|*lastpass*|*vault*)
    exit 0
    ;;
esac

if [[ -f "$STATE_DIR/settings.json" ]]; then
  custom_blocked=$(jq -r --arg c "$app_class" '.appBlacklist // [] | index($c) // empty' "$STATE_DIR/settings.json" 2>/dev/null || true)
  if [[ -n "$custom_blocked" ]]; then
    exit 0
  fi
fi

export RECLIP_APP_CLASS="$app_class"
export RECLIP_APP_TITLE="$app_title"

emit_image() {
  local mime="$1"
  local ext tmp hash file

  ext=${mime#image/}
  [[ $ext == jpeg ]] && ext=jpg

  tmp=$(mktemp --tmpdir="$IMAGE_DIR" clipboard.XXXXXX) || return 0
  cat >"$tmp"
  if [[ ! -s $tmp ]]; then
    rm -f "$tmp"
    return 0
  fi

  hash=$(sha256sum "$tmp" | awk '{print $1}')
  file="$IMAGE_DIR/$hash.$ext"
  if [[ -e $file ]]; then
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi

  local limit=12
  if [[ -f "$STATE_DIR/settings.json" ]]; then
    local conf_limit
    conf_limit=$(jq -r '.imagePaletteLimit // empty' "$STATE_DIR/settings.json" 2>/dev/null || true)
    if [[ -n "$conf_limit" && "$conf_limit" != "null" && "$conf_limit" =~ ^[0-9]+$ ]]; then
      limit="$conf_limit"
    fi
  fi
  local fetch_count=$(( limit * 3 ))
  (( fetch_count < 24 )) && fetch_count=24

  local colors="[]"
  if command -v magick &>/dev/null; then
    colors=$(magick "$file" -resize 64x64\! -quantize RGB +dither -colors "$fetch_count" -unique-colors txt:- 2>/dev/null \
      | grep -oE '#[0-9A-Fa-f]{6}' | tr '[:lower:]' '[:upper:]' | awk '!seen[$0]++' | head -n "$limit" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  elif command -v convert &>/dev/null; then
    colors=$(convert "$file" -resize 64x64\! -quantize RGB +dither -colors "$fetch_count" -unique-colors txt:- 2>/dev/null \
      | grep -oE '#[0-9A-Fa-f]{6}' | tr '[:lower:]' '[:upper:]' | awk '!seen[$0]++' | head -n "$limit" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  fi

  local qr_text=""
  local is_qr=false
  if command -v zbarimg &>/dev/null; then
    qr_text=$(timeout 1s zbarimg -q --raw "$file" 2>/dev/null | head -c 8192 || true)
    if [[ -n "$qr_text" ]]; then
      is_qr=true
    fi
  fi

  jq -cn --arg mime "$mime" --arg path "$file" --arg captured_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --argjson colors "$colors" \
    --arg app_class "$app_class" --arg app_title "$app_title" \
    --argjson isQr "$is_qr" --arg qrText "$qr_text" \
    '{type:"image", mime:$mime, path:$path, capturedAt:$captured_at, colors:$colors, sourceApp:$app_class, sourceTitle:$app_title, isQr:$isQr, qrText:$qrText}'
}

emit_text() {
  perl -MEncode=decode,FB_CROAK,LEAVE_SRC -MJSON::PP=encode_json -0777 -e '
    my $raw = <STDIN>;
    exit unless length $raw;

    my $encoding;
    my $heuristic_encoding = 0;
    if ($raw =~ /^(?:\xFF\xFE|\xFE\xFF)/) {
      $encoding = "UTF-16";
    } elsif (length($raw) % 2 == 0 && index($raw, "\0") >= 0) {
      my $units = length($raw) / 2;
      my $nuls = $raw =~ tr/\0/\0/;
      if ($nuls * 4 >= $units * 3) {
        my $even_bytes = $raw;
        $even_bytes =~ s/(.)./$1/sg;
        my $even_nuls = $even_bytes =~ tr/\0/\0/;
        undef $even_bytes;
        my $odd_bytes = $raw;
        $odd_bytes =~ s/.(.)/$1/sg;
        my $odd_nuls = $odd_bytes =~ tr/\0/\0/;
        if ($odd_nuls * 4 >= $units * 3 && $even_nuls * 4 < $units) {
          $encoding = "UTF-16LE";
          $heuristic_encoding = 1;
        } elsif ($even_nuls * 4 >= $units * 3 && $odd_nuls * 4 < $units) {
          $encoding = "UTF-16BE";
          $heuristic_encoding = 1;
        }
      }
    }

    my $text = $encoding ? eval { decode($encoding, $raw, FB_CROAK | LEAVE_SRC) } : undef;
    if ($heuristic_encoding && defined($text) && $text =~ /[\x00-\x08\x0E-\x1A\x1C-\x1F]/) {
      $text = undef;
    }
    $text = decode("UTF-8", $raw) unless defined $text;
    my $app = $ENV{"RECLIP_APP_CLASS"} || "";
    my $title = $ENV{"RECLIP_APP_TITLE"} || "";
    print encode_json({type => "text", text => $text, sourceApp => $app, sourceTitle => $title}), "\n";
  '
}

case "${1:-}" in
text) emit_text; exit 0 ;;
image/*) emit_image "$1"; exit 0 ;;
esac

for mime in image/png image/jpeg image/webp image/gif image/bmp image/tiff; do
  if grep -qx "$mime" <<<"$types"; then
    timeout 2s wl-paste --type "$mime" 2>/dev/null | emit_image "$mime"
    exit 0
  fi
done

if grep -q '^text/' <<<"$types" || grep -qx 'UTF8_STRING' <<<"$types" || grep -qx 'STRING' <<<"$types"; then
  wl-paste --type text --no-newline 2>/dev/null | emit_text
fi
