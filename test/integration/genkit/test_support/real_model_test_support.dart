import 'dart:io';

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
);

const HuggingFaceModelSpec integrationEmbedModel = HuggingFaceModelSpec(
  repository: 'second-state/jina-embeddings-v2-small-en-GGUF',
  fileName: 'jina-embeddings-v2-small-en-Q2_K.gguf',
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
  });

  final String repository;
  final String fileName;

  String get downloadUrl {
    return 'https://huggingface.co/$repository/resolve/main/$fileName?download=true';
  }

  String get cacheFileName {
    return '${repository.replaceAll('/', '__')}__$fileName';
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
  if (await targetFile.exists()) {
    return targetFile.path;
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
    await sink.flush();
    await sink.close();
    await partialFile.rename(targetFile.path);
    return targetFile.path;
  } finally {
    client.close(force: true);
  }
}

String? _readPathEnv(String envName) {
  final value = Platform.environment[envName];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
