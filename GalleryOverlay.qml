import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool loading: false
  property string view: "discover"
  property int selectedIndex: 0
  property string statusText: ""
  property var themes: []
  property var visibleThemes: []
  property var carouselRef: null
  readonly property string helperPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.da5ater.theme-drift/bin/theme-drift"
  readonly property var selectedTheme: visibleThemes.length > 0 && selectedIndex < visibleThemes.length ? visibleThemes[selectedIndex] : null
  readonly property var currentTheme: themes.find(function(theme) { return theme.current })

  function open(payloadJson) {
    opened = true
    statusText = ""
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { opened = false }

  function dismiss() {
    if (shell && typeof shell.hide === "function")
      shell.hide((manifest && manifest.id) || "io.github.da5ater.theme-drift")
    else close()
  }

  function parseJson(raw, fallback) {
    try { return JSON.parse(String(raw || "")) } catch (e) { return fallback }
  }

  function previewSource(value) {
    var source = String(value || "")
    if (!source) return ""
    return source.indexOf("https://") === 0 || source.indexOf("http://") === 0 ? source : "file://" + source
  }

  function refresh(message) {
    if (listProc.running) return
    loading = true
    if (message) statusText = message
    listProc.command = [helperPath, "list"]
    listProc.running = true
  }

  function rebuildVisible() {
    var next = []
    for (var i = 0; i < themes.length; i++) {
      var theme = themes[i]
      if (view === "favorites" && !theme.favorite) continue
      if (view === "hidden" && !theme.hidden) continue
      if (view === "discover" && theme.hidden) continue
      next.push(theme)
    }
    visibleThemes = next
    if (selectedIndex >= next.length) selectedIndex = Math.max(0, next.length - 1)
    Qt.callLater(function() {
      if (next.length > 0 && carouselRef) carouselRef.positionViewAtIndex(selectedIndex, ListView.Center)
    })
  }

  function chooseView(nextView) {
    view = nextView
    selectedIndex = 0
    rebuildVisible()
  }

  function move(delta) {
    if (visibleThemes.length === 0) return
    selectedIndex = (selectedIndex + delta + visibleThemes.length) % visibleThemes.length
    if (carouselRef) carouselRef.positionViewAtIndex(selectedIndex, ListView.Center)
  }

  function runAction(args, message) {
    if (actionProc.running) return
    statusText = message || "Working…"
    actionProc.command = [helperPath].concat(args)
    actionProc.running = true
  }

  function toggleFavorite() {
    if (selectedTheme) runAction(["favorite", selectedTheme.slug], selectedTheme.favorite ? "Removing favorite…" : "Adding favorite…")
  }

  function toggleCurrentFavorite() {
    if (currentTheme) runAction(["favorite-current"], currentTheme.favorite ? "Removing current favorite…" : "Favoriting your current theme…")
  }

  function toggleFavoritesOnlyRotation() {
    var favoritesOnly = themes.length > 0 && themes[0].rotationScope === "favorites"
    setRotationMode(favoritesOnly ? "all" : "favorites")
  }

  function setRotationMode(mode) {
    var favoritesOnly = themes.length > 0 && themes[0].rotationScope === "favorites"
    if ((mode === "favorites") === favoritesOnly && !themes.some(function(theme) { return theme.permanent })) return
    runAction(["rotation-mode", mode], mode === "favorites" ? "Drifting through favorites only…" : "Including all installed themes…")
  }

  function toggleHidden() {
    if (!selectedTheme) return
    if (selectedTheme.hidden) runAction(["restore", selectedTheme.slug], "Restoring theme…")
    else runAction(["hide", selectedTheme.slug], selectedTheme.current ? "Hiding theme and drifting onward…" : "Hiding theme…")
  }

  function applySelected() {
    if (selectedTheme) runAction(["apply", selectedTheme.slug, selectedTheme.installed ? "" : selectedTheme.repo], (selectedTheme.installed ? "Applying " : "Installing and applying ") + selectedTheme.name + "…")
  }

  function makePermanent() {
    if (selectedTheme) runAction(["permanent", selectedTheme.slug, selectedTheme.installed ? "" : selectedTheme.repo], (selectedTheme.installed ? "Making " : "Installing and keeping ") + selectedTheme.name + "…")
  }

  Process {
    id: listProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, [])
        root.themes = Array.isArray(parsed) ? parsed : []
        root.rebuildVisible()
      }
    }
    stderr: StdioCollector { id: listError; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) root.statusText = String(listError.text || "Could not read themes").trim()
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.refresh(String(actionOutput.text || "Saved").trim())
      else root.statusText = String(actionError.text || "Action failed").trim()
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "theme-drift"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle { anchors.fill: parent; color: Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(1120), panel.width - Style.space(48))
      height: Math.min(Style.space(690), panel.height - Style.space(48))
      radius: Style.cornerRadius * 2
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      padding: 0

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) root.dismiss()
          else if (event.key === Qt.Key_Left) root.move(-1)
          else if (event.key === Qt.Key_Right) root.move(1)
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.applySelected()
          else if (event.key === Qt.Key_F) root.toggleFavorite()
          else if (event.key === Qt.Key_G) root.toggleFavoritesOnlyRotation()
          else if (event.key === Qt.Key_H) root.toggleHidden()
          else if (event.key === Qt.Key_P) root.makePermanent()
          else if (event.key === Qt.Key_R) root.runAction(["resume"], "Resuming rotation…")
          else if (event.key === Qt.Key_1) root.chooseView("discover")
          else if (event.key === Qt.Key_2) root.chooseView("favorites")
          else if (event.key === Qt.Key_3) root.chooseView("hidden")
          else return
          event.accepted = true
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(24)
          spacing: Style.space(16)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(16)

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(3)
              Text {
                text: "THEME DRIFT  ·  " + root.themes.length + " THEMES"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                font.letterSpacing: 2
              }
              Text {
                text: root.themes.some(function(theme) { return theme.permanent })
                  ? "Permanent theme selected · choose a boot mode to resume drifting"
                  : (root.selectedTheme ? root.selectedTheme.name : "Your Omarchy, never stale")
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
              }
            }

            DriftButton { label: "Close"; icon: "󰅖"; onClicked: root.dismiss() }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Row {
              spacing: Style.space(8)
              Repeater {
                model: [
                  { key: "discover", label: "Discover", shortcut: "1" },
                  { key: "favorites", label: "Favorites", shortcut: "2" },
                  { key: "hidden", label: "Hidden", shortcut: "3" }
                ]
                Rectangle {
                  required property var modelData
                  width: tabContent.implicitWidth + Style.space(24)
                  height: Style.space(34)
                  radius: height / 2
                  color: root.view === modelData.key ? Color.menu.selectedBackground : "transparent"
                  border.color: root.view === modelData.key ? Color.menu.selectedBackground : Color.menu.border
                  border.width: Math.max(1, Style.normalBorderWidth)
                  Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: Style.space(8)
                    Text { text: modelData.label; color: root.view === modelData.key ? Color.menu.selectedText : Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
                    Text { text: modelData.shortcut; color: root.view === modelData.key ? Color.menu.selectedText : Qt.darker(Color.menu.text, 1.4); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.chooseView(modelData.key) }
                }
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "BOOT DRIFT"
              color: Color.menu.text
              opacity: 0.62
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              font.letterSpacing: 1.2
            }

            DriftButton {
              label: "All installed"
              icon: "󰒟"
              primary: root.themes.length > 0 && root.themes[0].rotationScope !== "favorites" && !root.themes.some(function(theme) { return theme.permanent })
              onClicked: root.setRotationMode("all")
            }

            DriftButton {
              label: "Favorites only"
              icon: "󰋑"
              primary: root.themes.length > 0 && root.themes[0].rotationScope === "favorites" && !root.themes.some(function(theme) { return theme.permanent })
              onClicked: root.setRotationMode("favorites")
            }

            DriftButton {
              visible: !!root.currentTheme
              label: root.currentTheme && root.currentTheme.favorite ? "Current saved" : "Save current"
              icon: root.currentTheme && root.currentTheme.favorite ? "󰄬" : "󰋑"
              onClicked: root.toggleCurrentFavorite()
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Style.space(330)
            radius: Style.cornerRadius * 1.5
            color: Qt.darker(Color.menu.background, 1.08)
            clip: true

            Image {
              anchors.fill: parent
              source: root.selectedTheme ? root.previewSource(root.selectedTheme.preview) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              opacity: status === Image.Ready ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1.0; color: "#D9000000" }
              }
            }

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: Style.space(24)
              spacing: Style.space(6)
              Text {
                text: root.selectedTheme ? root.selectedTheme.name : (root.loading ? "Loading themes…" : "Nothing here yet")
                color: "white"
                font.family: Style.font.family
                font.pixelSize: Style.font.display
                font.weight: Font.DemiBold
              }
              Text {
                text: root.selectedTheme ? ((root.selectedTheme.current ? "CURRENT  •  " : "") + (root.selectedTheme.installed ? "INSTALLED  •  " : "CATALOG  •  INSTALLS WHEN APPLIED  •  ") + (root.selectedIndex + 1) + " OF " + root.visibleThemes.length) : (root.view === "favorites" ? "Press F on a theme to build your collection" : "No themes in this collection")
                color: "#CCFFFFFF"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Medium
                font.letterSpacing: 1.1
              }
              Text {
                visible: root.selectedTheme && !root.selectedTheme.installed
                text: root.selectedTheme ? "SOURCE  " + root.selectedTheme.repo : ""
                color: "#B3FFFFFF"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
                width: parent.width
              }
            }

            Column {
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: Style.space(18)
              spacing: Style.space(8)

              Rectangle {
                visible: root.selectedTheme && !root.selectedTheme.installed
                anchors.right: parent.right
                width: catalogBadge.implicitWidth + Style.space(20)
                height: Style.space(32)
                radius: height / 2
                color: Color.menu.selectedBackground
                Text { id: catalogBadge; anchors.centerIn: parent; text: "󰏗  CATALOG"; color: Color.menu.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold }
              }

              Rectangle {
                visible: root.selectedTheme && root.selectedTheme.favorite
                anchors.right: parent.right
                width: favoriteBadge.implicitWidth + Style.space(20)
                height: Style.space(32)
                radius: height / 2
                color: Color.menu.selectedBackground
                Text { id: favoriteBadge; anchors.centerIn: parent; text: "󰋑  FAVORITE"; color: Color.menu.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold }
              }
            }
          }

          ListView {
            model: root.visibleThemes
            Component.onCompleted: root.carouselRef = this
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(74)
            orientation: ListView.Horizontal
            spacing: Style.space(10)
            clip: true
            preferredHighlightBegin: width / 2 - Style.space(55)
            preferredHighlightEnd: width / 2 + Style.space(55)
            highlightRangeMode: ListView.ApplyRange
            delegate: Rectangle {
              required property int index
              required property var modelData
              width: Style.space(108)
              height: ListView.view.height
              radius: Style.cornerRadius
              clip: true
              border.width: root.selectedIndex === index ? Math.max(2, Style.normalBorderWidth) : Math.max(1, Style.normalBorderWidth)
              border.color: root.selectedIndex === index ? Color.accent : Color.menu.border
              color: Color.menu.background
              Image { anchors.fill: parent; source: root.previewSource(modelData.preview); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true }
              Rectangle { anchors.fill: parent; color: root.selectedIndex === index ? "transparent" : "#4D000000" }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedIndex = index; onDoubleClicked: root.applySelected() }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)
            Text {
              Layout.fillWidth: true
              text: root.statusText || "← → browse   Enter apply   F favorite   G favorites-only   H hide   P permanent   R resume"
              color: Qt.darker(Color.menu.text, 1.35)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            DriftButton { enabled: !!root.selectedTheme; label: root.selectedTheme && root.selectedTheme.favorite ? "Unfavorite" : "Favorite"; icon: root.selectedTheme && root.selectedTheme.favorite ? "󰓎" : "󰋑"; onClicked: root.toggleFavorite() }
            DriftButton { enabled: !!root.selectedTheme; label: root.selectedTheme && root.selectedTheme.hidden ? "Restore" : "Hide"; icon: root.selectedTheme && root.selectedTheme.hidden ? "󰁪" : "󰈉"; onClicked: root.toggleHidden() }
            DriftButton { enabled: !!root.selectedTheme; label: "Keep"; icon: "󰐃"; onClicked: root.makePermanent() }
            DriftButton { enabled: !!root.selectedTheme; label: root.selectedTheme && !root.selectedTheme.installed ? "Install & Apply" : "Apply"; icon: root.selectedTheme && !root.selectedTheme.installed ? "󰇚" : "󰄬"; primary: true; onClicked: root.applySelected() }
          }
        }
      }
    }
  }
}
