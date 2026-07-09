/// Functional Tokens content: the launch command's conditional shell
/// assembly is security-relevant copy-paste material — pin it exactly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';

void main() {
  test('addAgentLaunchCommand assembles with and without a peer addr', () {
    expect(
      Tokens.addAgentLaunchCommand(
          ticket: 't1', addr: 'ep@203.0.113.7:4242', worker: 'echo'),
      'node scripts/jeliya-agent.mjs --ticket t1 '
      '--peer ep@203.0.113.7:4242 --worker echo',
    );
    expect(
      Tokens.addAgentLaunchCommand(ticket: 't1', addr: null, worker: 'claude'),
      'node scripts/jeliya-agent.mjs --ticket t1 --worker claude',
    );
  });

  test('issueUrl stays the exact GitHub issue form', () {
    expect(Tokens.issueUrl,
        'https://github.com/kortiene/jeliya/issues/new?title=Jeliya+issue+report');
  });
}
