import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    // ── Local edit state ──
    property string editResultFile:
        pluginApi?.pluginSettings?.resultFile
        || pluginApi?.manifest?.metadata?.defaultSettings?.resultFile
        || "/tmp/noctalia-dmenu-result"

    property string editSeparator:
        pluginApi?.pluginSettings?.defaultSeparator
        || pluginApi?.manifest?.metadata?.defaultSettings?.defaultSeparator
        || "\n"

    property bool editAllowCustom:
        pluginApi?.pluginSettings?.allowCustomInput
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.allowCustomInput
        ?? false

    property bool editShowToast:
        pluginApi?.pluginSettings?.showToastOnSelect
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showToastOnSelect
        ?? false

    property bool editCloseOnSelect:
        pluginApi?.pluginSettings?.closeOnSelect
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.closeOnSelect
        ?? true

    property string editResultFormat:
        pluginApi?.pluginSettings?.resultFormat
        || pluginApi?.manifest?.metadata?.defaultSettings?.resultFormat
        || "plain"

    property string editCustomInputPrefix:
        pluginApi?.pluginSettings?.customInputPrefix
        || pluginApi?.manifest?.metadata?.defaultSettings?.customInputPrefix
        || ""

    property int editMaxResults:
        pluginApi?.pluginSettings?.maxResults
        || pluginApi?.manifest?.metadata?.defaultSettings?.maxResults
        || 200

    spacing: Style.marginM

    // ── Output section ──
    NTextInput {
        Layout.fillWidth: true
        label: "Result file path"
        description: "Where selections are written. Scripts read this file after the menu closes."
        placeholderText: "/tmp/noctalia-dmenu-result"
        text: root.editResultFile
        onTextChanged: root.editResultFile = text
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "Result format"
            description: "How the selection is written: plain (raw value), json (structured), or index (item number)"
        }

        NTextInput {
            Layout.fillWidth: true
            placeholderText: "plain"
            text: root.editResultFormat
            onTextChanged: {
                var v = text.trim().toLowerCase();
                if (v === "plain" || v === "json" || v === "index") {
                    root.editResultFormat = v;
                }
            }
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Behavior section ──
    NToggle {
        id: toggleAllowCustom
        Layout.fillWidth: true
        label: "Allow custom input"
        description: "Let users type and submit text that isn't in the item list"
        checked: root.editAllowCustom
        onToggled: function(newValue) { root.editAllowCustom = newValue }
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Custom input prefix"
        description: "Prefix added to custom input values (e.g., 'custom:' → 'custom:mytext')"
        placeholderText: ""
        text: root.editCustomInputPrefix
        onTextChanged: root.editCustomInputPrefix = text
        visible: root.editAllowCustom
    }

    NToggle {
        id: toggleCloseOnSelect
        Layout.fillWidth: true
        label: "Close launcher on select"
        description: "Automatically close the launcher when an item is selected"
        checked: root.editCloseOnSelect
        onToggled: function(newValue) { root.editCloseOnSelect = newValue }
    }

    NToggle {
        id: toggleShowToast
        Layout.fillWidth: true
        label: "Show toast on select"
        description: "Display a notification when an item is selected"
        checked: root.editShowToast
        onToggled: function(newValue) { root.editShowToast = newValue }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Advanced section ──
    NTextInput {
        Layout.fillWidth: true
        label: "Default separator"
        description: "Separator for simple mode (\\n for newline, | for pipe, etc.)"
        placeholderText: "\\n"
        text: root.editSeparator === "\n" ? "\\n" : root.editSeparator
        onTextChanged: {
            root.editSeparator = (text === "\\n") ? "\n" : text;
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "Max results"
            description: "Maximum number of items to display: " + root.editMaxResults
        }

        NSlider {
            Layout.fillWidth: true
            from: 50
            to: 1000
            stepSize: 50
            value: root.editMaxResults
            onValueChanged: root.editMaxResults = value
        }
    }

    // ── Save ──
    function saveSettings() {
        if (!pluginApi) {
            Logger.e("DmenuProvider", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.resultFile = root.editResultFile;
        pluginApi.pluginSettings.defaultSeparator = root.editSeparator;
        pluginApi.pluginSettings.allowCustomInput = root.editAllowCustom;
        pluginApi.pluginSettings.showToastOnSelect = root.editShowToast;
        pluginApi.pluginSettings.closeOnSelect = root.editCloseOnSelect;
        pluginApi.pluginSettings.resultFormat = root.editResultFormat;
        pluginApi.pluginSettings.customInputPrefix = root.editCustomInputPrefix;
        pluginApi.pluginSettings.maxResults = root.editMaxResults;
        pluginApi.saveSettings();

        Logger.i("DmenuProvider", "Settings saved");
    }
}
