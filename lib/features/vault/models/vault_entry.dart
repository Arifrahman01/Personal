import 'package:flutter/foundation.dart';

/// AES-256-GCM encrypted payload stored as base64 strings.
@immutable
class EncryptedPayload {
  const EncryptedPayload({
    required this.cipherTextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  final String cipherTextBase64;
  final String nonceBase64;
  final String macBase64;

  Map<String, dynamic> toJson() => {
    'cipherTextBase64': cipherTextBase64,
    'nonceBase64': nonceBase64,
    'macBase64': macBase64,
  };

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      EncryptedPayload(
        cipherTextBase64:
            (json['cipherTextBase64'] ?? json['cipherText']) as String,
        nonceBase64: (json['nonceBase64'] ?? json['nonce']) as String,
        macBase64: (json['macBase64'] ?? json['mac']) as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedPayload &&
          runtimeType == other.runtimeType &&
          cipherTextBase64 == other.cipherTextBase64 &&
          nonceBase64 == other.nonceBase64 &&
          macBase64 == other.macBase64;

  @override
  int get hashCode =>
      Object.hash(cipherTextBase64, nonceBase64, macBase64);
}

/// Decrypted password vault entry handled strictly in-memory while unlocked.
@immutable
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          username == other.username &&
          password == other.password &&
          url == other.url &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    username,
    password,
    url,
    notes,
    createdAt,
    updatedAt,
  );
}
