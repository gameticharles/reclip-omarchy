import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

// ShareNumberField - one numeric Wi-Fi share server override.
//
// The distinction that matters here is "unset" versus "set". A setting the user
// has never touched is undefined, not the server's default, because the argv
// builder omits undefined values so lib/qr_file_server.py applies its own
// constant. Duplicating those constants in the UI would create a second copy
// that can silently drift, so the default is shown as placeholder text and
// discarded on commit unless the user actually types something.
Column {
    id: control

    property string label: ""
    property string suffix: ""
    property var value: undefined          // undefined = not overridden
    property var defaultValue: undefined   // shown as placeholder, never written
    property int min: 0
    property int max: 2147483647
    property string note: ""
    property bool integer: true


    // Theme, resolved from the same singletons the rest of the plugin uses, so
    // these fields follow the active theme without a caller passing colours in.
    property color fg: Color.popups.text || Color.text || "#cdd6f4"
    property string fontFamily: Style.fontFamily
    signal commit(var newValue)

    spacing: Style.space(6)

    Row {
        spacing: Style.space(6)
        width: parent.width

        Text {
            text: control.label
            color: control.fg
            font.family: control.fontFamily
            font.pixelSize: Style.space(9)
            font.bold: true
            width: parent.width - control.editable.implicitWidth - Style.space(8)
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: control.suffix
            color: Util.alpha(control.fg, 0.4)
            font.family: control.fontFamily
            font.pixelSize: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    TextField {
        id: editable
        width: parent.width
        height: Style.space(28)
        text: control.value === undefined ? "" : String(control.value)
        placeholderText: control.defaultValue === undefined ? "" : String(control.defaultValue)
        color: control.fg
        placeholderTextColor: Util.alpha(control.fg, 0.3)
        font.family: control.fontFamily
        font.pixelSize: Style.space(9)
        selectByMouse: true
        leftPadding: Style.space(8)
        rightPadding: Style.space(8)
        // A trailing "override" dot is the only cue that a field differs from
        // stock, since the value itself is the same number either way.
        background: Rectangle {
            radius: Style.space(6)
            color: editable.activeFocus ? Util.alpha(Color.accent, 0.08) : Util.alpha(control.fg, 0.04)
            border.width: 1
            border.color: editable.activeFocus ? Util.alpha(Color.accent, 0.5) : Util.alpha(control.fg, 0.1)
        }

        onEditingFinished: {
            var raw = String(text).trim()
            if (raw === "") {
                // Cleared: back to unset, not to zero.
                control.commit(undefined)
                text = ""
                return
            }
            var n = Number(raw)
            if (!isFinite(n)) {
                // Reject non-numeric input instead of coercing it to NaN and
                // letting it reach argparse.
                text = control.value === undefined ? "" : String(control.value)
                return
            }
            if (control.integer) n = Math.round(n)
            if (n < control.min) n = control.min
            if (n > control.max) n = control.max
            text = String(n)
            control.commit(n)
        }

        Keys.onEscapePressed: {
            // Abandon the edit, matching the modal-wide Esc behaviour.
            text = control.value === undefined ? "" : String(control.value)
            focus = false
        }
    }

    Text {
        text: control.note
        visible: control.note !== ""
        color: Util.alpha(control.fg, 0.45)
        font.family: control.fontFamily
        font.pixelSize: Style.space(8)
        wrapMode: Text.WordWrap
        width: parent.width
    }
}
