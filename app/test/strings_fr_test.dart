/// French-catalog contract pins — the guard rails a translation regression
/// trips: CLDR fr plurals (ICU 'one' covers 0 AND 1 — « 0 membre » is
/// singular in French), Tier 1 glossary vocabulary, Tier 2 never-translate
/// tokens, the Tier 3 brand line, and decision 7 typography
/// (docs/glossary-fr.md). Copy pins here are FRENCH values — the EN catalog
/// stays pinned by the generated l10n_parity_test.
library;

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('fr plurals: 0 and 1 are singular (CLDR fr), 2+ plural', () {
    expect(fr.panelRoomMemberCount(0), startsWith('0 membre'));
    expect(fr.panelRoomMemberCount(0), isNot(contains('membres')));
    expect(fr.panelRoomMemberCount(1), isNot(contains('membres')));
    expect(fr.panelRoomMemberCount(2), contains('membres'));
    expect(fr.timelineNewMessages(0), isNot(contains('messages')));
    expect(fr.timelineNewMessages(5), contains('messages'));
  });

  test('Tier 2 wire tokens stay verbatim in French', () {
    expect(fr.bootBinaryNotFound, contains('jeliyad'));
    expect(fr.bootBinaryNotFound, contains('JELIYAD_BIN'));
    // The wire display words ARE the tokens — French must equal English.
    expect(fr.wirePathDirect, en.wirePathDirect);
    expect(fr.wirePathRelay, en.wirePathRelay);
    expect(fr.wireModeLoopback, en.wireModeLoopback);
  });

  test('Tier 3: the onboarding tagline carries the brand line', () {
    expect(fr.onboardingTagline,
        'Jeliya — l’art du djéli, gardien de la mémoire vraie.');
  });

  test('Tier 1 glossary vocabulary holds', () {
    expect(fr.sidebarYourRooms.toLowerCase(), contains('salons'));
    expect(fr.sidebarNavSettings, 'Réglages');
    expect(fr.modalJoinRoom.toLowerCase(), contains('rejoindre'));
    expect(fr.panelShare.toLowerCase(), contains('partager'));
  });

  test('decision 7 typography: non-breaking spaces in live copy', () {
    // U+00A0 before ':' (the agent status footer).
    expect(fr.panelAgentStatusFooter('x'), contains(' :'));
    // Byte units are octets (decision 7): Ko, not KB.
    expect(fr.timelineBytesKb(1), contains('Ko'));
    expect(fr.timelineBytesKb(1), isNot(contains('KB')));
  });
}
