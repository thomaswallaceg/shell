pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "."

// Loads palettes, tracks the active one, persists selection, and owns shell-wide
// typography. Palette colors live on the Theme singleton; engine API on ThemeEngine.* .
Singleton {
    id: root

    property string savedFontFamily: "CodeNewRoman Nerd Font"
    property string previewFontFamily: ""
    readonly property string fontFamily: previewFontFamily !== "" ? previewFontFamily : savedFontFamily
    readonly property int fontSizeSm:   14
    readonly property int fontSizeLg:   16
    readonly property int fontSizeIcon: 20

    readonly property int barHeight:    32

    // System light/dark bridges (session should export QT_QPA_PLATFORMTHEME=qt6ct).
    property string qt6ctDarkPalette:  "/usr/share/qt6ct/colors/darker.conf"
    property string qt6ctLightPalette: "/usr/share/qt6ct/colors/airy.conf"

    property string currentId: ""
    property string previewId: ""
    property var themes: []

    Component {
        id: themeComponent
        ThemePalette {}
    }

    readonly property var placeholder: themeComponent.createObject(root)

    function findThemeById(id) {
        return themes.find(theme => theme.id === id);
    }

    readonly property var current: {
        return findThemeById(previewId !== "" ? previewId : currentId) || placeholder;
    }

    readonly property int count: themes.length
    readonly property string currentName: current.name
    readonly property string currentFamily: current.family

    function setTheme(id) {
        const theme = findThemeById(id);
        if (!theme)
            return;
        previewId = "";
        currentId = id;
        saveTheme(theme);
        applyColorScheme(theme);
    }

    function setFontFamily(name) {
        if (!name)
            return;
        previewFontFamily = "";
        savedFontFamily = name;
        fontConfFile.setText(name);
    }

    function saveTheme(theme) {
        themeConfFile.setText(theme.id);
    }

    function applySavedTheme() {
        const rawId = themeConfFile.text().trim();
        const theme = root.findThemeById(rawId) || root.themes[0];
        if (!theme)
            return;
        root.currentId = theme.id;
        root.applyColorScheme(theme);
    }

    function applySavedFont() {
        const name = fontConfFile.text().trim();
        if (name !== "")
            root.savedFontFamily = name;
    }

    function applyColorScheme(theme) {
        const gnomeScheme = theme.isDark() ? "prefer-dark" : "prefer-light";
        const qtPalette = theme.isDark() ? root.qt6ctDarkPalette : root.qt6ctLightPalette;
        colorSchemeProc.command = [
            "sh", "-c",
            // $1 = gsettings color-scheme, $2 = qt6ct palette path
            'gsettings set org.gnome.desktop.interface color-scheme "$1"; ' +
            'conf="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"; ' +
            'mkdir -p "$(dirname "$conf")"; ' +
            'if [ -f "$conf" ]; then ' +
            '  if grep -q "^color_scheme_path=" "$conf"; then ' +
            '    sed -i "s|^color_scheme_path=.*|color_scheme_path=$2|" "$conf"; ' +
            '  else ' +
            '    if grep -q "^\\[Appearance\\]" "$conf"; then ' +
            '      sed -i "/^\\[Appearance\\]/a color_scheme_path=$2" "$conf"; ' +
            '    else ' +
            '      printf "\\n[Appearance]\\ncolor_scheme_path=%s\\ncustom_palette=true\\n" "$2" >> "$conf"; ' +
            '    fi; ' +
            '  fi; ' +
            '  if grep -q "^custom_palette=" "$conf"; then ' +
            '    sed -i "s|^custom_palette=.*|custom_palette=true|" "$conf"; ' +
            '  else ' +
            '    sed -i "/^color_scheme_path=/a custom_palette=true" "$conf"; ' +
            '  fi; ' +
            'else ' +
            '  printf "[Appearance]\\ncolor_scheme_path=%s\\ncustom_palette=true\\nstyle=Fusion\\n" "$2" > "$conf"; ' +
            'fi',
            "apply-color-scheme", gnomeScheme, qtPalette
        ];
        colorSchemeProc.running = true;
    }

    Process { id: colorSchemeProc; running: false }

    // Persisted selection. Deliberately NOT Quickshell.statePath("theme.conf")
    // — that scopes under a by-shell/<hash-of-config-path> subdirectory, so
    // shell/ and greeter/ (two separate config roots) would each get their
    // own copy and never agree on the active theme. A plain $HOME-based path
    // has the same problem in a real greetd deployment: the greeter usually
    // runs as its own system user (e.g. "greeter") with its own $HOME, so it
    // still never sees the login user's file. A fixed system-wide path is the
    // only thing both processes can agree on regardless of which user runs
    // them, so both configs (and any future one sharing this file via the
    // common/ symlink) read and write the same theme selection.
    //
    // Requires one-time machine setup (not something this repo can do for
    // you): a dedicated group both your login user and whichever user runs
    // the greeter belong to, owning this directory, e.g.:
    //   sudo groupadd quickshell-theme
    //   sudo usermod -aG quickshell-theme <you>
    //   sudo usermod -aG quickshell-theme greeter
    //   sudo mkdir -p /var/lib/quickshell
    //   sudo chown root:quickshell-theme /var/lib/quickshell
    //   sudo chmod 2775 /var/lib/quickshell
    // (setgid bit so files created inside inherit the group instead of the
    // writer's primary group). Scoped to exactly the accounts that need it,
    // unlike a world-writable /tmp-style directory.
    readonly property string sharedStateDir: "/var/lib/quickshell"

    // Best-effort — succeeds as a no-op once the directory above has been
    // created via the one-time setup; if it doesn't exist yet and this
    // process lacks permission to create it in /var/lib, this fails silently
    // and FileView reads/writes below just won't find/persist anything until
    // the directory is set up.
    Process {
        command: ["mkdir", "-p", root.sharedStateDir]
        running: true
    }

    // themeConfFile and themesFile load asynchronously and independently, so
    // either can finish first — applySavedTheme() needs a chance to run from
    // both onTextChanged handlers (it's a safe no-op if themes aren't parsed
    // yet, or if the conf file hasn't loaded yet, since findThemeById/[0]
    // both come back empty/undefined in that case).
    FileView {
        id: themeConfFile
        path: root.sharedStateDir + "/theme.conf"
        onTextChanged: root.applySavedTheme()
    }

    FileView {
        id: fontConfFile
        path: root.sharedStateDir + "/font.conf"
        onTextChanged: root.applySavedFont()
    }

    FileView {
        id: themesFile
        path: Quickshell.shellPath("common/theme-switcher/themes.json")
        onTextChanged: {
            const raw = themesFile.text();
            if (!raw) return;
            try {
                const parsed = JSON.parse(raw);
                const loaded = [];
                for (let i = 0; i < parsed.length; i++)
                    loaded.push(themeComponent.createObject(root, parsed[i]));
                root.themes = loaded;
                root.applySavedTheme();
            } catch (e) {
                console.error("Failed to parse themes.json:", e);
            }
        }
    }
}
