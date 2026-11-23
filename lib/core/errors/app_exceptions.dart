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
class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when an AI inference request fails.
class AiException implements Exception {
  final AiErrorType type;
  final String message;

  const AiException(this.type, this.message);

  @override
  String toString() => 'AiException(${type.name}): $message';
}

/// Thrown when decrypting a vault entry or verifying vault credentials fails.
class VaultDecryptionException implements Exception {
  final String message;

  const VaultDecryptionException(this.message);

  @override
  String toString() => 'VaultDecryptionException: $message';
}

/// Thrown when decrypting an encrypted backup archive fails.
class BackupDecryptionException implements Exception {
  final String message;

  const BackupDecryptionException(this.message);

  @override
  String toString() => 'BackupDecryptionException: $message';
}
