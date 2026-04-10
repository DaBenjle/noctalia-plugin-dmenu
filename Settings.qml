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

    property string editCustomInputPrefix:
        pluginApi?.pluginSettings?.customInputPrefix
        || pluginApi?.manifest?.metadata?.defaultSettings?.customInputPrefix
        || ""

    property int editMaxResults:
        pluginApi?.pluginSettings?.maxResults
        || pluginApi?.manifest?.metadata?.defaultSettings?.maxResults
        || 200

    // ── Position settings ──
    property string editPanelPosition:
        pluginApi?.pluginSettings?.panelPosition
        || pluginApi?.manifest?.metadata?.defaultSettings?.panelPosition
        || "follow_launcher"

    property bool editShowMatchCount:
        pluginApi?.pluginSettings?.showMatchCount
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showMatchCount
        ?? true

    property bool editShowFooter:
        pluginApi?.pluginSettings?.showFooter
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showFooter
        ?? true

    spacing: Style.marginM

    // ═══════════════════════════════════════
    // Panel appearance
    // ═══════════════════════════════════════

    NLabel {
        label: "Panel appearance"
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Panel position"
        description: "follow_launcher, center, top_center, bottom_center, top_left, top_right, bottom_left, bottom_right, center_left, center_right"
        placeholderText: "follow_launcher"
        text: root.editPanelPosition
        onTextChanged: root.editPanelPosition = text
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show match count"
        description: "Display the number of matching items while filtering"
        checked: root.editShowMatchCount
        onToggled: function(v) { root.editShowMatchCount = v }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show footer"
        description: "Display the result count footer below the list"
        checked: root.editShowFooter
        onToggled: function(v) { root.editShowFooter = v }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ═══════════════════════════════════════
    // Behavior
    // ═══════════════════════════════════════

    NLabel {
        label: "Behavior"
    }

    NToggle {
        Layout.fillWidth: true
        label: "Allow custom input"
        description: "Let users type and submit text that isn't in the item list"
        checked: root.editAllowCustom
        onToggled: function(v) { root.editAllowCustom = v }
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
        Layout.fillWidth: true
        label: "Close panel on select"
        description: "Automatically close the panel when an item is selected"
        checked: root.editCloseOnSelect
        onToggled: function(v) { root.editCloseOnSelect = v }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show toast on select"
        description: "Display a notification when an item is selected"
        checked: root.editShowToast
        onToggled: function(v) { root.editShowToast = v }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ═══════════════════════════════════════
    // Advanced
    // ═══════════════════════════════════════

    NLabel {
        label: "Advanced"
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Result file path"
        description: "Where selections are written. Scripts read this file after the panel closes."
        placeholderText: "/tmp/noctalia-dmenu-result"
        text: root.editResultFile
        onTextChanged: root.editResultFile = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Default separator"
        description: "Separator for showSimple mode (\\n for newline, | for pipe, etc.)"
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
        pluginApi.pluginSettings.customInputPrefix = root.editCustomInputPrefix;
        pluginApi.pluginSettings.maxResults = root.editMaxResults;
        pluginApi.pluginSettings.panelPosition = root.editPanelPosition;
        pluginApi.pluginSettings.showMatchCount = root.editShowMatchCount;
        pluginApi.pluginSettings.showFooter = root.editShowFooter;
        pluginApi.saveSettings();

        Logger.i("DmenuProvider", "Settings saved");
    }
}
