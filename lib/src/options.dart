class LlamaDartGenerationConfig {
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

  final double? temperature;
  final double? topP;
  final int? topK;
  final double? minP;
  final double? penalty;
  final int? maxTokens;
  final List<String>? stop;
  final int? seed;
  final bool? enableThinking;
  final bool? parallelToolCalls;
  final String? sourceLangCode;
  final String? targetLangCode;
  final Map<String, dynamic>? chatTemplateKwargs;

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

class LlamaDartEmbedConfig {
  const LlamaDartEmbedConfig({this.normalize});

  factory LlamaDartEmbedConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LlamaDartEmbedConfig();
    }

    return LlamaDartEmbedConfig(normalize: _asBool(json['normalize']));
  }

  final bool? normalize;

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
