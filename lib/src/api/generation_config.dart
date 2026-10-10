import 'config_parsing.dart';

/// Sampling and chat-template options for a Genkit model request.
///
/// Null fields use the adapter defaults when a request executes. Backend and
/// model restrictions still apply; these options cannot enable an unsupported
/// capability. [toJson] omits null fields for Genkit configuration maps.
///
/// ```dart
/// final response = await ai.generate(
///   model: llamaDart.model('local-chat'),
///   prompt: 'Summarize this in one line.',
///   config: const LlamaDartGenerationConfig(
///     temperature: 0.2,
///     maxTokens: 128,
///     enableThinking: false,
///   ),
/// );
/// ```
class LlamaDartGenerationConfig {
  /// Default sampling temperature.
  static const double defaultTemperature = 0.8;

  /// Default nucleus sampling value.
  static const double defaultTopP = 0.9;

  /// Default top-k sampling value.
  static const int defaultTopK = 40;

  /// Default minimum probability cutoff.
  static const double defaultMinP = 0.0;

  /// Default repetition penalty.
  static const double defaultPenalty = 1.1;

  /// Default maximum generated tokens.
  static const int defaultMaxTokens = 4096;

  /// Whether thinking is enabled when the request omits [enableThinking].
  static const bool defaultEnableThinking = false;

  /// Default parallel tool-call behavior.
  static const bool defaultParallelToolCalls = false;

  /// Creates a generation config.
  const LlamaDartGenerationConfig({
    this.temperature,
    this.topP,
    this.topK,
    this.minP,
    this.penalty,
    this.maxTokens,
    this.stop,
    this.seed,
    this.enableThinking,
    this.parallelToolCalls,
    this.sourceLangCode,
    this.targetLangCode,
    this.chatTemplateKwargs,
  });

  /// Reads recognized fields from a Genkit config map.
  ///
  /// Null maps produce an empty config. Numeric values are converted to the
  /// required numeric type; integer fields truncate fractional numbers.
  /// Non-numeric sampling values, non-boolean flags and mixed-type stop lists
  /// become null. Language hints must be strings and template keys must be
  /// strings; incompatible values can throw [TypeError]. Unknown keys are
  /// ignored.
  factory LlamaDartGenerationConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LlamaDartGenerationConfig();
    }

    return LlamaDartGenerationConfig(
      temperature: asDouble(json['temperature']),
      topP: asDouble(json['topP']),
      topK: asInt(json['topK']),
      minP: asDouble(json['minP']),
      penalty: asDouble(json['penalty']),
      maxTokens: asInt(json['maxTokens']),
      stop: asStringList(json['stop']),
      seed: asInt(json['seed']),
      enableThinking: asBool(json['enableThinking']),
      parallelToolCalls: asBool(json['parallelToolCalls']),
      sourceLangCode: json['sourceLangCode'] as String?,
      targetLangCode: json['targetLangCode'] as String?,
      chatTemplateKwargs: asStringDynamicMap(json['chatTemplateKwargs']),
    );
  }

  /// Sampling temperature; lower values favor more predictable output.
  ///
  /// Null uses [defaultTemperature].
  final double? temperature;

  /// Cumulative probability cutoff for nucleus sampling.
  ///
  /// Null uses [defaultTopP].
  final double? topP;

  /// Maximum number of candidate tokens considered by top-k sampling.
  ///
  /// Null uses [defaultTopK].
  final int? topK;

  /// Minimum token probability relative to the most likely candidate.
  ///
  /// Null uses [defaultMinP], which disables this cutoff.
  final double? minP;

  /// Repetition penalty applied to previously generated tokens.
  ///
  /// Null uses [defaultPenalty].
  final double? penalty;

  /// Maximum number of generated tokens, excluding the input prompt.
  ///
  /// Null uses [defaultMaxTokens]. Reaching the limit can leave structured
  /// output incomplete; inspect the final Genkit result.
  final int? maxTokens;

  /// Additional strings that stop generation when encountered.
  ///
  /// Structured output also preserves stop sequences supplied by the template.
  final List<String>? stop;

  /// Sampling seed, when supported by the active backend.
  ///
  /// Reproducibility also depends on the model, backend and sampling settings.
  final int? seed;

  /// Whether the chat template enables model thinking.
  ///
  /// Null uses [defaultEnableThinking]. This controls model/template behavior,
  /// rather than merely hiding reasoning parts in the response.
  final bool? enableThinking;

  /// Whether the chat template permits multiple tool calls in one turn.
  ///
  /// Null uses [defaultParallelToolCalls]. Tool execution remains owned by Genkit.
  final bool? parallelToolCalls;

  /// Source language hint for translation-style chat templates.
  ///
  /// A nonempty value overrides `source_lang_code` in [chatTemplateKwargs].
  final String? sourceLangCode;

  /// Target language hint for translation-style chat templates.
  ///
  /// A nonempty value overrides `target_lang_code` in [chatTemplateKwargs].
  final String? targetLangCode;

  /// Extra globals supplied to the model's chat template.
  ///
  /// Accepted keys and effects depend on the template. Nonempty
  /// [sourceLangCode] and [targetLangCode] take precedence over matching keys.
  final Map<String, dynamic>? chatTemplateKwargs;

  /// Serializes the config to a Genkit-friendly map.
  Map<String, dynamic> toJson() {
    return {
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (topK != null) 'topK': topK,
      if (minP != null) 'minP': minP,
      if (penalty != null) 'penalty': penalty,
      if (maxTokens != null) 'maxTokens': maxTokens,
      if (stop != null) 'stop': stop,
      if (seed != null) 'seed': seed,
      if (enableThinking != null) 'enableThinking': enableThinking,
      if (parallelToolCalls != null) 'parallelToolCalls': parallelToolCalls,
      if (sourceLangCode != null) 'sourceLangCode': sourceLangCode,
      if (targetLangCode != null) 'targetLangCode': targetLangCode,
      if (chatTemplateKwargs != null) 'chatTemplateKwargs': chatTemplateKwargs,
    };
  }
}
