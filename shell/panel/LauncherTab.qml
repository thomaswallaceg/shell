import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.common.power
import qs.wallpaper
import qs.panel
import qs.services

Item {
    id: root

    signal closeRequested()

    readonly property int fileSearchMinLength: 3
    // Launcher only fits ~5-6 rows without scrolling — 20 was just noise.
    readonly property int fileSearchMaxResults: 10

    property var fileResults: []
    property bool fileSearching: false
    property int fileSearchGeneration: 0

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var builtInActions: [
        {
            id: "__action__lock",
            kind: "action",
            name: "Lock",
            genericName: "Lock the screen",
            keywords: ["lock", "session"],
            glyph: "󰌾",
            action: "lock"
        },
        {
            id: "__action__logout",
            kind: "action",
            name: "Log out",
            genericName: "Quit niri / end session",
            keywords: ["logout", "log out", "quit", "session"],
            glyph: "󰍃",
            action: "logout"
        },
        {
            id: "__action__suspend",
            kind: "action",
            name: "Suspend",
            genericName: "Suspend the system",
            keywords: ["suspend", "sleep"],
            glyph: "󰒲",
            action: "suspend"
        },
        {
            id: "__action__reboot",
            kind: "action",
            name: "Reboot",
            genericName: "Restart the system",
            keywords: ["reboot", "restart"],
            glyph: "󰜉",
            action: "reboot"
        },
        {
            id: "__action__shutdown",
            kind: "action",
            name: "Shut down",
            genericName: "Power off the system",
            keywords: ["shutdown", "shut down", "power", "poweroff", "halt"],
            glyph: "󰐥",
            action: "shutdown"
        },
        {
            id: "__action__playpause",
            kind: "action",
            name: "Play / Pause",
            genericName: "Toggle media playback",
            keywords: ["play", "pause", "media", "music"],
            glyph: "󰐎",
            action: "play-pause"
        },
        {
            id: "__action__next",
            kind: "action",
            name: "Next track",
            genericName: "Skip to next media track",
            keywords: ["next", "skip", "media", "music"],
            glyph: "󰒭",
            action: "next"
        },
        {
            id: "__action__previous",
            kind: "action",
            name: "Previous track",
            genericName: "Skip to previous media track",
            keywords: ["previous", "prev", "media", "music"],
            glyph: "󰒮",
            action: "previous"
        },
        {
            id: "__action__mute",
            kind: "action",
            name: "Toggle mute",
            genericName: "Mute or unmute volume",
            keywords: ["mute", "volume", "audio", "sound"],
            glyph: "󰝟",
            action: "mute"
        },
        {
            id: "__action__wallpaper",
            kind: "action",
            name: "Set wallpaper",
            genericName: "Choose a wallpaper image",
            keywords: ["wallpaper", "background", "desktop", "image"],
            glyph: "󰋩",
            action: "wallpaper"
        },
        {
            id: "__action__coffee",
            kind: "action",
            name: CoffeeMode.enabled ? "Coffee mode: On" : "Coffee mode: Off",
            genericName: "Toggle keeping the system awake",
            keywords: ["coffee", "caffeinate", "keep awake", "inhibit", "idle", "presentation"],
            glyph: "󰅶",
            action: "coffee-mode"
        },
        {
            id: "__action__sync_greeter_theme",
            kind: "action",
            name: "Sync theme to greeter",
            genericName: "Copy the current theme and font to the login screen",
            keywords: ["greeter", "sync", "theme", "font", "login", "greetd"],
            glyph: "󰓦",
            action: "sync-greeter-theme"
        },
        {
            id: "__action__theme",
            kind: "shell_panel_action",
            name: "Set theme",
            genericName: "Choose a theme",
            keywords: ["theme", "palette", "colors"],
            glyph: "󰏘",
            action: "theme"
        },
        {
            id: "__action__font",
            kind: "shell_panel_action",
            name: "Set font",
            genericName: "Choose a font",
            keywords: ["font", "text", "style"],
            glyph: "󰛖",
            action: "font"
        },
    ]

    function prepare() {
        panelTab.clearSearch();
        panelTab.selectedIndex = -1;
        clearFileSearch();
        Calculator.clear();
    }

    function activeMprisPlayer() {
        const players = Mpris.players.values;
        if (!players || players.length === 0)
            return null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i];
        }
        return players[0];
    }

    function matchingActions(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        // Same substring rules as apps — not `q.includes(k)`, which made a
        // single letter match nearly every keyword ("session", "suspend", …).
        return root.builtInActions.filter(a =>
            a.name.toLowerCase().includes(q) ||
            a.genericName.toLowerCase().includes(q) ||
            a.keywords.some(k => k.toLowerCase().includes(q))
        );
    }

    function rankName(name, query) {
        const n = (name || "").toLowerCase();
        if (n.startsWith(query))
            return 0;
        if (n.includes(query))
            return 1;
        return 2;
    }

    function compareEntries(a, b, query) {
        const ar = root.rankName(a.name, query);
        const br = root.rankName(b.name, query);
        if (ar !== br)
            return ar - br;
        return (a.name || "").localeCompare(b.name || "");
    }

    function runAction(actionId) {
        switch (actionId) {
            case "lock":
                Quickshell.execDetached(["qs", "ipc", "call", "lockscreen", "lock"]);
                break;
            case "logout":
                Quickshell.execDetached(["niri", "msg", "action", "quit"]);
                break;
            case "suspend":
                PowerController.request("suspend");
                break;
            case "reboot":
                PowerController.request("reboot");
                break;
            case "shutdown":
                PowerController.request("shutdown");
                break;
            case "play-pause": {
                const player = root.activeMprisPlayer();
                if (player && player.canTogglePlaying)
                    player.togglePlaying();
                break;
            }
            case "next": {
                const player = root.activeMprisPlayer();
                if (player && player.canGoNext)
                    player.next();
                break;
            }
            case "previous": {
                const player = root.activeMprisPlayer();
                if (player && player.canGoPrevious)
                    player.previous();
                break;
            }
            case "mute": {
                const sink = Pipewire.defaultAudioSink;
                if (sink && sink.audio)
                    sink.audio.muted = !sink.audio.muted;
                break;
            }
            case "wallpaper":
                WallpaperController.pick();
                break;
            case "coffee-mode":
                CoffeeMode.toggle();
                break;
            case "sync-greeter-theme":
                // Elevates via pkexec — the greeter's state dir is owned by
                // its own system user (root/greeter), not this session's
                // user. See sync-greeter-preferences.sh for why it's safe to
                // compute the greeter's state path without asking a running
                // greeter process for it.
                Quickshell.execDetached([
                    "pkexec",
                    Quickshell.shellPath("scripts/sync-greeter-preferences.sh"),
                    ThemeEngine.currentId,
                    ThemeEngine.savedFontFamily
                ]);
                break;
            case "theme":
                Quickshell.execDetached(["qs", "ipc", "call", "theme", "toggle"]);
                break;
            case "font":
                Quickshell.execDetached(["qs", "ipc", "call", "font", "toggle"]);
                break;
        }
    }

    function clearFileSearch() {
        fileSearchTimer.stop();
        fileResults = [];
        fileSearching = false;
        fileSearchGeneration += 1;
        fileSearchProc.running = false;
    }

    function basename(path) {
        const parts = path.split("/").filter(p => p.length > 0);
        return parts.length > 0 ? parts[parts.length - 1] : path;
    }

    function displayPath(path) {
        const home = Quickshell.env("HOME");
        if (home && path.startsWith(home))
            return "~" + path.slice(home.length);
        return path;
    }

    function parseFileResults(text) {
        const lines = text.trim() === ""
            ? []
            : text.trim().split("\n").filter(line => line.length > 0).slice(0, root.fileSearchMaxResults);

        return lines.map((line, i) => {
            const isDir = line.startsWith("d:");
            const path = line.startsWith("d:") || line.startsWith("f:")
                ? line.slice(2)
                : line;
            return {
                id: "__file__" + i + "__" + path,
                kind: "file",
                isDir: isDir,
                name: root.basename(path),
                genericName: root.displayPath(path),
                path: path,
                icon: ""
            };
        });
    }

    // "?" → files-only. Otherwise, inline file search when the query is long enough.
    // ">" run mode never triggers file search.
    function resolveFileSearch(query) {
        const trimmed = query.trim();
        if (trimmed.startsWith(">"))
            return { active: false, filesOnly: false, pattern: "" };
        if (trimmed.startsWith("?")) {
            const pattern = trimmed.slice(1).trim();
            return { active: pattern.length > 0, filesOnly: true, pattern: pattern };
        }
        if (trimmed.length < root.fileSearchMinLength)
            return { active: false, filesOnly: false, pattern: "" };
        return { active: true, filesOnly: false, pattern: trimmed };
    }

    function startFileSearch(pattern) {
        fileSearchGeneration += 1;
        const gen = fileSearchGeneration;
        fileSearching = true;

        const home = Quickshell.env("HOME") || ".";
        // "*"/"?"/"[" -> glob matching instead of a literal substring, so
        // e.g. "*.qml" or "foo?ar" work as expected.
        const matchFlag = /[*?[]/.test(pattern) ? "-g" : "-F";
        // A "/" in the query means they're narrowing by path (e.g.
        // "projects/foo"), not just a filename — fd only matches filenames
        // by default, so a path fragment would otherwise silently match
        // nothing. Left off for slash-less queries so a common word doesn't
        // suddenly match every file under a same-named directory.
        const pathFlag = pattern.includes("/") ? "-p" : "";
        const cap = root.fileSearchMaxResults;
        // Visible matches first, then hidden-only paths underneath (still capped).
        // Pattern/home/flags as $1.. to avoid injection.
        fileSearchProc.command = [
            "sh", "-c",
            'pattern="$1"; home="$2"; match_flag="$3"; path_flag="$4"; cap="$5"; ' +
            'tag() { while IFS= read -r p; do [ -d "$p" ] && echo "d:$p" || echo "f:$p"; done; }; ' +
            'is_hidden() { ' +
            '  oldifs=$IFS; IFS=/; ' +
            '  for part in $1; do ' +
            '    [ -n "$part" ] || continue; ' +
            '    [ "$part" = "." ] || [ "$part" = ".." ] && continue; ' +
            '    [ "${part#.}" != "$part" ] && { IFS=$oldifs; return 0; }; ' +
            '  done; ' +
            '  IFS=$oldifs; return 1; ' +
            '}; ' +
            'fd --type f --type d "$match_flag" $path_flag --max-results "$cap" -- "$pattern" "$home" | tag; ' +
            'fd --hidden --type f --type d "$match_flag" $path_flag --max-results "$((cap * 2))" -- "$pattern" "$home" | ' +
            'while IFS= read -r p; do is_hidden "$p" && echo "$p"; done | head -"$cap" | tag',
            "file-search", pattern, home, matchFlag, pathFlag, String(cap)
        ];
        fileSearchProc.generation = gen;
        fileSearchProc.running = false;
        fileSearchProc.running = true;
    }

    // Run mode: queries starting with ">" become a single "run this command" row.
    function tryRunCommand(query) {
        const trimmed = query.trim();
        if (!trimmed.startsWith(">"))
            return null;

        const command = trimmed.slice(1).trim();
        if (command === "")
            return { id: "__run__", kind: "run", empty: true };

        return {
            id: "__run__",
            kind: "run",
            name: command,
            genericName: "Run command",
            command: command,
            icon: ""
        };
    }

    function formatResultCount() {
        const values = filteredApps.values;
        const raw = panelTab.searchText.trim();
        const fileQuery = root.resolveFileSearch(raw);

        if (fileQuery.filesOnly) {
            if (root.fileSearching)
                return "Searching…";
            const n = values.length;
            return n + " result" + (n !== 1 ? "s" : "");
        }
        if (values.length === 1 && values[0].kind === "run")
            return "Run command";
        if (values.length === 0 && raw.startsWith(">"))
            return "Run command";

        const apps = values.filter(e => !e.kind || e.kind === "app");
        const actions = values.filter(e =>
            e.kind === "action" || e.kind === "shell_panel_action");
        const files = values.filter(e => e.kind === "file");
        const hasCalc = values.some(e => e.kind === "calc");
        const appCount = apps.length;
        let text = appCount + " application" + (appCount !== 1 ? "s" : "");
        if (actions.length > 0)
            text = actions.length + " action" + (actions.length !== 1 ? "s" : "") + " · " + text;
        if (hasCalc)
            text = "Calculator · " + text;
        if (root.fileSearching && fileQuery.active)
            text += " · searching…";
        else if (files.length > 0)
            text += " · " + files.length + " file" + (files.length !== 1 ? "s" : "");
        return text;
    }

    function actionLabelFor(entry) {
        if (entry?.kind === "calc")
            return "copy";
        if (entry?.kind === "run")
            return "run";
        if (entry?.kind === "file")
            return "open";
        if (entry?.kind === "action" || entry?.kind === "shell_panel_action")
            return "run";
        return "launch";
    }

    function emptyMessage() {
        const raw = panelTab.searchText.trim();
        const fileQuery = root.resolveFileSearch(raw);
        if (raw.startsWith(">"))
            return "Type a command after >";
        if (fileQuery.filesOnly) {
            if (fileQuery.pattern === "")
                return "Type a search after ?";
            if (root.fileSearching)
                return "Searching…";
            return "No results found";
        }
        if (root.fileSearching)
            return "Searching…";
        if (raw.length >= root.fileSearchMinLength)
            return "No results found";
        return "No applications found";
    }

    Timer {
        id: fileSearchTimer
        interval: 180
        repeat: false
        onTriggered: {
            const fileQuery = root.resolveFileSearch(panelTab.searchText);
            if (fileQuery.active)
                root.startFileSearch(fileQuery.pattern);
        }
    }

    Process {
        id: fileSearchProc
        property int generation: 0
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (fileSearchProc.generation !== root.fileSearchGeneration)
                    return;

                const fileQuery = root.resolveFileSearch(panelTab.searchText);
                if (!fileQuery.active) {
                    root.fileResults = [];
                    root.fileSearching = false;
                    return;
                }

                root.fileResults = root.parseFileResults(text);
                root.fileSearching = false;

                // Prefix mode: jump to the first file. Inline mode: keep the
                // current app selection; only select a file if nothing is selected.
                if (root.fileResults.length > 0) {
                    if (fileQuery.filesOnly || panelTab.selectedIndex < 0)
                        panelTab.selectedIndex = 0;
                }
            }
        }
    }

    Connections {
        target: panelTab
        function onSearchTextChanged() {
            // ">" (run mode) and "?" (files-only) never show a calc entry
            // (see the ScriptModel's values: binding) — no point spawning
            // qalc for text in either of those modes.
            const trimmed = panelTab.searchText.trim();
            if (trimmed.startsWith(">") || trimmed.startsWith("?"))
                Calculator.clear();
            else
                Calculator.evaluate(panelTab.searchText);

            const fileQuery = root.resolveFileSearch(panelTab.searchText);
            if (!fileQuery.active) {
                root.clearFileSearch();
                return;
            }
            root.fileSearching = true;
            fileSearchTimer.restart();
        }
    }

    ScriptModel {
        id: filteredApps
        objectProp: "id"
        values: {
            const raw = panelTab.searchText.trim();
            const fileQuery = root.resolveFileSearch(raw);

            if (fileQuery.filesOnly)
                return root.fileResults;

            const run = root.tryRunCommand(raw);
            if (run) {
                // Prefix mode: only the run row (nothing until a command is typed).
                return run.empty ? [] : [run];
            }

            const q = raw.toLowerCase();
            const all = [...DesktopEntries.applications.values];
            let apps;
            if (q === "") {
                apps = all.sort((a, b) => a.name.localeCompare(b.name));
            } else {
                // Categories like "System" match a lone "s" and keep unrelated
                // apps (e.g. Alacritty) in the list; only use them once the
                // query is long enough to be intentional.
                apps = all.filter(d => {
                    if (d.name && d.name.toLowerCase().includes(q))
                        return true;
                    if (d.genericName && d.genericName.toLowerCase().includes(q))
                        return true;
                    if (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q)))
                        return true;
                    if (q.length >= 3 && d.categories
                        && d.categories.some(c => c.toLowerCase().includes(q)))
                        return true;
                    return false;
                });
            }

            const calc = Calculator.hasResult ? {
                id: "__calc__",
                kind: "calc",
                name: "= " + Calculator.result,
                genericName: "Copy result to clipboard",
                result: Calculator.result,
                icon: ""
            } : null;
            // Interleave actions with apps by name relevance so a single
            // letter doesn't pin every loosely matched action above apps.
            const actions = q === "" ? [] : root.matchingActions(raw);
            let results = q === ""
                ? apps
                : [...actions, ...apps].sort((a, b) => root.compareEntries(a, b, q));
            if (calc)
                results = [calc, ...results];
            if (fileQuery.active && root.fileResults.length > 0)
                results = results.concat(root.fileResults);
            return results;
        }
    }

    function parentDirectory(path) {
        const trimmed = path.endsWith("/") && path.length > 1
            ? path.slice(0, -1)
            : path;
        const idx = trimmed.lastIndexOf("/");
        if (idx <= 0)
            return idx === 0 ? "/" : trimmed;
        return trimmed.slice(0, idx);
    }

    function activateEntry(entry, openLocation) {
        if (!entry)
            return;
        if (entry.kind === "calc") {
            Quickshell.clipboardText = entry.result;
            root.closeRequested();
            return;
        } else if (entry.kind === "run") {
            Quickshell.execDetached(["sh", "-c", entry.command]);
            root.closeRequested();
            return;
        } else if (entry.kind === "action") {
            root.runAction(entry.action);
            root.closeRequested();
            return;
        } else if (entry.kind === "shell_panel_action") {
            root.runAction(entry.action);
            return;
        } else if (entry.kind === "file") {
            const path = openLocation
                ? root.parentDirectory(entry.path)
                : entry.path;
            Quickshell.execDetached(["xdg-open", path]);
            root.closeRequested();
            return;
        }
        entry.execute();
        root.closeRequested();
    }

    ShellPanelTab {
        id: panelTab
        anchors.fill: parent

        searchPlaceholder: "Search apps, actions & files — ? files, > run…"
        searchAccessibleName: "Search applications"
        acceptTab: true
        clearSelectionOnEmpty: true

        model: filteredApps
        emptyText: root.emptyMessage()
        subtitleText: root.formatResultCount()

        hints: {
            const entry = panelTab.selectedIndex >= 0
                ? filteredApps.values[panelTab.selectedIndex]
                : null;
            const hints = [
                { key: "↑↓", label: "navigate" },
                { key: "⏎", label: root.actionLabelFor(entry) }
            ];
            if (entry?.kind === "file")
                hints.push({ key: "⇧⏎", label: "location" });
            hints.push({ key: "esc", label: "close" });
            return hints;
        }

        onCloseRequested: root.closeRequested()
        onActivated: modifiers => {
            if (panelTab.selectedIndex < 0)
                return;
            const entry = filteredApps.values[panelTab.selectedIndex];
            const openLocation = !!(modifiers & Qt.ShiftModifier) && entry?.kind === "file";
            root.activateEntry(entry, openLocation);
        }

        delegate: PanelListItem {
            required property var modelData
            required property int index

            readonly property bool isCalc: modelData.kind === "calc"
            readonly property bool isRun: modelData.kind === "run"
            readonly property bool isAction: modelData.kind === "action"
                || modelData.kind === "shell_panel_action"
            readonly property bool isFile: modelData.kind === "file"
            readonly property bool isSpecial: isCalc || isRun || isAction || isFile

            selectedIndex: panelTab.selectedIndex
            hoverHighlight: false

            Accessible.role: Accessible.Button
            Accessible.name: {
                if (isCalc)
                    return "Calculation result " + (modelData.result ?? "");
                if (isRun)
                    return "Run command " + (modelData.command ?? "");
                if (isAction)
                    return (modelData.name ?? "Action")
                        + (modelData.genericName ? " - " + modelData.genericName : "");
                if (isFile)
                    return (modelData.isDir ? "Open folder " : "Open file ") + (modelData.path ?? "");
                return (modelData.name ?? "Application")
                    + (modelData.genericName ? " - " + modelData.genericName : "");
            }

            onClicked: root.activateEntry(modelData, false)
            onHovered: panelTab.selectedIndex = index

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Item {
                    width: 28
                    height: 28
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (isFile)
                                return modelData.isDir ? "󰉋" : "󰈔";
                            if (isAction)
                                return modelData.glyph ?? "󰘳";
                            if (isRun)
                                return "󰆍";
                            return "󰃬";
                        }
                        color: selectedIndex === index ? Theme.accentPrimary : Theme.textSecondary
                        font.pixelSize: ThemeEngine.fontSizeIcon
                        font.family: ThemeEngine.fontFamily
                        visible: isSpecial
                    }

                    IconImage {
                        anchors.fill: parent
                        source: Quickshell.iconPath(modelData.icon ?? "", true)
                        visible: !isSpecial && (modelData.icon ?? "") !== ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                        text: modelData.name ?? ""
                        color: selectedIndex === index ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: ThemeEngine.fontSizeLg
                        font.family: ThemeEngine.fontFamily
                        font.bold: selectedIndex === index
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.genericName ?? modelData.comment ?? ""
                        color: selectedIndex === index ? Theme.textSecondary : Theme.textMuted
                        font.pixelSize: ThemeEngine.fontSizeSm
                        font.family: ThemeEngine.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text !== ""
                    }
                }
            }
        }
    }
}
