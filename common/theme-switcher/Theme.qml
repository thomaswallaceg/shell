pragma Singleton

import Quickshell
import QtQuick
import "."

// Active palette — bound to ThemeEngine.current so any file that imports
// theme-switcher can use Theme.bgBase. Engine API stays on ThemeEngine.* .
Singleton {
    readonly property string id: ThemeEngine.current.id
    readonly property string name: ThemeEngine.current.name
    readonly property string family: ThemeEngine.current.family

    readonly property color bgBase: ThemeEngine.current.bgBase
    readonly property color bgSurface: ThemeEngine.current.bgSurface
    readonly property color bgHover: ThemeEngine.current.bgHover
    readonly property color bgSelected: ThemeEngine.current.bgSelected
    readonly property color bgBorder: ThemeEngine.current.bgBorder

    readonly property color textPrimary: ThemeEngine.current.textPrimary
    readonly property color textSecondary: ThemeEngine.current.textSecondary
    readonly property color textMuted: ThemeEngine.current.textMuted

    readonly property color accentPrimary: ThemeEngine.current.accentPrimary
    readonly property color accentCyan: ThemeEngine.current.accentCyan
    readonly property color accentGreen: ThemeEngine.current.accentGreen
    readonly property color accentOrange: ThemeEngine.current.accentOrange
    readonly property color accentRed: ThemeEngine.current.accentRed

    readonly property color bgOverlay: ThemeEngine.current.bgOverlay

    readonly property color urgencyLow: ThemeEngine.current.urgencyLow
    readonly property color urgencyNormal: ThemeEngine.current.urgencyNormal
    readonly property color urgencyCritical: ThemeEngine.current.urgencyCritical

    function isDark() {
        return ThemeEngine.current.isDark();
    }
}
