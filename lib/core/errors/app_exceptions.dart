/// Base class for all application-level exceptions.
abstract class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => 'AppException: $message';
}

/// Error categories returned by the AI inference client.
enum AiErrorType {
  unauthorized,
  badRequest,
  quotaExhausted,
  network,
  server,
  emptyKey,
}

/// Thrown when user input or domain state fails validation.
class ValidationException extends AppException {
  const ValidationException(super.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when an AI inference request fails.
class AiException extends AppException {
  final AiErrorType type;

  const AiException(this.type, String message) : super(message);

  @override
  String toString() => 'AiException(${type.name}): $message';
}

/// Thrown when decrypting a vault entry or verifying vault credentials fails.
class VaultDecryptionException extends AppException {
  const VaultDecryptionException(super.message);

  @override
  String toString() => 'VaultDecryptionException: $message';
}

/// Thrown when decrypting an encrypted backup archive fails.
class BackupDecryptionException extends AppException {
  const BackupDecryptionException(super.message);

  @override
  String toString() => 'BackupDecryptionException: $message';
}

/// Thrown when decrypting an encrypted sync bundle fails.
class SyncDecryptionException extends AppException {
  const SyncDecryptionException(super.message);

  @override
  String toString() => 'SyncDecryptionException: $message';
}

/// Thrown when a sync operation fails or encounters an invalid state.
class SyncException extends AppException {
  const SyncException(super.message);

  @override
  String toString() => 'SyncException: $message';
}

