#!/usr/bin/env node
// i18n gate: no user-visible string literals outside the l10n layer.
//
// Rules (heuristic, tuned for zero findings on a clean tree):
//  1. app/lib/** (except lib/src/l10n/ and theme.dart): widget text params
//     (Text(...), hintText:, labelText:, semanticsLabel:, tooltip:, label:,
//     message:, title:, text:) must not take a letters-bearing string
//     literal — copy belongs in the ARB catalog (see remediation below).
//  2. Same scope: no `lookupAppStrings(` — production code resolves the
//     catalog through context.strings (Localizations-dependent); a lookup
//     call pins one locale and breaks live switching.
//  3. dart/jeliya_protocol/lib/src/conventions/**: no sentence-shaped
//     literals (capitalized multi-word) in code — UI narration is composed
//     app-side from structured fields (the join.dart rule).
//  4. app/test/** (except the GENERATED l10n_parity_test.dart, which pins
//     catalog values BY DESIGN): a string literal that IS a plain catalog
//     value (or its uppercased render-time form) asserts copy — tests
//     assert via the shared `en` instance (test/helpers.dart) so copy edits
//     and translation work never break them (docs/i18n.md rule 6). Fixture
//     data doesn't collide with catalog copy; a deliberate coincidence
//     opts out with i18n-exempt.
//
// A line may opt out with an `i18n-exempt: <reason>` comment (same line or
// the line above). Scanning is SOURCE-scoped: a literal wrapped onto its own
// line by dart format is still caught.
// Run: node scripts/i18n-gate.mjs   (exit 1 on findings)

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;

function* dartFiles(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* dartFiles(p);
    else if (p.endsWith('.dart')) yield p;
  }
}

// Letters that survive after stripping interpolation are "real" copy.
function bareLetters(literal) {
  const stripped = literal
    .replace(/\$\{[^}]*\}/g, '')
    .replace(/\$[A-Za-z_][A-Za-z0-9_]*/g, '');
  // A leftover '${' means the capture was truncated by a quote NESTED inside
  // an interpolation (e.g. '${open ? '▾' : '▸'} ...') — the regex cannot see
  // the real literal boundary, so don't judge the fragment.
  if (stripped.includes('${')) return null;
  return stripped.match(/[A-Za-z]{2,}/);
}

