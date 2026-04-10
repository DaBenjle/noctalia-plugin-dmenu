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

    // ── Convenience accessors ──
    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var dmenuState: main?.state ?? null

    // Track if we had an active session so we can detect when the user
    // backspaces past ">dmenu" and cancel gracefully.
    property bool hadActiveSession: false

    function init() {
        Logger.i("DmenuProvider", "LauncherProvider initialized");
    }

    function onOpened() {
        // Reset tracking
    }

    // ── Command handling ──
    function handleCommand(searchText) {
        // We handle the >dmenu prefix
        if (searchText.startsWith(">dmenu")) {
            return true;
        }

        // If we had an active session but the user backspaced past ">dmenu",
        // cancel the session. This prevents the user from accidentally
        // falling into the normal launcher while a dmenu session is active.
        if (hadActiveSession && root.main && root.main.state.active) {
            root.main.endSession();
            hadActiveSession = false;
        }

        return false;
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
            hadActiveSession = false;
            return [{
                "name": "No active dmenu session",
                "description": "Use IPC or noctalia-dmenu script to send items",
                "icon": "info-circle",
                "isTablerIcon": true,
                "onActivate": function() {}
            }];
        }

        hadActiveSession = true;

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

        // If there's a prompt and no search query, show it on the first result.
        // This gives a visual hint without adding a non-interactive entry.
        if (st.prompt && st.prompt !== "" && query === "" && results.length > 0) {
            var first = results[0];
            if (!first.description || first.description === "") {
                // No existing description — use prompt as the subtitle
                first.description = st.prompt;
                first.singleLine = false;
            } else {
                // Item has its own description — prepend prompt with a separator
                first.description = st.prompt + " · " + first.description;
            }
        }

        // Custom input option — only if query doesn't exactly match any item
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
