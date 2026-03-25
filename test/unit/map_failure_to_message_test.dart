import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

void main() {
  test('mapFailureToMessage maps known failures to their message', () {
    expect(
      mapFailureToMessage(const Failure.firestore(message: 'db error')),
      'db error',
    );
    expect(
      mapFailureToMessage(const Failure.unauthorized(message: 'no auth')),
      'no auth',
    );
    expect(
      mapFailureToMessage(const Failure.unknown(message: 'unknown')),
      'unknown',
    );
  });

  test('mapFailureToMessage returns default for unknown errors', () {
    expect(mapFailureToMessage(Exception('boom')), 'Error inesperado');
  });
}
