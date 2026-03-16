import 'package:genkit/plugin.dart';

import 'action_support.dart';
import 'embedder_action.dart';
import 'engine_registry.dart';
import 'model_action.dart';
import 'model_definition.dart';
import 'options.dart';
import 'runtime.dart';

const LlamaDartPluginHandle llamaDart = LlamaDartPluginHandle();

class LlamaDartPluginHandle {
  const LlamaDartPluginHandle();

  LlamaDartPlugin call({required List<LlamaModelDefinition> models}) {
    return LlamaDartPlugin(models: models);
  }

  ModelRef<LlamaDartGenerationConfig> model(String name) {
    return modelRef<LlamaDartGenerationConfig>(actionNameFor(name));
  }

  EmbedderRef<LlamaDartEmbedConfig> embedder(String name) {
    return embedderRef<LlamaDartEmbedConfig>(actionNameFor(name));
  }
}

class LlamaDartPlugin extends GenkitPlugin {
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

  @override
  String get name => llamaDartPluginName;

  Future<void> dispose() {
    return _registry.dispose();
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
          return <ActionMetadata>[
            ActionMetadata(
              name: actionName,
              description: definition.name,
              actionType: 'model',
              metadata: actionMetadataFor(definition),
            ),
            ActionMetadata(
              name: actionName,
              description: definition.name,
              actionType: 'embedder',
              metadata: actionMetadataFor(definition),
            ),
          ];
        })
        .toList(growable: false);
  }
}
