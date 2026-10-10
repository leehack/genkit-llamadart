import 'package:genkit/plugin.dart';
import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';
import '../../core/runtime/engine_registry.dart';
import '../../core/runtime/llama_runtime.dart';
import 'action_support.dart';
import 'actions/embedder_action.dart';
import 'actions/model_action.dart';

/// `GenkitPlugin` implementation backed by local `llamadart` runtimes.
class LlamaDartPlugin extends GenkitPlugin {
  /// Registers a model action and, when enabled, an embedder per definition.
  ///
  /// [observers] are copied and attached to default engines. Callbacks inherit
  /// the request zone and observer errors do not fail inference. When supplying
  /// [runtimeFactory], the factory owns observer installation instead.
  ///
  /// Custom runtimes supplied through [runtimeFactory] must implement
  /// [LlamaRuntimeCapabilityProvider] to confirm advanced request support.
  /// Without a provider, only single-turn text requests are accepted.
  /// Model names must be unique within the plugin instance; duplicate names
  /// throw [ArgumentError]. Registration and listing do not load model files.
  LlamaDartPlugin({
    required List<LlamaModelDefinition> models,
    LlamaDartRuntimeFactory? runtimeFactory,
    Iterable<llama.LlamaEngineObserver> observers = const [],
  }) : _models = List<LlamaModelDefinition>.unmodifiable(models),
       _registry = EngineRegistry(
         models: models,
         runtimeFactory: runtimeFactory,
         observers: observers,
       ) {
    final names = <String>{};
    for (final model in models) {
      if (!names.add(model.name)) {
        throw ArgumentError.value(
          model.name,
          'models',
          'Duplicate llamadart model names are not allowed.',
        );
      }
    }
  }

  final List<LlamaModelDefinition> _models;
  final EngineRegistry _registry;
  List<Action>? _actions;
  List<ActionMetadata>? _listedActions;

  /// Plugin name used when registering actions in Genkit.
  @override
  String get name => llamaDartPluginName;

  /// Disposes all runtimes cached by this plugin instance.
  ///
  /// Disposal is terminal. Create a new plugin instance instead of submitting
  /// model or embedding requests after this future has been requested.
  /// Multiple runtime disposal failures are retained in a `ParallelWaitError`.
  Future<void> dispose() {
    return _registry.dispose();
  }

  /// Requests cancellation of [modelName]'s active generation.
  ///
  /// Bypasses the operation queue, so it stops a running generation instead of
  /// waiting behind it. No-op when nothing is generating for that model.
  /// Throws [StateError] for a name not registered on this plugin. Separately
  /// queued requests can still run afterward.
  void cancelActiveGeneration(String modelName) {
    _registry.cancelActiveGeneration(modelName);
  }

  /// Cancels every in-flight generation across this plugin's runtimes.
  void cancelActiveGenerations() {
    _registry.cancelActiveGenerations();
  }

  /// Registers actions without loading models or probing capabilities.
  @override
  Future<List<Action>> init() async {
    if (_actions != null) {
      return _actions!;
    }

    _actions = _models
        .expand((definition) {
          return <Action>[
            buildModelAction(definition: definition, registry: _registry),
            if (definition.supportsEmbeddings)
              buildEmbedderAction(definition: definition, registry: _registry),
          ];
        })
        .toList(growable: false);

    return _actions!;
  }

  /// Lists actions with the most recently checked runtime capabilities.
  ///
  /// Does not load models. Unknown support is false in `model.supports`; inspect
  /// `llamadartCapabilities.state` to distinguish unloaded or unverified state
  /// from a verified snapshot. Cached metadata updates after each request probe.
  @override
  Future<List<ActionMetadata>> list() async {
    // Genkit caches plugin listings; keep their metadata synchronized too.
    return _listedActions ??= _models
        .expand((definition) {
          final actionName = actionNameFor(definition.name);
          Map<String, dynamic> metadataFor({bool generation = true}) {
            final metadata = actionMetadataFor(
              definition,
              modelInfo: modelInfoFor(definition, generation: generation),
            );
            trackCapabilityMetadata(metadata, definition, _registry);
            return metadata;
          }

          return <ActionMetadata>[
            ActionMetadata(
              name: actionName,
              description: definition.name,
              actionType: ActionType.model,
              metadata: metadataFor(),
            ),
            if (definition.supportsEmbeddings)
              ActionMetadata(
                name: actionName,
                description: definition.name,
                actionType: ActionType.embedder,
                metadata: metadataFor(generation: false),
              ),
          ];
        })
        .toList(growable: false);
  }
}
