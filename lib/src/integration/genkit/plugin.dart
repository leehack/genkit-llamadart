import 'package:genkit/plugin.dart';

import '../../api/model_definition.dart';
import '../../core/runtime/engine_registry.dart';
import '../../core/runtime/llama_runtime.dart';
import 'action_support.dart';
import 'actions/embedder_action.dart';
import 'actions/model_action.dart';

/// `GenkitPlugin` implementation backed by local `llamadart` runtimes.
class LlamaDartPlugin extends GenkitPlugin {
  /// Creates a plugin that registers one model and embedder per definition.
  ///
  /// Model names must be unique within the plugin instance.
  LlamaDartPlugin({
    required List<LlamaModelDefinition> models,
    LlamaRuntimeFactory? runtimeFactory,
  }) : _models = List<LlamaModelDefinition>.unmodifiable(models),
       _registry = EngineRegistry(
         models: models,
         runtimeFactory: runtimeFactory,
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

  /// Plugin name used when registering actions in Genkit.
  @override
  String get name => llamaDartPluginName;

  /// Disposes all runtimes cached by this plugin instance.
  ///
  /// Disposal is terminal. Create a new plugin instance instead of submitting
  /// model or embedding requests after this future has been requested.
  Future<void> dispose() {
    return _registry.dispose();
  }

  /// Cancels the in-flight generation for [modelName] on this plugin's runtime.
  /// Bypasses the operation queue, so it stops a running generation instead of
  /// waiting behind it. No-op when nothing is generating for that model.
  void cancelActiveGeneration(String modelName) {
    _registry.cancelActiveGeneration(modelName);
  }

  /// Cancels every in-flight generation across this plugin's runtimes.
  void cancelActiveGenerations() {
    _registry.cancelActiveGenerations();
  }

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

  @override
  Future<List<ActionMetadata>> list() async {
    return _models
        .expand((definition) {
          final actionName = actionNameFor(definition.name);
          final modelInfo = modelInfoFor(definition);
          return <ActionMetadata>[
            ActionMetadata(
              name: actionName,
              description: definition.name,
              actionType: 'model',
              metadata: actionMetadataFor(definition, modelInfo: modelInfo),
            ),
            if (definition.supportsEmbeddings)
              ActionMetadata(
                name: actionName,
                description: definition.name,
                actionType: 'embedder',
                metadata: actionMetadataFor(definition, modelInfo: modelInfo),
              ),
          ];
        })
        .toList(growable: false);
  }
}
