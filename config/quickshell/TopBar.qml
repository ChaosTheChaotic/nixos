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

  height: 35
  color: "transparent"

  RowLayout {
    anchors.fill: parent
    spacing: 12

    // Workspace
    Rectangle {
      Layout.fillHeight: true
      implicitWidth: wsRow.width + 20
      color: "#232136"
      radius: 10
      border.color: "#393552"
      border.width: 2

      Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
          model: Hyprland.workspaces

          Rectangle {
            id: workspacePill
            property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
            
            readonly property var cchars: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
            property string displayChar: modelData.name <= 10 ? cchars[modelData.name - 1] : modelData.name

            width: isActive ? 34 : 24 
            height: 24
            radius: 12
            color: isActive ? "#c4a7e7" : "#6e6a86" 

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 200 } }

            Text {
              anchors.centerIn: parent
              text: parent.displayChar
              color: parent.isActive ? "#232136" : "#e0def4"
              font.bold: true
              font.pixelSize: 12
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: modelData.focus() 
            }
          }
        }
      }
    }

    // Window Title
    Rectangle {
      id: titleIsland
      Layout.fillHeight: true
      Layout.fillWidth: true
      color: "#232136"
      radius: 10
      border.color: "#393552"
      border.width: 2
      visible: windowTitle.text !== ""

      Text {
        id: windowTitle
        anchors.centerIn: parent
        width: parent.width - 20
        text: Hyprland.focusedWindow?.title ?? ""
        horizontalAlignment: Text.AlignHCenter
        color: "#e0def4"
        font.pixelSize: 13
        font.bold: true
        elide: Text.ElideRight
      }
    }

    // Music and Clock
    Rectangle {
      Layout.alignment: Qt.AlignRight | Qt.AlignTop
      Layout.fillHeight: true
      implicitWidth: musicRow.width + 20
      color: "#232136"
      radius: 10
      border.color: "#393552"
      border.width: 2

      RowLayout {
        id: musicRow
        anchors.centerIn: parent
        spacing: 15

        // Cava
        Text {
          id: cavaOutput
          color: "#ea9a97"
          font.family: "Monospace" 
          font.pixelSize: 14
          
          Process {
            command: ["sh", "-c", "CONF=$(mktemp); printf '[output]\\nmethod = raw\\ndata_format = ascii\\nascii_max_range = 7\\nbars = 8' > $CONF; cava -p $CONF"]
            running: true
            stdout: Process.Read
            onStdoutChanged: cavaOutput.text = stdout.trim()
          }
        }

        // MPRIS
	Text {
	  id: mprisText
	  property var activePlayer: Mpris.players.length > 0 ? Mpris.players[0] : null

	  function updateMetadata() {
	    if (activePlayer) {
	      text = "  " + (activePlayer.trackArtist || "Unknown") + 
	      " - " + (activePlayer.trackTitle || "Unknown");
	    } else {
	      text = "  No Media";
	    }
	  }

	  Connections {
	    target: Mpris
	    function onPlayersChanged() { 
	      mprisText.updateMetadata(); 
	    }
	  }

	  Connections {
	    target: mprisText.activePlayer
	    enabled: mprisText.activePlayer !== null
	    function onTrackArtistChanged() { mprisText.updateMetadata(); }
	    function onTrackTitleChanged() { mprisText.updateMetadata(); }
	  }

	  color: "#f6c177"
	  font.pixelSize: 13
	  elide: Text.ElideRight
	  Layout.maximumWidth: titleIsland.visible ? 200 : 400

	  Component.onCompleted: updateMetadata()
	}

        // Date and Time
        Text {
          id: clock
          color: "#3e8fb0"
          font.pixelSize: 13
          font.bold: true
          
          function updateTime() {
            clock.text = Qt.formatDateTime(new Date(), "ddd d MMM  hh:mm:ss")
          }

          Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.updateTime()
          }
          Component.onCompleted: clock.updateTime()
        }
      }
    }
  }
}
