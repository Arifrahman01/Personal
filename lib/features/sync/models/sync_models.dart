import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Entities supported by the zero-knowledge sync engine.
enum SyncEntityType {
  note,
  task,
  meeting,
  transaction;

  /// Helper parser from string.
  static SyncEntityType fromString(String value) {
    return SyncEntityType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown SyncEntityType: $value'),
    );
  }
}

/// Action performed on a synced entity.
enum SyncAction {
  upsert,
  delete;

  /// Helper parser from string.
  static SyncAction fromString(String value) {
    return SyncAction.values.firstWhere(
      (a) => a.name.toLowerCase() == value.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown SyncAction: $value'),
    );
  }
}

/// A single granular change delta representing an upsert or deletion tombstone.
class SyncDeltaRecord {
  const SyncDeltaRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.payloadJson,
    required this.timestampUtc,
    required this.deviceId,
  });

  /// Unique identifier for this delta record.
  final String id;

  /// Type of domain entity affected.
  final SyncEntityType entityType;

  /// Primary key of the entity in its respective table.
  final String entityId;

  /// Whether this delta upserts or deletes (tombstones) the entity.
  final SyncAction action;

  /// Serialized JSON payload for upserts, or null for deletions.
  final String? payloadJson;

  /// UTC timestamp when this change was committed locally.
  final DateTime timestampUtc;

  /// Identifier of the device where this change originated.
  final String deviceId;

  /// Convenience factory for creating an upsert delta.
  factory SyncDeltaRecord.upsert({
    String? id,
    required SyncEntityType entityType,
    required String entityId,
    required String payloadJson,
    DateTime? timestampUtc,
    required String deviceId,
  }) {
    return SyncDeltaRecord(
      id: id ?? const Uuid().v4(),
      entityType: entityType,
      entityId: entityId,
      action: SyncAction.upsert,
      payloadJson: payloadJson,
      timestampUtc: (timestampUtc ?? DateTime.now()).toUtc(),
      deviceId: deviceId,
    );
  }

  /// Convenience factory for creating a deletion tombstone delta.
  factory SyncDeltaRecord.delete({
    String? id,
    required SyncEntityType entityType,
    required String entityId,
    DateTime? timestampUtc,
    required String deviceId,
  }) {
    return SyncDeltaRecord(
      id: id ?? const Uuid().v4(),
      entityType: entityType,
      entityId: entityId,
      action: SyncAction.delete,
      payloadJson: null,
      timestampUtc: (timestampUtc ?? DateTime.now()).toUtc(),
      deviceId: deviceId,
    );
  }

  /// Creates a copy with selectively updated fields.
  SyncDeltaRecord copyWith({
    String? id,
    SyncEntityType? entityType,
    String? entityId,
    SyncAction? action,
    String? payloadJson,
    DateTime? timestampUtc,
    String? deviceId,
  }) {
    return SyncDeltaRecord(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Converts this delta into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType.name,
    'entityId': entityId,
    'action': action.name,
    'payloadJson': payloadJson,
    'timestampUtc': timestampUtc.toUtc().toIso8601String(),
    'deviceId': deviceId,
  };

  /// Map representation compatible with SQLite or snake_case / camelCase JSON.
  Map<String, dynamic> toMap() => toJson();

  /// Deserializes a delta record from JSON or row map.
  factory SyncDeltaRecord.fromJson(Map<String, dynamic> json) {
    final entityTypeStr = (json['entityType'] ?? json['entity_type']) as String;
    final actionStr = json['action'] as String;
    final timestampStr =
        (json['timestampUtc'] ?? json['timestamp_utc']) as String;

    return SyncDeltaRecord(
      id: json['id'] as String,
      entityType: SyncEntityType.fromString(entityTypeStr),
      entityId: (json['entityId'] ?? json['entity_id']) as String,
      action: SyncAction.fromString(actionStr),
      payloadJson: (json['payloadJson'] ?? json['payload_json']) as String?,
      timestampUtc: DateTime.parse(timestampStr).toUtc(),
      deviceId: (json['deviceId'] ?? json['device_id']) as String,
    );
  }

  factory SyncDeltaRecord.fromMap(Map<String, dynamic> map) =>
      SyncDeltaRecord.fromJson(map);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDeltaRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          action == other.action &&
          payloadJson == other.payloadJson &&
          timestampUtc.isAtSameMomentAs(other.timestampUtc) &&
          deviceId == other.deviceId;

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    action,
    payloadJson,
    timestampUtc.millisecondsSinceEpoch,
    deviceId,
  );

  @override
  String toString() =>
      'SyncDeltaRecord(id: $id, entity: ${entityType.name}:$entityId, action: ${action.name}, time: ${timestampUtc.toIso8601String()}, device: $deviceId)';
}

