import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/pages/login_page.dart';

class FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;

  @override
  Future<Either<AuthFailure, AuthenticatedUser>> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    return Right(AuthenticatedUser(id: '1', email: email));
  }

  @override
  Future<Either<AuthFailure, Unit>> logout() async {
    return const Right(unit);
  }

  @override
  Future<Either<AuthFailure, AuthenticatedUser?>> getCurrentUser() async {
    return const Right(null);
  }
}

void main() {
  testWidgets('LoginPage renders and triggers login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final fakeRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaleFactor: 0.85),
            child: LoginPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Monitor de Imagenes'), findsOneWidget);
    expect(find.text('email'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'secret123');

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(fakeRepo.loginCalls, 1);
  });
}
