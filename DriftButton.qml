import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  property color foreground: Color.menu.text
  property color fill: "transparent"
  property color outline: Color.menu.border
  property bool primary: false
  property bool danger: false
  signal clicked()

  implicitWidth: Math.max(Style.space(112), content.implicitWidth + Style.space(30))
  implicitHeight: Math.max(Style.space(42), Style.font.body + Style.space(18))
  radius: Style.cornerRadius
  color: primary ? Color.menu.selectedBackground : fill
  border.width: Math.max(1, Style.normalBorderWidth)
  border.color: activeFocus || mouse.containsMouse ? Color.accent : outline
  scale: mouse.pressed ? 0.98 : 1
  opacity: enabled ? 1 : 0.45
  Accessible.role: Accessible.Button
  Accessible.name: label

  Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(8)
    Text {
      text: root.icon
      color: root.primary ? Color.menu.selectedText : root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Text {
      text: root.label
      color: root.primary ? Color.menu.selectedText : root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.weight: Font.Medium
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
