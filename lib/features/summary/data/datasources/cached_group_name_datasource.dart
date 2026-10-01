import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';

/// Decorador de [GroupNameDatasource] que recuerda los nombres encontrados
/// durante toda la vida del objeto (la sesión de la app), sin TTL. Nombre
/// PROVISIONAL. Dart puro.
///
/// Solo guarda éxitos con nombre: un documento ausente (`Right(null)`) o un
/// `Left` se devuelven tal cual y NO se guardan, para reintentar la próxima
/// vez.
class CachedGroupNameDatasource implements GroupNameDatasource {
  CachedGroupNameDatasource(this._inner);

  final GroupNameDatasource _inner;
  final Map<String, String> _names = {};

  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async {
    final cached = _names[chatJid];
    if (cached != null) return Right(cached);

    final result = await _inner.fetchGroupName(chatJid);
    result.fold((_) {}, (name) {
      if (name != null) _names[chatJid] = name;
    });
    return result;
  }
}
