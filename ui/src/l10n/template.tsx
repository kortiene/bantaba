/** Sentences with styled or interactive segments (`docs/i18n.md` rule 2).
 *
 *  A sentence must never be assembled from fragments in a component tree. This
 *  is not a style preference — it is the difference between a translatable
 *  string and an untranslatable one. JSX like
 *
 *      <p>Leaving <strong>{room}</strong> <code>{id}</code> publishes a signed
 *         departure.</p>
 *
 *  hands a translator three disconnected pieces and fixes English word order
 *  permanently. French needs the slots in a different place, and no amount of
 *  translating the fragments can move them.
 *
 *  So the whole sentence is ONE catalog message carrying `{slot}` markers, and
 *  the call site supplies what each marker renders as:
 *
 *      <Template template={s.roomLeaveWarning} slots={{
 *        room: <strong>{name}</strong>,
 *        id: <code className="mono">{shortId(roomId)}</code>,
 *      }} />
 *
 *  The translator moves `{room}` and `{id}` wherever the sentence needs them.
 *  Flutter does exactly this in `widgets/template_text.dart`.
 */

import { Fragment } from 'react';
import type { ReactNode } from 'react';

const MARKER = /\{(\w+)\}/g;

/** Split a template into literal text and slot names. Exported for the plain
 *  string case and for tests. */
export function templateParts(template: string): ({ text: string } | { slot: string })[] {
  const parts: ({ text: string } | { slot: string })[] = [];
  let last = 0;
  for (const match of template.matchAll(MARKER)) {
    if (match.index > last) parts.push({ text: template.slice(last, match.index) });
    parts.push({ slot: match[1] });
    last = match.index + match[0].length;
  }
  if (last < template.length) parts.push({ text: template.slice(last) });
  return parts;
}

export function Template({
  template,
  slots,
}: {
  template: string;
  slots: Record<string, ReactNode>;
}) {
  return (
    <>
      {templateParts(template).map((part, i) => {
        if ('text' in part) return <Fragment key={i}>{part.text}</Fragment>;
        // An unknown marker renders LITERALLY rather than disappearing. A
        // silently dropped slot is a sentence that reads fine and says the
        // wrong thing — a visible `{room}` is a bug report from the screen.
        const value = part.slot in slots ? slots[part.slot] : `{${part.slot}}`;
        return <Fragment key={i}>{value}</Fragment>;
      })}
    </>
  );
}

/** The plain-string variant, for an `aria-label` or a `title` where a
 *  ReactNode cannot go. */
export function fillTemplate(template: string, slots: Record<string, string>): string {
  return templateParts(template)
    .map((part) => ('text' in part ? part.text : (slots[part.slot] ?? `{${part.slot}}`)))
    .join('');
}
