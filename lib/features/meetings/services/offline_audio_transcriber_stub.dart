import 'package:personal_hub/features/meetings/services/offline_audio_transcriber.dart';
import 'package:personal_hub/features/meetings/services/whisper_model_manager.dart';

OfflineAudioTranscriberGateway createOfflineAudioTranscriberGateway(
  WhisperModelManager modelManager,
) {
  return NoOpOfflineAudioTranscriberGateway();
}
