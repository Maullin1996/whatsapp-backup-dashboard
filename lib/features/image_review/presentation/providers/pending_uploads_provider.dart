import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';

/// Posición de una jornada (por el texto que guarda el registro) dentro del
/// día; las desconocidas van al final.
int _shiftOrder(String shift) {
  final labels = Shift.values.map((s) => shiftNames[s]).toList();
  final index = labels.indexOf(shift);
  return index == -1 ? labels.length : index;
}

/// Jornadas del chat activo con registros pendientes de subir, del rol activo.
///
/// Depende SOLO del chat activo, el rol activo y el repositorio (no de los
/// mensajes cargados ni del filtro de fechas): un pendiente de otro día se ve
/// aunque esa jornada no esté en pantalla. Orden: día más reciente primero y,
/// dentro del día, en el orden de las jornadas.
///
/// Se recalcula sola al cambiar chat, rol o usuario; quien guarda o sube
/// registros debe hacer `ref.invalidate(pendingUploadsProvider)`. Sin chat
/// activo, la lista es vacía. Un `Failure` del repositorio queda como error
/// del `AsyncValue`, sin reintento automático (no es transitorio).
final pendingUploadsProvider = FutureProvider<List<PendingJornada>>((
  ref,
) async {
  final chatJid = ref.watch(activeChatProvider.select((c) => c?.chatJid));
  final rol = ref.watch(currentReviewRoleProvider);
  final repository = ref.watch(imageReviewRepositoryProvider);
  if (chatJid == null) return const [];

  final result = await repository.getPendingJornadas(
    chatJid: chatJid,
    rol: rol,
  );
  final jornadas = result.fold((failure) => throw failure, (list) => list);
  return [...jornadas]..sort((a, b) {
    final byDate = b.fechaJornada.compareTo(a.fechaJornada);
    return byDate != 0
        ? byDate
        : _shiftOrder(a.shift).compareTo(_shiftOrder(b.shift));
  });
}, retry: (retryCount, error) => null);
