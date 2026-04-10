import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    // ── Inline state object ──
    // LauncherProvider accesses this via pluginApi.mainInstance.state
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
    // Sequence: capture → write file → close launcher → end session → callback
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

        // Step 2: Close launcher
        if (shouldClose && pluginApi) {
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

        // Step 5: Fire callback (may chain another show())
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

        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.openLauncher(screen);
        });

        Logger.i("DmenuProvider", "Session " + root.state.sessionId
            + " started with " + merged.items.length + " items");
    }

    // ── IPC Handlers ──
    IpcHandler {
        target: "plugin:dmenu"

        // show takes a single JSON config string.
        // NOTE: If Quickshell CLI rejects single-arg calls, use showJson instead
        // which takes a dummy second arg, or use showSimple for plain lists.
        function show(configJson: string) {
            _doShow(configJson);
        }

        // Workaround for Quickshell CLI single-arg parsing bug.
        // Second arg is ignored — pass any value (e.g., "x").
        // Usage: noctalia-shell ipc call plugin:dmenu showJson '{"items":[...]}' x
        function showJson(configJson: string, unused: string) {
            _doShow(configJson);
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

            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.openLauncher(screen);
            });

            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " (simple) started with " + parsed.length + " items");
        }

        function showFromFile(filePath: string, separator: string, prompt: string, callbackCmd: string) {
            if (!pluginApi) return;
            fileLoader.separator = (separator && separator !== "") ? separator : "\n";
            fileLoader.prompt = prompt || "";
            fileLoader.callbackCmd = callbackCmd || "";
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

            if (pluginApi) {
                pluginApi.withCurrentScreen(function(screen) {
                    pluginApi.openLauncher(screen);
                });
            }

            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " (file) started with " + parsed.length + " items");
        }
    }

    Component.onCompleted: {
        Logger.i("DmenuProvider", "Main component loaded");
    }
}
