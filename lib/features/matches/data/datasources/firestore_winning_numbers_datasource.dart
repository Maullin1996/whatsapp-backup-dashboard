import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_group_name_datasource.dart';

/// Colección y campo de los ganadores: `winning_numbers/{fecha}` con
/// `entries` (lista de mapas `{loteria, numero}`, ambos texto). NOMBRES Y
/// FORMA PROVISIONALES. La escribe la función puente con el Admin SDK, junto
/// con `numbers` (lista de textos), que la app ya no lee.
const winningNumbersSource = (collection: 'winning_numbers', field: 'entries');

/// [WinningNumbersDatasource] con Firestore: `winning_numbers/{fecha}`.
/// Nunca lanza.
class FirestoreWinningNumbersDatasource implements WinningNumbersDatasource {
  /// Lectura real contra [firestore].
  FirestoreWinningNumbersDatasource(FirebaseFirestore firestore)
    : this.withReader((fecha) async {
        final doc = await firestore
            .collection(winningNumbersSource.collection)
            .doc(fecha)
            .get();
        return doc.exists ? doc.data() : null;
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreWinningNumbersDatasource.withReader(this._read);

  final DocumentReader _read;

  @override
  Future<Either<Failure, List<WinningEntry>>> fetchByFecha(String fecha) async {
    final Map<String, dynamic>? data;
    try {
      data = await _read(fecha);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return Left(
        Failure.unknown(
          message: 'Error inesperado al leer los números ganadores de $fecha.',
        ),
      );
    }

    // Sin documento o sin `entries`: todavía no hay ganadores.
    final entries = data?[winningNumbersSource.field];
    if (entries == null) return const Right([]);
    if (entries is! List ||
        entries.any(
          (e) => e is! Map || e['loteria'] is! String || e['numero'] is! String,
        )) {
      return Left(
        Failure.unknown(
          message:
              'Los números ganadores de $fecha tienen un formato inesperado: '
              'el campo "${winningNumbersSource.field}" no es una lista de '
              'pares con "loteria" y "numero" de texto.',
        ),
      );
    }
    return Right([
      for (final e in entries.cast<Map>())
        WinningEntry(
          loteria: e['loteria'] as String,
          numero: e['numero'] as String,
        ),
    ]);
  }
}
