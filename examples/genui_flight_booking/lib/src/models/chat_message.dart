import 'package:flutter/foundation.dart';

/// Role associated with a conversation message.
enum ChatRole {
  /// Message authored by the human user.
  user,

  /// Message authored by the flight booking AI assistant.
  assistant,

  /// Informational or system status message.
  system,
}

/// Represents a single message bubble within the flight assistant stream.
@immutable
class ChatMessage {
  /// Creates a [ChatMessage].
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.surfaceId,
  });

  /// Factory helper for creating a user message.
  factory ChatMessage.user(String text) {
    return ChatMessage(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: text,
      timestamp: DateTime.now(),
    );
  }

  /// Factory helper for creating an assistant message.
  factory ChatMessage.assistant(String text, {String? surfaceId}) {
    return ChatMessage(
      id: 'ast_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      text: text,
      timestamp: DateTime.now(),
      surfaceId: surfaceId,
    );
  }

  /// Unique message ID.
  final String id;

  /// The author role.
  final ChatRole role;

  /// Markdown or plain text message content.
  final String text;

  /// Timestamp when the message was generated.
  final DateTime timestamp;

  /// Optional A2UI surface ID associated with this message turn.
  final String? surfaceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          role == other.role &&
          text == other.text &&
          surfaceId == other.surfaceId;

  @override
  int get hashCode => Object.hash(id, role, text, surfaceId);

  @override
  String toString() => 'ChatMessage($role: $text, surface: $surfaceId)';
}
