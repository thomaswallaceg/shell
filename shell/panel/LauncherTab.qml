import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../common/theme-switcher"

Item {
    id: root

    signal closeRequested()

    readonly property int fileSearchMinLength: 3

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
        }
    ]

    function prepare() {
        panelTab.clearSearch();
        panelTab.selectedIndex = -1;
        clearFileSearch();
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
                Quickshell.execDetached(["systemctl", "suspend"]);
                break;
            case "reboot":
                Quickshell.execDetached(["systemctl", "reboot"]);
                break;
            case "shutdown":
                Quickshell.execDetached(["systemctl", "poweroff"]);
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
            : text.trim().split("\n").filter(line => line.length > 0);

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
        // Visible matches first, then hidden-only paths underneath (still capped).
        // Pattern/home as $1/$2 to avoid injection.
        fileSearchProc.command = [
            "sh", "-c",
            'pattern="$1"; home="$2"; ' +
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
            'fd --type f --type d --fixed-strings --max-results 20 -- "$pattern" "$home" | tag; ' +
            'fd --hidden --type f --type d --fixed-strings --max-results 40 -- "$pattern" "$home" | ' +
            'while IFS= read -r p; do is_hidden "$p" && echo "$p"; done | head -20 | tag',
            "file-search", pattern, home
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

    // Simple calculator: only digits and basic arithmetic, evaluated via a
    // strict Function so arbitrary JS can't sneak in through the search box.
    function tryCalculate(query) {
        const expr = query.trim().replace(/\s+/g, "");
        if (expr === "")
            return null;
        // Need at least one digit and one operator — plain "42" / app names stay as search.
        if (!/[0-9]/.test(expr) || !/[+\-*/%^]/.test(expr))
            return null;
        if (!/^[0-9+\-*/().,%^]+$/.test(expr))
            return null;

        try {
            const normalized = expr.replace(/\^/g, "**").replace(/,/g, "");
            const value = new Function(`"use strict"; return (${normalized});`)();
            if (typeof value !== "number" || !isFinite(value))
                return null;

            const display = Number.isInteger(value)
                ? String(value)
                : String(parseFloat(value.toPrecision(12)));

            return {
                id: "__calc__",
                kind: "calc",
                name: "= " + display,
                genericName: "Copy result to clipboard",
                result: display,
                icon: ""
            };
        } catch (e) {
            return null;
        }
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
        const actions = values.filter(e => e.kind === "action");
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
        if (entry?.kind === "action")
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

            const calc = root.tryCalculate(raw);
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
        }
        if (entry.kind === "run") {
            Quickshell.execDetached(["sh", "-c", entry.command]);
            root.closeRequested();
            return;
        }
        if (entry.kind === "action") {
            root.runAction(entry.action);
            root.closeRequested();
            return;
        }
        if (entry.kind === "file") {
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
