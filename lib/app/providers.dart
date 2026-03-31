//providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/auth/data/datasources/firebase_auth_datasource_impl.dart';
import 'package:whatsapp_monitor_viewer/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';
import 'package:whatsapp_monitor_viewer/features/chats/data/datasources/chats_firestore_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/chats/data/repositories/chats_repository_impl.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/repositories/chats_repository.dart';

/// ===============================
/// 🔐 FirebaseAuth (infraestructura)
/// ===============================

/// FirebaseAuth (infraestructura)
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Datasource
final firebaseAuthDatasourceProvider = Provider<FirebaseAuthDatasource>((ref) {
  final firebaseAuth = ref.read(firebaseAuthProvider);
  return FirebaseAuthDatasourceImpl(firebaseAuth);
});

/// Repository (puente data → domain)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final datasource = ref.read(firebaseAuthDatasourceProvider);
  return AuthRepositoryImpl(datasource);
});

/// ===============================
/// 🔥 FirebaseFirestore (infraestructura)
/// ===============================
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final chatsDatasourcesProvider = Provider<ChatsFirestoreDatasource>(
  (ref) => ChatsFirestoreDatasource(ref.read(firestoreProvider)),
);

final chatsRepositoryProvider = Provider<ChatsRepository>(
  (ref) => ChatsRepositoryImpl(ref.read(chatsDatasourcesProvider)),
);
