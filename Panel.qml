import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

FocusScope {
    id: root

    property var pluginApi: null

    // ── SmartPanel integration ──
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 620 * Style.uiScaleRatio
    property real contentPreferredHeight: 480 * Style.uiScaleRatio

    anchors.fill: parent
    focus: true

    // ── Convenience ──
    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var dmenuState: main?.state ?? null

    // ── Local state ──
    property string filterText: ""
    property int selectedIndex: 0
    property var filteredItems: []

    // ── Filtering ──
    function updateFilter() {
        var st = root.dmenuState;
        if (!st || !st.active) {
            filteredItems = [];
            return;
        }

        var query = filterText.trim().toLowerCase();
        var items = st.items;
        var results = [];
        var max = st.maxResults || 200;

        for (var i = 0; i < items.length && results.length < max; i++) {
            var item = items[i];
            var nm = item.name || "";
            var desc = item.description || "";
            var val = item.value || item.name || "";
            var ico = item.icon || "";

            if (query === ""
                || nm.toLowerCase().indexOf(query) !== -1
                || desc.toLowerCase().indexOf(query) !== -1
                || val.toLowerCase().indexOf(query) !== -1) {
                results.push({
                    name: nm, description: desc, value: val,
                    icon: ico, originalIndex: i, isCustomInput: false
                });
            }
        }

        if (st.allowCustomInput && query !== "") {
            var hasExact = results.some(function(r) {
                return r.name.toLowerCase() === query;
            });
            if (!hasExact) {
                results.push({
                    name: query, description: "Use as custom input",
                    value: query, icon: "text-plus",
                    originalIndex: -1, isCustomInput: true
                });
            }
        }

        filteredItems = results;
        if (selectedIndex >= results.length)
            selectedIndex = Math.max(0, results.length - 1);
    }

    function activateItem(idx) {
        if (idx < 0 || idx >= filteredItems.length) return;
        var item = filteredItems[idx];
        if (!main) return;
        if (item.isCustomInput) main.handleCustomInput(item.value);
        else main.handleSelection(item.value, item.originalIndex, "");
    }

    function scrollToSelected() {
        var itemY = selectedIndex * 50;
        var viewTop = flickable.contentY;
        var viewBottom = viewTop + flickable.height;
        if (itemY < viewTop) flickable.contentY = itemY;
        else if (itemY + 48 > viewBottom)
            flickable.contentY = itemY + 48 - flickable.height;
    }

    // ── Signals ──
    Connections {
        target: root.main
        enabled: root.main !== null

        function onItemsChanged() {
            root.filterText = "";
            root.selectedIndex = 0;
            searchField.text = "";
            root.updateFilter();
            searchField.forceActiveFocus();
        }

        function onSessionEnded(sid) {
            // Don't close if this is a rapid replacement (A → B → C).
            // Main.qml sets replacingSession=true during beginSession.
            if (root.main && root.main.replacingSession) return;
            if (pluginApi) {
                pluginApi.closePanel(pluginApi.panelOpenScreen);
            }
        }
    }

    onDmenuStateChanged: {
        if (dmenuState && dmenuState.active) updateFilter();
    }

    onFilterTextChanged: {
        selectedIndex = 0;
        updateFilter();
    }

    Component.onCompleted: {
        updateFilter();
        focusTimer.start();
        retryTimer.start();
    }

    Timer {
        id: retryTimer
        interval: 100
        onTriggered: root.updateFilter()
    }

    Timer {
        id: focusTimer
        interval: 150
        onTriggered: searchField.forceActiveFocus()
    }

    // ── UI ──
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // ── Search bar ──
            // Using a raw TextInput inside a styled Rectangle so we have
            // total control over focus — NTextInput's internal focus chain
            // was fighting our keyboard navigation.
            Rectangle {
                id: searchBar
                width: parent.width
                height: 44
                radius: Style.radiusM
                color: Color.mSurface
                border.color: searchField.activeFocus ? Color.mPrimary : Color.mOutline
                border.width: 1

                TextInput {
                    id: searchField
                    anchors {
                        fill: parent
                        leftMargin: Style.marginM
                        rightMargin: Style.marginM
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    font.pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                    selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    clip: true
                    focus: true
                    activeFocusOnTab: false

                    onTextChanged: root.filterText = text

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            root.selectedIndex = Math.min(
                                root.selectedIndex + 1,
                                root.filteredItems.length - 1);
                            root.scrollToSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                            root.scrollToSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activateItem(root.selectedIndex);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            if (root.main) root.main.endSession();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            // Tab cycles forward, Shift+Tab cycles backward
                            if (event.modifiers & Qt.ShiftModifier) {
                                root.selectedIndex = root.selectedIndex <= 0
                                    ? root.filteredItems.length - 1
                                    : root.selectedIndex - 1;
                            } else {
                                root.selectedIndex = (root.selectedIndex + 1) % Math.max(1, root.filteredItems.length);
                            }
                            root.scrollToSelected();
                            event.accepted = true;
                        }
                    }
                }

                // Placeholder text
                Text {
                    anchors {
                        fill: parent
                        leftMargin: Style.marginM
                        rightMargin: Style.marginM
                    }
                    verticalAlignment: Text.AlignVCenter
                    font.pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    visible: searchField.text === "" && !searchField.activeFocus
                    text: {
                        var st = root.dmenuState;
                        return (st && st.prompt) ? st.prompt : "Type to filter...";
                    }
                }
            }

            // ── Match count ──
            Text {
                visible: root.filteredItems.length > 0 && root.filterText !== ""
                text: root.filteredItems.length + " match" + (root.filteredItems.length !== 1 ? "es" : "")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            // ── Results ──
            Flickable {
                id: flickable
                width: parent.width
                height: parent.height - searchBar.height - Style.marginM * 2 - (root.filterText !== "" ? 20 : 0)
                contentHeight: resultsColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: resultsColumn
                    width: flickable.width
                    spacing: 2

                    Repeater {
                        model: root.filteredItems.length

                        Rectangle {
                            id: itemRect
                            width: resultsColumn.width
                            height: 48
                            radius: Style.radiusM

                            property int itemIndex: index
                            property var itemData: root.filteredItems[index] || {}
                            property bool isSelected: index === root.selectedIndex

                            color: {
                                if (isSelected) return Color.mPrimary;
                                if (itemMouse.containsMouse)
                                    return Qt.lighter(Color.mSurfaceVariant, 1.15);
                                return Color.mSurface;
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Style.marginM
                                anchors.rightMargin: Style.marginM
                                spacing: Style.marginM

                                Item {
                                    width: 24
                                    height: parent.height
                                    visible: (itemRect.itemData.icon || "") !== ""
                                    NIcon {
                                        anchors.centerIn: parent
                                        icon: itemRect.itemData.icon || ""
                                        color: itemRect.isSelected
                                            ? Color.mOnPrimary : Color.mOnSurface
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Style.marginM * 2 - (itemRect.itemData.icon ? 36 : 0)
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: itemRect.itemData.name || ""
                                        font.pointSize: Style.fontSizeM
                                        font.weight: Font.Medium
                                        color: itemRect.isSelected
                                            ? Color.mOnPrimary : Color.mOnSurface
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        visible: (itemRect.itemData.description || "") !== ""
                                        text: itemRect.itemData.description || ""
                                        font.pointSize: Style.fontSizeS
                                        color: itemRect.isSelected
                                            ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = itemIndex;
                                    root.activateItem(itemIndex);
                                }
                                onEntered: root.selectedIndex = itemIndex
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredItems.length === 0
                    text: {
                        var st = root.dmenuState;
                        if (!st || !st.active) return "Loading...";
                        if (root.filterText !== "") return "No matches";
                        return "No items";
                    }
                    font.pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
