pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Services.UPower
import org.kde.bluezqt as BluezQt

PanelWindow {
  id: root

  anchors {
    top: true
    left: true
    right: true
  }

  margins {
    top: 4
    left: 4
    right: 4
  }
  implicitHeight: 24
  color: "transparent"
  visible: Hyprland.focusedWorkspace ? !Hyprland.focusedWorkspace.hasFullscreen : true

  RowLayout {
    anchors.fill: parent
    spacing: 8

    // Workspaces
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: wsRow.implicitWidth + 4
      color: "#CC232136"
      radius: root.height / 2

      RowLayout {
        id: wsRow
        anchors.fill: parent
        spacing: 2

        Repeater {
          model: Hyprland.workspaces
          Rectangle {
            required property var modelData
            property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
            readonly property var cchars: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
            property string displayChar: modelData.name <= 10 ? cchars[modelData.name - 1] : modelData.name

            Layout.preferredWidth: 35
            Layout.fillHeight: true
            radius: root.height / 2

            color: isActive ? "#c4a7e7" : "transparent"

            Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }

            Text {
              anchors.centerIn: parent
              text: parent.displayChar
              color: parent.isActive ? "#232136" : "#e0def4"

              Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }

              font.pixelSize: 11
              font.bold: true
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Hyprland.dispatch("workspace " + parent.modelData.id)
            }
          }
        }
      }
    }

    Item { Layout.fillWidth: true }

    // Window title
    Rectangle {
      id: titlePill
      Layout.fillHeight: true

      readonly property bool hasWindow: {
        const toplevel = Hyprland.activeToplevel;
        if (!toplevel || !Hyprland.focusedWorkspace) return false;
        let found = false;
        for (const window of Hyprland.focusedWorkspace.toplevels?.values ?? []) {
          if (window === toplevel) {
            found = true;
            break;
          }
        }
        if (!found) return false;

        return toplevel.workspace?.id === Hyprland.focusedWorkspace?.id;
      }

      Layout.preferredWidth: hasWindow ? Math.max(80, Math.min(titleText.contentWidth + 40, 500)) : 0
      color: "#CC232136"
      radius: root.height / 2
      clip: true

      opacity: hasWindow ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 200 } }
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

      Text {
        id: titleText
        anchors.centerIn: parent
        color: "#e0def4"
        font.pixelSize: 12
        width: Math.min(parent.width - 20, 480)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter

        property string fullTitle: (titlePill.hasWindow && Hyprland.activeToplevel) ? Hyprland.activeToplevel.title : ""
        property int step: 0

        text: (parent.hasWindow && fullTitle !== "") ? fullTitle.substring(0, step) : ""

        onFullTitleChanged: {
          step = 0;
          if (fullTitle !== "") {
            typingTimer.restart();
          } else {
            typingTimer.stop();
          }
        }

        Timer {
          id: typingTimer
          interval: 10
          repeat: true
          running: parent.fullTitle !== "" && parent.step < parent.fullTitle.length
          onTriggered: parent.step++
        }
      }
    }

    Item { Layout.fillWidth: true }

    // Music
    Rectangle {
      id: musicPill
      Layout.fillHeight: true

      property bool hasPlayer: Mpris.players.values.length > 0
      Layout.preferredWidth: hasPlayer ? (musicRow.width + 16) : 0

      color: "#CC232136"
      radius: root.height / 2
      clip: true

      opacity: hasPlayer ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 250 } }
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!musicPopup.visible) {
            musicPopup.visible = true;
          } else {
            closeTimer.start();
          }
        }
      }

      RowLayout {
        id: musicRow
        anchors.centerIn: parent
        spacing: 10

        Row {
          id: visualizer
          spacing: 2
          Layout.alignment: Qt.AlignVCenter
          property var barValues: [0, 0, 0, 0, 0, 0]

          Repeater {
            model: 6
            Rectangle {
              width: 3
              required property int index
              height: 2 + (visualizer.barValues[index] / 100) * 14
              radius: 1
              color: "#ea9a97"
              anchors.verticalCenter: parent.verticalCenter
              Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
            }
          }

          Process {
            running: musicPill.opacity > 0
            command: ["sh", "-c", `printf "[general]\\nbars=6\\nsensitivity=60\\n[output]\\nmethod=raw\\ndata_format=ascii\\nascii_max_range=100\\n[smoothing]\\nintegral=80\\ngravity=100" | cava -p /dev/stdin`]
            stdout: SplitParser {
              onRead: data => {
                const parts = data.trim().split(';');
                if (parts.length >= 6) {
                  let newValues = [];
                  for (let i = 0; i < 6; i++) newValues.push(parseInt(parts[i]) || 0);
                  visualizer.barValues = newValues;
                }
              }
            }
          }
        }

        Text {
          id: musicText
          property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
          text: (activePlayer ? " " : "󰝛 ") +
                (activePlayer ? (activePlayer.trackTitle || "Unknown") + " - " + (activePlayer.trackArtist || "Unknown") : "")
          color: "#f6c177"
          font.pixelSize: 12
          font.family: "JetBrainsMono Nerd Font"
          elide: Text.ElideRight
          Layout.maximumWidth: 180
        }
      }

      PopupWindow {
        id: musicPopup
        visible: false
        color: "transparent"

        HyprlandFocusGrab {
          active: musicPopup.visible
          windows: [musicPopup]
          onCleared: {
            closeTimer.start()
          }
        }

        anchor {
          item: musicPill
          edges: Edges.Bottom
          gravity: Edges.Bottom
          margins.top: 8
        }

        implicitWidth: 360
        implicitHeight: 160

        property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

        Timer {
          id: closeTimer
          interval: 250
          onTriggered: musicPopup.visible = false
        }

        Rectangle {
          id: popupContent
          implicitWidth: 360
          implicitHeight: 140
          color: "#CC232136"
          radius: 12
          clip: true

          readonly property bool isClosing: closeTimer.running

          opacity: (musicPopup.visible && !isClosing) ? 1 : 0
          scale: (musicPopup.visible && !isClosing) ? 1 : 0.95
          y: (musicPopup.visible && !isClosing) ? 10 : -20
          Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
          Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
          Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

          Timer {
            interval: 500
            repeat: true
            running: musicPopup.visible && musicPopup.activePlayer && musicPopup.activePlayer.playbackState === MprisPlaybackState.Playing
            onTriggered: musicPopup.activePlayer.positionChanged()
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 16

            Rectangle {
              Layout.preferredWidth: 100
              Layout.preferredHeight: 100
              Layout.alignment: Qt.AlignVCenter
              radius: 8
              clip: true
              color: "#393552"

              Image {
                anchors.fill: parent
                source: musicPopup.activePlayer ? musicPopup.activePlayer.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 4

              Text {
                text: musicPopup.activePlayer ? (musicPopup.activePlayer.trackTitle || "Unknown Title") : "No Title"
                color: "#e0def4"
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: musicPopup.activePlayer ? (musicPopup.activePlayer.trackArtist || "Unknown Artist") : "No Artist"
                color: "#908caa"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: musicPopup.activePlayer ? (musicPopup.activePlayer.trackAlbum || "Unknown Album") : "No Album"
                color: "#6e6a86"
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Item { Layout.fillHeight: true }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                function formatTime(secondsIn) {
                  if (!secondsIn) return "0:00";
                  let seconds = Math.floor(secondsIn);
                  let m = Math.floor(seconds / 60);
                  let s = seconds % 60;
                  return m + ":" + (s < 10 ? "0" : "") + s;
                }

                Text {
                  text: parent.formatTime(musicPopup.activePlayer ? musicPopup.activePlayer.position : 0)
                  color: "#908caa"
                  font.pixelSize: 10
                }

                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: 4
                  radius: 2
                  color: "#393552"

                  Rectangle {
                    height: parent.height
                    radius: 2
                    color: "#c4a7e7"
                    width: {
                      if (!musicPopup.activePlayer || !musicPopup.activePlayer.length) return 0;
                      return (musicPopup.activePlayer.position / musicPopup.activePlayer.length) * parent.width;
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                      if (musicPopup.activePlayer && musicPopup.activePlayer.length) {
                        let clickRatio = mouse.x / width;
                        musicPopup.activePlayer.position = clickRatio * musicPopup.activePlayer.length;
                      }
                    }
                  }
                }

                Text {
                  text: parent.formatTime(musicPopup.activePlayer ? musicPopup.activePlayer.length : 0)
                  color: "#908caa"
                  font.pixelSize: 10
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Text {
                  text: "󰒮"
                  color: prevArea.containsMouse ? "#c4a7e7" : "#e0def4"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 20
                  MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (musicPopup.activePlayer) musicPopup.activePlayer.previous()
                  }
                }

                Text {
                  property bool isPlaying: musicPopup.activePlayer ? musicPopup.activePlayer.playbackState === MprisPlaybackState.Playing : false
                  text: isPlaying ? "󰏤" : "󰐊"
                  color: playArea.containsMouse ? "#c4a7e7" : "#e0def4"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 24
                  MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (musicPopup.activePlayer) musicPopup.activePlayer.togglePlaying()
                  }
                }

                Text {
                  text: "󰒭"
                  color: nextArea.containsMouse ? "#c4a7e7" : "#e0def4"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 20
                  MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (musicPopup.activePlayer) musicPopup.activePlayer.next()
                  }
                }
              }
            }
          }
        }
      }
    }

    // Battery
    Rectangle {
      id: batteryPill
      Layout.fillHeight: true
      implicitWidth: batteryRow.implicitWidth + 16
      color: "#CC232136"
      radius: root.height / 2

      RowLayout {
        id: batteryRow
        anchors.centerIn: parent
        spacing: 6

        Text {
          property real percent: UPower.displayDevice ? UPower.displayDevice.percentage * 100 : 0
          property int state: UPower.displayDevice ? UPower.displayDevice.state : 0

          text: {
            if (state === 1) return "󰂄"; // Charging
            if (percent >= 90) return "󰁹";
            if (percent >= 80) return "󰂂";
            if (percent >= 70) return "󰂁";
            if (percent >= 60) return "󰂀";
            if (percent >= 50) return "󰁿";
            if (percent >= 40) return "󰁾";
            if (percent >= 30) return "󰁽";
            if (percent >= 20) return "󰁼";
            if (percent >= 10) return "󰁻";
            return "󰂎";
          }
          color: state === 1 ? "#9ccfd8" : (percent <= 20 ? "#eb6f92" : "#ebbcba")
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
        }

        Text {
          text: Math.round(UPower.displayDevice ? UPower.displayDevice.percentage * 100 : 0) + "%"
          color: "#e0def4"
          font.pixelSize: 12
          font.bold: true
        }
      }
    }

    // Wi-Fi & Bluetooth
    Rectangle {
      id: netPill
      Layout.fillHeight: true
      implicitWidth: netRow.implicitWidth + 16
      color: "#CC232136"
      radius: root.height / 2

      MouseArea {
	anchors.fill: parent
	cursorShape: Qt.PointingHandCursor
	onClicked: {
	  if (!netPopup.visible) {
	    netPopup.visible = true;
	  } else {
	    netCloseTimer.start();
	  }
	}
      }

      RowLayout {
	id: netRow
	anchors.centerIn: parent
	spacing: 8

	// Wi‑Fi status icon (polled sadly cuz i gave up)
	Text {
	  id: wifiText
	  property bool isWifiOn: false
	  text: isWifiOn ? "󰖩" : "󰖪"
	  color: isWifiOn ? "#9ccfd8" : "#6e6a86"
	  font.family: "JetBrainsMono Nerd Font"
	  font.pixelSize: 14

	  Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

	  Timer {
	    interval: 2000
	    running: true
	    repeat: true
	    onTriggered: wifiStatusProc.running = true
	  }

	  Process {
	    id: wifiStatusProc
	    command: ["nmcli", "radio", "wifi"]
	    stdout: SplitParser {
	      onRead: data => wifiText.isWifiOn = data.trim() === "enabled"
	    }
	  }
	  Component.onCompleted: wifiStatusProc.running = true
	}

	// Bluetooth status icon
	Text {
	  text: BluezQt.Manager.bluetoothOperational ? "󰂯" : "󰂲"
	  color: BluezQt.Manager.bluetoothOperational ? "#c4a7e7" : "#6e6a86"
	  font.family: "JetBrainsMono Nerd Font"
	  font.pixelSize: 14

	  Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
	}
      }

      PopupWindow {
	id: netPopup
	visible: false
	color: "transparent"

	HyprlandFocusGrab {
	  active: netPopup.visible
	  windows: [netPopup]
	  onCleared: netCloseTimer.start()
	}

	anchor {
	  item: netPill
	  edges: Edges.Bottom
	  gravity: Edges.Bottom
	  margins.top: 8
	}

	implicitWidth: 420
	implicitHeight: 500

	Timer {
	  id: netCloseTimer
	  interval: 250
	  onTriggered: netPopup.visible = false
	}

	// Active tab
	property string activeTab: "wifi"

	Rectangle {
	  id: netPopupContent
	  anchors.fill: parent
	  color: "#CC232136"
	  radius: 12
	  clip: true

	  readonly property bool isClosing: netCloseTimer.running

	  opacity: (netPopup.visible && !isClosing) ? 1 : 0
	  scale: (netPopup.visible && !isClosing) ? 1 : 0.95
	  y: (netPopup.visible && !isClosing) ? 10 : -20

	  Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
	  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
	  Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

	  ColumnLayout {
	    anchors.fill: parent
	    anchors.margins: 12
	    spacing: 12

	    // Animated Icon-Only Tab Bar
	    RowLayout {
	      Layout.fillWidth: true
	      spacing: 8

	      // Segmented Control Switcher
	      Rectangle {
		Layout.fillWidth: true
		implicitHeight: 36
		radius: 18
		color: "#393552"

		RowLayout {
		  anchors.fill: parent
		  spacing: 4

		  // Wi‑Fi Icon Tab
		  Rectangle {
		    Layout.fillWidth: true
		    Layout.fillHeight: true
		    radius: 18
		    color: netPopup.activeTab === "wifi" ? "#c4a7e7" : "transparent"
		    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

		    Text {
		      anchors.centerIn: parent
		      text: "󰖩"
		      color: netPopup.activeTab === "wifi" ? "#232136" : "#e0def4"
		      font.family: "JetBrainsMono Nerd Font"
		      font.pixelSize: 16
		      Behavior on color { ColorAnimation { duration: 250 } }
		    }

		    MouseArea {
		      anchors.fill: parent
		      cursorShape: Qt.PointingHandCursor
		      onClicked: netPopup.activeTab = "wifi"
		    }
		  }

		  // Bluetooth Icon Tab
		  Rectangle {
		    Layout.fillWidth: true
		    Layout.fillHeight: true
		    radius: 18
		    color: netPopup.activeTab === "bluetooth" ? "#c4a7e7" : "transparent"
		    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

		    Text {
		      anchors.centerIn: parent
		      text: "󰂯"
		      color: netPopup.activeTab === "bluetooth" ? "#232136" : "#e0def4"
		      font.family: "JetBrainsMono Nerd Font"
		      font.pixelSize: 16
		      Behavior on color { ColorAnimation { duration: 250 } }
		    }

		    MouseArea {
		      anchors.fill: parent
		      cursorShape: Qt.PointingHandCursor
		      onClicked: netPopup.activeTab = "bluetooth"
		    }
		  }
		}
	      }

	      // Animated Refresh button
	      Rectangle {
		implicitWidth: 36
		implicitHeight: 36
		radius: 18
		color: refreshMouse.containsMouse ? "#403d4d" : "transparent"
		Behavior on color { ColorAnimation { duration: 150 } }

		Text {
		  anchors.centerIn: parent
		  text: ""
		  color: "#e0def4"
		  font.family: "JetBrainsMono Nerd Font"
		  font.pixelSize: 16

		  // Spin animation while scanning
		  RotationAnimation on rotation {
		    loops: Animation.Infinite
		    from: 0
		    to: 360
		    duration: 1000
		    running: (netPopup.activeTab === "wifi" && scanProc.running) || 
		    (netPopup.activeTab === "bluetooth" && BluezQt.Manager.usableAdapter && BluezQt.Manager.usableAdapter.discovering)
		  }
		}

		MouseArea {
		  id: refreshMouse
		  anchors.fill: parent
		  hoverEnabled: true
		  cursorShape: Qt.PointingHandCursor
		  onClicked: {
		    if (netPopup.activeTab === "wifi") {
		      scanProc.running = true;
		    } else {
		      if (tabLoader.item && tabLoader.item.updateBluetoothList)
		      tabLoader.item.updateBluetoothList();
		    }
		  }
		}

		Process {
		  id: scanProc
		  command: ["nmcli", "device", "wifi", "rescan"]
		  onRunningChanged: {
		    if (!running) {
		      if (tabLoader.item && tabLoader.item.updateWifiList)
		      tabLoader.item.updateWifiList();
		    }
		  }
		}
	      }
	    }

	    // Content area
	    Item {
	      Layout.fillWidth: true
	      Layout.fillHeight: true

	      Loader {
		id: tabLoader
		anchors.fill: parent
		sourceComponent: netPopup.activeTab === "wifi" ? wifiComponent : bluetoothComponent
	      }
	    }
	  }
	}

	// Wi‑Fi Component
	Component {
	  id: wifiComponent

	  Item {
	    id: wifiRoot

	    ListModel { id: wifiModel }

	    property bool passwordVisible: false
	    property string pendingSsid: ""
	    property string pendingSecurity: ""
	    property string lastAttemptSsid: ""
	    property string lastAttemptSecurity: ""
	    property var savedSsids: new Set()

	    function sortWifiModel() {
	      let insertIdx = 0;
	      for (let i = 0; i < wifiModel.count; ++i) {
		if (wifiModel.get(i).active) {
		  if (i > insertIdx) wifiModel.move(i, insertIdx, 1);
		  insertIdx++;
		}
	      }
	      for (let i = insertIdx; i < wifiModel.count; ++i) {
		if (wifiModel.get(i).isKnown && !wifiModel.get(i).active) {
		  if (i > insertIdx) wifiModel.move(i, insertIdx, 1);
		  insertIdx++;
		}
	      }
	    }

	    function addOrUpdateWifi(ssid, security, signal, active) {
	      let found = false;
	      let isKnown = wifiRoot.savedSsids.has(ssid);

	      for (let i = 0; i < wifiModel.count; i++) {
		if (wifiModel.get(i).ssid === ssid) {
		  wifiModel.set(i, { ssid, security, signal, active, isKnown, seen: true });
		  found = true;
		  break;
		}
	      }

	      if (!found) {
		wifiModel.append({ ssid, security, signal, active, isKnown, seen: true });
	      }
	      sortWifiModel();
	    }

	    Timer {
	      interval: 5000
	      running: netPopup.visible && netPopup.activeTab === "wifi"
	      repeat: true
	      onTriggered: {
		wifiRoot.updateWifiList();
		wifiRoot.fetchSavedConnections();
	      }
	      Component.onCompleted: {
		wifiRoot.updateWifiList();
		wifiRoot.fetchSavedConnections();
	      }
	    }

	    function fetchSavedConnections() {
	      savedConnsProc.running = true;
	    }

	    Process {
	      id: savedConnsProc
	      command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | awk -F: '$2 == \"wifi\" {print $1}'"]
	      stdout: SplitParser {
		onRead: line => {
		  if (line.trim() !== "") {
		    wifiRoot.savedSsids.add(line.trim());
		  }
		}
	      }
	      onRunningChanged: {
		if (!running) {
		  for (let i = 0; i < wifiModel.count; i++) {
		    let ssid = wifiModel.get(i).ssid;
		    let known = wifiRoot.savedSsids.has(ssid);
		    wifiModel.setProperty(i, "isKnown", known);
		  }
		  wifiRoot.sortWifiModel();
		}
	      }
	    }

	    function updateWifiList() {
	      for (let i = 0; i < wifiModel.count; i++) wifiModel.setProperty(i, "seen", false);
	      wifiListProc.running = true;
	    }

	    Process {
	      id: wifiListProc
	      command: ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL,ACTIVE", "device", "wifi", "list"]
	      stdout: SplitParser {
		onRead: line => {
		  if (line.trim() === "") return;
		  const parts = line.split(":");
		  if (parts.length >= 4) {
		    const ssid = parts[0];
		    const security = parts[1] === "" ? "--" : parts[1];
		    const signal = parseInt(parts[2]) || 0;
		    const active = parts[3] === "yes";
		    wifiRoot.addOrUpdateWifi(ssid, security, signal, active);
		  }
		}
	      }
	      onRunningChanged: {
		if (!running) {
		  for (let i = wifiModel.count - 1; i >= 0; i--) {
		    if (!wifiModel.get(i).seen) wifiModel.remove(i);
		  }
		  wifiRoot.fetchSavedConnections();
		}
	      }
	    }

	    property string wifiInterface: ""
	    Process {
	      id: ifaceProc
	      command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE device status | grep ':wifi$' | cut -d: -f1 | head -1"]
	      stdout: SplitParser {
		onRead: data => wifiRoot.wifiInterface = data.trim()
	      }
	    }
	    Component.onCompleted: ifaceProc.running = true

	    ListView {
	      id: wifiListView
	      anchors.fill: parent
	      model: wifiModel
	      spacing: 6
	      clip: true
	      visible: !wifiRoot.passwordVisible

	      add: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }
	      move: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }

	      delegate: Rectangle {
		required property var model
		width: ListView.view.width
		implicitHeight: 40
		radius: 8
		color: mouseArea.containsMouse ? "#403d4d" : "transparent"
		Behavior on color { ColorAnimation { duration: 150 } }

		RowLayout {
		  anchors.fill: parent
		  anchors.leftMargin: 10
		  anchors.rightMargin: 10
		  spacing: 8

		  Text {
		    text: {
		      if (model.signal >= 80) return "󰤨"
		      if (model.signal >= 60) return "󰤥"
		      if (model.signal >= 40) return "󰤢"
		      if (model.signal >= 20) return "󰤟"
		      return "󰤯"
		    }
		    color: model.active ? "#9ccfd8" : "#e0def4"
		    font.family: "JetBrainsMono Nerd Font"
		    font.pixelSize: 14
		  }

		  Text {
		    text: model.ssid || "<hidden>"
		    color: "#e0def4"
		    font.pixelSize: 13
		    font.bold: model.active
		    elide: Text.ElideRight
		    Layout.fillWidth: true
		  }

		  Row {
		    spacing: 4
		    Text {
		      text: {
			if (model.security === "--") return ""
			else if (model.isKnown) return ""
			else return ""
		      }
		      color: (model.security === "--") ? "#9ccfd8" : "#eb6f92"
		      font.family: "JetBrainsMono Nerd Font"
		      font.pixelSize: 12
		      visible: text !== ""
		    }
		    Text {
		      text: (model.isKnown || model.active) ? "" : ""
		      color: "#9ccfd8"
		      font.family: "JetBrainsMono Nerd Font"
		      font.pixelSize: 14
		      visible: (model.isKnown || model.active)
		    }
		  }
		}

		MouseArea {
		  id: mouseArea
		  anchors.fill: parent
		  hoverEnabled: true
		  cursorShape: Qt.PointingHandCursor
		  onClicked: {
		    if (model.active) {
		      if (wifiRoot.wifiInterface) {
			disconnectProc.command = ["nmcli", "device", "disconnect", wifiRoot.wifiInterface];
			disconnectProc.running = true;
		      }
		    } else {
		      wifiRoot.lastAttemptSsid = model.ssid;
		      wifiRoot.lastAttemptSecurity = model.security;
		      connectProc.command = ["nmcli", "device", "wifi", "connect", model.ssid];
		      connectProc.running = true;
		    }
		  }
		}
	      }
	    }

	    Process {
	      id: disconnectProc
	      onRunningChanged: if (!running) wifiRoot.updateWifiList();
	    }

	    Process {
	      id: connectProc
	      onRunningChanged: if (!running) wifiRoot.updateWifiList();
	      onExited: (exitCode) => {
		if (exitCode !== 0 && wifiRoot.lastAttemptSecurity && wifiRoot.lastAttemptSecurity !== "--") {
		  wifiRoot.passwordVisible = true;
		  wifiRoot.pendingSsid = wifiRoot.lastAttemptSsid;
		  wifiRoot.pendingSecurity = wifiRoot.lastAttemptSecurity;
		}
		wifiRoot.lastAttemptSsid = "";
		wifiRoot.lastAttemptSecurity = "";
	      }
	    }

	    // Animated Password Screen
	    Rectangle {
	      anchors.fill: parent
	      color: "#CC232136"
	      radius: 8
	      visible: wifiRoot.passwordVisible
	      opacity: visible ? 1 : 0
	      scale: visible ? 1 : 0.95
	      Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
	      Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
	      z: 1

	      ColumnLayout {
		anchors.centerIn: parent
		width: parent.width - 40
		spacing: 16

		Text {
		  text: wifiRoot.pendingSsid
		  color: "#e0def4"
		  font.pixelSize: 16
		  font.bold: true
		  elide: Text.ElideRight
		  horizontalAlignment: Text.AlignHCenter
		  Layout.fillWidth: true
		}

		Rectangle {
		  Layout.fillWidth: true
		  implicitHeight: 36
		  color: "#393552"
		  radius: 18
		  border.width: 1
		  border.color: passwordInput.focus ? "#c4a7e7" : "transparent"
		  Behavior on border.color { ColorAnimation { duration: 150 } }

		  TextInput {
		    id: passwordInput
		    anchors.fill: parent
		    anchors.leftMargin: 12
		    anchors.rightMargin: 12
		    verticalAlignment: TextInput.AlignVCenter
		    color: "#e0def4"
		    font.pixelSize: 13
		    echoMode: TextInput.Password
		    focus: true
		    onAccepted: wifiRoot.connectWithPassword()
		  }
		}

		// Icon-based Connect/Cancel Buttons
		RowLayout {
		  Layout.alignment: Qt.AlignHCenter
		  spacing: 24

		  Rectangle {
		    implicitWidth: 44
		    implicitHeight: 44
		    radius: 22
		    color: cancelMouse.containsMouse ? "#eb6f92" : "#393552"
		    Behavior on color { ColorAnimation { duration: 150 } }

		    Text { 
		      anchors.centerIn: parent
		      text: "" 
		      color: cancelMouse.containsMouse ? "#232136" : "#eb6f92"
		      font.pixelSize: 20
		      font.family: "JetBrainsMono Nerd Font"
		      Behavior on color { ColorAnimation { duration: 150 } }
		    }
		    MouseArea {
		      id: cancelMouse
		      anchors.fill: parent
		      hoverEnabled: true
		      cursorShape: Qt.PointingHandCursor
		      onClicked: { wifiRoot.passwordVisible = false; passwordInput.text = ""; }
		    }
		  }

		  Rectangle {
		    implicitWidth: 44
		    implicitHeight: 44
		    radius: 22
		    color: connectMouse.containsMouse ? "#9ccfd8" : "#393552"
		    Behavior on color { ColorAnimation { duration: 150 } }

		    Text { 
		      anchors.centerIn: parent
		      text: "󰄬" 
		      color: connectMouse.containsMouse ? "#232136" : "#9ccfd8"
		      font.pixelSize: 20
		      font.family: "JetBrainsMono Nerd Font"
		      font.bold: true 
		      Behavior on color { ColorAnimation { duration: 150 } }
		    }
		    MouseArea {
		      id: connectMouse
		      anchors.fill: parent
		      hoverEnabled: true
		      cursorShape: Qt.PointingHandCursor
		      onClicked: wifiRoot.connectWithPassword()
		    }
		  }
		}
	      }
	    }

	    function connectWithPassword() {
	      if (pendingSsid && passwordInput.text) {
		connectProc.command = ["nmcli", "device", "wifi", "connect", pendingSsid, "password", passwordInput.text];
		connectProc.running = true;
		passwordVisible = false;
		passwordInput.text = "";
	      }
	    }
	  }
	}

	// Bluetooth Component
	Component {
	  id: bluetoothComponent

	  Item {
	    id: bluetoothRoot

	    ListModel { id: bluetoothModel }

	    function sortModel() {
	      if (!bluetoothModel) return;
	      let insertIdx = 0;

	      for (let i = 0; i < bluetoothModel.count; ++i) {
		if (bluetoothModel.get(i).paired && bluetoothModel.get(i).connected) {
		  if (i > insertIdx) bluetoothModel.move(i, insertIdx, 1);
		  insertIdx++;
		}
	      }

	      for (let i = insertIdx; i < bluetoothModel.count; ++i) {
		if (bluetoothModel.get(i).paired && !bluetoothModel.get(i).connected) {
		  if (i > insertIdx) bluetoothModel.move(i, insertIdx, 1);
		  insertIdx++;
		}
	      }
	    }

	    function addDevice(device) {
	      if (!bluetoothModel || !device.name) return;
	      bluetoothModel.append({
		address: device.address,
		name: device.name,
		connected: device.connected,
		paired: device.paired
	      });
	      sortModel();
	    }

	    function updateDevice(device) {
	      for (let i = 0; i < bluetoothModel.count; ++i) {
		if (bluetoothModel.get(i).address === device.address) {
		  bluetoothModel.set(i, {
		    address: device.address,
		    name: device.name,
		    connected: device.connected,
		    paired: device.paired
		  });
		  sortModel();
		  break;
		}
	      }
	    }

	    function removeDevice(address) {
	      for (let i = 0; i < bluetoothModel.count; ++i) {
		if (bluetoothModel.get(i).address === address) {
		  bluetoothModel.remove(i);
		  break;
		}
	      }
	    }

	    Connections {
	      target: BluezQt.Manager
	      function onDeviceAdded(device) { bluetoothRoot.addDevice(device); }
	      function onDeviceRemoved(device) { if (bluetoothModel) bluetoothRoot.removeDevice(device.address); }
	      function onDeviceChanged(device) {
		if (!bluetoothModel) return;
		let found = false;
		for (let i = 0; i < bluetoothModel.count; ++i) {
		  if (bluetoothModel.get(i).address === device.address) {
		    found = true;
		    break;
		  }
		}
		if (found) bluetoothRoot.updateDevice(device);
		else bluetoothRoot.addDevice(device);
	      }
	    }

	    Component.onCompleted: {
	      for (const device of BluezQt.Manager.devices) addDevice(device);
	    }

	    ListView {
	      anchors.fill: parent
	      model: bluetoothModel
	      spacing: 6
	      clip: true

	      add: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }
	      move: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }

	      delegate: Rectangle {
		required property var model
		width: ListView.view.width
		implicitHeight: 40
		radius: 8
		color: mouseArea.containsMouse ? "#403d4d" : "transparent"
		Behavior on color { ColorAnimation { duration: 150 } }

		RowLayout {
		  anchors.fill: parent
		  anchors.leftMargin: 10
		  anchors.rightMargin: 10
		  spacing: 8

		  Text {
		    text: "󰂱"
		    color: model.connected ? "#9ccfd8" : (model.paired ? "#e0def4" : "#6e6a86")
		    font.family: "JetBrainsMono Nerd Font"
		    font.pixelSize: 14
		  }

		  Text {
		    text: model.name
		    color: model.paired ? "#e0def4" : "#908caa"
		    font.pixelSize: 13
		    font.bold: model.connected
		    elide: Text.ElideRight
		    Layout.fillWidth: true
		  }

		  Text {
		    text: model.paired ? (model.connected ? "" : "") : ""
		    color: model.connected ? "#9ccfd8" : "#c4a7e7"
		    font.family: "JetBrainsMono Nerd Font"
		    font.pixelSize: 14
		  }

		  Rectangle {
		    visible: model.paired
		    implicitWidth: 28
		    implicitHeight: 28
		    radius: 14
		    color: unpairMouse.containsMouse ? "#eb6f92" : "transparent"
		    Behavior on color { ColorAnimation { duration: 150 } }

		    Text {
		      anchors.centerIn: parent
		      text: "󰆴"
		      color: unpairMouse.containsMouse ? "#232136" : "#eb6f92"
		      font.family: "JetBrainsMono Nerd Font"
		      font.pixelSize: 14
		    }

		    MouseArea {
		      id: unpairMouse
		      anchors.fill: parent
		      hoverEnabled: true
		      cursorShape: Qt.PointingHandCursor
		      onClicked: {
			const devices = BluezQt.Manager.devices;
			for (const dev of devices) {
			  if (dev.address === model.address) {
			    if (BluezQt.Manager.usableAdapter) BluezQt.Manager.usableAdapter.removeDevice(dev);
			    break;
			  }
			}
		      }
		    }
		  }
		}

		MouseArea {
		  id: mouseArea
		  anchors.fill: parent
		  anchors.rightMargin: model.paired ? 32 : 0
		  hoverEnabled: true
		  cursorShape: Qt.PointingHandCursor
		  onClicked: {
		    const devices = BluezQt.Manager.devices;
		    for (const dev of devices) {
		      if (dev.address === model.address) {
			if (!model.paired) {
			  dev.trusted = true;
			  dev.connectToDevice();
			} else {
			  if (model.connected) dev.disconnectFromDevice();
			  else dev.connectToDevice();
			}
			break;
		      }
		    }
		  }
		}
	      }
	    }

	    function updateBluetoothList() {
	      const adapter = BluezQt.Manager.usableAdapter;
	      if (adapter) {
		if (adapter.discovering) adapter.stopDiscovery();
		else adapter.startDiscovery();
	      }
	      bluetoothModel.clear();
	      for (const device of BluezQt.Manager.devices) addDevice(device);
	    }
	  }
	}
      }

      Process {
	id: wifiToggleProc
	command: ["sh", "-c", "nmcli radio wifi $(nmcli radio wifi | grep -q 'enabled' && echo 'off' || echo 'on')"]
      }

      Process {
	id: btToggleProc
	command: ["sh", "-c", BluezQt.Manager.bluetoothOperational ? "rfkill block bluetooth" : "rfkill unblock bluetooth"]
      }
    }

    // Clock
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: clock.contentWidth + 16
      color: "#CC232136"
      radius: root.height / 2

      Text {
        id: clock
        anchors.centerIn: parent
        color: "#3e8fb0"
        font.pixelSize: 12
        font.bold: true
        function updateTime() { text = Qt.formatDateTime(new Date(), "ddd d MMM hh:mm:ss") }
        Timer { interval: 500; running: true; repeat: true; onTriggered: clock.updateTime() }
        Component.onCompleted: updateTime()
      }
    }
  }
}
