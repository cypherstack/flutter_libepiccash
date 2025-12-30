import 'dart:io';

import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'builder.dart';
import 'crate_hash.dart';
import 'options.dart';
import 'precompile_binaries.dart';
import 'rustup.dart';
import 'target.dart';

class Artifact {
  /// File system location of the artifact.
  final String path;

  /// Actual file name that the artifact should have in destination folder.
  final String finalFileName;

  AritifactType get type {
    if (finalFileName.endsWith('.dll') ||
        finalFileName.endsWith('.dll.lib') ||
        finalFileName.endsWith('.pdb') ||
        finalFileName.endsWith('.so') ||
        finalFileName.endsWith('.dylib')) {
      return AritifactType.dylib;
    } else if (finalFileName.endsWith('.lib') || finalFileName.endsWith('.a')) {
      return AritifactType.staticlib;
    } else {
      throw Exception('Unknown artifact type for $finalFileName');
    }
  }

  Artifact({
    required this.path,
    required this.finalFileName,
  });
}

final _log = Logger('artifacts_provider');

class ArtifactProvider {
  ArtifactProvider({
    required this.environment,
    required this.userOptions,
  });

  final BuildEnvironment environment;
  final CargokitUserOptions userOptions;

  Future<Map<Target, List<Artifact>>> getArtifacts(List<Target> targets) async {
    final result = <Target, List<Artifact>>{};

    // 1. Try precompiled binaries (remote or local from directory.txt)
    final precompiled = userOptions.useLocalPrecompiledBinaries
        ? await _getLocalPrecompiledArtifacts(targets)
        : await _getPrecompiledArtifacts(targets);
    result.addAll(precompiled);

    // 2. Try local build cache
    final pendingAfterPrecompiled = targets.where((t) => !result.containsKey(t));
    if (pendingAfterPrecompiled.isNotEmpty) {
      final cached = await _getCachedLocalBuilds(pendingAfterPrecompiled.toList());
      result.addAll(cached);
    }

    // 3. Build from source for any remaining targets
    final pendingTargets = targets.where((t) => !result.containsKey(t));

    if (pendingTargets.isEmpty) {
      return result;
    }

    final rustup = Rustup();
    for (final target in pendingTargets) {
      final builder = RustBuilder(target: target, environment: environment);
      builder.prepare(rustup);
      _log.info('Building ${environment.crateInfo.packageName} for $target');
      final targetDir = await builder.build();

      // Collect artifacts (accept both static and dynamic libraries)
      final artifactNames = <String>{
        ...getArtifactNames(
          target: target,
          libraryName: environment.crateInfo.packageName,
          aritifactType: AritifactType.dylib,
          remote: false,
        ),
        ...getArtifactNames(
          target: target,
          libraryName: environment.crateInfo.packageName,
          aritifactType: AritifactType.staticlib,
          remote: false,
        )
      };

      final artifacts = artifactNames
          .map((artifactName) => Artifact(
                path: path.join(targetDir, artifactName),
                finalFileName: artifactName,
              ))
          .where((element) => File(element.path).existsSync())
          .toList();

      result[target] = artifacts;

      // 4. Save to cache for future builds
      await _saveToCacheLocalBuilds(
        target,
        targetDir,
        artifacts.map((a) => a.finalFileName).toList(),
      );
    }

    return result;
  }

  Future<Map<Target, List<Artifact>>> _getPrecompiledArtifacts(
      List<Target> targets) async {
    if (userOptions.usePrecompiledBinaries == false) {
      _log.info('Precompiled binaries are disabled');
      return {};
    }
    if (environment.crateOptions.precompiledBinaries == null) {
      _log.fine('Precompiled binaries not enabled for this crate');
      return {};
    }

    final start = Stopwatch()..start();
    final crateHash = CrateHash.compute(environment.manifestDir,
        tempStorage: environment.targetTempDir);
    _log.fine(
        'Computed crate hash $crateHash in ${start.elapsedMilliseconds}ms');

    final downloadedArtifactsDir =
        path.join(environment.targetTempDir, 'precompiled', crateHash);
    Directory(downloadedArtifactsDir).createSync(recursive: true);

    final res = <Target, List<Artifact>>{};

    for (final target in targets) {
      final requiredArtifacts = getArtifactNames(
        target: target,
        libraryName: environment.crateInfo.packageName,
        remote: true,
      );
      final artifactsForTarget = <Artifact>[];

      for (final artifact in requiredArtifacts) {
        final fileName = PrecompileBinaries.fileName(target, artifact);
        final downloadedPath = path.join(downloadedArtifactsDir, fileName);
        if (!File(downloadedPath).existsSync()) {
          final signatureFileName =
              PrecompileBinaries.signatureFileName(target, artifact);
          await _tryDownloadArtifacts(
            crateHash: crateHash,
            fileName: fileName,
            signatureFileName: signatureFileName,
            finalPath: downloadedPath,
          );
        }
        if (File(downloadedPath).existsSync()) {
          artifactsForTarget.add(Artifact(
            path: downloadedPath,
            finalFileName: artifact,
          ));
        } else {
          break;
        }
      }

      // Only provide complete set of artifacts.
      if (artifactsForTarget.length == requiredArtifacts.length) {
        _log.fine('Found precompiled artifacts for $target');
        res[target] = artifactsForTarget;
      }
    }

    return res;
  }

