import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';

String mapFailureToMessage(Object error) {
  if (error is Failure) {
    return error.when(
      firestore: (message) => message,
      unauthorized: (message) => message,
      storage: (message) => message,
      unknown: (message) => message,
    );
  }

  if (error is ImageReviewFailure) {
    return error.message;
  }

  return 'Error inesperado';
}
