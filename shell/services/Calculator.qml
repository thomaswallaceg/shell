pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Launcher calculator, backed by qalc (libqalculate) instead of a hand-rolled
// JS `Function` eval — real implicit multiplication ("2(3+4)"), functions,
// units, etc. qalc is a subprocess, so this debounces on the launcher's own
// typing cadence and guards against races with a generation counter — the
// same idiom LauncherTab.qml's own file search already uses (see
// fileSearchProc/fileSearchGeneration there).
Singleton {
  id: root

  readonly property int debounceMs: 120

  property string query: ""
  property string result: ""
  property bool hasResult: false

  property int _generation: 0

  // Needs a digit, plus something that makes it look like an actual
  // expression rather than a plain search term — otherwise every app-name
  // search would spawn qalc. A guard-pass qalc still can't evaluate just
  // fails silently (no result shown, one cheap debounced subprocess), so
  // this errs toward covering more of what qalc itself understands rather
  // than trying to whitelist exact syntax:
  //   - an arithmetic/grouping/factorial operator: 2+3, 2(3+4), 5!
  //   - conversion phrasing: 5 km to miles, 100 usd to eur, 16 to hex
  //   - implicit multiplication against a constant/unit with no operator
  //     at all: 2pi, 5kg
  function isCandidate(text) {
    const expr = text.trim();
    if (!/[0-9]/.test(expr))
      return false;
    return /[+\-*/%^()!]/.test(expr)
      || /\b(to|in|as)\b/i.test(expr)
      || /[0-9][a-zA-Z]/.test(expr);
  }

  function evaluate(text) {
    root.query = text;
    if (!root.isCandidate(text)) {
      root.clear();
      return;
    }
    debounceTimer.restart();
  }

  function clear() {
    debounceTimer.stop();
    root._generation += 1;
    root.result = "";
    root.hasResult = false;
    proc.running = false;
  }

  Timer {
    id: debounceTimer
    interval: root.debounceMs
    repeat: false
    onTriggered: root._run()
  }

  function _run() {
    root._generation += 1;
    proc.generation = root._generation;
    // -t: terse, just the value — no "= " prefix or extra chrome to parse.
    proc.command = ["qalc", "-t", root.query.trim()];
    proc.running = false;
    proc.running = true;
  }

  Process {
    id: proc
    property int generation: 0
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        // Stale response for a query that's since changed or been cleared —
        // discard it rather than flashing an old result back on screen.
        if (proc.generation !== root._generation)
          return;

        // qalc can print warnings (e.g. precision loss) before the actual
        // result even in terse mode — the result is always the last line.
        const lines = text.trim().split("\n");
        const out = lines[lines.length - 1].trim();

        if (out === "" || /error/i.test(out)) {
          root.result = "";
          root.hasResult = false;
          return;
        }
        root.result = out;
        root.hasResult = true;
      }
    }
  }
}
