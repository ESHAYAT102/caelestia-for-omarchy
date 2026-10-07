pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var locationResults: []
    property var selectedLocation
    property bool locationSearching
    property string locationError
    property string locationQuery
    property int locationRequestId
    property Timer locationSearchTimer: Timer {
        property int requestId

        interval: 350
        onTriggered: root.searchLocations(root.locationQuery, requestId)
    }

    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: "°C"
        },
        MenuItem {
            text: "°F"
        }
    ]

    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: qsTr("24-hour")
        },
        MenuItem {
            text: qsTr("12-hour")
        }
    ]

    function queueLocationSearch(query: string): void {
        const trimmed = query.trim();
        locationQuery = trimmed;
        locationRequestId++;
        locationResults = [];
        locationError = "";
        locationSearchTimer.stop();

        if (trimmed.length < 2) {
            locationSearching = false;
            return;
        }

        locationSearching = true;
        locationSearchTimer.requestId = locationRequestId;
        locationSearchTimer.restart();
    }

    function searchLocations(query: string, requestId: int): void {
        const language = Qt.locale().name.split("_")[0];
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=8&language=${encodeURIComponent(language)}&format=json`;

        Requests.get(url, text => {
            if (requestId !== root.locationRequestId)
                return;

            root.locationSearching = false;
            try {
                const response = JSON.parse(text);
                root.locationResults = (response.results ?? []).map(result => {
                    const region = [result.admin1, result.country].filter(value => value).join(", ");
                    return {
                        name: result.name,
                        region,
                        coordinates: `${Number(result.latitude).toFixed(6)},${Number(result.longitude).toFixed(6)}`
                    };
                });
            } catch (error) {
                root.locationError = qsTr("Could not read location results");
            }
        }, error => {
            if (requestId !== root.locationRequestId)
                return;
            root.locationSearching = false;
            root.locationError = qsTr("Could not search for locations");
        });
    }

    function resetLocationPicker(): void {
        locationRequestId++;
        locationSearchTimer.stop();
        locationResults = [];
        locationError = "";
        locationQuery = "";
        locationSearching = false;

        const configured = GlobalConfig.services.weatherLocation;
        selectedLocation = configured ? {
            name: Weather.city || configured,
            region: qsTr("Current weather location"),
            coordinates: configured
        } : {
            automatic: true,
            name: qsTr("Automatic location"),
            region: qsTr("Based on your network")
        };
    }

    title: qsTr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Language")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: localeLayout.implicitHeight + localeLayout.anchors.margins * 2

            RowLayout {
                id: localeLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("System language")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Follows your system locale (%1)").arg(Qt.locale().name)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    text: Qt.locale().nativeLanguageName || Qt.locale().name
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }

        SectionHeader {
            text: qsTr("Weather")
        }

        DialogRowButton {
            id: locationPicker

            rootParent: root.flickable
            first: true
            icon: "location_on"
            label: GlobalConfig.services.weatherLocation ? (Weather.city || qsTr("Choose location")) : qsTr("Automatic location")
            header: qsTr("Weather location")
            acceptLabel: qsTr("Use location")
            acceptAllowed: !!root.selectedLocation
            openWidth: Math.min(rootParent.width * 0.9, 430)
            openHeight: Math.min(rootParent.height * 0.8, 430)
            separateContent: true
            horizontalContentMargin: -Tokens.padding.small

            onOpenChanged: {
                if (open)
                    root.resetLocationPicker();
            }
            onAccepted: {
                GlobalConfig.services.weatherLocation = root.selectedLocation?.automatic ? "" : root.selectedLocation.coordinates;
            }

            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    RowButton {
                        Layout.fillWidth: true
                        first: true
                        last: true
                        icon: "my_location"
                        text: qsTr("Automatic location")
                        subtext: qsTr("Use your network to determine the location")
                        trailingIcon: root.selectedLocation?.automatic ? "check" : ""
                        onClicked: root.selectedLocation = {
                            automatic: true,
                            name: qsTr("Automatic location"),
                            region: qsTr("Based on your network")
                        }
                    }

                    SearchBar {
                        id: locationSearch

                        Layout.fillWidth: true
                        placeholderText: qsTr("Search city or postcode")
                        onTextChanged: root.queueLocationSearch(text)
                        onAccepted: {
                            if (root.locationResults.length > 0)
                                root.selectedLocation = root.locationResults[0];
                        }

                        Component.onCompleted: forceActiveFocus()
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        VerticalFadeListView {
                            id: resultsList

                            anchors.fill: parent
                            visible: root.locationResults.length > 0
                            spacing: Tokens.spacing.extraSmall / 2
                            model: root.locationResults

                            delegate: StyledRect {
                                id: resultItem

                                required property var modelData
                                readonly property bool selected: root.selectedLocation?.coordinates === modelData.coordinates

                                anchors.left: ListView.view.contentItem.left
                                anchors.right: ListView.view.contentItem.right
                                implicitHeight: resultLayout.implicitHeight + Tokens.padding.medium * 2
                                radius: Tokens.rounding.large
                                color: selected ? Colours.palette.m3tertiaryContainer : "transparent"

                                StateLayer {
                                    radius: resultItem.radius
                                    onClicked: root.selectedLocation = resultItem.modelData
                                }

                                RowLayout {
                                    id: resultLayout

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Tokens.padding.large
                                    anchors.rightMargin: Tokens.padding.large
                                    spacing: Tokens.spacing.medium

                                    MaterialIcon {
                                        text: "location_on"
                                        color: resultItem.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.medium
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: resultItem.modelData.name
                                            color: resultItem.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                            font: Tokens.font.body.small
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: resultItem.modelData.region
                                            visible: text
                                            color: resultItem.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3outline
                                            font: Tokens.font.label.small
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MaterialIcon {
                                        text: "check"
                                        color: Colours.palette.m3onTertiaryContainer
                                        fontStyle: Tokens.font.icon.medium
                                        opacity: resultItem.selected ? 1 : 0
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.padding.large * 2
                            spacing: Tokens.spacing.extraSmall
                            visible: root.locationResults.length === 0

                            Loader {
                                Layout.alignment: Qt.AlignHCenter
                                active: root.locationSearching
                                visible: active
                                sourceComponent: LoadingIndicator {
                                    implicitSize: Tokens.font.icon.large.pointSize
                                }
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                visible: !root.locationSearching
                                text: root.locationError ? "cloud_off" : (root.locationQuery.length < 2 ? "travel_explore" : "location_off")
                                color: root.locationError ? Colours.palette.m3error : Colours.palette.m3outline
                                fontStyle: Tokens.font.icon.large
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.locationSearching ? qsTr("Searching…") : (root.locationError || (root.locationQuery.length < 2 ? qsTr("Type at least two characters") : qsTr("No locations found")))
                                color: root.locationError ? Colours.palette.m3error : Colours.palette.m3outline
                                font: Tokens.font.body.small
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("Units")
        }

        SelectRow {
            first: true
            label: qsTr("Temperature")
            subtext: qsTr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems[GlobalConfig.services.useFahrenheit ? 1 : 0]
            onSelected: item => GlobalConfig.services.useFahrenheit = root.tempItems.indexOf(item) === 1
        }

        SelectRow {
            last: true
            label: qsTr("System temperatures")
            subtext: qsTr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems[GlobalConfig.services.useFahrenheitPerformance ? 1 : 0]
            onSelected: item => GlobalConfig.services.useFahrenheitPerformance = root.tempItems.indexOf(item) === 1
        }

        SectionHeader {
            text: qsTr("Time & date")
        }

        SelectRow {
            first: true
            last: true
            label: qsTr("Clock format")
            subtext: qsTr("How times are shown across the shell")
            menuItems: root.clockItems
            active: root.clockItems[GlobalConfig.services.useTwelveHourClock ? 1 : 0]
            onSelected: item => GlobalConfig.services.useTwelveHourClock = root.clockItems.indexOf(item) === 1
        }
    }
}
