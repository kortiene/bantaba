# `src/l10n` — localization for the React client

The normative rules live in [`docs/i18n.md`](../../../docs/i18n.md) (seven rules,
binding on **both** clients) and the French terminology contract lives in
[`docs/glossary-fr.md`](../../../docs/glossary-fr.md). This note is only the
mechanics: where things are, and what to do when you add a string.

## Where copy lives

| File          | What it holds                                                          |
| ------------- | ---------------------------------------------------------------------- |
| `catalog.ts`  | The `Catalog` interface — the shape every locale must satisfy.          |
| `en.ts`       | The source of truth. Written first, reviewed as product copy.           |
| `fr.ts`       | Typed as `Catalog`, so a missing key is a **compile** error.            |
| `tokens.ts`   | Strings that are **not** copy and never reach a translator.             |
| `formats.ts`  | The single formatting seam (dates, bytes, counts, percent, rel. time).  |
| `locale.ts`   | The two persisted locale preferences and the platform fallback.         |
| `strings.tsx` | `useStrings()` / `useFormats()` — resolution at render time.            |
| `template.tsx`| `<Template>` for one sentence containing styled/interactive segments.   |

A component never holds a literal. It calls `useStrings()` in its render body
and reads `s.someKey`. Never capture the catalog into state or a module
constant — that is what makes a language switch apply live, with no restart.

## Adding a key

1. Add the field to `Catalog` in `catalog.ts`, in its area block, named
   `<area><Key>` in lowerCamelCase (`roomsFilterActive`) — the same scheme the
   Flutter ARB uses, so the two catalogs line up under review.
2. Plain string → `Message`. Needs a value from the call site → `MessageFn<[…]>`,
   which puts the argument list in the type and makes a missing one a type error
   instead of a `{name}` on screen.
3. Add the English value to `en.ts`, then the French to `fr.ts`. TypeScript
   fails the build until `fr.ts` is complete.
4. A sentence with a bolded name, a `<code>` id or a link is **one** message with
   `{slot}` markers rendered through `<Template>` — never JSX fragments glued
   together (rule 2). Independent facts on a meta line may be joined with
   `Punct.metaSep`; a sentence may not.

### French, briefly

Sentence case, vouvoiement, `U+202F` before `; ! ?` and inside `« »`, `U+00A0`
before `:`, `U+2019` for the apostrophe, `U+2026` for the ellipsis, octets
(`o/Ko/Mo/Go`), `42 %` with `U+202F`. Compare against the Flutter
`app/lib/src/l10n/arb/app_fr.arb`, which already follows the same contract —
if a phrase exists there, reuse its wording rather than inventing a second one.

## The never-translate module

`tokens.ts` holds glyphs, shell commands, wire-format examples, the brand, the
language endonyms and the issue URL. Some of these are a correctness matter,
not a style one: a `direct` / `relay` path badge must render the daemon's own
word, so "translating" it would be a lie about the network. Error **codes**
(`unavailable`, `hash_mismatch`), `daemon`, `jeliyad`, `pipe`, endpoint and
identity ids are the same — Tier 2 of the glossary. If a translator should
never see it, it belongs here and deliberately outside `Catalog`.

Protocol enums are never displayed raw either: they go through a display map
with a raw passthrough default for forward compatibility, so the wire value and
the display label are never the same constant.

## The two locale preferences

`textLocale` chooses the interface **language**; `formattingLocale` chooses
date, number and calendar **conventions**. They are separate persisted
preferences (glossary decision 4), and either may be unset, meaning "follow the
platform". Someone may read French while formatting under `en-CA`. The
deliberate exception, carried over from Flutter so the clients agree: byte-unit
words and the Today/Yesterday/"ago" phrases follow the **text** locale, because
they are vocabulary — only numeric and calendar conventions follow the
formatting locale.

Anything numeric or temporal goes through `useFormats()`. Never call
`toLocaleString` / `Intl` at a call site.

## How tests reference copy

Rule 6: assert copy through the shared `en` catalog, never a literal, so
translation work never breaks a test.

```ts
import { en } from '../src/l10n/en';
expect(screen.getByRole('button', { name: en.roomsCreate })).toBeVisible();
```

Fixture **data** — room names in `MOCK_ROOMS`, message bodies, file names —
stays literal. It is data, not copy; it is not translated, and pinning it is the
point. `e2e/fixtures.ts` states that split at the top and resolves every
destination label through `en`.

## Running the gate

```sh
cd ui
npx tsc --noEmit          # catalog completeness: fr.ts must satisfy Catalog
npm test                  # unit tests
npm run test:e2e          # typechecks e2e, then Playwright across the matrix
```

Completeness is a type error, not a runtime blank. The CI gate exists for what
types cannot see — an empty string, or a key left in English.
