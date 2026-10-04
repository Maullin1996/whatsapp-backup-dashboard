import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/auth_redirect.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

AuthenticatedUser _user({
  bool isAdmin = false,
  bool isSuperAdmin = false,
  ReviewRole? reviewRole,
}) => AuthenticatedUser(
  id: 'uid',
  email: 'a@x.com',
  isAdmin: isAdmin,
  isSuperAdmin: isSuperAdmin,
  reviewRole: reviewRole,
);

void main() {
  group('sin sesión', () {
    const authState = AuthSessionState.unauthenticated();

    test('yendo a /matches redirige a /login', () {
      expect(
        computeAuthRedirect(authState: authState, location: '/matches'),
        '/login',
      );
    });

    test('yendo a /summary redirige a /login (como antes)', () {
      expect(
        computeAuthRedirect(authState: authState, location: '/summary'),
        '/login',
      );
    });

    test('yendo a /login no redirige', () {
      expect(
        computeAuthRedirect(authState: authState, location: '/login'),
        isNull,
      );
    });
  });

  group('/matches', () {
    test('usuario normal (ni admin ni superAdmin) termina en /home', () {
      final authState = AuthSessionState.authenticated(_user());
      expect(
        computeAuthRedirect(authState: authState, location: '/matches'),
        '/home',
      );
    });

    test('isAdmin (sin superAdmin) entra, sin redirigir', () {
      final authState = AuthSessionState.authenticated(_user(isAdmin: true));
      expect(
        computeAuthRedirect(authState: authState, location: '/matches'),
        isNull,
      );
    });

    test('isSuperAdmin (sin isAdmin) entra, sin redirigir', () {
      final authState = AuthSessionState.authenticated(
        _user(isSuperAdmin: true),
      );
      expect(
        computeAuthRedirect(authState: authState, location: '/matches'),
        isNull,
      );
    });

    for (final rol in ReviewRole.values) {
      test('${rol.name} (sin admin) termina en /home, como antes', () {
        final authState = AuthSessionState.authenticated(
          _user(reviewRole: rol),
        );
        expect(
          computeAuthRedirect(authState: authState, location: '/matches'),
          '/home',
        );
      });
    }
  });

  group('/summary (canViewSummary: admin o superAdmin)', () {
    test('isAdmin (sin superAdmin) entra, sin redirigir', () {
      final authState = AuthSessionState.authenticated(_user(isAdmin: true));
      expect(
        computeAuthRedirect(authState: authState, location: '/summary'),
        isNull,
      );
    });

    test('isSuperAdmin (sin isAdmin) entra, sin redirigir', () {
      final authState = AuthSessionState.authenticated(
        _user(isSuperAdmin: true),
      );
      expect(
        computeAuthRedirect(authState: authState, location: '/summary'),
        isNull,
      );
    });

    for (final rol in ReviewRole.values) {
      test('${rol.name} (sin admin) termina en /home', () {
        final authState = AuthSessionState.authenticated(
          _user(reviewRole: rol),
        );
        expect(
          computeAuthRedirect(authState: authState, location: '/summary'),
          '/home',
        );
      });
    }

    test('usuario sin claims termina en /home', () {
      final authState = AuthSessionState.authenticated(_user());
      expect(
        computeAuthRedirect(authState: authState, location: '/summary'),
        '/home',
      );
    });
  });

  test('en loading no redirige, sin importar el destino', () {
    const authState = AuthSessionState.loading();
    expect(
      computeAuthRedirect(authState: authState, location: '/matches'),
      isNull,
    );
    expect(
      computeAuthRedirect(authState: authState, location: '/admin'),
      isNull,
    );
    expect(
      computeAuthRedirect(authState: authState, location: '/login'),
      isNull,
    );
  });

  group('/admin se comporta igual que antes', () {
    test('/admin: usuario normal termina en /home', () {
      final authState = AuthSessionState.authenticated(_user());
      expect(
        computeAuthRedirect(authState: authState, location: '/admin'),
        '/home',
      );
    });

    test('/admin: isSuperAdmin sin isAdmin también termina en /home (no cubre '
        'superAdmin, a propósito, sin cambiar ese comportamiento)', () {
      final authState = AuthSessionState.authenticated(
        _user(isSuperAdmin: true),
      );
      expect(
        computeAuthRedirect(authState: authState, location: '/admin'),
        '/home',
      );
    });

    test('/admin: isAdmin entra, sin redirigir', () {
      final authState = AuthSessionState.authenticated(_user(isAdmin: true));
      expect(
        computeAuthRedirect(authState: authState, location: '/admin'),
        isNull,
      );
    });
  });

  group('/review (sesión de llenado)', () {
    final revisor = AuthSessionState.authenticated(
      _user(reviewRole: ReviewRole.revisor),
    );

    String? go(String location, {required bool session}) => computeAuthRedirect(
      authState: revisor,
      location: location,
      reviewSessionActive: session,
    );

    test('con sesión, /review se queda', () {
      expect(go('/review', session: true), isNull);
    });

    test('con sesión, cualquier otra ruta vuelve a /review (también el '
        '"atrás" del navegador hacia /home o /login)', () {
      for (final location in [
        '/home',
        '/login',
        '/admin',
        '/summary',
        '/matches',
        '/home/viewer/0',
      ]) {
        expect(go(location, session: true), '/review', reason: location);
      }
    });

    test('sin sesión, /review lleva a /home', () {
      expect(go('/review', session: false), '/home');
    });

    test('sin sesión, el resto se comporta como antes', () {
      expect(go('/home', session: false), isNull);
      expect(go('/login', session: false), '/home');
      expect(go('/summary', session: false), '/home');
    });

    test('sin sesión de Firebase manda a /login aunque haya sesión de '
        'llenado', () {
      expect(
        computeAuthRedirect(
          authState: const AuthSessionState.unauthenticated(),
          location: '/review',
          reviewSessionActive: true,
        ),
        '/login',
      );
    });

    test('cargando la sesión de Firebase no redirige', () {
      expect(
        computeAuthRedirect(
          authState: const AuthSessionState.loading(),
          location: '/home',
          reviewSessionActive: true,
        ),
        isNull,
      );
    });
  });
}
