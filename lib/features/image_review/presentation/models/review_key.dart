import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Llave de todo lo que es "por imagen y por rol": borrador, registro guardado
/// y bloqueo de navegación. Es explícita (y no se lee dentro del provider)
/// para que cada rol tenga su propio borrador y registro de la misma imagen y
/// nunca vea los del otro, aunque el rol activo cambie.
typedef ReviewKey = ({String messageId, ReviewRole rol});

/// Nombre del rol en la UI (español).
extension ReviewRoleLabel on ReviewRole {
  String get label => switch (this) {
    ReviewRole.revisor => 'Revisor',
    ReviewRole.sumador => 'Sumador',
  };
}
