// Desktop data-dir resolution: macOS App Sandbox home unwrapping plus Linux
// XDG data roots. The debug product-name split keeps developer runs isolated
// from release identities on both platforms.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/session/daemon_session.dart';

void main() {
  group('realHomeFrom', () {
    test('unwraps a sandbox container HOME', () {
      expect(
        realHomeFrom(
          '/Users/sekou/Library/Containers/com.incubtek.jeliya/Data',
        ),
        '/Users/sekou',
      );
    });

    test('passes a real home through untouched', () {
      expect(realHomeFrom('/Users/sekou'), '/Users/sekou');
      expect(realHomeFrom('/var/root'), '/var/root');
    });

    test('never returns empty for a pathological value', () {
      // A HOME that *starts* with the marker has no user prefix to recover.
      expect(
        realHomeFrom('/Library/Containers/x/Data'),
        '/Library/Containers/x/Data',
      );
    });
  });

  group('defaultDataDirFrom', () {
    test('explicit override wins on every platform and build mode', () {
      expect(
        defaultDataDirFrom(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': '/home/sekou',
            'XDG_DATA_HOME': '/state',
            'JELIYA_DATA_DIR': '/profiles/demo',
          },
          fallbackHome: '/tmp',
          debugMode: true,
          isLinux: true,
        ),
        '/profiles/demo',
      );
    });

    test('Linux release uses XDG_DATA_HOME', () {
      expect(
        defaultDataDirFrom(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': '/home/sekou',
            'XDG_DATA_HOME': '/mnt/state',
          },
          fallbackHome: '/tmp',
          debugMode: false,
          isLinux: true,
        ),
        '/mnt/state/Jeliya',
      );
    });

    test('Linux debug uses an isolated product directory', () {
      expect(
        defaultDataDirFrom(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': '/home/sekou',
          },
          fallbackHome: '/tmp',
          debugMode: true,
          isLinux: true,
        ),
        '/home/sekou/.local/share/JeliyaAppDev',
      );
    });

    test('Linux falls back for an invalid relative XDG_DATA_HOME', () {
      expect(
        defaultDataDirFrom(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': '/home/sekou',
            'XDG_DATA_HOME': 'relative/state',
          },
          fallbackHome: '/tmp',
          debugMode: false,
          isLinux: true,
        ),
        '/home/sekou/.local/share/Jeliya',
      );
    });

    test('Linux can use XDG_DATA_HOME when HOME is absent', () {
      expect(
        defaultDataDirFrom(
          environment: const {'XDG_DATA_HOME': '/run/user/1000/data'},
          fallbackHome: '/tmp/session',
          debugMode: false,
          isLinux: true,
        ),
        '/run/user/1000/data/Jeliya',
      );
    });

    test('Linux fails closed when neither absolute data base is available', () {
      for (final environment in <Map<String, String>>[
        const {},
        const {
          // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
          'HOME': '',
        },
        const {
          // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
          'HOME': 'relative/home',
        },
        const {'XDG_DATA_HOME': 'relative/data'},
      ]) {
        expect(
          () => defaultDataDirFrom(
            environment: environment,
            fallbackHome: '/tmp/session',
            debugMode: false,
            isLinux: true,
          ),
          throwsA(isA<StateError>()),
        );
      }
    });

    test('macOS still uses the fallback home when HOME is absent', () {
      expect(
        defaultDataDirFrom(
          environment: const {},
          fallbackHome: '/tmp/session',
          debugMode: false,
          isLinux: false,
        ),
        '/tmp/session/Library/Application Support/Jeliya',
      );
    });

    test('macOS keeps its shared release and isolated debug paths', () {
      const home = '/Users/sekou/Library/Containers/com.incubtek.jeliya/Data';
      expect(
        defaultDataDirFrom(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': home,
          },
          fallbackHome: '/tmp',
          debugMode: false,
          isLinux: false,
        ),
        '/Users/sekou/Library/Application Support/Jeliya',
      );
      expect(
        defaultDataDirFrom(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': home,
          },
          fallbackHome: '/tmp',
          debugMode: true,
          isLinux: false,
        ),
        '/Users/sekou/Library/Application Support/JeliyaAppDev',
      );
    });
  });
}
