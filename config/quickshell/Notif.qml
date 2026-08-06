pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
	id: root

	WlrLayershell.layer: WlrLayer.Overlay

	color: "transparent"
	implicitHeight: mainLayout.implicitHeight
	implicitWidth: 380
	visible: notificationModel.count > 0

	anchors {
		right: true
		top: true
	}

	margins {
		right: 8
		top: 36
	}

	NotificationServer {
		id: server

		actionsSupported: true
		bodyImagesSupported: true
		bodyMarkupSupported: true
		bodySupported: true
		imageSupported: true
		inlineReplySupported: true

		onNotification: notification => {
			notification.tracked = true;
			notificationModel.append({
				modelData: notification
			});

			// Auto remove when the notification is dropped
			notification.Retainable.dropped.connect(() => {
				for (let i = 0; i < notificationModel.count; i++) {
					if (notificationModel.get(i).modelData === notification) {
						notificationModel.remove(i);
						break;
					}
				}
			});
		}
	}

	ListModel {
		id: notificationModel
	}

	ColumnLayout {
		id: mainLayout

		anchors.fill: parent
		spacing: 8

		Repeater {
			model: notificationModel

			delegate: Rectangle {
				id: notifCard

				required property var modelData

				Layout.fillWidth: true
				Layout.preferredHeight: contentLayout.implicitHeight + 24
				border.color: "#393552"
				border.width: 1
				clip: true
				color: "#CC232136"
				radius: 12

				ColumnLayout {
					id: contentLayout

					anchors.fill: parent
					anchors.margins: 12
					spacing: 8

					RowLayout {
						Layout.fillWidth: true
						spacing: 8

						Image {
							Layout.preferredHeight: 16
							Layout.preferredWidth: 16
							fillMode: Image.PreserveAspectFit
							source: notifCard.modelData.appIcon || ""
							visible: source !== ""
						}

						Text {
							Layout.fillWidth: true
							color: "#908caa"
							elide: Text.ElideRight
							font.bold: true
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 11
							text: notifCard.modelData.appName || "System"
						}

						Rectangle {
							color: closeMouse.containsMouse ? "#eb6f92" : "transparent"
							implicitHeight: 20
							implicitWidth: 20
							radius: 10

							Behavior on color {
								ColorAnimation {
									duration: 150
								}
							}

							Text {
								anchors.centerIn: parent
								color: closeMouse.containsMouse ? "#232136" : "#908caa"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 12
								text: "󰅖"
							}

							MouseArea {
								id: closeMouse

								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								hoverEnabled: true

								onClicked: {
									notifCard.modelData.dismiss();
									notificationModel.remove(index);
								}
							}
						}
					}

					RowLayout {
						Layout.fillWidth: true
						spacing: 10

						Image {
							Layout.preferredHeight: 48
							Layout.preferredWidth: 48
							fillMode: Image.PreserveAspectCrop
							source: notifCard.modelData.image || ""
							visible: source !== ""
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 4

							Text {
								Layout.fillWidth: true
								color: "#e0def4"
								elide: Text.ElideRight
								font.bold: true
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								text: notifCard.modelData.summary || ""
								visible: text !== ""
							}

							Text {
								Layout.fillWidth: true
								color: "#e0def4"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 12
								text: notifCard.modelData.body || ""
								visible: text !== ""
								wrapMode: Text.WordWrap
							}
						}
					}

					RowLayout {
						Layout.fillWidth: true
						spacing: 8
						visible: notifCard.modelData.actions.length > 0

						Repeater {
							model: notifCard.modelData.actions

							delegate: Rectangle {
								required property var modelData

								Layout.fillWidth: true
								color: actionMouse.containsMouse ? "#c4a7e7" : "#393552"
								implicitHeight: 28
								radius: 6

								Behavior on color {
									ColorAnimation {
										duration: 150
									}
								}

								Text {
									anchors.centerIn: parent
									color: actionMouse.containsMouse ? "#232136" : "#e0def4"
									font.bold: true
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 11
									text: modelData.text
								}

								MouseArea {
									id: actionMouse

									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									hoverEnabled: true

									onClicked: {
										modelData.invoke();
										notifCard.modelData.dismiss();
									}
								}
							}
						}
					}

					RowLayout {
						Layout.fillWidth: true
						spacing: 6
						visible: notifCard.modelData.hasInlineReply

						Rectangle {
							Layout.fillWidth: true
							border.color: replyInput.activeFocus ? "#c4a7e7" : "transparent"
							color: "#393552"
							implicitHeight: 30
							radius: 6

							TextInput {
								id: replyInput

								anchors.fill: parent
								anchors.leftMargin: 8
								anchors.rightMargin: 8
								color: "#e0def4"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 11
								verticalAlignment: TextInput.AlignVCenter

								onAccepted: {
									if (text.trim() !== "") {
										notifCard.modelData.sendInlineReply(text);
										text = "";
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
