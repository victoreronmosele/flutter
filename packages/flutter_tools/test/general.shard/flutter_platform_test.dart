// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/test/flutter_platform.dart';
import 'package:test_core/backend.dart';

import '../src/common.dart';
import '../src/context.dart';

void main() {
  late FileSystem fileSystem;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"configVersion":2,"packages":[]}');
  });

  group('FlutterPlatform', () {
    late SuitePlatform fakeSuitePlatform;
    setUp(() {
      fakeSuitePlatform = SuitePlatform(Runtime.vm);
    });

    testUsingContext('ensureConfiguration throws an error if an '
      'explicitVmServicePort is specified and more than one test file', () async {
      final FlutterPlatform flutterPlatform = FlutterPlatform(
        shellPath: '/',
        debuggingOptions: DebuggingOptions.enabled(
          BuildInfo.debug,
          hostVmServicePort: 1234,
        ),
        enableVmService: false,
      );
      flutterPlatform.loadChannel('test1.dart', fakeSuitePlatform);

      expect(() => flutterPlatform.loadChannel('test2.dart', fakeSuitePlatform), throwsToolExit());
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
    });

    testUsingContext('ensureConfiguration throws an error if a precompiled '
      'entrypoint is specified and more that one test file', () {
      final FlutterPlatform flutterPlatform = FlutterPlatform(
        debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
        shellPath: '/',
        precompiledDillPath: 'example.dill',
        enableVmService: false,
      );
      flutterPlatform.loadChannel('test1.dart', fakeSuitePlatform);

      expect(() => flutterPlatform.loadChannel('test2.dart', fakeSuitePlatform), throwsToolExit());
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
    });

    testUsingContext('installHook creates a FlutterPlatform', () {
      expect(() => installHook(
        shellPath: 'abc',
        debuggingOptions: DebuggingOptions.enabled(
          BuildInfo.debug,
          startPaused: true,
        ),
      ), throwsAssertionError);

      expect(() => installHook(
        shellPath: 'abc',
        debuggingOptions: DebuggingOptions.enabled(
          BuildInfo.debug,
          startPaused: true,
          hostVmServicePort: 123,
        ),
      ), throwsAssertionError);

      FlutterPlatform? capturedPlatform;
      final Map<String, String> expectedPrecompiledDillFiles = <String, String>{'Key': 'Value'};
      final FlutterPlatform flutterPlatform = installHook(
        shellPath: 'abc',
        debuggingOptions: DebuggingOptions.enabled(
          BuildInfo.debug,
          startPaused: true,
          disableServiceAuthCodes: true,
          hostVmServicePort: 200,
        ),
        enableVmService: true,
        machine: true,
        precompiledDillPath: 'def',
        precompiledDillFiles: expectedPrecompiledDillFiles,
        updateGoldens: true,
        testAssetDirectory: '/build/test',
        serverType: InternetAddressType.IPv6,
        icudtlPath: 'ghi',
        platformPluginRegistration: (FlutterPlatform platform) {
          capturedPlatform = platform;
        },
      );

      expect(identical(capturedPlatform, flutterPlatform), equals(true));
      expect(flutterPlatform.shellPath, equals('abc'));
      expect(flutterPlatform.debuggingOptions.buildInfo, equals(BuildInfo.debug));
      expect(flutterPlatform.debuggingOptions.startPaused, equals(true));
      expect(flutterPlatform.debuggingOptions.disableServiceAuthCodes, equals(true));
      expect(flutterPlatform.debuggingOptions.hostVmServicePort, equals(200));
      expect(flutterPlatform.enableVmService, equals(true));
      expect(flutterPlatform.machine, equals(true));
      expect(flutterPlatform.host, InternetAddress.loopbackIPv6);
      expect(flutterPlatform.precompiledDillPath, equals('def'));
      expect(flutterPlatform.precompiledDillFiles, expectedPrecompiledDillFiles);
      expect(flutterPlatform.updateGoldens, equals(true));
      expect(flutterPlatform.testAssetDirectory, '/build/test');
      expect(flutterPlatform.icudtlPath, equals('ghi'));
    });

    group('createListenerDart', () {
      late FlutterPlatform flutterPlatform;

      final Map<Type, Generator> overrides = <Type, Generator>{
        FileSystem: () => fileSystem,
        ProcessManager: () => FakeProcessManager.any(),
      };

      setUp(
        () {
          fileSystem.directory('build').createSync();

          final FlutterProject project = FlutterProject.fromDirectoryTest(
            fileSystem.currentDirectory,
          );

          flutterPlatform = FlutterPlatform(
            shellPath: '/',
            debuggingOptions: DebuggingOptions.enabled(
              const BuildInfo(
                BuildMode.debug,
                null,
                treeShakeIcons: false,
              ),
            ),
            enableVmService: false,
            flutterProject: project,
            host: InternetAddress.loopbackIPv6,
            updateGoldens: true,
          );
        },
      );

      testUsingContext(
          'creates listener.dart in the build directory of the FlutterProject',
          () async {
        final String listenerFilePath = flutterPlatform.createListenerDart(
          'test.dart',
        );

        const String expectedListenerFilePath =
            '/build/flutter_test_listener/listener.dart';

        expect(listenerFilePath, expectedListenerFilePath);

        expect(fileSystem.file(expectedListenerFilePath).existsSync(), isTrue);
      }, overrides: overrides);

      testUsingContext(
          'does not create a new listener.dart file if called more '
          'than once with the same test path', () async {
        final String listenerFilePath1 = flutterPlatform.createListenerDart(
          'test.dart',
        );

        final File listenerFile1 = fileSystem.file(listenerFilePath1);

        final String listenerFilePath2 = flutterPlatform.createListenerDart(
          'test.dart',
        );

        final File listenerFile2 = fileSystem.file(listenerFilePath2);

        expect(listenerFilePath1, listenerFilePath2);

        expect(listenerFile1.existsSync(), isTrue);
        expect(listenerFile2.existsSync(), isTrue);

        expect(
            listenerFile1.lastModifiedSync(), listenerFile2.lastModifiedSync());
        expect(
            listenerFile1.readAsBytesSync(), listenerFile2.readAsBytesSync());
      }, overrides: overrides);

      testUsingContext(
          'does not create a new listener.dart file if called more '
          'than once with different test paths', () async {
        final String listenerFilePath1 = flutterPlatform.createListenerDart(
          'test1.dart',
        );

        final File listenerFile1 = fileSystem.file(listenerFilePath1);

        final String listenerFilePath2 = flutterPlatform.createListenerDart(
          'test2.dart',
        );

        final File listenerFile2 = fileSystem.file(listenerFilePath2);

        expect(listenerFilePath1, listenerFilePath2);

        expect(listenerFile1.existsSync(), isTrue);
        expect(listenerFile2.existsSync(), isTrue);

        expect(
            listenerFile1.lastModifiedSync(), listenerFile2.lastModifiedSync());
        expect(
            listenerFile1.readAsBytesSync(), listenerFile2.readAsBytesSync());
      }, overrides: overrides);
    });
  });

  group('generateTestBootstrap', () {
    group('writes a "const packageConfigLocation" string', () {
      test('with null packageConfigUri', () {
        final String contents = generateTestBootstrap(
          testUrl:
              Uri.parse('file:///Users/me/some_package/test/some_test.dart'),
          host: InternetAddress('127.0.0.1', type: InternetAddressType.IPv4),
        );
        // IMPORTANT: DO NOT RENAME, REMOVE, OR MODIFY THE
        // 'const packageConfigLocation' VARIABLE.
        // Dash tooling like Dart DevTools performs an evaluation on this variable
        // at runtime to get the package config location for Flutter test targets.
        expect(contents, contains("const packageConfigLocation = 'null';"));
      });

      test('with non-null packageConfigUri', () {
        final String contents = generateTestBootstrap(
          testUrl:
              Uri.parse('file:///Users/me/some_package/test/some_test.dart'),
          host: InternetAddress('127.0.0.1', type: InternetAddressType.IPv4),
          packageConfigUri: Uri.parse(
              'file:///Users/me/some_package/.dart_tool/package_config.json'),
        );
        // IMPORTANT: DO NOT RENAME, REMOVE, OR MODIFY THE
        // 'const packageConfigLocation' VARIABLE.
        // Dash tooling like Dart DevTools performs an evaluation on this variable
        // at runtime to get the package config location for Flutter test targets.
        expect(
          contents,
          contains(
            "const packageConfigLocation = 'file:///Users/me/some_package/.dart_tool/package_config.json';",
          ),
        );
      });
    });
  });
}
