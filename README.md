# genkit_llamadart

`genkit_llamadart` is a path-based Genkit Dart plugin for running local models
through `llamadart` without an OpenAI-compatible HTTP server.

## What it supports

- local `modelPath` configuration
- lazy model loading
- queued per-model execution
- chat generation with streaming
- Genkit tool request emission
- constrained JSON output
- text embeddings

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

void main() async {
  final plugin = llamaDart(
    models: const [
      LlamaModelDefinition(
        name: 'local-chat',
        modelPath: '/models/qwen3.gguf',
        modelParams: ModelParams(contextSize: 8192),
      ),
    ],
  );

  final ai = Genkit(plugins: [plugin]);

  final response = await ai.generate(
    model: llamaDart.model('local-chat'),
    prompt: 'Say hello in one sentence.',
  );

  print(response.text);

  await plugin.dispose();
}
```

## Agent Example

There is also a multi-turn tool-calling example in
`example/genkit_llamadart_agent_example.dart`.

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_agent_example.dart
```

The agent example keeps full conversation history with `response.messages` and
lets Genkit drive the tool loop across turns.

## Current limits

- embeddings are text-only
- constrained structured output with tools is not supported yet
- model paths are local filesystem paths for now
