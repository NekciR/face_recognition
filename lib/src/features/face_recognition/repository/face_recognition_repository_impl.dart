import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'face_recognition_repository.dart';

class FaceRecognitionRepositoryImpl extends FaceRecognitionRepository {
  // TODO add your methods here
}

final faceRecognitionRepositoryProvider = Provider<FaceRecognitionRepository>((ref) {
  return FaceRecognitionRepositoryImpl();
});
