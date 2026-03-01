pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Io

PanelWindow {
  id: root
  
  anchors {
    top: true
    left: true
    right: true
  }

  margins {
    top: 8
    left: 8
    right: 8
  }
  implicitHeight: 30
  color: "transparent"

  RowLayout {
    anchors.fill: parent
    spacing: 12

    // Workspaces
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: wsRow.implicitWidth + 8 
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

	    Layout.preferredWidth: 45 
	    Layout.fillHeight: true
	    radius: root.height / 2

	    color: isActive ? "#c4a7e7" : "transparent" 

	    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } } 

	    Text {
	      anchors.centerIn: parent
	      text: parent.displayChar
	      color: parent.isActive ? "#232136" : "#e0def4" 

	      Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } } 

	      font.pixelSize: 12
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
	if (!toplevel) return false;

	let found = false;
	for (const window of Hyprland.focusedWorkspace.toplevels.values) {
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
	font.pixelSize: 13
	width: Math.min(parent.width - 20, 480) 
	elide: Text.ElideRight
	horizontalAlignment: Text.AlignHCenter

	property string fullTitle: titlePill.hasWindow ? Hyprland.activeToplevel.title : ""
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
      Layout.preferredWidth: hasPlayer ? (musicRow.width + 24) : 0 
      
      color: "#CC232136"
      radius: root.height / 2
      clip: true
      
      opacity: hasPlayer ? 1 : 0 
      
      Behavior on opacity { NumberAnimation { duration: 250 } }
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } } 

      MouseArea {
	anchors.fill: parent
	cursorShape: Qt.PointingHandCursor
	onClicked: musicPopup.visible = !musicPopup.visible
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
                (activePlayer ? (activePlayer.trackArtist || "Unknown") + " - " + (activePlayer.trackTitle || "Unknown") : "")
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

	anchor {
	  item: musicPill
	  edges: Edges.Bottom
	  gravity: Edges.Bottom
	  margins.top: 16
	}

	implicitWidth: 360
	implicitHeight: 160

	// Inherit the player context from your Mpris check
	property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null 

	Rectangle {
	  id: popupContent
	  implicitWidth: 360
	  implicitHeight: 140
	  color: "#CC232136" 
	  radius: 12
	  clip: true

	  // Intro animations
	  opacity: musicPopup.visible ? 1 : 0
	  scale: musicPopup.visible ? 1 : 0.95
	  y: musicPopup.visible ? 10 : -20
	  Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
	  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
	  Behavior on y { 
	    NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
	  }

	  Timer {
	    interval: 500
	    repeat: true
	    running: musicPopup.visible && musicPopup.activePlayer && musicPopup.activePlayer.playbackState === MprisPlaybackState.Playing
	    onTriggered: musicPopup.activePlayer.positionChanged()
	  }

	  RowLayout {
	    anchors.fill: parent
	    anchors.margins: 16
	    spacing: 16

	    // Album Art
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

	    // Song Info & Controls
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

	      // Seekbar
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

	      // Playback Controls
	      RowLayout {
		Layout.fillWidth: true
		Layout.alignment: Qt.AlignHCenter
		spacing: 20

		// Previous
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

		// Play / Pause
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

		// Next
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

    // Clock
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: clock.contentWidth + 24
      color: "#CC232136"
      radius: root.height / 2
      Text {
        id: clock
        anchors.centerIn: parent
        color: "#3e8fb0" 
        font.pixelSize: 13
        font.bold: true
        function updateTime() { text = Qt.formatDateTime(new Date(), "ddd d MMM hh:mm:ss") }
        Timer { interval: 500; running: true; repeat: true; onTriggered: clock.updateTime() } 
        Component.onCompleted: updateTime()
      }
    }
  }
}
