import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_group_name_datasource.dart';

/// Colección y campo de los números ganadores: `winning_numbers/{fecha}`
/// con `numbers` (lista de texto). NOMBRES Y FORMA PROVISIONALES: la
/// colección todavía no existe; la escribirá la función puente (pieza b) con
/// el Admin SDK.
const winningNumbersSource = (collection: 'winning_numbers', field: 'numbers');

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
  Future<Either<Failure, List<String>>> fetchByFecha(String fecha) async {
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

    if (data == null) return const Right([]);
    final numbers = data[winningNumbersSource.field];
    if (numbers is! List || numbers.any((n) => n is! String)) {
      return Left(
        Failure.unknown(
          message:
              'Los números ganadores de $fecha tienen un formato inesperado: '
              'el campo "${winningNumbersSource.field}" '
              '${numbers == null ? 'falta' : 'no es una lista de texto'}.',
        ),
      );
    }
    return Right(numbers.cast<String>().toList());
  }
}
