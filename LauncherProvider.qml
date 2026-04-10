import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root

    // ── Required properties (injected by PluginService) ──
    property var pluginApi: null
    property var launcher: null
    property string name: "Dmenu"

    // ── Provider configuration ──
    property bool handleSearch: false
    property string supportedLayouts: "list"
    property bool supportsAutoPaste: false
    property bool ignoreDensity: true

    // ── Convenience accessor ──
    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var dmenuState: main?.state ?? null

    function init() {
        Logger.i("DmenuProvider", "LauncherProvider initialized");
    }

    function onOpened() {
        // Nothing to reset — state is managed by Main.qml
    }

    // ── Command handling ──
    function handleCommand(searchText) {
        return searchText.startsWith(">dmenu");
    }

    function commands() {
        return [{
            "name": ">dmenu",
            "description": "External menu (dmenu mode)",
            "icon": "menu-2",
            "isTablerIcon": true,
            "onActivate": function() {
                launcher.setSearchText(">dmenu ");
            }
        }];
    }

    // ── Results ──
    function getResults(searchText) {
        if (!searchText.startsWith(">dmenu")) {
            return [];
        }

        var st = root.dmenuState;

        // If no active session, show a hint
        if (!st || !st.active) {
            return [{
                "name": "No active dmenu session",
                "description": "Use IPC or noctalia-dmenu script to send items",
                "icon": "info-circle",
                "isTablerIcon": true,
                "onActivate": function() {}
            }];
        }

        var query = searchText.slice(6).trim().toLowerCase();
        var items = st.items;
        var results = [];
        var maxResults = st.maxResults;
        var sid = st.sessionId;

        // Filter items by query
        for (var i = 0; i < items.length && results.length < maxResults; i++) {
            var item = items[i];
            var nameMatch = (item.name || "").toLowerCase().indexOf(query) !== -1;
            var descMatch = (item.description || "").toLowerCase().indexOf(query) !== -1;
            var valueMatch = (item.value || "").toLowerCase().indexOf(query) !== -1;

            if (query === "" || nameMatch || descMatch || valueMatch) {
                results.push(makeResult(item, i, sid));
            }
        }

        // Custom input option
        if (st.allowCustomInput && query !== "") {
            var exactMatch = results.some(function(r) {
                return r.name.toLowerCase() === query;
            });
            if (!exactMatch) {
                results.push({
                    "name": query,
                    "description": "Use as custom input",
                    "icon": "text-plus",
                    "isTablerIcon": true,
                    "singleLine": false,
                    "onActivate": function() {
                        var captured = query;
                        var capturedSid = sid;
                        var m = root.main;
                        if (m && m.state.sessionId === capturedSid && m.state.active) {
                            m.handleCustomInput(captured);
                        }
                    }
                });
            }
        }

        // Prompt header
        if (st.prompt && st.prompt !== "" && results.length > 0) {
            results.unshift({
                "name": st.prompt,
                "description": "",
                "icon": "chevron-right",
                "isTablerIcon": true,
                "singleLine": true,
                "onActivate": function() {}
            });
        }

        return results;
    }

    // ── Build a result object ──
    function makeResult(item, index, sid) {
        var capturedValue = item.value || item.name || "";
        var capturedIndex = index;
        var capturedSid = sid;

        var result = {
            "name": item.name || "",
            "description": item.description || "",
            "icon": item.icon || "",
            "isTablerIcon": item.isTablerIcon !== undefined ? item.isTablerIcon : true,
            "hideIcon": !item.icon || item.icon === "",
            "singleLine": !item.description || item.description === "",
            "onActivate": function() {
                var m = root.main;
                if (!m || m.state.sessionId !== capturedSid || !m.state.active) {
                    Logger.w("DmenuProvider", "Stale session activation ignored");
                    return;
                }
                m.handleSelection(capturedValue, capturedIndex, "");
            }
        };

        if (item.displayString) {
            result.displayString = item.displayString;
            result.hideIcon = true;
        }

        return result;
    }

    // ── React to state changes from Main.qml ──
    Connections {
        target: root.main
        enabled: root.main !== null

        function onItemsChanged() {
            if (launcher) {
                launcher.updateResults();
            }
        }

        function onSessionEnded(sid) {
            if (launcher) {
                launcher.updateResults();
            }
        }

        function onSessionStarted(sid) {
            if (launcher) {
                launcher.updateResults();
            }
        }
    }
}
