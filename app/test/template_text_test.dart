/// The {slot} template machinery is the load-bearing i18n primitive — these
/// tests pin its splitting contract AND that every production template still
/// matches the slot set its call site provides (a renamed slot must fail
/// here, not ship as a literal '{marker}' on screen).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/widgets/template_text.dart';

import 'helpers.dart';

TextSpan _slot(String text) => TextSpan(text: text);

/// Flattens rendered spans back to text (slot spans included).
String _flat(List<InlineSpan> spans) {
  final buf = StringBuffer();
  for (final s in spans) {
    s.visitChildren((child) {
      if (child is TextSpan && child.text != null) buf.write(child.text);
      return true;
    });
  }
  return buf.toString();
}

void main() {
  group('templateSpans', () {
    test('splits literal / slot / literal', () {
      final spans =
          templateSpans('a {x} b', slots: {'x': _slot('X')});
      expect(_flat(spans), 'a X b');
      expect(spans, hasLength(3));
    });

    test('slot at start and end, and adjacent slots', () {
      expect(
          _flat(templateSpans('{a}mid{b}',
              slots: {'a': _slot('A'), 'b': _slot('B')})),
          'AmidB');
      expect(
          _flat(templateSpans('{a}{b}',
              slots: {'a': _slot('A'), 'b': _slot('B')})),
          'AB');
    });

    test('template with no slots passes through', () {
      final spans = templateSpans('plain sentence', slots: const {});
      expect(_flat(spans), 'plain sentence');
      expect(spans, hasLength(1));
    });

    test('unknown slot asserts in debug', () {
      expect(() => templateSpans('{missing}', slots: const {}),
          throwsAssertionError);
    });
  });

  group('fillTemplate', () {
    test('fills plain-text values', () {
      expect(
          fillTemplate(en.commonOptionalFieldLabel('{label}', '{optional}'), {
            'label': en.modalPeerAddrLabel,
            'optional': en.modalPeerAddrOptional,
          }),
          en.commonOptionalFieldLabel(
              en.modalPeerAddrLabel, en.modalPeerAddrOptional));
    });

    test('unknown slot asserts in debug', () {
      expect(() => fillTemplate('{missing}', const {}), throwsAssertionError);
    });
  });

  group('templateParts', () {
    test('yields literal and slot parts in order', () {
      final parts = templateParts(en.timelineAuthorizedPeer('{peer}'));
      expect(parts, hasLength(2));
      // Filling the trailing slot with '' leaves exactly the literal prefix.
      expect(parts[0].text, en.timelineAuthorizedPeer(''));
      expect(parts[1].slot, 'peer');
    });
  });

  group('production templates match their call-site slot sets', () {
    // One entry per templateText/templateParts call site in the app. A
    // template/slot rename that breaks the pairing fails HERE.
    final cases = <String, (String, Set<String>)>{
      'syslineRoomCreated': (
        en.timelineSyslineRoomCreated('{sender}', 't'),
        {'sender'}
      ),
      'syslineInvited': (
        en.timelineSyslineInvited(
            '{sender}', '{invitee}', en.wireRoleMemberInline, 't'),
        {'sender', 'invitee'}
      ),
      'syslineJoined': (
        en.timelineSyslineJoined('{who}', en.wireRoleMemberInline, 't'),
        {'who'}
      ),
      'syslineLeft': (en.timelineSyslineLeft('{who}', 't'), {'who'}),
      'syslinePipeClosed': (
        en.timelineSyslinePipeClosed('{sender}', '{target}', 't'),
        {'sender', 'target'}
      ),
      'authorizedPeer': (en.timelineAuthorizedPeer('{peer}'), {'peer'}),
      'pipeMeta': (
        en.panelPipeMeta('{openedBy}', '{authorized}'),
        {'openedBy', 'authorized'}
      ),
      'detailVerified': (en.fetchDetailVerified('1 KB', '{path}'), {'path'}),
      'detailFetched': (en.fetchDetailFetched('1 KB', '{path}'), {'path'}),
      'joinCopy': (en.modalJoinCopy('{combined}'), {'combined'}),
      'leaveCopy': (en.modalLeaveCopy('{room}'), {'room'}),
      'addAgentIntro': (en.addAgentIntro('{emphasis}'), {'emphasis'}),
      'addAgentGuidance': (
        en.addAgentGuidance('{npm}', '{jeliyad}', '{prefix}', '{guide}'),
        {'npm', 'jeliyad', 'prefix', 'guide'}
      ),
      'optionalFieldLabel': (
        en.commonOptionalFieldLabel('{label}', '{optional}'),
        {'label', 'optional'}
      ),
    };

    cases.forEach((name, entry) {
      test(name, () {
        final (template, slotNames) = entry;
        final slots = {for (final n in slotNames) n: _slot('[$n]')};
        // Renders without the unknown-slot assert…
        final spans = templateSpans(template, slots: slots);
        final flat = _flat(spans);
        // …every declared slot actually appears…
        for (final n in slotNames) {
          expect(flat, contains('[$n]'),
              reason: 'template "$name" no longer references {$n}');
        }
        // …and no marker survives unexpanded.
        expect(flat, isNot(matches(RegExp(r'\{[a-zA-Z0-9_]+\}'))),
            reason: 'template "$name" has a slot its call site does not fill');
      });
    });
  });
}
