import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string helperPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.da5ater.theme-drift/bin/theme-drift"

  Timer {
    interval: 2500
    running: true
    repeat: false
    onTriggered: bootRotation.running = true
  }

  Process {
    id: bootRotation
    command: [root.helperPath, "rotate-boot"]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail) console.warn("Theme Drift: " + detail)
      }
    }
  }
}
