/// Request-time generation options supported by `genkit_llamadart`.
class LlamaDartGenerationConfig {
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

  /// Builds a config from a Genkit config map.
  factory LlamaDartGenerationConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LlamaDartGenerationConfig();
    }

    return LlamaDartGenerationConfig(
      temperature: _asDouble(json['temperature']),
      topP: _asDouble(json['topP']),
      topK: _asInt(json['topK']),
      minP: _asDouble(json['minP']),
      penalty: _asDouble(json['penalty']),
      maxTokens: _asInt(json['maxTokens']),
      stop: _asStringList(json['stop']),
      seed: _asInt(json['seed']),
      enableThinking: _asBool(json['enableThinking']),
      parallelToolCalls: _asBool(json['parallelToolCalls']),
      sourceLangCode: json['sourceLangCode'] as String?,
      targetLangCode: json['targetLangCode'] as String?,
      chatTemplateKwargs: _asStringDynamicMap(json['chatTemplateKwargs']),
    );
  }

  /// Sampling temperature.
  final double? temperature;

  /// Top-p nucleus sampling value.
  final double? topP;

  /// Top-k sampling value.
  final int? topK;

  /// Minimum probability cutoff.
  final double? minP;

  /// Repeat penalty value.
  final double? penalty;

  /// Maximum tokens to generate.
  final int? maxTokens;

  /// Stop sequences.
  final List<String>? stop;

  /// Optional deterministic seed.
  final int? seed;

  /// Whether model reasoning should remain enabled.
  final bool? enableThinking;

  /// Whether templates may emit parallel tool calls.
  final bool? parallelToolCalls;

  /// Optional source language hint for translation-style templates.
  final String? sourceLangCode;

  /// Optional target language hint for translation-style templates.
  final String? targetLangCode;

  /// Extra keyword arguments passed through to the chat template.
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

/// Request-time embedding options supported by `genkit_llamadart`.
class LlamaDartEmbedConfig {
  /// Creates an embedding config.
  const LlamaDartEmbedConfig({this.normalize});

  /// Builds an embed config from a Genkit options map.
  factory LlamaDartEmbedConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LlamaDartEmbedConfig();
    }

    return LlamaDartEmbedConfig(normalize: _asBool(json['normalize']));
  }

  /// Whether output vectors should be normalized.
  final bool? normalize;

  /// Serializes the config to a Genkit-friendly map.
  Map<String, dynamic> toJson() {
    return {if (normalize != null) 'normalize': normalize};
  }
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool? _asBool(Object? value) {
  return value is bool ? value : null;
}

List<String>? _asStringList(Object? value) {
  if (value is List) {
    final strings = value.whereType<String>().toList(growable: false);
    if (strings.length == value.length) {
      return strings;
    }
  }
  return null;
}

Map<String, dynamic>? _asStringDynamicMap(Object? value) {
  return value is Map ? value.cast<String, dynamic>() : null;
}
