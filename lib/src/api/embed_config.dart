import 'config_parsing.dart';

/// Request-time embedding options supported by `genkit_llamadart`.
///
/// ```dart
/// final embeddings = await ai.embed(
///   embedder: llamaDart.embedder('local-embed'),
///   document: DocumentData(
///     content: <Part>[TextPart(text: 'hello world')],
///   ),
///   options: const LlamaDartEmbedConfig(normalize: true),
/// );
/// ```
class LlamaDartEmbedConfig {
  /// Default embedding normalization behavior.
  static const bool defaultNormalize = true;

  /// Creates an embedding config.
  const LlamaDartEmbedConfig({this.normalize});

  /// Builds an embed config from a Genkit options map.
  factory LlamaDartEmbedConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LlamaDartEmbedConfig();
    }

    return LlamaDartEmbedConfig(normalize: asBool(json['normalize']));
  }

  /// Whether output vectors should be normalized.
  final bool? normalize;

  /// Serializes the config to a Genkit-friendly map.
  Map<String, dynamic> toJson() {
    return {if (normalize != null) 'normalize': normalize};
  }
}
