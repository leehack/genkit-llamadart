import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

const String integrationModelPathEnv = 'LLAMADART_INTEGRATION_MODEL_PATH';
const String integrationEmbedModelPathEnv =
    'LLAMADART_INTEGRATION_EMBED_MODEL_PATH';
const String autoDownloadTestModelsEnv = 'LLAMADART_AUTO_DOWNLOAD_TEST_MODELS';
const String testModelDirectoryEnv = 'LLAMADART_TEST_MODEL_DIR';
const String huggingFaceTokenEnv = 'HUGGING_FACE_HUB_TOKEN';

const HuggingFaceModelSpec integrationChatModel = HuggingFaceModelSpec(
  repository: 'unsloth/SmolLM2-135M-Instruct-GGUF',
  fileName: 'SmolLM2-135M-Instruct-Q2_K.gguf',
  revision: '9e6855bc4be717fca1ef21360a1db4b29d5c559a',
  expectedSha256:
      'c53fe6626c7165ebfd8de5db22edc3f719b813da001e662bc5cb453f2540a076',
  expectedSizeBytes: 88201792,
);

const HuggingFaceModelSpec integrationEmbedModel = HuggingFaceModelSpec(
  repository: 'second-state/jina-embeddings-v2-small-en-GGUF',
  fileName: 'jina-embeddings-v2-small-en-Q2_K.gguf',
  revision: 'ce1d7885a6c52267f47f4793bc312ae5f71e8aca',
  expectedSha256:
      '3e8a47e196fcd604106c2b7f40c5d3fcc4010703a1b732c04b3d166ca1f1e90e',
  expectedSizeBytes: 19680224,
);

Future<String> requireIntegrationModelPath() {
  return _resolveModelPath(
    envName: integrationModelPathEnv,
    spec: integrationChatModel,
  );
}

Future<String> requireIntegrationEmbedModelPath() {
  return _resolveModelPath(
    envName: integrationEmbedModelPathEnv,
    spec: integrationEmbedModel,
  );
}

void expectFiniteEmbedding(Embedding embedding) {
  expect(embedding.embedding, isNotEmpty);
  expect(
    embedding.embedding.every((value) => value.isFinite),
    isTrue,
    reason: 'Expected all embedding values to be finite.',
  );
}

({Genkit ai, LlamaDartPlugin plugin}) createIntegrationGenkit({
  required String modelName,
  required String modelPath,
  bool supportsEmbeddings = true,
}) {
  final plugin = llamaDart(
    models: <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: modelName,
        modelPath: modelPath,
        supportsEmbeddings: supportsEmbeddings,
      ),
    ],
  );

  return (ai: Genkit(plugins: <LlamaDartPlugin>[plugin]), plugin: plugin);
}

class HuggingFaceModelSpec {
  const HuggingFaceModelSpec({
    required this.repository,
    required this.fileName,
    required this.revision,
    required this.expectedSha256,
    required this.expectedSizeBytes,
  });

  final String repository;
  final String fileName;
  final String revision;
  final String expectedSha256;
  final int expectedSizeBytes;

  String get downloadUrl {
    return 'https://huggingface.co/$repository/resolve/$revision/$fileName?download=true';
  }

  String get cacheFileName {
    return '${repository.replaceAll('/', '__')}__${revision}__$fileName';
  }
}

Future<String> _resolveModelPath({
  required String envName,
  required HuggingFaceModelSpec spec,
}) async {
  final envPath = _readPathEnv(envName);
  if (envPath != null) {
    return envPath;
  }

  if (Platform.environment[autoDownloadTestModelsEnv] != '1') {
    markTestSkipped(
      'Set $envName or enable $autoDownloadTestModelsEnv=1 to download a tiny test model from Hugging Face.',
    );
  }

  final modelDir = Directory(
    Platform.environment[testModelDirectoryEnv] ??
        '${Directory.current.path}/.dart_tool/llamadart_test_models',
  );
  await modelDir.create(recursive: true);

  final targetFile = File('${modelDir.path}/${spec.cacheFileName}');
  final cacheLock = File('${targetFile.path}.lock');
  await _acquireCacheLock(cacheLock);
  try {
    if (await targetFile.exists()) {
      if (await _hasExpectedModelContents(targetFile, spec)) {
        return targetFile.path;
      }
      stdout.writeln(
        'Discarding cached ${spec.fileName}: size or SHA-256 did not match.',
      );
      await targetFile.delete();
    }

    final partialFile = File('${targetFile.path}.part');
    if (await partialFile.exists()) {
      await partialFile.delete();
    }

    stdout.writeln('Downloading ${spec.fileName} from ${spec.repository}...');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(spec.downloadUrl));
      final token = Platform.environment[huggingFaceTokenEnv];
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download ${spec.downloadUrl} (status ${response.statusCode}).',
          uri: Uri.parse(spec.downloadUrl),
        );
      }

      final sink = partialFile.openWrite();
      await response.pipe(sink);
      if (!await _hasExpectedModelContents(partialFile, spec)) {
        await partialFile.delete();
        throw StateError(
          'Downloaded ${spec.fileName} did not match its pinned size and SHA-256.',
        );
      }
      await partialFile.rename(targetFile.path);
      return targetFile.path;
    } finally {
      client.close(force: true);
    }
  } finally {
    await cacheLock.delete();
  }
}

Future<void> _acquireCacheLock(File lockFile) async {
  final deadline = DateTime.now().add(const Duration(minutes: 15));
  var missingLockFailures = 0;
  while (true) {
    try {
      await lockFile.create(exclusive: true);
      return;
    } on FileSystemException {
      if (!await lockFile.exists()) {
        missingLockFailures += 1;
        if (missingLockFailures >= 3) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      missingLockFailures = 0;

      try {
        final age = DateTime.now().difference(await lockFile.lastModified());
        if (age > const Duration(minutes: 30)) {
          await lockFile.delete();
          continue;
        }
      } on FileSystemException {
        // The owner may have replaced or removed the lock while it was checked.
      }

      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'Timed out waiting for model cache lock ${lockFile.path}.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

Future<bool> _hasExpectedModelContents(
  File file,
  HuggingFaceModelSpec spec,
) async {
  if (await file.length() != spec.expectedSizeBytes) {
    return false;
  }
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString() == spec.expectedSha256;
}

String? _readPathEnv(String envName) {
  final value = Platform.environment[envName];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
