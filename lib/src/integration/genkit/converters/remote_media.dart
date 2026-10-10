import 'dart:typed_data';

import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

import '../../../api/media_resolver.dart';
import 'genkit_to_llama.dart';

Future<List<llama.LlamaChatMessage>> resolveLlamaMessages(
  List<genkit.Message> messages, {
  LlamaDartMediaResolver? resolver,
  genkit.CancellationToken? cancel,
}) async {
  if (!const bool.fromEnvironment('dart.library.io') || resolver == null) {
    return toLlamaMessages(messages);
  }
  final pending = <(String, String?), String>{};
  final overrides = <(String, String?), llama.LlamaContentPart>{};
  for (final message in messages) {
    if (message.role == genkit.Role.tool) continue;
    for (final part in message.content) {
      if (!part.isMedia) continue;
      final media = part.media!;
      final uri = Uri.tryParse(media.url);
      if (uri?.scheme != 'http' && uri?.scheme != 'https') continue;
      final type = (media.contentType ?? inferMediaContentType(media.url))
          ?.toLowerCase();
      if (type == null ||
          !RegExp(r'^(image|audio)/[a-z0-9!#$&^_.+*-]+$').hasMatch(type)) {
        throw genkit.GenkitException(
          'Remote media requires an image/* or audio/* MIME type.',
          status: genkit.StatusCode.invalidArgument,
        );
      }
      final key = (media.url, media.contentType);
      pending[key] = type;
      overrides[key] = type.startsWith('image/')
          ? llama.LlamaImageContent(bytes: Uint8List(0))
          : llama.LlamaAudioContent(bytes: Uint8List(0));
    }
  }
  final validated = toLlamaMessages(messages, mediaOverrides: overrides);
  if (pending.isEmpty) return validated;
  for (final entry in pending.entries) {
    if (cancel?.isCancelled ?? false) {
      throw genkit.CancelledException(token: cancel);
    }
    final Uint8List bytes;
    try {
      bytes = await resolver.resolve(
        Uri.parse(entry.key.$1),
        contentType: entry.value,
        cancel: cancel,
      );
      if (bytes.isEmpty) throw StateError('Empty media.');
    } catch (error) {
      if (cancel?.isCancelled ?? false) {
        throw genkit.CancelledException(token: cancel);
      }
      throw genkit.GenkitException(
        'Remote media resolution failed. Check URL policy, authentication, '
        'response MIME type and transfer limits.',
        status: error is genkit.GenkitException
            ? error.status
            : genkit.StatusCode.invalidArgument,
      );
    }
    if (cancel?.isCancelled ?? false) {
      throw genkit.CancelledException(token: cancel);
    }
    overrides[entry.key] = entry.value.startsWith('image/')
        ? llama.LlamaImageContent(bytes: bytes)
        : llama.LlamaAudioContent(bytes: bytes);
  }
  return toLlamaMessages(messages, mediaOverrides: overrides);
}
