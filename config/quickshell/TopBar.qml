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
  implicitHeight: 35
  color: "transparent"

  RowLayout {
    anchors.fill: parent
    spacing: 12

    // Workspaces
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: wsRow.width + 20
      color: "#CC232136"
      radius: 10
      Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 8
        Repeater {
          model: Hyprland.workspaces
          Rectangle {
            required property var modelData 
            property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
            readonly property var cchars: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
            property string displayChar: modelData.name <= 10 ? cchars[modelData.name - 1] : modelData.name
            width: isActive ? 34 : 24
            height: 24
            radius: 12
            color: isActive ? "#c4a7e7" : "#6e6a86" 
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } } 
            Text {
              anchors.centerIn: parent
              text: parent.displayChar
              color: parent.isActive ? "#232136" : "#e0def4" 
              font.pixelSize: 12
              font.bold: true
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
      radius: 10
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
	  interval: 30 
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
      radius: 10
      clip: true
      
      opacity: hasPlayer ? 1 : 0 
      
      Behavior on opacity { NumberAnimation { duration: 250 } }
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } } 

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
    }

    // Clock
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: clock.contentWidth + 24
      color: "#CC232136"
      radius: 10
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
