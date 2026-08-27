import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string helperPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.da5ater.theme-drift/bin/theme-drift"
  readonly property string notificationPath: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/bin/omarchy-notification-send"
  property bool promptVisible: false
  property var suggestion: null

  function parseJson(raw) {
    try { return JSON.parse(String(raw || "")) } catch (e) { return null }
  }

  function previewSource(value) {
    var source = String(value || "")
    if (!source) return ""
    return source.indexOf("https://") === 0 || source.indexOf("http://") === 0 ? source : "file://" + source
  }

  function dismissSuggestion() {
    promptVisible = false
    suggestion = null
  }

  function showSuggestion(raw) {
    var parsed = parseJson(raw)
    if (!parsed || !parsed.slug || !parsed.repo) return
    suggestion = parsed
    promptVisible = true
    Qt.callLater(function() { promptKeys.forceActiveFocus() })
  }

  function acceptSuggestion() {
    if (!suggestion || installSuggestion.running) return
    var selected = suggestion
    promptVisible = false
    installSuggestion.command = [helperPath, "apply", String(selected.slug), String(selected.repo)]
    installSuggestion.running = true
  }

  function notify(headline, detail, urgency) {
    Quickshell.execDetached([notificationPath, "-g", "󰏘", "-u", urgency || "low", headline, detail])
  }

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
    onExited: suggestionDelay.start()
  }

  Timer {
    id: suggestionDelay
    interval: 1800
    repeat: false
    onTriggered: suggestionProc.running = true
  }

  Process {
    id: suggestionProc
    command: [root.helperPath, "suggest"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.showSuggestion(String(text || "").trim())
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail) console.warn("Theme Drift suggestion: " + detail)
      }
    }
  }

  Process {
    id: installSuggestion
    stdout: StdioCollector { id: installOutput; waitForEnd: true }
    stderr: StdioCollector { id: installError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0)
        root.notify("Fresh look applied ✨", String(installOutput.text || "Your new theme is ready.").trim(), "low")
      else
        root.notify("Theme install failed", String(installError.text || "The approved theme could not be installed.").trim(), "normal")
      root.suggestion = null
    }
  }

  PanelWindow {
    id: suggestionWindow
    visible: root.promptVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "theme-drift-suggestion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.promptVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismissSuggestion() }

    BorderSurface {
      id: promptCard
      anchors.centerIn: parent
      width: Math.min(Style.space(620), suggestionWindow.width - Style.space(40))
      height: promptContent.implicitHeight + Style.space(48)
      radius: Style.cornerRadius * 2
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      padding: Style.space(24)

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: promptKeys
        anchors.fill: parent
        anchors.margins: promptCard.padding
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_N) root.dismissSuggestion()
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Y) root.acceptSuggestion()
          else return
          event.accepted = true
        }

        ColumnLayout {
          id: promptContent
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(14)

          Text {
            Layout.fillWidth: true
            text: "TRY NEW ONE?  ✨"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.Bold
            font.letterSpacing: 1.8
          }

          Text {
            Layout.fillWidth: true
            text: root.suggestion ? root.suggestion.name : "A fresh theme"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Style.space(280), Math.max(Style.space(170), suggestionWindow.height * 0.32))
            radius: Style.cornerRadius * 1.5
            color: Color.menu.selectedBackground
            border.color: Color.menu.border
            border.width: Math.max(1, Style.normalBorderWidth)
            clip: true

            Text {
              anchors.centerIn: parent
              text: promptPreview.status === Image.Error ? "Preview unavailable" : "Loading preview…"
              color: Color.menu.selectedText
              opacity: 0.72
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Image {
              id: promptPreview
              anchors.fill: parent
              source: root.suggestion ? root.previewSource(root.suggestion.preview) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              opacity: status === Image.Ready ? 1 : 0
              Accessible.name: root.suggestion ? "Preview of " + root.suggestion.name : "Theme preview"
              Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Style.space(42)
              color: "#73000000"
              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(14)
                text: "WALLPAPER PREVIEW"
                color: "white"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                font.letterSpacing: 1.2
              }
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Install and apply this catalog theme now? It will join your automatic rotation after installation."
            color: Color.menu.text
            opacity: 0.82
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: sourceText.implicitHeight + Style.space(20)
            radius: Style.cornerRadius
            color: Color.menu.selectedBackground
            Text {
              id: sourceText
              anchors.fill: parent
              anchors.margins: Style.space(10)
              text: "SOURCE  " + (root.suggestion ? root.suggestion.repo : "")
              color: Color.menu.selectedText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
              verticalAlignment: Text.AlignVCenter
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Style.space(4)
            spacing: Style.space(10)
            Item { Layout.fillWidth: true }
            DriftButton { label: "No, not now"; icon: "󰅖"; onClicked: root.dismissSuggestion() }
            DriftButton { label: "Yes, try it"; icon: "󰄬"; primary: true; onClicked: root.acceptSuggestion() }
          }

          Text {
            Layout.fillWidth: true
            text: "Enter / Y to try  ·  Esc / N to skip"
            color: Color.menu.text
            opacity: 0.58
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }
  }
}
