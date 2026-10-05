import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';

/// Lo que Coincidencias muestra de un mensaje de WhatsApp.
typedef MessageContext = ({String senderName, String localTime});

/// Lee un mensaje de `whatsapp_messages` por su id.
abstract class MessageContextDatasource {
  /// Contrato: no lanza. Un error de lectura, un mensaje inexistente o sin
  /// `senderName` o `localTime` de texto devuelven `Left` con el id.
  Future<Either<Failure, MessageContext>> fetchById(String messageId);
}