/// An encrypted container of delta records for secure end-to-end multi-device synchronization.
class EncryptedSyncBundle {
  const EncryptedSyncBundle({
    required this.cipherTextBase64,
    required this.nonceBase64,
    required this.macBase64,
    this.bundleVersion = 1,
    required this.timestamp,
    this.saltBase64,
  });

  /// Base64-encoded AES-256-GCM ciphertext of the serialized delta records.
  final String cipherTextBase64;

  /// Base64-encoded 12-byte initialization vector (nonce).
  final String nonceBase64;

  /// Base64-encoded 16-byte authentication tag (MAC).
  final String macBase64;

  /// Protocol bundle format version.
  final int bundleVersion;

  /// Timestamp when the bundle was encrypted/generated.
  final DateTime timestamp;

  /// Optional Base64-encoded salt used for PBKDF2 derivation.
  final String? saltBase64;

  /// Converts this encrypted bundle into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'cipherTextBase64': cipherTextBase64,
    'nonceBase64': nonceBase64,
    'macBase64': macBase64,
    'bundleVersion': bundleVersion,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (saltBase64 != null) 'saltBase64': saltBase64,
  };

  /// Deserializes an encrypted sync bundle from JSON.
  factory EncryptedSyncBundle.fromJson(Map<String, dynamic> json) {
    final timestampStr =
        (json['timestamp'] ?? json['timestamp_utc']) as String;
    return EncryptedSyncBundle(
      cipherTextBase64:
          (json['cipherTextBase64'] ?? json['cipher_text_base64']) as String,
      nonceBase64: (json['nonceBase64'] ?? json['nonce_base64']) as String,
      macBase64: (json['macBase64'] ?? json['mac_base64']) as String,
      bundleVersion:
          (json['bundleVersion'] ?? json['bundle_version'] ?? 1) as int,
      timestamp: DateTime.parse(timestampStr).toUtc(),
      saltBase64: (json['saltBase64'] ?? json['salt_base64']) as String?,
    );
  }

  /// Serializes the bundle to an encoded JSON string.
  String serialize() => jsonEncode(toJson());

  /// Deserializes a bundle from a JSON string.
  factory EncryptedSyncBundle.deserialize(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return EncryptedSyncBundle.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedSyncBundle &&
          runtimeType == other.runtimeType &&
          cipherTextBase64 == other.cipherTextBase64 &&
          nonceBase64 == other.nonceBase64 &&
          macBase64 == other.macBase64 &&
          bundleVersion == other.bundleVersion &&
          timestamp.isAtSameMomentAs(other.timestamp) &&
          saltBase64 == other.saltBase64;

  @override
  int get hashCode => Object.hash(
    cipherTextBase64,
    nonceBase64,
    macBase64,
    bundleVersion,
    timestamp.millisecondsSinceEpoch,
    saltBase64,
  );

  @override
  String toString() =>
      'EncryptedSyncBundle(v$bundleVersion, timestamp: ${timestamp.toIso8601String()})';
}

/// Result summary of a remote delta merge operation.
class SyncMergeResult {
  const SyncMergeResult({
    required this.appliedDeltas,
    required this.skippedDeltas,
    required this.conflictsResolved,
  });

  /// Remote deltas that were newer than local state and successfully applied.
  final List<SyncDeltaRecord> appliedDeltas;

  /// Remote deltas that were older or duplicates and were ignored.
  final List<SyncDeltaRecord> skippedDeltas;

  /// Deltas that involved a conflict resolution where remote or local state took precedence.
  final List<SyncDeltaRecord> conflictsResolved;

  int get appliedCount => appliedDeltas.length;
  int get skippedCount => skippedDeltas.length;
  int get conflictCount => conflictsResolved.length;

  bool get hasChanges => appliedDeltas.isNotEmpty;

  @override
  String toString() =>
      'SyncMergeResult(applied: $appliedCount, skipped: $skippedCount, conflicts: $conflictCount)';
}