  static Future<Response> _get(Uri url, {Map<String, String>? headers}) async {
    int attempt = 0;
    const maxAttempts = 10;
    while (true) {
      try {
        return await get(url, headers: headers);
      } on SocketException catch (e) {
        // Try to detect reset by peer error and retry.
        if (attempt++ < maxAttempts &&
            (e.osError?.errorCode == 54 || e.osError?.errorCode == 10054)) {
          _log.severe(
              'Failed to download $url: $e, attempt $attempt of $maxAttempts, will retry...');
          await Future.delayed(Duration(seconds: 1));
          continue;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<Map<Target, List<Artifact>>> _getLocalPrecompiledArtifacts(
    List<Target> targets,
  ) async {
    if (userOptions.usePrecompiledBinaries == false) {
      _log.info('Precompiled binaries are disabled');
      return {};
    }
    if (environment.crateOptions.precompiledBinaries == null) {
      _log.fine('Precompiled binaries not enabled for this crate');
      return {};
    }

    final start = Stopwatch()..start();
    final crateHash = CrateHash.compute(
      environment.manifestDir,
      tempStorage: environment.targetTempDir,
    );
    _log.fine(
        'Computed crate hash $crateHash in ${start.elapsedMilliseconds}ms');

    final downloadedArtifactsDir = path.join(
      environment.targetTempDir,
      'precompiled',
      crateHash,
    );
    Directory(downloadedArtifactsDir).createSync(recursive: true);

    final res = <Target, List<Artifact>>{};

    for (final target in targets) {
      final requiredArtifacts = getArtifactNames(
        target: target,
        libraryName: environment.crateInfo.packageName,
        remote: true,
      );
      final artifactsForTarget = <Artifact>[];

      for (final artifact in requiredArtifacts) {
        final fileName =
            '$target/$artifact'; // PrecompileBinaries.fileName(target, artifact);
        final downloadedPath = path.join(downloadedArtifactsDir, fileName);

        if (!File(downloadedPath).existsSync()) {
          String filePath = "${Directory.current.path}/directory.txt";
          File file = File(filePath);

          if (file.existsSync()) {
            String firstLine = file.readAsLinesSync().first;

            await _tryLocalDownloadArtifacts(
              fileName: fileName,
              finalPath: downloadedPath,
              sdkDirectory: firstLine,
            );
          }
        }
        if (File(downloadedPath).existsSync()) {
          artifactsForTarget.add(Artifact(
            path: downloadedPath,
            finalFileName: artifact,
          ));
        } else {
          break;
        }
      }

      // Only provide complete set of artifacts.
      if (artifactsForTarget.length == requiredArtifacts.length) {
        _log.fine('Found precompiled artifacts for $target');
        res[target] = artifactsForTarget;
      }
    }

    return res;
  }

  /// Checks for artifacts cached from previous local builds.
  /// Unlike precompiled binaries, this doesn't require cargokit.yaml configuration.
  Future<Map<Target, List<Artifact>>> _getCachedLocalBuilds(
    List<Target> targets,
  ) async {
    if (!userOptions.cacheLocalBuilds) {
      return {};
    }

    final start = Stopwatch()..start();
    final crateHash = CrateHash.compute(
      environment.manifestDir,
      tempStorage: environment.targetTempDir,
    );
    _log.fine('Computed crate hash $crateHash in ${start.elapsedMilliseconds}ms');

    // Include build configuration in cache path to avoid reusing
    // release artifacts in debug builds or vice versa
    final configuration = environment.configuration.name;
    final cachedArtifactsDir = path.join(
      environment.targetTempDir,
      'precompiled',
      crateHash,
      configuration,
    );

    final res = <Target, List<Artifact>>{};

    for (final target in targets) {
      final requiredArtifacts = getArtifactNames(
        target: target,
        libraryName: environment.crateInfo.packageName,
        remote: false, // Use local naming (includes .pdb for Windows)
      );
      final artifactsForTarget = <Artifact>[];

      final targetCacheDir = path.join(cachedArtifactsDir, target.rust);

      for (final artifact in requiredArtifacts) {
        final cachedPath = path.join(targetCacheDir, artifact);
        if (File(cachedPath).existsSync()) {
          artifactsForTarget.add(Artifact(
            path: cachedPath,
            finalFileName: artifact,
          ));
        } else {
          break; // Missing artifact, can't use cache for this target
        }
      }

      // Only use cache if all required artifacts are present
      if (artifactsForTarget.length == requiredArtifacts.length) {
        _log.info('Using cached build artifacts for $target ($configuration)');
        res[target] = artifactsForTarget;
      }
    }

    return res;
  }

  /// Saves build artifacts to the local cache for future reuse.
  Future<void> _saveToCacheLocalBuilds(
    Target target,
    String buildDir,
    List<String> artifactNames,
  ) async {
    if (!userOptions.cacheLocalBuilds) {
      return;
    }

    final crateHash = CrateHash.compute(
      environment.manifestDir,
      tempStorage: environment.targetTempDir,
    );

    final configuration = environment.configuration.name;
    final targetCacheDir = path.join(
      environment.targetTempDir,
      'precompiled',
      crateHash,
      configuration,
      target.rust,
    );

    Directory(targetCacheDir).createSync(recursive: true);

    for (final artifactName in artifactNames) {
      final sourcePath = path.join(buildDir, artifactName);
      final destPath = path.join(targetCacheDir, artifactName);

      if (File(sourcePath).existsSync()) {
        File(sourcePath).copySync(destPath);
        _log.fine('Cached $artifactName for $target ($configuration)');
      }
    }

    _log.info('Saved build artifacts to cache for $target ($configuration)');
  }

  Future<void> _tryDownloadArtifacts({
    required String crateHash,
    required String fileName,
    required String signatureFileName,
    required String finalPath,
  }) async {
    final precompiledBinaries = environment.crateOptions.precompiledBinaries!;
    final prefix = precompiledBinaries.uriPrefix;
    final url = Uri.parse('$prefix$crateHash/$fileName');
    final signatureUrl = Uri.parse('$prefix$crateHash/$signatureFileName');
    _log.fine('Downloading signature from $signatureUrl');
    final signature = await _get(signatureUrl);
    if (signature.statusCode == 404) {
      _log.warning(
          'Precompiled binaries not available for crate hash $crateHash ($fileName)');
      return;
    }
    if (signature.statusCode != 200) {
      _log.severe(
          'Failed to download signature $signatureUrl: status ${signature.statusCode}');
      return;
    }
    _log.fine('Downloading binary from $url');
    final res = await _get(url);
    if (res.statusCode != 200) {
      _log.severe('Failed to download binary $url: status ${res.statusCode}');
      return;
    }
    if (verify(
        precompiledBinaries.publicKey, res.bodyBytes, signature.bodyBytes)) {
      File(finalPath).writeAsBytesSync(res.bodyBytes);
    } else {
      _log.shout('Signature verification failed! Ignoring binary.');
    }
  }

  Future<void> _tryLocalDownloadArtifacts({
    required String fileName,
    required String finalPath,
    required String sdkDirectory,
  }) async {
    final sdkPath = '$sdkDirectory/binary/$fileName';
    final binaryFile = File(sdkPath);
    if (!binaryFile.existsSync()) {
      throw Exception('Missing artifact: ${binaryFile.path}');
    }
    File destinationFile = File(finalPath);
    destinationFile.parent.createSync(recursive: true);
    binaryFile.copySync(finalPath);
  }
}

enum AritifactType {
  staticlib,
  dylib,
}

AritifactType artifactTypeForTarget(Target target) {
  if (target.darwinPlatform != null) {
    return AritifactType.staticlib;
  } else {
    return AritifactType.dylib;
  }
}

List<String> getArtifactNames({
  required Target target,
  required String libraryName,
  required bool remote,
  AritifactType? aritifactType,
}) {
  aritifactType ??= artifactTypeForTarget(target);
  if (target.darwinArch != null) {
    if (aritifactType == AritifactType.staticlib) {
      return ['lib$libraryName.a'];
    } else {
      return ['lib$libraryName.dylib'];
    }
  } else if (target.rust.contains('-windows-')) {
    if (aritifactType == AritifactType.staticlib) {
      return ['$libraryName.lib'];
    } else {
      return [
        '$libraryName.dll',
        '$libraryName.dll.lib',
        if (!remote) '$libraryName.pdb'
      ];
    }
  } else if (target.rust.contains('-linux-')) {
    if (aritifactType == AritifactType.staticlib) {
      return ['lib$libraryName.a'];
    } else {
      return ['lib$libraryName.so'];
    }
  } else {
    throw Exception("Unsupported target: ${target.rust}");
  }
}
