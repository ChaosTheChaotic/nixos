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

    Item { Layout.fillWidth: true } // Spacer

    // Window title
    Rectangle {
      id: titlePill
      Layout.fillHeight: true

      implicitWidth: Math.max(80, Math.min(titleText.contentWidth + 40, 500))

      color: "#CC232136"
      radius: 10
      visible: Hyprland.activeToplevel !== null
      clip: true

      Text {
	id: titleText
	anchors.centerIn: parent

	text: Hyprland.activeToplevel?.title || ""
	color: "#e0def4"
	font.pixelSize: 13

	width: Math.min(parent.width - 20, 480) 

	elide: Text.ElideRight
	horizontalAlignment: Text.AlignHCenter
      }
    }

    Item { Layout.fillWidth: true } // Spacer

    // Music
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: musicRow.width + 24
      color: "#CC232136"
      radius: 10
      visible: Mpris.players.values.length > 0

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
              // Scale the 0-100 cava value to a 2-16px height
              height: 2 + (visualizer.barValues[index] / 100) * 14
              radius: 1
              color: "#ea9a97"
              anchors.verticalCenter: parent.verticalCenter
              
              Behavior on height {
                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
              }
            }
          }

          Process {
            command: ["sh", "-c", `printf "[general]\\nbars=6\\nsensitivity=60\\n[output]\\nmethod=raw\\ndata_format=ascii\\nascii_max_range=100\\n[smoothing]\\nintegral=80\\ngravity=100" | cava -p /dev/stdin`]
            running: true
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

	// Mpris
        Text {
          property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
          text: (activePlayer ? " " : "󰝛 ") + 
                (activePlayer ? (activePlayer.trackTitle || "Unknown") + " - " + (activePlayer.trackArtist || "Unknown") : "No Media")
          
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
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.updateTime() }
        Component.onCompleted: updateTime()
      }
    }
  }
}
