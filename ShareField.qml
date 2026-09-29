import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

// ShareField - one free-text Wi-Fi share server override (ports, IP, save dir).
//
// Same unset-versus-set contract as ShareNumberField: an empty commit clears
// the override rather than storing "", and FileShareArgs then omits the flag so
// the server falls back to its own behaviour.
Column {
    id: control

    property string label: ""
    property string placeholder: ""
    property string value: ""
    property string defaultText: ""
    property string note: ""


    // Theme, resolved from the same singletons the rest of the plugin uses, so
    // these fields follow the active theme without a caller passing colours in.
    property color fg: Color.popups.text || Color.text || "#cdd6f4"
    property string fontFamily: Style.fontFamily
    signal commit(string newValue)

    spacing: Style.space(6)

    Text {
        text: control.label
        color: control.fg
        font.family: control.fontFamily
        font.pixelSize: Style.space(9)
        font.bold: true
        width: parent.width
        elide: Text.ElideRight
    }

    TextField {
        id: editable
        width: parent.width
        height: Style.space(28)
        text: control.value
        placeholderText: control.placeholder !== "" ? control.placeholder : control.defaultText
        color: control.fg
        placeholderTextColor: Util.alpha(control.fg, 0.3)
        font.family: control.fontFamily
        font.pixelSize: Style.space(9)
        selectByMouse: true
        leftPadding: Style.space(8)
        rightPadding: Style.space(8)
        background: Rectangle {
            radius: Style.space(6)
            color: editable.activeFocus ? Util.alpha(Color.accent, 0.08) : Util.alpha(control.fg, 0.04)
            border.width: 1
            border.color: editable.activeFocus ? Util.alpha(Color.accent, 0.5) : Util.alpha(control.fg, 0.1)
        }

        onEditingFinished: control.commit(String(text).trim())

        Keys.onEscapePressed: {
            text = control.value
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
