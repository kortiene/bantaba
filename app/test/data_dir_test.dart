// Data-dir resolution under the App Sandbox (Phase 5): $HOME points at the
// app container, but the shared-dir exception is resolved against the REAL
// home — realHomeFrom must unwrap the container prefix and pass everything
// else through untouched.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/session/daemon_session.dart';

void main() {
  test('realHomeFrom unwraps a sandbox container HOME', () {
    expect(
      realHomeFrom('/Users/sekou/Library/Containers/com.incubtek.jeliya/Data'),
      '/Users/sekou',
    );
  });

  test('realHomeFrom passes a real home through untouched', () {
    expect(realHomeFrom('/Users/sekou'), '/Users/sekou');
    expect(realHomeFrom('/var/root'), '/var/root');
  });

  test('realHomeFrom never returns empty for a pathological value', () {
    // A HOME that *starts* with the marker has no user prefix to recover.
    expect(realHomeFrom('/Library/Containers/x/Data'),
        '/Library/Containers/x/Data');
  });
}
