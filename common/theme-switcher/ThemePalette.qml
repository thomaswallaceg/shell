import QtQuick

// A single curated color palette — loaded from themes.json by ThemeEngine.
QtObject {
    id: root

    property string id: ""
    property string name: ""
    property string family: ""

    property color bgBase: "#000000"
    property color bgSurface: "#000000"
    property color bgHover: "#000000"
    property color bgSelected: "#000000"
    property color bgBorder: "#000000"

    property color textPrimary: "#ffffff"
    property color textSecondary: "#cccccc"
    property color textMuted: "#888888"

    property color accentPrimary: "#ffffff"
    property color accentCyan: "#ffffff"
    property color accentGreen: "#ffffff"
    property color accentOrange: "#ffffff"
    property color accentRed: "#ffffff"

    readonly property color bgOverlay: "#88000000"

    readonly property color urgencyLow: textMuted
    readonly property color urgencyNormal: accentPrimary
    readonly property color urgencyCritical: accentRed

    function isDark() {
        const hex = bgBase.toString().replace("#", "");
        const r = parseInt(hex.substr(0, 2), 16);
        const g = parseInt(hex.substr(2, 2), 16);
        const b = parseInt(hex.substr(4, 2), 16);
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5;
    }
}
