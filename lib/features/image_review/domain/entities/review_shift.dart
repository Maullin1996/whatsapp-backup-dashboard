import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

part 'review_shift.freezed.dart';

/// Un grupo y una jornada que un Revisor/Sumador cubre. Sin campo `role`: se
/// deriva del `reviewRole` de la cuenta dueña de la lista (`AppUser.reviewShifts`)
/// — un usuario no puede cubrir un grupo+jornada bajo un rol que no es el
/// suyo. Reemplaza a `ReviewAssignment` (una sola tupla por cuenta): ahora es
/// una LISTA, ver `.claude/skills/image-review-roles.md`.
@freezed
abstract class ReviewShift with _$ReviewShift {
  const factory ReviewShift({required String chatJid, required Shift shift}) =
      _ReviewShift;
}
