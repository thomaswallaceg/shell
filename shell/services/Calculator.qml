pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Launcher calculator backed by fend (crates.io, installed by install.sh
// rust); debounced, with a generation counter against out-of-order results.
// fend over qalc: it takes "to", "in" and "as" as conversions, where qalc
// only takes "to" and reads "9 inches in cm" as inch·inch·cm. The cost is
// that inches have to be spelled "inch"/"inches".
Singleton {
  id: root

  readonly property int debounceMs: 120

  property string query: ""
  property string result: ""
  property bool hasResult: false
  // fend marks inexact results (1/3, pi, currencies) with "approx. "; that's
  // stripped from result so the copied value is just the number.
  property bool approximate: false

  property int _generation: 0

  // Only spawn fend for queries with a digit that also look like an expression:
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
    root.approximate = false;
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
    proc.command = ["fend", root.query.trim()];
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

        // fend reports errors (unknown identifier, division by zero, ...) on
        // stderr with a non-zero exit, so empty stdout means no result.
        const out = text.trim();
        if (out === "") {
          root.result = "";
          root.hasResult = false;
          root.approximate = false;
          return;
        }
        root.approximate = out.startsWith("approx. ");
        root.result = root.approximate ? out.slice("approx. ".length) : out;
        root.hasResult = true;
      }
    }
  }
}
