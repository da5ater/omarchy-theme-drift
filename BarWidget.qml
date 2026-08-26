import QtQuick
import Quickshell
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.da5ater.theme-drift"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏘"
    tooltipText: "Theme Drift"
    onPressed: function(mouseButton) {
      if (root.bar && root.bar.shell)
        root.bar.shell.summon(root.moduleName, "{}")
    }
  }
}