// Blank out comments (string-aware: '//' inside a literal survives) so
// commented-out code can't match; newlines are preserved for line numbers.
function stripComments(src) {
  return src.replace(
    /('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")|\/\/[^\n]*|\/\*[\s\S]*?\*\//g,
    (m, str) => str ?? m.replace(/[^\n]/g, ' '),
  );
}

const findings = [];

function scan(file, patterns) {
  const rel = relative(root, file);
  const src = readFileSync(file, 'utf8');
  const code = stripComments(src);
  const lines = src.split('\n');
  const exempt = (lineIdx) =>
    (lines[lineIdx] ?? '').includes('i18n-exempt') ||
    (lines[lineIdx - 1] ?? '').includes('i18n-exempt');
  for (const pattern of patterns) {
    for (const m of code.matchAll(pattern)) {
      // Group 2 is the literal's content (group 1 its quote character);
      // patterns without groups (bare markers) flag on any match.
      if (m[2] !== undefined && !bareLetters(m[2])) continue;
      const line = code.slice(0, m.index).split('\n').length - 1;
      // A match can span lines (formatter-wrapped literal after `Text(`) —
      // honor the marker anywhere in the span, so same-line placement on
      // the literal's own line works as documented.
      const endLine =
        code.slice(0, m.index + m[0].length).split('\n').length - 1;
      let exempted = false;
      for (let l = line; l <= endLine && !exempted; l++) exempted = exempt(l);
      if (exempted) continue;
      findings.push(`${rel}:${line + 1}  ${lines[line].trim()}`);
    }
  }
}

// Either quote style (backreference keeps the pair matched); [\s\S] lets a
// formatter-wrapped literal on the next line still match.
const literal = String.raw`(['"])((?:\\.|(?!\1).)*?)\1`;
const appPatterns = [
  new RegExp(String.raw`(?:\bText|\bSelectableText)\(\s*${literal}`, 'g'),
  new RegExp(
    String.raw`\b(?:hintText|labelText|semanticsLabel|tooltip|label|message|title|text):\s*${literal}`,
    'g',
  ),
  // Locale pinning (rule 2) — no capture group: any occurrence flags.
  /\blookupAppStrings\(/g,
];
// Sentence-shaped: a capitalized word then two more words inside one literal.
const conventionsPatterns = [
  new RegExp(String.raw`(['"])([A-Z][a-z]+ [a-z]+ (?:\\.|(?!\1).)*?)\1`, 'g'),
];

for (const file of dartFiles(join(root, 'app/lib'))) {
  const rel = relative(root, file);
  if (rel.startsWith('app/lib/src/l10n/') || rel === 'app/lib/src/theme.dart') {
    continue;
  }
  scan(file, appPatterns);
}
for (const file of dartFiles(join(root, 'dart/jeliya_protocol/lib/src/conventions'))) {
  scan(file, conventionsPatterns);
}

// Rule 4 — test literals that duplicate catalog copy. Plain entries only:
// parameterized values can't appear verbatim in a finder anyway.
const arb = JSON.parse(
  readFileSync(join(root, 'app/lib/src/l10n/arb/app_en.arb'), 'utf8'),
);
const catalogValues = new Set();
for (const [key, value] of Object.entries(arb)) {
  if (key.startsWith('@') || typeof value !== 'string' || value.includes('{')) {
    continue;
  }
  // Same letters guard as rule 1: a letterless value ('?') is not copy a
  // test could meaningfully duplicate.
  if (!/[A-Za-z]{2}/.test(value)) continue;
  catalogValues.add(value);
  catalogValues.add(value.toUpperCase()); // render-time .toUpperCase() copies
}

// All three Dart unicode escape forms plus the control/identity escapes.
function unescapeDart(s) {
  return s.replace(
    /\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|.)/g,
    (_, c) => {
      if (c.startsWith('u{')) {
        return String.fromCodePoint(parseInt(c.slice(2, -1), 16));
      }
      if (/^u[0-9a-fA-F]{4}$/.test(c) || /^x[0-9a-fA-F]{2}$/.test(c)) {
        return String.fromCodePoint(parseInt(c.slice(1), 16));
      }
      return { n: '\n', t: '\t', r: '\r' }[c] ?? c;
    },
  );
}

function scanTestCopy(file) {
  const rel = relative(root, file);
  const src = readFileSync(file, 'utf8');
  const code = stripComments(src);
  const lines = src.split('\n');
  const exempt = (lineIdx) =>
    (lines[lineIdx] ?? '').includes('i18n-exempt') ||
    (lines[lineIdx - 1] ?? '').includes('i18n-exempt');
  // Merge adjacent-string concatenation ('foo '\n'bar' — dart format's wrap
  // shape) into one run before the lookup, or long copy escapes the set.
  const runs = [];
  for (const m of code.matchAll(new RegExp(literal, 'g'))) {
    const prev = runs[runs.length - 1];
    if (prev && /^\s*$/.test(code.slice(prev.end, m.index))) {
      prev.content += m[2];
      prev.end = m.index + m[0].length;
    } else {
      runs.push({
        start: m.index,
        end: m.index + m[0].length,
        content: m[2],
      });
    }
  }
  for (const run of runs) {
    if (!catalogValues.has(unescapeDart(run.content))) continue;
    const line = code.slice(0, run.start).split('\n').length - 1;
    const endLine = code.slice(0, run.end).split('\n').length - 1;
    let exempted = false;
    for (let l = line; l <= endLine && !exempted; l++) exempted = exempt(l);
    if (exempted) continue;
    findings.push(`${rel}:${line + 1}  ${lines[line].trim()}`);
  }
}

for (const file of dartFiles(join(root, 'app/test'))) {
  if (relative(root, file) === 'app/test/l10n_parity_test.dart') continue;
  scanTestCopy(file);
}

if (findings.length > 0) {
  console.error(`i18n-gate: ${findings.length} finding(s)\n`);
  for (const f of findings) console.error('  ' + f);
  console.error('\nCopy belongs in app/lib/src/l10n/arb/app_en.arb (with an');
  console.error('@description for translators) — run `flutter gen-l10n` and');
  console.error('reference it via context.strings. Non-copy glyphs/URLs/commands');
  console.error('go in app/lib/src/l10n/tokens.dart. lookupAppStrings() is for');
  console.error('tests only. Tests assert copy via `en.<key>` (test/helpers.dart),');
  console.error('never a literal duplicate of a catalog value. Deliberate');
  console.error('exceptions: `// i18n-exempt: <reason>`.');
  process.exit(1);
}
console.log('i18n-gate: OK — no user-visible literals outside the l10n layer.');
