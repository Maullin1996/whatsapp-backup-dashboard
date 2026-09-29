import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/auth_redirect.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';

AuthenticatedUser _user({bool isAdmin = false, bool isSuperAdmin = false}) =>
    AuthenticatedUser(
      id: 'uid',
      email: 'a@x.com',
      isAdmin: isAdmin,
      isSuperAdmin: isSuperAdmin,
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

  group('/admin y /summary se comportan igual que antes', () {
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

    test('/summary: cualquier usuario autenticado entra, sin redirigir', () {
      final authState = AuthSessionState.authenticated(_user());
      expect(
        computeAuthRedirect(authState: authState, location: '/summary'),
        isNull,
      );
    });
  });
}
