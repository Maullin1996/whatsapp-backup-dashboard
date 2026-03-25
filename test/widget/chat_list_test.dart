import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/controllers/chats_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chats_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chat_list.dart';

import 'test_asset_bundle.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<AuthFailure, AuthenticatedUser>> login({
    required String email,
    required String password,
  }) async {
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

class FakeChatsNotifier extends ChatsNotifier {
  FakeChatsNotifier(this._chats);

  final List<Chat> _chats;

  @override
  Future<List<Chat>> build() async => _chats;
}

void main() {
  setUpAll(setUpMockAssets);

  testWidgets('ChatList shows chats and filters by search', (tester) async {
    final chats = [
      Chat(
        chatJid: '1',
        groupName: 'Grupo Alpha',
        lastMessageAt: DateTime.now().millisecondsSinceEpoch,
        totalImages: 5,
      ),
      Chat(
        chatJid: '2',
        groupName: 'Beta Team',
        lastMessageAt: DateTime.now().millisecondsSinceEpoch - 1000,
        totalImages: 2,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          chatsProvider.overrideWith(() => FakeChatsNotifier(chats)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatList()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Grupo Alpha'), findsOneWidget);
    expect(find.text('Beta Team'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'alpha');
    await tester.pump();

    expect(find.text('No se encontraron grupos'), findsNothing);
    expect(find.text('Grupo Alpha'), findsWidgets);
  });
}
