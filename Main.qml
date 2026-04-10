import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    // ── Inline state object ──
    property QtObject state: QtObject {
        property int sessionId: 0
        property var items: []
        property string prompt: ""
        property bool allowCustomInput: false
        property bool closeOnSelect: true
        property string resultFile: "/tmp/noctalia-dmenu-result"
        property string resultFormat: "plain"
        property string callbackCmd: ""
        property var altActions: ({})
        property int maxResults: 200
        property bool active: false
    }

    // Signals for the provider to react to
    signal itemsChanged()
    signal sessionStarted(int sid)
    signal sessionEnded(int sid)

    // ── Deferred launcher open ──
    // When openLauncher is called shortly after a closeLauncher (chaining),
    // we defer it to let the close animation finish.
    property real lastCloseTimestamp: 0
    readonly property int chainDelay: 350  // ms to wait after close before reopen

    Timer {
        id: launcherOpenTimer
        interval: root.chainDelay
        repeat: false
        onTriggered: {
            if (pluginApi && state.active) {
                pluginApi.withCurrentScreen(function(screen) {
                    pluginApi.openLauncher(screen);
                });
            }
        }
    }

    // Smart open: if we recently closed the launcher, defer the open.
    // Otherwise open immediately.
    function openLauncherSmart() {
        if (!pluginApi) return;
        var now = Date.now();
        var elapsed = now - lastCloseTimestamp;

        if (elapsed < chainDelay) {
            // We just closed — defer to let animation finish
            launcherOpenTimer.interval = chainDelay - elapsed + 50;
            launcherOpenTimer.restart();
            Logger.d("DmenuProvider", "Deferring launcher open by " + launcherOpenTimer.interval + "ms");
        } else {
            // No recent close — open immediately
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.openLauncher(screen);
            });
        }
    }

    // ── Session management ──
    function beginSession(config) {
        if (state.active) {
            var oldSid = state.sessionId;
            state.active = false;
            sessionEnded(oldSid);
        }

        state.sessionId++;
        var newSid = state.sessionId;

        state.items = config.items || [];
        state.prompt = config.prompt || "";
        state.allowCustomInput = config.allowCustomInput !== undefined
            ? config.allowCustomInput : false;
        state.closeOnSelect = config.closeOnSelect !== undefined
            ? config.closeOnSelect : true;
        state.resultFile = config.resultFile || "/tmp/noctalia-dmenu-result";
        state.resultFormat = config.resultFormat || "plain";
        state.callbackCmd = config.callbackCmd || "";
        state.altActions = config.altActions || {};
        state.maxResults = config.maxResults || 200;

        state.active = true;
        sessionStarted(newSid);
        itemsChanged();

        return newSid;
    }

    function endSession() {
        if (!state.active) return;
        var oldSid = state.sessionId;
        state.active = false;
        state.items = [];
        state.prompt = "";
        state.callbackCmd = "";
        state.altActions = {};
        sessionEnded(oldSid);
    }

    function formatResult(value, index) {
        if (state.resultFormat === "json") {
            return JSON.stringify({
                "value": value,
                "index": index,
                "sessionId": state.sessionId
            });
        } else if (state.resultFormat === "index") {
            return index.toString();
        }
        return value;
    }

    // ── Config builder ──
    function buildConfig(overrides) {
        var defaults = pluginApi ? pluginApi.pluginSettings : {};
        var manifest = pluginApi ? (pluginApi.manifest.metadata.defaultSettings || {}) : {};
        var cfg = {};

        cfg.resultFile = overrides.resultFile
            || defaults.resultFile
            || manifest.resultFile
            || "/tmp/noctalia-dmenu-result";
        cfg.resultFormat = overrides.resultFormat
            || defaults.resultFormat
            || manifest.resultFormat
            || "plain";
        cfg.allowCustomInput = overrides.allowCustomInput !== undefined
            ? overrides.allowCustomInput
            : (defaults.allowCustomInput !== undefined
                ? defaults.allowCustomInput : false);
        cfg.closeOnSelect = overrides.closeOnSelect !== undefined
            ? overrides.closeOnSelect
            : (defaults.closeOnSelect !== undefined
                ? defaults.closeOnSelect : true);
        cfg.maxResults = overrides.maxResults
            || defaults.maxResults
            || manifest.maxResults
            || 200;
        cfg.showToastOnSelect = overrides.showToastOnSelect !== undefined
            ? overrides.showToastOnSelect
            : (defaults.showToastOnSelect || false);

        cfg.items = overrides.items || [];
        cfg.prompt = overrides.prompt || "";
        cfg.callbackCmd = overrides.callbackCmd || "";
        cfg.altActions = overrides.altActions || {};

        return cfg;
    }

    // ── Item parsing ──
    function parseItems(input, separator) {
        if (typeof input === "string") {
            try {
                var parsed = JSON.parse(input);
                if (Array.isArray(parsed)) {
                    return normalizeItems(parsed);
                }
                if (parsed.items && Array.isArray(parsed.items)) {
                    return normalizeItems(parsed.items);
                }
            } catch (e) {
                // Not JSON — treat as separated string
            }
            var sep = separator || "\n";
            // Unescape common separator literals passed as strings from IPC
            // (IPC sends "\n" as two chars: backslash + n)
            sep = sep.replace(/\\n/g, "\n")
                     .replace(/\\t/g, "\t")
                     .replace(/\\r/g, "\r");
            var lines = input.split(sep).filter(function(l) { return l.length > 0; });
            return lines.map(function(line, idx) {
                return { name: line.trim(), value: line.trim(), index: idx };
            });
        }
        if (Array.isArray(input)) {
            return normalizeItems(input);
        }
        return [];
    }

    function normalizeItems(arr) {
        return arr.map(function(item, idx) {
            if (typeof item === "string") {
                return { name: item, value: item, index: idx };
            }
            return {
                name: item.name || item.label || item.value || ("Item " + idx),
                description: item.description || "",
                value: item.value || item.name || item.label || "",
                icon: item.icon || "",
                isTablerIcon: item.isTablerIcon !== undefined ? item.isTablerIcon : true,
                altActions: item.altActions || {},
                index: idx
            };
        });
    }

    // ── Selection handler ──
    function handleSelection(value, index, altKey) {
        if (!state.active) return;

        var sid = state.sessionId;
        var resultStr = formatResult(value, index);
        var resultFile = state.resultFile;
        var callbackCmd = state.callbackCmd;
        var showToast = pluginApi
            ? (pluginApi.pluginSettings.showToastOnSelect || false) : false;
        var shouldClose = state.closeOnSelect;

        // Capture item name BEFORE endSession clears items
        var itemName = "";
        if (index >= 0 && index < state.items.length) {
            itemName = state.items[index].name || "";
        }

        // Handle alt-action
        var actualCallback = callbackCmd;
        if (altKey && altKey !== "") {
            var itemAltActions = {};
            if (index >= 0 && index < state.items.length) {
                itemAltActions = state.items[index].altActions || {};
            }
            var globalAltActions = state.altActions || {};
            var altAction = itemAltActions[altKey] || globalAltActions[altKey];
            if (altAction) {
                if (typeof altAction === "string") {
                    actualCallback = altAction;
                } else if (altAction.callback) {
                    actualCallback = altAction.callback;
                }
                if (altAction.value !== undefined) {
                    resultStr = formatResult(altAction.value, index);
                }
            }
        }

        // Step 1: Write result file (atomic: tmp + mv)
        var escaped = resultStr.replace(/'/g, "'\\''");
        var escapedFile = resultFile.replace(/'/g, "'\\''");
        Quickshell.execDetached([
            "sh", "-c",
            "printf '%s' '" + escaped + "' > '" + escapedFile + ".tmp' && mv '" + escapedFile + ".tmp' '" + escapedFile + "'"
        ]);

        // Step 2: Close launcher and record timestamp
        if (shouldClose && pluginApi) {
            lastCloseTimestamp = Date.now();
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.closeLauncher(screen);
            });
        }

        // Step 3: End session
        endSession();

        // Step 4: Toast
        if (showToast) {
            ToastService.showNotice("Selected: " + value);
        }

        // Step 5: Fire callback immediately
        // The callback itself may call show/showSimple, which will use
        // openLauncherSmart() to defer the open if needed.
        if (actualCallback && actualCallback !== "") {
            var cmd = actualCallback.replace(/\{\}/g, resultStr);
            cmd = cmd.replace(/\{value\}/g, resultStr);
            cmd = cmd.replace(/\{index\}/g, index.toString());
            cmd = cmd.replace(/\{name\}/g, itemName || resultStr);
            Quickshell.execDetached(["sh", "-c", cmd]);
        }

        Logger.i("DmenuProvider", "Session " + sid + " selection: " + value
            + (altKey ? " (alt: " + altKey + ")" : ""));
    }

    function handleCustomInput(text) {
        if (!state.active || !state.allowCustomInput) return;
        var prefix = pluginApi
            ? (pluginApi.pluginSettings.customInputPrefix || "") : "";
        handleSelection(prefix + text, -1, "");
    }

    // ── Internal: shared implementation for show/showJson ──
    function _doShow(configJson) {
        if (!pluginApi) {
            Logger.e("DmenuProvider", "pluginApi not available");
            return;
        }

        var config;
        try {
            config = JSON.parse(configJson);
        } catch (e) {
            Logger.e("DmenuProvider", "Invalid JSON in show():", e);
            return;
        }

        config.items = root.parseItems(config.items || [], null);
        var merged = root.buildConfig(config);
        root.beginSession(merged);
        root.openLauncherSmart();

        Logger.i("DmenuProvider", "Session " + root.state.sessionId
            + " started with " + merged.items.length + " items");
    }

    // ── IPC Handlers ──
    IpcHandler {
        target: "plugin:dmenu"

        function show(configJson: string) {
            root._doShow(configJson);
        }

        function showJson(configJson: string, unused: string) {
            root._doShow(configJson);
        }

        function showSimple(items: string, separator: string, prompt: string, callbackCmd: string) {
            if (!pluginApi) return;

            var sep = (separator && separator !== "") ? separator : "\n";
            var parsed = root.parseItems(items, sep);
            var merged = root.buildConfig({
                items: parsed,
                prompt: prompt || "",
                callbackCmd: callbackCmd || ""
            });
            root.beginSession(merged);
            root.openLauncherSmart();

            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " (simple) started with " + parsed.length + " items");
        }

        function showFromFile(filePath: string, separator: string, prompt: string, callbackCmd: string) {
            if (!pluginApi) return;
            fileLoader.separator = (separator && separator !== "") ? separator : "\n";
            fileLoader.prompt = prompt || "";
            fileLoader.callbackCmd = callbackCmd || "";
            // Reset path first to force FileView to re-fire onLoaded
            // even if the same file is requested again
            fileLoader.path = "";
            fileLoader.path = filePath;
        }

        function toggle() {
            if (!pluginApi) return;
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.toggleLauncher(screen);
            });
        }

        function close() {
            if (!pluginApi) return;
            root.endSession();
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.closeLauncher(screen);
            });
        }

        function clear() {
            root.endSession();
        }
    }

    // ── File loader ──
    FileView {
        id: fileLoader
        path: ""
        watchChanges: false

        property string separator: "\n"
        property string prompt: ""
        property string callbackCmd: ""

        onLoaded: {
            var content = text();
            var parsed = root.parseItems(content, fileLoader.separator);
            var merged = root.buildConfig({
                items: parsed,
                prompt: fileLoader.prompt,
                callbackCmd: fileLoader.callbackCmd
            });
            root.beginSession(merged);
            root.openLauncherSmart();

            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " (file) started with " + parsed.length + " items");
        }
    }

    Component.onCompleted: {
        Logger.i("DmenuProvider", "Main component loaded");
    }
}
