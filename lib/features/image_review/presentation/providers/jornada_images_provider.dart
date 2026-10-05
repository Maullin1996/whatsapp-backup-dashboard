import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/jornada_images.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';

/// Una jornada de un chat en un día: lo que se abre desde "Llenar
/// formularios". [date] es solo la fecha (sin hora).
typedef JornadaImagesKey = ({String chatJid, DateTime date, Shift shift});

/// `fechaJornada` (`yyyy-MM-dd`) del día de [key]: la del inicio de su rango
/// de `DateFilterSpecificDay` (el mismo día que se lee).
String fechaJornadaOf(JornadaImagesKey key) => fechaJornadaDe(
  DateFilterSpecificDay(date: key.date).toTimestampRange().from,
);

/// Tamaño de página al leer el día: las lecturas de Firestore son por
/// documento, así que una página grande solo ahorra viajes, no lecturas.
const int jornadaImagesPageSize = 500;

/// Imágenes de una jornada de un chat en un día, de la PRIMERA a la ÚLTIMA.
///
/// Lee el día completo con el `fetchByDateRange` que ya existe (rango de
/// `DateFilterSpecificDay`, página por página) y se queda con las imágenes de
/// esa jornada ([isImageOfJornada]). Si el día es hoy, sigue escuchando con
/// `listenNewMessages` y agrega al final las imágenes nuevas de la jornada; un
/// día pasado no escucha (escuchar desde un día viejo traería todo lo
/// posterior). Un error de la lectura inicial queda como error del provider,
/// SIN reintento automático de Riverpod 3 (cada reintento volvería a leer el
/// día completo; se reintenta a mano con "Reintentar");
/// un error de la escucha se ignora y la lista se queda como estaba (igual que
/// la escucha del chat).
final jornadaImagesProvider = StreamProvider.autoDispose
    .family<List<ImageViewItem>, JornadaImagesKey>((ref, key) async* {
      final repository = ref.watch(messagesRepositoryProvider);
      final range = DateFilterSpecificDay(date: key.date).toTimestampRange();
      final fecha = fechaJornadaOf(key);

      final dayMessages = <Message>[];
      Object? cursor;
      while (true) {
        final result = await repository.fetchByDateRange(
          chatJid: key.chatJid,
          fromTimestamp: range.from,
          toTimestamp: range.to,
          limit: jornadaImagesPageSize,
          cursor: cursor,
        );
        final page = result.fold((failure) => throw failure, (page) => page);
        dayMessages.addAll(page.items);
        cursor = page.nextCursor;
        if (cursor == null || page.items.length < jornadaImagesPageSize) break;
      }

      final images = [
        for (final m in dayMessages)
          if (isImageOfJornada(m, fecha, key.shift)) m,
      ]..sort(compareOldestFirst);
      yield _items(images);

      final today = fechaJornadaDe(DateTime.now().millisecondsSinceEpoch);
      if (fecha != today) return;

      // Desde el último mensaje del día ya leído (cualquiera, no solo
      // imágenes); sin mensajes, desde el inicio del día.
      final after = dayMessages.fold<int>(
        range.from - 1,
        (max, m) => m.messageTimestamp > max ? m.messageTimestamp : max,
      );
      final ids = {for (final m in images) m.id};
      final live = repository
          .listenNewMessages(chatJid: key.chatJid, afterTimestamp: after)
          .handleError((Object _) {});
      await for (final message in live) {
        if (!isImageOfJornada(message, fecha, key.shift)) continue;
        if (!ids.add(message.id)) continue;
        images
          ..add(message)
          ..sort(compareOldestFirst);
        yield _items(images);
      }
    }, retry: (retryCount, error) => null);

List<ImageViewItem> _items(List<Message> messages) =>
    List.unmodifiable(messages.map(ImageViewItem.fromMessage));
