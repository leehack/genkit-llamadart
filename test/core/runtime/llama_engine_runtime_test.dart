import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_llamadart/src/core/runtime/llama_engine_runtime.dart';
import 'package:llamadart/llamadart.dart' as llama;
import 'package:test/test.dart';

void main() {
  test('loads a typed model, projector and parameters exactly once', () async {
    final engine = _RecordingEngine();
    final runtime = LlamaEngineRuntime(engine: engine);
    addTearDown(runtime.dispose);
    const params = ModelParams(device: ComputeDevice.cpu, contextSize: 1024);
    const definition = LlamaModelDefinition(
      name: 'vision',
      modelPath: '/models/chat.gguf',
      mmprojPath: '/models/projector.gguf',
      modelParams: params,
    );
    await runtime.initialize(definition);
    await runtime.initialize(definition);
    expect(engine.loads, hasLength(1));
    expect(engine.loads.single.source.path, definition.modelPath);
    expect(engine.loads.single.projector!.path, definition.mmprojPath);
    expect(engine.params, same(params));
  });

  test('capability provider delegates the active engine snapshot', () async {
    final engine = _RecordingEngine();
    final runtime = LlamaEngineRuntime(engine: engine);
    addTearDown(runtime.dispose);
    expect(await runtime.capabilities, same(engine.snapshot));
  });

  test('failed loading can retry without a projector', () async {
    final error = llama.LlamaModelException('load failed');
    final engine = _RecordingEngine()..loadError = error;
    final runtime = LlamaEngineRuntime(engine: engine);
    addTearDown(runtime.dispose);
    const definition = LlamaModelDefinition(
      name: 'chat',
      modelPath: '/models/chat.gguf',
    );
    await expectLater(runtime.initialize(definition), throwsA(same(error)));
    engine.loadError = null;
    await runtime.initialize(definition);
    expect(engine.loads, hasLength(2));
    expect(engine.loads.last.projector, isNull);
  });

  for (final structured in [false, true]) {
    test('preserves language precedence for structured=$structured', () async {
      final engine = _RecordingEngine();
      final runtime = LlamaEngineRuntime(engine: engine);
      addTearDown(runtime.dispose);
      final kwargs = <String, dynamic>{
        'source_lang_code': 'fr',
        'target_lang_code': 'de',
        'custom': true,
      };
      Future<void> run({String? source, String? target}) async {
        if (structured) {
          await runtime.chatTemplate(
            [],
            sourceLangCode: source,
            targetLangCode: target,
            chatTemplateKwargs: kwargs,
          );
        } else {
          await runtime
              .create(
                [],
                sourceLangCode: source,
                targetLangCode: target,
                chatTemplateKwargs: kwargs,
              )
              .drain<void>();
        }
      }

      await run(source: 'en', target: 'ko');
      expect(engine.kwargs, {
        'source_lang_code': 'en',
        'target_lang_code': 'ko',
        'custom': true,
      });
      expect(kwargs['source_lang_code'], 'fr');
      expect(kwargs['target_lang_code'], 'de');
      await run(source: '', target: '');
      expect(engine.kwargs, same(kwargs));
      await run();
      expect(engine.kwargs, same(kwargs));
    });
  }
}

class _RecordingEngine implements llama.LlamaEngine {
  final snapshot = const llama.LlamaEngineCapabilities(
    isSupported: true,
    supportsToolCalling: true,
  );
  @override
  Future<llama.LlamaEngineCapabilities> get capabilities async => snapshot;

  final loads = <llama.LlamaModel>[];
  llama.ModelParams? params;
  Map<String, dynamic>? kwargs;
  Object? loadError;

  @override
  Future<void> setModel(
    llama.LlamaModel model, {
    llama.ModelParams params = const llama.ModelParams(),
    llama.ModelLoadOptions download = llama.ModelLoadOptions.defaults,
    llama.ModelDownloadProgressCallback? onProgress,
  }) async {
    loads.add(model);
    this.params = params;
    if (loadError != null) throw loadError!;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #create ||
        invocation.memberName == #chatTemplate) {
      expect(invocation.namedArguments[#sourceLangCode], isNull);
      expect(invocation.namedArguments[#targetLangCode], isNull);
      kwargs =
          invocation.namedArguments[#chatTemplateKwargs]
              as Map<String, dynamic>?;
      if (invocation.memberName == #create) {
        return const Stream<llama.LlamaCompletionChunk>.empty();
      }
      return Future.value(const llama.LlamaChatTemplateResult(prompt: ''));
    }
    throw UnsupportedError('Unexpected engine call: ${invocation.memberName}');
  }
}
