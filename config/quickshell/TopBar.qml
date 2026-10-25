pragma ComponentBehavior: Bound

import org.kde.bluezqt as BluezQt
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
	id: root

	color: "transparent"
	implicitHeight: 24

	anchors {
		left: true
		right: true
		top: true
	}

	margins {
		left: 4
		right: 4
		top: 4
	}

	RowLayout {
		anchors.fill: parent
		spacing: 8

		// Workspaces
		Rectangle {
			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: Layout.preferredWidth
			Layout.preferredWidth: wsRow.implicitWidth + 4
			clip: true
			color: "#CC232136"
			radius: root.height / 2

			RowLayout {
				id: wsRow

				anchors.fill: parent
				spacing: 2

				Repeater {
					model: Hyprland.workspaces

					Rectangle {
						readonly property var cchars: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
						property string displayChar: modelData.name <= 10 ? cchars[modelData.name - 1] : modelData.name
						property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
						required property var modelData

						Layout.fillHeight: true
						Layout.preferredWidth: 35
						color: isActive ? "#c4a7e7" : "transparent"
						radius: root.height / 2

						Behavior on color {
							ColorAnimation {
								duration: 250
								easing.type: Easing.OutQuint
							}
						}

						Text {
							anchors.centerIn: parent
							color: parent.isActive ? "#232136" : "#e0def4"
							font.bold: true
							font.pixelSize: 16
							text: parent.displayChar

							Behavior on color {
								ColorAnimation {
									duration: 250
									easing.type: Easing.OutQuint
								}
							}
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor

							onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.modelData.id + " })")
						}
					}
				}
			}
		}

		Item {
			Layout.fillWidth: true
		}

		// Window title
		Rectangle {
			id: titlePill

			readonly property bool hasWindow: {
				const toplevel = Hyprland.activeToplevel;
				if (!toplevel || !Hyprland.focusedWorkspace)
					return false;
				let found = false;
				for (const window of Hyprland.focusedWorkspace.toplevels?.values ?? []) {
					if (window === toplevel) {
						found = true;
						break;
					}
				}
				if (!found)
					return false;

				return toplevel.workspace?.id === Hyprland.focusedWorkspace?.id;
			}

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: 0
			Layout.preferredWidth: hasWindow ? Math.max(80, Math.min(titleText.implicitWidth + 40, 500)) : 0
			clip: true
			color: "#CC232136"
			opacity: hasWindow ? 1 : 0
			radius: root.height / 2

			Behavior on Layout.preferredWidth {
				NumberAnimation {
					duration: 200
					easing.type: Easing.OutCubic
				}
			}
			Behavior on opacity {
				NumberAnimation {
					duration: 200
				}
			}

			Text {
				id: titleText

				property string fullTitle: (titlePill.hasWindow && Hyprland.activeToplevel) ? Hyprland.activeToplevel.title : ""
				property int step: 0

				anchors.centerIn: parent
				color: "#e0def4"
				elide: Text.ElideRight
				font.pixelSize: 12
				horizontalAlignment: Text.AlignHCenter
				text: (parent.hasWindow && fullTitle !== "") ? fullTitle.substring(0, step) : ""
				width: Math.min(parent.width - 20, implicitWidth)

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

		Item {
			Layout.fillWidth: true
		}

		// Music
		Rectangle {
			id: musicPill

			property bool hasPlayer: Mpris.players.values.length > 0

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: hasPlayer ? Math.min(Layout.preferredWidth, 400) : 0
			Layout.minimumWidth: 0
			Layout.preferredWidth: hasPlayer ? (musicRow.implicitWidth + 16) : 0
			clip: true
			color: "#CC232136"
			opacity: hasPlayer ? 1 : 0
			radius: root.height / 2

			Behavior on Layout.preferredWidth {
				NumberAnimation {
					duration: 250
					easing.type: Easing.OutCubic
				}
			}
			Behavior on opacity {
				NumberAnimation {
					duration: 250
				}
			}

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

				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 8
				spacing: 10

				Row {
					id: visualizer

					property var barValues: [0, 0, 0, 0, 0, 0]

					Layout.alignment: Qt.AlignVCenter
					spacing: 2

					Connections {
						function onPlaybackStateChanged() {
							if (target && target.playbackState !== MprisPlaybackState.Playing) {
								visualizer.barValues = [0, 0, 0, 0, 0, 0];
							}
						}

						target: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
					}

					Repeater {
						model: 6

						Rectangle {
							required property int index

							anchors.verticalCenter: parent.verticalCenter
							color: "#ea9a97"
							height: 2 + (visualizer.barValues[index] / 100) * 14
							radius: 1
							width: 3

							Behavior on height {
								NumberAnimation {
									duration: 80
									easing.type: Easing.OutQuad
								}
							}
						}
					}

					Process {
						command: ["sh", "-c", `printf "[general]\\nbars=6\\nsensitivity=60\\n[output]\\nmethod=raw\\ndata_format=ascii\\nascii_max_range=100\\n[smoothing]\\nintegral=80\\ngravity=100" | cava -p /dev/stdin`]
						running: musicPill.opacity > 0 && Mpris.players.values[0]?.playbackState === MprisPlaybackState.Playing

						stdout: SplitParser {
							onRead: data => {
								const parts = data.trim().split(';');
								if (parts.length >= 6) {
									let newValues = [];
									for (let i = 0; i < 6; i++)
										newValues.push(parseInt(parts[i]) || 0);
									visualizer.barValues = newValues;
								}
							}
						}
					}
				}

				Text {
					property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

					Layout.fillWidth: true
					Layout.minimumWidth: 0
					color: "#f6c177"
					elide: Text.ElideRight
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 12
					text: (activePlayer ? " " : "󰝛 ") + (activePlayer ? (activePlayer.trackTitle || "Unknown") + " - " + (activePlayer.trackArtist || "Unknown") : "")
				}
			}

			PopupWindow {
				id: musicPopup

				color: "transparent"
				implicitHeight: 170
				implicitWidth: 380
				visible: false

				HyprlandFocusGrab {
					active: musicPopup.visible
					windows: [musicPopup]

					onCleared: {
						closeTimer.start();
					}
				}

				anchor {
					edges: Edges.Bottom
					gravity: Edges.Bottom
					item: musicPill
					margins.top: 8
				}

				Timer {
					id: closeTimer

					interval: 250

					onTriggered: musicPopup.visible = false
				}

				Loader {
					id: musicPopupLoader

					active: musicPopup.visible
					anchors.fill: parent

					sourceComponent: Rectangle {
						id: popupContent

						readonly property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
						readonly property bool isClosing: closeTimer.running
						property bool isLoaded: false

						anchors.fill: parent
						clip: true
						color: "#CC232136"
						opacity: (isLoaded && !isClosing) ? 1 : 0
						radius: 12
						scale: (isLoaded && !isClosing) ? 1 : 0.95
						y: (isLoaded && !isClosing) ? 10 : -20

						Behavior on opacity {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutCubic
							}
						}
						Behavior on scale {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutBack
							}
						}
						Behavior on y {
							NumberAnimation {
								duration: 250
								easing.type: Easing.OutCubic
							}
						}

						Component.onCompleted: isLoaded = true

						Timer {
							interval: 500
							repeat: true
							running: musicPopup.visible && popupContent.activePlayer && popupContent.activePlayer.playbackState === MprisPlaybackState.Playing

							onTriggered: popupContent.activePlayer.positionChanged()
						}

						RowLayout {
							anchors.fill: parent
							anchors.margins: 16
							spacing: 16

							// Album Art
							Rectangle {
								Layout.alignment: Qt.AlignVCenter
								Layout.preferredHeight: 120
								Layout.preferredWidth: 120
								clip: true
								color: "#393552"
								radius: 8

								Image {
									anchors.fill: parent
									asynchronous: true
									fillMode: Image.PreserveAspectCrop
									source: popupContent.activePlayer ? popupContent.activePlayer.trackArtUrl : ""
								}
							}

							ColumnLayout {
								Layout.fillHeight: true
								Layout.fillWidth: true
								spacing: 4

								Text {
									Layout.fillWidth: true
									color: "#e0def4"
									elide: Text.ElideRight
									font.bold: true
									font.pixelSize: 16
									text: popupContent.activePlayer ? (popupContent.activePlayer.trackTitle || "Unknown Title") : "No Title"
								}

								Text {
									Layout.fillWidth: true
									color: "#908caa"
									elide: Text.ElideRight
									font.pixelSize: 13
									text: popupContent.activePlayer ? (popupContent.activePlayer.trackArtist || "Unknown Artist") : "No Artist"
								}

								Text {
									Layout.fillWidth: true
									color: "#6e6a86"
									elide: Text.ElideRight
									font.pixelSize: 12
									text: popupContent.activePlayer ? (popupContent.activePlayer.trackAlbum || "Unknown Album") : "No Album"
								}

								Item {
									Layout.fillHeight: true
								}

								// Progress Bar
								RowLayout {
									function formatTime(secondsIn) {
										if (!secondsIn)
											return "0:00";
										let seconds = Math.floor(secondsIn);
										let m = Math.floor(seconds / 60);
										let s = seconds % 60;
										return m + ":" + (s < 10 ? "0" : "") + s;
									}

									Layout.fillWidth: true
									spacing: 8

									Text {
										color: "#908caa"
										font.pixelSize: 10
										text: parent.formatTime(popupContent.activePlayer ? popupContent.activePlayer.position : 0)
									}

									Rectangle {
										Layout.fillWidth: true
										color: "#393552"
										implicitHeight: 6
										radius: 3

										Rectangle {
											color: "#c4a7e7"
											height: parent.height
											radius: 3
											width: {
												if (!popupContent.activePlayer || !popupContent.activePlayer.length)
													return 0;
												return Math.min(1, popupContent.activePlayer.position / popupContent.activePlayer.length) * parent.width;
											}
										}

										MouseArea {
											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor

											onClicked: mouse => {
												if (popupContent.activePlayer && popupContent.activePlayer.length) {
													let clickRatio = mouse.x / width;
													popupContent.activePlayer.position = clickRatio * popupContent.activePlayer.length;
												}
											}
										}
									}

									Text {
										color: "#908caa"
										font.pixelSize: 10
										text: parent.formatTime(popupContent.activePlayer ? popupContent.activePlayer.length : 0)
									}
								}

								Item {
									Layout.fillHeight: true
								}

								// Media Controls
								RowLayout {
									Layout.alignment: Qt.AlignHCenter
									Layout.fillWidth: true
									spacing: 16

									// Previous
									Rectangle {
										color: prevArea.containsMouse ? "#393552" : "transparent"
										implicitHeight: 36
										implicitWidth: 36
										radius: 18

										Behavior on color {
											ColorAnimation {
												duration: 150
											}
										}

										Text {
											anchors.centerIn: parent
											color: prevArea.containsMouse ? "#c4a7e7" : "#e0def4"
											font.family: "JetBrainsMono Nerd Font"
											font.pixelSize: 20
											text: "󰒮"

											Behavior on color {
												ColorAnimation {
													duration: 150
												}
											}
										}

										MouseArea {
											id: prevArea

											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor
											hoverEnabled: true

											onClicked: if (popupContent.activePlayer)
												popupContent.activePlayer.previous()
										}
									}

									// Play / Pause
									Rectangle {
										property bool isPlaying: popupContent.activePlayer ? popupContent.activePlayer.playbackState === MprisPlaybackState.Playing : false

										color: playArea.containsMouse ? "#c4a7e7" : "#393552"
										implicitHeight: 44
										implicitWidth: 44
										radius: 22

										Behavior on color {
											ColorAnimation {
												duration: 150
											}
										}

										Text {
											anchors.centerIn: parent
											color: playArea.containsMouse ? "#232136" : "#e0def4"
											font.family: "JetBrainsMono Nerd Font"
											font.pixelSize: 22
											text: parent.isPlaying ? "󰏤" : "󰐊"

											Behavior on color {
												ColorAnimation {
													duration: 150
												}
											}
										}

										MouseArea {
											id: playArea

											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor
											hoverEnabled: true

											onClicked: if (popupContent.activePlayer)
												popupContent.activePlayer.togglePlaying()
										}
									}

									// Next
									Rectangle {
										color: nextArea.containsMouse ? "#393552" : "transparent"
										implicitHeight: 36
										implicitWidth: 36
										radius: 18

										Behavior on color {
											ColorAnimation {
												duration: 150
											}
										}

										Text {
											anchors.centerIn: parent
											color: nextArea.containsMouse ? "#c4a7e7" : "#e0def4"
											font.family: "JetBrainsMono Nerd Font"
											font.pixelSize: 20
											text: "󰒭"

											Behavior on color {
												ColorAnimation {
													duration: 150
												}
											}
										}

										MouseArea {
											id: nextArea

											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor
											hoverEnabled: true

											onClicked: if (popupContent.activePlayer)
												popupContent.activePlayer.next()
										}
									}
								}
							}
						}
					}
				}
			}
		}

		Rectangle {
			id: volumePill

			property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
			property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: Layout.preferredWidth
			Layout.preferredWidth: volumeRow.implicitWidth + 16
			clip: true
			color: "#CC232136"
			radius: root.height / 2

			PwObjectTracker {
				objects: [Pipewire.defaultAudioSink]
			}

			RowLayout {
				id: volumeRow

				anchors.centerIn: parent
				spacing: 6

				Text {
					color: volumePill.muted ? "#6e6a86" : "#c4a7e7"
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 14
					text: volumePill.muted ? "󰝟" : (volumePill.volume >= 0.7 ? "󰕾" : (volumePill.volume >= 0.3 ? "󰖀" : "󰕿"))
				}

				Text {
					color: "#e0def4"
					font.bold: true
					font.pixelSize: 12
					text: Math.round(volumePill.volume * 100) + "%"
				}
			}
		}

		// Battery
		Rectangle {
			id: batteryPill

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: Layout.preferredWidth
			Layout.preferredWidth: batteryRow.implicitWidth + 16
			clip: true
			color: "#CC232136"
			radius: root.height / 2

			RowLayout {
				id: batteryRow

				anchors.centerIn: parent
				spacing: 6

				Text {
					property real percent: UPower.displayDevice ? UPower.displayDevice.percentage * 100 : 0
					property int state: UPower.displayDevice ? UPower.displayDevice.state : 0

					color: state === 1 ? "#9ccfd8" : (percent <= 20 ? "#eb6f92" : "#ebbcba")
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 14
					text: {
						if (state === 1)
							return "󰂄";
						if (percent >= 90)
							return "󰁹";
						if (percent >= 80)
							return "󰂂";
						if (percent >= 70)
							return "󰂁";
						if (percent >= 60)
							return "󰂀";
						if (percent >= 50)
							return "󰁿";
						if (percent >= 40)
							return "󰁾";
						if (percent >= 30)
							return "󰁽";
						if (percent >= 20)
							return "󰁼";
						if (percent >= 10)
							return "󰁻";
						return "󰂎";
					}
				}

				Text {
					color: "#e0def4"
					font.bold: true
					font.pixelSize: 12
					text: Math.round(UPower.displayDevice ? UPower.displayDevice.percentage * 100 : 0) + "%"
				}
			}
		}

		// Wi-Fi & Bluetooth
		Rectangle {
			id: netPill

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: Layout.preferredWidth
			Layout.preferredWidth: netRow.implicitWidth + 16
			clip: true
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

				Text {
					id: wifiText

					property bool isWifiOn: Networking.wifiEnabled && Networking.wifiHardwareEnabled
					property var wifiDevice: {
						for (let i = 0; i < Networking.devices.values.length; i++) {
							let dev = Networking.devices.values[i];
							if (dev.type === DeviceType.Wifi)
								return dev;
						}
						return null;
					}

					color: isWifiOn ? "#9ccfd8" : "#6e6a86"
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 14
					text: isWifiOn ? "󰖩" : "󰖪"

					Behavior on color {
						ColorAnimation {
							duration: 250
							easing.type: Easing.OutCubic
						}
					}
				}

				Text {
					color: BluezQt.Manager.bluetoothOperational ? "#c4a7e7" : "#6e6a86"
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 14
					text: BluezQt.Manager.bluetoothOperational ? "󰂯" : "󰂲"

					Behavior on color {
						ColorAnimation {
							duration: 250
							easing.type: Easing.OutCubic
						}
					}
				}
			}

			PopupWindow {
				id: netPopup

				property string activeTab: "wifi"

				color: "transparent"
				implicitHeight: 500
				implicitWidth: 420
				visible: false

				HyprlandFocusGrab {
					active: netPopup.visible
					windows: [netPopup]

					onCleared: netCloseTimer.start()
				}

				anchor {
					edges: Edges.Bottom
					gravity: Edges.Bottom
					item: netPill
					margins.top: 8
				}

				Timer {
					id: netCloseTimer

					interval: 250

					onTriggered: netPopup.visible = false
				}

				Loader {
					id: netPopupLoader

					active: netPopup.visible
					anchors.fill: parent

					sourceComponent: Rectangle {
						id: netPopupContent

						readonly property bool isClosing: netCloseTimer.running
						property bool isLoaded: false

						anchors.fill: parent
						clip: true
						color: "#CC232136"
						opacity: (isLoaded && !isClosing) ? 1 : 0
						radius: 12
						scale: (isLoaded && !isClosing) ? 1 : 0.95
						y: (isLoaded && !isClosing) ? 10 : -20

						Behavior on opacity {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutCubic
							}
						}
						Behavior on scale {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutBack
							}
						}
						Behavior on y {
							NumberAnimation {
								duration: 250
								easing.type: Easing.OutCubic
							}
						}

						Component.onCompleted: isLoaded = true

						ColumnLayout {
							anchors.fill: parent
							anchors.margins: 12
							spacing: 12

							RowLayout {
								Layout.fillWidth: true
								spacing: 8

								Rectangle {
									Layout.fillWidth: true
									color: "#393552"
									implicitHeight: 36
									radius: 18

									RowLayout {
										anchors.fill: parent
										spacing: 4

										Rectangle {
											Layout.fillHeight: true
											Layout.fillWidth: true
											color: netPopup.activeTab === "wifi" ? "#c4a7e7" : "transparent"
											radius: 18

											Behavior on color {
												ColorAnimation {
													duration: 250
													easing.type: Easing.OutCubic
												}
											}

											Text {
												anchors.centerIn: parent
												color: netPopup.activeTab === "wifi" ? "#232136" : "#e0def4"
												font.family: "JetBrainsMono Nerd Font"
												font.pixelSize: 16
												text: "󰖩"
											}

											MouseArea {
												anchors.fill: parent
												cursorShape: Qt.PointingHandCursor

												onClicked: netPopup.activeTab = "wifi"
											}
										}

										Rectangle {
											Layout.fillHeight: true
											Layout.fillWidth: true
											color: netPopup.activeTab === "bluetooth" ? "#c4a7e7" : "transparent"
											radius: 18

											Behavior on color {
												ColorAnimation {
													duration: 250
													easing.type: Easing.OutCubic
												}
											}

											Text {
												anchors.centerIn: parent
												color: netPopup.activeTab === "bluetooth" ? "#232136" : "#e0def4"
												font.family: "JetBrainsMono Nerd Font"
												font.pixelSize: 16
												text: "󰂯"
											}

											MouseArea {
												anchors.fill: parent
												cursorShape: Qt.PointingHandCursor

												onClicked: netPopup.activeTab = "bluetooth"
											}
										}
									}
								}

								Rectangle {
									color: refreshMouse.containsMouse ? "#403d4d" : "transparent"
									implicitHeight: 36
									implicitWidth: 36
									radius: 18

									Behavior on color {
										ColorAnimation {
											duration: 150
										}
									}

									Text {
										anchors.centerIn: parent
										color: "#e0def4"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 16
										text: ""

										RotationAnimation on rotation {
											duration: 1000
											from: 0
											loops: Animation.Infinite
											running: (netPopup.activeTab === "wifi" && tabLoader.item && tabLoader.item.isScanning) || (netPopup.activeTab === "bluetooth" && BluezQt.Manager.usableAdapter && BluezQt.Manager.usableAdapter.discovering)
											to: 360
										}
									}

									MouseArea {
										id: refreshMouse

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											if (netPopup.activeTab === "wifi") {
												if (tabLoader.item && tabLoader.item.updateWifiList)
													tabLoader.item.updateWifiList();
											} else if (netPopup.activeTab === "bluetooth") {
												if (tabLoader.item && tabLoader.item.updateBluetoothList)
													tabLoader.item.updateBluetoothList();
											}
										}
									}
								}
							}

							Item {
								Layout.fillHeight: true
								Layout.fillWidth: true

								Loader {
									id: tabLoader

									anchors.fill: parent
									sourceComponent: netPopup.activeTab === "wifi" ? wifiComponent : bluetoothComponent
								}
							}
						}
					}
				}

				Component {
					id: wifiComponent

					Item {
						id: wifiRoot

						property bool isScanning: false
						property bool passwordVisible: false
						property var pendingNetwork: null
						property var wifiDevice: {
							for (let i = 0; i < Networking.devices.values.length; i++) {
								let dev = Networking.devices.values[i];
								if (dev.type === DeviceType.Wifi)
									return dev;
							}
							return null;
						}

						function connectWithPassword() {
							if (wifiRoot.pendingNetwork && passwordInput.text.trim() !== "") {
								wifiRoot.pendingNetwork.connectWithPsk(passwordInput.text);
								passwordVisible = false;
								passwordInput.text = "";
								wifiRoot.pendingNetwork = null;
							}
						}

						function updateWifiList() {
							if (wifiDevice) {
								wifiDevice.scannerEnabled = false;
								wifiDevice.scannerEnabled = true;
								isScanning = true;
								scanTimer.restart();
							}
						}

						Component.onCompleted: {
							if (wifiDevice) {
								wifiDevice.scannerEnabled = true;
								isScanning = true;
								scanTimer.restart();
							}
						}
						Component.onDestruction: {
							if (wifiDevice) {
								wifiDevice.scannerEnabled = false;
							}
						}

						Timer {
							id: scanTimer

							interval: 4000

							onTriggered: wifiRoot.isScanning = false
						}

						ListView {
							id: wifiListView

							anchors.fill: parent
							clip: true
							model: wifiDevice ? wifiDevice.networks : null
							spacing: 6

							delegate: Rectangle {
								required property var modelData

								color: mouseArea.containsMouse ? "#403d4d" : "transparent"
								implicitHeight: 40
								radius: 8
								width: ListView.view.width

								RowLayout {
									anchors.fill: parent
									anchors.leftMargin: 10
									anchors.rightMargin: 10
									spacing: 8

									Text {
										color: modelData.connected ? "#9ccfd8" : "#e0def4"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 14
										text: "󰤨"
									}

									Text {
										Layout.fillWidth: true
										color: "#e0def4"
										elide: Text.ElideRight
										font.bold: modelData.connected
										font.pixelSize: 13
										text: modelData.name || "<hidden>"
									}

									Text {
										color: "#9ccfd8"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 14
										text: modelData.connected || modelData.known ? "" : ""
									}
								}

								Connections {
									function onConnectionFailed(reason) {
										if (reason === ConnectionFailReason.NoSecrets) {
											wifiRoot.pendingNetwork = modelData;
											wifiRoot.passwordVisible = true;
										}
									}

									target: modelData
								}

								MouseArea {
									id: mouseArea

									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									hoverEnabled: true

									onClicked: {
										if (modelData.connected) {
											modelData.disconnect();
										} else if (!modelData.known && modelData.security !== WifiSecurityType.Open) {
											wifiRoot.pendingNetwork = modelData;
											wifiRoot.passwordVisible = true;
										} else {
											modelData.connect();
										}
									}
								}
							}

							Component.onCompleted: {
								contentY = 0;
								positionViewAtBeginning();
							}
							onCountChanged: {
								contentY = 0;
							}
						}

						Rectangle {
							anchors.fill: parent
							color: "#CC232136"
							opacity: visible ? 1 : 0
							radius: 8
							scale: visible ? 1 : 0.95
							visible: wifiRoot.passwordVisible
							z: 1

							ColumnLayout {
								anchors.centerIn: parent
								spacing: 16
								width: parent.width - 40

								Text {
									Layout.fillWidth: true
									color: "#e0def4"
									elide: Text.ElideRight
									font.bold: true
									font.pixelSize: 16
									horizontalAlignment: Text.AlignHCenter
									text: wifiRoot.pendingNetwork ? wifiRoot.pendingNetwork.name : "Enter Password"
								}

								Rectangle {
									Layout.fillWidth: true
									border.color: passwordInput.activeFocus ? "#c4a7e7" : "transparent"
									border.width: 1
									color: "#393552"
									implicitHeight: 36
									radius: 18

									TextInput {
										id: passwordInput

										anchors.fill: parent
										anchors.leftMargin: 12
										anchors.rightMargin: 12
										color: "#e0def4"
										echoMode: TextInput.Password
										font.pixelSize: 13
										verticalAlignment: TextInput.AlignVCenter

										onAccepted: wifiRoot.connectWithPassword()
									}
								}

								RowLayout {
									Layout.alignment: Qt.AlignHCenter
									spacing: 24

									Rectangle {
										color: cancelMouse.containsMouse ? "#eb6f92" : "#393552"
										implicitHeight: 44
										implicitWidth: 44
										radius: 22

										Text {
											anchors.centerIn: parent
											color: cancelMouse.containsMouse ? "#232136" : "#eb6f92"
											font.family: "JetBrainsMono Nerd Font"
											font.pixelSize: 20
											text: ""
										}

										MouseArea {
											id: cancelMouse

											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor
											hoverEnabled: true

											onClicked: {
												wifiRoot.passwordVisible = false;
												passwordInput.text = "";
												wifiRoot.pendingNetwork = null;
											}
										}
									}

									Rectangle {
										color: connectMouse.containsMouse ? "#9ccfd8" : "#393552"
										implicitHeight: 44
										implicitWidth: 44
										radius: 22

										Text {
											anchors.centerIn: parent
											color: connectMouse.containsMouse ? "#232136" : "#9ccfd8"
											font.bold: true
											font.family: "JetBrainsMono Nerd Font"
											font.pixelSize: 20
											text: "󰄬"
										}

										MouseArea {
											id: connectMouse

											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor
											hoverEnabled: true

											onClicked: wifiRoot.connectWithPassword()
										}
									}
								}
							}
						}
					}
				}

				Component {
					id: bluetoothComponent

					Item {
						id: bluetoothRoot

						function addDevice(device) {
							if (!bluetoothModel || !device.name)
								return;
							bluetoothModel.append({
								address: device.address,
								name: device.name,
								connected: device.connected,
								paired: device.paired
							});
							sortModel();
						}

						function removeDevice(address) {
							for (let i = 0; i < bluetoothModel.count; ++i) {
								if (bluetoothModel.get(i).address === address) {
									bluetoothModel.remove(i);
									break;
								}
							}
						}

						function sortModel() {
							if (!bluetoothModel)
								return;
							let insertIdx = 0;
							for (let i = 0; i < bluetoothModel.count; ++i) {
								if (bluetoothModel.get(i).paired && bluetoothModel.get(i).connected) {
									if (i > insertIdx)
										bluetoothModel.move(i, insertIdx, 1);
									insertIdx++;
								}
							}
							for (let i = insertIdx; i < bluetoothModel.count; ++i) {
								if (bluetoothModel.get(i).paired && !bluetoothModel.get(i).connected) {
									if (i > insertIdx)
										bluetoothModel.move(i, insertIdx, 1);
									insertIdx++;
								}
							}
						}

						function updateBluetoothList() {
							const adapter = BluezQt.Manager.usableAdapter;
							if (adapter) {
								if (adapter.discovering) {
									adapter.stopDiscovery();
								} else {
									adapter.startDiscovery();
									btScanTimer.restart();
								}
							}
							bluetoothModel.clear();
							for (const device of BluezQt.Manager.devices)
								addDevice(device);
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

						Component.onCompleted: {
							const adapter = BluezQt.Manager.usableAdapter;
							if (adapter) {
								if (!adapter.discovering)
									adapter.startDiscovery();
								btScanTimer.restart();
							}
							for (const device of BluezQt.Manager.devices)
								addDevice(device);
						}
						Component.onDestruction: {
							const adapter = BluezQt.Manager.usableAdapter;
							if (adapter && adapter.discovering) {
								adapter.stopDiscovery();
							}
						}

						Timer {
							id: btScanTimer

							interval: 5000

							onTriggered: {
								const adapter = BluezQt.Manager.usableAdapter;
								if (adapter && adapter.discovering) {
									adapter.stopDiscovery();
								}
							}
						}

						ListModel {
							id: bluetoothModel
						}

						Connections {
							function onDeviceAdded(device) {
								bluetoothRoot.addDevice(device);
							}

							function onDeviceChanged(device) {
								if (!bluetoothModel)
									return;
								let found = false;
								for (let i = 0; i < bluetoothModel.count; ++i) {
									if (bluetoothModel.get(i).address === device.address) {
										found = true;
										break;
									}
								}
								if (found)
									bluetoothRoot.updateDevice(device);
								else
									bluetoothRoot.addDevice(device);
							}

							function onDeviceRemoved(device) {
								if (bluetoothModel)
									bluetoothRoot.removeDevice(device.address);
							}

							target: BluezQt.Manager
						}

						ListView {
							anchors.fill: parent
							clip: true
							model: bluetoothModel
							spacing: 6

							delegate: Rectangle {
								required property var model

								color: mouseAreaBt.containsMouse ? "#403d4d" : "transparent"
								implicitHeight: 40
								radius: 8
								width: ListView.view.width

								RowLayout {
									anchors.fill: parent
									anchors.leftMargin: 10
									anchors.rightMargin: 10
									spacing: 8

									Text {
										color: model.connected ? "#9ccfd8" : (model.paired ? "#e0def4" : "#6e6a86")
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 14
										text: "󰂱"
									}

									Text {
										Layout.fillWidth: true
										color: model.paired ? "#e0def4" : "#908caa"
										elide: Text.ElideRight
										font.bold: model.connected
										font.pixelSize: 13
										text: model.name
									}

									Text {
										color: model.connected ? "#9ccfd8" : "#c4a7e7"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 14
										text: model.paired ? (model.connected ? "" : "") : ""
									}

									Rectangle {
										color: unpairMouse.containsMouse ? "#eb6f92" : "transparent"
										implicitHeight: 28
										implicitWidth: 28
										radius: 14
										visible: model.paired

										Text {
											anchors.centerIn: parent
											color: unpairMouse.containsMouse ? "#232136" : "#eb6f92"
											font.family: "JetBrainsMono Nerd Font"
											font.pixelSize: 14
											text: "󰆴"
										}

										MouseArea {
											id: unpairMouse

											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor
											hoverEnabled: true

											onClicked: {
												const devices = BluezQt.Manager.devices;
												for (const dev of devices) {
													if (dev.address === model.address) {
														if (BluezQt.Manager.usableAdapter)
															BluezQt.Manager.usableAdapter.removeDevice(dev);
														break;
													}
												}
											}
										}
									}
								}

								MouseArea {
									id: mouseAreaBt

									anchors.fill: parent
									anchors.rightMargin: model.paired ? 32 : 0
									cursorShape: Qt.PointingHandCursor
									hoverEnabled: true

									onClicked: {
										const devices = BluezQt.Manager.devices;
										for (const dev of devices) {
											if (dev.address === model.address) {
												if (!model.paired) {
													dev.trusted = true;
													dev.connectToDevice();
												} else {
													if (model.connected)
														dev.disconnectFromDevice();
													else
														dev.connectToDevice();
												}
												break;
											}
										}
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
			id: clockPill

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: Layout.preferredWidth
			Layout.preferredWidth: clock.contentWidth + 16
			clip: true
			color: "#CC232136"
			radius: root.height / 2

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor

				onClicked: {
					if (!calPopup.visible) {
						calPopup.displayedDate = new Date();
						calPopup.updateCalendar();
						calPopup.visible = true;
					} else {
						calCloseTimer.start();
					}
				}
			}

			Text {
				id: clock

				function updateTime() {
					text = Qt.formatDateTime(new Date(), "ddd d MMM hh:mm:ss");
				}

				anchors.centerIn: parent
				color: "#3e8fb0"
				font.bold: true
				font.pixelSize: 12

				Component.onCompleted: updateTime()

				Timer {
					interval: 500
					repeat: true
					running: true

					onTriggered: clock.updateTime()
				}
			}

			PopupWindow {
				id: calPopup

				property var daysModel: []
				property var displayedDate: new Date()
				property var selectedDate: new Date()

				function updateCalendar() {
					let d = new Date(displayedDate.getFullYear(), displayedDate.getMonth(), 1);
					let firstDay = d.getDay();
					let daysInMonth = new Date(displayedDate.getFullYear(), displayedDate.getMonth() + 1, 0).getDate();
					let daysInPrevMonth = new Date(displayedDate.getFullYear(), displayedDate.getMonth(), 0).getDate();

					let today = new Date();
					let arr = [];

					for (let i = firstDay - 1; i >= 0; i--) {
						let date = new Date(displayedDate.getFullYear(), displayedDate.getMonth() - 1, daysInPrevMonth - i);
						arr.push({
							day: daysInPrevMonth - i,
							isCurrent: false,
							isToday: false,
							date: date
						});
					}

					for (let i = 1; i <= daysInMonth; i++) {
						let date = new Date(displayedDate.getFullYear(), displayedDate.getMonth(), i);
						let isToday = (i === today.getDate() && displayedDate.getMonth() === today.getMonth() && displayedDate.getFullYear() === today.getFullYear());
						arr.push({
							day: i,
							isCurrent: true,
							isToday: isToday,
							date: date
						});
					}

					let remaining = 42 - arr.length;
					for (let i = 1; i <= remaining; i++) {
						let date = new Date(displayedDate.getFullYear(), displayedDate.getMonth() + 1, i);
						arr.push({
							day: i,
							isCurrent: false,
							isToday: false,
							date: date
						});
					}
					daysModel = arr;
				}

				color: "transparent"
				implicitHeight: 330
				implicitWidth: 300
				visible: false

				HyprlandFocusGrab {
					active: calPopup.visible
					windows: [calPopup]

					onCleared: calCloseTimer.start()
				}

				anchor {
					edges: Edges.Bottom
					gravity: Edges.Bottom
					item: clockPill
					margins.top: 8
				}

				Timer {
					id: calCloseTimer

					interval: 250

					onTriggered: calPopup.visible = false
				}

				Loader {
					id: calPopupLoader

					active: calPopup.visible
					anchors.fill: parent

					sourceComponent: Rectangle {
						id: calPopupContent

						readonly property bool isClosing: calCloseTimer.running
						property bool isLoaded: false

						anchors.fill: parent
						clip: true
						color: "#CC232136"
						opacity: (isLoaded && !isClosing) ? 1 : 0
						radius: 12
						scale: (isLoaded && !isClosing) ? 1 : 0.95
						y: (isLoaded && !isClosing) ? 10 : -20

						Behavior on opacity {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutCubic
							}
						}
						Behavior on scale {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutBack
							}
						}
						Behavior on y {
							NumberAnimation {
								duration: 250
								easing.type: Easing.OutCubic
							}
						}

						Component.onCompleted: isLoaded = true

						ColumnLayout {
							anchors.fill: parent
							anchors.margins: 16
							spacing: 16

							RowLayout {
								Layout.fillWidth: true

								Text {
									color: prevMonthMa.containsMouse ? "#c4a7e7" : "#908caa"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 16
									text: ""

									MouseArea {
										id: prevMonthMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											calPopup.displayedDate = new Date(calPopup.displayedDate.getFullYear(), calPopup.displayedDate.getMonth() - 1, 1);
											calPopup.updateCalendar();
										}
									}
								}

								Text {
									Layout.fillWidth: true
									color: "#e0def4"
									font.bold: true
									font.pixelSize: 15
									horizontalAlignment: Text.AlignHCenter
									text: Qt.formatDateTime(calPopup.displayedDate, "MMMM yyyy")
								}

								Text {
									color: nextMonthMa.containsMouse ? "#c4a7e7" : "#908caa"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 16
									text: ""

									MouseArea {
										id: nextMonthMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											calPopup.displayedDate = new Date(calPopup.displayedDate.getFullYear(), calPopup.displayedDate.getMonth() + 1, 1);
											calPopup.updateCalendar();
										}
									}
								}
							}

							GridLayout {
								Layout.fillWidth: true
								columnSpacing: 4
								columns: 7
								rowSpacing: 8

								Repeater {
									model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

									Text {
										required property string modelData

										Layout.fillWidth: true
										color: "#908caa"
										font.bold: true
										font.pixelSize: 12
										horizontalAlignment: Text.AlignHCenter
										text: modelData
									}
								}

								Repeater {
									model: calPopup.daysModel

									Item {
										readonly property bool isSelected: modelData.date.getTime() === calPopup.selectedDate.getTime()
										readonly property bool isToday: modelData.isToday
										required property var modelData

										Layout.fillWidth: true
										Layout.preferredHeight: width

										Rectangle {
											anchors.centerIn: parent
											color: parent.isSelected ? "#ebbcba" : (parent.isToday ? "#9ccfd8" : "transparent")
											height: 30
											radius: 15
											width: 30

											Text {
												anchors.centerIn: parent
												color: (parent.parent.isToday || parent.parent.isSelected) ? "#232136" : (parent.parent.modelData.isCurrent ? "#e0def4" : "#6e6a86")
												font.bold: parent.parent.isToday || parent.parent.isSelected
												font.pixelSize: 13
												text: parent.parent.modelData.day
											}
										}

										MouseArea {
											anchors.fill: parent
											cursorShape: Qt.PointingHandCursor

											onClicked: {
												let d = new Date(parent.modelData.date);
												d.setHours(0, 0, 0, 0);
												calPopup.selectedDate = d;
											}
										}
									}
								}
							}

							Item {
								Layout.fillHeight: true
							}
						}
					}
				}
			}
		}

		// System Menu
		Rectangle {
			id: sysPill

			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.maximumWidth: Layout.preferredWidth
			Layout.minimumWidth: Layout.preferredWidth
			Layout.preferredWidth: sysRow.implicitWidth + 16
			clip: true
			color: "#CC232136"
			radius: root.height / 2

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor

				onClicked: {
					if (!sysPopup.visible) {
						sysPopup.visible = true;
					} else {
						sysCloseTimer.start();
					}
				}
			}

			RowLayout {
				id: sysRow

				anchors.centerIn: parent
				spacing: 6

				Text {
					color: "#9ccfd8"
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 14
					text: ""
				}
			}

			PopupWindow {
				id: sysPopup

				color: "transparent"
				implicitHeight: 380
				implicitWidth: 320
				visible: false

				HyprlandFocusGrab {
					active: sysPopup.visible
					windows: [sysPopup]

					onCleared: sysCloseTimer.start()
				}

				anchor {
					edges: Edges.Bottom
					gravity: Edges.Bottom
					item: sysPill
					margins.top: 8
				}

				Timer {
					id: sysCloseTimer

					interval: 250

					onTriggered: sysPopup.visible = false
				}

				Loader {
					id: sysPopupLoader

					active: sysPopup.visible
					anchors.fill: parent

					sourceComponent: Rectangle {
						id: sysPopupContent

						property real cpuUsage: 0
						property real diskUsage: 0
						readonly property bool isClosing: sysCloseTimer.running
						property bool isLoaded: false
						property real netRx: 0
						property real netTx: 0
						property real ramMax: 1
						property real ramUsage: 0
						property real sysTemp: 0
						property string sysUptime: "0h 0m"

						function formatBytes(bytes) {
							if (bytes === 0)
								return "0 B/s";
							const k = 1024;
							const sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
							const i = Math.floor(Math.log(bytes) / Math.log(k));
							return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
						}

						anchors.fill: parent
						clip: true
						color: "#CC232136"
						opacity: (isLoaded && !isClosing) ? 1 : 0
						radius: 12
						scale: (isLoaded && !isClosing) ? 1 : 0.95
						y: (isLoaded && !isClosing) ? 10 : -20

						Behavior on opacity {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutCubic
							}
						}
						Behavior on scale {
							NumberAnimation {
								duration: 200
								easing.type: Easing.OutBack
							}
						}
						Behavior on y {
							NumberAnimation {
								duration: 250
								easing.type: Easing.OutCubic
							}
						}

						Component.onCompleted: isLoaded = true

						FileView {
							id: sysstatFile

							path: "/dev/shm/sysstat.json"
							printErrors: false
							watchChanges: true

							onFileChanged: reload()
							onLoaded: {
								try {
									const s = JSON.parse(text());
									sysPopupContent.cpuUsage = s.cpu ?? 0;
									sysPopupContent.ramUsage = s.ram ?? 0;
									sysPopupContent.ramMax = s.ramMax ?? 1;
									sysPopupContent.diskUsage = s.disk ?? 0;
									sysPopupContent.sysUptime = s.uptime ?? "0h 0m";
									sysPopupContent.sysTemp = (s.temp ?? 0) / 1000.0;
									sysPopupContent.netRx = s.rx ?? 0;
									sysPopupContent.netTx = s.tx ?? 0;
								} catch (e) {
									console.error("sysstat parse error:", e);
								}
							}
						}

						Timer {
							interval: 2000
							repeat: true
							running: sysPopup.visible && !sysCloseTimer.running

							onTriggered: sysstatFile.reload()
						}

						ColumnLayout {
							anchors.fill: parent
							anchors.margins: 16
							spacing: 16

							// CPU
							RowLayout {
								Layout.fillWidth: true
								spacing: 12

								Text {
									Layout.preferredWidth: 20
									color: "#eb6f92"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 16
									text: ""
								}

								Rectangle {
									Layout.fillWidth: true
									color: "#393552"
									implicitHeight: 8
									radius: 4

									Rectangle {
										color: "#eb6f92"
										height: parent.height
										radius: 4
										width: parent.width * (sysPopupContent.cpuUsage / 100)

										Behavior on width {
											NumberAnimation {
												duration: 500
												easing.type: Easing.OutCubic
											}
										}
									}
								}

								Text {
									Layout.preferredWidth: 50
									color: "#e0def4"
									font.pixelSize: 12
									horizontalAlignment: Text.AlignRight
									text: sysPopupContent.cpuUsage + "%"
								}
							}

							// RAM
							RowLayout {
								Layout.fillWidth: true
								spacing: 12

								Text {
									Layout.preferredWidth: 20
									color: "#f6c177"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 16
									text: ""
								}

								Rectangle {
									Layout.fillWidth: true
									color: "#393552"
									implicitHeight: 8
									radius: 4

									Rectangle {
										color: "#f6c177"
										height: parent.height
										radius: 4
										width: parent.width * (sysPopupContent.ramUsage / sysPopupContent.ramMax)

										Behavior on width {
											NumberAnimation {
												duration: 500
												easing.type: Easing.OutCubic
											}
										}
									}
								}

								Text {
									Layout.preferredWidth: 50
									color: "#e0def4"
									font.pixelSize: 12
									horizontalAlignment: Text.AlignRight
									text: Math.round((sysPopupContent.ramUsage / sysPopupContent.ramMax) * 100) + "%"
								}
							}

							// Disk
							RowLayout {
								Layout.fillWidth: true
								spacing: 12

								Text {
									Layout.preferredWidth: 20
									color: "#c4a7e7"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 16
									text: "󰋊"
								}

								Rectangle {
									Layout.fillWidth: true
									color: "#393552"
									implicitHeight: 8
									radius: 4

									Rectangle {
										color: "#c4a7e7"
										height: parent.height
										radius: 4
										width: parent.width * (sysPopupContent.diskUsage / 100)

										Behavior on width {
											NumberAnimation {
												duration: 500
												easing.type: Easing.OutCubic
											}
										}
									}
								}

								Text {
									Layout.preferredWidth: 50
									color: "#e0def4"
									font.pixelSize: 12
									horizontalAlignment: Text.AlignRight
									text: sysPopupContent.diskUsage + "%"
								}
							}

							Item {
								Layout.fillHeight: true
							}

							GridLayout {
								Layout.fillWidth: true
								columnSpacing: 16
								columns: 2
								rowSpacing: 12

								RowLayout {
									Layout.fillWidth: true
									spacing: 8

									Text {
										color: "#f6c177"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: "󰔚"
									}

									Text {
										Layout.fillWidth: true
										color: "#e0def4"
										font.pixelSize: 13
										text: "Up: " + sysPopupContent.sysUptime
									}
								}

								RowLayout {
									Layout.fillWidth: true
									spacing: 8

									Text {
										color: "#ea9a97"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: ""
									}

									Text {
										Layout.fillWidth: true
										color: "#e0def4"
										font.pixelSize: 13
										text: Math.round(sysPopupContent.sysTemp) + "°C"
									}
								}

								RowLayout {
									Layout.fillWidth: true
									spacing: 8

									Text {
										color: "#9ccfd8"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 16
										text: "󰁅"
									}

									Text {
										Layout.fillWidth: true
										color: "#e0def4"
										font.pixelSize: 12
										text: sysPopupContent.formatBytes(sysPopupContent.netRx)
									}
								}

								RowLayout {
									Layout.fillWidth: true
									spacing: 8

									Text {
										color: "#eb6f92"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 16
										text: "󰁝"
									}

									Text {
										Layout.fillWidth: true
										color: "#e0def4"
										font.pixelSize: 12
										text: sysPopupContent.formatBytes(sysPopupContent.netTx)
									}
								}
							}

							Item {
								Layout.fillHeight: true
							}

							Rectangle {
								Layout.fillWidth: true
								color: "#393552"
								implicitHeight: 1
							}

							Item {
								Layout.fillHeight: true
							}

							RowLayout {
								Layout.alignment: Qt.AlignHCenter
								Layout.fillWidth: true
								spacing: 16

								Rectangle {
									color: pwrOffMa.containsMouse ? "#eb6f92" : "#393552"
									implicitHeight: 40
									implicitWidth: 40
									radius: 20

									Text {
										anchors.centerIn: parent
										color: pwrOffMa.containsMouse ? "#232136" : "#eb6f92"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: ""
									}

									MouseArea {
										id: pwrOffMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											sysPopup.visible = false;
											Hyprland.dispatch("exec systemctl poweroff");
										}
									}
								}

								Rectangle {
									color: pwrReMa.containsMouse ? "#f6c177" : "#393552"
									implicitHeight: 40
									implicitWidth: 40
									radius: 20

									Text {
										anchors.centerIn: parent
										color: pwrReMa.containsMouse ? "#232136" : "#f6c177"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: ""
									}

									MouseArea {
										id: pwrReMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											sysPopup.visible = false;
											Hyprland.dispatch("exec systemctl reboot");
										}
									}
								}

								Rectangle {
									color: pwrSlMa.containsMouse ? "#c4a7e7" : "#393552"
									implicitHeight: 40
									implicitWidth: 40
									radius: 20

									Text {
										anchors.centerIn: parent
										color: pwrSlMa.containsMouse ? "#232136" : "#c4a7e7"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: "󰤄"
									}

									MouseArea {
										id: pwrSlMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											sysPopup.visible = false;
											Hyprland.dispatch("exec systemctl suspend");
										}
									}
								}

								Rectangle {
									color: pwrLkMa.containsMouse ? "#9ccfd8" : "#393552"
									implicitHeight: 40
									implicitWidth: 40
									radius: 20

									Text {
										anchors.centerIn: parent
										color: pwrLkMa.containsMouse ? "#232136" : "#9ccfd8"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: ""
									}

									MouseArea {
										id: pwrLkMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											sysPopup.visible = false;
											Hyprland.dispatch("exec systemctl lock");
										}
									}
								}

								Rectangle {
									color: pwrExMa.containsMouse ? "#ea9a97" : "#393552"
									implicitHeight: 40
									implicitWidth: 40
									radius: 20

									Text {
										anchors.centerIn: parent
										color: pwrExMa.containsMouse ? "#232136" : "#ea9a97"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 18
										text: "󰗽"
									}

									MouseArea {
										id: pwrExMa

										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										hoverEnabled: true

										onClicked: {
											sysPopup.visible = false;
											Hyprland.dispatch("exit");
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
