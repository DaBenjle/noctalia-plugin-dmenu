import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    // ── Edit state ──
    property string editResultFile:
        pluginApi?.pluginSettings?.resultFile
        || pluginApi?.manifest?.metadata?.defaultSettings?.resultFile
        || "/tmp/noctalia-dmenu-result"

    property bool editShowToast:
        pluginApi?.pluginSettings?.showToastOnSelect
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showToastOnSelect
        ?? false

    property int editMaxResults:
        pluginApi?.pluginSettings?.maxResults
        || pluginApi?.manifest?.metadata?.defaultSettings?.maxResults
        || 200

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

    // Position options
    readonly property var positionOptions: [
        { key: "follow_launcher", name: "Follow launcher" },
        { key: "center",          name: "Center" },
        { key: "top_center",      name: "Top center" },
        { key: "bottom_center",   name: "Bottom center" },
        { key: "top_left",        name: "Top left" },
        { key: "top_right",       name: "Top right" },
        { key: "bottom_left",     name: "Bottom left" },
        { key: "bottom_right",    name: "Bottom right" },
        { key: "center_left",     name: "Center left" },
        { key: "center_right",    name: "Center right" }
    ]

    spacing: Style.marginM

    // ═══════════════════════════════════════
    // Panel position
    // ═══════════════════════════════════════

    NComboBox {
        label: "Panel position"
        description: "Where the dmenu panel appears on screen"
        Layout.fillWidth: true
        model: root.positionOptions
        currentKey: root.editPanelPosition
        onSelected: function(key) {
            root.editPanelPosition = key;
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ═══════════════════════════════════════
    // Display
    // ═══════════════════════════════════════

    NLabel {
        label: "Display"
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show match count"
        description: "Show filtered/total count in footer while searching"
        checked: root.editShowMatchCount
        onToggled: function(v) { root.editShowMatchCount = v }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show footer"
        description: "Show the result count bar below the list"
        checked: root.editShowFooter
        onToggled: function(v) { root.editShowFooter = v }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show toast on select"
        description: "Brief notification when an item is selected"
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
        description: "Where selections are written for scripts to read"
        placeholderText: "/tmp/noctalia-dmenu-result"
        text: root.editResultFile
        onTextChanged: root.editResultFile = text
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: "Max results: " + root.editMaxResults
            description: "Cap on displayed items"
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
        pluginApi.pluginSettings.showToastOnSelect = root.editShowToast;
        pluginApi.pluginSettings.maxResults = root.editMaxResults;
        pluginApi.pluginSettings.panelPosition = root.editPanelPosition;
        pluginApi.pluginSettings.showMatchCount = root.editShowMatchCount;
        pluginApi.pluginSettings.showFooter = root.editShowFooter;
        pluginApi.saveSettings();

        Logger.i("DmenuProvider", "Settings saved");
    }
}
