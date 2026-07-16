import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/session/daemon_session.dart';

void main() {
  group('resolveJeliyadBinaryFrom', () {
    String? resolve({
      Map<String, String> environment = const {},
      Set<String> executableFiles = const {},
      Set<String> existingFiles = const {},
      bool debugMode = false,
      bool isLinux = true,
      String executable = '/opt/jeliya/jeliya',
      String currentDirectory = '/checkout/app',
    }) => resolveJeliyadBinaryFrom(
      environment: environment,
      resolvedExecutable: executable,
      currentDirectory: currentDirectory,
      debugMode: debugMode,
      isLinux: isLinux,
      // Every executable file exists; existingFiles adds present-but-unusable
      // candidates (e.g. a sidecar that lost its execute bit).
      fileExists: (path) =>
          executableFiles.contains(path) || existingFiles.contains(path),
      fileIsExecutable: executableFiles.contains,
    );

    test('explicit override wins without probing other locations', () {
      expect(
        resolve(
          environment: const {
            'JELIYAD_BIN': '/custom/jeliyad',
            'PATH': '/usr/bin',
          },
          executableFiles: const {'/opt/jeliya/jeliyad', '/usr/bin/jeliyad'},
        ),
        '/custom/jeliyad',
      );
    });

    test('Linux bundle beside the runner wins over PATH', () {
      expect(
        resolve(
          environment: const {'PATH': '/usr/local/bin:/usr/bin'},
          executableFiles: const {
            '/opt/jeliya/jeliyad',
            '/usr/local/bin/jeliyad',
          },
        ),
        '/opt/jeliya/jeliyad',
      );
    });

    test('Linux supports an FHS lib directory beside the bin directory', () {
      expect(
        resolve(
          executable: '/usr/bin/jeliya',
          executableFiles: const {'/usr/bin/../lib/jeliya/jeliyad'},
        ),
        '/usr/bin/../lib/jeliya/jeliyad',
      );
    });

    test('a bundled sidecar that exists but is unusable is still selected', () {
      // The packaged app must run the sidecar it shipped: a present bundle
      // binary with a broken mode is returned so the spawn failure names its
      // exact path, instead of silently substituting a host-installed daemon.
      expect(
        resolve(
          environment: const {'PATH': '/usr/local/bin:/usr/bin'},
          existingFiles: const {'/opt/jeliya/jeliyad'},
          executableFiles: const {'/usr/local/bin/jeliyad'},
        ),
        '/opt/jeliya/jeliyad',
      );
    });

    test('an unusable PATH entry is skipped for a later usable one', () {
      // PATH is a last resort scanned for something exec(2) will accept: an
      // entry this user cannot run (e.g. a root-only 0700 binary) must not
      // shadow a working install later on the PATH.
      expect(
        resolve(
          environment: const {'PATH': '/usr/local/bin:/usr/bin'},
          existingFiles: const {'/usr/local/bin/jeliyad'},
          executableFiles: const {'/usr/bin/jeliyad'},
        ),
        '/usr/bin/jeliyad',
      );
    });

    test('debug repo binary wins over PATH', () {
      expect(
        resolve(
          environment: const {
            // i18n-exempt: 'HOME' is the env-var name, not the Home nav label
            'HOME': '/home/sekou',
            'PATH': '/usr/bin',
          },
          executableFiles: const {
            '/checkout/app/../target/debug/jeliyad',
            '/usr/bin/jeliyad',
          },
          debugMode: true,
        ),
        '/checkout/app/../target/debug/jeliyad',
      );
    });

    test('Linux can fall back to an installed PATH binary', () {
      expect(
        resolve(
          environment: const {'PATH': '/missing:/usr/local/bin:/usr/bin'},
          executableFiles: const {'/usr/local/bin/jeliyad'},
        ),
        '/usr/local/bin/jeliyad',
      );
    });

    test('PATH fallback is Linux-only', () {
      expect(
        resolve(
          environment: const {'PATH': '/usr/local/bin'},
          executableFiles: const {'/usr/local/bin/jeliyad'},
          isLinux: false,
        ),
        isNull,
      );
    });
  });

  test('Linux uses real networking without changing macOS loopback policy', () {
    expect(desktopSidecarUsesLoopback(isLinux: true), isFalse);
    expect(desktopSidecarUsesLoopback(isLinux: false), isTrue);
  });

  group('Linux package readiness signal', () {
    test('is absent from normal and non-Linux launches', () {
      expect(
        linuxPackageReadinessPathFrom(
          environment: const {},
          isLinux: true,
          dataDir: '/tmp/profile',
        ),
        isNull,
      );
      expect(
        linuxPackageReadinessPathFrom(
          environment: const {'JELIYA_LINUX_PACKAGE_GATE': '1'},
          isLinux: false,
          dataDir: '/tmp/profile',
        ),
        isNull,
      );
    });

    test('uses a fixed file inside the isolated gate data directory', () {
      expect(
        linuxPackageReadinessPathFrom(
          environment: const {'JELIYA_LINUX_PACKAGE_GATE': '1'},
          isLinux: true,
          dataDir: '/tmp/profile',
        ),
        '/tmp/profile/$linuxPackageReadinessFileName',
      );
      expect(
        linuxPackageReadinessPathFrom(
          environment: const {'JELIYA_LINUX_PACKAGE_GATE': '1'},
          isLinux: true,
          dataDir: '/tmp/profile/',
        ),
        '/tmp/profile/$linuxPackageReadinessFileName',
      );
    });

    test(
      'payload carries matching lifecycle facts but no authentication token',
      () {
        final payload = linuxPackageReadinessPayload(
          boot: 'ready',
          phase: 'noIdentity',
          connection:
              'connected', // i18n-exempt: wire enum fixture value, not copy
          frame: 'rendered',
          protocol: 1,
          appPid: 100,
          daemonPid: 101,
          daemonPort: 4242,
        );
        expect(payload, {
          'schema': 1,
          'boot': 'ready',
          'phase': 'noIdentity',
          'connection':
              'connected', // i18n-exempt: wire enum fixture value, not copy
          'frame': 'rendered',
          'protocol': 1,
          'app_pid': 100,
          'daemon_pid': 101,
          'daemon_port': 4242,
        });
        expect(payload, isNot(contains('auth_token')));
      },
    );
  });
}
