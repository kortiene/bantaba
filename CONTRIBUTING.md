# Contributing to Jeliya

Thanks for wanting to help build the gathering place. Setup lives in the
README ("Build from source"); the daemon ⇄ UI contract is
`docs/PROTOCOL.md`; design tokens and rules are `DESIGN.md`.

## The honesty rules are contribution requirements

Jeliya's one promise is that the screen never shows a comforting lie.
Contributions are reviewed against that promise first:

1. **No fake state.** No optimistic "delivered" checks, no spinners implying
   progress that isn't happening, no invented presence. Render what the
   signed log proves.
2. **Green is earned.** The emerald accent marks real, verified
   live/healthy state — never decoration, never a fallback
   (see `labelTone` in `dart/jeliya_protocol/lib/src/conventions/format.dart`,
   normative in `docs/PROTOCOL.md`).
3. **Failures are failures.** Errors surface their real code
   (`unavailable`, `unauthorized`, `hash_mismatch`) and a useful hint —
   never a silent partial result.
4. **Accessibility floor.** WCAG 2.1 AA: ≥4.5:1 contrast for
   information-bearing text, status never by color alone (dot + label),
   `prefers-reduced-motion` honored, full keyboard operability.

A PR that makes the UI friendlier by making it less truthful will be
declined kindly.

## Practical notes

- **Layering:** only `jeliya-core` may import the `iroh-rooms` SDK. The
  daemon (`jeliyad`) speaks `docs/PROTOCOL.md` to the UI; don't route around
  the contract.
- **Prove it runs.** `node scripts/agent-e2e.mjs` proves the agent flow
  end-to-end with no network and no AI; `scripts/demo.sh` runs the full
  two-daemon demo. Say in the PR what you ran.
- **Strings & i18n:** French ships at desktop launch — `docs/i18n.md` records
  the decisions and engineering rules; `docs/glossary-fr.md` the glossary
  tiers. App copy lives in the ARB catalog (`app/lib/src/l10n/arb/app_en.arb`
  with an `@description` per key); run `flutter gen-l10n` and
  `node scripts/gen-l10n-parity.mjs` after editing it, and resolve copy via
  `context.strings` at render time. No hand-rolled pluralizations (ICU
  plurals in the ARB), no sentence-building from concatenated fragments (use
  `template_text.dart` slots), no wire enums as display text. Tests assert
  copy via the shared `en` catalog instance (`test/helpers.dart`), never a
  literal duplicate of a catalog value. `node scripts/i18n-gate.mjs`
  enforces the literal, locale-pinning, and test-copy rules — CI runs it on
  every PR and push to main, and the release jobs gate on it.
- **Naming:** the project renamed from Bantaba to Jeliya on 2026-07-05
  (`docs/naming.md`). Don't reintroduce the old name outside that record.
- **Security reports:** privately, please — see `SECURITY.md`.

## License

Dual-licensed MIT OR Apache-2.0. By contributing, you agree your
contribution may be distributed under both.
