import 'dart:io';

const appPackages = <String, String>{
  'sarisupply_pos': 'pos',
  'sarisupply_admin': 'admin',
  'sarisupply_driver': 'driver',
};

const ignoredPathFragments = <String>[
  '/.dart_tool/',
  '/build/',
  '/node_modules/',
  '/.git/',
];

void main() {
  final root = Directory.current.absolute;
  final violations = <String>[];

  for (final topLevel in ['apps', 'packages']) {
    final directory = Directory('${root.path}/$topLevel');
    if (!directory.existsSync()) {
      continue;
    }

    for (final entity
        in directory.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final normalizedPath = _slash(entity.absolute.path);
      if (_isIgnored(normalizedPath)) {
        continue;
      }

      if (normalizedPath.endsWith('.dart')) {
        _checkDartFile(root, entity, normalizedPath, violations);
      }

      if (normalizedPath.endsWith('/pubspec.yaml')) {
        _checkPubspec(root, entity, normalizedPath, violations);
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Architecture boundary check FAILED:');
    for (final violation in violations) {
      stderr.writeln(' - $violation');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Architecture boundary check PASS');
}

void _checkDartFile(
  Directory root,
  File file,
  String sourcePath,
  List<String> violations,
) {
  final sourceApp = _appForPath(root, sourcePath);
  final importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  final lines = file.readAsLinesSync();
  for (var index = 0; index < lines.length; index++) {
    final match = importPattern.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }

    final uri = match.group(1)!;
    final packageTarget = _targetAppFromPackageUri(uri);

    if (packageTarget != null && packageTarget != sourceApp) {
      violations.add(
        '${_relative(root, sourcePath)}:${index + 1} imports '
        'application "$packageTarget" from outside that application',
      );
      continue;
    }

    if (uri.startsWith('package:') || uri.startsWith('dart:')) {
      continue;
    }

    final resolved = _normalizePath(
      '${_slash(file.parent.absolute.path)}/$uri',
    );
    final relativeTarget = _appForPath(root, resolved);

    if (relativeTarget != null && relativeTarget != sourceApp) {
      violations.add(
        '${_relative(root, sourcePath)}:${index + 1} uses a relative '
        'import/export into application "$relativeTarget"',
      );
    }
  }
}

void _checkPubspec(
  Directory root,
  File file,
  String sourcePath,
  List<String> violations,
) {
  final sourceApp = _appForPath(root, sourcePath);
  final sourceIsSharedPackage =
      _relative(root, sourcePath).startsWith('packages/');

  final lines = file.readAsLinesSync();
  final pathPattern = RegExp(r'^\s*path:\s*(.+?)\s*$');

  for (var index = 0; index < lines.length; index++) {
    final match = pathPattern.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }

    var dependencyPath = match.group(1)!.trim();
    if ((dependencyPath.startsWith('"') && dependencyPath.endsWith('"')) ||
        (dependencyPath.startsWith("'") && dependencyPath.endsWith("'"))) {
      dependencyPath = dependencyPath.substring(1, dependencyPath.length - 1);
    }

    final resolved = _normalizePath(
      '${_slash(file.parent.absolute.path)}/$dependencyPath',
    );
    final targetApp = _appForPath(root, resolved);

    if (targetApp == null) {
      continue;
    }

    if (sourceIsSharedPackage || targetApp != sourceApp) {
      violations.add(
        '${_relative(root, sourcePath)}:${index + 1} declares a path '
        'dependency on application "$targetApp"',
      );
    }
  }
}

bool _isIgnored(String path) =>
    ignoredPathFragments.any((fragment) => path.contains(fragment));

String? _targetAppFromPackageUri(String uri) {
  if (!uri.startsWith('package:')) {
    return null;
  }

  final packageName = uri.substring('package:'.length).split('/').first;
  return appPackages[packageName];
}

String? _appForPath(Directory root, String path) {
  final relative = _relative(root, path);
  final parts = relative.split('/');

  if (parts.length >= 2 && parts.first == 'apps') {
    final app = parts[1];
    if (app == 'pos' || app == 'admin' || app == 'driver') {
      return app;
    }
  }

  return null;
}

String _relative(Directory root, String path) {
  final rootPath = _slash(root.path);
  final normalized = _slash(path);
  if (normalized == rootPath) {
    return '.';
  }
  if (normalized.startsWith('$rootPath/')) {
    return normalized.substring(rootPath.length + 1);
  }
  return normalized;
}

String _normalizePath(String input) {
  final normalizedInput = _slash(input);
  final prefix = normalizedInput.startsWith('/') ? '/' : '';
  final parts = <String>[];

  for (final part in normalizedInput.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
      continue;
    }
    parts.add(part);
  }

  return '$prefix${parts.join('/')}';
}

String _slash(String value) => value.replaceAll('\\', '/');
